------------------------------------------------------------------------
-- Internal entities (power connector, LEDs)
------------------------------------------------------------------------

-- for default_circuit_wire_max_distance
require 'circuit-connector-sprites'

local collision_mask_util = require('collision-mask-util')
local util = require('util')

local sprites = require('stdlib.data.modules.sprites')

local const = require('lib.constants')

local fo_powerpole_icon = const:png('sprite/oc-power-unit-128')

---@type data.ItemPrototype
local powerpole_item = {
    -- Prototype Base
    type = 'item',
    name = const.powerpole_name,
    order = 'f[iber-optics]',
    subgroup = 'circuit-network',
    hidden = true,
    hidden_in_factoriopedia = true,

    -- ItemPrototype
    stack_size = 50,
    icon = fo_powerpole_icon,
    icon_size = 128,

    place_result = const.powerpole_name,
    flags = {
        'hide-from-bonus-gui',
        'only-in-cursor',
    },
    weight = 0,
}

--- @type data.PowerSwitchPrototype
local powerpole_entity = {
    -- PrototypeBase
    type = 'power-switch',
    name = const.powerpole_name,
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
    icon = fo_powerpole_icon,
    icon_size = 128,

    collision_box = { util.by_pixel_hr(-22, -8), util.by_pixel_hr(24, 8) },
    collision_mask = collision_mask_util.new_mask(),
    selection_box = { util.by_pixel_hr(-22, -8), util.by_pixel_hr(24, 8) },
    flags = const.prototype_internal_entity_flags,
    minable = nil,
    selection_priority = 99,
    allow_copy_paste = false,
}

-- represents the power consumption

--- @type data.ElectricEnergyInterfacePrototype
local power_entity = {
    -- PrototypeBase
    type = 'electric-energy-interface',
    name = const.power_interface_name,
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
    collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    collision_mask = collision_mask_util.new_mask(),
    selection_box = { { -1, -1 }, { 1, 1 } },
    flags = const.prototype_hidden_entity_flags,
    minable = nil,
    allow_copy_paste = false,
    selectable_in_game = false,
    selection_priority = 1,
}

local led_entity = {
    -- PrototypeBase
    type = 'lamp',
    name = const.led_name,
    hidden = true,
    hidden_in_factoriopedia = true,

    -- LampPrototype
    picture_on = {
        filename = '__base__/graphics/entity/wall/wall-diode-green.png',
        priority = 'extra-high',
        width = 72,
        height = 44,
        scale = 0.5,
    },
    picture_off = {
        filename = '__base__/graphics/entity/wall/wall-diode-red.png',
        priority = 'extra-high',
        width = 72,
        height = 44,
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
    allow_copy_paste = false,
    selectable_in_game = false,
    selection_priority = 1,
}

-- constant combinator to turn led lamps on and off
--- @type data.ConstantCombinatorPrototype
local controller_entity = {
    -- PrototypeBase
    type = 'constant-combinator',
    name = const.controller_name,
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
    allow_copy_paste = false,
    selectable_in_game = false,
    selection_priority = 1,
}

data:extend { powerpole_item, powerpole_entity, power_entity, led_entity, controller_entity }
