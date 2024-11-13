---@meta
------------------------------------------------------------------------
-- Manage all the attached entities and ghosts
------------------------------------------------------------------------

local Area = require('stdlib.area.area')
local Position = require('stdlib.area.position')

local const = require('lib.constants')


---@class FiberNetworkAttachedEntities
local AttachedEntities = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the storage for attached entities
function AttachedEntities:init()
    if not storage.attached_entities then
        storage.attached_entities = {} --[[@as AttachedEntity[] ]]
    end
end

--------------------------------------------------------------------------------
-- direct building with cut and paste
--------------------------------------------------------------------------------

---@param entity LuaEntity
---@param player_index integer
---@param tags Tags?
function AttachedEntities:registerEntity(entity, player_index, tags)
    storage.attached_entities[entity.unit_number] = {
        entity = entity,
        player_index = player_index,
        tags = tags,
        -- allow 10 seconds of dwelling time until the actual entity was placed and claimed this entity
        tick = game.tick + 600,
    }
end

--------------------------------------------------------------------------------
-- remove registered ghost/entity
--------------------------------------------------------------------------------

function AttachedEntities:delete(unit_number)
    if storage.attached_entities[unit_number] then
        storage.attached_entities[unit_number].entity.destroy()
        storage.attached_entities[unit_number] = nil
    end
end

--------------------------------------------------------------------------------
-- find related entities
--------------------------------------------------------------------------------

---@param area BoundingBox
---@return AttachedEntity[] attached_entities
function AttachedEntities:findEntitiesInArea(area)
    local entities = {}

    for idx, entity in pairs(storage.attached_entities) do
        local pos = Position.new(entity.entity.position)
        if pos:inside(area) then
            -- if the entity has tags with an iopin_index (therefore represents an IO Pin),
            -- store it under the iopin index value, not its name. The creation code will
            -- pick it up using the index because most pins have the same name.
            if entity.tags and entity.tags.iopin_index then
                entities[entity.tags.iopin_index] = entity
            else
                entities[entity.entity.name] = entity
            end
            storage.attached_entities[idx] = nil
        end
    end

    return entities
end

--------------------------------------------------------------------------------
-- ticker
--------------------------------------------------------------------------------

function AttachedEntities:tick()
    -- deal with placed entities. that is simple because
    -- the tick time is already set and if no actual oc is
    -- constructed (e.g. because it collided with water while the IO pin did not),
    -- it can simply be removed.
    for id, attached_entity in pairs(storage.attached_entities) do
        if attached_entity.tick < game.tick then
            self:delete(id)
        end
    end

    -- find all placed OC ghosts which may be lingering because e.g. material shortage
    for _, attached_entity in pairs(storage.ghost_entities) do
        if attached_entity.name == const.optical_connector then
            attached_entity.tick = game.tick + 600 -- refresh
            local area = Area.new(attached_entity.entity.selection_box)
            for _, ghost_entity in pairs(storage.ghost_entities) do
                local pos = Position.new(ghost_entity.position)
                if pos:inside(area) then
                    ghost_entity.tick = game.tick + 600 -- refresh
                end
            end
        end
    end

    -- remove stale ghost entities
    for id, attached_entity in pairs(storage.ghost_entities) do
        if attached_entity.tick < game.tick then
            self:delete(id)
        end
    end
end

return AttachedEntities
