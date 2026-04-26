------------------------------------------------------------------------
-- Edit Descriptions GUI
------------------------------------------------------------------------
assert(script)

local util = require('util')

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')

local const = require('lib.constants')

---@class fo.DescGui
local Gui = {
    DESCRIPTION_GUI_NAME = 'fiber-optics-description-gui'
}

----------------------------------------------------------------------------------------------------
-- UI definition
----------------------------------------------------------------------------------------------------

local function get_gui_event_definition()
    ---@type framework.gui_manager.event_definition
    return {
        events = {
            onWindowClosed = Gui.onCloseDesc,
            onConfirmDesc = Gui.onConfirmDesc,
            onDescTitleChanged = Gui.onDescTitleChanged,
            onDescTitleConfirmed = Gui.onDescTitleConfirmed,
            onDescBodyChanged = Gui.onDescBodyChanged,
        },
        cleanup = function(gui)
            if not (gui.context.button and gui.context.button.valid) then return false end
            -- untoggle button that opened the description window
            gui.context.button.toggled = false

            return false
        end,
        custominput_events = {
            [defines.events.on_gui_closed] = {
                [const.custom_input_confirm_gui] = Gui.onConfirmDesc,
                [const.custom_input_toggle_menu] = Gui.onCloseDesc,
            },
        }
    }
end

--- Returns the definition of the Description GUI.
--- All events must be mapped onto constants from the gui_events array.
---@param gui framework.gui
---@return framework.gui.element_definition ui
function Gui.getUi(gui)
    local gui_events = gui.gui_events

    ---@type fo.DescGuiContext
    local context = gui.context

    return {
        type = 'frame',
        name = 'gui_root',
        direction = 'vertical',
        handler = {
            [defines.events.on_gui_closed] = gui_events.onWindowClosed,
        },
        elem_mods = { auto_center = true },
        style_mods = {
            width = 400,
            height = 300,
        },
        children = {
            { -- Title Bar
                type = 'flow',
                style = 'frame_header_flow',
                drag_target = 'gui_root',
                children = {
                    {
                        type = 'label',
                        style = 'frame_title',
                        caption = { '', { const:locale('edit_description') }, ' - ', { const:locale(context.desc_args.desc_type .. '_caption'), context.desc_args.index } },
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
                        tooltip = { 'gui.cancel-instruction' },
                        handler = { [defines.events.on_gui_click] = gui_events.onWindowClosed },
                    },
                },
            },
            {
                type = 'flow',
                direction = 'vertical',
                children = {
                    {
                        type = 'textfield',
                        name = 'desc_title',
                        style_mods = {
                            horizontally_stretchable = true,
                            horizontally_squashable = true,
                            width = 376,
                        },
                        lose_focus_on_confirm = true,
                        clear_and_focus_on_right_click = true,
                        icon_selector = true,
                        handler = {
                            [defines.events.on_gui_text_changed] = gui_events.onDescTitleChanged,
                            [defines.events.on_gui_confirmed] = gui_events.onDescTitleConfirmed,
                        },
                        text = gui.context.desc.title
                    },
                    {
                        type = 'text-box',
                        name = 'desc_body',
                        style_mods = {
                            horizontally_stretchable = true,
                            horizontally_squashable = true,
                            vertically_squashable = true,
                            vertically_stretchable = true,
                            width = 376,
                            natural_height = 200,
                        },
                        icon_selector = true,
                        handler = {
                            [defines.events.on_gui_text_changed] = gui_events.onDescBodyChanged,
                        },
                        text = gui.context.desc.body
                    },
                    {
                        type = 'flow',
                        direction = 'horizontal',
                        style_mods = {
                            vertically_stretchable = false,
                        },
                        children = {
                            {
                                type = 'empty-widget',
                                style = 'draggable_space',
                                style_mods = {
                                    horizontally_stretchable = true,
                                    vertically_stretchable = true,
                                },
                            },
                            {
                                type = 'button',
                                style = 'confirm_button',
                                caption = { 'gui-edit-label.save-description' },
                                mouse_button_filter = { 'left' },
                                handler = { [defines.events.on_gui_click] = gui_events.onConfirmDesc },
                            }
                        },
                    }
                }
            },
            --     },
            -- },
        }
    }
end

----------------------------------------------------------------------------------------------------
-- UI Callbacks
----------------------------------------------------------------------------------------------------

---@param event EventData.on_gui_click|EventData.on_gui_opened
---@param gui framework.gui
function Gui.onCloseDesc(event, gui)
    Framework.gui_manager:destroyGui(event.player_index, gui.type)

    local main_gui = Framework.gui_manager:findGui(event.player_index, This.gui.MAIN_GUI_NAME)
    if main_gui then
        local player = Player.get(event.player_index)
        player.opened = main_gui.root
    else
        Framework.gui_manager:destroyGuiByPlayer(event.player_index)
    end
end

---@param event EventData.on_gui_click
---@param gui framework.gui
function Gui.onConfirmDesc(event, gui)
    ---@type fo.DescGuiContext
    local context = gui.context

    local desc_args = context.desc_args
    desc_args.desc = assert(context.desc)

    This.fo:setDescription(desc_args)

    return Gui.onCloseDesc(event, gui)
end

---@param event EventData.on_gui_text_changed
function Gui.onDescBodyChanged(event, gui)
    ---@type fo.DescGuiContext
    local context = gui.context
    context.desc.body = event.text
end

function Gui.onDescTitleChanged(event, gui)
    ---@type fo.DescGuiContext
    local context = gui.context
    context.desc.title = event.text
end

function Gui.onDescTitleConfirmed(event, gui)
    local body = assert(gui:find_element('desc_body'))
    body.focus()
end

----------------------------------------------------------------------------------------------------
-- open/close
----------------------------------------------------------------------------------------------------


---@class fo.DescGuiContext
---@field desc fo.Description
---@field desc_args fo.FoGetSetDescriptionArgs
---@field button LuaGuiElement

---@param player LuaPlayer
---@param desc_args fo.FoGetSetDescriptionArgs
---@param button LuaGuiElement
function Gui.openGui(player, desc_args, button)
    local desc = desc_args.desc and util.copy(desc_args.desc) or {
        title = '',
        body = ''
    }

    desc_args.desc = nil

    ---@type fo.DescGuiContext
    local gui_context = {
        desc = desc,
        desc_args = desc_args,
        button = button
    }

    local gui = Framework.gui_manager:createGui {
        type = Gui.DESCRIPTION_GUI_NAME,
        player_index = player.index,
        parent = player.gui.screen,
        ui_tree_provider = Gui.getUi,
        context = gui_context,
        entity_id = desc_args.entity_id,
        retain_open_guis = true,
    }

    player.opened = gui.root

    local title = assert(gui:find_element('desc_title'))
    title.focus()
end

---@param player_index integer
function Gui.closeGui(player_index)
    Framework.gui_manager:destroyGui(player_index, Gui.DESCRIPTION_GUI_NAME)
end

----------------------------------------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------------------------------------

local function init_gui()
    Framework.gui_manager:registerGuiType(Gui.DESCRIPTION_GUI_NAME, get_gui_event_definition())
end

Event.on_init(init_gui)
Event.on_load(init_gui)

return Gui
