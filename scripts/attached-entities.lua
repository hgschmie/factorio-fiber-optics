---@meta
------------------------------------------------------------------------
-- Manage all the attached entities and ghosts
------------------------------------------------------------------------

local Position = require('__stdlib__/stdlib/area/position')


---@class FiberNetworkAttachedEntities
local AttachedEntities = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the storage for ghosts and entities
function AttachedEntities:init()
    if not global.ghost_entities then
        global.ghost_entities = {} --[[@as AttachedEntity[] ]]
    end

    if not global.attached_entities then
        global.attached_entities = {} --[[@as AttachedEntity[] ]]
    end
end

--------------------------------------------------------------------------------
-- manage ghost building (robot building)
--------------------------------------------------------------------------------

---@param entity LuaEntity
---@param player_index integer
function AttachedEntities:registerGhost(entity, player_index)
    -- if an entity ghost was placed, register information to configure
    -- an entity if it is placed over the ghost

    global.ghost_entities[entity.unit_number] = {
        -- maintain entity reference for attached entity ghosts
        entity = entity,
        -- but for matching ghost replacement, all the values
        -- must be kept because the entity is invalid when it
        -- replaces the ghost
        name = entity.ghost_name,
        position = entity.position,
        orientation = entity.orientation,
        tags = entity.tags,
        player_index = player_index
    }
end

--------------------------------------------------------------------------------
-- direct building with cut and paste
--------------------------------------------------------------------------------

---@param entity LuaEntity
---@param player_index integer
function AttachedEntities:registerEntity(entity, player_index)
    global.attached_entities[entity.unit_number] = {
        entity = entity,
        player_index = player_index
    }
end

--------------------------------------------------------------------------------
-- remove registered ghost/entity
--------------------------------------------------------------------------------

function AttachedEntities:delete(unit_number)
    if global.ghost_entities[unit_number] then
        global.ghost_entities[unit_number].entity.destroy()
        global.ghost_entities[unit_number] = nil
    end

    if global.attached_entities[unit_number] then
        global.attached_entities[unit_number].entity.destroy()
        global.attached_entities[unit_number] = nil
    end
end

--------------------------------------------------------------------------------
-- find related ghosts
--------------------------------------------------------------------------------

---@param entity LuaEntity
---@return AttachedEntity? attached_entity
function AttachedEntities:findMatchingGhost(entity)
    -- find a ghost that matches the entity
    for idx, ghost in pairs(global.ghost_entities) do
        -- it provides the tags and player_index for robot builds
        if entity.name == ghost.name
            and entity.position.x == ghost.position.x
            and entity.position.y == ghost.position.y
            and entity.orientation == ghost.orientation then
            global.ghost_entities[idx] = nil
            return ghost
        end
    end
    return nil
end

---@param area BoundingBox
---@return AttachedEntity[] attached_entities
function AttachedEntities:findGhostsInArea(area)
    local ghosts = {}
    for idx, ghost in pairs(global.ghost_entities) do
        local pos = Position.new(ghost.position)
        if pos:inside(area) then
            ghosts[ghost.name] = ghost
            global.ghost_entities[idx] = nil
        end
    end

    return ghosts
end

--------------------------------------------------------------------------------
-- find related entities
--------------------------------------------------------------------------------

---@param area BoundingBox
---@return AttachedEntity[] attached_entities
function AttachedEntities:findEntitiesInArea(area)
    local entities = {}

    for idx, entity in pairs(global.attached_entities) do
        local pos = Position.new(entity.entity.position)
        if pos:inside(area) then
            entities[entity.entity.name] = entity
            global.attached_entities[idx] = nil
        end
    end

    return entities
end

return AttachedEntities
