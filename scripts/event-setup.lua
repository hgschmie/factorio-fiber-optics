--------------------------------------------------------------------------------
-- event setup for the mod
--------------------------------------------------------------------------------

local Event = require('__stdlib__/stdlib/event/event')
local Is = require('__stdlib__/stdlib/utils/is')
local Player = require('__stdlib__/stdlib/event/player')
local Area = require('__stdlib__/stdlib/area/area')
local table = require('__stdlib__/stdlib/utils/table')

local Util = require('framework.util')

local const = require('lib.constants')

--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------
local function onInitOc()
    This.network:init()
    This.attached_entities:init()
end

local function onLoadOc()
end

--------------------------------------------------------------------------------
-- rotation
--------------------------------------------------------------------------------

---@param event EventData.on_player_rotated_entity
local function onPlayerRotatedEntity(event)
    local entity = event and event.entity

    This.oc:rotate(entity, event.player_index, event.previous_direction)
end

--------------------------------------------------------------------------------
-- manage attached entities
--------------------------------------------------------------------------------

--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function onGhostEntityCreated(event)
    local entity = event and (event.created_entity or event.entity)
    if not Is.Valid(entity) then return end

    script.register_on_entity_destroyed(entity)

    This.attached_entities:registerGhost(entity, event.player_index)
end

-- record any attached entity
--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function onAttachedEntityCreated(event)
    local entity = event and (event.created_entity or event.entity)
    if not Is.Valid(entity) then return end

    script.register_on_entity_destroyed(entity)

    This.attached_entities:registerEntity(entity, event.player_index, event.tags)
end

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

--- @param event EventData.on_pre_build
local function onPreBuild(event)
    local _, player_data = Player.get(event.player_index)

    -- register the per-player flip state
    player_data.flip_horizontal = event.flip_horizontal
    player_data.flip_vertical = event.flip_vertical
end


--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function onEntityCreated(event)
    local entity = event and (event.created_entity or event.entity)

    -- register entity for destruction
    script.register_on_entity_destroyed(entity)

    local player_index = event.player_index

    local tags = event.tags

    local entity_ghost = This.attached_entities:findMatchingGhost(entity)
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
    local attached_ghosts = This.attached_entities:findGhostsInArea(area)

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

---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_entity_died | EventData.script_raised_destroy
local function onEntityDeleted(event)
    local entity = event and event.entity
    if not entity then return end

    This.oc:destroy(entity.unit_number)
end

--------------------------------------------------------------------------------
-- entity destroy
--------------------------------------------------------------------------------

---@param event EventData.on_entity_destroyed
local function onEntityDestroyed(event)
    -- is it a known ghost or entity?
    This.attached_entities:delete(event.unit_number)

    -- or a main entity?
    local oc_entity = This.oc:entity(event.unit_number)
    if oc_entity then
        -- main entity destroyed
        This.oc:destroy(event.unit_number)
    end
end

--------------------------------------------------------------------------------
-- Blueprint / copy&paste management
--------------------------------------------------------------------------------

--- @param event EventData.on_player_setup_blueprint
local function onPlayerSetupBlueprint(event)
    if not event.area then return end

    local player, player_data = Player.get(event.player_index)

    This.blueprint:setupBlueprint(player, player_data, event.area)
end

--- @param event EventData.on_player_configured_blueprint
local function onPlayerConfiguredBlueprint(event)
    local player, player_data = Player.get(event.player_index)

    This.blueprint:configuredBlueprint(player, player_data)
end

--------------------------------------------------------------------------------
-- Cursor stack / Pipette
--------------------------------------------------------------------------------

local match_attached_entities = table.array_to_dictionary(const.attached_entities)

local function onPlayerCursorStackChanged(event)
    local player = Player.get(event.player_index)

    if not Is.Valid(player) then return end
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

local function onSelectedEntityChanged(event)
    local player = Player.get(event.player_index)

    local selected_entity = player.selected --[[@as LuaEntity]]
    if not Is.Valid(selected_entity) then return end

    This.oc:displayPinCaption(selected_entity, event.player_index)
end

--------------------------------------------------------------------------------
-- Ticker code
--------------------------------------------------------------------------------

local function onTick()
    This.oc:update_entities()
    This.attached_entities:update()
end

--------------------------------------------------------------------------------
-- Debug code
--------------------------------------------------------------------------------

local function onDebugTick()
    This.network:fiber_network_debug_output()
end

local debug_enabled = false
local function onRuntimeModSettingsChanged(event)
    local new_debug_enabled = Framework.settings:runtime().debug_mode or false --[[@as boolean]]
    if new_debug_enabled ~= debug_enabled then
        if new_debug_enabled then
            Event.on_nth_tick(101, onDebugTick)
        else
            Event.remove(-101, onDebugTick)
        end
        debug_enabled = new_debug_enabled
    end
end

--------------------------------------------------------------------------------
-- Event registration
--------------------------------------------------------------------------------

-- mod init/load code
Event.on_init(onInitOc)
Event.on_load(onLoadOc)

Event.register(defines.events.on_player_cursor_stack_changed, onPlayerCursorStackChanged)
Event.register(defines.events.on_runtime_mod_setting_changed, onRuntimeModSettingsChanged)
Event.register(defines.events.on_selected_entity_changed, onSelectedEntityChanged)

local oc_entity_filter = Util.create_event_entity_matcher('name', const.optical_connector)
local oc_attached_entities_filter = Util.create_event_entity_matcher('name', const.attached_entities)
local oc_ghost_filter = Util.create_event_ghost_entity_matcher(const.ghost_entities)

-- rotation
Event.register(defines.events.on_player_rotated_entity, onPlayerRotatedEntity, oc_entity_filter)

-- manage ghost building (robot building)
Util.event_register(const.creation_events, onGhostEntityCreated, oc_ghost_filter)

-- entity create / delete
Event.register(defines.events.on_pre_build, onPreBuild)

Util.event_register(const.creation_events, onEntityCreated, oc_entity_filter)
Util.event_register(const.creation_events, onAttachedEntityCreated, oc_attached_entities_filter)

Util.event_register(const.deletion_events, onEntityDeleted, oc_entity_filter)

-- Blueprint / copy&paste management
Event.register(defines.events.on_player_setup_blueprint, onPlayerSetupBlueprint)
Event.register(defines.events.on_player_configured_blueprint, onPlayerConfiguredBlueprint)

-- entity destroy
Event.register(defines.events.on_entity_destroyed, onEntityDestroyed)

-- ticker code
Event.on_nth_tick(299, onTick)
