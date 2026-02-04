------------------------------------------------------------------------
-- mod settings
------------------------------------------------------------------------

local const = require('lib.constants')

---@type table<FrameworkSettings.name, FrameworkSettingsGroup>
local Settings = {
    startup = {
        [const.settings_name.network_refresh] = {
            key = const.settings.network_refresh,
            value = 5
        },
    }
}

return Settings
