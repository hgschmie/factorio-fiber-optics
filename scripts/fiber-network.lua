------------------------------------------------------------------------
-- Manage Fiber Networks
------------------------------------------------------------------------
assert(script)

local const = require('lib.constants')

local helpers = require('scripts.helpers')

---@class fo.Network
local Network = {}

------------------------------------------------------------------------
-- getters
------------------------------------------------------------------------

---@return fo.SurfaceNetwork[]
function Network:allSurfaceNetworks()
    return This.storage().surface_networks
end

---@return integer
local function count_networks()
    local count = 0

    for _, surface_network in pairs(Network:allSurfaceNetworks()) do
        count = count + table_size(surface_network)
    end

    return count
end


---@param surface_index integer
---@return fo.SurfaceNetwork
function Network:locateSurfaceNetwork(surface_index)
    local surface_networks = self:allSurfaceNetworks()
    surface_networks[surface_index] = surface_networks[surface_index] or {}

    return surface_networks[surface_index]
end

---@param surface_index integer
---@param force_id integer
---@return fo.FiberStrand fiber_strand
local function create_fiber_strand(surface_index, force_id)
    ---@type fo.FiberHub[]
    local hubs = {}

    local surface = assert(game.surfaces[surface_index])
    local force = assert(game.forces[force_id])

    for idx = 1, const.max_hub_count, 1 do
        hubs[idx] = {
            hub = surface.create_entity {
                name = const.fiber_hub_name,
                position = { x = 0, y = 0 },
                force = force,
            }
        }
    end

    return {
        endpoint_count = 0,
        endpoints = {},
        hubs = hubs,
    }
end

---@param surface_index integer
---@param force_id integer
---@param network_id integer
---@return fo.FiberNetwork
function Network:getOrCreateFiberNetwork(surface_index, force_id, network_id)
    local surface_network = self:locateSurfaceNetwork(surface_index)

    surface_network[network_id] = surface_network[network_id] or {
        default = create_fiber_strand(surface_index, force_id)
    }

    return surface_network[network_id]
end

--- returns a specific fiber network for a given entity to connect to.
---
---@param entity LuaEntity
---@param network_id integer
---@param strand_name string
---@return fo.FiberNetwork fiber_network
function Network:locateFiberStrand(entity, network_id, strand_name)
    local surface_index = entity.surface_index

    local fiber_network = self:getOrCreateFiberNetwork(surface_index, entity.force_index, network_id)
    fiber_network[strand_name] = fiber_network[strand_name] or create_fiber_strand(surface_index, entity.force_index)

    return fiber_network[strand_name]
end

---@param entity LuaEntity
---@param network_id integer
function Network:destroyFiberNetwork(entity, network_id)
    local surface_index = entity.surface_index
    local surface_network = self:locateSurfaceNetwork(surface_index)

    if not surface_network[network_id] then return end

    for strand_name, strand in pairs(surface_network[network_id]) do
        if strand.endpoint_count > 0 then
            Framework.logger:logf("Shutting down fiber strand '%d/%s' with %d remaining endpoints!", network_id, strand_name, strand.endpoint_count)
        end

        for _, hub in pairs(strand.hubs) do
            if (hub.hub and hub.hub.valid) then hub.hub.destroy() end
        end
    end

    surface_network[network_id] = nil
end

------------------------------------------------------------------------
-- entity connect / disconnect
------------------------------------------------------------------------

---@param network_id integer
---@param fo_entity fo.FiberOptics
function Network:connectEntity(network_id, fo_entity)
    local main = fo_entity.main
    if not (main and main.valid) then return end

    local fiber_strand = self:locateFiberStrand(main, network_id, 'default')

    -- register as endpoint
    fiber_strand.endpoint_count = fiber_strand.endpoint_count + 1
    fiber_strand.endpoints[main.unit_number] = main

    -- wire each IO pin to its corresponding hub
    for idx = 1, const.max_hub_count do
        local iopin = fo_entity.iopin[idx]
        local hub = fiber_strand.hubs[idx] and fiber_strand.hubs[idx].hub

        if iopin and iopin.valid and hub and hub.valid then
            for _, circuit in pairs { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green } do
                local pin_connector = assert(iopin.get_wire_connector(circuit, true))
                local hub_connector = assert(hub.get_wire_connector(circuit, true))
                pin_connector.connect_to(hub_connector, false, defines.wire_origin.script)
            end
        end
    end
end

---@param network_id integer
---@param fo_entity fo.FiberOptics
function Network:disconnectEntity(network_id, fo_entity)
    local main = fo_entity.main
    if not (main and main.valid) then return end

    local surface_network = self:locateSurfaceNetwork(main.surface_index)
    local fiber_network = surface_network[network_id]
    if not fiber_network then return end

    local fiber_strand = fiber_network['default']
    if not fiber_strand then return end

    -- disconnect each IO pin from its hub
    for idx = 1, const.max_hub_count do
        local iopin = fo_entity.iopin[idx]
        local hub = fiber_strand.hubs[idx] and fiber_strand.hubs[idx].hub

        if iopin and iopin.valid and hub and hub.valid then
            for _, circuit in pairs { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green } do
                local pin_connector = assert(iopin.get_wire_connector(circuit, true))
                local hub_connector = assert(hub.get_wire_connector(circuit, true))
                pin_connector.disconnect_from(hub_connector, defines.wire_origin.script)
            end
        end
    end

    -- remove endpoint
    if fiber_strand.endpoints[main.unit_number] then
        fiber_strand.endpoints[main.unit_number] = nil
        fiber_strand.endpoint_count = fiber_strand.endpoint_count - 1
    end

    -- destroy network if no endpoints remain
    if fiber_strand.endpoint_count <= 0 then
        self:destroyFiberNetwork(main, network_id)
    end
end

------------------------------------------------------------------------
-- ticker
------------------------------------------------------------------------

function Network:tick()
    local ticker = helpers:getTicker('network')

    --- interval per network refresh
    local interval = Framework.settings:startup_setting(const.settings_names.network_refresh) or 60

    local network_count = count_networks()
    if network_count == 0 then return end
    -- interval = 60, 5 networks -> run every 12 ticks
    -- interval = 30, 10 networks -> run every three ticks
    -- interval = 20, 40 networks -> run every tick
    -- interval = 10, 100 networks -> run every tick
    local ticks_per_network = math.max(1, math.floor(interval / network_count)) -- at least one

    if ticker.last_tick + ticks_per_network > game.tick then return end
    -- interval = 60, 5 networks -> 1 network per process (every 12 ticks)
    -- interval = 30, 10 networks = 1 network per process (every three ticks)
    -- interval = 20, 40 networks = 2 networks per process (every tick)
    -- interval = 10, 100 networks = 10 networks per process (every tick)
    local process_count = math.ceil(network_count / interval)

    local surface_networks = self:allSurfaceNetworks()
    local index = ticker.last_tick_index or {}

    if not (index.surface_index and surface_networks[index.surface_index]) then index = {} end
    if not (index.network_index and surface_networks[index.surface_index][index.network_index]) then index = {} end

    if process_count > 0 then
        repeat
            local surface_network
            index.surface_index, surface_network = next(surface_networks, index.surface_index)
            if not index.surface_index then index.surface_index, surface_network = next(surface_networks, index.surface_index) end
            if surface_network then
                repeat
                    local fiber_network
                    index.network_index, fiber_network = next(surface_network, index.network_index)
                    if not index.network_index then index.network_index, fiber_network = next(surface_network, index.network_index) end

                    if fiber_network then
                        for _, fiber_strand in pairs(fiber_network) do
                            -- validate all endpoints on this fiber strand
                            for id, endpoint in pairs(fiber_strand.endpoints) do
                                if not (endpoint and endpoint.valid) then
                                    fiber_strand.endpoints[id] = nil
                                    fiber_strand.endpoint_count = fiber_strand.endpoint_count - 1
                                end
                            end

                            if fiber_strand.endpoint_count < 0 then
                                fiber_strand.endpoint_count = 0
                            end

                            process_count = process_count - 1
                        end
                    end
                until process_count == 0 or not index.network_index
            end
        until process_count == 0 or not index.surface_index
    else
        index = nil
    end

    ticker.last_tick_index = index
    ticker.last_tick = game.tick
end

return Network
