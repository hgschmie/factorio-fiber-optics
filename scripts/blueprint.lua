---@meta
--------------------------------------------------------------------------------
-- Blueprint / copy&paste management
--------------------------------------------------------------------------------

local Is = require('__stdlib__/stdlib/utils/is')
local table = require('__stdlib__/stdlib/utils/table')

local const = require('lib.constants')

---@class FiberNetworkBlueprint
local Blueprint = {}

-- all entities that are moved to the back of the blueprint
local move_to_tail = table.array_to_dictionary {
    const.optical_connector
}

local function reorder_optical_connectors(blueprint_entity)
    return move_to_tail[blueprint_entity.name]
end

local function rewrite_blueprint_entities(array, id_map)
    for _, entry in pairs(array) do
        if entry.entity_id then
            entry.entity_id = id_map[entry.entity_id]
        else
            rewrite_blueprint_entities(entry, id_map)
        end
    end
end

-- reorders the blueprint based on the passed split function. If the function
-- returns true, move the BlueprintEntity to the end of the list. This is necessary
-- e.g. for the optical connectors where the IOPins etc. must be built before the
-- main entity so that they can be adopted by the main entity.
---@param blueprint LuaItemStack
---@param splitter function(blueprint_entity: BlueprintEntity): boolean
---@return BlueprintEntity[] blueprint_entities
local function reorder_blueprint(blueprint, splitter)
    local blueprint_entities = blueprint.get_blueprint_entities()
    assert(blueprint_entities)

    -- if there are any attached entities in the blueprint, reorder so that they get built
    -- before the actual oc's. Otherwise any entity built after the oc will not be created
    -- (and that would lose e.g. wire connections)

    ---@type BlueprintEntity[], BlueprintEntity[]
    local head_list, tail_list = {}, {}

    -- split the blueprint into head and tail
    for _, blueprint_entity in pairs(blueprint_entities) do
        if splitter(blueprint_entity) then
            table.insert(tail_list, blueprint_entity)
        else
            table.insert(head_list, blueprint_entity)
        end
    end

    if #tail_list == 0 then return blueprint_entities end

    -- attach tail to head
    for _, blueprint_entity in pairs(tail_list) do
        table.insert(head_list, blueprint_entity)
    end

    -- create a map from the old entity id (before reordering) to the new order
    local id_map = {}
    local blueprint_count = 1
    for _, blueprint_entity in pairs(head_list) do
        id_map[blueprint_entity.entity_number] = blueprint_count
        blueprint_entity.entity_number = blueprint_count
        blueprint_count = blueprint_count + 1
    end

    -- rewrite the connection information

    -- neighbours for electric poles etc.
    for _, blueprint_entity in pairs(head_list) do
        if blueprint_entity.neighbours then
            -- electric poles have neighbours...
            blueprint_entity.neighbours = table.map(blueprint_entity.neighbours, function(neighbor) return id_map[neighbor] end)
        end

        -- other stuff has entity_id values
        if blueprint_entity.connections then
            rewrite_blueprint_entities(blueprint_entity.connections, id_map)
        end
    end

    -- replace the current blueprint
    blueprint.clear_blueprint()
    blueprint.set_blueprint_entities(head_list)
    return head_list
end

--- @param blueprint LuaItemStack
--- @param entities LuaEntity[]
local function save_to_blueprint(entities, blueprint)
    if not entities or #entities < 1 then return end
    if not (blueprint and blueprint.is_blueprint_setup()) then return end

    local blueprint_entities = reorder_blueprint(blueprint, reorder_optical_connectors)
    assert(blueprint_entities)

    -- blueprints hold a set of entities without any identifying information besides
    -- the position of the entity. Build a double-index map that allows finding the
    -- index in the blueprint entity list by x/y coordinate.
    local blueprint_index = {}

    for idx, blueprint_entity in pairs(blueprint_entities) do
        local x_map = blueprint_index[blueprint_entity.position.x] or {}
        local y_map = x_map[blueprint_entity.position.y] or {}
        x_map[blueprint_entity.position.y] = y_map
        assert(not y_map[blueprint_entity.name])
        y_map[blueprint_entity.name] = idx

        blueprint_index[blueprint_entity.position.x] = x_map
    end

    -- -- all entities here are of interest. Find their index in the blueprint
    -- -- and assign the config as a tag.
    for _, entity in pairs(entities) do
        local idx_map = (blueprint_index[entity.position.x] or {})[entity.position.y]
        if idx_map and idx_map[entity.name] then
            local oc_config = This.oc:entity(entity.unit_number)
            -- record the flip index with the blueprint
            if oc_config then
                blueprint.set_blueprint_entity_tag(idx_map[entity.name], 'flip_index', oc_config.flip_index)
            end
        end
    end
end

--- checks whether the player has a valid blueprint for editing
---@param player LuaPlayer
---@return boolean valid
local function has_valid_blueprint(player)
    if not Is.Valid(player) then return false end
    if not player.cursor_stack then return false end

    return (player.cursor_stack.valid_for_read and player.cursor_stack.name == 'blueprint')
end

---@param player LuaPlayer
---@param player_data table<string, any>
---@param area BoundingBox
function Blueprint:setupBlueprint(player, player_data, area)
    local entities = player.surface.find_entities_filtered {
        area = area,
        force = player.force,
    }

    -- nothing in there for us
    if #entities < 1 then return end

    if has_valid_blueprint(player) then
        save_to_blueprint(entities, player.cursor_stack)
    else
        -- Player is editing the blueprint, no access for us yet.
        -- onPlayerConfiguredBlueprint picks this up and stores it.
        player_data.current_blueprint = entities
    end
end

---@param player LuaPlayer
---@param player_data table<string, any>
function Blueprint:configuredBlueprint(player, player_data)
    if player_data.current_blueprint then
        if has_valid_blueprint(player) and player_data.current_blueprint then
            save_to_blueprint(player_data.current_blueprint, player.cursor_stack)
        end
        player_data.current_blueprint = nil
    end
end

return Blueprint
