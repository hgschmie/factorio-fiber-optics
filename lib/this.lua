----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

local const = require('lib.constants')

---@class fo.Mod
---@field remote_apis table<string, string>
---@field settings ff2.ModSettings
---@field fo fo.Fo
---@field pin fo.FoPin
---@field other fo.Other
---@field network fo.Network
---@field gui fo.Gui
---@field desc_gui fo.DescGui
---@field console fo.Console
local This = {
    remote_apis = {
        PickerDollies = 'picker-dollies',
    },
    settings = require('lib.settings'),
}

function This.boot()
    This.fo = require('scripts.fo')
    This.pin = require('scripts.pin')
    This.other = require('scripts.other')
    This.network = require('scripts.fiber-network')
    This.gui = require('scripts.gui')
    This.desc_gui = require('scripts.desc-gui')
    This.signal_gui = require('scripts.signal-gui')
    This.console = require('scripts.console')
end

--------------------------------------------------------------------------------
-- Framework intializer
--------------------------------------------------------------------------------

---@return FrameworkConfig config
function This.framework_init()
    return {
        -- prefix is the internal mod prefix
        prefix = const.prefix,
        -- prefix for log messages
        log_prefix = const.log_prefix,
        -- name is a human readable name
        name = const.name,
        -- The filesystem root.
        root = const.root,
    }
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
end

---@return fo.Storage
function This.storage()
    return assert(storage.fo_data)
end

return This
