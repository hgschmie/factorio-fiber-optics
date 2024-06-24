--------------------------------------------------------------------------------
-- Space Exploration (https://mods.factorio.com/mod/space-exploration)
--------------------------------------------------------------------------------

local const = require('lib.constants')

local SpaceExplorationSupport = {}

local space_entities = {
    { 'simple-entity-with-owner', const.optical_connector },
    { 'power-switch',             const.oc_power_pole },
    { 'container',                const.iopin_name },
    { 'container',                const.iopin_one_name },
}

--------------------------------------------------------------------------------

SpaceExplorationSupport.data = function()
    for _, space_entity in pairs(space_entities) do
        if data.raw[space_entity[1]] and data.raw[space_entity[1]][space_entity[2]] then
            data.raw[space_entity[1]][space_entity[2]].se_allow_in_space = true
        end
    end
end

return SpaceExplorationSupport
