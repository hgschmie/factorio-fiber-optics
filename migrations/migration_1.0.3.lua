------------------------------------------------------------------------
-- Minor tweaks from the development version
------------------------------------------------------------------------

local const = require('lib.constants')

-- don't bother with 1.x
if storage.oc_data then return end

This:init()

local storage = This:storage()

storage.iopins = {}
storage.iopin_count = 0

for idx, fo_entity in pairs(This.fo:getAllEntities()) do
    fo_entity.config.descriptions = fo_entity.config.descriptions or {}
    fo_entity.state.networks = {}
    fo_entity.networks = nil

    for idx2, pin in pairs(fo_entity.iopin) do
        storage.iopins[pin.unit_number] = {
            index = idx2,
            entity_id = idx
        }
    end
end
