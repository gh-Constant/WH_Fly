local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerData = require(script.Parent.PlayerData)
local RodManager = require(ServerScriptService.AW_Fishing.FishingRods.RodManager)
local ZoneManager = require(ServerScriptService.AW_Fishing.Zones.ZoneManager)

local PlayerObject = {}
PlayerObject.__index = PlayerObject

-- Table to store player objects
local playerObjects = {}

function PlayerObject.new(player: Player)
	local self = setmetatable({}, PlayerObject)
	self.player = player
	self.Rod = RodManager.new(player)
	self.currentZone = "Default"
	return self
end

function PlayerObject:getPlayer()
	return self.player
end

function PlayerObject:getEquippedRod()
	return PlayerData.GetEquippedRod(self.player)
end

function PlayerObject:equipRod()
	self.Rod:EquipRod()
end

function PlayerObject:addFishToInventory(fishName, fishWeight)
	PlayerData.AddFishToInventory(self.player, fishName, fishWeight)
end

function PlayerObject:getFishInventory()
	return PlayerData.GetFishInventory(self.player)
end

function PlayerObject:removeFishFromInventory(fishName, index)
	PlayerData.RemoveFishFromInventory(self.player, fishName, index)
end

function PlayerObject:setEquippedRod(rodName)
	PlayerData.SetEquippedRod(self.player, rodName)
end

function PlayerObject.GetPlayerObject(player: Player)
	return playerObjects[player]
end

-- Connect to PlayerAdded event to create a PlayerObject for each player
Players.PlayerAdded:Connect(function(player)
	playerObjects[player] = PlayerObject.new(player)
end)

-- Optionally, handle PlayerRemoving to clean up
Players.PlayerRemoving:Connect(function(player)
	playerObjects[player] = nil
end)

function PlayerObject:setCurrentZone(zoneName: string)
	self.currentZone = zoneName
end

function PlayerObject:getCurrentZone(): string
	return self.currentZone
end

return PlayerObject
