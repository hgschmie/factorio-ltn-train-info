---@meta
----------------------------------------------------------------------------------------------------
--- class definitions
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
--- lib/this
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
--- scripts/train-info
----------------------------------------------------------------------------------------------------

---@class lti_train_info.Storage
---@field VERSION integer
---@field count integer
---@field deliveries table<integer, LTNDelivery>
---@field lti table<integer, lti_train_info.Data>
---@field stops table<integer, table<integer, boolean>>

---@class lti_train_info.Data
---@field main LuaEntity
---@field config lti_train_info.Config
---@field stop_ids integer[]
---@field current_delivery lti_train_info.Delivery?

---@class lti_train_info.Delivery
---@field delivery_type lti_train_info.DeliveryType
---@field shipment LTNShipment
---@field train_id integer

---@class lti_train_info.DeliveryConfig
---@field enabled boolean
---@field signal_type lti_train_info.SignalType
---@field negate boolean

---@class lti_train_info.Config
---@field enabled boolean
---@field provide lti_train_info.DeliveryConfig
---@field request lti_train_info.DeliveryConfig
---@field virtual boolean
---@field divide_by integer
---@field modified boolean?

----------------------------------------------------------------------------------------------------
--- LTN Stuff
----------------------------------------------------------------------------------------------------

---@class LTNSurfaceConnection
---@field entity1 LuaEntity
---@field entity2 LuaEntity
---@field network_id integer

---@alias LTNShipment table<string, integer>

---@class LTNDelivery
---@field force LuaForce
---@field train LuaTrain
---@field from string
---@field from_id integer
---@field to string
---@field to_id integer
---@field network_id integer
---@field started integer
---@field surface_connections LTNSurfaceConnection[]
---@field shipment LTNShipment

---@class LTNTrain
---@field capacity integer,
---@field fluid_capacity integer,
---@field force LuaForce,
---@field surface LuaSurface,
---@field depot_priority integer,
---@field network_id integer,
---@field train LuaTrain

---@class LTNDispatcherUpdatedEvent
---@field update_interval integer time in ticks LTN needed to run all updates, varies depending on number of stops and requests
---@field provided_by_stop table<integer, LTNShipment>
---@field requests_by_stop table<integer, LTNShipment>
---@field new_deliveries integer[]
---@field deliveries table<integer, LTNDelivery>
---@field available_trains table<integer, LTNTrain>

---@class LTNOnDeliveryCompleted
---@field train_id integer,
---@field train LuaTrain,
---@field shipment LTNShipment

---@class LTNOnDeliveryFailed
---@field train_id integer,
---@field shipment LTNShipment
