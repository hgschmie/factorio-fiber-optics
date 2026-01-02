------------------------------------------------------------------------
-- Fiber Optics main management code
------------------------------------------------------------------------
assert(script)

------------------------------------------------------------------------

---@class fo.Fo
local FiberOptics = {}

------------------------------------------------------------------------
-- attribute getters/setters
------------------------------------------------------------------------

---@param entity_id integer main unit number (== entity id)
---@return fo.FiberOptics? fo_entity
function FiberOptics:getEntity(entity_id)
    if not entity_id then return nil end
    return This.storage().fo[entity_id]
end

---@param entity_id integer The unit_number of the primary
---@param fo_entity fo.FiberOptics?
function FiberOptics:setEntity(entity_id, fo_entity)
    local fo_storage = This.storage()

    if (fo_entity and fo_storage.fo[entity_id]) then
        Framework.logger:logf('[BUG] Overwriting existing fo_entity for unit %d', entity_id)
    end

    fo_storage.fo[entity_id] = fo_entity
    fo_storage.fo_count = fo_storage.fo_count + (fo_entity and 1 or -1)

    if fo_storage.fo_count < 0 then
        fo_storage.fo_count = table_size(fo_storage.fo)
        Framework.logger:logf('Fiber Optics Connector count got negative (bug), size is now: %d', fo_storage.count)
    end
end

------------------------------------------------------------------------
-- create/destroy
------------------------------------------------------------------------

local FLIP_DIRECTION = {
    [defines.direction.north] = defines.direction.west,
    [defines.direction.east] = defines.direction.south,
    [defines.direction.south] = defines.direction.east,
    [defines.direction.west] = defines.direction.north,
}

---@class fo.FoCreateParams
---@field main LuaEntity
---@field tags Tags?
---@field flipped boolean

--- Creates a new entity from the main entity, registers with the mod and configures it.
---@param cfg fo.FoCreateParams
---@return fo.FiberOptics? fo_entity
function FiberOptics:create(cfg)
    if not (cfg.main and cfg.main.valid) then return nil end

    ---@type fo.FiberOptics
    local fo_entity = {
        main = cfg.main,
        direction = cfg.flipped and FLIP_DIRECTION[cfg.main.direction] or cfg.main.direction,
        flipped = cfg.flipped,
        iopin = {},
    }

    for i = 1, This.pin.MAX_PIN_COUNT do
        local pin_entity = This.pin:create {
            main = cfg.main,
            idx = i,
        }
        fo_entity.iopin[i] = pin_entity
    end

    self:setEntity(cfg.main.unit_number, fo_entity)

    return fo_entity
end

---@param entity_id integer
---@return boolean True if an entity was destroyed
function FiberOptics:destroy(entity_id)
    if not entity_id then return false end

    local fo_entity = self:getEntity(entity_id)
    if not fo_entity then return false end

    for _, pin in pairs(fo_entity.iopin) do
        if (pin and pin.valid) then
            pin.destroy()
        end
    end

    self:setEntity(entity_id, nil)
    return true
end

---@param entity_id integer
---@return boolean True if an entity was rotated
function FiberOptics:rotate(entity_id)
    if not entity_id then return false end

    local fo_entity = self:getEntity(entity_id)
    if not fo_entity then return false end

    fo_entity.direction = fo_entity.flipped and FLIP_DIRECTION[fo_entity.main.direction] or fo_entity.main.direction

    self:repositionPins(fo_entity)

    return true
end

---@param fo_entity fo.FiberOptics
function FiberOptics:repositionPins(fo_entity)
    if not (fo_entity and fo_entity.main.valid) then return end

    for i = 1, This.pin.MAX_PIN_COUNT do
        local pos = This.pin:position {
            main = fo_entity.main,
            idx = i,
            flipped = fo_entity.flipped,
            direction = fo_entity.direction,
        }
        if (fo_entity.iopin[i] and fo_entity.iopin[i].valid) then
            fo_entity.iopin[i].teleport(pos)
        end
    end
end

return FiberOptics
