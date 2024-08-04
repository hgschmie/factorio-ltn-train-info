--------------------------------------------------------------------------------
-- event setup for the mod
--------------------------------------------------------------------------------

local Event = require('__stdlib__/stdlib/event/event')
local Is = require('__stdlib__/stdlib/utils/is')
local Player = require('__stdlib__/stdlib/event/player')
local table = require('__stdlib__/stdlib/utils/table')

local Util = require('framework.util')

local const = require('lib.constants')

--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------
local function onInitLtnTrainInfo()
    This.lti:init()
end

local function onLoadLtnTrainInfo()
end

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function onEntityCreated(event)
    local entity = event and (event.created_entity or event.entity)

    -- register entity for destruction
    script.register_on_entity_destroyed(entity)

    local player_index = event.player_index
    local tags = event.tags

    local entity_ghost = Framework.ghost_manager:findMatchingGhost(entity)
    if entity_ghost then
        player_index = player_index or entity_ghost.player_index
        tags = tags or entity_ghost.tags
    end

    This.lti:create(entity, tags)
end

---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_entity_died | EventData.script_raised_destroy
local function onEntityDeleted(event)
    local entity = event and event.entity
    if not entity then return end

    This.lti:destroy(entity.unit_number)
end

---@param event EventData.on_entity_destroyed
local function onEntityDestroyed(event)
    -- or a main entity?
    local lti_entity = This.lti:entity(event.unit_number)
    if lti_entity then
        -- main entity destroyed
        This.lti:destroy(event.unit_number)
    end
end

--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function onTrainStopCreated(event)
    local entity = event and (event.created_entity or event.entity)

    if not const.lti_train_stops[entity.name] then return end

    local player_index = event.player_index
    local entity_ghost = Framework.ghost_manager:findMatchingGhost(entity)
    if entity_ghost then
        player_index = player_index or entity_ghost.player_index
    end

    This.lti:createTrainStop(entity)
end


---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_entity_died | EventData.script_raised_destroy
local function onTrainStopDeleted(event)
    local entity = event and event.entity
    if not entity then return end

    This.lti:deleteTrainStop(entity.unit_number)
end

--------------------------------------------------------------------------------
-- Entity cloning
--------------------------------------------------------------------------------

--- @param event EventData.on_entity_cloned
local function onEntityCloned(event)
    if not (Is.Valid(event.source) and Is.Valid(event.destination)) then return end

    local src_entity = This.lti:entity(event.source.unit_number)
    if not src_entity then return end

    local tags = { lti_config = src_entity.config } -- clone the config from the src to the destination

    This.lti:create(event.destination, tags)
end

--------------------------------------------------------------------------------
-- Entity settings pasting
--------------------------------------------------------------------------------

--- @param event EventData.on_entity_settings_pasted
local function onEntitySettingsPasted(event)
    local player = Player.get(event.player_index)

    if not (Is.Valid(player) and player.force == event.source.force and player.force == event.destination.force) then return end

    local src_entity = This.lti:entity(event.source.unit_number)
    local dst_entity = This.lti:entity(event.destination.unit_number)

    if not (src_entity and dst_entity) then return end

    dst_entity.config = table.deepcopy(src_entity.config)
    This.lti:update_status(src_entity.main)
end

--------------------------------------------------------------------------------
-- Configuration changes (runtime and startup)
--------------------------------------------------------------------------------

--- @param changed ConfigurationChangedData?
local function onConfigurationChanged(changed)
    This.lti:init()

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
        This.lti:train_arrived(train)
    else
        This.lti:train_departed(train)
    end
end


--------------------------------------------------------------------------------
-- Event registration
--------------------------------------------------------------------------------

-- mod init/load code
Event.on_init(onInitLtnTrainInfo)
Event.on_load(onLoadLtnTrainInfo)

-- Configuration changes (runtime and startup)
Event.on_configuration_changed(onConfigurationChanged)
Event.register(defines.events.on_runtime_mod_setting_changed, onConfigurationChanged)

-- train schedule
Event.register(defines.events.on_train_changed_state, onTrainChangedState)

-- entity creation/deletion
local lti_entity_filter = Util.create_event_entity_matcher('name', const.lti_train_info)
Util.event_register(Util.CREATION_EVENTS, onEntityCreated, lti_entity_filter)
Util.event_register(Util.DELETION_EVENTS, onEntityDeleted, lti_entity_filter)

local train_stop_filter = Util.create_event_entity_matcher('type', 'train-stop')
Util.event_register(Util.DELETION_EVENTS, onTrainStopDeleted, train_stop_filter)
Util.event_register(Util.CREATION_EVENTS, onTrainStopCreated, train_stop_filter)

-- manage ghost building (robot building) Register all ghosts we are interested in
Framework.ghost_manager.register_for_ghost_names(const.lti_train_info)
Framework.ghost_manager.register_for_ghost_attributes('ghost_type', 'train-stop')

-- Manage blueprint configuration setting
Framework.blueprint:register_callback(const.lti_train_info, This.lti.blueprint_callback)

-- entity destroy
Event.register(defines.events.on_entity_destroyed, onEntityDestroyed)

-- Entity settings pasting
Event.register(defines.events.on_entity_settings_pasted, onEntitySettingsPasted, lti_entity_filter)

-- Entity cloning
Event.register(defines.events.on_entity_cloned, onEntityCloned, lti_entity_filter)
