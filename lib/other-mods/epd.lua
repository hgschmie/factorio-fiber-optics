--------------------------------------------------------------------------------
-- EPD support
--------------------------------------------------------------------------------

local const = require('lib.constants')

return {
    runtime = function()
        assert(script)

        local Event = require('stdlib.event.event')
        local Player = require('stdlib.event.player')

        local epd_moved = function(event)
            if not (event.moved_entity and event.moved_entity.valid) then return end
            if event.moved_entity.name ~= const.main_entity_name then return end

            local player = Player.get(event.player_index)
            This.fo:move(event.moved_entity.unit_number, event.start_pos, player)
        end

        local epd_init = function()
            local epd = remote.interfaces['PickerDollies']
            if not epd then return end

            assert(epd['dolly_moved_entity_id'], 'Picker Dollies present but no dolly_moved_entity_id interface!')
            assert(epd['add_blacklist_name'], 'Picker Dollies present but no add_blacklist_name interface!')

            Event.on_event(remote.call('PickerDollies', 'dolly_moved_entity_id'), epd_moved)

            for _, entity_name in pairs(const.attached_entity_names) do
                remote.call('PickerDollies', 'add_blacklist_name', entity_name)
            end
        end

        Event.on_init(epd_init)
        Event.on_load(epd_init)
    end
}
