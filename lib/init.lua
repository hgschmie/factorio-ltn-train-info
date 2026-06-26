----------------------------------------------------------------------------------------------------
--- Global definitions included in all phases
----------------------------------------------------------------------------------------------------

local const = require('lib.constants')

-- Framework core
local Framework = require('framework.init'):init(const.framework_init)

-- mod code
local This = require('lib.this')

return function()
    return This, Framework
end
