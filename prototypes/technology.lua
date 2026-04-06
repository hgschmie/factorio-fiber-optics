------------------------------------------------------------------------
-- Recipe and technology
------------------------------------------------------------------------

local const = require('lib.constants')

data:extend {

    -- Recipe for connector

    {
        type = 'recipe',
        name = const.main_entity_name,
        enabled = false,

        ingredients = {
            { type = 'item', name = 'advanced-circuit', amount = 2 },
            { type = 'item', name = 'plastic-bar',      amount = 4 },
            { type = 'item', name = 'copper-cable',     amount = 4 },
        },

        results = {
            { type = 'item', name = const.main_entity_name, amount = 1 },
        },

        energy_required = 30,
    },

    -- Technology for Optical Connector

    {
        type = 'technology',
        name = const:with_prefix('optical-connector-technology'),
        icon_size = 128,
        icon = const:png('oc-tech'),
        effects = {
            { type = 'unlock-recipe', recipe = const.main_entity_name, },
        },
        prerequisites = { 'advanced-circuit', 'laser', 'electric-energy-distribution-2', 'circuit-network' },
        unit = {
            count = 250,
            ingredients = {
                { 'automation-science-pack', 1 },
                { 'logistic-science-pack',   1 },
                { 'chemical-science-pack',   1 },
            },
            time = 30,
        },
        order = 'a-d-d-z',
    },
}
