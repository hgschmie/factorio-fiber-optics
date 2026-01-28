------------------------------------------------------------------------
-- Fiber Optics main management code
------------------------------------------------------------------------
assert(script)

local Direction = require('stdlib.area.direction')
local Position = require('stdlib.area.position')

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
        Framework.logger:logf('Fiber Optics Connector count got negative (bug), size is now: %d', fo_storage.fo_count)
    end
end

------------------------------------------------------------------------
-- create/destroy
------------------------------------------------------------------------


local V_FLIP_DIRECTION = {
    [defines.direction.north] = defines.direction.west, -- -4
    [defines.direction.east] = defines.direction.south, -- +4
    [defines.direction.south] = defines.direction.east, -- -4
    [defines.direction.west] = defines.direction.north, -- +4
}

local H_FLIP_DIRECTION = {
    [defines.direction.north] = defines.direction.east, -- +4
    [defines.direction.east] = defines.direction.north, -- -4
    [defines.direction.south] = defines.direction.west, -- +4
    [defines.direction.west] = defines.direction.south, -- -4
}

---@param direction defines.direction
---@return boolean
local function is_vertical(direction)
    return direction == defines.direction.north or direction == defines.direction.south
end

---@param direction defines.direction
---@return boolean
local function is_horizontal(direction)
    return direction == defines.direction.west or direction == defines.direction.east
end


---@param direction defines.direction
---@param h_flipped boolean
---@param v_flipped boolean
---@return defines.direction direction
---@return boolean reverse
local function compute_flip(direction, h_flipped, v_flipped)
    local reverse = h_flipped ~= v_flipped

    if h_flipped then
        direction = is_horizontal(direction) and Direction.previous(direction) or Direction.next(direction)
    end
    if v_flipped then
        direction = is_vertical(direction) and Direction.previous(direction) or Direction.next(direction)
    end

    return direction, reverse
end

---@param direction defines.direction
---@param h_flipped boolean
---@param v_flipped boolean
---@return defines.direction direction
---@return boolean reverse
local function compute_rflip(direction, h_flipped, v_flipped)
    if h_flipped == v_flipped then return direction, false end

    return Direction.next(direction), true
end

---@class fo.FoCreateParams
---@field main LuaEntity
---@field attached_entities fo.AttachedEntity[]?
---@field attached_ghosts table<any, framework.ghost_manager.AttachedEntity>
---@field tags Tags?
---@field h_flipped boolean?
---@field v_flipped boolean?

--- Creates a new entity from the main entity, registers with the mod and configures it.
---@param cfg fo.FoCreateParams
---@return fo.FiberOptics? fo_entity
function FiberOptics:create(cfg)
    if not (cfg.main and cfg.main.valid) then return nil end


    local direction, reverse = compute_rflip(cfg.main.direction, cfg.h_flipped, cfg.v_flipped)
    ---@type fo.FiberOptics
    local fo_entity = {
        main = cfg.main,
        direction = cfg.main.direction,
        reverse = reverse,
        h_flipped = cfg.h_flipped or false,
        v_flipped = cfg.v_flipped or false,
        iopin = {},
    }

    cfg.main.direction = direction

    for i = 1, This.pin.MAX_PIN_COUNT do
        local pin_entity
        if cfg.attached_entities and cfg.attached_entities[i] and cfg.attached_entities[i].entity and cfg.attached_entities[i].entity.valid then
            pin_entity = cfg.attached_entities[i].entity
            local dst_pos = This.pin:position {
                main = fo_entity.main,
                idx = i,
                reverse = fo_entity.reverse,
                direction = fo_entity.main.direction
            }
            assert(pin_entity.teleport(dst_pos))

            This.pin:adopt(pin_entity, i)
            cfg.attached_entities[i] = nil

        elseif cfg.attached_ghosts and cfg.attached_ghosts[i] and cfg.attached_ghosts[i].entity and cfg.attached_ghosts[i].entity.valid then
            -- adopt any ghost, revive it and position it (flipping may move the pins around a bit)
            local res, entity = cfg.attached_ghosts[i].entity.silent_revive()
            if res then
                pin_entity = assert(entity)
                local dst_pos = This.pin:position {
                    main = fo_entity.main,
                    idx = i,
                    reverse = fo_entity.reverse,
                    direction = fo_entity.main.direction
                }
                assert(pin_entity.teleport(dst_pos))

                This.pin:adopt(pin_entity, i)
                cfg.attached_ghosts[i] = nil
            end
        end

        if not pin_entity then
            pin_entity = This.pin:create {
                main = cfg.main,
                idx = i,
                reverse = reverse,
            }
        end

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
---@param previous_direction defines.direction
---@param player LuaPlayer
---@return boolean True if an entity was rotated
function FiberOptics:rotate(entity_id, previous_direction, player)
    if not entity_id then return false end

    local fo_entity = self:getEntity(entity_id)
    if not fo_entity then return false end

    local direction = (fo_entity.direction + (fo_entity.main.direction - previous_direction)) % table_size(defines.direction)
    local move_list = {}

    -- check that each iopin can be moved to the new position. If any pin can
    -- not be moved, the whole move is vetoed
    for i, io_pin in pairs(fo_entity.iopin) do
        local dst_pos = This.pin:position {
            main = fo_entity.main,
            idx = i,
            reverse = fo_entity.reverse,
            direction = fo_entity.main.direction,
        }
        local iopin_pos = This.pin:check_move(io_pin, dst_pos, player)
        if iopin_pos then
            move_list[io_pin.unit_number] = iopin_pos
        else
            fo_entity.main.direction = previous_direction
            return false
        end
    end

    fo_entity.direction = direction

    for _, io_pin in pairs(fo_entity.iopin) do
        io_pin.teleport(move_list[io_pin.unit_number])
    end

    return true
end

---@param entity_id integer
---@param is_horizontal boolean
---@param player LuaPlayer
---@return boolean True if an entity was flipped
function FiberOptics:flip(entity_id, is_horizontal, player)
    if not entity_id then return false end

    local fo_entity = self:getEntity(entity_id)
    if not fo_entity then return false end

    local h_flipped = fo_entity.h_flipped
    local v_flipped = fo_entity.v_flipped

    if is_horizontal then
        h_flipped = not h_flipped
    else
        v_flipped = not v_flipped
    end

    local main_direction, reverse = compute_flip(fo_entity.direction, h_flipped, v_flipped)

    local move_list = {}

    -- check that each iopin can be moved to the new position. If any pin can
    -- not be moved, the whole move is vetoed
    for i, io_pin in pairs(fo_entity.iopin) do
        local dst_pos = This.pin:position {
            main = fo_entity.main,
            idx = i,
            reverse = reverse,
            direction = main_direction,
        }
        local iopin_pos = This.pin:check_move(io_pin, dst_pos, player)
        if iopin_pos then
            move_list[io_pin.unit_number] = iopin_pos
        else
            return false
        end
    end

    fo_entity.h_flipped = h_flipped
    fo_entity.v_flipped = v_flipped
    fo_entity.reverse = reverse
    fo_entity.main.direction = main_direction

    for _, io_pin in pairs(fo_entity.iopin) do
        io_pin.teleport(move_list[io_pin.unit_number])
    end

    return true
end

---@param entity_id integer
---@param start_pos MapPosition
---@param player LuaPlayer
---@return boolean moved True if the entity was moved
function FiberOptics:move(entity_id, start_pos, player)
    if not entity_id then return false end

    local fo_entity = self:getEntity(entity_id)
    if not fo_entity then return false end

    local diff = Position(fo_entity.main.position):subtract(Position(start_pos))

    local move_list = {}

    -- check that each iopin can be moved to the new position. If any pin can
    -- not be moved, the whole move is vetoed
    for _, io_pin in pairs(fo_entity.iopin) do
        local dst_pos = Position(io_pin.position):add(diff)
        local iopin_pos = This.pin:check_move(io_pin, dst_pos, player)
        if iopin_pos then
            move_list[io_pin.unit_number] = iopin_pos
        else
            fo_entity.main.teleport(start_pos)
            return false
        end
    end

    for _, io_pin in pairs(fo_entity.iopin) do
        io_pin.teleport(assert(move_list[io_pin.unit_number]))
    end

    return true
end

---@param fo_entity fo.FiberOptics
function FiberOptics:repositionPins(fo_entity)
    if not (fo_entity and fo_entity.main.valid) then return end

    for i = 1, This.pin.MAX_PIN_COUNT do
        local pos = This.pin:position {
            main = fo_entity.main,
            idx = i,
            reverse = fo_entity.reverse,
            direction = fo_entity.main.direction,
        }
        if (fo_entity.iopin[i] and fo_entity.iopin[i].valid) then
            assert(fo_entity.iopin[i].teleport(pos))
        end
    end
end

---@param entity_id integer
---@return table<string, any>?
function FiberOptics:serialize(entity_id)
    local fo_entity = self:getEntity(entity_id)
    if not fo_entity then return end

    return {
        h_flipped = fo_entity.h_flipped,
        v_flipped = fo_entity.v_flipped,
    }
end

return FiberOptics
