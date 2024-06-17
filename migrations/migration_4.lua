--------------------------------------------------------------------------------
-- migration 4
--------------------------------------------------------------------------------
-- ensure that all entities have the operable flag set to false
--------------------------------------------------------------------------------

require('lib.init')

if global.oc_networks.VERSION > 3 and global.oc_data.VERSION > 3 then return end

local oc = require('scripts.oc')

for _, entity in pairs(oc:entities()) do
    for _, e in pairs(entity.ref) do
        e.operable = false
    end
end


-- don't use 'const.current_version', otherwise the next migrations are not run!
global.oc_networks.VERSION = 4
global.oc_data.VERSION = 4
