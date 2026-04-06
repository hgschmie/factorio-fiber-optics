------------------------------------------------------------------------
-- data phase 1
------------------------------------------------------------------------

require('lib.init')
local const = require('lib.constants')

require('prototypes.main')
require('prototypes.pins')
require('prototypes.internal')
require('prototypes.network')
require('prototypes.technology')
require('prototypes.sprites')
require('prototypes.custom-input')

---@diagnostic disable-next-line: undefined-field
Framework.post_data_stage()
