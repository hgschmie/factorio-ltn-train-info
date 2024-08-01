----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@type ModThis
local This = {
    other_mods = { 'LogisticTrainNetwork', 'PickerDollies' },
    debug_mode = 0,

    lti = require('scripts.train-info'),
    gui = nil,
}

if (script) then
    This.gui = require('scripts.gui') --[[@as ModGui ]]
end

----------------------------------------------------------------------------------------------------

return This
