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

---@class lti.Storage
---@field VERSION integer
---@field count integer
---@field deliveries table<integer, LTNDelivery>
---@field lti table<integer, lti.Data>
---@field stop_to_ltis table<number, LuaEntity>
---@field train_to_last_stop table<integer, LuaEntity>


---@class lti.Data
---@field main LuaEntity
---@field config lti.Config
---@field connected_stops table<number, LuaEntity>
---@field current_delivery lti.Delivery?

---@class lti.Delivery
---@field delivery_type lti.DeliveryType
---@field shipment LTNShipment
---@field train_id integer

---@class lti.DeliveryConfig
---@field enabled boolean
---@field signal_type lti.SignalType
---@field negate boolean

---@class lti.Config
---@field enabled boolean
---@field provide lti.DeliveryConfig
---@field request lti.DeliveryConfig
---@field virtual boolean
---@field divide_by integer

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

---@class LTNOnDeliveryReassigned
---@field old_train_id integer
---@field new_train_id integer
---@field shipment LTNShipment
