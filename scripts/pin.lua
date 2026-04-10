------------------------------------------------------------------------
-- Pin related code
------------------------------------------------------------------------
assert(script)

-- load extended math lib
local math = require('stdlib.utils.math')
local table = require('stdlib.utils.table')

local const = require('lib.constants')

---@class fo.IoPin
---@field index integer
---@field entity_id integer

---@class fo.FoPin
local Pins = {}

------------------------------------------------------------------------
-- attribute getters/setters
------------------------------------------------------------------------

---@param entity_id integer
---@param pin_id integer
---@param idx integer
function Pins:addPin(entity_id, pin_id, idx)
    assert(idx)

    ---@type fo.Storage
    local fo_storage = This.storage()

    if (entity_id and fo_storage.iopins[pin_id]) then
        Framework.logger:logf('[BUG] Overwriting existing iopin %d for entity %d', pin_id, entity_id)
    else
        fo_storage.iopin_count = fo_storage.iopin_count + 1
    end

    fo_storage.iopins[pin_id] = {
        entity_id = entity_id,
        index = idx
    }
end

---@param pin_id integer
function Pins:deletePin(pin_id)
    local fo_storage = This.storage()
    if (pin_id and fo_storage.iopins[pin_id]) then
        fo_storage.iopins[pin_id] = nil
        fo_storage.iopin_count = fo_storage.iopin_count - 1
    end

    if fo_storage.iopin_count < 0 then
        fo_storage.iopin_count = table_size(fo_storage.iopins)
        Framework.logger:logf('[BUG] Fiber Optics IO pin count got negative, size is now: %d', fo_storage.iopin_count)
    end
end

---@param pin_id integer
---@return fo.IoPin?
function Pins:findPin(pin_id)
    return This.storage().iopins[pin_id]
end

---@class fo.PinCreateParams
---@field main LuaEntity
---@field idx integer
---@field pos MapPosition

---@param cfg fo.PinCreateParams
function Pins:create(cfg)
    assert(cfg.main and cfg.main.valid)
    assert(cfg.idx > 0 and cfg.idx <= const.max_pin_count)

    local name = (cfg.idx == 1) and const.pin_one_entity_name or const.pin_entity_name

    local pin_entity = cfg.main.surface.create_entity {
        name = name,
        position = cfg.pos,
        direction = cfg.main.direction,
        force = cfg.main.force,

        create_build_effect_smoke = false,
        spawn_decorations = false,
        move_stuck_players = true,
    }

    assert(pin_entity, ("Could not create entity for '%s'"):format(name))

    self:adopt(cfg.main.unit_number, pin_entity, cfg.idx)

    return pin_entity
end

---@param entity_id integer
---@param pin_entity LuaEntity
---@param idx integer
function Pins:adopt(entity_id, pin_entity, idx)

    pin_entity.minable = false
    pin_entity.destructible = false
    pin_entity.operable = true

    self:addPin(entity_id, pin_entity.unit_number, idx)
end

---@class fo.PinPositionParams
---@field main LuaEntity
---@field direction defines.direction
---@field reverse boolean
---@field idx integer

---@param cfg fo.PinPositionParams
---@return MapPosition
function Pins:position(cfg)
    -- for each rotation, the count for pins needs to start four pins further down (1, 5, 9, 13)
    -- each direction is actually just four more (north, east, south west), so this can just
    -- be added up
    local idx = (cfg.reverse and (const.max_pin_count + 2 - cfg.idx) or cfg.idx)
    idx = math.one_mod(idx + cfg.direction, const.max_pin_count)

    local pin_position = const.pin_positions[idx]
    return {
        x = cfg.main.position.x + pin_position.x,
        y = cfg.main.position.y + pin_position.y,
    }
end

local MSG_WIRES_TOO_LONG = const:locale('wires_too_long')

local IGNORED_FOR_MOVE = table.array_to_dictionary({
    const.fiber_hub_name
}, true)

---@param iopin LuaEntity
---@param dst_pos MapPosition
---@param player LuaPlayer
---@return MapPosition? new_pos New iopin position or nil if it can not be moved.
function Pins:check_move(iopin, dst_pos, player)
    local src_pos = iopin.position

    if not iopin.teleport(dst_pos) then return nil end

    for _, wire_connection in pairs(iopin.get_wire_connectors(true)) do
        for _, target_connection in pairs(wire_connection.connections) do
            if not (IGNORED_FOR_MOVE[wire_connection.owner.name] or IGNORED_FOR_MOVE[target_connection.target.owner.name]) then
                local allowed = wire_connection.can_wire_reach(target_connection.target)

                if not allowed then
                    player.create_local_flying_text {
                        position = iopin.position,
                        text = { MSG_WIRES_TOO_LONG },
                    }

                    -- move back
                    iopin.teleport(src_pos)
                    return nil
                end
            end
        end
    end

    -- move back
    iopin.teleport(src_pos)
    return dst_pos
end

---@param entity_id integer
---@return table<string, any>?
function Pins:serialize(entity_id)
    local iopin_idx = self:findPin(entity_id)
    if not iopin_idx then return end

    return {
        iopin_index = iopin_idx.index,
    }
end

local IOPIN_CAPTION = const:locale('hover_pin_caption')

local IOPIN_COLOR = {
    { 1,   1,   1, },  -- none
    { 1,   0.5, 0.5 }, -- red
    { 0.5, 1,   0.5 }, -- green
    { 1,   1,   0.5 }, -- red and green
}

---@param entity LuaEntity?
---@param player_index integer
function Pins:displayCaption(entity, player_index)
    if not (entity and entity.valid) then return end

    local iopin = self:findPin(entity.unit_number)
    if not iopin then return end

    local text = {"", { IOPIN_CAPTION, iopin.index }}
    local color_index = 1

    local fo_entity = This.fo:getEntity(iopin.entity_id)
    if fo_entity then
        local caption = This.fo:getCaptionForPin(fo_entity, iopin.index)

        color_index = color_index + (caption.red and 1 or 0)
        color_index = color_index + (caption.green and 2 or 0)

        if caption.desc then
            table.insert(text, ': ')
            table.insert(text, caption.desc.title)
        end
    end

    Framework.render:renderText(player_index, {
        text = text,
        surface = entity.surface,
        target = entity,
        color = IOPIN_COLOR[color_index],
        only_in_alt_mode = false,
        alignment = 'center',
        target_offset = { 0, -0.7 },
        use_rich_text = true
    })
end

return Pins
