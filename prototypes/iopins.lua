------------------------------------------------------------------------
-- setup code for all the io pins
------------------------------------------------------------------------

local collision_mask_util = require('collision-mask-util')

local const = require('lib.constants')

local tools = require('framework.tools')
local sprites = require('stdlib.data.modules.sprites')


local circle_sprite = const:png('sprite/circle')
local oc_iopin = const:png('sprite/oc-iopin-128')

---@type data.Sprite
local iopin_sprite = {
    filename = circle_sprite,
    size = 32,
    scale = 0.125,
    tint = { 1, 0.5, 0, 1 }, -- orange
}

---@type data.Sprite
local iopin_one_sprite = {
    filename = circle_sprite,
    size = 32,
    scale = 0.125,
    tint = { 0, 1, 0, 1 }, -- green
}

---@type data.ItemPrototype
local iopin_item = {

    -- ItemPrototype
    stack_size = 50,
    icon = oc_iopin,
    icon_size = 128,
    place_result = const.iopin_name,
    flags = const.prototype_internal_item_flags,
    weight = 0,

    -- PrototypeBase
    type = 'item',
    name = const.iopin_name,
    order = 'f[iber-optics]',
    subgroup = 'circuit-network',
    hidden_in_factoriopedia = true,
}

local iopin_entity = {
    -- PrototypeBase
    type = 'container',
    name = const.iopin_name,
    hidden_in_factoriopedia = true,


    -- ContainerPrototype
    inventory_size = 0,
    picture = iopin_sprite,
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    draw_copper_wires = false,
    draw_circuit_wires = true,

    -- EntityWithHealthPrototype
    max_health = 1,

    -- EntityPrototype
    icon = oc_iopin,
    icon_size = 128,
    collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    collision_mask = collision_mask_util.new_mask(),
    selection_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    flags = const.prototype_internal_entity_flags,
    minable = nil,
    selection_priority = 70,
    allow_copy_paste = false,
}

-- IO Pin 1 is special
local iopin_one_item = tools.copy(iopin_item)
iopin_one_item.name = const.iopin_one_name
iopin_one_item.place_result = const.iopin_one_name

local iopin_one_entity = tools.copy(iopin_entity)
iopin_one_entity.name = const.iopin_one_name
iopin_one_entity.picture = iopin_one_sprite

data:extend { iopin_item, iopin_one_item, iopin_entity, iopin_one_entity }

------------------------------------------------------------------------
-- legacy item / entity. Needs to exist for migrating
------------------------------------------------------------------------

local legacy_entity = {
    -- PrototypeBase
    type = 'lamp',
    hidden_in_factoriopedia = true,

    -- LampPrototype
    energy_usage_per_tick = '1J',
    energy_source = { type = 'void' },
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    draw_copper_wires = false,
    draw_circuit_wires = true,
    always_on = true,

    -- EntityWithHealthPrototype
    max_health = 1,

    -- EntityPrototype
    icon = oc_iopin,
    icon_size = 128,
    collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    collision_mask = collision_mask_util.new_mask(),
    selection_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    flags = const.prototype_internal_entity_flags,
    minable = nil,
    selection_priority = 70,
    allow_copy_paste = false,
}

local legacy_iopin_entities = {}

local sprite_name = iopin_one_sprite

for idx = 1, const.oc_iopin_count, 1 do
    local name = const:with_prefix('oc-iopin_') .. idx

    local legacy_iopin_entity = tools.copy(legacy_entity)
    legacy_iopin_entity.name = name
    legacy_iopin_entity.picture_on = sprite_name
    legacy_iopin_entity.picture_off = sprite_name

    table.insert(legacy_iopin_entities, legacy_iopin_entity)

    sprite_name = iopin_sprite
end

data:extend(legacy_iopin_entities)
