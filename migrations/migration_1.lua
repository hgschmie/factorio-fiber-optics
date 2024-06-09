--------------------------------------------------------------------------------
-- migrate network and entities from 0.0.1
--------------------------------------------------------------------------------

require('lib.init')

local const = require('lib.constants')

if global.oc_networks and global.oc_data and global.oc_networks.VERSION > 0 and global.oc_data.VERSION > 0 then return end

if not global.oc_networks then
    This.network:init()
end

if not global.oc_data then
    This.oc:init()
end

if global.networks then
    local entity_map = {}
    for entity_id, context in pairs(global.context) do
        entity_map[entity_id] = context._primary
    end


    for idx, old_surface_networks in pairs(global.networks) do
        local surface_networks = This.network:get_surface_network()
        global.oc_networks.surface_networks[idx] = surface_networks

        for network_idx, old_network in pairs(old_surface_networks) do
            local network = {
                endpoints = {},
                endpoint_count = 0,
                connectors = old_network.connector,
            }

            for endpoint_id in pairs(old_network.endpoint) do
                assert(entity_map[endpoint_id])
                network.endpoints[endpoint_id] = entity_map[endpoint_id]
                network.endpoint_count = network.endpoint_count + 1
            end

            surface_networks.networks[network_idx] = network
            surface_networks.network_count = surface_networks.network_count + 1
            global.oc_networks.total_count = global.oc_networks.total_count + 1
        end
    end
    global.networks = nil
end

if global.context then
    for idx, old_connector in pairs(global.context) do
        local new_entity = {
            main = old_connector._primary,
            entities = old_connector._cleanup,
            connected_networks = old_connector.connected_networks,
            ref = {
                main = old_connector._primary,
                power_entity = old_connector.power_entity,
                power_pole = old_connector.power_pole,
                status_led_1 = old_connector.lamp1,
                status_led_2 = old_connector.lamp2,
                status_controller = old_connector.cc,
            }
        }

        for io_idx, entity in pairs(old_connector.iopins) do
            new_entity.ref['iopin' .. io_idx ] = entity
        end

        global.oc_data.oc[idx] = new_entity
        global.oc_data.count = global.oc_data.count + 1
    end

    global.context = nil
end
