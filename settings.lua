require('lib.init')

data:extend {
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
