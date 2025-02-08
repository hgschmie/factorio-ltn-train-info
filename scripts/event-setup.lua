--------------------------------------------------------------------------------
-- event setup for the mod
--------------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')
local table = require('stdlib.utils.table')

local Matchers = require('framework.matchers')

local const = require('lib.constants')

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function on_entity_created(event)
    local entity = event and event.entity
    if not entity then return end

    -- register entity for destruction
    script.register_on_object_destroyed(entity)

    local player_index = event.player_index
    local tags = event.tags

    local entity_ghost = Framework.ghost_manager:findGhostForEntity(entity)
    if entity_ghost then
        player_index = player_index or entity_ghost.player_index
        tags = tags or entity_ghost.tags
    end

    local config = tags and tags[const.config_tag_name]

    This.Lti:create(entity, config)
end

---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_space_platform_mined_entity | EventData.script_raised_destroy
local function on_entity_deleted(event)
    local entity = event and event.entity
    if not entity then return end

    This.Lti:destroy(entity.unit_number)
end

---@param event EventData.on_object_destroyed
local function on_entity_destroyed(event)
    This.Lti:destroy(event.useful_id)
end

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function on_train_stop_created(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end

    if not const.lti_train_stops[entity.name] then return end

    This.Lti:addTrainStop(entity)
end


---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_space_platform_mined_entity | EventData.script_raised_destroy
local function on_train_stop_deleted(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end

    This.Lti:removeTrainStop(entity.unit_number)
end

--------------------------------------------------------------------------------
-- Entity cloning
--------------------------------------------------------------------------------

---@param event EventData.on_entity_cloned
local function on_entity_cloned(event)
    if not (event and event.source and event.source.valid) then return end
    if not (event.destination and event.destination.valid) then return end

    local src_entity = This.Lti:getLtiData(event.source.unit_number)
    if not src_entity then return end

    This.Lti:create(event.destination, src_entity.config)
end

--------------------------------------------------------------------------------
-- Entity settings pasting
--------------------------------------------------------------------------------

---@param event EventData.on_entity_settings_pasted
local function on_entity_settings_pasted(event)
    if not (event and event.source and event.source.valid) then return end
    if not (event.destination and event.destination.valid) then return end

    local player = Player.get(event.player_index)
    if not (player and player.valid) then return end
    if not (player.force == event.source.force and player.force == event.destination.force) then return end

    local src_entity = This.Lti:getLtiData(event.source.unit_number)
    local dst_entity = This.Lti:getLtiData(event.destination.unit_number)

    if not (src_entity and dst_entity) then return end

    dst_entity.config = util.copy(src_entity.config)
    This.Lti:updateStatus(dst_entity.main)
end

--------------------------------------------------------------------------------
-- Configuration changes (runtime and startup)
--------------------------------------------------------------------------------

---@param changed ConfigurationChangedData?
local function on_configuration_changed(changed)
    This.Lti:init()

    for _, force in pairs(game.forces) do
        if force.technologies['logistic-train-network'].researched then
            force.recipes[const.lti_train_info_name].enabled = true
        end
    end
end

--------------------------------------------------------------------------------
-- serialize config (for blueprint and tombstone)
--------------------------------------------------------------------------------

---@param entity LuaEntity
---@return table<string, any>? data
local function serialize_config(entity)
    if not (entity and entity.valid) then return end

    local lti_data = This.Lti:getLtiData(entity.unit_number)
    if not lti_data then return end

    return lti_data.config
end

--------------------------------------------------------------------------------
-- Train code
--------------------------------------------------------------------------------

---@param event EventData.on_train_changed_state
local function on_train_changed_state(event)
    local train = event and event.train
    if not train then return end

    if train.state == defines.train_state.wait_station then
        if not (train.station and train.station.valid) then return end
        This.Lti:trainArrived(train)
    else
        This.Lti:trainDeparted(train)
    end
end


--------------------------------------------------------------------------------
-- Event registration
--------------------------------------------------------------------------------

local function register_events()
    local lti_entity_filter = Matchers:matchEventEntityName(const.lti_train_info_name)

    -- entity creation/deletion
    Event.register(Matchers.CREATION_EVENTS, on_entity_created, lti_entity_filter)
    Event.register(Matchers.DELETION_EVENTS, on_entity_deleted, lti_entity_filter)
    Framework.ghost_manager:registerForName(const.lti_train_info_name)

    -- Framework.ghost_manager.register_for_ghost_attributes('ghost_type', 'train-stop') -- WHY?

    -- Configuration changes (runtime and startup)
    Event.on_configuration_changed(on_configuration_changed)

    -- entity destroy
    Event.register(defines.events.on_object_destroyed, on_entity_destroyed)

    -- Manage blueprint configuration setting
    Framework.blueprint:registerCallback(const.lti_train_info_name, serialize_config)

    -- manage tombstones for undo/redo and dead entities
    Framework.tombstone:registerCallback(const.lti_train_info_name, {
        create_tombstone = serialize_config,
        apply_tombstone = Framework.ghost_manager.mapTombstoneToGhostTags,
    })

    -- Entity cloning
    Event.register(defines.events.on_entity_cloned, on_entity_cloned, lti_entity_filter)

    -- Entity settings pasting
    Event.register(defines.events.on_entity_settings_pasted, on_entity_settings_pasted, lti_entity_filter)

    -- train schedule
    Event.register(defines.events.on_train_changed_state, on_train_changed_state)

    local train_stop_filter = Matchers:matchEventEntity('type', 'train-stop')
    Event.register(Matchers.CREATION_EVENTS, on_train_stop_created, train_stop_filter)
    Event.register(Matchers.DELETION_EVENTS, on_train_stop_deleted, train_stop_filter)
end

--------------------------------------------------------------------------------
-- Event registration
--------------------------------------------------------------------------------

local function on_init()
    --     This.Lti:init()
    register_events()
end

local function on_load()
    register_events()
end

-- setup player management
Player.register_events(true)

Event.on_init(on_init)
Event.on_load(on_load)
