--==================================================
-- ZONE WALKSPEED
--
-- Every island gives you its own walk speed (set in
-- ReplicatedStorage.AccessibleModules.ZoneData):
--   Starter 28  ->  67 Island 32  ->  Verity 36  ->  LaPeace 42
--
-- The old version used .Touched on the huge Walkboxes parts,
-- which misses teleports and respawns, so you could keep the
-- wrong speed. This checks where you actually are 4x a second.
--
-- It never overrides a WalkSpeed of 0 -- cutscenes and the
-- teleport freeze use that to lock you in place.
-- Also publishes the zone name as the "Zone" attribute on the
-- player (used by the lapis spawner and anything else).
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneData = require(ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("ZoneData"))

--==================================================
-- LOCKED ISLANDS
-- The teleport menu gates islands by ascensions, but the
-- Elytra let you just fly there. Standing inside a locked
-- island's zone for a moment sends you home with the same
-- message the teleport menu would show.
--==================================================
local AscensionData, Monetization
pcall(function() AscensionData = require(ReplicatedStorage.AccessibleModules:WaitForChild("AscensionDataModule")) end)
pcall(function() Monetization = require(ReplicatedStorage.AccessibleModules:WaitForChild("MonetizationData")) end)
local teleportRemote = ReplicatedStorage:WaitForChild("AccessibleEvents"):WaitForChild("TeleportRequest", 30)

local function ascensions(player)
	local ls = player:FindFirstChild("leaderstats")
	local s = ls and (ls:FindFirstChild("Ascensions") or ls:FindFirstChild("Rebirths"))
	return s and s.Value or 0
end

local function lockedFor(player, zone)
	if zone == ZoneData.Default then return false end
	local need = AscensionData and AscensionData.Islands and AscensionData.Islands[zone.Name]
	if not need or ascensions(player) >= need then return false end
	if Monetization and Monetization.HasIslandAccess and Monetization.HasIslandAccess(player, zone.Name) then return false end
	return true, need
end

local function homeCFrame(player)
	local plots = workspace.Islands.StarterIsland:FindFirstChild("IslandPlots")
	for _, plot in ipairs(plots and plots:GetChildren() or {}) do
		local owner = plot:FindFirstChild("Owner")
		if owner and owner.Value == player.Name and plot:FindFirstChild("Hitbox") then
			return CFrame.new(plot.Hitbox.Position.X, 140, plot.Hitbox.Position.Z)
		end
	end
	local pts = workspace:FindFirstChild("TeleportPoints")
	local home = pts and pts:FindFirstChild("Home")
	return home and (home.CFrame + Vector3.new(0, 3, 0)) or nil
end

local trespassSince = {}

-- Faster on the lapis fields themselves (the LapisSpawnBox pads), so
-- running around collecting feels snappier. x the island's speed.
local LAPIS_FIELD_SPEED_MULT = 1.25 -- (the base speeds are much higher now)
local spawnBox = workspace:WaitForChild("LapisSpawnBox", 30)
local HEIGHT_PADDING = 60
local function onLapisField(pos)
	if not spawnBox then return false end
	for _, d in ipairs(spawnBox:GetDescendants()) do
		if d:IsA("BasePart") then
			local rel = d.CFrame:PointToObjectSpace(pos)
			local h = d.Size / 2
			if math.abs(rel.X) <= h.X and math.abs(rel.Z) <= h.Z and rel.Y >= -h.Y - 2 and rel.Y <= h.Y + HEIGHT_PADDING then
				return true
			end
		end
	end
	return false
end

local lastZone = {}

local function update(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end

	local zone = ZoneData.At(root.Position)
	if lastZone[player] ~= zone then
		lastZone[player] = zone
		player:SetAttribute("Zone", zone.Name)
	end

	local locked, need = lockedFor(player, zone)
	if locked then
		trespassSince[player] = trespassSince[player] or os.clock()
		if os.clock() - trespassSince[player] > 0.75 then
			trespassSince[player] = nil
			local cf = homeCFrame(player)
			if cf then
				character:PivotTo(cf)
				root.AssemblyLinearVelocity = Vector3.zero
			end
			if teleportRemote then
				teleportRemote:FireClient(player, false, ("%s is locked -- it needs %d ascension%s. You have %d."):format(
					zone.Name, need, need == 1 and "" or "s", ascensions(player)))
			end
			return
		end
	else
		trespassSince[player] = nil
	end

	-- 0 = frozen by a cutscene / teleport; leave it alone
	local speed = zone.WalkSpeed
	if onLapisField(root.Position) then
		speed = math.floor(speed * LAPIS_FIELD_SPEED_MULT + 0.5)
	end
	if humanoid.WalkSpeed ~= 0 and humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
end

Players.PlayerRemoving:Connect(function(player)
	lastZone[player] = nil
	trespassSince[player] = nil
end)

while true do
	for _, player in ipairs(Players:GetPlayers()) do
		pcall(update, player)
	end
	task.wait(0.25)
end
