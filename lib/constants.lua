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
    return Constants:with_prefix('locale.') .. id
end

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

Constants.max_hub_count = 16

-- These names *MUST* match the 1.x.x code. DO NOT CHANGE!
Constants.main_entity_name = Constants:with_prefix('optical-connector')
Constants.pin_entity_name = Constants:with_prefix('oc-io_pin')
Constants.pin_one_entity_name = Constants:with_prefix('oc-io_pin_one')
Constants.powerpole_name = Constants:with_prefix('oc-power-pole')

Constants.power_interface_name = Constants:with_prefix('power-interface')
Constants.led_name = Constants:with_prefix('led')
Constants.controller_name = Constants:with_prefix('controller')
Constants.fiber_hub_name = Constants:with_prefix('fiber-hub')

---@type string[]
Constants.attached_entity_names = {
    Constants.pin_entity_name,
    Constants.pin_one_entity_name,
    Constants.powerpole_name,
    Constants.power_interface_name,
    Constants.led_name,
    Constants.controller_name,
}

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
