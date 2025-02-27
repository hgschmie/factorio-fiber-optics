--------------------------------------------------------------------------------
-- Picker Dollies (https://mods.factorio.com/mod/PickerDollies) support
--------------------------------------------------------------------------------

local const = require('lib.constants')
local Is = require('stdlib.utils.is')

local PickerDolliesSupport = {}

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------

PickerDolliesSupport.runtime = function()
    assert(script)

    local Event = require('stdlib.event.event')
    local Player = require('stdlib.event.player')

    local picker_dollies_moved = function(event)
        if not Is.Valid(event.moved_entity) then return end
        if event.moved_entity.name ~= const.optical_connector then return end

        local player = Player.get(event.player_index)
        This.oc:move(event.moved_entity, event.start_pos, player)
    end

    local picker_dollies_init = function()
        if not remote.interfaces['PickerDollies'] then return end

        assert(remote.interfaces['PickerDollies']['dolly_moved_entity_id'], 'Picker Dollies present but no dolly_moved_entity_id interface!')
        assert(remote.interfaces['PickerDollies']['add_blacklist_name'], 'Picker Dollies present but no add_blacklist_name interface!')

        Event.on_event(remote.call('PickerDollies', 'dolly_moved_entity_id'), picker_dollies_moved)

        for _, entity_name in pairs(const.attached_entities) do
            remote.call('PickerDollies', 'add_blacklist_name', entity_name)
        end
    end

    Event.on_init(picker_dollies_init)
    Event.on_load(picker_dollies_init)
end

return PickerDolliesSupport
