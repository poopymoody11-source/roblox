--==================================================
-- OPENING CUTSCENE + LOADING SCREEN   (ReplicatedFirst)
--
-- Plays while the game loads: two hyped block-streamers are deep in a
-- cave, 3 hours into a stream, when they finally break into a lapis
-- vein -> "LA PEACE!!!". Then the title screen with a PLAY button that
-- unlocks once loading hits 100%. SKIP is always available.
--==================================================

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)

local SFX = {
	cave     = { 9065315388, 0.5 },
	tink     = { 9116651251, 0.35 },
	crack    = { 9120801590, 0.9 },
	heart    = { 1836341744, 0.9 },
	boom     = { 140367458608473, 1.2 },
	laPeace  = { 97886203052070, 2 },
	horn     = { 132844961288199, 0.7 },
	cheer    = { 98246069123313, 0.8 },
	woah     = { 112820076716146, 1 },
	ding     = { 4612374807, 0.8 },
}
local LAPIS_IMAGE = "rbxassetid://79764642487535"

local C = {
	blue = Color3.fromRGB(40, 90, 255), light = Color3.fromRGB(120, 180, 255),
	gold = Color3.fromRGB(255, 215, 90), white = Color3.new(1, 1, 1), black = Color3.new(0, 0, 0),
}

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end

local function rnd(a, b) return math.random(math.floor(a), math.floor(b)) end

--------------------------------------------------
-- sounds
--------------------------------------------------
local soundFolder = new("Folder", { Name = "IntroSounds", Parent = SoundService })
local sounds = {}
for name, def in pairs(SFX) do
	sounds[name] = new("Sound", { Name = name, SoundId = "rbxassetid://" .. def[1], Volume = def[2], Parent = soundFolder })
end
local function play(name, pitch)
	local s = sounds[name]
	if not s then return end
	if pitch then
		local c = s:Clone()
		c.PlaybackSpeed = pitch
		c.Parent = soundFolder
		c:Play()
		c.Ended:Once(function() c:Destroy() end)
		return
	end
	s.TimePosition = 0
	s:Play()
end
task.spawn(function() pcall(function() ContentProvider:PreloadAsync(soundFolder:GetChildren()) end) end)

--------------------------------------------------
-- GUI shell
--------------------------------------------------
local gui = new("ScreenGui", {
	Name = "IntroCutscene", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui,
})
local bg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.black, Parent = gui })

local viewport = new("ViewportFrame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 12), Visible = false,
	Ambient = Color3.fromRGB(70, 70, 90), LightColor = Color3.fromRGB(255, 190, 130),
	LightDirection = Vector3.new(-0.4, -1, -0.6), Parent = bg,
})
local cam = new("Camera", { FieldOfView = 55, Parent = viewport })
viewport.CurrentCamera = cam

-- vignette (four soft edges)
for _, spec in ipairs({
	{ UDim2.new(1, 0, 0.25, 0), UDim2.new(0, 0, 0, 0), 90 }, { UDim2.new(1, 0, 0.25, 0), UDim2.new(0, 0, 0.75, 0), 270 },
	{ UDim2.new(0.2, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0 }, { UDim2.new(0.2, 0, 1, 0), UDim2.new(0.8, 0, 0, 0), 180 },
}) do
	local f = new("Frame", { Size = spec[1], Position = spec[2], BackgroundColor3 = C.black, BorderSizePixel = 0, Parent = viewport })
	new("UIGradient", { Rotation = spec[3], Transparency = NumberSequence.new(0.1, 1), Parent = f })
end

-- stream overlay
local liveTag = new("TextLabel", {
	Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(20, 64), BackgroundColor3 = Color3.fromRGB(220, 30, 40),
	Text = "  🔴 LIVE · 1.2M watching", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.white,
	TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Parent = bg,
}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
local timer = new("TextLabel", {
	Size = UDim2.fromOffset(180, 30), Position = UDim2.fromOffset(280, 64), BackgroundTransparency = 0.4, BackgroundColor3 = C.black,
	Text = "3:00:00", Font = Enum.Font.Code, TextSize = 16, TextColor3 = C.white, Visible = false, Parent = bg,
}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })

local chat = new("Frame", {
	Size = UDim2.new(0.24, 0, 0.62, 0), Position = UDim2.new(0.745, 0, 0.12, 0), BackgroundColor3 = C.black,
	BackgroundTransparency = 0.45, ClipsDescendants = true, Visible = false, Parent = bg,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 8) }),
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6) }),
	new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
})
local chatNames = { "blockhead77", "lapis_lover", "xXminerXx", "peacekeeper", "noobmaster", "cavegoblin", "diamondhands", "sweatyTryhard", "bobux_rich", "LA_PEACE_FAN" }
local chatColors = { Color3.fromRGB(255, 120, 120), Color3.fromRGB(120, 200, 255), Color3.fromRGB(150, 255, 150), Color3.fromRGB(255, 200, 90), Color3.fromRGB(220, 140, 255) }
local chatN = 0
local function chatLine(msg)
	chatN += 1
	local name = chatNames[math.random(#chatNames)]
	local col = chatColors[math.random(#chatColors)]
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, RichText = true, TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = chatN, Font = Enum.Font.Gotham, TextSize = 14,
		TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Left,
		Text = ('<b><font color="#%s">%s</font></b>: %s'):format(col:ToHex(), name, msg), Parent = chat,
	})
	local lines = {}
	for _, c in ipairs(chat:GetChildren()) do if c:IsA("TextLabel") then table.insert(lines, c) end end
	if #lines > 22 then lines[1]:Destroy() end
end

local caption = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.86, 0), Size = UDim2.new(0.7, 0, 0.08, 0),
	BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = C.white, Text = "", ZIndex = 4, Parent = bg,
}, { new("UIStroke", { Thickness = 3 }) })

local bigText = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.9, 0.3),
	BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = C.white, Text = "",
	TextTransparency = 1, ZIndex = 5, Parent = bg,
}, { new("UIStroke", { Thickness = 6, Color = Color3.fromRGB(10, 20, 80) }) })
local bigGrad = new("UIGradient", {
	Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.light), ColorSequenceKeypoint.new(0.5, C.white), ColorSequenceKeypoint.new(1, C.blue) }),
	Rotation = 90, Parent = bigText,
})

local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 8, Parent = bg })

-- skip + progress (always on top)
local skip = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.fromOffset(110, 38),
	BackgroundColor3 = Color3.fromRGB(30, 30, 40), BackgroundTransparency = 0.2, Text = "SKIP ⏭", Font = Enum.Font.GothamBold,
	TextSize = 16, TextColor3 = C.white, ZIndex = 20, Parent = gui,
}, { new("UICorner", { CornerRadius = UDim.new(0, 8) }), new("UIStroke", { Color = C.light, Thickness = 1.5 }) })

local barBack = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0.5, 0, 0, 10),
	BackgroundColor3 = Color3.fromRGB(25, 25, 35), ZIndex = 20, Parent = gui,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Color3.fromRGB(70, 70, 100) }) })
local barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.blue, ZIndex = 21, Parent = barBack }, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	new("UIGradient", { Color = ColorSequence.new(C.light, C.blue) }),
})
local barText = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.white, Text = "LOADING 0%", ZIndex = 21, Parent = barBack,
}, { new("UIStroke", { Thickness = 1.5 }) })

--------------------------------------------------
-- loading progress
--------------------------------------------------
local progress = 0
local loaded = false
task.spawn(function()
	if not game:IsLoaded() then
		task.spawn(function()
			while not game:IsLoaded() do
				progress = math.min(0.4, progress + 0.004)
				task.wait(0.05)
			end
		end)
		game.Loaded:Wait()
	end
	progress = math.max(progress, 0.4)
	local assets = {}
	for _, root in ipairs({ workspace, game:GetService("ReplicatedStorage"), playerGui, game:GetService("Lighting") }) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Decal") or d:IsA("Texture") or d:IsA("ImageLabel") or d:IsA("ImageButton") or d:IsA("MeshPart") or d:IsA("Sound") or d:IsA("Sky") then
				table.insert(assets, d)
			end
			if #assets >= 500 then break end
		end
	end
	local total, done = math.max(#assets, 1), 0
	local finished = false
	task.delay(30, function() finished = true end) -- never hold anyone hostage
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(assets, function()
				done += 1
				progress = math.max(progress, 0.4 + 0.59 * math.min(1, done / total))
			end)
		end)
		finished = true
	end)
	while not finished do task.wait(0.1) end
	progress = 1
	loaded = true
end)

--------------------------------------------------
-- 3D scene (ViewportFrame)
--------------------------------------------------
local function block(pos, size, color)
	return new("Part", { Anchored = true, Size = size, CFrame = CFrame.new(pos), Color = color, Material = Enum.Material.SmoothPlastic, Parent = viewport })
end

local STONE = { Color3.fromRGB(110, 110, 115), Color3.fromRGB(95, 95, 100), Color3.fromRGB(125, 125, 128), Color3.fromRGB(85, 85, 92) }
local rng = Random.new(7)
local function stone() return STONE[rng:NextInteger(1, #STONE)] end
for x = -5, 5 do
	for z = -3, 3 do
		block(Vector3.new(x * 4, -2, z * 4), Vector3.new(4, 4, 4), stone())
	end
end
local lapisBlockPos = Vector3.new(0, 6, -14)
for x = -5, 5 do
	for y = 0, 4 do
		local pos = Vector3.new(x * 4, 2 + y * 4, -14)
		if (pos - lapisBlockPos).Magnitude > 0.1 then
			block(pos, Vector3.new(4, 4, 4), stone())
			if rng:NextNumber() < 0.12 then -- coal specks
				for _ = 1, 3 do block(pos + Vector3.new(rng:NextInteger(-12, 12) / 10, rng:NextInteger(-12, 12) / 10, 2.02), Vector3.new(0.6, 0.6, 0.1), Color3.fromRGB(30, 30, 30)) end
			end
		end
	end
end
for z = -3, 3 do
	for y = 0, 4 do
		block(Vector3.new(-22, 2 + y * 4, z * 4), Vector3.new(4, 4, 4), stone())
		block(Vector3.new(22, 2 + y * 4, z * 4), Vector3.new(4, 4, 4), stone())
	end
end
for _, x in ipairs({ -12, 12 }) do
	block(Vector3.new(x, 8, -11.6), Vector3.new(0.5, 2, 0.5), Color3.fromRGB(120, 80, 40))
	block(Vector3.new(x, 9.3, -11.6), Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(255, 190, 60))
end

local oreBlock = block(lapisBlockPos, Vector3.new(4, 4, 4), STONE[2])
local specks = {}
for _ = 1, 9 do
	table.insert(specks, block(lapisBlockPos + Vector3.new(rng:NextInteger(-14, 14) / 10, rng:NextInteger(-14, 14) / 10, 2.02), Vector3.new(0.6, 0.6, 0.1), Color3.fromRGB(30, 70, 220)))
end
local lapis = block(lapisBlockPos, Vector3.new(2.2, 2.2, 2.2), Color3.fromRGB(40, 90, 255))
lapis.Transparency = 1
local lapisTrim = {}
for _, off in ipairs({ Vector3.new(0, 1.12, 0), Vector3.new(0, -1.12, 0), Vector3.new(1.12, 0, 0), Vector3.new(-1.12, 0, 0) }) do
	local t = block(lapisBlockPos + off, Vector3.new(off.X ~= 0 and 0.1 or 2.3, off.Y ~= 0 and 0.1 or 2.3, 2.3), Color3.fromRGB(180, 220, 255))
	t.Transparency = 1
	table.insert(lapisTrim, { part = t, off = off })
end

local function figure(shirt, pants, skin, hat)
	local f = { parts = {} }
	local function limb(name, size, color) f.parts[name] = block(Vector3.zero, size, color) end
	limb("head", Vector3.new(2, 2, 2), skin)
	limb("torso", Vector3.new(2, 3, 1), shirt)
	limb("larm", Vector3.new(1, 3, 1), shirt)
	limb("rarm", Vector3.new(1, 3, 1), shirt)
	limb("lleg", Vector3.new(1, 3, 1), pants)
	limb("rleg", Vector3.new(1, 3, 1), pants)
	limb("hat", Vector3.new(2.1, 0.5, 2.1), hat)
	limb("eyeL", Vector3.new(0.35, 0.35, 0.1), C.black)
	limb("eyeR", Vector3.new(0.35, 0.35, 0.1), C.black)
	limb("mouth", Vector3.new(0.8, 0.2, 0.1), Color3.fromRGB(60, 20, 20))
	limb("pickStick", Vector3.new(0.25, 3, 0.25), Color3.fromRGB(120, 80, 40))
	limb("pickHead", Vector3.new(2.4, 0.4, 0.4), Color3.fromRGB(90, 220, 230))
	f.root = CFrame.new()
	f.pose = { larm = 0, rarm = 0, lleg = 0, rleg = 0, head = 0, mouthOpen = 0, armsUp = 0 }
	function f:apply()
		local r, p, P = self.root, self.pose, self.parts
		P.torso.CFrame = r
		P.head.CFrame = r * CFrame.new(0, 2.5, 0) * CFrame.Angles(p.head, 0, 0)
		P.hat.CFrame = P.head.CFrame * CFrame.new(0, 1.2, 0)
		P.eyeL.CFrame = P.head.CFrame * CFrame.new(-0.45, 0.2, -1.01)
		P.eyeR.CFrame = P.head.CFrame * CFrame.new(0.45, 0.2, -1.01)
		P.mouth.Size = Vector3.new(0.8, 0.2 + p.mouthOpen * 0.6, 0.1)
		P.mouth.CFrame = P.head.CFrame * CFrame.new(0, -0.45 - p.mouthOpen * 0.2, -1.01)
		local function arm(ang, sideSign)
			return r * CFrame.new(1.5 * sideSign, 1.5, 0) * CFrame.Angles(ang, 0, sideSign * p.armsUp * 0.35) * CFrame.new(0, -1.5, 0)
		end
		P.larm.CFrame = arm(p.larm + p.armsUp * math.pi, -1)
		P.rarm.CFrame = arm(p.rarm + p.armsUp * math.pi, 1)
		P.lleg.CFrame = r * CFrame.new(-0.5, -1.5, 0) * CFrame.Angles(p.lleg, 0, 0) * CFrame.new(0, -1.5, 0)
		P.rleg.CFrame = r * CFrame.new(0.5, -1.5, 0) * CFrame.Angles(p.rleg, 0, 0) * CFrame.new(0, -1.5, 0)
		local hand = P.rarm.CFrame * CFrame.new(0, -1.4, 0)
		P.pickStick.CFrame = hand * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, 1, 0)
		P.pickHead.CFrame = P.pickStick.CFrame * CFrame.new(0, 1.4, 0)
		local showPick = p.armsUp < 0.5
		P.pickStick.Transparency = showPick and 0 or 1
		P.pickHead.Transparency = showPick and 0 or 1
	end
	return f
end

local A = figure(Color3.fromRGB(230, 90, 30), Color3.fromRGB(40, 40, 50), Color3.fromRGB(150, 100, 70), Color3.fromRGB(20, 20, 20))
local B = figure(Color3.fromRGB(40, 110, 230), Color3.fromRGB(230, 230, 235), Color3.fromRGB(110, 70, 45), Color3.fromRGB(230, 40, 40))
local groundY = 4.5
local homeA = Vector3.new(-3.2, groundY, -9.5)
local homeB = Vector3.new(3.2, groundY, -9.5)

local confetti = {}
local function spawnConfetti(n)
	for _ = 1, n do
		local f = new("Frame", {
			Size = UDim2.fromOffset(rnd(6, 14), rnd(6, 14)), Position = UDim2.fromScale(math.random(), -0.05),
			BackgroundColor3 = (math.random() < 0.7) and C.blue or ((math.random() < 0.5) and C.light or C.gold), BorderSizePixel = 0,
			Rotation = rnd(0, 360), ZIndex = 6, Parent = bg,
		})
		table.insert(confetti, { f = f, vy = rnd(25, 55) / 100, vx = rnd(-10, 10) / 100, vr = rnd(-300, 300) })
	end
end

--------------------------------------------------
-- title screen
--------------------------------------------------
local title = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 10, 30), Visible = false, ZIndex = 10, Parent = gui })
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(20, 40, 120), Color3.fromRGB(4, 6, 20)), Parent = title })
-- light rays behind the portrait
local rays = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(1.2, 1.2),
	SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundTransparency = 1, ZIndex = 11, Parent = title,
})
for i = 0, 11 do
	local ray = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0.05, 0),
		Rotation = i * 15, BackgroundColor3 = C.light, BorderSizePixel = 0, ZIndex = 11, Parent = rays,
	})
	new("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.75), NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.65, 0.75), NumberSequenceKeypoint.new(1, 1) }), Parent = ray })
end
local glow = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.5, 0.5),
	SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundColor3 = C.light, BackgroundTransparency = 0.6, ZIndex = 11, Parent = title,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
new("UIGradient", { Transparency = NumberSequence.new(0.2, 1), Rotation = 90, Parent = glow })
local star = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.34, 0.34),
	SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundTransparency = 1, Image = LAPIS_IMAGE, ZIndex = 12, Parent = title,
}, { new("UICorner", { CornerRadius = UDim.new(0.12, 0) }), new("UIStroke", { Thickness = 4, Color = C.light }) })
local titleText = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromScale(0.8, 0.14),
	BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true, Text = "BECOME LA PEACE", TextColor3 = C.white, ZIndex = 13, Parent = title,
}, { new("UIStroke", { Thickness = 5, Color = Color3.fromRGB(10, 20, 80) }) })
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.white, C.light), Parent = titleText })
local playBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.22, 0.09),
	BackgroundColor3 = Color3.fromRGB(60, 60, 80), Text = "LOADING…", Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = C.white, AutoButtonColor = false, ZIndex = 13, Parent = title,
}, {
	new("UICorner", { CornerRadius = UDim.new(0.25, 0) }), new("UIStroke", { Thickness = 3, Color = C.white, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	new("UIPadding", { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) }),
})

--------------------------------------------------
-- hide the rest of the game while this plays
--------------------------------------------------
local done = false
local pausedMusic = {}
local function muteGame()
	for _, s in ipairs(SoundService:GetDescendants()) do
		if s:IsA("Sound") and not s:IsDescendantOf(soundFolder) and s.Volume > 0 and pausedMusic[s] == nil then
			pausedMusic[s] = s.Volume
			s.Volume = 0
		end
	end
end
local function unmuteGame()
	for s, v in pairs(pausedMusic) do if s.Parent then s.Volume = v end end
	table.clear(pausedMusic)
end
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
task.spawn(function()
	while not done do
		muteGame()
		task.wait(0.3)
	end
end)

--------------------------------------------------
-- timeline
--------------------------------------------------
local phase = "intro"
local t0 = os.clock()
local fired = {}
local function once(key, at, t, fn)
	if not fired[key] and t >= at then fired[key] = true fn() end
end
local shake = 0

local function say(text, color)
	caption.Text = text
	caption.TextColor3 = color or C.white
	caption.Size = UDim2.new(0.62, 0, 0.07, 0)
	TweenService:Create(caption, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.new(0.7, 0, 0.08, 0) }):Play()
end

local function typewriter(text)
	caption.TextColor3 = Color3.fromRGB(200, 200, 220)
	task.spawn(function()
		for i = 1, #text do
			if phase ~= "intro" or fired.scene then return end
			caption.Text = text:sub(1, i)
			task.wait(0.045)
		end
	end)
end

local function showTitle()
	if phase ~= "intro" then return end
	phase = "title"
	for _, s in ipairs(soundFolder:GetChildren()) do if s.Name ~= "cheer" and s.Name ~= "laPeace" then s:Stop() end end
	skip.Visible = false
	title.Visible = true
	star.Size = UDim2.fromScale(0.05, 0.05)
	TweenService:Create(star, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.34, 0.34) }):Play()
	titleText.Size = UDim2.fromScale(1.6, 0.3)
	titleText.TextTransparency = 1
	TweenService:Create(titleText, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(0.8, 0.14), TextTransparency = 0 }):Play()
	task.delay(0.35, function() play("boom") shake = 0.4 end)
	play("ding")
end
skip.MouseButton1Click:Connect(showTitle)

local function finish()
	if phase == "done" then return end
	phase = "done"
	play("ding")
	local fade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 30, Parent = gui })
	TweenService:Create(fade, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
	task.wait(0.3)
	done = true
	title.Visible = false
	bg.Visible = false
	barBack.Visible = false
	unmuteGame()
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
	-- the core scripts sometimes finish loading after this and come up
	-- with the hotbar off; make sure it's back
	task.spawn(function()
		for _ = 1, 6 do
			task.wait(0.5)
			pcall(function()
				if not playerGui:FindFirstChild("Tutorial") or not playerGui.Tutorial.Enabled then
					StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
				end
			end)
		end
	end)
	local tw = TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 })
	tw:Play()
	tw.Completed:Wait()
	gui:Destroy()
	task.delay(3, function() soundFolder:Destroy() end)
end
playBtn.MouseButton1Click:Connect(function()
	if loaded then finish() end
end)

local chatIdle = { "W stream", "bro is NOT finding it 💀", "3 HOURS 😭", "just go home", "keep mining", "ratio", "chat is he cooked", "any lapis yet??", "L luck", "bro mining like a grandma", "🙏🙏", "one more block" }
local chatHype = { "LA PEACE 🔥🔥🔥", "NO WAYYYY", "LAAA PEEACE", "💎💎💎", "HE DID IT", "W W W W W", "CLIP IT", "LA PEACE LA PEACE", "BRO SCREAMED 😭", "GOATED", "🔵🔵🔵", "HISTORY" }
local chatSus = { "????", "WAIT", "IS THAT LAPIS", "NAHHH", "chat...", "BRO" }
local nextChat = 0

RunService.RenderStepped:Connect(function(dt)
	if phase == "done" then return end
	barFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	barText.Text = loaded and "LOADED ✓" or ("LOADING " .. math.floor(progress * 100) .. "%")

	for i = #confetti, 1, -1 do
		local c = confetti[i]
		local p = c.f.Position
		c.f.Position = UDim2.fromScale(p.X.Scale + c.vx * dt, p.Y.Scale + c.vy * dt)
		c.f.Rotation += c.vr * dt
		if p.Y.Scale > 1.1 then c.f:Destroy() table.remove(confetti, i) end
	end

	local jitter = Vector2.zero
	if shake > 0 then
		shake = math.max(0, shake - dt)
		local m = math.max(1, math.floor(shake * 40))
		jitter = Vector2.new(rnd(-m, m), rnd(-m, m))
	end
	bg.Position = UDim2.fromOffset(jitter.X, jitter.Y)
	title.Position = UDim2.fromOffset(jitter.X, jitter.Y)

	if phase == "title" then
		local tt = os.clock()
		star.Rotation = math.sin(tt * 1.5) * 8
		rays.Rotation = (tt * 12) % 360
		if loaded then
			playBtn.Text = "PLAY"
			playBtn.BackgroundColor3 = Color3.fromRGB(40, 170, 90)
			playBtn.AutoButtonColor = true
			local s = 1 + math.sin(tt * 4) * 0.04
			playBtn.Size = UDim2.fromScale(0.22 * s, 0.09 * s)
		else
			playBtn.Text = "LOADING " .. math.floor(progress * 100) .. "%"
		end
		return
	end

	local t = os.clock() - t0

	once("type", 0.4, t, function()
		play("cave")
		typewriter("3 hours into the stream...")
	end)

	once("scene", 2.6, t, function()
		viewport.Visible = true
		liveTag.Visible, timer.Visible, chat.Visible = true, true, true
		caption.Text = ""
		for _ = 1, 8 do chatLine(chatIdle[math.random(#chatIdle)]) end
	end)
	once("s1", 3.1, t, function() say("chat we are NOT leaving till we find it", Color3.fromRGB(255, 170, 110)) end)
	once("s2", 4.7, t, function() say("bro my hands hurt 😭😭", Color3.fromRGB(140, 190, 255)) end)
	once("s3", 6.0, t, function() say("one more block. ONE MORE.", Color3.fromRGB(255, 170, 110)) end)

	local mining = t >= 2.6 and t < 7.2
	local reveal = t >= 7.2
	local hype = t >= 9.6

	if t >= 2.6 then
		timer.Text = ("3:%02d:%02d"):format(math.floor(t / 60) % 60, math.floor(t) % 60)
	end

	if t < 7.2 then
		local k = math.clamp((t - 2.6) / 4.6, 0, 1)
		cam.CFrame = CFrame.lookAt(Vector3.new(-6 + k * 4, 8.5 - k * 1.2, 6 - k * 3), Vector3.new(0, 5.5, -12))
	elseif t < 9.6 then
		local k = TweenService:GetValue(math.clamp((t - 7.2) / 2.2, 0, 1), Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		local from = Vector3.new(-2, 7.3, 3)
		local to = lapisBlockPos + Vector3.new(0.5, 0.4, 7.5)
		cam.CFrame = CFrame.lookAt(from:Lerp(to, k), Vector3.new(0, 5.5, -12):Lerp(lapisBlockPos + Vector3.new(0, 0, 2), k))
	else
		local k = math.clamp((t - 9.6) / 0.35, 0, 1)
		local swing = math.sin(t * 1.3) * 3
		cam.CFrame = CFrame.lookAt(Vector3.new(swing, 7 - k, 9 - k * 2), Vector3.new(0, 5.5, -10))
	end

	for i, f in ipairs({ A, B }) do
		local home = (i == 1) and homeA or homeB
		local faceWall = CFrame.new(home) * CFrame.Angles(0, (i == 1) and -0.25 or 0.25, 0)
		local p = f.pose
		if mining then
			local sw = math.sin(t * 13 + i * 1.7)
			p.rarm = -1.2 + sw * 1.0
			p.larm = -0.3
			p.lleg, p.rleg, p.head, p.armsUp, p.mouthOpen = 0, 0, 0.1, 0, 0
			f.root = faceWall
		elseif reveal and not hype then
			local k = math.clamp((t - 8.2) / 0.6, 0, 1)
			p.rarm = -0.4
			p.larm = 0
			p.mouthOpen = k * 0.6
			p.head = 0.15
			f.root = faceWall * CFrame.Angles(0, ((i == 1) and -0.9 or 0.9) * k, 0)
		elseif hype then
			local jump = math.abs(math.sin(t * 9 + i)) * 2.2
			p.armsUp = 1
			p.mouthOpen = 1
			p.lleg = math.sin(t * 18 + i) * 0.5
			p.rleg = -p.lleg
			p.head = -0.3
			f.root = CFrame.new(home + Vector3.new(0, jump, 2)) * CFrame.Angles(0, math.pi + ((i == 1) and 0.35 or -0.35), math.sin(t * 20 + i) * 0.1)
		else
			f.root = faceWall
		end
		f:apply()
	end

	if mining then
		local beat = math.floor(t * 13 / math.pi)
		once("tink" .. beat, 0, t, function() play("tink", 0.9 + math.random() * 0.3) end)
	end

	once("break", 7.2, t, function()
		play("crack")
		oreBlock.Transparency = 1
		for _, s in ipairs(specks) do s.Transparency = 1 end
		lapis.Transparency = 0
		for _, tr in ipairs(lapisTrim) do tr.part.Transparency = 0 end
		sounds.cave:Stop()
		caption.Text = ""
	end)
	once("heart", 7.6, t, function() play("heart") end)
	once("w1", 8.1, t, function() say("...wait.", Color3.fromRGB(140, 190, 255)) end)
	once("w2", 8.9, t, function() say("WAIT WAIT WAIT WAIT", Color3.fromRGB(255, 170, 110)) end)

	if reveal then
		local bob = math.sin(t * 3) * 0.25
		local popped = TweenService:GetValue(math.clamp((t - 7.2) / 0.6, 0, 1), Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local cf = CFrame.new(lapisBlockPos + Vector3.new(0, bob, popped * 2.5)) * CFrame.Angles(t * 0.8, t * 1.6, 0)
		lapis.CFrame = cf
		for _, tr in ipairs(lapisTrim) do tr.part.CFrame = cf * CFrame.new(tr.off) end
		local pulse = (math.sin(t * 6) + 1) / 2
		lapis.Color = Color3.fromRGB(40, 90, 255):Lerp(Color3.fromRGB(140, 200, 255), pulse * 0.6)
		viewport.Ambient = Color3.fromRGB(70, 70, 90):Lerp(Color3.fromRGB(80, 110, 200), math.clamp(popped, 0, 1))
	end

	once("peace", 9.6, t, function()
		sounds.heart:Stop()
		play("boom")
		play("laPeace")
		play("horn")
		play("cheer")
		play("woah")
		shake = 1.1
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		caption.Text = ""
		bigText.Text = "LA PEACE!!!"
		bigText.TextTransparency = 0
		bigText.Size = UDim2.fromScale(2, 0.7)
		TweenService:Create(bigText, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.9, 0.3) }):Play()
		spawnConfetti(90)
	end)
	if hype then
		bigText.Rotation = math.sin(t * 25) * 4
		bigGrad.Offset = Vector2.new(0, math.sin(t * 8) * 0.3)
	end
	once("again", 10.8, t, function() play("horn") shake = 0.6 spawnConfetti(50) end)

	if t >= 2.6 and os.clock() >= nextChat then
		if hype then
			nextChat = os.clock() + 0.06
			chatLine(chatHype[math.random(#chatHype)])
		elseif reveal then
			nextChat = os.clock() + 0.35
			chatLine(chatSus[math.random(#chatSus)])
		else
			nextChat = os.clock() + 0.7 + math.random() * 0.6
			chatLine(chatIdle[math.random(#chatIdle)])
		end
	end

	once("toTitle", 12.6, t, showTitle)
end)
