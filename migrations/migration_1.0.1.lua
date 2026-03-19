------------------------------------------------------------------------
-- Minor tweaks from the development version
------------------------------------------------------------------------

-- don't bother with 1.x
if storage.oc_data then return end

This:init()

local internal_cfg = This.fo.INTERNAL_CFG[2]

for _, fo_entity in pairs(This.storage().fo) do
    if not (fo_entity.internal.power and fo_entity.internal.power.valid) then
        fo_entity.internal.power.destroy()

        local pos = {
            x = fo_entity.main.position.x + internal_cfg.x / 64,
            y = fo_entity.main.position.y + internal_cfg.y / 64,
        }

        fo_entity.internal.power = This.fo:createInternal {
            main = fo_entity.main,
            name = internal_cfg.name,
            pos = pos,
        }
    end
end
