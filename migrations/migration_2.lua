--------------------------------------------------------------------------------
-- migrate network and entities from 0.0.1
--------------------------------------------------------------------------------

require('lib.init')

local const = require('lib.constants')

if global.oc_networks.VERSION > 1 and global.oc_data.VERSION > 1 then return end

if not global.oc_ghosts then
    global.oc_ghosts = {}
end

if not global.oc_attached then
    global.oc_attached = {}
end

global.oc_networks.VERSION = const.current_version
global.oc_data.VERSION = const.current_version
