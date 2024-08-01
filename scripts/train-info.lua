---@meta
------------------------------------------------------------------------
-- manage the train delivery state
------------------------------------------------------------------------

local Is = require('__stdlib__/stdlib/utils/is')
local Position = require('__stdlib__/stdlib/area/position')
local string = require('__stdlib__/stdlib/utils/string')

local table = require('__stdlib__/stdlib/utils/table')

local const = require('lib.constants')

---@class ModLti
local Lti = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global data structures
function Lti:init()
    if not global.lti_data then
        ---@type ModLtiData
        global.lti_data = {
            VERSION = const.current_version,
            lti = {},
            count = 0,
            deliveries = {},
            stops = {},
        }
    end

    if not global.last_stop then
        global.last_stop = {}
    end
end

---@return TrainInfoConfig config
function Lti:get_new_config()
    return {
        enabled = false,
        src = {
            enabled = true,
            signal_type = const.signal_type.quantity,
            negate = false,
        },
        dst = {
            enabled = true,
            signal_type = const.signal_type.quantity,
            negate = false,
        },
        virtual = false,
        divide_by = 1,
        stop_ids = {},
    }
end

------------------------------------------------------------------------
-- attribute getters/setters
------------------------------------------------------------------------

function Lti:deliveries()
    return global.lti_data.deliveries
end

function Lti:delivery(train_id)
    return global.lti_data.deliveries[train_id]
end

function Lti:set_delivery(train_id, delivery)
    if global.lti_data.deliveries[train_id] then
        Framework.logger:logf('[BUG] Overwriting existing delivery for train %d', train_id)
    end

    global.lti_data.deliveries[train_id] = delivery
end

function Lti:clear_delivery(train_id)
    global.lti_data.deliveries[train_id] = nil
end

------------------------------------------------------------------------

function Lti:add_stop_entity(stop_id, entity_id)
    local stops = global.lti_data.stops[stop_id] or {}
    stops[entity_id] = true
    global.lti_data.stops[stop_id] = stops
end

function Lti:remove_stop_entity(stop_id, entity_id)
    local stops = global.lti_data.stops[stop_id]
    if not stops then return end
    stops[entity_id] = nil
end

function Lti:stop_entities(stop_id)
    return global.lti_data.stops[stop_id]
end

function Lti:clear_stop_entities(stop_id)
    global.lti_data.stops[stop_id] = nil
end

------------------------------------------------------------------------

--- Returns data for all train info combinators.
---@return table<integer, TrainInfoData> entities
function Lti:entities()
    return global.lti_data.lti
end

--- Returns data for a given train info combinator.
---@param entity_id integer main unit number (== entity id)
---@return TrainInfoData? entity
function Lti:entity(entity_id)
    return global.lti_data.lti[entity_id]
end

--- Sets or clears a train info combinator entity
---@param entity_id integer The unit_number of the combinator
---@param lti_entity TrainInfoData?
function Lti:setEntity(entity_id, lti_entity)
    if (lti_entity and global.lti_data.lti[entity_id]) then
        Framework.logger:logf('[BUG] Overwriting existing lti_entity for unit %d', entity_id)
    end

    global.lti_data.lti[entity_id] = lti_entity
    global.lti_data.count = global.lti_data.count + ((lti_entity and 1) or -1)

    if global.lti_data.count < 0 then
        global.lti_data.count = table_size(global.lti_data.lti)
        Framework.logger:logf('Train Info count got negative (bug), size is now: %d', global.lti_data.count)
    end
end

function Lti:set_last_stop(train_id, station_id)
    global.last_stop[train_id] = station_id
end

function Lti:last_stop(train_id)
    return global.last_stop[train_id]
end

------------------------------------------------------------------------
-- create/destroy
------------------------------------------------------------------------

---@param main LuaEntity
---@param player LuaPlayer
---@return TrainInfoData?
function Lti:create(main, player)
    if not Is.Valid(main) then return nil end

    local entity_id = main.unit_number --[[@as integer]]

    assert(self:entity(entity_id) == nil, "[BUG] main entity '" .. entity_id .. "' has already an lti_entity assigned!")

    local lti_entity = {
        main = main,
        config = self:get_new_config(),
    }

    self:setEntity(entity_id, lti_entity)

    self:update_status(entity_id, player)
    return lti_entity
end

function Lti:destroy(entity_id)
    local lti_entity = self:entity(entity_id)
    if not lti_entity then return end

    self:setEntity(entity_id, nil)

    for _, stop_id in pairs(lti_entity.config.stop_ids) do
        self:remove_stop_entity(stop_id, entity_id)
    end
end

function Lti:createTrainStop(train_stop, player)
    local pos = Position.new(train_stop.position)

    local entities = player.surface.find_entities_filtered {
        area = pos:expand_to_area(const.lti_range + 0.5),
        force = player.force,
        name = const.lti_train_info,
    }

    for _, entity in pairs(entities) do
        self:update_status(entity.unit_number, player)
    end
end

function Lti:deleteTrainStop(train_stop_id)
    local lti_entity_ids = self:stop_entities(train_stop_id)
    if not lti_entity_ids then return end

    for lti_entity_id in pairs(lti_entity_ids) do
        local lti_entity = self:entity(lti_entity_id)
        if lti_entity then
            for idx, stop_id in pairs(lti_entity.config.stop_ids) do
                if train_stop_id == stop_id then
                    table.remove(lti_entity.config.stop_ids, idx)
                    self:update_status(lti_entity_id)
                end
            end
        end
    end

    self:clear_stop_entities(train_stop_id)
end

function Lti:update_status(entity_id, player)
    local lti_entity = self:entity(entity_id)
    if not lti_entity then return end

    if player then
        -- unregister existing stops
        for _, stop_id in pairs(lti_entity.config.stop_ids) do
            self:remove_stop_entity(stop_id, entity_id)
        end

        local pos = Position.new(lti_entity.main.position)

        local train_stops = player.surface.find_entities_filtered {
            area = pos:expand_to_area(const.lti_range),
            force = player.force,
            type = 'train-stop',
        }

        -- re-register newly found stops
        local stops = {}

        if table_size(train_stops) > 0 then
            for _, train_stop in pairs(train_stops) do
                if const.lti_train_stops[train_stop.name] then
                    table.insert(stops, train_stop.unit_number)
                    self:add_stop_entity(train_stop.unit_number, entity_id)
                end
            end
        end

        lti_entity.config.stop_ids = stops
    end

    lti_entity.config.enabled = (#lti_entity.config.stop_ids > 0) and true or false

    local control = lti_entity.main.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    control.enabled = lti_entity.config.enabled
end

------------------------------------------------------------------------
-- move
------------------------------------------------------------------------

function Lti:move(main, start_pos, player)
    if not Is.Valid(main) then return end

    local lti_entity = self:entity(main.unit_number)
    if not lti_entity then return end

    self:update_status(main.unit_number, player)
end

------------------------------------------------------------------------
-- event callbacks
------------------------------------------------------------------------

function Lti:dispatcher_updated(event)
    if table_size(self:deliveries()) == 0 then
        -- load all deliveries
        for train_id, delivery in pairs(event.deliveries) do
            self:set_delivery(train_id, delivery)
        end
    else
        -- only load new deliveries
        for _, train_id in pairs(event.new_deliveries) do
            self:set_delivery(train_id, event.deliveries[train_id])
        end
    end
end

function Lti:delivery_completed(event)
    self:clear_delivery(event.train_id)
end

function Lti:delivery_failed(event)
    self:clear_delivery(event.train_id)
end

function Lti:update_delivery(entities, shipment, train_id, delivery_type)
    for entity_id in pairs(entities) do
        local lti_entity = self:entity(entity_id)
        if lti_entity then
            local control = lti_entity.main.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
            if control then
                ---@type ConstantCombinatorParameters[]
                local signals = {}
                local idx = 1

                local lti_config = lti_entity.config
                control.enabled = lti_config.enabled

                if shipment then
                    -- figure out which delivery config is responsible for the current delivery
                    local delivery_cfg = (delivery_type == const.delivery_type.src) and lti_config.src or lti_config.dst --[[@as TrainInfoDeliveryConfig ]]

                    -- if not enabled, don't add any signals
                    if delivery_cfg.enabled then
                        -- add the shipping signals
                        for type, quantity in pairs(shipment) do
                            local fields = string.split(type, ',', false)
                            -- default to 1
                            local count = 1
                            if delivery_cfg.signal_type == const.signal_type.stack_size and fields[1] == 'item' and game.item_prototypes[fields[2]] then
                                -- if using stack size and element is an item, use the item stack size (fluids don't have a stack size)
                                count = quantity / game.item_prototypes[fields[2]].stack_size
                            elseif delivery_cfg.signal_type == const.signal_type.quantity then
                                -- if quantity is desired, use the quantity
                                count = quantity
                            end

                            count = count / lti_config.divide_by
                            count = count * (delivery_cfg.negate and -1 or 1)

                            table.insert(signals, {
                                signal = {
                                    type = fields[1],
                                    name = fields[2]
                                },
                                count = count,
                                index = idx
                            })
                            idx = idx + 1
                        end

                        -- add virtual signals
                        if lti_config.virtual then
                            local signal_name = (delivery_type == 1) and 'signal-S' or 'signal-D'

                            table.insert(signals, { signal = { type = 'virtual', name = signal_name }, count = 1, index = idx })
                            if train_id then
                                table.insert(signals, { signal = { type = 'virtual', name = 'signal-T' }, count = train_id, index = idx + 1 })
                            end
                        end
                    end
                end

                control.parameters = signals
            end
        end
    end
end

function Lti:train_arrived(train)
    local station_id = train.station.unit_number
    self:set_last_stop(train.id, station_id)

    local entities = self:stop_entities(station_id)
    if not entities then return end

    local delivery = self:delivery(train.id)
    if not delivery then return end

    local delivery_type = (delivery.from_id == station_id) and const.delivery_type.src or const.delivery_type.dst
    self:update_delivery(entities, delivery.shipment, train.id, delivery_type)
end

function Lti:train_departed(train)
    local station_id = self:last_stop(train.id)
    if not station_id then return end
    -- consume the event
    self:set_last_stop(train.id)

    local entities = self:stop_entities(station_id)
    if not entities then return end

    self:update_delivery(entities)
end

------------------------------------------------------------------------

return Lti
