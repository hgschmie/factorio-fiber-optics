--------------------------------------------------------------------------------
-- Blueprint / copy&paste management
--------------------------------------------------------------------------------
assert(script)

local Is = require('stdlib.utils.is')
local table = require('stdlib.utils.table')

local const = require('lib.constants')

---@class FiberNetworkBlueprint
local Blueprint = {}

-- all entities that are moved to the back of the blueprint
local move_to_tail = table.array_to_dictionary {
    const.optical_connector
}

local function reorder_optical_connectors(blueprint_entity)
    -- if there are any attached entities in the blueprint, reorder so that they get built
    -- before the actual oc's. Otherwise any entity built after the oc will not be created
    -- (and that would lose e.g. wire connections)
    return move_to_tail[blueprint_entity.name]
end

---@param wires BlueprintWire[]
---@param id_map table<integer, integer>
local function rewrite_blueprint_entities(wires, id_map)
    local also_rewrite = {}
    for _, wire in pairs(wires) do
        if id_map[wire[1]] then
            wire[1] = id_map[wire[1]]
        end
        if id_map[wire[3]] then
            wire[3] = id_map[wire[3]]
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
    ---@type BlueprintEntity[], BlueprintEntity[]
    local head_list, tail_list = {}, {}

    local blueprint_entities = blueprint.get_blueprint_entities()
    if not blueprint_entities then return head_list end

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
    ---@type table<integer, integer>
    local id_map = {}
    local blueprint_count = 1
    for _, blueprint_entity in pairs(head_list) do
        id_map[blueprint_entity.entity_number] = blueprint_count
        blueprint_entity.entity_number = blueprint_count
        blueprint_count = blueprint_count + 1
    end

    -- rewrite the wire connection information
    for _, blueprint_entity in pairs(head_list) do
        if blueprint_entity.wires then
            rewrite_blueprint_entities(blueprint_entity.wires, id_map)
        end
    end

    -- replace the current blueprint
    blueprint.clear_blueprint()
    blueprint.set_blueprint_entities(head_list)
    return head_list
end

-- #region Callback Code

---@param blueprint LuaItemStack
---@return BlueprintEntity[] entities
function Blueprint.prepare_blueprint(blueprint)
    return reorder_blueprint(blueprint, reorder_optical_connectors)
end

---@param entity LuaEntity
---@return table<string, any>?
function Blueprint.serializeOc(entity)
    if not (entity or entity.valid) then return end
    -- for all OC entities, record the flip index. This is needed to "unflip" the entity
    -- when building to place the pins in the right places.
    local oc_config = This.oc:entity(entity.unit_number)
    if not oc_config then return end

    return {
        [const.flip_index_tag] = oc_config.flip_index,
    }
end

---@param oc LuaEntity
---@param idx integer
---@param context table<string, any>
function Blueprint.registerIoPins(oc, idx, context)
    context.iopin_index = context.iopin_index or {}
    if not (oc and oc.valid) then return end

    local oc_config = This.oc:entity(oc.unit_number)
    if not (oc_config and oc_config.iopin) then return end

    for iopin_idx, iopin_entity in pairs(oc_config.iopin) do
        context.iopin_index[iopin_entity.unit_number] = iopin_idx
    end
end

---@param entity LuaEntity
---@param context table<string, any>
---@return table<string, any>?
function Blueprint.serializeIoPins(entity, context)
    if not (entity or entity.valid) then return end

    context.iopin_index = context.iopin_index or {}

    -- for io pins, record their index which comes from the map that was built above
    local iopin_idx = context.iopin_index[entity.unit_number]
    if not iopin_idx then
        Framework.logger:logf('Found an unknown IO Pin entity, ignoring: %d', entity.unit_number)
        return
    end

    return {
        [const.iopin_index_tag] = iopin_idx,
    }
end

-- #endregion

return Blueprint
