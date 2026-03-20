------------------------------------------------------------------------
-- Fiber Optics GUI
------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')
local table = require('stdlib.utils.table')
local string = require('stdlib.utils.string')
local Position = require('stdlib.area.position')

local Matchers = require('framework.matchers')
local tools = require('framework.tools')

local signal_converter = require('framework.signal_converter')

local const = require('lib.constants')

local SIGNAL_COLUMN_COUNT = 8

---@class fo.Gui
---@field NAME string
local Gui = {
    NAME = 'fiber-optics-gui',
}

----------------------------------------------------------------------------------------------------
-- UI definition
----------------------------------------------------------------------------------------------------

---@return framework.gui.element_definitions[]
local function create_signal_fields()
    local result = {}
    for i = 1, This.pin.MAX_PIN_COUNT do
        local idx = bit32.band(i - 1, 1) * 8 + bit32.rshift(i - 1, 1) + 1
        result[i] = {
            type = 'flow',
            direction = 'vertical',
            children = {
                {
                    type = 'label',
                    style = 'semibold_label',
                    style_mods = {
                        top_padding = 8, -- pad a bit to create visual space
                    },
                    caption = { const:locale('iopin_caption'), idx },
                },
                {
                    type = 'scroll-pane',
                    style = 'deep_slots_scroll_pane',
                    direction = 'vertical',
                    vertical_scroll_policy = 'auto-and-reserve-space',
                    horizontal_scroll_policy = 'never',
                    style_mods = {
                        width = 40 * SIGNAL_COLUMN_COUNT,
                    },
                    children = {
                        {
                            type = 'table',
                            style = 'filter_slot_table',
                            name = ('signal-view-%d'):format(idx),
                            column_count = SIGNAL_COLUMN_COUNT,
                            style_mods = {
                                vertical_spacing = 4,
                            },
                        },
                    },
                },
            },
        }
    end

    return result
end


--- Provides all the events used by the GUI and their mappings to functions. This must be outside the
--- GUI definition as it can not be serialized into storage.
---@return framework.gui_manager.event_definition
local function get_gui_event_definition()
    return {
        events = {
            onWindowClosed = Gui.onWindowClosed,
            onSwitchEnabled = Gui.onSwitchEnabled,
            onStrandChanged = Gui.onStrandChanged,
            onStrandDeleted = Gui.onStrandDeleted,
            onNewStrandChanged = Gui.onNewStrandChanged,
            onNewStrandConfirmed = Gui.onNewStrandConfirmed,
        },
        callback = Gui.guiUpdater,
    }
end

--- Returns the definition of the GUI. All events must be mapped onto constants from the gui_events array.
---@param gui framework.gui
---@return framework.gui.element_definition ui
function Gui.getUi(gui)
    local gui_events = gui.gui_events

    local fo_entity = assert(This.fo:getEntity(gui.entity_id))

    return {
        type = 'frame',
        name = 'gui_root',
        direction = 'vertical',
        handler = { [defines.events.on_gui_closed] = gui_events.onWindowClosed },
        elem_mods = { auto_center = true },
        children = {
            { -- Title Bar
                type = 'flow',
                style = 'frame_header_flow',
                drag_target = 'gui_root',
                children = {
                    {
                        type = 'label',
                        style = 'frame_title',
                        caption = { 'entity-name.' .. const.main_entity_name },
                        drag_target = 'gui_root',
                        ignored_by_interaction = true,
                    },
                    {
                        type = 'empty-widget',
                        style = 'framework_titlebar_drag_handle',
                        ignored_by_interaction = true,
                    },
                    {
                        type = 'sprite-button',
                        style = 'frame_action_button',
                        sprite = 'utility/close',
                        hovered_sprite = 'utility/close_black',
                        clicked_sprite = 'utility/close_black',
                        mouse_button_filter = { 'left' },
                        handler = { [defines.events.on_gui_click] = gui_events.onWindowClosed },
                    },
                },
            }, -- Title Bar End
            {  -- Body
                type = 'frame',
                style = 'entity_frame',
                -- style_mods = { width = 424, }, -- fix width of the window to match the signal bottom
                children = {
                    {
                        type = 'flow',
                        style = 'two_module_spacing_vertical_flow',
                        direction = 'vertical',
                        children = {
                            {
                                type = 'frame',
                                direction = 'horizontal',
                                style = 'framework_subheader_frame',
                                children = {
                                    {
                                        type = 'label',
                                        style = 'subheader_label',
                                        name = 'connections',
                                    },
                                    {
                                        type = 'label',
                                        style = 'label',
                                        name = 'connection-wires',
                                        visible = false,
                                    },
                                    {
                                        type = 'empty-widget',
                                        style_mods = { horizontally_stretchable = true },
                                    },
                                },
                            },
                            {
                                type = 'flow',
                                style = 'framework_indicator_flow',
                                children = {
                                    {
                                        type = 'sprite',
                                        name = 'status-lamp',
                                        style = 'framework_indicator',
                                    },
                                    {
                                        type = 'label',
                                        style = 'label',
                                        name = 'status-label',
                                    },
                                    {
                                        type = 'empty-widget',
                                        style_mods = { horizontally_stretchable = true },
                                    },
                                    {
                                        type = 'label',
                                        style = 'label',
                                        caption = { const:locale('id'), fo_entity.main.unit_number, },
                                    },
                                },
                            },
                            {
                                type = 'line',
                            },
                            {
                                type = 'label',
                                style = 'semibold_label',
                                caption = { const:locale('transceiver') },
                            },
                            {
                                type = 'switch',
                                name = 'on-off',
                                right_label_caption = { 'description.enabled' },
                                left_label_caption = { 'description.disabled' },
                                handler = { [defines.events.on_gui_switch_state_changed] = gui_events.onSwitchEnabled },
                            },
                            {
                                type = 'label',
                                style = 'semibold_label',
                                caption = { const:locale('strand') },
                                style_mods = {
                                    top_padding = 8, -- pad a bit to create visual space between the on-off switch and the label
                                },
                            },
                            {
                                type = 'flow',
                                direction = 'horizontal',
                                style_mods = {
                                    vertical_align = 'center',
                                },
                                children = {
                                    {
                                        type = 'drop-down',
                                        name = 'strand_select',
                                        handler = { [defines.events.on_gui_selection_state_changed] = gui_events.onStrandChanged },
                                        items = {},
                                    },
                                    {
                                        type = 'sprite-button',
                                        name = 'strand_delete',
                                        style = 'tool_button_red',
                                        sprite = 'utility/trash',
                                        mouse_button_filter = { 'left' },
                                        handler = { [defines.events.on_gui_click] = gui_events.onStrandDeleted },
                                    },
                                    {
                                        type = 'label',
                                        style = 'semibold_label',
                                        caption = { const:locale('add') },
                                        style_mods = {
                                            left_padding = 8, -- pad a bit to create visual space to the delete button
                                        },
                                    },
                                    {
                                        type = 'textfield',
                                        name = 'strand_text',
                                        lose_focus_on_confirm = true,
                                        clear_and_focus_on_right_click = true,
                                        icon_selector = true,
                                        handler = {
                                            [defines.events.on_gui_text_changed] = gui_events.onNewStrandChanged,
                                            [defines.events.on_gui_confirmed] = gui_events.onNewStrandConfirmed,
                                        },
                                    },
                                },
                            },
                            {
                                type = 'flow',
                                direction = 'vertical',
                                children = {
                                    {
                                        type = 'scroll-pane',
                                        direction = 'vertical',
                                        visible = true,
                                        vertical_scroll_policy = 'auto',
                                        horizontal_scroll_policy = 'never',
                                        style_mods = {
                                            horizontally_stretchable = true,
                                            horizontally_squashable = true,
                                            vertically_stretchable = false,
                                        },
                                        children = {
                                            {
                                                type = 'table',
                                                style = 'table',
                                                name = 'signals',
                                                column_count = 2,
                                                style_mods = {
                                                    margin = 4,
                                                    cell_padding = 2,
                                                },
                                                children = create_signal_fields(),
                                            },
                                        }, -- children
                                    },     -- scroll-pane
                                },         -- children
                            },
                        },
                    },
                },
            },
        },
    }
end

----------------------------------------------------------------------------------------------------
-- UI Callbacks
----------------------------------------------------------------------------------------------------

--- close the UI (button or shortcut key)
---
---@param event EventData.on_gui_click|EventData.on_gui_opened
function Gui.onWindowClosed(event)
    Framework.gui_manager:destroy_gui(event.player_index)
end

local on_off_values = {
    left = false,
    right = true,
}

local values_on_off = table.invert(on_off_values)

--- Enable / Disable switch
---
---@param event EventData.on_gui_switch_state_changed
---@param gui framework.gui
function Gui.onSwitchEnabled(event, gui)
    local fo_entity = This.fo:getEntity(gui.entity_id)
    if not fo_entity then return end

    fo_entity.config.enabled = on_off_values[event.element.switch_state]
    This.fo:updateEntityStatus(fo_entity, true)
end

--- Select strand on the dropdown
---
---@param event EventData.on_gui_selection_state_changed
---@param gui framework.gui
function Gui.onStrandChanged(event, gui)
    local element = event.element

    local fo_entity = This.fo:getEntity(gui.entity_id)
    if not fo_entity then return end

    if element.selected_index > 0 and element.items[element.selected_index] then
        fo_entity.config.strand_name = element.items[element.selected_index]

        ---@type fo.GuiContext
        local context = gui.context
        context.new_strand_name = ''
    end
end

---@param event EventData.on_gui_click
---@param gui framework.gui
function Gui.onStrandDeleted(event, gui)
    local fo_entity = This.fo:getEntity(gui.entity_id)
    if not fo_entity then return end

    local strand_select = assert(gui:find_element('strand_select'))
    if strand_select.selected_index < 1 then return end

    local strand_name = strand_select.items[strand_select.selected_index]
    if strand_name == 'default' then return end

    ---@type fo.GuiContext
    local context = gui.context
    context.new_strand_name = ''

    This.network:destroyFiberStrandAndReconnectEntities(fo_entity, strand_name)
end

--- Something was typed in the text box for new strands
---
---@param event EventData.on_gui_text_changed
---@param gui framework.gui
function Gui.onNewStrandChanged(event, gui)
    ---@type fo.GuiContext
    local context = gui.context

    context.new_strand_name = event.text
end

--- The text box was confirmed
---
---@param event EventData.on_gui_confirmed
---@param gui framework.gui
function Gui.onNewStrandConfirmed(event, gui)
    local fo_entity = This.fo:getEntity(gui.entity_id)
    if not fo_entity then return end

    local text = event.element.text:trim()
    if text:len() > 0 then
        fo_entity.config.strand_name = text
    end

    ---@type fo.GuiContext
    local context = gui.context
    context.new_strand_name = ''
end

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------

---@param fo_entity fo.FiberOptics
---@return string[] strand_items
---@return integer strand_index
local function create_strand_items(fo_entity)
    local strands = {
        [fo_entity.config.strand_name] = true
    }

    local entity = fo_entity.main
    for network_id in pairs(fo_entity.networks) do
        local network = This.network:getOrCreateFiberNetwork(entity.surface_index, entity.force_index, network_id)
        for strand_name in pairs(network) do
            strands[strand_name] = true
        end
    end

    local strand_items = table.keys(strands, true, true)
    local _, strand_index = table.find(strand_items, function(v) return v == fo_entity.config.strand_name end)

    return strand_items, strand_index or 0
end

local color_map = {
    [defines.wire_connector_id.circuit_red] = 'red',
    [defines.wire_connector_id.circuit_green] = 'green',
}

---@param gui framework.gui
---@param fo_entity fo.FiberOptics
---@param idx integer
local function add_signals(gui, fo_entity, idx)
    local gui_element = assert(gui:find_element(('signal-view-%d'):format(idx)))
    gui_element.clear()

    local signal_count = 0
    for _, connector_id in pairs { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green } do
        local signals = fo_entity.iopin[idx].get_signals(connector_id)
        if signals then
            for _, signal in ipairs(signals) do
                gui_element.add {
                    type = 'sprite-button',
                    sprite = signal_converter:signal_to_sprite_name(signal),
                    number = signal.count,
                    quality = signal.signal.quality,
                    style = color_map[connector_id] .. '_circuit_network_content_slot',
                    tooltip = signal_converter:signal_to_prototype(signal).localised_name,
                    elem_tooltip = signal_converter:signal_to_elem_id(signal),
                    enabled = true,
                }
                signal_count = signal_count + 1
            end
        end
    end

    while (signal_count % SIGNAL_COLUMN_COUNT) > 0 do
        gui_element.add {
            type = 'sprite',
            enabled = true,
            }
        signal_count = signal_count + 1
    end
end

----------------------------------------------------------------------------------------------------
-- GUI state updater
----------------------------------------------------------------------------------------------------

--- Executed every time the config changes
---
---@param gui framework.gui
---@param fo_entity fo.FiberOptics
local function update_gui(gui, fo_entity)
    local fo_config = fo_entity.config

    local enabled = fo_config.enabled
    local on_off = gui:find_element('on-off')
    on_off.switch_state = values_on_off[enabled]

    local strand_items, strand_index = create_strand_items(fo_entity)

    local strand_select = assert(gui:find_element('strand_select'))
    strand_select.items = strand_items
    strand_select.selected_index = assert(strand_index)

    local strand_delete = gui:find_element('strand_delete')
    strand_delete.enabled = strand_items[strand_index] ~= 'default'

    ---@type fo.GuiContext
    local context = gui.context

    local strand_text = assert(gui:find_element('strand_text'))
    if strand_text.text ~= context.new_strand_name then
        strand_text.text = context.new_strand_name
    end
end

--- Executed at every refresh tick
---
---@param gui framework.gui
---@param fo_entity fo.FiberOptics
---@return table<integer, integer> connection_state
local function refresh_gui(gui, fo_entity)
    local fo_config = fo_entity.config

    ---@type defines.entity_status?
    local entity_status

    -- status LED
    if fo_config.enabled then
        if fo_entity.status ~= defines.entity_status.working then
            entity_status = fo_entity.status or defines.entity_status.broken
        elseif table_size(fo_entity.networks) > 0 then
            entity_status = defines.entity_status.working
        else
            entity_status = defines.entity_status.networks_disconnected
        end
    else
        entity_status = defines.entity_status.disabled
    end

    local lamp = gui:find_element('status-lamp')
    lamp.sprite = tools.STATUS_SPRITES[entity_status] or tools.STATUS_LEDS.RED

    local status = gui:find_element('status-label')
    status.caption = entity_status and { tools.STATUS_NAMES[entity_status] } or { 'gui-control-behavior.not-connected' }

    -- wire connections
    local connections = gui:find_element('connections')
    local connection_wire = gui:find_element('connection-wires')

    if table_size(fo_entity.networks) > 0 then
        local networks = ''
        for _, network_id in pairs(table.keys(fo_entity.networks, true, false)) do
            local endpoint_count = This.network:getEndpointCount(fo_entity.main.surface_index, network_id, fo_entity.config.strand_name)
            networks = networks .. ('%d (%d) '):format(network_id, endpoint_count)
        end

        connections.caption = { 'gui-control-behavior.connected-to-network' }
        connection_wire.visible = true
        connection_wire.caption = networks
    else
        connections.caption = { 'gui-control-behavior.not-connected' }
        connection_wire.visible = false
        connection_wire.caption = nil
    end

    -- Signal display
    for idx = 1, This.pin.MAX_PIN_COUNT do
        add_signals(gui, fo_entity, idx)
    end

    return util.copy(fo_entity.networks)
end

----------------------------------------------------------------------------------------------------
-- open gui handler
----------------------------------------------------------------------------------------------------

---@param event EventData.on_gui_opened
function Gui.onGuiOpened(event)
    local player = Player.get(event.player_index)
    if not player then return end

    -- close an eventually open gui
    Framework.gui_manager:destroy_gui(event.player_index)

    local clicked_entity = event and event.entity --[[@as LuaEntity]]
    if not clicked_entity then
        player.opened = nil
        return
    end

    local fo = player.surface.find_entities_filtered {
        area = Position(clicked_entity.position):expand_to_area(0.1),
        name = const.main_entity_name
    }

    if #fo ~= 1 then
        player.opened = nil
        return
    end

    local entity = fo[1]
    assert(entity.unit_number)
    local fo_entity = This.fo:getEntity(entity.unit_number)

    if not fo_entity then
        Framework.logger:logf('Data missing for %s on %s at %s, refusing to display UI',
            event.entity.name, event.entity.surface.name, serpent.line(event.entity.position))
        player.opened = nil
        return
    end

    ---@class fo.GuiContext
    ---@field last_config fo.FiberOpticsConfig?
    ---@field last_connection_state table<integer, integer>?
    ---@field new_strand_name string
    local gui_state = {
        last_config = nil,
        last_connection_state = nil,
        new_strand_name = '',
    }

    local gui = Framework.gui_manager:create_gui {
        type = Gui.NAME,
        player_index = event.player_index,
        parent = player.gui.screen,
        ui_tree_provider = Gui.getUi,
        context = gui_state,
        entity_id = entity.unit_number
    }

    player.opened = gui.root
end

function Gui.onGhostGuiOpened(event)
    local player = Player.get(event.player_index)
    if not player then return end

    player.opened = nil
end

----------------------------------------------------------------------------------------------------
-- Event ticker
----------------------------------------------------------------------------------------------------

---@param gui framework.gui
---@return boolean
function Gui.guiUpdater(gui)
    local fo_entity = This.fo:getEntity(gui.entity_id)
    if not fo_entity then return false end

    ---@type fo.GuiContext
    local context = gui.context

    -- always update wire state and preview
    local connection_state = refresh_gui(gui, fo_entity)

    local refresh_config = not (context.last_config and table.compare(context.last_config, fo_entity.config))
    local refresh_state = not (context.last_connection_state and table.compare(context.last_connection_state, connection_state))

    if refresh_config or refresh_state then
        update_gui(gui, fo_entity)
        This.fo:updateEntityStatus(fo_entity, true)
    end

    if refresh_config then
        context.last_config = tools.copy(fo_entity.config)
    end

    if refresh_state then
        context.last_connection_state = connection_state
    end

    return true
end

----------------------------------------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------------------------------------

local function init_gui()
    Framework.gui_manager:register_gui_type(Gui.NAME, get_gui_event_definition())

    local match_clickable_entities = Matchers:matchEventEntityName { const.pin_entity_name, const.pin_one_entity_name, const.powerpole_name }
    local match_ghost_clickable_entities = Matchers:matchEventEntityGhostName { const.pin_entity_name, const.pin_one_entity_name, const.powerpole_name }

    Event.on_event(defines.events.on_gui_opened, Gui.onGuiOpened, match_clickable_entities)
    Event.on_event(defines.events.on_gui_opened, Gui.onGhostGuiOpened, match_ghost_clickable_entities)
end

Event.on_init(init_gui)
Event.on_load(init_gui)

return Gui
