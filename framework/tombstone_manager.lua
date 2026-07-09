------------------------------------------------------------------------
-- Manages tombstone (configuration data after an entity has been removed)
--
-- Deals with:
--   - undo/redo
--      - undo construction will save config/tombstone information for redo
--      - redo destruction will save config/tombstone for undo
--   - entities dying
------------------------------------------------------------------------
assert(script)
assert(Framework)

local Event = require('stdlib.event.event')

local Matchers = require('framework.matchers')
local Ticker = require('framework.ticker')
local tools = require('framework.tools')

local TICKER_NAME = 'ff2.tombstone'
local TICK_INTERVAL = 59             -- ~ tick about once  per second
local LIFETIME_IN_TICKS = 60 * 86400 -- 24 hours

---@alias ff2.tombstone.TombstoneMap table<string, ff2.tombstone.Tombstone>

---@class ff2.tombstone.State
---@field tombstones table<string, table<string, ff2.tombstone.TombstoneMap>>
---@field tombstone_count integer

---@alias ff2.tombstone.UndoRedoAction fun(action: UndoRedoAction.base)
---@alias ff2.tombstone.CreateTombstoneCallback fun(entity: LuaEntity): Tags?
---@alias ff2.tombstone.ApplyTombstoneCallback fun(entity_data: Tags?, position: MapPosition, surface_index: number, name: string)

---@class ff2.tombstone.TombstoneCallback
---@field create_tombstone ff2.tombstone.CreateTombstoneCallback
---@field apply_tombstone ff2.tombstone.ApplyTombstoneCallback

---@class ff2.tombstone.TombstoneKey
---@field position data.MapPosition
---@field surface_index integer
---@field type string
---@field name string?

---@class ff2.tombstone.Tombstone
---@field position data.MapPosition
---@field surface_index integer
---@field type string
---@field name string
---@field data table<string, any>
---@field tick number

---@class ff2.TombstoneManager
---@field known_actions table<string, ff2.tombstone.UndoRedoAction>
---@field callbacks table<string, ff2.tombstone.TombstoneCallback>
local FrameworkTombstoneManager = {
    known_actions = {},
    callbacks = {}
}

---@param force boolean? If true, force reinit
---@return ff2.tombstone.State state Manages undo/redo state
function FrameworkTombstoneManager:state(force)
    local state = Framework.runtime:storage()

    ---@type ff2.tombstone.State
    state.tombstone_manager = (state.tombstone_manager and not force) and state.tombstone_manager or {
        tombstones = {},
        tombstone_count = 0,
    }

    return state.tombstone_manager
end

------------------------------------------------------------------------

---@param tombstone ff2.tombstone.Tombstone
local function add_tombstone(tombstone)
    local state = FrameworkTombstoneManager:state()
    local gps_key = assert(tools:createEntityKey(tombstone.position, tombstone.surface_index))
    state.tombstones[gps_key] = state.tombstones[gps_key] or {}
    state.tombstones[gps_key][tombstone.type] = state.tombstones[gps_key][tombstone.type] or {}

    if not state.tombstones[gps_key][tombstone.type][tombstone.name] then state.tombstone_count = state.tombstone_count + 1 end
    state.tombstones[gps_key][tombstone.type][tombstone.name] = tombstone
end

---@param tombstone_key ff2.tombstone.Tombstone|ff2.tombstone.TombstoneKey
---@return ff2.tombstone.Tombstone? tombstone
local function remove_tombstone(tombstone_key)
    assert(tombstone_key.name)

    local state = FrameworkTombstoneManager:state()
    local gps_key = assert(tools:createEntityKey(tombstone_key.position, tombstone_key.surface_index))
    local type_map = state.tombstones[gps_key]
    if not type_map then return nil end
    local name_map = type_map[tombstone_key.type]
    if not name_map then return nil end
    local tombstone = name_map[tombstone_key.name]

    if name_map[tombstone_key.name] then state.tombstone_count = state.tombstone_count - 1 end
    name_map[tombstone_key.name] = nil

    if table_size(name_map) == 0 then type_map[tombstone_key.type] = nil end
    if table_size(type_map) == 0 then state.tombstones[gps_key] = nil end

    return tombstone
end

---@param tombstone_key ff2.tombstone.Tombstone|ff2.tombstone.TombstoneKey
---@return ff2.tombstone.Tombstone? tombstone
---@return ff2.tombstone.Tombstone? tombstone
local function get_tombstone(tombstone_key)
    assert(tombstone_key.name)

    local state = FrameworkTombstoneManager:state()
    local gps_key = assert(tools:createEntityKey(tombstone_key.position, tombstone_key.surface_index))
    local type_map = state.tombstones[gps_key]
    if not type_map then return nil end
    local name_map = type_map[tombstone_key.type]
    if not name_map then return nil end
    return name_map[tombstone_key.name]
end

---@param entity LuaEntity?
function FrameworkTombstoneManager:createTombstoneFromEntity(entity)
    if not (entity and entity.valid) then return end

    local callback = self.callbacks[entity.name] or self.callbacks['*']
    if not callback then return end

    local entity_data = callback.create_tombstone(entity)
    if not entity_data then return end

    local tombstone = {
        name = entity.name,
        type = entity.type,
        position = entity.position,
        surface_index = entity.surface_index,
        data = entity_data,
        tick = game.tick
    }

    add_tombstone(tombstone)
end

---@param entity LuaEntity?
function FrameworkTombstoneManager:removeTombstoneForEntity(entity)
    if not (entity and entity.valid) then return end

    remove_tombstone {
        position = entity.position,
        surface_index = entity.surface_index,
        type = tools.getType(entity),
        name = tools.getName(entity),
    }
end

--- Retrieves a tombstone based on a blueprint entity and surface index.
---@param blueprint_entity BlueprintEntity
---@param surface_index number
function FrameworkTombstoneManager:retrieveTombstoneFromBlueprintEntity(blueprint_entity, surface_index)
    assert(blueprint_entity)

    local callback = self.callbacks[blueprint_entity.name] or self.callbacks['*']
    if not callback then return end

    local prototype = prototypes.entity[blueprint_entity.name]
    if not prototype then return end

    local tombstone = get_tombstone {
        position = blueprint_entity.position,
        surface_index = surface_index,
        name = blueprint_entity.name,
        type = prototype.type,
    }

    if not tombstone then return end

    local data = tombstone.data
    callback.apply_tombstone(data, blueprint_entity.position, surface_index, blueprint_entity.name)
end

--- Retrieves a tombstone created at the current tick from the same position
---
---@param tombstone_key ff2.tombstone.TombstoneKey
---@return ff2.tombstone.Tombstone? tombstone
function FrameworkTombstoneManager:retrieveLatestTombstoneByType(tombstone_key)
    local state = FrameworkTombstoneManager:state()
    local gps_key = assert(tools:createEntityKey(tombstone_key.position, tombstone_key.surface_index))
    local type_map = state.tombstones[gps_key]
    if not type_map then return nil end
    local name_map = type_map[tombstone_key.type]
    if not name_map then return nil end

    for _, tombstone in pairs(name_map) do
        if (tombstone.tick == 0) or (tombstone.tick == game.tick) then return tombstone end
    end

    return nil
end

--- Retrieves a tombstone based on an entity or ghost
---@param entity LuaEntity?
function FrameworkTombstoneManager:applyCallbackForEntity(entity)
    if not (entity and entity.valid) then return end

    local name = tools.getName(entity)

    local callback = self.callbacks[name] or self.callbacks['*']
    if not callback then return end

    local tombstone = get_tombstone {
        position = entity.position,
        surface_index = entity.surface_index,
        type = tools.getType(entity),
        name = name,
    }

    if not tombstone then return end

    callback.apply_tombstone(tombstone.data, entity.position, entity.surface_index, name)
end

------------------------------------------------------------------------
-- Processed undo/redo actions
------------------------------------------------------------------------

local function removed_entity_action(action)
    FrameworkTombstoneManager:retrieveTombstoneFromBlueprintEntity(action.target, action.surface_index)
end

FrameworkTombstoneManager.known_actions['removed-entity'] = removed_entity_action

------------------------------------------------------------------------
-- Event callbacks
------------------------------------------------------------------------

---@param event EventData.on_undo_applied | EventData.on_redo_applied
local function process_undo_redo_event(event)
    for _, action in pairs(event.actions) do
        local method = FrameworkTombstoneManager.known_actions[action.type]
        if method then method(action) end
    end
end

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function creation_events(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local tombstone = get_tombstone {
        position = entity.position,
        surface_index = entity.surface_index,
        type = tools.getType(entity),
        name = tools.getName(entity),
    }

    if not tombstone then return end

    -- mark for collection by the ticker
    tombstone.tick = 0
end

---@param event EventData.on_pre_player_mined_item | EventData.on_robot_pre_mined | EventData.on_space_platform_pre_mined | EventData.on_entity_died
local function deletion_events(event)
    FrameworkTombstoneManager:createTombstoneFromEntity(event.entity)
end

---@param event EventData.on_post_entity_died
local function died_event(event)
    FrameworkTombstoneManager:applyCallbackForEntity(event.ghost)
end

--------------------------------------------------------------------------------
-- Registration API
--------------------------------------------------------------------------------

---@param matcher_function framework.event_matcher.MatcherFunction
---@return framework.event_matcher.MatchEventFunction
local function create_event_ghost_matcher(matcher_function)
    return function(event, context)
        if not event then return false end
        -- move / clone events
        ---@diagnostic disable-next-line: undefined-field
        return matcher_function(event.ghost, context)
    end
end

--- Register a callback when an entity is replaced with a tombstone.
--- This must be called from an on_init / on_load callback because it registers
--- new events.
---
---@param names string|string[]
---@param callback ff2.tombstone.TombstoneCallback
function FrameworkTombstoneManager:registerCallback(names, callback)
    assert(names)
    if type(names) ~= 'table' then names = { names } end

    for _, name in pairs(names) do
        self.callbacks[name] = callback
    end

    local entity_filter = Matchers:matchEventEntityName(names)
    local ghost_filter = create_event_ghost_matcher(Matchers:createMatcherFunction(names, Matchers.GHOST_NAME_EXTRACTOR))

    Event.register(Matchers.CREATION_EVENTS, creation_events, entity_filter, nil, { framework = true })

    Event.register(Matchers.DELETION_EVENTS, deletion_events, entity_filter, nil, { framework = true })
    Event.register(defines.events.on_entity_died, deletion_events, entity_filter, nil, { framework = true })

    Event.register(defines.events.on_post_entity_died, died_event, ghost_filter, nil, { framework = true })
end

--------------------------------------------------------------------------------
-- ticker
--------------------------------------------------------------------------------

---@param context ff2.ticker.TickerContext
---@param values ff2.ticker.TickerContext
local function ticker_unit_of_work(context, values)
    local tombstone = values.name
    if not tombstone then return end

    if tombstone.tick < context.expiration then
        remove_tombstone(tombstone)
    end
end

local function tick()
    local ticker_info = Ticker.getTicker(TICKER_NAME)

    local state = FrameworkTombstoneManager:state()
    if state.tombstone_count == 0 then return end

    -- maximum of one tombstone per tick processed
    local tombstones_per_tick = math.min(TICK_INTERVAL, state.tombstone_count)

    local context = ticker_info.context or {}

    context.expiration = game.tick - LIFETIME_IN_TICKS
    context.state = state

    local iterator = Ticker.createWorkIterator {
        context = context,
        field_name = 'tombstone',
        iterable = state.tombstones,
        sub_iterator = Ticker.createWorkIterator {
            context = context,
            field_name = 'type',
            sub_iterator = Ticker.createWorkIterator {
                context = context,
                field_name = 'name',
            }
        },
    }

    while tombstones_per_tick > 0 do
        iterator.process(ticker_unit_of_work)

        tombstones_per_tick = tombstones_per_tick - 1
    end

    ticker_info.context = context
    ticker_info.last_tick = game.tick
end

--------------------------------------------------------------------------------
-- event registration
--------------------------------------------------------------------------------

local function register_events()
    Event.register(defines.events.on_undo_applied, process_undo_redo_event, nil, nil, { framework = true })
    Event.register(defines.events.on_redo_applied, process_undo_redo_event, nil, nil, { framework = true })

    Event.register(-TICK_INTERVAL, tick, nil, nil, { framework = true })
end

Event.on_init(register_events)
Event.on_load(register_events)

return FrameworkTombstoneManager
