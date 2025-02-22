---@meta
------------------------------------------------------------------------
-- Manage all the attached entities and ghosts
------------------------------------------------------------------------
assert(script)

local Area = require('stdlib.area.area')
local Position = require('stdlib.area.position')

local const = require('lib.constants')

local LINGER_TIME = 600

---@class fiber_optics.State
---@field entities fiber_optics.AttachedEntity[]

---@class fiber_optics.AttachedEntitiesManager
local AttachedEntities = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the storage for attached entities
function AttachedEntities:init()
    storage.attached_entities = storage.attached_entities or {}
    storage.attached_entities.entities = storage.attached_entities.entities or {}
end

---@return fiber_optics.State
function AttachedEntities:state()
    return assert(storage.attached_entities)
end

--------------------------------------------------------------------------------
-- direct building with cut and paste
--------------------------------------------------------------------------------

---@param entity LuaEntity
---@param player_index integer
---@param tags Tags?
function AttachedEntities:registerEntity(entity, player_index, tags)
    local state = self:state()

    state.entities[entity.unit_number] = {
        entity = entity,
        player_index = player_index,
        tags = tags,
        -- allow 10 seconds of dwelling time until the actual entity was placed and claimed this entity
        tick = game.tick + LINGER_TIME,
    }
end

--------------------------------------------------------------------------------
-- remove attached entity
--------------------------------------------------------------------------------

function AttachedEntities:deleteEntity(unit_number)
    local state = self:state()
    if not state.entities[unit_number] then return end

    state.entities[unit_number].entity.destroy()
    state.entities[unit_number] = nil
end

--------------------------------------------------------------------------------
-- find related entities
--------------------------------------------------------------------------------

---@param area BoundingBox
---@return fiber_optics.AttachedEntity[] attached_entities
function AttachedEntities:findEntitiesInArea(area)
    local entities = {}

    local state = self:state()

    for idx, entity in pairs(state.entities) do
        if entity.entity and entity.entity.valid then
            local pos = Position.new(entity.entity.position)
            if pos:inside(area) then
                -- if the entity has tags with an iopin_index (therefore represents an IO Pin),
                -- store it under the iopin index value, not its name. The creation code will
                -- pick it up using the index because most pins have the same name.
                local iopin_index = entity.tags and entity.tags[const.iopin_index_tag]

                if iopin_index then
                    entities[iopin_index] = entity
                else
                    entities[entity.entity.name] = entity
                end
                state.entities[idx] = nil
            end
        end
    end

    return entities
end

--------------------------------------------------------------------------------
-- ticker
--------------------------------------------------------------------------------

function AttachedEntities:tick()
    local state = self:state()

    -- deal with placed entities. that is simple because
    -- the tick time is already set and if no actual oc is
    -- constructed (e.g. because it collided with water while the IO pin did not),
    -- it can simply be removed.
    for id, attached_entity in pairs(state.entities) do
        if not(attached_entity.entity and attached_entity.entity.valid) then
            self:deleteEntity(id)
        elseif attached_entity.tick < game.tick then
            self:deleteEntity(id)
        end
    end
end

--------------------------------------------------------------------------------
-- ghost refresh
--------------------------------------------------------------------------------

--- Called by the ghost manager to ensure that all built entities under an oc ghost
--- may disappear again if the ghost is never built.
---
---@param entity framework.ghost_manager.AttachedEntity
---@param all_entities framework.ghost_manager.AttachedEntity[]
---@return table<integer, framework.ghost_manager.AttachedEntity>
function AttachedEntities.ghostRefresh(entity, all_entities)
    local entities = {
        [entity.entity.unit_number] = entity
    }

    -- find all placed OC ghosts which may be lingering because e.g. material shortage
    -- all oc ghosts (and the oc itself) are refreshed so that they do not disappear if
    -- no robot is around.
    local area = Area.new(entity.entity.selection_box)
    for _, ghost_entity in pairs(all_entities) do
        if (ghost_entity.entity and ghost_entity.entity.valid) then
            local pos = Position.new(ghost_entity.entity.position)
            if pos:inside(area) then
                entities[ghost_entity.entity.unit_number] = ghost_entity
            end
        end
    end

    return entities
end

return AttachedEntities
