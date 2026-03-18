------------------------------------------------------------------------
-- Helper code
------------------------------------------------------------------------
assert(script)

---@class fo.Helpers
local Helpers = {}

---@alias helper.TickerContext table<string, any>

---@param ticker_id string
---@return helper.TickerContext
function Helpers:getTicker(ticker_id)
    assert(ticker_id)

    storage.ticker[ticker_id] = assert(storage.ticker)[ticker_id] or {}
    storage.ticker[ticker_id].last_tick = storage.ticker[ticker_id].last_tick or game.tick

    return storage.ticker[ticker_id]
end

---@class helper.TickerIteratorParams
---@field context helper.TickerContext
---@field field_name string
---@field iterable table<any, any>?
---@field sub_iterator helper.TickerIterator?

---@alias helper.TickerIteratorCallback fun(keys: helper.TickerContext, values: helper.TickerContext): any?

---@param args helper.TickerIteratorParams
---@return helper.TickerIterator
function Helpers.createWorkIterator(args)
    ---@class helper.TickerIterator
    local ticker_iterator = {
        ---@param callback helper.TickerIteratorCallback  Callback that does the work
        ---@param values table<any, any>? Current value snapshot. If not provided, an empty table is created.
        ---@param parent_field_name string? The name of the enclosing iterator if any.
        ---@return any result Callback result.
        ---@return boolean increment If true, the last iteration reached the end. This signals the enclosing iterator to increment.
        process = function(callback, values, parent_field_name)
            if not values then values = {} end

            -- If an iterable was passed in, it takes precedence. If none was passed in,
            -- then it is assumed that the current parent value is iterable and should be used.
            -- One or the other must exist!
            local iterable = assert(args.iterable or (parent_field_name and values[parent_field_name]))

            if not (args.context[args.field_name] and iterable[args.context[args.field_name]]) then
                -- the current iterator state is either not valid or unset. Reset the iterator
                -- to the first value.
                args.context[args.field_name] = next(iterable)
                -- also reset all subiterators (they need to start fresh)
                if args.sub_iterator then args.sub_iterator.reset() end
                -- if not value exist in the array, then signal to a possible enclosing iterator
                -- that it needs to increment and return. As no callback was executed, return nil
                -- as the value.
                if not args.context[args.field_name] then return nil, true end
            end

            -- the iterator here must be valid (either it passed the check above or it has been reset to the first value)
            values[args.field_name] = assert(iterable[args.context[args.field_name]])

            local result
            local increment = true
            if args.sub_iterator then
                -- if sub-iterator(s) exist, go down the chain and have them execute the callback
                -- The goal is to compose a full set of iterated, validated values (highest -> lowest)
                -- before actually executing the callback.
                result, increment = args.sub_iterator.process(callback, values, args.field_name)
            else
                -- this is the lowest (sub-)iterator, so the set of values is complete. Do the work
                result = callback(args.context, values)
            end

            if increment then
                -- if we executed the callback, we increment in any case
                -- the sub-iterator has incremented. See if we need to increment as well.
                args.context[args.field_name] = next(iterable, args.context[args.field_name])
            end

            -- return to the caller. If we incremented past the last element (wraparound at the next
            -- call), then signal to the caller that they must increment as well.
            return result, args.context[args.field_name] == nil
        end,

        reset = function()
            -- reset this iterator and all sub-iterators. This should not be called
            -- outside the process function.
            args.context[args.field_name] = nil
            if args.sub_iterator then args.sub_iterator.reset() end
        end
    }

    return ticker_iterator
end

return Helpers
