--==================================================
-- TUTORIAL  (client)
--
-- Shows on a player's first join (after the opening cutscene), and any time
-- from the "?" button (bottom-right, above the music player).
--
-- A short tour of little sets built on floating pads in
-- Workspace.TutorialStage, far off the map where nothing wanders into shot.
-- Getting there and back goes through a loading screen, so the camera never
-- whips 55,000 studs across the sky. Between steps the camera glides from
-- set to set. NEXT / BACK or the arrow keys move through it; SKIP ends it.
-- Finishing or skipping saves Set_TutorialDone so it never auto-plays again.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local settingsRemote = ReplicatedStorage:WaitForChild("PlotSettings")

local function V(x, y, z) return Vector3.new(x, y, z) end

-- Pads run along +X from (38000, 2000, -38000), 300 studs apart.
-- Only 8 of the 12 sets are used; the others stay built but unvisited.
local STEPS = {
	{ Title = "WELCOME TO BECOME LA PEACE",
		Body = "Collect lapis, grow your Peace Points (PP), ascend to new islands, and eventually face the FINAL BOSS. Here's the quick version.",
		Cam = V(37974, 2022, -38054), Look = V(38000, 2006, -38000), Drift = V(16, 0, 0) },
	{ Title = "COLLECT LAPIS",
		Body = "Lapis spawns all over the island. Walk near it with your staff to pull it in. Better staffs reach further and find rarer lapis.",
		Cam = V(38326, 2020, -38052), Look = V(38300, 2006, -38000), Drift = V(-16, 0, 0) },
	{ Title = "YOUR PLOT",
		Body = "Walk into an empty plot to claim it, then place lapis on the platforms. Placed lapis earns PP every second, even while you're away collecting.",
		Cam = V(38574, 2026, -38058), Look = V(38600, 2006, -38000), Drift = V(14, 0, -4) },
	{ Title = "SELL, SHOP & UPGRADES",
		Body = "SELL lapis for PP, buy better staffs in the SHOP, and talk to the sage for BASE UPGRADES: more slots, more power, teleporting.",
		Cam = V(38926, 2022, -38056), Look = V(38900, 2006, -38000), Drift = V(-14, 0, -4) },
	{ Title = "QUESTS",
		Body = "People around the islands need help. Talk to anyone with a ! over their head. Quests pay big and some unlock new places, like Mr Villager's village.",
		Cam = V(39174, 2020, -38052), Look = V(39200, 2006, -38000), Drift = V(16, 0, 0) },
	{ Title = "ASCEND & NEW ISLANDS",
		Body = "Save up PP and ASCEND to reset for permanent boosts. Ascending opens 67 Island, Verity Island and finally La Peace Island.",
		Cam = V(39774, 2028, -38060), Look = V(39800, 2010, -38000), Drift = V(14, 0, -5) },
	{ Title = "THE FINAL BOSS",
		Body = "Finish every quest and buy the final upgrade at your plot. The portal opens and you can take on the Final Boss with a party.",
		Cam = V(40726, 2028, -38058), Look = V(40700, 2010, -38000), Drift = V(-16, 0, 0) },
	{ Title = "YOU'RE READY",
		Body = "Right side: [G] inventory, [F] shop, [R] ascend, [T] teleport. The star opens the Robux shop. Tap ? any time to see this again. Now go grab some lapis.",
		Cam = V(41318, 2013, -38044), Look = V(41300, 2009.5, -37996), Drift = V(-12, 2, 8), ShowHud = true },
}

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end

local C = {
	ink = Color3.fromRGB(16, 12, 30),
	top = Color3.fromRGB(70, 52, 128),
	bottom = Color3.fromRGB(24, 18, 46),
	gold = Color3.fromRGB(255, 204, 84),
	text = Color3.new(1, 1, 1),
	dim = Color3.fromRGB(205, 200, 232),
	green = Color3.fromRGB(70, 200, 120),
	btn = Color3.fromRGB(52, 44, 90),
}

--==================================================
-- UI
--==================================================

local gui = new("ScreenGui", { Name = "Tutorial", ResetOnSpawn = false, DisplayOrder = 60, IgnoreGuiInset = true, Enabled = false, Parent = playerGui })

-- letterbox bars that slide in
local topBar = new("Frame", { Size = UDim2.new(1, 0, 0.075, 0), Position = UDim2.fromScale(0, -0.075), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui })
local botBar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1.075), Size = UDim2.new(1, 0, 0.075, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui })

local card = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -26), Size = UDim2.new(0.56, 0, 0, 206),
	BackgroundColor3 = C.text, Parent = gui,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 18) }),
	new("UIStroke", { Color = C.gold, Thickness = 3 }),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.top, C.bottom) }),
	new("UISizeConstraint", { MinSize = Vector2.new(380, 0), MaxSize = Vector2.new(780, 999) }),
})
local pill = new("TextLabel", {
	Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(104, 24), BackgroundColor3 = C.gold,
	FontFace = FONT, TextSize = 15, TextColor3 = C.ink, Text = "STEP 1 / 8", Parent = card,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local titleLabel = new("TextLabel", {
	Position = UDim2.fromOffset(18, 44), Size = UDim2.new(1, -36, 0, 36), BackgroundTransparency = 1,
	FontFace = FONT, TextScaled = true, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
}, { new("UIStroke", { Thickness = 2, Color = C.ink }) })
local bodyLabel = new("TextLabel", {
	Position = UDim2.fromOffset(18, 86), Size = UDim2.new(1, -36, 0, 64), BackgroundTransparency = 1,
	FontFace = BODY_FONT, TextSize = 17, TextWrapped = true, TextColor3 = C.dim,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card,
})

-- progress bar along the bottom of the card
local track = new("Frame", {
	Position = UDim2.new(0, 18, 1, -34), Size = UDim2.new(1, -310, 0, 8), BackgroundColor3 = C.btn, Parent = card,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local fill = new("Frame", { Size = UDim2.fromScale(1 / #STEPS, 1), BackgroundColor3 = C.gold, Parent = track },
	{ new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

local function button(text, color, xOffset, width)
	return new("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, xOffset, 1, -16), Size = UDim2.fromOffset(width, 40),
		BackgroundColor3 = color, Text = text, FontFace = FONT, TextSize = 18, TextColor3 = C.text, AutoButtonColor = true, Parent = card,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 12) }), new("UIStroke", { Thickness = 2, Color = C.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
end
local nextBtn = button("NEXT ▶", Color3.fromRGB(96, 110, 255), -16, 124)
local backBtn = button("◀ BACK", C.btn, -148, 104)
local skipBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0.075, 12), Size = UDim2.fromOffset(150, 34),
	BackgroundColor3 = C.bottom, BackgroundTransparency = 0.1, Text = "SKIP TOUR ⏭",
	FontFace = FONT, TextSize = 16, TextColor3 = C.text, Parent = gui,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = C.gold, Thickness = 1.5 }) })

-- loading / transition screen
local loader = new("ScreenGui", { Name = "TutorialLoader", ResetOnSpawn = false, DisplayOrder = 70, IgnoreGuiInset = true, Enabled = false, Parent = playerGui })
local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.text, BackgroundTransparency = 1, Parent = loader },
	{ new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 28, 80), Color3.fromRGB(8, 6, 18)) }) })
-- the same look as the intro screen: slow-turning rays behind a tilted
-- portrait card of the sage
local rays = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(1400, 1400),
	BackgroundTransparency = 1, Parent = shade,
})
local RAY_COUNT = 18
for i = 1, RAY_COUNT do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 70), Rotation = (i / RAY_COUNT) * 180,
		BackgroundColor3 = Color3.fromRGB(120, 150, 255), BackgroundTransparency = 1, BorderSizePixel = 0,
		Parent = rays,
	}, { new("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.6),
		NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.65, 0.6), NumberSequenceKeypoint.new(1, 1),
	}) }) })
end
local portrait = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromOffset(150, 150),
	BackgroundColor3 = Color3.fromRGB(30, 30, 50), Image = "rbxassetid://79764642487535", ImageTransparency = 1,
	BackgroundTransparency = 1, Rotation = -5, Parent = shade,
}, { new("UICorner", { CornerRadius = UDim.new(0, 22) }), new("UIStroke", { Color = C.gold, Thickness = 4, Transparency = 1 }) })
local loadTitle = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0.6, 0, 0, 58),
	BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, TextColor3 = C.gold, TextTransparency = 1,
	Text = "BECOME LA PEACE", Parent = shade,
}, { new("UIStroke", { Thickness = 3, Color = C.ink, Transparency = 1 }) })
local loadSub = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.6, 0, 0, 24),
	BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, TextColor3 = C.dim, TextTransparency = 1,
	Text = "PREPARING YOUR TOUR", Parent = shade,
})
local spinner = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(46, 46),
	BackgroundTransparency = 1, Parent = shade,
})
local spinDots = {}
for i = 1, 8 do
	local a = (i / 8) * math.pi * 2
	spinDots[i] = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + math.cos(a) * 0.45, 0.5 + math.sin(a) * 0.45),
		Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.gold, BackgroundTransparency = 1, Parent = spinner,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end
local loadTrack = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromOffset(260, 6),
	BackgroundColor3 = C.btn, BackgroundTransparency = 1, Parent = shade,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local loadFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.gold, BackgroundTransparency = 1, Parent = loadTrack },
	{ new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

local helpGui = new("ScreenGui", { Name = "TutorialButton", ResetOnSpawn = false, DisplayOrder = 4, Parent = playerGui })
local helpBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -66), Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = Color3.fromRGB(20, 20, 35), BackgroundTransparency = 0.35, Text = "?",
	FontFace = FONT, TextSize = 18, TextColor3 = C.text, Parent = helpGui,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = C.gold, Thickness = 1.2, Transparency = 0.3 }) })

--==================================================
-- state
--==================================================

local camera = workspace.CurrentCamera
local running = false
local busy = false -- a transition is playing
local index = 1
local stepStart = 0
local fromCF, flyTime = nil, 1.4
local hudStates = {}
local KEEP = { Tutorial = true, TutorialLoader = true, NowPlaying = true, IntroCutscene = true, AdminPanelGui = true }

local function stepCF(step, t)
	local k = math.clamp(t / 12, 0, 1)
	return CFrame.lookAt(step.Cam + (step.Drift or Vector3.zero) * k, step.Look)
end
local function hideHud()
	Players.LocalPlayer:SetAttribute("HideAura_Tutorial", true) -- auras off during the tour
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and not KEEP[g.Name] then
			if hudStates[g] == nil then hudStates[g] = g.Enabled end
			g.Enabled = false
		end
	end
end
local function restoreHud()
	Players.LocalPlayer:SetAttribute("HideAura_Tutorial", nil)
	for g, was in pairs(hudStates) do if g.Parent then g.Enabled = was end end
end
local function controls(enabled)
	task.spawn(function()
		pcall(function()
			local ps = player:FindFirstChild("PlayerScripts")
			local mod = ps and ps:FindFirstChild("PlayerModule")
			if not mod then return end
			local c = require(mod):GetControls()
			if enabled then c:Enable() else c:Disable() end
		end)
	end)
end

local function tween(obj, time, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

--==================================================
-- loading screen
--==================================================

local spinning = false
local function spin()
	spinning = true
	task.spawn(function()
		local t0 = os.clock()
		while spinning do
			local t = os.clock() - t0
			rays.Rotation = t * 8
			portrait.Rotation = -5 + math.sin(t * 1.4) * 3
			for i, d in ipairs(spinDots) do
				local k = ((t * 1.6 - i / 8) % 1)
				d.BackgroundTransparency = 0.1 + k * 0.8
				d.Size = UDim2.fromOffset(10 - k * 5, 10 - k * 5)
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

local function loaderIn(subtitle)
	loadSub.Text = subtitle
	loadFill.Size = UDim2.fromScale(0, 1)
	loader.Enabled = true
	shade.BackgroundTransparency = 1
	loadTitle.Position = UDim2.fromScale(0.5, 0.45)
	tween(shade, 0.35, { BackgroundTransparency = 0 })
	task.wait(0.2)
	tween(loadTitle, 0.4, { TextTransparency = 0, Position = UDim2.fromScale(0.5, 0.42) }, Enum.EasingStyle.Back)
	portrait.Size = UDim2.fromOffset(110, 110)
	tween(portrait, 0.45, { ImageTransparency = 0, Size = UDim2.fromOffset(150, 150) }, Enum.EasingStyle.Back)
	tween(portrait:FindFirstChildOfClass("UIStroke"), 0.45, { Transparency = 0 })
	for _, r in ipairs(rays:GetChildren()) do tween(r, 0.6, { BackgroundTransparency = 0.55 }) end
	tween(loadTitle:FindFirstChildOfClass("UIStroke"), 0.4, { Transparency = 0 })
	tween(loadSub, 0.4, { TextTransparency = 0 })
	tween(loadTrack, 0.3, { BackgroundTransparency = 0 })
	tween(loadFill, 0.3, { BackgroundTransparency = 0 })
	spin()
	task.wait(0.2)
end

local function loaderProgress(a, time)
	tween(loadFill, time or 0.25, { Size = UDim2.fromScale(a, 1) })
end

local function loaderOut()
	loaderProgress(1, 0.2)
	task.wait(0.25)
	spinning = false
	tween(loadTitle, 0.3, { TextTransparency = 1 })
	tween(loadTitle:FindFirstChildOfClass("UIStroke"), 0.3, { Transparency = 1 })
	tween(portrait, 0.3, { ImageTransparency = 1 })
	tween(portrait:FindFirstChildOfClass("UIStroke"), 0.3, { Transparency = 1 })
	for _, r in ipairs(rays:GetChildren()) do tween(r, 0.3, { BackgroundTransparency = 1 }) end
	tween(loadSub, 0.3, { TextTransparency = 1 })
	tween(loadTrack, 0.3, { BackgroundTransparency = 1 })
	tween(loadFill, 0.3, { BackgroundTransparency = 1 })
	for _, d in ipairs(spinDots) do tween(d, 0.3, { BackgroundTransparency = 1 }) end
	task.wait(0.15)
	tween(shade, 0.55, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	task.wait(0.55)
	loader.Enabled = false
end

--==================================================
-- steps
--==================================================

local typing = 0
local function typeBody(text)
	typing += 1
	local my = typing
	bodyLabel.Text = text
	bodyLabel.MaxVisibleGraphemes = 0
	task.spawn(function()
		local total = utf8.len(text) or #text
		local shown = 0
		while shown < total and typing == my do
			shown = math.min(total, shown + 2)
			bodyLabel.MaxVisibleGraphemes = shown
			task.wait(0.012)
		end
		if typing == my then bodyLabel.MaxVisibleGraphemes = -1 end
	end)
end

local function show(i, snap)
	index = math.clamp(i, 1, #STEPS)
	local step = STEPS[index]
	pill.Text = ("STEP %d / %d"):format(index, #STEPS)
	titleLabel.Text = step.Title
	typeBody(step.Body)
	backBtn.Visible = index > 1
	nextBtn.Text = (index == #STEPS) and "PLAY ✓" or "NEXT ▶"
	nextBtn.BackgroundColor3 = (index == #STEPS) and C.green or Color3.fromRGB(96, 110, 255)
	tween(fill, 0.35, { Size = UDim2.fromScale(index / #STEPS, 1) }, Enum.EasingStyle.Quint)

	card.Position = UDim2.new(0.5, 0, 1, -6)
	tween(card, 0.3, { Position = UDim2.new(0.5, 0, 1, -26) }, Enum.EasingStyle.Back)

	if step.ShowHud then
		restoreHud()
		tween(topBar, 0.3, { Position = UDim2.fromScale(0, -0.075) })
		tween(botBar, 0.3, { Position = UDim2.fromScale(0, 1.075) })
	else
		hideHud()
		tween(topBar, 0.4, { Position = UDim2.fromScale(0, 0) })
		tween(botBar, 0.4, { Position = UDim2.fromScale(0, 1) })
	end
	gui.Enabled = true
	stepStart = os.clock()
	if snap then
		fromCF = stepCF(step, 0)
		flyTime = 0
	else
		fromCF = camera.CFrame
		flyTime = math.clamp((fromCF.Position - step.Cam).Magnitude / 450, 0.9, 1.8)
	end
end

local function stop()
	if not running or busy then return end
	busy = true
	task.spawn(function()
		loaderIn("BACK TO THE ISLAND")
		loaderProgress(0.6, 0.3)
		running = false
		gui.Enabled = false
		restoreHud()
		table.clear(hudStates)
		controls(true)
		camera.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then camera.CameraSubject = hum end
		helpBtn.Visible = true
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true) end)
		settingsRemote:FireServer("TutorialDone")
		task.wait(0.35)
		loaderOut()
		busy = false
	end)
end

local function start()
	if running or busy then return end
	busy = true
	helpBtn.Visible = false
	task.spawn(function()
		loaderIn("PREPARING YOUR TOUR")
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
		controls(false)
		hideHud()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = stepCF(STEPS[1], 0)
		running = true
		loaderProgress(0.35)

		-- warm up the sets' textures and meshes so the first shots aren't blank
		local stage = workspace:FindFirstChild("TutorialStage")
		if stage then
			local assets = {}
			for _, d in ipairs(stage:GetDescendants()) do
				if d:IsA("MeshPart") or d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") then
					table.insert(assets, d)
				end
			end
			local done = false
			task.spawn(function()
				pcall(function() ContentProvider:PreloadAsync(assets) end)
				done = true
			end)
			local t = 0
			while not done and t < 2.5 do
				t += task.wait(0.1)
				loaderProgress(0.35 + 0.55 * math.min(t / 2.5, 1), 0.1)
			end
		end
		task.wait(0.2)
		show(1, true)
		loaderOut()
		busy = false
	end)
end

local function go(delta)
	if not running or busy then return end
	local target = index + delta
	if target > #STEPS then stop() return end
	if target < 1 then return end
	show(target)
end

nextBtn.MouseButton1Click:Connect(function() go(1) end)
backBtn.MouseButton1Click:Connect(function() go(-1) end)
skipBtn.MouseButton1Click:Connect(stop)
helpBtn.MouseButton1Click:Connect(start)

UserInputService.InputBegan:Connect(function(input, processed)
	if not running or processed then return end
	if input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.Return then
		go(1)
	elseif input.KeyCode == Enum.KeyCode.Left then
		go(-1)
	end
end)

RunService.RenderStepped:Connect(function()
	if not running then return end
	camera.CameraType = Enum.CameraType.Scriptable
	local step = STEPS[index]
	local t = os.clock() - stepStart
	local target = stepCF(step, t)
	if flyTime > 0 and t < flyTime then
		local a = TweenService:GetValue(t / flyTime, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
		local dist = (fromCF.Position - target.Position).Magnitude
		local lift = math.sin(a * math.pi) * math.min(60, dist * 0.15)
		camera.CFrame = fromCF:Lerp(target, a) + Vector3.new(0, lift, 0)
	else
		camera.CFrame = target
	end
end)

task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	playerGui:WaitForChild("IntroCutscene", 4)
	repeat task.wait(0.5) until not playerGui:FindFirstChild("IntroCutscene")
	if not player.Character then player.CharacterAdded:Wait() end
	local waited = 0
	while player:GetAttribute("SettingsLoaded") ~= true and waited < 15 do
		task.wait(0.25)
		waited += 0.25
	end
	task.wait(1)
	if player:GetAttribute("Set_TutorialDone") ~= true then start() end
end)
