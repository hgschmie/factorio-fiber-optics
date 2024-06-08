--------------------------------------------------------------------------------
-- migrate network and entities from 0.0.1
--------------------------------------------------------------------------------

require('lib.init')

if global.oc_networks and global.oc_networks.VERSION > 0 then return end

if not global.oc_networks then
    This.network:init()
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
