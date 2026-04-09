----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class fo.Mod
---@field other_mods table<string, string>
---@field fo fo.Fo
---@field pin fo.FoPin
---@field other fo.Other
---@field network fo.Network
---@field gui fo.Gui
---@field desc_gui fo.DescGui
---@field console fo.Console
This = {
    other_mods = {
        ['even-pickier-dollies'] = 'epd',
    },
}

if script then
    This.fo = require('scripts.fo')
    This.pin = require('scripts.pin')
    This.other = require('scripts.other')
    This.network = require('scripts.fiber-network')
    This.gui = require('scripts.gui')
    This.desc_gui = require('scripts.desc-gui')
    This.console = require('scripts.console')
end

--- Setup the global optical connector data structure.
function This:init()
    if storage.fo_data then return end

    ---@type fo.Storage
    storage.fo_data = {
        -- connector entities
        fo = {},
        fo_count = 0,
        attached_entities = {},
        -- iopins and iopin mappings
        iopins = {},
        iopin_count = 0,
        -- network configuration
        surface_networks = {},
    }

    ---@type table<string, helper.TickerContext>
    storage.ticker = {}
end

Framework.settings:add_defaults(require('lib.settings'))

---@return fo.Storage
function This.storage()
    return assert(storage.fo_data)
end

return This
