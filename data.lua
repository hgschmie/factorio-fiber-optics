------------------------------------------------------------------------
-- data phase 1
------------------------------------------------------------------------

require('lib.init')('data')

local const = require('lib.constants')

require('prototypes.optical-connector')
require('prototypes.internal-entities')
require('prototypes.iopins')


local recipe_technology = {
    {
        type = 'recipe',
        name = const.optical_connector,

        ingredients = {
            { type = 'item', name = 'advanced-circuit', amount = 2 },
            { type = 'item', name = 'red-wire',       amount = 4 },
            { type = 'item', name = 'green-wire',     amount = 4 },
            { type = 'item', name = 'copper-cable',   amount = 2 },
        },

        results = {
            { type = 'item', name = const.optical_connector, amount = 1 },
        },

        energy_required = 30,
    },
    {
        type = 'technology',
        name = const.optical_connector_technology,
        icon_size = 128,
        icon = const:png('oc-tech'),
        effects = {
            { type = 'unlock-recipe', recipe = const.optical_connector },
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

data:extend(recipe_technology)

require('framework.other-mods').data()
