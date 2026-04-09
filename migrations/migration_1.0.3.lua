------------------------------------------------------------------------
-- Minor tweaks from the development version
------------------------------------------------------------------------

local const = require('lib.constants')

-- don't bother with 1.x
if storage.oc_data then return end

This:init()

for _, fo_entity in pairs(This.fo:getAllEntities()) do
    fo_entity.config.descriptions = fo_entity.config.descriptions or {}
    fo_entity.state.networks = {}
    fo_entity.networks = nil
end
