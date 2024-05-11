--
-- setup code for all the io pins
--

local function rotate_pins(from)
    local result = {}
    for _, offset in pairs(from) do
        local pin = { offset[2], -offset[1] }
        table.insert(result, pin)
    end
    return result
end

local function iopin_setup(const)
    const.oc_iopin_count = 16
    const.oc_iopin_prefix = const:with_prefix("oc-iopin_")

    const.iopin_name = function(idx)
        return const.oc_iopin_prefix .. idx
    end

    const.all_iopins = {}

    for idx = 1, const.oc_iopin_count, 1 do
        local name = const.iopin_name(idx)
        table.insert(const.attached_entities, name)
        table.insert(const.all_iopins, name)
    end

    --
    -- connection points for wires
    --
    const.iopin_connection_points = {
        [defines.direction.north] = {
            [1] = { -2, -2 }, [16] = { -2, -1 }, [15] = { -2, 0 }, [14] = { -2, 1 }, [13] = { -2, 2 },
            [2] = { -1, -2 }, [12] = { -1, 2 },
            [3] = { 0, -2 }, [11] = { 0, 2 },
            [4] = { 1, -2 }, [10] = { 1, 2 },
            [5] = { 2, -2 }, [6] = { 2, -1 }, [7] = { 2, 0 }, [8] = { 2, 1 }, [9] = { 2, 2 },
        },
    }

    local previous = {}
    for _, dir in pairs(const.directions) do
        if not const.iopin_connection_points[dir] then
            const.iopin_connection_points[dir] = rotate_pins(previous)
        end
        previous = const.iopin_connection_points[dir]
    end
end

------------------------------------------------------------------------

local function iopin_create_data()
    local const = require('lib.constants')
    local tools = require('lib.tools')

    local empty_icon = '__core__/graphics/empty.png' -- tools.image('sprite/oc-sprite-128.png')
    local circle_sprite = tools.image("sprite/circle.png")

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

    return result
end

------------------------

return {
    setup = iopin_setup,
    create_data = iopin_create_data,
}
