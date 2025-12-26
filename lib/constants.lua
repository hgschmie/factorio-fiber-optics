------------------------------------------------------------------------
-- mod constant definitions.
--
-- can be loaded into scripts and data
------------------------------------------------------------------------

local Constants = {
    prefix = 'hps__fo2-',
    name = 'optical-connector',
    root = '__fiber-optics-2__',
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

Constants.main_entity_name = Constants:with_prefix('main')
Constants.pin_entity_name = Constants:with_prefix('pin')
Constants.pin_one_entity_name = Constants:with_prefix('pin-one')

return Constants
