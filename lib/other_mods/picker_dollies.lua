--
-- picker dollies support
--

local const = require('lib.constants')
local tools = require('lib.tools')

local PickerDollies = {}

-- see if all entities related to the main entity (things that are located wihin the area of the main
-- entity and listed in the related_entity_names) can be moved. This checks whether any entities have wire
-- connections and if yes, if they can be stretched when moving. Returns true (vetoed) and a list of related
-- entities if they can not be moved and false, the list of related entities and their new positions in a separate
-- list if the entities can be moved.
local function move_related_entities(move_event, managed_entity_names)
    local player = game.players[move_event.player_index]
    local entity = move_event.moved_entity

    local start_pos = move_event.start_pos
    local dx = entity.position.x - start_pos.x
    local dy = entity.position.y - start_pos.y
    local related_entities = tools.find_entities(entity, start_pos, { name = managed_entity_names })

    local move_list = {}

    for idx, related_entity in pairs(related_entities) do
        local dst_pos = {
            x = related_entity.position.x + dx,
            y = related_entity.position.y + dy,
        }

        if tools.check_wire_stretch(related_entity, dst_pos, player) then
            return true, related_entities, {}
        end

        move_list[idx] = dst_pos
    end

    return false, related_entities, move_list
end

--- Installs the move code to support picker dollies. 
-- The managed_entity_names list is not moved by picker dollies but managed by this module.
-- @param managed_entity_names A list of entity names that should not be moved by picker dollies.
function PickerDollies.install(managed_entity_names)
    local function move(move_event)
        local entity = move_event.moved_entity
        if not tools.is_valid(move_event.moved_entity) then return end

        local vetoed, related_entities, move_list = move_related_entities(move_event, managed_entity_names)

        if vetoed then
            entity.teleport(move_event.start_pos)
        else
            for idx, related_entity in pairs(related_entities) do
                related_entity.teleport(move_list[idx])
            end
        end
    end

    if remote.interfaces["PickerDollies"] then
        assert(remote.interfaces["PickerDollies"]["dolly_moved_entity_id"], "Picker Dollies present but no dolly_moved_entity_id interface!")
        assert(remote.interfaces["PickerDollies"]["add_blacklist_name"], "Picker Dollies present but no add_blacklist_name interface!")

        local event = remote.call("PickerDollies", "dolly_moved_entity_id")
        script.on_event(event, move)

        for _, entity_name in pairs(managed_entity_names) do
            remote.call("PickerDollies", "add_blacklist_name", entity_name)
        end
    end
end

return PickerDollies
