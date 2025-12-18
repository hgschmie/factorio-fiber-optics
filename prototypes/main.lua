------------------------------------------------------------------------
-- Main entity
------------------------------------------------------------------------

local const = require('lib.constants')

-- Item

local oc_icon = const:png('sprite/oc-sprite-128')

---@type data.ItemPrototype
local item = {
    -- Prototype Base
    type = 'item',
    name = const.main_entity_name,
    place_result = const.main_entity_name,

    -- ItemPrototype
    stack_size = 50,
    icon = oc_icon,
    icon_size = 128,
    order = 'f[iber-optics]',
    subgroup = 'circuit-network',
}

---@type data.Sprite[]
local oc_sprite = {}

for idx, direction in pairs { 'north', 'east', 'south', 'west' } do
    oc_sprite[direction] = {
        filename = const:png('entity/oc-entity-shadow'),
        width = 128,
        height = 127,
        scale = 0.5,
        x = (idx - 1) * 128,
        shift = util.by_pixel(4, 4),
    }
end

-- represents the main entity of the connector
---@type data.SimpleEntityWithOwnerPrototype
local entity = {
    -- PrototypeBase
    type = 'simple-entity-with-owner',
    name = const.main_entity_name,

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
    minable = { mining_time = 1, result = const.main_entity_name, },
    selection_priority = 20,
}

data:extend { item, entity }
