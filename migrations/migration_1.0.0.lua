------------------------------------------------------------------------
-- Minor tweaks from the development version
------------------------------------------------------------------------

-- don't bother with 1.x
if storage.oc_data then return end

This:init()

for _, fo_entity in pairs(This.storage().fo) do
    fo_entity.config = fo_entity.config or This.fo.DEFAULT_CONFIG
end
