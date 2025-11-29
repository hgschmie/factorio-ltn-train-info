--------------------------------------------------------------------------------
-- Logistics Train network
--------------------------------------------------------------------------------

local LogisticsTrainNetwork = {}
--------------------------------------------------------------------------------

---@param event LTNDispatcherUpdatedEvent
local function lti_dispatcher_updated(event)
    This.Lti:dispatcherUpdated(event)
end

---@param event LTNOnDeliveryCompleted
local function lti_delivery_completed(event)
    This.Lti:deliveryCompleted(event)
end

---@param event LTNOnDeliveryFailed
local function lti_delivery_failed(event)
    This.Lti:deliveryFailed(event)
end

---@param event LTNOnDeliveryReassigned
local function lti_delivery_reassigned(event)
    This.Lti:deliveryReassigned(event)
end


LogisticsTrainNetwork.runtime = function()
    assert(script)

    local Event = require('stdlib.event.event')

    local ltn_init = function()
        if not remote.interfaces['logistic-train-network'] then return end

        assert(remote.interfaces['logistic-train-network']['on_dispatcher_updated'], 'LTN present but no on_dispatcher_updated event')
        assert(remote.interfaces['logistic-train-network']['on_delivery_completed'], 'LTN present but no on_delivery_completed event')
        assert(remote.interfaces['logistic-train-network']['on_delivery_failed'], 'LTN present but no on_delivery_failed event')
        assert(remote.interfaces['logistic-train-network']['on_delivery_reassigned'], 'LTN present but no on_delivery_failed event')

        Event.on_event(remote.call('logistic-train-network', 'on_dispatcher_updated'), lti_dispatcher_updated)
        Event.on_event(remote.call('logistic-train-network', 'on_delivery_completed'), lti_delivery_completed)
        Event.on_event(remote.call('logistic-train-network', 'on_delivery_failed'), lti_delivery_failed)
        Event.on_event(remote.call('logistic-train-network', 'on_delivery_reassigned'), lti_delivery_reassigned)
    end

    Event.on_init(ltn_init)
    Event.on_load(ltn_init)
end

return LogisticsTrainNetwork
