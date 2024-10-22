--------------------------------------------------------------------------------
-- migration 2
--------------------------------------------------------------------------------
-- create global fields for ghosts and attached entities
--------------------------------------------------------------------------------

require('lib.init')

if storage.oc_networks.VERSION > 1 and storage.oc_data.VERSION > 1 then return end

if not storage.oc_ghosts then
    storage.oc_ghosts = {}
end

if not storage.oc_attached then
    storage.oc_attached = {}
end

-- don't use 'const.current_version', otherwise the next migrations are not run!
storage.oc_networks.VERSION = 2
storage.oc_data.VERSION = 2
