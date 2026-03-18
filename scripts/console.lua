--------------------------------------------------------------------------------
-- custom commands
--------------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')

local table = require('stdlib.utils.table')
local string = require('stdlib.utils.string')

local const = require('lib.constants')

---@class fo.Console
local Console = {}


---@param data CustomCommandData
local function resync(data)
    local strand_count = 0
    local entity_count = 0

    for _, surface_network in pairs(This.network:allSurfaceNetworks()) do
        for _, fiber_network in pairs(surface_network) do
            for _, fiber_strand in pairs(fiber_network) do
                This.network:disconnectAllEntities(fiber_strand)
                strand_count = strand_count + 1
            end
        end
    end

    for _, fo_entity in pairs(This.fo:getAllEntities()) do
        This.fo:updateEntityStatus(fo_entity, true)
        entity_count = entity_count + 1
    end

    game.print { const:locale('command_fo_resync_result'), entity_count, strand_count }
end

---@param data CustomCommandData
local function prune_networks(data)
    local network_count = 0

    for surface_index, surface_network in pairs(This.network:allSurfaceNetworks()) do
        local known_networks = {}
        for _, e in pairs (game.surfaces[surface_index].find_entities_filtered { type = 'electric-pole' }) do
            known_networks[e.electric_network_id] = true
        end
        for network_id, fiber_network in pairs(surface_network) do
            if not known_networks[network_id] then
                local fiber_strands = (', '):join(table.keys(fiber_network, true, true))
                game.print { const:locale('command_fo_prune_networks_pruning'), game.surfaces[surface_index].name, network_id, fiber_strands }
                This.network:destroyNetwork(fiber_network)
                surface_network[network_id] = nil

                network_count = network_count + 1
            end
        end
    end

    game.print { const:locale('command_fo_prune_networks_result'), network_count }
end

function Console:register_commands()
    commands.add_command('fiber-optics-resync', { const:locale('command_fo_resync') }, resync)
    commands.add_command('fiber-optics-prune-networks', { const:locale('command_fo_prune_networks') }, prune_networks)
end

--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------

local function on_init()
    Console:register_commands()
end

local function on_load()
    Console:register_commands()
end

Event.on_init(on_init)
Event.on_load(on_load)

return Console
