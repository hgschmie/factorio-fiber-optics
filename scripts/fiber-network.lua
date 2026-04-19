------------------------------------------------------------------------
-- Manage Fiber Networks
------------------------------------------------------------------------
assert(script)

require('stdlib.utils.string')

local const = require('lib.constants')

local helpers = require('scripts.helpers')

local DEBUG_MODE = Framework.settings:startup_setting('debug_mode')
local WIRE_TYPE = DEBUG_MODE and defines.wire_origin.player or defines.wire_origin.script
local HUB_ENTITY_NAME = DEBUG_MODE and const.debug_name(const.fiber_hub_name) or const.fiber_hub_name

---@class fo.Network
local Network = {}

---@param prefix string
---@param format_func fun(...: any?):string
local function debug_print(prefix, format_func)
    if not DEBUG_MODE then return end

    prefix = assert(prefix):ljust(18, ' ')
    game.print(('[font=debug-mono][fiber-optics][%s][%s][/font] %s'):format(const.formatTime(game.tick), prefix, format_func()),
        { sound = defines.print_sound.never, skip = defines.print_skip.never })
end

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
        for _, fiber_strands in pairs(surface_network) do
            count = count + table_size(fiber_strands)
        end
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
function Network:deleteSurfaceNetwork(surface_index)
    local all_surface_networks = self:allSurfaceNetworks()
    if not all_surface_networks[surface_index] then return end
    for _, fiber_network in pairs(all_surface_networks[surface_index]) do
        self:destroyNetwork(fiber_network)
    end
    all_surface_networks[surface_index] = nil
end

---@param surface_index integer
---@param strand_index integer
---@return fo.FiberStrand fiber_strand
local function create_fiber_strand(surface_index, strand_index)
    local neutral_force = assert(game.forces['neutral'])

    ---@type fo.FiberHub[]
    local hubs = {}

    local surface = assert(game.surfaces[surface_index])

    for idx = 1, const.max_hub_count, 1 do
        hubs[idx] = {
            hub = surface.create_entity {
                name = HUB_ENTITY_NAME,
                -- spread out for debugging visibility
                position = DEBUG_MODE and { x = idx * 4, y = strand_index * 4 } or { x = 0, y = 0 },
                force = neutral_force,
            },
        }
        hubs[idx].hub.operable = false
    end

    return {
        endpoint_count = 0,
        endpoints = {},
        hubs = hubs,
    }
end

---@class fo.FiberNetworkArgs
---@field surface_index integer
---@field network_id integer
---@field strand_name string?
---@field create boolean?


-- Retrieves an existing or creates a new fiber network. A fiber network always has a default strand and may have more strands.
---@param args fo.FiberNetworkArgs
---@return fo.FiberNetwork?
function Network:getOrCreateFiberNetwork(args)
    local surface_network = self:locateSurfaceNetwork(args.surface_index)

    if not surface_network[args.network_id] then
        if not args.create then return nil end

        debug_print('Create Network', function()
            return ('Creating surface network %d on surface %d'):format(args.network_id, args.surface_index)
        end)
    end

    surface_network[args.network_id] = surface_network[args.network_id] or {
        default = create_fiber_strand(args.surface_index, 0) -- default is always strand index 0
    }

    return surface_network[args.network_id]
end

--- returns a specific fiber strand for a given entity to connect to. If the strand does not exist, it will be created.
---@param args fo.FiberNetworkArgs
---@return fo.FiberNetwork? fiber_network
function Network:locateFiberStrand(args)
    if not args.strand_name then return nil end

    local fiber_network = self:getOrCreateFiberNetwork(args)

    if not fiber_network then return nil end

    if not fiber_network[args.strand_name] then
        debug_print('Create Fiber Strand', function()
            return ('Creating Fiber Strand %s for network %d on surface %d'):format(args.strand_name, args.network_id, args.surface_index)
        end)

        if args.create then
            fiber_network[args.strand_name] = create_fiber_strand(args.surface_index, table_size(fiber_network))
        end
    end

    return fiber_network[args.strand_name]
end

---@param fo_entity fo.FiberOptics Entity used to determine the surface and networks to delete
---@param strand_name string
function Network:destroyFiberStrandAndReconnectEntities(fo_entity, strand_name)
    if strand_name == 'default' then return end -- default network is never deleted

    local main = fo_entity.main
    if not (main and main.valid) then return end

    local surface_network = self:locateSurfaceNetwork(main.surface_index)

    local entities_to_update = {}

    for _, network_id in pairs(fo_entity.state.networks) do
        local fiber_strand = surface_network[network_id] and surface_network[network_id][strand_name]
        if fiber_strand then
            for _, endpoint in pairs(fiber_strand.endpoints) do
                if endpoint.valid then
                    local endpoint_entity = This.fo:getEntity(endpoint.unit_number)
                    if endpoint_entity then
                        endpoint_entity.state.strand_names[network_id] = nil
                        entities_to_update[endpoint.unit_number] = true
                    end
                end
            end

            for _, hub in pairs(fiber_strand.hubs) do
                if hub.hub.valid then hub.hub.destroy() end
            end

            surface_network[network_id][strand_name] = nil

            debug_print('Remove Fiber Strand', function()
                return ('Removed Fiber Strand %s from network %d on surface %d'):format(strand_name, network_id, main.surface_index)
            end)
        end
    end

    for entity_id in pairs(entities_to_update) do
        local endpoint_entity = assert(This.fo:getEntity(entity_id))
        endpoint_entity.config.strand_name = 'default'
        This.fo:updateEntityStatus(endpoint_entity)
    end
end

---@param surface_index integer
---@param network_id integer
---@param strand_name string
---@return integer endpoint_count
function Network:getEndpointCount(surface_index, network_id, strand_name)
    local surface_network = self:locateSurfaceNetwork(surface_index)
    if not (surface_network[network_id] and surface_network[network_id][strand_name]) then return 0 end
    return surface_network[network_id][strand_name].endpoint_count
end

------------------------------------------------------------------------
-- entity connect / disconnect
------------------------------------------------------------------------

---@param network_id integer
---@param fo_entity fo.FiberOptics
---@return boolean connection_changed True if entity connected to the network.
function Network:connectEntity(network_id, fo_entity)
    local main = fo_entity.main
    if not (main and main.valid) then return false end

    local fiber_strand = self:locateFiberStrand {
        surface_index = main.surface_index,
        network_id = network_id,
        strand_name = fo_entity.config.strand_name,
        create = true
    }

    if not fiber_strand then return false end

    -- register as endpoint
    if fiber_strand.endpoints[main.unit_number] then return false end

    fiber_strand.endpoint_count = fiber_strand.endpoint_count + 1
    fiber_strand.endpoints[main.unit_number] = main

    fo_entity.state.strand_names[network_id] = fo_entity.config.strand_name

    debug_print('Connect Entity', function()
        return ('Connected Entity %d to network %d/%s'):format(main.unit_number, network_id, fo_entity.config.strand_name)
    end)

    return true
end

---@param network_id integer
---@param fo_entity fo.FiberOptics
---@return boolean disconnected True if the entity disconnected
function Network:disconnectEntity(network_id, fo_entity)
    local main = fo_entity.main
    if not (main and main.valid) then return false end

    local strand_name = fo_entity.state.strand_names[network_id]
    fo_entity.state.strand_names[network_id] = nil

    -- if the network is gone, don't bother with the fiber strand
    local fiber_strand = self:locateFiberStrand {
        surface_index = main.surface_index,
        network_id = network_id,
        strand_name = strand_name,
    }

    if not (fiber_strand and fiber_strand.endpoints[main.unit_number]) then return false end

    fiber_strand.endpoints[main.unit_number] = nil
    fiber_strand.endpoint_count = fiber_strand.endpoint_count - 1

    self:updateFiberStrandConnections(network_id, fo_entity, fiber_strand)

    debug_print('Disconnect Entity', function()
        return ('Disconnected Entity %d from network %d/%s'):format(main.unit_number, network_id, strand_name)
    end)

    return true
end

---@param network_id integer
---@param fo_entity fo.FiberOptics
---@param fiber_strand fo.FiberStrand?
---@return boolean changed True if any connection changed
function Network:updateFiberStrandConnections(network_id, fo_entity, fiber_strand)
    local main = fo_entity.main
    if not (main and main.valid) then return false end

    -- can be nil (if called from disconnectEntity and a fiber_strand was passed in)
    local strand_name = fo_entity.state.strand_names[network_id]
    assert(strand_name or fiber_strand)

    fiber_strand = assert(fiber_strand or self:locateFiberStrand {
        surface_index = main.surface_index,
        network_id = network_id,
        strand_name = strand_name,
        create = true
    })

    local result = false
    -- wire each IO pin to its corresponding hub
    for idx = 1, const.max_hub_count do
        local iopin = fo_entity.iopin[idx]
        local hub = fiber_strand.hubs[idx].hub

        if iopin and iopin.valid and hub and hub.valid then
            for _, circuit in pairs { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green } do
                local pin_connector = assert(iopin.get_wire_connector(circuit, true))
                local hub_connector = assert(hub.get_wire_connector(circuit, true))

                local is_connected = pin_connector.is_connected_to(hub_connector, defines.wire_origin.player)
                    or pin_connector.is_connected_to(hub_connector, defines.wire_origin.script)

                -- only connect if the connector is enabled, a strand name is present and a connection was requested
                if fo_entity.config.enabled and strand_name and fo_entity.config.connected_pins[circuit][idx] then
                    if not is_connected then
                        pin_connector.connect_to(hub_connector, false, WIRE_TYPE)
                        result = true
                    end
                elseif is_connected then
                    -- disconnect both player and script wires (debug mode creates player wires)
                    pin_connector.disconnect_from(hub_connector, defines.wire_origin.player)
                    pin_connector.disconnect_from(hub_connector, defines.wire_origin.script)
                    result = true
                end
            end
        end
    end

    return result
end

---@param fiber_strand fo.FiberStrand
function Network:disconnectAllEntities(fiber_strand)
    for _, hub in pairs(fiber_strand.hubs) do
        if (hub.hub and hub.hub.valid) then
            for _, circuit in pairs { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green } do
                local hub_connector = assert(hub.hub.get_wire_connector(circuit, true))
                hub_connector.disconnect_all(defines.wire_origin.player)
                hub_connector.disconnect_all(defines.wire_origin.script)
            end
        end
    end

    fiber_strand.endpoint_count = 0
    fiber_strand.endpoints = {}
end

---@param fiber_network fo.FiberNetwork
function Network:destroyNetwork(fiber_network)
    for strand_name, fiber_strand in pairs(fiber_network) do
        for _, hub in pairs(fiber_strand.hubs) do
            if (hub.hub and hub.hub.valid) then hub.hub.destroy() end
        end
        fiber_strand.endpoints = {}
        fiber_strand.endpoint_count = 0
        fiber_network[strand_name] = nil
    end
end

------------------------------------------------------------------------
-- ticker
------------------------------------------------------------------------

---@param keys helper.TickerContext
---@param values helper.TickerContext
---@return any
local function ticker_unit_of_work(keys, values)
    local fiber_strand = assert(values.strand_name)

    if table_size(fiber_strand.endpoints) == 0 then
        fiber_strand.endpoint_count = 0
    else
        -- validate all endpoints on this fiber strand
        for id, endpoint in pairs(fiber_strand.endpoints) do
            if not (endpoint and endpoint.valid) then
                fiber_strand.endpoints[id] = nil
                fiber_strand.endpoint_count = fiber_strand.endpoint_count - 1
            end
        end
    end
end


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

    local context = ticker.last_tick_context or {}

    local surfaceIterator = helpers.createWorkIterator {
        context = context,
        field_name = 'surface_index',
        iterable = self:allSurfaceNetworks(),
        sub_iterator = helpers.createWorkIterator {
            context = context,
            field_name = 'network_index',
            sub_iterator = helpers.createWorkIterator {
                context = context,
                field_name = 'strand_name',
            },
        },
    }

    while process_count > 0 do
        surfaceIterator.process(ticker_unit_of_work)
        process_count = process_count - 1
    end

    ticker.last_tick_context = context
    ticker.last_tick = game.tick
end

return Network
