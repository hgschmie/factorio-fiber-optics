------------------------------------------------------------------------
-- setup code for all the io pins
------------------------------------------------------------------------

local const = require('lib.constants')

local empty_icon = '__core__/graphics/empty.png'
local circle_sprite = const:png('sprite/circle')

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

local item = {
    type = "item",
    icon = empty_icon,
    icon_size = 1,
    subgroup = "circuit-network",
    order = 'f[iber-optics]',
    stack_size = 50,
    flags = {
        'hidden',
        'hide-from-bonus-gui',
    },
}

local entity = {
    -- PrototypeBase
    type = "lamp",
    icon = empty_icon,
    icon_size = 1,

    -- LampPrototype
    energy_usage_per_tick = "1J",
    energy_source = { type = "void" },
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    circuit_wire_connection_point = const.circuit_wire_connectors,
    draw_copper_wires = false,
    draw_circuit_wires = true,

    always_on = true,

    -- EntityWithHealthPrototype
    max_health = 1,

    -- EntityPrototype
    collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    collision_mask = {},
    selection_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    flags = {
        "player-creation",
        "placeable-neutral",
        "not-rotatable",
        "placeable-off-grid",
        "hide-alt-info",
        "not-upgradable",
        "not-in-kill-statistics",
    },
    minable = nil,
    allow_copy_paste = false,
    selection_priority = 70,
}

local result = {}

local sprite_name = iopin_one_sprite

for idx = 1, const.oc_iopin_count, 1 do
    local name = const.iopin_name(idx)

    local iopin_item = table.deepcopy(item)
    iopin_item.name = name
    iopin_item.place_result = name

    table.insert(result, iopin_item)

    local iopin_entity = table.deepcopy(entity)
    iopin_entity.name = name
    iopin_entity.picture_on = sprite_name
    iopin_entity.picture_off = sprite_name

    table.insert(result, iopin_entity)

    sprite_name = iopin_sprite
end

data:extend(result)
