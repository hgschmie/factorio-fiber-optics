--------------------------------------------------------------------------------
-- runtime code
--------------------------------------------------------------------------------
assert(script)

local const = require('lib.constants')

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')

require('lib.init')

--------------------------------------------------------------------------------
-- Configuration changes (startup)
--------------------------------------------------------------------------------

local function on_configuration_changed()
    for _, force in pairs(game.forces) do
        if force.recipes[const.main_entity_name] and force.technologies[const.main_entity_name] then
            force.recipes[const.main_entity_name].enabled = force.technologies[const.main_entity_name].researched
        end
    end
end

--------------------------------------------------------------------------------
-- event registration and management
--------------------------------------------------------------------------------

local function register_events()
    -- Configuration changes (startup)
    Event.on_configuration_changed(on_configuration_changed)
end

--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------

local function on_init()
    register_events()
end

local function on_load()
    register_events()
end

-- setup player management
Player.register_events(true)

Event.on_init(on_init)
Event.on_load(on_load)

--------------------------------------------------------------------------------

---@diagnostic disable-next-line: undefined-field
Framework.post_runtime_stage()
