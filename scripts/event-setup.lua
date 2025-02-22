--------------------------------------------------------------------------------
-- event setup for the mod
--------------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')
local Area = require('stdlib.area.area')
local table = require('stdlib.utils.table')

local Matchers = require('framework.matchers')
local tools = require('framework.tools')

local const = require('lib.constants')

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

---@param event EventData.on_pre_build
local function on_pre_build(event)
    local _, player_data = Player.get(event.player_index)

    -- register the per-player flip state
    player_data.flip_horizontal = event.flip_horizontal
    player_data.flip_vertical = event.flip_vertical
end


---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function on_entity_created(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end

    local player_index = event.player_index
    local tags = event.tags

    local entity_ghost = Framework.ghost_manager:findGhostForEntity(entity)
    if entity_ghost then
        player_index = player_index or entity_ghost.player_index
        tags = tags or entity_ghost.tags
    end

    local flip_index = 1 -- (NORMAL - no flips)
    if player_index then
        local _, player_data = Player.get(player_index)
        -- increase the flip index based on present flips
        flip_index = flip_index + (player_data.flip_horizontal and 1 or 0)
        flip_index = flip_index + (player_data.flip_vertical and 2 or 0)
    end

    local area = Area.new(entity.selection_box)

    -- find all the ghosts that are covered by the new entity
    -- Those would be placed by paste / blueprint and the main entity
    -- will pick them up and revive (to keep e.g. wire connections)
    local attached_ghosts = Framework.ghost_manager:findGhostsInArea(area, function(ghost)
        -- if the ghost has tags with an iopin_index (therefore represents an IO Pin),
        -- store it under the iopin index value, not its name. The creation code will
        -- pick it up using the index because most pins have the same name.
        local iopin_index = ghost.tags and ghost.tags[const.iopin_index_tag]
        return iopin_index and iopin_index or ghost.entity.ghost_name
    end)

    -- when doing direct build with cut and paste, then all the entities
    -- (iopins and power) have already been built before the main oc is
    -- built. Pick up those; the OC needs to adopt them and not build new
    -- entities.
    local attached_entities = This.attached_entities:findEntitiesInArea(area)

    This.oc:create {
        main = entity,
        tags = tags,
        player_index = player_index,
        ghosts = attached_ghosts,
        attached = attached_entities,
        flip_index = flip_index,
    }
end

---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_space_platform_mined_entity | EventData.script_raised_destroy
local function on_entity_deleted(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end
    assert(entity.unit_number)

    This.oc:destroy(entity.unit_number)
end

--------------------------------------------------------------------------------
-- Entity destruction
--------------------------------------------------------------------------------

---@param event EventData.on_object_destroyed
local function on_object_destroyed(event)
    -- is it a known ghost or entity?
    This.attached_entities:deleteEntity(event.useful_id)

    -- main entity destroyed
    This.oc:destroy(event.useful_id)
end

--------------------------------------------------------------------------------
-- rotation
--------------------------------------------------------------------------------

---@param event EventData.on_player_rotated_entity
local function on_player_rotated_entity(event)
    local entity = event and event.entity

    This.oc:rotate(entity, event.player_index, event.previous_direction)
end

--------------------------------------------------------------------------------
-- manage attached entities
--------------------------------------------------------------------------------

-- record any attached entity
---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function on_attached_entity_created(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end

    script.register_on_object_destroyed(entity)

    This.attached_entities:registerEntity(entity, event.player_index, event.tags)
end

--------------------------------------------------------------------------------
-- Cursor stack / Pipette
--------------------------------------------------------------------------------

local match_attached_entities = table.array_to_dictionary(const.attached_entities)

local function on_player_cursor_stack_changed(event)
    local player = Player.get(event.player_index)
    if not (player and player.valid) then return end

    if not (player.cursor_stack and player.cursor_stack.valid_for_read) then return end

    -- don't allow picking up any of the attached entities
    if match_attached_entities[player.cursor_stack.name] then
        player.cursor_stack.clear()
        return
    end
end

--------------------------------------------------------------------------------
-- Selected Entity changed (for IO Pin labels)
--------------------------------------------------------------------------------

local function on_selected_entity_changed(event)
    local player = Player.get(event.player_index)

    local selected_entity = player.selected --[[@as LuaEntity]]
    if not (selected_entity and selected_entity.valid) then return end

    This.oc:displayPinCaption(selected_entity, event.player_index)
end

--------------------------------------------------------------------------------
-- Configuration changes (startup)
--------------------------------------------------------------------------------

local function on_configuration_changed()
    This.oc:init()
    This.network:init()
    This.attached_entities:init()

    for _, force in pairs(game.forces) do
        if force.recipes[const.optical_connector] and force.technologies[const.optical_connector] then
            force.recipes[const.optical_connector].enabled = force.technologies[const.optical_connector_technology].researched
        end
    end

    -- force disconnect and reconnect of all entities
    This.oc:tick(true)
    This.network:tick()
end

--------------------------------------------------------------------------------
-- Event ticker
--------------------------------------------------------------------------------

local function on_tick()
    This.oc:tick()
    This.attached_entities:tick()
    This.network:tick()
end

--------------------------------------------------------------------------------
-- event registration and management
--------------------------------------------------------------------------------

local function register_events()
    local oc_entity_matcher = Matchers:matchEventEntityName(const.optical_connector)
    local oc_attached_entities_matcher = Matchers:matchEventEntityName(const.attached_entities)

    -- entity create / delete
    Event.register(defines.events.on_pre_build, on_pre_build)

    Event.register(Matchers.CREATION_EVENTS, on_entity_created, oc_entity_matcher)
    Event.register(Matchers.CREATION_EVENTS, on_attached_entity_created, oc_attached_entities_matcher)

    Event.register(Matchers.DELETION_EVENTS, on_entity_deleted, oc_entity_matcher)

    -- manage ghost building (robot building)
    Framework.ghost_manager:registerForName(const.optical_connector, This.attached_entities.ghostRefresh)
    Framework.ghost_manager:registerForName(const.attached_entities)

    Event.register(defines.events.on_player_cursor_stack_changed, on_player_cursor_stack_changed)
    Event.register(defines.events.on_selected_entity_changed, on_selected_entity_changed)

    -- entity destroy (can't filter on that)
    Event.register(defines.events.on_object_destroyed, on_object_destroyed)

    -- Configuration changes (startup)
    Event.on_configuration_changed(on_configuration_changed)

    -- manage blueprinting and copy/paste
    Framework.blueprint:registerPreprocessor(This.blueprint.prepare_blueprint)
    Framework.blueprint:registerCallback(const.optical_connector, This.blueprint.serializeOc, This.blueprint.registerIoPins)
    Framework.blueprint:registerCallback(const.all_iopins, This.blueprint.serializeIoPins)

    -- manage tombstones for undo/redo and dead entities
    Framework.tombstone:registerCallback(const.optical_connector, {
        create_tombstone = This.blueprint.serializeOc,
        apply_tombstone = Framework.ghost_manager.mapTombstoneToGhostTags,
    })

    Framework.tombstone:registerCallback(const.attached_entities, {
        create_tombstone = This.blueprint.serializeIoPins,
        apply_tombstone = Framework.ghost_manager.mapTombstoneToGhostTags,
    })

    -- rotation
    Event.register(defines.events.on_player_rotated_entity, on_player_rotated_entity, oc_entity_matcher)

    -- ticker code
    Event.on_nth_tick(299, on_tick)
end

--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------

local function on_init()
    This.oc:init()
    This.network:init()
    This.attached_entities:init()
    register_events()
end

local function on_load()
    register_events()
end

-- setup player management
Player.register_events(true)

Event.on_init(on_init)
Event.on_load(on_load)
