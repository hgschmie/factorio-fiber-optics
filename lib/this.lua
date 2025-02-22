----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class FiberOpticsMod
---@field other_mods string[]
---@field debug_mode integer
---@field oc ModOc
---@field network FiberNetworkManager
---@field blueprint FiberNetworkBlueprint
---@field attached_entities fiber_optics.AttachedEntitiesManager
This = {
    other_mods = {
        PickerDollies = 'PickerDollies',
        ['even-pickier-dollies'] = 'PickerDollies',
    },
    debug_mode = 0, -- bit 0 (0/1): network debug, bit 1 (0/2): entity debug
}

if script then
    This.oc = require('scripts.oc')
    This.network = require('scripts.network')
    This.blueprint = require('scripts.blueprint')
    This.attached_entities = require('scripts.attached-entities')
end

return This
