--==================================================
-- CRUELTY BOSS UI  (client)
--
-- Replaces the plain corner health bar with a proper boss
-- presentation:
--   * centred boss bar with a lagging damage "ghost" fill,
--     segment ticks, phase colouring and a hit flash
--   * name plate with a subtitle that changes in phase 2
--   * dialogue subtitles (typed out) driven by the server
--   * "PHASE II" banner + screen pulse
--   * "CRUELTY DEFEATED" prompt on the kill
--   * "YOU DIED" prompt with a RETRY button
--   * the boss phonk track, swapped up a gear in phase 2
--
-- The bar hides itself the moment the fight ends or the
-- boss dies, so nothing is left hanging on screen.
--==================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local cutscene = workspace:WaitForChild("CrueltyCutscene")
local cruelty = cutscene:WaitForChild("Cruelty")
local dummyHumanoid = cruelty:WaitForChild("Humanoid")

local fx = ReplicatedStorage:WaitForChild("CrueltyFightFX")
local retryRemote = ReplicatedStorage:WaitForChild("CrueltyRetry")

local RED = Color3.fromRGB(200, 30, 30)
local CRIMSON = Color3.fromRGB(255, 70, 50)
local EMBER = Color3.fromRGB(255, 160, 50)
local DARK = Color3.fromRGB(18, 8, 10)
local WHITE = Color3.new(1, 1, 1)

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end
local function stroke(thick, color, transparency)
	return new("UIStroke", {
		Thickness = thick, Color = color or Color3.new(0, 0, 0),
		Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end
-- Text needs Contextual, or the stroke draws a box around the whole label
-- instead of outlining the letters.
local function textStroke(thick, color)
	return new("UIStroke", {
		Thickness = thick, Color = color or Color3.new(0, 0, 0),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end
local function tween(o, t, goal, style)
	return TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
end

--==================================================
-- UI
--==================================================

local gui = new("ScreenGui", {
	Name = "BossHealthUI", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 80, Enabled = false, Parent = playerGui,
})

-- red vignette that breathes while the fight runs
local vignette = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED, BackgroundTransparency = 1, Parent = gui })
new("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0),
	}),
	Rotation = 90, Parent = vignette,
})

local root = new("Frame", {
	Name = "BossBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.045, 0),
	Size = UDim2.fromScale(0.52, 0.12), BackgroundTransparency = 1, Parent = gui,
}, { new("UIAspectRatioConstraint", { AspectRatio = 7.5 }), new("UISizeConstraint", { MaxSize = Vector2.new(900, 130), MinSize = Vector2.new(300, 44) }) })
local rootScale = new("UIScale", { Parent = root })

local nameLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 0.4), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
	TextScaled = true, TextColor3 = WHITE, Text = "C R U E L T Y", Parent = root,
}, { textStroke(3, DARK) })
local nameGrad = new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CRIMSON), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, CRIMSON),
	}),
	Parent = nameLabel,
})

local subtitle = new("TextLabel", {
	Position = UDim2.fromScale(0, 0.38), Size = UDim2.fromScale(1, 0.18), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Color3.fromRGB(230, 140, 130),
	Text = "THE THING BEHIND THE PORTAL", Parent = root,
}, { textStroke(2, DARK) })

local barBack = new("Frame", {
	Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.34),
	BackgroundColor3 = Color3.fromRGB(26, 12, 14), Parent = root,
}, { new("UICorner", { CornerRadius = UDim.new(0.35, 0) }), stroke(3, DARK) })

-- the ghost fill lags behind, so a big hit shows as a white sliver draining away
local ghost = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 220, 210), BorderSizePixel = 0, Parent = barBack },
	{ new("UICorner", { CornerRadius = UDim.new(0.35, 0) }) })
local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 2, Parent = barBack },
	{ new("UICorner", { CornerRadius = UDim.new(0.35, 0) }) })
local fillGrad = new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 10, 20)),
		ColorSequenceKeypoint.new(0.5, CRIMSON),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 10, 20)),
	}),
	Rotation = 90, Parent = fill,
})

-- segment ticks across the bar
for i = 1, 9 do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(i / 10, 0),
		Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = DARK, BackgroundTransparency = 0.45,
		BorderSizePixel = 0, ZIndex = 3, Parent = barBack,
	})
end

local hpText = new("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
	TextScaled = true, TextColor3 = WHITE, ZIndex = 4, Text = "", Parent = barBack,
}, { textStroke(2, DARK), new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }) })

-- dialogue subtitles (bright, with a heavy dark outline -- the arena is
-- red-lit, so anything dark was unreadable down there)
local sub = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.9), Size = UDim2.fromScale(0.78, 0.12),
	BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true, TextWrapped = true,
	TextColor3 = Color3.fromRGB(255, 240, 235), Text = "", TextTransparency = 1, Parent = gui,
}, { textStroke(4, Color3.fromRGB(8, 0, 2)), new("UITextSizeConstraint", { MaxTextSize = 34 }) })
-- A UIStroke does NOT follow its label's TextTransparency, so fading the text
-- out on its own leaves a solid black ghost of the words sitting on screen.
-- Both have to be faded together.
local subStroke = sub:FindFirstChildOfClass("UIStroke")

-- big centre banner (PHASE II / DEFEATED / YOU DIED)
local banner = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.8, 0.16),
	BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = WHITE, Text = "", TextTransparency = 1, Parent = gui,
}, { textStroke(5, Color3.fromRGB(8, 0, 2)) })
local bannerStroke = banner:FindFirstChildOfClass("UIStroke")
local bannerScale = new("UIScale", { Parent = banner })
local bannerGrad = new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 100)),
		ColorSequenceKeypoint.new(0.5, WHITE),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 90)),
	}),
	Parent = banner,
})

-- retry panel
local retryPanel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(280, 76),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.05, Visible = false, Parent = gui,
}, { new("UICorner", { CornerRadius = UDim.new(0, 14) }), stroke(4, CRIMSON) })
local retryBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.82, 0.5),
	BackgroundColor3 = RED, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE,
	Text = "RETRY", Parent = retryPanel,
}, { new("UICorner", { CornerRadius = UDim.new(0, 10) }), stroke(2, WHITE), new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })
new("TextLabel", {
	Position = UDim2.fromScale(0, 0.04), Size = UDim2.fromScale(1, 0.3), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Color3.fromRGB(240, 150, 140),
	Text = "back to the arena entrance", Parent = retryPanel,
})

--==================================================
-- MUSIC
--==================================================

local musicFolder = SoundService:FindFirstChild("BossMusic")
local function track(name) return musicFolder and musicFolder:FindFirstChild(name) end
local playing = nil

local function musicOn()
	return player:GetAttribute("Set_Audio") ~= false and player:GetAttribute("Set_Music") ~= false
end

local function playTrack(name)
	local s = track(name)
	if not s or playing == s then return end
	local previous = playing
	playing = s
	s.TimePosition = 0
	s.Volume = 0
	s:Play()
	tween(s, 1.2, { Volume = musicOn() and (s:GetAttribute("TargetVolume") or 0.45) or 0 }):Play()
	if previous then
		tween(previous, 1, { Volume = 0 }):Play()
		task.delay(1.1, function() if previous ~= playing then previous:Stop() end end)
	end
end

local function stopMusic()
	local s = playing
	playing = nil
	if not s then return end
	tween(s, 1.2, { Volume = 0 }):Play()
	task.delay(1.3, function() if playing ~= s then s:Stop() end end)
end

-- the island soundtrack steps aside while the fight is on
local worldMusic = SoundService:FindFirstChild("Music")
local function duckWorld(quiet)
	if not worldMusic then return end
	for _, s in ipairs(worldMusic:GetChildren()) do
		if s:IsA("Sound") and s.IsPlaying then
			tween(s, 1, { Volume = quiet and 0 or (s:GetAttribute("SetOrigVolume") or 0.25) }):Play()
		end
	end
end

--==================================================
-- BEHAVIOUR
--==================================================

local shownHealth, targetHealth, maxHealth = 1, 1, dummyHumanoid.MaxHealth
local ghostHealth = 1
local hitFlash = 0
local phase = 1
local active = false

local function setHealth(health, max)
	maxHealth = max or maxHealth
	targetHealth = math.clamp(maxHealth > 0 and health / maxHealth or 0, 0, 1)
	hpText.Text = ("%d / %d"):format(math.max(math.floor(health), 0), math.floor(maxHealth))
	hitFlash = 1
end

local typing = 0
local function say(text, hold)
	typing += 1
	local mine = typing
	sub.Text = ""
	sub.TextTransparency = 0
	subStroke.Transparency = 0
	for i = 1, #text do
		if typing ~= mine then return end
		sub.Text = text:sub(1, i)
		task.wait(0.022)
	end
	task.delay(hold or 2.4, function()
		if typing == mine then
			tween(sub, 0.5, { TextTransparency = 1 }):Play()
			tween(subStroke, 0.5, { Transparency = 1 }):Play()
		end
	end)
end

-- Says each line in turn. A newer speak() cancels an older one,
-- because `typing` has moved on by the time it checks.
local function speak(lines, gap)
	task.spawn(function()
		for _, line in ipairs(lines) do
			local mine = typing + 1
			say(line, gap or 1.2)
			task.wait(#line * 0.022 + (gap or 1.2) + 0.3)
			if typing ~= mine then return end -- someone else started talking
		end
	end)
end

local function showBanner(text, color, hold)
	banner.Text = text
	bannerGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.5, WHITE),
		ColorSequenceKeypoint.new(1, EMBER),
	})
	banner.TextTransparency = 1
	bannerStroke.Transparency = 1
	bannerScale.Scale = 2.2
	tween(banner, 0.25, { TextTransparency = 0 }):Play()
	tween(bannerStroke, 0.25, { Transparency = 0 }):Play()
	tween(bannerScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back):Play()
	task.delay(hold or 2, function()
		tween(banner, 0.6, { TextTransparency = 1 }):Play()
		tween(bannerStroke, 0.6, { Transparency = 1 }):Play()
		tween(bannerScale, 0.6, { Scale = 1.4 }):Play()
	end)
end

local function setActive(on)
	active = on
	gui.Enabled = on
	if on then
		phase = 1
		shownHealth, ghostHealth, targetHealth = 1, 1, 1
		subtitle.Text = "THE THING BEHIND THE PORTAL"
		fillGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 10, 20)),
			ColorSequenceKeypoint.new(0.5, CRIMSON),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 10, 20)),
		})
		rootScale.Scale = 0.6
		tween(rootScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back):Play()
		playTrack("VerityPhonk")
		duckWorld(true)
	else
		retryPanel.Visible = false
		sub.TextTransparency = 1
		stopMusic()
		duckWorld(false)
	end
end

fx.OnClientEvent:Connect(function(action, a, b)
	if action == "Entrance" then
		setActive(true)
		hpText.Text = ""
		showBanner("SOMETHING IS COMING", CRIMSON, 1.4)

	elseif action == "Smash" then
		-- camera kick + screen shove on the landing
		task.spawn(function()
			local cam = workspace.CurrentCamera
			local t0 = os.clock()
			while os.clock() - t0 < 0.9 do
				local k = (1 - (os.clock() - t0) / 0.9) ^ 2 * 3.5
				cam.CFrame = cam.CFrame * CFrame.Angles(
					math.rad((math.random() - 0.5) * k),
					math.rad((math.random() - 0.5) * k),
					math.rad((math.random() - 0.5) * k))
				RunService.RenderStepped:Wait()
			end
		end)
		vignette.BackgroundTransparency = 0.45
		tween(vignette, 1.2, { BackgroundTransparency = 0.88 }):Play()

	elseif action == "Start" then
		setActive(true)
		setHealth(dummyHumanoid.MaxHealth, dummyHumanoid.MaxHealth)
		showBanner("C R U E L T Y", CRIMSON, 1.6)
		if type(a) == "table" then speak(a) end

	elseif action == "FightGo" then
		-- the truce is over; from here everyone can hurt everyone
		showBanner("F I G H T", Color3.fromRGB(255, 196, 64), 1.3)

	elseif action == "Health" then
		setHealth(a, b)

	elseif action == "PhaseTwo" then
		phase = 2
		subtitle.Text = "ENRAGED"
		fillGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 40, 0)),
			ColorSequenceKeypoint.new(0.5, EMBER),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 40, 0)),
		})
		showBanner("PHASE  II", EMBER, 1.8)
		playTrack("VerityPhonkRage")
		if type(a) == "table" then speak(a) end
		vignette.BackgroundTransparency = 0.3
		tween(vignette, 1.5, { BackgroundTransparency = 0.8 }):Play()

	elseif action == "Defeated" then
		if type(a) == "table" then speak(a) end
		targetHealth = 0
		task.delay(1.2, function()
			showBanner("CRUELTY DEFEATED", Color3.fromRGB(255, 215, 90), 3.2)
			tween(root, 0.6, { BackgroundTransparency = 1 }):Play()
			tween(rootScale, 0.6, { Scale = 0.8 }):Play()
			tween(nameLabel, 0.6, { TextTransparency = 1 }):Play()
			tween(subtitle, 0.6, { TextTransparency = 1 }):Play()
			tween(barBack, 0.6, { BackgroundTransparency = 1 }):Play()
			tween(fill, 0.6, { BackgroundTransparency = 1 }):Play()
			tween(ghost, 0.6, { BackgroundTransparency = 1 }):Play()
			tween(hpText, 0.6, { TextTransparency = 1 }):Play()
		end)
		task.delay(5, function()
			setActive(false)
			for _, o in ipairs({ nameLabel, subtitle, hpText }) do o.TextTransparency = 0 end
			for _, o in ipairs({ barBack, fill, ghost }) do o.BackgroundTransparency = 0 end
			root.BackgroundTransparency = 1
		end)

	elseif action == "YouDied" then
		showBanner("YOU DIED", RED, 2.6)
		if type(a) == "string" then task.spawn(say, a, 2) end
		retryPanel.Visible = true

	elseif action == "Retried" then
		retryPanel.Visible = false
		showBanner("AGAIN", EMBER, 1.2)

	elseif action == "Toast" then
		retryPanel.Visible = false
		if type(a) == "string" then task.spawn(say, a, 2.5) end

	elseif action == "End" then
		setActive(false)
	end
end)

retryBtn.Activated:Connect(function()
	retryRemote:FireServer()
end)

-- the dummy's health mirrors the clone's, so this keeps the bar honest
-- even if a Health broadcast is missed
dummyHumanoid.HealthChanged:Connect(function(h)
	if active then setHealth(h, dummyHumanoid.MaxHealth) end
end)

cruelty:GetAttributeChangedSignal("FightActive"):Connect(function()
	if not cruelty:GetAttribute("FightActive") then setActive(false) end
end)

--==================================================
-- ANIMATION LOOP
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
		fill.BackgroundColor3 = RED:Lerp(WHITE, hitFlash * 0.7)
		rootScale.Scale = 1 + hitFlash * 0.035
	else
		fill.BackgroundColor3 = RED
	end

	nameGrad.Offset = Vector2.new(math.sin(t * 0.8) * 0.5, 0)
	local pulse = (math.sin(t * (phase == 2 and 5 or 2.5)) + 1) / 2
	vignette.BackgroundTransparency = math.min(vignette.BackgroundTransparency, 0.94 - pulse * (phase == 2 and 0.12 or 0.05))
	if phase == 2 then
		root.Position = UDim2.new(0.5, math.sin(t * 22) * 2, 0.045, 0)
	else
		root.Position = UDim2.new(0.5, 0, 0.045, 0)
	end
end)
