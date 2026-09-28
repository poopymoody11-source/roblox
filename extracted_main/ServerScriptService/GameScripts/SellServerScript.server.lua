--==================================================
-- SELL SERVER SCRIPT (INVENTORY SAVE FIX)
-- Place in: ServerScriptService > SellServer
-- Type: Script (Server Script)
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local AscensionData = require(
	ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("AscensionDataModule")
)

local Monetization = require(
	ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("MonetizationData")
)

-- Require LapisDataModule safely
local accessibleModules = ReplicatedStorage:WaitForChild("AccessibleModules", 10)
local lapisDataModule = accessibleModules and accessibleModules:WaitForChild("LapisDataModule", 10)
local LapisConfig = lapisDataModule and require(lapisDataModule) or nil

-- Find InventoryService
local function findInventoryModule()
	local nested = ServerScriptService:FindFirstChild("InventoryService", true)
	if nested then return nested end
	return ServerStorage:FindFirstChild("InventoryService", true)
end

local invModule = findInventoryModule()
local InventoryService = invModule and require(invModule) or nil

-- Ensure SellRemote exists in ReplicatedStorage
local sellRemote = ReplicatedStorage:FindFirstChild("SellRemote")
if not sellRemote then
	sellRemote = Instance.new("RemoteEvent")
	sellRemote.Name = "SellRemote"
	sellRemote.Parent = ReplicatedStorage
end

local DEFAULT_PRICE = 10

local function getItemPrice(itemName)
	if not LapisConfig or not LapisConfig.Items then
		return DEFAULT_PRICE
	end

	for _, itemData in ipairs(LapisConfig.Items) do
		if itemData.Name == itemName and itemData.Value then
			return itemData.Value
		end
	end

	return DEFAULT_PRICE
end

-- SELL EVERYTHING: the client sends the lapis it wants gone (it leaves out
-- favorites); every one is re-checked here and sold in full
local selling = {}
sellRemote.OnServerEvent:Connect(function(player, action, names)
	if action ~= "SellMany" or type(names) ~= "table" or not InventoryService or selling[player] then return end
	selling[player] = true
	local leaderstats = player:FindFirstChild("leaderstats")
	local peacePoints = leaderstats and leaderstats:FindFirstChild("PeacePoints")
	local ascensionsVal = leaderstats and leaderstats:FindFirstChild("Ascensions")
	if not peacePoints then selling[player] = nil return end
	local multiplier = AscensionData.GetMultiplier(ascensionsVal and ascensionsVal.Value or 0) * Monetization.GetMoneyMultiplier(player)
	local totalCount, totalEarnings, kinds = 0, 0, 0
	local done = {}
	for i, itemName in ipairs(names) do
		if i > 200 then break end
		if type(itemName) == "string" and not done[itemName] then
			done[itemName] = true
			local owned = InventoryService.GetCount(player, itemName)
			if owned and owned > 0 then
				local earnings = math.floor(getItemPrice(itemName) * owned * multiplier)
				if InventoryService.Remove(player, itemName, owned) then
					peacePoints.Value += earnings
					totalCount += owned
					totalEarnings += earnings
					kinds += 1
				end
			end
		end
	end
	selling[player] = nil
	sellRemote:FireClient(player, "SellAllSuccess", kinds, totalCount, totalEarnings, multiplier)
end)
Players.PlayerRemoving:Connect(function(p) selling[p] = nil end)

sellRemote.OnServerEvent:Connect(function(player, action, itemName, amount)
	if action ~= "SellItem" then return end

	-- Input Validation
	if type(itemName) ~= "string" or type(amount) ~= "number" then return end
	amount = math.floor(amount)
	if amount <= 0 then return end

	if not InventoryService then return end

	-- Check against InventoryService -- the single source of truth --
	-- not the mirrored PlayerStats.Lapis IntValue.
	local owned = InventoryService.GetCount(player, itemName)
	if owned < amount then return end

	-- leaderstats is the AUTHORITATIVE copy of PeacePoints/Ascensions.
	-- PlayerStats is only a read-only mirror kept in sync by
	-- LeaderstatsSetup. Reading/writing the mirror here was the bug:
	-- writing to PlayerStats.PeacePoints never touched the real
	-- leaderstats value, so no PP was actually granted. Likewise the
	-- Ascensions mirror could go stale (see LeaderstatsSetup fix), so
	-- read the multiplier from leaderstats directly to be safe.
	local leaderstats = player:FindFirstChild("leaderstats")
	local peacePoints = leaderstats and leaderstats:FindFirstChild("PeacePoints")
	local ascensionsVal = leaderstats and leaderstats:FindFirstChild("Ascensions")

	if not peacePoints then return end

	local ascensionsCount = ascensionsVal and ascensionsVal.Value or 0
	local multiplier = AscensionData.GetMultiplier(ascensionsCount)

	-- 2x Money and any future multiplier pass stack on top of
	-- the ascension multiplier. Floor the result: PeacePoints is
	-- a NumberValue now, so without this a x1.5 ascension bonus
	-- would start leaving fractional PP in the player's balance.
	local passMultiplier = Monetization.GetMoneyMultiplier(player)
	multiplier = multiplier * passMultiplier

	local pricePerUnit = getItemPrice(itemName)
	local totalEarnings = math.floor(pricePerUnit * amount * multiplier)

	-- 1. Credit PeacePoints on the AUTHORITATIVE leaderstats value.
	--    This automatically flows down to the PlayerStats mirror via
	--    the property-changed binding in LeaderstatsSetup.
	peacePoints.Value = peacePoints.Value + totalEarnings

	-- 2. Remove from InventoryService ONLY. Do not also hand-edit
	--    PlayerStats.Lapis[itemName].Value here -- InventoryService.Remove
	--    fires Changed, which LeaderstatsSetup listens to in order to
	--    update PlayerStats.Lapis AND persist the save.
	local removed = InventoryService.Remove(player, itemName, amount)

	if not removed then
		-- Someone/something changed the count between our check above
		-- and now (e.g. two rapid sell clicks) -- refund and bail.
		peacePoints.Value = peacePoints.Value - totalEarnings
		return
	end

	-- Notify Client
	sellRemote:FireClient(player, "SellSuccess", itemName, amount, totalEarnings, multiplier)
end)