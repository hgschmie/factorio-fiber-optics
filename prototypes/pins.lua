------------------------------------------------------------------------
-- IO Pins
------------------------------------------------------------------------

require 'circuit-connector-sprites'

local util = require('util')
local meld = require('meld')
local collision_mask_util = require('collision-mask-util')

local const = require('lib.constants')

local circle_sprite = const:png('sprite/circle')
local oc_pin_icon = const:png('sprite/oc-iopin-128')

---@type data.Sprite
local pin_sprite_orange = {
    filename = circle_sprite,
    size = 32,
    scale = 0.125,
    tint = { 1, 0.5, 0, 1 }, -- orange
}

---@type data.Sprite
local pin_sprite_green = {
    filename = circle_sprite,
    size = 32,
    scale = 0.125,
    tint = { 0, 1, 0, 1 }, -- green
}

---@type data.ItemPrototype
local pin_item = {
    -- PrototypeBase
    type = 'item',
    name = const.pin_entity_name,
    order = 'f[iber-optics]',
    subgroup = 'circuit-network',
    hidden_in_factoriopedia = true,

    -- ItemPrototype
    stack_size = 50,
    icon = oc_pin_icon,
    icon_size = 128,

    place_result = const.pin_entity_name,
    flags = {
        'hide-from-bonus-gui',
        'only-in-cursor',
    },
    weight = 0,
}

local pin_entity = {
    -- PrototypeBase
    type = 'container',
    name = const.pin_entity_name,
    hidden_in_factoriopedia = true,

    -- ContainerPrototype
    inventory_size = 0,
    picture = pin_sprite_orange,
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    draw_copper_wires = false,
    draw_circuit_wires = true,

    -- EntityWithHealthPrototype
    max_health = 1,

    -- EntityPrototype
    icon = oc_pin_icon,
    icon_size = 128,
    collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    collision_mask = collision_mask_util.new_mask(),
    selection_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    flags = {
        'placeable-neutral',
        'player-creation',
        'not-upgradable',
    },
    minable = nil,
    selection_priority = 70,
    allow_copy_paste = false,
}

-- IO Pin 1 is special
local pin_one_item = meld(util.copy(pin_item), {
    name = const.pin_one_entity_name,
    place_result = const.pin_one_entity_name,
})

local pin_one_entity = meld(util.copy(pin_entity), {
    name = const.pin_one_entity_name,
    picture = meld.overwrite(pin_sprite_green),
})

data:extend { pin_item, pin_one_item, pin_entity, pin_one_entity }
