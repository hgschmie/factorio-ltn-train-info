----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class lti_train_info.Mod
---@field other_mods table<string, string>
---@field Lti lti_train_info.Lti?
---@field Gui lti_train_info.Gui?
local This = {
    other_mods = {
        LogisticTrainNetwork = 'ltn',
        ['even-pickier-dollies'] = 'picker_dollies',
    },
}

if (script) then
    This.Lti = require('scripts.train-info')
    This.Gui = require('scripts.gui')
end

----------------------------------------------------------------------------------------------------

return This
