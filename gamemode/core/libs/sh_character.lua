nut.char = nut.char or {}
nut.char.loaded = nut.char.loaded or {}
nut.char.vars = nut.char.vars or {}
nut.char.cache = nut.char.cache or {}

nut.util.include("nutscript/gamemode/core/meta/sh_character.lua")

if (SERVER) then
	function nut.char.create(data, callback)
		local timeStamp = math.floor(os.time())

		nut.db.insertTable({
			_name = data.name or "John Doe",
			_desc = data.desc or "No description available.",
			_model = data.model or "models/error.mdl",
			_schema = SCHEMA and SCHEMA.folder or "nutscript",
			_createTime = timeStamp,
			_lastJoinTime = timeStamp,
			_steamID = data.steamID,
			_faction = data.faction or "Unknown",
			_money = data.money or nut.config.get("defMoney", 0),
			_data = data.data
		}, function(data2, charID)
			local client

			for k, v in ipairs(player.GetAll()) do
				if (v:SteamID64() == data.steamID) then
					client = v
					break
				end
			end

			nut.char.loaded[charID] = nut.char.new(data, charID, client, data.steamID)
			table.insert(nut.char.cache[data.steamID], charID)

			if (callback) then
				callback(charID)
			end
		end)
	end

	function nut.char.restore(client, callback, noCache, id)
		local steamID64 = client:SteamID64()
		local cache = nut.char.cache[steamID64]

		if (cache and !noCache) then
			for k, v in ipairs(cache) do
				local character = nut.char.loaded[v]

				if (character and !IsValid(character.client)) then
					character.player = client
				end
			end

			if (callback) then
				callback(cache)
			end

			return
		end

		local fields = "_id, _name, _desc, _model, _attribs, _data, _money, _faction"
		local condition = "_schema = '"..nut.db.escape(SCHEMA.folder).."' AND _steamID = "..client:SteamID64()

		if (id) then
			condition = condition.." AND _id = "..id
		end

		nut.db.query("SELECT "..fields.." FROM nut_characters WHERE "..condition, function(data)
			local characters = {}

			for k, v in ipairs(data or {}) do
				local id = tonumber(v._id)

				if (id) then
					local data = {}

					for k2, v2 in pairs(nut.char.vars) do
						if (v2.field and v[v2.field]) then
							local value = tostring(v[v2.field])

							if (type(v2.default) == "number") then
								value = tonumber(value) or v2.default
							elseif (type(v2.default) == "boolean") then
								value = tobool(vlaue)
							elseif (type(v2.default) == "table") then
								value = util.JSONToTable(value)
							end

							data[k2] = value
						end
					end

					characters[#characters + 1] = id

					local character = nut.char.new(data, id, client)
						hook.Run("CharacterRestored", character)

						character.vars.inv = nut.item.createInv(nut.config.get("invW", 6), nut.config.get("invH", 4))
						character.vars.inv:setOwner(id)
						
						nut.db.query("SELECT _itemID, _uniqueID, _data, _x, _y FROM nut_items WHERE _charID = "..id, function(data)
							if (data) then
								local slots = {}

								for _, item in ipairs(data) do
									local x, y = tonumber(item._x), tonumber(item._y)
									local itemID = tonumber(item._itemID)
									local data = util.JSONToTable(item._data)

									if (x and y and itemID) then
										local item2 = nut.item.new(item._uniqueID, itemID)
										item2.data = data
										item2.gridX = x
										item2.gridY = y
										
										for x2 = 0, item2.width - 1 do
											for y2 = 0, item2.height - 1 do
												slots[x + x2] = slots[x + x2] or {}
												slots[x + x2][y + y2] = item2
											end
										end
									end
								end

								character.vars.inv.slots = slots
							end
						end)
					nut.char.loaded[id] = character
				else
					ErrorNoHalt("[NutScript] Attempt to load character '"..(data._name or "nil").."' with invalid ID!")
				end
			end

			if (callback) then
				callback(characters)
			end

			nut.char.cache[steamID64] = characters
		end)
	end
end

function nut.char.new(data, id, client, steamID)
	local character = setmetatable({vars = {}}, FindMetaTable("Character"))
		for k, v in pairs(data) do
			if (v != nil) then
				character.vars[k] = v
			end
		end

		character.id = id or 0
		character.player = client

		if (IsValid(client) or steamID) then
			character.steamID = IsValid(client) and client:SteamID64() or steamID
		end
	return character
end

-- Registration of default variables go here.
do
	nut.char.registerVar("name", {
		field = "_name",
		default = "John Doe",
		index = 1,
		onValidate = function(value, data)
			if (!value or !value:find("%S")) then
				return false, "invalid", "name"
			end

			return value:sub(1, 70)
		end
	})

	nut.char.registerVar("desc", {
		field = "_desc",
		default = "No description available.",
		index = 2,
		onValidate = function(value, data)
			local minLength = nut.config.get("minDescLen", 16)

			if (!value or #value:gsub("%s", "") < minLength) then
				return false, "descMinLen", minLength
			end
		end
	})

	local gradient = nut.util.getMaterial("vgui/gradient-d")

	nut.char.registerVar("model", {
		field = "_model",
		default = "models/error.mdl",
		onSet = function(character, value)
			local client = character:getPlayer()

			if (IsValid(client) and client:getChar() == character) then
				client:SetModel(value)
			end
		end,
		onGet = function(character, default)
			return character.vars.model or default
		end,
		index = 3,
		onDisplay = function(panel, y)
			local scroll = panel:Add("DScrollPanel")
			scroll:SetSize(panel:GetWide(), 260)
			scroll:SetPos(0, y)

			local layout = scroll:Add("DIconLayout")
			layout:Dock(FILL)
			layout:SetSpaceX(1)
			layout:SetSpaceY(1)

			local faction = nut.faction.indices[panel.faction]

			if (faction) then
				for k, v in SortedPairs(faction.models) do
					local icon = layout:Add("SpawnIcon")
					icon:SetSize(64, 128)
					icon:InvalidateLayout(true)
					icon.DoClick = function(this)
						panel.payload.model = k
					end
					icon.PaintOver = function(this, w, h)
						if (panel.payload.model == k) then
							local color = nut.config.get("color", color_white)

							surface.SetDrawColor(color.r, color.g, color.b, 200)

							for i = 1, 3 do
								local i2 = i * 2

								surface.DrawOutlinedRect(i, i, w - i2, h - i2)
							end

							surface.SetDrawColor(color.r, color.g, color.b, 75)
							surface.SetMaterial(gradient)
							surface.DrawTexturedRect(0, 0, w, h)
						end
					end

					if (type(v) == "string") then
						icon:SetModel(v)
					else
						icon:SetModel(v[1], v[2] or 0, v[3])
					end
				end
			end

			return scroll
		end,
		onValidate = function(value, data)
			local faction = nut.faction.indices[data.faction]

			if (faction) then
				if (!data.model or !faction.models[data.model]) then
					return false, "needModel"
				end
			else
				return false, "needModel"
			end
		end,
		onAdjust = function(client, data, value, newData)
			local faction = nut.faction.indices[data.faction]

			if (faction) then
				local model = faction.models[value]

				if (type(model) == "string") then
					newData.model = model
				elseif (type(model) == "table") then
					newData.model = model[1]
					newData.data = newData.data or {}
					newData.data.skin = model[2] or 0
					newData.data.bodyGroups = model[3]
				end
			end
		end
	})

	nut.char.registerVar("faction", {
		field = "_faction",
		default = "Citizen",
		onSet = function(character, value)
			local client = character:getPlayer()

			if (IsValid(client)) then
				client:SetTeam(value)
			end
		end,
		onGet = function(character, default)
			local faction = nut.faction.teams[character.vars.faction]

			return faction and faction.index or 0
		end,
		noDisplay = true,
		onValidate = function(value, data, client)
			if (value) then
				if (client:hasWhitelist(value)) then
					return true
				end
			end

			return false
		end,
		onAdjust = function(client, data, value, newData)
			newData.faction = nut.faction.indices[value].uniqueID
		end
	})

	nut.char.registerVar("attribs", {
		field = "_attribs",
		default = {},
		isLocal = true,
		index = 4,
		onDisplay = function(panel, y)
			local container = panel:Add("DPanel")
			container:SetPos(0, y)
			container:SetWide(panel:GetWide() - 16)

			local y2 = 0
			local total = 0

			panel.payload.attribs = {}

			for k, v in SortedPairsByMemberValue(nut.attribs.list, "name") do
				panel.payload.attribs[k] = 0

				local bar = container:Add("nutAttribBar")
				bar:setMax(nut.config.get("maxAttribs"))
				bar:Dock(TOP)
				bar:DockMargin(2, 2, 2, 2)
				bar:setText(v.name)
				bar.onChanged = function(this, difference)
					total = total + difference

					if (total > nut.config.get("maxAttribs")) then
						return false
					end

					panel.payload.attribs[k] = panel.payload.attribs[k] + difference
				end

				y2 = bar:GetTall() + 4
			end

			container:SetTall(y2)
			return container
		end,
		onValidate = function(value, data)
			if (type(value) == "table") then
				local count = 0

				for k, v in pairs(value) do
					count = count + v
				end

				if (count > nut.config.get("maxAttribs")) then
					return false, "unknownError"
				end
			else
				return false, "unknownError"
			end
		end,
		shouldDisplay = function(panel) return table.Count(nut.attribs.list) > 0 end
	})

	nut.char.registerVar("money", {
		field = "_money",
		default = 0,
		isLocal = true,
		noDisplay = true
	})

	nut.char.registerVar("data", {
		default = {},
		isLocal = true,
		noDisplay = true,
		onSet = function(character, key, value)
			local data = character:getChar():getData()
			local client = character:getPlayer()

			data[key] = value

			if (IsValid(client)) then
				netstream.Start(client, "charData", character:getID(), key, value)
			end
		end
	})
end

-- Networking information here.
do
	if (SERVER) then
		netstream.Hook("charChoose", function(client, id)
			local character = nut.char.loaded[id]

			if (character and character:getPlayer() == client) then
				local status, result = hook.Run("CanPlayerUseChar", character)

				if (status == false) then
					return client:ChatPrint(result)
				end

				local currentChar = client:getChar()

				if (currentChar) then
					currentChar:save()
				end

				client:Spawn()
				character:setup()

				hook.Run("PlayerLoadedChar", client, character, currentChar)
			else
				ErrorNoHalt("[NutScript] Attempt to load invalid character '"..id.."'\n")
			end
		end)

		netstream.Hook("charCreate", function(client, data)
			local newData = {}

			for k, v in pairs(data) do
				local info = nut.char.vars[k]

				if (!info or (!info.onValidate and info.noDisplay)) then
					data[k] = nil
				end
			end

			for k, v in SortedPairsByMemberValue(nut.char.vars, "index") do
				local value = data[k]

				if (v.onValidate) then
					local result = {v.onValidate(value, data, client)}

					if (result[1] == false) then
						return netstream.Start(client, "charAuthed", unpack(result, 2))
					else
						if (result[1] != nil) then
							data[k] = result[1]
						end

						if (v.onAdjust) then
							v.onAdjust(client, data, value, newData)
						end
					end
				end
			end

			data.steamID = client:SteamID64()
				hook.Run("AdjustCreationData", client, data, newData)
			data = table.Merge(data, newData)

			nut.char.create(data, function(id)
				if (IsValid(client)) then
					nut.char.loaded[id]:sync(client)

					netstream.Start(client, "charAuthed", client.nutCharList)
					MsgN("Created character '"..id.."' for "..client:steamName()..".")
				end
			end)
			
		end)

		netstream.Hook("charDel", function(client, id)
			local character = nut.char.loaded[id]
			local steamID = client:SteamID64()

			if (character and character.steamID == steamID) then
				for k, v in ipairs(client.nutCharList or {}) do
					if (v == id) then
						table.remove(client.nutCharList, k)
					end
				end

				nut.char.loaded[id] = nil
				netstream.Start(nil, "charDel", id)
				nut.db.query("DELETE FROM nut_characters WHERE _id = "..id.." AND _steamID = "..client:SteamID64())
			end
		end)
	else
		netstream.Hook("charInfo", function(data, id, client)
			nut.char.loaded[id] = nut.char.new(data, id, client == nil and LocalPlayer() or client)
		end)

		netstream.Hook("charMenu", function(data)
			if (data) then
				nut.characters = data
			end

			vgui.Create("nutCharMenu")
		end)

		netstream.Hook("charData", function(id, key, value)
			local character = nut.char.loaded[id]

			if (character) then
				character:getData()[key] = value
			end
		end)

		netstream.Hook("charDel", function(id)
			nut.char.loaded[id] = nil

			for k, v in ipairs(nut.characters) do
				if (v == id) then
					table.remove(nut.characters, k)

					if (IsValid(nut.gui.char) and nut.gui.char.setupCharList) then
						nut.gui.char:setupCharList()
					end
				end
			end
		end)
	end
end

-- Additions to the player metatable here.
do
	local playerMeta = FindMetaTable("Player")
	playerMeta.steamName = playerMeta.steamName or playerMeta.Name
	playerMeta.SteamName = playerMeta.steamName

	function playerMeta:getChar()
		return nut.char.loaded[self:getNetVar("char")]
	end

	function playerMeta:Name()
		local character = self:getChar()

		if (character) then
			return character:getName()
		else
			return self:steamName()
		end
	end

	playerMeta.Nick = playerMeta.Name
	playerMeta.GetName = playerMeta.Name
end