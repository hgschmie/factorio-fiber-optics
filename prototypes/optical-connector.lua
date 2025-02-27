------------------------------------------------------------------------
-- Prototype for the optical connector
------------------------------------------------------------------------

local const = require('lib.constants')

local oc_sprite = {}
for idx, direction in pairs { 'north', 'east', 'south', 'west' } do

    ---@type data.Sprite
    oc_sprite[direction] = {
        filename = const:png('entity/oc-entity-shadow'),
        width = 128,
        height = 127,
        scale = 0.5,
        x = (idx - 1) * 128,
        shift = util.by_pixel(4, 4),
    }
end

local oc_icon = const:png('sprite/oc-sprite-128')

-- The actual connector item
---@type data.ItemPrototype
local item = {
    -- Prototype Base
    type = 'item',
    name = const.optical_connector,
    place_result = const.optical_connector,

    -- ItemPrototype
    stack_size = 50,
    icon = oc_icon,
    icon_size = 128,
    order = 'f[iber-optics]',
    subgroup = 'circuit-network',
}

-- represents the main entity of the connector
---@type data.SimpleEntityWithOwnerPrototype
local entity = {
    -- PrototypeBase
    type = 'simple-entity-with-owner',
    name = const.optical_connector,

    -- SimpleEntityWithOwnerPrototype
    render_layer = 'floor-mechanics',
    picture = oc_sprite,

    -- EntityWithHealthPrototype
    max_health = 250,
    dying_explosion = 'medium-explosion',
    corpse = 'medium-remnants',

    -- EntityPrototype
    icon = oc_icon,
    icon_size = 128,
    collision_box = { { -0.95, -0.95 }, { 0.95, 0.95 } },
    collision_mask = const.entity_collision_mask,
    selection_box = { { -1, -1 }, { 1, 1 } },
    flags = {
        'player-creation',
        'placeable-neutral',
        'not-upgradable',
    },
    minable = { mining_time = 1, result = const.optical_connector },
    selection_priority = 20,
}

data:extend { entity, item }
