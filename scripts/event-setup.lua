--------------------------------------------------------------------------------
-- event setup for the mod
--------------------------------------------------------------------------------

local Event = require('__stdlib__/stdlib/event/event')
local Is = require('__stdlib__/stdlib/utils/is')

local Util = require('framework.util')

local const = require('lib.constants')

--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------
local function onInitOc()
    This.network:init()
end

local function onLoadOc()
end


--------------------------------------------------------------------------------
-- rotation
--------------------------------------------------------------------------------

---@param event EventData.on_player_rotated_entity
function onPlayerRotatedEntity(event)
    local entity = event and event.entity

    This.oc:rotate(entity, event.player_index, event.previous_direction)
end

--------------------------------------------------------------------------------
-- manage ghost building (robot building)
--------------------------------------------------------------------------------

function onGhostEntityCreated(event)
    local entity = event and (event.created_entity or event.entity)
    if not Is.Valid(entity) then return end

    This.oc:createGhost(event)
end

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
function onEntityCreated(event)
    local entity = event and (event.created_entity or event.entity)
    local tags = event.tags

    -- TODO Ghost management

    -- register entity for destruction
    script.register_on_entity_destroyed(entity)

    This.oc:create(entity, tags)
end

function onEntityDeleted(event)
    local entity = event and (event.created_entity or event.entity)
    if not entity then return end

    This.oc:destroy(entity.unit_number)
end

--------------------------------------------------------------------------------
-- deconstruction - todo
--------------------------------------------------------------------------------

function onMarkedForDeconstruction(event)
    local entity = event and (event.created_entity or event.entity)
    if not Is.Valid(entity) then return end

    This.oc:mark_for_deconstruction(entity)
end

--------------------------------------------------------------------------------
-- entity destroy
--------------------------------------------------------------------------------

function onEntityDestroyed(event)
    --     This.context_manager:cleanup(event.unit_number)
end

--------------------------------------------------------------------------------
-- Ticker code
--------------------------------------------------------------------------------

function onTick(event)
    --    This.network:fiber_network_management_handler()
end

--------------------------------------------------------------------------------
-- Debug code
--------------------------------------------------------------------------------

function onDebugTick(event)
    --     This.network:fiber_network_debug_output()
end

--------------------------------------------------------------------------------
-- Event registration
--------------------------------------------------------------------------------

local oc_entity_filter = Util.create_event_entity_matcher('name', const.optical_connector)
local oc_attached_entities_filter = Util.create_event_entity_matcher('name', const.attached_entities)
local oc_ghost_filter = Util.create_event_ghost_entity_matcher(const.attached_entities)


-- mod init/load code
Event.on_init(onInitOc)
Event.on_load(onLoadOc)

-- rotation
Event.register(defines.events.on_player_rotated_entity, onPlayerRotatedEntity)

-- manage ghost building (robot building)
Util.event_register(const.creation_events, onGhostEntityCreated, oc_ghost_filter)

-- entity create / delete
Util.event_register(const.creation_events, onEntityCreated, oc_entity_filter)
Util.event_register(const.deletion_events, onEntityDeleted, oc_entity_filter)


-- deconstruction - todo
Event.register(defines.events.on_marked_for_deconstruction, onMarkedForDeconstruction, oc_attached_entities_filter)

-- entity destroy
Event.register(defines.events.on_entity_destroyed, onEntityDestroyed)

-- ticker code
-- Event.on_nth_tick(299, onTick)

-- debug code
if bit32.band(const.debug_mode, 1) ~= 0 then
    --     Event.on_nth_tick(101, onDebugTick)
end
