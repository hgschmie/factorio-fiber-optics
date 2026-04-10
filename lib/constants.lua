------------------------------------------------------------------------
-- mod constant definitions.
--
-- can be loaded into scripts and data
------------------------------------------------------------------------

local Constants = {
    prefix = 'hps__fo-',
    name = 'optical-connector',
    root = '__fiber-optics__',
}

--------------------------------------------------------------------------------
-- main constants
--------------------------------------------------------------------------------

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
    return Constants:with_prefix('messages.') .. id
end

---@param name string
---@return string
function Constants.debug_name(name)
    return name .. '-debug'
end

---@param tick_value number?
---@return string
function Constants.formatTime(tick_value)
    if tick_value == 0 then return '0s' end
    local seconds = tick_value / 60
    if seconds < 60 then return ('%.2fs'):format(seconds) end
    local minutes = math.floor(seconds / 60)
    seconds = seconds - minutes * 60
    if minutes < 60 then return ('%02d:%05.2fs'):format(minutes, seconds) end
    local hours = math.floor(minutes / 60)
    minutes = minutes - hours * 60
    return ('%02d:%02d:%05.2fs'):format(hours, minutes, seconds)
end

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

-- IO Pin sprite positions relative to the main entity
-- see sprite_positions.txt
-- X offset is along orientation of the main entity
-- Y offset is "previous direction" of the main entity (e.g. for "North", this is "West")
Constants.pin_positions = {
    { -42, -41 }, { -22, -29 }, { 3, -50 }, { 25, -29 },
    { 48,  -41 }, { 35, -14 }, { 55, 3 }, { 35, 21 },
    { 48,  47 }, { 25, 31 }, { 3, 53 }, { -22, 31 },
    { -42, 47 }, { -30, 21 }, { -50, 3 }, { -30, -14 },
}

for _, pos in pairs(Constants.pin_positions) do
    pos.x = pos[1] / 64
    pos.y = pos[2] / 64
end

Constants.max_pin_count = #Constants.pin_positions
Constants.max_hub_count = 16

Constants.title_style = Constants:with_prefix('title')
Constants.title_style_dimmed = Constants:with_prefix('title_dimmed')

Constants.ui_signal_column_count = 8
Constants.ui_scrollpane_width = Constants.ui_signal_column_count * 40
Constants.ui_title_width = Constants.ui_scrollpane_width - 42

-- These names *MUST* match the 1.x.x code. DO NOT CHANGE!
Constants.main_entity_name = Constants:with_prefix('optical-connector')
Constants.pin_entity_name = Constants:with_prefix('oc-io_pin')
Constants.pin_one_entity_name = Constants:with_prefix('oc-io_pin_one')
Constants.powerpole_name = Constants:with_prefix('oc-power-pole')

Constants.power_interface_name = Constants:with_prefix('power-interface')
Constants.led_name = Constants:with_prefix('led')
Constants.controller_name = Constants:with_prefix('controller')
Constants.fiber_hub_name = Constants:with_prefix('fiber-hub')

Constants.custom_input_toggle_menu = Constants:with_prefix('toggle-menu')
Constants.custom_input_confirm_gui = Constants:with_prefix('confirm-gui')
Constants.custom_input_ignore_close = Constants:with_prefix('ignore-close')

---@type string[]
Constants.attached_entity_names = {
    Constants.pin_entity_name,
    Constants.pin_one_entity_name,
    Constants.powerpole_name,
    Constants.power_interface_name,
    Constants.led_name,
    Constants.controller_name,
}

Constants.IOPIN_CAPTION = Constants:locale('hover_pin_caption')

-- Only available in runtime

if script then
    ---@type table<defines.wire_connector_id, string>
    Constants.COLOR_MAP = {
        [defines.wire_connector_id.circuit_red] = 'red',
        [defines.wire_connector_id.circuit_green] = 'green',
    }
end

--------------------------------------------------------------------------------
-- settings
--------------------------------------------------------------------------------

Constants.settings_keys = {
    'network_refresh',
    'fo_refresh',
}

Constants.settings_names = {}
Constants.settings = {}

for _, key in pairs(Constants.settings_keys) do
    Constants.settings_names[key] = key
    Constants.settings[key] = Constants:with_prefix(key)
end

--------------------------------------------------------------------------------
-- entity flags
--------------------------------------------------------------------------------

---@type data.EntityPrototypeFlags
local base_entity_flags = {
    'placeable-off-grid',
    'not-on-map',
    'not-deconstructable',
    'hide-alt-info',
    'not-selectable-in-game',
    'not-upgradable',
    'no-automated-item-removal',
    'no-automated-item-insertion',
    'not-in-kill-statistics',
}

-- flags for the visible entities (io pins, power connector)

---@type data.EntityPrototypeFlags
Constants.prototype_internal_entity_flags = {
    'placeable-neutral',
    'player-creation',
}

---@type data.EntityPrototypeFlags
Constants.prototype_hidden_entity_flags = {
    'not-rotatable',
    'no-copy-paste',
}

-- flags for the invisible entities
for _, flag in pairs(base_entity_flags) do
    table.insert(Constants.prototype_internal_entity_flags, flag)
    table.insert(Constants.prototype_hidden_entity_flags, flag)
end

return Constants
