require('lib.init')

data:extend {
    {
        -- Debug mode (framework dependency)
        setting_type = 'runtime-global',
        name = Framework.PREFIX .. 'debug-mode',
        type = 'bool-setting',
        default_value = false,
        order = 'z'
    },
}

--------------------------------------------------------------------------------
Framework.post_settings_stage()
