local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local Debris = game:GetService("Debris") -- NEW: Added Debris service

local Lighting = game:GetService("Lighting")
local white = Lighting:WaitForChild("whiteframe")
local purple = Lighting:WaitForChild("purpleframe")
local black = Lighting:WaitForChild("blackframe")

local Dungeon = workspace:WaitForChild("Dungeon")
local Cutscene = Dungeon:WaitForChild("Cutscene")
local speedy = Cutscene:WaitForChild("IShowSpeed")
local torso = speedy:WaitForChild("LowerTorso")
local humanoid = speedy:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

local npcs = Cutscene:WaitForChild("NPCs")
local BEAM = Cutscene:WaitForChild("UltimateBeam")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local projectileAsset = ReplicatedStorage:WaitForChild("Purple")

local triggerPart = script.Parent
local cutsceneCamPart = Cutscene:WaitForChild("CutsceneCameraPart")
local cutsceneCamPart2 = Cutscene:WaitForChild("CutsceneCameraPart2")
local goodcutsceneCamPart = Cutscene:WaitForChild("GoodCutscenePart")
local goodCutsceneCamPart2 = Cutscene:WaitForChild("GoodCutscenePart2")
local goodCutsceneCamPart3 = Cutscene:WaitForChild("GoodCutscenePart3")
local camera = workspace.CurrentCamera

local characterLocation = Cutscene:WaitForChild("CharacterLocation")
--local character = localPlayer:WaitForChild("Character")
--local characterRoot = character:WaitForChild("HumanoidRootPart")

local hasPlayed = false

local holdAnim = Instance.new("Animation")
holdAnim.AnimationId = "rbxassetid://139209711419916"
local holdTrack = animator:LoadAnimation(holdAnim)
local gettinghitAnim = Instance.new("Animation")
gettinghitAnim.AnimationId = "rbxassetid://97968542662768"
local gettinghitTrack = animator:LoadAnimation(gettinghitAnim)

local playerStats = localPlayer:WaitForChild("PlayerStats")
local claimedQuests = playerStats:WaitForChild("ClaimedQuests")


local LETTER_DELAY = 0.05
local function typeOut(label, fullText, delay)
	label.Text = ""
	for i = 1, #fullText do
		label.Text = string.sub(fullText, 1, i)
		task.wait(delay)
	end
end



--==================================================
-- GOOD ENDING (every quest done)  -- revamped
--
-- Same order of events as before:
--   1. Evil Speed: "You shouldn't be here."
--   2. he charges the purple blast and fires it at you
--   3. time freezes the blast mid-air
--   4. the gang drops in: "Not on my watch."
--   5. the ultimate beam; Speed: "NOOOO!"; he blows apart
-- ...and then, new:
--   6. silence. The room shakes. A purple portal tears open behind
--      True Lapeace, the Anti-Spiral hand reaches through, grabs it
--      (and every lapis circling it) and drags it into the dark.
--   7. the end card.
--
-- Letterboxed, spring-smoothed camera, subtitles, impact frames.
-- If you die at any point, it stops and gives the camera back.
--==================================================

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local GFONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local WHITE3 = Color3.new(1, 1, 1)
local BLACK3 = Color3.new(0, 0, 0)
local VIOLET = Color3.fromRGB(150, 60, 255)
local MAGENTA = Color3.fromRGB(255, 60, 200)
local ABYSS = Color3.fromRGB(12, 0, 22)
local SPARKTEX = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKETEX = "rbxasset://textures/particles/smoke_main.dds"

local function inst(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end
local function tw(o, t, goal, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	x:Play()
	return x
end

local onGoodEndingOver = nil -- set further down (retry / restore True Lapeace)
local tlRestore = nil -- puts True Lapeace back if the scene is cut short
local handRestore = nil -- puts the Anti-Spiral hand back if the scene is cut short
local ceilingRestore = nil -- puts the ceiling back

-- The ceiling is one big slab, so to punch a hole in it (on this client
-- only) it's hidden and rebuilt as four slabs round an opening, plus a
-- patch that fills the opening until the moment it breaks.
local function findCeiling()
	local main = Dungeon:FindFirstChild("Main")
	local best
	for _, p in ipairs(main and main:GetChildren() or {}) do
		if p:IsA("BasePart") and p.Material == Enum.Material.Wood and p.Size.X > 60 and p.Size.Z > 60 then best = p end
	end
	return best
end

local function prepCeiling(centre, holeSize)
	local ceil = findCeiling()
	if not ceil then return nil end
	local c, sz = ceil.Position, ceil.Size
	local x0, x1 = c.X - sz.X / 2, c.X + sz.X / 2
	local z0, z1 = c.Z - sz.Z / 2, c.Z + sz.Z / 2
	local hx0, hx1 = centre.X - holeSize / 2, centre.X + holeSize / 2
	local hz0, hz1 = centre.Z - holeSize / 2, centre.Z + holeSize / 2
	local folder = Instance.new("Folder")
	folder.Name = "CeilingPieces"
	folder.Parent = workspace
	local function slab(ax0, ax1, az0, az1, name)
		if ax1 - ax0 < 0.05 or az1 - az0 < 0.05 then return nil end
		local p = ceil:Clone()
		p:ClearAllChildren()
		for _, ch in ipairs(ceil:GetChildren()) do
			if ch:IsA("Texture") or ch:IsA("Decal") or ch:IsA("SurfaceAppearance") then ch:Clone().Parent = p end
		end
		p.Name = name or "Slab"
		p.Size = Vector3.new(ax1 - ax0, sz.Y, az1 - az0)
		p.CFrame = CFrame.new((ax0 + ax1) / 2, c.Y, (az0 + az1) / 2)
		p.Parent = folder
		return p
	end
	slab(x0, hx0, z0, z1)
	slab(hx1, x1, z0, z1)
	slab(hx0, hx1, z0, hz0)
	slab(hx0, hx1, hz1, z1)
	local patch = slab(hx0, hx1, hz0, hz1, "Patch")
	local oldT = ceil.Transparency
	ceil.Transparency = 1
	ceilingRestore = function()
		if ceil.Parent then ceil.Transparency = oldT end
		folder:Destroy()
		ceilingRestore = nil
	end
	return { patch = patch, folder = folder, y = c.Y - sz.Y / 2, top = c.Y + sz.Y / 2, hole = holeSize, centre = Vector3.new(centre.X, c.Y, centre.Z), ceil = ceil }
end

local badVanish = nil
--==================================================
-- SCORE, OTHER PLAYERS, GAME MUSIC (shared by both endings)
--==================================================
-- licensed (APM) tracks, so they play in every server
local SCORE = {
	Standoff = "rbxassetid://1835248722", -- Stalking the Prey: low drums, threatening brass
	Heroes   = "rbxassetid://1848107874", -- Fight For A Tomorrow
	Dread    = "rbxassetid://1848159364", -- Darkness On The Edge Of Time
	Doom     = "rbxassetid://1838626086", -- Hell Ride: you're about to get obliterated
}

local scoreSound = nil
local function playScore(id, vol, fadeIn, startAt)
	local old = scoreSound
	if old then
		TweenService:Create(old, TweenInfo.new(0.8), { Volume = 0 }):Play()
		task.delay(0.9, function() old:Destroy() end)
	end
	if not id then scoreSound = nil return end
	local s = Instance.new("Sound")
	s.Name = "DungeonScore"
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.TimePosition = startAt or 0
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(fadeIn or 1), { Volume = vol or 0.5 }):Play()
	scoreSound = s
end
local function stopScore(fade)
	local s = scoreSound
	scoreSound = nil
	if s then
		TweenService:Create(s, TweenInfo.new(fade or 1), { Volume = 0 }):Play()
		task.delay((fade or 1) + 0.1, function() s:Destroy() end)
	end
end

-- the game's own background music (phonk) sits out the cutscene
local pausedMusic = {}
local function pauseGameMusic()
	-- the music controller (StarterPlayerScripts.music) now holds the song
	-- itself during any cutscene, so there's nothing to do here
	if true then return end
	local folder = SoundService:FindFirstChild("Music")
	for _, s in ipairs(folder and folder:GetDescendants() or {}) do
		if s:IsA("Sound") and s.IsPlaying then
			table.insert(pausedMusic, s)
			s:Pause()
		end
	end
end
local function resumeGameMusic()
	for _, s in ipairs(pausedMusic) do
		if s.Parent then s:Resume() end
	end
	table.clear(pausedMusic)
end

-- other players vanish (on this screen only) while the cutscene runs
local hideState = nil
local HIDE_FX = { ParticleEmitter = true, Trail = true, Beam = true, BillboardGui = true, PointLight = true, SpotLight = true, SurfaceLight = true, Highlight = true, Fire = true, Smoke = true, Sparkles = true }
local function applyHide()
	if not hideState then return end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= localPlayer and pl.Character then
			for _, d in ipairs(pl.Character:GetDescendants()) do
				if d:IsA("BasePart") or d:IsA("Decal") then
					d.LocalTransparencyModifier = 1
				elseif HIDE_FX[d.ClassName] and not hideState.saved[d] then
					local ok, en = pcall(function() return d.Enabled end)
					if ok and en then
						hideState.saved[d] = true
						d.Enabled = false
					end
				end
			end
		end
	end
end
local function hideOthers(on)
	if on then
		if hideState then return end
		hideState = { saved = {}, t = 0 }
		applyHide()
		hideState.conn = RunService.Heartbeat:Connect(function(dt)
			if not hideState then return end
			hideState.t += dt
			if hideState.t > 0.4 then
				hideState.t = 0
				applyHide()
			end
		end)
	else
		local st = hideState
		hideState = nil
		if not st then return end
		if st.conn then st.conn:Disconnect() end
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= localPlayer and pl.Character then
				for _, d in ipairs(pl.Character:GetDescendants()) do
					if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end
				end
			end
		end
		for d in pairs(st.saved) do
			if d.Parent then pcall(function() d.Enabled = true end) end
		end
	end
end

local function runGoodEnding(character, characterRoot, mode)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local myHum = character:FindFirstChildOfClass("Humanoid")
	local made = {}      -- instances to clean up
	local sounds = {}
	local function keep(o) table.insert(made, o) return o end

	-- ---------- overlay ----------
	local gui = keep(inst("ScreenGui", { Name = "DungeonCinematic", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 90, Parent = playerGui }))
	local topBar = inst("Frame", { Size = UDim2.fromScale(1, 0), BackgroundColor3 = BLACK3, BorderSizePixel = 0, ZIndex = 10, Parent = gui })
	local botBar = inst("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = BLACK3, BorderSizePixel = 0, ZIndex = 10, Parent = gui })
	local flash = inst("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE3, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 30, Parent = gui })
	local fade = inst("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK3, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 40, Parent = gui })
	local vign = inst("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "rbxasset://textures/ui/Vignette.png", ImageColor3 = VIOLET, ImageTransparency = 1, ZIndex = 5, Parent = gui })
	local subFrame = inst("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.965), Size = UDim2.fromScale(0.75, 0.075), BackgroundTransparency = 1, ZIndex = 20, Parent = gui })
	local subName = inst("TextLabel", { Size = UDim2.fromScale(1, 0.38), BackgroundTransparency = 1, FontFace = GFONT, TextScaled = true, Text = "", TextColor3 = WHITE3, TextTransparency = 1, ZIndex = 20, Parent = subFrame },
	{ inst("UIStroke", { Thickness = 1.5, Transparency = 1 }) })
	local subLine = inst("TextLabel", { Position = UDim2.fromScale(0, 0.4), Size = UDim2.fromScale(1, 0.6), BackgroundTransparency = 1, FontFace = GFONT, TextScaled = true, Text = "", TextColor3 = WHITE3, TextTransparency = 1, ZIndex = 20, Parent = subFrame },
	{ inst("UITextSizeConstraint", { MaxTextSize = 32 }), inst("UIStroke", { Thickness = 2, Transparency = 1 }) })
	local function letterbox(on, t)
		tw(topBar, t or 0.6, { Size = UDim2.fromScale(1, on and 0.1 or 0) }, Enum.EasingStyle.Quart)
		tw(botBar, t or 0.6, { Size = UDim2.fromScale(1, on and 0.1 or 0) }, Enum.EasingStyle.Quart)
	end
	local typingId = 0
	local function say(name, colour, text, hold)
		typingId += 1
		local my = typingId
		subName.Text, subName.TextColor3 = name, colour
		subName.TextTransparency, subLine.TextTransparency = 0, 0
		subName.UIStroke.Transparency, subLine.UIStroke.Transparency = 0, 0
		subLine.MaxVisibleGraphemes = 0
		subLine.Text = text
		for i = 1, #text do
			if typingId ~= my then return end
			subLine.MaxVisibleGraphemes = i
			task.wait(0.028)
		end
		task.delay(hold or 1.5, function()
			if typingId ~= my then return end
			for _, l in ipairs({ subName, subLine }) do
				tw(l, 0.35, { TextTransparency = 1 })
				tw(l.UIStroke, 0.3, { Transparency = 1 })
			end
		end)
	end
	local function flashTo(colour, out)
		flash.BackgroundColor3 = colour
		flash.BackgroundTransparency = 0
		tw(flash, out or 0.5, { BackgroundTransparency = 1 })
	end
	local function sfx(id, vol, speed, parent)
		local snd = inst("Sound", { SoundId = id, Volume = vol or 0.7, PlaybackSpeed = speed or 1, Parent = parent or SoundService })
		table.insert(sounds, snd)
		if parent then snd:Play() else SoundService:PlayLocalSound(snd) end
		return snd
	end

	-- ---------- post fx ----------
	local cc = keep(inst("ColorCorrectionEffect", { Name = "DungeonCC", Parent = Lighting }))
	local blur = keep(inst("BlurEffect", { Name = "DungeonBlur", Size = 0, Parent = Lighting }))

	-- ---------- camera ----------
	local camCF, camFov = camera.CFrame, camera.FieldOfView
	local shakeAmp, shakeUntil = 0, 0
	local function shake(a, d) shakeAmp, shakeUntil = a, os.clock() + (d or 0.5) end
	local function drive(target, fov, dt, stiff)
		local k = 1 - math.exp(-(stiff or 8) * dt)
		camCF = camCF:Lerp(target, k)
		camFov += ((fov or camFov) - camFov) * k
		local out = camCF
		if os.clock() < shakeUntil then
			local s = shakeAmp * ((shakeUntil - os.clock()) / 0.5)
			out = out * CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0) * CFrame.Angles(0, 0, math.rad((math.random() - 0.5) * s * 2))
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = out
		camera.FieldOfView = math.clamp(camFov, 15, 110)
	end
	local function cut(cf, fov) camCF = cf camFov = fov or camFov end
	local function over(d, fn)
		local t0 = os.clock()
		while true do
			local dt = RunService.RenderStepped:Wait()
			local a = math.clamp((os.clock() - t0) / d, 0, 1)
			if fn(dt, a) == false or a >= 1 then break end
		end
	end
	local function hold(d, target, fov, stiff)
		over(d, function(dt) drive(target, fov, dt, stiff) end)
	end

	-- ---------- impact frames ----------
	local function impact(models, pattern)
		local card = keep(inst("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Size = Vector3.new(80, 80, 0.05), Parent = workspace }))
		local hls = {}
		for _, m in ipairs(models) do
			if m and m.Parent then table.insert(hls, inst("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, FillTransparency = 0, OutlineTransparency = 0, Adornee = m, Parent = card })) end
		end
		for _, f in ipairs(pattern) do
			card.CFrame = camera.CFrame * CFrame.new(0, 0, -1.5)
			card.Color = f[1]
			for _, h in ipairs(hls) do h.FillColor = f[2] h.OutlineColor = f[3] or f[2] end
			task.wait(f[4] or 0.05)
		end
		card:Destroy()
	end
	local IMPACT = { { WHITE3, BLACK3, BLACK3, 0.06 }, { BLACK3, WHITE3, VIOLET, 0.06 }, { WHITE3, BLACK3, BLACK3, 0.05 } }
	local IMPACT_P = { { BLACK3, VIOLET, WHITE3, 0.06 }, { WHITE3, BLACK3, BLACK3, 0.06 }, { VIOLET, BLACK3, WHITE3, 0.05 }, { BLACK3, WHITE3, MAGENTA, 0.05 } }

	-- ---------- world fx ----------
	local fxFolder = keep(inst("Folder", { Name = "DungeonCinematicFX", Parent = workspace }))
	local function part(props)
		local p = inst("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth })
		for k, v in pairs(props) do p[k] = v end
		p.Parent = fxFolder
		return p
	end
	local function bolt(a, b, colour, life)
		local prev, segs = a, {}
		for i = 1, 6 do
			local p = a:Lerp(b, i / 6)
			if i < 6 then p += Vector3.new((math.random() - 0.5) * 3, (math.random() - 0.5) * 3, (math.random() - 0.5) * 3) end
			table.insert(segs, part({ Size = Vector3.new(0.25, 0.25, (p - prev).Magnitude), CFrame = CFrame.lookAt((prev + p) / 2, p), Color = colour }))
			prev = p
		end
		task.delay(life or 0.08, function() for _, s in ipairs(segs) do s:Destroy() end end)
	end

	-- ---------- places ----------
	local speedRoot = speedy:WaitForChild("HumanoidRootPart")
	local speedHead = speedy:FindFirstChild("Head") or speedRoot
	local trueLapeace = Dungeon:FindFirstChild("True Lapeace")
	local tlPart = trueLapeace and trueLapeace:FindFirstChild("model")
	local tlPos = tlPart and tlPart.Position or Vector3.new(205.8, -218.2, 1340.1)
	local hand = Dungeon:FindFirstChild("AntiSpiralHand")
	if trueLapeace then
		local tlHome = trueLapeace:GetPivot()
		tlRestore = function() trueLapeace:SetAttribute("Grabbed", nil) if trueLapeace.Parent then trueLapeace:PivotTo(tlHome) end end
	end
	local handHome = hand and hand.CFrame
	local handSize = hand and hand.Size
	if hand then
		handRestore = function()
			if hand.Parent then hand.CFrame = handHome hand.Size = handSize end
		end
	end
	local playerPos = characterLocation.Position + Vector3.new(0, 3, 0)
	local toSpeed = (Vector3.new(speedRoot.Position.X, playerPos.Y, speedRoot.Position.Z) - playerPos).Unit
	local roomSide = toSpeed:Cross(Vector3.yAxis)

	-- ---------- start ----------
	localPlayer:SetAttribute("HideHud_Dungeon", true)
	camera.CameraType = Enum.CameraType.Scriptable
	characterRoot.CFrame = characterLocation.CFrame
	characterRoot.Anchored = true
	letterbox(true, 0.8)
	-- the good ending gets a faint desaturated "cinematic" grade; the bad
	-- ending keeps normal color (no black-and-white look at all)
	if mode == "bad" then
		cc.Contrast, cc.TintColor = 0.1, Color3.fromRGB(225, 225, 245)
	else
		cc.Saturation, cc.Contrast, cc.TintColor = -0.15, 0.1, Color3.fromRGB(225, 225, 245)
	end
	local drone = sfx("rbxassetid://9112795463", 0.35, 0.7, gui)
	drone.Looped = true
	pauseGameMusic()
	hideOthers(true)
	playScore(SCORE.Standoff, 0.45, 2)

	-- 1. THE STANDOFF: over your shoulder, dolly in on him
	cut(camera.CFrame, camera.FieldOfView)
	local shoulder = playerPos - toSpeed * 7 + roomSide * 3 + Vector3.new(0, 2.5, 0)
	over(2.2, function(dt, a)
		drive(CFrame.lookAt(shoulder, speedHead.Position), 60 - a * 12, dt, 4)
	end)
	task.spawn(say, "EVIL SPEED", Color3.fromRGB(255, 60, 60), "You shouldn't be here.", 1.6)
	local faceEye = speedHead.Position - toSpeed * -1 * 0 + (playerPos - speedHead.Position).Unit * 16 + Vector3.new(0, 1, 0)
	over(2.6, function(dt, a)
		local e = a * a * (3 - 2 * a)
		drive(CFrame.lookAt(faceEye:Lerp(speedHead.Position + (playerPos - speedHead.Position).Unit * 10, e), speedHead.Position), 45 - e * 10, dt, 3)
	end)

	-- 2. THE CHARGE: low orbit round his hand as the purple gathers
	holdTrack:Play()
	local handPart = speedy:FindFirstChild("RightHand")
	for _, item in ipairs(handPart and handPart:GetDescendants() or {}) do
		if item:IsA("ParticleEmitter") then item.Enabled = true item:Emit(5) end
	end
	local orb = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = VIOLET, CFrame = handPart and handPart.CFrame or speedRoot.CFrame })
	local orbShell = part({ Shape = Enum.PartType.Ball, Size = Vector3.one, Color = MAGENTA, Material = Enum.Material.ForceField, CFrame = orb.CFrame })
	inst("ParticleEmitter", { Texture = SPARKTEX, Color = ColorSequence.new(WHITE3, VIOLET), LightEmission = 1, LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 0) }),
		Speed = NumberRange.new(-26, -16), Lifetime = NumberRange.new(0.4, 0.6), SpreadAngle = Vector2.new(180, 180), Rate = 140, Parent = orb })
	inst("PointLight", { Color = VIOLET, Range = 22, Brightness = 5, Parent = orb })
	sfx("rbxassetid://9114446852", 0.6, 0.8)
	tw(vign, 1.5, { ImageTransparency = 0.45 })
	local orbitStart = math.random() * math.pi * 2
	over(3.2, function(dt, a)
		local hp = handPart and handPart.Position or speedRoot.Position
		orb.CFrame, orbShell.CFrame = CFrame.new(hp), CFrame.new(hp)
		orb.Size = Vector3.one * (0.5 + a * 3.5)
		orbShell.Size = Vector3.one * (1 + a * 6)
		local ang = orbitStart + a * 1.4
		local eye = hp + Vector3.new(math.cos(ang) * 14, -4 + a * 3, math.sin(ang) * 14)
		drive(CFrame.lookAt(eye, hp), 55, dt, 4)
		shake(0.1 + a * 0.6, 0.2)
		if math.random() < 0.3 then bolt(hp, hp + Vector3.new((math.random() - 0.5) * 8, (math.random() - 0.5) * 8, (math.random() - 0.5) * 8), MAGENTA, 0.06) end
		cc.TintColor = Color3.fromRGB(225, 225, 245):Lerp(Color3.fromRGB(230, 200, 255), a)
	end)

	-- 3. FIRE: impact frames, the old flash frames, and the blast leaves his hand
	orb:Destroy() orbShell:Destroy()
	local projectile = projectileAsset:Clone()
	projectile:PivotTo(handPart and handPart.CFrame or speedRoot.CFrame)
	projectile.Parent = workspace
	keep(projectile)
	local aimCFrame = speedRoot.CFrame * CFrame.Angles(math.rad(-15), 0, 0)
	local mainPart = projectile.PrimaryPart or projectile:FindFirstChildWhichIsA("BasePart", true)
	if mainPart then
		local att = inst("Attachment", { Parent = mainPart })
		inst("LinearVelocity", { Attachment0 = att, MaxForce = math.huge, VectorVelocity = aimCFrame.LookVector * 50, Parent = mainPart })
	end
	for _, p in projectile:GetDescendants() do if p:IsA("BasePart") then p.Anchored = false end end
	task.spawn(impact, { speedy, character }, IMPACT)
	white.Enabled = true
	task.wait(0.1)
	purple.Enabled = true
	white.Enabled = false
	for _, item in ipairs(handPart and handPart:GetDescendants() or {}) do
		if item:IsA("ParticleEmitter") then item.Enabled = false end
		if item:IsA("Sound") then item:Play() end
	end
	task.wait(0.03)
	purple.Enabled = false
	black.Enabled = true
	task.wait(0.05)
	black.Enabled = false
	shake(1.2, 0.5)
	if mode == "bad" then
		-- ======== NOT READY: nobody comes. You take the blast. ========
		playScore(SCORE.Doom, 0.55, 0.3, 4)
		local b = function() return mainPart and mainPart.Position or speedRoot.Position end
		-- the blast is coming, and nothing is stopping it
		over(0.5, function(dt)
			local p = b()
			drive(CFrame.lookAt(p - toSpeed * -10 + roomSide * 6 + Vector3.new(0, 2, 0), p), 70, dt, 12)
		end)
		-- over your shoulder as it closes in: slow, heavy, inevitable
		-- (kept in full color for the bad ending -- no desaturation)
		cc.Contrast = 0.25
		local shoulderEye = playerPos - toSpeed * 6 + roomSide * 2.5 + Vector3.new(0, 2.5, 0)
		for _, p in projectile:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true end end
		local from = b()
		local target = playerPos + Vector3.new(0, 0.5, 0)
		sfx("rbxassetid://9114446852", 0.8, 0.5)
		over(1.6, function(dt, a)
			local e = a ^ 2.2
			local p = from:Lerp(target, e)
			if projectile.Parent then projectile:PivotTo(CFrame.new(p)) end
			drive(CFrame.lookAt(shoulderEye, p), 60 - a * 20, dt, 6)
			shake(0.2 + a * 1.2, 0.2)
			vign.ImageTransparency = 0.45 - a * 0.3
		end)
		-- IMPACT
		if projectile.Parent then projectile:Destroy() end
		sfx("rbxassetid://139557908315922", 1, 0.7)
		sfx("rbxassetid://83382878583668", 1, 0.6)
		task.spawn(impact, { character, speedy }, IMPACT_P)
		flashTo(VIOLET, 0.25)
		shake(4, 0.9)
		local ball = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = VIOLET, CFrame = CFrame.new(target) })
		local shell = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Color = MAGENTA, Material = Enum.Material.ForceField, CFrame = CFrame.new(target) })
		inst("PointLight", { Color = VIOLET, Range = 60, Brightness = 8, Parent = ball })
		tw(ball, 0.5, { Size = Vector3.one * 26, Transparency = 1 }, Enum.EasingStyle.Quint)
		tw(shell, 0.8, { Size = Vector3.one * 40, Transparency = 1 }, Enum.EasingStyle.Quint)
		for i = 1, 2 do
			local ring = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 4, 4), Color = (i == 1) and MAGENTA or WHITE3,
				CFrame = CFrame.new(target.X, characterLocation.Position.Y - 2.4 + i * 0.2, target.Z) * CFrame.Angles(0, 0, math.rad(90)) })
			tw(ring, 0.7 + i * 0.2, { Size = Vector3.new(0.2, 70 + i * 20, 70 + i * 20), Transparency = 1 }, Enum.EasingStyle.Quint)
		end
		local smoke = part({ Transparency = 1, Size = Vector3.new(6, 2, 6), CFrame = CFrame.new(target) })
		local se = inst("ParticleEmitter", { Texture = SMOKETEX, Color = ColorSequence.new(Color3.fromRGB(120, 60, 170), Color3.fromRGB(20, 10, 30)),
			Size = NumberSequence.new(6, 16), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(10, 26), SpreadAngle = Vector2.new(180, 180), Drag = 2, Rate = 0, Parent = smoke })
		se:Emit(60)
		-- you are gone: burnt to ash where you stood
		for _, p in ipairs(character:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local ash = inst("ParticleEmitter", { Texture = SPARKTEX, Color = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(30, 10, 40)), LightEmission = 0.7, LightInfluence = 0,
					Size = NumberSequence.new(0.6, 0), Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(4, 12), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 6, 0), Rate = 0, Parent = p })
				ash:Emit(16)
				task.delay(3, function() ash:Destroy() end)
			end
		end
		local vanish = RunService.RenderStepped:Connect(function()
			for _, p in ipairs(character:GetDescendants()) do
				if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 1 end
			end
		end)
		badVanish = vanish
		-- slow motion wide as the smoke rolls out
		-- (kept in full color for the bad ending -- no desaturation)
		cc.Contrast, cc.TintColor = 0.35, Color3.fromRGB(230, 190, 255)
		blur.Size = 4
		local wideEye = target + roomSide * 26 - toSpeed * 18 + Vector3.new(0, 7, 0)
		cut(CFrame.lookAt(wideEye, target), 70)
		hold(2.2, CFrame.lookAt(wideEye + roomSide * -4, target), 62, 1.5)
		blur.Size = 0
		-- he doesn't even look impressed
		holdTrack:Stop(0.3)
		tw(drone, 1, { Volume = 0.5, PlaybackSpeed = 0.55 })
		playScore(SCORE.Standoff, 0.45, 1.5)
		local speedFace = speedHead.Position + (playerPos - speedHead.Position).Unit * 11 + Vector3.new(0, 0.6, 0)
		cut(CFrame.lookAt(speedFace + roomSide * 3, speedHead.Position), 45)
		task.spawn(say, "EVIL SPEED", Color3.fromRGB(255, 60, 60), "Pathetic.", 1.4)
		hold(2, CFrame.lookAt(speedFace, speedHead.Position), 38, 2)
		task.spawn(say, "EVIL SPEED", Color3.fromRGB(255, 60, 60), "You came down here ALONE?", 1.6)
		hold(2.4, CFrame.lookAt(speedFace - (playerPos - speedHead.Position).Unit * 2, speedHead.Position), 32, 2)
		task.spawn(say, "EVIL SPEED", Color3.fromRGB(255, 60, 60), "Come back when you've got nothing left to do.", 2)
		-- pull back up out of the crater
		local craterEye = target + Vector3.new(0, 15, 0) - toSpeed * 12 + roomSide * 6
		over(3, function(dt, a)
			drive(CFrame.lookAt(craterEye + Vector3.new(0, a * 4, 0), target:Lerp(speedHead.Position, 0.3)), 60 + a * 10, dt, 2)
		end)
		-- THE END CARD
		stopScore(2)
		tw(fade, 1.2, { BackgroundTransparency = 0 })
		task.wait(1.3)
		local card = inst("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.7, 0.14), BackgroundTransparency = 1,
			FontFace = GFONT, TextScaled = true, Text = "YOU WERE OBLITERATED", TextColor3 = Color3.fromRGB(255, 50, 70), TextTransparency = 1, ZIndex = 41, Parent = gui },
		{ inst("UIStroke", { Thickness = 3, Color = BLACK3 }) })
		local sub = inst("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.6, 0.05), BackgroundTransparency = 1,
			FontFace = GFONT, TextScaled = true, Text = "Finish every quest... then come back.", TextColor3 = Color3.fromRGB(200, 170, 255), TextTransparency = 1, ZIndex = 41, Parent = gui })
		sfx("rbxassetid://114743565978001", 0.8, 0.4)
		tw(card, 0.3, { TextTransparency = 0 })
		task.wait(1)
		tw(sub, 0.8, { TextTransparency = 0 })
		task.wait(3)
		-- wake up outside the dungeon
		vanish:Disconnect()
		badVanish = nil
		for _, p in ipairs(character:GetDescendants()) do
			if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 0 end
		end
		local exit = Dungeon:FindFirstChild("ExitPart")
		if exit and characterRoot.Parent then
			characterRoot.Anchored = false
			character:PivotTo(exit.CFrame + Vector3.new(0, 3, 0))
		end
		local myHum2 = character:FindFirstChildOfClass("Humanoid")
		if myHum2 and myHum2.WalkSpeed == 0 then myHum2.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed end
		tw(card, 0.8, { TextTransparency = 1 })
		tw(sub, 0.8, { TextTransparency = 1 })
		task.wait(0.9)
		return
	end

	-- whip after the blast, then TIME STOPS
	local blastPos = function() return mainPart and mainPart.Position or speedRoot.Position end
	over(0.4, function(dt)
		local b = blastPos()
		drive(CFrame.lookAt(b - toSpeed * -10 + roomSide * 6 + Vector3.new(0, 2, 0), b), 70, dt, 12)
	end)
	for _, p in projectile:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true end end
	-- the freeze: colour drains, a heartbeat, the camera drifts round the frozen blast
	cc.Saturation, cc.Contrast = -0.85, 0.3
	blur.Size = 3
	sfx("rbxassetid://114743565978001", 0.6, 0.45)
	local frozen = blastPos()
	local fa = math.atan2(roomSide.X, roomSide.Z)
	over(1.6, function(dt, a)
		local ang = fa + a * 0.6
		drive(CFrame.lookAt(frozen + Vector3.new(math.sin(ang) * 16, 2, math.cos(ang) * 16), frozen), 55, dt, 3)
	end)

	-- 4. NOT ON MY WATCH: look up; the gang drops in
	local startCF = npcs:GetPivot()
	local endCF = startCF * CFrame.new(0, -38, 0)
	local landPos = endCF.Position
	over(0.9, function(dt)
		drive(CFrame.lookAt(playerPos + roomSide * 8 - toSpeed * 4 + Vector3.new(0, -1, 0), startCF.Position), 70, dt, 6)
	end)
	cc.Saturation, cc.Contrast = 0.05, 0.12
	blur.Size = 0
	-- something is coming through the roof: the ceiling groans, dust trickles
	local roof = prepCeiling(Vector3.new(landPos.X, 0, landPos.Z), 20)
	if roof then
		local trickle = part({ Transparency = 1, Size = Vector3.new(roof.hole, 0.2, roof.hole), CFrame = CFrame.new(roof.centre.X, roof.y - 0.2, roof.centre.Z) })
		local dustE = inst("ParticleEmitter", { Texture = SMOKETEX, Color = ColorSequence.new(Color3.fromRGB(150, 130, 110)), Size = NumberSequence.new(0.8, 2.5),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(4, 8), EmissionDirection = Enum.NormalId.Bottom, Acceleration = Vector3.new(0, -10, 0), Shape = Enum.ParticleEmitterShape.Box, Rate = 30, Parent = trickle })
		sfx("rbxassetid://9112795463", 0.6, 1.3)
		over(0.9, function(dt, a)
			shake(0.2 + a * 0.6, 0.15)
			if roof.patch then roof.patch.CFrame = CFrame.new(roof.centre) * CFrame.new((math.random() - 0.5) * 0.2 * a, (math.random() - 0.5) * 0.3 * a, 0) end
			drive(CFrame.lookAt(playerPos + roomSide * 8 - toSpeed * 4 + Vector3.new(0, -1, 0), roof.centre), 70, dt, 6)
		end)
		dustE.Rate = 0
	end
	playScore(SCORE.Heroes, 0.6, 0.3)
	task.spawn(say, "THE GANG", Color3.fromRGB(255, 225, 60), "Not on my watch.", 1.2)
	sfx("rbxassetid://72728975467251", 1, 1, gui)
	local cfv = inst("CFrameValue", { Value = startCF })
	cfv.Changed:Connect(function(v) if npcs.Parent then npcs:PivotTo(v) end end)
	local drop = TweenService:Create(cfv, TweenInfo.new(0.45, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), { Value = endCF })
	drop:Play()
	-- ...and they smash straight through it
	if roof then
		task.delay(0.12, function()
			if roof.patch then roof.patch:Destroy() roof.patch = nil end
			sfx("rbxassetid://83382878583668", 1, 1.1)
			sfx("rbxassetid://139557908315922", 0.7, 1.4)
			shake(2.4, 0.5)
			flashTo(Color3.fromRGB(255, 240, 210), 0.35)
			-- broken planks and chunks, real physics (this client only)
			local wood = roof.ceil.Color
			for i = 1, 22 do
				local plank = i % 3 ~= 0
				local sz = plank and Vector3.new(1 + math.random() * 5, 0.6 + math.random() * 0.6, 0.6 + math.random() * 1.2) or Vector3.one * (0.6 + math.random() * 1.6)
				local p = Instance.new("Part")
				p.Size = sz
				p.Material = plank and Enum.Material.Wood or Enum.Material.Slate
				p.Color = plank and wood or Color3.fromRGB(90, 88, 84)
				p.CanCollide = true
				p.CanQuery = false
				p.CFrame = CFrame.new(roof.centre + Vector3.new((math.random() - 0.5) * roof.hole, -1, (math.random() - 0.5) * roof.hole)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
				p.Parent = fxFolder
				p.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 30, -20 - math.random() * 25, (math.random() - 0.5) * 30)
				p.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20
			end
			-- dust cloud bursting down and out
			local burst = part({ Transparency = 1, Size = Vector3.new(roof.hole, 1, roof.hole), CFrame = CFrame.new(roof.centre.X, roof.y - 0.5, roof.centre.Z) })
			local be = inst("ParticleEmitter", { Texture = SMOKETEX, Color = ColorSequence.new(Color3.fromRGB(170, 150, 130), Color3.fromRGB(90, 80, 70)), Size = NumberSequence.new(4, 12),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(1.5, 2.5),
				Speed = NumberRange.new(15, 30), SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Bottom, Drag = 2, Shape = Enum.ParticleEmitterShape.Box, Rate = 0, Parent = burst })
			be:Emit(45)
			local splinters = inst("ParticleEmitter", { Texture = SPARKTEX, Color = ColorSequence.new(Color3.fromRGB(255, 220, 160)), LightEmission = 0.5, Size = NumberSequence.new(0.6, 0),
				Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(20, 40), SpreadAngle = Vector2.new(90, 90), EmissionDirection = Enum.NormalId.Bottom, Acceleration = Vector3.new(0, -40, 0), Rate = 0, Parent = burst })
			splinters:Emit(40)
			-- daylight pouring through the hole
			local shaft = part({ Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 240, 200), Transparency = 0.85, Size = Vector3.new(31, roof.hole * 0.8, roof.hole * 0.8),
				CFrame = CFrame.new(roof.centre.X, roof.y - 15.5, roof.centre.Z) * CFrame.Angles(0, 0, math.rad(90)) })
			inst("SpotLight", { Face = Enum.NormalId.Right, Angle = 60, Range = 40, Brightness = 4, Color = Color3.fromRGB(255, 235, 200), Parent = shaft })
			tw(shaft, 4, { Transparency = 0.93 })
		end)
	end
	over(0.45, function(dt)
		drive(CFrame.lookAt(playerPos + roomSide * 8 - toSpeed * 4 + Vector3.new(0, -1, 0), npcs:GetPivot().Position), 70, dt, 10)
	end)
	cfv:Destroy()
	-- landing
	sfx("rbxassetid://125367748123159", 1, 1, gui)
	local friendModels = {}
	for _, m in ipairs(npcs:GetChildren()) do table.insert(friendModels, m) end
	task.spawn(impact, friendModels, { { WHITE3, BLACK3, BLACK3, 0.05 }, { Color3.fromRGB(255, 225, 60), BLACK3, WHITE3, 0.05 } })
	shake(2, 0.5)
	flashTo(Color3.fromRGB(255, 240, 180), 0.4)
	local ring = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 4, 4), Color = Color3.fromRGB(255, 225, 60), CFrame = CFrame.new(landPos.X, -233.5, landPos.Z) * CFrame.Angles(0, 0, math.rad(90)) })
	tw(ring, 0.6, { Size = Vector3.new(0.2, 50, 50), Transparency = 1 }, Enum.EasingStyle.Quint)
	-- hero shot: low, behind the line-up, Speed at the far end
	-- hero shot: low and off to the side of the line-up, pushing past them
	-- towards Speed at the far end
	local floorY = characterLocation.Position.Y
	local hero0 = Vector3.new(landPos.X, floorY + 1.5, landPos.Z) + roomSide * 15 + toSpeed * 5
	cut(CFrame.lookAt(hero0, Vector3.new(landPos.X, floorY + 3, landPos.Z)), 75)
	over(1.8, function(dt, a)
		local e = a * a * (3 - 2 * a)
		local look = Vector3.new(landPos.X, floorY + 3, landPos.Z):Lerp(speedHead.Position, e * 0.6)
		drive(CFrame.lookAt(hero0 + toSpeed * e * 8 - roomSide * e * 3, look), 75 - e * 12, dt, 4)
	end)

	-- 5. THE ULTIMATE BEAM
	for _, item in ipairs(BEAM:GetDescendants()) do
		if item:IsA("Beam") then
			item.Enabled = true
			if not item:GetAttribute("HasDoubled") then
				item.Width0 *= 5
				item.Width1 *= 5
				item:SetAttribute("HasDoubled", true)
			end
		elseif item:IsA("ParticleEmitter") or item:IsA("PointLight") then
			item.Enabled = true
		end
	end
	sfx("rbxassetid://86261914368076", 1, 1, gui)
	projectile:Destroy()
	gettinghitTrack:Play()
	task.spawn(impact, { speedy }, IMPACT)
	flashTo(WHITE3, 0.6)
	cc.Brightness, cc.Contrast, cc.TintColor = 0.25, 0.25, Color3.fromRGB(255, 250, 225)
	tw(cc, 2, { Brightness = 0.05, Contrast = 0.15 })
	-- track along the beam into his face
	local beamFrom = landPos
	over(1.4, function(dt, a)
		local e = a * a
		local p = beamFrom:Lerp(speedHead.Position, 0.35 + e * 0.45)
		drive(CFrame.lookAt(p + roomSide * 9 + Vector3.new(0, 2, 0), speedHead.Position), 70, dt, 6)
		shake(0.6 + a, 0.2)
	end)
	task.spawn(say, "EVIL SPEED", Color3.fromRGB(255, 30, 30), "NOOOOOOOOOOOOO!", 0.8)
	hold(1.3, CFrame.lookAt(speedHead.Position + (playerPos - speedHead.Position).Unit * 9 + Vector3.new(0, 0.5, 0), speedHead.Position), 40, 8)
	-- wide: he comes apart
	cut(CFrame.lookAt(speedRoot.Position + roomSide * 30 + toSpeed * 12 + Vector3.new(0, 4, 0), speedRoot.Position), 70)
	task.wait(0.4)
	humanoid.Health = 0
	humanoid:ChangeState(Enum.HumanoidStateType.Dead)
	for _, d in ipairs(speedy:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("JointInstance") or d:IsA("WeldConstraint") then d:Destroy() end
	end
	for _, p in ipairs(speedy:GetDescendants()) do
		if p.Name == "FullBodyOutlineAura" then
			p:Destroy()
		elseif p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = true
			if p.Name == "HumanoidRootPart" then
				p:Destroy()
			else
				p:ApplyImpulse(Vector3.new(math.random(-25, 25), math.random(10, 35), math.random(-25, 25)) * p:GetMass())
			end
		end
	end
	gettinghitTrack:Stop()
	sfx("rbxassetid://139557908315922", 1, 1, gui)
	task.spawn(impact, { speedy }, { { WHITE3, BLACK3, BLACK3, 0.06 }, { BLACK3, WHITE3, Color3.fromRGB(255, 60, 60), 0.06 } })
	flashTo(WHITE3, 0.8)
	shake(3, 0.8)
	hold(0.3, camCF, 70, 8)
	for _, item in ipairs(BEAM:GetDescendants()) do
		if item:IsA("Beam") or item:IsA("PointLight") or item:IsA("ParticleEmitter") then item.Enabled = false end
	end
	hold(1.4, CFrame.lookAt(speedRoot.Position + roomSide * 34 + toSpeed * 14 + Vector3.new(0, 6, 0), speedRoot.Position + Vector3.new(0, -8, 0)), 70, 2)

	-- what's left of him burns away to ash
	for _, p in ipairs(speedy:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local ash = inst("ParticleEmitter", { Texture = SPARKTEX, Color = ColorSequence.new(Color3.fromRGB(255, 120, 60), Color3.fromRGB(40, 20, 20)), LightEmission = 0.6, LightInfluence = 0,
				Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(2, 5), Acceleration = Vector3.new(0, 4, 0), Rate = 0, Parent = p })
			ash:Emit(12)
			tw(p, 0.9, { Transparency = 1 })
		elseif p:IsA("Decal") or p:IsA("Texture") then
			tw(p, 0.9, { Transparency = 1 })
		elseif p:IsA("ParticleEmitter") or p:IsA("Beam") or p:IsA("Trail") or p:IsA("Highlight") then
			pcall(function() p.Enabled = false end)
		end
	end
	for _, a in ipairs(speedy:GetDescendants()) do
		if a:IsA("Accessory") then
			for _, h in ipairs(a:GetDescendants()) do if h:IsA("BasePart") then tw(h, 0.9, { Transparency = 1 }) end end
		end
	end

	-- 6. IT ISN'T OVER. Silence, then the room starts to shake.
	playScore(SCORE.Dread, 0.5, 2.5)
	tw(cc, 1.5, { Brightness = 0, Contrast = 0.1, Saturation = -0.1, TintColor = Color3.fromRGB(220, 215, 240) })
	tw(drone, 1, { Volume = 0.05 })
	local tlView = tlPos + Vector3.new(0, 1, 0) + (playerPos - tlPos) * Vector3.new(1, 0, 1).Unit * 0 
	local fromPlayer = (Vector3.new(tlPos.X, 0, tlPos.Z) - Vector3.new(playerPos.X, 0, playerPos.Z)).Unit
	local calmEye = tlPos - fromPlayer * 34 + Vector3.new(0, 2, 0)
	cut(CFrame.lookAt(calmEye, tlPos), 55)
	task.spawn(say, "HOMELESS GUY", Color3.fromRGB(210, 210, 210), "...is it over?", 1.4)
	over(2.6, function(dt, a)
		drive(CFrame.lookAt(calmEye + fromPlayer * a * 6, tlPos), 55 - a * 5, dt, 2)
	end)
	-- the rumble
	sfx("rbxassetid://9114795437", 0.9, 0.6)
	tw(drone, 1, { Volume = 0.6, PlaybackSpeed = 0.5 })
	local lights = {}
	local lf = Dungeon:FindFirstChild("Lights")
	for _, d in ipairs(lf and lf:GetDescendants() or {}) do
		if d:IsA("Beam") or d:IsA("Light") then table.insert(lights, { d = d, on = d.Enabled }) end
	end
	local wall = Vector3.new(tlPos.X, tlPos.Y, 1318.4)
	local tlHome = trueLapeace and trueLapeace:GetPivot()
	over(2.4, function(dt, a)
		shake(0.2 + a * 1.2, 0.2)
		for _, l in ipairs(lights) do l.d.Enabled = math.random() > a * 0.6 end
		if trueLapeace and tlHome then trueLapeace:PivotTo(tlHome * CFrame.new((math.random() - 0.5) * 0.3 * a, (math.random() - 0.5) * 0.3 * a, 0)) end
		if math.random() < a * 0.5 then
			local ang = math.random() * math.pi * 2
			local r = 2 + math.random() * 8 * a
			bolt(wall + Vector3.new(math.cos(ang) * r * 0.5, math.sin(ang) * r * 0.5, 0.2), wall + Vector3.new(math.cos(ang) * r, math.sin(ang) * r, 0.2), (math.random() < 0.5) and VIOLET or MAGENTA, 0.07)
		end
		drive(CFrame.lookAt(calmEye + fromPlayer * 6, tlPos:Lerp(wall, a * 0.6)), 50, dt, 3)
		cc.TintColor = Color3.fromRGB(220, 215, 240):Lerp(Color3.fromRGB(200, 170, 255), a)
	end)

	-- 7. THE PORTAL tears open behind True Lapeace
	local portalCF = CFrame.lookAt(wall, wall + Vector3.new(0, 0, 1))
	local R = 11
	local core = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.5, 0.5), Color = ABYSS, CFrame = portalCF * CFrame.Angles(0, math.rad(90), 0) })
	local veil = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.5, 0.5), Color = VIOLET, Material = Enum.Material.ForceField, CFrame = portalCF * CFrame.new(0, 0, 0.3) * CFrame.Angles(0, math.rad(90), 0) })
	local rings = {}
	for r = 1, 3 do
		local segs = {}
		for i = 1, 30 do segs[i] = part({ Size = Vector3.new(0.35, 0.35, 1.6), Color = (i % 3 == 0) and WHITE3 or ((r % 2 == 0) and MAGENTA or VIOLET) }) end
		rings[r] = { segs = segs, rad = R * (0.75 + r * 0.14), speed = (r % 2 == 0) and -1.6 or 1.1 + r * 0.3 }
	end
	local suckSrc = part({ Transparency = 1, Size = Vector3.new(40, 30, 30), CFrame = portalCF * CFrame.new(0, 0, 15) })
	local suck = inst("ParticleEmitter", { Texture = SMOKETEX, Color = ColorSequence.new(VIOLET, ABYSS), LightEmission = 0.4, LightInfluence = 0,
		Size = NumberSequence.new(2, 0.5), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(20, 30), EmissionDirection = Enum.NormalId.Back, Shape = Enum.ParticleEmitterShape.Box, Rate = 0, Parent = suckSrc })
	local plight = inst("PointLight", { Color = VIOLET, Range = 40, Brightness = 0, Parent = core })
	local open = 0
	local portalConn
	portalConn = RunService.RenderStepped:Connect(function()
		if not core.Parent then portalConn:Disconnect() return end
		local t = os.clock()
		local rad = R * open
		core.Size = Vector3.new(0.3, rad * 1.9 + 0.2, rad * 1.9 + 0.2)
		veil.Size = Vector3.new(0.4, rad * 2.1 + 0.2, rad * 2.1 + 0.2)
		for _, rg in ipairs(rings) do
			local rr = rg.rad * open
			for i, sg in ipairs(rg.segs) do
				local ang = (i / #rg.segs) * math.pi * 2 + t * rg.speed
				local p = portalCF:PointToWorldSpace(Vector3.new(math.cos(ang) * rr, math.sin(ang) * rr, 0.4))
				local tan = portalCF:VectorToWorldSpace(Vector3.new(-math.sin(ang), math.cos(ang), 0))
				sg.CFrame = CFrame.lookAt(p, p + tan)
				sg.Transparency = open < 0.05 and 1 or 0
			end
		end
		plight.Brightness = open * 6
		suck.Rate = open * 60
		if open > 0.2 and math.random() < 0.35 then
			local ang = math.random() * math.pi * 2
			local a1 = portalCF:PointToWorldSpace(Vector3.new(math.cos(ang) * rad, math.sin(ang) * rad, 0.3))
			bolt(a1, a1 + portalCF:VectorToWorldSpace(Vector3.new(math.cos(ang) * 5, math.sin(ang) * 5, 1)), (math.random() < 0.5) and VIOLET or WHITE3, 0.06)
		end
	end)
	sfx("rbxassetid://9114446852", 1, 0.5)
	sfx("rbxassetid://114743565978001", 0.9, 0.35)
	task.spawn(impact, { trueLapeace }, IMPACT_P)
	flashTo(VIOLET, 0.6)
	tw(vign, 0.8, { ImageColor3 = VIOLET, ImageTransparency = 0.25 })
	-- the tear, seen from beside True Lapeace
	local sideEye = tlPos + roomSide * 18 + fromPlayer * -8 + Vector3.new(0, 2, 0)
	cut(CFrame.lookAt(sideEye, tlPos:Lerp(wall, 0.5)), 70)
	over(1.8, function(dt, a)
		open = 1 - (1 - a) ^ 3
		shake(1.2 * (1 - a) + 0.3, 0.2)
		drive(CFrame.lookAt(sideEye, tlPos:Lerp(wall, 0.5)), 70, dt, 5)
		cc.Saturation = -0.1 + a * 0.2
	end)

	-- 8. THE HAND. It lunges out and grabs True Lapeace.
	local ASH_NAME, ASH_COLOUR = "???", Color3.fromRGB(170, 120, 255)
	task.spawn(say, ASH_NAME, ASH_COLOUR, "Your species does not deserve this power...", 1.2)
	hold(1.5, CFrame.lookAt(tlPos - fromPlayer * 12 + Vector3.new(0, 1, 0), wall), 45, 3)
	local reachCF, grabCF
	if hand and handHome then
		hand.Transparency = 0
		-- bigger, with a burning violet edge and dark smoke pouring off it, so
		-- it reads against the black of the portal
		hand.Size = handSize * 1.7
		keep(inst("Highlight", { FillColor = Color3.fromRGB(30, 0, 50), FillTransparency = 0.35, OutlineColor = MAGENTA, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.Occluded, Adornee = hand, Parent = fxFolder }))
		local handAtt = inst("Attachment", { Parent = hand })
		keep(handAtt)
		inst("ParticleEmitter", { Texture = SMOKETEX, Color = ColorSequence.new(Color3.fromRGB(90, 20, 140), ABYSS), LightEmission = 0.3, LightInfluence = 0,
			Size = NumberSequence.new(3, 7), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1, 3), Shape = Enum.ParticleEmitterShape.Box, Rate = 40, Parent = handAtt })
		inst("PointLight", { Color = MAGENTA, Range = 18, Brightness = 3, Parent = handAtt })
		-- line the hand up with the portal centre, fingers into the room
		local len = hand.Size.Y
		local startHand = handHome - handHome.Position + Vector3.new(tlPos.X, tlPos.Y, wall.Z - len * 0.5 - 1)
		reachCF = startHand + Vector3.new(0, 0, (tlPos.Z - len * 0.42) - startHand.Position.Z)
		hand.CFrame = startHand
		-- punch-in on the grab from low and to the side
		local grabEye = tlPos + roomSide * 11 + fromPlayer * -7 + Vector3.new(0, -3, 0)
		cut(CFrame.lookAt(grabEye, tlPos), 62)
		task.spawn(impact, { hand }, IMPACT_P)
		sfx("rbxassetid://83382878583668", 1, 0.7)
		local lunge = TweenService:Create(hand, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = reachCF })
		lunge:Play()
		over(0.35, function(dt) drive(CFrame.lookAt(grabEye, tlPos), 62, dt, 12) end)
		-- the grab: the hand clenches (squash) round it
		task.spawn(impact, { hand, trueLapeace }, { { BLACK3, WHITE3, VIOLET, 0.07 }, { WHITE3, BLACK3, BLACK3, 0.06 }, { VIOLET, BLACK3, WHITE3, 0.06 }, { BLACK3, WHITE3, MAGENTA, 0.06 } })
		sfx("rbxassetid://114743565978001", 1, 0.6)
		shake(2.5, 0.6)
		local baseSize = hand.Size
		tw(hand, 0.15, { Size = baseSize * Vector3.new(0.8, 0.92, 0.75) }, Enum.EasingStyle.Quad)
		if trueLapeace then trueLapeace:SetAttribute("Grabbed", true) end
		grabCF = hand.CFrame:ToObjectSpace(trueLapeace and trueLapeace:GetPivot() or CFrame.new(tlPos))
		hold(0.6, CFrame.lookAt(grabEye + (tlPos - grabEye) * 0.35, tlPos), 50, 10)
	end

	-- 9. INTO THE DARK: it drags True Lapeace back through the portal
	local farEye = playerPos - fromPlayer * 2 + Vector3.new(0, 1.5, 0)
	cut(CFrame.lookAt(farEye, tlPos), 60)
	sfx("rbxassetid://9125742262", 1, 0.8)
	if hand and reachCF then
		local backCF = reachCF + Vector3.new(0, 0, -34)
		local t0 = os.clock()
		over(1.5, function(dt, a)
			local e = a ^ 2.4
			hand.CFrame = reachCF:Lerp(backCF, e)
			if trueLapeace and grabCF then trueLapeace:PivotTo(hand.CFrame * grabCF) end
			drive(CFrame.lookAt(farEye + fromPlayer * a * 10, tlPos:Lerp(wall, a)), 60 - a * 20, dt, 4)
			shake(0.5 + a, 0.2)
		end)
	end
	-- the dungeon quest is finished the moment True Lapeace is taken
	pcall(function() ReplicatedStorage.ClaimQuestReward:FireServer("DungeonReturn") end)
	-- the portal slams shut
	task.spawn(impact, {}, { { WHITE3, BLACK3, BLACK3, 0.06 } })
	sfx("rbxassetid://139557908315922", 1, 0.6)
	local shutStart = open
	over(0.35, function(dt, a) open = shutStart * (1 - a ^ 2) shake(1.5, 0.2) drive(camCF, camFov, dt, 8) end)
	open = 0
	flashTo(WHITE3, 1.2)
	if trueLapeace then trueLapeace.Parent = nil end -- gone (orbiting lapis go with it)
	if handRestore then handRestore() end
	for _, l in ipairs(lights) do l.d.Enabled = l.on end
	tw(drone, 1, { Volume = 0 })
	cc.Saturation, cc.TintColor = -0.3, Color3.fromRGB(220, 215, 235)
	hold(1.4, CFrame.lookAt(farEye + fromPlayer * 10, wall), 45, 2)

	-- 9.5. ONE LAST LOOK: back to the gang
	local gangPos = npcs:GetPivot().Position
	local gangEye = Vector3.new(landPos.X, floorY + 4, landPos.Z) + roomSide * 14 + toSpeed * 6
	over(1.2, function(dt, a)
		drive(CFrame.lookAt(gangEye, Vector3.new(gangPos.X, floorY + 3, gangPos.Z)), 55, dt, 4)
	end)
	say("THE GANG", Color3.fromRGB(255, 225, 60), "Aight bro, you got that.", 1.3)
	task.wait(1.7)
	say("THE GANG", Color3.fromRGB(255, 225, 60), "Lapeace out ✌️", 1.6)
	task.wait(2.2)

	-- the gang fades away before the end card comes in
	do
		local NPC_FADE_TIME = 1.2
		for _, m in ipairs(npcs:GetChildren()) do
			if m:IsA("BasePart") then
				tw(m, NPC_FADE_TIME, { Transparency = 1 })
			end
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then
					tw(p, NPC_FADE_TIME, { Transparency = 1 })
				elseif p:IsA("Decal") or p:IsA("Texture") then
					tw(p, NPC_FADE_TIME, { Transparency = 1 })
				elseif p:IsA("ParticleEmitter") or p:IsA("Trail") or p:IsA("Beam") or p:IsA("Highlight") then
					pcall(function() p.Enabled = false end)
				end
			end
		end
		task.wait(NPC_FADE_TIME + 0.2)
	end

	-- 10. THE END CARD
	stopScore(1.5)
	tw(fade, 1.5, { BackgroundTransparency = 0 })
	local music = sfx("rbxassetid://1846088038", 0.5, 1, gui)
	task.wait(1.6)
	local card = inst("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.22), BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy), TextScaled = true, Text = "The Real Lapeace is the Friends We Made Along The Way",
		TextColor3 = WHITE3, TextTransparency = 1, ZIndex = 41, Parent = gui })
	tw(card, 1.5, { TextTransparency = 0 })
	task.wait(6)
	tw(card, 1, { TextTransparency = 1 })
	task.wait(1.2)
	card.Text = "...but True Lapeace is gone."
	card.TextColor3 = Color3.fromRGB(200, 170, 255)
	tw(card, 1.2, { TextTransparency = 0 })
	task.wait(3.5)
	tw(card, 0.8, { TextTransparency = 1 })
	task.wait(1)
	card.Text = "TO BE CONTINUED"
	card.FontFace = GFONT
	card.TextColor3 = VIOLET
	card.Size = UDim2.fromScale(0.6, 0.16)
	inst("UIStroke", { Thickness = 3, Color = BLACK3, Parent = card })
	tw(card, 0.3, { TextTransparency = 0 })
	sfx("rbxassetid://114743565978001", 0.8, 0.5)
	task.wait(3.5)
	tw(card, 1, { TextTransparency = 1 })
	tw(music, 1.5, { Volume = 0 })
	task.wait(1.2)
end

-- Always hands everything back, whether the scene finished or you died in it.
local function endGoodEnding(character, characterRoot)
	localPlayer:SetAttribute("HideHud_Dungeon", nil)
	stopScore(0.6)
	resumeGameMusic()
	hideOthers(false)
	pcall(function() holdTrack:Stop(0.2) end)
	if badVanish then badVanish:Disconnect() badVanish = nil end
	local me = localPlayer.Character
	for _, p in ipairs(me and me:GetDescendants() or {}) do
		if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 0 end
	end
	for _, n in ipairs({ "DungeonCinematic" }) do
		local g = localPlayer.PlayerGui:FindFirstChild(n)
		if g then g:Destroy() end
	end
	for _, n in ipairs({ "DungeonCC", "DungeonBlur" }) do
		local e = Lighting:FindFirstChild(n)
		if e then e:Destroy() end
	end
	local f = workspace:FindFirstChild("DungeonCinematicFX")
	if f then f:Destroy() end
	white.Enabled, purple.Enabled, black.Enabled = false, false, false
	if handRestore then handRestore() end
	if ceilingRestore then ceilingRestore() end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then camera.CameraSubject = hum end
	if characterRoot and characterRoot.Parent then characterRoot.Anchored = false end
end

local function playGoodEnding(character, characterRoot, mode)
	local hum = character:FindFirstChildOfClass("Humanoid")
	local done = false
	local thread
	local function finish()
		if done then return end
		done = true
		if thread and coroutine.status(thread) ~= "dead" and coroutine.running() ~= thread then pcall(task.cancel, thread) end
		endGoodEnding(character, characterRoot)
		task.delay(1, function() if onGoodEndingOver then onGoodEndingOver() end end)
	end
	local diedConn = hum and hum.Died:Connect(finish)
	local charConn = localPlayer.CharacterAdded:Connect(finish)
	thread = task.spawn(function()
		local ok, err = pcall(runGoodEnding, character, characterRoot, mode)
		if not ok then warn("[DungeonCutscene] " .. tostring(err)) end
		if diedConn then diedConn:Disconnect() end
		charConn:Disconnect()
		finish()
	end)
end

--==================================================
-- WHICH ENDING?
--  * every quest done (the 8 main quests, villager = cangoin)  -> GOOD ending
--  * anything missing                                        -> BAD ending
--    (the original "You shouldn't be here." scene, unchanged)
--  * True Lapeace already taken (DungeonReturn claimed)       -> nothing plays,
--    True Lapeace stays gone
--==================================================
local MAIN_QUESTS = { "HomelessQuest", "ToiletQuest", "TungQuest", "CarKeyQuest", "VerityQuest", "VerityQuest2", "VerityQuest3" }

local function canGoIn()
	local v = playerStats:FindFirstChild("cangoin")
	return v ~= nil and v.Value == true
end

local function allQuestsDone()
	if not canGoIn() then return false end -- VillagerQuest
	for _, q in ipairs(MAIN_QUESTS) do
		if not claimedQuests:FindFirstChild(q) then return false end
	end
	return true
end

-- True Lapeace (and the lapis orbiting it) is hidden on this client once
-- the Anti-Spiral has taken it, and comes back if quests are reset.
local trueLapeaceRef = Dungeon:FindFirstChild("True Lapeace")
local function syncTrueLapeace()
	if not trueLapeaceRef then return end
	local gone = claimedQuests:FindFirstChild("DungeonReturn") ~= nil
	if gone then
		-- (mid-cutscene the scene itself removes it at the right moment)
		if not hasPlayed then trueLapeaceRef.Parent = nil end
	elseif trueLapeaceRef.Parent == nil and not hasPlayed then
		trueLapeaceRef.Parent = Dungeon
	end
end
onGoodEndingOver = function()
	if claimedQuests:FindFirstChild("DungeonReturn") then
		if trueLapeaceRef then trueLapeaceRef.Parent = nil end
		hasPlayed = false -- the trigger itself refuses to replay while DungeonReturn is claimed
		return
	end
	-- cut short before the Anti-Spiral finished: put everything back so it can play again
	if trueLapeaceRef and trueLapeaceRef.Parent == nil then trueLapeaceRef.Parent = Dungeon end
	if tlRestore then tlRestore() end
	hasPlayed = false
end
syncTrueLapeace()
claimedQuests.ChildAdded:Connect(function(c) if c.Name == "DungeonReturn" then task.defer(syncTrueLapeace) end end)
claimedQuests.ChildRemoved:Connect(function(c) if c.Name == "DungeonReturn" then task.defer(syncTrueLapeace) end end)

--==================================================
-- BAD ENDING (quests not finished) -- the original scene
--==================================================
local function runBadEnding(character, characterRoot, speakText)
	localPlayer:SetAttribute("HideHud_DungeonBad", true)
	camera.CameraType = Enum.CameraType.Scriptable

	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local tween = TweenService:Create(camera, tweenInfo, {CFrame = cutsceneCamPart.CFrame})
	tween:Play()
	character.Humanoid.WalkSpeed = 0
	characterRoot.CFrame = characterLocation.CFrame
	tween.Completed:Wait()
	speakText.Parent.Visible = true
	typeOut(speakText, "EVIL SPEED: You shouldn't be here.", LETTER_DELAY)
	task.wait(3)
	typeOut(speakText, "", LETTER_DELAY)
	speakText.Parent.Visible = false

	holdTrack:Play()
	task.wait(0.5)
	local hand = speedy.RightHand

	for _, item in pairs(hand:GetDescendants()) do
		if item:IsA("ParticleEmitter") then
			item.Enabled = true
			item:Emit(5)
		end
	end

	task.wait(3)

	local rootPart = speedy:WaitForChild("HumanoidRootPart")

	local projectile = projectileAsset:Clone()
	projectile:PivotTo(hand.CFrame)
	projectile.Parent = workspace

	local aimCFrame = rootPart.CFrame * CFrame.Angles(math.rad(-15), 0, 0)
	local shootVelocity = aimCFrame.LookVector * 50

	local mainPart = projectile.PrimaryPart or projectile:FindFirstChildWhichIsA("BasePart", true)
	if mainPart then
		local attachment = Instance.new("Attachment")
		attachment.Parent = mainPart
		local linearVel = Instance.new("LinearVelocity")
		linearVel.Attachment0 = attachment
		linearVel.MaxForce = math.huge
		linearVel.VectorVelocity = shootVelocity
		linearVel.Parent = mainPart
	end
	for _, part in projectile:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	white.Enabled = true
	task.wait(0.1)
	purple.Enabled = true
	white.Enabled = false

	for _, item in pairs(hand:GetDescendants()) do
		if item:IsA("ParticleEmitter") then
			item.Enabled = false
		end
		if item:IsA("Sound") then
			item:Play()
		end
	end

	task.wait(0.03)
	purple.Enabled = false
	black.Enabled = true
	task.wait(0.05)
	black.Enabled = false

	Debris:AddItem(projectile, 3)

	tween = TweenService:Create(camera, tweenInfo, {CFrame = cutsceneCamPart2.CFrame})
	tween:Play()
	tween.Completed:Wait()
end

local function endBadEnding(speakText)
	localPlayer:SetAttribute("HideHud_DungeonBad", nil)
	white.Enabled, purple.Enabled, black.Enabled = false, false, false
	pcall(function() holdTrack:Stop() end)
	pcall(function()
		for _, item in ipairs(speedy.RightHand:GetDescendants()) do
			if item:IsA("ParticleEmitter") then item.Enabled = false end
		end
	end)
	if speakText then
		pcall(function() speakText.Text = "" speakText.Parent.Visible = false end)
	end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
		if hum.Health > 0 and hum.WalkSpeed == 0 then hum.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed end
	end
end

local function playBadEnding(character, characterRoot, speakText)
	local hum = character:FindFirstChildOfClass("Humanoid")
	local done = false
	local thread, diedConn, charConn
	local function finish(aborted)
		if done then return end
		done = true
		if diedConn then diedConn:Disconnect() end
		if charConn then charConn:Disconnect() end
		if thread and coroutine.status(thread) ~= "dead" and coroutine.running() ~= thread then pcall(task.cancel, thread) end
		endBadEnding(speakText)
		task.delay(aborted and 0.5 or 2, function() hasPlayed = false end)
	end
	diedConn = hum and hum.Died:Connect(function() finish(true) end)
	charConn = localPlayer.CharacterAdded:Connect(function() finish(true) end)
	thread = task.spawn(function()
		local ok, err = pcall(runBadEnding, character, characterRoot, speakText)
		if not ok then warn("[DungeonCutscene] bad ending: " .. tostring(err)) end
		finish(false)
	end)
end

triggerPart.Touched:Connect(function(hit)
	if hasPlayed then return end
	local character = hit.Parent
	local hitPlayer = Players:GetPlayerFromCharacter(character)
	if hitPlayer ~= localPlayer then return end
	local characterRoot = character:FindFirstChild("HumanoidRootPart")
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not characterRoot or not hum or hum.Health <= 0 then return end

	-- True Lapeace is already gone: the room is quiet now
	if claimedQuests:FindFirstChild("DungeonReturn") then return end

	if allQuestsDone() then
		hasPlayed = true
		playGoodEnding(character, characterRoot)
	else
		-- turned away: "open the door" is done, now "finish everything and come back"
		pcall(function() ReplicatedStorage.ClaimQuestReward:FireServer("DungeonDoor") end)
		local Screen = hitPlayer.PlayerGui:FindFirstChild("ScreenGui")
		local SpeakFrame = Screen and Screen:FindFirstChild("BossSpeakFrame")
		local speakText = SpeakFrame and SpeakFrame:FindFirstChild("BossSpeak")
		hasPlayed = true
		-- the full cinematic, but nobody comes to help: you get obliterated
		playGoodEnding(character, characterRoot, "bad")
	end
end)