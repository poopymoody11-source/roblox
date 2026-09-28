--==================================================
-- UNIFIED LEADERSTATS & SHOP SERVICE (COMPLETE & FIXED)
-- Place in: ServerScriptService > LeaderstatsSetup
--==================================================


------

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---
local QuestDataService = require(ServerScriptService.GameScripts.QuestDataService)
local MonetizationData = require(ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("MonetizationData"))
local AscensionData = require(ReplicatedStorage.AccessibleModules:WaitForChild("AscensionDataModule"))

-- Staffs that come from a gamepass the player owns (OP / Verity / La Peace).
-- If one of these is equipped when you ascend, you keep holding it instead
-- of being dropped back to the base staff.
local function ownedPassStaffs(player)
	local set = {}
	for key, benefit in pairs(MonetizationData.Benefits) do
		if benefit.Staffs and MonetizationData.Owns(player, key) then
			for _, itemName in ipairs(benefit.Staffs) do set[itemName] = true end
		end
	end
	return set
end
local batTool = ReplicatedStorage.AccessibleModels.Bat
local verityBat = ReplicatedStorage.AccessibleModels.VerityBat
---
local LEADERSTATS_DATASTORE_NAME = "PlayerLeaderstats_v2"
local AUTO_SAVE_INTERVAL = 180

local ALL_LAPIS_ITEMS = {
	"normal_lapis", "golden_lapis", "diamond_lapis", "emerald_lapis", 
	"rgb_lapis", "totem_lapis", "verity_lapis", "hell_lapis", 
	"67_lapis", "lapeace_lapis", "malevolent_lapis", "interstellar_lapis"
}

local ITEM_DATA = {
	["normal_lapis"]       = {Cost = 10,           ToolName = "normalstaff"},
	-- Staff prices were a flat x10 ladder topping out at 5 TRILLION PP,
	-- which is unreachable in a ~90 minute run (end-game income is about
	-- 1.3M PP/sec). Rescaled to ~x4 per staff so each one lands a few
	-- minutes after the previous, and the last is a late-game goal rather
	-- than a decoration. Magnet radius scales alongside in MagnetScript.
	-- (x0.3 for the ~25 minute run, in step with ascension/base upgrade costs;
	-- the shop's price labels are updated to match)
	["golden_lapis"]       = {Cost = 75,           ToolName = "gold"},
	["diamond_lapis"]      = {Cost = 300,          ToolName = "diamond"},
	["emerald_lapis"]      = {Cost = 1200,         ToolName = "emerald"},
	["rgb_lapis"]          = {Cost = 4800,         ToolName = "rgb"},
	["totem_lapis"]        = {Cost = 20000,        ToolName = "totem"},
	["verity_lapis"]       = {Cost = 78000,        ToolName = "verity"},
	["hell_lapis"]         = {Cost = 300000,       ToolName = "hell"},
	["67_lapis"]           = {Cost = 1300000,      ToolName = "67staff2.0"},
	["lapeace_lapis"]      = {Cost = 5100000,      ToolName = "heavenstaff"},
	["malevolent_lapis"]   = {Cost = 20000000,     ToolName = "sucknarstaff"},
	["interstellar_lapis"] = {Cost = 81000000,     ToolName = "interstellar2.0"},
	["op_lapis"]           = {Cost = 1000000000,   ToolName = "opstaff"},
}

local leaderstatsStore = DataStoreService:GetDataStore(LEADERSTATS_DATASTORE_NAME)

--==================================================
-- NUMBER STATS
--
-- Returns a NumberValue called `name` under `parent`,
-- converting an existing IntValue of the same name in
-- place (value carried over) so an older save or a
-- still-running server upgrades cleanly instead of
-- keeping the 2.1 billion ceiling.
--==================================================

local function ensureNumberValue(parent, name)
	local existing = parent:FindFirstChild(name)

	if existing then
		if existing:IsA("NumberValue") then
			return existing
		end

		-- Wrong class (almost certainly an IntValue from the
		-- old build). Carry the number across and swap it.
		local carried = 0
		pcall(function() carried = existing.Value end)
		existing:Destroy()

		local replacement = Instance.new("NumberValue")
		replacement.Name = name
		replacement.Value = carried
		replacement.Parent = parent
		return replacement
	end

	local created = Instance.new("NumberValue")
	created.Name = name
	created.Parent = parent
	return created
end
local playerSessionData = {}
local lastSaveTimes = {}
local lastEquipTimes = {}
local lastShopTimes = {}
local lastAscendTimes = {}

local accessibleEvents = ReplicatedStorage:FindFirstChild("AccessibleEvents")
if not accessibleEvents then
	accessibleEvents = Instance.new("Folder")
	accessibleEvents.Name = "AccessibleEvents"
	accessibleEvents.Parent = ReplicatedStorage
end

local shopEvent = accessibleEvents:FindFirstChild("ShopEvent")
if not shopEvent then
	shopEvent = Instance.new("RemoteEvent")
	shopEvent.Name = "ShopEvent"
	shopEvent.Parent = accessibleEvents
end

local inventoryRemote = accessibleEvents:FindFirstChild("InventoryRemote")
if not inventoryRemote then
	inventoryRemote = Instance.new("RemoteEvent")
	inventoryRemote.Name = "InventoryRemote"
	inventoryRemote.Parent = accessibleEvents
end

local resetShopEvent = ServerStorage:FindFirstChild("ResetPlayerShop")
if not resetShopEvent then
	resetShopEvent = Instance.new("BindableEvent")
	resetShopEvent.Name = "ResetPlayerShop"
	resetShopEvent.Parent = ServerStorage
end

local adminBindable = ServerStorage:FindFirstChild("AdminActionBindable")
if not adminBindable then
	adminBindable = Instance.new("BindableEvent")
	adminBindable.Name = "AdminActionBindable"
	adminBindable.Parent = ServerStorage
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function findInventoryModule()
	local nested = ServerScriptService:FindFirstChild("InventoryService", true)
	if nested then return nested end
	return ServerStorage:FindFirstChild("InventoryService", true)
end

local inventoryModule = findInventoryModule()
local _, InventoryService = pcall(function()
	return inventoryModule and require(inventoryModule)
end)

if not InventoryService then
	InventoryService = {
		Get = function() return {} end,
		GetCount = function() return 0 end,
		Add = function() end,
		Remove = function() return false end,
		Set = function() end,
		Clear = function() end,
		WaitUntilLoaded = function() end,
		Changed = { Connect = function() end }
	}
end

local function buildStatsFolder(player)
	local stats = player:FindFirstChild("PlayerStats") or Instance.new("Folder", player)
	stats.Name = "PlayerStats"

	local lapis = stats:FindFirstChild("Lapis") or Instance.new("Folder", stats)
	lapis.Name = "Lapis"

	local discovered = stats:FindFirstChild("Discovered") or Instance.new("Folder", stats)
	discovered.Name = "Discovered"

	for _, itemName in ipairs(ALL_LAPIS_ITEMS) do
		local val = lapis:FindFirstChild(itemName) or Instance.new("IntValue", lapis)
		val.Name = itemName
		if val.Value == nil then val.Value = 0 end

		local disc = discovered:FindFirstChild(itemName) or Instance.new("BoolValue", discovered)
		disc.Name = itemName
		if disc.Value == nil then disc.Value = (itemName == "normal_lapis") end
	end

	return stats, lapis, discovered
end

local function markDiscovered(discoveredFolder, itemName, state)
	local boolVal = discoveredFolder:FindFirstChild(itemName) or Instance.new("BoolValue", discoveredFolder)
	boolVal.Name = itemName
	boolVal.Value = (state == nil and true or state)
end

local function syncLapis(player, inventory)
	local session = playerSessionData[player.UserId]
	if session then
		session.Inventory = inventory or {}
	end

	local _, lapisFolder, discoveredFolder = buildStatsFolder(player)

	for _, itemName in ipairs(ALL_LAPIS_ITEMS) do
		local count = inventory and inventory[itemName] or 0
		local value = lapisFolder:FindFirstChild(itemName) or Instance.new("IntValue", lapisFolder)
		value.Name = itemName
		value.Value = count

		if count > 0 then
			markDiscovered(discoveredFolder, itemName, true)
		end
	end
end

local function loadLeaderstatsData(player)
	local success, result = pcall(function()
		return leaderstatsStore:GetAsync(keyFor(player))
	end)

	if success and type(result) == "table" then
		return {
			PeacePoints = result.PeacePoints or 0,
			Ascensions = result.Ascensions or result.Rebirths or 0,
			Discovered = result.Discovered or {},
			Favorites = result.Favorites or {},
			AutoSell = result.AutoSell or {},
			OwnedItems = result.OwnedItems or { ["Staffs_normal_lapis"] = true },
			EquippedItem = result.EquippedItem or "Staffs_normal_lapis",
			Inventory = result.Inventory or {},
			Godmode = result.Godmode or false,
		}
	end

	return {
		PeacePoints = 0,
		Ascensions = 0,
		Discovered = {},
		Favorites = {},
		AutoSell = {},
		OwnedItems = { ["Staffs_normal_lapis"] = true },
		EquippedItem = "Staffs_normal_lapis",
		Inventory = {},
		Godmode = false,
	}
end

local pendingSaves = {}

local function saveLeaderstats(player, forced)
	local userId = player.UserId
	local now = os.clock()
	local since = lastSaveTimes[userId] and (now - lastSaveTimes[userId])

	if since and since < 6.5 then
		if not forced then
			return
		end
		-- A forced save right after another one (equip spam, a bundle
		-- grant, several rewards in a row) would queue up behind the
		-- DataStore's 6s-per-key limit. Coalesce: one save shortly after
		-- the cooldown with the latest data. "now" (leaving / shutdown)
		-- always writes immediately.
		if forced ~= "now" then
			if not pendingSaves[userId] then
				pendingSaves[userId] = true
				task.delay(6.6 - since, function()
					pendingSaves[userId] = nil
					if player.Parent then saveLeaderstats(player, "now") end
				end)
			end
			return
		end
	end
	lastSaveTimes[userId] = now

	local leaderstats = player:FindFirstChild("leaderstats")
	local playerStats = player:FindFirstChild("PlayerStats")
	if not leaderstats or not playerStats then return end

	local peacePoints = leaderstats:FindFirstChild("PeacePoints")
	local ascensions = leaderstats:FindFirstChild("Ascensions") or leaderstats:FindFirstChild("Rebirths")
	if not peacePoints or not ascensions then return end

	local discoveredFolder = playerStats:FindFirstChild("Discovered")
	local discoveredTable = {}
	if discoveredFolder then
		for _, boolVal in ipairs(discoveredFolder:GetChildren()) do
			if boolVal:IsA("BoolValue") then
				discoveredTable[boolVal.Name] = boolVal.Value
			end
		end
	end

	local session = playerSessionData[userId] or {}

	-- InventoryService is the source of truth for counts --
	-- pull the latest straight from it rather than trusting
	-- whatever session.Inventory happened to hold.
	local currentInventory = InventoryService.Get(player)
	session.Inventory = currentInventory

	local saveData = {
		PeacePoints = peacePoints.Value,
		Ascensions = ascensions.Value,
		Discovered = discoveredTable,
		Favorites = session.Favorites or {},
		AutoSell = session.AutoSell or {},
		OwnedItems = session.OwnedItems or { ["Staffs_normal_lapis"] = true },
		EquippedItem = session.EquippedItem or "Staffs_normal_lapis",
		Inventory = currentInventory,
		Godmode = session.Godmode or false,
	}

	pcall(function()
		leaderstatsStore:SetAsync(keyFor(player), saveData)
	end)
end

-- Tools tagged PassSessionTool are gamepass staffs handed out in a test
-- session (MonetizationService). They're owned for the whole session, so
-- ascending or equipping another staff must not delete them -- that was
-- the "OP staff removes itself on ascension" bug.
local function isPassSessionTool(tool)
	return tool:GetAttribute("PassSessionTool") == true
end

local function clearTools(player)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and not isPassSessionTool(child) then child:Destroy() end
		end
	end
	if player.Character then
		for _, child in ipairs(player.Character:GetChildren()) do
			if child:IsA("Tool") and not isPassSessionTool(child) then child:Destroy() end
		end
	end
end

local function equipTool(player, itemName, category)
	local userId = player.UserId
	local now = os.clock()
	if lastEquipTimes[userId] and (now - lastEquipTimes[userId] < 0.2) then return end
	lastEquipTimes[userId] = now

	local backpack = player:WaitForChild("Backpack", 5)
	if not backpack then return end

	clearTools(player)

	category = category or "Staffs"
	local itemConfig = ITEM_DATA[itemName]
	local toolName = itemConfig and itemConfig.ToolName or itemName

	local accessibleModels = ServerStorage:FindFirstChild("AccessibleModels")
	local catFolder = accessibleModels and accessibleModels:FindFirstChild(category) or (accessibleModels and accessibleModels:FindFirstChild("Staffs"))
	local toolTemplate = catFolder and catFolder:FindFirstChild(toolName)

	if not toolTemplate and accessibleModels then
		for _, desc in ipairs(accessibleModels:GetDescendants()) do
			if desc:IsA("Tool") and (desc.Name:lower() == toolName:lower() or desc.Name:lower() == itemName:lower()) then
				toolTemplate = desc
				break
			end
		end
	end

	-- don't hand out a second copy of a pass staff they're already holding
	local alreadyHeld = backpack:FindFirstChild(toolTemplate and toolTemplate.Name or toolName)
		or (player.Character and player.Character:FindFirstChild(toolTemplate and toolTemplate.Name or toolName))
	if toolTemplate and not (alreadyHeld and alreadyHeld:IsA("Tool") and isPassSessionTool(alreadyHeld)) then
		toolTemplate:Clone().Parent = backpack
	end
	
	if not QuestDataService.WaitUntilLoaded(player) then
		warn("Quest data never loaded for " .. player.Name .. " — can't grant owned tools")
		return
	end

	-- Once Verity has upgraded it, the plain bat is gone for good --
	-- only the Verity Bat comes back.
	local upgraded = QuestDataService.IsQuestClaimed(player, "VerityQuest3")
	if QuestDataService.IsQuestClaimed(player, "TungQuest") and not upgraded then
		batTool:Clone().Parent = backpack
	end
	if upgraded then
		verityBat:Clone().Parent = backpack
	end
	-- clearTools wiped Verity's paper too; hand it back while it's still owed
	local paper = ReplicatedStorage.AccessibleModels:FindFirstChild("VerityPaper")
	if paper and QuestDataService.IsQuestClaimed(player, "VerityQuest")
		and not QuestDataService.IsQuestClaimed(player, "VerityQuest2")
		and not backpack:FindFirstChild("VerityPaper") then
		paper:Clone().Parent = backpack
	end
end

local function equipSavedStaff(player)
	local session = playerSessionData[player.UserId]
	if not session or not session.EquippedItem or session.EquippedItem == "" then return end

	local category, itemName = session.EquippedItem:match("^(.-)_(.+)$")
	if category and itemName then
		equipTool(player, itemName, category)
	end
end

local function performAscension(player)
	local userId = player.UserId
	local now = os.clock()
	if lastAscendTimes[userId] and (now - lastAscendTimes[userId] < 1) then return end
	lastAscendTimes[userId] = now

	local leaderstats = player:FindFirstChild("leaderstats")
	local stats, lapisFolder, discoveredFolder = buildStatsFolder(player)

	local ascensionsStat = leaderstats and (leaderstats:FindFirstChild("Ascensions") or leaderstats:FindFirstChild("Rebirths"))
	local statsAscensions = stats and stats:FindFirstChild("Ascensions")

	if ascensionsStat then
		ascensionsStat.Value += 1
		if statsAscensions then statsAscensions.Value = ascensionsStat.Value end
	end

	local peacePointsStat = leaderstats and leaderstats:FindFirstChild("PeacePoints")
	local statsPeace = stats and stats:FindFirstChild("PeacePoints")

	if peacePointsStat then peacePointsStat.Value = 0 end
	if statsPeace then statsPeace.Value = 0 end

	local session = playerSessionData[userId]
	if session then
		-- STAFFS SURVIVE ASCENSION: every staff you've bought stays yours, and the one
		-- you're holding stays equipped (it's re-given to your inventory right after)
		local passStaffs = ownedPassStaffs(player)
		session.OwnedItems = session.OwnedItems or {}
		session.OwnedItems["Staffs_normal_lapis"] = true
		for itemName in pairs(passStaffs) do
			session.OwnedItems["Staffs_" .. itemName] = true
		end
		session.EquippedItem = session.EquippedItem or "Staffs_normal_lapis"
		session.Godmode = false
		session.Inventory = {}
		session.Favorites = {}
		session.AutoSell = {}
	end

	pcall(function()
		InventoryService.Clear(player)
	end)

	for _, val in ipairs(lapisFolder:GetChildren()) do
		if val:IsA("IntValue") then val.Value = 0 end
	end

	for _, discVal in ipairs(discoveredFolder:GetChildren()) do
		if discVal:IsA("BoolValue") then 
			discVal.Value = (discVal.Name == "normal_lapis") 
		end
	end

	clearTools(player)
	lastEquipTimes[userId] = nil -- never let the equip debounce swallow the re-equip
	equipSavedStaff(player)
	saveLeaderstats(player, true)

	if session then
		shopEvent:FireClient(player, "LoadData", session.OwnedItems, session.EquippedItem)
		shopEvent:FireClient(player, "Init", session.OwnedItems, session.EquippedItem)
		inventoryRemote:FireClient(player, "InitData", session)
	end
end

-- Ascend only if the player can actually afford it. The rebirth button
-- used to be trusted blindly: the cost check lived on the client only,
-- so an exploiter could fire ShopEvent("Ascend") for free ascensions.
local function canAffordAscension(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local pp = leaderstats and leaderstats:FindFirstChild("PeacePoints")
	local asc = leaderstats and (leaderstats:FindFirstChild("Ascensions") or leaderstats:FindFirstChild("Rebirths"))
	if not pp or not asc then return false end
	return pp.Value >= AscensionData.GetCostFor(player, asc.Value)
end

resetShopEvent.Event:Connect(function(player)
	performAscension(player)
end)

adminBindable.Event:Connect(function(player, action, arg1, arg2)
	local session = playerSessionData[player.UserId]
	if not session then return end

	if action == "Ascend" then
		performAscension(player)

	elseif action == "GiveAllMax" then
		local amount = arg1 or 999

		for _, itemName in ipairs(ALL_LAPIS_ITEMS) do
			InventoryService.Set(player, itemName, amount)
			session.OwnedItems["Staffs_" .. itemName] = true
		end

		session.Inventory = InventoryService.Get(player)
		syncLapis(player, session.Inventory)
		saveLeaderstats(player, true)
		shopEvent:FireClient(player, "LoadData", session.OwnedItems, session.EquippedItem)
		shopEvent:FireClient(player, "Init", session.OwnedItems, session.EquippedItem)
		inventoryRemote:FireClient(player, "InitData", session)

	elseif action == "GiveLapis" then
		local targetItem = arg1
		local amount = arg2 or 1

		-- amount 0 = "make sure this staff is unlocked" (the OP Staff pass
		-- re-asserts it on every spawn and every ownership sweep). If it's
		-- already owned there's nothing to do -- saving and re-sending the
		-- whole inventory each time was flooding the DataStore queue.
		if amount == 0 and targetItem ~= "all" and session.OwnedItems
			and session.OwnedItems["Staffs_" .. tostring(targetItem)] then
			return
		end

		if targetItem == "all" then
			for _, itemName in ipairs(ALL_LAPIS_ITEMS) do
				InventoryService.Add(player, itemName, amount)
				session.OwnedItems["Staffs_" .. itemName] = true
			end
		elseif targetItem and ITEM_DATA[targetItem] then
			InventoryService.Add(player, targetItem, amount)
			session.OwnedItems["Staffs_" .. targetItem] = true
		end

		session.Inventory = InventoryService.Get(player)
		syncLapis(player, session.Inventory)
		saveLeaderstats(player, true)
		shopEvent:FireClient(player, "LoadData", session.OwnedItems, session.EquippedItem)
		shopEvent:FireClient(player, "Init", session.OwnedItems, session.EquippedItem)
		inventoryRemote:FireClient(player, "InitData", session)

	elseif action == "WipeData" then
		local leaderstats = player:FindFirstChild("leaderstats")
		local ppStat = leaderstats and leaderstats:FindFirstChild("PeacePoints")
		local ascStat = leaderstats and leaderstats:FindFirstChild("Ascensions")
		if ppStat then ppStat.Value = 0 end
		if ascStat then ascStat.Value = 0 end

		session.OwnedItems = { ["Staffs_normal_lapis"] = true }
		session.EquippedItem = "Staffs_normal_lapis"
		session.Godmode = false
		session.Inventory = {}
		session.Favorites = {}
		session.AutoSell = {}

		pcall(function()
			InventoryService.Clear(player)
		end)

		local _, lapisFolder, discoveredFolder = buildStatsFolder(player)
		for _, val in ipairs(lapisFolder:GetChildren()) do
			if val:IsA("IntValue") then val.Value = 0 end
		end
		for _, discVal in ipairs(discoveredFolder:GetChildren()) do
			if discVal:IsA("BoolValue") then 
				discVal.Value = (discVal.Name == "normal_lapis") 
			end
		end

		clearTools(player)
		equipSavedStaff(player)
		saveLeaderstats(player, true)

		shopEvent:FireClient(player, "LoadData", session.OwnedItems, session.EquippedItem)
		shopEvent:FireClient(player, "Init", session.OwnedItems, session.EquippedItem)
		inventoryRemote:FireClient(player, "InitData", session)
	end
end)

shopEvent.OnServerEvent:Connect(function(player, action, arg1, arg2)
	local userId = player.UserId
	local now = os.clock()
	if lastShopTimes[userId] and (now - lastShopTimes[userId] < 0.2) then return end
	lastShopTimes[userId] = now

	local session = playerSessionData[userId]
	if not session then return end

	if action == "Ascend" then
		if canAffordAscension(player) then
			performAscension(player)
		end
		return
	end

	if action == "BuyOrEquip" then
		local itemName = arg1
		local category = arg2 or "Staffs"

		if not ITEM_DATA[itemName] and ITEM_DATA[category] then
			category, itemName = itemName, category
		end
		category = category or "Staffs"

		local item = ITEM_DATA[itemName]
		if not item then return end

		local itemKey = category .. "_" .. itemName
		local isOwned = session.Godmode or session.OwnedItems[itemKey] or session.OwnedItems[itemName]
		local justPurchased = false

		local leaderstats = player:FindFirstChild("leaderstats")
		local peacePointsStat = leaderstats and leaderstats:FindFirstChild("PeacePoints")

		if not isOwned then
			if peacePointsStat and peacePointsStat.Value >= item.Cost then
				peacePointsStat.Value -= item.Cost
				session.OwnedItems[itemKey] = true
				justPurchased = true
			else
				shopEvent:FireClient(player, "BuyError", "NOT ENOUGH PEACEPOINTS!")
				return
			end
		end

		session.EquippedItem = itemKey
		equipTool(player, itemName, category)
		saveLeaderstats(player, true)

		if justPurchased then
			shopEvent:FireClient(player, "BuySuccess", itemName, category)
		else
			shopEvent:FireClient(player, "EquipSuccess", itemName, category)
		end
	end
end)

local function onPlayerAdded(player)
	local saved = loadLeaderstatsData(player)

	playerSessionData[player.UserId] = {
		OwnedItems = saved.OwnedItems,
		EquippedItem = saved.EquippedItem,
		Favorites = saved.Favorites,
		AutoSell = saved.AutoSell,
		Inventory = saved.Inventory,
		Godmode = saved.Godmode,
	}

	-- CRITICAL: wait for InventoryService's own DataStore load to
	-- finish before we touch this player's inventory in any way.
	-- InventoryService.PlayerAdded and this script's PlayerAdded both
	-- fire around the same time; without this wait, the merge below
	-- can run BEFORE InventoryService has loaded its saved data, then
	-- InventoryService's own load-merge (which assumes anything
	-- already present is a brand-new pickup) ADDS the real saved
	-- values on top of what we just wrote here -- silently doubling
	-- lapis counts on every join. This wait makes the two loads
	-- deterministic instead of a race.
	pcall(function()
		InventoryService.WaitUntilLoaded(player)
	end)

	-- Merge PlayerLeaderstats_v2's saved inventory into
	-- InventoryService rather than blindly overwriting it -- this is
	-- a one-time migration safety net for older saves. In normal
	-- operation these two should already agree, since both are
	-- always saved together right after InventoryService changes.
	if saved.Inventory and type(saved.Inventory) == "table" then
		pcall(function()
			local current = InventoryService.Get(player)
			local merged = {}

			for itemName, count in pairs(current) do
				merged[itemName] = count
			end

			for itemName, count in pairs(saved.Inventory) do
				if not merged[itemName] or count > merged[itemName] then
					merged[itemName] = count
				end
			end

			InventoryService.Set(player, merged)
		end)
	end

	if InventoryService and InventoryService.Changed then
		InventoryService.Changed:Connect(function(changedPlayer, newInventory)
			if changedPlayer == player then
				local session = playerSessionData[player.UserId]
				if session then
					session.Inventory = newInventory or {}
					syncLapis(player, session.Inventory)
					saveLeaderstats(player)
				end
			end
		end)
	end

	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- PeacePoints MUST be a NumberValue, not an IntValue.
	--
	-- IntValue is a signed 32-bit int, so it tops out at
	-- 2,147,483,647. The ending upgrade costs 3,000,000,000,
	-- which made the game literally unfinishable: the player
	-- could never hold enough PP to buy it, and any write past
	-- the cap threw "Unable to cast value to int". NumberValue
	-- is a double, so it counts exactly up to 2^53 -- about
	-- 9 quadrillion -- which is far beyond anything the
	-- economy can reach.
	--
	-- ensureNumberValue also REPLACES an IntValue left behind
	-- by an older build, so a live server picks the change up
	-- without anyone losing their balance.
	local peacePoints = ensureNumberValue(leaderstats, "PeacePoints")
	peacePoints.Value = saved.PeacePoints

	local ascensionPoints = leaderstats:FindFirstChild("Ascensions") or Instance.new("IntValue")
	ascensionPoints.Name = "Ascensions"
	ascensionPoints.Value = saved.Ascensions
	ascensionPoints.Parent = leaderstats

	local stats, _, discoveredFolder = buildStatsFolder(player)

	local statsPeace = ensureNumberValue(stats, "PeacePoints")
	statsPeace.Value = peacePoints.Value

	local statsAscensions = stats:FindFirstChild("Ascensions") or Instance.new("IntValue")
	statsAscensions.Name = "Ascensions"
	statsAscensions.Value = ascensionPoints.Value
	statsAscensions.Parent = stats

	-- leaderstats is the SOURCE OF TRUTH for both of these; PlayerStats
	-- is just a read-only mirror for the GUI. Both bindings must flow
	-- leaderstats -> PlayerStats, never the other way. The Ascensions
	-- one used to be backwards (PlayerStats -> leaderstats), which
	-- meant /reset setting leaderstats.Ascensions to 0 never reached
	-- the PlayerStats copy that SellServer reads its multiplier from --
	-- that's why an old ascension count (e.g. "x26") kept showing
	-- after a reset. Fixed to match PeacePoints' direction below.
	peacePoints:GetPropertyChangedSignal("Value"):Connect(function() statsPeace.Value = peacePoints.Value end)
	ascensionPoints:GetPropertyChangedSignal("Value"):Connect(function() statsAscensions.Value = ascensionPoints.Value end)

	if type(saved.Discovered) == "table" then
		for itemName, isDiscovered in pairs(saved.Discovered) do
			if isDiscovered then markDiscovered(discoveredFolder, itemName, true) end
		end
	end

	-- Reflect InventoryService's (now safely merged) copy into
	-- PlayerStats.Lapis, rather than trusting the raw saved table --
	-- this is what the UI and SellServer actually read from.
	syncLapis(player, InventoryService.Get(player))

	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		equipSavedStaff(player)
	end)

	if player.Character then
		task.spawn(function()
			task.wait(0.3)
			equipSavedStaff(player)
		end)
	end

	task.delay(0.5, function()
		if player:IsDescendantOf(Players) and playerSessionData[player.UserId] then
			local session = playerSessionData[player.UserId]
			inventoryRemote:FireClient(player, "InitData", session)
			shopEvent:FireClient(player, "LoadData", session.OwnedItems, session.EquippedItem)
			shopEvent:FireClient(player, "Init", session.OwnedItems, session.EquippedItem)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveLeaderstats(player, "now")
	playerSessionData[player.UserId] = nil
	lastSaveTimes[player.UserId] = nil
	lastEquipTimes[player.UserId] = nil
	lastShopTimes[player.UserId] = nil
	lastAscendTimes[player.UserId] = nil
end)

task.spawn(function()
	while true do
		task.wait(AUTO_SAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			saveLeaderstats(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveLeaderstats(player, "now")
	end
end)