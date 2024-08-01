--------------------------------------------------------------------------------
-- Logistics Train network
--------------------------------------------------------------------------------

local const = require('lib.constants')

local LogisticsTrainNetwork = {}
--------------------------------------------------------------------------------

local function lti_dispatcher_updated(event)
    This.lti:dispatcher_updated(event)
end

local function lti_delivery_completed(event)
    This.lti:delivery_completed(event)
end

local function lti_delivery_failed(event)
    This.lti:delivery_failed(event)
end


LogisticsTrainNetwork.runtime = function()
    local Event = require('__stdlib__/stdlib/event/event')

    local ltn_init = function()
        if not remote.interfaces['logistic-train-network'] then return end

        assert(remote.interfaces['logistic-train-network']['on_dispatcher_updated'], 'LTN present but no on_dispatcher_updated event')
        assert(remote.interfaces['logistic-train-network']['on_delivery_completed'], 'LTN present but no on_delivery_completed event')
        assert(remote.interfaces['logistic-train-network']['on_delivery_failed'], 'LTN present but no on_delivery_failed event')

        Event.on_event(remote.call('logistic-train-network', 'on_dispatcher_updated'), lti_dispatcher_updated)
        Event.on_event(remote.call('logistic-train-network', 'on_delivery_completed'), lti_delivery_completed)
        Event.on_event(remote.call('logistic-train-network', 'on_delivery_failed'), lti_delivery_failed)
    end

    Event.on_init(ltn_init)
    Event.on_load(ltn_init)
end


return LogisticsTrainNetwork
