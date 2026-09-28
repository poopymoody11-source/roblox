--==================================================
-- LOCAL LAPIS SERVICE  (server)
--
-- Ambient lapis is now PER PLAYER and drawn only on that
-- player's own screen (LocalLapisClient). The server never
-- creates a model for them: it keeps a tiny ledger per player
-- (id -> type + spot), tells that player's client where each
-- one is, and checks every pickup the client asks for before
-- paying out through the same InventoryService / AutoSell path
-- the old pickups used.
--
-- Why:
--   * nobody can snipe your lapis, and a full server doesn't
--     thin everyone's spawns out
--   * no replication cost, so there can be MUCH more of it
--   * lapis keeps spawning whether you're moving or not (the old
--     "stand still = no spawns" AFK rule was removed)
--
-- Mob / drop lapis (RequestLapisSpawn) is still spawned by the
-- old LapisSpawner as shared server lapis.
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("AccessibleModules")
local LapisConfig = require(Modules:WaitForChild("LapisDataModule"))
local ZoneData = require(Modules:WaitForChild("ZoneData"))
local GameScripts = script.Parent
local InventoryService = require(GameScripts:WaitForChild("InventoryService"))
local AutoSellService = require(GameScripts:WaitForChild("AutoSellService"))

--==================================================
-- TUNING
--==================================================
-- (was 4x / 4x / 520: raised for a fuller map; ascension costs went up
-- x1.3 in AscensionDataModule to keep the run to the Final Boss ~25 min)
-- An island fills up FAST the first time (so it looks full when you
-- arrive), but once a lapis type has hit its cap, anything you pick up
-- grows back at the much slower REGEN rate. Before this, a full field
-- refilled at the fill rate, so sweeping it with a magnet was an
-- endless money tap.
local SPAWN_MULT = 6      -- x the LapisDataModule spawn rates while an island is first filling
local REGEN_MULT = 1.5    -- x the LapisDataModule spawn rates after that
local CAP_MULT = 6        -- x the LapisDataModule caps, per player...
local CAP_OVERRIDE = {    -- ...except the heavy models (hundreds of parts each)
	-- 67 Island was a lot (each 67 lapis carries ~240 particle emitters):
	-- fewer on the ground at once there
	["67_lapis"] = 20,
	hell_lapis = 55,
	totem_lapis = 38,
	interstellar_lapis = 20,
	malevolent_lapis = 28,
	lapeace_lapis = 9,
	rgb_lapis = 18,
}
-- extra spawn rate for the rarer lapis on each island (x on top of
-- SPAWN_MULT / REGEN_MULT) so you actually see them now and then
local RARE_BOOST = {
	diamond_lapis = 2,
	hell_lapis = 1.6, totem_lapis = 2.5,
	emerald_lapis = 2, rgb_lapis = 3,
	malevolent_lapis = 1.6, interstellar_lapis = 2.5, lapeace_lapis = 3,
}
local MAX_PER_PLAYER = 760    -- hard ceiling on one player's live lapis
local TICK = 0.2
local MOVE_EPS = 3            -- studs that count as "moved"
local WALK_REACH = 9          -- pickup check slack on foot
local REACH_SLACK = 30        -- extra slack on top of a staff's magnet radius (lag)
local COLLECT_BUDGET = 40     -- pickups per second a client may claim (burst)

-- the pads (same radii as the old LapisSpawner.PAD_CONFIG)
local PADS = {
	A = { MinRadius = 55, MaxRadius = 170 },
	B = { MinRadius = 0,  MaxRadius = 300 },
	C = { MinRadius = 0,  MaxRadius = 300 },
	D = { MinRadius = 0,  MaxRadius = 300 },
}
local PAD_OF = {
	normal_lapis = "A", golden_lapis = "A", diamond_lapis = "A",
	verity_lapis = "B", rgb_lapis = "B", emerald_lapis = "B",
	["67_lapis"] = "C", hell_lapis = "C", totem_lapis = "C",
	lapeace_lapis = "D", malevolent_lapis = "D", interstellar_lapis = "D",
}

--==================================================
-- REMOTE
--==================================================
local remote = ReplicatedStorage:FindFirstChild("LocalLapis")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "LocalLapis"
	remote.Parent = ReplicatedStorage
end

local byName = {}
for _, item in ipairs(LapisConfig.Items) do byName[item.Name] = item end

local spawnBox = workspace:WaitForChild("LapisSpawnBox")
local function padBounds(padName)
	local pad = spawnBox:FindFirstChild(padName)
	if not pad then return nil end
	if pad:IsA("Model") then return pad:GetBoundingBox() end
	if pad:IsA("BasePart") then return pad.CFrame, pad.Size end
	return nil
end

local rng = Random.new()
local payOut -- (defined below)
local function randomPoint(padName)
	local cf, size = padBounds(padName)
	if not cf then return nil end
	local cfg = PADS[padName] or {}
	local maxPhys = math.min(size.X, size.Z) / 2
	local minR = math.clamp(cfg.MinRadius or 0, 0, maxPhys)
	local maxR = math.clamp(cfg.MaxRadius or 15, minR + 0.1, maxPhys)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = math.sqrt(rng:NextNumber() * (maxR ^ 2 - minR ^ 2) + minR ^ 2)
	return cf:PointToWorldSpace(Vector3.new(math.cos(a) * r, size.Y / 2, math.sin(a) * r))
end

--==================================================
-- PER-PLAYER LEDGER
--==================================================
-- The ledger is kept for EVERY island you've been on. Leaving an island
-- only hides its lapis on your screen; coming back shows the same ones
-- again. (It used to wipe the island, which also reset its refill.)
local state = {} -- [player] = { Items = {[id] = {Name, Pos, Pad, Yaw}}, Count = {[name] = n}, PadTotal = {[pad] = n}, Filled = {[name] = true}, NextId, Zone, Acc = {}, Budget, Queue = {} }

local function newState(player)
	state[player] = { Items = {}, Count = {}, PadTotal = {}, Filled = {}, NextId = 0, Zone = nil, Acc = {}, Budget = COLLECT_BUDGET, Queue = {} }
end

-- (re)send one island's lapis to the client, in one message
local function sendPad(player, s, padName)
	local batch = {}
	for id, e in pairs(s.Items) do
		if e.Pad == padName then
			table.insert(batch, { id, e.Name, e.Pos, e.Yaw })
		end
	end
	remote:FireClient(player, "Clear")
	if #batch > 0 then remote:FireClient(player, "SpawnMany", batch) end
end

local function spawnFor(player, s, item, padName)
	local pos = randomPoint(padName)
	if not pos then return end
	s.NextId += 1
	local id = s.NextId
	local yaw = rng:NextInteger(0, 359)
	s.Items[id] = { Name = item.Name, Pos = pos, Pad = padName, Yaw = yaw }
	s.Count[item.Name] = (s.Count[item.Name] or 0) + 1
	s.PadTotal[padName] = (s.PadTotal[padName] or 0) + 1
	remote:FireClient(player, "Spawn", id, item.Name, pos, yaw)
end

local function rootOf(player)
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if r and h and h.Health > 0 then return r end
	return nil
end

local function reachFor(player)
	local c = player.Character
	local tool = c and c:FindFirstChildOfClass("Tool")
	local radius = tool and tool:GetAttribute("MagnetRadius")
	return radius and (radius + REACH_SLACK) or WALK_REACH
end

--==================================================
-- PAYOUT (declared before the loop uses it)
--==================================================
payOut = function(player, s, id)
	local entry = s.Items[id]
	if not entry then return end
	s.Budget -= 1
	s.Items[id] = nil
	s.Count[entry.Name] = math.max(0, (s.Count[entry.Name] or 1) - 1)
	s.PadTotal[entry.Pad] = math.max(0, (s.PadTotal[entry.Pad] or 1) - 1)
	local soldOnPickup, soldFor = AutoSellService.TrySellOnPickup(player, entry.Name, 1)
	if not soldOnPickup then
		InventoryService.Add(player, entry.Name, 1)
	end
	remote:FireClient(player, "Collected", id, soldOnPickup and (soldFor or 0) or nil)
end

--==================================================
-- SPAWN LOOP
--==================================================
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < TICK then return end
	local step = acc
	acc = 0
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local s = state[player]
		if not s then continue end
		s.Budget = math.min(COLLECT_BUDGET, s.Budget + COLLECT_BUDGET * step)
		local root = rootOf(player)
		if not root then continue end

		local pos = root.Position

		-- only the island you're standing on spawns for you (and is drawn)
		local zone = ZoneData.At(pos)
		if zone ~= s.Zone then
			s.Zone = zone
			sendPad(player, s, zone.Pad)
		end
		local padName = zone.Pad
		for _, item in ipairs(LapisConfig.Items) do
			if PAD_OF[item.Name] == padName then
				local cap = CAP_OVERRIDE[item.Name] or math.floor(item.MaxCap * CAP_MULT)
				local count = s.Count[item.Name] or 0
				if count >= cap then s.Filled[item.Name] = true end
				local mult = s.Filled[item.Name] and REGEN_MULT or SPAWN_MULT
				local rate = (item.RarityChance / 100) / item.SpawnDelay * mult * (RARE_BOOST[item.Name] or 1)
				s.Acc[item.Name] = (s.Acc[item.Name] or 0) + rate * step
				while s.Acc[item.Name] >= 1 do
					s.Acc[item.Name] -= 1
					if (s.Count[item.Name] or 0) < cap and (s.PadTotal[padName] or 0) < MAX_PER_PLAYER then
						spawnFor(player, s, item, padName)
					else
						s.Acc[item.Name] = 0
					end
				end
			end
		end

		-- pickups that came in faster than the budget wait here instead
		-- of bouncing back (a big magnet grabs hundreds at once)
		while #s.Queue > 0 and s.Budget >= 1 do
			local id = table.remove(s.Queue, 1)
			payOut(player, s, id)
		end
	end
end)

--==================================================
-- PICKUPS
--==================================================
remote.OnServerEvent:Connect(function(player, action, id)
	local s = state[player]
	if not s then return end
	if action == "Ready" then
		-- (a fresh client: redraw the island you're on)
		s.Zone = nil
		return
	end
	if action ~= "Collect" or type(id) ~= "number" then return end
	local entry = s.Items[id]
	if not entry then return end
	local root = rootOf(player)
	local ok = root ~= nil
	if ok then
		local d = (root.Position - entry.Pos).Magnitude
		ok = d <= reachFor(player) + 8
	end
	if not ok then
		remote:FireClient(player, "Reject", id)
		return
	end
	if s.Budget >= 1 and #s.Queue == 0 then
		payOut(player, s, id)
	elseif #s.Queue < 400 then
		table.insert(s.Queue, id)
	end
end)

Players.PlayerAdded:Connect(newState)
for _, p in ipairs(Players:GetPlayers()) do newState(p) end
Players.PlayerRemoving:Connect(function(p) state[p] = nil end)
