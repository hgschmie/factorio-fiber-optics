--
-- all the optical connector management code
--

local const = require('lib.constants')
local tools = require('lib.tools')
local context_manager = require('lib.context')

---------------------------------------------------------------------------------------------------------


-- computes io pin position relative to an entity and the iopin index.
local function oc_iopin_position(entity, idx, direction)
    local offset = const.iopin_connection_points[direction or entity.direction][idx]

    local x_off = 0.02 + offset[1] * 0.35
    local y_off = 0.02 + offset[2] * 0.35

    return {
        x = entity.position.x + x_off,
        y = entity.position.y + y_off,
    }
end

local function oc_idx_from_iopin(iopin)
    if not iopin or not iopin.valid then return end

    local s, e = iopin.name:find(const.oc_iopin_prefix, 1, true)
    if s ~= 1 then return end
    return tonumber(iopin.name:sub(e + 1))
end

---------------------------------------------------------------------------------------------------------

--- rotates the iopins to the new orientation of the entity and tests whether the
--- wires overstretch.
---@param entity LuaEntity The base entity for the io pins
---@param iopins LuaEntity[] Array of IO pins to move
---@param player LuaPlayer The player doing the moving
---@return boolean vetoed If true, vetoed the move
---@return MapPosition[] iopin_positions Array of new positions for the io pins. Only valid if not vetoed.
local function rotate_iopins(entity, iopins, player)
    local entity_context = context_manager:get_entity_context(entity, false)
    if not tools.is_valid(entity_context) then return true, {} end

    local move_list = {}
    for idx, io_pin in pairs(iopins) do
        local dst_pos = oc_iopin_position(entity, idx)
        if tools.check_wire_stretch(io_pin, dst_pos, player) then
            return true, {}
        end

        move_list[idx] = dst_pos
    end
    return false, move_list
end


-- see if we can rotate the connector. The io pins move around
-- when rotating, so check whether there are stretched wires.
local function oc_rotate_event_handler(entity, event)
    if not tools.is_valid(entity) or entity.name ~= const.optical_connector then return end

    local entity_context = context_manager:get_entity_context(entity, false)
    if not tools.is_valid(entity_context) then return end

    local player = game.players[event.player_index]
    local vetoed, rotated_io_pins = rotate_iopins(entity, entity_context.iopins, player)

    if vetoed then
        entity.direction = event.previous_direction
    else
        for idx, io_pin in pairs(entity_context.iopins) do
            io_pin.teleport(rotated_io_pins[idx])
        end
    end
end

---------------------------------------------------------------------------------------------------------

--- Creates a specific, related entity for a primary entity (an optical connector). Looks whether
-- a ghost has been placed before and if yes, picks it up. This allows e.g. wires to be reconnected
-- when pasting from a blueprint (or cut and paste).
--- @param primary_entity LuaEntity The primary entity (optical_connector)
---@param entity_name string The name of the new entity to create or recover.
---@param position table|function|nil Position for the new entity.
---@param ghosts LuaEntity[]? An array of ghost entities that should be considered for revival.
local function create_related_entity(primary_entity, entity_name, position, ghosts)
    local entity

    if not position then
        position = primary_entity.position
    elseif type(position) == 'function' then
        position = position(primary_entity)
    end

    if ghosts and #ghosts > 0 then
        for _, ghost in pairs(ghosts) do
            if ghost.valid and ghost.ghost_name == entity_name then
                local _, revived_entity = ghost.silent_revive()
                assert(revived_entity, "Ghost could not be revived!")
                entity = revived_entity
                entity.teleport(position)
                break
            end
        end
    end

    if not entity then
        entity = primary_entity.surface.create_entity {
            name = entity_name,
            position = position,
            force = primary_entity.force,
        }
    end

    entity.minable = false
    entity.destructible = false
    entity.operable = false
    return entity
end

-- augments the initial entity with all the additional entities that make up the OC.
local function oc_create_optical_connector(primary_entity)
    -- only deal with optical connectors
    if not tools.is_valid(primary_entity) or primary_entity.name ~= const.optical_connector then return primary_entity end

    local entity_context = context_manager:get_entity_context(primary_entity, true)

    script.register_on_entity_destroyed(primary_entity)

    -- find all possible ghosts that may have been placed before this entity
    local ghosts = tools.find_entities(primary_entity, nil, { name = 'entity-ghost' })

    -- add the power entity for power consumption
    context_manager:add_entity_if_not_exists(primary_entity, "power_entity", function()
        return create_related_entity(primary_entity, const.oc_power_interface, nil, ghosts)
    end)

    -- power pole to connect the copper wires (connect to the fiber optic cables)
    context_manager:add_entity_if_not_exists(primary_entity, "power_pole", function()
        local entity = create_related_entity(primary_entity, const.oc_power_pole, nil, ghosts)

        ---@type LuaLampControlBehavior?
        local control = entity.get_or_create_control_behavior()
        assert(control, "where is my control?")
        control.connect_to_logistic_network = false

        return entity
    end)

    -- status lamp 1
    context_manager:add_entity_if_not_exists(primary_entity, "lamp1", function()
        local entity = create_related_entity(primary_entity, const.oc_led_lamp, { primary_entity.position.x - 0.2, primary_entity.position.y - 0.02 }, ghosts)

        ---@type LuaLampControlBehavior?
        local control = entity.get_or_create_control_behavior()
        assert(control, "where is my control?")
        control.circuit_condition = {
            condition = { comparator = "=", first_signal = { type = "virtual", name = "signal-1" }, constant = 1 },
            connect_to_logistic_network = false,
        }
        return entity
    end)

    -- status lamp 2
    context_manager:add_entity_if_not_exists(primary_entity, "lamp2", function()
        local entity = create_related_entity(primary_entity, const.oc_led_lamp, { primary_entity.position.x + 0.2, primary_entity.position.y - 0.02 }, ghosts)

        ---@type LuaLampControlBehavior?
        local control = entity.get_or_create_control_behavior()
        assert(control, "where is my control?")
        control.circuit_condition = {
            condition = { comparator = "=", first_signal = { type = "virtual", name = "signal-2" }, constant = 1 },
            connect_to_logistic_network = false,
        }

        return entity
    end)

    context_manager:add_entity_if_not_exists(primary_entity, "cc", function(context)
        local entity = create_related_entity(primary_entity, const.oc_cc, nil, ghosts)

        ---@type LuaConstantCombinatorControlBehavior?
        local control = entity.get_or_create_control_behavior()
        assert(control, "where is my control?")
        control.parameters = {
            { index = 1, count = 0, signal = { type = "virtual", name = "signal-1" } },
            { index = 2, count = 0, signal = { type = "virtual", name = "signal-2" } },
        }

        entity.connect_neighbour { wire = defines.wire_type.red, target_entity = entity_context.lamp1 }
        entity.connect_neighbour { wire = defines.wire_type.green, target_entity = entity_context.lamp2 }

        return entity
    end)

    for idx = 1, const.oc_iopin_count, 1 do
        context_manager:add_entity_if_not_exists(primary_entity, { "iopins", idx }, function()
            return create_related_entity(primary_entity, const.iopin_name(idx), oc_iopin_position(primary_entity, idx), ghosts)
        end)
    end

    context_manager:set_field_if_not_exists(primary_entity, 'connected_networks', {})

    return primary_entity
end

---------------------------------------------------------------------------------------------------------

local function oc_remove_optical_connector(primary_entity)
    -- only deal with optical connectors
    if not tools.is_valid(primary_entity) or primary_entity.name ~= const.optical_connector then return primary_entity end

    context_manager:cleanup(primary_entity)
end

---------------------------------------------------------------------------------------------------------

local function find_oc_from_entity(entity)
    local entities = tools.find_entities(entity, nil, { name = const.optical_connector })
    for _, found_entity in pairs(entities) do
        if found_entity.valid and found_entity.name == const.optical_connector then
            local oc_context = context_manager:get_entity_context(found_entity, false)
            if tools.is_valid(oc_context) then
                return found_entity, oc_context
            end
        end
    end
end

local function oc_entity_ghosts(primary_entity)
    if not tools.is_valid(primary_entity) or primary_entity.type ~= 'entity-ghost' then return end
    if not tools.array_contains(const.attached_entities, primary_entity.ghost_name) then return end

    local existing_oc = find_oc_from_entity(primary_entity)
    if (existing_oc) then
        local _, revived_entity = primary_entity.silent_revive()
        if tools.is_valid(revived_entity) then
            -- deal with io pins
            if tools.array_contains(const.all_iopins, revived_entity.name) then
                local idx = oc_idx_from_iopin(revived_entity)
                local old_pin = context_manager:remove_entity(existing_oc, { 'iopins', idx })
                if old_pin and old_pin.valid then
                    old_pin.destroy()
                end

                context_manager:add_entity(existing_oc, { 'iopins', idx }, revived_entity)
                revived_entity.direction = existing_oc.direction
                revived_entity.teleport(oc_iopin_position(existing_oc, idx))
            elseif revived_entity.name == const.oc_power_pole then
                local old_power_pole = context_manager:remove_entity(existing_oc, 'power_pole')
                if old_power_pole and old_power_pole.valid then
                    old_power_pole.destroy()
                end
                context_manager:add_entity(existing_oc, 'power_pole')
                revived_entity.direction = existing_oc.direction
                revived_entity.teleport(existing_oc.position)
            else
                -- everything else can be destroyed
                revived_entity.destroy()
            end
        end
    end
end

---------------------------------------------------------------------------------------------------------

--- Required for undo/robot construction to clean up anything attached.
local function oc_entity_deconstruction(attached_entity)
    -- only deal with attached objects
    if not (tools.is_valid(attached_entity) and tools.array_contains(const.attached_entities, attached_entity.name)) then return attached_entity end

    attached_entity.destroy()
end

---------------------------------------------------------------------------------------------------------

local function oc_entity_destroyed(event)
    context_manager:cleanup(event.unit_number)
end

---------------------------------------------------------------------------------------------------------

local function oc_init()

    local oc_entity_filter = {
        { filter = 'name', name = const.optical_connector },
    }

    local oc_ghost_filter = {}
    local oc_attached_entities_filter = {}

    for _, name in pairs(const.attached_entities) do
        table.insert(oc_ghost_filter, { filter = 'ghost_name', name = name })
        table.insert(oc_attached_entities_filter, { filter = 'name', name = name })
    end


    tools.register_entity_event(defines.events.on_player_rotated_entity, oc_rotate_event_handler)


    tools.register_entity_event({ defines.events.on_built_entity,
                                    defines.events.on_robot_built_entity,
                                    defines.events.script_raised_built,
                                    defines.events.script_raised_revive,
                                }, oc_create_optical_connector, oc_entity_filter)
    tools.register_entity_event({ defines.events.on_player_mined_entity,
                                    defines.events.on_robot_mined_entity,
                                    defines.events.on_entity_died,
                                    defines.events.script_raised_destroy,
                                }, oc_remove_optical_connector, oc_entity_filter)

    tools.register_entity_event({ defines.events.on_built_entity,
                                    defines.events.on_robot_built_entity,
                                    defines.events.script_raised_built,
                                    defines.events.script_raised_revive,
                                }, oc_entity_ghosts, oc_ghost_filter)

    tools.register_entity_event(defines.events.on_marked_for_deconstruction, oc_entity_deconstruction, oc_attached_entities_filter)

    tools.register_event(defines.events.on_entity_destroyed, oc_entity_destroyed)
end

return {
    init = oc_init,
}
