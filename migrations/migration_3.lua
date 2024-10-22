--------------------------------------------------------------------------------
-- migration 3
--------------------------------------------------------------------------------
-- change ghosts and attached units to match the internal code
--------------------------------------------------------------------------------

require('lib.init')

if storage.oc_networks.VERSION > 2 and storage.oc_data.VERSION > 2 then return end

storage.oc_ghosts = nil
storage.oc_attached = nil
storage.ghosts = nil

local attached_entities = require('scripts.attached-entities')
attached_entities:init()

-- don't use 'const.current_version', otherwise the next migrations are not run!
storage.oc_networks.VERSION = 3
storage.oc_data.VERSION = 3
