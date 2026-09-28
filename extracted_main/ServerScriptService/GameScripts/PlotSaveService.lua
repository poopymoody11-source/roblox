local DataStoreService = game:GetService("DataStoreService")

local PlotSaveService = {}

local DATASTORE_NAME = "PlotPlacementData_v1"
local AUTO_SAVE_INTERVAL = 120

local store = DataStoreService:GetDataStore(DATASTORE_NAME)

local sessionData = {}
local dirty = {}
local isLoaded = {}
local activeUserIds = {}

local function keyFor(userId)
	return "Player_" .. userId
end

local function ensurePlatformEntry(userId, platformName)
	sessionData[userId] = sessionData[userId] or {}
	local userTable = sessionData[userId]
	userTable[platformName] = userTable[platformName] or { Item = nil, Money = 0 }
	return userTable[platformName]
end

function PlotSaveService.Init(player)
	local userId = player.UserId

	local success, result = pcall(function()
		return store:GetAsync(keyFor(userId))
	end)

	sessionData[userId] = (success and type(result) == "table") and result or {}
	dirty[userId] = false
	isLoaded[userId] = true
	activeUserIds[userId] = true
end

function PlotSaveService.IsLoaded(userId)
	return isLoaded[userId] == true
end

function PlotSaveService.Teardown(player)
	local userId = player.UserId
	PlotSaveService.FlushSave(userId)
	sessionData[userId] = nil
	dirty[userId] = nil
	isLoaded[userId] = nil
	activeUserIds[userId] = nil
end

function PlotSaveService.FlushSave(userId)
	local data = sessionData[userId]
	if not data then return end

	local success, err = pcall(function()
		store:SetAsync(keyFor(userId), data)
	end)

	if success then
		dirty[userId] = false
	else
		warn("[PlotSaveService] Failed to save plot data for userId " .. tostring(userId) .. ": " .. tostring(err))
	end
end

function PlotSaveService.GetPlacedItem(userId, platformName)
	local userTable = sessionData[userId]
	local entry = userTable and userTable[platformName]
	return entry and entry.Item or nil
end

function PlotSaveService.SetPlacedItem(userId, platformName, itemName)
	local entry = ensurePlatformEntry(userId, platformName)
	entry.Item = itemName
	dirty[userId] = true
end

function PlotSaveService.ClearPlacedItem(userId, platformName)
	local entry = ensurePlatformEntry(userId, platformName)
	entry.Item = nil
	dirty[userId] = true
end

function PlotSaveService.GetMoney(userId, platformName)
	local userTable = sessionData[userId]
	local entry = userTable and userTable[platformName]
	return entry and entry.Money or 0
end

function PlotSaveService.AddMoney(userId, platformName, amount)
	local entry = ensurePlatformEntry(userId, platformName)
	entry.Money += amount
	dirty[userId] = true
	return entry.Money
end

function PlotSaveService.ResetMoney(userId, platformName)
	local entry = ensurePlatformEntry(userId, platformName)
	entry.Money = 0
	dirty[userId] = true
end

task.spawn(function()
	while true do
		task.wait(AUTO_SAVE_INTERVAL)
		for userId in pairs(activeUserIds) do
			PlotSaveService.FlushSave(userId)
		end
	end
end)

game:BindToClose(function()
	for userId in pairs(activeUserIds) do
		PlotSaveService.FlushSave(userId)
	end
end)

return PlotSaveService