------------------------------------------------------------------------
-- Fiber Optics main management code
------------------------------------------------------------------------
assert(script)

local Direction = require('stdlib.area.direction')
local Position = require('stdlib.area.position')

local tools = require('framework.tools')

local const = require('lib.constants')
local helpers = require('scripts.helpers')

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

---@class fo.FoInternalEntityCfg
---@field id string
---@field name string
---@field x integer
---@field y integer

---@type fo.FoInternalEntityCfg[]
local INTERNAL_CFG = {
    { id = 'powerpole',  name = const.powerpole_name,       x = 0,   y = 16, },
    { id = 'power',      name = const.power_interface_name, x = 0,   y = 0, },
    { id = 'led_1',      name = const.led_name,             x = -13, y = -1, },
    { id = 'led_2',      name = const.led_name,             x = 13,  y = -1, },
    { id = 'controller', name = const.controller_name,      x = 0,   y = 0, },
}

---@class fo.FoAdoptParams
---@field entity fo.AttachedEntity?
---@field ghost framework.ghost_manager.AttachedEntity?
---@field main LuaEntity
---@field pos MapPosition

---@param cfg fo.FoAdoptParams
---@return LuaEntity?
local function adopt(cfg)
    local internal_entity

    if cfg.entity then
        internal_entity = cfg.entity.entity
        if internal_entity and internal_entity.valid then
            assert(internal_entity.teleport(cfg.pos))
        end

        if cfg.ghost then
            local ghost_entity = cfg.ghost.entity
            if ghost_entity and ghost_entity.valid then
                ghost_entity.destroy()
            end
        end
    elseif cfg.ghost then
        local ghost_entity = cfg.ghost.entity
        if ghost_entity and ghost_entity.valid then
            -- adopt any ghost, revive it and position it (flipping may move the pins around a bit)
            local res, entity = ghost_entity.silent_revive()
            if res then
                internal_entity = assert(entity)
                assert(internal_entity.teleport(cfg.pos))
            end
        end
    end

    return internal_entity
end

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
    assert(cfg.attached_entities)
    assert(cfg.attached_ghosts)

    local direction, reverse = compute_rflip(cfg.main.direction, cfg.h_flipped, cfg.v_flipped)
    ---@type fo.FiberOptics
    local fo_entity = {
        main = cfg.main,
        direction = cfg.main.direction,
        reverse = reverse,
        h_flipped = cfg.h_flipped or false,
        v_flipped = cfg.v_flipped or false,
        iopin = {},
        internal = {},
        networks = {},
        state = {
            connected_strands = {},
        },
    }

    cfg.main.direction = direction

    -- add io pins
    for i = 1, This.pin.MAX_PIN_COUNT do
        local pos = This.pin:position {
            main = fo_entity.main,
            idx = i,
            reverse = fo_entity.reverse,
            direction = fo_entity.main.direction
        }

        local entity = adopt {
            main = fo_entity.main,
            index = i,
            entity = cfg.attached_entities[i],
            ghost = cfg.attached_ghosts[i],
            pos = pos,
        }

        if entity then
            This.pin:adopt(entity, i)
        else
            entity = This.pin:create {
                main = fo_entity.main,
                idx = i,
                pos = pos,
            }
        end

        fo_entity.iopin[i] = entity
    end

    -- add remaining innards
    for _, internal_cfg in pairs(INTERNAL_CFG) do
        local pos = {
            x = fo_entity.main.position.x + internal_cfg.x / 64,
            y = fo_entity.main.position.y + internal_cfg.y / 64,
        }

        local entity = adopt {
            main = fo_entity.main,
            entity = cfg.attached_entities[internal_cfg.name],
            ghost = cfg.attached_ghosts[internal_cfg.name],
            name = internal_cfg.name,
            pos = pos,
        }

        if not entity then
            entity = fo_entity.main.surface.create_entity {
                name = internal_cfg.name,
                position = pos,
                direction = fo_entity.main.direction,
                force = fo_entity.main.force,

                create_build_effect_smoke = false,
                spawn_decorations = false,
                move_stuck_players = true,
            }
        end

        fo_entity.internal[internal_cfg.id] = entity
    end

    -- configure entities

    -- power switch
    local pp_control = assert(fo_entity.internal.powerpole.get_or_create_control_behavior()) --[[@as LuaGenericOnOffControlBehavior ]]
    pp_control.connect_to_logistic_network = false

    local sl1_control = assert(fo_entity.internal.led_1.get_or_create_control_behavior()) --[[@as LuaLampControlBehavior]]
    sl1_control.circuit_enable_disable = true
    sl1_control.use_colors = false
    sl1_control.circuit_condition = { comparator = '=', first_signal = { type = 'virtual', name = 'signal-1', quality = 'normal', }, constant = 1, } --[[@as CircuitConditionDefinition ]]

    local sl2_control = assert(fo_entity.internal.led_2.get_or_create_control_behavior()) --[[@as LuaLampControlBehavior]]
    sl2_control.circuit_enable_disable = true
    sl1_control.use_colors = false
    sl2_control.circuit_condition = { comparator = '=', first_signal = { type = 'virtual', name = 'signal-2', quality = 'normal', }, constant = 1, } --[[@as CircuitConditionDefinition ]]

    local sc_control = assert(fo_entity.internal.controller.get_or_create_control_behavior()) --[[@as LuaConstantCombinatorControlBehavior]]
    if sc_control.sections_count < 1 then sc_control.add_section() end
    local sc_section = sc_control.sections[1]
    sc_section.filters = {
        { value = { type = 'virtual', name = 'signal-1', quality = 'normal' }, min = 0, },
        { value = { type = 'virtual', name = 'signal-2', quality = 'normal' }, min = 0, },
    }

    -- wire up controller and LEDs

    local controller_connector = assert(fo_entity.internal.controller.get_wire_connector(defines.wire_connector_id.circuit_red, true))
    local led1_connector = assert(fo_entity.internal.led_1.get_wire_connector(defines.wire_connector_id.circuit_red, true))
    local led2_connector = assert(fo_entity.internal.led_2.get_wire_connector(defines.wire_connector_id.circuit_red, true))
    controller_connector.connect_to(led1_connector, false, defines.wire_origin.script)
    controller_connector.connect_to(led2_connector, false, defines.wire_origin.script)

    self:setEntity(cfg.main.unit_number, fo_entity)

    return fo_entity
end

---@param entity_id integer
---@return boolean True if an entity was destroyed
function FiberOptics:destroy(entity_id)
    if not entity_id then return false end

    local fo_entity = self:getEntity(entity_id)
    if not fo_entity then return false end

    -- delete iopins
    for _, pin in pairs(fo_entity.iopin) do
        if (pin and pin.valid) then
            This.pin:deletePin(pin.unit_number)
            pin.destroy()
        end
    end

    -- delete internal entities
    for _, internal_entity in pairs(fo_entity.internal) do
        if internal_entity and internal_entity.valid then internal_entity.destroy() end
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
---@param mode boolean True is horizontal, false is vertical
---@param player LuaPlayer
---@return boolean True if an entity was flipped
function FiberOptics:flip(entity_id, mode, player)
    if not entity_id then return false end

    local fo_entity = self:getEntity(entity_id)
    if not fo_entity then return false end

    local h_flipped = fo_entity.h_flipped
    local v_flipped = fo_entity.v_flipped

    if mode then
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

    -- check power pole
    local powerpole = fo_entity.internal.powerpole
    local dst_pos = Position(powerpole.position):add(diff)
    local pp_pos = This.pin:check_move(powerpole, dst_pos, player)
    if not pp_pos then
        fo_entity.main.teleport(start_pos)
        return false
    end

    -- now move sub-entities

    for _, io_pin in pairs(fo_entity.iopin) do
        io_pin.teleport(assert(move_list[io_pin.unit_number]))
    end

    -- move internal entities
    for _, internal_entity in pairs(fo_entity.internal) do
        internal_entity.teleport(Position(internal_entity.position):add(diff))
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

---@param entity_id integer
---@param context table<string, any>
function FiberOptics:register_blueprint_context(entity_id, context)
    context.iopin_index = context.iopin_index or {}

    local fo_entity = self:getEntity(entity_id)
    if not fo_entity then return end

    for iopin_idx, iopin_entity in pairs(fo_entity.iopin) do
        context.iopin_index[iopin_entity.unit_number] = iopin_idx
    end
end

---@param power_pole LuaEntity
---@return table<integer, integer> network_map
local function get_connected_networks(power_pole)
    local result = {}
    if not (power_pole and power_pole.valid) then return result end

    local idx = 1
    for _, connector in pairs { defines.wire_connector_id.power_switch_left_copper, defines.wire_connector_id.power_switch_right_copper } do
        local wire_connector = assert(power_pole.get_wire_connector(connector, true))
        local connected = wire_connector.network_id > 0 or wire_connector.real_connection_count > 0 -- https://forums.factorio.com/viewtopic.php?t=127085

        if connected and not result[wire_connector.network_id] then
            result[wire_connector.network_id] = idx
            idx = idx + 1
        end
    end

    return result
end

---@param fo_entity fo.FiberOptics
function FiberOptics:updateEntityStatus(fo_entity)
    assert(fo_entity)
    if not (fo_entity.main and fo_entity.main.valid) then return end

    fo_entity.status = fo_entity.internal.power.status or defines.entity_status.disabled

    -- check connected networks
    local changes = false
    local signals = { 0, 0 }
    local active_signals = 0

    -- if the unit is in red status, disconnect all networks
    local current_networks = ((tools.STATUS_TABLE[fo_entity.status] == 'RED') and {}) or get_connected_networks(fo_entity.internal.powerpole)

    -- disconnect missing networks
    for network_id in pairs(fo_entity.networks) do
        if (not current_networks[network_id]) then
            This.network:disconnectEntity(network_id, fo_entity)
            changes = true
        end
    end

    -- connect new networks
    for network_id, idx in pairs(current_networks) do
        signals[idx] = 1
        active_signals = active_signals + 1
        if not fo_entity.networks[network_id] then
            This.network:connectEntity(network_id, fo_entity)
            changes = true
        end
    end

    if changes then
        local sc_control = assert(fo_entity.internal.controller.get_or_create_control_behavior()) --[[@as LuaConstantCombinatorControlBehavior]]
        if sc_control.sections_count < 1 then sc_control.add_section() end
        local sc_section = sc_control.sections[1]

        local filters = {}

        -- idx is the led to turn on/off, count is 0 for off or 1 for on
        for idx, value in pairs(signals) do
            filters[idx] = {
                value = {
                    type = 'virtual',
                    name = 'signal-' .. tostring(idx),
                    quality = 'normal'
                },
                min = value,
            }
        end

        sc_section.filters = filters

        fo_entity.networks = current_networks
        fo_entity.internal.power.power_usage = (1000 * (1 + active_signals * 8)) / 60.0
    end
end

------------------------------------------------------------------------
-- Ticker
------------------------------------------------------------------------

function FiberOptics:tick()
    local ticker = helpers:getTicker('fiber_optics')
    local interval = Framework.settings:startup_setting(const.settings_names.fo_refresh) or 300

    local fo_entities = This.storage().fo
    local count = table_size(fo_entities)
    if count == 0 then return end

    local ticks_per_entity = math.max(1, math.floor(interval / count)) -- at least one

    if ticker.last_tick + ticks_per_entity > game.tick then return end

    local process_count = math.ceil(count / interval)
    local index = ticker.last_tick_index

    if not fo_entities[index] then index = nil end

    if process_count > 0 then
        repeat
            local fo_entity
            index, fo_entity = next(fo_entities, index)
            if not index then index, fo_entity = next(fo_entities, index) end -- wraparound
            if fo_entity then
                self:updateEntityStatus(fo_entity)
                process_count = process_count - 1
            end
        until process_count == 0 or not index
    else
        index = nil
    end

    ticker.last_tick_index = index
    ticker.last_tick = game.tick
end

return FiberOptics
