------------------------------------------------------------------------
-- Network related code
------------------------------------------------------------------------
assert(script)

local Is = require('stdlib.utils.is')

local const = require('lib.constants')

---@class FiberNetworkManager
local Network = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global network data structure
function Network:init()
    if storage.oc_networks then return end

    ---@type GlobalFiberNetworks
    storage.oc_networks = {
        VERSION = const.current_version,
        surface_networks = {},
        total_count = 0,
    }
end

------------------------------------------------------------------------
-- getters
------------------------------------------------------------------------

---@return table<integer, SurfaceFiberNetworks> all_surface_networks
function Network:all_surface_networks()
    return storage.oc_networks.surface_networks
end

---@return SurfaceFiberNetworks? surface_networks
function Network:surface_networks(surface_id)
    return storage.oc_networks.surface_networks[surface_id]
end

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
---@param entity LuaEntity
---@param network_id integer
---@return FiberNetwork fiber_network
function Network:locate_network(entity, network_id)
    local surface_index = entity.surface_index

    local surface_networks = self:surface_networks(surface_index) or self:create_new_surface_network()
    local fiber_network = surface_networks.networks[network_id] or create_new_network(entity)

    if not surface_networks.networks[network_id] then
        surface_networks.networks[network_id] = fiber_network
        surface_networks.network_count = surface_networks.network_count + 1
        storage.oc_networks.total_count = storage.oc_networks.total_count + 1
    end

    storage.oc_networks.surface_networks[surface_index] = storage.oc_networks.surface_networks[surface_index] or surface_networks

    return fiber_network
end

function Network:destroy_network(entity, network_id)
    local network = self:locate_network(entity, network_id)

    if network.endpoint_count > 0 then
        Framework.logger:logf("Shutting down fiber network '%d' with %d remaining endpoints!", network_id, network.endpoint_count)
    end

    for idx = 1, const.max_fiber_count, 1 do
        network.connectors[idx].destroy()
    end

    local surface_networks = self:surface_networks(entity.surface.index)
    if surface_networks and surface_networks.networks[network_id] then
        surface_networks.networks[network_id] = nil
        surface_networks.network_count = surface_networks.network_count - 1

        storage.oc_networks.total_count = storage.oc_networks.total_count - 1
    end
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
-- ticker
------------------------------------------------------------------------

local debug_tick = -1
function Network:tick()
    local debug = Framework.settings:startup_setting('debug_mode')

    local print_debug_info = false
    if debug_tick < game.tick then
        debug_tick = game.tick + 3600 -- tick once a minute
        print_debug_info = debug
    end

    for surface_index, surface_networks in pairs(self:all_surface_networks()) do
        for network_id, fiber_network in pairs(surface_networks.networks) do
            local connectors = ''
            local count = 0

            for id, entity in pairs(fiber_network.endpoints) do
                if not Is.Valid(entity) then
                    fiber_network.endpoints[id] = nil
                    fiber_network.endpoint_count = fiber_network.endpoint_count - 1
                else
                    count = count + 1
                    if connectors:len() > 0 then
                        connectors = connectors .. ', '
                    end
                    connectors = connectors .. id
                end
            end

            if fiber_network.endpoint_count < 0 then
                fiber_network.endpoint_count = 0
            end

            if print_debug_info then
                Framework.logger:debugf('Network Id: %d/%d, connected entities: %d', network_id, surface_index, fiber_network.endpoint_count)
                Framework.logger:debugf('Entities: %s', connectors)

                for idx, connector in pairs(fiber_network.connectors) do
                    local red_connector = connector.get_wire_connector(defines.wire_connector_id.circuit_red, true)
                    if red_connector.connection_count ~= count then
                        Framework.logger:debugf('Fiber strand %d has %d connected red endpoints', idx, red_connector.connection_count)
                    end
                    local green_connector = connector.get_wire_connector(defines.wire_connector_id.circuit_green, true)
                    if green_connector.connection_count ~= count then
                        Framework.logger:debugf('Fiber strand %d has %d connected green endpoints', idx, green_connector.connection_count)
                    end
                end
            end
        end
    end
end

return Network
