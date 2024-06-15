--------------------------------------------------------------------------------
-- migrate network and entities from 0.0.1
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
