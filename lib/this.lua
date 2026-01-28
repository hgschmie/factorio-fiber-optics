----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class fo.Mod
---@field other_mods table<string, string>
---@field fo fo.Fo
---@field pin fo.Pin
---@field other fo.Other
This = {
    other_mods = {
        ['even-pickier-dollies'] = 'epd',
    },
}

if script then
    This.fo = require('scripts.fo')
    This.pin = require('scripts.pin')
    This.other = require('scripts.other')
end

--- Setup the global optical connector data structure.
function This:init()
    if storage.fo_data then return end

    ---@type fo.Storage
    storage.fo_data = {
        fo = {},
        fo_count = 0,
        iopins = {},
        iopin_count = 0,
        attached_entities = {},
    }
end

---@return fo.Storage
function This.storage()
    return assert(storage.fo_data)
end

return This
