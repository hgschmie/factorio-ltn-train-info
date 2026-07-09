---@meta
----------------------------------------------------------------------------------------------------
--- framework types
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
--- ghost_manager.lua
----------------------------------------------------------------------------------------------------

--@field name string
--@field position MapPosition
--@field surface_index number
--@field direction defines.direction

---@class ff2.ghost_manager.AttachedEntity
---@field entity LuaEntity
---@field key string
---@field tags Tags?
---@field player_index integer
---@field tick integer
---@field pre_build ff2.ghost_manager.PreBuild?

---@class ff2.ghost_manager.PreBuild
---@field tick integer
---@field direction defines.direction
---@field flip_horizontal boolean
---@field flip_vertical boolean

---@class ff2.ghost_manager.State
---@field ghost_entities ff2.ghost_manager.AttachedEntity[]
---@field pre_build ff2.ghost_manager.PreBuild[]

----------------------------------------------------------------------------------------------------
--- gui.lua
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
--- init.lua
----------------------------------------------------------------------------------------------------

---@class FrameworkConfig
---@field name string The human readable name for the module
---@field prefix string A prefix for all game registered elements
---@field root string The module root name
---@field log_tag string? A custom logger tag
---@field exported_api_name string? The name for the remote interface. If defined, the mod will expose an API for other mods to call.

----------------------------------------------------------------------------------------------------
--- settings.lua
----------------------------------------------------------------------------------------------------

---@alias FrameworkSettingsStorage table<string, (FrameworkSettingValue|table<string, FrameworkSettingValue?>)?>?

---@class FrameworkSettingsProvider
---@field values FrameworkSettingsStorage
---@field definitions FrameworkSettingsGroup
---@field load_value fun(name: string, player_index: integer?): ModSetting?
---@field store_value fun(name: string, value: FrameworkSettingValue, player_index: integer?)?
---@field get_values fun(self: FrameworkSettingsProvider, player_index: integer?): FrameworkSettingsStorage
---@field set_values fun(self: FrameworkSettingsProvider, values: table<string, FrameworkSettingValue?>, player_index: integer?)
---@field clear fun(self: FrameworkSettingsProvider, player_index: integer?)

---@alias FrameworkSettingValue (int)|(double)|(boolean)|(string)|(Color)

---@class FrameworkSetting
---@field key string
---@field value FrameworkSettingValue

---@alias FrameworkSettingsGroup table<string, FrameworkSetting>
