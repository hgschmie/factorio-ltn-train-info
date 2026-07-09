----------------------------------------------------------------------------------------------------
--- Global definitions included in all phases
----------------------------------------------------------------------------------------------------

local const = require('lib.constants')

-- Framework core
local framework = require('framework.init'):init(const.framework_init)

-- mod code
local this = require('lib.this')

return function()
    return this, framework
end
