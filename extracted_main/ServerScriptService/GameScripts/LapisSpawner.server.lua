--==================================================
-- LAPIS SPAWNER (Script-Configured Radius & Lapis Types)
--
-- Place in: ServerScriptService (as a Script)
--==================================================

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LapisConfig = require(
	ReplicatedStorage
		:WaitForChild("AccessibleModules")
		:WaitForChild("LapisDataModule")
)

--==================================================
-- CONFIGURATION
--==================================================

local CONFIG = {
	FOLDER_NAME = "SpawnedLapis",
	ROTATION_SPEED = 90,   -- degrees/sec
	BOB_HEIGHT = 2.5,
	BOB_SPEED = 2,         -- bobs/sec-ish

	-- GLOBAL DEFAULT RADIUS IN STUDS
	DEFAULT_MIN_RADIUS = 0,    -- Studs from center
	DEFAULT_MAX_RADIUS = 15,   -- Studs from center

	-- PER-PAD CONFIGURATION
	-- Set Radius (in Studs) and specific Lapis items per pad here.
	-- Lapis can be a single string "LapisName" or a table {"Lapis1", "Lapis2"}
	PAD_CONFIG = {
		["A"] = { MinRadius = 55, MaxRadius = 170, Lapis = {"normal_lapis","golden_lapis", "diamond_lapis"} },
		["B"] = { MinRadius = 0,  MaxRadius = 300, Lapis = {"verity_lapis", "rgb_lapis", "emerald_lapis"} },
		["C"] = { MinRadius = 0,  MaxRadius = 300, Lapis = {"67_lapis", "hell_lapis", "totem_lapis"} },
		["D"] = { MinRadius = 0,  MaxRadius = 300, Lapis = {"lapeace_lapis", "malevolent_lapis", "interstellar_lapis"} }, 
	},

	FLOOR_RAYCAST_DISTANCE = 500,
	POINT_DROP_JITTER = 2,
}

local LapisFolder = ServerStorage
	:WaitForChild("AccessibleModels")
	:WaitForChild("Lapis")

local SpawnBoxFolder = Workspace:WaitForChild("LapisSpawnBox")

local AccessibleEvents = ReplicatedStorage:WaitForChild("AccessibleEvents")

local spawnedLapis = Workspace:FindFirstChild(CONFIG.FOLDER_NAME)

if not spawnedLapis then
	spawnedLapis = Instance.new("Folder")
	spawnedLapis.Name = CONFIG.FOLDER_NAME
	spawnedLapis.Parent = Workspace
end

--==================================================
-- REQUEST API
--==================================================

local RequestLapisSpawn = AccessibleEvents:FindFirstChild("RequestLapisSpawn")

if not RequestLapisSpawn then
	RequestLapisSpawn = Instance.new("BindableEvent")
	RequestLapisSpawn.Name = "RequestLapisSpawn"
	RequestLapisSpawn.Parent = AccessibleEvents
end

--==================================================
-- ITEM LOOKUP + COOLDOWN TRACKING
--==================================================

local itemLookup = {}

for _, item in ipairs(LapisConfig.Items) do
	itemLookup[item.Name] = item
end

local lastSpawnTimes = {}

--==================================================
-- SCALE WITH PLAYER COUNT
-- Caps were global, so every extra player in the server meant
-- less lapis for everyone. Each player past the first adds +50%
-- to every cap and spawns that much faster, up to 3x.
--==================================================
local Players = game:GetService("Players")
local function playerScale()
	return math.clamp(1 + 0.5 * (#Players:GetPlayers() - 1), 1, 3)
end

--==================================================
-- SCALE WITH PLAYERS *PER ZONE*
-- Each island's lapis scales with how many people are standing
-- on THAT island (the "Zone" attribute set by GameScripts >
-- Walkspeed), not with the whole server:
--   nobody there -> half speed, normal cap (still stocked when
--                   someone arrives, but not wasting lag on it)
--   1 player     -> normal
--   each extra   -> +50% cap and spawn speed, up to 3x
--==================================================
local ZoneData = require(ReplicatedStorage.AccessibleModules:WaitForChild("ZoneData"))

local function playersInZone(zoneName)
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if (p:GetAttribute("Zone") or ZoneData.Default.Name) == zoneName then n += 1 end
	end
	return n
end

local itemPad = {}   -- [lapisName] = pad name, from PAD_CONFIG
for padName, cfg in pairs(CONFIG.PAD_CONFIG) do
	local list = typeof(cfg.Lapis) == "table" and cfg.Lapis or { cfg.Lapis }
	for _, itemName in ipairs(list) do itemPad[itemName] = padName end
end

-- returns capScale, speedScale for this lapis type
local function zoneScale(itemName)
	local zone = ZoneData.ForPad(itemPad[itemName] or "")
	if not zone then
		local s = playerScale()
		return s, s
	end
	local n = playersInZone(zone.Name)
	if n == 0 then return 1, 0.5 end
	local s = math.clamp(1 + 0.5 * (n - 1), 1, 3)
	return s, s
end

--==================================================
-- HELPER: GET MODEL / PART BOUNDS
--==================================================

local function getPadBounds(pad)
	if pad:IsA("Model") then
		return pad:GetBoundingBox()
	elseif pad:IsA("BasePart") then
		return pad.CFrame, pad.Size
	end
	return CFrame.new(), Vector3.zero
end

--==================================================
-- COUNT ACTIVE LAPIS
--==================================================

-- Running tally instead of scanning every spawned lapis (up to ~400)
-- on each of the 12 spawn loops' ticks.
local liveTotal = 0
local liveByName = {}
local counted = {}

local function onAdded(child)
	if counted[child] or not child:GetAttribute("IsSpawnedLapis") then return end
	counted[child] = child.Name
	liveTotal += 1
	liveByName[child.Name] = (liveByName[child.Name] or 0) + 1
end
local function onRemoved(child)
	local name = counted[child]
	if not name then return end
	counted[child] = nil
	liveTotal -= 1
	liveByName[name] = math.max(0, (liveByName[name] or 1) - 1)
end
for _, c in ipairs(spawnedLapis:GetChildren()) do onAdded(c) end
spawnedLapis.ChildAdded:Connect(onAdded)
spawnedLapis.ChildRemoved:Connect(onRemoved)

local function countLapisInstances(targetName)
	return liveTotal, (targetName and liveByName[targetName]) or 0
end

--==================================================
-- CAN THIS ITEM SPAWN RIGHT NOW?
--==================================================

local function canSpawnItem(lapisData)
	local totalActive, specificActive = countLapisInstances(lapisData.Name)
	-- The global ceiling scales with players too. It used to stay fixed
	-- while every per-type cap grew, so from ~3 players up the shared
	-- ceiling was hit first and it felt like each join REDUCED lapis.
	-- Hard-capped so a full server can't spawn itself into lag.
	local globalMax = math.min(
		math.floor((LapisConfig.MaxGlobalLapis or 30) * playerScale()),
		650
	)

	if totalActive >= globalMax then
		return false
	end

	local capScale = zoneScale(lapisData.Name)
	if specificActive >= math.floor(lapisData.MaxCap * capScale) then
		return false
	end

	local cooldown = lapisData.SpawnCooldown or 0
	local lastSpawn = lastSpawnTimes[lapisData.Name]

	if lastSpawn and (os.clock() - lastSpawn) < cooldown then
		return false
	end

	return true
end

--==================================================
-- RAYCAST DOWN (FOR DROP REQUESTS & FLOOR SNAPPING)
--==================================================

local dropRaycastParams = RaycastParams.new()
dropRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
dropRaycastParams.IgnoreWater = true

local function raycastDown(origin, ignoreInstance)
	local ignoreList = { spawnedLapis }

	if ignoreInstance then
		table.insert(ignoreList, ignoreInstance)
	end

	dropRaycastParams.FilterDescendantsInstances = ignoreList

	local result = Workspace:Raycast(
		origin,
		Vector3.new(0, -CONFIG.FLOOR_RAYCAST_DISTANCE, 0),
		dropRaycastParams
	)

	if result then
		return result.Position, result.Instance
	end

	return origin, nil
end

--==================================================
-- SURFACE POINT CALCULATOR (RADIAL RING DISTRIBUTED)
--==================================================

local function getRandomPadSurfacePoint(spawnPad)
	local cframe, size = getPadBounds(spawnPad)

	-- Read stud configuration for this specific pad name or use global defaults
	local padSettings = CONFIG.PAD_CONFIG[spawnPad.Name] or {}
	local minStuds = padSettings.MinRadius or CONFIG.DEFAULT_MIN_RADIUS
	local maxStuds = padSettings.MaxRadius or CONFIG.DEFAULT_MAX_RADIUS

	-- Cap max studs so items don't float beyond the physical boundary of the pad
	local maxAllowedX = size.X / 2
	local maxAllowedZ = size.Z / 2
	local maxPhysicalRadius = math.min(maxAllowedX, maxAllowedZ)

	minStuds = math.clamp(minStuds, 0, maxPhysicalRadius)
	maxStuds = math.clamp(maxStuds, minStuds + 0.1, maxPhysicalRadius)

	-- Uniform polar area distribution between MinRadius and MaxRadius
	local angle = math.random() * math.pi * 2
	local sampledRadius = math.sqrt(math.random() * (maxStuds^2 - minStuds^2) + minStuds^2)

	local offsetX = math.cos(angle) * sampledRadius
	local offsetZ = math.sin(angle) * sampledRadius

	-- Place precisely at top surface height of the model/part
	local localTopSurface = Vector3.new(offsetX, size.Y / 2, offsetZ)
	return cframe:PointToWorldSpace(localTopSurface)
end

--==================================================
-- FOOTPRINT OF A DROP TARGET
--==================================================

local function getDropFootprint(target)
	if typeof(target) == "Vector3" then
		return target, CONFIG.POINT_DROP_JITTER, CONFIG.POINT_DROP_JITTER
	end

	if typeof(target) == "Instance" then
		if target:IsA("Model") then
			local cframe, size = target:GetBoundingBox()
			return cframe.Position, size.X / 2, size.Z / 2
		elseif target:IsA("BasePart") then
			return target.Position, target.Size.X / 2, target.Size.Z / 2
		end
	end

	warn("RequestLapisSpawn received an invalid target; dropping at origin.")
	return Vector3.new(0, 0, 0), CONFIG.POINT_DROP_JITTER, CONFIG.POINT_DROP_JITTER
end

--==================================================
-- FLOOR MODEL
--==================================================

local function getFloorModel(lapis)
	local inner = lapis:FindFirstChild("model")
	if inner and inner:IsA("Model") then
		return inner
	end
	return lapis
end

--==================================================
-- CLONE + STAMP + PLACE
--==================================================

local function finalizeAndPlace(lapisData, clonedLapis, cframe)
	clonedLapis:SetAttribute("IsSpawnedLapis", true)
	clonedLapis:SetAttribute("Value", lapisData.Value or 0)
	clonedLapis:SetAttribute("Collecting", false)
	clonedLapis:SetAttribute("Magnetized", false)

	if not clonedLapis.PrimaryPart then
		warn(lapisData.Name .. " has no PrimaryPart set -- nothing will be anchored!")
	else
		clonedLapis.PrimaryPart.Anchored = true
		clonedLapis.PrimaryPart.CanCollide = false
	end

	clonedLapis:PivotTo(cframe)
	clonedLapis:SetAttribute("DoAnim", lapisData.DoAnim ~= false)

	clonedLapis.Parent = spawnedLapis
	lastSpawnTimes[lapisData.Name] = os.clock()
end

--==================================================
-- PLACE RESTING ON FLOOR
--==================================================

local function placeRestingOnFloor(clonedLapis, surfacePoint)
	local floorModel = getFloorModel(clonedLapis)
	local floorCFrame, floorSize = floorModel:GetBoundingBox()

	local lowestEdgeY = floorCFrame.Position.Y - (floorSize.Y / 2)
	local pivotOffsetY = clonedLapis:GetPivot().Position.Y - lowestEdgeY

	return CFrame.new(
		Vector3.new(
			surfacePoint.X,
			surfacePoint.Y + pivotOffsetY,
			surfacePoint.Z
		)
	) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
end

--==================================================
-- SPAWN ONE LAPIS (ambient, from a floor pad)
--==================================================

local function spawnOne(lapisData, targetZone)
	local template = LapisFolder:FindFirstChild(lapisData.Name)

	if not template or not template:IsA("Model") then
		warn("Could not find a valid Model named '" .. lapisData.Name .. "' inside ServerStorage!")
		return
	end

	local surfacePoint = getRandomPadSurfacePoint(targetZone)

	local clonedLapis = template:Clone()
	clonedLapis.Name = lapisData.Name

	local cframe = placeRestingOnFloor(clonedLapis, surfacePoint)
	finalizeAndPlace(lapisData, clonedLapis, cframe)
end

--==================================================
-- SPAWN ONE LAPIS (from a drop request)
--==================================================

local function spawnAtDropPosition(
	lapisData,
	footprintCenter,
	halfX,
	halfZ,
	ignoreInstance
)
	local template = LapisFolder:FindFirstChild(lapisData.Name)

	if not template or not template:IsA("Model") then
		warn("Could not find a valid Model named '" .. lapisData.Name .. "' inside ServerStorage!")
		return
	end

	local randomX = (math.random() * 2 - 1) * halfX
	local randomZ = (math.random() * 2 - 1) * halfZ

	local samplePosition = footprintCenter + Vector3.new(randomX, 0, randomZ)
	local rayOrigin = samplePosition + Vector3.new(0, 5, 0)
	local hitPos = raycastDown(rayOrigin, ignoreInstance)

	local clonedLapis = template:Clone()
	clonedLapis.Name = lapisData.Name

	local cframe = placeRestingOnFloor(clonedLapis, hitPos)
	finalizeAndPlace(lapisData, clonedLapis, cframe)
end

--==================================================
-- SPECIFIC LAPIS OVERRIDE
--==================================================

local function getSpecificLapisOverride(target)
	if typeof(target) ~= "Instance" then
		return nil
	end

	-- 1. Check PAD_CONFIG in script
	local scriptConfig = CONFIG.PAD_CONFIG[target.Name]
	if scriptConfig and scriptConfig.Lapis then
		if typeof(scriptConfig.Lapis) == "table" then
			return scriptConfig.Lapis[math.random(1, #scriptConfig.Lapis)]
		elseif typeof(scriptConfig.Lapis) == "string" then
			return scriptConfig.Lapis
		end
	end

	-- 2. Check Instance attributes if present
	local direct = target:GetAttribute("SpecificLapis")
	if direct and direct ~= "" then
		return direct
	end

	for _, descendant in ipairs(target:GetDescendants()) do
		local value = descendant:GetAttribute("SpecificLapis")
		if value and value ~= "" then
			return value
		end
	end

	return nil
end

--==================================================
-- HANDLE AN INCOMING DROP REQUEST
--==================================================

local function handleDropRequest(itemName, target)
	local override = getSpecificLapisOverride(target)
	if override then
		itemName = override
	end

	local lapisData = itemLookup[itemName]
	if not lapisData then
		warn("RequestLapisSpawn got an unrecognized item name: '" .. tostring(itemName) .. "'")
		return
	end

	if not canSpawnItem(lapisData) then
		return
	end

	if math.random(1, 100) > lapisData.RarityChance then
		return
	end

	local footprintCenter, halfX, halfZ = getDropFootprint(target)
	local ignoreInstance = (typeof(target) == "Instance") and target or nil

	if lapisData.SpawnDelay and lapisData.SpawnDelay > 0 then
		task.wait(lapisData.SpawnDelay)

		if not canSpawnItem(lapisData) then
			return
		end
	end

	spawnAtDropPosition(
		lapisData,
		footprintCenter,
		halfX,
		halfZ,
		ignoreInstance
	)
end

RequestLapisSpawn.Event:Connect(handleDropRequest)

--==================================================
-- WHICH PADS CAN THIS ITEM USE?
--==================================================

local function isPadAllowedForItem(pad, itemName)
	local padSettings = CONFIG.PAD_CONFIG[pad.Name]
	local reservedFor = (padSettings and padSettings.Lapis) or pad:GetAttribute("SpecificLapis")

	if not reservedFor or reservedFor == "" then
		return true
	end

	if typeof(reservedFor) == "string" then
		for allowedItem in string.gmatch(reservedFor, "[^,%s]+") do
			if allowedItem == itemName then
				return true
			end
		end
	elseif typeof(reservedFor) == "table" then
		for _, allowedItem in ipairs(reservedFor) do
			if allowedItem == itemName then
				return true
			end
		end
	end

	return false
end

local function getEligibleSpawnZones(lapisData)
	local eligible = {}

	for _, pad in ipairs(SpawnBoxFolder:GetChildren()) do
		-- Only pads that actually have a PAD_CONFIG entry. LapisSpawnBox
		-- also holds stray decoration models (there is a 67_lapis prop in
		-- there); those have no config, so isPadAllowedForItem returned
		-- true for everything and lapis spawned floating on top of them.
		if CONFIG.PAD_CONFIG[pad.Name] and (pad:IsA("BasePart") or pad:IsA("Model")) then
			if isPadAllowedForItem(pad, lapisData.Name) then
				table.insert(eligible, pad)
			end
		end
	end

	return eligible
end

--==================================================
-- PER-TYPE AMBIENT SPAWN LOOP
--==================================================

local function startLapisSpawner(lapisData)
	while true do
		local _, speedScale = zoneScale(lapisData.Name)
		task.wait(lapisData.SpawnDelay / speedScale)

		if canSpawnItem(lapisData) then
			if math.random(1, 100) <= lapisData.RarityChance then
				local spawnParts = getEligibleSpawnZones(lapisData)
				if #spawnParts > 0 then
					local targetZone = spawnParts[math.random(1, #spawnParts)]
					spawnOne(lapisData, targetZone)
				end
			end
		end
	end
end

-- Ambient lapis is per-player and client-side now (GameScripts >
-- LocalLapisService + LocalLapisClient). This spawner only serves
-- RequestLapisSpawn drops. Flip to true to bring the old shared
-- server-side spawns back.
local AMBIENT_SERVER_SPAWNS = false
if AMBIENT_SERVER_SPAWNS then
	for _, lapisData in ipairs(LapisConfig.Items) do
		task.spawn(startLapisSpawner, lapisData)
	end
end

--==================================================
-- DIAGNOSTIC: STUCK-AT-CAP WATCHDOG
--==================================================

local STUCK_THRESHOLD = 120

task.spawn(function()
	while true do
		task.wait(30)

		for _, lapisData in ipairs(LapisConfig.Items) do
			local _, specificActive = countLapisInstances(lapisData.Name)

			if specificActive >= lapisData.MaxCap then
				local lastSpawn = lastSpawnTimes[lapisData.Name]
				if lastSpawn then
					local stuckFor = os.clock() - lastSpawn
					if stuckFor > STUCK_THRESHOLD then
						warn(
							string.format(
								"[LapisSpawner] %s has been at cap (%d/%d) for %ds.",
								lapisData.Name,
								specificActive,
								lapisData.MaxCap,
								math.floor(stuckFor)
							)
						)
					end
				end
			end
		end
	end
end)