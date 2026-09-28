-- LocalScript: LapisZoneEdgeHighlight
-- Place in: StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Clean up any pre-existing GUI
local oldGui = playerGui:FindFirstChild("LapisZoneHighlightGui")
if oldGui then oldGui:Destroy() end

--==================================================
-- CONFIGURATION
--==================================================
local CONFIG = {
	FolderName = "LapisSpawnBox", -- Workspace folder containing A, B, C, D

	-- INDIVIDUAL COLOR MAP
	ZoneColors = {
		["A"] = Color3.fromRGB(0, 140, 255),   -- Blue
		["B"] = Color3.fromRGB(255, 230, 0),  -- Yellow
		["C"] = Color3.fromRGB(0, 30, 130),   -- Dark Blue
		["D"] = Color3.fromRGB(255, 255, 255) -- White
	},
	DefaultColor = Color3.fromRGB(255, 255, 255),

	-- HIGHLIGHT SIZE & GLOW TUNING
	EdgeThickness = 0.02,  -- Size of edge glow (0.045 = 4.5% screen thickness). Adjust up/down as needed!
	MinGlow = 0.08,        -- Lower boundary of pulse transparency
	MaxGlow = 0.30,        -- Upper peak of pulse transparency
	PulseSpeed = 3.0,      -- Breathing pulse speed

	-- TINY PARTICLE TUNING
	EnableParticles = true,
	ParticleSpawnInterval = 0.015,  -- Time between particle spawns (seconds)
	ParticleLifespan = 0.35,       -- How fast tiny particles fade away (seconds)
	ParticleSize = Vector2.new(3, 7), -- Very tiny particle pixel size (Min, Max)

	-- TRANSITION & LAYER SETTINGS
	HeightPadding = 6,     -- Extra studs above the part to detect standing on top
	FadeInDuration = 0.35, -- Smooth fade-in duration
	FadeOutDuration = 0.35,-- Smooth fade-out duration
	DisplayOrder = -100,   -- Keeps UI rendered behind all other player GUIs
}

--==================================================
-- UI SETUP (SCREEN-EDGE GLOW & PARTICLE CONTAINER)
--==================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LapisZoneHighlightGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = CONFIG.DisplayOrder
screenGui.Enabled = false
screenGui.Parent = playerGui

-- CanvasGroup for the glowing edge vignette
local container = Instance.new("CanvasGroup")
container.Name = "HighlightContainer"
container.Size = UDim2.fromScale(1, 1)
container.BackgroundTransparency = 1
container.GroupTransparency = 1
container.Parent = screenGui

-- Separate container for floating tiny particles
local particleContainer = Instance.new("Frame")
particleContainer.Name = "ParticleContainer"
particleContainer.Size = UDim2.fromScale(1, 1)
particleContainer.BackgroundTransparency = 1
particleContainer.Parent = screenGui

local function createEdgeGlow(name, size, position, anchorPoint, rotation)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchorPoint
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = CONFIG.DefaultColor
	frame.Parent = container

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	gradient.Parent = frame

	return frame
end

local thick = CONFIG.EdgeThickness
local edgeTop    = createEdgeGlow("EdgeTop",    UDim2.fromScale(1, thick), UDim2.fromScale(0, 0), Vector2.new(0, 0), 90)
local edgeBottom = createEdgeGlow("EdgeBottom", UDim2.fromScale(1, thick), UDim2.fromScale(0, 1), Vector2.new(0, 1), -90)
local edgeLeft   = createEdgeGlow("EdgeLeft",   UDim2.fromScale(thick, 1), UDim2.fromScale(0, 0), Vector2.new(0, 0), 0)
local edgeRight  = createEdgeGlow("EdgeRight",  UDim2.fromScale(thick, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180)

local function applyGlowColor(color)
	edgeTop.BackgroundColor3 = color
	edgeBottom.BackgroundColor3 = color
	edgeLeft.BackgroundColor3 = color
	edgeRight.BackgroundColor3 = color
end

--==================================================
-- TINY PARTICLE EMITTER
--==================================================
local function getRandomEdgePosition()
	local edge = math.random(1, 4)
	local x, y

	if edge == 1 then
		x = math.random()
		y = math.random() * CONFIG.EdgeThickness
	elseif edge == 2 then
		x = math.random()
		y = 1 - (math.random() * CONFIG.EdgeThickness)
	elseif edge == 3 then
		x = math.random() * CONFIG.EdgeThickness
		y = math.random()
	else
		x = 1 - (math.random() * CONFIG.EdgeThickness)
		y = math.random()
	end

	return UDim2.fromScale(x, y), edge
end

local function spawnTinyParticle(color, currentFadeAlpha)
	if not screenGui.Enabled or not CONFIG.EnableParticles then return end

	local particle = Instance.new("Frame")
	particle.BorderSizePixel = 0
	particle.BackgroundColor3 = color
	particle.BackgroundTransparency = 0.2
	particle.AnchorPoint = Vector2.new(0.5, 0.5)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = particle

	local size = math.random(CONFIG.ParticleSize.X, CONFIG.ParticleSize.Y)
	particle.Size = UDim2.fromOffset(size, size)

	local startPos = getRandomEdgePosition()
	particle.Position = startPos
	particle.Parent = particleContainer

	-- Subtle drift inward toward the screen center
	local driftX = (0.5 - startPos.X.Scale) * 0.015
	local driftY = (0.5 - startPos.Y.Scale) * 0.015
	local endPos = UDim2.fromScale(startPos.X.Scale + driftX, startPos.Y.Scale + driftY)

	local fadeInfo = TweenInfo.new(CONFIG.ParticleLifespan, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(particle, fadeInfo, {
		BackgroundTransparency = 1,
		Position = endPos,
		Size = UDim2.fromOffset(math.max(1, size * 0.2), math.max(1, size * 0.2))
	})

	tween:Play()
	tween.Completed:Connect(function()
		if particle then particle:Destroy() end
	end)
end

--==================================================
-- ZONE DETECTION LOGIC
--==================================================
local function isPlayerInsidePartEntirety(playerPos, part)
	if not part:IsA("BasePart") then return false end

	local localPos = part.CFrame:PointToObjectSpace(playerPos)
	local halfSize = part.Size / 2

	return math.abs(localPos.X) <= halfSize.X
		and math.abs(localPos.Z) <= halfSize.Z
		and (localPos.Y >= -halfSize.Y - 2 and localPos.Y <= halfSize.Y + CONFIG.HeightPadding)
end

local function getActiveZoneAndColor()
	local character = player.Character
	if not character then return false, nil end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false, nil end

	local folder = Workspace:FindFirstChild(CONFIG.FolderName, true)
	if not folder then return false, nil end

	local playerPos = hrp.Position

	for _, zoneItem in ipairs(folder:GetChildren()) do
		local zoneName = zoneItem.Name
		local zoneColor = CONFIG.ZoneColors[zoneName] or CONFIG.DefaultColor

		if zoneItem:IsA("BasePart") then
			if isPlayerInsidePartEntirety(playerPos, zoneItem) then
				return true, zoneColor
			end
		else
			for _, desc in ipairs(zoneItem:GetDescendants()) do
				if desc:IsA("BasePart") then
					if isPlayerInsidePartEntirety(playerPos, desc) then
						return true, zoneColor
					end
				end
			end
		end
	end

	return false, nil
end

--==================================================
-- RENDER LOOP (GLOW, PULSE & PARTICLE SPINNER)
--==================================================
local fadeProgress = 0
local lastTime = os.clock()
local lastParticleTime = 0
local activeColor = CONFIG.DefaultColor

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = now - lastTime
	lastTime = now

	local inZone, targetColor = getActiveZoneAndColor()

	if inZone and targetColor then
		activeColor = targetColor
		applyGlowColor(activeColor)
		fadeProgress = math.min(1, fadeProgress + (dt / CONFIG.FadeInDuration))
	else
		fadeProgress = math.max(0, fadeProgress - (dt / CONFIG.FadeOutDuration))
	end

	if fadeProgress > 0 then
		if not screenGui.Enabled then
			screenGui.Enabled = true
		end

		-- Pulsing math
		local pulse = (math.sin(now * CONFIG.PulseSpeed) + 1) / 2
		local targetGlowAlpha = CONFIG.MinGlow + (pulse * (CONFIG.MaxGlow - CONFIG.MinGlow))
		local currentGlowAlpha = targetGlowAlpha * fadeProgress

		container.GroupTransparency = 1 - currentGlowAlpha

		-- Spawn tiny matching-color particles while active
		if inZone and now - lastParticleTime >= CONFIG.ParticleSpawnInterval then
			lastParticleTime = now
			spawnTinyParticle(activeColor, fadeProgress)
		end
	else
		if screenGui.Enabled then
			container.GroupTransparency = 1
			screenGui.Enabled = false
			particleContainer:ClearAllChildren()
		end
	end
end)