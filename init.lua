local editing = {}
local placing = {}

local F = core.formspec_escape

local stex = "custompainting_side.png"
local btex = "custompainting_back.png"
local ftex = "custompainting_front.png"
local frametex = "custompainting_frame.png"

local function update(self)
	local vs = self.visual_size
	self.selectionbox = {-vs.x/2, -vs.y/2, -0.025, vs.x/2, vs.y/2, 0.025, rotate = true}
	self.object:set_properties(self)
end

core.register_entity("custompainting:entity",{
	initial_properties = {
		visual = "cube",
		static_save = true,
		textures = {stex,stex,stex,stex,btex,ftex},
		visual_size = {x=1, y=1, z=0.05},
		physical = false,
		selectionbox = {-0.5, -0.5, -0.025, 0.5, 0.5, 0.025, rotate = true},
		pointable = true,
	},
	on_rightclick = function(self, clicker)
		if not clicker or not clicker:is_player() then return end
		local name = clicker:get_player_name()
		if core.is_protected(self.object:get_pos(), name) then return end
		editing[clicker] = self
		core.show_formspec(name, "custompainting:prompt", "size[6,2]" ..
			"field[0.3,0.5;6,1;texture;Texture;"..F(self.textures[6]:gsub(ftex.."%^?",""):gsub("%^"..frametex,""),"").."]" ..
			"field_close_on_enter[texture;false]" ..
			"field[0.3,1.6;1.5,1;width;Width;"..F(tostring(self.visual_size.x)).."]" ..
			"field_close_on_enter[width;false]" ..
			"field[1.7,1.6;1.5,1;height;Height;"..F(tostring(self.visual_size.y)).."]" ..
			"field_close_on_enter[height;false]" ..
			"checkbox[2.8,1.3;frame;Frame;"..(self.textures[6]:match(frametex) and "true" or "false").."]" ..
			"button[4,1.3;2,1;apply;Apply]")
	end,
	on_activate = function(self, staticdata)
		if not self.textures then
			self.textures = table.copy(self.initial_properties.textures)
		end
		if not self.visual_size then
			self.visual_size = table.copy(self.initial_properties.visual_size)
		end
		self.object:set_armor_groups({immortal=1})
		if staticdata then
			local data = core.deserialize(staticdata)
			if not data then return end
			if data.texture then
				self.textures = {stex,stex,stex,stex,btex,data.texture}
			end
			if data.vs then
				self.visual_size = data.vs
			end
			update(self)
		end
	end,
	get_staticdata = function(self)
		if self.textures and self.visual_size then
			return core.serialize({texture=self.textures[6], vs=self.visual_size})
		end
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
		if not puncher or not puncher:is_player() then return end
		local ctrl = puncher:get_player_control()
		if ctrl.sneak and not core.is_protected(self.object:get_pos(), puncher:get_player_name()) then
			local stack = ItemStack("custompainting:custompainting")
			local meta = stack:get_meta()
			meta:set_string("inventory_image", self.textures[6])
			meta:set_string("vss", vector.to_string(self.visual_size))
			local inv = puncher:get_inventory()
			inv:add_item("main", stack)
			self.object:remove()
		end
	end,
})

core.register_craftitem("custompainting:custompainting", {
	description = "Custom painting",
	inventory_image = btex,
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.above
		local name = placer:get_player_name()
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return
		end
		local meta = itemstack:get_meta()
		local texture = meta:get("inventory_image")
		local vss = meta:get("vss")
		local vs = vss and vector.from_string(vss) or vector.new(1,1,0.05)
		local obj = core.add_entity(pos, "custompainting:entity", core.serialize({texture=texture, vs=vs}))
		local pyaw = placer:get_look_horizontal()
		obj:set_yaw(pyaw)
		if texture or not core.check_player_privs(placer, {creative=true}) then
			itemstack:take_item()
		end
		local ppos = placer:get_pos()
		ppos.y = ppos.y + placer:get_properties().eye_height
		placing[placer] = {obj, vector.distance(ppos, pos)}
		core.chat_send_player(placer:get_player_name(), "Align the painting now. Click LMB when done.")
		return itemstack
	end
})

core.register_globalstep(function(dtime)
	for _,player in ipairs(core.get_connected_players()) do
		if placing[player] then
			local obj = placing[player][1]
			local dist = placing[player][2]
			local ppos = player:get_pos()
			ppos.y = ppos.y + player:get_properties().eye_height
			local pdir = player:get_look_dir()
			local pyaw = player:get_look_horizontal()
			local tpos = ppos + pdir*dist
			local name = player:get_player_name()
			if not core.is_protected(tpos, name) then
				obj:move_to(ppos + pdir*dist)
				obj:set_yaw(pyaw)
				if player:get_player_control().dig then
					placing[player] = nil
				end
			else
				core.record_protection_violation(pos, name)
				placing[player] = nil
			end
		end
	end

end)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "custompainting:prompt" or not editing[player] then return end
	if fields.quit then
		editing[player] = nil
		return
	end
	local self = editing[player]
	local frame = self.textures[6]:match(frametex)
	if fields.frame == "true" then
		frame = true
	elseif fields.frame == "false" then
		frame = false
	end
	if fields.texture then
		self.textures[6] = ftex.."^"..fields.texture..(frame and "^"..frametex or "")
	end
	local w = tonumber(fields.width)
	local h = tonumber(fields.height)
	if not (w and h) then
		core.chat_send_player(player:get_player_name(), "Invalid width/height value!")
		return
	end
	self.visual_size = {x = w, y = h, z = 0.05}
	update(self)
end)
