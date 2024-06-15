--------------------------------------------------------------------------------
-- migration 3
--------------------------------------------------------------------------------

require('lib.init')

local const = require('lib.constants')

if global.oc_networks.VERSION > 2 and global.oc_data.VERSION > 2 then return end

global.oc_ghosts = nil
global.oc_attached = nil
global.ghosts = nil

local attached_entities = require('scripts.attached-entities')
attached_entities:init()

global.oc_networks.VERSION = const.current_version
global.oc_data.VERSION = const.current_version
