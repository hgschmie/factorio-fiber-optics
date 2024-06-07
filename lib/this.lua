----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class ModThis
---@field other_mods string[]
---@field oc ModOc
---@field context_manager ModContext
---@field network ModNetwork
local This = {
    other_mods = { 'PickerDollies' },

    oc = require('scripts.oc'),
    context_manager = require('lib.context'),
    network = require('scripts.network'),
}

----------------------------------------------------------------------------------------------------

return This
