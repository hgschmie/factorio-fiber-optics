--
-- control.lua
--

local const = require('lib.constants')
local context_manager = require('lib.context')

local oc = require('scripts.oc')
local network = require('scripts.network')

-- support for other mods
local PickerDollies = require('lib.other_mods.picker_dollies')

---------------------------------------------------------------------------------------------------------


local function on_init()
    -- register custom cleanup for network connections
    context_manager:init(nil, network.destroy_context)
    network.init()

    oc.init()
    PickerDollies.install(const.attached_entities)
end

local function on_load()
    -- register custom cleanup for network connections
    context_manager:load(nil, network.destroy_context)
    network.load()

    oc.init()

    PickerDollies.install(const.attached_entities)
end

script.on_init(on_init)
script.on_load(on_load)
