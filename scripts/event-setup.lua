--------------------------------------------------------------------------------
-- event setup for the mod
--------------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Is = require('stdlib.utils.is')
local Player = require('stdlib.event.player')
local table = require('stdlib.utils.table')

local tools = require('framework.tools')

local const = require('lib.constants')

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function onEntityCreated(event)
    local entity = event and event.entity

    -- register entity for destruction
    script.register_on_object_destroyed(entity)

    local player_index = event.player_index
    local tags = event.tags

    local entity_ghost = Framework.ghost_manager:findMatchingGhost(entity)
    if entity_ghost then
        player_index = player_index or entity_ghost.player_index
        tags = tags or entity_ghost.tags
    end

    This.Lti:create(entity, tags)
end

---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_entity_died | EventData.script_raised_destroy
local function onEntityDeleted(event)
    local entity = event and event.entity
    if not entity then return end

    This.Lti:destroy(entity.unit_number)
end

---@param event EventData.on_object_destroyed
local function onEntityDestroyed(event)
    -- or a main entity?
    local lti_entity = This.Lti:entity(event.unit_number)
    if lti_entity then
        -- main entity destroyed
        This.Lti:destroy(event.unit_number)
    end
end

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function onTrainStopCreated(event)
    local entity = event and event.entity

    if not const.lti_train_stops[entity.name] then return end

    local player_index = event.player_index
    local entity_ghost = Framework.ghost_manager:findMatchingGhost(entity)
    if entity_ghost then
        player_index = player_index or entity_ghost.player_index
    end

    This.Lti:createTrainStop(entity)
end


---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_entity_died | EventData.script_raised_destroy
local function onTrainStopDeleted(event)
    local entity = event and event.entity
    if not entity then return end

    This.Lti:deleteTrainStop(entity.unit_number)
end

--------------------------------------------------------------------------------
-- Entity cloning
--------------------------------------------------------------------------------

---@param event EventData.on_entity_cloned
local function onEntityCloned(event)
    if not (Is.Valid(event.source) and Is.Valid(event.destination)) then return end

    local src_entity = This.Lti:entity(event.source.unit_number)
    if not src_entity then return end

    local tags = { lti_config = src_entity.config } -- clone the config from the src to the destination

    This.Lti:create(event.destination, tags)
end

--------------------------------------------------------------------------------
-- Entity settings pasting
--------------------------------------------------------------------------------

---@param event EventData.on_entity_settings_pasted
local function onEntitySettingsPasted(event)
    local player = Player.get(event.player_index)

    if not (Is.Valid(player) and player.force == event.source.force and player.force == event.destination.force) then return end

    local src_entity = This.Lti:entity(event.source.unit_number)
    local dst_entity = This.Lti:entity(event.destination.unit_number)

    if not (src_entity and dst_entity) then return end

    dst_entity.config = util.copy(src_entity.config)
    This.Lti:update_status(src_entity.main)
end

--------------------------------------------------------------------------------
-- Configuration changes (runtime and startup)
--------------------------------------------------------------------------------

---@param changed ConfigurationChangedData?
local function onConfigurationChanged(changed)
    This.Lti:init()

    for _, force in pairs(game.forces) do
        if force.technologies['logistic-train-network'].researched then
            force.recipes[const.lti_train_info].enabled = true
        end
    end
end

--------------------------------------------------------------------------------
-- Train code
--------------------------------------------------------------------------------

---@param event EventData.on_train_changed_state
local function onTrainChangedState(event)
    local train = event.train
    if train.state == defines.train_state.wait_station then
        if not Is.Valid(train.station) then return end
        This.Lti:train_arrived(train)
    else
        This.Lti:train_departed(train)
    end
end


--------------------------------------------------------------------------------
-- Event registration
--------------------------------------------------------------------------------

local function register_events()
    -- -- Configuration changes (runtime and startup)
    -- Event.on_configuration_changed(onConfigurationChanged)
    -- Event.register(defines.events.on_runtime_mod_setting_changed, onConfigurationChanged)

    -- -- train schedule
    -- Event.register(defines.events.on_train_changed_state, onTrainChangedState)

    -- -- entity creation/deletion
    -- local lti_entity_filter = tools.create_event_entity_matcher('name', const.lti_train_info)
    -- tools.event_register(tools.CREATION_EVENTS, onEntityCreated, lti_entity_filter)
    -- tools.event_register(tools.DELETION_EVENTS, onEntityDeleted, lti_entity_filter)

    -- local train_stop_filter = tools.create_event_entity_matcher('type', 'train-stop')
    -- tools.event_register(tools.DELETION_EVENTS, onTrainStopDeleted, train_stop_filter)
    -- tools.event_register(tools.CREATION_EVENTS, onTrainStopCreated, train_stop_filter)

    -- -- manage ghost building (robot building) Register all ghosts we are interested in
    -- Framework.ghost_manager.register_for_ghost_names(const.lti_train_info)
    -- Framework.ghost_manager.register_for_ghost_attributes('ghost_type', 'train-stop')

    -- -- Manage blueprint configuration setting
    -- Framework.blueprint:register_callback(const.lti_train_info, This.Lti.blueprint_callback)

    -- -- entity destroy
    -- Event.register(defines.events.on_object_destroyed, onEntityDestroyed)

    -- -- Entity settings pasting
    -- Event.register(defines.events.on_entity_settings_pasted, onEntitySettingsPasted, lti_entity_filter)

    -- -- Entity cloning
    -- Event.register(defines.events.on_entity_cloned, onEntityCloned, lti_entity_filter)
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
