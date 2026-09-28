--==================================================
-- FAVORITE REWARD  (server)
--
-- Like + favorite BECOME LA PEACE and get 10,000 PP, once per
-- account. Roblox only lets the CLIENT check whether the game is
-- favorited (AvatarEditorService), so the client asks to claim
-- once it sees the favorite; this hands the PP out once, ever,
-- and remembers it in its own DataStore.
--   player attribute FavRewardClaimed: nil while loading, then true/false
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local REWARD = 10000
local store = DataStoreService:GetDataStore("FavoriteReward_v1")

local remote = ReplicatedStorage:FindFirstChild("FavoriteReward")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "FavoriteReward"
	remote.Parent = ReplicatedStorage
end

local busy = {}

local function load(player)
	local ok, v
	for _ = 1, 3 do
		ok, v = pcall(store.GetAsync, store, tostring(player.UserId))
		if ok then break end
		task.wait(2)
	end
	if player.Parent then player:SetAttribute("FavRewardClaimed", ok and v == true or false) end
	-- (if the store can't be read, leave it false: the claim itself checks again)
end

local function claim(player)
	if busy[player] or player:GetAttribute("FavRewardClaimed") ~= false then return end
	busy[player] = true
	-- once, ever: the DataStore decides (UpdateAsync, so two servers can't both pay out)
	local granted = false
	local ok = pcall(function()
		store:UpdateAsync(tostring(player.UserId), function(old)
			if old == true then return nil end
			granted = true
			return true
		end)
	end)
	if ok and granted then
		local ls = player:FindFirstChild("leaderstats")
		local pp = ls and ls:FindFirstChild("PeacePoints")
		local tries = 0
		while not pp and tries < 20 and player.Parent do
			task.wait(0.5)
			tries += 1
			ls = player:FindFirstChild("leaderstats")
			pp = ls and ls:FindFirstChild("PeacePoints")
		end
		if pp then
			pp.Value += REWARD
			print(("[FavoriteReward] +%d PP -> %s"):format(REWARD, player.Name))
		end
		player:SetAttribute("FavRewardClaimed", true)
		remote:FireClient(player, "Granted", REWARD)
	elseif ok then
		player:SetAttribute("FavRewardClaimed", true)
	end
	busy[player] = nil
end

remote.OnServerEvent:Connect(function(player, action)
	if action == "Claim" then task.spawn(claim, player) end
end)

Players.PlayerAdded:Connect(function(p) task.spawn(load, p) end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(load, p) end
Players.PlayerRemoving:Connect(function(p) busy[p] = nil end)
