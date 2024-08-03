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
---@field current_delivery TrainInfoDelivery?

---@class TrainInfoDelivery
---@field delivery_type string
---@field shipment table<string, integer>
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
---@field stop_ids integer[]
---@field modified boolean?

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
---@field shipment table<string, integer>

---@class LTNSurfaceConnection
---@field entity1 LuaEntity
---@field entity2 LuaEntity
---@field network_id integer
