------------------------------------------------------------------------
-- Minor tweaks from the development version
------------------------------------------------------------------------

local const = require('lib.constants')

-- don't bother with 1.x
if storage.oc_data then return end

This:init()

for _, fo_entity in pairs(This.fo:getAllEntities()) do
    fo_entity.config.descriptions = fo_entity.config.descriptions or {}
end

-- for _, surface_network in pairs(This.network:allSurfaceNetworks()) do
--     for _, fiber_network in pairs(surface_network) do
--         for _, fiber_strand in pairs(fiber_network) do
--             for _, hub in pairs(fiber_strand.hubs) do
--                 hub.description = hub.description or {
--                     title = '',
--                     body = '',
--                 }
--             end
--         end
--     end
-- end
