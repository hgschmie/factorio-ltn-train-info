-----------------------------
-- Move ticker state into framework
-----------------------------

local Ticker = require('framework.ticker')

This, Framework = require('lib.init')()

if storage.ticker then
    local state = Ticker.state()

    for ticker_id, ticker in pairs(storage.ticker) do
        state[ticker_id] = ticker
    end

    storage.ticker = nil
end
