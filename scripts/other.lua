------------------------------------------------------------------------
-- Manage all the attached entities and ghosts
------------------------------------------------------------------------

assert(script)

local Area = require('stdlib.area.area')
local Position = require('stdlib.area.position')

local helpers = require('scripts.helpers')

local LINGER_TIME = 600

---@class fo.Other
local Other = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- direct building with cut and paste
--------------------------------------------------------------------------------

---@param entity LuaEntity
---@param tags Tags?
function Other:registerEntity(entity, tags)
    local state = This.storage()

    state.attached_entities[entity.unit_number] = {
        entity = entity,
        tags = tags,
        -- allow 10 seconds of dwelling time until the actual entity was placed and claimed this entity
        tick = game.tick + LINGER_TIME,
    }
end

--------------------------------------------------------------------------------
-- remove attached entity
--------------------------------------------------------------------------------

function Other:deleteEntity(unit_number)
    local state = This.storage()

    ---@type fo.AttachedEntity?
    local attached_entity = state.attached_entities[unit_number]
    if not attached_entity then return end

    if (attached_entity.entity and attached_entity.entity.valid) then
        attached_entity.entity.destroy()
    end

    state.attached_entities[unit_number] = nil
end

--------------------------------------------------------------------------------
-- find related entities
--------------------------------------------------------------------------------

---@param area BoundingBox
---@return fo.AttachedEntity[] attached_entities
function Other:findEntitiesInArea(area)
    local entities = {}

    local state = This.storage()

    for idx, entity in pairs(state.attached_entities) do
        if entity.entity and entity.entity.valid then
            local pos = Position.new(entity.entity.position)
            if pos:inside(area) then
                -- if the entity has tags with an iopin_index (therefore represents an IO Pin),
                -- store it under the iopin index value, not its name. The creation code will
                -- pick it up using the index because most pins have the same name.
                local iopin_index = entity.tags and entity.tags['iopin_index']

                if iopin_index then
                    if not entities[iopin_index] then
                        entities[iopin_index] = entity
                        state.attached_entities[idx] = nil
                    end
                elseif not entities[entity.entity.name] then
                    entities[entity.entity.name] = entity
                    state.attached_entities[idx] = nil
                end
            end
        end
    end

    return entities
end

--------------------------------------------------------------------------------
-- ghost refresh
--------------------------------------------------------------------------------

--- Called by the ghost manager to ensure that all built entities under an fo ghost
--- may disappear again if the ghost is never built.
---
---@param attached_entity framework.ghost_manager.AttachedEntity
---@param all_entities framework.ghost_manager.AttachedEntity[]
---@return table<integer, framework.ghost_manager.AttachedEntity>
function Other:ghostRefresh(attached_entity, all_entities)
    local state = This.storage()

    local entities = {
        [attached_entity.entity.unit_number] = attached_entity
    }

    -- find all placed FO ghosts or attached entities which may be lingering because e.g.
    -- material shortage
    -- all fo ghosts, attached entities (and the fo itself) are refreshed so that they do
    -- not disappear if no robot is around.
    local area = Area.new(attached_entity.entity.selection_box)
    local found_entities = attached_entity.entity.surface.find_entities(area)

    for _, found_entity in pairs(found_entities) do
        if found_entity and found_entity.valid then
            local id = assert(found_entity.unit_number)
            -- refresh actual entities
            if state.attached_entities[id] then
                state.attached_entities[id].tick = game.tick + LINGER_TIME
                -- refresh ghosts
            elseif all_entities[id] then
                entities[id] = all_entities[id]
            end
        end
    end

    return entities
end

--------------------------------------------------------------------------------
-- ticker
--------------------------------------------------------------------------------

function Other:tick()
    local ticker = helpers:getTicker('attached_entities')

    local interval = 60

    local state = This.storage()
    local entity_count = table_size(state.attached_entities)
    if entity_count == 0 then return end
    local ticks_per_entity = math.max(1, math.floor(interval / entity_count)) -- at least one

    if ticker.last_tick + ticks_per_entity > game.tick then return end

    local process_count = math.ceil(entity_count / interval)
    local index = ticker.last_tick_index

    if not state.attached_entities[index] then index = nil end

    if process_count > 0 then
        repeat
            -- deal with placed entities. that is simple because
            -- the tick time is already set and if no actual fo is
            -- constructed (e.g. because it collided with water while the entity did not),
            -- it can simply be removed.
            local attached_entity
            index, attached_entity = next(state.attached_entities, index)
            if not index then index, attached_entity = next(state.attached_entities, index) end

            if attached_entity then
                if not (attached_entity.entity and attached_entity.entity.valid) then
                    self:deleteEntity(index)
                elseif attached_entity.tick < game.tick then
                    self:deleteEntity(index)
                end
                process_count = process_count - 1
            end
        until process_count == 0 or not index
    else
        index = nil
    end

    ticker.last_tick_index = index
    ticker.last_tick = game.tick
end

return Other
