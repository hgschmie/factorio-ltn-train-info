--------------------------------------------------------------------------------
-- event setup for the mod
--------------------------------------------------------------------------------

local Event = require('__stdlib__/stdlib/event/event')
local Is = require('__stdlib__/stdlib/utils/is')
local Player = require('__stdlib__/stdlib/event/player')

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

    local entity_ghost = Framework.ghost_manager:findMatchingGhost(entity)
    if entity_ghost then
        player_index = player_index or entity_ghost.player_index
    end

    local player = Player.get(player_index)

    This.lti:create(entity, player)
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

    local player = Player.get(player_index)

    This.lti:createTrainStop(entity, player)
end


---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_entity_died | EventData.script_raised_destroy
local function onTrainStopDeleted(event)
    local entity = event and event.entity
    if not entity then return end

    This.lti:deleteTrainStop(entity.unit_number)
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
Util.event_register(const.creation_events, onEntityCreated, lti_entity_filter)
Util.event_register(const.deletion_events, onEntityDeleted, lti_entity_filter)

local train_stop_filter = Util.create_event_entity_matcher('type', 'train-stop')
Util.event_register(const.deletion_events, onTrainStopDeleted, train_stop_filter)
Util.event_register(const.creation_events, onTrainStopCreated, train_stop_filter)

-- manage ghost building (robot building) Register all ghosts we are interested in
local lti_ghost_filter = Util.create_event_ghost_entity_name_matcher(const.lti_train_info)
Util.event_register(const.creation_events, Framework.ghost_manager.onGhostEntityCreated, lti_ghost_filter)
local lti_ghost_trainstop_filter = Util.create_event_ghost_entity_matcher('ghost_type', 'train-stop')
Util.event_register(const.creation_events, Framework.ghost_manager.onGhostEntityCreated, lti_ghost_trainstop_filter)


-- entity destroy
Event.register(defines.events.on_entity_destroyed, onEntityDestroyed)
