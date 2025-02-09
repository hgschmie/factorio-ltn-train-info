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

---@class lti_train_info.Lti
local Lti = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global data structures
function Lti:init()
    if not storage.lti_data then
        ---@type lti_train_info.Storage
        storage.lti_data = {
            VERSION = const.current_version,
            lti = {},
            count = 0,
            deliveries = {},
            stops = {},
        }
    end

    if not storage.last_stop then
        ---@type table<integer, integer>
        storage.last_stop = {}
    end
end

---@return lti_train_info.Config config
local function get_new_config()
    return {
        enabled = true,
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
function Lti:getDelivery(train_id)
    return storage.lti_data.deliveries[train_id]
end

---@param train_id integer
---@param delivery LTNDelivery
function Lti:addDelivery(train_id, delivery)
    if storage.lti_data.deliveries[train_id] then
        Framework.logger:logf('[BUG] Overwriting existing delivery for train %d', train_id)
    end

    storage.lti_data.deliveries[train_id] = delivery
end

---@param train_id integer
function Lti:clearDelivery(train_id)
    storage.lti_data.deliveries[train_id] = nil
end

------------------------------------------------------------------------

---@param stop_id integer
---@return table<integer, boolean> stops
function Lti:getStops(stop_id)
    storage.lti_data.stops[stop_id] = storage.lti_data.stops[stop_id] or {}
    return storage.lti_data.stops[stop_id]
end

---@param stop_id integer
function Lti:clearStopEntities(stop_id)
    storage.lti_data.stops[stop_id] = nil
end

---@param stop_id integer
---@param entity_id integer?
function Lti:addStopEntity(stop_id, entity_id)
    if not entity_id then return end

    local stops = self:getStops(stop_id)
    stops[entity_id] = true
end

---@param stop_id integer
---@param entity_id integer?
function Lti:removeStopEntity(stop_id, entity_id)
    if not entity_id then return end

    local stops = self:getStops(stop_id)
    stops[entity_id] = nil
end

------------------------------------------------------------------------

--- Returns data for all train info combinators.
---@return table<integer, lti_train_info.Data> entities
function Lti:allLtiData()
    return storage.lti_data.lti
end

--- Returns data for a given train info combinator.
---@param entity_id integer? main unit number (== entity id)
---@return lti_train_info.Data? entity
function Lti:getLtiData(entity_id)
    if not entity_id then return nil end
    return storage.lti_data.lti[entity_id]
end

--- Sets a train info combinator entity
---@param entity_id integer The unit_number of the combinator
---@param lti_data lti_train_info.Data?
function Lti:setLtiData(entity_id, lti_data)
    assert(lti_data)

    if (storage.lti_data.lti[entity_id]) then
        Framework.logger:logf('[BUG] Overwriting existing lti_data for unit %d', entity_id)
    end

    storage.lti_data.lti[entity_id] = lti_data
    storage.lti_data.count = storage.lti_data.count + 1
end

---@param entity_id integer The unit_number of the combinator
function Lti:clearLtiData(entity_id)
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
function Lti:setLastStop(train_id, station_id)
    assert(station_id)

    storage.last_stop[train_id] = station_id
end

---@param train_id integer
function Lti:clearLastStop(train_id)
    storage.last_stop[train_id] = nil
end

---@param train_id integer
---@return integer? station_id
function Lti:getLastStop(train_id)
    return storage.last_stop[train_id]
end

------------------------------------------------------------------------
-- move
------------------------------------------------------------------------

---@param main LuaEntity
function Lti:move(main)
    if not (main and main.valid) then return end

    local lti_data = self:getLtiData(main.unit_number)
    if not lti_data then return end

    self:updateStatus(main)
end

------------------------------------------------------------------------
-- create/destroy
------------------------------------------------------------------------

---@param main LuaEntity
---@param config lti_train_info.Config?
---@return lti_train_info.Data?
function Lti:create(main, config)
    if not Is.Valid(main) then return nil end

    local entity_id = main.unit_number --[[@as integer]]

    assert(self:getLtiData(entity_id) == nil, "[BUG] main entity '" .. entity_id .. "' has already an lti_data assigned!")

    local lti_data = {
        main = main,
        config = config or get_new_config(),
        stop_ids = {},
    }

    self:setLtiData(entity_id, lti_data)
    self:updateStatus(main)

    return lti_data
end

---@param entity_id integer
function Lti:destroy(entity_id)
    local lti_data = self:getLtiData(entity_id)
    if not lti_data then return end

    self:clearLtiData(entity_id)

    for _, stop_id in pairs(lti_data.stop_ids) do
        self:removeStopEntity(stop_id, entity_id)
    end
end

------------------------------------------------------------------------
-- manage related entities being created/destroyed
------------------------------------------------------------------------

---@param train_stop LuaEntity
function Lti:addTrainStop(train_stop)
    local pos = Position.new(train_stop.position)

    local entities = train_stop.surface.find_entities_filtered {
        area = pos:expand_to_area(const.lti_range + 0.5),
        force = train_stop.force,
        name = const.lti_train_info_name,
    }

    for _, entity in pairs(entities) do
        self:updateStatus(entity)
    end
end

---@param train_stop_id integer
function Lti:removeTrainStop(train_stop_id)
    local lti_data_ids = self:getStops(train_stop_id)
    if not lti_data_ids then return end

    for lti_data_id in pairs(lti_data_ids) do
        local lti_data = self:getLtiData(lti_data_id)
        if lti_data then
            for idx, stop_id in pairs(lti_data.stop_ids) do
                if train_stop_id == stop_id then
                    table.remove(lti_data.stop_ids, idx)
                    self:updateStatus(lti_data.main)
                end
            end
        end
    end

    self:clearStopEntities(train_stop_id)
end

------------------------------------------------------------------------
-- status control
------------------------------------------------------------------------

---@param entity LuaEntity
function Lti:updateStatus(entity)
    if not entity then return end

    local entity_id = entity.unit_number
    local lti_data = self:getLtiData(entity_id)
    if not lti_data then return end

    -- unregister existing stops
    for _, stop_id in pairs(lti_data.stop_ids) do
        self:removeStopEntity(stop_id, entity_id)
    end

    local pos = Position.new(lti_data.main.position)

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
                self:addStopEntity(train_stop.unit_number, entity_id)
            end
        end
    end

    lti_data.stop_ids = stop_ids

    self:updateDelivery(lti_data)
end

---@param cc_entity LuaEntity Must be a constant combinator
---@return LuaConstantCombinatorControlBehavior control with a guaranteed LogisticSection.
local function get_control_with_section(cc_entity)
    local control = cc_entity.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    assert(control)
    if control.sections_count < 1 then
        control.add_section()
    end
    return control
end

---@param name string signal name
---@param count integer?
---@return LogisticFilter
local function create_filter(name, count)
    return {
        value = {
            type = 'virtual',
            name = name,
            quality = 'normal',
        },
        min = count or 1
    }
end

---@param lti_data lti_train_info.Data
---@param current_delivery lti_train_info.Delivery?
---@return LogisticFilter[] signals
function Lti:updateDelivery(lti_data, current_delivery)
    ---@type LogisticFilter[]
    local filters = {}

    local lti_config = lti_data.config
    local control = get_control_with_section(lti_data.main)
    control.enabled = lti_config.enabled

    lti_data.current_delivery = current_delivery

    if current_delivery then
        -- figure out which delivery config is responsible for the current delivery
        local delivery_cfg = lti_config[current_delivery.delivery_type] --[[@as lti_train_info.DeliveryConfig ]]

        -- if not enabled, don't add any signals
        if delivery_cfg.enabled then
            -- add the shipping signals
            for type, quantity in pairs(current_delivery.shipment) do
                local fields = string.split(type, ',', false)
                assert(#fields > 1)
                -- default to 1
                local count = 1
                local item_prototype = prototypes.item[fields[2]]
                if delivery_cfg.signal_type == const.signal_type.stack_size and fields[1] == 'item' and item_prototype then
                    -- if using stack size and element is an item, use the item stack size (fluids don't have a stack size)
                    count = (quantity / item_prototype.stack_size) / lti_config.divide_by
                elseif delivery_cfg.signal_type == const.signal_type.quantity then
                    -- if quantity is desired, use the quantity
                    count = quantity / lti_config.divide_by -- don't refactor this, the "1" for virtual signals must not be divided
                end

                count = count * (delivery_cfg.negate and -1 or 1)

                if count ~= 0 then
                    table.insert(filters, {
                        value = {
                            type = fields[1],
                            name = fields[2],
                            quality = fields[3] or 'normal',
                        },
                        min = count,
                    })
                end
            end
        end

        -- add virtual signals
        if lti_config.virtual then
            -- deliver or provide
            table.insert(filters, create_filter(const.delivery_signals[current_delivery.delivery_type]))
            -- train id
            local train_id = current_delivery.train_id
            table.insert(filters, create_filter('signal-T', train_id))

            local station_id = self:getLastStop(train_id)
            if station_id then
                table.insert(filters, create_filter('signal-S', station_id))
            end

            if delivery_cfg.signal_type ~= const.signal_type.one then
                -- divisor
                table.insert(filters, create_filter('signal-D', lti_config.divide_by))
            end
        end
    end

    control.sections[1].filters = filters

    return filters
end

------------------------------------------------------------------------
-- event callbacks
------------------------------------------------------------------------

---@param event LTNDispatcherUpdatedEvent
function Lti:dispatcherUpdated(event)
    assert(event)

    if table_size(self:deliveries()) == 0 then
        -- load all deliveries
        for train_id, delivery in pairs(event.deliveries) do
            self:addDelivery(train_id, delivery)
        end
    else
        -- only load new deliveries
        for _, train_id in pairs(event.new_deliveries) do
            local delivery = event.deliveries[train_id]
            if delivery then
                self:addDelivery(train_id, delivery)
            end
        end
    end
end

---@param event LTNOnDeliveryCompleted
function Lti:deliveryCompleted(event)
    assert(event)

    self:clearDelivery(event.train_id)
end

---@param event LTNOnDeliveryFailed
function Lti:deliveryFailed(event)
    assert(event)

    self:clearDelivery(event.train_id)
end

---@param train LuaTrain
function Lti:trainArrived(train)
    local station_id = train.station.unit_number
    if not station_id then return end

    self:setLastStop(train.id, station_id)

    local entities = self:getStops(station_id)
    if not entities then return end

    local delivery = self:getDelivery(train.id)
    if not delivery then return end

    ---@type lti_train_info.Delivery
    local current_delivery = {
        delivery_type = (delivery.from_id == station_id) and const.delivery_type.provide or const.delivery_type.request,
        shipment = delivery.shipment,
        train_id = train.id,
    }

    for entity_id in pairs(entities) do
        local lti_data = self:getLtiData(entity_id)
        if lti_data then
            self:updateDelivery(lti_data, current_delivery)
        end
    end
end

---@param train LuaTrain
function Lti:trainDeparted(train)
    local station_id = self:getLastStop(train.id)
    if not station_id then return end

    -- consume the event
    self:clearLastStop(train.id)

    local entities = self:getStops(station_id)
    if not entities then return end

    for entity_id in pairs(entities) do
        local lti_data = self:getLtiData(entity_id)
        if lti_data then
            self:updateDelivery(lti_data, nil)
        end
    end
end

------------------------------------------------------------------------

return Lti
