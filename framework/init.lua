------------------------------------------------------------------------
-- Framework initialization code
--
-- provides the global `Framework` object
--
------------------------------------------------------------------------

local Is = require('stdlib.utils.is')

----------------------------------------------------------------------------------------------------

--- Framework central access point
-- The framework singleton, provides access to well known constants and the Framework components
-- other components.

---@class FrameworkRoot
---@field PREFIX string
---@field NAME string
---@field GAME_ID integer,
---@field RUN_ID integer,
---@field settings FrameworkSettings?
---@field logger FrameworkLogger?
---@field runtime FrameworkRuntime?
---@field gui_manager framework.gui_manager?
---@field Ghost ff2.ghost_manager?
---@field blueprint framework.blueprint.Manager?
---@field Tombstone ff2.TombstoneManager?
---@field translation_manager framework.translation.Manager?
---@field other_mods framework.OtherModsManager
---@field RemoteApis ff2.RemoteApisManager?
---@field ExportedApis table<string, function>?
---@field render FrameworkRender?
local FrameworkInit = {
    --- The non-localised prefix (textual ID) of this mod.
    -- Must be set as the earliest possible time, as virtually all other framework parts use this.
    PREFIX = 'unknown-module-',

    --- Human readable, non-localized name
    NAME = '<unknown>',

    --- Root location
    ROOT = '__unknown__',

    GAME_ID = -1,

    RUN_ID = -1,

    settings = nil,

    logger = nil,

    runtime = nil,

    gui_manager = nil,

    ghost_manager = nil,

    blueprint = nil,

    translation_manager = nil,

    Tombstone = nil,

    ExportedApis = nil,

    RemoteApis = nil,

    render = nil,
}

--- called in runtime stage
---@param config FrameworkConfig
function FrameworkInit:init_runtime(config)
    -- runtime stage
    self.runtime = self.runtime or require('framework.runtime')

    self.logger:init()

    self.logger:log('================================================================================')
    self.logger:log('==')
    self.logger:logf("== Framework logfile for '%s' mod intialized ", FrameworkInit.NAME)     --(debug mode: %s)", FrameworkInit.NAME, tostring(self.debug_mode))
    self.logger:log('==')
    self.logger:logf('== Run ID: %d', FrameworkInit.RUN_ID)
    self.logger:log('================================================================================')
    self.logger:flush()

    self.gui_manager = self.gui_manager or require('framework.gui_manager')
    self.Ghost = self.Ghost or require('framework.ghost_manager')
    self.blueprint = self.blueprint or require('framework.blueprint_manager')
    self.translation_manager = self.translation_manager or require('framework.translation_manager')
    self.Tombstone = self.Tombstone or require('framework.tombstone_manager')

    self.render = self.render or require('framework.render')

    if config.exported_api_name and not self.ExportedApis then
        self.ExportedApis = {}
        remote.add_interface(config.exported_api_name, self.ExportedApis)
    end
end

--- Initialize the core framework.
--- the code itself references the global Framework table.
---@param config FrameworkConfig|function():FrameworkConfig config provider
function FrameworkInit:init(config)
    assert(Is.Function(config) or Is.Table(config), 'configuration must either be a table or a function that provides a table')
    if Is.Function(config) then
        config = config()
    end

    assert(config, 'no configuration provided')
    assert(config.name, 'config.name must contain the mod name')
    assert(config.prefix, 'config.prefix must contain the mod prefix')
    assert(config.root, 'config.root must be contain the module root name!')

    self.NAME = config.name
    self.PREFIX = config.prefix
    self.ROOT = config.root

    -- load only once per stage
    self.settings = self.settings or require('framework.settings') --[[@as FrameworkSettings ]]
    self.logger = self.logger or require('framework.logger') --[[@as FrameworkLogger ]]
    self.other_mods = self.other_mods or require('framework.other-mods')
    self.RemoteApis = self.RemoteApis or require('framework.remote-apis')

    if data and data.raw['gui-style'] then
        -- data stage
        require('framework.prototype')
    elseif script then
        -- runtime stage
        self:init_runtime(config --[[@as FrameworkConfig]])
    end

    -- flush possible settings pulled in by framework init code
    self.settings:flush()

    return self
end

---------------------------------------------------------------------------------------------------
-- add meta methods
---------------------------------------------------------------------------------------------------

local game_stages = { 'settings', 'data', 'data_updates', 'data_final_fixes', 'runtime' }

local Framework_mt = {}
setmetatable(FrameworkInit, Framework_mt)

local prototype = {}

for _, game_stage in pairs(game_stages) do
    prototype['post_' .. game_stage .. '_stage'] = function()
        -- otherwise, it is an stage method, pass it to the submodules
        FrameworkInit.other_mods[game_stage]() -- other-mods subsystem
        FrameworkInit.RemoteApis[game_stage]() -- remote-apis subsystem
    end
end

Framework_mt.__index = prototype

Framework = FrameworkInit

return FrameworkInit
