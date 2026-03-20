------------------------------------------------------------------------
-- Minor tweaks from the development version
------------------------------------------------------------------------

local const = require('lib.constants')

-- don't bother with 1.x
if storage.oc_data then return end

This:init()

-- remove all existing power interfaces
for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered {
        name = const.power_interface_name
    }
    for _, entity in pairs(entities) do
        entity.destroy()
    end
end

local internal_cfg = This.fo.INTERNAL_CFG[2]

for _, fo_entity in pairs(This.fo:getAllEntities()) do
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
