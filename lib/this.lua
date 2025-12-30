----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class fo.Mod
---@field fo fo.FiberOptics
This = {
}

if script then
    This.fo = require('scripts.fo')
end

return This
