--------------------------------------------------------------------------------
-- migration 3
--------------------------------------------------------------------------------

require('lib.init')

if global.oc_networks.VERSION > 2 and global.oc_data.VERSION > 2 then return end

global.oc_ghosts = nil
global.oc_attached = nil
global.ghosts = nil

local attached_entities = require('scripts.attached-entities')
attached_entities:init()

-- don't use 'const.current_version', otherwise the next migrations are not run!
global.oc_networks.VERSION = 3
global.oc_data.VERSION = 3
