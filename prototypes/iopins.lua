------------------------------------------------------------------------
-- setup code for all the io pins
------------------------------------------------------------------------

local Sprites = require('__stdlib__/stdlib/data/modules/sprites')

local const = require('lib.constants')

local circle_sprite = const:png('sprite/circle')
local oc_iopin = const:png('sprite/oc-iopin-128')

local iopin_sprite = {
    filename = circle_sprite,
    size = 32,
    scale = 0.125,
    tint = { 1, 0.5, 0, 1 }, -- orange
}

local iopin_one_sprite = {
    filename = circle_sprite,
    size = 32,
    scale = 0.125,
    tint = { 0, 1, 0, 1 }, -- green
}

local iopin_item = {
    type = 'item',
    name = const.iopin_name,
    icon = oc_iopin,
    icon_size = 128,
    place_result = const.iopin_name,
    subgroup = 'circuit-network',
    order = 'f[iber-optics]',
    stack_size = 50,
    flags = const.prototype_internal_item_flags,
}

local iopin_entity = {
    -- PrototypeBase
    type = 'container',
    name = const.iopin_name,
    icon = oc_iopin,
    icon_size = 128,

    -- ContainerPrototype
    inventory_size = 0,
    picture = iopin_sprite,
    circuit_wire_connection_points = Sprites.empty_connection_points()[1],
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    draw_circuit_wires = true,

    -- EntityWithHealthPrototype
    max_health = 1,

    -- EntityPrototype
    collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    collision_mask = const.empty_collision_mask,
    selection_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    flags = const.prototype_internal_entity_flags,
    minable = nil,
    allow_copy_paste = false,
    selection_priority = 70,
}

-- IO Pin 1 is special
local iopin_one_item = table.deepcopy(iopin_item)
iopin_one_item.name = const.iopin_one_name
iopin_one_item.place_result = const.iopin_one_name

local iopin_one_entity = table.deepcopy(iopin_entity)
iopin_one_entity.name = const.iopin_one_name
iopin_one_entity.picture = iopin_one_sprite

data:extend { iopin_item, iopin_one_item, iopin_entity, iopin_one_entity }

------------------------------------------------------------------------
-- legacy item / entity. Needs to exist for migrating
------------------------------------------------------------------------

local legacy_entity = {
    -- PrototypeBase
    type = 'lamp',
    icon = oc_iopin,
    icon_size = 128,

    -- LampPrototype
    energy_usage_per_tick = '1J',
    energy_source = { type = 'void' },
    circuit_wire_connection_point = Sprites.empty_connection_points()[1],
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    draw_circuit_wires = true,
    draw_copper_wires = false,
    always_on = true,

    -- EntityWithHealthPrototype
    max_health = 1,

    -- EntityPrototype
    collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    collision_mask = const.empty_collision_mask,
    selection_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    flags = const.prototype_internal_entity_flags,
    minable = nil,
    allow_copy_paste = false,
    selection_priority = 70,
}

local legacy_iopin_entities = {}

local sprite_name = iopin_one_sprite

for idx = 1, const.oc_iopin_count, 1 do
    local name = const:with_prefix('oc-iopin_') .. idx

    local legacy_iopin_entity = table.deepcopy(legacy_entity)
    legacy_iopin_entity.name = name
    legacy_iopin_entity.picture_on = sprite_name
    legacy_iopin_entity.picture_off = sprite_name

    table.insert(legacy_iopin_entities, legacy_iopin_entity)

    sprite_name = iopin_sprite
end

data:extend(legacy_iopin_entities)
