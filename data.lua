------------------------------------------------------------------------
-- data phase 1
------------------------------------------------------------------------

require('lib.init')
local const = require('lib.constants')

require('prototypes.main')
require('prototypes.technology')

---@diagnostic disable-next-line: undefined-field
Framework.post_data_stage()
