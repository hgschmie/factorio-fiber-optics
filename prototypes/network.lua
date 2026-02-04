------------------------------------------------------------------------
-- Network entities
------------------------------------------------------------------------

-- for default_circuit_wire_max_distance
require 'circuit-connector-sprites'

local collision_mask_util = require('collision-mask-util')
local util = require('util')

local const = require('lib.constants')

--- @type data.ContainerPrototype
local fiber_hub_entity = {
    -- PrototypeBase
    type = 'container',
    name = const.fiber_hub_name,
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
    collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    collision_mask = collision_mask_util.new_mask(),
    selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    flags = const.prototype_hidden_entity_flags,
    minable = nil,
    allow_copy_paste = false,
    selectable_in_game = false,
    selection_priority = 1,
}

data:extend { fiber_hub_entity }
