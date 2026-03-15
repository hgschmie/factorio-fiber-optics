------------------------------------------------------------------------
-- Manage Fiber Networks
------------------------------------------------------------------------
assert(script)

local const = require('lib.constants')

local helpers = require('scripts.helpers')


local debug_mode = Framework.settings:startup_setting('debug_mode')

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
---@param strand_index integer
---@return fo.FiberStrand fiber_strand
local function create_fiber_strand(surface_index, force_id, strand_index)
    ---@type fo.FiberHub[]
    local hubs = {}

    local surface = assert(game.surfaces[surface_index])
    local force = assert(game.forces[force_id])

    local hub_entity_name = debug_mode and const.debug_name(const.fiber_hub_name) or const.fiber_hub_name

    for idx = 1, const.max_hub_count, 1 do
        hubs[idx] = {
            hub = surface.create_entity {
                name = hub_entity_name,
                -- spread out for debugging visibility
                position = { x = idx * 4, y = strand_index * 4 },
                force = force,
            }
        }
        hubs[idx].hub.operable = false
    end

    return {
        endpoint_count = 0,
        endpoints = {},
        hubs = hubs,
    }
end

-- Retrieves an existing or creates a new fiber network. A fiber network always has a default strand and may have more strands.
---@param surface_index integer
---@param force_id integer
---@param network_id integer
---@return fo.FiberNetwork
function Network:getOrCreateFiberNetwork(surface_index, force_id, network_id)
    local surface_network = self:locateSurfaceNetwork(surface_index)

    surface_network[network_id] = surface_network[network_id] or {
        default = create_fiber_strand(surface_index, force_id, 0) -- default is always strand index 0
    }

    return surface_network[network_id]
end

--- returns a specific fiber strand for a given entity to connect to. If the strand does not exist, it will be created.
---@param entity LuaEntity
---@param network_id integer
---@param strand_name string
---@return fo.FiberNetwork fiber_network
function Network:locateFiberStrand(entity, network_id, strand_name)
    local surface_index = entity.surface_index

    local fiber_network = self:getOrCreateFiberNetwork(surface_index, entity.force_index, network_id)
    fiber_network[strand_name] = fiber_network[strand_name] or create_fiber_strand(surface_index, entity.force_index, table_size(fiber_network))

    return fiber_network[strand_name]
end

---@param surface_index integer
---@param network_id integer
---@param strand_name string
function Network:destroyFiberStrand(surface_index, network_id, strand_name)
    if strand_name == 'default' then return end -- default network is never deleted

    local surface_network = self:locateSurfaceNetwork(surface_index)
    if not surface_network[network_id] then return end

    local fiber_strand = surface_network[network_id][strand_name]
    if not fiber_strand then return end

    if fiber_strand.endpoint_count > 0 then
        Framework.logger:logf("Shutting down fiber strand '%d/%s' with %d remaining endpoints!", network_id, strand_name, fiber_strand.endpoint_count)
    end

    for _, hub in pairs(fiber_strand.hubs) do
        if (hub.hub and hub.hub.valid) then hub.hub.destroy() end
    end

    surface_network[network_id][strand_name] = nil
end

------------------------------------------------------------------------
-- entity connect / disconnect
------------------------------------------------------------------------

---@param network_id integer
---@param fo_entity fo.FiberOptics
function Network:connectEntity(network_id, fo_entity)
    local main = fo_entity.main
    if not (main and main.valid) then return end

    assert(not fo_entity.state.strand_name)

    local fiber_strand = self:locateFiberStrand(main, network_id, fo_entity.config.strand_name)

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
                pin_connector.connect_to(hub_connector, false, debug_mode and defines.wire_origin.player or defines.wire_origin.script)
            end
        end
    end

    fo_entity.state.strand_name = fo_entity.config.strand_name
end

---@param network_id integer
---@param fo_entity fo.FiberOptics
function Network:disconnectEntity(network_id, fo_entity)
    local main = fo_entity.main
    if not (main and main.valid) then return end

    if not fo_entity.state.strand_name then return end

    local fiber_strand = self:locateFiberStrand(main, network_id, fo_entity.config.strand_name)

    -- disconnect each IO pin from its hub
    for idx = 1, const.max_hub_count do
        local iopin = fo_entity.iopin[idx]
        local hub = fiber_strand.hubs[idx] and fiber_strand.hubs[idx].hub

        if iopin and iopin.valid and hub and hub.valid then
            for _, circuit in pairs { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green } do
                local pin_connector = assert(iopin.get_wire_connector(circuit, true))
                local hub_connector = assert(hub.get_wire_connector(circuit, true))
                pin_connector.disconnect_from(hub_connector)
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
        self:destroyFiberStrand(main.surface_index, network_id, fo_entity.config.strand_name)
    end

    fo_entity.state.strand_name = nil
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
    if not (index.strand_name and surface_networks[index.surface_index][index.network_index][index.strand_name]) then index = {} end

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
                        repeat
                            local fiber_strand
                            index.strand_name, fiber_strand = next(fiber_network, index.strand_name)
                            if not index.strand_name then index.strand_name, fiber_strand = next(fiber_network, index.strand_name) end
                            if fiber_strand then
                                -- validate all endpoints on this fiber strand
                                for id, endpoint in pairs(fiber_strand.endpoints) do
                                    if not (endpoint and endpoint.valid) then
                                        fiber_strand.endpoints[id] = nil
                                        fiber_strand.endpoint_count = fiber_strand.endpoint_count - 1
                                    end
                                end

                                if fiber_strand.endpoint_count <= 0 then
                                    This.network:destroyFiberStrand(index.surface_index, index.network_index, index.strand_name)
                                end

                                process_count = process_count - 1
                            end
                        until process_count <= 0 or not index.strand_name
                    end
                until process_count <= 0 or not index.network_index
            end
        until process_count <= 0 or not index.surface_index
    else
        index = nil
    end

    ticker.last_tick_index = index
    ticker.last_tick = game.tick
end

return Network
