------------------------------------------------------------------------
-- Migrate old OCs to Version 2
------------------------------------------------------------------------

local Direction = require('stdlib.area.direction')

local const = require('lib.constants')

This:init()

-- migrate 1.x entities
if storage.oc_data then
    for _, oc_entity in pairs(storage.oc_data.oc) do
        oc_entity.ref.power_pole.operable = false

        local attached_entities = {
            [const.powerpole_name] = { entity = oc_entity.ref.power_pole },
        }

        oc_entity.entities[oc_entity.ref.power_pole.unit_number] = nil
        oc_entity.ref.power_pole = nil

        for idx, entity in pairs(oc_entity.iopin) do
            assert(entity.type == 'container', 'This is an extremely old save. Migrate it to Factorio 2.0 first by using the latest fiber-optics 1.x release.')
            entity.operable = false
            attached_entities[idx] = { entity = entity }

            oc_entity.entities[entity.unit_number] = nil
            oc_entity.iopin[idx] = nil
        end

        -- correct direction for entity creation
        local h_flipped = bit32.band(oc_entity.flip_index - 1, 1) == 1
        local v_flipped = bit32.band(oc_entity.flip_index - 1, 2) == 2

        local reverse = h_flipped ~= v_flipped
        local direction = reverse and Direction.previous(oc_entity.main.direction) or oc_entity.main.direction

        oc_entity.main.direction = direction

        local cfg = {
            main = oc_entity.main,
            attached_entities = attached_entities,
            attached_ghosts = {},
            h_flipped = h_flipped,
            v_flipped = v_flipped,
        }

        local fo_entity = This.fo:create(cfg)
        This.fo:updateEntityStatus(fo_entity)

        oc_entity.main = nil

        for _, entity in pairs(oc_entity.entities) do
            entity.destroy()
        end
    end
end

storage.oc_data = nil
storage.oc_networks = nil
