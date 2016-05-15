--- Common functions [INTERNAL].  All of these functions are internal!
-- @module worldedit.common

--- Copies and modifies positions `pos1` and `pos2` so that each component of
-- `pos1` is less than or equal to the corresponding component of `pos2`.
-- Returns the new positions.
function worldedit.sort_pos(pos1, pos2)
	pos1 = {x=pos1.x, y=pos1.y, z=pos1.z}
	pos2 = {x=pos2.x, y=pos2.y, z=pos2.z}
	if pos1.x > pos2.x then
		pos2.x, pos1.x = pos1.x, pos2.x
	end
	if pos1.y > pos2.y then
		pos2.y, pos1.y = pos1.y, pos2.y
	end
	if pos1.z > pos2.z then
		pos2.z, pos1.z = pos1.z, pos2.z
	end
	return pos1, pos2
end


--- Determines the volume of the region defined by positions `pos1` and `pos2`.
-- @return The volume.
function worldedit.volume(pos1, pos2)
	local pos1, pos2 = worldedit.sort_pos(pos1, pos2)
	return (pos2.x - pos1.x + 1) *
		(pos2.y - pos1.y + 1) *
		(pos2.z - pos1.z + 1)
end


--- Gets other axes given an axis.
-- @raise Axis must be x, y, or z!
function worldedit.get_axis_others(axis)
	if axis == "x" then
		return "y", "z"
	elseif axis == "y" then
		return "x", "z"
	elseif axis == "z" then
		return "x", "y"
	else
		error("Axis must be x, y, or z!")
	end
end


function worldedit.keep_loaded(pos1, pos2)
	local manip = minetest.get_voxel_manip()
	manip:read_from_map(pos1, pos2)
end


local mh = {}
worldedit.manip_helpers = mh


--- Generates an empty VoxelManip data table for an area.
-- @return The empty data table.
function mh.get_empty_data(area)
	-- Fill emerged area with ignore so that blocks in the area that are
	-- only partially modified aren't overwriten.
	local data = {}
	local c_ignore = minetest.get_content_id("ignore")
	for i = 1, worldedit.volume(area.MinEdge, area.MaxEdge) do
		data[i] = c_ignore
	end
	return data
end


local emin_c, emax_c
function mh.init(pos1, pos2)
	local manip = minetest.get_voxel_manip()
	emin_c, emax_c = manip:read_from_map(pos1, pos2)
	local area = VoxelArea:new({MinEdge=emin_c, MaxEdge=emax_c})
	return manip, area
end


function mh.init_radius(pos, radius)
	local pos1 = vector.subtract(pos, radius)
	local pos2 = vector.add(pos, radius)
	return mh.init(pos1, pos2)
end


function mh.init_axis_radius(base_pos, axis, radius)
	return mh.init_axis_radius_length(base_pos, axis, radius, radius)
end


function mh.init_axis_radius_length(base_pos, axis, radius, length)
	local other1, other2 = worldedit.get_axis_others(axis)
	local pos1 = {
		[axis]   = base_pos[axis],
		[other1] = base_pos[other1] - radius,
		[other2] = base_pos[other2] - radius
	}
	local pos2 = {
		[axis]   = base_pos[axis] + length,
		[other1] = base_pos[other1] + radius,
		[other2] = base_pos[other2] + radius
	}
	return mh.init(pos1, pos2)
end


local extend_chunkqueue
function mh.finish(manip, data)
	-- Update map
	manip:set_data(data)
	manip:write_to_map()
	extend_chunkqueue(emin_c, emax_c)
	--manip:update_map()
end


-- scheduled map updates instead of instant ones, depends on function_delayer and vector_extras

-- vm updates a single mapchunk
local function update_single_chunk(pos)
	if not minetest.get_node_or_nil(pos) then
		return -- don't update not active chunks
	end

	local manip = minetest.get_voxel_manip()
	local emin,emax = manip:read_from_map(pos, pos)--vector.add(pos, 15))

	manip:write_to_map()
	manip:update_map()
end

local set = vector.set_data_to_pos
local get = vector.get_data_from_pos
local remove = vector.remove_data_from_pos

local chunkqueue_working = false
local chunkqueue_list
local chunkqueue = {}
local function update_chunks()
	local n
	if not chunkqueue_list
	and next(chunkqueue) then
		local _
		chunkqueue_list,_,_,n = vector.get_data_pos_table(chunkqueue)
	end
	--[[if n then
		print("[tnt] updating "..n.." chunks in time")
	end--]]
	n = next(chunkqueue_list)
	if not n then
		--print("stopping chunkupdate")
		chunkqueue_working = false
		return
	end
	minetest.delay_function(16384, update_chunks)

	local z,y,x = unpack(chunkqueue_list[n])
	chunkqueue_list[n] = nil
	remove(chunkqueue, z,y,x)
	z = z*16
	y = y*16
	x = x*16
	update_single_chunk({x=x,y=y,z=z})
end

function extend_chunkqueue(emin, emax)
	for z = emin.z, emax.z, 16 do
		for y = emin.y, emax.y, 16 do
			for x = emin.x, emax.x, 16 do
				set(chunkqueue, z/16,y/16,x/16, true)
			end
		end
	end
	chunkqueue_list = nil
	if not chunkqueue_working then
		chunkqueue_working = true
		--print("start chunkupdate")
		minetest.delay_function(16384, update_chunks)
	end
end

mh.extend_chunk_update_queue = extend_chunkqueue
