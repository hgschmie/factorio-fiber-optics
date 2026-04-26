------------------------------------------------------------------------
-- IO Pin hover signal display GUI
------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')

local signal_converter = require('framework.signal_converter')

local const = require('lib.constants')

---@class fo.SignalGui
local Gui = {
    SIGNAL_GUI_NAME = 'fiber-optics-signal-gui'
}

----------------------------------------------------------------------------------------------------
-- UI definition
----------------------------------------------------------------------------------------------------

---@return framework.gui_manager.event_definition
local function get_gui_event_definition()
    return {
        callback = Gui.guiUpdater,
    }
end

---@return framework.gui.element_definition
function Gui.getUi()
    return {
        type = 'frame',
        name = 'signal_gui_root',
        direction = 'vertical',
        children = {
            {
                type = 'label',
                name = 'pin_label',
                style = 'semibold_label',
                caption = '',
            },
            {
                type = 'table',
                name = 'red_signal_table',
                style = 'filter_slot_table',
                style_mods = {
                    vertical_spacing = 4,
                },
                column_count = const.ui_signal_column_count,
            },
            {
                type = 'table',
                name = 'green_signal_table',
                style = 'filter_slot_table',
                style_mods = {
                    vertical_spacing = 4,
                },
                column_count = const.ui_signal_column_count,
            },
        }
    }
end

----------------------------------------------------------------------------------------------------
-- GUI updater callback
----------------------------------------------------------------------------------------------------

---@param gui framework.gui
---@return boolean
function Gui.guiUpdater(gui)
    local player = Player.get(gui.player_index)
    if not player then return false end

    local entity = player.selected
    if not (entity and entity.valid) then return false end

    ---@type fo.SignalGuiContext
    local context = gui.context
    local iopin = context.iopin

    local text = { const.IOPIN_CAPTION, iopin.index }

    ---@type fo.FiberOptics
    local fo_entity = This.fo:getEntity(iopin.entity_id)
    if  fo_entity then
        ---@type fo.FoPinCaption
        local caption = This.fo:getCaptionForPin(fo_entity, iopin.index)
        if caption.desc and caption.desc.title ~= '' then
            text = { '', { const.IOPIN_CAPTION, iopin.index }, ': ', caption.desc.title }
        end
    end

    -- update label
    local pin_label = assert(gui:find_element('pin_label'))
    pin_label.caption = text

    -- update signals
    local red_signal_table = assert(gui:find_element('red_signal_table'))
    red_signal_table.clear()

    local green_signal_table = assert(gui:find_element('green_signal_table'))
    green_signal_table.clear()

    local table_map = {
        [defines.wire_connector_id.circuit_red] = red_signal_table,
        [defines.wire_connector_id.circuit_green] = green_signal_table,
    }

    local iopin_entity = fo_entity.iopin[iopin.index]
    if iopin_entity and iopin_entity.valid then
        for _, connector_id in pairs { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green } do
            local signals = iopin_entity.get_signals(connector_id)
            if signals then
                for _, signal in ipairs(signals) do
                    table_map[connector_id].add {
                        type = 'sprite-button',
                        sprite = signal_converter:signal_to_sprite_name(signal),
                        number = signal.count,
                        quality = signal.signal.quality,
                        style = const.COLOR_MAP[connector_id] .. '_circuit_network_content_slot',
                        tooltip = signal_converter:signal_to_prototype(signal).localised_name,
                        elem_tooltip = signal_converter:signal_to_elem_id(signal),
                        enabled = true,
                    }
                end
            end
        end
    end

    return true
end

----------------------------------------------------------------------------------------------------
-- open / close
----------------------------------------------------------------------------------------------------

---@param player LuaPlayer
---@param iopin fo.IoPin
function Gui.openGui(player, iopin)
    Framework.gui_manager:createGui {
        type = Gui.SIGNAL_GUI_NAME,
        player_index = player.index,
        parent = player.gui.left,
        ui_tree_provider = Gui.getUi,
        ---@class fo.SignalGuiContext
        ---@field iopin fo.IoPin
        context = {
            iopin = iopin,
        },
        entity_id = iopin.entity_id,
        retain_open_guis = true,
    }
end

---@param player_index integer
function Gui.closeGui(player_index)
    Framework.gui_manager:destroyGui(player_index, Gui.SIGNAL_GUI_NAME)
end

----------------------------------------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------------------------------------

---@param event EventData.on_selected_entity_changed
local function on_selected_entity_changed(event)
    local player = Player.get(event.player_index)
    if not player then return end

    local entity = player.selected
    if entity and entity.valid then
        local iopin = This.pin:findPin(entity.unit_number)
        if iopin then
            Gui.openGui(player, iopin)
        end
    else
        Gui.closeGui(event.player_index)
    end
end

local function init_gui()
    Framework.gui_manager:registerGuiType(Gui.SIGNAL_GUI_NAME, get_gui_event_definition())
    Event.on_event(defines.events.on_selected_entity_changed, on_selected_entity_changed)
end

Event.on_init(init_gui)
Event.on_load(init_gui)

return Gui
