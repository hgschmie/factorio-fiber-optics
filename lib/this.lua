----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class fo.Mod
---@field fo fo.Fo
---@field pin fo.Pin
This = {
}

if script then
    This.fo = require('scripts.fo')
    This.pin = require('scripts.pin')
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
    }
end

---@return fo.Storage
function This.storage()
    return assert(storage.fo_data)
end

return This
