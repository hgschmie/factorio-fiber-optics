---@meta
----------------------------------------------------------------------------------------------------
--- class definitions
----------------------------------------------------------------------------------------------------

---@class fo.Storage
---@field fo fo.FiberOptics[]
---@field fo_count integer
---@field iopins integer[]
---@field iopin_count integer
---@field attached_entities fo.AttachedEntity[]

---@class fo.FiberOptics
---@field main LuaEntity
---@field iopin LuaEntity[]
---@field internal table<string, LuaEntity>
---@field direction defines.direction
---@field reverse boolean
---@field h_flipped boolean
---@field v_flipped boolean

---@class fo.AttachedEntity
---@field entity LuaEntity
---@field tags Tags?
---@field tick integer
