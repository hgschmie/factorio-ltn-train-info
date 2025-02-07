---@meta
------------------------------------------------------------------------
-- manage the train delivery state
------------------------------------------------------------------------
assert(script)

local Is = require('stdlib.utils.is')
local Position = require('stdlib.area.position')
local string = require('stdlib.utils.string')

local table = require('stdlib.utils.table')

local const = require('lib.constants')

---@class ModLti
local Lti = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global data structures
function Lti:init()
    if not storage.lti_data then
        ---@type ModLtiData
        storage.lti_data = {
            VERSION = const.current_version,
            lti = {},
            count = 0,
            deliveries = {},
            stops = {},
        }
    end

    if not storage.last_stop then
        storage.last_stop = {}
    end
end

---@return TrainInfoConfig config
function Lti:get_new_config()
    return {
        enabled = false,
        provide = {
            enabled = true,
            signal_type = const.signal_type.quantity,
            negate = false,
        },
        request = {
            enabled = true,
            signal_type = const.signal_type.quantity,
            negate = false,
        },
        virtual = false,
        divide_by = 1,
    }
end

------------------------------------------------------------------------
-- attribute getters/setters
------------------------------------------------------------------------

---@return LTNDelivery[] deliveries
function Lti:deliveries()
    return storage.lti_data.deliveries
end

---@param train_id integer
---@return LTNDelivery?
function Lti:delivery(train_id)
    return storage.lti_data.deliveries[train_id]
end

---@param train_id integer
---@param delivery LTNDelivery
function Lti:set_delivery(train_id, delivery)
    if storage.lti_data.deliveries[train_id] then
        Framework.logger:logf('[BUG] Overwriting existing delivery for train %d', train_id)
    end

    storage.lti_data.deliveries[train_id] = delivery
end

---@param train_id integer
function Lti:clear_delivery(train_id)
    storage.lti_data.deliveries[train_id] = nil
end

------------------------------------------------------------------------

---@param stop_id integer
---@param entity_id integer?
function Lti:add_stop_entity(stop_id, entity_id)
    if not entity_id then return end

    local stops = storage.lti_data.stops[stop_id] or {}
    stops[entity_id] = true
    storage.lti_data.stops[stop_id] = stops
end

---@param stop_id integer
---@param entity_id integer?
function Lti:remove_stop_entity(stop_id, entity_id)
    if not entity_id then return end

    local stops = storage.lti_data.stops[stop_id]
    if not stops then return end
    stops[entity_id] = nil
end

---@param stop_id integer
---@return integer[] entity_ids
function Lti:stop_entities(stop_id)
    local stops = storage.lti_data.stops[stop_id] or {}
    return stops
end

---@param stop_id integer
function Lti:clear_stop_entities(stop_id)
    storage.lti_data.stops[stop_id] = nil
end

------------------------------------------------------------------------

--- Returns data for all train info combinators.
---@return table<integer, TrainInfoData> entities
function Lti:entities()
    return storage.lti_data.lti
end

--- Returns data for a given train info combinator.
---@param entity_id integer? main unit number (== entity id)
---@return TrainInfoData? entity
function Lti:entity(entity_id)
    if not entity_id then return nil end
    return storage.lti_data.lti[entity_id]
end

--- Sets a train info combinator entity
---@param entity_id integer The unit_number of the combinator
---@param lti_entity TrainInfoData?
function Lti:set_entity(entity_id, lti_entity)
    assert(lti_entity)

    if (storage.lti_data.lti[entity_id]) then
        Framework.logger:logf('[BUG] Overwriting existing lti_entity for unit %d', entity_id)
    end

    storage.lti_data.lti[entity_id] = lti_entity
    storage.lti_data.count = storage.lti_data.count + 1
end

---@param entity_id integer The unit_number of the combinator
function Lti:clear_entity(entity_id)
    storage.lti_data.lti[entity_id] = nil
    storage.lti_data.count = storage.lti_data.count - 1
    if storage.lti_data.count < 0 then
        storage.lti_data.count = table_size(storage.lti_data.lti)
        Framework.logger:logf('Train Info count got negative (bug), size is now: %d', storage.lti_data.count)
    end
end

------------------------------------------------------------------------

---@param train_id integer
---@param station_id integer
function Lti:set_last_stop(train_id, station_id)
    assert(station_id)

    storage.last_stop[train_id] = station_id
end

---@param train_id integer
function Lti:clear_last_stop(train_id)
    storage.last_stop[train_id] = nil
end

---@param train_id integer
---@return integer? station_id
function Lti:last_stop(train_id)
    return storage.last_stop[train_id]
end

------------------------------------------------------------------------
-- move
------------------------------------------------------------------------

---@param main LuaEntity
function Lti:move(main)
    if not Is.Valid(main) then return end

    local lti_entity = self:entity(main.unit_number)
    if not lti_entity then return end

    self:update_status(main)
end

------------------------------------------------------------------------
-- create/destroy
------------------------------------------------------------------------

---@param main LuaEntity
---@param tags table<string, any>
---@return TrainInfoData?
function Lti:create(main, tags)
    if not Is.Valid(main) then return nil end

    local entity_id = main.unit_number --[[@as integer]]

    assert(self:entity(entity_id) == nil, "[BUG] main entity '" .. entity_id .. "' has already an lti_entity assigned!")

    local lti_entity = {
        main = main,
        config = tags and tags['lti_config'] or self:get_new_config(),
        stop_ids = {},
    }

    self:set_entity(entity_id, lti_entity)

    self:update_status(main)

    return lti_entity
end

---@param entity_id integer
function Lti:destroy(entity_id)
    local lti_entity = self:entity(entity_id)
    if not lti_entity then return end

    self:clear_entity(entity_id)

    for _, stop_id in pairs(lti_entity.stop_ids) do
        self:remove_stop_entity(stop_id, entity_id)
    end
end

------------------------------------------------------------------------
-- manage related entities being created/destroyed
------------------------------------------------------------------------

---@param train_stop LuaEntity
function Lti:createTrainStop(train_stop)
    local pos = Position.new(train_stop.position)

    local entities = train_stop.surface.find_entities_filtered {
        area = pos:expand_to_area(const.lti_range + 0.5),
        force = train_stop.force,
        name = const.lti_train_info,
    }

    for _, entity in pairs(entities) do
        self:update_status(entity)
    end
end

---@param train_stop_id integer
function Lti:deleteTrainStop(train_stop_id)
    local lti_entity_ids = self:stop_entities(train_stop_id)
    if not lti_entity_ids then return end

    for lti_entity_id in pairs(lti_entity_ids) do
        local lti_entity = self:entity(lti_entity_id)
        if lti_entity then
            for idx, stop_id in pairs(lti_entity.stop_ids) do
                if train_stop_id == stop_id then
                    table.remove(lti_entity.stop_ids, idx)
                    self:update_status(lti_entity.main)
                end
            end
        end
    end

    self:clear_stop_entities(train_stop_id)
end

--------------------------------------------------------------------------------
-- Blueprint
--------------------------------------------------------------------------------

---@param blueprint LuaItemStack
---@param idx integer
---@param entity LuaEntity
function Lti.blueprint_callback(blueprint, idx, entity)
    if not Is.Valid(entity) then return end

    local lti_entity = This.Lti:entity(entity.unit_number)
    if not lti_entity then return end

    blueprint.set_blueprint_entity_tag(idx, 'lti_config', lti_entity.config)
end

------------------------------------------------------------------------
-- status control
------------------------------------------------------------------------

---@param entity LuaEntity
function Lti:update_status(entity)
    if not entity then return end

    local entity_id = entity.unit_number
    local lti_entity = self:entity(entity_id)
    if not lti_entity then return end

    -- unregister existing stops
    for _, stop_id in pairs(lti_entity.stop_ids) do
        self:remove_stop_entity(stop_id, entity_id)
    end

    local pos = Position.new(lti_entity.main.position)

    local train_stops = entity.surface.find_entities_filtered {
        area = pos:expand_to_area(const.lti_range),
        force = entity.force,
        type = 'train-stop',
    }

    -- re-register newly found stops
    local stop_ids = {}

    if table_size(train_stops) > 0 then
        for _, train_stop in pairs(train_stops) do
            if const.lti_train_stops[train_stop.name] then
                table.insert(stop_ids, train_stop.unit_number)
                self:add_stop_entity(train_stop.unit_number, entity_id)
            end
        end
    end

    lti_entity.stop_ids = stop_ids

    lti_entity.config.enabled = (#lti_entity.stop_ids > 0) and true or false
    lti_entity.config.modified = true

    self:update_delivery(lti_entity)
end

---@param lti_entity TrainInfoData
---@return ConstantCombinatorParameters[] signals
function Lti:update_delivery(lti_entity)
    ---@type ConstantCombinatorParameters[]
    local signals = {}
    local idx = 1

    local lti_config = lti_entity.config
    local control = lti_entity.main.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    if control then
        local lti_delivery = lti_entity.current_delivery
        control.enabled = lti_config.enabled

        if lti_delivery then
            -- figure out which delivery config is responsible for the current delivery
            local delivery_cfg = lti_config[lti_delivery.delivery_type] --[[@as TrainInfoDeliveryConfig ]]

            -- if not enabled, don't add any signals
            if delivery_cfg.enabled then
                -- add the shipping signals
                for type, quantity in pairs(lti_delivery.shipment) do
                    local fields = string.split(type, ',', false)
                    -- default to 1
                    local count = 1
                    if delivery_cfg.signal_type == const.signal_type.stack_size and fields[1] == 'item' and game.item_prototypes[fields[2]] then
                        -- if using stack size and element is an item, use the item stack size (fluids don't have a stack size)
                        count = (quantity / game.item_prototypes[fields[2]].stack_size) / lti_config.divide_by
                    elseif delivery_cfg.signal_type == const.signal_type.quantity then
                        -- if quantity is desired, use the quantity
                        count = quantity / lti_config.divide_by -- don't refactor this, the "1" for virtual signals must not be divided
                    end

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
                    local signal_name = const.delivery_signals[lti_delivery.delivery_type]

                    table.insert(signals, { signal = { type = 'virtual', name = signal_name }, count = 1, index = idx })
                    idx = idx + 1

                    table.insert(signals, { signal = { type = 'virtual', name = 'signal-T' }, count = lti_delivery.train_id, index = idx })
                    idx = idx + 1

                    if delivery_cfg.signal_type ~= const.signal_type.one then
                        table.insert(signals, { signal = { type = 'virtual', name = 'signal-D' }, count = lti_config.divide_by, index = idx })
                        idx = idx + 1
                    end
                end
            end
        end

        control.parameters = signals
    end

    lti_config.modified = true
    return signals
end

------------------------------------------------------------------------
-- event callbacks
------------------------------------------------------------------------

---@param event LTNDispatcherUpdatedEvent
function Lti:dispatcher_updated(event)
    if table_size(self:deliveries()) == 0 then
        -- load all deliveries
        for train_id, delivery in pairs(event.deliveries) do
            self:set_delivery(train_id, delivery)
        end
    else
        -- only load new deliveries
        for _, train_id in pairs(event.new_deliveries) do
            local delivery = event.deliveries[train_id]
            if delivery then
                self:set_delivery(train_id, delivery)
            end
        end
    end
end

---@param event LTNOnDeliveryCompleted
function Lti:delivery_completed(event)
    self:clear_delivery(event.train_id)
end

---@param event LTNOnDeliveryFailed
function Lti:delivery_failed(event)
    self:clear_delivery(event.train_id)
end

---@param train LuaTrain
function Lti:train_arrived(train)
    local station_id = train.station.unit_number
    if not station_id then return end

    self:set_last_stop(train.id, station_id)

    local entities = self:stop_entities(station_id)
    if not entities then return end

    local delivery = self:delivery(train.id)
    if not delivery then return end

    for entity_id in pairs(entities) do
        local lti_entity = self:entity(entity_id)
        if lti_entity then
            ---@type TrainInfoDelivery
            lti_entity.current_delivery = {
                delivery_type = (delivery.from_id == station_id) and const.delivery_type.provide or const.delivery_type.request,
                shipment = delivery.shipment,
                train_id = train.id,
            }

            self:update_delivery(lti_entity)
        end
    end
end

---@param train LuaTrain
function Lti:train_departed(train)
    local station_id = self:last_stop(train.id)
    if not station_id then return end
    -- consume the event
    self:clear_last_stop(train.id)

    local entities = self:stop_entities(station_id)
    if not entities then return end

    for entity_id in pairs(entities) do
        local lti_entity = self:entity(entity_id)
        if lti_entity then
            lti_entity.current_delivery = nil
            self:update_delivery(lti_entity)
        end
    end
end

------------------------------------------------------------------------

return Lti
