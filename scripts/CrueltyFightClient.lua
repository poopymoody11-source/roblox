--==================================================
-- CRUELTY FIGHT CLIENT  (client)
--
-- Everything the player sees of the Cruelty fight once they've landed:
--
--   ENTRANCE   the camera looks up as he drops out of the sky, slams with
--              the impact, then circles his face while he talks (bottom
--              subtitles only) and a title card slides in lower-left. Then
--              it glides back to you and the health bar drops in.
--   HEALTH     driven ONLY by the server's broadcasts. (The old UI also
--              listened to the dormant stand-in's health, which is capped
--              at its own max -- so the bar flipped between the two numbers
--              depending on who hit last.)
--   PHASE II   a smooth push-in on his face, red flash, music gear-change.
--   ATTACKS    slash arcs on his melee, a gathering fire orb before the
--              giant shot.
--   VICTORY    hit-stop, colour drains then floods gold, VICTORY slams in
--              letter by letter over turning light rays and a shockwave.
--   FAILED     die down there and the colour drains, the camera drifts up
--              off your body, YOU FAILED glitches in with his taunt, and you
--              wake up back at Verity's portal. No retries.
--
-- No mid-screen banners otherwise. Only players actually in the arena
-- react to any of it.
--==================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local cutscene = workspace:WaitForChild("CrueltyCutscene")
local cruelty = cutscene:WaitForChild("Cruelty")
local arenaSpawn = cutscene:WaitForChild("CharacterLocation")
local fx = ReplicatedStorage:WaitForChild("CrueltyFightFX")

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local RED = Color3.fromRGB(200, 30, 30)
local CRIMSON = Color3.fromRGB(255, 70, 50)
local EMBER = Color3.fromRGB(255, 160, 50)
local GOLD = Color3.fromRGB(255, 205, 80)
local DARK = Color3.fromRGB(14, 6, 8)
local WHITE = Color3.new(1, 1, 1)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local BOOM = "rbxassetid://114743565978001"

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end
local function tween(o, t, goal, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function textStroke(thick, color)
	return new("UIStroke", { Thickness = thick, Color = color or DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end
local function play(id, volume, speed)
	local s = new("Sound", { SoundId = id, Volume = volume or 0.6, PlaybackSpeed = speed or 1, Parent = SoundService })
	SoundService:PlayLocalSound(s)
	task.delay(8, function() s:Destroy() end)
end

local function myRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function inArena()
	local r = myRoot()
	return r ~= nil and (r.Position - arenaSpawn.Position).Magnitude < 900
end
local late = {} -- functions defined further down that earlier code needs
local function bossClone()
	for _, c in ipairs(cutscene:GetChildren()) do
		if c ~= cruelty and c:GetAttribute("IsClone") and c:FindFirstChildOfClass("Humanoid") then return c end
	end
	return nil
end

--==================================================
-- UI
--==================================================

local gui = new("ScreenGui", { Name = "CrueltyFightUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 85, Enabled = true, Parent = playerGui })

-- letterbox
local topBar = new("Frame", { Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 20, Parent = gui })
local botBar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 20, Parent = gui })
local function letterbox(on, t)
	player:SetAttribute("HideHud_CrueltyFight", on and true or nil)
	tween(topBar, t or 0.6, { Size = UDim2.fromScale(1, on and 0.1 or 0) }, Enum.EasingStyle.Quart)
	tween(botBar, t or 0.6, { Size = UDim2.fromScale(1, on and 0.1 or 0) }, Enum.EasingStyle.Quart)
end

local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50, Parent = gui })
local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 60, Parent = gui })

-- THE TIPS: when the fight goes live - hit him with your bat, and watch for the QTEs
local tipGui = new("ScreenGui", { Name = "CrueltyTips", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 90, Parent = playerGui })
local tipFrame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.13), Size = UDim2.fromScale(0.5, 0.11),
	BackgroundColor3 = Color3.fromRGB(25, 10, 20), BackgroundTransparency = 1, Visible = false, Parent = tipGui })
new("UICorner", { CornerRadius = UDim.new(0.25, 0), Parent = tipFrame })
local tipStroke = new("UIStroke", { Color = Color3.fromRGB(255, 70, 70), Thickness = 3, Transparency = 1, Parent = tipFrame })
local tip1 = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.94, 0.5), Position = UDim2.fromScale(0.03, 0.04), Font = Enum.Font.FredokaOne, TextScaled = true,
	Text = "⚾ HIT CRUELTY WITH YOUR BAT! (click to swing)", TextColor3 = Color3.fromRGB(255, 225, 120), TextTransparency = 1, Parent = tipFrame })
local tip2 = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.94, 0.4), Position = UDim2.fromScale(0.03, 0.55), Font = Enum.Font.FredokaOne, TextScaled = true,
	Text = "⚠ WHEN A KEY FLASHES ON SCREEN, PRESS IT FAST (QTE) OR GET HIT HARD!", TextColor3 = Color3.fromRGB(255, 120, 120), TextTransparency = 1, Parent = tipFrame })
for _, l in ipairs({ tip1, tip2 }) do new("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Parent = l }) end
local tipShownAt = 0
local function showTips()
	if os.clock() - tipShownAt < 20 then return end
	tipShownAt = os.clock()
	tipFrame.Visible = true
	for _, o in ipairs({ tip1, tip2 }) do tween(o, 0.4, { TextTransparency = 0 }) end
	tween(tipFrame, 0.4, { BackgroundTransparency = 0.25 })
	tween(tipStroke, 0.4, { Transparency = 0 })
	task.delay(8, function()
		for _, o in ipairs({ tip1, tip2 }) do tween(o, 0.6, { TextTransparency = 1 }) end
		tween(tipFrame, 0.6, { BackgroundTransparency = 1 })
		tween(tipStroke, 0.6, { Transparency = 1 })
		task.delay(0.7, function() tipFrame.Visible = false end)
	end)
end
workspace:GetAttributeChangedSignal("CrueltyFightLive"):Connect(function()
	if workspace:GetAttribute("CrueltyFightLive") == true and player:GetAttribute("InCrueltyArena") then
		task.delay(1.5, showTips)
	end
end)
local vignette = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui },
	{ new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0) }) }) })
local function flashTo(colour, fadeOut)
	flash.BackgroundColor3 = colour
	flash.BackgroundTransparency = 0
	tween(flash, fadeOut or 0.5, { BackgroundTransparency = 1 })
end

-- subtitles: a name tag and the line, inside the bottom letterbox
local subFrame = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.965), Size = UDim2.fromScale(0.7, 0.07), BackgroundTransparency = 1, ZIndex = 30, Parent = gui })
local subName = new("TextLabel", { Size = UDim2.fromScale(1, 0.38), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = "CRUELTY", TextColor3 = CRIMSON, TextTransparency = 1, ZIndex = 30, Parent = subFrame }, { textStroke(1.5) })
local subLine = new("TextLabel", { Position = UDim2.fromScale(0, 0.4), Size = UDim2.fromScale(1, 0.6), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = "", TextColor3 = Color3.fromRGB(255, 240, 235), TextTransparency = 1, ZIndex = 30, Parent = subFrame },
	{ new("UITextSizeConstraint", { MaxTextSize = 30 }), textStroke(2) })

local typing = 0
local subStrokes = { subName:FindFirstChildOfClass("UIStroke"), subLine:FindFirstChildOfClass("UIStroke") }
for _, st in ipairs(subStrokes) do st.Transparency = 1 end
local function say(text, hold)
	typing += 1
	local mine = typing
	subName.TextTransparency = 0
	subLine.TextTransparency = 0
	for _, st in ipairs(subStrokes) do st.Transparency = 0 end
	subLine.MaxVisibleGraphemes = 0
	subLine.Text = text
	for i = 1, #text do
		if typing ~= mine then return end
		subLine.MaxVisibleGraphemes = i
		task.wait(0.024)
	end
	task.delay(hold or 1.4, function()
		if typing == mine then
			tween(subLine, 0.4, { TextTransparency = 1 })
			tween(subName, 0.4, { TextTransparency = 1 })
			for _, st in ipairs(subStrokes) do tween(st, 0.3, { Transparency = 1 }) end
		end
	end)
end
local function hush()
	typing += 1
	tween(subLine, 0.25, { TextTransparency = 1 })
	tween(subName, 0.25, { TextTransparency = 1 })
	for _, st in ipairs(subStrokes) do tween(st, 0.2, { Transparency = 1 }) end
end
late.hush = hush
local function speak(lines)
	task.spawn(function()
		for _, line in ipairs(lines) do
			local mine = typing + 1
			say(line, 1.3)
			task.wait(#line * 0.024 + 1.5)
			if typing ~= mine then return end
		end
	end)
end

-- title card, lower-left
local card = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, -520, 0.82, 0), Size = UDim2.fromOffset(460, 120), BackgroundTransparency = 1, ZIndex = 31, Parent = gui })
local cardName = new("TextLabel", { Size = UDim2.new(1, 0, 0, 78), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = "CRUELTY", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = card },
	{ textStroke(4), new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, CRIMSON), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, CRIMSON) }) }) })
local cardRule = new("Frame", { Position = UDim2.fromOffset(4, 82), Size = UDim2.fromOffset(0, 4), BackgroundColor3 = CRIMSON, BorderSizePixel = 0, ZIndex = 31, Parent = card })
local cardSub = new("TextLabel", { Position = UDim2.fromOffset(4, 90), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = "THE THING BEHIND THE PORTAL", TextColor3 = Color3.fromRGB(240, 170, 160), TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 31, Parent = card }, { textStroke(2) })
local function titleCard()
	card.Position = UDim2.new(0, -520, 0.82, 0)
	cardRule.Size = UDim2.fromOffset(0, 4)
	cardSub.TextTransparency = 1
	tween(card, 0.6, { Position = UDim2.new(0, 60, 0.82, 0) }, Enum.EasingStyle.Quint)
	task.delay(0.35, function()
		tween(cardRule, 0.5, { Size = UDim2.fromOffset(380, 4) }, Enum.EasingStyle.Quint)
		tween(cardSub, 0.5, { TextTransparency = 0 })
	end)
	local g = cardName:FindFirstChildOfClass("UIGradient")
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 4.5 do
			g.Offset = Vector2.new(math.sin((os.clock() - t0) * 1.5) * 0.6, 0)
			RunService.RenderStepped:Wait()
		end
	end)
	task.delay(4.2, function()
		tween(card, 0.5, { Position = UDim2.new(0, -520, 0.82, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	end)
end

-- health bar
local barRoot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -120), Size = UDim2.fromScale(0.5, 0.1), BackgroundTransparency = 1, Parent = gui },
	{ new("UIAspectRatioConstraint", { AspectRatio = 8 }), new("UISizeConstraint", { MaxSize = Vector2.new(860, 110), MinSize = Vector2.new(300, 40) }) })
local barScale = new("UIScale", { Parent = barRoot })
local barName = new("TextLabel", { Size = UDim2.fromScale(1, 0.42), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = "C R U E L T Y", TextColor3 = WHITE, Parent = barRoot }, { textStroke(3) })
local barNameGrad = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, CRIMSON), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, CRIMSON) }), Parent = barName })
local barBack = new("Frame", { Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(1, 0.42), BackgroundColor3 = Color3.fromRGB(26, 12, 14), Parent = barRoot },
	{ new("UICorner", { CornerRadius = UDim.new(0.35, 0) }), new("UIStroke", { Thickness = 3, Color = DARK }) })
local ghost = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 225, 215), BorderSizePixel = 0, Parent = barBack }, { new("UICorner", { CornerRadius = UDim.new(0.35, 0) }) })
local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = barBack }, { new("UICorner", { CornerRadius = UDim.new(0.35, 0) }) })
local fillGrad = new("UIGradient", { Rotation = 90, Parent = fill })
for i = 1, 9 do
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(i / 10, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = DARK, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 3, Parent = barBack })
end
local hpText = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, TextColor3 = WHITE, ZIndex = 4, Text = "", Parent = barBack },
	{ textStroke(2), new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }) })
local function setFillColours(p2)
	fillGrad.Color = p2 and ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 40, 0)), ColorSequenceKeypoint.new(0.5, EMBER), ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 40, 0)) })
		or ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 10, 20)), ColorSequenceKeypoint.new(0.5, CRIMSON), ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 10, 20)) })
end
setFillColours(false)
local function showBar(on)
	tween(barRoot, 0.6, { Position = UDim2.new(0.5, 0, on and 0.035 or 0, on and 0 or -120) }, Enum.EasingStyle.Back, on and Enum.EasingDirection.Out or Enum.EasingDirection.In)
end

--==================================================
-- MUSIC
--==================================================

local musicFolder = SoundService:FindFirstChild("BossMusic")
local playing
local function musicOn() return player:GetAttribute("Set_Audio") ~= false and player:GetAttribute("Set_Music") ~= false end
local function playTrack(name)
	local s = musicFolder and musicFolder:FindFirstChild(name)
	if not s or playing == s then return end
	local prev = playing
	playing = s
	s.TimePosition = 0
	s.Volume = 0
	s:Play()
	tween(s, 1.2, { Volume = musicOn() and (s:GetAttribute("TargetVolume") or 0.45) or 0 })
	if prev then
		tween(prev, 1, { Volume = 0 })
		task.delay(1.1, function() if prev ~= playing then prev:Stop() end end)
	end
end
local lastMusicStop = 0
local function stopMusic()
	lastMusicStop = os.clock()
	local s = playing
	playing = nil
	if s then
		tween(s, 1.2, { Volume = 0 })
		task.delay(1.3, function() if playing ~= s then s:Stop() end end)
	end
end
local worldMusic = SoundService:FindFirstChild("Music")
local function duckWorld(quiet)
	if not worldMusic then return end
	for _, s in ipairs(worldMusic:GetChildren()) do
		if s:IsA("Sound") and s.IsPlaying then
			tween(s, 1, { Volume = quiet and 0 or (s:GetAttribute("SetOrigVolume") or 0.25) })
		end
	end
end

--==================================================
-- CAMERA
--==================================================

local cc = nil
local function ensureCC()
	if not (cc and cc.Parent) then
		cc = new("ColorCorrectionEffect", { Name = "CrueltyFightCC", Parent = Lighting })
	end
	return cc
end
local blur = nil
local function ensureBlur()
	if not (blur and blur.Parent) then
		blur = new("BlurEffect", { Name = "CrueltyFightBlur", Size = 0, Parent = Lighting })
	end
	return blur
end

local camOwner = 0 -- bumped by every sequence that takes the camera
local camCF, camFov
local shakeAmp, shakeUntil = 0, 0
local function shake(amount, duration)
	shakeAmp = amount
	shakeUntil = os.clock() + (duration or 0.6)
end
local function takeCamera()
	camOwner += 1
	late.holding = true
	late.lastDrive = os.clock()
	local cam = workspace.CurrentCamera
	camCF = cam.CFrame
	camFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	return camOwner
end
local function drive(owner, target, fov, dt, stiffness)
	if owner ~= camOwner then return false end
	late.lastDrive = os.clock()
	local cam = workspace.CurrentCamera
	local k = 1 - math.exp(-(stiffness or 8) * dt)
	camCF = camCF:Lerp(target, k)
	camFov += ((fov or camFov) - camFov) * k
	local out = camCF
	if os.clock() < shakeUntil then
		local s = shakeAmp * ((shakeUntil - os.clock()) / 0.6)
		out = out * CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0) * CFrame.Angles(0, 0, math.rad((math.random() - 0.5) * s * 2))
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = out
	cam.FieldOfView = math.clamp(camFov, 20, 110)
	return true
end
local function releaseCamera(owner)
	if owner and owner ~= camOwner then return end
	camOwner += 1
	late.holding = false
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
end
local function over(owner, duration, fn)
	local t0 = os.clock()
	while owner == camOwner do
		local dt = RunService.RenderStepped:Wait()
		local a = math.clamp((os.clock() - t0) / duration, 0, 1)
		if fn(dt, a) == false then break end
		if a >= 1 then break end
	end
	return owner == camOwner
end

-- let the landing cinematic finish before the entrance takes the camera
local function waitForEntryCinematic()
	local entry = playerGui:FindFirstChild("CrueltyEntry")
	local t = 0
	while entry and entry.Enabled and workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable and t < 2 do
		t += task.wait(0.05)
	end
end

--==================================================
-- FIGHT STATE
--==================================================

local active = false
local phase = 1
local shownHealth, ghostHealth, targetHealth, maxHealth = 1, 1, 1, 1
local hitFlash = 0

local function setHealth(h, m)
	maxHealth = m or maxHealth
	targetHealth = math.clamp(maxHealth > 0 and h / maxHealth or 0, 0, 1)
	hpText.Text = ("%d / %d"):format(math.max(math.floor(h), 0), math.floor(maxHealth))
	hitFlash = 1
end

local function setActive(on)
	if active == on then return end
	active = on
	pcall(function() player:SetAttribute("InBossFight", on or nil) end)
	if on then
		phase = 1
		shownHealth, ghostHealth, targetHealth = 1, 1, 1
		setFillColours(false)
		playTrack("CrueltyPhase1")
		duckWorld(true)
	else
		showBar(false)
		stopMusic()
		duckWorld(false)
		letterbox(false)
		tween(vignette, 0.6, { BackgroundTransparency = 1 })
		if cc then tween(cc, 0.8, { TintColor = WHITE, Saturation = 0, Contrast = 0, Brightness = 0 }) end
		if blur then tween(blur, 0.6, { Size = 0 }) end
	end
end

--==================================================
-- ENTRANCE
--==================================================

local entranceOwner
local function entrance(ground)
	waitForEntryCinematic()
	setActive(true)
	letterbox(true)
	local owner = takeCamera()
	entranceOwner = owner
	local me = myRoot()
	local base = me and me.Position or (ground - Vector3.new(0, 0, 40))
	local away = (base - ground) * Vector3.new(1, 0, 1)
	away = away.Magnitude > 1 and away.Unit or Vector3.new(0, 0, -1)
	local eye = ground + away * 34 + Vector3.new(0, 4, 0)
	-- look up at the sky he's about to fall out of, then follow him down
	over(owner, 1.9, function(dt)
		local clone = bossClone()
		local r = clone and clone:FindFirstChild("HumanoidRootPart")
		local focus = r and r.Position or (ground + Vector3.new(0, 120, 0))
		drive(owner, CFrame.lookAt(eye, focus), 60, dt, 7)
	end)
end

local function smash(ground)
	if not active then return end
	local clone = bossClone()
	if clone and late.impactFrames then
		task.spawn(late.impactFrames, { clone }, late.SMASH_FRAMES)
	end
	shake(2.2, 0.8)
	flashTo(Color3.fromRGB(255, 190, 160), 0.5)
	play(BOOM, 0.9, 0.7)
	vignette.BackgroundTransparency = 0.4
	tween(vignette, 1.2, { BackgroundTransparency = 0.88 })
end

local function introTalk(lines)
	if not entranceOwner or entranceOwner ~= camOwner then return end
	local owner = entranceOwner
	titleCard()
	if type(lines) == "table" then speak(lines) end
	-- a slow dolly round his face while he talks
	local clone = bossClone()
	local head = clone and (clone:FindFirstChild("Head") or clone:FindFirstChild("HumanoidRootPart"))
	if not head then return end
	local total = 0
	for _, l in ipairs(type(lines) == "table" and lines or {}) do total += #l * 0.024 + 1.5 end
	local start = math.random() * math.pi * 2
	over(owner, math.max(total, 3), function(dt, a)
		local h = head.Position
		local look = head.CFrame.LookVector
		local ang = math.atan2(look.X, look.Z) + math.rad(-35 + a * 70)
		local dist = 16 - a * 5
		local eye = h + Vector3.new(math.sin(ang) * dist, 1.5 - a * 2.5, math.cos(ang) * dist)
		drive(owner, CFrame.lookAt(eye, h + Vector3.new(0, -1, 0)), 48 - a * 6, dt, 4)
	end)
end

local function fightGo()
	if not active then return end
	local owner = entranceOwner
	entranceOwner = nil
	showBar(true)
	letterbox(false)
	if owner and owner == camOwner then
		-- glide back to over your shoulder, then hand the camera back
		local me = myRoot()
		over(owner, 0.9, function(dt)
			if not me then return false end
			local cf = me.CFrame
			drive(owner, CFrame.lookAt(cf.Position - cf.LookVector * 12 + Vector3.new(0, 5, 0), cf.Position + cf.LookVector * 10), 70, dt, 9)
		end)
		releaseCamera(owner)
	end
end

--==================================================
-- IMPACT FRAMES
-- A card right in front of the lens fills the screen with flat colour,
-- and a Highlight drawn on top of everything turns the subjects into pure
-- silhouettes -- the manga "impact frame" look, a few frames at a time.
--==================================================

local p2Folder = new("Folder", { Name = "CrueltyPhaseFX", Parent = workspace })
local function fxPart(props)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon })
	for k, v in pairs(props) do p[k] = v end
	p.Parent = p2Folder
	return p
end

local impactLines = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 48, Parent = gui })
for i = 1, 22 do
	local ang = (i / 22) * 360 + math.random(-6, 6)
	new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0, math.random(2, 7)),
		Rotation = ang, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 48, Parent = impactLines,
	}, { new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 0) }) }) })
end

local function impactFrames(models, pattern)
	local cam = workspace.CurrentCamera
	local card = fxPart({ Name = "ImpactCard", Size = Vector3.new(80, 80, 0.05), Color = WHITE })
	local conn = RunService.RenderStepped:Connect(function()
		card.CFrame = cam.CFrame * CFrame.new(0, 0, -1.5)
	end)
	card.CFrame = cam.CFrame * CFrame.new(0, 0, -1.5)
	local hls = {}
	for _, m in ipairs(models) do
		if m and m.Parent then
			table.insert(hls, new("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, FillTransparency = 0, OutlineTransparency = 0, Adornee = m, Parent = p2Folder }))
		end
	end
	impactLines.Visible = true
	for _, f in ipairs(pattern) do
		card.Color = f[1]
		for _, h in ipairs(hls) do
			h.FillColor = f[2]
			h.OutlineColor = f[3] or f[2]
		end
		for _, l in ipairs(impactLines:GetChildren()) do
			l.BackgroundColor3 = f[2]
			l.Rotation += math.random(-8, 8)
		end
		task.wait(f[4] or 0.05)
	end
	impactLines.Visible = false
	conn:Disconnect()
	card:Destroy()
	for _, h in ipairs(hls) do h:Destroy() end
end

late.impactFrames = impactFrames

local function partyModels()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - arenaSpawn.Position).Magnitude < 900 then table.insert(list, p.Character) end
	end
	return list
end

local BLACK = Color3.new(0, 0, 0)
local BLOOD = Color3.fromRGB(190, 0, 10)
local SMASH_FRAMES = {
	{ WHITE, BLACK, BLACK, 0.06 },
	{ BLACK, WHITE, CRIMSON, 0.06 },
	{ WHITE, BLACK, BLACK, 0.05 },
	{ BLOOD, BLACK, WHITE, 0.05 },
}
late.SMASH_FRAMES = SMASH_FRAMES
local RAGE_FRAMES = {
	{ BLACK, BLOOD, WHITE, 0.07 },
	{ WHITE, BLACK, BLACK, 0.06 },
	{ BLOOD, BLACK, BLACK, 0.06 },
	{ BLACK, WHITE, CRIMSON, 0.06 },
	{ WHITE, BLOOD, BLACK, 0.05 },
	{ BLACK, BLOOD, WHITE, 0.05 },
}

--==================================================
-- THE RED REALM
-- Anyone who's gone through the clouds over the arena sees the sky bleed:
-- red haze, red clouds, red ambient light. Nobody else's sky changes.
--==================================================

local realmOn = false
local realmSaved = nil
local realmScenery = nil

-- the world under the clouds: a ring of black spires round the arena and a
-- blood moon hanging over it. Only built for players who are down here.
local function buildRealmScenery()
	local folder = new("Folder", { Name = "CrueltyRealmScenery", Parent = workspace })
	local centre = arenaSpawn.Position
	local function block(props)
		local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Basalt, Color = Color3.fromRGB(22, 6, 8), Reflectance = 0 })
		for k, v in pairs(props) do p[k] = v end
		p.Parent = folder
		return p
	end
	for i = 1, 22 do
		local ang = (i / 22) * math.pi * 2 + math.random() * 0.2
		local r = 380 + math.random() * 300
		local h = 160 + math.random() * 280
		local w = 30 + math.random() * 40
		local base = centre + Vector3.new(math.cos(ang) * r, -60, math.sin(ang) * r)
		local tilt = CFrame.Angles((math.random() - 0.5) * 0.25, math.random() * 6, (math.random() - 0.5) * 0.25)
		local y = 0
		for k = 1, 4 do
			local seg = h / 4
			local ww = w * (1 - (k - 1) * 0.22)
			block({ Size = Vector3.new(ww, seg, ww * 0.85), CFrame = CFrame.new(base) * tilt * CFrame.new(0, y + seg / 2, 0) * CFrame.Angles(0, k * 0.4, 0) })
			y += seg
		end
		block({ Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 40, 30), Size = Vector3.new(1.5, h * 0.7, w * 0.9), CFrame = CFrame.new(base) * tilt * CFrame.new(0, h * 0.4, 0) })
		-- spike on top
		block({ Size = Vector3.new(w * 0.25, h * 0.35, w * 0.25), CFrame = CFrame.new(base) * tilt * CFrame.new(0, h + h * 0.15, 0) * CFrame.Angles(0.15, 0, 0.1) })
	end
	-- a sea of blood-red cloud far beneath the arena (no bottomless void)
	block({ Name = "CloudSea", Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(90, 14, 20), Size = Vector3.new(2048, 4, 2048), CFrame = CFrame.new(centre + Vector3.new(0, -140, 0)) })
	for gx = -4, 4 do
		for gz = -4, 4 do
			if gx ~= 0 or gz ~= 0 then
				block({ Name = "CloudSeaTile", Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(90, 14, 20), Size = Vector3.new(2048, 4, 2048), CFrame = CFrame.new(centre + Vector3.new(gx * 2048, -140, gz * 2048)) })
			end
		end
	end
	local seaFog = block({ Name = "CloudSeaFog", Transparency = 1, Size = Vector3.new(2400, 30, 2400), CFrame = CFrame.new(centre + Vector3.new(0, -125, 0)) })
	local sf = Instance.new("ParticleEmitter")
	sf.Texture = "rbxasset://textures/particles/smoke_main.dds"
	sf.Color = ColorSequence.new(Color3.fromRGB(170, 40, 46), Color3.fromRGB(90, 14, 20))
	sf.Size = NumberSequence.new(120, 180)
	sf.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 1) })
	sf.Lifetime = NumberRange.new(10, 14)
	sf.Speed = NumberRange.new(2, 5)
	sf.Rotation = NumberRange.new(0, 360)
	sf.RotSpeed = NumberRange.new(-5, 5)
	sf.Shape = Enum.ParticleEmitterShape.Box
	sf.Rate = 30
	sf.LightInfluence = 0.3
	sf.Parent = seaFog
	sf:Emit(250)
	local moonDir = Vector3.new(0.6, 0, -0.8).Unit
	local moonPos = centre + moonDir * 900 + Vector3.new(0, 520, 0)
	block({ Name = "BloodMoon", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.fromRGB(210, 26, 30), Size = Vector3.one * 200, CFrame = CFrame.new(moonPos) })
	block({ Name = "MoonHalo", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = Color3.fromRGB(255, 60, 50), Size = Vector3.one * 290, CFrame = CFrame.new(moonPos) })
	return folder
end
local realmCC, realmAtm
local function setRealm(on)
	if realmOn == on then return end
	realmOn = on
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local T = 1.4
	if on then
		realmSaved = {
			Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
			FogColor = Lighting.FogColor, ColorShift_Top = Lighting.ColorShift_Top,
		}
		if atm then
			realmSaved.atm = { Density = atm.Density, Color = atm.Color, Decay = atm.Decay, Glare = atm.Glare, Haze = atm.Haze, Offset = atm.Offset }
		else
			realmAtm = new("Atmosphere", { Name = "CrueltyRealmAtmosphere", Density = 0, Parent = Lighting })
			atm = realmAtm
		end
		if clouds then realmSaved.clouds = { Color = clouds.Color } end
		-- swap in the blood-red skybox
		local redSky = ReplicatedStorage:FindFirstChild("CrueltyRealmSky")
		if redSky then
			realmSaved.sky = sky
			if sky then sky.Parent = nil end
			realmSaved.redSky = redSky:Clone()
			realmSaved.redSky.Parent = Lighting
		elseif sky then
			realmSaved.celestial = sky.CelestialBodiesShown
			sky.CelestialBodiesShown = false
		end
		tween(Lighting, T, { Ambient = Color3.fromRGB(70, 34, 38), OutdoorAmbient = Color3.fromRGB(105, 60, 62), FogColor = Color3.fromRGB(120, 10, 16) })
		tween(atm, T, { Density = 0.34, Color = Color3.fromRGB(190, 50, 54), Decay = Color3.fromRGB(70, 6, 12), Glare = 0.2, Haze = 1.6, Offset = 0.1 })
		if clouds then tween(clouds, T, { Color = Color3.fromRGB(170, 30, 38) }) end
		realmCC = realmCC or new("ColorCorrectionEffect", { Name = "CrueltyRealmCC", Parent = Lighting })
		if realmScenery then realmScenery:Destroy() end
		realmScenery = buildRealmScenery()
		tween(realmCC, T, { TintColor = Color3.fromRGB(255, 238, 236), Saturation = 0, Contrast = 0.06 })
	else
		local sv = realmSaved or {}
		tween(Lighting, T, { Ambient = sv.Ambient or Lighting.Ambient, OutdoorAmbient = sv.OutdoorAmbient or Lighting.OutdoorAmbient, FogColor = sv.FogColor or Lighting.FogColor, ColorShift_Top = sv.ColorShift_Top or Lighting.ColorShift_Top })
		if realmAtm then
			local a0 = realmAtm
			realmAtm = nil
			tween(a0, T, { Density = 0 })
			task.delay(T + 0.1, function() a0:Destroy() end)
		elseif atm and sv.atm then
			tween(atm, T, sv.atm)
		end
		if clouds and sv.clouds then tween(clouds, T, sv.clouds) end
		if sv.redSky then sv.redSky:Destroy() end
		if sv.sky then sv.sky.Parent = Lighting end
		if sky and sv.celestial ~= nil then sky.CelestialBodiesShown = sv.celestial end
		if realmCC then
			local c0 = realmCC
			realmCC = nil
			tween(c0, T, { TintColor = WHITE, Saturation = 0, Contrast = 0 })
			task.delay(T + 0.1, function() c0:Destroy() end)
		end
		realmSaved = nil
		if realmScenery then realmScenery:Destroy() realmScenery = nil end
	end
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local r = myRoot()
		local near = false
		if r then
			local d = (r.Position - arenaSpawn.Position) * Vector3.new(1, 0, 1)
			near = d.Magnitude < 900 and r.Position.Y < arenaSpawn.Position.Y + 1400
		end
		if (late.nukeUntil or 0) > os.clock() then near = true end
		if not near and player:GetAttribute("CrueltyRealm") then player:SetAttribute("CrueltyRealm", nil) end
		setRealm(near and player:GetAttribute("CrueltyRealm") == true)
	end
end)

--==================================================
-- PHASE II -- THE TRANSFORMATION
-- Time stops. Colour drains. He rises off the floor while a pillar of
-- blood-light tears out of the ground through him, rings of thorns spin
-- up around him, lightning cracks down, the floor splits and the rubble
-- floats. The camera spirals up and away, snaps back to his face on
-- "LOOK AT ME", and then he SLAMS down: impact frames, shockwave, and the
-- fight comes back twice as red.
--==================================================

local rageCrown = nil
local function startCrown(clone)
	if rageCrown then rageCrown.stop() end
	local head = clone:FindFirstChild("Head")
	if not head then return end
	local spikes = {}
	for i = 1, 14 do
		spikes[i] = fxPart({ Name = "Crown", Size = Vector3.new(0.35, 0.35, (i % 2 == 0) and 3.2 or 1.8), Color = (i % 2 == 0) and BLOOD or BLACK })
	end
	local ring = {}
	for i = 1, 24 do ring[i] = fxPart({ Name = "CrownRing", Size = Vector3.new(0.25, 0.25, 1.3), Color = CRIMSON }) end
	local alive = true
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not alive or not head.Parent then
			conn:Disconnect()
			for _, p in ipairs(spikes) do p:Destroy() end
			for _, p in ipairs(ring) do p:Destroy() end
			return
		end
		local t = os.clock()
		local c = head.Position + Vector3.new(0, head.Size.Y * 0.9 + 1.2, 0)
		local R = math.max(head.Size.X, head.Size.Z) * 0.75 + 1.2
		for i, p in ipairs(spikes) do
			local a = (i / #spikes) * math.pi * 2 + t * 1.2
			local dir = Vector3.new(math.cos(a), 0.9, math.sin(a)).Unit
			local base = c + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)
			p.CFrame = CFrame.lookAt(base + dir * p.Size.Z / 2, base + dir * p.Size.Z)
		end
		for i, p in ipairs(ring) do
			local a = (i / #ring) * math.pi * 2 - t * 0.8
			local pos = c + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)
			p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
			p.Transparency = 0.1 + 0.5 * (0.5 + 0.5 * math.sin(t * 6 + i))
		end
	end)
	rageCrown = { stop = function() alive = false end }
end

local function bolt(from, to, colour, life)
	local segs = 7
	local prev = from
	local parts = {}
	for i = 1, segs do
		local u = i / segs
		local p = from:Lerp(to, u)
		if i < segs then p += Vector3.new((math.random() - 0.5) * 6, (math.random() - 0.5) * 3, (math.random() - 0.5) * 6) end
		local len = (p - prev).Magnitude
		table.insert(parts, fxPart({ Size = Vector3.new(0.5, 0.5, len), CFrame = CFrame.lookAt((prev + p) / 2, p), Color = (i % 3 == 0) and WHITE or colour }))
		prev = p
	end
	task.delay(life or 0.12, function()
		for _, p in ipairs(parts) do p:Destroy() end
	end)
end

local phaseFxAlive = false
local slamAt = nil

local function phaseTwo(lines, duration)
	if not active then return end
	phase = 2
	duration = duration or 6.2
	local clone = bossClone()
	local head = clone and clone:FindFirstChild("Head")
	local root = clone and (clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart)
	if not (head and root) then
		setFillColours(true)
		playTrack("CrueltyPhase2")
		return
	end
	local owner = takeCamera()
	local t0 = os.clock()
	slamAt = nil
	phaseFxAlive = true

	-- TIME STOPS
	showBar(false)
	letterbox(true, 0.15)
	stopMusic()
	local c = ensureCC()
	local b = ensureBlur()
	c.Saturation, c.Contrast, c.TintColor, c.Brightness = -1, 0.5, WHITE, 0
	play(BOOM, 1, 0.35)
	play("rbxassetid://9114446852", 0.7, 0.4)
	shake(1, 0.3)

	local ok, ext = pcall(function() return clone:GetExtentsSize() end)
	local tall = ok and ext.Y or 10
	local ground = root.Position - Vector3.new(0, tall * 0.5, 0)
	local fwd = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	fwd = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.new(0, 0, -1)
	local side = fwd:Cross(Vector3.yAxis)

	-- hard cut: extreme close-up on the grin
	local faceDist = math.max(6, tall * 0.35)
	camCF = CFrame.lookAt(head.Position + fwd * faceDist, head.Position)
	camFov = 28
	task.spawn(impactFrames, { clone }, { { BLACK, WHITE, CRIMSON, 0.08 }, { WHITE, BLACK, BLACK, 0.06 } })
	if type(lines) == "table" and lines[1] then task.delay(0.35, function() say(lines[1], 1.2) end) end

	-- ---------------- the set piece ----------------
	-- pillar of blood-light through him
	local pillar = fxPart({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(600, 0.5, 0.5), Color = CRIMSON, Transparency = 0.15 })
	local core = fxPart({ Name = "PillarCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(600, 0.2, 0.2), Color = WHITE })
	-- spinning rings of thorns
	local rings = {}
	for r = 1, 3 do
		local segs = {}
		for i = 1, 26 do
			segs[i] = fxPart({ Name = "Ring", Size = Vector3.new(0.5, 0.5, 2.4), Color = (i % 2 == 0) and BLOOD or BLACK, Material = (i % 2 == 0) and Enum.Material.Neon or Enum.Material.SmoothPlastic })
		end
		rings[r] = { segs = segs, radius = 9 + r * 5, tilt = CFrame.Angles(math.rad(70 + r * 14), math.rad(r * 60), 0), speed = (r % 2 == 0) and -2.2 or 1.7 + r * 0.4 }
	end
	-- the floor splits
	local cracks = {}
	for i = 1, 14 do
		cracks[i] = { p = fxPart({ Name = "Crack", Size = Vector3.new(0.6, 0.2, 1), Color = CRIMSON }), a = (i / 14) * math.pi * 2 + math.random() * 0.3, len = 20 + math.random() * 40 }
	end
	-- rubble floats up
	local rubble = {}
	for i = 1, 22 do
		local ang = math.random() * math.pi * 2
		local r = 10 + math.random() * 30
		local sz = 1 + math.random() * 3
		local p = fxPart({ Name = "Rubble", Material = Enum.Material.Slate, Color = Color3.fromRGB(60, 20, 22), Size = Vector3.new(sz, sz * 0.8, sz * 1.1) })
		rubble[i] = { p = p, base = ground + Vector3.new(math.cos(ang) * r, 0.5, math.sin(ang) * r), rise = 6 + math.random() * 16, spin = Vector3.new(math.random(), math.random(), math.random()) * 2, delay = math.random() * 0.8 }
	end
	-- souls sucked into him
	local suckBall = fxPart({ Name = "Suck", Shape = Enum.PartType.Ball, Size = Vector3.one * 70, Transparency = 1 })
	new("ParticleEmitter", {
		Texture = SPARK, Color = ColorSequence.new(WHITE, CRIMSON), LightEmission = 1, LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1.6), NumberSequenceKeypoint.new(1, 0.2) }),
		Transparency = NumberSequence.new(0, 0.3), Lifetime = NumberRange.new(0.9, 1.1), Speed = NumberRange.new(30, 38),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 220, Parent = suckBall,
	})
	new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(40, 0, 4), BLACK),
		Size = NumberSequence.new(10, 3), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1, 1.3), Speed = NumberRange.new(20, 28),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 40, Parent = suckBall,
	})
	local glow = new("PointLight", { Color = CRIMSON, Range = 60, Brightness = 0, Parent = suckBall })
	-- he becomes a black silhouette with a burning white edge while it happens
	local sil = new("Highlight", { Adornee = clone, DepthMode = Enum.HighlightDepthMode.Occluded, FillColor = BLACK, FillTransparency = 1, OutlineColor = WHITE, OutlineTransparency = 1, Parent = p2Folder })
	tween(sil, 1.2, { FillTransparency = 0.15, OutlineTransparency = 0 })

	-- everything animates off one loop until the slam
	local lastBolt = 0
	local fxConn
	fxConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if not phaseFxAlive or not root.Parent then return end
		local centre = root.Position
		local grow = math.clamp((t - 0.3) / 1.5, 0, 1)
		local flick = 0.8 + math.random() * 0.4
		pillar.Size = Vector3.new(600, (0.5 + grow * 4.5) * flick, (0.5 + grow * 4.5) * flick)
		pillar.CFrame = CFrame.new(ground.X, ground.Y + 300, ground.Z) * CFrame.Angles(0, 0, math.rad(90))
		core.Size = Vector3.new(600, 0.3 + grow * 1.4 * flick, 0.3 + grow * 1.4 * flick)
		core.CFrame = pillar.CFrame
		pillar.Transparency = 0.35 + (1 - grow) * 0.6
		suckBall.CFrame = CFrame.new(centre)
		glow.Brightness = grow * 8 * flick
		for _, rg in ipairs(rings) do
			local R = rg.radius * (0.3 + 0.7 * grow)
			local spin = t * rg.speed
			for i, sgm in ipairs(rg.segs) do
				local a = (i / #rg.segs) * math.pi * 2 + spin
				local lp = Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)
				local cf = CFrame.new(centre) * rg.tilt * CFrame.new(lp)
				sgm.CFrame = CFrame.lookAt(cf.Position, cf.Position + (CFrame.new(centre) * rg.tilt):VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a))))
				sgm.Transparency = 1 - grow
			end
		end
		for _, ck in ipairs(cracks) do
			local len = ck.len * math.clamp((t - 0.6) / 2.2, 0, 1)
			local dir = Vector3.new(math.cos(ck.a), 0, math.sin(ck.a))
			ck.p.Size = Vector3.new(0.6 + len * 0.02, 0.2, math.max(len, 0.1))
			ck.p.CFrame = CFrame.lookAt(ground + Vector3.new(0, 0.15, 0) + dir * len / 2, ground + dir * len + Vector3.new(0, 0.15, 0))
		end
		for _, rb in ipairs(rubble) do
			local k = math.clamp((t - 0.5 - rb.delay) / 2.5, 0, 1)
			local e = 1 - (1 - k) ^ 3
			rb.p.CFrame = CFrame.new(rb.base + Vector3.new(0, e * rb.rise + math.sin(t * 2 + rb.rise) * 0.5, 0)) * CFrame.Angles(rb.spin.X * t, rb.spin.Y * t, rb.spin.Z * t)
		end
		if t > 0.8 and t - lastBolt > 0.11 then
			lastBolt = t
			local ang = math.random() * math.pi * 2
			local fromSky = math.random() < 0.5
			local startP = fromSky and (centre + Vector3.new(math.cos(ang) * 30, 90, math.sin(ang) * 30)) or (ground + Vector3.new(math.cos(ang) * 35, 0.5, math.sin(ang) * 35))
			bolt(startP, centre + Vector3.new(0, (math.random() - 0.5) * tall * 0.5, 0), (math.random() < 0.3) and WHITE or CRIMSON, 0.1)
		end
		-- the grade slides from grey into blood
		local redness = math.clamp((t - 1.2) / 2.5, 0, 1)
		c.TintColor = WHITE:Lerp(Color3.fromRGB(255, 120, 110), redness)
		c.Saturation = -1 + redness * 0.9
		vignette.BackgroundTransparency = 0.8 - redness * 0.45 + math.sin(t * 9) * 0.05
		if t > 1.2 then shake(0.25 + redness * 0.9, 0.2) end
	end)

	-- camera: pull back off the face and spiral up around him while he rises
	local ang0 = math.atan2(fwd.X, fwd.Z)
	over(owner, 2.7, function(dt, a)
		local e = 1 - (1 - a) ^ 2
		local focus = root.Position + Vector3.new(0, tall * 0.2, 0)
		local ang = ang0 + e * 2.4
		local dist = faceDist + e * (tall * 1.6 + 18)
		local eye = focus + Vector3.new(math.sin(ang) * dist, -tall * 0.2 + e * tall * 0.9, math.cos(ang) * dist)
		local roll = math.sin(a * math.pi) * 0.12
		drive(owner, CFrame.lookAt(eye, focus) * CFrame.Angles(0, 0, roll), 28 + e * 52, dt, 5)
	end)
	-- "LOOK AT ME": snap back onto his face with a dolly-zoom
	if type(lines) == "table" and lines[2] then say(lines[2], 1.4) end
	play(BOOM, 0.8, 0.5)
	flashTo(Color3.fromRGB(255, 60, 50), 0.35)
	local startFace = head.Position + fwd * (faceDist * 3)
	camCF = CFrame.lookAt(startFace, head.Position)
	camFov = 24
	over(owner, 1.5, function(dt, a)
		local e = a * a
		local eye = head.Position + fwd * (faceDist * (3 - e * 1.6)) + Vector3.new(0, 0.5, 0)
		camCF = CFrame.lookAt(eye, head.Position)
		drive(owner, camCF, 24 + e * 34, dt, 30)
		if slamAt then return false end
	end)
	-- wait for the slam (server), max a second more
	local waited = 0
	while not slamAt and waited < 1.2 and owner == camOwner do
		local dt = RunService.RenderStepped:Wait()
		waited += dt
		local eye = head.Position + fwd * (faceDist * 1.6) + Vector3.new(0, 0.5, 0)
		drive(owner, CFrame.lookAt(eye, head.Position), 58, dt, 20)
	end

	-- THE SLAM
	phaseFxAlive = false
	fxConn:Disconnect()
	sil:Destroy()
	local slamPos = slamAt or ground
	-- wide low shot for the impact
	camCF = CFrame.lookAt(ground + fwd * (tall * 1.4 + 24) + side * 8 + Vector3.new(0, 3, 0), root.Position)
	camFov = 85
	local subjects = partyModels()
	table.insert(subjects, clone)
	task.spawn(impactFrames, subjects, RAGE_FRAMES)
	shake(3.2, 1)
	play(BOOM, 1, 0.6)
	play("rbxassetid://83382878583668", 1, 0.6)
	setFillColours(true)
	playTrack("CrueltyPhase2")
	-- shockwave rings
	for i = 1, 4 do
		local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 4, 4), Color = (i % 2 == 0) and WHITE or CRIMSON, CFrame = CFrame.new(ground + Vector3.new(0, 0.6 + i * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
		task.delay(0.35 + (i - 1) * 0.08, function()
			tween(ring, 0.8 + i * 0.1, { Size = Vector3.new(0.3, 150 + i * 30, 150 + i * 30), Transparency = 1 }, Enum.EasingStyle.Quint)
			task.delay(1.4, function() ring:Destroy() end)
		end)
	end
	-- the rubble gets flung out
	for _, rb in ipairs(rubble) do
		local out = (rb.p.Position - ground) * Vector3.new(1, 0, 1)
		out = out.Magnitude > 0.1 and out.Unit or Vector3.new(1, 0, 0)
		tween(rb.p, 0.9, { CFrame = rb.p.CFrame + out * 60 + Vector3.new(0, 10, 0), Transparency = 1 }, Enum.EasingStyle.Quint)
	end
	tween(pillar, 0.5, { Size = Vector3.new(600, 40, 40), Transparency = 1 })
	tween(core, 0.4, { Size = Vector3.new(600, 16, 16), Transparency = 1 })
	for _, rg in ipairs(rings) do
		for _, sgm in ipairs(rg.segs) do
			local out = (sgm.Position - root.Position)
			tween(sgm, 0.7, { CFrame = sgm.CFrame + out * 3, Transparency = 1 }, Enum.EasingStyle.Quint)
		end
	end
	for _, ck in ipairs(cracks) do tween(ck.p, 2.5, { Transparency = 1, Color = Color3.fromRGB(60, 0, 0) }) end
	suckBall:Destroy()
	task.delay(0.4, function()
		flashTo(WHITE, 0.6)
		tween(c, 0.9, { Saturation = 0.08, Contrast = 0.1, TintColor = Color3.fromRGB(255, 238, 232), Brightness = 0 })
		tween(b, 0.5, { Size = 0 })
		vignette.BackgroundTransparency = 0.2
		tween(vignette, 1.6, { BackgroundTransparency = 0.75 })
	end)
	task.delay(3, function()
		for _, x in ipairs({ pillar, core }) do x:Destroy() end
		for _, rg in ipairs(rings) do for _, sgm in ipairs(rg.segs) do sgm:Destroy() end end
		for _, ck in ipairs(cracks) do ck.p:Destroy() end
		for _, rb in ipairs(rubble) do rb.p:Destroy() end
	end)
	startCrown(clone)

	over(owner, 0.9, function(dt, a)
		local eye = ground + fwd * (tall * 1.4 + 24 + a * 10) + side * 8 + Vector3.new(0, 3 + a * 4, 0)
		drive(owner, CFrame.lookAt(eye, root.Position), 85 - a * 10, dt, 10)
	end)
	letterbox(false, 0.4)
	showBar(true)
	local me = myRoot()
	over(owner, 0.8, function(dt)
		if not me then return false end
		local cf = me.CFrame
		drive(owner, CFrame.lookAt(cf.Position - cf.LookVector * 12 + Vector3.new(0, 5, 0), cf.Position + cf.LookVector * 10), 70, dt, 10)
	end)
	releaseCamera(owner)
end

local function phaseSlam(pos)
	slamAt = pos or true
end

local function taunt(line, rage)
	if not active or type(line) ~= "string" then return end
	subName.TextColor3 = rage and Color3.fromRGB(255, 40, 40) or CRIMSON
	say(line, 2.2)
	if rage then
		vignette.BackgroundTransparency = 0.45
		shake(0.4, 0.3)
	end
end

--==================================================
-- FINAL ATTACK -- cutscene + rhythm rings
-- He goes up into the sky and pulls the whole world apart: the arena
-- floor lifts, the spires shake, the blood moon swells, the sky spins,
-- lightning everywhere. Each player gets their own 8 rings scattered
-- round the screen; a ring closes in behind each one and you hit it
-- (click / tap it, or press its key) as the ring lands. Three misses and
-- the sphere takes you. Anyone who holds on kills him.
--==================================================

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local qteRemote = ReplicatedStorage:WaitForChild("CrueltyQTE", 10)

local INCON_I = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
local QTE_KEYS = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D }
local QTE_PAD = { Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonA }
local PAD_LABEL = { "X", "Y", "B", "A" }
local KEY_LABEL = { "W", "A", "S", "D" }
local NOTE_COLOUR = { Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 170, 40), Color3.fromRGB(150, 90, 255), Color3.fromRGB(60, 200, 255) }
local SFX_APPEAR = "rbxassetid://9048764475"
local SFX_HIT = "rbxasset://sounds/swordslash.wav"
local SFX_MISS = "rbxasset://sounds/collide.wav"
local MIN_SHOW = 0.9   -- shortest time a ring stays up (lag spikes)
local LAG_GRACE = 0.5  -- how far past its hit time that can stretch (matches the server)
-- PHONES: finding and tapping 8 circles at random spots in ~1.4s each was
-- next to impossible, so on touch screens each circle stays up this much
-- longer after its hit time (its ring shrinks over the whole time as a
-- countdown). Must not be more than TOUCH_EXTRA in CrueltyFightService.
local TOUCH_EXTRA = 1.6

local function inputMode()
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then return "touch" end
	if last.Name:find("Gamepad") then return "pad" end
	return "keys"
end
local function touchMode()
	return inputMode() == "touch" or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
end
local function labelFor(sym)
	local mode = inputMode()
	if mode == "pad" then return PAD_LABEL[sym] end
	if mode == "touch" then return "" end
	return KEY_LABEL[sym]
end

-- The real button icon for the controller that's plugged in. Xbox letters
-- were wrong on PlayStation: "X" (ButtonX) is SQUARE there, and the PS
-- "X" button is ButtonA -- so PS players pressed the wrong one.
local function padImage(sym)
	local ok, id = pcall(function() return UserInputService:GetImageForKeyCode(QTE_PAD[sym]) end)
	if ok and type(id) == "string" and id ~= "" then return id end
	return nil
end

local function applyGlyph(note)
	local img = (inputMode() == "pad") and padImage(note.sym) or nil
	if img then
		if not note.glyph then
			note.glyph = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ImageTransparency = note.label.TextTransparency, ZIndex = 75, Parent = note.body })
		end
		note.glyph.Image = img
		note.glyph.Visible = true
		note.label.Text = ""
	else
		if note.glyph then note.glyph.Visible = false end
		note.label.Text = labelFor(note.sym)
	end
end

-- ---------- ring UI ----------
local qteLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 70, Parent = gui })
local comboLabel = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.12), Size = UDim2.fromOffset(400, 60), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = "", TextColor3 = GOLD, ZIndex = 78, Parent = qteLayer },
	{ textStroke(3), new("UIScale", { Name = "Pop" }) })
local lifeRow = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromOffset(300, 44), BackgroundTransparency = 1, ZIndex = 78, Parent = qteLayer },
	{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10) }) })
local hintLabel = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromOffset(620, 26), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = "", TextColor3 = WHITE, ZIndex = 78, Parent = qteLayer }, { textStroke(2) })
local lives = {}

local qte = nil

local function popText(parent, text, colour, pos)
	local l = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(240, 50), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = text, TextColor3 = colour, ZIndex = 80, Parent = parent },
		{ textStroke(3), new("UIScale", { Scale = 1.8 }) })
	tween(l:FindFirstChildOfClass("UIScale"), 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(l, 0.6, { Position = pos - UDim2.fromOffset(0, 50) }, Enum.EasingStyle.Quad)
	task.delay(0.35, function() tween(l, 0.3, { TextTransparency = 1 }) end)
	task.delay(0.7, function() l:Destroy() end)
end

local function sparkBurst(parent, pos, colour)
	for i = 1, 12 do
		local ang = (i / 12) * math.pi * 2 + math.random() * 0.3
		local p = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(10, 10), Rotation = math.random(0, 90), BackgroundColor3 = (i % 3 == 0) and WHITE or colour, BorderSizePixel = 0, ZIndex = 79, Parent = parent })
		local d = 70 + math.random() * 60
		tween(p, 0.45, { Position = pos + UDim2.fromOffset(math.cos(ang) * d, math.sin(ang) * d), BackgroundTransparency = 1, Size = UDim2.fromOffset(3, 3) }, Enum.EasingStyle.Quint)
		task.delay(0.5, function() p:Destroy() end)
	end
end

local parryFx
local function setLives(n)
	for i, h in ipairs(lives) do
		local alive = i <= n
		h.BackgroundColor3 = alive and Color3.fromRGB(255, 60, 80) or Color3.fromRGB(50, 40, 45)
	end
end

local function judge(note, ok, dtHit)
	if note.done then return end
	note.done = true
	local run = qte
	if not run then return end
	run.answered[note.i] = ok
	local pos = note.frame.Position
	if ok then
		run.combo += 1
		local grade = math.abs(dtHit or 0) < 0.1 and "PERFECT" or (math.abs(dtHit or 0) < 0.2 and "GREAT" or "GOOD")
		sparkBurst(qteLayer, pos, note.colour)
		play(SFX_HIT, 0.6, 1 + run.combo * 0.05)
		play(BOOM, 0.35, 1.4 + run.combo * 0.05)

		tween(note.body, 0.25, { Size = UDim2.fromOffset(170, 170), BackgroundTransparency = 1 }, Enum.EasingStyle.Quint)
		tween(note.stroke, 0.25, { Transparency = 1 })
		tween(note.label, 0.2, { TextTransparency = 1 })
		if note.glyph then tween(note.glyph, 0.2, { ImageTransparency = 1 }) end
		note.ring.Visible = false
		shake(0.6, 0.2)
		if parryFx then task.spawn(parryFx) end
	else
		run.combo = 0
		run.misses += 1
		comboLabel.Text = ""

		play(SFX_MISS, 0.8, 0.5)
		note.body.BackgroundColor3 = Color3.fromRGB(60, 50, 55)
		note.stroke.Color = Color3.fromRGB(255, 60, 60)
		note.ring.Visible = false
		tween(note.body, 0.4, { BackgroundTransparency = 1 })
		tween(note.stroke, 0.4, { Transparency = 1 })
		tween(note.label, 0.3, { TextTransparency = 1 })
		if note.glyph then tween(note.glyph, 0.3, { ImageTransparency = 1 }) end
		shake(1, 0.3)
		flashTo(Color3.fromRGB(255, 30, 30), 0.3)
		setLives(math.max(0, run.maxMisses + 1 - run.misses))
	end
	task.delay(0.5, function() note.frame:Destroy() end)
end

-- tapped: a TAP on the circle itself (phones / clicking). Tapping a circle
-- counts any time it's on screen - on phones people tap a circle as soon as it
-- shows up, and the strict key timing made every one of those an instant miss.
-- Keys / controller buttons keep the timing: press as the ring closes.
local function tryHit(note, sym, tapped)
	local run = qte
	if not run or note.done then return end
	local now = workspace:GetServerTimeNow()
	local dtHit = now - note.hitAt
	local ok
	if tapped then
		ok = sym == note.sym and now <= note.expireAt
	else
		if dtHit < -0.6 then return end -- way too early: ignore the press
		ok = sym == note.sym and dtHit >= -run.window and now <= note.expireAt
	end
	-- (a miss here is a miss on the server too)
	if qteRemote then qteRemote:FireServer(note.i, ok and sym or 0) end
	judge(note, ok, tapped and 0 or dtHit)
end

local function makeNote(run, i)
	local spot = run.spots[i]
	local sym = run.seq[i]
	local colour = NOTE_COLOUR[sym]
	local pos = UDim2.fromScale(spot[1], spot[2])
	local frame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(120, 120), BackgroundTransparency = 1, ZIndex = 71, Parent = qteLayer })
	-- the approach ring, BEHIND the circle, closing in on it
	local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(360, 360), BackgroundTransparency = 1, ZIndex = 71, Parent = frame },
		{ new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = colour, Thickness = 6, Transparency = 1 }) })
	-- the circle itself: clickable
	local body = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(104, 104), BackgroundColor3 = colour, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", ZIndex = 73, Parent = frame },
		{ new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		  new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(120, 120, 120)) }) })
	local stroke = new("UIStroke", { Color = WHITE, Thickness = 6, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = body })
	-- outer black rim for readability on busy backgrounds
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(124, 124), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 72, Name = "Rim", Parent = frame },
		{ new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local label = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, FontFace = INCON_I, TextScaled = true, Text = labelFor(sym), TextColor3 = WHITE, TextTransparency = 1, ZIndex = 74, Parent = body },
		{ textStroke(3), new("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0), PaddingLeft = UDim.new(0.2, 0), PaddingRight = UDim.new(0.2, 0) }) })
	local number = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(60, 26), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = tostring(i), TextColor3 = WHITE, TextTransparency = 1, ZIndex = 74, Parent = frame }, { textStroke(2) })
	-- every ring gets at least MIN_SHOW seconds on screen, even if a lag spike
	-- (phones, during all the effects) brought it in late
	local hitAt = run.start + (i - 1) * run.gap
	local appearAt = workspace:GetServerTimeNow()
	local expireAt = math.clamp(appearAt + MIN_SHOW, hitAt + run.window + 0.12, hitAt + run.window + 0.12 + LAG_GRACE)
	local touch = touchMode()
	if touch then expireAt = math.max(expireAt, hitAt + run.window + 0.12 + TOUCH_EXTRA) end
	local note = { i = i, sym = sym, colour = colour, hitAt = hitAt, expireAt = expireAt, appearAt = appearAt, touch = touch, frame = frame, ring = ring, body = body, stroke = stroke, label = label, number = number, rim = frame:FindFirstChild("Rim") }
	body.Activated:Connect(function() tryHit(note, sym, true) end)
	applyGlyph(note)
	if note.glyph then tween(note.glyph, 0.2, { ImageTransparency = 0 }) end
	-- pop in
	local sc = new("UIScale", { Scale = 0.4, Parent = frame })
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(body, 0.2, { BackgroundTransparency = 0 })
	tween(stroke, 0.2, { Transparency = 0 })
	tween(label, 0.2, { TextTransparency = 0 })
	tween(number, 0.2, { TextTransparency = 0 })
	tween(ring:FindFirstChildOfClass("UIStroke"), 0.2, { Transparency = 0 })
	tween(note.rim, 0.2, { BackgroundTransparency = 0 })
	play(SFX_APPEAR, 0.45, 0.9 + i * 0.04)
	return note
end

local function qteAction(_, state, input)
	if state ~= Enum.UserInputState.Begin or not qte then return Enum.ContextActionResult.Pass end
	for sym = 1, 4 do
		if input.KeyCode == QTE_KEYS[sym] or input.KeyCode == QTE_PAD[sym] then
			-- the key applies to the earliest ring still waiting
			local best
			for _, note in ipairs(qte.notes) do
				if not note.done and (not best or note.hitAt < best.hitAt) then best = note end
			end
			if best then tryHit(best, sym) end
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end

local function stopQTE()
	local run = qte
	qte = nil
	ContextActionService:UnbindAction("CrueltyQTE")
	if run then
		for _, note in ipairs(run.notes) do if note.frame.Parent then note.frame:Destroy() end end
	end
	qteLayer.Visible = false
end

local function startQTE(info)
	if type(info) ~= "table" or type(info.seq) ~= "table" then return end
	stopQTE()
	local run = { seq = info.seq, spots = info.spots or {}, start = info.start, gap = info.gap or 0.62, window = info.window or 0.3, lead = info.lead or 1, count = info.count or #info.seq, maxMisses = info.maxMisses or 2, answered = {}, notes = {}, misses = 0, combo = 0, spawned = 0 }
	for i = 1, run.count do
		if not run.spots[i] then run.spots[i] = { 0.3 + math.random() * 0.4, 0.3 + math.random() * 0.3 } end
	end
	qte = run
	for _, h in ipairs(lives) do h:Destroy() end
	lives = {}
	for i = 1, run.maxMisses + 1 do
		lives[i] = new("Frame", { Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Color3.fromRGB(255, 60, 80), Rotation = 45, LayoutOrder = i, ZIndex = 78, Parent = lifeRow },
			{ new("UICorner", { CornerRadius = UDim.new(0.25, 0) }), new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3 }) })
	end
	comboLabel.Text = ""
	local keys = {}
	for i = 1, 4 do table.insert(keys, QTE_KEYS[i]) table.insert(keys, QTE_PAD[i]) end
	ContextActionService:BindActionAtPriority("CrueltyQTE", qteAction, false, 3000, table.unpack(keys))
	local function refreshHint()
		local mode = inputMode()
		hintLabel.Text = (mode == "touch") and "TAP EVERY CIRCLE BEFORE ITS RING CLOSES!" or (mode == "pad" and "PRESS THE BUTTON AS THE RING CLOSES IN" or "PRESS ITS KEY - W A S D - AS THE RING CLOSES IN")
	end
	refreshHint()
	-- picked up a controller / switched to keyboard mid-QTE: relabel everything
	local inputConn
	inputConn = UserInputService.LastInputTypeChanged:Connect(function()
		if qte ~= run then inputConn:Disconnect() return end
		refreshHint()
		for _, note in ipairs(run.notes) do
			if not note.done then applyGlyph(note) end
		end
	end)

	-- backup for taps on phones: any touch on (or right next to) a circle hits
	-- it, even if something else on screen swallowed the button press
	local touchConn
	touchConn = UserInputService.InputBegan:Connect(function(input)
		if qte ~= run then touchConn:Disconnect() return end
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local best, bestD
		for _, note in ipairs(run.notes) do
			if not note.done and note.body.Parent then
				local c = note.body.AbsolutePosition + note.body.AbsoluteSize / 2
				local d = (c - pos).Magnitude
				if d <= note.body.AbsoluteSize.X * 0.75 and (not bestD or d < bestD) then best, bestD = note, d end
			end
		end
		if best then tryHit(best, best.sym, true) end
	end)

	task.spawn(function()
		while qte == run do
			local now = workspace:GetServerTimeNow()
			qteLayer.Visible = now >= run.start - run.lead - 0.4
			-- bring rings in on time
			while run.spawned < run.count and now >= run.start + run.spawned * run.gap - run.lead do
				run.spawned += 1
				table.insert(run.notes, makeNote(run, run.spawned))
			end
			for _, note in ipairs(run.notes) do
				if not note.done then
					local k
					if note.touch then
						-- phones: the ring closes over the circle's whole time on screen
						k = math.clamp((now - note.appearAt) / math.max(note.expireAt - note.appearAt, 0.1), 0, 1)
					else
						k = math.clamp(1 - (note.hitAt - now) / run.lead, 0, 1)
					end
					local size = 104 + (1 - k) * 250
					note.ring.Size = UDim2.fromOffset(size, size)
					local st = note.ring:FindFirstChildOfClass("UIStroke")
					st.Thickness = 4 + k * 4
					st.Color = (not note.touch and math.abs(note.hitAt - now) <= run.window) and WHITE or note.colour
					-- late: counts as a miss
					if now > note.expireAt then
						if qteRemote then qteRemote:FireServer(note.i, 0) end
						judge(note, false)
					end
				end
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

-- ---------- the world tears itself apart ----------
local function worldReacts(state, clone, arenaMid)
	local bits = {}
	-- lift a handful of the arena's own parts (your screen only; put back after)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { p2Folder }
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ex, p.Character) end end
	table.insert(ex, clone)
	params.FilterDescendantsInstances = ex
	local near = workspace:GetPartBoundsInRadius(arenaMid, 160, params)
	local picked = 0
	for _, p in ipairs(near) do
		if picked >= 45 then break end
		if p.Anchored and p.Transparency < 0.9 and p.Size.Magnitude < 60 and not p:IsDescendantOf(cutscene) then
			picked += 1
			table.insert(bits, { part = p, cf = p.CFrame, rise = 2 + math.random() * 9, spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.6, delay = math.random() * 2 })
		end
	end
	local neons = {}
	for _, p in ipairs(near) do
		if p.Material == Enum.Material.Neon and #neons < 60 then table.insert(neons, { part = p, colour = p.Color }) end
	end
	local scenery = workspace:FindFirstChild("CrueltyRealmScenery")
	local moon = scenery and scenery:FindFirstChild("BloodMoon")
	local halo = scenery and scenery:FindFirstChild("MoonHalo")
	local moonCF, moonSize = moon and moon.CFrame, moon and moon.Size
	local spires = {}
	if scenery then
		for _, p in ipairs(scenery:GetChildren()) do
			if p ~= moon and p ~= halo and p:IsA("BasePart") and p.Name:sub(1, 8) ~= "CloudSea" then table.insert(spires, { part = p, cf = p.CFrame }) end
		end
	end
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local skyOri = sky and sky.SkyboxOrientation
	local lastBolt, lastBeat = 0, 0
	local t0 = os.clock()
	state.worldConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local ramp = math.clamp(t / 4, 0, 1)
		for _, b in ipairs(bits) do
			if b.part.Parent then
				local k = math.clamp((t - b.delay) / 2.5, 0, 1)
				local e = 1 - (1 - k) ^ 3
				b.part.CFrame = b.cf + Vector3.new((math.random() - 0.5) * 0.25 * ramp, e * b.rise + math.sin(t * 2 + b.rise) * 0.4 * e, (math.random() - 0.5) * 0.25 * ramp)
					* CFrame.Angles(b.spin.X * e, b.spin.Y * e, b.spin.Z * e)
			end
		end
		for i, n in ipairs(neons) do
			if n.part.Parent then
				local f = 0.5 + 0.5 * math.sin(t * 14 + i)
				n.part.Color = n.colour:Lerp((math.random() < 0.08) and WHITE or Color3.fromRGB(255, 20, 20), f * ramp)
			end
		end
		for i, sp in ipairs(spires) do
			if sp.part.Parent then
				local lean = math.min(t / 10, 1) * ((i % 3 == 0) and 0.25 or 0.05)
				sp.part.CFrame = sp.cf * CFrame.new((math.random() - 0.5) * 1.5 * ramp, (math.random() - 0.5) * 1.5 * ramp, 0) * CFrame.Angles(lean, 0, lean * 0.5)
			end
		end
		if moon and moonCF then
			local grow = 1 + ramp * 0.8 + math.sin(t * 6) * 0.05
			moon.Size = moonSize * grow
			moon.CFrame = moonCF:Lerp(CFrame.new(arenaMid + (moonCF.Position - arenaMid) * 0.6), ramp * 0.6)
			if halo then halo.CFrame = moon.CFrame halo.Size = moon.Size * 1.45 end
		end
		if sky and skyOri then
			sky.SkyboxOrientation = skyOri + Vector3.new(0, t * 12 * ramp, math.sin(t * 0.7) * 6 * ramp)
		end
		-- lightning raining down all round the arena
		if t - lastBolt > 0.12 - ramp * 0.06 then
			lastBolt = t
			local ang = math.random() * math.pi * 2
			local r = 30 + math.random() * 150
			local hit = arenaMid + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
			bolt(hit + Vector3.new((math.random() - 0.5) * 40, 160, (math.random() - 0.5) * 40), hit, (math.random() < 0.3) and WHITE or CRIMSON, 0.1)
			local splash = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3, 3), Color = CRIMSON, CFrame = CFrame.new(hit + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
			tween(splash, 0.35, { Size = Vector3.new(0.2, 22, 22), Transparency = 1 })
			task.delay(0.4, function() splash:Destroy() end)
		end
		-- the whole world throbs on the beat
		if t - lastBeat > 0.48 then
			lastBeat = t
			vignette.BackgroundTransparency = 0.25
			shake(0.35 + ramp * 0.6, 0.25)
			camFov += 3 * ramp
		end
	end)
	state.restoreWorld = function()
		if state.worldConn then state.worldConn:Disconnect() end
		for _, b in ipairs(bits) do
			if b.part.Parent then tween(b.part, 0.35, { CFrame = b.cf }, Enum.EasingStyle.Back) end
		end
		for _, n in ipairs(neons) do if n.part.Parent then n.part.Color = n.colour end end
		for _, sp in ipairs(spires) do if sp.part.Parent then sp.part.CFrame = sp.cf end end
		if moon and moonCF then moon.CFrame = moonCF moon.Size = moonSize if halo then halo.CFrame = moonCF halo.Size = moonSize * 1.45 end end
		if sky and skyOri and sky.Parent then sky.SkyboxOrientation = skyOri end
	end
end

-- ---------- the cutscene ----------
local final = nil

late.cancelFinal = function()
	stopQTE()
	parryFx = nil
	local st = final
	final = nil
	if st then
		st.alive = false
		if st.conn then st.conn:Disconnect() end
		if st.restoreWorld then st.restoreWorld() end
		for _, p in ipairs(st.parts or {}) do if p.Parent then p:Destroy() end end
	end
end

local function finalAttack(lines, info)
	if not active or type(info) ~= "table" then return end
	-- dead players (or ones already on the YOU FAILED screen) sit this out
	if late.isFailing and late.isFailing() then return end
	local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not myHum or myHum.Health <= 0 then return end
	local clone = bossClone()
	local head = clone and clone:FindFirstChild("Head")
	local root = clone and (clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart)
	if not (head and root) then return end
	local ok, ext = pcall(function() return clone:GetExtentsSize() end)
	local tall = ok and ext.Y or 10
	local ground = root.Position - Vector3.new(0, tall * 0.5, 0)
	local arenaMid = ground

	local owner = takeCamera()
	local state = { owner = owner, alive = true, parts = {} }
	final = state
	letterbox(true, 0.25)
	showBar(false)
	local c = ensureCC()
	local b = ensureBlur()

	-- the music drops
	playTrack("CrueltyFinal")

	-- TIME STOPS
	local subjects = partyModels()
	table.insert(subjects, clone)
	task.spawn(impactFrames, subjects, { { BLACK, WHITE, CRIMSON, 0.07 }, { WHITE, BLACK, BLACK, 0.06 }, { BLOOD, BLACK, WHITE, 0.06 }, { BLACK, BLOOD, WHITE, 0.06 } })
	play(BOOM, 1, 0.3)
	play("rbxassetid://9114446852", 0.8, 0.35)
	shake(2.4, 0.7)
	c.Saturation, c.Contrast, c.TintColor = -0.6, 0.35, Color3.fromRGB(255, 190, 190)
	if type(lines) == "table" then speak(lines) end
	worldReacts(state, clone, arenaMid)

	-- the sphere of death
	local orb = fxPart({ Name = "DeathOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = Color3.fromRGB(8, 0, 2) })
	local shell = fxPart({ Name = "DeathShell", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Color = CRIMSON, Material = Enum.Material.ForceField })
	local halo = fxPart({ Name = "DeathHalo", Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Color = Color3.fromRGB(255, 40, 40), Transparency = 0.75 })
	local rings = {}
	for r = 1, 4 do
		local segs = {}
		for i = 1, 26 do segs[i] = fxPart({ Size = Vector3.new(0.8, 0.8, 4), Color = (i % 2 == 0) and WHITE or CRIMSON }) end
		rings[r] = { segs = segs, tilt = CFrame.Angles(math.rad(50 + r * 25), math.rad(r * 70), 0), speed = (r % 2 == 0) and -1.8 or 1.4 + r * 0.3 }
	end
	new("ParticleEmitter", {
		Texture = SPARK, Color = ColorSequence.new(WHITE, CRIMSON), LightEmission = 1, LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 2.4), NumberSequenceKeypoint.new(1, 0.3) }),
		Transparency = NumberSequence.new(0, 0.3), Lifetime = NumberRange.new(0.8, 1), Speed = NumberRange.new(70, 90),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 260, Parent = halo,
	})
	new("PointLight", { Color = CRIMSON, Range = 60, Brightness = 8, Parent = orb })
	state.parts = { orb, shell, halo }
	for _, rg in ipairs(rings) do for _, sg in ipairs(rg.segs) do table.insert(state.parts, sg) end end

	local now0 = workspace:GetServerTimeNow()
	local qStart, resolveAt = info.start, info.resolveAt
	local lastBolt = 0
	state.orbPos = function()
		local now = workspace:GetServerTimeNow()
		local over = head.Position + Vector3.new(0, tall * 0.6 + 16, 0)
		if now < qStart then return over end
		local k = math.clamp((now - qStart) / (resolveAt - qStart), 0, 1)
		return over:Lerp(arenaMid + Vector3.new(0, 18, 0), k * k * 0.8)
	end
	state.orbSize = function()
		local now = workspace:GetServerTimeNow()
		return 2 + math.clamp((now - now0) / (qStart - now0), 0, 1) * 70
	end
	state.conn = RunService.RenderStepped:Connect(function()
		if not state.alive then return end
		local t = os.clock()
		local p = state.orbPos()
		local sz = state.orbSize() * (0.95 + math.random() * 0.1)
		orb.Size = Vector3.one * sz
		orb.CFrame = CFrame.new(p)
		shell.Size = Vector3.one * sz * 1.18
		shell.CFrame = orb.CFrame
		halo.Size = Vector3.one * sz * 1.6
		halo.CFrame = orb.CFrame
		for _, rg in ipairs(rings) do
			local R = sz * 0.95
			for i, sg in ipairs(rg.segs) do
				local ang = (i / #rg.segs) * math.pi * 2 + t * rg.speed
				local cf = CFrame.new(p) * rg.tilt
				local lp = cf:PointToWorldSpace(Vector3.new(math.cos(ang) * R, 0, math.sin(ang) * R))
				sg.CFrame = CFrame.lookAt(lp, lp + cf:VectorToWorldSpace(Vector3.new(-math.sin(ang), 0, math.cos(ang))))
			end
		end
		if t - lastBolt > 0.07 then
			lastBolt = t
			local ang = math.random() * math.pi * 2
			bolt(p + Vector3.new(math.cos(ang) * sz * 0.5, (math.random() - 0.5) * sz, math.sin(ang) * sz * 0.5), (math.random() < 0.5) and head.Position or (arenaMid + Vector3.new(math.cos(ang) * 40, 0, math.sin(ang) * 40)), CRIMSON, 0.08)
		end
	end)

	parryFx = function()
		local p = state.orbPos()
		task.spawn(impactFrames, { clone, player.Character }, { { WHITE, BLACK, BLACK, 0.04 }, { BLACK, WHITE, GOLD, 0.04 } })
		local burst = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 8, Color = GOLD, CFrame = CFrame.new(p - Vector3.new(0, state.orbSize() * 0.5, 0)) })
		tween(burst, 0.35, { Size = Vector3.one * 40, Transparency = 1 })
		task.delay(0.4, function() burst:Destroy() end)
	end

	-- SHOT 1: from the floor, looking up as he rises and the sphere forms
	local me = myRoot()
	local base = me and me.Position or (ground - Vector3.new(0, 0, 30))
	local toBoss = (root.Position - base) * Vector3.new(1, 0, 1)
	toBoss = toBoss.Magnitude > 1 and toBoss.Unit or Vector3.new(0, 0, -1)
	local side = toBoss:Cross(Vector3.yAxis)
	local eye1 = ground - toBoss * (tall + 26) + side * 10 + Vector3.new(0, 2, 0)
	camCF = CFrame.lookAt(eye1, head.Position)
	camFov = 70
	over(owner, 2.2, function(dt, a)
		drive(owner, CFrame.lookAt(eye1 - toBoss * a * 8, state.orbPos():Lerp(head.Position, 0.5)), 70 + a * 14, dt, 6)
	end)
	-- SHOT 2: sweeping crane round him, the sphere, the whole world coming apart
	local ang0 = math.atan2(-toBoss.X, -toBoss.Z)
	while owner == camOwner and workspace:GetServerTimeNow() < qStart - 1.3 do
		local dt = RunService.RenderStepped:Wait()
		local k = math.clamp(1 - (qStart - 1.3 - workspace:GetServerTimeNow()) / 3, 0, 1)
		local p = state.orbPos()
		local ang = ang0 + k * 2.2
		local dist = tall * 1.8 + 60
		local eye = arenaMid + Vector3.new(math.sin(ang) * dist, 20 + k * 40, math.cos(ang) * dist)
		drive(owner, CFrame.lookAt(eye, p:Lerp(head.Position, 0.4)), 80, dt, 4)
		c.TintColor = Color3.fromRGB(255, 190, 190):Lerp(Color3.fromRGB(255, 130, 120), k)
	end
	-- "DIE."
	if owner == camOwner then
		task.spawn(impactFrames, subjects, { { WHITE, BLACK, BLACK, 0.06 }, { BLOOD, BLACK, WHITE, 0.06 }, { BLACK, BLOOD, WHITE, 0.06 }, { WHITE, BLOOD, BLACK, 0.05 } })
		say("DIE.", 1)
		shake(3, 0.6)
		play(BOOM, 1, 0.45)
		flashTo(Color3.fromRGB(255, 40, 40), 0.5)
	end

	-- SHOT 3 (the rings): low behind your shoulder, the sphere coming down on you
	while owner == camOwner and state.alive and workspace:GetServerTimeNow() < resolveAt + 0.2 do
		local dt = RunService.RenderStepped:Wait()
		local r = myRoot()
		local p = state.orbPos()
		local k = math.clamp((workspace:GetServerTimeNow() - qStart) / (resolveAt - qStart), 0, 1)
		if r then
			local toOrb = (p - r.Position) * Vector3.new(1, 0, 1)
			toOrb = toOrb.Magnitude > 1 and toOrb.Unit or toBoss
			local eye = r.Position - toOrb * (10 - k * 3) + toOrb:Cross(Vector3.yAxis) * 4 + Vector3.new(0, 1.5, 0)
			drive(owner, CFrame.lookAt(eye, p:Lerp(r.Position, 0.2)), 80 + k * 14, dt, 8)
		end
		local music = playing
		if music then music.PlaybackSpeed = 1 + k * 0.06 end
	end
end

-- THE NUKE. What the players who didn't hold on see.
--   0.0  IMPLOSION  the sphere crushes down to a point; every sound cuts out
--   0.5  DETONATION a star is born on the arena floor: white-out, blinding
--                   bloom, a boiling fireball of real fire, a Wilson cloud
--                   shell flashing round it, lightning crawling over it
--   1.0  SHOCKWAVE  a dome of air tears outward; the arena is ripped apart
--                   and thrown; the spires snap; the shock hits the lens
--   2.5  THE CLOUD  the fireball lifts on a churning column of smoke and
--                   rolls over into a mushroom cap that keeps climbing,
--                   while the camera cranes back, and back, and up
local NUKE_TIME = 8.6
late.nukeUntil = 0
local function nuke(ground)
	late.nukeUntil = os.clock() + NUKE_TIME + 0.8
	local owner = takeCamera()
	local folder = new("Folder", { Name = "CrueltyNuke", Parent = workspace })
	local FIRE = "rbxasset://textures/particles/fire_main.dds"
	local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
	local SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
	local function prt(props, class)
		local p = new(class or "Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth })
		for k, v in pairs(props) do p[k] = v end
		p.Parent = folder
		return p
	end
	local function emitter(parent, props)
		local e = new("ParticleEmitter", { LightInfluence = 0, Rotation = NumberRange.new(0, 360), Rate = 0 })
		for k, v in pairs(props) do e[k] = v end
		e.Parent = parent
		return e
	end
	local c = ensureCC()
	local blurFx = ensureBlur()
	local bloom = new("BloomEffect", { Name = "NukeBloom", Intensity = 0, Size = 32, Threshold = 0.8, Parent = Lighting })
	local rays = new("SunRaysEffect", { Name = "NukeRays", Intensity = 0, Spread = 1, Parent = Lighting })
	local exposure0 = Lighting.ExposureCompensation
	hush()
	stopMusic()
	letterbox(true, 0.2)

	-- where the camera watches from: out towards where you were standing
	local away = Vector3.new(1, 0, 0.35).Unit
	local me = myRoot()
	if me then
		local d = (me.Position - ground) * Vector3.new(1, 0, 1)
		if d.Magnitude > 1 then away = d.Unit end
	end
	local side = away:Cross(Vector3.yAxis)

	-- ---------------- 0.0 IMPLOSION ----------------
	local seed = prt({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(10, 0, 2), Size = Vector3.one * 30, CFrame = CFrame.new(ground + Vector3.new(0, 10, 0)) })
	local seedRim = prt({ Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = Color3.fromRGB(255, 60, 60), Size = Vector3.one * 34, CFrame = seed.CFrame })
	local suckSrc = prt({ Shape = Enum.PartType.Ball, Transparency = 1, Size = Vector3.one * 120, CFrame = seed.CFrame })
	local suck = emitter(suckSrc, { Texture = SPARKS, Color = ColorSequence.new(WHITE, Color3.fromRGB(255, 80, 60)), LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 3), NumberSequenceKeypoint.new(1, 0.5) }), Lifetime = NumberRange.new(0.45),
		Speed = NumberRange.new(130), Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward })
	suck:Emit(260)
	tween(seed, 0.5, { Size = Vector3.one * 1.5 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tween(seedRim, 0.5, { Size = Vector3.one * 2 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	-- silence: duck every sound in the game for a beat
	local ducked = {}
	for _, snd in ipairs(game:GetService("SoundService"):GetDescendants()) do
		if snd:IsA("Sound") and snd.IsPlaying then ducked[snd] = snd.Volume tween(snd, 0.25, { Volume = 0 }) end
	end
	play("rbxassetid://9114446852", 0.8, 2.2) -- the in-breath
	camCF = CFrame.lookAt(ground + away * 70 + side * 10 + Vector3.new(0, 5, 0), ground + Vector3.new(0, 14, 0))
	camFov = 60
	over(owner, 0.5, function(dt, a)
		drive(owner, CFrame.lookAt(ground + away * (70 - a * 12) + side * 10 + Vector3.new(0, 5, 0), ground + Vector3.new(0, 12, 0)), 60 - a * 18, dt, 12)
		c.Saturation = -a
		c.Contrast = a * 0.3
	end)
	seed:Destroy() seedRim:Destroy()

	-- ---------------- 0.5 DETONATION ----------------
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 0
	tween(flash, 2.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	Lighting.ExposureCompensation = exposure0 + 3
	tween(Lighting, 3.2, { ExposureCompensation = exposure0 }, Enum.EasingStyle.Quad)
	bloom.Intensity = 3.5
	tween(bloom, 3, { Intensity = 0.25 })
	rays.Intensity = 0.6
	tween(rays, 4, { Intensity = 0.15 })
	c.Saturation, c.Contrast, c.Brightness, c.TintColor = 0.1, 0.35, 0.35, Color3.fromRGB(255, 244, 220)
	tween(c, 4, { Brightness = 0.02, Contrast = 0.22, Saturation = 0.3, TintColor = Color3.fromRGB(255, 170, 120) })
	blurFx.Size = 24
	tween(blurFx, 1.2, { Size = 2 })
	play(BOOM, 1, 0.16)
	play(BOOM, 1, 0.24)
	play("rbxassetid://83382878583668", 1, 0.25)
	play("rbxassetid://9114795437", 1, 0.7)
	shake(4, 1.2)

	-- the star: white core inside a layered, boiling fireball of real fire
	local core = prt({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 255, 240), Size = Vector3.one * 6, CFrame = CFrame.new(ground + Vector3.new(0, 8, 0)) })
	local light = new("PointLight", { Color = Color3.fromRGB(255, 210, 150), Range = 60, Brightness = 40, Shadows = true, Parent = core })
	local shellA = prt({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 220, 120), Transparency = 0.15, Size = Vector3.one * 8, CFrame = core.CFrame })
	local shellB = prt({ Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = Color3.fromRGB(255, 140, 50), Size = Vector3.one * 10, CFrame = core.CFrame })
	local fireSrc = prt({ Shape = Enum.PartType.Ball, Transparency = 1, Size = Vector3.one * 20, CFrame = core.CFrame })
	local boil = emitter(fireSrc, { Texture = FIRE, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 220)), ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 170, 60)), ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 40, 20)) }),
		LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 20), NumberSequenceKeypoint.new(1, 45) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(6, 18), RotSpeed = NumberRange.new(-60, 60), Shape = Enum.ParticleEmitterShape.Sphere, Rate = 90 })
	boil:Emit(80)
	-- the Wilson cloud: a white condensation shell that flashes round it and fades
	local wilson = prt({ Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = WHITE, Size = Vector3.one * 20, CFrame = core.CFrame })
	tween(wilson, 1.1, { Size = Vector3.one * 420, Transparency = 1 }, Enum.EasingStyle.Quint)
	tween(core, 1.6, { Size = Vector3.one * 110 }, Enum.EasingStyle.Quint)
	tween(shellA, 1.8, { Size = Vector3.one * 150, Color = Color3.fromRGB(255, 150, 50) }, Enum.EasingStyle.Quint)
	tween(shellB, 2, { Size = Vector3.one * 180, Color = Color3.fromRGB(220, 60, 20) }, Enum.EasingStyle.Quint)
	tween(fireSrc, 1.8, { Size = Vector3.one * 150 }, Enum.EasingStyle.Quint)

	-- ---------------- 1.0 SHOCKWAVE ----------------
	local dome = prt({ Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = Color3.fromRGB(255, 200, 150), Size = Vector3.one * 30, CFrame = CFrame.new(ground) })
	tween(dome, 2.6, { Size = Vector3.one * 2600, Transparency = 1 }, Enum.EasingStyle.Quart)
	for i = 1, 3 do
		local ring = prt({ Shape = Enum.PartType.Cylinder, Color = (i == 1) and WHITE or Color3.fromRGB(255, 170, 80), Size = Vector3.new(3, 30, 30), CFrame = CFrame.new(ground + Vector3.new(0, 1.5 + i, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
		task.delay((i - 1) * 0.15, function() tween(ring, 2.4 + i * 0.4, { Size = Vector3.new(1, 3200, 3200), Transparency = 1 }, Enum.EasingStyle.Quart) end)
	end
	-- a wall of dust rolling out along the ground behind the shock
	local dustSrc = prt({ Transparency = 1, Size = Vector3.new(40, 2, 40), CFrame = CFrame.new(ground + Vector3.new(0, 2, 0)) })
	local dust = emitter(dustSrc, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(200, 120, 90), Color3.fromRGB(70, 30, 22)), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 25), NumberSequenceKeypoint.new(1, 80) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.8, 0.5), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(2.5, 3.5),
		Speed = NumberRange.new(220, 320), Drag = 1.2, SpreadAngle = Vector2.new(4, 180), EmissionDirection = Enum.NormalId.Front, RotSpeed = NumberRange.new(-40, 40) })
	dustSrc.CFrame = CFrame.new(ground + Vector3.new(0, 2, 0)) * CFrame.Angles(math.rad(-90), 0, 0)
	dust:Emit(260)
	local burstSrc = new("Attachment", { Parent = core })
	emitter(burstSrc, { Texture = SPARKS, Color = ColorSequence.new(WHITE, Color3.fromRGB(255, 120, 40)), LightEmission = 1, Size = NumberSequence.new(5, 0.4), Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(150, 320), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -70, 0), Drag = 0.5 }):Emit(300)
	-- rip the arena apart: real nearby parts get thrown out and tumble
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { folder, p2Folder }
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ex, p.Character) end end
	params.FilterDescendantsInstances = ex
	local thrown = {}
	for _, p in ipairs(workspace:GetPartBoundsInRadius(ground, 220, params)) do
		if #thrown >= 110 then break end
		if p.Anchored and p.Transparency < 0.95 and p.Size.Magnitude < 90 and not p:IsDescendantOf(cutscene) then
			local out = (p.Position - ground)
			local flat = out * Vector3.new(1, 0, 1)
			local horiz = flat.Magnitude > 0.5 and flat.Unit or Vector3.new(1, 0, 0)
			local towardCam = horiz:Dot(away) > 0.3
			local dir = horiz * (towardCam and 0.35 or 1) + Vector3.new(0, (towardCam and 1.2 or 0.35) + math.random() * 0.5, 0)
			local distK = 1 - math.clamp(out.Magnitude / 220, 0, 1)
			table.insert(thrown, { p = p, cf = p.CFrame, vel = dir.Unit * (160 + distK * 320) * (0.7 + math.random() * 0.6),
				spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 8, delay = out.Magnitude / 900, trans = p.Transparency })
		end
	end
	local scenery = workspace:FindFirstChild("CrueltyRealmScenery")
	local spires = {}
	local hiddenSpires = {}
	if scenery then
		for _, p in ipairs(scenery:GetChildren()) do
			if p:IsA("BasePart") and p.Name ~= "BloodMoon" and p.Name ~= "MoonHalo" and p.Name:sub(1, 8) ~= "CloudSea" then
				local d = (p.Position - ground) * Vector3.new(1, 0, 1)
				if d.Magnitude > 1 and d.Unit:Dot(away) < 0.4 then
					table.insert(spires, { p = p, cf = p.CFrame, axis = d.Unit:Cross(Vector3.yAxis), delay = d.Magnitude / 900 })
				elseif d.Magnitude > 1 then
					-- on the camera's side: out of the shot while it pulls back
					table.insert(hiddenSpires, { p = p, t = p.Transparency })
					p.Transparency = 1
				end
			end
		end
	end

	-- ---------------- the mushroom ----------------
	-- Built from solid billowing blobs (smoke particles alone read as a
	-- faint haze at this distance). The cap is a torus of blobs that roll
	-- over and over outward; the stem churns upward into it; a base surge
	-- of dust rolls out along the ground in a ring.
	local HOT = Color3.fromRGB(255, 190, 90)
	local EMBER = Color3.fromRGB(235, 90, 30)
	local SOOT = Color3.fromRGB(70, 28, 22)
	local ASH = Color3.fromRGB(120, 60, 50)
	local smokes = {}
	local function blob(col)
		local p = prt({ Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Color = col, Size = Vector3.one * 10, CFrame = CFrame.new(ground), Transparency = 1 })
		-- a soft skin of smoke so the silhouette billows instead of looking like a ball
		local e = emitter(p, { Texture = SMOKE, Color = ColorSequence.new(col), LightEmission = 0.15, LightInfluence = 0, Size = NumberSequence.new(10), 
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(1, 4), RotSpeed = NumberRange.new(-30, 30), Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Rate = 0 })
		table.insert(smokes, { p = p, e = e })
		return p
	end
	local capBlobs = {}
	for i = 1, 44 do
		capBlobs[i] = { p = blob(EMBER), a = (i / 44) * math.pi * 2 + math.random() * 0.1, ph = math.random() * math.pi * 2, k = 0.8 + math.random() * 0.4 }
	end
	local capTop = {}
	for i = 1, 14 do
		capTop[i] = { p = blob(ASH), a = math.random() * math.pi * 2, r = math.random(), k = 0.8 + math.random() * 0.5 }
	end
	local stemBlobs = {}
	for i = 1, 26 do
		stemBlobs[i] = { p = blob(SOOT), u = (i - 0.5) / 26, a = math.random() * math.pi * 2, k = 0.8 + math.random() * 0.4, ph = math.random() * 6 }
	end
	local surge = {}
	for i = 1, 40 do
		surge[i] = { p = blob(ASH), a = (i / 40) * math.pi * 2 + math.random() * 0.12, k = 0.7 + math.random() * 0.6, ph = math.random() * 6 }
	end
	local skirtGlow = prt({ Shape = Enum.PartType.Ball, Color = HOT, Size = Vector3.one * 10, CFrame = CFrame.new(ground), Transparency = 1 })
	local capLight = new("PointLight", { Color = Color3.fromRGB(255, 150, 80), Range = 60, Brightness = 10, Shadows = false, Parent = skirtGlow })
	-- embers raining out of the cap
	local rainSrc = prt({ Transparency = 1, Size = Vector3.new(200, 10, 200), CFrame = CFrame.new(ground) })
	local rain = emitter(rainSrc, { Texture = SPARKS, Color = ColorSequence.new(HOT, EMBER), LightEmission = 1, Size = NumberSequence.new(3, 0.3), Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(5, 20), EmissionDirection = Enum.NormalId.Bottom, Acceleration = Vector3.new(0, -25, 0), Shape = Enum.ParticleEmitterShape.Box, Rate = 0 })

	local t0 = os.clock()
	local lastBolt = 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		-- flying debris
		for _, d in ipairs(thrown) do
			if d.p.Parent then
				local tt = t - d.delay
				if tt > 0 then
					local pos = d.cf.Position + d.vel * tt + Vector3.new(0, -60, 0) * tt * tt * 0.5
					d.p.CFrame = CFrame.new(pos) * (d.cf - d.cf.Position) * CFrame.Angles(d.spin.X * tt, d.spin.Y * tt, d.spin.Z * tt)
				end
			end
		end
		-- spires snap and lean away from the blast
		for _, sp in ipairs(spires) do
			if sp.p.Parent then
				local k = math.clamp((t - sp.delay) / 1.5, 0, 1)
				local e = 1 - (1 - k) ^ 3
				sp.p.CFrame = CFrame.fromAxisAngle(sp.axis, -e * 0.3) * (sp.cf - sp.cf.Position) + sp.cf.Position
			end
		end

		-- the fireball lifts and becomes the head of the cloud
		local rise = math.clamp((t - 0.7) / 5.5, 0, 1)
		local e = 1 - (1 - rise) ^ 2.4
		local h = 30 + e * 480
		local capR = 50 + e * 170
		local cooled = math.clamp((t - 1.5) / 5, 0, 1)
		core.CFrame = CFrame.new(ground + Vector3.new(0, h * 0.97, 0))
		shellA.CFrame, shellB.CFrame, fireSrc.CFrame = core.CFrame, core.CFrame, core.CFrame
		local fade = math.clamp((t - 1.2) / 2.5, 0, 1)
		core.Transparency = fade * 0.9
		shellA.Transparency = 0.15 + fade * 0.8
		shellB.Transparency = fade
		light.Brightness = 40 * (1 - fade) + 5
		boil.Rate = 90 * (1 - fade)
		local show = math.clamp((t - 0.8) / 0.8, 0, 1)

		-- cap: a rolling torus
		local capC = ground + Vector3.new(0, h, 0)
		local rr = capR * 0.42
		for _, cb in ipairs(capBlobs) do
			local ang = cb.a + t * 0.05
			local roll = cb.ph + t * 1.1
			local out = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local pos = capC + out * (capR * 0.62 + math.cos(roll) * rr) + Vector3.new(0, math.sin(roll) * rr * 0.75, 0)
			cb.p.Size = Vector3.one * (rr * 1.35 * cb.k)
			cb.p.CFrame = CFrame.new(pos)
			-- the underside is lit by the fire, the top is soot
			local under = math.clamp(0.5 - math.sin(roll) * 0.5, 0, 1)
			local base = EMBER:Lerp(HOT, under * (1 - cooled * 0.7))
			cb.p.Color = SOOT:Lerp(base, 0.35 + under * 0.65 * (1 - cooled * 0.5))
			cb.p.Material = (under > 0.65 and cooled < 0.7) and Enum.Material.Neon or Enum.Material.SmoothPlastic
			cb.p.Transparency = 1 - show
		end
		for _, ct in ipairs(capTop) do
			local ang = ct.a + t * 0.04
			local r = ct.r * capR * 0.55
			ct.p.Size = Vector3.one * (capR * 0.55 * ct.k)
			ct.p.CFrame = CFrame.new(capC + Vector3.new(math.cos(ang) * r, rr * 0.55 + math.sin(t + ct.a) * 3, math.sin(ang) * r))
			ct.p.Color = ASH:Lerp(SOOT, cooled)
			ct.p.Transparency = 1 - show
		end
		skirtGlow.Size = Vector3.new(capR * 1.3, capR * 0.3, capR * 1.3)
		skirtGlow.CFrame = CFrame.new(capC - Vector3.new(0, rr * 0.5, 0))
		skirtGlow.Transparency = 0.25 + cooled * 0.7
		capLight.Range = 60
		capLight.Brightness = 10 * (1 - cooled) + 2
		rainSrc.CFrame = CFrame.new(capC - Vector3.new(0, rr, 0))
		rainSrc.Size = Vector3.new(capR * 1.4, 4, capR * 1.4)
		rain.Rate = (t > 1.5) and 60 or 0

		-- stem: churning upward into the cap, narrow at the waist
		for _, sb in ipairs(stemBlobs) do
			local u = (sb.u + t * 0.18) % 1
			local y = u * h * 0.9
			local waist = 1 - math.sin(u * math.pi) * 0.35
			local w = (34 + e * 44) * waist
			local ang = sb.a + t * 0.8 + u * 4
			sb.p.Size = Vector3.one * (w * 1.3 * sb.k)
			sb.p.CFrame = CFrame.new(ground + Vector3.new(math.cos(ang) * w * 0.35, y, math.sin(ang) * w * 0.35))
			sb.p.Color = SOOT:Lerp(EMBER, math.clamp(u * 1.2 - cooled * 0.6, 0, 1))
			sb.p.Transparency = (1 - show) + math.clamp((0.05 - u) * 20, 0, 1) * 0.5
		end

		-- base surge: a ring of dust racing out along the ground
		local sk = math.clamp((t - 0.6) / 3.5, 0, 1)
		local se = 1 - (1 - sk) ^ 3
		local sr = 30 + se * 520
		for _, sg in ipairs(surge) do
			local ang = sg.a
			local sz = (30 + se * 90) * sg.k
			sg.p.Size = Vector3.new(sz * 1.4, sz * 0.8, sz * 1.4)
			sg.p.CFrame = CFrame.new(ground + Vector3.new(math.cos(ang) * sr, sz * 0.25 + math.sin(t * 2 + sg.ph) * 3, math.sin(ang) * sr))
			sg.p.Color = EMBER:Lerp(ASH, se):Lerp(SOOT, cooled * 0.5)
			sg.p.Transparency = (sk <= 0) and 1 or (0.02 + se * 0.25)
		end

		for _, sm in ipairs(smokes) do
			local sz = sm.p.Size.X
			sm.e.Size = NumberSequence.new(sz * 1.05, sz * 1.5)
			local col = sm.p.Color
			sm.e.Color = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.08), col)
			sm.e.Rate = (sm.p.Transparency < 0.9) and 11 or 0
		end
		-- lightning crawling over the cloud
		if t > 1 and t - lastBolt > 0.14 then
			lastBolt = t
			local ang = math.random() * math.pi * 2
			local from = capC + Vector3.new(math.cos(ang), 0, math.sin(ang)) * capR * 0.9
			bolt(from, from + Vector3.new((math.random() - 0.5) * 120, -80 - math.random() * 160, (math.random() - 0.5) * 120), (math.random() < 0.4) and WHITE or Color3.fromRGB(255, 120, 90), 0.1)
		end
	end)

	-- the shock reaches the camera: knocked backwards, deafening
	local shockAt = 0.85
	camCF = CFrame.lookAt(ground + away * 58 + side * 10 + Vector3.new(0, 4, 0), ground + Vector3.new(0, 20, 0))
	camFov = 50
	over(owner, shockAt, function(dt, a)
		drive(owner, CFrame.lookAt(ground + away * (58 - a * 4) + side * 10 + Vector3.new(0, 4, 0), core.Position), 50 + a * 30, dt, 10)
	end)
	shake(6, 1.6)
	flashTo(Color3.fromRGB(255, 200, 150), 0.9)
	play("rbxassetid://9125742262", 1, 0.6)
	play(BOOM, 1, 0.2)
	task.delay(0.9, function() play("rbxassetid://9112795463", 1, 0.55) end)
	-- ...and then the long pull back to see the whole thing
	local startEye = camCF.Position
	local rest = NUKE_TIME - 0.5 - shockAt
	over(owner, rest, function(dt, a)
		local e = 1 - (1 - a) ^ 3
		local knock = math.clamp(a * 6, 0, 1)
		local dist = 58 + knock * 90 + e * 1150
		local height = 4 + knock * 20 + e * 180
		local ang = e * 0.5
		local dir = (away * math.cos(ang) + side * math.sin(ang))
		local eye = ground + dir * dist + Vector3.new(0, height, 0)
		local lookAt = ground + Vector3.new(0, 60 + e * 250, 0)
		drive(owner, CFrame.lookAt(eye, lookAt) * CFrame.Angles(0, 0, math.sin(a * 3) * 0.03), 80 - e * 25, dt, 4)
	end)

	-- clean up
	for snd, vol in pairs(ducked) do if snd.Parent then snd.Volume = vol end end
	task.delay(7, function()
		conn:Disconnect()
		for _, d in ipairs(thrown) do if d.p.Parent then d.p.CFrame = d.cf end end
		for _, sp in ipairs(spires) do if sp.p.Parent then sp.p.CFrame = sp.cf end end
		for _, hs in ipairs(hiddenSpires) do if hs.p.Parent then hs.p.Transparency = hs.t end end
		folder:Destroy()
		bloom:Destroy()
		rays:Destroy()
		Lighting.ExposureCompensation = exposure0
	end)
end
late.nuke = nuke
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("DebugNuke"):Connect(function()
		local r = myRoot()
		if r then task.spawn(nuke, r.Position + r.CFrame.LookVector * 60 - Vector3.new(0, 3, 0)) end
	end)
end

local function finalResolve(survivors, fallen, lines)
	stopQTE()
	parryFx = nil
	local state = final
	if not state then return end
	if playing then playing.PlaybackSpeed = 1 end
	local clone = bossClone()
	local mine = table.find(survivors or {}, player.UserId) ~= nil
	local wasIn = mine or table.find(fallen or {}, player.UserId) ~= nil
	if type(lines) == "table" and lines[1] then say(lines[1], 1.4) end
	local c = ensureCC()
	if state.restoreWorld then state.restoreWorld() end
	if #(survivors or {}) > 0 then
		-- THROWN BACK: the sphere goes up into him and he comes apart
		if clone then task.spawn(impactFrames, { clone, player.Character }, { { WHITE, BLACK, GOLD, 0.06 }, { BLACK, GOLD, WHITE, 0.06 }, { WHITE, BLACK, BLACK, 0.05 }, { GOLD, BLACK, BLACK, 0.05 }, { WHITE, BLACK, GOLD, 0.05 } }) end
		flashTo(GOLD, 0.6)
		play(BOOM, 1, 0.8)
		shake(2.4, 0.6)
		local head = clone and clone:FindFirstChild("Head")
		local from = state.orbPos()
		local t0 = os.clock()
		state.orbPos = function()
			local k = math.clamp((os.clock() - t0) / 0.5, 0, 1)
			return from:Lerp(head and head.Position or from + Vector3.new(0, 40, 0), k * k)
		end
		task.delay(0.5, function()
			state.alive = false
			if state.conn then state.conn:Disconnect() end
			for _, p in ipairs(state.parts) do tween(p, 0.35, { Size = p.Size * 3, Transparency = 1 }) end
			task.delay(0.4, function() for _, p in ipairs(state.parts) do p:Destroy() end end)
			flashTo(WHITE, 0.8)
			shake(3.2, 0.7)
			if clone then task.spawn(impactFrames, { clone }, RAGE_FRAMES) end
		end)
		tween(c, 1, { Saturation = 0.1, Contrast = 0.12, TintColor = Color3.fromRGB(255, 240, 225) })
		local owner = state.owner
		local root = clone and clone:FindFirstChild("HumanoidRootPart")
		if root and owner == camOwner then
			local me = myRoot()
			local base = me and me.Position or root.Position + Vector3.new(0, 0, 40)
			local away = (base - root.Position) * Vector3.new(1, 0, 1)
			away = away.Magnitude > 1 and away.Unit or Vector3.new(0, 0, 1)
			over(owner, 1.6, function(dt, a)
				drive(owner, CFrame.lookAt(root.Position + away * 55 + away:Cross(Vector3.yAxis) * 20 + Vector3.new(0, 10, 0), root.Position), 70, dt, 6)
			end)
		end
	else
		local p0 = state.orbPos()
		local t0 = os.clock()
		state.orbPos = function() return p0:Lerp(p0 - Vector3.new(0, 30, 0), math.clamp((os.clock() - t0) / 0.5, 0, 1)) end
		task.delay(0.5, function()
			state.alive = false
			if state.conn then state.conn:Disconnect() end
			for _, p in ipairs(state.parts) do p:Destroy() end
		end)
	end
	if wasIn and not mine then
		-- impact frames the instant it lands on you, then it goes off
		late.nukeUntil = os.clock() + NUKE_TIME + 0.5
		local ground = state.orbPos() - Vector3.new(0, 18, 0)
		task.spawn(function()
			impactFrames({ player.Character, clone }, { { BLOOD, BLACK, WHITE, 0.07 }, { BLACK, BLOOD, WHITE, 0.07 }, { WHITE, BLACK, BLACK, 0.06 }, { WHITE, BLACK, BLACK, 0.05 } })
			nuke(ground)
		end)
	end
end

local function finalEnd()
	stopQTE()
	local state = final
	final = nil
	if state then
		state.alive = false
		if state.conn then state.conn:Disconnect() end
		if state.restoreWorld then state.restoreWorld() end
		for _, p in ipairs(state.parts) do if p.Parent then p:Destroy() end end
	end
	if late.isFailing and late.isFailing() then return end
	letterbox(false, 0.4)
	showBar(true)
	local owner = state and state.owner
	if owner and owner == camOwner then
		local me = myRoot()
		over(owner, 0.8, function(dt)
			if not me then return false end
			local cf = me.CFrame
			drive(owner, CFrame.lookAt(cf.Position - cf.LookVector * 12 + Vector3.new(0, 5, 0), cf.Position + cf.LookVector * 10), 70, dt, 10)
		end)
		releaseCamera(owner)
	end
	local c = ensureCC()
	tween(c, 1, { Saturation = 0.08, Contrast = 0.1, TintColor = Color3.fromRGB(255, 238, 232) })
end

--==================================================
-- ATTACK VFX
--==================================================

local fxFolder = new("Folder", { Name = "CrueltyClientFX", Parent = workspace })
local function neon(props)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon })
	for k, v in pairs(props) do p[k] = v end
	p.Parent = fxFolder
	return p
end

local function slash(rootCF, targetPos)
	if not inArena() then return end
	-- a crescent of fire swept across the front of him
	local segs = {}
	for i = 1, 14 do segs[i] = neon({ Size = Vector3.new(0.4, 0.4, 2), Color = (i % 3 == 0) and WHITE or EMBER, Transparency = 1 }) end
	local centre = rootCF.Position + Vector3.new(0, 1.5, 0)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.35 do
			local a = (os.clock() - t0) / 0.35
			for i, s in ipairs(segs) do
				local u = (i - 1) / (#segs - 1)
				local ang = math.rad(-80 + 160 * u)
				local show = u <= a * 1.4
				local r = 9 + math.sin(u * math.pi) * 2
				local pos = (rootCF * CFrame.Angles(0, ang, math.rad(-15))) * Vector3.new(0, 0, -r) + Vector3.new(0, 1.5, 0) - rootCF.Position + rootCF.Position
				local tangent = (rootCF * CFrame.Angles(0, ang + 0.1, math.rad(-15)) * Vector3.new(0, 0, -r)) - (rootCF * CFrame.Angles(0, ang, math.rad(-15)) * Vector3.new(0, 0, -r))
				s.Size = Vector3.new(0.3 + math.sin(u * math.pi) * 1.2, 0.3, 2.2)
				s.CFrame = CFrame.lookAt(pos, pos + tangent)
				s.Transparency = show and (0.05 + a * 0.9) or 1
			end
			RunService.RenderStepped:Wait()
		end
		for _, s in ipairs(segs) do s:Destroy() end
	end)
	local me = myRoot()
	if me and (me.Position - targetPos).Magnitude < 8 then
		shake(1.1, 0.35)
		flashTo(Color3.fromRGB(255, 120, 90), 0.25)
	end
end

local function charge(pos, duration)
	if not inArena() then return end
	local orb = neon({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = EMBER, CFrame = CFrame.new(pos) })
	local halo = neon({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1, Color = CRIMSON, Material = Enum.Material.ForceField, CFrame = CFrame.new(pos) })
	local att = new("Attachment", { Parent = orb })
	new("ParticleEmitter", {
		Texture = SPARK, Color = ColorSequence.new(WHITE, EMBER), LightEmission = 1, LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 0) }),
		Speed = NumberRange.new(-22, -14), Lifetime = NumberRange.new(0.4, 0.6), SpreadAngle = Vector2.new(180, 180), Rate = 120, Parent = att,
	})
	new("PointLight", { Color = EMBER, Range = 20, Brightness = 4, Parent = orb })
	tween(orb, duration, { Size = Vector3.one * 5 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(halo, duration, { Size = Vector3.one * 8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(duration, function()
		orb:Destroy()
		halo:Destroy()
		if inArena() then shake(0.8, 0.3) end
	end)
end

--==================================================
-- VICTORY
--==================================================

local screens = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 40, Parent = gui })

local function rays(parent, colour)
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(1600, 1600), BackgroundTransparency = 1, ZIndex = 41, Parent = parent })
	for i = 1, 16 do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 80),
			Rotation = (i / 16) * 180, BackgroundColor3 = colour, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 41, Parent = holder,
		}, { new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 0.5), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(0.58, 0.5), NumberSequenceKeypoint.new(1, 1) }) }) })
	end
	return holder
end

local function burst(parent, colour, count)
	local cx, cy = 0.5, 0.42
	for i = 1, count do
		local sz = math.random(6, 16)
		local p = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy), Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = colour, Rotation = math.random(0, 90), BorderSizePixel = 0, ZIndex = 44, Parent = parent })
		local ang = math.random() * math.pi * 2
		local dist = 0.25 + math.random() * 0.45
		tween(p, 0.9 + math.random() * 0.6, {
			Position = UDim2.fromScale(cx + math.cos(ang) * dist * 0.6, cy + math.sin(ang) * dist),
			BackgroundTransparency = 1, Rotation = p.Rotation + math.random(-180, 180),
		}, Enum.EasingStyle.Quint)
		task.delay(1.6, function() p:Destroy() end)
	end
end

local function shockwave(parent, colour)
	local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, ZIndex = 43, Parent = parent },
		{ new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = colour, Thickness = 10 }) })
	local st = ring:FindFirstChildOfClass("UIStroke")
	tween(ring, 0.8, { Size = UDim2.fromOffset(1400, 1400) }, Enum.EasingStyle.Quint)
	tween(st, 0.8, { Transparency = 1, Thickness = 1 }, Enum.EasingStyle.Quint)
	task.delay(0.9, function() ring:Destroy() end)
end

local function bigWord(parent, word, colourA, colourB, y)
	local row = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y), Size = UDim2.fromScale(0.9, 0.2), BackgroundTransparency = 1, ZIndex = 45, Parent = parent },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) }) })
	local letters = {}
	for i = 1, #word do
		local ch = word:sub(i, i)
		local holder = new("Frame", { Size = UDim2.new(0, ch == " " and 30 or 110, 1, 0), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 45, Parent = row })
		if ch ~= " " then
			local l = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = ch, TextColor3 = WHITE, TextTransparency = 1, ZIndex = 46, Parent = holder },
				{ new("UIStroke", { Thickness = 6, Color = DARK, Transparency = 1 }), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(colourA, colourB) }), new("UIScale", { Scale = 3 }) })
			table.insert(letters, l)
		end
	end
	return row, letters
end

local function slamLetters(letters, stagger, onLand)
	for i, l in ipairs(letters) do
		task.delay((i - 1) * stagger, function()
			local sc = l:FindFirstChildOfClass("UIScale")
			local st = l:FindFirstChildOfClass("UIStroke")
			l.Rotation = math.random(-25, 25)
			tween(l, 0.12, { TextTransparency = 0 })
			tween(st, 0.12, { Transparency = 0 })
			tween(sc, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
			tween(l, 0.32, { Rotation = 0 }, Enum.EasingStyle.Back)
			if onLand then onLand(i) end
		end)
	end
end

local victoryRunning = false
local function victory(lines, winners)
	if victoryRunning or not inArena() then return end
	-- only the ones who actually won it (alive, never fell) get the screen
	if late.isFailing and late.isFailing() then return end
	if type(winners) == "table" and not table.find(winners, player.UserId) then return end
	if final then
		final.alive = false
		if final.restoreWorld then final.restoreWorld() end
		final = nil
	end
	stopQTE()
	victoryRunning = true
	hush()
	entranceOwner = nil
	showBar(false)
	targetHealth = 0

	-- hit-stop: snap onto him, white flash, colour drains
	local owner = takeCamera()
	local clone = bossClone()
	local head = clone and (clone:FindFirstChild("Head") or clone:FindFirstChild("HumanoidRootPart"))
	local focus = head and head.Position or arenaSpawn.Position
	local look = head and head.CFrame.LookVector or Vector3.new(0, 0, -1)
	camCF = CFrame.lookAt(focus + look * 14 + Vector3.new(0, 3, 0), focus)
	camFov = 40
	flashTo(WHITE, 0.9)
	play(BOOM, 1, 0.5)
	shake(2.5, 0.7)
	local c = ensureCC()
	c.Saturation = -1
	c.Contrast = 0.3
	letterbox(true, 0.3)
	stopMusic()

	-- slow orbit as he falls apart
	task.spawn(function()
		local startAng = math.atan2(look.X, look.Z)
		over(owner, 6, function(dt, a)
			local ang = startAng + a * 1.6
			local eye = focus + Vector3.new(math.sin(ang) * (16 + a * 10), 3 + a * 6, math.cos(ang) * (16 + a * 10))
			drive(owner, CFrame.lookAt(eye, focus - Vector3.new(0, a * 4, 0)), 45 + a * 15, dt, 3)
		end)
	end)

	task.delay(0.9, function()
		-- colour floods back in gold
		tween(c, 1.2, { Saturation = 0.25, TintColor = Color3.fromRGB(255, 232, 190), Contrast = 0.12 })
	end)

	-- VICTORY
	local layer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 40, Parent = screens })
	local dim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 40, Parent = layer })
	task.delay(1.3, function()
		tween(dim, 0.6, { BackgroundTransparency = 0.45 })
		local r = rays(layer, GOLD)
		r.Size = UDim2.fromOffset(200, 200)
		tween(r, 0.8, { Size = UDim2.fromOffset(1600, 1600) }, Enum.EasingStyle.Quint)
		task.spawn(function()
			while layer.Parent do
				r.Rotation += 0.15
				RunService.RenderStepped:Wait()
			end
		end)
		local _, letters = bigWord(layer, "VICTORY", Color3.fromRGB(255, 250, 220), GOLD, 0.42)
		slamLetters(letters, 0.08, function(i)
			play("rbxassetid://4612374036", 0.25, 0.8 + i * 0.06)
			if i == #letters then
				shockwave(layer, GOLD)
				burst(layer, GOLD, 50)
				flashTo(Color3.fromRGB(255, 235, 180), 0.4)
				play(BOOM, 0.7, 1.2)
			end
		end)
		-- a shine sweeping across the letters
		task.delay(1, function()
			for _, l in ipairs(letters) do
				local g = l:FindFirstChildOfClass("UIGradient")
				g.Rotation = 20
				g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, GOLD), ColorSequenceKeypoint.new(0.45, GOLD), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(0.55, GOLD), ColorSequenceKeypoint.new(1, GOLD) })
				g.Offset = Vector2.new(-1, 0)
				tween(g, 1.2, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
			end
		end)
		local sub = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.6, 0.05), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = "C R U E L T Y   H A S   F A L L E N", TextColor3 = Color3.fromRGB(255, 225, 180), TextTransparency = 1, ZIndex = 46, Parent = layer }, { textStroke(3) })
		local pill = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromOffset(420, 44), BackgroundColor3 = GOLD, BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = "TITLE UNLOCKED  -  CRUELTY SLAYER", TextColor3 = DARK, TextTransparency = 1, ZIndex = 46, Parent = layer },
			{ new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }) })
		task.delay(0.9, function() tween(sub, 0.6, { TextTransparency = 0 }) end)
		task.delay(1.4, function()
			pill.Size = UDim2.fromOffset(300, 34)
			tween(pill, 0.4, { BackgroundTransparency = 0, TextTransparency = 0, Size = UDim2.fromOffset(420, 44) }, Enum.EasingStyle.Back)
		end)
	end)

	-- out: fade to black just before the server moves you, then back in at Verity's
	task.delay(6.4, function()
		tween(black, 0.6, { BackgroundTransparency = 0 })
	end)
	task.delay(7.8, function()
		layer:Destroy()
		setActive(false)
		releaseCamera(owner)
		letterbox(false, 0.1)
		if cc then cc.Saturation, cc.Contrast, cc.TintColor = 0, 0, WHITE end
		tween(black, 1, { BackgroundTransparency = 1 })
		victoryRunning = false
	end)
end

--==================================================
-- YOU FAILED
--==================================================

local failRunning = false
late.isFailing = function() return failRunning ~= false end
local failStart = 0
local returned
local function failed(line)
	if failRunning then return end
	failRunning = true
	-- if the final attack's nuke is still playing, let it finish first
	local wait = (late.nukeUntil or 0) - os.clock()
	local afterNuke = wait > 0
	failStart = os.clock() + math.max(wait, 0)
	if afterNuke then task.wait(wait) end
	hush()
	entranceOwner = nil
	showBar(false)
	stopMusic()

	local owner = takeCamera()
	local body = camCF.Position
	local r = myRoot()
	if r then body = r.Position end
	local startCF = camCF
	local c = ensureCC()
	local b = ensureBlur()
	tween(c, 0.8, { Saturation = -0.9, TintColor = Color3.fromRGB(255, 170, 170), Contrast = 0.25 })
	tween(b, 1.5, { Size = 6 })
	flashTo(Color3.fromRGB(255, 40, 40), 0.7)
	play(BOOM, 0.7, 0.4)
	letterbox(true, 0.5)

	-- drift up and away off the body (after a nuke: keep drifting back from
	-- the mushroom cloud instead of cutting back down to the ground)
	task.spawn(function()
		if afterNuke then
			local from = camCF
			over(owner, 6, function(dt, a)
				drive(owner, from * CFrame.new(0, a * 40, a * 160), camFov, dt, 3)
			end)
			return
		end
		over(owner, 5, function(dt, a)
			local eye = body + Vector3.new(0, 6 + a * 22, 0) + (startCF.LookVector * -1 * Vector3.new(1, 0, 1)) * (8 + a * 10)
			drive(owner, CFrame.lookAt(eye, body), 60 + a * 10, dt, 2)
		end)
	end)

	local layer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 40, Parent = screens })
	-- cracks across the screen
	for i = 1, 7 do
		local crack = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.3, 0.42 + (math.random() - 0.5) * 0.2), Size = UDim2.new(0, 0, 0, 3), Rotation = math.random(0, 180), BackgroundColor3 = Color3.fromRGB(255, 80, 70), BorderSizePixel = 0, ZIndex = 42, Parent = layer })
		task.delay(0.35 + i * 0.03, function()
			tween(crack, 0.25, { Size = UDim2.new(0, math.random(300, 900), 0, 3) }, Enum.EasingStyle.Quint)
			task.delay(0.8, function() tween(crack, 1, { BackgroundTransparency = 1 }) end)
		end)
	end
	-- YOU FAILED: three offset copies (red / cyan / white) that jitter, then lock
	local copies = {}
	for i, col in ipairs({ Color3.fromRGB(255, 40, 60), Color3.fromRGB(60, 230, 255), WHITE }) do
		copies[i] = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.8, 0.18), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = "YOU FAILED", TextColor3 = col, TextTransparency = 1, ZIndex = 43 + i, Parent = layer },
			{ i == 3 and textStroke(6) or nil })
	end
	task.delay(0.4, function()
		for _, cp in ipairs(copies) do cp.TextTransparency = 0 end
		local t0 = os.clock()
		while os.clock() - t0 < 0.7 do
			local k = 1 - (os.clock() - t0) / 0.7
			copies[1].Position = UDim2.new(0.5, (math.random() - 0.5) * 30 * k - 6 * k, 0.42, (math.random() - 0.5) * 10 * k)
			copies[2].Position = UDim2.new(0.5, (math.random() - 0.5) * 30 * k + 6 * k, 0.42, (math.random() - 0.5) * 10 * k)
			copies[3].Position = UDim2.new(0.5, (math.random() - 0.5) * 8 * k, 0.42, 0)
			RunService.RenderStepped:Wait()
		end
		copies[1].Position = UDim2.new(0.5, -3, 0.42, 0)
		copies[2].Position = UDim2.new(0.5, 3, 0.42, 0)
		copies[3].Position = UDim2.fromScale(0.5, 0.42)
		shake(0.8, 0.3)
	end)
	local taunt = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.6, 0.05), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = ('"%s"  -  CRUELTY'):format(type(line) == "string" and line or "Weak."), TextColor3 = Color3.fromRGB(255, 170, 160), TextTransparency = 1, ZIndex = 46, Parent = layer }, { textStroke(3) })
	task.delay(1.3, function() tween(taunt, 0.6, { TextTransparency = 0 }) end)
	local back = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromScale(0.4, 0.035), BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = "returning to Verity's portal...", TextColor3 = Color3.fromRGB(210, 190, 200), TextTransparency = 1, ZIndex = 46, Parent = layer })
	task.delay(2.2, function() tween(back, 0.6, { TextTransparency = 0.2 }) end)
	task.delay(4.4, function() if failRunning then tween(black, 0.6, { BackgroundTransparency = 0 }) end end)

	-- stays black until you've respawned and been moved (the "Returned" event)
	local myStart = failStart
	task.delay(14, function()
		-- safety net: never leave the screen black if "Returned" got lost
		if failRunning and failStart == myStart then returned() end
	end)
	failRunning = { layer = layer, owner = owner }
end

returned = function()
	-- the fail sequence may still be waiting on the nuke: wait until it's
	-- actually up (a table), so we don't release the camera too early and
	-- have YOU FAILED grab it again afterwards
	local waited = 0
	while failRunning == true and waited < 16 do
		waited += task.wait(0.1)
	end
	-- then let the fail animation play out before lifting the black
	if failRunning then
		local w = 5.1 - (os.clock() - failStart)
		if w > 0 then task.wait(w) end
	end
	local state = failRunning
	failRunning = false
	task.wait(0.4)
	if type(state) == "table" and state.layer then state.layer:Destroy() end
	-- whatever still thinks it owns the camera (a final-attack shot, a
	-- phase-two shot...), you're back in the lobby now: hand it back
	if late.cancelFinal then late.cancelFinal() end
	releaseCamera()
	setActive(false)
	hush()
	stopQTE()
	letterbox(false, 0.1)
	if cc then cc.Saturation, cc.Contrast, cc.TintColor = 0, 0, WHITE end
	if blur then blur.Size = 0 end
	tween(black, 1, { BackgroundTransparency = 1 })
end

--==================================================
-- WIRING
--==================================================

fx.OnClientEvent:Connect(function(action, a, b, c)
	if action == "YouDied" then
		-- a still-running final attack shot must not keep fighting the fail camera
		-- (the nuke itself is kept: it IS the fail animation for the final attack)
		if final and not ((late.nukeUntil or 0) > os.clock()) then late.cancelFinal() end
		task.spawn(failed, a)
		return
	end
	if action == "Returned" then task.spawn(returned) return end
	if action == "Slash" then slash(a, b) return end
	if action == "Charge" then charge(a, b or 0.8) return end
	if not inArena() then return end

	if action == "Entrance" then
		task.spawn(entrance, a)
	elseif action == "Smash" then
		smash(a)
	elseif action == "Start" then
		task.spawn(introTalk, a)
	elseif action == "FightGo" then
		task.spawn(fightGo)
	elseif action == "Health" then
		setHealth(a, b)
	elseif action == "PhaseTwo" then
		task.spawn(phaseTwo, a, b)
	elseif action == "PhaseSlam" then
		phaseSlam(a)
	elseif action == "FinalAttack" then
		task.spawn(finalAttack, a, b)
	elseif action == "FinalQTE" then
		startQTE(a)
	elseif action == "QTEResult" then
		-- the server has the final word; the rings already judged locally
	elseif action == "FinalResolve" then
		task.spawn(finalResolve, a, b, c)
	elseif action == "FinalEnd" then
		task.spawn(finalEnd)
	elseif action == "Taunt" then
		taunt(a, b)
	elseif action == "Defeated" then
		task.spawn(victory, a, b)
	elseif action == "End" then
		if not victoryRunning and not failRunning then
			setActive(false)
			releaseCamera()
		end
	end
end)

cruelty:GetAttributeChangedSignal("FightActive"):Connect(function()
	if not cruelty:GetAttribute("FightActive") and not victoryRunning and not failRunning then
		setActive(false)
	end
end)

-- never leave the camera stuck if you respawn mid-sequence (a failure is
-- handled by `returned`)
player.CharacterAdded:Connect(function()
	if not failRunning and camOwner > 0 and workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable and not victoryRunning then
		releaseCamera()
	end
end)

-- Hard reset: everything this fight put on screen comes off and the
-- camera goes back to you.
local function forceRecover(leaveFight)
	if late.cancelFinal then pcall(late.cancelFinal) end
	late.nukeUntil = 0
	local state = failRunning
	failRunning = false
	if type(state) == "table" and state.layer then state.layer:Destroy() end
	releaseCamera()
	stopQTE()
	hush()
	letterbox(false, 0.1)
	if cc then cc.Saturation, cc.Contrast, cc.TintColor = 0, 0, WHITE end
	if blur then blur.Size = 0 end
	tween(black, 0.6, { BackgroundTransparency = 1 })
	if leaveFight then setActive(false) end
end

-- You died but the server never sent "YouDied" (the fight had already
-- ended, or you were outside its range): don't leave the camera hanging.
local function watchMyDeath(character)
	local hum = character:WaitForChild("Humanoid", 10)
	if not hum then return end
	hum.Died:Connect(function()
		task.wait(2.5)
		if not failRunning and late.holding and not victoryRunning then
			forceRecover(false)
		end
	end)
end
if player.Character then task.spawn(watchMyDeath, player.Character) end
player.CharacterAdded:Connect(watchMyDeath)

-- Watchdog: once you're alive and back OUT of the arena, nothing from this
-- fight may keep the camera. Covers dying mid-nuke / right before the
-- rings, where a late shot could grab the camera again after `returned`.
task.spawn(function()
	local strayFor = 0
	while true do
		local dt = task.wait(0.5)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local alive = hum ~= nil and hum.Health > 0
		local cam = workspace.CurrentCamera
		local stuck = alive and late.holding and not victoryRunning and not inArena()
			and cam and cam.CameraType == Enum.CameraType.Scriptable
			and (os.clock() - (late.lastDrive or 0)) > 1.2
		if stuck then
			strayFor += dt
		else
			strayFor = 0
		end
		-- the fail screen gets its full run first; anything else, fix fast
		local limit = failRunning and 8 or 1.5
		if strayFor >= limit then
			strayFor = 0
			forceRecover(true)
		end
	end
end)

--==================================================
-- MUSIC WATCHDOG
-- The fight's cinematics stop the score on purpose (time-stop,
-- the nuke, victory, fail). If one of them is cut short the
-- track never came back and the fight went silent. While the
-- fight is live and nothing cinematic is running, the right
-- track is always playing.
--==================================================
task.spawn(function()
	while true do
		task.wait(1)
		if active and not victoryRunning and not failRunning and final == nil
			and workspace:GetAttribute("CrueltyFightLive") == true
			and os.clock() - lastMusicStop > 10
			and (playing == nil or not playing.IsPlaying) then
			local name = (phase == 2) and "CrueltyPhase2" or "CrueltyPhase1"
			if playing and not playing.IsPlaying then playing = nil end
			playTrack(name)
			duckWorld(true)
		end
	end
end)

--==================================================
-- BAR ANIMATION
--==================================================

RunService.RenderStepped:Connect(function(dt)
	if not active then return end
	local t = os.clock()
	shownHealth += (targetHealth - shownHealth) * math.min(dt * 12, 1)
	ghostHealth += (shownHealth - ghostHealth) * math.min(dt * 2.2, 1)
	fill.Size = UDim2.fromScale(math.max(shownHealth, 0), 1)
	ghost.Size = UDim2.fromScale(math.max(ghostHealth, shownHealth), 1)
	if hitFlash > 0 then
		hitFlash = math.max(0, hitFlash - dt * 3)
		fill.BackgroundColor3 = WHITE:Lerp(Color3.fromRGB(255, 255, 255), 1)
		barScale.Scale = 1 + hitFlash * 0.035
		fillGrad.Offset = Vector2.new(0, -hitFlash * 0.3)
	end
	barNameGrad.Offset = Vector2.new(math.sin(t * 0.8) * 0.5, 0)
	local pulse = (math.sin(t * (phase == 2 and 5 or 2.5)) + 1) / 2
	vignette.BackgroundTransparency = math.min(vignette.BackgroundTransparency + dt * 0.3, 0.95 - pulse * (phase == 2 and 0.12 or 0.05))
end)
