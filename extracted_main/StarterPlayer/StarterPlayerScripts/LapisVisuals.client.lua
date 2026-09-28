--==================================================
-- LAPIS VISUALS (CLIENT)
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CONFIG = {
	FOLDER_NAME = "SpawnedLapis",

	ROTATION_SPEED = 90,     -- degrees/sec idle
	BOB_HEIGHT = 2.5,        -- studs of lift
	BOB_SPEED = 2,

	FLIGHT_SPIN_SPEED = 540, -- degrees/sec while flying
	FLIGHT_ARC = 1,          -- studs of upward arc mid-flight

	RETURN_DURATION = 0.4,   -- seconds to fly back when unequipped
	RETURN_ARC = 0.5,

	PICKUP_DURATION = 0.45,
	PICKUP_RISE = 3,
	PICKUP_SPIN = 720,
}

local state = {}

local IDLE_RADIUS = 170      -- studs from the camera that idle lapis animate within
local IDLE_RADIUS_LOW = 80   -- same, with Low Graphic Mode on

local function getState(lapis)
	local existing = state[lapis]
	if existing then return existing end

	local pivot = lapis:GetPivot()
	local _, spawnYaw = pivot:ToEulerAnglesYXZ()

	local created = {
		Mode = "idle",
		InitialPosition = pivot.Position,
		SpawnClock = os.clock(),
		Angle = spawnYaw,
	}
	state[lapis] = created
	return created
end

local function getBasePosition(lapis, data)
	local rawOriginal = lapis:GetAttribute("OriginalPosition")
	if rawOriginal then
		if typeof(rawOriginal) == "CFrame" then
			return rawOriginal.Position
		elseif typeof(rawOriginal) == "Vector3" then
			return rawOriginal
		end
	end
	return data.InitialPosition
end

local function getPlayerPosition(userId)
	local player = Players:GetPlayerByUserId(userId)
	if not player or not player.Character then return nil end

	local torso = player.Character:FindFirstChild("UpperTorso") or player.Character:FindFirstChild("Torso")
	if torso then return torso.Position end

	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or nil
end

local function isDecalHolder(object)
	if not object:IsA("BasePart") then return false end
	for _, child in ipairs(object:GetChildren()) do
		if child:IsA("Decal") then return true end
	end
	return false
end

local function fadeNumberSequence(originalSequence, alpha)
	local keypoints = {}
	for _, keypoint in ipairs(originalSequence.Keypoints) do
		local original = keypoint.Value
		local faded = original + ((1 - original) * alpha)
		table.insert(keypoints, NumberSequenceKeypoint.new(keypoint.Time, faded, keypoint.Envelope))
	end
	return NumberSequence.new(keypoints)
end

local function saveOriginalTransparency(lapis)
	local transparencyData = {}
	for _, object in ipairs(lapis:GetDescendants()) do
		if object:IsA("BasePart") then
			if isDecalHolder(object) then
				transparencyData[object] = { Type = "BasePart", Transparency = 1, AlwaysInvisible = true }
			else
				transparencyData[object] = { Type = "BasePart", Transparency = object.Transparency }
			end
		elseif object:IsA("Decal") or object:IsA("Texture") or object:IsA("Beam") or object:IsA("Trail") or object:IsA("ParticleEmitter") then
			transparencyData[object] = { Type = object.ClassName, Transparency = object.Transparency }
		elseif object:IsA("Highlight") then
			transparencyData[object] = { Type = "Highlight", FillTransparency = object.FillTransparency, OutlineTransparency = object.OutlineTransparency }
		end
	end
	return transparencyData
end

local function fadeLapis(lapis, transparencyData, alpha)
	for object, data in pairs(transparencyData) do
		if not object or not object.Parent then continue end

		if data.Type == "BasePart" then
			object.Transparency = data.AlwaysInvisible and 1 or (data.Transparency + ((1 - data.Transparency) * alpha))
		elseif data.Type == "Decal" or data.Type == "Texture" then
			object.Transparency = data.Transparency + ((1 - data.Transparency) * alpha)
		elseif data.Type == "Highlight" then
			object.FillTransparency = data.FillTransparency + ((1 - data.FillTransparency) * alpha)
			object.OutlineTransparency = data.OutlineTransparency + ((1 - data.OutlineTransparency) * alpha)
		elseif data.Type == "Beam" or data.Type == "Trail" or data.Type == "ParticleEmitter" then
			object.Transparency = fadeNumberSequence(data.Transparency, alpha)
		end
	end
end

local function animatePickup(lapis, data)
	if data.Mode ~= "pickup" then
		data.Mode = "pickup"
		data.PickupOrigin = lapis:GetPivot()
		data.PickupClock = os.clock()
		data.PickupTransparency = saveOriginalTransparency(lapis)
	end

	local elapsed = os.clock() - data.PickupClock
	local alpha = math.clamp(elapsed / CONFIG.PICKUP_DURATION, 0, 1)
	local eased = 1 - (1 - alpha) ^ 3

	lapis:PivotTo(
		data.PickupOrigin
			* CFrame.new(0, CONFIG.PICKUP_RISE * eased, 0)
			* CFrame.Angles(0, math.rad(CONFIG.PICKUP_SPIN) * eased, 0)
	)

	fadeLapis(lapis, data.PickupTransparency, eased)
end

local function animate(lapis, deltaTime)
	local data = getState(lapis)

	-- 1. PICKUP
	if lapis:GetAttribute("Collecting") then
		animatePickup(lapis, data)
		return
	end

	local magnetTarget = lapis:GetAttribute("MagnetTarget")

	-- 2. MAGNET FLIGHT
	if magnetTarget then
		local targetPosition = getPlayerPosition(magnetTarget)
		local startTime = lapis:GetAttribute("MagnetStart")
		local duration = lapis:GetAttribute("MagnetDuration") or 0.6

		if targetPosition and startTime then
			if data.Mode ~= "flight" then
				data.Mode = "flight"
				data.FlightOrigin = lapis:GetPivot().Position
			end

			local elapsed = workspace:GetServerTimeNow() - startTime
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local eased = 1 - (1 - alpha) ^ 3

			local position = data.FlightOrigin:Lerp(targetPosition, eased)
			position += Vector3.new(0, math.sin(math.pi * alpha) * CONFIG.FLIGHT_ARC, 0)

			data.Angle += math.rad(CONFIG.FLIGHT_SPIN_SPEED) * deltaTime

			lapis:PivotTo(CFrame.new(position) * CFrame.Angles(0, data.Angle, 0))
			return
		end
		return
	end

	-- 3. RETURN FLIGHT (Triggers when flight ends without collecting)
	if data.Mode == "flight" then
		data.Mode = "returning"
		data.ReturnOrigin = lapis:GetPivot().Position
		data.ReturnClock = os.clock()
	end

	if data.Mode == "returning" then
		local elapsed = os.clock() - data.ReturnClock
		local alpha = math.clamp(elapsed / CONFIG.RETURN_DURATION, 0, 1)
		local eased = 1 - (1 - alpha) ^ 3

		-- Target live idle bob height so landing is completely seamless
		local basePos = getBasePosition(lapis, data)
		local idleClock = os.clock() - data.SpawnClock
		local currentBob = (1 - math.cos(idleClock * CONFIG.BOB_SPEED)) / 2 * CONFIG.BOB_HEIGHT
		local currentIdleTarget = basePos + Vector3.new(0, currentBob, 0)

		local position = data.ReturnOrigin:Lerp(currentIdleTarget, eased)
		position += Vector3.new(0, math.sin(math.pi * alpha) * CONFIG.RETURN_ARC, 0)

		data.Angle += math.rad(CONFIG.FLIGHT_SPIN_SPEED) * (1 - alpha) * deltaTime

		lapis:PivotTo(CFrame.new(position) * CFrame.Angles(0, data.Angle, 0))

		if alpha >= 1 then
			data.Mode = "idle"
		end
		return
	end

	-- 4. IDLE BOB + SPIN
	data.Mode = "idle"

	if lapis:GetAttribute("DoAnim") == false then return end

	local basePos = getBasePosition(lapis, data)

	-- PERFORMANCE: idle bob/spin only for lapis near the camera. With a
	-- few hundred lapis on the map, pivoting every one of them every
	-- frame was the single biggest cost on the client.
	local cam = workspace.CurrentCamera
	if cam then
		local radius = (Players.LocalPlayer:GetAttribute("LowGraphics") and IDLE_RADIUS_LOW) or IDLE_RADIUS
		if (cam.CFrame.Position - basePos).Magnitude > radius then
			data.Angle += math.rad(CONFIG.ROTATION_SPEED) * deltaTime
			return
		end
	end
	local elapsed = os.clock() - data.SpawnClock

	data.Angle += math.rad(CONFIG.ROTATION_SPEED) * deltaTime
	local bobOffset = (1 - math.cos(elapsed * CONFIG.BOB_SPEED)) / 2 * CONFIG.BOB_HEIGHT

	lapis:PivotTo(
		CFrame.new(basePos + Vector3.new(0, bobOffset, 0))
			* CFrame.Angles(0, data.Angle, 0)
	)
end

-- MAIN LOOP
local folder = workspace:WaitForChild(CONFIG.FOLDER_NAME)

folder.ChildRemoved:Connect(function(lapis)
	state[lapis] = nil
end)

RunService.RenderStepped:Connect(function(deltaTime)
	for _, lapis in ipairs(folder:GetChildren()) do
		if lapis:IsA("Model") then
			animate(lapis, deltaTime)
		end
	end
end)