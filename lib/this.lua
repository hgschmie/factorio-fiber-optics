----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class ModThis
---@field other_mods string[]
---@field oc ModOc
---@field network FiberNetworkManager
local This = {
    other_mods = { 'PickerDollies' },

    oc = require('scripts.oc'),
    network = require('scripts.network'),
}

----------------------------------------------------------------------------------------------------

return This
