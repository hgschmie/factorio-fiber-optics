------------------------------------------------------------------------
-- custom inputs for toggle-menu and confirm-gui
------------------------------------------------------------------------

local const = require('lib.constants')

data:extend {
    {
        type = 'custom-input',
        name = const.custom_input_toggle_menu,
        linked_game_control = 'toggle-menu',
        hidden = true,
        hidden_in_factoriopedia = true,
        key_sequence = '',
    },
    {
        type = 'custom-input',
        name = const.custom_input_confirm_gui,
        linked_game_control = 'confirm-gui',
        hidden = true,
        hidden_in_factoriopedia = true,
        key_sequence = '',
    },
}
