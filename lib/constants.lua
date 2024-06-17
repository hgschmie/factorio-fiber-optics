------------------------------------------------------------------------
-- mod constant definitions.
--
-- can be loaded into scripts and data
------------------------------------------------------------------------

local table = require('__stdlib__/stdlib/utils/table')

local Constants = {}

--------------------------------------------------------------------------------
-- main constants
--------------------------------------------------------------------------------

-- debug mode
Constants.debug_mode = 0 -- bit 0 (0/1): network debug, bit 1 (0/2): entity debug

-- the current version that is the result of the latest migration
Constants.current_version = 5

Constants.prefix = 'hps:fo-'
Constants.name = 'optical-connector'
Constants.root = '__fiber-optics__'
Constants.gfx_location = Constants.root .. '/gfx/'

--------------------------------------------------------------------------------
-- Framework intializer
--------------------------------------------------------------------------------

---@return FrameworkConfig config
function Constants.framework_init()
    return {
        -- prefix is the internal mod prefix
        prefix = Constants.prefix,
        -- name is a human readable name
        name = Constants.name,
        -- The filesystem root.
        root = Constants.root,
    }
end

--------------------------------------------------------------------------------
-- Path and name helpers
--------------------------------------------------------------------------------

---@param value string
---@return string result
function Constants:with_prefix(value)
    return self.prefix .. value
end

---@param path string
---@return string result
function Constants:png(path)
    return self.gfx_location .. path .. '.png'
end

---@param id string
---@return string result
function Constants:locale(id)
    return Constants:with_prefix('gui.') .. id
end

--------------------------------------------------------------------------------
-- Entities
--------------------------------------------------------------------------------

Constants.optical_connector = Constants:with_prefix(Constants.name)

Constants.optical_connector_technology = Constants:with_prefix('optical-connector-technology')

Constants.oc_power_interface = Constants:with_prefix('oc-power-interface')
Constants.oc_power_pole = Constants:with_prefix('oc-power-pole')
Constants.oc_led_lamp = Constants:with_prefix('oc-led-lamp')
Constants.oc_cc = Constants:with_prefix('oc-constant-combinator')

Constants.oc_iopin_count = 16
Constants.oc_iopin_prefix = Constants:with_prefix('oc-iopin_')

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

Constants.creation_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
}

Constants.deletion_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy,
}

--------------------------------------------------------------------------------
-- Network
--------------------------------------------------------------------------------

Constants.network_connector = Constants:with_prefix('network-connector')
Constants.max_fiber_count = 16

Constants.check_circuit_wires = 1
Constants.check_power_wires = 2

-- map for all entities that need to do connection check
Constants.wire_check = {
    [Constants.oc_power_pole] = Constants.check_power_wires
}


--------------------------------------------------------------------------------
-- data phase
--------------------------------------------------------------------------------

Constants.empty_icon = '__core__/graphics/empty.png'

-- item flags
Constants.prototyle_internal_item_flags = {
    'hidden',
    'hide-from-bonus-gui',
    'only-in-cursor',
}

local base_entity_flags = {
    'not-rotatable',
    'placeable-off-grid',
    'not-on-map',
    'not-deconstructable',
    'hidden', -- includes 'not-made-in'
    'hide-alt-info',
    'not-selectable-in-game',
    'not-upgradable',
    'no-automated-item-removal',
    'no-automated-item-insertion',
    'not-in-kill-statistics',
}

-- flags for the visible entities (io pins, power connector)
Constants.prototype_internal_entity_flags = table.deepcopy(base_entity_flags)
table.insert(Constants.prototype_internal_entity_flags, 'placeable-neutral')
table.insert(Constants.prototype_internal_entity_flags, 'player-creation')

-- flags for the invisible entities
Constants.prototype_hidden_entity_flags = table.deepcopy(base_entity_flags)
table.insert(Constants.prototype_hidden_entity_flags, 'no-copy-paste')


-------- todo -------


Constants.iopin_name = function(idx) return Constants.oc_iopin_prefix .. idx end

-- network specific stuff

-- sub entities to the optical connector
Constants.attached_entities = {
    Constants.oc_power_interface,
    Constants.oc_power_pole,
    Constants.oc_led_lamp,
    Constants.oc_cc,
}

-- entities that take a wire connection
Constants.ghost_entities = {
    Constants.optical_connector,
    Constants.oc_power_pole,
}

Constants.empty_sprite = {
    filename = '__core__/graphics/empty.png',
    width = 1,
    height = 1,
}

Constants.circuit_wire_connectors = {
    wire = { red = { 0, 0 }, green = { 0, 0 } },
    shadow = { red = { 0, 0 }, green = { 0, 0 } },
}

Constants.directions = { defines.direction.north, defines.direction.west, defines.direction.south, defines.direction.east }

Constants.msg_wires_too_long = Constants.prefix .. 'messages.wires_too_long'

Constants.all_iopins = {}

for idx = 1, Constants.oc_iopin_count, 1 do
    local name = Constants.iopin_name(idx)
    table.insert(Constants.attached_entities, name)
    table.insert(Constants.ghost_entities, name)
    table.insert(Constants.all_iopins, name)

    Constants.wire_check[name] = Constants.check_circuit_wires
end

--
-- create the eight variants of io pin distribution, depending
-- on rotation and mirroring (from blueprints). See sprite_positions.txt
-- for the variants
--
Constants.iopin_positions = {}

for idx = 1, 4, 1 do
    Constants.iopin_positions[idx * 2 - 1] = {}
    Constants.iopin_positions[idx * 2] = {}
    local start = (idx - 1) * 4
    for id = 0, 15, 1 do
        local pos_forward = ((start + id) % 16) + 1
        local pos_backward = ((start - id + 16) % 16) + 1
        Constants.iopin_positions[idx * 2 - 1][id + 1] = pos_forward
        Constants.iopin_positions[idx * 2][id + 1] = pos_backward
    end
end

-- see sprite_positions.txt
Constants.sprite_positions = {
    { -42, -41 }, { -22, -29 }, { 3, -50 }, { 25, -29 },
    { 48,  -41 }, { 35, -14 }, { 55, 3 }, { 35, 21 },
    { 48,  47 }, { 25, 31 }, { 3, 53 }, { -22, 31 },
    { -42, 47 }, { -30, 21 }, { -50, 3 }, { -30, -14 },
}

Constants.iopin_directions = {
    [defines.direction.north] = {
        -- north related
        1, -- NORMAL (NORTH)
        4, -- H-FLIP (SOUTH-V)
        -- north related (show up as south after v-flip)
        8, -- V-FLIP (SOUTH-V)
        5, -- H/V FLIP (NORTH)
    },
    [defines.direction.east] = {
        -- east related
        3, -- NORMAL (EAST)

        -- east related (show up as west after h-flip)
        2, -- H-FLIP (WEST-V)

        -- east related
        6, -- V-FLIP (EAST-V)

        -- east related (show up as west after h-flip)
        7, -- H/V FLIP (WEST)
    },
    [defines.direction.south] = {
        -- south related
        5, -- NORMAL (SOUTH)
        8, -- H-FLIP (NORTH-V)

        -- south related (show up as north after v-flip)
        4, -- V-FLIP (NORTH-V)
        1, -- H/V FLIP (SOUTH)
    },
    [defines.direction.west] = {
        -- west related
        7, -- NORMAL (WEST)

        -- west related (show up as east after h-flip)
        6, -- H-FLIP (EAST-V)

        -- west related
        2, -- V-FLIP (WEST-V)

        -- west related (show up as east after h-flip)
        3, -- H/V FLIP (EAST)
    },
}

-- any main entity at construction time has been rotated
-- according to the flip_h and flip_v settings. This matrix
-- undoes those so that the actual direction is the original
-- direction before flipping.
Constants.correct_direction = {
    [defines.direction.north] = {
        defines.direction.north, -- NORMAL
        defines.direction.north, -- H-FLIP
        defines.direction.south, -- V-FLIP
        defines.direction.south, -- H/V-FLIP
    },
    [defines.direction.east] = {
        defines.direction.east,
        defines.direction.west,
        defines.direction.east,
        defines.direction.west,
    },
    [defines.direction.south] = {
        defines.direction.south,
        defines.direction.south,
        defines.direction.north,
        defines.direction.north,
    },
    [defines.direction.west] = {
        defines.direction.west,
        defines.direction.east,
        defines.direction.west,
        defines.direction.east,
    },
}

Constants.correct_image = {
    [defines.direction.north] = {
        defines.direction.north, -- NORMAL
        defines.direction.east,  -- H-FLIP
        defines.direction.west,  -- V-FLIP
        defines.direction.south, -- H/V-FLIP
    },
    [defines.direction.east] = {
        defines.direction.east,
        defines.direction.north,
        defines.direction.south,
        defines.direction.west,
    },
    [defines.direction.south] = {
        defines.direction.south,
        defines.direction.west,
        defines.direction.east,
        defines.direction.north,
    },
    [defines.direction.west] = {
        defines.direction.west,
        defines.direction.south,
        defines.direction.north,
        defines.direction.east,
    },
}

-- this is the equivalent of <first> XOR <second>
Constants.total_flip = {
    { 1, 2, 3, 4, }, -- NORMAL   (NORMAL, H-FLIP, V-FLIP, H/V-FLIP)
    { 2, 1, 4, 3, }, -- H-FLIP   (H-FLIP, NORMAL, H/V-FLIP, V-FLIP)
    { 3, 4, 1, 2, }, -- V-FLIP   (V-FLIP, H/V-FLIP, NORMAL, H-FLIP)
    { 4, 3, 2, 1, }, -- H/V-FLIP (H/V-FLIP, V-FLIP, H-FLIP, NORMAL)
}


return Constants
