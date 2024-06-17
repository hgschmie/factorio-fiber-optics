--------------------------------------------------------------------------------
-- migration 2
--------------------------------------------------------------------------------
-- create global fields for ghosts and attached entities
--------------------------------------------------------------------------------

require('lib.init')

if global.oc_networks.VERSION > 1 and global.oc_data.VERSION > 1 then return end

if not global.oc_ghosts then
    global.oc_ghosts = {}
end

if not global.oc_attached then
    global.oc_attached = {}
end

-- don't use 'const.current_version', otherwise the next migrations are not run!
global.oc_networks.VERSION = 2
global.oc_data.VERSION = 2
