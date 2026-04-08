------------------------------------------------------------------------
-- styles
------------------------------------------------------------------------

local const = require('lib.constants')

local styles = data.raw['gui-style'].default

styles[const:with_prefix('title')] = {
    type = 'label_style',
    parent = 'label',
    width = const.ui_title_width,
    maximal_width = const.ui_title_width,
}

styles[const:with_prefix('title_dimmed')] = {
    type = 'label_style',
    parent = const:with_prefix('title'),
    font_color = gui_color.grey
}
