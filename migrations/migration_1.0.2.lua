------------------------------------------------------------------------
-- Minor tweaks from the development version
------------------------------------------------------------------------

local const = require('lib.constants')

-- don't bother with 1.x
if storage.oc_data then return end

This:init()

local connected_pins = This.fo:getDefaultConfig().connected_pins

for _, fo_entity in pairs(This.fo:getAllEntities()) do
    for _, internal_cfg in pairs(This.fo.INTERNAL_CFG) do
        local pos = {
            x = fo_entity.main.position.x + internal_cfg.x / 64,
            y = fo_entity.main.position.y + internal_cfg.y / 64,
        }

        fo_entity.internal[internal_cfg.id].teleport(pos)
    end
    This.fo:configureLed(fo_entity, 1)
    This.fo:configureLed(fo_entity, 2)

    local power_signal = { type = 'virtual', name = 'signal-E', quality = 'normal', }
    local power_control = assert(fo_entity.internal.power.get_or_create_control_behavior()) --[[@as LuaLampControlBehavior]]
    power_control.circuit_enable_disable = true
    power_control.circuit_condition = { comparator = '>', first_signal = power_signal, constant = 0, } --[[@as CircuitConditionDefinition ]]

    fo_entity.config.connected_pins = fo_entity.config.connected_pins or util.copy(connected_pins)

    This.fo:updateEntityStatus(fo_entity, true)
end
