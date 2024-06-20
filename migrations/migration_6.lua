--------------------------------------------------------------------------------
-- migration 6
--------------------------------------------------------------------------------
-- replace all the iopin_<x> units with a single iopin
--------------------------------------------------------------------------------

require('lib.init')

if global.oc_networks.VERSION > 5 and global.oc_data.VERSION > 5 then return end

local Is = require('__stdlib__/stdlib/utils/is')

local const = require('lib.constants')
local oc = require('scripts.oc')

global.oc_data.iopins = global.oc_data.iopins or {}

for _, oc_entity in pairs(oc:entities()) do
    oc_entity.iopin = oc_entity.iopin or {}

    for idx = 1, const.oc_iopin_count, 1 do
        local iopin_ref = 'iopin' .. idx
        local entity = oc_entity.ref[iopin_ref]

        if Is.Valid(entity) then
            if entity.type == 'lamp' then
                local iopin_entity = oc.create_internal_entity {
                    entity = oc_entity,
                    name = (idx == 1) and const.iopin_one_name or const.iopin_name,
                    pos = entity.position,
                }

                if entity.circuit_connection_definitions then
                    for _, circuit_connection_definition in pairs(entity.circuit_connection_definitions) do
                        local target_entity = circuit_connection_definition.target_entity
                        local target_pos = target_entity.position
                        target_entity.teleport(iopin_entity.position)

                        assert(iopin_entity.connect_neighbour {
                            wire = circuit_connection_definition.wire,
                            target_entity = circuit_connection_definition.target_entity,
                            source_circuit_id = circuit_connection_definition.source_circuit_id,
                            target_circuit_id = circuit_connection_definition.target_circuit_id,
                        })

                        target_entity.teleport(target_pos)
                    end
                end

                oc_entity.entities[entity.unit_number] = nil
                entity.destroy()

                oc_entity.ref[iopin_ref] = nil
                oc_entity.iopin[idx] = iopin_entity

                oc:setIOPin(iopin_entity.unit_number, oc_entity.main.unit_number)
            else
                oc:setIOPin(entity.unit_number, oc_entity.main.unit_number)
            end
        end
    end
end

global.oc_networks.VERSION = 6
global.oc_data.VERSION = 6