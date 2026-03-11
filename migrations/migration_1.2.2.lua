-----------------------------------------------------------------------
-- make internal entities not operable
-----------------------------------------------------------------------

for _, oc_entity in pairs(This.oc:entities()) do
    if oc_entity.main and oc_entity.main.valid then
        oc_entity.ref.power_pole.operable = false
        for _, entity in pairs(oc_entity.iopin) do
            entity.operable = false
        end
    end
end
