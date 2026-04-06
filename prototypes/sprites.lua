------------------------------------------------------------------------
-- Sprites
------------------------------------------------------------------------

local const = require('lib.constants')

data:extend {
    {
        type = 'sprite',
        name = const:with_prefix('red-wire'),
        -- filename = '__base__/graphics/icons/shortcut-toolbar/mip/new-red-wire-x56.png',
        filename = '__base__/graphics/icons/red-wire.png',
        priority = 'extra-high-no-scale',
        width = 64,
        -- width = 56,
        height = 64,
        -- height = 56,
        flags = { 'gui-icon' },
        mipmap_count = 4,
        -- mipmap_count = 2,
        scale = 0.5
    },
    {
        type = 'sprite',
        name = const:with_prefix('green-wire'),
        -- filename = '__base__/graphics/icons/shortcut-toolbar/mip/new-green-wire-x56.png',
        filename = '__base__/graphics/icons/green-wire.png',
        priority = 'extra-high-no-scale',
        width = 64,
        -- width = 56,
        height = 64,
        -- height = 56,
        flags = { 'gui-icon' },
        mipmap_count = 4,
        -- mipmap_count = 2,
        scale = 0.5
    },
}
