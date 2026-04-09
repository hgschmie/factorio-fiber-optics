------------------------------------------------------------------------
-- mod settings
------------------------------------------------------------------------

local const = require('lib.constants')

---@type table<FrameworkSettings.name, FrameworkSettingsGroup>
local Settings = {
    startup = {
        [const.settings_names.fo_refresh] = {
            key = const.settings.fo_refresh,
            value = 300
        },
        [const.settings_names.network_refresh] = {
            key = const.settings.network_refresh,
            value = 60
        },
    }
}

return Settings
