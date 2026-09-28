--==================================================
-- ISLAND SEEN  (server)
-- Remembers which islands a player has already been told about, so the
-- "NEW ISLAND!" pill by the TP button only pops for islands that are
-- open to them and that they haven't looked at yet - across sessions.
-- Mirrored on the player as the "SeenIslands" attribute ("67,verity").
--==================================================
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("IslandSeen")
local store
pcall(function() store = DataStoreService:GetDataStore("IslandSeen_v1") end)

local VALID = { ["67"] = true, verity = true, lapeace = true }
local seen = {}

local function publish(p)
	local list = {}
	for k in pairs(seen[p] or {}) do table.insert(list, k) end
	table.sort(list)
	p:SetAttribute("SeenIslands", table.concat(list, ","))
end

Players.PlayerAdded:Connect(function(p)
	seen[p] = {}
	if store then
		local ok, data = pcall(function() return store:GetAsync(tostring(p.UserId)) end)
		if ok and type(data) == "table" then
			for _, k in ipairs(data) do if VALID[k] then seen[p][k] = true end end
		end
	end
	publish(p)
	p:SetAttribute("SeenIslandsLoaded", true)
end)

remote.OnServerEvent:Connect(function(p, keys)
	if type(keys) ~= "table" or not seen[p] then return end
	local changed = false
	for _, k in ipairs(keys) do
		if VALID[k] and not seen[p][k] then seen[p][k] = true changed = true end
	end
	if not changed then return end
	publish(p)
	if store then
		local list = {}
		for k in pairs(seen[p]) do table.insert(list, k) end
		task.spawn(function() pcall(function() store:SetAsync(tostring(p.UserId), list) end) end)
	end
end)

Players.PlayerRemoving:Connect(function(p) seen[p] = nil end)

-- (the admin panel's WIPE DATA starts you over: every island is new again)
task.spawn(function()
	local b = game:GetService("ServerStorage"):WaitForChild("AdminActionBindable", 30)
	if not b then return end
	b.Event:Connect(function(target, action)
		if action ~= "WipeData" or typeof(target) ~= "Instance" or not seen[target] then return end
		seen[target] = {}
		publish(target)
		if store then task.spawn(function() pcall(function() store:RemoveAsync(tostring(target.UserId)) end) end) end
	end)
end)
