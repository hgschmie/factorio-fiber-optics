---@meta
----------------------------------------------------------------------------------------------------
--- class definitions
----------------------------------------------------------------------------------------------------

-- A surface network contains a number of fiber networks. Each fiber network is carried by a power network
---@alias fo.SurfaceNetwork fo.FiberNetwork[]

-- A fiber network contains a number of fiber strands. A single fiber connector can be connected to a single strand.
-- There is an unlimited number of fiber strands in a network
---@alias fo.FiberNetwork table<string, fo.FiberStrand>

-- A fiber strand contains a number of colors that are accessible through hubs.
-- Each hub is connected to a single pin on a fiber connector and carries a red and a green signal

---@class fo.FiberStrand
---@field endpoint_count integer
---@field endpoints LuaEntity[]
---@field hubs fo.FiberHub[]

---@class fo.FiberHub
---@field hub LuaEntity
---@field description fo.Description?

---@class fo.Storage
---@field fo fo.FiberOptics[]
---@field fo_count integer
---@field attached_entities fo.AttachedEntity[]
---@field iopins integer[]
---@field iopin_count integer
---@field surface_networks fo.SurfaceNetwork[]

---@class fo.FiberOptics
---@field main LuaEntity
---@field status defines.entity_status?
---@field iopin LuaEntity[]
---@field internal table<string, LuaEntity>
---@field networks table<integer, integer>
---@field direction defines.direction
---@field reverse boolean
---@field h_flipped boolean
---@field v_flipped boolean
---@field state fo.FiberOpticsState
---@field config fo.FiberOpticsConfig

---@class fo.FiberOpticsState
---@field strand_names table<integer, string>

---@class fo.FiberOpticsConfig
---@field enabled boolean
---@field strand_name string
---@field connected_pins table<defines.wire_connector_id, boolean[]>
---@field descriptions fo.Description[]

---@class fo.AttachedEntity
---@field entity LuaEntity
---@field tags Tags?
---@field tick integer

---@alias fo.DescType ('iopin'|'strand')

---@class fo.PlayerData
---@field h_flipped boolean?
---@field v_flipped boolean?
---@field gui_tab fo.DescType?

---@class fo.Description
---@field title string
---@field body string
