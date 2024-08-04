---@meta
------------------------------------------------------------------------
-- Framework initialization code
--
-- provides the global `Framework` object
--
------------------------------------------------------------------------

local Is = require('__stdlib__/stdlib/utils/is')

----------------------------------------------------------------------------------------------------

--- Framework central access point
-- The framework singleton, provides access to well known constants and the Framework components
-- other components.

---@class FrameworkRoot
---@field PREFIX string
---@field NAME string
---@field STORAGE string
---@field GAME_ID integer,
---@field RUN_ID integer,
---@field settings FrameworkSettings?
---@field logger FrameworkLogger?
---@field runtime FrameworkRuntime?
---@field gui_manager FrameworkGuiManager?
---@field ghost_manager FrameworkGhostManager?
---@field blueprint FrameworkBlueprintManager?
---@field remote_api table<string, function>?
---@field render FrameworkRender?
Framework = {
    --- The non-localised prefix (textual ID) of this mod.
    -- Must be set as the earliest possible time, as virtually all other framework parts use this.
    PREFIX = 'unknown-module-',

    --- Human readable, non-localized name
    NAME = '<unknown>',

    --- Root location
    ROOT = '__unknown__',

    --- Name of the field in `global` to store framework persistent runtime data.
    STORAGE = 'framework',

    GAME_ID = -1,

    RUN_ID = -1,

    settings = nil,

    logger = nil,

    runtime = nil,

    gui_manager = nil,

    ghost_manager = nil,

    blueprint = nil,

    remote_api = nil,

    render = nil,
}

--- Initialize the core framework.
--- the code itself references the global Framework table.
---@param config FrameworkConfig|function():FrameworkConfig config provider
function Framework:init(config)
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

    self.settings = require('framework.settings') --[[ @as FrameworkSettings ]]
    self.logger = require('framework.logger') --[[ @as FrameworkLogger ]]

    if (script) then
        -- runtime stage
        self.runtime = require('framework.runtime')

        self.logger:init()

        self.gui_manager = require('framework.gui_manager')
        self.ghost_manager = require('framework.ghost_manager')
        self.blueprint = require('framework.blueprint_manager')

        self.render = require('framework.render')

        if config.remote_name then
            self.remote_api = {}
            remote.add_interface(config.remote_name, self.remote_api)
        end
    elseif data.raw['gui-style'] then
        -- prototype stage
        require('framework.prototype')
    end

    return self
end

---------------------------------------------------------------------------------------------------

return Framework
