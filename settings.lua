This, Framework = require('lib.init')()

local framework_settings = {
    {
        -- Debug mode (framework dependency)
        type = 'bool-setting',
        name = Framework.PREFIX .. 'debug-mode',
        order = 'z',
        setting_type = 'startup',
        default_value = false,
    },
}

data:extend(framework_settings)

---@diagnostic disable-next-line: undefined-field
Framework.post_settings_stage()
