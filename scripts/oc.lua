--
-- all the optical connector management code
--

local Is = require('__stdlib__/stdlib/utils/is')

local Util = require('framework.util')

local const = require('lib.constants')

------------------------------------------------------------------------

---@class ModOc
local Oc = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global fico data structure.
function Oc:init()
    if global.oc_data then return end

    ---@class OpticalConnectorData
    ---@field main LuaEntity
    ---@field entities LuaEntity[]
    ---@field status defines.entity_status?
    ---@field ref table<string, LuaEntity>
    ---@field connected_networks table<integer, integer>

    ---@class ModOcData
    ---@field oc OpticalConnectorData[]
    ---@field count integer
    ---@field VERSION integer
    global.oc_data = {
        oc = {},
        count = 0,
        VERSION = const.current_version,
    }
end

------------------------------------------------------------------------
-- attribute getters/setters
------------------------------------------------------------------------

--- Returns the registered total count
---@return integer count The total count of optical connectors
function Oc:totalCount()
    return global.oc_data.count
end

--- Returns data for all optical connectors.
---@return OpticalConnectorData[] entities
function Oc:entities()
    return global.oc_data.oc
end

--- Returns data for a given optical connector
---@param entity_id integer main unit number (== entity id)
---@return OpticalConnectorData? entity
function Oc:entity(entity_id)
    return global.oc_data.oc[entity_id]
end

--- Sets or clears a optical connector entity
---@param entity_id integer The unit_number of the primary
---@param oc_entity OpticalConnectorData?
function Oc:setEntity(entity_id, oc_entity)
    assert((oc_entity ~= nil and global.oc_data.oc[entity_id] == nil)
        or (oc_entity == nil and global.oc_data.oc[entity_id] ~= nil))

    if (oc_entity) then
        assert(Is.Valid(oc_entity.main) and oc_entity.main.unit_number == entity_id)
    end

    global.oc_data.oc[entity_id] = oc_entity
    global.oc_data.count = global.oc_data.count + ((oc_entity and 1) or -1)

    if global.oc_data.count < 0 then
        global.oc_data.count = table_size(global.oc_data.oc)
        Framework.logger:logf('Optical Connector count got negative (bug), size is now: %d', global.oc_data.count)
    end
end

------------------------------------------------------------------------
-- create/destroy
------------------------------------------------------------------------

-- computes io pin position relative to an entity and the iopin index.
local function oc_iopin_position(entity, idx, direction)

    -- find the right direction map, do only "normal" for now (1)
    local direction_id = const.iopin_directions[direction or entity.direction][1]

    -- find the iopin position
    local iopin_id = const.iopin_positions[direction_id][idx]
    local sprite_position = const.sprite_positions[iopin_id]

    return {
        x = entity.position.x + sprite_position[1] / 64,
        y = entity.position.y + sprite_position[2] / 64,
    }
end

---@class OcCreateInternalEntityCfg
---@field entity OpticalConnectorData
---@field name string
---@field x integer?
---@field y integer?
---@field pos MapPosition?
---@field ghost AttachedEntity?
---@field attached AttachedEntity?

local sub_entities = {
    { id = 'power_entity',      name = const.oc_power_interface, },                     -- Power Entity for power consumption
    { id = 'power_pole',        name = const.oc_power_pole, },                          -- Power Pole for power connections
    { id = 'status_led_1',      name = const.oc_led_lamp,        x = -0.2, y = -0.02 }, -- Status Lamp 1
    { id = 'status_led_2',      name = const.oc_led_lamp,        x = 0.2,  y = -0.02 }, -- Status Lamp 2
    { id = 'status_controller', name = const.oc_cc, },                                  -- Status Controller
}

---@param cfg OcCreateInternalEntityCfg
local function create_internal_entity(cfg)
    local oc_entity = cfg.entity
    local main = oc_entity.main

    local x = (cfg.pos and cfg.pos.x) or (main.position.x + (cfg.x or 0))
    local y = (cfg.pos and cfg.pos.y) or (main.position.y + (cfg.y or 0))

    local ghost = cfg.ghost
    local attached = cfg.attached

    ---@type LuaEntity?
    local sub_entity
    if ghost and ghost.entity then
        local collision, entity = ghost.entity.silent_revive()
        sub_entity = entity
    elseif attached and attached.entity then
        sub_entity = attached.entity
    else
        sub_entity = main.surface.create_entity {
            name = cfg.name,
            position = { x = x, y = y },
            direction = main.direction,
            force = main.force,

            create_build_effect_smoke = false,
            spawn_decorations = false,
            move_stuck_players = true,
        }
    end

    assert(sub_entity)

    sub_entity.minable = false
    sub_entity.destructible = false
    sub_entity.operable = false

    oc_entity.entities[sub_entity.unit_number] = sub_entity

    return sub_entity
end

local function setup_oc(oc_entity)
    local pp_control = oc_entity.ref.power_pole.get_or_create_control_behavior() --[[@as LuaLampControlBehavior]]
    pp_control.connect_to_logistic_network = false

    local sl1_control = oc_entity.ref.status_led_1.get_or_create_control_behavior() --[[@as LuaLampControlBehavior]]
    sl1_control.circuit_condition = {
        condition = { comparator = '=', first_signal = { type = 'virtual', name = 'signal-1' }, constant = 1 },
        connect_to_logistic_network = false,
    }

    local sl2_control = oc_entity.ref.status_led_2.get_or_create_control_behavior() --[[@as LuaLampControlBehavior]]
    sl2_control.circuit_condition = {
        condition = { comparator = '=', first_signal = { type = 'virtual', name = 'signal-2' }, constant = 1 },
        connect_to_logistic_network = false,
    }

    local sc_control = oc_entity.ref.status_controller.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior?]]
    sc_control.parameters = {
        { signal = { type = 'virtual', name = 'signal-1' }, index = 1, count = 0, },
        { signal = { type = 'virtual', name = 'signal-2' }, index = 2, count = 0, },
    }

    assert(oc_entity.ref.status_controller.connect_neighbour { wire = defines.wire_type.red, target_entity = oc_entity.ref.status_led_1 })
    assert(oc_entity.ref.status_controller.connect_neighbour { wire = defines.wire_type.green, target_entity = oc_entity.ref.status_led_2 })
end

--- Creates a new entity from the main entity, registers with the mod
--- and configures it.
---@param main LuaEntity
---@param tags Tags?
---@param player_index integer
---@param ghosts AttachedEntity[]
---@param attached AttachedEntity[]
---@return OpticalConnectorData? oc_entity
function Oc:create(main, tags, player_index, ghosts, attached)
    if not Is.Valid(main) then return nil end

    local entity_id = main.unit_number --[[@as integer]]

    assert(self:entity(entity_id) == nil)

    ---@type OpticalConnectorData
    local oc_entity = {
        main = main,
        status = defines.entity_status.disabled,
        entities = {},
        ref = { main = main },
        connected_networks = {},
    }

    -- create the basic innards
    for _, cfg in pairs(sub_entities) do
        oc_entity.ref[cfg.id] = create_internal_entity {
            entity = oc_entity,
            name = cfg.name,
            ghost = ghosts[cfg.name],
            attached = attached[cfg.name],
            x = cfg.x,
            y = cfg.y,
        }
    end

    -- create the io pins
    for idx = 1, const.oc_iopin_count, 1 do
        local iopin_ref = 'iopin' .. idx
        local iopin_name = const.iopin_name(idx)
        local iopin_pos = oc_iopin_position(main, idx)
        oc_entity.ref[iopin_ref] = create_internal_entity {
            entity = oc_entity,
            name = iopin_name,
            ghost = ghosts[iopin_name],
            attached = attached[iopin_name],
            pos = iopin_pos,
        }
    end

    setup_oc(oc_entity)

    self:setEntity(entity_id, oc_entity)

    return oc_entity
end

------------------------------------------------------------------------
-- control status of the optical connector
------------------------------------------------------------------------

---@param entity OpticalConnectorData
---@param network_id integer
local function disconnect_network(entity, network_id)
    local network = This.network:locate_network(entity.main, network_id)
    assert(network)

    for idx = 1, const.oc_iopin_count, 1 do
        local iopin_ref = 'iopin' .. idx
        local iopin = entity.ref[iopin_ref]
        assert(Is.Valid(iopin), 'IO Pin object invalid!')
        local fiber_strand = network.connectors[idx]
        assert(Is.Valid(fiber_strand), 'Fiber strand is invalid!')

        iopin.disconnect_neighbour { wire = defines.wire_type.red, target_entity = fiber_strand }
        iopin.disconnect_neighbour { wire = defines.wire_type.green, target_entity = fiber_strand }
    end

    This.network:remove_endpoint(entity.main, network_id)

    return true
end

---@param entity OpticalConnectorData
---@param network_id integer
local function connect_network(entity, network_id)
    local network = This.network:locate_network(entity.main, network_id)
    assert(network)

    local connection_success = true

    for idx = 1, const.oc_iopin_count, 1 do
        local iopin_ref = 'iopin' .. idx
        local iopin = entity.ref[iopin_ref]
        assert(Is.Valid(iopin), 'IO Pin object invalid!')

        local fiber_strand = network.connectors[idx]
        assert(Is.Valid(fiber_strand), 'Fiber strand is invalid!')

        -- bring the connection point close to connect
        fiber_strand.teleport(entity.main.position)

        connection_success = connection_success and iopin.connect_neighbour { wire = defines.wire_type.red, target_entity = fiber_strand }
        connection_success = connection_success and iopin.connect_neighbour { wire = defines.wire_type.green, target_entity = fiber_strand }
    end

    assert(connection_success)

    This.network:add_endpoint(entity.main, network_id)

    return true
end

---@param power_pole LuaEntity
---@return table<integer, integer> network_map
local function get_connected_networks(power_pole)
    local result = {}
    if not (power_pole.neighbours or power_pole.neighbours.copper) then return result end

    for idx = 1, 2, 1 do
        if power_pole.neighbours.copper[idx] then
            local neighbor = power_pole.neighbours.copper[idx]
            if Is.Valid(neighbor) and not result[power_pole.neighbours.copper[idx].electric_network_id] then
                -- id -> idx for presence check below
                result[power_pole.neighbours.copper[idx].electric_network_id] = idx
            end
        end
    end

    return result
end

---@param entity OpticalConnectorData
function Oc:update_entity_status(entity)
    if not (entity and entity.main and Is.Valid(entity.main)) then return end

    entity.status = entity.ref.power_entity.status or defines.entity_status.disabled

    -- check connected networks
    local changes = false
    local signals = { 0, 0 }
    local active_signals = 0

    -- if the unit is in red status, disconnect all networks
    local current_networks = ((Util.STATUS_NAMES[entity.status] == 'RED') and {}) or get_connected_networks(entity.ref.power_pole)

    -- disconnect missing networks
    for network_id in pairs(entity.connected_networks) do
        changes = (not current_networks[network_id] and disconnect_network(entity, network_id)) or changes
    end

    -- connect new networks
    for network_id, idx in pairs(current_networks) do
        signals[idx] = 1
        active_signals = active_signals + 1
        changes = (not entity.connected_networks[network_id] and connect_network(entity, network_id)) or changes
    end

    if changes then
        local control = entity.ref.status_controller.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior ]]
        assert(control)

        -- idx is the led to turn on/off, count is 0 for off or 1 for on
        for idx, count in pairs(signals) do
            control.set_signal(idx, { signal = { type = 'virtual', name = 'signal-' .. idx }, count = count })
        end

        entity.connected_networks = current_networks

        entity.ref.power_entity.power_usage = (1000 * (1 + active_signals * 8)) / 60.0
    end
end

-- local entity_context = This.context_manager:get_entity_context(primary_entity, true)



-- -- find all possible ghosts that may have been placed before this entity
-- local ghosts = tools.find_entities(primary_entity, nil, { name = 'entity-ghost' })

-- -- add the power entity for power consumption
-- This.context_manager:add_entity_if_not_exists(primary_entity, 'power_entity', function()
--     return create_related_entity(primary_entity, const.oc_power_interface, nil, ghosts)
-- end)

-- -- power pole to connect the copper wires (connect to the fiber optic cables)
-- This.context_manager:add_entity_if_not_exists(primary_entity, 'power_pole', function()
--     local entity = create_related_entity(primary_entity, const.oc_power_pole, nil, ghosts)

--     ---@type LuaLampControlBehavior?
--     local control = entity.get_or_create_control_behavior() --[[@as LuaLampControlBehavior]]
--     assert(control, 'where is my control?')
--     control.connect_to_logistic_network = false

--     return entity
-- end)

-- -- status lamp 1
-- This.context_manager:add_entity_if_not_exists(primary_entity, 'lamp1', function()
--     local entity = create_related_entity(primary_entity, const.oc_led_lamp, { primary_entity.position.x - 0.2, primary_entity.position.y - 0.02 }, ghosts)

--     ---@type LuaLampControlBehavior?
--     local control = entity.get_or_create_control_behavior() --[[@as LuaLampControlBehavior]]
--     assert(control, 'where is my control?')
--     control.circuit_condition = {
--         condition = { comparator = '=', first_signal = { type = 'virtual', name = 'signal-1' }, constant = 1 },
--         connect_to_logistic_network = false,
--     }
--     return entity
-- end)

-- -- status lamp 2
-- This.context_manager:add_entity_if_not_exists(primary_entity, 'lamp2', function()
--     local entity = create_related_entity(primary_entity, const.oc_led_lamp, { primary_entity.position.x + 0.2, primary_entity.position.y - 0.02 }, ghosts)

--     ---@type LuaLampControlBehavior?
--     local control = entity.get_or_create_control_behavior() --[[@as LuaLampControlBehavior]]
--     assert(control, 'where is my control?')
--     control.circuit_condition = {
--         condition = { comparator = '=', first_signal = { type = 'virtual', name = 'signal-2' }, constant = 1 },
--         connect_to_logistic_network = false,
--     }

--     return entity
-- end)

-- This.context_manager:add_entity_if_not_exists(primary_entity, 'cc', function(context)
--     local entity = create_related_entity(primary_entity, const.oc_cc, nil, ghosts)

--     local control = entity.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior?]]
--     assert(control, 'where is my control?')
--     control.parameters = {
--         { index = 1, count = 0, signal = { type = 'virtual', name = 'signal-1' } },
--         { index = 2, count = 0, signal = { type = 'virtual', name = 'signal-2' } },
--     }

--     entity.connect_neighbour { wire = defines.wire_type.red, target_entity = entity_context.lamp1 }
--     entity.connect_neighbour { wire = defines.wire_type.green, target_entity = entity_context.lamp2 }

--     return entity
-- end)

-- for idx = 1, const.oc_iopin_count, 1 do
--     This.context_manager:add_entity_if_not_exists(primary_entity, { 'iopins', idx }, function()
--         return create_related_entity(primary_entity, const.iopin_name(idx), oc_iopin_position(primary_entity, idx), ghosts)
--     end)
-- end

-- This.context_manager:set_field_if_not_exists(primary_entity, 'connected_networks', {})

-- return primary_entity

---@param entity_id integer
function Oc:destroy(entity_id)
    assert(Is.Number(entity_id))

    local oc_entity = self:entity(entity_id)
    if not oc_entity then return end

    for _, sub_entity in pairs(oc_entity.entities) do
        sub_entity.destroy()
    end

    self:setEntity(entity_id, nil)
end

------------------------------------------------------------------------
-- Move OC (Picker Dollies code)
------------------------------------------------------------------------

local wire_checks = {
    [const.check_circuit_wires] = function(entity)
        local wire_connections = entity.circuit_connected_entities
        if wire_connections then
            for _, connected_entities in pairs(wire_connections) do
                for _, connected_entity in pairs(connected_entities) do
                    if entity.surface == connected_entity.surface and connected_entity.name ~= const.network_connector then
                        if not entity.can_wires_reach(connected_entity) then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end,
    [const.check_power_wires] = function(entity)
        if entity.neighbours and entity.neighbours.copper then
            for _, neighbor in pairs(entity.neighbours.copper) do
                if entity.surface == neighbor.surface then
                    if not entity.can_wires_reach(neighbor) then
                        return true
                    end
                end
            end
        end
        return false
    end,
}

--- check whether connected wires can be stretched. Returns true if the wire
--- could not be stretched to the new position.
---@param entity LuaEntity
---@param new_pos MapPosition
---@param player LuaPlayer
local function check_wire_stretch(entity, new_pos, player)
    local src_pos = entity.position

    local checker = const.wire_check[entity.name]
    -- no wires, no check
    if not checker then return false end

    -- move entity temporarily to check wire reach
    entity.teleport(new_pos)

    local vetoed = wire_checks[checker](entity)
    if vetoed then
        player.create_local_flying_text {
            position = entity.position,
            text = { const.msg_wires_too_long },
        }
    end

    -- move back
    entity.teleport(src_pos)

    return vetoed
end

function Oc:move(main, start_pos, player)
    if not Is.Valid(main) then return end

    local oc_entity = self:entity(main.unit_number)
    if not oc_entity then return end

    local dx = main.position.x - start_pos.x
    local dy = main.position.y - start_pos.y

    local move_list = {}

    for idx, related_entity in pairs(oc_entity.entities) do
        local dst_pos = {
            x = related_entity.position.x + dx,
            y = related_entity.position.y + dy,
        }

        if check_wire_stretch(related_entity, dst_pos, player) then
            -- move entity back, end
            main.teleport(start_pos)
            return
        end

        move_list[idx] = dst_pos
    end

    for idx, related_entity in pairs(oc_entity.entities) do
        related_entity.teleport(move_list[idx])
    end
end

------------------------------------------------------------------------
-- Rotate OC
------------------------------------------------------------------------

--- rotates the iopins to the new orientation of the entity and tests whether the
--- wires overstretch.
---@param main LuaEntity The base entity for the io pins
---@param oc_entity OpticalConnectorData
---@param player LuaPlayer The player doing the moving
---@return boolean vetoed If true, vetoed the move
---@return MapPosition[] iopin_positions Array of new positions for the io pins. Only valid if not vetoed.
local function rotate_iopins(main, oc_entity, player)
    local move_list = {}
    for idx = 1, const.oc_iopin_count, 1 do
        local iopin_name = 'iopin' .. idx
        local dst_pos = oc_iopin_position(main, idx)
        local iopin = oc_entity.ref[iopin_name]
        if check_wire_stretch(iopin, dst_pos, player) then
            return true, {}
        end

        move_list[idx] = dst_pos
    end
    return false, move_list
end

-- see if we can rotate the connector. The io pins move around
-- when rotating, so check whether there are stretched wires.

---@param main LuaEntity
---@param player_index integer?
function Oc:rotate(main, player_index, previous_direction)
    if not Is.Valid(main) then return end

    local oc_entity = self:entity(main.unit_number)
    if not oc_entity then return end

    local player = game.players[player_index]
    local vetoed, rotated_io_pins = rotate_iopins(main, oc_entity, player)

    if vetoed then
        main.direction = previous_direction
    else
        for idx = 1, const.oc_iopin_count, 1 do
            local iopin_name = 'iopin' .. idx
            oc_entity.ref[iopin_name].teleport(rotated_io_pins[idx])
        end
    end
end

------------------------------------------------------------------------
-- Ticker
------------------------------------------------------------------------

function Oc:update_entities()
    for idx, entity in pairs(self:entities()) do
        local power_entity = entity.ref.power_entity

        if bit32.band(This.debug_mode, 2) ~= 0 then
            Framework.logger.debugf('Connector %d, current energy usage %4.1d kW', idx, (power_entity.power_usage * 60) / 1000.0)
            Framework.logger.debugf('Connector %d, charge: %d, drain: %d, capacity: %d', idx, power_entity.electric_emissions, power_entity.electric_drain,
                power_entity.electric_buffer_size)
        end

        self:update_entity_status(entity)
    end
end

---------------------------------------------------------------------------------------------------------

--- Creates a specific, related entity for a primary entity (an optical connector). Looks whether
-- a ghost has been placed before and if yes, picks it up. This allows e.g. wires to be reconnected
-- when pasting from a blueprint (or cut and paste).
---@param primary_entity LuaEntity The primary entity (optical_connector)
---@param entity_name string The name of the new entity to create or recover.
---@param position table|function|nil Position for the new entity.
---@param ghosts LuaEntity[]? An array of ghost entities that should be considered for revival.
-- local function create_related_entity(primary_entity, entity_name, position, ghosts)
--     local entity

--     if not position then
--         position = primary_entity.position
--     elseif type(position) == 'function' then
--         position = position(primary_entity)
--     end

--     if ghosts and #ghosts > 0 then
--         for _, ghost in pairs(ghosts) do
--             if ghost.valid and ghost.ghost_name == entity_name then
--                 local _, revived_entity = ghost.silent_revive()
--                 assert(revived_entity, 'Ghost could not be revived!')
--                 entity = revived_entity
--                 entity.teleport(position)
--                 break
--             end
--         end
--     end

--     if not entity then
--         entity = primary_entity.surface.create_entity {
--             name = entity_name,
--             position = position,
--             force = primary_entity.force,
--         }
--     end

--     entity.minable = false
--     entity.destructible = false
--     entity.operable = false
--     return entity
-- end

---------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------

-- local function find_oc_from_entity(entity)
--     -- local entities = tools.find_entities(entity, nil, { name = const.optical_connector })
--     -- for _, found_entity in pairs(entities) do
--     --     if found_entity.valid and found_entity.name == const.optical_connector then
--     --         local oc_context = This.context_manager:get_entity_context(found_entity, false)
--     --         if tools.is_valid(oc_context) then
--     --             return found_entity, oc_context
--     --         end
--     --     end
--     -- end
-- end

-- function Oc:createGhost(primary_entity)
--     if not tools.is_valid(primary_entity) or primary_entity.type ~= 'entity-ghost' then return end
--     if not tools.array_contains(const.attached_entities, primary_entity.ghost_name) then return end

--     -- local existing_oc = find_oc_from_entity(primary_entity)
--     -- if (existing_oc) then
--     --     local _, revived_entity = primary_entity.silent_revive()
--     --     if tools.is_valid(revived_entity) then
--     --         -- deal with io pins
--     --         if tools.array_contains(const.all_iopins, revived_entity.name) then
--     --             local idx = oc_idx_from_iopin(revived_entity)
--     --             local old_pin = This.context_manager:remove_entity(existing_oc, { 'iopins', idx })
--     --             if old_pin and old_pin.valid then
--     --                 old_pin.destroy()
--     --             end

--     --             This.context_manager:add_entity(existing_oc, { 'iopins', idx }, revived_entity)
--     --             revived_entity.direction = existing_oc.direction
--     --             revived_entity.teleport(oc_iopin_position(existing_oc, idx))
--     --         elseif revived_entity.name == const.oc_power_pole then
--     --             local old_power_pole = This.context_manager:remove_entity(existing_oc, 'power_pole')
--     --             if old_power_pole and old_power_pole.valid then
--     --                 old_power_pole.destroy()
--     --             end
--     --             This.context_manager:add_entity(existing_oc, 'power_pole')
--     --             revived_entity.direction = existing_oc.direction
--     --             revived_entity.teleport(existing_oc.position)
--     --         else
--     --             -- everything else can be destroyed
--     --             revived_entity.destroy()
--     --         end
--     --     end
--     -- end
-- end

---------------------------------------------------------------------------------------------------------

--- Required for undo/robot construction to clean up anything attached.
function Oc:mark_for_deconstruction(attached_entity)
    -- -- only deal with attached objects
    -- if not (tools.is_valid(attached_entity) and tools.array_contains(const.attached_entities, attached_entity.name)) then return end

    -- attached_entity.destroy()
end

---------------------------------------------------------------------------------------------------------

return Oc
