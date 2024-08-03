------------------------------------------------------------------------
-- mod constant definitions.
--
-- can be loaded into scripts and data
------------------------------------------------------------------------

local table = require('__stdlib__/stdlib/utils/table')

local Constants = {}

--------------------------------------------------------------------------------
-- main constants
--------------------------------------------------------------------------------

-- debug mode
Constants.debug_mode = 0

-- the current version that is the result of the latest migration
Constants.current_version = 1

Constants.prefix = 'hps:lti-'
Constants.name = 'ltn-train-info'
Constants.root = '__ltn-train-info__'
Constants.gfx_location = Constants.root .. '/gfx/'

Constants.divide_by_max = 20
Constants.divide_by_min = 1

Constants.signal_type = {
    quantity = 1,
    stack_size = 2,
    one = 3,
}

Constants.delivery_type = table.array_to_dictionary({'provide', 'request'})

Constants.delivery_signals = {
    [Constants.delivery_type.provide] = 'signal-P',
    [Constants.delivery_type.request] = 'signal-R',
}

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
Constants.lti_train_info = Constants:with_prefix(Constants.name)
Constants.lti_range = 3

-- names of the supported "train" stops
Constants.lti_train_stop_names = { 'logistic-train-stop', 'ltn-port', }
Constants.lti_train_stops = table.array_to_dictionary(Constants.lti_train_stop_names)

--------------------------------------------------------------------------------
-- localization
--------------------------------------------------------------------------------

Constants.lti_entity_name = 'entity-name.' .. Constants.lti_train_info

return Constants
