--
-- tools - various helpers for stuff
--

local const = require('lib.constants')

local tools = {}

local event_handlers = {}

---Checks whether a given entity exists and is valid.
---@param entity LuaEntity? The entity to check.
---@return boolean Whether the entity exists and is valid.
function tools.is_valid(entity)
    return entity ~= nil and entity.valid
end

---Finds all entities that overlap with the given entity.
---@param entity LuaEntity The entity to check.
---@param start_position? MapPosition The position to start the search from. Can be nil, then the entity position is used.
---@param conditions? table Additional conditions for the search. The area is always set to the entity's selection box.
---@return LuaEntity[] The entities that overlap with the given entity.
function tools.find_entities(entity, start_position, conditions)
    local position = start_position or entity.position
    local selection_box = entity.selection_box
    local xradius = (selection_box.right_bottom.x - selection_box.left_top.x) / 2 - 0.01
    local yradius = (selection_box.right_bottom.y - selection_box.left_top.y) / 2 - 0.01

    local filter = conditions or {}

    filter.area = {
        left_top = { x = position.x - xradius, y = position.y - yradius },
        right_bottom = { x = position.x + xradius, y = position.y + yradius },
    }

    return entity.surface.find_entities_filtered(filter)
end

local function the_event_handler(event)
    local handler = event_handlers[event.name]
    if handler then
        assert(type(handler.func) == 'function', 'Found ' .. tostring(handler.func) .. ' which is not a function')
        handler.func(event)
    else
        tools.debug_print('Received event for ' .. event.name .. ' but no handler registered!')
    end
end

--- Registers event handlers for any event that manages entities
---@param event_names any One or more events to register for.
---@param event_function function<LuaEntity?, table<string, any>> The function to call.
---@param event_filter table? A filter expression.
function tools.register_entity_event(event_names, event_function, event_filter)
    local entity_wrapper = function(event)
        local entity = event.entity or event.created_entity
        if tools.is_valid(entity) then
            event_function(entity, event)
        else
            tools.debug_print(string.format('Received event %d for invalid entity!', event.name))
        end
    end

    return tools.register_event(event_names, entity_wrapper, event_filter)
end

--- Registers event handlers for any event.
---@param event_names any One or more events to register for.
---@param event_function function<table<string, any>> The function to call.
---@param event_filter table? A filter expression.
function tools.register_event(event_names, event_function, event_filter)
    if type(event_names) ~= 'table' then
        event_names = { event_names }
    end

    for _, event_name in pairs(event_names) do
        local new_filter = {}
        local old_filter = script.get_event_filter(event_name)

        local keep_filters = true
        local old_handler = script.get_event_handler(event_name)
        if old_handler then
            assert(old_handler == the_event_handler, string.format('Found a foreign handler for event %d: %s', event_name, tostring(old_handler)))
        end

        -- see if there were already filter conditions set. If yes, copy them over
        if old_filter and #old_filter > 0 then
            for _, f in pairs(old_filter) do table.insert(new_filter, f) end
        else
            -- if no (and there was a handler registered), there is handler that wants
            -- to see all events. Do not register any filter in that case.
            if old_handler then
                keep_filters = false
            end
        end

        -- if the new event filter has conditions, add them to the filter list
        -- if no filter was given, remove all filter conditions.
        if keep_filters and event_filter and #event_filter > 0 then
            for _, f in pairs(event_filter) do table.insert(new_filter, f) end
        else
            keep_filters = false
        end

        -- re-register  because the filter may have changed. If keep_filters is true, use the new filters, otherwise clear the filters
        script.on_event(event_name, the_event_handler, (keep_filters and new_filter) or nil)

        local handler = { func = event_function }
        if event_handlers[event_name] then
            local previous_function = event_handlers[event_name].func
            handler = {
                func = function(event)
                    previous_function(event)
                    event_function(event)
                end,
            }
        end

        event_handlers[event_name] = handler
    end
end



function tools.array_contains(array, value)
    for i, v in ipairs(array) do
        if v == value then return i end
    end
    return nil
end

--
-- debugging
--
function tools.debug_print(msg)
    if not msg then return end
    if type(msg) == 'string' then
        if game then game.print(msg) end
    elseif type(msg) == 'table' then
        if game then game.print(serpent.line(msg)) end
    end
end

return tools
