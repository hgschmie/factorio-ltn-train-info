------------------------------------------------------------------------
-- mod constant definitions.
--
-- can be loaded into scripts and data
------------------------------------------------------------------------

local table = require('stdlib.utils.table')

--------------------------------------------------------------------------------
-- main constants
--------------------------------------------------------------------------------

local Constants = {
    CURRENT_VERSION = 1,
    prefix = 'hps__lti-',
    name = 'ltn-train-info',
    root = '__ltn-train-info__',
    order = 'c[combinators]-dl[ltn-train-info]',
    config_tag_name = 'lti_config',
}

Constants.gfx_location = Constants.root .. '/graphics/'

--------------------------------------------------------------------------------
-- Framework intializer
--------------------------------------------------------------------------------

---@return FrameworkConfig config
function Constants.framework_init()
    return {
        -- prefix is the internal mod prefix
        prefix = Constants.prefix,
        -- name is a human readable name
        name = Constants.name,
        -- The filesystem root.
        root = Constants.root,
    }
end

--------------------------------------------------------------------------------
-- Path and name helpers
--------------------------------------------------------------------------------

---@param value string
---@return string result
function Constants:with_prefix(value)
    return self.prefix .. value
end

---@param path string
---@return string result
function Constants:png(path)
    return self.gfx_location .. path .. '.png'
end

---@param id string
---@return string result
function Constants:locale(id)
    return Constants:with_prefix('gui.') .. id
end

--------------------------------------------------------------------------------
-- entity names and maps
--------------------------------------------------------------------------------

-- Base name
Constants.lti_train_info_name = Constants:with_prefix(Constants.name)

--------------------------------------------------------------------------------
-- constants and names
--------------------------------------------------------------------------------

Constants.divide_by_min = 1
Constants.divide_by_max = 31 -- maximum length of a LTN train

---@enum lti_train_info.DeliveryType
Constants.delivery_type = {
    provide = 'provide',
    request = 'request'
}

---@enum lti_train_info.SignalType
Constants.signal_type = {
    quantity = 1,
    stack_size = 2,
    one = 3,
}

Constants.delivery_signals = {
    [Constants.delivery_type.provide] = 'signal-P',
    [Constants.delivery_type.request] = 'signal-R',
}

Constants.lti_range = 3

-- names of the supported "train" stops
Constants.lti_train_stop_names = { 'logistic-train-stop', 'ltn-port', }
Constants.lti_train_stops = table.array_to_dictionary(Constants.lti_train_stop_names)

--------------------------------------------------------------------------------
-- localization
--------------------------------------------------------------------------------

Constants.lti_entity_name = 'entity-name.' .. Constants.lti_train_info_name

--------------------------------------------------------------------------------
-- settings
--------------------------------------------------------------------------------

Constants.settings_keys = {}

Constants.settings_names = {}
Constants.settings = {}

for _, key in pairs(Constants.settings_keys) do
    Constants.settings_names[key] = key
    Constants.settings[key] = Constants:with_prefix(key)
end

return Constants
