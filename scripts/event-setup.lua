---@meta
--------------------------------------------------------------------------------
-- event setup for the mod
--------------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Is = require('stdlib.utils.is')
local Player = require('stdlib.event.player')
local Area = require('stdlib.area.area')
local table = require('stdlib.utils.table')

local tools = require('framework.tools')

local const = require('lib.constants')

--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------
local function onInitOc()
    This.oc:init()
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

-- record any attached entity
---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function onAttachedEntityCreated(event)
    local entity = event and event.entity
    if not Is.Valid(entity) then return end

    script.register_on_object_destroyed(entity)

    This.attached_entities:registerEntity(entity, event.player_index, event.tags)
end

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

---@param event EventData.on_pre_build
local function onPreBuild(event)
    local _, player_data = Player.get(event.player_index)

    -- register the per-player flip state
    player_data.flip_horizontal = event.flip_horizontal
    player_data.flip_vertical = event.flip_vertical
end


---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built | EventData.on_space_platform_built_entity
local function onEntityCreated(event)
    local entity = event and event.entity

    -- register entity for destruction
    script.register_on_object_destroyed(entity)

    local player_index = event.player_index

    local tags = event.tags

    local entity_ghost = Framework.ghost_manager:findMatchingGhost(entity)
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
        if ghost.tags and ghost.tags.iopin_index then
            return ghost.tags.iopin_index
        else
            return ghost.name
        end
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

---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_entity_died | EventData.script_raised_destroy
local function onEntityDeleted(event)
    local entity = event and event.entity
    if not entity then return end

    This.oc:destroy(entity.unit_number)
end

--------------------------------------------------------------------------------
-- entity destroy
--------------------------------------------------------------------------------

---@param event EventData.on_object_destroyed
local function onObjectDestroyed(event)
    -- is it a known ghost or entity?
    This.attached_entities:delete(event.useful_id)

    -- or a main entity?
    local oc_entity = This.oc:entity(event.useful_id)
    if oc_entity then
        -- main entity destroyed
        This.oc:destroy(event.useful_id)
    end
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
    This.oc:tick()
    This.attached_entities:tick()
    This.network:tick()
end

--------------------------------------------------------------------------------
-- config changes
--------------------------------------------------------------------------------

---@param ev ConfigurationChangedData?
local function onConfigurationChanged(ev)
    for _, force in pairs(game.forces) do
        if force.recipes[const.optical_connector] then
            force.recipes[const.optical_connector].enabled = force.technologies[const.optical_connector_technology].researched
        end
    end
end

--------------------------------------------------------------------------------
-- Event registration
--------------------------------------------------------------------------------

-- mod init/load code
Event.on_init(onInitOc)
Event.on_load(onLoadOc)

Event.register(defines.events.on_player_cursor_stack_changed, onPlayerCursorStackChanged)
Event.register(defines.events.on_selected_entity_changed, onSelectedEntityChanged)

local oc_entity_filter = tools.create_event_entity_matcher('name', const.optical_connector)
local oc_attached_entities_filter = tools.create_event_entity_matcher('name', const.attached_entities)

-- rotation
Event.register(defines.events.on_player_rotated_entity, onPlayerRotatedEntity, oc_entity_filter)

-- manage ghost building (robot building)
Framework.ghost_manager:register_for_ghost_names(const.ghost_entities)
Framework.ghost_manager:register_for_ghost_refresh(const.optical_connector, This.attached_entities.ghost_refresh)

-- entity create / delete
Event.register(defines.events.on_pre_build, onPreBuild)

tools.event_register(tools.CREATION_EVENTS, onEntityCreated, oc_entity_filter)
tools.event_register(tools.CREATION_EVENTS, onAttachedEntityCreated, oc_attached_entities_filter)

tools.event_register(tools.DELETION_EVENTS, onEntityDeleted, oc_entity_filter)

-- Manage blueprint configuration setting
Framework.blueprint:register_callback(const.optical_connector, This.blueprint.oc_callback, This.blueprint.oc_map_callback)
Framework.blueprint:register_callback(const.all_iopins, This.blueprint.iopin_callback)
Framework.blueprint:register_preprocessor(This.blueprint.prepare_blueprint)

-- entity destroy
Event.register(defines.events.on_object_destroyed, onObjectDestroyed)

-- config changes
Event.on_configuration_changed(onConfigurationChanged)
Event.register(defines.events.on_runtime_mod_setting_changed, onConfigurationChanged)

-- ticker code
Event.on_nth_tick(299, onTick)
