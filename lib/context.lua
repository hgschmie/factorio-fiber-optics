--
-- manage context
--
local tools = require('lib.tools')

---@class ModContext
local Context = {}

---------------------------------------------------------------------------------------------------------

--- Locate a nested element
---@param root table<string, any> The root table.
---@param fields string|string[] Coordinates for the element.
---@return table<string, any> obj Table to access the element from.
---@return string key The key for the element in the table.
local function locate_nested_element(root, fields)
    if type(fields) == 'table' then
        local target = root
        assert(#fields > 0, "no field reference found")

        for idx = 1, #fields - 1, 1 do
            if not target[fields[idx]] then
                target[fields[idx]] = {}
            end
            target = target[fields[idx]]
        end
        return target, fields[#fields]
    else
        return root, fields
    end
end

local function find_element(entity_context, fields)
    local target, name = locate_nested_element(entity_context, fields)
    return target[name]
end

local function get_unit_number(entity)
    if type(entity) == 'table' then
        assert(tools.is_valid(entity), "entity is not valid!")
        return entity.unit_number
    else
        return tonumber(entity)
    end
end

---------------------------------------------------------------------------------------------------------

--- Default implementation to create an entity related context. The context contains
-- two fields, the primary entity and the unit number of the primary entity as _primary and _unit_number.
---@param primary_entity table<string, any> Any entity to associate a context to.
---@return table The context object.
local function default_create_context(primary_entity)
    assert(primary_entity, "primary_entity can not be nil!")

    return {
        _primary = primary_entity,
        _unit_number = primary_entity.unit_number,
    }
end

local function create_entity_context(context, primary_entity)
    local entity_context = context._create_entity_context(primary_entity)

    entity_context._cleanup = {}
    entity_context.valid = true

    return entity_context
end

local function destroy_entity_context(context, entity_context, unit_number)
    if entity_context then
        if context._destroy_entity_context then
            context._destroy_entity_context(unit_number, entity_context)
        end

        for entity_key, entity_value in pairs(entity_context._cleanup) do
            local entity = (type(entity_key) == 'table' and entity_key) or entity_value
            if entity.valid then
                entity.destroy()
            end
        end
    end

    context.valid = false
end

---------------------------------------------------------------------------------------------------------

--- Initializes the context system. Called by on_init.
--- @param custom_create_entity_context function<table<string, any>>? The function to call to create an new entity context.
--- @param custom_destroy_entity_context function<number, table<string, any>>? The function to call to destroy an existing entity context.
function Context:init(custom_create_entity_context, custom_destroy_entity_context)
    global.context = {}
    self:load(custom_create_entity_context, custom_destroy_entity_context)
end

-- Initialized the context system when on_load is called.
--- @param custom_create_entity_context function<table<string, any>>? The function to call to create an new entity context.
--- @param custom_destroy_entity_context function<number, table<string, any>>? The function to call to destroy an existing entity context.
function Context:load(custom_create_entity_context, custom_destroy_entity_context)
    self._create_entity_context = custom_create_entity_context or default_create_context
    self._destroy_entity_context = custom_destroy_entity_context

    assert(global.context, "Load called but no global context found!")
end

---------------------------------------------------------------------------------------------------------

function Context:get_all_contexts()
    return global.context
end

function Context:get_entity_context(primary_entity, create)
    assert(global.context, "global context is not defined!")

    local unit_number = get_unit_number(primary_entity)

    local entity_context = global.context[unit_number]

    if not entity_context and create then
        assert(type(primary_entity) == 'table', "Need primary_entity object to create context!")

        entity_context = create_entity_context(self, primary_entity)
        Context:set_entity_context(primary_entity, entity_context)
    end

    return entity_context
end

function Context:set_entity_context(primary_entity, context)
    assert(global.context, "global context is not defined!")
    local unit_number = get_unit_number(primary_entity)

    local old_context = global.context[unit_number]

    global.context[unit_number] = context
    return old_context
end

---------------------------------------------------------------------------------------------------------

function Context:cleanup(primary_entity)
    assert(global.context, "global context is not defined!")
    local unit_number = get_unit_number(primary_entity)

    local entity_context = Context:set_entity_context(unit_number, nil)
    destroy_entity_context(self, entity_context, unit_number)
end

---------------------------------------------------------------------------------------------------------

local function do_add_entity(entity_context, fields, entity)
    -- resolve lazy (function) entities
    if type(entity) == "function" then
        entity = entity(entity_context)
    end

    assert(type(entity) == 'table', "Can only add entities!")

    -- register for cleanup
    entity_context._cleanup[entity.unit_number] = entity
    -- register for access

    local target, name = locate_nested_element(entity_context, fields)
    local old_value = target[name]
    target[name] = entity

    return entity, old_value
end

function Context:remove_entity(primary_entity, fields)
    local entity_context = self:get_entity_context(primary_entity, false)
    if not entity_context then return nil end

    local target, name = locate_nested_element(entity_context, fields)
    local old_value = target[name]
    target[name] = nil

    if old_value then
        entity_context._cleanup[old_value.unit_number] = nil
        entity_context._cleanup[old_value] = nil
    end

    return old_value
end

function Context:add_entity(primary_entity, name, entity)
    local entity_context = self:get_entity_context(primary_entity, false)
    if not entity_context then return nil end
    return do_add_entity(entity_context, name, entity)
end

function Context:add_entity_if_not_exists(primary_entity, name, entity)
    local entity_context = self:get_entity_context(primary_entity, false)
    if not entity_context then return nil end

    local value = find_element(entity_context, name)
    if value then return value end

    return do_add_entity(entity_context, name, entity)
end

---------------------------------------------------------------------------------------------------------

local function do_set_field(entity_context, fields, value)
    -- resolve lazy (function) entities
    if type(value) == "function" then
        value = value(entity_context)
    end

    -- register for access
    local target, name = locate_nested_element(entity_context, fields)
    local old_value = target[name]
    target[name] = value
    return value, old_value
end

function Context:get_field(primary_entity, fields)
    local entity_context = self:get_entity_context(primary_entity, false)
    if not entity_context then return nil end
    return find_element(entity_context, fields)
end

function Context:remove_field(primary_entity, fields)
    local entity_context = self:get_entity_context(primary_entity, false)
    if not entity_context then return nil end

    local target, name = locate_nested_element(entity_context, fields)
    local old_value = target[name]
    target[name] = nil
    return old_value
end

function Context:set_field(primary_entity, name, value)
    local entity_context = self:get_entity_context(primary_entity, false)
    if not entity_context then return nil end
    return do_set_field(entity_context, name, value)
end

function Context:set_field_if_not_exists(primary_entity, name, value)
    local entity_context = self:get_entity_context(primary_entity, false)
    if not entity_context then return nil end

    local old_value = find_element(entity_context, name)
    if old_value then return old_value end

    return do_set_field(entity_context, name, value)
end

return Context
