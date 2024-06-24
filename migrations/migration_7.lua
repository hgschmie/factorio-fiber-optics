--------------------------------------------------------------------------------
-- migration 7
--------------------------------------------------------------------------------
-- fix the bad network setup which caused OCs to be not connected.
--------------------------------------------------------------------------------

require('lib.init')

if global.oc_networks.VERSION > 6 and global.oc_data.VERSION > 6 then return end

local Is = require('__stdlib__/stdlib/utils/is')

local function destroy_networks(networks)
    if not networks then return end
    for _, network in pairs(networks) do
        if network and network.connectors then
            for _, connector in pairs(network.connectors) do
                connector.destroy()
            end
        end
    end
end

-- fix the electrical networks that ended up in the wrong spots.
for key, surface_network in pairs(global.oc_networks) do
    if Is.Number(key) and surface_network then
        destroy_networks(surface_network.networks)
    end
end

for _, surface_network in pairs(This.network:all_surface_networks()) do
    destroy_networks(surface_network.networks)
end

global.oc_networks = nil
This.network:init()

for _, oc_entity in pairs(This.oc:entities()) do
    if Is.Valid(oc_entity.main) then
        for network_id in pairs(oc_entity.connected_networks) do
            This.oc:connect_network(oc_entity, network_id)
        end
    end
end

global.oc_networks.VERSION = 7
global.oc_data.VERSION = 7
