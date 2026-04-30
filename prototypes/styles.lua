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
    ---@diagnostic disable-next-line: undefined-global
    font_color = gui_color.grey
}

styles[const:with_prefix('pin_table')] = {
    type = 'table_style',
    parent = 'table',
    margin = 4,
    cell_padding = 2,
    column_alignments = {
        { column = 1, alignment = 'top-left' },
        { column = 2, alignment = 'top-left' },
    },
}
