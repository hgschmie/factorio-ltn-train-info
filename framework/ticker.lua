--------------------------------------------------------------------------------
-- Ticker and iterators
--------------------------------------------------------------------------------
assert(script)
assert(Framework)

-- Factorio Framework 2 (ff2)

---@alias ff2.ticker.TickerStorage table<string, any>
---@alias ff2.ticker.TickerContext table<string, any>
---@alias ff2.ticker.TickerIteratorCallback fun(context: ff2.ticker.TickerContext, values: ff2.ticker.TickerContext): any?

---@class ff2.Ticker
local Ticker = {}

---@param force boolean? If true, force reinit
---@return ff2.ticker.TickerStorage state Manages undo/redo state
function Ticker.state(force)
    local state = Framework.runtime:storage()

    ---@type ff2.ticker.TickerStorage
    state.ticker = (state.ticker and not force) and state.ticker or {}

    return state.ticker
end

---@param ticker_id string
---@return ff2.ticker.TickerContext
function Ticker.getTicker(ticker_id)
    assert(ticker_id)

    local state = Ticker.state()


    state[ticker_id] = state[ticker_id] or {}
    state[ticker_id].last_tick = state[ticker_id].last_tick or game.tick

    return state[ticker_id]
end

---@param ticker_id string
---@param ticker_fields string[]
function Ticker.resetTicker(ticker_id, ticker_fields)
    assert(ticker_id)

    local ticker_context = Ticker.getTicker(ticker_id)

    for _, field_name in pairs(ticker_fields) do
        ticker_context[field_name] = nil
    end
end

---@class ff2.ticker.TickerIteratorParams
---@field context      ff2.ticker.TickerContext
---@field field_name   string
---@field iterable     table<any, any>?
---@field process_iterable (fun(iterable: table<any, any>, context: ff2.ticker.TickerContext): table<any, any>)?
---@field sub_iterator ff2.ticker.TickerIterator?
---@field reset fun(context: ff2.ticker.TickerContext)?

---@param args ff2.ticker.TickerIteratorParams
---@return ff2.ticker.TickerIterator
function Ticker.createWorkIterator(args)
    ---@class ff2.ticker.TickerIterator
    local ticker_iterator = {

        ---@param callback ff2.ticker.TickerIteratorCallback  Callback that does the work
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
            iterable = args.process_iterable and args.process_iterable(iterable, args.context) or iterable

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

            local reset = args.context[args.field_name] == nil
            if reset and args.reset then args.reset(args.context) end

            -- return to the caller. If we incremented past the last element (wraparound at the next
            -- call), then signal to the caller that they must increment as well.
            return result, reset
        end,

        reset = function()
            -- reset this iterator and all sub-iterators. This should not be called
            -- outside the process function.
            args.context[args.field_name] = nil
            if args.reset then args.reset(args.context) end
            if args.sub_iterator then args.sub_iterator.reset() end
        end,
    }

    return ticker_iterator
end

return Ticker
