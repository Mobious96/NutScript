--[[
    NutScript is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    NutScript is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with NutScript.  If not, see <http://www.gnu.org/licenses/>.
--]]

PLUGIN.name = "Vendors"
PLUGIN.author = "Chessnut"
PLUGIN.desc = "Adds NPC vendors that can sell things."

VENDOR_BUY = 1
VENDOR_SELL = 2
VENDOR_BOTH = 3

if (SERVER) then
	local PLUGIN = PLUGIN

	function PLUGIN:saveVendors()
		local data = {}
			for k, v in ipairs(ents.FindByClass("nut_vendor")) do
				data[#data + 1] = {
					name = v:getNetVar("name"),
					desc = v:getNetVar("desc"),
					pos = v:GetPos(),
					angles = v:GetAngles(),
					model = v:GetModel(),
					bubble = v:getNetVar("noBubble"),
					items = v.items,
					factions = v.factions,
					classes = v.classes,
					rates = v.rates,
					money = v.money,
					msg = v.messages,
					stocks = v.stocks
				}
			end
		self:setData(data)
	end

	function PLUGIN:LoadData()
		for k, v in ipairs(self:getData()) do
			local entity = ents.Create("nut_vendor")
			entity:SetPos(v.pos)
			entity:SetAngles(v.angles)
			entity:SetModel(v.model)
			entity:Spawn()
			entity:setNetVar("noBubble", v.bubble)
			entity:setNetVar("name", v.name)
			entity:setNetVar("desc", v.desc)

			entity.items = v.items or {}
			entity.factions = v.factions or {}
			entity.classes = v.classes or {}
			entity.rates = v.rates
			entity.money = v.money
			entity.msg = v.messages
			entity.stocks = v.stocks
		end
	end

	netstream.Hook("vendorExit", function(client)
		client.nutVendor = nil
	end)

	netstream.Hook("vendorEdit", function(client, entity, key, value)
		if (client:IsAdmin() and IsValid(entity)) then
			if (key == "name" or key == "desc") then
				entity:setNetVar(key, value)
			elseif (entity[key]) then
				entity[key] = value
			end

			timer.Create("nutSaveVendorEdits", 60, 1, function()
				PLUGIN:saveVendors()
			end)
		end
	end)

	netstream.Hook("vendorItemMod", function(client, entity, uniqueID, key, value)
		if (client:IsAdmin() and IsValid(entity)) then
			entity.items[uniqueID] = value

			timer.Create("nutSaveVendorEdits", 60, 1, function()
				PLUGIN:saveVendors()
			end)
		end
	end)
else
	netstream.Hook("vendorUse", function(entity, items, rates, money, stock, adminData)
		vgui.Create("nutVendor"):setVendor(entity, items, rates, money, stocks)

		if (LocalPlayer():IsAdmin() and adminData) then
			vgui.Create("nutVendorAdmin"):setData(entity, items, rates, money, stock, adminData)
		end
	end)
end

nut.util.include("sh_commands.lua")