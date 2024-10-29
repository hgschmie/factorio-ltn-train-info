---@meta
----------------------------------------------------------------------------------------------------
-- access to the framework provided runtime storage - ported from flib
----------------------------------------------------------------------------------------------------

local Player = require('__stdlib__/stdlib/event/player')
local table = require('__stdlib__/stdlib/utils/table')

--- Main class governing the runtime.
-- Runtime exists during gameplay.
---@class FrameworkRuntime
local FrameworkRuntime = {}

--- Framework storage, not intended for direct access from the mod
---@return table<string,any?> framework_storage
function FrameworkRuntime:storage()
    storage[Framework.STORAGE] = storage[Framework.STORAGE] or {}
    return storage[Framework.STORAGE] --[[@as table<string, any?>>]]
end

--- Returns framework managed per-player storage
---@param player_index integer
---@return table<string,any?> player_storage
function FrameworkRuntime:player_storage(player_index)
    local _, player_data = Player.get(player_index)

    player_data[Framework.STORAGE] = player_data[Framework.STORAGE] or {}
    return player_data[Framework.STORAGE] --[[@as table<string, any?>>]]
end

local function get_id(self, name, initial_function)
    if self[name] then return self[name] end
    assert(self:storage(), 'no framework storage found!')

    if self:storage()[name] then
        Framework.logger:debugf('Loaded %s from storage', name)
        self[name] = self:storage()[name]
    else
        self[name] = initial_function and initial_function() or 0
        Framework.logger:debugf('Created %s (%d)', name, self[name])
        self:storage()[name] = self[name]
    end
    return self[name]
end

--- Get game id, creating it if necessary.
--- Unique(-ish) ID for the current save, so that we can have one persistent log file per savegame.
--- Must be called from an event (e.g. on_load or on_init)
---@return integer game_id
function FrameworkRuntime:get_game_id()
    return get_id(self, 'game_id', function() return math.random(100, 999) end)
end

--- Get (generate if necessary) run ID. run id increments for each call.
--- Unique(-ish) ID for the current save, so that we can have one persistent log file per savegame.
--- Must be called from an event (e.g. on_load or on_init)
---@return integer run_id
function FrameworkRuntime:get_run_id()
    local run_id = get_id(self, 'run_id')
    self:storage().run_id = run_id + 1
    return run_id
end

----------------------------------------------------------------------------------------------------

return FrameworkRuntime
