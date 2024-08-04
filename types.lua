---@meta
----------------------------------------------------------------------------------------------------
--- class definitions
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
--- lib/this
----------------------------------------------------------------------------------------------------

---@class ModThis
---@field other_mods string[]
---@field debug_mode integer
---@field lti ModLti

----------------------------------------------------------------------------------------------------
--- scripts/train-info
----------------------------------------------------------------------------------------------------

---@class ModLtiData
---@field VERSION integer
---@field count integer
---@field deliveries table<integer, LTNDelivery>
---@field lti table<integer, TrainInfoData>
---@field stops table<integer, table<integer, boolean>>

---@class TrainInfoData
---@field main LuaEntity
---@field config TrainInfoConfig
---@field stop_ids integer[]
---@field current_delivery TrainInfoDelivery?

---@class TrainInfoDelivery
---@field delivery_type string
---@field shipment LTNShipment
---@field train_id integer

---@class TrainInfoDeliveryConfig
---@field enabled boolean
---@field signal_type integer
---@field negate boolean

---@class TrainInfoConfig
---@field enabled boolean
---@field provide TrainInfoDeliveryConfig
---@field request TrainInfoDeliveryConfig
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
