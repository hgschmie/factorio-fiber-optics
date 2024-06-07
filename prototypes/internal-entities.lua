------------------------------------------------------------------------
-- Prototype for the entities within the optical connector
------------------------------------------------------------------------

local const = require('lib.constants')

local oc_icon = const:png('sprite/oc-sprite-128')
local empty_icon = '__core__/graphics/empty.png'

-- power pole for the copper connections
local powerpole_item = {
    type = 'item',
    name = const.oc_power_pole,
    icon = empty_icon,
    icon_size = 1,
    subgroup = 'circuit-network',
    order = 'f[iber-optics]',
    place_result = const.oc_power_pole,
    stack_size = 50,
    flags = {
        'hidden',
    },
}


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
        picture = const.empty_sprite,

        -- EntityWithHealthPrototype
        max_health = 1,

        -- EntityPrototype
        icon = oc_icon,
        icon_size = 128,
        collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        collision_mask = {},
        selection_box = { { -1, -1 }, { 1, 1 } },
        flags = {
            'not-rotatable',
            'placeable-off-grid',
            'hide-alt-info',
            'not-upgradable',
            'not-in-kill-statistics',
            'not-on-map',
            'not-blueprintable',
            'hidden',
        },
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
        icon = empty_icon,
        icon_size = 1,

        -- PowerSwitchPrototype
        power_on_animation = const.empty_sprite,
        overlay_start = const.empty_sprite,
        overlay_loop = const.empty_sprite,
        led_on = const.empty_sprite,
        led_off = const.empty_sprite,
        overlay_start_delay = 0,

        circuit_wire_connection_point = {
            wire = {}, shadow = {},
        },

        left_wire_connection_point = {
            wire = { copper = { -0.2, 0 } },
            shadow = { copper = { -0.2, 0 } },
        },
        right_wire_connection_point = {
            wire = { copper = { 0.2, 0 } },
            shadow = { copper = { 0.2, 0 } },
        },
        wire_max_distance = 10,
        draw_copper_wires = true,
        draw_circuit_wires = false,

        -- EntityWithHealthPrototype
        max_health = 1,

        -- EntityPrototype
        collision_box = { { -0.2, -0.1 }, { 0.2, 0.1 } },
        collision_mask = {},
        selection_box = { { -0.2, -0.1 }, { 0.2, 0.1 } },

        flags = {
            'player-creation',
            'placeable-neutral',
            'not-rotatable',
            'placeable-off-grid',
            'hide-alt-info',
            'not-upgradable',
            'not-in-kill-statistics',
        },

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
        collision_mask = {},
        selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        flags = {
            'not-rotatable',
            'placeable-off-grid',
            'hide-alt-info',
            'not-upgradable',
            'not-in-kill-statistics',
            'not-on-map',
            'not-blueprintable',
            'hidden',
        },
        minable = nil,
        selectable_in_game = false,
        allow_copy_paste = false,
        selection_priority = 0,
    },
    {
        -- PrototypeBase
        type = 'constant-combinator',
        name = const.oc_cc,

        -- ConstantCombinatorPrototype
        item_slot_count = 2,
        activity_led_light_offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },
        circuit_wire_connection_points = { const.circuit_wire_connectors, const.circuit_wire_connectors, const.circuit_wire_connectors, const.circuit_wire_connectors },
        circuit_wire_max_distance = 2,
        draw_circuit_wires = false,
        sprites = const.empty_sprite,

        -- EntityWithHealthPrototype
        max_health = 1,

        -- EntityPrototype
        collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        collision_mask = {},
        selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        flags = {
            'not-rotatable',
            'placeable-off-grid',
            'hide-alt-info',
            'not-upgradable',
            'not-in-kill-statistics',
            'not-on-map',
            'not-blueprintable',
            'hidden',
        },
        minable = nil,
        selectable_in_game = false,
        allow_copy_paste = false,
        selection_priority = 0,
    },

    {
        -- PrototypeBase
        type = 'container',
        name = const.network_connector,

        -- ContainerPrototype
        inventory_size = 0,
        picture = const.empty_sprite,
        circuit_wire_connection_points = const.circuit_wire_connectors,
        circuit_wire_max_distance = default_circuit_wire_max_distance,
        draw_circuit_wires = false,

        -- EntityWithHealthPrototype
        max_health = 1,

        -- EntityPrototype
        collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        collision_mask = {},
        selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        flags = {
            'not-rotatable',
            'placeable-off-grid',
            'hide-alt-info',
            'not-upgradable',
            'not-in-kill-statistics',
            'not-on-map',
            'not-blueprintable',
            'no-automated-item-removal',
            'no-automated-item-insertion',
            'hidden',
        },

        minable = nil,
        selectable_in_game = false,
        allow_copy_paste = false,
        selection_priority = 0,
    },
}

data:extend { powerpole_item }
data:extend(entities)
