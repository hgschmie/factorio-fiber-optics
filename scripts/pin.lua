------------------------------------------------------------------------
-- Pin related code
------------------------------------------------------------------------
assert(script)

-- load extended math lib
local math = require('stdlib.utils.math')
local table = require('stdlib.utils.table')

local const = require('lib.constants')

-- IO Pin sprite positions relative to the main entity
-- see sprite_positions.txt
-- X offset is along orientation of the main entity
-- Y offset is "previous direction" of the main entity (e.g. for "North", this is "West")
local PIN_POSITIONS = {
    { -42, -41 }, { -22, -29 }, { 3, -50 }, { 25, -29 },
    { 48,  -41 }, { 35, -14 }, { 55, 3 }, { 35, 21 },
    { 48,  47 }, { 25, 31 }, { 3, 53 }, { -22, 31 },
    { -42, 47 }, { -30, 21 }, { -50, 3 }, { -30, -14 },
}

for _, pos in pairs(PIN_POSITIONS) do
    pos.x = pos[1] / 64
    pos.y = pos[2] / 64
end

---@class fo.Pin
---@field MAX_PIN_COUNT integer
local Pins = {
    MAX_PIN_COUNT = #PIN_POSITIONS,
}

------------------------------------------------------------------------
-- attribute getters/setters
------------------------------------------------------------------------

---@param entity_id integer
---@param idx integer
function Pins:addPin(entity_id, idx)
    assert(idx)
    local fo_storage = This.storage()

    if (entity_id and fo_storage.iopins[entity_id]) then
        Framework.logger:logf('[BUG] Overwriting existing iopin %d', entity_id)
    else
        fo_storage.iopin_count = fo_storage.iopin_count + 1
    end

    fo_storage.iopins[entity_id] = idx
end

---@param entity_id integer
function Pins:deletePin(entity_id)
    local fo_storage = This.storage()
    if (entity_id and fo_storage.iopins[entity_id]) then
        fo_storage.iopins[entity_id] = nil
        fo_storage.iopin_count = fo_storage.iopin_count - 1
    end

    if fo_storage.iopin_count < 0 then
        fo_storage.iopin_count = table_size(fo_storage.iopins)
        Framework.logger:logf('[BUG] Fiber Optics IO pin count got negative, size is now: %d', fo_storage.iopin_count)
    end
end

function Pins:findPin(entity_id)
    return This.storage().iopins[entity_id]
end

---@class fo.PinCreateParams
---@field main LuaEntity
---@field idx integer
---@field pos MapPosition

---@param cfg fo.PinCreateParams
function Pins:create(cfg)
    assert(cfg.main and cfg.main.valid)
    assert(cfg.idx > 0 and cfg.idx <= self.MAX_PIN_COUNT)

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

    self:adopt(pin_entity, cfg.idx)

    return pin_entity
end

---@param pin_entity LuaEntity
---@param idx integer
function Pins:adopt(pin_entity, idx)

    pin_entity.minable = false
    pin_entity.destructible = false
    pin_entity.operable = true

    self:addPin(pin_entity.unit_number, idx)

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
    local idx = (cfg.reverse and (self.MAX_PIN_COUNT + 2 - cfg.idx) or cfg.idx)
    idx = math.one_mod(idx + cfg.direction, self.MAX_PIN_COUNT)

    local pin_position = PIN_POSITIONS[idx]
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
        iopin_index = iopin_idx,
    }
end

local IOPIN_CAPTION = const:locale('iopin_caption')

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

    local iopin_idx = self:findPin(entity.unit_number)
    if not iopin_idx then return end

    -- local wire_connectors = entity.get_wire_connectors(true)

    -- local red_count = get_connection_count(wire_connectors[defines.wire_connector_id.circuit_red])
    -- local green_count = get_connection_count(wire_connectors[defines.wire_connector_id.circuit_green])

    local color_index = 1
    -- -- > 1 b/c every pin is connected to a network
    -- color_index = color_index + ((red_count > 0) and 1 or 0)
    -- color_index = color_index + ((green_count > 0) and 2 or 0)

    Framework.render:renderText(player_index, {
        text = { IOPIN_CAPTION, iopin_idx },
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
