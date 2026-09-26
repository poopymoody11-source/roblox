--==================================================
-- CUTSCENE DIRECTOR  (CLIENT)
--
-- Plays the two Moon Animator scenes back to back when
-- a player joins, with THAT player's avatar in place of
-- the TemplateR6 stand-in.
--
-- WHY THIS RUNS ON THE CLIENT
--
-- Each player has to see themselves in the shot, so
-- there can't be one shared set of props on the server:
-- two people joining together would fight over the same
-- rig and the same camera path. Instead every client
-- clones its OWN copy of the set out of ReplicatedStorage.
-- Instances a LocalScript creates aren't replicated, so
-- those clones are invisible to everyone else -- each
-- player gets a private performance in the same space.
--
-- The real character is hidden and frozen for the
-- duration, then handed back exactly as it was.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer

local stageFolder = ReplicatedStorage:WaitForChild("CutsceneStage", 30)
if not stageFolder then
	warn("[Cutscene] ReplicatedStorage.CutsceneStage is missing")
	return
end

local MoonPlayer = require(stageFolder:WaitForChild("MoonPlayer"))
local Config = require(stageFolder:WaitForChild("CutsceneConfig"))

local PROPS = stageFolder:WaitForChild("Props")
local SAVES = stageFolder:WaitForChild("Saves")
local PRESENTATION = Config.Presentation

if not Config.Playback.PlayOnJoin then return end

-- A party from the BECOME LA PEACE lobby lands in a normal server for a
-- few seconds before PrivatePartyRouter moves it into a private one.
-- Show a holding screen here instead of starting the cutscene; it plays
-- in the private server.
do
	local TeleportService = game:GetService("TeleportService")
	local ok, td = pcall(function() return TeleportService:GetLocalPlayerTeleportData() end)
	if ok and type(td) == "table" and td.PrivateParty
		and workspace:GetAttribute("IsReservedServer") ~= true
		and not RunService:IsStudio() then
		local hold = Instance.new("ScreenGui")
		hold.Name = "PartyTransit"
		hold.IgnoreGuiInset = true
		hold.DisplayOrder = 1000
		hold.ResetOnSpawn = false
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.new(0, 0, 0)
		bg.Parent = hold
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.Position = UDim2.fromScale(0.5, 0.5)
		text.Size = UDim2.fromScale(0.7, 0.06)
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(200, 190, 255)
		text.Text = "OPENING A PRIVATE SERVER FOR YOUR PARTY..."
		text.Parent = bg
		hold.Parent = player:WaitForChild("PlayerGui")
		task.spawn(function()
			local t = 0
			while hold.Parent do
				t += task.wait()
				text.TextTransparency = 0.25 + math.sin(t * 3) * 0.25
			end
		end)
		return
	end
end
if Config.Playback.SkipInStudio and RunService:IsStudio() then return end

--==================================================
-- STATE
--==================================================

local camera = workspace.CurrentCamera

local session = {
	Active = false,
	Skipped = false,
	Clones = {},
	Sounds = {},
	Shakes = {},
	FovOffset = 0,
	FovTweens = {},
}

--==================================================
-- UI
--==================================================

local gui = Instance.new("ScreenGui")
gui.Name = "CutsceneGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 500
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(anchorY, positionY)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0.5, anchorY)
	frame.Position = UDim2.fromScale(0.5, positionY)
	frame.Size = UDim2.fromScale(1, 0)
	frame.ZIndex = 10
	frame.Parent = gui
	return frame
end

local topBar = bar(0, 0)
local bottomBar = bar(1, 1)

local fade = Instance.new("Frame")
fade.BackgroundColor3 = Color3.new(0, 0, 0)
fade.BorderSizePixel = 0
fade.Size = UDim2.fromScale(1, 1)
fade.BackgroundTransparency = 0
fade.ZIndex = 20
fade.Parent = gui

local flash = Instance.new("Frame")
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BorderSizePixel = 0
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundTransparency = 1
flash.ZIndex = 25
flash.Parent = gui

-- title card
local titleHolder = Instance.new("Frame")
titleHolder.BackgroundTransparency = 1
titleHolder.Size = UDim2.fromScale(1, 1)
titleHolder.ZIndex = 30
titleHolder.Parent = gui

local function makeText(size, positionY, font, zindex)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, positionY)
	label.Size = size
	label.Font = font
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 1
	label.ZIndex = zindex
	label.Parent = titleHolder

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 1
	stroke.Parent = label

	return label, stroke
end

local titleMain, titleMainStroke = makeText(UDim2.fromScale(0.72, 0.13), 0.44, Enum.Font.GothamBlack, 31)
local titleSub, titleSubStroke = makeText(UDim2.fromScale(0.4, 0.045), 0.545, Enum.Font.GothamBold, 31)

-- skip prompt
local skipHolder = Instance.new("Frame")
skipHolder.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
skipHolder.BackgroundTransparency = 0.35
skipHolder.BorderSizePixel = 0
skipHolder.AnchorPoint = Vector2.new(1, 1)
skipHolder.Position = UDim2.fromScale(0.96, 0.9)
skipHolder.Size = UDim2.fromScale(0.16, 0.042)
skipHolder.Visible = false
skipHolder.ZIndex = 35
skipHolder.Parent = gui

local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 8)
skipCorner.Parent = skipHolder

local skipFill = Instance.new("Frame")
skipFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
skipFill.BackgroundTransparency = 0.75
skipFill.BorderSizePixel = 0
skipFill.Size = UDim2.fromScale(0, 1)
skipFill.ZIndex = 35
skipFill.Parent = skipHolder

local skipFillCorner = Instance.new("UICorner")
skipFillCorner.CornerRadius = UDim.new(0, 8)
skipFillCorner.Parent = skipFill

local skipLabel = Instance.new("TextLabel")
skipLabel.BackgroundTransparency = 1
skipLabel.Size = UDim2.fromScale(1, 0.72)
skipLabel.Position = UDim2.fromScale(0, 0.14)
skipLabel.Font = Enum.Font.GothamBold
skipLabel.TextScaled = true
skipLabel.TextColor3 = Color3.new(1, 1, 1)
skipLabel.Text = "HOLD  E  TO SKIP"
skipLabel.ZIndex = 36
skipLabel.Parent = skipHolder

if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	skipLabel.Text = "HOLD TO SKIP"
end

--==================================================
-- GRADE
--==================================================

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "CutsceneGrade"
grade.Enabled = false
grade.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name = "CutsceneBloom"
bloom.Enabled = false
bloom.Intensity = PRESENTATION.BloomIntensity
bloom.Size = 24
bloom.Threshold = 0.9
bloom.Parent = Lighting

--==================================================
-- SOUND
--==================================================

local soundFolder = Instance.new("Folder")
soundFolder.Name = "CutsceneSounds"
soundFolder.Parent = SoundService

local function playSound(key, fadeIn)
	local spec = Config.Sounds[key]
	if not spec then return end

	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = "rbxassetid://" .. spec.Id
	sound.Volume = fadeIn and 0 or spec.Volume
	sound.Looped = spec.Looped == true
	sound.Parent = soundFolder
	sound:Play()

	if fadeIn then
		TweenService:Create(sound, TweenInfo.new(fadeIn), { Volume = spec.Volume }):Play()
	end

	table.insert(session.Sounds, sound)

	-- One-shots clean themselves up; looped ones live until the
	-- cutscene ends.
	if not sound.Looped then
		sound.Ended:Connect(function() sound:Destroy() end)
	end

	return sound
end

local function stopAllSounds(fadeOut)
	for _, sound in ipairs(session.Sounds) do
		if sound.Parent then
			if fadeOut then
				local tween = TweenService:Create(sound, TweenInfo.new(fadeOut), { Volume = 0 })
				tween:Play()
				tween.Completed:Connect(function() sound:Destroy() end)
			else
				sound:Destroy()
			end
		end
	end
	session.Sounds = {}
end

--==================================================
-- THE PLAYER'S OWN AVATAR
--
-- The saves animate an R6 stand-in, so the rig has to
-- stay R6 or every joint track would be pointing at
-- limbs that don't exist. Applying the player's
-- HumanoidDescription to an R6 rig keeps the skeleton
-- and swaps the look: body colours, shirt, pants, face
-- and hats. That is what makes it read as "you".
--==================================================

-- Clothing, copied straight off the player's live character.
--
-- This runs even when ApplyDescription succeeds, because on an
-- R6 stand-in that already has a Shirt and Pants of its own,
-- ApplyDescription reports success and applies the body colours,
-- the face and every accessory -- but leaves the existing
-- clothing untouched. The result was the player's hair, shades
-- and cape on top of the template's outfit. Copying the live
-- character's clothing afterwards is what closes that gap.
local function copyClothing(rig)
	local character = player.Character
	if not character then return end

	for _, class in ipairs({ "Shirt", "Pants", "ShirtGraphic" }) do
		local source = character:FindFirstChildOfClass(class)
		local existing = rig:FindFirstChildOfClass(class)

		if existing then existing:Destroy() end
		if source then
			source:Clone().Parent = rig
		end
	end

	-- R6 wears its face as a Decal; R15 bakes it into the head mesh,
	-- so there's often nothing to copy. The description already set
	-- the right face in that case, so only overwrite when the live
	-- character genuinely has a Decal to give.
	local sourceHead = character:FindFirstChild("Head")
	local rigHead = rig:FindFirstChild("Head")
	local sourceFace = sourceHead and sourceHead:FindFirstChildOfClass("Decal")
	local rigFace = rigHead and rigHead:FindFirstChildOfClass("Decal")
	if sourceFace and rigFace then
		rigFace.Texture = sourceFace.Texture
	end
end

local function applyAvatar(rig)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end

	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)

	if ok and description then
		-- R6 rigs don't scale, and forcing scale values onto one
		-- can shove the limbs out of their sockets mid-animation.
		description.HeightScale = 1
		description.WidthScale = 1
		description.DepthScale = 1
		description.HeadScale = 1
		description.BodyTypeScale = 0
		description.ProportionScale = 0

		pcall(function()
			humanoid:ApplyDescription(description)
		end)
	end

	-- Always, whether or not the description landed.
	pcall(copyClothing, rig)

	return true
end

--==================================================
-- BUILDING A SCENE'S PRIVATE SET
--==================================================

local function buildStage(scene)
	local container = Instance.new("Model")
	container.Name = "CutsceneStage_Local"
	container.Parent = workspace
	table.insert(session.Clones, container)

	local map = {}

	for _, propName in ipairs(scene.Props) do
		local template = PROPS:FindFirstChild(propName)
		if not template then
			warn("[Cutscene] missing prop: " .. propName)
			continue
		end

		local clone = template:Clone()

		-- A rig has to keep its limbs UNANCHORED.
		--
		-- An anchored part is pinned in world space and its Motor6D
		-- can no longer move it, so anchoring the whole model leaves
		-- the character standing frozen while the camera flies around
		-- it. Moon Animator's own preview doesn't show this because
		-- the plugin writes part CFrames directly in the editor
		-- instead of going through the joints.
		--
		-- So: anchor the root (nothing falls), free everything hanging
		-- off it, and let the joint tracks do the work.
		local humanoid = clone:IsA("Model") and clone:FindFirstChildOfClass("Humanoid") or nil
		local isRig = humanoid ~= nil
		local rootPart = isRig
			and (clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart)
			or nil

		local function prepare(part)
			-- Nothing in the set is collidable: the player's real body is
			-- frozen nearby and a 180-stud wind part landing on it would
			-- fling them across the map.
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false

			if isRig then
				part.Anchored = (part == rootPart)
				part.Massless = (part ~= rootPart)
			else
				part.Anchored = true
			end
		end

		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then prepare(d) end
		end
		if clone:IsA("BasePart") then prepare(clone) end

		clone.Parent = container
		map[propName] = clone
	end

	-- Quiet every humanoid in the set, not just the player's
	-- stand-in: a live state machine will try to stand the rig up
	-- and fight the keyframes for control of the joints.
	for _, clone in ipairs(container:GetChildren()) do
		local humanoid = clone:IsA("Model") and clone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = true
			humanoid.AutoRotate = false
			humanoid.BreakJointsOnDeath = false
			pcall(function() humanoid.EvaluateStateMachine = false end)
			pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
			for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
				if state ~= Enum.HumanoidStateType.None then
					pcall(function() humanoid:SetStateEnabled(state, false) end)
				end
			end
		end
	end

	-- the stand-in becomes the player
	local avatarRig = map[scene.AvatarProp]
	if avatarRig then
		pcall(applyAvatar, avatarRig)
	end

	return map
end

--==================================================
-- POLISH
--==================================================

local function addShake(power, time)
	table.insert(session.Shakes, { Power = power, Time = time, Elapsed = 0 })
end

local function currentShake(delta)
	local offset = Vector3.zero
	local roll = 0

	for index = #session.Shakes, 1, -1 do
		local shake = session.Shakes[index]
		shake.Elapsed = shake.Elapsed + delta

		if shake.Elapsed >= shake.Time then
			table.remove(session.Shakes, index)
		else
			-- square falloff: hits hard, settles fast
			local remaining = 1 - (shake.Elapsed / shake.Time)
			local amount = shake.Power * remaining * remaining
			offset = offset + Vector3.new(
				(math.random() * 2 - 1) * amount,
				(math.random() * 2 - 1) * amount,
				(math.random() * 2 - 1) * amount
			)
			roll = roll + (math.random() * 2 - 1) * amount * 0.01
		end
	end

	return offset, roll
end

local function doFlash(time)
	flash.BackgroundTransparency = 0.05
	TweenService:Create(flash, TweenInfo.new(time), { BackgroundTransparency = 1 }):Play()
end

local function doPunch(amount, time)
	session.FovOffset = session.FovOffset + amount

	task.spawn(function()
		local steps = math.max(1, math.floor(time * 60))
		for step = 1, steps do
			if not session.Active then return end
			session.FovOffset = session.FovOffset - (amount / steps)
			RunService.RenderStepped:Wait()
		end
	end)
end

--==================================================
-- BACKDROPS
--
-- Eases Lighting, the Atmosphere and the bloom between
-- the presets in the config, so the sky travels with the
-- camera: grass, then thinning air, then open space,
-- then the violet of the black hole.
--
-- A LocalScript writing to Lighting only affects this
-- client, so a player already in the game doesn't watch
-- the sky lurch about while someone else joins. The
-- catch is that it's global to this client, so EVERY
-- property touched has to be captured up front and put
-- back afterwards -- otherwise a skipped cutscene leaves
-- the player standing in a purple void.
--==================================================

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local sceneBloom = Lighting:FindFirstChild("Bloom")

local LIGHTING_PROPS = {
	"Ambient", "OutdoorAmbient", "Brightness",
	"ClockTime", "FogColor", "FogStart", "FogEnd",
}
local ATMOSPHERE_PROPS = { "Density", "Color", "Decay", "Haze", "Glare" }

local savedLighting, savedAtmosphere, savedBloom
local backdropTweens = {}

--------------------------------------------------
-- SKYBOXES
-- Earth scenes use the "Sky" skybox, everything from space down to
-- the boss arena uses "Space". Local clones are swapped in and out of
-- Lighting, so only this player's view changes.
--------------------------------------------------
local skyClones = {}
local activeSky = nil
do
	local sources = {}
	local skyFolder = stageFolder:FindFirstChild("Skies")
	if skyFolder then
		for _, s in ipairs(skyFolder:GetChildren()) do
			if s:IsA("Sky") then sources[s.Name] = s end
		end
	end
	for _, s in ipairs(Lighting:GetChildren()) do
		if s:IsA("Sky") then
			sources[s.Name] = sources[s.Name] or s
		end
	end
	for name, s in pairs(sources) do
		skyClones[name] = s:Clone()
	end
end

local function setSky(name)
	local want = name and skyClones[name]
	if not want or want == activeSky then return end
	-- clear every other sky out of Lighting on this client
	for _, s in ipairs(Lighting:GetChildren()) do
		if s:IsA("Sky") and s ~= want then
			s.Parent = nil
		end
	end
	want.Parent = Lighting
	activeSky = want
end

local function captureLighting()
	savedLighting = {}
	for _, property in ipairs(LIGHTING_PROPS) do
		local ok, value = pcall(function() return Lighting[property] end)
		if ok then savedLighting[property] = value end
	end

	if atmosphere then
		savedAtmosphere = {}
		for _, property in ipairs(ATMOSPHERE_PROPS) do
			local ok, value = pcall(function() return atmosphere[property] end)
			if ok then savedAtmosphere[property] = value end
		end
	end

	if sceneBloom then
		savedBloom = { Intensity = sceneBloom.Intensity, Enabled = sceneBloom.Enabled }
	end
end

local function cancelBackdropTweens()
	for _, t in ipairs(backdropTweens) do
		pcall(function() t:Cancel() end)
	end
	backdropTweens = {}
end

local function restoreLighting()
	cancelBackdropTweens()

	if savedLighting then
		for property, value in pairs(savedLighting) do
			pcall(function() Lighting[property] = value end)
		end
	end

	if atmosphere and savedAtmosphere then
		for property, value in pairs(savedAtmosphere) do
			pcall(function() atmosphere[property] = value end)
		end
	end

	if sceneBloom and savedBloom then
		sceneBloom.Intensity = savedBloom.Intensity
		sceneBloom.Enabled = savedBloom.Enabled
	end

	-- this place lives in the boss arena, whose sky is Space
	setSky("Space")
end

local function applyBackdrop(presetName, time)
	local preset = Config.Backdrops and Config.Backdrops[presetName]
	if not preset then
		warn("[Cutscene] no backdrop preset called " .. tostring(presetName))
		return
	end

	-- A new backdrop overrides whatever was still easing, or the two
	-- fight and the sky lands somewhere between them.
	cancelBackdropTweens()

	if preset.Sky then setSky(preset.Sky) end

	time = time or 1.5
	local info = TweenInfo.new(math.max(time, 0.01), Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

	local lightingGoal = {}
	for _, property in ipairs(LIGHTING_PROPS) do
		if preset[property] ~= nil then
			lightingGoal[property] = preset[property]
		end
	end

	if next(lightingGoal) then
		if time <= 0 then
			for property, value in pairs(lightingGoal) do
				pcall(function() Lighting[property] = value end)
			end
		else
			local t = TweenService:Create(Lighting, info, lightingGoal)
			t:Play()
			table.insert(backdropTweens, t)
		end
	end

	if atmosphere and preset.Atmosphere then
		if time <= 0 then
			for property, value in pairs(preset.Atmosphere) do
				pcall(function() atmosphere[property] = value end)
			end
		else
			local t = TweenService:Create(atmosphere, info, preset.Atmosphere)
			t:Play()
			table.insert(backdropTweens, t)
		end
	end

	if sceneBloom and preset.Bloom then
		local t = TweenService:Create(sceneBloom, info, { Intensity = preset.Bloom })
		t:Play()
		table.insert(backdropTweens, t)
	end

	if preset.Tint then
		local t = TweenService:Create(grade, info, { TintColor = preset.Tint })
		t:Play()
		table.insert(backdropTweens, t)
	else
		local t = TweenService:Create(grade, info, { TintColor = Color3.new(1, 1, 1) })
		t:Play()
		table.insert(backdropTweens, t)
	end
end

-- A short push on the grade, which settles back to the cutscene's
-- base look rather than to neutral.
local function doGrade(contrast, brightness, time)
	time = time or 0.4

	local peak = TweenService:Create(grade, TweenInfo.new(time * 0.35), {
		Contrast = PRESENTATION.GradeContrast + (contrast or 0),
		Brightness = brightness or 0,
	})
	peak:Play()

	task.delay(time * 0.35, function()
		if not session.Active then return end
		TweenService:Create(grade, TweenInfo.new(time * 0.65), {
			Contrast = PRESENTATION.GradeContrast,
			Brightness = 0,
		}):Play()
	end)
end

local function doBurst(map, targetName, count)
	local target = map[targetName]
	if not target then return end

	local function emit(instance)
		if instance:IsA("ParticleEmitter") then
			pcall(function() instance:Emit(count or 25) end)
		end
	end

	emit(target)
	for _, d in ipairs(target:GetDescendants()) do emit(d) end
end

local function showTitle(text, sub, time)
	titleMain.Text = text or ""
	titleSub.Text = sub or ""

	titleMain.Position = UDim2.fromScale(0.5, 0.47)
	local inInfo = TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

	TweenService:Create(titleMain, inInfo, {
		TextTransparency = 0,
		Position = UDim2.fromScale(0.5, 0.44),
	}):Play()
	TweenService:Create(titleMainStroke, inInfo, { Transparency = 0 }):Play()
	TweenService:Create(titleSub, inInfo, { TextTransparency = 0.15 }):Play()
	TweenService:Create(titleSubStroke, inInfo, { Transparency = 0.15 }):Play()

	task.delay(time or 3, function()
		local outInfo = TweenInfo.new(0.6)
		TweenService:Create(titleMain, outInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(titleMainStroke, outInfo, { Transparency = 1 }):Play()
		TweenService:Create(titleSub, outInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(titleSubStroke, outInfo, { Transparency = 1 }):Play()
	end)
end

--==================================================
-- STREAMING
--
-- This place has StreamingEnabled, which loads the map
-- around the PLAYER'S CHARACTER -- not around the
-- camera. During a cutscene the character is frozen at
-- spawn while the camera flies up to 2,700 studs away,
-- so everything it's pointed at is simply not loaded on
-- the client: the clouds, the black hole, the Earth and
-- the VFX rigs sitting beside the characters all render
-- as empty space.
--
-- Two mechanisms, because one alone isn't enough:
--
--   RequestStreamAroundAsync pulls a region in NOW, which
--   is what gets the opening frame loaded before the fade
--   lifts. But it doesn't pin anything -- measured on a
--   real run, the clouds appeared and were streamed back
--   out twice mid-scene.
--
--   ReplicationFocus is what actually keeps the region
--   loaded, and it can only be set from the server, so
--   CutsceneStreamingService does it on our behalf.
--
-- Deliberately NOT moving the character to drag streaming
-- along with it: the character's position replicates, so
-- everyone else in the server would watch the new player
-- teleport around the map and back for 22 seconds.
--==================================================

local focusRemote = ReplicatedStorage:WaitForChild("CutsceneFocus", 10)

local function prepareStreaming(points)
	if not workspace.StreamingEnabled then return end

	-- Take the focus to where the scene opens first, so the region
	-- is being held while the explicit requests fill in the rest.
	if focusRemote and points[1] then
		focusRemote:FireServer("focus", points[1])
	end

	for _, point in ipairs(points) do
		-- Best effort with a short timeout each: a slow request must
		-- not hold the cutscene up for longer than the fade covers.
		pcall(function()
			player:RequestStreamAroundAsync(point, 2)
		end)
	end
end

-- Walks the replication focus along with the camera for as long as
-- the scene runs. Returns a stop function.
local function followStreamingWithCamera()
	if not workspace.StreamingEnabled or not focusRemote then
		return function() end
	end

	local running = true

	task.spawn(function()
		local lastPoint = nil
		while running do
			local position = camera.CFrame.Position

			if not lastPoint or (position - lastPoint).Magnitude > 40 then
				lastPoint = position
				focusRemote:FireServer("focus", position)

				-- A hard cut can jump further than the streaming system
				-- will fill in on its own, so ask for that region too.
				task.spawn(function()
					pcall(function()
						player:RequestStreamAroundAsync(position, 1)
					end)
				end)
			end

			task.wait(0.2)
		end
	end)

	return function() running = false end
end

local function releaseStreaming()
	if focusRemote then
		focusRemote:FireServer("stop")
	end
end

--==================================================
-- CONTROL OF THE REAL CHARACTER
--==================================================

local hiddenParts = {}

-- LocalTransparencyModifier is a client-only override, so this hides
-- a body on this screen without touching what the server or anyone
-- else sees.
local function hideModel(model)
	if not model then return end

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if hiddenParts[d] == nil then
				hiddenParts[d] = d.LocalTransparencyModifier
			end
			d.LocalTransparencyModifier = 1
		elseif d:IsA("Decal") then
			if hiddenParts[d] == nil then
				hiddenParts[d] = d.Transparency
			end
			d.Transparency = 1
		elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
			if hiddenParts[d] == nil then
				hiddenParts[d] = d.Enabled
			end
			d.Enabled = false
		end
	end
end

--==================================================
-- OTHER PLAYERS
--
-- The cutscene is a private performance, but it happens
-- in the live world -- so anyone already standing near
-- spawn, or walking through a shot, would be in it.
-- Every other character is hidden for the duration, and
-- anyone who joins or respawns mid-cutscene is hidden as
-- they appear.
--==================================================

local otherPlayerConnections = {}

local function hideOtherPlayers()
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			hideModel(other.Character)

			-- respawns during the cutscene arrive as a fresh model
			table.insert(otherPlayerConnections, other.CharacterAdded:Connect(function(character)
				if not session.Active then return end
				task.wait(0.2)
				if session.Active then hideModel(character) end
			end))
		end
	end

	table.insert(otherPlayerConnections, Players.PlayerAdded:Connect(function(other)
		if not session.Active then return end
		other.CharacterAdded:Connect(function(character)
			if not session.Active then return end
			task.wait(0.2)
			if session.Active then hideModel(character) end
		end)
	end))
end

local function stopWatchingOtherPlayers()
	for _, connection in ipairs(otherPlayerConnections) do
		connection:Disconnect()
	end
	otherPlayerConnections = {}
end

local function hideCharacter()
	local character = player.Character
	if not character then return end

	-- Anchor them where they stand. They're frozen and invisible for
	-- the next half minute, and an unanchored body can still slide,
	-- fall or get shoved in the meantime.
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
	end

	hideModel(character)
	hideOtherPlayers()

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
end

local function showCharacter()
	local restoreTarget = player.Character
	local restoreRoot = restoreTarget and restoreTarget:FindFirstChild("HumanoidRootPart")
	if restoreRoot then
		restoreRoot.Anchored = false
		restoreRoot.AssemblyLinearVelocity = Vector3.zero

		-- Make sure the ground under them is loaded before they can
		-- see and move again, or they drop through an unstreamed map.
		if workspace.StreamingEnabled then
			pcall(function()
				player:RequestStreamAroundAsync(restoreRoot.Position, 3)
			end)
		end
	end

	stopWatchingOtherPlayers()

	for instance, original in pairs(hiddenParts) do
		if instance.Parent then
			if instance:IsA("BasePart") then
				instance.LocalTransparencyModifier = original
			elseif instance:IsA("Decal") then
				instance.Transparency = original
			else
				instance.Enabled = original
			end
		end
	end
	table.clear(hiddenParts)

	local humanoid = restoreTarget and restoreTarget:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
	end
end

--==================================================
-- SKIP
--==================================================

local skipHeld = false

local function watchSkip()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not session.Active then return end
		if input.KeyCode == Enum.KeyCode.E or input.UserInputType == Enum.UserInputType.Touch then
			skipHeld = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.E or input.UserInputType == Enum.UserInputType.Touch then
			skipHeld = false
		end
	end)

	task.spawn(function()
		local held = 0
		while true do
			local delta = RunService.RenderStepped:Wait()
			if not session.Active then
				held = 0
				skipFill.Size = UDim2.fromScale(0, 1)
				continue
			end

			if skipHeld then
				held = held + delta
			else
				held = math.max(0, held - delta * 2)
			end

			skipFill.Size = UDim2.fromScale(
				math.clamp(held / PRESENTATION.SkipHoldTime, 0, 1), 1)

			if held >= PRESENTATION.SkipHoldTime then
				session.Skipped = true
				held = 0
			end
		end
	end)
end

--==================================================
-- RUNNING A SCENE
--==================================================

--------------------------------------------------
-- cloud decks for a scene (clouds are defined later in the file, so
-- this is a forward-declared hook filled in once makeCloudField exists)
--------------------------------------------------
local buildSceneClouds

--------------------------------------------------
-- BLACK HOLE TRANSITION
-- After the last frame of scene 2 the camera is dragged into the
-- black hole: it accelerates down the throat, spinning faster and
-- faster, the field of view stretches, streaks of light pour past,
-- the picture crushes to a point and goes black.
--------------------------------------------------
local function runBlackHoleTransition(map)
	local hole = map["blackhole"] or map["blackhole copy"]
	if not hole then return end
	local centre = hole:IsA("Model") and hole:GetPivot().Position or hole.Position

	local from = camera.CFrame
	local startPos = from.Position
	local dir = (centre - startPos)
	local dist = dir.Magnitude
	if dist < 1 then return end
	dir = dir.Unit

	-- streaks rushing out of the hole past the camera
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Parent = workspace
	table.insert(session.Clones, holder)
	local att = Instance.new("Attachment")
	att.Parent = holder
	local streaks = Instance.new("ParticleEmitter")
	streaks.Texture = "rbxassetid://1053548563"
	streaks.Color = ColorSequence.new(Color3.fromRGB(210, 170, 255), Color3.fromRGB(255, 190, 120))
	streaks.LightEmission = 1
	streaks.LightInfluence = 0
	streaks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 10),
		NumberSequenceKeypoint.new(1, 0),
	})
	streaks.Transparency = NumberSequence.new(0.2, 1)
	streaks.Lifetime = NumberRange.new(0.3, 0.55)
	streaks.Speed = NumberRange.new(250, 420)
	streaks.SpreadAngle = Vector2.new(35, 35)
	streaks.EmissionDirection = Enum.NormalId.Front
	streaks.Rate = 0
	streaks.Parent = att

	-- darkness closing in from the edges: four black gradient edges
	-- that grow inward until they meet in the middle
	local tunnelEdges = {}
	local edgeSpecs = {
		{ Anchor = Vector2.new(0.5, 0), Pos = UDim2.fromScale(0.5, 0), Rot = 90,  Horizontal = true },
		{ Anchor = Vector2.new(0.5, 1), Pos = UDim2.fromScale(0.5, 1), Rot = -90, Horizontal = true },
		{ Anchor = Vector2.new(0, 0.5), Pos = UDim2.fromScale(0, 0.5), Rot = 0,   Horizontal = false },
		{ Anchor = Vector2.new(1, 0.5), Pos = UDim2.fromScale(1, 0.5), Rot = 180, Horizontal = false },
	}
	for _, e in ipairs(edgeSpecs) do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = e.Anchor
		f.Position = e.Pos
		f.ZIndex = 18
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = e.Rot
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.55, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
		table.insert(tunnelEdges, { Frame = f, Horizontal = e.Horizontal })
	end
	local function setTunnel(amount)
		for _, e in ipairs(tunnelEdges) do
			if e.Horizontal then
				e.Frame.Size = UDim2.fromScale(1, 0.1 + amount * 0.55)
			else
				e.Frame.Size = UDim2.fromScale(0.1 + amount * 0.55, 1)
			end
		end
	end
	setTunnel(0)

	playSound("Rumble", 0.4)
	playSound("Riser")
	local duration = 4.2
	local start, last = os.clock(), os.clock()
	local spin = 0
	local flashed = false

	while not session.Skipped do
		local now = os.clock()
		local delta = now - last
		last = now
		local p = math.clamp((now - start) / duration, 0, 1)

		-- slow creep, then the throat grabs you
		local travel = (p ^ 2.6) * (dist - 8)
		local pos = startPos + dir * travel
		spin = spin + delta * (0.2 + p * p * 9)
		local cf = CFrame.lookAt(pos, centre) * CFrame.Angles(0, 0, spin)

		local wobble = p * p * 0.6
		cf = cf * CFrame.Angles(
			math.rad(math.noise(now * 7, 3) * 8 * wobble),
			math.rad(math.noise(now * 7, 4) * 8 * wobble), 0)
		local offset, roll = currentShake(delta)
		camera.CFrame = cf * CFrame.new(offset) * CFrame.Angles(0, 0, roll)
		camera.FieldOfView = math.clamp(PRESENTATION.BaseFieldOfView + p * p * 55, 1, 120)

		holder.CFrame = CFrame.lookAt(centre, pos)
		streaks.Rate = 40 + 420 * p * p

		-- edges fall away into the hole
		setTunnel(p ^ 1.7)

		grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(200, 150, 255), p)
		grade.Saturation = PRESENTATION.GradeSaturation - p * 0.4

		if p > 0.35 and p < 0.4 then addShake(0.8 * p, 0.4) end
		if not flashed and p > 0.93 then
			flashed = true
			playSound("Boom")
			doFlash(0.25)
			addShake(3, 0.6)
		end

		if p >= 1 then break end
		RunService.RenderStepped:Wait()
	end

	fade.BackgroundTransparency = 0
	for _, e in ipairs(tunnelEdges) do e.Frame:Destroy() end
	streaks.Rate = 0
end

local function runScene(scene)
	local save = SAVES:FindFirstChild(scene.Save)
	if not save then
		warn("[Cutscene] missing save: " .. scene.Save)
		return
	end

	local map = buildStage(scene)
	map["CurrentCamera"] = camera

	local moon, err = MoonPlayer.new(save, map)
	if not moon then
		warn("[Cutscene] " .. scene.Save .. ": " .. tostring(err))
		return
	end

	if #moon.Missing > 0 then
		warn("[Cutscene] " .. scene.Save .. " couldn't resolve: "
			.. table.concat(moon.Missing, ", "))
	end

	-- Pull the map in around every position this scene visits before
	-- a single frame plays. This happens behind the black fade, so
	-- the wait costs nothing on screen.
	prepareStreaming(moon:GetFocusPoints())

	-- Prime frame 0 and hold it for a beat before the fade lifts,
	-- so the first thing on screen is the scene and not whatever
	-- the camera happened to be looking at.
	moon:Seek(0)
	if scene.Clouds and buildSceneClouds then
		pcall(buildSceneClouds, scene.Clouds)
	end
	task.wait(0.35)

	local fired = {}
	local done = false
	local lastElapsed = 0

	local function fireCue(cue)
		if cue.Kind == "Sound" then
			playSound(cue.Key, cue.FadeIn)
		elseif cue.Kind == "Shake" then
			addShake(cue.Power, cue.Time)
		elseif cue.Kind == "Flash" then
			doFlash(cue.Time or 0.4)
		elseif cue.Kind == "Punch" then
			doPunch(cue.Amount, cue.Time or 0.5)
		elseif cue.Kind == "Burst" then
			doBurst(map, cue.Target, cue.Count)
		elseif cue.Kind == "Title" then
			showTitle(cue.Text, cue.Sub, cue.Time)
		elseif cue.Kind == "Backdrop" then
			applyBackdrop(cue.Preset, cue.Time)
		elseif cue.Kind == "Grade" then
			doGrade(cue.Contrast, cue.Brightness, cue.Time)
		end
	end

	-- fade up
	TweenService:Create(fade, TweenInfo.new(PRESENTATION.FadeTime),
		{ BackgroundTransparency = 1 }):Play()

	moon:Play({
		TimeWarp = scene.TimeWarp,
		OnFrame = function(frame, elapsed)
			-- cues
			for index, cue in ipairs(scene.Cues) do
				if not fired[index] and frame >= cue.Frame then
					fired[index] = true
					fireCue(cue)
				end
			end

			-- Shake and FOV ride on top of whatever the animation just
			-- set, which is why this runs inside OnFrame -- MoonPlayer
			-- calls it after applying the tracks, in the same render
			-- step. On its own loop it would be fighting the camera
			-- track for the same property and lose half the time.
			local delta = math.max(elapsed - lastElapsed, 0)
			lastElapsed = elapsed

			local offset, roll = currentShake(delta)
			if offset.Magnitude > 0 or roll ~= 0 then
				camera.CFrame = camera.CFrame
					* CFrame.new(offset)
					* CFrame.Angles(0, 0, roll)
			end

			camera.FieldOfView = PRESENTATION.BaseFieldOfView + session.FovOffset

			if session.Skipped then
				moon:Stop()
				done = true
			end
		end,

		OnFinished = function()
			done = true
		end,
	})

	local stopStreamFollow = followStreamingWithCamera()

	-- prompt shows a little way in, so a first-time player sees
	-- some of it before being offered the exit
	task.delay(PRESENTATION.SkipPromptAfter, function()
		if session.Active and not session.Skipped then
			skipHolder.Visible = true
		end
	end)

	while not done and not session.Skipped do
		task.wait(0.05)
	end

	stopStreamFollow()
	moon:Stop()

	if scene.EndTransition == "BlackHole" and not session.Skipped then
		runBlackHoleTransition(map)
	end

	-- fade down before tearing the set apart
	TweenService:Create(fade, TweenInfo.new(PRESENTATION.FadeTime * 0.6),
		{ BackgroundTransparency = 0 }):Play()
	task.wait(PRESENTATION.FadeTime * 0.6)

	for _, clone in ipairs(session.Clones) do
		if clone.Parent then clone:Destroy() end
	end
	session.Clones = {}
end

--==================================================
-- THE DESCENT
--
-- Generated rather than animated: it has to finish with
-- the player's real body standing in the boss arena, and
-- where that is belongs to the map, not to a keyframe.
-- Four beats: fall, impact, black, wake.
--==================================================

local function buildFallingRig()
	local template = PROPS:FindFirstChild("TemplateR6")
	if not template then return nil end

	local rig = template:Clone()
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = true
		end
	end

	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
		pcall(function() humanoid.EvaluateStateMachine = false end)
	end

	return rig
end

-- Speed lines and re-entry burn on the falling body, built from the
-- same light-ray and flare textures as the rest of the pack.
local function newEmitter(parent, name, texture, color, size, lifetime, speed, spread)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = lifetime
	e.Rate = 0
	e.Speed = speed
	e.SpreadAngle = Vector2.new(spread, spread)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
	return e
end

local function buildEntryEffects(rig, color)
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local attachment = Instance.new("Attachment")
	attachment.Name = "EntryOrigin"
	attachment.Parent = root

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 0
	light.Range = 40
	light.Shadows = false
	light.Parent = root

	return {
		Streaks = newEmitter(attachment, "Streaks", "rbxassetid://1053548563", color,
			7, NumberRange.new(0.35, 0.6), NumberRange.new(40, 70), 12),
		Burn = newEmitter(attachment, "Burn", "rbxassetid://14684195806", color,
			12, NumberRange.new(0.5, 0.8), NumberRange.new(4, 10), 30),
		Light = light,
	}
end

-- The map already carries splash and spark emitters for exactly this,
-- loose in BossFightMap.Folder with no part to emit from. Copy them
-- onto a throwaway anchor at the landing point and fire them once.
local function fireArenaSplash(position)
	local map = workspace:FindFirstChild("BossFightMap", true)
	local folder = map and map:FindFirstChild("Folder")
	if not folder then return end

	local anchor = Instance.new("Part")
	anchor.Name = "LandingSplash"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	for _, source in ipairs(folder:GetChildren()) do
		if source:IsA("ParticleEmitter") then
			local clone = source:Clone()
			clone.Enabled = false
			clone.Parent = anchor
			pcall(function() clone:Emit(45) end)
		end
	end

	game:GetService("Debris"):AddItem(anchor, 6)
end

--------------------------------------------------
-- first-person helpers
--------------------------------------------------

local ARM_NAMES = { "Left Arm", "Right Arm" }

-- Heat haze around the edges of the screen, orange and pulsing,
-- built from four gradient frames (no image assets needed).
local function buildHeatVignette()
	local holder = Instance.new("Frame")
	holder.Name = "HeatVignette"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 15
	holder.Parent = gui

	local edges = {}
	local specs = {
		{ Size = UDim2.fromScale(1, 0.38), Pos = UDim2.fromScale(0, 0),    Rot = 90 },
		{ Size = UDim2.fromScale(1, 0.38), Pos = UDim2.fromScale(0, 0.62), Rot = -90 },
		{ Size = UDim2.fromScale(0.3, 1),  Pos = UDim2.fromScale(0, 0),    Rot = 0 },
		{ Size = UDim2.fromScale(0.3, 1),  Pos = UDim2.fromScale(0.7, 0),  Rot = 180 },
	}
	for _, spec in ipairs(specs) do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(255, 110, 30)
		f.Size = spec.Size
		f.Position = spec.Pos
		f.ZIndex = 15
		f.Parent = holder
		local g = Instance.new("UIGradient")
		g.Rotation = spec.Rot
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 70, 10))
		g.Parent = f
		f.BackgroundTransparency = 1
		table.insert(edges, f)
	end

	local tint = Instance.new("Frame")
	tint.Name = "LayerTint"
	tint.BorderSizePixel = 0
	tint.BackgroundColor3 = Color3.new(1, 1, 1)
	tint.BackgroundTransparency = 1
	tint.Size = UDim2.fromScale(1, 1)
	tint.ZIndex = 16
	tint.Parent = gui

	return {
		Holder = holder,
		Tint = tint,
		Set = function(amount, t)
			local pulse = 0.12 * math.sin(t * 9) + 0.08 * math.sin(t * 23)
			local a = math.clamp(amount + pulse * amount, 0, 1)
			for _, f in ipairs(edges) do
				f.BackgroundTransparency = 1 - a * 0.85
			end
		end,
		Destroy = function()
			holder:Destroy()
			tint:Destroy()
		end,
	}
end

-- Physical cloud layers: clusters of soft overlapping spheres scattered
-- around a column, so the camera flies (or falls) through real volume
-- instead of a flat sheet. Built locally, so only this player has them.
local function makeCloudField(parent, centre, y, opts)
	opts = opts or {}
	local radius = opts.Radius or 500
	local clusters = opts.Clusters or 30
	local color = opts.Color or Color3.fromRGB(240, 242, 255)
	local transparency = opts.Transparency or 0.3
	local neon = opts.Neon
	local scale = opts.Scale or 1
	local thickness = opts.Thickness or 40
	local rng = Random.new(opts.Seed or math.floor(y))
	local field = Instance.new("Model")
	field.Name = opts.Name or "CloudField"
	field.Parent = parent

	for i = 1, clusters do
		-- the first few sit right on the flight path so we punch through
		local r = i <= 4 and rng:NextNumber(0, 40) or math.sqrt(rng:NextNumber()) * radius
		local ang = rng:NextNumber(0, math.pi * 2)
		local cx = centre.X + math.cos(ang) * r
		local cz = centre.Z + math.sin(ang) * r
		local cy = y + rng:NextNumber(-thickness, thickness) * 0.5
		local puffs = rng:NextInteger(3, 6)
		local size = rng:NextNumber(38, 80) * scale
		for k = 1, puffs do
			local ball = Instance.new("Part")
			ball.Shape = Enum.PartType.Ball
			ball.Anchored = true
			ball.CanCollide = false
			ball.CanQuery = false
			ball.CanTouch = false
			ball.CastShadow = false
			ball.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
			local shade = rng:NextNumber(0.88, 1)
			ball.Color = Color3.new(color.R * shade, color.G * shade, color.B * shade)
			ball.Transparency = math.clamp(transparency + rng:NextNumber(-0.08, 0.12), 0, 0.95)
			local s2 = size * rng:NextNumber(0.55, 1.1)
			ball.Size = Vector3.new(s2, s2, s2)
			ball.CFrame = CFrame.new(
				cx + rng:NextNumber(-size, size) * 0.6,
				cy + rng:NextNumber(-size, size) * 0.18,
				cz + rng:NextNumber(-size, size) * 0.6)
			ball.Parent = field
		end
	end
	return field
end

buildSceneClouds = function(clouds)
	local container = Instance.new("Model")
	container.Name = "CutsceneClouds_Local"
	container.Parent = workspace
	table.insert(session.Clones, container)
	for i, deck in ipairs(clouds.Decks or {}) do
		makeCloudField(container, clouds.Centre, deck.Y, {
			Name = "Deck" .. i,
			Color = deck.Color,
			Transparency = deck.Transparency,
			Clusters = deck.Clusters,
			Radius = deck.Radius,
			Scale = deck.Scale or 1.2,
			Thickness = deck.Thickness or 50,
			Seed = i * 31,
		})
	end
end

local function buildLayers(spec, container)
	local layers = {}
	local topY = spec.Landing.Y + spec.StartHeight
	for i, l in ipairs(spec.Layers or {}) do
		local y = topY - l.At * spec.StartHeight
		local isBurn = (l.Name or ""):find("Burn") ~= nil
		local isCloud = (l.Name or ""):find("Cloud") ~= nil

		-- the volume: thick cumulus for cloud layers, glowing plasma
		-- wisps for the burn layers, thin tinted haze banks up high
		-- Up here the only light is starlight, so plain parts render as
		-- dark grey blobs. Neon makes the vapour self-lit: soft glowing
		-- cloud decks and plasma, dimmed so it doesn't bloom to white.
		local glow = isBurn and 1 or (isCloud and 0.62 or 0.5)
		makeCloudField(container, spec.Landing, y, {
			Name = "Layer_" .. (l.Name or i),
			Color = Color3.new(l.Color.R * glow, l.Color.G * glow, l.Color.B * glow),
			Transparency = isCloud and 0.42 or (isBurn and 0.55 or 0.66),
			Neon = true,
			Clusters = isCloud and 42 or 26,
			Radius = isCloud and 650 or 520,
			Scale = isCloud and 1.25 or 0.9,
			Thickness = isCloud and 70 or 30,
			Seed = i * 97,
		})

		-- faint haze sheet so the layer still reads as a band from afar
		local sheet = Instance.new("Part")
		sheet.Name = "Haze_" .. (l.Name or "")
		sheet.Anchored = true
		sheet.CanCollide = false
		sheet.CanQuery = false
		sheet.CanTouch = false
		sheet.CastShadow = false
		sheet.Material = Enum.Material.SmoothPlastic
		sheet.Color = l.Color
		sheet.Transparency = 1
		sheet.Size = Vector3.new(2048, 1, 2048)
		sheet.CFrame = CFrame.new(spec.Landing.X, y, spec.Landing.Z)
		sheet.Parent = container

		-- burst of vapour as we pass
		local att = Instance.new("Attachment")
		att.Parent = sheet
		local puffs = Instance.new("ParticleEmitter")
		puffs.Texture = "rbxasset://textures/particles/smoke_main.dds"
		puffs.Color = ColorSequence.new(l.Color)
		puffs.LightEmission = isBurn and 0.8 or 0.3
		puffs.LightInfluence = 0
		puffs.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 14),
			NumberSequenceKeypoint.new(1, 36),
		})
		puffs.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		puffs.Lifetime = NumberRange.new(0.8, 1.4)
		puffs.Speed = NumberRange.new(30, 80)
		puffs.SpreadAngle = Vector2.new(180, 180)
		puffs.Rate = 0
		puffs.Parent = att

		table.insert(layers, {
			Y = y, Color = l.Color, Sheet = sheet, Under = sheet,
			Base = isCloud and 0.8 or 0.88, Attachment = att, Puffs = puffs, Passed = false,
		})
	end
	return layers
end

-- Places an R6 arm so it hangs from `shoulder` (camera space) and
-- points along `dir` (camera space), then converts to world.
local function armCFrame(camCF, shoulder, dir, roll)
	dir = dir.Unit
	local up = -dir                           -- an R6 arm's hand is at its -Y end
	local right = Vector3.new(1, 0, 0)
	if math.abs(right:Dot(up)) > 0.95 then right = Vector3.new(0, 0, 1) end
	local back = right:Cross(up).Unit
	right = up:Cross(back).Unit
	local centre = shoulder + dir * 1.0
	local cf = CFrame.fromMatrix(centre, right, up, back) * CFrame.Angles(0, roll or 0, 0)
	return camCF * cf
end

local function runDescent()
	local spec = Config.Descent
	if not spec or not spec.Enabled or session.Skipped then return end

	local landing = spec.Landing
	local startPosition = landing + Vector3.new(0, spec.StartHeight, 0)

	-- 0. HOLD ON BLACK -- a breath between the black hole and the fall
	fade.BackgroundTransparency = 0
	prepareStreaming({ startPosition, landing })
	playSound("Drone", 1.5)
	local holdStart = os.clock()
	while not session.Skipped and os.clock() - holdStart < (spec.PreDelay or 0) do
		RunService.RenderStepped:Wait()
	end
	if session.Skipped then return end

	local stopFollow = followStreamingWithCamera()

	local rig = buildFallingRig()
	if not rig then stopFollow() return end

	local container = Instance.new("Model")
	container.Name = "CutsceneStage_Local"
	container.Parent = workspace
	table.insert(session.Clones, container)
	rig.Parent = container
	pcall(applyAvatar, rig)

	local torso = rig:FindFirstChild("Torso")
	local arms, armRest = {}, {}
	for _, name in ipairs(ARM_NAMES) do
		local arm = rig:FindFirstChild(name)
		if arm and torso then
			arms[name] = arm
			armRest[name] = torso.CFrame:ToObjectSpace(arm.CFrame)
			-- free the arm so we can pose it by hand for the first-person view
			for _, j in ipairs(torso:GetChildren()) do
				if j:IsA("JointInstance") and j.Part1 == arm then j.Enabled = false end
			end
		end
	end

	-- First person: everything but the arms is invisible to us.
	local function setBodyHidden(hidden)
		for _, d in ipairs(rig:GetDescendants()) do
			if d:IsA("BasePart") then
				local isArm = arms[d.Name] == d
				d.LocalTransparencyModifier = (hidden and not isArm) and 1 or 0
			elseif d:IsA("Decal") and d.Parent and d.Parent.Name == "Head" then
				d.Transparency = hidden and 1 or 0
			end
		end
	end
	setBodyHidden(true)

	-- Arms on fire
	local armFires = {}
	for _, arm in pairs(arms) do
		local f = Instance.new("Fire")
		f.Color = Color3.fromRGB(255, 120, 30)
		f.SecondaryColor = Color3.fromRGB(255, 220, 90)
		f.Heat = 18
		f.Size = 2
		f.Enabled = false
		f.Parent = arm
		table.insert(armFires, f)
	end

	-- Streaks and embers rush up past the camera from an emitter
	-- that rides below it.
	local rushPart = Instance.new("Part")
	rushPart.Name = "RushFX"
	rushPart.Anchored = true
	rushPart.CanCollide = false
	rushPart.CanQuery = false
	rushPart.CanTouch = false
	rushPart.Transparency = 1
	rushPart.Size = Vector3.new(30, 1, 30)
	rushPart.Parent = container
	local rushAtt = Instance.new("Attachment")
	rushAtt.Parent = rushPart
	local streaks = newEmitter(rushAtt, "Streaks", "rbxassetid://1053548563", Color3.fromRGB(255, 240, 220),
		9, NumberRange.new(0.25, 0.4), NumberRange.new(160, 240), 25)
	local embers = newEmitter(rushAtt, "Embers", "rbxassetid://14684195806", spec.EntryColor,
		4, NumberRange.new(0.3, 0.5), NumberRange.new(120, 200), 35)
	local heatLight = Instance.new("PointLight")
	heatLight.Color = spec.EntryColor
	heatLight.Range = 30
	heatLight.Brightness = 0
	heatLight.Parent = rushPart

	local layers = buildLayers(spec, container)
	local vignette = buildHeatVignette()

	applyBackdrop("space", 0)
	camera.FieldOfView = 80
	rig:PivotTo(CFrame.new(startPosition))
	task.wait(0.1)

	TweenService:Create(fade, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	playSound("Rumble", 1.0)
	playSound("Riser")

	-- 1. THE FALL (first person)
	local start, last = os.clock(), os.clock()
	local enteredFire, enteredClouds = false, false
	local heading = math.rad(35)

	while not session.Skipped do
		local now = os.clock()
		local delta = now - last
		last = now
		local t = now - start

		local p = math.clamp(t / spec.FallTime, 0, 1)
		-- slow drift in space, then gravity takes over hard
		local fallen = p < 0.15 and (p / 0.15) * 0.03 or 0.03 + ((p - 0.15) / 0.85) ^ 1.8 * 0.97
		local eye = startPosition - Vector3.new(0, spec.StartHeight * fallen, 0) + Vector3.new(0, 1.5, 0)

		local burn = math.clamp((p - spec.BurnStart) / (spec.BurnPeak - spec.BurnStart), 0, 1)
		-- fire dies down once we're through the burn and into clouds
		local heat = burn * (1 - math.clamp((p - 0.72) / 0.15, 0, 1))

		-- looking down at the arena, tilted forward, tumbling a little
		heading = heading + delta * (0.15 + heat * 0.6)
		local forward = Vector3.new(math.cos(heading), 0, math.sin(heading))
		local tumble = math.sin(t * 1.7) * 0.10 + math.sin(t * 4.3) * 0.05 * heat
		local look = (Vector3.new(0, -1, 0) + forward * (0.55 + math.sin(t * 0.9) * 0.1)).Unit
		local camCF = CFrame.lookAt(eye, eye + look) * CFrame.Angles(0, 0, tumble)

		-- continuous buffeting that grows with heat
		local jitter = (0.05 + heat * 0.35 + p * 0.1)
		camCF = camCF * CFrame.Angles(
			math.rad((math.noise(t * 11, 1) ) * 6 * jitter),
			math.rad((math.noise(t * 11, 2) ) * 6 * jitter), 0)

		local offset, roll = currentShake(delta)
		if offset.Magnitude > 0 then
			camCF = camCF * CFrame.new(offset) * CFrame.Angles(0, 0, roll)
		end
		camera.CFrame = camCF
		camera.FieldOfView = 80 + heat * 12 + math.max(0, p - 0.85) * 60

		-- body sits just behind the eye so the arms come from our shoulders
		rig:PivotTo(camCF * CFrame.new(0, -1.5, 0.6) * CFrame.Angles(math.rad(-90), 0, 0))

		-- flailing arms: reaching down at the ground, clawing wildly as
		-- the heat rises
		local flail = 0.25 + heat * 1.0 + math.max(0, p - 0.8) * 1.5
		for i, name in ipairs(ARM_NAMES) do
			local arm = arms[name]
			if arm then
				local side = (i == 1) and -1 or 1
				local ph = t * (5 + heat * 9) + i * 1.9
				-- shoulders just below/beside the eye, arms thrust forward into
				-- view (hands ~2 studs out), swinging harder as it heats up
				local dir = Vector3.new(
					side * (0.22 + math.sin(ph) * 0.3 * flail),
					-0.18 + math.sin(ph * 1.3 + 0.7) * 0.35 * flail,
					-1)
				local shoulder = Vector3.new(side * 0.95, -1.0 + math.sin(ph * 0.8) * 0.12 * flail, 0.1)
				arm.CFrame = armCFrame(camCF, shoulder, dir, math.sin(ph * 1.7) * 0.6 * flail)
			end
		end

		-- fire
		for _, f in ipairs(armFires) do
			f.Enabled = heat > 0.05
			f.Size = 1.5 + heat * 5
		end
		vignette.Set(heat * 0.9, t)
		rushPart.CFrame = CFrame.new(eye - Vector3.new(0, 45, 0))
		streaks.Rate = 25 + 140 * math.max(heat, p * 0.6)
		embers.Rate = 160 * heat
		heatLight.Brightness = 4 * heat

		if not enteredFire and heat > 0.1 then
			enteredFire = true
			playSound("Whoosh")
			addShake(0.8, spec.FallTime * 0.5)
			applyBackdrop("galaxy", 2.5)
		end
		if not enteredClouds and p > 0.7 then
			enteredClouds = true
			applyBackdrop(Config.Playback.EndBackdrop or "arena", 1.5)
		end

		-- Layers only materialise as we close in (otherwise seven stacked
		-- sheets would hide the arena from orbit) and thin out behind us.
		for _, layer in ipairs(layers) do
			local d = eye.Y - layer.Y
			local alpha = d >= 0 and math.clamp(1 - d / 320, 0, 1) or math.clamp(1 + d / 160, 0, 1)
			layer.Sheet.Transparency = 1 - (1 - layer.Base) * alpha
			layer.Under.Transparency = 1 - (1 - layer.Base) * alpha * 0.6
		end

		-- punching through a layer
		for _, layer in ipairs(layers) do
			if not layer.Passed and eye.Y <= layer.Y then
				layer.Passed = true
				layer.Attachment.WorldPosition = Vector3.new(eye.X, layer.Y, eye.Z)
				pcall(function() layer.Puffs:Emit(40) end)
				vignette.Tint.BackgroundColor3 = layer.Color
				vignette.Tint.BackgroundTransparency = 0.25
				TweenService:Create(vignette.Tint, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
				addShake(1.6, 0.45)
				doPunch(8, 0.35)
				playSound("Boom")
			end
		end

		if p >= 1 then break end
		RunService.RenderStepped:Wait()
	end

	-- 2. IMPACT
	for _, f in ipairs(armFires) do f.Enabled = false end
	streaks.Rate, embers.Rate, heatLight.Brightness = 0, 0, 0
	vignette.Set(0, 0)
	fireArenaSplash(landing)
	playSound("Boom")
	playSound("Impact")
	doFlash(0.5)
	addShake(5, 1.4)
	camera.CFrame = CFrame.lookAt(landing + Vector3.new(0, 1.2, 0), landing + Vector3.new(1, 0.2, 0))
	task.wait(spec.ImpactHold)

	-- 3. BLACK
	TweenService:Create(fade, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
	task.wait(0.3 + spec.BlackHold)
	vignette.Destroy()

	-- Put the body back together for the third-person wake-up: limbs go
	-- back on their joints (unanchored, root stays anchored) so the
	-- stand-up can be posed joint by joint.
	for _, j in ipairs(rig:GetDescendants()) do
		if j:IsA("JointInstance") then j.Enabled = true end
	end
	local rootPart = rig:FindFirstChild("HumanoidRootPart")
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BasePart") and d ~= rootPart then
			d.Anchored = false
			d.Massless = true
		end
	end
	setBodyHidden(false)
	camera.FieldOfView = PRESENTATION.BaseFieldOfView

	local joints = {}
	if torso then
		for _, name in ipairs({ "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip", "Neck" }) do
			local j = torso:FindFirstChild(name)
			if j and j:IsA("Motor6D") then
				joints[name] = { Joint = j, C0 = j.C0 }
			end
		end
	end

	-- rotate a limb about its joint, in torso space (X = right, Y = up,
	-- Z = back). +X swings an arm/leg forward, +Z swings a right limb out.
	local function pose(name, rx, ry, rz)
		local entry = joints[name]
		if not entry then return end
		local c0 = entry.C0
		entry.Joint.C0 = CFrame.new(c0.Position)
			* CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
			* (c0 - c0.Position)
	end

	-- 4. WAKING UP (third person). Keyframed get-up: sprawled face down,
	-- head turned -> twitch -> plants both hands -> push-up -> one knee
	-- -> hunched stand -> straightens and looks up at the boss.
	applyBackdrop(Config.Playback.EndBackdrop or "arena", 0)
	playSound("Ambience", 1.5)
	TweenService:Create(fade, TweenInfo.new(1.6), { BackgroundTransparency = 1 }):Play()

	-- root = { height above floor, forward offset, pitch, roll }
	-- limbs = { x, y, z } degrees
	local K = {
		-- sprawled face down, head turned to the side
		{ t = 0.00, root = { 0.55, 0, -90, 0 },    RS = { 0, 0, 12 },  LS = { 0, 0, -18 }, RH = { 0, 0, 6 },  LH = { 0, 0, -3 },  N = { 0, 40, 0 } },
		-- a twitch of the hand and leg
		{ t = 0.14, root = { 0.55, 0, -90, 0 },    RS = { 6, 0, 16 },  LS = { 0, 0, -18 }, RH = { 0, 0, 6 },  LH = { 4, 0, -3 },  N = { 5, 38, 0 } },
		-- slides both hands up beside the shoulders, head comes round
		{ t = 0.26, root = { 0.55, 0, -90, 0 },    RS = { 12, 0, 34 }, LS = { 12, 0, -34 }, RH = { 0, 0, 6 },  LH = { 0, 0, -3 },  N = { 15, 8, 0 } },
		{ t = 0.34, root = { 0.58, 0, -89, 0 },    RS = { 18, 0, 26 }, LS = { 18, 0, -26 }, RH = { 0, 0, 5 },  LH = { 0, 0, -5 },  N = { 28, 0, 0 } },
		-- push-up: chest off the floor, feet stay planted
		{ t = 0.46, root = { 1.55, 0.3, -62, 0 },  RS = { 62, 0, 14 }, LS = { 62, 0, -14 }, RH = { -4, 0, 4 }, LH = { -4, 0, -4 }, N = { 35, 0, 0 } },
		-- swings one foot through into a kneel, hand on the knee
		{ t = 0.58, root = { 2.4, 0.7, -28, 0 },   RS = { 50, 0, 8 },  LS = { 20, 0, -8 }, RH = { 58, 0, 4 }, LH = { -10, 0, -4 }, N = { 18, 0, 0 } },
		{ t = 0.68, root = { 2.5, 0.75, -26, 3 },  RS = { 58, 0, 6 },  LS = { 12, 0, -8 }, RH = { 60, 0, 4 }, LH = { -11, 0, -4 }, N = { 8, 0, 0 } },
		-- pushes off the knee to a hunched stand
		{ t = 0.80, root = { 2.9, 0.9, -14, -2 },  RS = { 18, 0, 6 },  LS = { 8, 0, -6 },  RH = { 14, 0, 2 }, LH = { -2, 0, -2 }, N = { -10, 0, 0 } },
		-- straightens, a little unsteady, looks up at the boss
		{ t = 0.90, root = { 3.0, 1.0, -3, 1.5 },  RS = { 4, 0, 5 },   LS = { 3, 0, -5 },  RH = { 2, 0, 2 },  LH = { -1, 0, -2 }, N = { 14, -8, 0 } },
		{ t = 1.00, root = { 3.0, 1.0, 0, 0 },     RS = { 0, 0, 3 },   LS = { 0, 0, -3 },  RH = { 0, 0, 0 },  LH = { 0, 0, 0 },  N = { 8, 0, 0 } },
	}

	local function smooth(x) return x * x * (3 - 2 * x) end
	local function lerpArr(a, b, e)
		local out = {}
		for i = 1, #a do out[i] = a[i] + (b[i] - a[i]) * e end
		return out
	end
	local function sampleK(p)
		for i = 1, #K - 1 do
			local a, b = K[i], K[i + 1]
			if p <= b.t then
				local e = smooth(math.clamp((p - a.t) / (b.t - a.t), 0, 1))
				local f = {}
				for _, key in ipairs({ "root", "RS", "LS", "RH", "LH", "N" }) do
					f[key] = lerpArr(a[key], b[key], e)
				end
				return f
			end
		end
		return K[#K]
	end

	start, last = os.clock(), os.clock()
	local faceYaw = heading + math.pi
	local floor = landing - Vector3.new(0, 3, 0)
	local base = CFrame.new(floor) * CFrame.Angles(0, faceYaw, 0)
	local grunted, stepped = false, false

	while not session.Skipped do
		local now = os.clock()
		local delta = now - last
		last = now

		local p = math.clamp((now - start) / spec.WakeTime, 0, 1)
		local f = sampleK(p)
		-- breathing, heavier while down
		local breath = math.sin(now * 3.2) * (p < 0.6 and 0.06 or 0.025)

		local r = f.root
		-- +Z is toward the feet: as they rise the torso ends up over the hips
		rig:PivotTo(base * CFrame.new(0, r[1] + breath, r[2])
			* CFrame.Angles(math.rad(r[3]), 0, math.rad(r[4])))
		pose("Right Shoulder", f.RS[1], f.RS[2], f.RS[3])
		pose("Left Shoulder", f.LS[1], f.LS[2], f.LS[3])
		pose("Right Hip", f.RH[1], f.RH[2], f.RH[3])
		pose("Left Hip", f.LH[1], f.LH[2], f.LH[3])
		pose("Neck", f.N[1], f.N[2], f.N[3])

		if not grunted and p > 0.34 then
			grunted = true
			addShake(0.4, 0.4)
		end
		if not stepped and p > 0.78 then
			stepped = true
			playSound("StepRight")
		end

		-- camera: starts low beside the body, drifts round and up to
		-- finish over the shoulder as they stand
		local e = smooth(math.clamp((p - 0.1) / 0.85, 0, 1))
		-- orbit from a low side-on shot (you see the whole get-up) round
		-- to behind the shoulder, keeping a proper distance
		local ang = math.rad(80) * (1 - e) -- 80 deg to the side -> directly behind
		local distCam = 11 + 1.5 * e
		local heightCam = 2.2 + 3.4 * e
		local camPos = (base * CFrame.new(math.sin(ang) * distCam + 2.2 * e, heightCam,
			math.cos(ang) * distCam + 0.5)).Position
		local torsoPart = rig:FindFirstChild("Torso")
		local head = rig:FindFirstChild("Head")
		local target = (torsoPart and head) and torsoPart.Position:Lerp(head.Position, 0.5) or landing
		camera.CFrame = CFrame.lookAt(camPos, target) * CFrame.Angles(0, 0, math.rad(10 * (1 - e)))
		camera.FieldOfView = PRESENTATION.BaseFieldOfView + (1 - e) * 8

		local offset = currentShake(delta)
		if offset.Magnitude > 0 then camera.CFrame = camera.CFrame * CFrame.new(offset) end

		if p >= 1 then break end
		RunService.RenderStepped:Wait()
	end

	-- remember where to hand over so the real body stands on the same spot
	session.LandFacing = faceYaw

	stopFollow()
	task.wait(0.3)
	TweenService:Create(fade, TweenInfo.new(0.35), { BackgroundTransparency = 0 }):Play()
	task.wait(0.4)

	for _, clone in ipairs(session.Clones) do
		if clone.Parent then clone:Destroy() end
	end
	session.Clones = {}
end

--==================================================
-- THE WHOLE THING
--==================================================

local function preload()
	local holder = Instance.new("Folder")
	for key, spec in pairs(Config.Sounds) do
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. spec.Id
		s.Parent = holder
	end
	pcall(function() ContentProvider:PreloadAsync({ holder, PROPS }) end)
	holder:Destroy()
end

-- Shared by the full run and the single-scene replay hook, so both
-- paths set the stage up and tear it down the same way.
-- Puts the player's real body in the arena. Done from the client
-- because a character's physics belongs to its own client -- a CFrame
-- set here replicates to the server and everyone else. The target is
-- a fixed value from the config, never anything derived from input.
local function landInArena(position)
	-- The floor has to exist on this client before the body arrives, or
	-- the player drops straight through an unstreamed arena.
	if workspace.StreamingEnabled then
		pcall(function() player:RequestStreamAroundAsync(position, 4) end)
	end

	showCharacter()

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		-- face the same way the cutscene body stood up facing
		character:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0))
			* CFrame.Angles(0, session.LandFacing or 0, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function withPresentation(body)
	if session.Active then return end
	session.Active = true
	session.Skipped = false

	gui.Enabled = true
	fade.BackgroundTransparency = 0

	local originalCameraType = camera.CameraType
	local originalFov = camera.FieldOfView

	hideCharacter()
	captureLighting()

	camera.CameraType = Enum.CameraType.Scriptable
	grade.Enabled = true
	bloom.Enabled = true
	TweenService:Create(grade, TweenInfo.new(1), {
		Contrast = PRESENTATION.GradeContrast,
		Saturation = PRESENTATION.GradeSaturation,
	}):Play()

	-- letterbox in
	TweenService:Create(topBar, TweenInfo.new(PRESENTATION.LetterboxTime, Enum.EasingStyle.Quart),
		{ Size = UDim2.fromScale(1, PRESENTATION.LetterboxHeight) }):Play()
	TweenService:Create(bottomBar, TweenInfo.new(PRESENTATION.LetterboxTime, Enum.EasingStyle.Quart),
		{ Size = UDim2.fromScale(1, PRESENTATION.LetterboxHeight) }):Play()

	body()

	-- out
	skipHolder.Visible = false
	stopAllSounds(0.6)

	TweenService:Create(topBar, TweenInfo.new(PRESENTATION.LetterboxTime),
		{ Size = UDim2.fromScale(1, 0) }):Play()
	TweenService:Create(bottomBar, TweenInfo.new(PRESENTATION.LetterboxTime),
		{ Size = UDim2.fromScale(1, 0) }):Play()
	TweenService:Create(grade, TweenInfo.new(0.8), { Contrast = 0, Saturation = 0 }):Play()

	camera.CameraType = originalCameraType
	camera.FieldOfView = originalFov
	session.FovOffset = 0

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end

	-- Focus goes back to the character BEFORE they can see or move,
	-- so the ground under them is loaded by the time control returns.
	releaseStreaming()

	if session.Land and Config.Descent and Config.Descent.Enabled then
		-- The full sequence ends in the boss arena, so the player is put
		-- there for real -- and left under the arena's galaxy sky rather
		-- than having the old lighting restored over the top of it.
		landInArena(Config.Descent.Landing)
		applyBackdrop(Config.Playback.EndBackdrop or "arena", 0)
	else
		-- a single-scene replay just puts everything back
		restoreLighting()
		showCharacter()
	end
	task.wait(0.25)

	TweenService:Create(fade, TweenInfo.new(PRESENTATION.FadeTime),
		{ BackgroundTransparency = 1 }):Play()
	task.wait(PRESENTATION.FadeTime)

	gui.Enabled = false
	grade.Enabled = false
	bloom.Enabled = false
	session.Active = false

	if session.Land then
		-- The fight begins: tell the boss (BossService starts it once)
		-- and let the HUD know it can bring up the boss bar.
		player:SetAttribute("CutsceneDone", true)
		local remotes = ReplicatedStorage:FindFirstChild("BossRemotes")
		local finished = remotes and remotes:FindFirstChild("CutsceneFinished")
		if finished then finished:FireServer() end
	end
end

local function run()
	-- Set before the body runs: even a player who skips on the first
	-- frame still has to end up in the arena.
	session.Land = true
	withPresentation(function()
		for index, scene in ipairs(Config.Scenes) do
			if session.Skipped then break end
			runScene(scene)
			if index < #Config.Scenes then
				task.wait(PRESENTATION.GapBetweenScenes)
			end
		end

		if not session.Skipped then
			task.wait(PRESENTATION.GapBetweenScenes)
			runDescent()
		end
	end)
	session.Land = false
end

local function runOne(scene)
	session.Land = false
	withPresentation(function()
		runScene(scene)
	end)
end

--==================================================
-- REPLAY HOOKS
--
-- Handy while you're tuning the cue times: run
--     _G.PlayCutscene()
-- in the client console to watch it again without
-- rejoining, or
--     _G.PlayCutscene("animpart2")
-- to jump straight to one scene.
--
-- This is also how you'd trigger part 2 later from your
-- own code -- at the boss door, say -- instead of on
-- join. Pass the save name and it plays just that one.
--==================================================

local function playCutscene(sceneName)
	if session.Active then return false end

	if not sceneName then
		task.spawn(run)
		return true
	end

	-- "descent" replays just the fall + stand-up (handy for tuning)
	if sceneName == "descent" then
		task.spawn(function()
			session.Land = true
			withPresentation(runDescent)
			session.Land = false
		end)
		return true
	end

	for _, scene in ipairs(Config.Scenes) do
		if scene.Save == sceneName then
			task.spawn(function()
				runOne(scene)
			end)
			return true
		end
	end

	warn("[Cutscene] no scene called " .. tostring(sceneName))
	return false
end

_G.PlayCutscene = playCutscene

-- Also exposed as a BindableEvent, because _G is only shared between
-- scripts running in the same Lua VM -- the command bar and plugins
-- can't see it. Firing this works from anywhere on the client:
--
--     ReplicatedStorage.CutsceneReplay:Fire()
--     ReplicatedStorage.CutsceneReplay:Fire("animpart2")
local replay = ReplicatedStorage:FindFirstChild("CutsceneReplay")
if not replay then
	replay = Instance.new("BindableEvent")
	replay.Name = "CutsceneReplay"
	replay.Parent = ReplicatedStorage
end

replay.Event:Connect(function(sceneName)
	playCutscene(sceneName)
end)

--==================================================

watchSkip()

task.spawn(function()
	-- Wait for the character so the fallback avatar copy has
	-- something to read, and so hiding it actually finds parts.
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(0.4)

	preload()
	run()
end)
