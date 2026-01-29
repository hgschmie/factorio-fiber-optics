--------------------------------------------------------------------------------
-- runtime code
--------------------------------------------------------------------------------
assert(script)

-- first line
require('lib.init')

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')
local Area = require('stdlib.area.area')

local Matchers = require('framework.matchers')

local const = require('lib.constants')

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

---@param event EventData.on_pre_build
local function on_pre_build(event)
    local _, player_data = Player.get(event.player_index)

    -- register the per-player flip state
    player_data.h_flipped = event.flip_horizontal
    player_data.v_flipped = event.flip_vertical
end

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function on_entity_created(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end

    script.register_on_object_destroyed(entity)

    ---@type Tags?
    local tags = event.tags
    local player_index = event.player_index

    local entity_ghost = Framework.ghost_manager:findGhostForEntity(entity)
    if entity_ghost then
        tags = tags or entity_ghost.tags
        player_index = player_index or entity_ghost.player_index
    end

    local h_flipped = false
    local v_flipped = false

    if player_index then
        local _, player_data = Player.get(player_index)
        h_flipped = player_data.h_flipped or false
        v_flipped = player_data.v_flipped or false
    end

    local area = Area.new(entity.selection_box)

    -- find all the ghosts that are covered by the new entity
    -- Those would be placed by paste / blueprint and the main entity
    -- will pick them up and revive (to keep e.g. wire connections)
    local attached_ghosts = Framework.ghost_manager:findGhostsInArea(area, function(ghost)
        -- if the ghost has tags with an iopin_index (therefore represents an IO Pin),
        -- store it under the iopin index value, not its name. The creation code will
        -- pick it up using the index because most pins have the same name.
        local iopin_index = ghost.tags and ghost.tags['iopin_index']
        return iopin_index and iopin_index or ghost.entity.ghost_name
    end)

    -- when doing direct build with cut and paste, then all the entities
    -- (iopins and power) have already been built before the main oc is
    -- built. Pick up those; the OC needs to adopt them and not build new
    -- entities.
    local attached_entities = This.other:findEntitiesInArea(area)

    This.fo:create {
        main = entity,
        tags = tags,
        h_flipped = h_flipped,
        v_flipped = v_flipped,
        attached_entities = attached_entities,
        attached_ghosts = attached_ghosts,
    }
end

-- record any attached entity
---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function on_attached_entity_created(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end

    script.register_on_object_destroyed(entity)

    This.other:registerEntity(entity, event.tags)
end

---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_space_platform_mined_entity | EventData.script_raised_destroy
local function on_entity_deleted(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end

    This.fo:destroy(entity.unit_number)
    This.pin:deletePin(entity.unit_number)
    This.other:deleteEntity(entity.unit_number)
end

--------------------------------------------------------------------------------
-- Entity destruction
--------------------------------------------------------------------------------

---@param event EventData.on_object_destroyed
local function on_object_destroyed(event)
    This.fo:destroy(event.useful_id)
end

--------------------------------------------------------------------------------
-- rotation
--------------------------------------------------------------------------------

---@param event EventData.on_player_rotated_entity
local function on_player_rotated_entity(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end

    local player = Player.get(event.player_index)

    This.fo:rotate(entity.unit_number, event.previous_direction, player)
end

---@param event EventData.on_player_flipped_entity
local function on_player_flipped_entity(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end

    local player = Player.get(event.player_index)

    This.fo:flip(entity.unit_number, event.horizontal, player)
end

--------------------------------------------------------------------------------
-- Selected Entity changed (for IO Pin labels)
--------------------------------------------------------------------------------

---@param event EventData.on_selected_entity_changed
local function on_selected_entity_changed(event)
    local player = Player.get(event.player_index)

    This.pin:displayCaption(player.selected, event.player_index)
end

--------------------------------------------------------------------------------
-- Configuration changes (startup)
--------------------------------------------------------------------------------

local function on_configuration_changed()
    This:init()

    for _, force in pairs(game.forces) do
        if force.recipes[const.main_entity_name] and force.technologies[const.main_entity_name] then
            force.recipes[const.main_entity_name].enabled = force.technologies[const.main_entity_name].researched
        end
    end
end

--------------------------------------------------------------------------------
-- Entity serialization
--------------------------------------------------------------------------------
---@param entity LuaEntity
---@return table<string, any>?
local function serialize_fo(entity)
    if not (entity and entity.valid) then return end
    return This.fo:serialize(entity.unit_number)
end

---@param entity LuaEntity
---@return table<string, any>?
local function serialize_pin(entity)
    if not (entity and entity.valid) then return end
    return This.pin:serialize(entity.unit_number)
end

---@param main_entity LuaEntity
---@param idx integer
---@param context table<string, any>
local function register_iopin(main_entity, idx, context)
    if not (main_entity and main_entity.valid) then return end
    return This.fo:register_blueprint_context(main_entity.unit_number, context)
end

---@param attached_entity framework.ghost_manager.AttachedEntity
---@param all_entities framework.ghost_manager.AttachedEntity[]
---@return table<integer, framework.ghost_manager.AttachedEntity>
local function ghost_refresh(attached_entity, all_entities)
    return This.other:ghostRefresh(attached_entity, all_entities)
end

--------------------------------------------------------------------------------
-- Event ticker
--------------------------------------------------------------------------------

local function on_tick()
    This.other:tick()
end

--------------------------------------------------------------------------------
-- event registration and management
--------------------------------------------------------------------------------

local function register_events()
    local main_entity_matcher = Matchers:matchEventEntityName(const.main_entity_name)
    local attached_entities_matcher = Matchers:matchEventEntityName(const.attached_entity_names)

    -- entity create / delete
    Event.register(defines.events.on_pre_build, on_pre_build)

    -- creation events
    Event.register(Matchers.CREATION_EVENTS, on_entity_created, main_entity_matcher)
    Event.register(Matchers.CREATION_EVENTS, on_attached_entity_created, attached_entities_matcher)

    -- deletion events
    Event.register(Matchers.DELETION_EVENTS, on_entity_deleted, main_entity_matcher)

    -- entity destroy (can't filter on that)
    Event.register(defines.events.on_object_destroyed, on_object_destroyed)

    -- manage ghost building (robot building)
    Framework.ghost_manager:registerForName(const.main_entity_name, ghost_refresh)
    Framework.ghost_manager:registerForName(const.attached_entity_names)

    -- selection change (pin label hovers)
    Event.register(defines.events.on_selected_entity_changed, on_selected_entity_changed)

    -- Configuration changes (startup)
    Event.on_configuration_changed(on_configuration_changed)

    -- manage blueprinting and copy/paste
    Framework.blueprint:registerCallbackForNames(const.main_entity_name, serialize_fo, register_iopin)
    Framework.blueprint:registerCallbackForNames({ const.pin_one_entity_name, const.pin_entity_name }, serialize_pin)

    -- rotation and flipping
    Event.register(defines.events.on_player_rotated_entity, on_player_rotated_entity, main_entity_matcher)
    Event.register(defines.events.on_player_flipped_entity, on_player_flipped_entity, main_entity_matcher)

    -- ticker code
    Event.on_nth_tick(299, on_tick)
end

--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------

local function on_init()
    This:init()

    register_events()
end

local function on_load()
    register_events()
end

-- setup player management
Player.register_events(true)

Event.on_init(on_init)
Event.on_load(on_load)

--------------------------------------------------------------------------------

---@diagnostic disable-next-line: undefined-field
Framework.post_runtime_stage()
