---@meta
--------------------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------------------

local Is = require('__stdlib__/stdlib/utils/is')
local table = require('__stdlib__/stdlib/utils/table')

---@class FrameworkUtil
---@field STATUS_TABLE table<defines.entity_status, string>
---@field STATUS_SPRITES table<defines.entity_status, string>
---@field STATUS_NAMES table<defines.entity_status, string>
---@field STATUS_LEDS table<string, string>
---@field CREATION_EVENTS defines.events[]
---@field DELETION_EVENTS defines.events[]
local Util = {
    STATUS_LEDS = {},
    STATUS_TABLE = {},
    STATUS_NAMES = {},
    STATUS_SPRITES = {},
    CREATION_EVENTS = {
        defines.events.on_built_entity,
        defines.events.on_robot_built_entity,
        defines.events.script_raised_built,
        defines.events.script_raised_revive,
    },
    DELETION_EVENTS = {
        defines.events.on_player_mined_entity,
        defines.events.on_robot_mined_entity,
        defines.events.on_entity_died,
        defines.events.script_raised_destroy,
    },
}

--------------------------------------------------------------------------------
-- entity_status led and caption
--------------------------------------------------------------------------------

Util.STATUS_LEDS = {
    RED = 'utility/status_not_working',
    GREEN = 'utility/status_working',
    YELLOW = 'utility/status_yellow',
}

Util.STATUS_TABLE = {
    [defines.entity_status.working] = 'GREEN',
    [defines.entity_status.normal] = 'GREEN',
    [defines.entity_status.no_power] = 'RED',
    [defines.entity_status.low_power] = 'YELLOW',
    [defines.entity_status.disabled_by_control_behavior] = 'RED',
    [defines.entity_status.disabled_by_script] = 'RED',
    [defines.entity_status.marked_for_deconstruction] = 'RED',
    [defines.entity_status.disabled] = 'RED',
}

for name, idx in pairs(defines.entity_status) do
    Util.STATUS_NAMES[idx] = 'entity-status.' .. string.gsub(name, '_', '-')
end

for status, led in pairs(Util.STATUS_TABLE) do
    Util.STATUS_SPRITES[status] = Util.STATUS_LEDS[led]
end

--------------------------------------------------------------------------------
-- entity event matcher management
--------------------------------------------------------------------------------

local function create_matcher(values, entity_matcher)
    if type(values) ~= 'table' then
        values = { values }
    end

    local matcher_map = table.array_to_dictionary(values, true)
    return function(event, pattern)
        if not event then return false end
        -- move / clone events
        if event.source and event.destination then
            return matcher_map[entity_matcher(event.source, pattern)] and matcher_map[entity_matcher(event.destination, pattern)]
        end

        return matcher_map[entity_matcher(event.entity, pattern)]
    end
end

---@param attribute string The entity attribute to match.
---@param values string|string[] One or more values to match.
---@return function(ev: EventData, pattern: any): boolean
function Util.create_event_entity_matcher(attribute, values)
    local matcher = function(entity) return entity and entity[attribute] end
    return create_matcher(values, matcher)
end

---@param attribute string The entity attribute to match.
---@param values string|string[] One or more values to match.
---@return function(ev: EventData, pattern: any): boolean
function Util.create_event_ghost_entity_matcher(attribute, values)
    local matcher = function(entity) return entity and entity.type == 'entity-ghost' and entity[attribute] end
    return create_matcher(values, matcher)
end

---@param values string|string[] One or more names to match to the ghost_name field.
---@return function(ev: EventData, pattern: any): boolean
function Util.create_event_ghost_entity_name_matcher(values)
    return Util.create_event_ghost_entity_matcher('ghost_name', values)
end

--------------------------------------------------------------------------------
-- event registration support (only for runtime!)
--------------------------------------------------------------------------------

if script then
    local Event = require('__stdlib__/stdlib/event/event')

    --- Registers a handler for the given events.
    --- works around https://github.com/Afforess/Factorio-Stdlib/pull/164
    ---@param event_ids defines.events[]
    ---@param handler function(ev: EventData)
    ---@param filter? function(ev: EventData, pattern: any?)?:boolean
    ---@param pattern any?
    ---@param options table<string, boolean>?
    function Util.event_register(event_ids, handler, filter, pattern, options)
        assert(Is.Table(event_ids))
        for _, event_id in pairs(event_ids) do
            Event.register(event_id, handler, filter, pattern, options)
        end
    end
end

return Util
