------------------------------------------------------------------------
-- Framework logger
------------------------------------------------------------------------

local StdLibLogger = require('__stdlib__/stdlib/misc/logger')

----------------------------------------------------------------------------------------------------

local dummy = function(...) end

local default_logger = { log = log }

--- Logging
---@class FrameworkLogger
---@field debug_mode boolean? If true, debug and debugf produce output lines
---@field core_logger table<string, any> The logging target
local FrameworkLogger = {
    debug_mode = nil,
    core_logger = default_logger,

    debug = dummy,
    debugf = dummy,
    flush = dummy,
}

---@param message string
function FrameworkLogger:log(message)
    self.core_logger.log(message)
end

---@param message string
---@param ... any
function FrameworkLogger:logf(message, ...)
    self.core_logger.log(message:format(table.unpack { ... }))
end

if FrameworkLogger.debug_mode then
    FrameworkLogger.debug = FrameworkLogger.log
    FrameworkLogger.debugf = FrameworkLogger.logf
end

function FrameworkLogger:updateDebugSettings()
    local new_debug_mode = Framework.settings:runtime().debug_mode --[[@as boolean]]

    if new_debug_mode ~= self.debug_mode then
        self:log('==')
        self:logf('== Debug Mode %s.', new_debug_mode and 'enabled' or 'disabled')
        self:log('==')
    end

    -- reset debug logging, turn back on if debug_mode is still set
    self.debug = (new_debug_mode and self.log) or dummy
    self.debugf = (new_debug_mode and self.logf) or dummy

    self.debug_mode = new_debug_mode
end

----------------------------------------------------------------------------------------------------

--- Brings up the actual file logging using the stdlib. This only works in runtime mode, otherwise logging
--- just goes to the regular logfile/output.
---
--- writes a <module-name>/framework.log logfile by default
function FrameworkLogger:init()
    assert(script, 'Logger can only be initalized in runtime stage')

    self.core_logger = StdLibLogger.new('framework', self.debug_mode, { force_append = true })

    self.flush = function() self.core_logger.write() end

    self:log('================================================================================')
    self:log('==')
    self:logf("== Framework logfile for '%s' mod intialized ", Framework.NAME) --(debug mode: %s)", Framework.NAME, tostring(self.debug_mode))
    self:log('==')

    self:updateDebugSettings()

    local Event = require('__stdlib__/stdlib/event/event')

    -- The runtime storage is only available from an event. Schedule logging (and loading) for RUN_ID and GAME_ID
    -- in a tick event, then remove the event handler again.
    self.info = function()
        Framework.RUN_ID = Framework.runtime:get_run_id()
        Framework.GAME_ID = Framework.runtime:get_game_id()
        Framework.logger:logf('== Game ID: %d, Run ID: %d', Framework.GAME_ID, Framework.RUN_ID)
        Framework.logger:log('================================================================================')
        Framework.logger:flush()

        Event.remove(defines.events.on_tick, self.info)
        self.info = nil
    end
    Event.register(defines.events.on_tick, self.info)

    -- flush the log every 60 seconds
    Event.on_nth_tick(3600, function(ev)
        self:flush()
    end)

    -- Runtime settings changed
    Event.register(defines.events.on_runtime_mod_setting_changed, function()
        self:updateDebugSettings()
    end)
end

return FrameworkLogger
