--------------------------------------------------------------------------------
-- migration 1
--------------------------------------------------------------------------------
-- move network and data to the new data model in version 0.1
--------------------------------------------------------------------------------

require('lib.init')

if storage.oc_networks and storage.oc_data and storage.oc_networks.VERSION > 0 and storage.oc_data.VERSION > 0 then return end

if not storage.oc_networks then
    This.network:init()
end

if not storage.oc_data then
    This.oc:init()
end

if storage.networks then
    local entity_map = {}
    for entity_id, context in pairs(storage.context) do
        entity_map[entity_id] = context._primary
    end


    for idx, old_surface_networks in pairs(storage.networks) do
        local surface_networks = This.network:create_new_surface_network()
        storage.oc_networks.surface_networks[idx] = surface_networks

        for network_idx, old_network in pairs(old_surface_networks) do
            local network = {
                endpoints = {},
                endpoint_count = 0,
                connectors = old_network.connector,
            }

            for endpoint_id in pairs(old_network.endpoint) do
                if entity_map[endpoint_id] then
                    network.endpoints[endpoint_id] = entity_map[endpoint_id]
                    network.endpoint_count = network.endpoint_count + 1
                end
            end

            surface_networks.networks[network_idx] = network
            surface_networks.network_count = surface_networks.network_count + 1
            storage.oc_networks.total_count = storage.oc_networks.total_count + 1
        end
    end
    storage.networks = nil
end

if storage.context then
    for idx, old_connector in pairs(storage.context) do
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

        storage.oc_data.oc[idx] = new_entity
        storage.oc_data.count = storage.oc_data.count + 1
    end

    storage.context = nil
end

-- don't use 'const.current_version', otherwise the next migrations are not run!
storage.oc_networks.VERSION = 1
storage.oc_data.VERSION = 1
