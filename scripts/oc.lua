------------------------------------------------------------------------
-- all the optical connector management code
------------------------------------------------------------------------
assert(script)

local Is = require('stdlib.utils.is')

local tools = require('framework.tools')

local const = require('lib.constants')

------------------------------------------------------------------------

---@class ModOc
local Oc = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global optical connector data structure.
function Oc:init()
    if storage.oc_data then return end

    ---@type ModOcData
    storage.oc_data = {
        oc = {},
        iopins = {},
        count = 0,
        VERSION = const.current_version,
    }
end

------------------------------------------------------------------------
-- attribute getters/setters
------------------------------------------------------------------------

--- Returns the registered total count
---@return integer count The total count of optical connectors
function Oc:totalCount()
    return storage.oc_data.count
end

--- Returns data for all optical connectors.
---@return OpticalConnectorData[] entities
function Oc:entities()
    return storage.oc_data.oc
end

--- Returns data for a given optical connector
---@param entity_id integer main unit number (== entity id)
---@return OpticalConnectorData? entity
function Oc:entity(entity_id)
    return storage.oc_data.oc[entity_id]
end

--- Sets or clears a optical connector entity
---@param entity_id integer The unit_number of the primary
---@param oc_entity OpticalConnectorData?
function Oc:setEntity(entity_id, oc_entity)
    if (oc_entity and storage.oc_data.oc[entity_id]) then
        Framework.logger:logf('[BUG] Overwriting existing oc_entity for unit %d', entity_id)
    end

    storage.oc_data.oc[entity_id] = oc_entity
    storage.oc_data.count = storage.oc_data.count + ((oc_entity and 1) or -1)

    if storage.oc_data.count < 0 then
        storage.oc_data.count = table_size(storage.oc_data.oc)
        Framework.logger:logf('Optical Connector count got negative (bug), size is now: %d', storage.oc_data.count)
    end
end

--- Returns a map of all IO Pins (for text overlay)
---@return table<integer, integer> entities
function Oc:iopins()
    return storage.oc_data.iopins
end

-- Sets a new IO Pin reference
---@param iopin_id integer unit number of the iopin
---@param iopin_index integer? The IO Pin index (1 .. 16)
function Oc:setIOPin(iopin_id, iopin_index)
    storage.oc_data.iopins[iopin_id] = iopin_index
end

------------------------------------------------------------------------
-- create/destroy
------------------------------------------------------------------------

-- computes io pin position relative to an entity and the iopin index.
---@param cfg OcIopinPositionCfg
local function oc_iopin_position(cfg)
    -- find the right direction map
    local direction_id = const.iopin_directions[cfg.direction or cfg.main.direction][cfg.flip_index]

    -- find the iopin position
    local iopin_id = const.iopin_positions[direction_id][cfg.idx]
    local sprite_position = const.sprite_positions[iopin_id]

    return {
        x = cfg.main.position.x + sprite_position[1] / 64,
        y = cfg.main.position.y + sprite_position[2] / 64,
    }
end

local sub_entities = {
    { id = 'power_entity',      name = const.oc_power_interface, },                         -- Power Entity for power consumption
    { id = 'power_pole',        name = const.oc_power_pole,      dx = 0,    dy = 16 / 64 }, -- Power Pole for power connections
    { id = 'status_led_1',      name = const.oc_led_lamp,        dx = -0.2, dy = -0.02 },   -- Status Lamp 1
    { id = 'status_led_2',      name = const.oc_led_lamp,        dx = 0.2,  dy = -0.02 },   -- Status Lamp 2
    { id = 'status_controller', name = const.oc_cc, },                                      -- Status Controller
}

---@param cfg OcCreateInternalEntityCfg
function Oc.create_internal_entity(cfg)
    local oc_entity = cfg.entity
    local main = oc_entity.main

    local x = (cfg.pos and cfg.pos.x) or (main.position.x + (cfg.dx or 0))
    local y = (cfg.pos and cfg.pos.y) or (main.position.y + (cfg.dy or 0))

    local ghost = cfg.ghost
    local attached = cfg.attached

    ---@type LuaEntity?
    local sub_entity

    if ghost and ghost.entity then
        -- adopt any ghost, revive it and position it (flipping may move the pins around a bit)
        local _, entity = ghost.entity.silent_revive()
        if entity then
            entity.teleport { x, y }
            sub_entity = entity
        else
            ghost.entity.destroy()
            Framework.logger:logf("Could not revive ghost for '%s'", cfg.name)
        end
    elseif attached and attached.entity then
        if Is.Valid(attached.entity) then
            -- adopt an actual entity and position it
            sub_entity = attached.entity
            sub_entity.teleport { x, y }
        else
            attached.entity.destroy()
            Framework.logger:logf("Could not attach existing entity for '%s'", cfg.name)
        end
    end

    if not sub_entity then
        -- otherwise create a new entity
        sub_entity = main.surface.create_entity {
            name = cfg.name,
            position = { x = x, y = y },
            direction = main.direction,
            force = main.force,

            create_build_effect_smoke = false,
            spawn_decorations = false,
            move_stuck_players = true,
        }

        assert(sub_entity, "Could not create entity for '" .. cfg.name .. "'")
    end

    sub_entity.minable = false
    sub_entity.destructible = false
    sub_entity.operable = false

    oc_entity.entities[sub_entity.unit_number] = sub_entity

    return sub_entity
end

---@param section LuaLogisticSection
---@param idx integer
---@param value integer
local function set_slot_data(section, idx, value)
    local signal = { value = { type = 'virtual', name = 'signal-' .. idx, quality = 'normal' }, min = value, }
    section.set_slot(idx, signal)
end

---@param oc_entity OpticalConnectorData
local function setup_oc(oc_entity)
    -- power switch
    local pp_control = assert(oc_entity.ref.power_pole.get_or_create_control_behavior()) --[[@as LuaGenericOnOffControlBehavior ]]
    pp_control.connect_to_logistic_network = false

    local sl1_control = assert(oc_entity.ref.status_led_1.get_or_create_control_behavior()) --[[@as LuaLampControlBehavior]]
    sl1_control.circuit_enable_disable = true
    sl1_control.use_colors = false
    ---@diagnostic disable-next-line: missing-fields
    sl1_control.circuit_condition = { comparator = '=', first_signal = { type = 'virtual', name = 'signal-1', quality = 'normal', }, constant = 1, } --[[@as CircuitConditionDefinition ]]

    local sl2_control = assert(oc_entity.ref.status_led_2.get_or_create_control_behavior()) --[[@as LuaLampControlBehavior]]
    sl2_control.circuit_enable_disable = true
    sl1_control.use_colors = false
    ---@diagnostic disable-next-line: missing-fields
    sl2_control.circuit_condition = { comparator = '=', first_signal = { type = 'virtual', name = 'signal-2', quality = 'normal', }, constant = 1, } --[[@as CircuitConditionDefinition ]]

    local sc_control = assert(oc_entity.ref.status_controller.get_or_create_control_behavior()) --[[@as LuaConstantCombinatorControlBehavior]]
    if sc_control.sections_count < 1 then sc_control.add_section() end
    local sc_section = sc_control.sections[1]
    sc_section.filters = {
        { value = { type = 'virtual', name = 'signal-1', quality = 'normal' }, min = 0, },
        { value = { type = 'virtual', name = 'signal-2', quality = 'normal' }, min = 0, },
    }

    local controller_connector = oc_entity.ref.status_controller.get_wire_connector(defines.wire_connector_id.circuit_red, true)
    local led1_connector = oc_entity.ref.status_led_1.get_wire_connector(defines.wire_connector_id.circuit_red, true)
    local led2_connector = oc_entity.ref.status_led_2.get_wire_connector(defines.wire_connector_id.circuit_red, true)
    controller_connector.connect_to(led1_connector, false, defines.wire_origin.script)
    controller_connector.connect_to(led2_connector, false, defines.wire_origin.script)
end

--- Creates a new entity from the main entity, registers with the mod and configures it.
---@param cfg OcCreateCfg
---@return OpticalConnectorData? oc_entity
function Oc:create(cfg)
    if not (cfg.main and cfg.main.valid) then return nil end

    local entity_id = assert(cfg.main.unit_number)

    assert(self:entity(entity_id) == nil, "[BUG] main entity '" .. entity_id .. "' has already an oc_entity assigned!")

    -- deal with flipped entities. This is somewhat convoluted as there are
    -- two transformations: one by the current h/v flip (which can be done by
    -- flipping a blueprint) and the existing flips from the entity (if a flipped
    -- entity was picked up by a blueprint first).
    --
    -- For an added bonus, the oc uses an asymmetric image (pin 1 is marked green)
    -- so for a flipped image, the direction is actually not the direction of the
    -- main entity.

    -- undo the current flip. The entity now points in the direction if it had not been
    -- flipped through the blueprint
    local pre_build_flip_direction = const.correct_direction[cfg.main.direction][cfg.flip_index]

    -- the build code has put an existing flip into the tags (either from a blueprint ghost
    -- entity or from the event if this is a direct build.
    -- this is an optional value; if no tag was found, it uses index 1 ("no flips")
    local existing_flip_index = cfg.tags and cfg.tags[const.flip_index_tag] or 1

    -- the image was corrected so that pin 1 was in the right location when it was created
    -- undo this here. The main entity now points in the correct direction without any flips
    -- this allows finding the right spots for all the io points.
    local pre_image_flip_direction = const.correct_image[pre_build_flip_direction][existing_flip_index]

    -- this is the direction that is needed for all the iopin calculations
    cfg.main.direction = pre_image_flip_direction

    -- now the flip index includes both the tags from a blueprint and the current flips
    local final_flip_index = const.total_flip[existing_flip_index][cfg.flip_index]

    -- the final image may need to point in a different direction so that pin 1 aligns
    -- correctly. Create that direction and store it.
    local final_direction = const.correct_image[pre_image_flip_direction][final_flip_index]

    ---@type OpticalConnectorData
    local oc_entity = {
        main = cfg.main,                         -- reference to the main entity. This is a shortcut for 'ref.main' because ... lazy
        status = defines.entity_status.disabled, -- status of the OC. Is managed by the update_entity_status
        entities = {},                           -- unit_number to sub entities map. Allows reference to unit_number even if the sub_entity is invalid. Used by deletion and move code
        ref = { main = cfg.main },               -- named references to sub entities. Used by all the code that wants to address a specific sub entity.
        iopin = {},                              -- iopin index (1 - 16) to iopin entity map.
        connected_networks = {},                 -- connected network ids. Used to find network information.
        flip_index = final_flip_index,           -- the flip index of the entity (bit 1 is H flip, bit 2 is V flip)
    }

    -- create the basic innards
    for _, sub_entity in pairs(sub_entities) do
        oc_entity.ref[sub_entity.id] = self.create_internal_entity {
            entity = oc_entity,
            name = sub_entity.name,
            ghost = cfg.ghosts[sub_entity.name],
            attached = cfg.attached[sub_entity.name],
            dx = sub_entity.dx,
            dy = sub_entity.dy,
        }
    end

    -- create the io pins
    for idx = 1, const.oc_iopin_count, 1 do
        local iopin_pos = oc_iopin_position {
            main = cfg.main,
            idx = idx,
            flip_index = final_flip_index,
        }

        local iopin_entity = self.create_internal_entity {
            entity = oc_entity,
            name = (idx == 1) and const.iopin_one_name or const.iopin_name,
            -- ghosts and attached entities were stored using the iopin index (because they may have the same name)
            ghost = cfg.ghosts[idx],
            attached = cfg.attached[idx],
            pos = iopin_pos,
        }

        oc_entity.iopin[idx] = iopin_entity

        self:setIOPin(iopin_entity.unit_number, idx)
    end

    setup_oc(oc_entity)
    self:setEntity(entity_id, oc_entity)

    -- finally point the entity in the final direction so that the image lines up
    -- with the IO pins. If the entity was not flipped anywhere, all of those transformations
    -- end up being neutral and nothing changed.
    oc_entity.main.direction = final_direction

    return oc_entity
end

------------------------------------------------------------------------
-- control status of the optical connector
------------------------------------------------------------------------

---@param entity OpticalConnectorData
---@param network_id integer
function Oc:disconnect_network(entity, network_id)
    local network = This.network:locate_network(entity.main, network_id)
    if not network then return true end

    This.network:remove_endpoint(entity.main, network_id)

    for idx = 1, const.oc_iopin_count, 1 do
        local iopin = entity.iopin[idx]
        local fiber_strand = network.connectors[idx]

        if Is.Valid(iopin) and Is.Valid(fiber_strand) then
            for _, circuit in pairs { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green } do
                local connector = iopin.get_wire_connector(circuit, true)
                local target = fiber_strand.get_wire_connector(circuit, true)
                connector.disconnect_from(target, defines.wire_origin.script)
            end
        end
    end
end

---@param entity OpticalConnectorData
---@param network_id integer
function Oc:connect_network(entity, network_id)
    local network = This.network:locate_network(entity.main, network_id)

    if not network then return true end

    This.network:add_endpoint(entity.main, network_id)

    for idx = 1, const.oc_iopin_count, 1 do
        local iopin = entity.iopin[idx]
        local fiber_strand = network.connectors[idx]

        if Is.Valid(iopin) and Is.Valid(fiber_strand) then
            for _, circuit in pairs { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green } do
                local connector = iopin.get_wire_connector(circuit, true)
                local target = fiber_strand.get_wire_connector(circuit, true)
                connector.connect_to(target, false, defines.wire_origin.script)
            end
        end
    end
end

---@param power_pole LuaEntity
---@return table<integer, integer> network_map
local function get_connected_networks(power_pole)
    local result = {}
    if not Is.Valid(power_pole) then return result end

    local idx = 1
    for _, connector in pairs { defines.wire_connector_id.power_switch_left_copper, defines.wire_connector_id.power_switch_right_copper } do
        local wire_connector = power_pole.get_wire_connector(connector, true)
        local connected = wire_connector.network_id > 0 or wire_connector.real_connection_count > 0 -- https://forums.factorio.com/viewtopic.php?t=127085

        if connected and not result[wire_connector.network_id] then
            result[wire_connector.network_id] = idx
            idx = idx + 1
        end
    end

    return result
end

---@param entity OpticalConnectorData
---@param force boolean? If true, force disconnect and reconnect
function Oc:update_entity_status(entity, force)
    if not (entity and Is.Valid(entity.main)) then return end

    entity.status = entity.ref.power_entity.status or defines.entity_status.disabled

    -- check connected networks
    local changes = false
    local signals = { 0, 0 }
    local active_signals = 0

    -- if the unit is in red status, disconnect all networks
    local current_networks = ((tools.STATUS_NAMES[entity.status] == 'RED') and {}) or get_connected_networks(entity.ref.power_pole)

    -- disconnect missing networks
    for network_id in pairs(entity.connected_networks) do
        if (not current_networks[network_id]) or force then
            self:disconnect_network(entity, network_id)
            changes = true
        end
    end

    -- connect new networks
    for network_id, idx in pairs(current_networks) do
        signals[idx] = 1
        active_signals = active_signals + 1
        if not entity.connected_networks[network_id] or force then
            self:connect_network(entity, network_id)
            changes = true
        end
    end

    if changes then
        local sc_control = assert(entity.ref.status_controller.get_or_create_control_behavior()) --[[@as LuaConstantCombinatorControlBehavior]]
        if sc_control.sections_count < 1 then sc_control.add_section() end
        local sc_section = sc_control.sections[1]
        
        local filters = {}

        -- idx is the led to turn on/off, count is 0 for off or 1 for on
        for idx, value in pairs(signals) do
            filters[idx] = { value = { type = 'virtual', name = 'signal-' .. tostring(idx), quality = 'normal' }, min = value, }
        end

        sc_section.filters = filters

        entity.connected_networks = current_networks
        entity.ref.power_entity.power_usage = (1000 * (1 + active_signals * 8)) / 60.0
    end
end

---@param entity_id integer
---@return boolean True if an entity was destroyed
function Oc:destroy(entity_id)
    local oc_entity = self:entity(entity_id)
    if not oc_entity then return false end

    for id, sub_entity in pairs(oc_entity.entities) do
        self:setIOPin(id)
        sub_entity.destroy()
    end

    self:setEntity(entity_id, nil)
    return true
end

------------------------------------------------------------------------
-- Move OC (Picker Dollies code)
------------------------------------------------------------------------

local msg_wires_too_long = const:with_prefix('messages.wires_too_long')

--- check whether connected wires can be stretched. Returns false if the wire
--- could not be stretched to the new position.
---@param entity LuaEntity
---@param new_pos MapPosition
---@param player LuaPlayer
local function check_wire_stretch(entity, new_pos, player)
    local src_pos = entity.position

    -- move entity temporarily to check wire reach
    if not entity.teleport(new_pos) then
        return false
    end

    for _, wire_connection in pairs(entity.get_wire_connectors(true)) do
        for _, target_connection in pairs(wire_connection.connections) do
            if not (const.internal_entities[wire_connection.owner.name] and const.internal_entities[target_connection.target.owner.name]) then
                local vetoed = not wire_connection.can_wire_reach(target_connection.target)

                if vetoed then
                    player.create_local_flying_text {
                        position = entity.position,
                        text = { msg_wires_too_long },
                    }

                    -- move back
                    entity.teleport(src_pos)
                    return false
                end
            end
        end
    end

    -- move back
    entity.teleport(src_pos)
    return true
end

function Oc:move(main, start_pos, player)
    if not Is.Valid(main) then return end

    local oc_entity = self:entity(main.unit_number)
    if not oc_entity then return end

    local dx = main.position.x - start_pos.x
    local dy = main.position.y - start_pos.y

    local move_list = {}

    for idx, related_entity in pairs(oc_entity.entities) do
        local dst_pos = {
            x = related_entity.position.x + dx,
            y = related_entity.position.y + dy,
        }

        if not check_wire_stretch(related_entity, dst_pos, player) then
            -- move entity back, end
            main.teleport(start_pos)
            return
        end

        move_list[idx] = dst_pos
    end

    for idx, related_entity in pairs(oc_entity.entities) do
        related_entity.teleport(move_list[idx])
    end
end

------------------------------------------------------------------------
-- Rotate OC
------------------------------------------------------------------------

--- rotates the iopins to the new orientation of the entity and tests whether the
--- wires overstretch.
---@param main LuaEntity The base entity for the io pins
---@param oc_entity OpticalConnectorData
---@param player LuaPlayer The player doing the moving
---@return boolean vetoed If true, vetoed the move
---@return MapPosition[] iopin_positions Array of new positions for the io pins. Only valid if not vetoed.
local function rotate_iopins(main, oc_entity, player)
    local move_list = {}
    for idx = 1, const.oc_iopin_count, 1 do
        local dst_pos = oc_iopin_position {
            main = main,
            idx = idx,
            flip_index = oc_entity.flip_index or 1,
        }

        local iopin = oc_entity.iopin[idx]
        if not check_wire_stretch(iopin, dst_pos, player) then
            return true, {}
        end

        move_list[idx] = dst_pos
    end
    return false, move_list
end

-- see if we can rotate the connector. The io pins move around
-- when rotating, so check whether there are stretched wires.

---@param main LuaEntity
---@param player_index integer?
function Oc:rotate(main, player_index, previous_direction)
    if not Is.Valid(main) then return end

    local oc_entity = self:entity(main.unit_number)
    if not oc_entity then return end

    -- reverse the image correction
    local rotated_direction = const.correct_image[main.direction][oc_entity.flip_index]
    main.direction = rotated_direction

    local player = game.players[player_index] -- don't use the stdlib players module
    local vetoed, rotated_io_pins = rotate_iopins(main, oc_entity, player)

    if vetoed then
        main.direction = previous_direction
    else
        for idx = 1, const.oc_iopin_count, 1 do
            oc_entity.iopin[idx].teleport(rotated_io_pins[idx])
        end

        -- redo image correction
        main.direction = const.correct_image[main.direction][oc_entity.flip_index]
    end
end

------------------------------------------------------------------------
-- IO Pin identification
------------------------------------------------------------------------

local msg_iopin_caption = const:with_prefix('messages.iopin_caption')
local text_color = {
    { 1,   1,   1, },  -- none
    { 1,   0.5, 0.5 }, -- red
    { 0.5, 1,   0.5 }, -- green
    { 1,   1,   0.5 }, -- red and green
}

---@param wire_connector  LuaWireConnector
---@return integer connection_count
local function get_connection_count(wire_connector)
    if not wire_connector or wire_connector.connection_count == 0 then return 0 end

    local count = 0
    for _, connection in pairs(wire_connector.connections) do
        -- do not count connections to internal things
        if not const.internal_entities[connection.target.owner.name] then
            count = count + 1
        end
    end

    return count
end

function Oc:displayPinCaption(entity, player_index)
    local iopin_idx = self:iopins()[entity.unit_number]
    if not iopin_idx then return end

    local wire_connectors = entity.get_wire_connectors(true)

    local red_count = get_connection_count(wire_connectors[defines.wire_connector_id.circuit_red])
    local green_count = get_connection_count(wire_connectors[defines.wire_connector_id.circuit_green])

    local color_index = 1
    -- > 1 b/c every pin is connected to a network
    color_index = color_index + ((red_count > 0) and 1 or 0)
    color_index = color_index + ((green_count > 0) and 2 or 0)

    Framework.render:renderText(player_index, {
        text = { msg_iopin_caption, iopin_idx },
        surface = entity.surface,
        target = entity,
        color = text_color[color_index],
        only_in_alt_mode = false,
        alignment = 'center',
        target_offset = { 0, -0.7 },
        use_rich_text = true
    })
end

------------------------------------------------------------------------
-- Ticker
------------------------------------------------------------------------

---@param force boolean? Force disconnect and reconnect of all OCs
function Oc:tick(force)
    for idx, entity in pairs(self:entities()) do
        self:update_entity_status(entity, force)

        if Framework.settings:startup_setting('debug_mode') then
            local power_entity = entity.ref.power_entity
            Framework.logger:debugf('Connector %d, current energy usage %4.1d kW', idx, (power_entity.power_usage * 60) / 1000.0)
            Framework.logger:debugf('Connector %d, charge: %d, drain: %d, capacity: %d', idx, power_entity.power_production, power_entity.electric_drain,
                power_entity.electric_buffer_size)
        end
    end
end

------------------------------------------------------------------------
return Oc
