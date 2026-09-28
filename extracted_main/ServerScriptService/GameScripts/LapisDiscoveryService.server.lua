--==================================================
-- LAPIS DISCOVERY  (server)
--
-- The first time you get each kind of lapis, your screen
-- shows a "NEW LAPIS UNLOCKED" card (LapisUnlockedPopup).
-- What you've found is remembered per player and wiped
-- every time you ascend, so each run discovers them again.
--
-- Hooks the two ways lapis reaches a player:
--   InventoryService.Add            (pickups, rewards, drops)
--   AutoSellService.TrySellOnPickup (sold the moment it's picked up)
-- Saved in the "LapisDiscovery_v1" DataStore as
--   { Asc = <ascension level it belongs to>, Seen = { name = true } }
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local GameScripts = script.Parent
local InventoryService = require(GameScripts:WaitForChild("InventoryService"))
local AutoSellService = require(GameScripts:WaitForChild("AutoSellService"))
local LapisConfig = require(ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("LapisDataModule"))

local events = ReplicatedStorage:WaitForChild("AccessibleEvents")
local remote = events:FindFirstChild("LapisDiscovered") or Instance.new("RemoteEvent")
remote.Name = "LapisDiscovered"
remote.Parent = events

local store
pcall(function() store = DataStoreService:GetDataStore("LapisDiscovery_v1") end)

local known = {}
for _, item in ipairs(LapisConfig.Items) do known[item.Name] = true end

local state = {} -- [player] = { Asc = n, Seen = {}, Loaded = bool, Dirty = bool }

local function ascensionsStat(player)
	local ls = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 30)
	return ls and (ls:FindFirstChild("Ascensions") or ls:WaitForChild("Ascensions", 10))
end

local function inventoryNames(player)
	local names = {}
	local stats = player:FindFirstChild("PlayerStats") or player:WaitForChild("PlayerStats", 10)
	local lapis = stats and (stats:FindFirstChild("Lapis") or stats:WaitForChild("Lapis", 10))
	if lapis then
		for _, v in ipairs(lapis:GetChildren()) do
			if v:IsA("ValueBase") and tonumber(v.Value) and v.Value > 0 then names[v.Name] = true end
		end
	end
	return names
end

local function save(player)
	local s = state[player]
	if not (s and s.Loaded and s.Dirty and store) then return end
	s.Dirty = false
	local seen = {}
	for name in pairs(s.Seen) do table.insert(seen, name) end
	pcall(function()
		store:SetAsync("u_" .. player.UserId, { Asc = s.Asc, Seen = seen })
	end)
end

local function discover(player, lapisType)
	local s = state[player]
	if not (s and s.Loaded) or not known[lapisType] or s.Seen[lapisType] then return end
	s.Seen[lapisType] = true
	s.Dirty = true
	remote:FireClient(player, lapisType)
end

local function onJoin(player)
	local stat = ascensionsStat(player)
	local asc = stat and stat.Value or 0
	local data
	if store then
		for _ = 1, 3 do
			local ok, res = pcall(function() return store:GetAsync("u_" .. player.UserId) end)
			if ok then data = res break end
			task.wait(2)
		end
	end
	if player.Parent ~= Players then return end
	local s = { Asc = asc, Seen = {}, Loaded = true, Dirty = false }
	if type(data) == "table" and data.Asc == asc and type(data.Seen) == "table" then
		for _, name in ipairs(data.Seen) do s.Seen[name] = true end
	else
		-- first time here (or a different run than the save): whatever's
		-- already in the inventory counts as found, so nothing pops up for it
		s.Seen = inventoryNames(player)
		s.Dirty = true
	end
	state[player] = s
	-- ascending wipes the lapis, so the discoveries start over too
	if stat then
		stat.Changed:Connect(function(v)
			local cur = state[player]
			if cur and v ~= cur.Asc then
				cur.Asc = v
				cur.Seen = {}
				cur.Dirty = true
				save(player)
			end
		end)
	end
end

Players.PlayerAdded:Connect(function(p) task.spawn(onJoin, p) end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onJoin, p) end
Players.PlayerRemoving:Connect(function(p)
	save(p)
	state[p] = nil
end)
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do save(p) end
end)
task.spawn(function()
	while true do
		task.wait(30)
		for p in pairs(state) do save(p) end
	end
end)

--------------------------------------------------
-- hooks
--------------------------------------------------
local add = InventoryService.Add
InventoryService.Add = function(player, lapisType, amount, ...)
	local result = add(player, lapisType, amount, ...)
	if player and lapisType and (amount == nil or amount > 0) then
		task.spawn(discover, player, lapisType)
	end
	return result
end

local trySell = AutoSellService.TrySellOnPickup
AutoSellService.TrySellOnPickup = function(player, itemName, amount, ...)
	local sold, earnings = trySell(player, itemName, amount, ...)
	if sold then task.spawn(discover, player, itemName) end
	return sold, earnings
end
