------------------------------------------------------------------------
-- Fiber Optics main management code
------------------------------------------------------------------------
assert(script)

------------------------------------------------------------------------

---@class fo.FiberOptics
local FiberOptics = {
}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global optical connector data structure.
function FiberOptics:init()
    if storage.fo_data then return end

    ---@type fo.Storage
    storage.fo_data = {
        fo = {},
        count = 0,
    }
end

------------------------------------------------------------------------
-- attribute getters/setters
------------------------------------------------------------------------

---@param entity_id integer main unit number (== entity id)
---@return fo.FiberOptics? fo_entity
function FiberOptics:getEntity(entity_id)
    if not entity_id then return nil end
    return storage.fo_data.fo[entity_id]
end

---@param entity_id integer The unit_number of the primary
---@param fo_entity fo.FiberOptics?
function FiberOptics:setEntity(entity_id, fo_entity)
    if (fo_entity and storage.fo_data.fo[entity_id]) then
        Framework.logger:logf('[BUG] Overwriting existing fo_entity for unit %d', entity_id)
    end

    storage.fo_data.fo[entity_id] = fo_entity
    storage.fo_data.count = storage.fo_data.count + (fo_entity and 1 or -1)

    if storage.fo_data.count < 0 then
        storage.fo_data.count = table_size(storage.fo_data.fo)
        Framework.logger:logf('Fiber Optics Connector count got negative (bug), size is now: %d', storage.fo_data.count)
    end
end

------------------------------------------------------------------------
-- create/destroy
------------------------------------------------------------------------

---@class fo.CreateParameters
---@field main LuaEntity
---@field tags Tags?

--- Creates a new entity from the main entity, registers with the mod and configures it.
---@param cfg fo.CreateParameters
---@return fo.FiberOptics? fo_entity
function FiberOptics:create(cfg)
    if not (cfg.main and cfg.main.valid) then return nil end

    ---@type fo.FiberOptics
    local fo_entity = {
        main = cfg.main,
    }

    self:setEntity(cfg.main.unit_number, fo_entity)

    return fo_entity
end

---@param entity_id integer
---@return boolean True if an entity was destroyed
function FiberOptics:destroy(entity_id)
    if not entity_id then return false end

    local fo_entity = self:getEntity(entity_id)
    if not fo_entity then return false end

    self:setEntity(entity_id, nil)
    return true
end


return FiberOptics
