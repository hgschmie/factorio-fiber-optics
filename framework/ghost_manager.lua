---@meta
------------------------------------------------------------------------
-- Manage all ghost state for robot building
------------------------------------------------------------------------

local Event = require('stdlib.event.event')
local Is = require('stdlib.utils.is')
local Position = require('stdlib.area.position')

local tools = require('framework.tools')

---@class FrameworkGhostManager
local FrameworkGhostManager = {}

---@return FrameworkGhostManagerState state Manages ghost state
function FrameworkGhostManager:state()
    local storage = Framework.runtime:storage()

    if not storage.ghost_manager then
        ---@type FrameworkGhostManagerState
        storage.ghost_manager = {
            ghost_entities = {},
        }
    end

    return storage.ghost_manager
end

---@param entity LuaEntity
---@param player_index integer
function FrameworkGhostManager:registerGhost(entity, player_index)
    -- if an entity ghost was placed, register information to configure
    -- an entity if it is placed over the ghost

    local state = self:state()

    state.ghost_entities[entity.unit_number] = {
        -- maintain entity reference for attached entity ghosts
        entity = entity,
        -- but for matching ghost replacement, all the values
        -- must be kept because the entity is invalid when it
        -- replaces the ghost
        name = entity.ghost_name,
        position = entity.position,
        orientation = entity.orientation,
        tags = entity.tags,
        player_index = player_index,
        -- allow 10 seconds of dwelling time until a refresh must have happened
        tick = game.tick + 600,
    }
end

function FrameworkGhostManager:deleteGhost(unit_number)
    local state = self:state()

    if state.ghost_entities[unit_number] then
        state.ghost_entities[unit_number].entity.destroy()
        state.ghost_entities[unit_number] = nil
    end
end

---@param entity LuaEntity
---@return FrameworkAttachedEntity? attached_entity
function FrameworkGhostManager:findMatchingGhost(entity)
    local state = self:state()

    -- find a ghost that matches the entity
    for idx, ghost in pairs(state.ghost_entities) do
        -- it provides the tags and player_index for robot builds
        if entity.name == ghost.name
            and entity.position.x == ghost.position.x
            and entity.position.y == ghost.position.y
            and entity.orientation == ghost.orientation then
            state.ghost_entities[idx] = nil
            return ghost
        end
    end
    return nil
end

---@param area BoundingBox
---@param callback fun(ghost: FrameworkAttachedEntity) : any?
---@return table<any, FrameworkAttachedEntity> attached_entities
function FrameworkGhostManager:findGhostsInArea(area, callback)
    local state = self:state()

    local ghosts = {}
    for idx, ghost in pairs(state.ghost_entities) do
        local pos = Position.new(ghost.position)
        if pos:inside(area) then
            local key = callback(ghost)
            if key then
                ghosts[key] = ghost
                storage.ghost_entities[idx] = nil
            end
        end
    end

    return ghosts
end

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
function FrameworkGhostManager.onGhostEntityCreated(event)
    local entity = event and event.entity
    if not Is.Valid(entity) then return end

    script.register_on_object_destroyed(entity)

    Framework.ghost_manager:registerGhost(entity, event.player_index)
end

---@param event EventData.on_object_destroyed
function FrameworkGhostManager.onObjectDestroyed(event)
    Framework.ghost_manager:deleteGhost(event.useful_id)
end

function FrameworkGhostManager.register_for_ghost_names(values)
    local ghost_filter = tools.create_event_ghost_entity_name_matcher(values)
    tools.event_register(tools.CREATION_EVENTS, Framework.ghost_manager.onGhostEntityCreated, ghost_filter)
end

function FrameworkGhostManager.register_for_ghost_attributes(attribute, values)
    local ghost_filter = tools.create_event_ghost_entity_matcher(attribute, values)
    tools.event_register(tools.CREATION_EVENTS, Framework.ghost_manager.onGhostEntityCreated, ghost_filter)
end

Event.register(defines.events.on_object_destroyed, FrameworkGhostManager.onObjectDestroyed)

return FrameworkGhostManager
