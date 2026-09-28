--==================================================
-- INVENTORY DATA SERVER (PERSISTENCE CONTROLLER)
--
-- Place in: ServerScriptService > GameScripts > InventoryDataServer
-- Type: Script (Server-Side)
--==================================================

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local InventoryDataStore = DataStoreService:GetDataStore("PlayerInventorySettings_v2")

-- Auto-create RemoteEvent in ReplicatedStorage if missing
local inventoryRemote = ReplicatedStorage:FindFirstChild("InventoryRemote")
if not inventoryRemote then
	inventoryRemote = Instance.new("RemoteEvent")
	inventoryRemote.Name = "InventoryRemote"
	inventoryRemote.Parent = ReplicatedStorage
end

-- In-memory session cache:
-- sessionData[UserId] = { Favorites = { [ItemName] = true }, AutoSell = { [ItemName] = true } }
-- Shared with AutoSellService so both always agree.
local sessionData = require(script.Parent:WaitForChild("InvSettingsState"))

local function loadData(player)
	local userId = player.UserId
	sessionData[userId] = {
		Favorites = {},
		AutoSell = {}
	}

	local success, savedData = pcall(function()
		return InventoryDataStore:GetAsync("InvSettings_" .. userId)
	end)

	if not sessionData[userId] then return end -- left while loading
	if success and type(savedData) == "table" then
		if type(savedData.Favorites) == "table" then
			for _, itemName in ipairs(savedData.Favorites) do
				sessionData[userId].Favorites[itemName] = true
			end
		end
		if type(savedData.AutoSell) == "table" then
			for _, itemName in ipairs(savedData.AutoSell) do
				sessionData[userId].AutoSell[itemName] = true
			end
		end
	end

	sessionData[userId].Loaded = true
	inventoryRemote:FireClient(player, "InitData", sessionData[userId])
end

local function saveData(player)
	local userId = player.UserId
	if not sessionData[userId] then return end

	local favoritesList = {}
	for itemName, isFav in pairs(sessionData[userId].Favorites) do
		if isFav then table.insert(favoritesList, itemName) end
	end

	local autoSellList = {}
	for itemName, isAutoSell in pairs(sessionData[userId].AutoSell) do
		if isAutoSell then table.insert(autoSellList, itemName) end
	end

	pcall(function()
		InventoryDataStore:SetAsync("InvSettings_" .. userId, {
			Favorites = favoritesList,
			AutoSell = autoSellList
		})
	end)

	sessionData[userId] = nil
end

Players.PlayerAdded:Connect(loadData)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

inventoryRemote.OnServerEvent:Connect(function(player, action, itemName)
	local userId = player.UserId
	if not sessionData[userId] then return end

	-- The client asks once its listener is connected; the PlayerAdded
	-- push often arrives before the GUI script exists and is lost.
	if action == "RequestInit" then
		if sessionData[userId].Loaded then
			inventoryRemote:FireClient(player, "InitData", sessionData[userId])
		end
		return
	end

	if action == "ToggleFavorite" and type(itemName) == "string" then
		if sessionData[userId].Favorites[itemName] then
			sessionData[userId].Favorites[itemName] = nil
		else
			sessionData[userId].Favorites[itemName] = true
			sessionData[userId].AutoSell[itemName] = nil -- Enforce mutual exclusion
		end
	elseif action == "ToggleAutoSell" and type(itemName) == "string" then
		if sessionData[userId].AutoSell[itemName] then
			sessionData[userId].AutoSell[itemName] = nil
		else
			sessionData[userId].AutoSell[itemName] = true
			sessionData[userId].Favorites[itemName] = nil -- Enforce mutual exclusion
		end
	end
end)