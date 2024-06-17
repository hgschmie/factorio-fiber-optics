------------------------------------------------------------------------
-- Network related code
------------------------------------------------------------------------

local const = require('lib.constants')

---@class FiberNetworkManager
local Network = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global network data structure
function Network:init()
    if global.oc_networks then return end

    ---@type GlobalFiberNetworks
    global.oc_networks = {
        VERSION = const.current_version,
        surface_networks = {},
        total_count = 0,
    }
end

---------------------------------------------------------------------------------------------------------

function Network:create_new_surface_network()
    ---@class SurfaceFiberNetworks
    ---@field networks table<integer, FiberNetwork>
    ---@field network_count integer
    return {
        networks = {},
        network_count = 0
    }
end

---@param entity LuaEntity
---@return FiberNetwork fiber_network
local function create_new_network(entity)
    local connectors = {}

    for idx = 1, const.max_fiber_count, 1 do
        connectors[idx] = entity.surface.create_entity {
            name = const.network_connector,
            position = { x = 0, y = 0 },
            force = entity.force,
        }
    end

    ---@type FiberNetwork
    return {
        endpoint_count = 0,
        endpoints = {},
        connectors = connectors,
    }
end

--- returns a specific fiber network for a given entity to connect to.
---
--- @param entity LuaEntity
--- @param network_id integer
--- @return FiberNetwork fiber_network
function Network:locate_network(entity, network_id)
    local surface_index = entity.surface_index

    local surface_networks = global.oc_networks.surface_networks[surface_index] or self:create_new_surface_network()
    local fiber_network = surface_networks.networks[network_id] or create_new_network(entity)

    if not surface_networks.networks[network_id] then
        surface_networks.networks[network_id] = fiber_network
        surface_networks.network_count = surface_networks.network_count + 1
        global.oc_networks.total_count = global.oc_networks.total_count + 1
    end

    global.oc_networks[surface_index] = global.oc_networks[surface_index] or surface_networks

    return fiber_network
end

function Network:destroy_network(entity, network_id)
    local network = self:locate_network(entity, network_id)

    assert(network.endpoint_count == 0, 'can not shut down a fiber network with remaining endpoints!')

    for idx = 1, const.max_fiber_count, 1 do
        network.connectors[idx].destroy()
    end

    local surface_networks = global.oc_networks.surface_networks[entity.surface.index]
    surface_networks.networks[network_id] = nil
    surface_networks.network_count = surface_networks.network_count - 1

    global.oc_networks.total_count = global.oc_networks.total_count - 1
end

------------------------------------------------------------------------
-- add/remove endpoint
------------------------------------------------------------------------

---@param entity LuaEntity
---@param network_id integer
function Network:remove_endpoint(entity, network_id)
    local network = self:locate_network(entity, network_id)

    -- already disconnected
    if not network.endpoints[entity.unit_number] then return end

    network.endpoints[entity.unit_number] = nil
    network.endpoint_count = network.endpoint_count - 1

    if network.endpoint_count <= 0 then
        self:destroy_network(entity, network_id)
    end
end

---@param entity LuaEntity
---@param network_id integer
function Network:add_endpoint(entity, network_id)
    local network = self:locate_network(entity, network_id)

    -- already connected
    if network.endpoints[entity.unit_number] then return end

    network.endpoints[entity.unit_number] = entity
    network.endpoint_count = network.endpoint_count + 1
end

------------------------------------------------------------------------
-- network debug code
------------------------------------------------------------------------

function Network:fiber_network_debug_output()
    for surface_index, networks in pairs(global.oc_networks.surface_networks) do
        for network_id, fiber_network in pairs(networks) do
            local connectors = ''
            local count = 0

            for id, _ in pairs(fiber_network.endpoints) do
                count = count + 1
                if connectors:len() > 0 then
                    connectors = connectors .. ', '
                end
                connectors = connectors .. id
            end

            Framework.logger:debugf('Network Id: %d/%d, connected entities: %d', network_id, surface_index, fiber_network.endpoint_count)
            Framework.logger:debugf('Entities: %s', connectors)

            for idx, connector in pairs(fiber_network.connectors) do
                if #connector.circuit_connected_entities.red ~= count then
                    Framework.logger:debugf('Fiber strand %d has %d connected red endpoints', idx, #connector.circuit_connected_entities.red)
                end
                if #connector.circuit_connected_entities.green ~= count then
                    Framework.logger:debugf('Fiber strand %d has %d connected green endpoints', idx, #connector.circuit_connected_entities.green)
                end
            end
        end
    end
end

return Network
