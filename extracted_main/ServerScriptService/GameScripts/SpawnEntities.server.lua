--// Day/Night Cycle & Entity Spawner, Combined --// Put this script in ServerScriptService
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

--// Require Spawner Modules
local EntityDataModule = require(ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("EntityDataModule"))

--// Spawner Folder Paths
local accessibleStorage = ServerStorage:WaitForChild("AccessibleModels")
local entitiesFolder = accessibleStorage:WaitForChild("Entities")
local mobsFolder = entitiesFolder:WaitForChild("Mobs")

--// Ask the Lapis Spawner to handle loot drops instead of spawning it ourselves.
--// The Lapis Spawner script owns the "RequestLapisSpawn" BindableEvent (it lives
--// in ReplicatedStorage.AccessibleEvents and creates it if missing), so we just
--// wait for it here -- this script never touches a lapis template, a cap, or a
--// cooldown directly anymore.
local accessibleEvents = ReplicatedStorage:WaitForChild("AccessibleEvents")
local RequestLapisSpawn = accessibleEvents:WaitForChild("RequestLapisSpawn")

--// Setup Workspace Spawning Folders
local spawnedEntities = workspace:FindFirstChild("SpawnedEntities") or Instance.new("Folder")
if not spawnedEntities.Parent then
	spawnedEntities.Name = "SpawnedEntities"
	spawnedEntities.Parent = workspace
end

local liveMobsFolder = spawnedEntities:FindFirstChild("Mobs") or Instance.new("Folder")
if not liveMobsFolder.Parent then
	liveMobsFolder.Name = "Mobs"
	liveMobsFolder.Parent = spawnedEntities
end

--// Easy Cycle Settings
local DayTime = 800
local NightTime = DayTime / 2
local DuskTime = DayTime * 0.15
local DawnTime = DayTime * 0.15
local FadeTime = math.max(1, DayTime * 0.03)
local NormalAmbient = Color3.fromRGB(140, 140, 140)

--// Spawner Trackers
local spawnPoints = workspace:WaitForChild("SpawnPoints"):GetChildren()
local activeMobs = {}

--// Find or create effects
local Atmosphere = Lighting:FindFirstChild("Atmosphere") or Instance.new("Atmosphere")
Atmosphere.Parent = Lighting
local Bloom = Lighting:FindFirstChild("Bloom") or Instance.new("BloomEffect")
Bloom.Name = "Bloom"
Bloom.Parent = Lighting
local SunRays = Lighting:FindFirstChild("SunRays") or Instance.new("SunRaysEffect")
SunRays.Name = "SunRays"
SunRays.Parent = Lighting
local ColorCorrection = Lighting:FindFirstChild("ColorCorrection") or Instance.new("ColorCorrectionEffect")
ColorCorrection.Name = "ColorCorrection"
ColorCorrection.Parent = Lighting

--// Starting lighting
--Lighting.ClockTime = 20

local function tween(obj, time, info)
	local newTween = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Linear), info)
	newTween:Play()
	return newTween
end

--// Spawner Helper Functions
local function getActiveMobCount(mobName)
	local count = 0
	for _, name in pairs(activeMobs) do
		if name == mobName then count = count + 1 end
	end
	return count
end

local function chooseMobToSpawn()
	local availableMobs = {}
	local totalWeight = 0

	for mobName, config in pairs(EntityDataModule.Mobs) do
		local currentAlive = getActiveMobCount(mobName)
		if currentAlive < config.MaxAmount then
			table.insert(availableMobs, {name = mobName, weight = config.SpawnChance})
			totalWeight = totalWeight + config.SpawnChance
		end
	end

	if totalWeight == 0 then return nil end

	local roll = math.random() * totalWeight
	local counter = 0
	for _, mobData in ipairs(availableMobs) do
		counter = counter + mobData.weight
		if roll <= counter then
			return mobData.name
		end
	end
	return nil
end

--// This no longer spawns anything itself. It just tells the Lapis Spawner
--// which item types this mob COULD drop and where it died. The Lapis Spawner
--// decides -- based on RarityChance, MaxCap, MaxGlobalLapis, and SpawnCooldown --
--// whether an actual drop happens.
local function handleMobDeath(mobName, deathPosition)
	local mobData = EntityDataModule.GetMobData(mobName)
	if not mobData or not mobData.DropLoot then return end

	for _, lootName in ipairs(mobData.SpawnableLoot) do
		RequestLapisSpawn:Fire(lootName, deathPosition)
	end
end

local function spawnMobs()
	if #spawnPoints == 0 then return end
	-- Make sure spawn points list is completely fresh
	spawnPoints = workspace:WaitForChild("SpawnPoints"):GetChildren()

	for _, spawnPoint in ipairs(spawnPoints) do
		local mobName = chooseMobToSpawn()
		if not mobName then continue end

		local mobTemplate = mobsFolder:FindFirstChild(mobName)
		if mobTemplate then
			local clonedMob = mobTemplate:Clone()
			local humanoid = clonedMob:FindFirstChildOfClass("Humanoid")

			clonedMob:SetPrimaryPartCFrame(spawnPoint.CFrame + Vector3.new(0, 3, 0))
			clonedMob.Parent = liveMobsFolder

			activeMobs[clonedMob] = mobName

			if humanoid then
				humanoid.Died:Connect(function()
					local primaryPart = clonedMob.PrimaryPart
					local deathPos = primaryPart and primaryPart.Position or Vector3.new(0,0,0)

					activeMobs[clonedMob] = nil
					handleMobDeath(mobName, deathPos)
					Debris:AddItem(clonedMob, 5)
				end)
			end
		end
	end
end

-- Clear out any surviving mobs when daytime starts
local function clearRemainingMobs()
	table.clear(activeMobs)
	for _, child in ipairs(liveMobsFolder:GetChildren()) do
		child:Destroy()
	end
end

--// Tweens & States
local function makeDay()
	tween(Lighting, FadeTime, { Ambient = NormalAmbient, OutdoorAmbient = NormalAmbient, Brightness = 2.4, ExposureCompensation = 0.05, ColorShift_Top = Color3.fromRGB(255, 245, 230), ColorShift_Bottom = Color3.fromRGB(255, 250, 240), ShadowSoftness = 0.3 })
	tween(Atmosphere, FadeTime, { Color = Color3.fromRGB(220, 235, 255), Decay = Color3.fromRGB(120, 170, 255), Density = 0.22, Haze = 1.15, Glare = 0.2 })
	tween(Bloom, FadeTime, { Intensity = 0.12, Size = 38, Threshold = 1 })
	tween(SunRays, FadeTime, { Intensity = 0.08, Spread = 0.9 })
	tween(ColorCorrection, FadeTime, { Brightness = 0, Contrast = 0.07, Saturation = 0.1 })
end

local function makeDusk()
	tween(Lighting, FadeTime, { Ambient = NormalAmbient, OutdoorAmbient = NormalAmbient, Brightness = 2, ExposureCompensation = 0, ColorShift_Top = Color3.fromRGB(255, 190, 125), ColorShift_Bottom = Color3.fromRGB(255, 135, 90) })
	tween(Atmosphere, FadeTime, { Color = Color3.fromRGB(255, 180, 140), Decay = Color3.fromRGB(255, 130, 95), Density = 0.3, Haze = 2, Glare = 0.35 })
	tween(Bloom, FadeTime, { Intensity = 0.15, Size = 45, Threshold = 0.95 })
	tween(SunRays, FadeTime, { Intensity = 0.12, Spread = 0.9 })
	tween(ColorCorrection, FadeTime, { Brightness = 0, Contrast = 0.1, Saturation = 0.18 })
end

local function makeNight()
	tween(Lighting, FadeTime, { Ambient = NormalAmbient, OutdoorAmbient = NormalAmbient, Brightness = 1.35, ExposureCompensation = -0.15, ColorShift_Top = Color3.fromRGB(55, 75, 135), ColorShift_Bottom = Color3.fromRGB(25, 35, 75) })
	tween(Atmosphere, FadeTime, { Color = Color3.fromRGB(75, 95, 150), Decay = Color3.fromRGB(25, 35, 65), Density = 0.5, Haze = 3.2, Glare = 0 })
	tween(Bloom, FadeTime, { Intensity = 0.08, Size = 34, Threshold = 1.1 })
	tween(SunRays, FadeTime, { Intensity = 0.02, Spread = 1 })
	tween(ColorCorrection, FadeTime, { Brightness = -0.02, Contrast = 0.1, Saturation = -0.05 })
end

local function makeDawn()
	tween(Lighting, FadeTime, { Ambient = NormalAmbient, OutdoorAmbient = NormalAmbient, Brightness = 1.8, ExposureCompensation = 0, ColorShift_Top = Color3.fromRGB(255, 200, 150), ColorShift_Bottom = Color3.fromRGB(255, 160, 120) })
	tween(Atmosphere, FadeTime, { Color = Color3.fromRGB(255, 205, 170), Decay = Color3.fromRGB(255, 150, 110), Density = 0.32, Haze = 2.2, Glare = 0.25 })
	tween(Bloom, FadeTime, { Intensity = 0.13, Size = 42, Threshold = 1 })
	tween(SunRays, FadeTime, { Intensity = 0.1, Spread = 0.95 })
	tween(ColorCorrection, FadeTime, { Brightness = 0, Contrast = 0.09, Saturation = 0.15 })
end

--// Main Master Cycle Loop
while true do
	-- Day (Mobs get cleared out)
	clearRemainingMobs()
	makeDay()
	tween(Lighting, DayTime, { ClockTime = 17 })
	task.wait(DayTime)

	-- Dusk / sunset
	makeDusk()
	tween(Lighting, DuskTime, { ClockTime = 19 })
	task.wait(DuskTime)

	-- Night (Spawns your entities!)
	makeNight()
	spawnMobs()
	tween(Lighting, NightTime, { ClockTime = 5 })
	task.wait(NightTime)

	-- Dawn / sunrise
	makeDawn()
	tween(Lighting, DawnTime, { ClockTime = 7 })
	task.wait(DawnTime)
end