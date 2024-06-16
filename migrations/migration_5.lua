--------------------------------------------------------------------------------
-- migration 5
--------------------------------------------------------------------------------

require('lib.init')

if global.oc_networks.VERSION > 4 and global.oc_data.VERSION > 4 then return end

local oc = require('scripts.oc')

for _, entity in pairs(oc:entities()) do
    entity.flip_index = 1
end


-- don't use 'const.current_version', otherwise the next migrations are not run!
global.oc_networks.VERSION = 5
global.oc_data.VERSION = 5
