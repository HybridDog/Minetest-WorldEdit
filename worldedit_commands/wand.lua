local function above_or_under(player, pointed_thing)
	if player:get_player_control().sneak then
		return pointed_thing.above
	else
		return pointed_thing.under
	end
end

minetest.register_tool(":worldedit:wand", {
	description = "WorldEdit Wand tool, Left-click to set 1st position, "
		.. "right-click to set 2nd",
	inventory_image = "worldedit_wand.png",
	liquids_pointable = true,

	on_use = function(itemstack, player, pointed_thing)
		if player and pointed_thing and pointed_thing.type == "node" then
			local name = player:get_player_name()
			worldedit.pos1[name] = above_or_under(player, pointed_thing)
			worldedit.mark_pos1(name)
		end
	end,

	on_place = function(itemstack, player, pointed_thing)
		if player and pointed_thing and pointed_thing.type == "node" then
			local name = player:get_player_name()
			worldedit.pos2[name] = above_or_under(player, pointed_thing)
			worldedit.mark_pos2(name)
		end
	end,
})
