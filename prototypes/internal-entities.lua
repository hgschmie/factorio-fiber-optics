------------------------------------------------------------------------
-- Prototype for the entities within the optical connector
------------------------------------------------------------------------
local collision_mask_util = require('collision-mask-util')

local const = require('lib.constants')
local sprites = require('stdlib.data.modules.sprites')

local oc_power_unit = const:png('sprite/oc-power-unit-128')

-- power pole for the copper connections
---@type data.ItemPrototype
local powerpole_item = {
    -- Prototype Base
    type = 'item',
    name = const.oc_power_pole,
    place_result = const.oc_power_pole,

    -- ItemPrototype
    stack_size = 50,
    icon = oc_power_unit,
    icon_size = 128,
    order = 'f[iber-optics]',
    subgroup = 'circuit-network',
    hidden = true,
    hidden_in_factoriopedia = true,
    flags = const.prototype_internal_item_flags,
    weight = 0,
}

data:extend { powerpole_item }

-- represents the power connection and consumption
--- @type data.ElectricEnergyInterfacePrototype
local power_entity = {
    -- PrototypeBase
    type = 'electric-energy-interface',
    name = const.oc_power_interface,
    hidden = true,
    hidden_in_factoriopedia = true,

    -- ElectricEnergyInterfacePrototype
    ---@type data.ElectricEnergySource
    energy_source = {
        type = 'electric',
        buffer_capacity = '66kJ',
        usage_priority = 'secondary-input',
        input_flow_limit = '66kW',
        output_flow_limit = '66kW',
    },

    energy_usage = '2kW',
    gui_mode = 'none',
    picture = util.empty_sprite(),

    -- EntityWithHealthPrototype
    max_health = 1,

    -- EntityPrototype
    icon = oc_power_unit,
    icon_size = 128,
    collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    collision_mask = collision_mask_util.new_mask(),
    selection_box = { { -1, -1 }, { 1, 1 } },
    flags = const.prototype_hidden_entity_flags,
    minable = nil,
    allow_copy_paste = false,
    selectable_in_game = false,
    selection_priority = 0,
}

-- connection point for the power wires
--- @type data.PowerSwitchPrototype
local connection_entity = {
    -- PrototypeBase
    type = 'power-switch',
    name = const.oc_power_pole,
    hidden = true,
    hidden_in_factoriopedia = true,


    -- PowerSwitchPrototype
    led_on = util.empty_sprite(),
    led_off = util.empty_sprite(),
    overlay_start_delay = 0,

    circuit_wire_connection_point = sprites.empty_connection_points()[1],

    ---@type data.WireConnectionPoint
    left_wire_connection_point = {
        wire = { copper = util.by_pixel_hr(-14, 4) },
        shadow = { copper = util.by_pixel_hr(-14, 4) },
    },

    ---@type data.WireConnectionPoint
    right_wire_connection_point = {
        wire = { copper = util.by_pixel_hr(16, 4) },
        shadow = { copper = util.by_pixel_hr(16, 4) },
    },

    wire_max_distance = default_circuit_wire_max_distance + 1,
    draw_copper_wires = true,
    draw_circuit_wires = false,

    -- EntityWithHealthPrototype
    max_health = 1,

    -- EntityPrototype
    icon = oc_power_unit,
    icon_size = 128,

    collision_box = { util.by_pixel_hr(-22, -8), util.by_pixel_hr(24, 8) },
    collision_mask = collision_mask_util.new_mask(),
    selection_box = { util.by_pixel_hr(-22, -8), util.by_pixel_hr(24, 8) },

    flags = const.prototype_internal_entity_flags,

    minable = nil,
    selection_priority = 99,
    allow_copy_paste = false,
}

-- led lamp to show the connection state
--- @type data.LampPrototype
local led_entity = {
    -- PrototypeBase
    type = 'lamp',
    name = const.oc_led_lamp,
    hidden = true,
    hidden_in_factoriopedia = true,

    -- LampPrototype
    picture_on = {
        filename = '__base__/graphics/entity/wall/wall-diode-green.png',
        priority = 'extra-high',
        width = 72,
        height = 44,
        scale = 0.5,
        draw_as_glow = true,
    },
    picture_off = {
        filename = '__base__/graphics/entity/wall/wall-diode-red.png',
        priority = 'extra-high',
        width = 72,
        height = 44,
        draw_as_glow = true,
        scale = 0.5,
    },
    energy_usage_per_tick = '1J',
    energy_source = { type = 'void' },
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    draw_copper_wires = false,
    draw_circuit_wires = false,
    always_on = false,

    -- EntityWithHealthPrototype
    max_health = 1,

    -- EntityPrototype
    collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    collision_mask = collision_mask_util.new_mask(),
    selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    flags = const.prototype_hidden_entity_flags,
    minable = nil,
    selection_priority = 0,
    allow_copy_paste = false,
    selectable_in_game = false,
}

-- constant combinator to turn led lamps on and off
--- @type data.ConstantCombinatorPrototype
local controller_entity = {
    -- PrototypeBase
    type = 'constant-combinator',
    name = const.oc_cc,
    hidden = true,
    hidden_in_factoriopedia = true,

    -- ConstantCombinatorPrototype
    sprites = util.empty_sprite(),
    activity_led_light_offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },
    circuit_wire_connection_points = sprites.empty_connection_points(4),
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    draw_copper_wires = false,
    draw_circuit_wires = false,

    -- EntityWithHealthPrototype
    max_health = 1,

    -- EntityPrototype
    collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    collision_mask = collision_mask_util.new_mask(),
    selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    flags = const.prototype_hidden_entity_flags,
    minable = nil,
    selection_priority = 0,
    allow_copy_paste = false,
    selectable_in_game = false,
}

-- network connection entities
--- @type data.ContainerPrototype
local iopin_entity = {
    -- PrototypeBase
    type = 'container',
    name = const.network_connector,
    hidden = true,
    hidden_in_factoriopedia = true,

    -- ContainerPrototype
    inventory_size = 0,
    picture = util.empty_sprite(),
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    draw_copper_wires = false,
    draw_circuit_wires = false,

    -- EntityWithHealthPrototype
    max_health = 1,

    -- EntityPrototype
    icon = const.empty_icon,
    icon_size = 1,
    collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    collision_mask = collision_mask_util.new_mask(),
    selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    flags = const.prototype_hidden_entity_flags,
    minable = nil,
    selection_priority = 0,
    allow_copy_paste = false,
    selectable_in_game = false,
}

data:extend { power_entity, connection_entity, led_entity, controller_entity, iopin_entity }
