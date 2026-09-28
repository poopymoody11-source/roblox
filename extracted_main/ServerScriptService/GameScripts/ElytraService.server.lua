--==================================================
-- RETIRED -- see GameScripts > MonetizationService
--
-- This script used to hand out the Elytra on its own
-- against a GAMEPASS_ID that was still 00000000, so it
-- never fired for anyone except the hardcoded name
-- below. It also looked for "elytra" (lowercase) on the
-- character while the model is named "Elytra", so its
-- duplicate guard never matched and a respawn stacked
-- a second pair of wings.
--
-- MonetizationService now owns every pass benefit,
-- including this one: it knows the real pass id
-- (1986009366), re-applies on respawn, and grants the
-- moment the purchase completes instead of on rejoin.
--
-- The script itself is Disabled rather than deleted,
-- so the old logic is still here to read. Delete it
-- whenever you like -- nothing references it.
--==================================================

local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

-- Change this to your actual GamePass ID
local GAMEPASS_ID = 00000000 

-- Path to your item based on your request
local StorageFolder = ServerStorage:WaitForChild("AccessibleModels"):WaitForChild("Accessories")
local ElytraItem = StorageFolder:WaitForChild("Elytra")

-- Function to equip the item
local function giveElytra(player, character)
	-- Prevents duplicating if they already have it equipped
	if character:FindFirstChild("elytra") then return end

	-- Clone and weld the accessory to the character
	local clone = ElytraItem:Clone()
	clone.Parent = character
end

-- Listen for players joining
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)

		-- 1. Check if their username matches the free whitelist bypass
		if player.Name == "munkyusik" then
			giveElytra(player, character)
			return -- Stop running the rest of the script for this player
		end

		-- 2. If they are not Breacher681, securely check if they own the gamepass
		local hasPass = false
		local success, message = pcall(function()
			hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_ID)
		end)

		-- If the check succeeded and they own it, give them the item
		if success and hasPass then
			giveElytra(player, character)
		elseif not success then
			warn("Error checking gamepass for " .. player.Name .. ": " .. tostring(message))
		end

	end)
end)
