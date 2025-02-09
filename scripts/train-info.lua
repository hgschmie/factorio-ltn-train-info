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

---@class lti.Lti
local Lti = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global data structures
function Lti:init()
    if not storage.lti_data then
        ---@type lti.Storage
        storage.lti_data = {
            VERSION = const.current_version,
            lti = {},
            count = 0,
            deliveries = {},
            stop_to_ltis = {},
            train_to_last_stop = {},
        }
    end
end

---@return lti.Config config
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
---@return table<integer, LuaEntity> ltis
function Lti:getLtisForStop(stop_id)
    storage.lti_data.stop_to_ltis[stop_id] = storage.lti_data.stop_to_ltis[stop_id] or {}
    return storage.lti_data.stop_to_ltis[stop_id]
end

---@param stop_id integer
function Lti:clearLtisForStop(stop_id)
    storage.lti_data.stop_to_ltis[stop_id] = nil
end

---@param stop_id integer
---@param lti_entity LuaEntity?
function Lti:addLtiToStop(stop_id, lti_entity)
    if not (lti_entity and lti_entity.valid) then return end

    local ltis = self:getLtisForStop(stop_id)
    ltis[lti_entity.unit_number] = lti_entity
end

---@param stop_id integer
---@param lti_id integer?
function Lti:removeLtiFromStop(stop_id, lti_id)
    if not lti_id then return end

    if not storage.lti_data.stop_to_ltis[stop_id] then return end

    storage.lti_data.stop_to_ltis[stop_id][lti_id] = nil
end

------------------------------------------------------------------------

--- Returns data for all train info combinators.
---@return table<integer, lti.Data> entities
function Lti:allLtiData()
    return storage.lti_data.lti
end

--- Returns data for a given train info combinator.
---@param lti_id integer? main unit number (== entity id)
---@return lti.Data? entity
function Lti:getLtiData(lti_id)
    if not lti_id then return nil end
    return storage.lti_data.lti[lti_id]
end

--- Sets a train info combinator entity
---@param lti_id integer The unit_number of the combinator
---@param lti_data lti.Data?
function Lti:setLtiData(lti_id, lti_data)
    assert(lti_data)

    if (storage.lti_data.lti[lti_id]) then
        Framework.logger:logf('[BUG] Overwriting existing lti_data for unit %d', lti_id)
    end

    storage.lti_data.lti[lti_id] = lti_data
    storage.lti_data.count = storage.lti_data.count + 1
end

---@param lti_id integer The unit_number of the combinator
function Lti:clearLtiData(lti_id)
    storage.lti_data.lti[lti_id] = nil
    storage.lti_data.count = storage.lti_data.count - 1
    if storage.lti_data.count < 0 then
        storage.lti_data.count = table_size(storage.lti_data.lti)
        Framework.logger:logf('Train Info count got negative (bug), size is now: %d', storage.lti_data.count)
    end
end

------------------------------------------------------------------------

---@param train_id integer
---@param stop LuaEntity
function Lti:setLastStop(train_id, stop)
    assert(stop)
    storage.lti_data.train_to_last_stop[train_id] = stop
end

---@param train_id integer
function Lti:clearLastStop(train_id)
    storage.lti_data.train_to_last_stop[train_id] = nil
end

---@param train_id integer
---@return LuaEntity? stop
function Lti:getLastStop(train_id)
    local stop = storage.lti_data.train_to_last_stop[train_id]
    if stop and stop.valid then return stop end
    return nil
end

------------------------------------------------------------------------
-- move
------------------------------------------------------------------------

---@param main LuaEntity
function Lti:move(main)
    if not (main and main.valid) then return end

    local lti_data = self:getLtiData(main.unit_number)
    if not lti_data then return end

    self:scanForStops(lti_data)
end

------------------------------------------------------------------------
-- create/destroy
------------------------------------------------------------------------

---@param main LuaEntity
---@param config lti.Config?
---@return lti.Data?
function Lti:create(main, config)
    if not Is.Valid(main) then return nil end

    local lti_id = main.unit_number --[[@as integer]]

    assert(self:getLtiData(lti_id) == nil, "[BUG] main entity '" .. lti_id .. "' has already an lti_data assigned!")

    ---@type lti.Data
    local lti_data = {
        main = main,
        config = config or get_new_config(),
        stop_ids = {},
        connected_stops = {},
    }

    self:setLtiData(lti_id, lti_data)
    self:scanForStops(lti_data)
    self:updateLtiState(lti_data)

    return lti_data
end

---@param lti_id integer
function Lti:destroy(lti_id)
    local lti_data = self:getLtiData(lti_id)
    if not lti_data then return end

    self:clearLtiData(lti_id)

    for stop_id in pairs(lti_data.connected_stops) do
        self:removeLtiFromStop(stop_id, lti_id)
    end
end

------------------------------------------------------------------------
-- manage related entities being created/destroyed
------------------------------------------------------------------------

---@param train_stop LuaEntity
function Lti:addTrainStop(train_stop)
    local pos = Position.new(train_stop.position)

    local lti_entities = train_stop.surface.find_entities_filtered {
        area = pos:expand_to_area(const.lti_range + 0.5),
        force = train_stop.force,
        name = const.lti_name,
    }

    for _, lti_entity in pairs(lti_entities) do
        local lti_data = self:getLtiData(lti_entity.unit_number)
        if lti_data then
            self:scanForStops(lti_data)
        end
    end
end

---@param train_stop_id integer
function Lti:removeTrainStop(train_stop_id)
    local lti_entities = self:getLtisForStop(train_stop_id)

    for _, lti_entity in pairs(lti_entities) do
        local lti_data = self:getLtiData(lti_entity.unit_number)
        if lti_data then
            self:scanForStops(lti_data)
        end
    end

    self:clearLtisForStop(train_stop_id)
end

------------------------------------------------------------------------
-- status control
------------------------------------------------------------------------

---@param lti_data lti.Data
---@param ignore_stop_id number?
function Lti:scanForStops(lti_data, ignore_stop_id)
    if not (lti_data.main and lti_data.main.valid) then return end

    local lti_entity = lti_data.main
    local lti_id = lti_entity.unit_number
    local remove_list = table.keys(lti_data.connected_stops)
    for _, stop_id in pairs(remove_list) do
        self:removeLtiFromStop(stop_id, lti_id)
    end

    local pos = Position.new(lti_entity.position)

    local train_stops = lti_entity.surface.find_entities_filtered {
        area = pos:expand_to_area(const.lti_range),
        force = lti_entity.force,
        type = 'train-stop',
    }

    if not (train_stops and #train_stops > 0) then return end

    lti_data.connected_stops = {}
    for _, train_stop in pairs(train_stops) do
        if (train_stop.unit_number ~= ignore_stop_id) and const.lti_train_stops[train_stop.name] then
            lti_data.connected_stops[train_stop.unit_number] = train_stop
            self:addLtiToStop(train_stop.unit_number, lti_data.main)
        end
    end
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

---@param lti_data lti.Data
---@param current_delivery lti.Delivery?
---@return LogisticFilter[] signals
function Lti:updateLtiState(lti_data, current_delivery)
    ---@type LogisticFilter[]
    local filters = {}

    local lti_config = lti_data.config
    local control = get_control_with_section(lti_data.main)
    control.enabled = lti_config.enabled

    lti_data.current_delivery = current_delivery

    if current_delivery then
        -- figure out which delivery config is responsible for the current delivery
        local delivery_cfg = lti_config[current_delivery.delivery_type] --[[@as lti.DeliveryConfig ]]

        -- if not enabled, don't add any signals
        if delivery_cfg.enabled then
            -- add the shipping signals
            for type, quantity in pairs(current_delivery.shipment) do
                local fields = string.split(type, ',', false)
                assert(#fields > 1)
                -- default to 1
                local count = 1
                if delivery_cfg.signal_type == const.signal_type.stack_size then
                    local item_prototype = prototypes.item[fields[2]]
                    local stack_size = 1
                    -- if the  element is an item, use the item stack size (fluids don't have a stack size)
                    if fields[1] == 'item' and item_prototype then stack_size = item_prototype.stack_size end

                    count = (quantity / stack_size) / lti_config.divide_by
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

            local station = self:getLastStop(train_id)
            if station then table.insert(filters, create_filter('signal-S', station.unit_number)) end

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
    local stop = train.station
    if not (stop and stop.valid) then return end

    self:setLastStop(train.id, stop)

    local lti_entities = self:getLtisForStop(stop.unit_number)
    if table_size(lti_entities) == 0 then return end

    local delivery = self:getDelivery(train.id)
    if not delivery then return end

    ---@type lti.Delivery
    local current_delivery = {
        delivery_type = (delivery.from_id == stop.unit_number) and const.delivery_type.provide or const.delivery_type.request,
        shipment = delivery.shipment,
        train_id = train.id,
    }

    for lti_id in pairs(lti_entities) do
        local lti_data = self:getLtiData(lti_id)
        if lti_data then self:updateLtiState(lti_data, current_delivery) end
    end
end

---@param train LuaTrain
function Lti:trainDeparted(train)
    local stop = self:getLastStop(train.id)
    if not stop then return end

    -- consume the event
    self:clearLastStop(train.id)

    local lti_entities = self:getLtisForStop(stop.unit_number)

    for lti_id in pairs(lti_entities) do
        local lti_data = self:getLtiData(lti_id)
        if lti_data then self:updateLtiState(lti_data, nil) end
    end
end

------------------------------------------------------------------------

return Lti
