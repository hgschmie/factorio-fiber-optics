----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class ModThis
---@field other_mods string[]
---@field debug_mode integer
---@field oc ModOc
---@field network FiberNetworkManager
---@field blueprint FiberNetworkBlueprint
---@field attached_entities FiberNetworkAttachedEntities
local This = {
    other_mods = { 'PickerDollies' },
    debug_mode = 0, -- bit 0 (0/1): network debug, bit 1 (0/2): entity debug

    oc = require('scripts.oc'),
    network = require('scripts.network'),
    blueprint = require('scripts.blueprint'),
    attached_entities = require('scripts.attached-entities')
}

----------------------------------------------------------------------------------------------------

return This
