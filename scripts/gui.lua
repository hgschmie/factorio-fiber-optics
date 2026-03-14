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

---@class fo.Gui
---@field NAME string
local Gui = {
    NAME = 'fiber-optics-gui',
}

----------------------------------------------------------------------------------------------------
-- UI definition
----------------------------------------------------------------------------------------------------

--- Provides all the events used by the GUI and their mappings to functions. This must be outside the
--- GUI definition as it can not be serialized into storage.
---@return framework.gui_manager.event_definition
local function get_gui_event_definition()
    return {
        events = {
            onWindowClosed = Gui.onWindowClosed,
            onSwitchEnabled = Gui.onSwitchEnabled,
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
                style_mods = { width = 424, }, -- fix width of the window to match the signal bottom
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
                                type = 'frame',
                                style = 'deep_frame_in_shallow_frame',
                                name = 'preview_frame',
                                children = {
                                    {
                                        type = 'entity-preview',
                                        name = 'preview',
                                        style = 'wide_entity_button',
                                        elem_mods = { entity = fo_entity.main },
                                    },
                                },
                            },
                            {
                                type = 'line',
                            },
                            {
                                type = 'label',
                                style = 'semibold_label',
                                caption = { 'gui-constant.output' },
                            },
                            {
                                type = 'switch',
                                name = 'on-off',
                                right_label_caption = { 'gui-constant.on' },
                                left_label_caption = { 'gui-constant.off' },
                                handler = { [defines.events.on_gui_switch_state_changed] = gui_events.onSwitchEnabled },
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


----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- GUI state updater
----------------------------------------------------------------------------------------------------

---@param gui framework.gui
---@param fo_entity fo.FiberOptics
local function update_gui(gui, fo_entity)
    local config = fo_entity.config

    local enabled = fo_entity.config.enabled
    local on_off = gui:find_element('on-off')
    on_off.switch_state = values_on_off[enabled]
end

---@param gui framework.gui
---@param fo_entity fo.FiberOptics
---@return table<integer, integer> connection_state
local function refresh_gui(gui, fo_entity)
    local fo_config = fo_entity.config

    ---@type defines.entity_status?
    local entity_status

    -- status LED
    if fo_config.enabled then
        if fo_entity.internal.power.status ~= defines.entity_status.working then
            entity_status = fo_entity.main.status or defines.entity_status.broken
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
    status.caption = entity_status and { tools.STATUS_NAMES[entity_status] } or { const:locale('not-connected') }

    -- wire connections
    local connections = gui:find_element('connections')
    local connection_wire = gui:find_element('connection-wires')

    if table_size(fo_entity.networks) > 0 then
        local networks = (' '):join(table.keys(fo_entity.networks, true, true))
        connections.caption = { 'gui-control-behavior.connected-to-network' }
        connection_wire.visible = true
        connection_wire.caption = networks
    else
        connections.caption = { 'gui-control-behavior.not-connected' }
        connection_wire.visible = false
        connection_wire.caption = nil
    end

    return fo_entity.networks
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
    local gui_state = {
        last_config = nil,
        last_connection_state = nil,
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

    local match_clickable_entities = Matchers:matchEventEntityName({ const.pin_entity_name, const.pin_one_entity_name, const.powerpole_name})
    local match_ghost_clickable_entities = Matchers:matchEventEntityGhostName({ const.pin_entity_name, const.pin_one_entity_name, const.powerpole_name})

    Event.on_event(defines.events.on_gui_opened, Gui.onGuiOpened, match_clickable_entities)
    Event.on_event(defines.events.on_gui_opened, Gui.onGhostGuiOpened, match_ghost_clickable_entities)
end

Event.on_init(init_gui)
Event.on_load(init_gui)

return Gui
