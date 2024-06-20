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
---@field oc ModOc
---@field network FiberNetworkManager
---@field blueprint FiberNetworkBlueprint
---@field attached_entities FiberNetworkAttachedEntities

----------------------------------------------------------------------------------------------------
--- scripts/attached_entities
----------------------------------------------------------------------------------------------------

---@class AttachedEntity
---@field entity LuaEntity
---@field name string?
---@field position MapPosition?
---@field orientation float?
---@field tags Tags?
---@field player_index integer
---@field tick integer

----------------------------------------------------------------------------------------------------
--- scripts/network
----------------------------------------------------------------------------------------------------

---@class GlobalFiberNetworks
---@field VERSION integer
---@field surface_networks table<integer, SurfaceFiberNetworks>
---@field total_count integer

---@class FiberNetwork
---@field endpoint_count integer
---@field endpoints table<integer, LuaEntity>
---@field connectors table<integer, LuaEntity>

----------------------------------------------------------------------------------------------------
--- scripts/oc
----------------------------------------------------------------------------------------------------

---@class OpticalConnectorData
---@field main LuaEntity
---@field entities LuaEntity[]
---@field status defines.entity_status?
---@field ref table<string, LuaEntity>
---@field connected_networks table<integer, integer>
---@field flip_index integer?
---@field iopin table<integer, LuaEntity>

---@class ModOcData
---@field oc OpticalConnectorData[]
---@field iopins table<integer, integer>
---@field count integer
---@field VERSION integer

---@class OcIopinPositionCfg
---@field main LuaEntity
---@field idx integer
---@field direction defines.direction?
---@field flip_index integer

---@class OcCreateInternalEntityCfg
---@field entity OpticalConnectorData
---@field name string
---@field dx integer?
---@field dy integer?
---@field pos MapPosition?
---@field ghost AttachedEntity?
---@field attached AttachedEntity?

---@class OcCreateCfg
---@field main LuaEntity
---@field tags Tags?
---@field player_index integer
---@field ghosts AttachedEntity[]
---@field attached AttachedEntity[]
---@field flip_index integer
