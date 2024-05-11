--
-- Network related code
--

local const = require('lib.constants')
local tools = require('lib.tools')
local context_manager = require('lib.context')

local debug_mode = 0 -- bit 0 (0/1): network debug, bit 1 (0/2): entity debug 

---------------------------------------------------------------------------------------------------------

local function locate_fiber_network(primary_entity, network_id)
    local surface_index = primary_entity.surface.index

    if not global.networks then
        global.networks = {}
    end

    if not global.networks[surface_index] then
        global.networks[surface_index] = {}
    end

    if global.networks[surface_index][network_id] then
        return global.networks[surface_index][network_id]
    end

    return nil
end

local function start_fiber_network(primary_entity, network_id)
    local fiber_network = locate_fiber_network(primary_entity, network_id)

    if not fiber_network then
        fiber_network = {
            endpoint_count = 0,
            endpoint = {},
            connector = {},
        }

        for idx = 1, const.oc_iopin_count, 1 do
            fiber_network.connector[idx] = primary_entity.surface.create_entity {
                name = const.network_connector,
                position = { x = 0, y = 0 },
                force = primary_entity.force,
            }
        end

        global.networks[primary_entity.surface.index][network_id] = fiber_network
    end
    return fiber_network
end

local function stop_fiber_network(primary_entity, network_id)
    local network_bus = locate_fiber_network(primary_entity, network_id)

    if network_bus then
        assert(network_bus.endpoint_count == 0, "can not shut down a fiber network with remaining endpoints!")

        for idx = 1, const.oc_iopin_count, 1 do
            network_bus.connector[idx].destroy()
        end

        global.networks[primary_entity.surface.index][network_id] = nil
    end
end

local function connect_to_fiber_network(network_id, context)
    local network_bus = start_fiber_network(context._primary, network_id)

    if network_bus then
        local connection_success = true
        for idx, iopin in pairs(context.iopins) do
            assert(tools.is_valid(iopin))
            local network_terminator = network_bus.connector[idx]
            assert(tools.is_valid(network_terminator))

            -- bring the connection point close to connect
            network_terminator.teleport(context._primary.position)

            connection_success = connection_success and iopin.connect_neighbour { wire = defines.wire_type.red, target_entity = network_terminator }
            connection_success = connection_success and iopin.connect_neighbour { wire = defines.wire_type.green, target_entity = network_terminator }
        end

        if connection_success then
            table.insert(network_bus.endpoint, context._primary.unit_number, true)
            network_bus.endpoint_count = network_bus.endpoint_count + 1
        end
        return connection_success
    end
    return false
end

local function disconnect_from_fiber_network(network_id, context)
    local network_bus = locate_fiber_network(context._primary, network_id)

    if network_bus then
        for idx, iopin in pairs(context.iopins) do
            assert(tools.is_valid(iopin), "IO Pin object invalid!")
            local fiber_strand = network_bus.connector[idx]
            assert(tools.is_valid(fiber_strand), "Fiber strand is invalid!")

            iopin.disconnect_neighbour({ wire = defines.wire_type.red, target_entity = fiber_strand })
            iopin.disconnect_neighbour({ wire = defines.wire_type.green, target_entity = fiber_strand })
        end

        network_bus.endpoint[context._primary.unit_number] = nil
        network_bus.endpoint_count = network_bus.endpoint_count - 1

        if network_bus.endpoint_count <= 0 then
            stop_fiber_network(context._primary, network_id)
        end
    end
    return true
end

---------------------------------------------------------------------------------------------------------

local function is_functional(entity_context)
    if not tools.is_valid(entity_context) then return false end
    if not tools.is_valid(entity_context._primary) then return false end
    if not tools.is_valid(entity_context.power_entity) then return false end
    if not tools.is_valid(entity_context.power_pole) then return false end
    if not tools.is_valid(entity_context.cc) then return false end

    return true
end

local function detect_network_status(power_pole)
    local result = {}
    if power_pole.neighbours and power_pole.neighbours.copper then
        for idx = 1, 2, 1 do
            if power_pole.neighbours.copper[idx] then
                local neighbor = power_pole.neighbours.copper[idx]
                if tools.is_valid(neighbor) and not result[power_pole.neighbours.copper[idx].electric_network_id] then
                    result[power_pole.neighbours.copper[idx].electric_network_id] = idx
                end
            end
        end
    end
    return result
end

local function fiber_network_management_handler()
    for _, context in pairs(context_manager:get_all_contexts()) do
        if is_functional(context) then
            local power_entity = context.power_entity

            if bit32.band(debug_mode, 2) ~= 0 then
                tools.debug_print(string.format("Connector %d, current energy usage %4.1d kW", context._primary.unit_number, (power_entity.power_usage * 60)/1000.0))
                tools.debug_print(string.format("Connector %d, charge: %d, drain: %d, capacity: %d", context._primary.unit_number, power_entity.electric_emissions, power_entity.electric_drain, power_entity.electric_buffer_size))
            end

            local no_power = (power_entity.status and
                (power_entity.status == defines.entity_status.no_power or power_entity.status == defines.entity_status.low_power)) or false

            local connected_networks = context.connected_networks or {}
            -- if the unit is unpowered, all networks disconnect
            local current_networks = (no_power and {}) or detect_network_status(context.power_pole)

            local changes = false

            -- disconnect missing networks
            for id, _ in pairs(connected_networks) do
                changes = (not current_networks[id] and disconnect_from_fiber_network(id, context)) or changes
            end

            local signals = { 0, 0 }
            local active_signals = 0
            -- connect new networks
            for id, idx in pairs(current_networks) do
                signals[idx] = 1
                active_signals = active_signals + 1
                changes = (not connected_networks[id] and connect_to_fiber_network(id, context)) or changes
            end

            if changes then
                local cc = context.cc
                if tools.is_valid(cc) then
                    local control = cc.get_or_create_control_behavior()
                    assert(control, "Where is my control?")

                    for idx, count in pairs(signals) do
                        control.set_signal(idx, { signal = { type = "virtual", name = "signal-" .. idx }, count = count })
                    end
                end

                context.connected_networks = current_networks

                power_entity.power_usage = (1000 * (1 + active_signals * 8)) / 60.0
            end
        end
    end
end

-- called when the context is destroyed because the primary object was destroyed.
-- removes all network connections from the network table
local function network_destroy_context(unit_number, entity_context)
    local connected_networks = entity_context.connected_networks or {}

    for network_id, _ in pairs(connected_networks) do
        disconnect_from_fiber_network(network_id, entity_context)
    end
end

local function fiber_network_debug_output()
    if not global.networks then
        global.networks = {}
    end

    if not global.networks[1] then
        global.networks[1] = {}
    end

    for network_id, fiber_network in pairs(global.networks[1]) do

        local connectors = ''
        local count = 0

        for id, _ in pairs(fiber_network.endpoint) do
            count = count + 1
            if connectors:len() > 0 then
                connectors = connectors .. ", "
            end
            connectors = connectors .. id
        end

        tools.debug_print(string.format("Network Id: %d, connected entities: %d", network_id, fiber_network.endpoint_count))
        tools.debug_print(string.format("Entities: %s", connectors))

        for idx, connector in pairs(fiber_network.connector) do
            if #connector.circuit_connected_entities.red ~= count then
                tools.debug_print(string.format("Fiber strand %d has %d connected red endpoints", idx, #connector.circuit_connected_entities.red))
            end
            if #connector.circuit_connected_entities.green ~= count then
                tools.debug_print(string.format("Fiber strand %d has %d connected green endpoints", idx, #connector.circuit_connected_entities.green))
            end
        end
    end
end



local function network_load()
    script.on_nth_tick(300, fiber_network_management_handler)

    if bit32.band(debug_mode, 1) ~= 0 then
        script.on_nth_tick(100, fiber_network_debug_output)
    end
end


local function network_init()
    global.networks = {}

    network_load()
end

return {
    init = network_init,
    load = network_load,
    destroy_context = network_destroy_context,
}
