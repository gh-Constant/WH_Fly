local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileStore = require(ReplicatedStorage.AW_Fishing.ExternalLibs.ProfileStore)

-- Define the profile template
local PROFILE_TEMPLATE = {
	FishInventory = {},
	playerRodEquipped = "Basic Rod", -- Add playerRodEquipped to the template
}

local PlayerStore = ProfileStore.New("PlayerStore3", PROFILE_TEMPLATE)
local Profiles = {}

local PlayerData = {}

function PlayerData.SetupPlayer(player)
	if Profiles[player] then
		print("Profile session already exists for player:", player.DisplayName)
		return
	end

	print("Attempting to start profile session for player:", player.DisplayName)

	-- Start a profile session for this player's data
	local profile = PlayerStore:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then
		print("Profile session started successfully for:", player.DisplayName)
		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from PROFILE_TEMPLATE

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			player:Kick("Profile session end - Please rejoin")
		end)

		if player.Parent == Players then
			Profiles[player] = profile
			print("Profile loaded for " .. player.DisplayName .. "!")
		else
			-- The player has left before the profile session started
			profile:EndSession()
		end
	else
		print("Failed to start profile session for:", player.DisplayName)
		player:Kick("Profile load fail - Please rejoin")
	end
end

function PlayerData.CleanupPlayer(player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end

function PlayerData.GetEquippedRod(player)
	local profile = Profiles[player]
	return profile and profile.Data.playerRodEquipped or nil
end

function PlayerData.SetEquippedRod(player, rodName)
	local profile = Profiles[player]
	if profile then
		profile.Data.playerRodEquipped = rodName
		profile:Save()
	end
end
function PlayerData.AddFishToInventory(player, fishName, fishWeight)
	local profile = Profiles[player]
	if profile then
		if not profile.Data.FishInventory[fishName] then
			profile.Data.FishInventory[fishName] = {}
		end
		table.insert(profile.Data.FishInventory[fishName], fishWeight)
		profile:Save()
	end
end

function PlayerData.GetFishInventory(player)
	local profile = Profiles[player]
	return profile and profile.Data.FishInventory or {}
end

function PlayerData.RemoveFishFromInventory(player, fishName, index)
	local profile = Profiles[player]
	if profile and profile.Data.FishInventory[fishName] then
		if index then
			table.remove(profile.Data.FishInventory[fishName], index)
			if #profile.Data.FishInventory[fishName] == 0 then
				profile.Data.FishInventory[fishName] = nil
			end
		else
			profile.Data.FishInventory[fishName] = nil
		end
		profile:Save()
	end
end

-- Connect player events
Players.PlayerAdded:Connect(function(player)
	if not Profiles[player] then
		PlayerData.SetupPlayer(player)
	end
end)

Players.PlayerRemoving:Connect(PlayerData.CleanupPlayer)

-- In case players have joined the server earlier than this script ran
for _, player in Players:GetPlayers() do
	if not Profiles[player] then
		task.spawn(PlayerData.SetupPlayer, player)
	end
end

return PlayerData
