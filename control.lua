--------------------------------------------------------------------------------
-- runtime code
--------------------------------------------------------------------------------
assert(script)

-- first line
require('lib.init')

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')

local const = require('lib.constants')

local Matchers = require('framework.matchers')

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function on_entity_created(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end

    script.register_on_object_destroyed(entity)

    ---@type Tags?
    local tags = event.tags

    local entity_ghost = Framework.ghost_manager:findGhostForEntity(entity)
    if entity_ghost then
        tags = tags or entity_ghost.tags
    end

    This.fo:create {
        main = entity,
        tags = tags,
    }
end

---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_space_platform_mined_entity | EventData.script_raised_destroy
local function on_entity_deleted(event)
     local entity = event and event.entity
    if not (entity and entity.valid) then return end

    This.fo:destroy(entity.unit_number)
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
    game.print(("Direction: %d, Mirror : %s"):format(entity.direction, entity.mirroring))
end

---@param event EventData.on_player_flipped_entity
local function on_player_flipped_entity(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end
    game.print(("Direction: %d, Mirror : %s"):format(entity.direction, entity.mirroring))
end

--------------------------------------------------------------------------------
-- Configuration changes (startup)
--------------------------------------------------------------------------------

local function on_configuration_changed()
    This.fo:init()

    for _, force in pairs(game.forces) do
        if force.recipes[const.main_entity_name] and force.technologies[const.main_entity_name] then
            force.recipes[const.main_entity_name].enabled = force.technologies[const.main_entity_name].researched
        end
    end
end

--------------------------------------------------------------------------------
-- event registration and management
--------------------------------------------------------------------------------

local function register_events()
    local main_entity_matcher = Matchers:matchEventEntityName(const.main_entity_name)

    -- creation events
    Event.register(Matchers.CREATION_EVENTS, on_entity_created, main_entity_matcher)

    -- deletion events
    Event.register(Matchers.DELETION_EVENTS, on_entity_deleted, main_entity_matcher)

    -- entity destroy (can't filter on that)
    Event.register(defines.events.on_object_destroyed, on_object_destroyed)

    -- manage ghost building (robot building)
    Framework.ghost_manager:registerForName(const.main_entity_name) -- TODO , This.attached_entities.ghostRefresh)


    -- Configuration changes (startup)
    Event.on_configuration_changed(on_configuration_changed)

    -- rotation and flipping
    Event.register(defines.events.on_player_rotated_entity, on_player_rotated_entity, main_entity_matcher)
    Event.register(defines.events.on_player_flipped_entity, on_player_flipped_entity, main_entity_matcher)

end

--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------

local function on_init()
    This.fo:init()

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
