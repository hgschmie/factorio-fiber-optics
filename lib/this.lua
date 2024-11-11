----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@type FiberOpticsThis
local This = {
    other_mods = {
        PickerDollies = 'PickerDollies',
        ['even-pickier-dollies'] = 'PickerDollies',
        ['space-exploration'] = 'space-exploration'
    },
    debug_mode = 0, -- bit 0 (0/1): network debug, bit 1 (0/2): entity debug

    oc = require('scripts.oc'),
    network = require('scripts.network'),
    blueprint = require('scripts.blueprint'),
    attached_entities = require('scripts.attached-entities')
}

----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
return function(stage)
    if This['this_' .. stage] then
        This['this_' .. stage](This)
    end

    return This
end