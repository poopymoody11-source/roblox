--==================================================
-- AUTOSELL SERVICE
--
-- Why AutoSell did nothing: the toggle state was being
-- written to THREE different places and read by none of
-- them for the purpose of selling.
--
--   InventoryServer.playerAutoSell    -- in memory, never saved, never read
--   FavoriteDataServer.sessionData    -- saved to PlayerInventorySettings_v2
--   LeaderboardStats session.AutoSell -- a third copy, also unused
--
-- ...and there are two different RemoteEvents both named
-- "InventoryRemote" (one directly under ReplicatedStorage,
-- one under ReplicatedStorage.Remotes), so depending on
-- which one the client fired, one of the two servers never
-- even heard the toggle.
--
-- This module is now the one thing that decides whether an
-- item is auto-sold. It listens on BOTH remotes, seeds
-- itself from the data FavoriteDataServer already persists
-- (so existing players keep their settings and there is
-- still exactly one writer to that key), and actually
-- performs the sale.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local AutoSellService = {}

local CONFIG = {
	-- Sweep interval for items flagged while already sitting in the
	-- inventory (flag a type you own 500 of -> they get sold).
	SWEEP_INTERVAL = 2,
	NOTIFY_ON_PICKUP_SALE = false,  -- true = a toast per pickup (spammy)
	NOTIFY_ON_SWEEP_SALE = true,
}

--==================================================
-- DEPENDENCIES
--==================================================

local GameScripts = ServerScriptService:WaitForChild("GameScripts")
local InventoryService = require(GameScripts:WaitForChild("InventoryService"))

local modules = ReplicatedStorage:WaitForChild("AccessibleModules")
local LapisConfig = require(modules:WaitForChild("LapisDataModule"))
local AscensionData = require(modules:WaitForChild("AscensionDataModule"))
local Monetization = require(modules:WaitForChild("MonetizationData"))

--==================================================
-- GAMEPASS GATE
--
-- Auto-selling is the Auto Sell gamepass. The toggle
-- still saves and still shows as ticked without the
-- pass -- taking the checkbox away would make the
-- feature invisible and nobody would know it exists --
-- but nothing is actually sold until the pass is owned.
--
-- Flip REQUIRE_PASS to false to hand auto-sell to
-- everyone (e.g. for a free weekend).
--==================================================

local REQUIRE_PASS = true

local function canAutoSell(player)
	if not REQUIRE_PASS then return true end
	return Monetization.Owns(player, "AutoSell")
end

function AutoSellService.CanAutoSell(player)
	return canAutoSell(player)
end

local values = {}
for _, item in ipairs(LapisConfig.Items) do
	values[item.Name] = item.Value
end

local sellRemote = ReplicatedStorage:FindFirstChild("SellRemote")

--==================================================
-- STATE (shared with FavoriteDataServer)
--
-- The flags now live in ONE table (InvSettingsState) that
-- FavoriteDataServer loads, saves and toggles. This service
-- used to keep its own copy, flipped on every toggle; the
-- two drifted (missed InitData, relocked items after an
-- ascension, etc.) and items the UI showed as NOT autosell
-- kept getting sold.
--==================================================

local sessionData = require(GameScripts:WaitForChild("InvSettingsState"))

local function isDiscovered(player, itemName)
	local stats = player:FindFirstChild("PlayerStats")
	local disc = stats and stats:FindFirstChild("Discovered")
	local v = disc and disc:FindFirstChild(itemName)
	return v ~= nil and v.Value == true
end

function AutoSellService.IsAutoSell(player, itemName)
	local data = sessionData[player.UserId]
	if not (data and data.Loaded and data.AutoSell) then return false end
	if data.AutoSell[itemName] ~= true then return false end
	if data.Favorites and data.Favorites[itemName] then return false end
	-- The inventory UI hides the autosell badge on locked items,
	-- so never sell something the player can't see is flagged.
	return isDiscovered(player, itemName)
end

function AutoSellService.SetAutoSell(player, itemName, on)
	local data = sessionData[player.UserId]
	if not (data and data.AutoSell) then return end
	data.AutoSell[itemName] = on and true or nil
end

-- An ascension relocks items and the client wipes their badges;
-- drop the matching server flags so the two stay identical.
local function watchDiscovery(player)
	local stats = player:WaitForChild("PlayerStats", 30)
	local disc = stats and stats:WaitForChild("Discovered", 30)
	if not disc then return end
	local function hook(v)
		if not v:IsA("BoolValue") then return end
		local was = v.Value
		v.Changed:Connect(function()
			if was and not v.Value then
				AutoSellService.SetAutoSell(player, v.Name, false)
				local data = sessionData[player.UserId]
				if data and data.Favorites then data.Favorites[v.Name] = nil end
			end
			was = v.Value
		end)
	end
	for _, v in ipairs(disc:GetChildren()) do hook(v) end
	disc.ChildAdded:Connect(hook)
end

Players.PlayerAdded:Connect(function(p) task.spawn(watchDiscovery, p) end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(watchDiscovery, p) end

--==================================================
-- SELLING
--==================================================

local function creditPP(player, itemName, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	local pp = leaderstats and leaderstats:FindFirstChild("PeacePoints")
	if not pp then return 0, 1 end

	local ascStat = leaderstats:FindFirstChild("Ascensions")
		or leaderstats:FindFirstChild("Rebirths")

	-- Same stack as manual selling: ascension bonus x any
	-- money pass. Auto-sold lapis must be worth exactly what
	-- hand-sold lapis is worth, or the pass quietly costs the
	-- player money.
	local multiplier = AscensionData.GetMultiplier(ascStat and ascStat.Value or 0)
		* Monetization.GetMoneyMultiplier(player)

	local unit = values[itemName] or 0
	local earnings = math.floor(unit * amount * multiplier)

	pp.Value = pp.Value + earnings
	return earnings, multiplier
end

local function notify(player, itemName, amount, earnings, multiplier)
	if not sellRemote then
		sellRemote = ReplicatedStorage:FindFirstChild("SellRemote")
	end
	if sellRemote then
		sellRemote:FireClient(player, "SellSuccess", itemName, amount, earnings, multiplier)
	end
end

-- Called from LapisPickupService BEFORE the lapis reaches the
-- inventory. Returns true if it was sold instead of stored.
function AutoSellService.TrySellOnPickup(player, itemName, amount)
	if not canAutoSell(player) then
		return false
	end
	if not AutoSellService.IsAutoSell(player, itemName) then
		return false
	end
	if values[itemName] == nil then
		return false
	end

	amount = amount or 1
	local earnings, multiplier = creditPP(player, itemName, amount)

	if CONFIG.NOTIFY_ON_PICKUP_SALE then
		notify(player, itemName, amount, earnings, multiplier)
	end
	return true, earnings
end

-- Catches everything the pickup hook doesn't: items already held when
-- the flag is switched on, mob drops, admin grants, etc.
local function sweep(player)
	if not canAutoSell(player) then return end
	local data = sessionData[player.UserId]
	if not (data and data.AutoSell) then return end

	for itemName in pairs(data.AutoSell) do
		if AutoSellService.IsAutoSell(player, itemName) then
			local held = InventoryService.GetCount(player, itemName)
			if held > 0 then
				if InventoryService.Remove(player, itemName, held) then
					local earnings, multiplier = creditPP(player, itemName, held)
					if CONFIG.NOTIFY_ON_SWEEP_SALE then
						notify(player, itemName, held, earnings, multiplier)
					end
				end
			end
		end
	end
end

task.spawn(function()
	while task.wait(CONFIG.SWEEP_INTERVAL) do
		for _, player in ipairs(Players:GetPlayers()) do
			pcall(sweep, player)
		end
	end
end)

return AutoSellService
