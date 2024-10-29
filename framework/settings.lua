---@meta
----------------------------------------------------------------------------------------------------
-- framework settings support -- inspired by flib
----------------------------------------------------------------------------------------------------

local table = require('__stdlib__/stdlib/utils/table')

----------------------------------------------------------------------------------------------------

--- Access to all mod settings
---@class FrameworkSettings
---@field definitions table<string, table>
local FrameworkSettings = {
   --- Contains setting definitions
   -- Each field must be a table with `setting = <default value>` items, as well as containing a
   -- `NAMES` table mapping settings fields to their in-game names (fields not present in NAMES will
   -- be ignored).
   definitions = {
      startup = {},
      runtime = {
        debug_mode = { Framework.PREFIX .. 'debug-mode', false }
      },
      player = {},
   }
}

---@type table<string, table<string, (integer|boolean|double|string|Color)?>?>
local loaded = {
   --- Startup settings
   startup = nil,
   --- Runtime settings
   runtime = nil,
   --- Player settings
   player = nil,
}

---@type table<string, FrameworkSettingDefinition>
local settings_table = {
   startup = {
      values = nil,
      load_value = function(name) return settings.startup[name] end,
      get_values = function(self) return self.values end,
      set_values = function(self, values) self.values = values end,
      clear = function(self) self.values = nil end,
   },

   runtime = {
      values = nil,
      load_value = function(name) return settings.global[name] end,
      get_values = function(self) return self.values end,
      set_values = function(self, values) self.values = values end,
      clear = function(self) self.values = nil end,
   },

   player = {
      values = {},
      load_value = function(name, player_index)
         if player_index then
            return settings.get_player_settings(player_index)[name]
         else
            return settings['player'][name]
         end
      end,
      get_values = function(self, player_index)
         local index = player_index or 'default'
         return self.values[index]
      end,
      set_values = function(self, values, player_index)
         local index = player_index or 'default'
         self.values[index] = values
      end,
      clear = function(self, player_index)
         if player_index then
            self.values[player_index] = {}
         else
            self.values = {}
         end
      end,
   },
}

--- Add setting definitions of the given setting_type to the corresponding table
---@param setting_type string
---@param definitions table<string, any>
---@return self FrameworkSettings
function FrameworkSettings:add_all(setting_type, definitions)
   table.merge(self.definitions[setting_type], definitions)

   settings_table[setting_type]:clear()
   return self
end

--- Add setting definitions to the startup table
---@param definitions table<string, any>
---@return self FrameworkSettings
function FrameworkSettings:add_startup(definitions)
   return self:add_all('startup', definitions)
end

--- Add setting definitions to the runtime table
---@param definitions table<string, any>
---@return self FrameworkSettings
function FrameworkSettings:add_runtime(definitions)
   return self:add_all('runtime', definitions)
end

--- Add setting definitions to the player table
---@param definitions table<string, any>
---@return self FrameworkSettings
function FrameworkSettings:add_player(definitions)
   return self:add_all('player', definitions)
end

--- Access the mod's settings
---@param setting_type string Setting setting_type. Valid values are "startup", "runtime" and "player"
---@param player_index integer? The current player index.
---@return table<string, (integer|boolean|double|string|Color)?> result
function FrameworkSettings:get_settings(setting_type, player_index)
   local st = settings_table[setting_type]

   if (not st:get_values(player_index)) then
      local definition = self.definitions[setting_type]
      local values = {}
      st:set_values(values, player_index)

      for key, setting_def in pairs(definition) do
         if (type(setting_def) == 'table') then
            local value = st.load_value(setting_def[1], player_index).value
            if (value == nil) then
               value = setting_def[2]
            end
            values[key] = value
         end
      end
      Framework.logger:debugf("Loaded '%s' settings: %s", setting_type, serpent.line(st:get_values()))
   end
   return st:get_values(player_index) or error('Failed to load ' .. setting_type .. ' settings.')
end

--- Flushes all cached settings.
--- The next access to a setting will reload them from the game.
function FrameworkSettings:flush()
   settings_table['player']:clear()
   settings_table['runtime']:clear()
end

--- Access the startup settings.
---@return table<string, (integer|boolean|double|string|Color)?> result
function FrameworkSettings:startup()
   return self:get_settings('startup')
end

--- Access the runtime settings.
---@return table<string, (integer|boolean|double|string|Color)?> result
function FrameworkSettings:runtime()
   return self:get_settings('runtime')
end

--- Access the player settings. If no player index is given, use the default player settings in settings.player.
---@param player_index integer? The current player index.
---@return table<string, (integer|boolean|double|string|Color)?> result
function FrameworkSettings:player(player_index)
   return self:get_settings('player', player_index)
end

----------------------------------------------------------------------------------------------------

if script then
   local Event = require('__stdlib__/stdlib/event/event')

   -- Runtime settings changed
   Event.register(defines.events.on_runtime_mod_setting_changed, function()
      FrameworkSettings:flush()
   end)
end

return FrameworkSettings
