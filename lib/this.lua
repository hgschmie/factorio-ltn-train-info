----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

local const = require('lib.constants')

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

function This.boot()
    This.Lti = require('scripts.train-info')
    This.Gui = require('scripts.gui')
end

--------------------------------------------------------------------------------
-- Framework initializer
--------------------------------------------------------------------------------

---@return FrameworkConfig config
function This.framework_init()
    return {
        -- prefix is the internal mod prefix
        prefix = const.prefix,
        -- prefix for log messages
        log_prefix = const.log_prefix,
        -- name is a human readable name
        name = const.name,
        -- The filesystem root.
        root = const.root,
    }
end

return This
