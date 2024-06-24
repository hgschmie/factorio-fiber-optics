----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@type ModThis
local This = {
    other_mods = { 'PickerDollies', 'space-exploration' },
    debug_mode = 0, -- bit 0 (0/1): network debug, bit 1 (0/2): entity debug

    oc = require('scripts.oc'),
    network = require('scripts.network'),
    blueprint = require('scripts.blueprint'),
    attached_entities = require('scripts.attached-entities')
}

----------------------------------------------------------------------------------------------------

return This
