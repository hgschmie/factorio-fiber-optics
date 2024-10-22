------------------------------------------------------------------------
-- Prototype for the entities within the optical connector
------------------------------------------------------------------------

local const = require('lib.constants')
local Sprites = require('__stdlib__/stdlib/data/modules/sprites')

local oc_power_unit = const:png('sprite/oc-power-unit-128')

-- power pole for the copper connections
local powerpole_item = {
    type = 'item',
    name = const.oc_power_pole,
    icon = oc_power_unit,
    icon_size = 128,
    subgroup = 'circuit-network',
    order = 'f[iber-optics]',
    place_result = const.oc_power_pole,
    stack_size = 50,
    hidden = true,
    flags = const.prototype_internal_item_flags,
}

data:extend { powerpole_item }

local entities = {
    -- represents the power connection and consumption
    {
        -- PrototypeBase
        type = 'electric-energy-interface',
        name = const.oc_power_interface,

        always_on = true,

        -- ElectricEnergyInterfacePrototype
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
            input_flow_limit = '66kW',
            output_flow_limit = '66kW',
            buffer_capacity = '66kJ',
        },

        energy_usage = '2kW',
        gui_mode = 'none',
        picture = Sprites.empty_picture(),

        -- EntityWithHealthPrototype
        max_health = 1,

        -- EntityPrototype
        icon = oc_power_unit,
        icon_size = 128,
        collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        collision_mask = const.empty_collision_mask,
        selection_box = { { -1, -1 }, { 1, 1 } },
        hidden = true,
        flags = const.prototype_hidden_entity_flags,
        minable = nil,
        allow_copy_paste = false,
        selectable_in_game = false,
        selection_priority = 0,
    },
    -- connection point for the power wires
    {
        -- PrototypeBase
        type = 'power-switch',
        name = const.oc_power_pole,
        icon = oc_power_unit,
        icon_size = 128,

        -- PowerSwitchPrototype
        power_on_animation = Sprites.empty_picture(),
        overlay_start = Sprites.empty_picture(),
        overlay_loop = Sprites.empty_picture(),
        led_on = Sprites.empty_picture(),
        led_off = Sprites.empty_picture(),
        overlay_start_delay = 0,

        circuit_wire_connection_point = {
            wire = {}, shadow = {},
        },

        left_wire_connection_point = {
            wire = { copper = { -14 / 64, 4 / 64 } },
            shadow = { copper = { -14 / 64, 4 / 64 } },
        },
        right_wire_connection_point = {
            wire = { copper = { 16 / 64, 4 / 64 } },
            shadow = { copper = { 16 / 64, 4 / 64 } },
        },
        wire_max_distance = 10,
        draw_copper_wires = true,
        draw_circuit_wires = false,

        -- EntityWithHealthPrototype
        max_health = 1,

        -- EntityPrototype
        collision_box = { { -22 / 64, -8 / 64 }, { 24 / 64, 8 / 64 } },
        collision_mask = const.empty_collision_mask,
        selection_box = { { -22 / 64, -8 / 64 }, { 24 / 64, 8 / 64 } },

        hidden = true,
        flags = const.prototype_internal_entity_flags,

        minable = nil,
        allow_copy_paste = false,
        selection_priority = 99,
    },
    -- led lamp to show the connection state
    {
        -- PrototypeBase
        type = 'lamp',
        name = const.oc_led_lamp,

        -- LampPrototype
        picture_on = {
            filename = '__base__/graphics/entity/wall/wall-diode-green.png',
            priority = 'extra-high',
            width = 38,
            height = 24,
            draw_as_glow = true,
            hr_version =
            {
                filename = '__base__/graphics/entity/wall/hr-wall-diode-green.png',
                priority = 'extra-high',
                width = 72,
                height = 44,
                draw_as_glow = true,
                scale = 0.5,
            },
        },
        picture_off = {
            filename = '__base__/graphics/entity/wall/wall-diode-red.png',
            priority = 'extra-high',
            width = 38,
            height = 24,
            draw_as_glow = true,
            hr_version =
            {
                filename = '__base__/graphics/entity/wall/hr-wall-diode-red.png',
                priority = 'extra-high',
                width = 72,
                height = 44,
                draw_as_glow = true,
                scale = 0.5,
            },
        },
        energy_usage_per_tick = '1J',
        energy_source = { type = 'void' },
        draw_circuit_wires = false,
        circuit_wire_max_distance = 2,
        circuit_connector_sprites = nil,
        always_on = false,

        -- EntityWithHealthPrototype
        max_health = 1,

        -- EntityPrototype
        collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        collision_mask = const.empty_collision_mask,
        selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        hidden = true,
        flags = const.prototype_hidden_entity_flags,
        minable = nil,
        selectable_in_game = false,
        allow_copy_paste = false,
        selection_priority = 0,
    },
    -- constant combinator to turn led lamps on and off
    {
        -- PrototypeBase
        type = 'constant-combinator',
        name = const.oc_cc,

        -- ConstantCombinatorPrototype
        item_slot_count = 2,
        activity_led_light_offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },
        circuit_wire_connection_points = Sprites.empty_connection_points(4),
        circuit_wire_max_distance = 2,
        draw_circuit_wires = false,
        sprites = Sprites.empty_picture(),

        -- EntityWithHealthPrototype
        max_health = 1,

        -- EntityPrototype
        collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        collision_mask = const.empty_collision_mask,
        selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        hidden = true,
        flags = const.prototype_hidden_entity_flags,
        minable = nil,
        selectable_in_game = false,
        allow_copy_paste = false,
        selection_priority = 0,
    },
    -- network connection entities
    {
        -- PrototypeBase
        type = 'container',
        name = const.network_connector,
        icon = const.empty_icon,
        icon_size = 1,

        -- ContainerPrototype
        inventory_size = 0,
        picture = Sprites.empty_picture(),
        circuit_wire_connection_points = Sprites.empty_connection_points()[1],
        circuit_wire_max_distance = default_circuit_wire_max_distance,
        draw_circuit_wires = false,

        -- EntityWithHealthPrototype
        max_health = 1,

        -- EntityPrototype
        collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        collision_mask = const.empty_collision_mask,
        selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        hidden = true,
        flags = const.prototype_hidden_entity_flags,
        minable = nil,
        selectable_in_game = false,
        allow_copy_paste = false,
        selection_priority = 0,
    },
}

data:extend(entities)
