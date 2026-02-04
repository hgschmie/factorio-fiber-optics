require('lib.init')

local const = require('lib.constants')

data:extend {
    {
        type = 'int-setting',
        name = const.settings.fo_refresh,
        order = 'aa',
        setting_type = 'startup',
        default_value = 300,
        minimum_value = 30,
        maximum_value = 600, -- 5 seconds
    },
    {
        type = 'int-setting',
        name = const.settings.network_refresh,
        order = 'ab',
        setting_type = 'startup',
        default_value = 60,
        minimum_value = 5,
        maximum_value = 300, -- 5 seconds
    },
    {
        -- Debug mode (framework dependency)
        type = 'bool-setting',
        name = Framework.PREFIX .. 'debug-mode',
        order = 'z',
        setting_type = 'startup',
        default_value = false,
    },
}

---@diagnostic disable-next-line: undefined-field
Framework.post_settings_stage()
