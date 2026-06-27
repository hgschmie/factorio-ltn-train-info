----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class lti.Mod
---@field other_mods table<string, string>
---@field Lti lti.Lti?
---@field Gui lti.Gui?
local This = {
    remote_apis = {
        ['PickerDollies'] = 'picker-dollies',
        ['logistic-train-network'] = 'ltn',
    },
}

if (script) then
    This.Lti = require('scripts.train-info')
    This.Gui = require('scripts.gui')
end

----------------------------------------------------------------------------------------------------

return This
