--------------------------------------------------------------------------------
-- migration 5
--------------------------------------------------------------------------------
-- ensure that all entities have a flip_index field
-- (which is 1 == NORMAL unless it has been set)
--------------------------------------------------------------------------------

require('lib.init')

if storage.oc_networks.VERSION > 4 and storage.oc_data.VERSION > 4 then return end

local oc = require('scripts.oc')

for _, entity in pairs(oc:entities()) do
    if not entity.flip_index then
        entity.flip_index = 1
    end
end

-- don't use 'const.current_version', otherwise the next migrations are not run!
storage.oc_networks.VERSION = 5
storage.oc_data.VERSION = 5
