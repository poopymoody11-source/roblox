--==================================================
-- INVENTORY SERVER HANDLER (REAL-TIME SYNC)
-- Place in: ServerScriptService
-- Type: Script (Server)
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local inventoryRemote = remotes:FindFirstChild("InventoryRemote")
if not inventoryRemote then
	inventoryRemote = Instance.new("RemoteEvent")
	inventoryRemote.Name = "InventoryRemote"
	inventoryRemote.Parent = remotes
end

local ITEMS = {
	"normal_lapis", "golden_lapis", "diamond_lapis", "emerald_lapis",
	"rgb_lapis", "totem_lapis", "verity_lapis", "hell_lapis",
	"67_lapis", "lapeace_lapis", "malevolent_lapis", "interstellar_lapis"
}

local playerFavorites = {}
local playerAutoSell = {}

local function fetchInventory(player)
	if type(InventoryService.Get) == "function" then
		return InventoryService.Get(player)
	elseif type(InventoryService.GetInventory) == "function" then
		return InventoryService.GetInventory(player)
	elseif type(InventoryService.GetData) == "function" then
		return InventoryService.GetData(player)
	end
	return nil
end

Players.PlayerAdded:Connect(function(player)
	playerFavorites[player] = {}
	playerAutoSell[player] = {}

	local playerStats = Instance.new("Folder")
	playerStats.Name = "PlayerStats"
	playerStats.Parent = player

	local lapisFolder = Instance.new("Folder")
	lapisFolder.Name = "Lapis"
	lapisFolder.Parent = playerStats

	local discoveredFolder = Instance.new("Folder")
	discoveredFolder.Name = "Discovered"
	discoveredFolder.Parent = playerStats

	for _, itemName in ipairs(ITEMS) do
		local intVal = Instance.new("IntValue")
		intVal.Name = itemName
		intVal.Value = 0
		intVal.Parent = lapisFolder

		local boolVal = Instance.new("BoolValue")
		boolVal.Name = itemName
		boolVal.Value = false
		boolVal.Parent = discoveredFolder
	end

	task.delay(1, function()
		if player and player.Parent then
			inventoryRemote:FireClient(player, "InitData", {
				Favorites = playerFavorites[player],
				AutoSell = playerAutoSell[player]
			})
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerFavorites[player] = nil
	playerAutoSell[player] = nil
end)

-- Real-time synchronization loop (checks every 0.2 seconds to reflect pickups instantly)
task.spawn(function()
	while true do
		task.wait(0.2)
		for _, player in ipairs(Players:GetPlayers()) do
			local playerStats = player:FindFirstChild("PlayerStats")
			if playerStats then
				local lapisFolder = playerStats:FindFirstChild("Lapis")
				local discoveredFolder = playerStats:FindFirstChild("Discovered")

				if lapisFolder then
					local inv = fetchInventory(player)
					if inv and type(inv) == "table" then
						for _, itemName in ipairs(ITEMS) do
							local count = inv[itemName] or (inv.Items and inv.Items[itemName]) or 0

							local val = lapisFolder:FindFirstChild(itemName)
							if val and val.Value ~= count then
								val.Value = count
							end

							if discoveredFolder and count > 0 then
								local disc = discoveredFolder:FindFirstChild(itemName)
								if disc and not disc.Value then
									disc.Value = true
								end
							end
						end
					end
				end
			end
		end
	end
end)

inventoryRemote.OnServerEvent:Connect(function(player, action, itemName)
	if not table.find(ITEMS, itemName) then return end

	if action == "ToggleFavorite" then
		if not playerFavorites[player] then playerFavorites[player] = {} end
		playerFavorites[player][itemName] = not playerFavorites[player][itemName]
		if playerFavorites[player][itemName] then
			playerAutoSell[player][itemName] = nil
		end
	elseif action == "ToggleAutoSell" then
		if not playerAutoSell[player] then playerAutoSell[player] = {} end
		playerAutoSell[player][itemName] = not playerAutoSell[player][itemName]
		if playerAutoSell[player][itemName] then
			playerFavorites[player][itemName] = nil
		end
	end
end)