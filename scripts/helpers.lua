------------------------------------------------------------------------
-- Helper code
------------------------------------------------------------------------
assert(script)

local const = require('lib.constants')

---@class fo.Helpers
local Helpers = {}

---@param ticker_id string
---@return fo.Ticker
function Helpers:getTicker(ticker_id)
    assert(ticker_id)

    storage.ticker[ticker_id] = assert(storage.ticker)[ticker_id] or {}
    storage.ticker[ticker_id].last_tick = storage.ticker[ticker_id].last_tick or game.tick

    return storage.ticker[ticker_id]
end


return Helpers
