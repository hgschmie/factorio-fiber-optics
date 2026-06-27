--------------------------------------------------------------------------------
-- Support for moving fiber optics connectors through
-- Even Pickier Dollies (https://mods.factorio.com/mod/even-pickier-dollies)
--------------------------------------------------------------------------------

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')

local const = require('lib.constants')

--------------------------------------------------------------------------------

local function picker_dollies_moved(event)
    if not (event.moved_entity and event.moved_entity.valid) then return end
    if event.moved_entity.name ~= const.main_entity_name then return end

    local player = Player.get(event.player_index)
    This.fo:move(event.moved_entity.unit_number, event.start_pos, player)
end

local function picker_dollies_init()
    local epd = assert(remote.interfaces['PickerDollies'])

    assert(epd['dolly_moved_entity_id'], 'Picker Dollies present but no dolly_moved_entity_id interface!')
    assert(epd['add_blacklist_name'], 'Picker Dollies present but no add_blacklist_name interface!')

    Event.on_event(remote.call('PickerDollies', 'dolly_moved_entity_id'), picker_dollies_moved)

    for _, entity_name in pairs(const.attached_entity_names) do
        remote.call('PickerDollies', 'add_blacklist_name', entity_name)
    end
end

--------------------------------------------------------------------------------

local PickerDollies = {
    on_init = picker_dollies_init,
    on_load = picker_dollies_init,
}

return PickerDollies
