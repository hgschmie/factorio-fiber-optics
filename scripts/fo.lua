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

---@type fo.FiberOpticsConfig
local DEFAULT_CONFIG = {
    enabled = true,
    strand_name = 'default',
    connected_pins = {
        [defines.wire_connector_id.circuit_red] = {},
        [defines.wire_connector_id.circuit_green] = {},
    },
    descriptions = {},
}

local RED_RGB = 0xff0000
local GREEN_RGB = 0xff00
local DARK_RGB = 0

---@class fo.Fo
---@field INTERNAL_CFG fo.FoInternalEntityCfg[]
---@field DEFAULT_CONFIG fo.FiberOpticsConfig
local FiberOptics = {
    DEFAULT_CONFIG = DEFAULT_CONFIG,
}

------------------------------------------------------------------------
-- attribute getters/setters
------------------------------------------------------------------------

---@return fo.FiberOptics[] fo_entities
function FiberOptics:getAllEntities()
    return This.storage().fo
end

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
-- manage descriptions
------------------------------------------------------------------------

---@class fo.FoGetSetDescriptionArgs
---@field entity_id integer
---@field desc_type fo.DescType
---@field network_id integer?
---@field index integer
---@field desc fo.Description?


---@param networks integer[]
---@param network_id integer
---@return boolean
local function has_network(networks, network_id)
    if not network_id then return false end
    return networks[1] == network_id or networks[2] == network_id
end

---@param args fo.FoGetSetDescriptionArgs
---@return fo.Description?
function FiberOptics:getDescription(args)
    local fo_entity = self:getEntity(args.entity_id)
    if not fo_entity then return end

    if args.desc_type == 'iopin' then
        return fo_entity.config.descriptions[args.index]
    else
        if not (args.network_id and has_network(fo_entity.state.networks, args.network_id)) then return end
        local strand_name = fo_entity.state.strand_names[args.network_id]

        ---@type fo.FiberStrand
        local fiber_strand = This.network:locateFiberStrand(fo_entity.main, args.network_id, strand_name)
        if not fiber_strand then return end
        return fiber_strand.hubs[args.index].description
    end
end

---@param args fo.FoGetSetDescriptionArgs
function FiberOptics:setDescription(args)
    local fo_entity = self:getEntity(args.entity_id)
    if not fo_entity then return end

    if args.desc_type == 'iopin' then
        fo_entity.config.descriptions[args.index] = args.desc
    else
        if not (args.network_id and has_network(fo_entity.state.networks, args.network_id)) then return end
        local strand_name = fo_entity.state.strand_names[args.network_id]

        ---@type fo.FiberStrand
        local fiber_strand = This.network:locateFiberStrand(fo_entity.main, args.network_id, strand_name)
        if not fiber_strand then return end
        fiber_strand.hubs[args.index].description = args.desc
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
FiberOptics.INTERNAL_CFG = {
    { id = 'powerpole',  name = const.powerpole_name,       x = 0,   y = 16, },
    { id = 'power',      name = const.power_interface_name, x = 0,   y = 0, },
    { id = 'led_1',      name = const.led_name,             x = -15, y = -15, },
    { id = 'led_2',      name = const.led_name,             x = 15,  y = -15, },
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

---@class fo.FoCreateInternalParams
---@field main LuaEntity
---@field name string
---@field pos MapPosition

---@param cfg fo.FoCreateInternalParams
---@return LuaEntity?
function FiberOptics:createInternal(cfg)
    return cfg.main.surface.create_entity {
        name = cfg.name,
        position = cfg.pos,
        direction = cfg.main.direction,
        force = cfg.main.force,

        create_build_effect_smoke = false,
        spawn_decorations = false,
        move_stuck_players = true,
    }
end

---@param fo_entity fo.FiberOptics
---@param index integer
function FiberOptics:configureLed(fo_entity, index)
    local idx = tostring(index)
    local sl_signal = { type = 'virtual', name = 'signal-' .. idx, quality = 'normal', }
    local sl_control = assert(fo_entity.internal['led_' .. idx].get_or_create_control_behavior()) --[[@as LuaLampControlBehavior]]
    sl_control.circuit_enable_disable = true
    sl_control.use_colors = true
    sl_control.color_mode = defines.control_behavior.lamp.color_mode.packed_rgb
    sl_control.rgb_signal = sl_signal
    sl_control.circuit_condition = { comparator = '>', first_signal = sl_signal, constant = 0, } --[[@as CircuitConditionDefinition ]]
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
---@field config fo.FiberOpticsConfig?
---@field h_flipped boolean?
---@field v_flipped boolean?

--- Creates a new entity from the main entity, registers with the mod and configures it.
---@param cfg fo.FoCreateParams
---@return fo.FiberOptics? fo_entity
function FiberOptics:create(cfg)
    if not (cfg.main and cfg.main.valid) then return nil end
    assert(cfg.attached_entities)
    assert(cfg.attached_ghosts)
    local h_flipped = cfg.h_flipped or false
    local v_flipped = cfg.v_flipped or false

    local direction, reverse = compute_rflip(cfg.main.direction, h_flipped, v_flipped)

    local config = cfg.config or self:getDefaultConfig()
    -- fix up that sparse arrays come out of blueprints as table<string, ...>
    for idx = 1, const.max_pin_count do
        if config.descriptions[tostring(idx)] then
            config.descriptions[idx] = config.descriptions[tostring(idx)]
            config.descriptions[tostring(idx)] = nil
        end
    end

    ---@type fo.FiberOptics
    local fo_entity = {
        main = cfg.main,
        direction = cfg.main.direction,
        reverse = reverse,
        h_flipped = h_flipped,
        v_flipped = v_flipped,
        iopin = {},
        internal = {},
        state = {
            strand_names = {},
            networks = {},
        },
        config = config,
    }

    fo_entity.main.direction = direction

    -- add io pins
    for i = 1, const.max_pin_count do
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
    for _, internal_cfg in pairs(self.INTERNAL_CFG) do
        local pos = {
            x = fo_entity.main.position.x + internal_cfg.x / 64,
            y = fo_entity.main.position.y + internal_cfg.y / 64,
        }

        local entity = adopt {
            main = fo_entity.main,
            entity = cfg.attached_entities[internal_cfg.name],
            ghost = cfg.attached_ghosts[internal_cfg.name],
            pos = pos,
        }

        if not entity then
            entity = self:createInternal {
                main = fo_entity.main,
                name = internal_cfg.name,
                pos = pos,
            }
        end

        fo_entity.internal[internal_cfg.id] = entity
    end

    -- configure entities

    fo_entity.internal.powerpole.operable = true

    -- power switch
    local pp_control = assert(fo_entity.internal.powerpole.get_or_create_control_behavior()) --[[@as LuaGenericOnOffControlBehavior ]]
    pp_control.connect_to_logistic_network = false

    self:configureLed(fo_entity, 1)
    self:configureLed(fo_entity, 2)

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
    local power_connector = assert(fo_entity.internal.power.get_wire_connector(defines.wire_connector_id.circuit_red, true))
    controller_connector.connect_to(led1_connector, false, defines.wire_origin.script)
    controller_connector.connect_to(led2_connector, false, defines.wire_origin.script)
    controller_connector.connect_to(power_connector, false, defines.wire_origin.script)

    local power_signal = { type = 'virtual', name = 'signal-E', quality = 'normal', }
    local power_control = assert(fo_entity.internal.power.get_or_create_control_behavior()) --[[@as LuaLampControlBehavior]]
    power_control.circuit_enable_disable = true
    power_control.circuit_condition = { comparator = '>', first_signal = power_signal, constant = 0, } --[[@as CircuitConditionDefinition ]]

    self:setEntity(cfg.main.unit_number, fo_entity)

    return fo_entity
end

function FiberOptics:getDefaultConfig()
    local config = util.copy(DEFAULT_CONFIG)
    for idx = 1, const.max_pin_count do
        config.connected_pins[defines.wire_connector_id.circuit_red][idx] = true
        config.connected_pins[defines.wire_connector_id.circuit_green][idx] = true
    end

    return config
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

    for i = 1, const.max_pin_count do
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
        config = fo_entity.config,
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
---@return integer[] network_map
local function get_connected_networks(power_pole)
    local result = {}
    if not (power_pole and power_pole.valid) then return result end

    for _, connector in pairs { defines.wire_connector_id.power_switch_left_copper, defines.wire_connector_id.power_switch_right_copper } do
        local wire_connector = assert(power_pole.get_wire_connector(connector, true))
        local connected = wire_connector.network_id > 0 or wire_connector.real_connection_count > 0 -- https://forums.factorio.com/viewtopic.php?t=127085

        if connected and not has_network(result, wire_connector.network_id) then
            table.insert(result, wire_connector.network_id)
        end
    end

    return result
end

---@param fo_entity fo.FiberOptics
---@param force_reconnect boolean?
function FiberOptics:updateEntityStatus(fo_entity, force_reconnect)
    assert(fo_entity)
    if not (fo_entity.main and fo_entity.main.valid) then return end

    fo_entity.status = fo_entity.internal.power.status or defines.entity_status.disabled
    -- replace "disabled by control behavior" with "working"
    fo_entity.status = fo_entity.status == defines.entity_status.disabled_by_control_behavior and defines.entity_status.working or fo_entity.status

    -- check connected networks
    local connection_change = true
    local signals = { DARK_RGB, DARK_RGB }
    local active_signals = 0

    local all_networks = get_connected_networks(fo_entity.internal.powerpole)
    -- if the unit is in red status, disconnect all networks
    local connected_networks = ((tools.STATUS_TABLE[fo_entity.status] == 'RED') and {}) or all_networks

    -- disconnect networks if reconnect is forced or the entity is not enabled or
    -- a network is missing from the set of current network or if the current strand name does not match the configured strand name.
    for _, network_id in pairs(fo_entity.state.networks) do
        if (force_reconnect or not (fo_entity.config.enabled
                and has_network(connected_networks, network_id)
                and fo_entity.state.strand_names[network_id]
                and fo_entity.state.strand_names[network_id] == fo_entity.config.strand_name)) then
            This.network:disconnectEntity(network_id, fo_entity)

            connection_change = true
        end
    end

    -- connect new networks if the entity is enabled and the network is not already connected
    -- or if reconnection is forced.
    for idx, network_id in pairs(connected_networks) do
        signals[idx] = fo_entity.config.enabled and GREEN_RGB or RED_RGB
        active_signals = active_signals + 1
        connection_change = This.network:connectEntity(network_id, fo_entity) or connection_change -- do not flip around, otherwise connectEntity is not called

        if fo_entity.state.strand_names[network_id] then
            This.network:updateFiberStrandConnections(network_id, fo_entity)
        end
    end

    local sc_control = assert(fo_entity.internal.controller.get_or_create_control_behavior()) --[[@as LuaConstantCombinatorControlBehavior]]
    if sc_control.sections_count < 1 then sc_control.add_section() end
    local sc_section = sc_control.sections[1]

    local filters = {}

    if connection_change then
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
    end

    filters[3] = {
        value = {
            type = 'virtual',
            name = 'signal-E',
            quality = 'normal',
        },
        -- control through total connected signals, otherwise, if there is no power, it will flip back and forth between "disabled" and "no power"
        min = fo_entity.config.enabled and table_size(all_networks) and 1 or 0,
    }

    sc_section.filters = filters

    fo_entity.state.networks = connected_networks
end

------------------------------------------------------------------------
-- Ticker
------------------------------------------------------------------------

---@param values helper.TickerContext
local function ticker_unit_of_work(_, values)
    local fo_entity = values.index
    This.fo:updateEntityStatus(fo_entity)
end

function FiberOptics:tick()
    local ticker = helpers:getTicker('fiber_optics')
    local interval = Framework.settings:startup_setting(const.settings_names.fo_refresh) or 300

    local fo_entities = self:getAllEntities()
    local count = table_size(fo_entities)
    if count == 0 then return end

    local ticks_per_entity = math.max(1, math.floor(interval / count)) -- at least one

    if ticker.last_tick + ticks_per_entity > game.tick then return end

    local process_count = math.ceil(count / interval)
    local context = { index = ticker.last_tick_index }

    local iterator = helpers.createWorkIterator {
        context = context,
        field_name = 'index',
        iterable = fo_entities,
    }

    while process_count > 0 do
        iterator.process(ticker_unit_of_work)
        process_count = process_count - 1
    end

    ticker.last_tick_index = context.index
    ticker.last_tick = game.tick
end

return FiberOptics
