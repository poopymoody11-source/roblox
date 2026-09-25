--==================================================
-- FINAL CUTSCENE KIT (client)
-- Everything the chapters share: the server clock, easing,
-- the camera rig (shake / FOV kicks / roll), sound, the
-- screen overlay (letterbox, fades, flashes, impact frames,
-- boss dialogue in the crazy font), R6 avatar rigs with
-- procedural posing, textured quads, VFX cloning and the
-- lighting presets.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local SoundService = game:GetService("SoundService")

local Kit = {}
Kit.Player = Players.LocalPlayer
Kit.FC = ReplicatedStorage:WaitForChild("FinalCutscene")
Kit.Assets = Kit.FC:WaitForChild("Assets")
Kit.TL = require(Kit.FC:WaitForChild("Timeline"))

local camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera
end)

--==================================================
-- MATH
--==================================================
local sin, cos, rad, clamp, abs = math.sin, math.cos, math.rad, math.clamp, math.abs

-- (Studio review: set workspace attribute FC_FreezeAt on the client; the clock
-- pauses when it reaches that moment and carries on from there when it's moved later)
local reviewOffset = 0
function Kit.now()
	local real = workspace:GetServerTimeNow() - reviewOffset
	local f = workspace:GetAttribute("FC_FreezeAt")
	if f and real >= f then
		reviewOffset += real - f
		return f
	end
	return real
end
function Kit.lerp(a, b, t) return a + (b - a) * t end
function Kit.remap(x, a, b) if b == a then return x >= b and 1 or 0 end return clamp((x - a) / (b - a), 0, 1) end
function Kit.A(x, y, z) return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0)) end
function Kit.noise(x, seed) return math.noise(x, seed or 0.5, 0.25) end

local E = {}
E.linear = function(t) return t end
E.inSine = function(t) return 1 - cos(t * math.pi / 2) end
E.outSine = function(t) return sin(t * math.pi / 2) end
E.inOutSine = function(t) return -(cos(math.pi * t) - 1) / 2 end
E.inQuad = function(t) return t * t end
E.outQuad = function(t) return 1 - (1 - t) * (1 - t) end
E.inOutQuad = function(t) return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2 end
E.inCubic = function(t) return t * t * t end
E.outCubic = function(t) return 1 - (1 - t) ^ 3 end
E.inOutCubic = function(t) return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 end
E.outQuint = function(t) return 1 - (1 - t) ^ 5 end
E.inOutQuint = function(t) return t < 0.5 and 16 * t ^ 5 or 1 - (-2 * t + 2) ^ 5 / 2 end
E.inExpo = function(t) return t == 0 and 0 or 2 ^ (10 * t - 10) end
E.outExpo = function(t) return t == 1 and 1 or 1 - 2 ^ (-10 * t) end
E.inOutExpo = function(t)
	if t == 0 or t == 1 then return t end
	return t < 0.5 and 2 ^ (20 * t - 10) / 2 or (2 - 2 ^ (-20 * t + 10)) / 2
end
E.outBack = function(t) local c1 = 1.70158 local c3 = c1 + 1 return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2 end
E.inBack = function(t) local c1 = 1.70158 local c3 = c1 + 1 return c3 * t * t * t - c1 * t * t end
E.smooth = function(t) return t * t * (3 - 2 * t) end
E.smoother = function(t) return t * t * t * (t * (t * 6 - 15) + 10) end
Kit.E = E

-- eased 0..1 over [a,b]
function Kit.k(x, a, b, ease) return (ease or E.inOutSine)(Kit.remap(x, a, b)) end

-- Catmull-Rom through a list of points, u in [0,1]
function Kit.spline(points, u)
	local n = #points
	if n == 1 then return points[1] end
	local seg = clamp(u, 0, 1) * (n - 1)
	local i = math.min(math.floor(seg) + 1, n - 1)
	local t = seg - (i - 1)
	local p0 = points[math.max(i - 1, 1)]
	local p1 = points[i]
	local p2 = points[i + 1]
	local p3 = points[math.min(i + 2, n)]
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

--==================================================
-- CLOCK-DRIVEN LOOPS
--==================================================
-- Runs fn(t, dt) every render frame, t = seconds since t0 on the
-- server clock, until t >= dur (or stop() is called). Yields.
function Kit.run(t0, dur, fn, priority)
	local done = false
	local traced = false
	local last = Kit.now()
	local name = "FC_Run_" .. tostring(math.random(1, 1e9))
	RunService:BindToRenderStep(name, priority or (Enum.RenderPriority.Camera.Value + 5), function()
		local n = Kit.now()
		local dt = math.max(n - last, 0)
		last = n
		local t = n - t0
		if t >= dur then
			done = true
			return
		end
		local ok, err = xpcall(fn, debug.traceback, math.max(t, 0), dt)
		if not ok then
			-- (the full trace once per chapter, then just the message)
			if not traced then traced = true workspace:SetAttribute("FC_LastTrace", tostring(err)) warn("[FinalCutscene] " .. tostring(err)) else warn("[FinalCutscene] " .. tostring(err):match("^[^\n]*")) end
		end
	end)
	while not done and not Kit.Aborted do
		RunService.RenderStepped:Wait()
	end
	RunService:UnbindFromRenderStep(name)
	pcall(fn, dur, 0)
end

-- one-shot cues: local cue = Kit.cues(); cue(t, 2.5, function() ... end)
function Kit.cues()
	local fired = {}
	return function(t, at, fn)
		if t >= at and not fired[at .. tostring(fn)] then
			fired[at .. tostring(fn)] = true
			task.spawn(fn)
		end
	end
end

-- named one-shots, so cues declared inside a per-frame closure only fire once
function Kit.once()
	local done = {}
	return function(key, cond, fn)
		if cond and not done[key] then
			done[key] = true
			task.spawn(fn)
		end
	end
end

--==================================================
-- CAMERA
--==================================================
local Cam = {
	CF = CFrame.new(),
	Fov = 70,
	Roll = 0,
	Shakes = {},
	Kicks = {},
	Active = false,
}
Kit.Cam = Cam

function Kit.setCam(cf, fov, roll)
	Cam.CF = cf
	if fov then Cam.Fov = fov end
	Cam.Roll = roll or 0
end

function Kit.shake(amp, dur, freq, rotOnly)
	table.insert(Cam.Shakes, { Amp = amp, Dur = dur, Freq = freq or 18, Start = os.clock(), Seed = math.random() * 100, Rot = rotOnly })
end

function Kit.kick(amount, dur, ease)
	table.insert(Cam.Kicks, { Amt = amount, Dur = dur, Start = os.clock(), Ease = ease or E.outCubic })
end

local function cameraStep()
	if not Cam.Active then return end
	local cf = Cam.CF
	local now = os.clock()
	local px, py, pz, rx, ry, rz = 0, 0, 0, 0, 0, 0
	for i = #Cam.Shakes, 1, -1 do
		local s = Cam.Shakes[i]
		local a = (now - s.Start) / s.Dur
		if a >= 1 then
			table.remove(Cam.Shakes, i)
		else
			local amp = s.Amp * (1 - a) ^ 2
			local tt = (now - s.Start) * s.Freq
			rx += math.noise(tt, s.Seed, 1) * amp * 0.035
			ry += math.noise(tt, s.Seed, 2) * amp * 0.035
			rz += math.noise(tt, s.Seed, 3) * amp * 0.02
			if not s.Rot then
				px += math.noise(tt, s.Seed, 4) * amp * 0.5
				py += math.noise(tt, s.Seed, 5) * amp * 0.5
			end
		end
	end
	local fov = Cam.Fov
	for i = #Cam.Kicks, 1, -1 do
		local k = Cam.Kicks[i]
		local a = (now - k.Start) / k.Dur
		if a >= 1 then
			table.remove(Cam.Kicks, i)
		else
			fov += k.Amt * (1 - k.Ease(a))
		end
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cf * CFrame.new(px, py, pz) * CFrame.Angles(rx, ry, rz + rad(Cam.Roll))
	camera.FieldOfView = clamp(fov, 1, 120)
end

function Kit.startCamera()
	Cam.Active = true
	RunService:BindToRenderStep("FC_Camera", Enum.RenderPriority.Camera.Value + 50, cameraStep)
end

function Kit.stopCamera()
	Cam.Active = false
	pcall(function() RunService:UnbindFromRenderStep("FC_Camera") end)
end

-- first-person helper: a camera CFrame from a rig's head
function Kit.headCam(rig, extra)
	local head = rig.Model:FindFirstChild("Head")
	return head.CFrame * CFrame.new(0, 0.25, -0.35) * (extra or CFrame.new())
end

--==================================================
-- SOUND
--==================================================
local soundFolder = Instance.new("Folder")
soundFolder.Name = "FC_Sounds"
soundFolder.Parent = SoundService
Kit.SoundFolder = soundFolder

local function sid(id)
	if type(id) == "number" then return "rbxassetid://" .. id end
	if not tostring(id):find("rbxasset") then return "rbxassetid://" .. id end
	return id
end

function Kit.sfx(id, vol, speed, opts)
	opts = opts or {}
	local s = Instance.new("Sound")
	s.SoundId = sid(id)
	s.Volume = vol or 0.6
	s.PlaybackSpeed = speed or 1
	s.Looped = opts.Looped or false
	if opts.TimePosition then s.TimePosition = opts.TimePosition end
	s.Parent = opts.Parent or soundFolder
	if opts.Reverb then
		local r = Instance.new("ReverbSoundEffect")
		r.DecayTime = opts.Reverb
		r.WetLevel = -4
		r.Parent = s
	end
	if opts.Muffle then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = -30
		eq.MidGain = -12
		eq.LowGain = 4
		eq.Parent = s
	end
	s:Play()
	if not s.Looped then
		s.Ended:Connect(function() s:Destroy() end)
		task.delay(opts.Life or 30, function() if s.Parent then s:Destroy() end end)
	end
	return s
end

function Kit.loop(id, vol, fadeIn, speed)
	local s = Kit.sfx(id, fadeIn and 0 or vol, speed, { Looped = true })
	if fadeIn and fadeIn > 0 then
		TweenService:Create(s, TweenInfo.new(fadeIn, Enum.EasingStyle.Sine), { Volume = vol }):Play()
	end
	s:SetAttribute("TargetVolume", vol)
	return s
end

function Kit.fadeSound(s, vol, time, destroy)
	if not s or not s.Parent then return end
	local tw = TweenService:Create(s, TweenInfo.new(time or 1, Enum.EasingStyle.Sine), { Volume = vol })
	tw:Play()
	if destroy then
		task.delay((time or 1) + 0.05, function() if s.Parent then s:Destroy() end end)
	end
end

function Kit.stopAllSounds(fade)
	for _, s in ipairs(soundFolder:GetChildren()) do
		if s:IsA("Sound") then Kit.fadeSound(s, 0, fade or 0.5, true) end
	end
end

-- a single muffle effect on the whole cutscene mix (space / out-of-body)
local muffleGroup = Instance.new("SoundGroup")
muffleGroup.Name = "FC_Mix"
muffleGroup.Parent = SoundService
local mixEq = Instance.new("EqualizerSoundEffect")
mixEq.HighGain = 0
mixEq.MidGain = 0
mixEq.LowGain = 0
mixEq.Parent = muffleGroup
soundFolder.ChildAdded:Connect(function(c)
	if c:IsA("Sound") and not c:GetAttribute("Dry") then c.SoundGroup = muffleGroup end
end)
function Kit.muffle(amount, time)
	TweenService:Create(mixEq, TweenInfo.new(time or 0.5), { HighGain = -40 * amount, MidGain = -15 * amount, LowGain = 3 * amount }):Play()
end

-- IDs, all from Roblox's licensed libraries (APM / Pro Sound Effects)
Kit.S = {
	-- ambience / wind
	SpaceAmb = 9119392620, Rush = 9125742262, Tunnel = 9119462099, Meadow = 9112777821, Birds = 9112832297,
	Rumble = 9112775414, DarkDrone = 9112795463, Drone = 9043359885, Heartbeat = 9043365842, Ring = 71033223432168,
	-- hits
	Boom = 1837830314, Impact = 6555423202, Whoosh = 116314379282109, FireWhoosh = 9114446852, Hell = 9114795437,
	BigHit = 1843054069, MetalHit = 9041754067, TonalHit = 1835353110, ShipHit = 1835345971,
	Punch = 98168954865521, Punch2 = 123732376743848, Thunder = 112528158781772, Lightning = 93403424380357,
	RockBoom = 114743565978001, BodyFall = 83382878583668, Thump = 72728975467251, Electric = 86261914368076,
	Glass1 = 132535085898211, Glass2 = 132349765576039, Glass3 = 118987440163311,
	-- stings / risers / powers
	Sting = 9044902278, Heist = 9042305931, Riser = 1837831381, Portal = 134847459602515, Portal2 = 109286612583064,
	Cannon = 97082923020121, CutIn = 89786894346774, Overdrive = 101311815784759, GreenAura = 113813942754476,
	Broly = 116363079075797, BeamFire = 92846408037360, Choir = 1840524246,
	StepL = 106672010112184, StepR = 82667401006591,
	-- music (APM / Distrokid, licensed for all experiences)
	M_Doom = 74478562593758, M_Astral = 75226952728672, M_Altitudes = 1838765406, M_Xanadu = 1838772658,
	M_Universe = 1841154386, M_Pulse = 1839410810, M_LowDrone = 1843965739, M_Battle = 9043171221,
	M_Determined = 1836104037, M_Trailer = 1839498813, M_Overture = 1839459610, M_Andromeda = 92667692414358, M_Sad = 122979340200406,
	M_Wonder = 1840904817, M_EpicAnime = 122341436199468,
}

--==================================================
-- SCREEN OVERLAY
--==================================================
local gui = Instance.new("ScreenGui")
gui.Name = "FinalCutsceneGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 600
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = true
gui.Parent = Kit.Player:WaitForChild("PlayerGui")
Kit.Gui = gui

local function frame(name, props, parent)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent or gui
	return f
end
Kit.frame = frame

-- (the bars sit above the fades and flashes, so a coloured fade never washes them out)
Kit.TopBar = frame("TopBar", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 0), ZIndex = 95 })
Kit.BottomBar = frame("BottomBar", { BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), ZIndex = 95 })
-- (a thin glowing edge on the inside of each bar, so they still read as bars
-- against black space; clipped away when the bars are closed)
for _, bar in ipairs({ Kit.TopBar, Kit.BottomBar }) do
	bar.ClipsDescendants = true
	local top = bar == Kit.TopBar
	local edge = frame("Edge", {
		BackgroundColor3 = Color3.fromRGB(120, 100, 170), BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(0, top and 1 or 0), Position = UDim2.fromScale(0, top and 1 or 0),
		Size = UDim2.new(1, 0, 0, 2), ZIndex = 96,
	}, bar)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = edge
end
Kit.Fade = frame("Fade", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 90 })
Kit.Flash = frame("Flash", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 80 })
Kit.Layer = frame("Layer", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40 })

-- soft vignette from four gradient strips
local vig = frame("Vignette", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 })
Kit.Vignette = vig
for i, spec in ipairs({
	{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0), 90 },
	{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), -90 },
	{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0), 0 },
	{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0), 180 },
}) do
	local f = frame("V" .. i, { BackgroundColor3 = Color3.new(0, 0, 0), Size = spec[1], Position = spec[2], ZIndex = 30 }, vig)
	local g = Instance.new("UIGradient")
	g.Rotation = spec[3]
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
end
function Kit.vignette(alpha, color, time)
	for _, f in ipairs(vig:GetChildren()) do
		if f:IsA("Frame") then
			if color then f.BackgroundColor3 = color end
			TweenService:Create(f, TweenInfo.new(time or 0.4), { BackgroundTransparency = 1 - alpha }):Play()
		end
	end
end
Kit.vignette(0, nil, 0)

function Kit.letterbox(on, time)
	local h = on and 0.1 or 0
	TweenService:Create(Kit.TopBar, TweenInfo.new(time or 0.8, Enum.EasingStyle.Quart), { Size = UDim2.fromScale(1, h) }):Play()
	TweenService:Create(Kit.BottomBar, TweenInfo.new(time or 0.8, Enum.EasingStyle.Quart), { Size = UDim2.fromScale(1, h) }):Play()
end

function Kit.fade(to, time, color)
	if color then Kit.Fade.BackgroundColor3 = color end
	if not time or time <= 0 then
		Kit.Fade.BackgroundTransparency = 1 - to
		return
	end
	TweenService:Create(Kit.Fade, TweenInfo.new(time, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 - to }):Play()
end

function Kit.flash(time, color, strength)
	Kit.Flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	Kit.Flash.BackgroundTransparency = 1 - (strength or 1)
	TweenService:Create(Kit.Flash, TweenInfo.new(time or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

--==================================================
-- POST (grade, bloom, blur, sun rays, depth of field)
--==================================================
local function fx(class, name)
	local e = Lighting:FindFirstChild(name)
	if not e then
		e = Instance.new(class)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end
Kit.Grade = fx("ColorCorrectionEffect", "FC_Grade")
Kit.Blur = fx("BlurEffect", "FC_Blur")
Kit.Bloom = fx("BloomEffect", "FC_Bloom")
Kit.Rays = fx("SunRaysEffect", "FC_Rays")
Kit.DOF = fx("DepthOfFieldEffect", "FC_DOF")
Kit.Grade.Enabled = false
Kit.Blur.Size = 0
Kit.Blur.Enabled = false
Kit.Bloom.Enabled = false
Kit.Rays.Enabled = false
Kit.DOF.Enabled = false

function Kit.tween(obj, time, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.InOut), props)
	tw:Play()
	return tw
end

-- a short punch on the grade that settles back
function Kit.gradePunch(contrast, brightness, time, tint)
	local g = Kit.Grade
	local base = { Contrast = g.Contrast, Brightness = g.Brightness, TintColor = g.TintColor }
	g.Contrast = base.Contrast + (contrast or 0.3)
	g.Brightness = base.Brightness + (brightness or 0)
	if tint then g.TintColor = tint end
	Kit.tween(g, time or 0.5, base, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

--==================================================
-- LIGHTING PRESETS
--==================================================
local skies = {}
function Kit.sky(name)
	for _, s in ipairs(Lighting:GetChildren()) do
		if s:IsA("Sky") then s.Parent = nil table.insert(skies, s) end
	end
	local src = Kit.Assets:FindFirstChild(name)
	if not src then return end
	local sky = src:Clone()
	sky.Name = "FC_Sky"
	sky.Parent = Lighting
end

local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmo then
	atmo = Instance.new("Atmosphere")
	atmo.Parent = Lighting
end
Kit.Atmo = atmo

Kit.Presets = {
	Day = {
		Sky = "LaPeaceSky",
		L = { Ambient = Color3.fromRGB(80, 80, 88), OutdoorAmbient = Color3.fromRGB(120, 124, 130), Brightness = 3, ClockTime = 14, FogColor = Color3.fromRGB(192, 200, 214), FogEnd = 100000, FogStart = 0, ExposureCompensation = 0, EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1 },
		A = { Density = 0.24, Offset = 0.05, Color = Color3.fromRGB(212, 228, 248), Decay = Color3.fromRGB(126, 150, 194), Glare = 0.16, Haze = 0.5 },
		Bloom = { Intensity = 0.6, Size = 24, Threshold = 1.4 },
		Grade = { Brightness = 0, Contrast = 0.08, Saturation = 0.1, TintColor = Color3.new(1, 1, 1) },
	},
	Storm = {
		Sky = "LaPeaceSky",
		L = { Ambient = Color3.fromRGB(82, 62, 118), OutdoorAmbient = Color3.fromRGB(128, 102, 178), Brightness = 1.6, ClockTime = 19.5, FogColor = Color3.fromRGB(40, 20, 60), FogEnd = 6000, FogStart = 0, ExposureCompensation = 0.3 },
		A = { Density = 0.3, Offset = 0.1, Color = Color3.fromRGB(90, 45, 130), Decay = Color3.fromRGB(40, 12, 70), Glare = 0, Haze = 1.2 },
		Bloom = { Intensity = 0.9, Size = 30, Threshold = 1.25 },
		Grade = { Brightness = 0, Contrast = 0.22, Saturation = -0.05, TintColor = Color3.fromRGB(240, 222, 255) },
	},
	Sky = {
		Sky = "LaPeaceSky",
		L = { Ambient = Color3.fromRGB(90, 100, 130), OutdoorAmbient = Color3.fromRGB(130, 150, 190), Brightness = 3.2, ClockTime = 13, FogColor = Color3.fromRGB(170, 200, 240), FogEnd = 100000, FogStart = 0, ExposureCompensation = 0.1 },
		A = { Density = 0.3, Offset = 0.2, Color = Color3.fromRGB(190, 215, 255), Decay = Color3.fromRGB(90, 130, 210), Glare = 0.4, Haze = 1.2 },
		Bloom = { Intensity = 0.9, Size = 28, Threshold = 1.2 },
		Grade = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.15, TintColor = Color3.new(1, 1, 1) },
	},
	Upper = {
		Sky = "LaPeaceSky",
		L = { Ambient = Color3.fromRGB(70, 80, 105), OutdoorAmbient = Color3.fromRGB(120, 135, 165), Brightness = 3.4, ClockTime = 14.5, FogColor = Color3.fromRGB(170, 200, 240), FogEnd = 100000, FogStart = 0, ExposureCompensation = 0.05 },
		A = { Density = 0.12, Offset = 0.2, Color = Color3.fromRGB(190, 215, 255), Decay = Color3.fromRGB(90, 130, 210), Glare = 0.3, Haze = 0.4 },
		Bloom = { Intensity = 0.9, Size = 30, Threshold = 1.15 },
		Grade = { Brightness = 0, Contrast = 0.12, Saturation = 0.12, TintColor = Color3.new(1, 1, 1) },
	},
	Space = {
		Sky = "SolarSky",
		L = { Ambient = Color3.fromRGB(62, 62, 76), OutdoorAmbient = Color3.fromRGB(92, 92, 108), Brightness = 3.6, ClockTime = 15.6, GeographicLatitude = 0, FogColor = Color3.new(0, 0, 0), FogEnd = 100000, FogStart = 0, ExposureCompensation = 0.1 },
		-- (the real sun sits exactly where the Sun is, so every world has a lit day side and a black night side)
		A = { Density = 0, Offset = 0, Color = Color3.new(0, 0, 0), Decay = Color3.new(0, 0, 0), Glare = 0, Haze = 0 },
		Bloom = { Intensity = 0.7, Size = 30, Threshold = 1.25 },
		Grade = { Brightness = 0, Contrast = 0.18, Saturation = 0.12, TintColor = Color3.new(1, 1, 1) },
	},
	Hole = {
		Sky = "SpaceSky",
		L = { Ambient = Color3.fromRGB(40, 28, 18), OutdoorAmbient = Color3.fromRGB(70, 48, 30), Brightness = 7, ClockTime = 3.6, FogColor = Color3.new(0, 0, 0), FogEnd = 100000, FogStart = 0, ExposureCompensation = 0.1 },
		A = { Density = 0, Offset = 0, Color = Color3.new(0, 0, 0), Decay = Color3.new(0, 0, 0), Glare = 0, Haze = 0 },
		Bloom = { Intensity = 1.1, Size = 40, Threshold = 1.05 },
		Grade = { Brightness = 0, Contrast = 0.25, Saturation = 0.05, TintColor = Color3.fromRGB(255, 238, 220) },
	},
	Anti = {
		Sky = "SpaceSky",
		L = { Ambient = Color3.fromRGB(34, 26, 60), OutdoorAmbient = Color3.fromRGB(44, 34, 80), Brightness = 1.8, ClockTime = 0, FogColor = Color3.fromRGB(8, 4, 20), FogEnd = 100000, FogStart = 0, ExposureCompensation = 0 },
		A = { Density = 0, Offset = 0, Color = Color3.new(0, 0, 0), Decay = Color3.new(0, 0, 0), Glare = 0, Haze = 0 },
		Bloom = { Intensity = 1.4, Size = 36, Threshold = 1 },
		Grade = { Brightness = 0, Contrast = 0.2, Saturation = 0.15, TintColor = Color3.fromRGB(236, 228, 255) },
	},
	-- inside the soul: a dark red body-haze that swallows the distance
	Inner = {
		L = { Ambient = Color3.fromRGB(42, 10, 15), OutdoorAmbient = Color3.fromRGB(36, 8, 12), Brightness = 0.5, ClockTime = 0, FogColor = Color3.fromRGB(30, 2, 6), FogEnd = 100000, FogStart = 0, ExposureCompensation = 0 },
		A = { Density = 0.42, Offset = 0, Color = Color3.fromRGB(95, 10, 22), Decay = Color3.fromRGB(40, 0, 8), Glare = 0, Haze = 1.5 },
		Bloom = { Intensity = 0.75, Size = 28, Threshold = 1.1 },
		Grade = { Brightness = 0, Contrast = 0.25, Saturation = 0.1, TintColor = Color3.new(1, 1, 1) },
	},
	Arena = {
		-- (the Galaxy Realm's purple nebula sky. Roblox dims a skybox at night, so the
		-- realm keeps a daytime clock; its sun disc is hidden in the sky itself)
		Sky = "RealmSky",
		-- (exposure down: the gold floor, the shrine and the halo are all additive and
		-- blew out to white at 0; the ambient comes up so the people don't go dark)
		L = { Ambient = Color3.fromRGB(84, 68, 120), OutdoorAmbient = Color3.fromRGB(104, 80, 140), Brightness = 1.2, ClockTime = 14, FogColor = Color3.fromRGB(10, 6, 20), FogEnd = 100000, FogStart = 0, ExposureCompensation = -0.55 },
		A = { Density = 0, Offset = 0, Color = Color3.new(0, 0, 0), Decay = Color3.new(0, 0, 0), Glare = 0, Haze = 0 },
		Bloom = { Intensity = 0.55, Size = 28, Threshold = 1.2 },
		Grade = { Brightness = 0, Contrast = 0.1, Saturation = 0.1, TintColor = Color3.new(1, 1, 1) },
	},
}

function Kit.lightDir()
	local sd = Lighting:GetSunDirection()
	if sd.Y < -0.02 then return Lighting:GetMoonDirection() end
	return sd
end

function Kit.lighting(name, time)
	local p = Kit.Presets[name]
	if not p then return end
	time = time or 0
	if p.Sky then Kit.sky(p.Sky) end
	Kit.Grade.Enabled = true
	Kit.Bloom.Enabled = true
	-- a new look always wins over one still blending in
	for _, tw in ipairs(Kit._lightTweens or {}) do tw:Cancel() end
	Kit._lightTweens = {}
	if time <= 0 then
		for k, v in pairs(p.L) do pcall(function() Lighting[k] = v end) end
		for k, v in pairs(p.A) do atmo[k] = v end
		for k, v in pairs(p.Bloom) do Kit.Bloom[k] = v end
		for k, v in pairs(p.Grade) do Kit.Grade[k] = v end
	else
		Kit._lightTweens = {
			Kit.tween(Lighting, time, p.L),
			Kit.tween(atmo, time, p.A),
			Kit.tween(Kit.Bloom, time, p.Bloom),
			Kit.tween(Kit.Grade, time, p.Grade),
		}
	end
end

-- saved so the fight gets the right sky even if the cutscene is interrupted
local savedLighting
function Kit.captureLighting()
	savedLighting = {}
	for _, k in ipairs({ "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "FogColor", "FogEnd", "FogStart", "ExposureCompensation" }) do
		savedLighting[k] = Lighting[k]
	end
	for _, e in ipairs(Lighting:GetChildren()) do
		if (e:IsA("PostEffect") or e:IsA("SunRaysEffect")) and not e.Name:find("^FC_") then
			e:SetAttribute("FC_WasEnabled", e.Enabled)
			e.Enabled = false
		end
	end
end
function Kit.releasePost()
	for _, e in ipairs(Lighting:GetChildren()) do
		local was = e:GetAttribute("FC_WasEnabled")
		if was ~= nil then
			e.Enabled = was
			e:SetAttribute("FC_WasEnabled", nil)
		end
	end
	Kit.Blur.Enabled = false
	Kit.DOF.Enabled = false
	Kit.Rays.Enabled = false
end

--==================================================
-- WORLD HELPERS
--==================================================
function Kit.part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end

-- a flat textured quad drawn with a Beam (additive when LightEmission = 1).
-- The quad is centred on cf, spans cf.XVector (w) and cf.YVector (h)
-- and faces along cf.LookVector.
function Kit.quad(host, cf, w, h, tex, opts)
	opts = opts or {}
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	local rel = host.CFrame:ToObjectSpace(cf)
	a0.CFrame = rel * CFrame.new(-w / 2, 0, 0)
	a1.CFrame = rel * CFrame.new(w / 2, 0, 0)
	local b = Instance.new("Beam")
	b.TextureSpeed = 0
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.Segments = 1
	b.FaceCamera = false
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = h
	b.Width1 = h
	b.Texture = tex and sid(tex) or ""
	b.LightEmission = opts.Emission or 1
	b.LightInfluence = opts.Influence or 0
	b.Brightness = opts.Brightness or 1
	b.ZOffset = opts.ZOffset or 0
	local tr = opts.Transparency or 0
	b.Transparency = typeof(tr) == "NumberSequence" and tr or NumberSequence.new(tr)
	b.Color = ColorSequence.new(opts.Color or Color3.new(1, 1, 1))
	a0.Parent = host
	a1.Parent = host
	b.Parent = host
	return b, a0, a1
end

-- move an existing quad (keeps its size)
local warnedQuad = false
function Kit.moveQuad(beam, cf)
	if not beam then
		if not warnedQuad then warnedQuad = true warn("[moveQuad] nil beam\n" .. debug.traceback()) end
		return
	end
	local host = beam.Attachment0.Parent
	local rel = host.CFrame:ToObjectSpace(cf)
	local w = (beam.Attachment1.Position - beam.Attachment0.Position).Magnitude
	beam.Attachment0.CFrame = rel * CFrame.new(-w / 2, 0, 0)
	beam.Attachment1.CFrame = rel * CFrame.new(w / 2, 0, 0)
end

function Kit.setQuadSize(beam, w, h)
	local a0, a1 = beam.Attachment0, beam.Attachment1
	local mid = a0.CFrame:Lerp(a1.CFrame, 0.5)
	a0.CFrame = mid * CFrame.new(-w / 2, 0, 0)
	a1.CFrame = mid * CFrame.new(w / 2, 0, 0)
	beam.Width0 = h
	beam.Width1 = h
end

-- a beam between two world points (for light shafts / streaks)
function Kit.ray(host, p0, p1, width0, width1, tex, opts)
	opts = opts or {}
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	a0.WorldPosition = p0
	a1.WorldPosition = p1
	a0.Parent = host
	a1.Parent = host
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = width0
	b.Width1 = width1 or width0
	b.FaceCamera = opts.FaceCamera ~= false
	b.Texture = tex and sid(tex) or ""
	b.TextureSpeed = opts.Speed or 0
	b.TextureMode = opts.Mode or Enum.TextureMode.Stretch
	b.TextureLength = opts.Length or 1
	b.LightEmission = opts.Emission or 1
	b.LightInfluence = 0
	b.Brightness = opts.Brightness or 1
	b.Segments = opts.Segments or 10
	local tr = opts.Transparency or 0
	b.Transparency = typeof(tr) == "NumberSequence" and tr or NumberSequence.new(tr)
	b.Color = ColorSequence.new(opts.Color or Color3.new(1, 1, 1))
	b.Parent = host
	return b, a0, a1
end

function Kit.ns(...)
	local args = { ... }
	if #args == 1 then return NumberSequence.new(args[1]) end
	local kps = {}
	for i = 1, #args, 2 do table.insert(kps, NumberSequenceKeypoint.new(args[i], args[i + 1])) end
	if #kps == 1 then return NumberSequence.new(kps[1].Value) end
	if kps[1].Time > 0 then table.insert(kps, 1, NumberSequenceKeypoint.new(0, kps[1].Value)) end
	if kps[#kps].Time < 1 then table.insert(kps, NumberSequenceKeypoint.new(1, kps[#kps].Value)) end
	return NumberSequence.new(kps)
end

function Kit.emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.LightEmission = 1
	e.Rate = 0
	for k, v in pairs(props) do
		if k == "Texture" then v = sid(v) end
		e[k] = v
	end
	-- (these textures are sprite sheets: without the layout every particle shows the
	-- whole grid of frames as a little square of dots)
	if not props.FlipbookLayout then
		if e.Texture:find("17000879366") then
			e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			e.FlipbookMode = Enum.ParticleFlipbookMode.Random
		elseif e.Texture:find("11381556016") then
			e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
			e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
	end
	e.Parent = parent
	return e
end

-- clone a pack VFX by name from Assets.VFX, drop it at cf and fire it
function Kit.vfx(name, cf, parent, scale, count, life)
	local src = Kit.Assets:FindFirstChild("VFX") and Kit.Assets.VFX:FindFirstChild(name, true)
	if not src then return end
	local c = src:Clone()
	local host
	if c:IsA("BasePart") then
		host = c
	else
		host = Instance.new("Part")
		host.Size = Vector3.new(1, 1, 1)
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("ParticleEmitter") or d:IsA("Attachment") then
				if d.Parent:IsA("BasePart") or d.Parent == c then d.Parent = host end
			end
		end
		c:Destroy()
	end
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.CFrame = cf
	host.Parent = parent or workspace
	scale = scale or 1
	for _, d in ipairs(host:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			if scale ~= 1 then
				local kps = {}
				for _, k in ipairs(d.Size.Keypoints) do table.insert(kps, NumberSequenceKeypoint.new(k.Time, k.Value * scale, k.Envelope * scale)) end
				d.Size = NumberSequence.new(kps)
				d.Speed = NumberRange.new(d.Speed.Min * scale, d.Speed.Max * scale)
			end
			d.Enabled = false
			d:Emit(count or d:GetAttribute("EmitCount") or 12)
		end
	end
	task.delay(life or 6, function() host:Destroy() end)
	return host
end

-- scale a particle emitter's size + speed (for reused emitters)
function Kit.scaleEmitter(e, s)
	local kps = {}
	for _, k in ipairs(e.Size.Keypoints) do table.insert(kps, NumberSequenceKeypoint.new(k.Time, k.Value * s, k.Envelope * s)) end
	e.Size = NumberSequence.new(kps)
	e.Speed = NumberRange.new(e.Speed.Min * s, e.Speed.Max * s)
end

--==================================================
-- SKY DOME
-- A box of solid-colour beams that follows the camera, used to
-- darken the sky from blue to black while climbing through the
-- atmosphere (the Roblox day sky can't be darkened on its own).
-- Faces are vertical gradients: horizon colour -> zenith colour,
-- with a star layer that fades in on top.
--==================================================
function Kit.dome(parent, dist)
	dist = dist or 3400
	local host = Kit.part({ Name = "DomeHost", Size = Vector3.one, Transparency = 1 }, parent)
	-- a real sky DOME (a sphere of trapezoid beams, 16 around x 8 bands from the
	-- nadir to the zenith) instead of a drum with a flat lid: no corners or flat
	-- faces anywhere, the horizon is a smooth circle whichever way you look
	local d = { Host = host, Dist = dist, Bands = {}, AZ = 32 }
	d.EL = { -90, -58, -30, -10, 4, 20, 40, 64, 90 }
	local function beam(tex, emission)
		local a0 = Instance.new("Attachment")
		local a1 = Instance.new("Attachment")
		a0.Parent = host
		a1.Parent = host
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.FaceCamera = false
		b.Segments = 1
		b.TextureSpeed = 0
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureLength = 1
		b.Texture = tex and sid(tex) or ""
		b.LightEmission = emission
		b.LightInfluence = 0
		b.Brightness = 1
		b.Transparency = NumberSequence.new(1)
		b.Parent = host
		return b
	end
	for j = 1, #d.EL - 1 do
		local row = {}
		for i = 1, d.AZ do
			local b = beam(nil, 0)
			b.Segments = 6 -- colour/transparency are only sampled at segment points
			b.ZOffset = -600 -- sort behind the sun/glow sprites that sit inside the dome
			row[i] = b
		end
		d.Bands[j] = row
	end
	-- stars: tiny additive sparks on a sphere that rides above the camera
	-- (locked to it, so they sit at "infinity"); only above the horizon
	local starHost = Kit.part({ Name = "StarHost", Size = Vector3.new(2048, 2048, 2048), Transparency = 1 }, parent)
	d.StarHost = starHost
	d.Stars = {}
	for k, col in ipairs({ Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 215, 255), Color3.fromRGB(255, 236, 205) }) do
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(col)
		e.Size = NumberSequence.new(k == 1 and 4.5 or 3.5)
		e.Transparency = NumberSequence.new(1)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Brightness = k == 1 and 3 or 2.2
		e.Lifetime = NumberRange.new(20) -- (the engine caps particle life at 20s; they're re-sown)
		e.Speed = NumberRange.new(0)
		e.Rate = 0
		e.Rotation = NumberRange.new(0, 360)
		e.LockedToPart = true
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapePartial = 0.5
		e.EmissionDirection = Enum.NormalId.Top
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ZOffset = -1
		e.Parent = starHost
		d.Stars[k] = { E = e, N = k == 1 and 900 or 350 }
	end
	d.Sun = beam("116996021489973", 1)
	d.SunGlow = beam("rbxasset://sky/sun.jpg", 1)
	return d
end

local function placeBeam(b, p0, p1, widthAxis, width, width1)
	local len = p1 - p0
	b.Attachment0.WorldCFrame = CFrame.fromMatrix(p0, len.Unit, widthAxis)
	b.Attachment1.WorldCFrame = CFrame.fromMatrix(p1, len.Unit, widthAxis)
	b.Width0 = width
	b.Width1 = width1 or width
end

-- horizon/zenith: Color3; alpha: 0 (clear) .. 1 (fully painted); stars 0..1
function Kit.domeUpdate(d, camPos, horizon, zenith, alpha, stars, sunDir, sunAlpha, bottomAlpha, horizonDip)
	local D = d.Dist
	local up = Vector3.yAxis
	local rad = math.rad
	bottomAlpha = bottomAlpha or 0
	-- high up, the real horizon of a round world sits below eye level (horizonDip,
	-- degrees): the whole sky gradient is re-laid so its horizon band sits on it,
	-- and the rows of the dome are placed round that horizon so the fade across
	-- it is smooth instead of cut by a straight panel edge
	local h = -math.max(horizonDip or 0, 0)
	-- below the horizon the haze fades out over a band that tightens as you climb:
	-- down low it's a wide soft fade (no hard rim looking down), up high it hugs the
	-- edge of the world so the curve of the planet stays clear
	local s = math.clamp((-h - 2) / 10, 0, 1)
	local fadeTop = -10 + 9 * s
	local fadeBot = fadeTop - (20 - 13 * s)
	local EL = { -90, h - 34, h + fadeBot * (90 - h) / 90, h + fadeTop * (90 - h) / 90, h + 4, h + 20, 0, 0, 90 }
	EL[7] = EL[6] + (90 - EL[6]) * 0.35
	EL[8] = EL[6] + (90 - EL[6]) * 0.68
	local function shift(el)
		if el >= 90 then return 90 end
		return (el - h) * 90 / (90 - h)
	end
	local function colAt(el)
		el = shift(el)
		if el <= 4 then return horizon end
		return horizon:Lerp(zenith, math.clamp((el - 4) / 60, 0, 1) ^ 0.8)
	end
	local function trAt(el)
		el = shift(el)
		-- below the horizon the sky fades out (or into the floor haze), so looking
		-- down never shows a hard rim
		if el >= 4 then return 1 - alpha * (el >= 20 and 1 or 0.9 + 0.1 * (el - 4) / 16) end
		if el >= fadeTop then return 1 - alpha * (0.85 + 0.05 * (el - fadeTop) / (4 - fadeTop)) end
		local sky = el >= fadeBot and (1 - alpha * 0.85 * (el - fadeBot) / (fadeTop - fadeBot)) or 1
		local floor = 1 - bottomAlpha * math.clamp((-10 - el) / 30, 0, 1)
		return math.min(sky, floor)
	end
	local n = d.AZ
	local half = math.pi / n
	for j, row in ipairs(d.Bands) do
		local e0, e1 = EL[j], EL[j + 1]
		local c0, c1 = colAt(e0), colAt(e1)
		local cs = ColorSequence.new(c0, c1)
		if shift(e0) < fadeTop then cs = ColorSequence.new(horizon) end
		local ts = NumberSequence.new(math.clamp(trAt(e0), 0, 1), math.clamp(trAt(e1), 0, 1))
		local r0, r1 = D * math.cos(rad(e0)), D * math.cos(rad(e1))
		local y0, y1 = D * math.sin(rad(e0)), D * math.sin(rad(e1))
		for i, b in ipairs(row) do
			local a = (i - 0.5) * 2 * half
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local tan = Vector3.new(-math.sin(a), 0, math.cos(a))
			-- chords of the two latitude circles: a flat trapezoid on the sphere
			local p0 = camPos + dir * (r0 * math.cos(half)) + up * y0
			local p1 = camPos + dir * (r1 * math.cos(half)) + up * y1
			-- (exactly the chord: neighbouring panels meet edge to edge. Overlapping
			-- them doubled the haze along every seam and drew dark lines on the sky)
			placeBeam(b, p0, p1, tan, 2 * r0 * math.sin(half) + 0.2, 2 * r1 * math.sin(half) + 0.2)
			b.Color = cs
			b.Transparency = ts
		end
	end
	-- stars on the upper half-sphere
	d.StarHost.CFrame = CFrame.new(camPos)
	if stars > 0.01 and (not d.StarsAt or os.clock() - d.StarsAt > 18) then
		d.StarsAt = os.clock()
		for _, s in ipairs(d.Stars) do s.E:Emit(s.N) end
	end
	for _, s in ipairs(d.Stars) do s.E.Transparency = NumberSequence.new(1 - math.clamp(stars, 0, 1) * 0.95) end
	-- a sun sprite inside the dome
	sunDir = sunDir or Kit.lightDir()
	sunAlpha = sunAlpha or 0
	local sp = camPos + sunDir * D * 0.55 -- well inside the dome, so the walls never clip the glow
	local right = sunDir:Cross(up).Magnitude > 0.01 and sunDir:Cross(up).Unit or Vector3.xAxis
	local s1 = 250
	placeBeam(d.Sun, sp - right * s1 / 2, sp + right * s1 / 2, sunDir:Cross(right).Unit, s1)
	d.Sun.Transparency = NumberSequence.new(1 - sunAlpha)
	d.Sun.Color = ColorSequence.new(Color3.fromRGB(255, 248, 235))
	d.Sun.Brightness = 3
	local s2 = 1100
	placeBeam(d.SunGlow, sp - right * s2 / 2, sp + right * s2 / 2, sunDir:Cross(right).Unit, s2)
	d.SunGlow.Transparency = NumberSequence.new(1 - sunAlpha)
	d.SunGlow.Color = ColorSequence.new(Color3.fromRGB(255, 230, 190))
end

-- a full sphere of stars riding on the camera (for open space). ZOffset pushes
-- them far back so planets and the Earth still cover them.
function Kit.starShell(parent)
	local host = Kit.part({ Name = "StarShell", Size = Vector3.new(2048, 2048, 2048), Transparency = 1 }, parent)
	local sh = { Host = host, E = {} }
	for k, col in ipairs({ Color3.fromRGB(255, 255, 255), Color3.fromRGB(185, 210, 255), Color3.fromRGB(255, 230, 200) }) do
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(col)
		e.Size = NumberSequence.new(k == 1 and 4.5 or 3.5)
		e.Transparency = NumberSequence.new(1)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Brightness = k == 1 and 3 or 2.2
		e.Lifetime = NumberRange.new(20)
		e.Speed = NumberRange.new(0)
		e.Rate = 0
		e.Rotation = NumberRange.new(0, 360)
		e.LockedToPart = true
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ZOffset = -1500
		e.Parent = host
		sh.E[k] = { E = e, N = k == 1 and 1400 or 500 }
	end
	return sh
end
function Kit.starShellUpdate(sh, camPos, alpha)
	sh.Host.CFrame = CFrame.new(camPos)
	if alpha > 0.01 and (not sh.At or os.clock() - sh.At > 18) then
		sh.At = os.clock()
		for _, s in ipairs(sh.E) do s.E:Emit(s.N) end
	end
	for _, s in ipairs(sh.E) do s.E.Transparency = NumberSequence.new(1 - math.clamp(alpha, 0, 1) * 0.95) end
end

function Kit.domeHide(d)
	for _, row in ipairs(d.Bands) do
		for _, b in ipairs(row) do b.Transparency = NumberSequence.new(1) end
	end
	for _, s in ipairs(d.Stars) do s.E.Transparency = NumberSequence.new(1) end
	d.Sun.Transparency = NumberSequence.new(1)
	d.SunGlow.Transparency = NumberSequence.new(1)
end

--==================================================
-- IMPACT FRAMES
-- A camera-locked card behind the subjects plus solid
-- Highlights on them, cycling through colour patterns:
-- the classic black/white/red anime smear frame.
--==================================================
local IMPACT_PATTERNS = {
	W = { Card = Color3.new(1, 1, 1), Fill = Color3.new(0, 0, 0) },
	B = { Card = Color3.new(0, 0, 0), Fill = Color3.new(1, 1, 1) },
	R = { Card = Color3.fromRGB(255, 20, 40), Fill = Color3.new(0, 0, 0) },
	G = { Card = Color3.fromRGB(40, 255, 110), Fill = Color3.new(0, 0, 0) },
	V = { Card = Color3.fromRGB(150, 60, 255), Fill = Color3.new(1, 1, 1) },
	Y = { Card = Color3.fromRGB(255, 205, 60), Fill = Color3.new(0, 0, 0) },
}
Kit.SpeedLines = "rbxassetid://105323735180936"
Kit.Burst = "rbxassetid://88412276952555"

function Kit.impact(subjects, pattern, frameTime, opts)
	opts = opts or {}
	frameTime = frameTime or 0.06
	local card = Kit.part({ Name = "FC_ImpactCard", Size = Vector3.new(3000, 3000, 1), Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1) }, workspace)
	local highs = {}
	for _, m in ipairs(subjects) do
		if m and m.Parent then
			local h = Instance.new("Highlight")
			h.FillTransparency = 0
			h.OutlineTransparency = opts.Outline and 0 or 1
			h.OutlineColor = Color3.new(1, 1, 1)
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Adornee = m
			h.Parent = m
			table.insert(highs, h)
		end
	end
	local lines = Instance.new("ImageLabel")
	lines.BackgroundTransparency = 1
	lines.Image = Kit.SpeedLines
	lines.AnchorPoint = Vector2.new(0.5, 0.5)
	lines.Position = UDim2.fromScale(0.5, 0.5)
	lines.Size = UDim2.fromScale(1.6, 1.6)
	lines.SizeConstraint = Enum.SizeConstraint.RelativeXX
	lines.ZIndex = 45
	lines.ImageTransparency = opts.Lines == false and 1 or 0.1
	lines.Parent = gui
	local dist = opts.Distance
	if not dist then
		dist = 60
		for _, m in ipairs(subjects) do
			if m and m.Parent then
				local ok, cf = pcall(function() return m:GetPivot() end)
				if ok then dist = math.max(dist, (cf.Position - camera.CFrame.Position).Magnitude + 40) end
			end
		end
	end
	dist = math.min(dist, 2500)
	local conn = RunService.RenderStepped:Connect(function()
		card.CFrame = camera.CFrame * CFrame.new(0, 0, -dist)
		lines.Rotation = math.random(0, 360)
	end)
	for _, key in ipairs(string.split(pattern or "WBW", "")) do
		local p = IMPACT_PATTERNS[key] or IMPACT_PATTERNS.W
		card.Color = p.Card
		for _, h in ipairs(highs) do h.FillColor = p.Fill end
		lines.ImageColor3 = p.Fill
		task.wait(frameTime)
	end
	conn:Disconnect()
	card:Destroy()
	lines:Destroy()
	for _, h in ipairs(highs) do h:Destroy() end
end

--==================================================
-- TEXT
--==================================================
Kit.Fonts = {
	Boss = Font.new("rbxasset://fonts/families/GrenzeGotisch.json", Enum.FontWeight.Heavy),
	Shout = Font.new("rbxasset://fonts/families/Bangers.json", Enum.FontWeight.Regular),
	Title = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Regular),
	Clean = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
}

local measureCache = {}
local function measure(char, font, size)
	local key = char .. tostring(font.Family) .. size
	if measureCache[key] then return measureCache[key] end
	local params = Instance.new("GetTextBoundsParams")
	params.Text = char
	params.Font = font
	params.Size = size
	params.Width = 10000
	local ok, v = pcall(function() return TextService:GetTextBoundsAsync(params) end)
	local w = ok and v.X or size * 0.6
	if char == " " then w = size * 0.32 end
	measureCache[key] = w
	return w
end

local function viewport() return camera.ViewportSize end

-- Dialogue in the "crazy" style: every letter slams in on its own
-- with a chromatic split, then twitches while it holds, then the
-- line shatters upward. Returns once the line is gone.
function Kit.say(text, hold, style)
	style = style or {}
	local font = style.Font or Kit.Fonts.Boss
	local vp = viewport()
	local size = math.floor(math.clamp(vp.Y * (style.Scale or 0.075), 26, 110))
	local holder = frame("Say", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = style.Position or UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromOffset(vp.X, size * 3),
		ZIndex = 60,
	}, Kit.Layer)
	local lines = string.split(text, "\n")
	local letters = {}
	local lineGap = size * 1.05
	local top = -(#lines - 1) * lineGap / 2
	for li, line in ipairs(lines) do
		local widths, total = {}, 0
		for c in line:gmatch(utf8.charpattern) do
			local w = measure(c, font, size) * 1.02
			table.insert(widths, { c, w })
			total += w
		end
		local x = -total / 2
		for _, cw in ipairs(widths) do
			local c, w = cw[1], cw[2]
			if c ~= " " then
				local base = UDim2.new(0.5, x + w / 2, 0.5, top + (li - 1) * lineGap)
				local function mk(color, z, tr)
					local l = Instance.new("TextLabel")
					l.BackgroundTransparency = 1
					l.AnchorPoint = Vector2.new(0.5, 0.5)
					l.Size = UDim2.fromOffset(w * 1.6, size * 1.4)
					l.Position = base
					l.FontFace = font
					l.TextSize = size
					l.Text = c
					l.TextColor3 = color
					l.TextTransparency = 1
					l.ZIndex = z
					l.Parent = holder
					return l
				end
				local red = mk(style.SplitA or Color3.fromRGB(255, 40, 90), 61, 0.35)
				local cyan = mk(style.SplitB or Color3.fromRGB(60, 220, 255), 61, 0.35)
				local main = mk(style.Color or Color3.new(1, 1, 1), 62, 0)
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = style.Stroke or math.max(2, size / 22)
				stroke.Color = style.StrokeColor or Color3.new(0, 0, 0)
				stroke.Transparency = 1
				stroke.Parent = main
				local grad = Instance.new("UIGradient")
				grad.Color = style.Gradient or ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.55, Color3.fromRGB(205, 225, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 110, 255)),
				})
				grad.Rotation = 90
				grad.Parent = main
				local scale = Instance.new("UIScale")
				scale.Scale = 3
				scale.Parent = main
				table.insert(letters, { Main = main, Red = red, Cyan = cyan, Stroke = stroke, Scale = scale, Base = base })
			end
			x += w
		end
	end
	-- slam in
	local per = style.Per or 0.03
	for i, L in ipairs(letters) do
		task.delay((i - 1) * per, function()
			L.Main.Rotation = math.random(-25, 25)
			TweenService:Create(L.Scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			TweenService:Create(L.Main, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { TextTransparency = 0, Rotation = 0 }):Play()
			TweenService:Create(L.Stroke, TweenInfo.new(0.18), { Transparency = 0 }):Play()
			L.Red.TextTransparency = 0.35
			L.Cyan.TextTransparency = 0.35
		end)
	end
	if style.Sound ~= false then
		Kit.sfx(style.SoundId or Kit.S.Sting, 0.45, 0.9)
	end
	-- twitch while holding
	local alive = true
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local glitch = (math.random() < 0.06) and 1 or 0
		for i, L in ipairs(letters) do
			local j = (math.noise(t * 6, i) * 2) + glitch * math.random(-6, 6)
			L.Main.Position = L.Base + UDim2.fromOffset(j * 0.4, math.noise(i, t * 5) * 1.5)
			local s = 2 + math.sin(t * 9 + i) * 1.5 + glitch * 6
			L.Red.Position = L.Base + UDim2.fromOffset(-s, 0)
			L.Cyan.Position = L.Base + UDim2.fromOffset(s, glitch * 2)
		end
	end)
	task.wait(#letters * per + (hold or 2.5))
	-- shatter out
	for i, L in ipairs(letters) do
		local dir = UDim2.fromOffset(math.random(-60, 60), -math.random(40, 140))
		for _, l in ipairs({ L.Main, L.Red, L.Cyan }) do
			TweenService:Create(l, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, Position = L.Base + dir, Rotation = math.random(-90, 90) }):Play()
		end
		TweenService:Create(L.Stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end
	task.wait(0.5)
	alive = false
	conn:Disconnect()
	holder:Destroy()
end

--==================================================
-- RIGS
-- R6 stand-ins built by the server from each player's
-- HumanoidDescription (FinalCutscene.Avatars.<UserId>).
-- Procedural posing edits Motor6D.C0 on top of whatever
-- animation track is playing, so a walk cycle and a hand-
-- authored arm pose can run together.
--==================================================
local ANIMS = {
	Idle = 180435571, Look = 180435792, Walk = 180426354, Run = 180426354, Jump = 125750702,
	Fall = 180436148, Climb = 180436334, Sit = 178130996, Wave = 128777973, Point = 128853357,
	Dance1 = 182435998, Dance2 = 182436842, Dance3 = 182436935, Cheer = 129423030, Laugh = 129423131,
	Dance1b = 182491037, Dance2b = 182491248, Dance3b = 182491368,
}
Kit.ANIMS = ANIMS

local JOINTS = { Neck = "Neck", RS = "Right Shoulder", LS = "Left Shoulder", RH = "Right Hip", LH = "Left Hip" }

local Rig = {}
Rig.__index = Rig

function Kit.rig(userId, parent)
	local src = Kit.FC:FindFirstChild("Avatars") and Kit.FC.Avatars:FindFirstChild(tostring(userId))
	if not src then
		src = Kit.FC.Avatars and Kit.FC.Avatars:WaitForChild(tostring(userId), 4)
	end
	src = src or Kit.Assets:FindFirstChild("FallbackR6")
	local model = src:Clone()
	model.Name = "FC_Rig_" .. tostring(userId)
	local self = setmetatable({}, Rig)
	self.Model = model
	self.Root = model:WaitForChild("HumanoidRootPart")
	self.Torso = model:WaitForChild("Torso")
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	self.Root.Anchored = true
	self.Root.Transparency = 1
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = true
			if d ~= self.Root then d.Anchored = false end
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	if self.Humanoid then
		self.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		self.Humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		self.Humanoid.PlatformStand = true
		self.Humanoid.RequiresNeck = false
		self.Humanoid.BreakJointsOnDeath = false
		self.Animator = self.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", self.Humanoid)
	end
	self.J = {}
	self.Base = {}
	for key, name in pairs(JOINTS) do
		local m = self.Torso:FindFirstChild(name)
		if m then
			self.J[key] = m
			self.Base[key] = m.C0
		end
	end
	local rootJoint = self.Root:FindFirstChild("RootJoint")
	if rootJoint then
		self.J.Root = rootJoint
		self.Base.Root = rootJoint.C0
	end
	self.Pose = {}
	self.Tracks = {}
	self.Parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= self.Root then table.insert(self.Parts, d) end
	end
	model.Parent = parent or workspace
	return self
end

-- joint offsets as rotations expressed in the parent part's space
function Rig:set(key, rot)
	self.Pose[key] = rot
end

function Rig:setPose(pose)
	local copy = {}
	for k, v in pairs(pose) do copy[k] = v end
	self.Pose = copy
end

function Rig:clearPose()
	self.Pose = {}
end

-- joints ease toward their target pose (critically-damped feel) so
-- procedural poses never snap; apply(true) snaps (camera cuts etc.)
local IDENT = CFrame.new()
function Rig:apply(snap)
	local now = os.clock()
	local dt = self.LastApply and (now - self.LastApply) or nil
	self.LastApply = now
	local a = 1
	if not snap and dt then
		a = 1 - math.exp(-(self.Smooth or 14) * math.min(dt, 0.1))
	end
	local cur = self.Cur
	if not cur then
		cur = {}
		self.Cur = cur
	end
	for key, m in pairs(self.J) do
		local base = self.Base[key]
		local target = self.Pose[key] or IDENT
		local c = cur[key]
		c = c and c:Lerp(target, a) or target
		cur[key] = c
		m.C0 = CFrame.new(base.Position) * c * base.Rotation
	end
end

-- neck rotation (torso space) that turns the head toward a world point
function Rig:lookRot(pos, amount, maxYaw)
	local torso = self.Torso
	local d = torso.CFrame:VectorToObjectSpace(pos - self:head().Position)
	if d.Magnitude < 1e-3 then return IDENT end
	d = d.Unit
	local yaw = math.atan2(-d.X, -d.Z)
	local lim = math.rad(maxYaw or 70)
	yaw = math.clamp(yaw, -lim, lim)
	local pitch = math.clamp(math.asin(math.clamp(d.Y, -1, 1)), math.rad(-40), math.rad(60))
	amount = amount or 1
	return CFrame.fromEulerAnglesYXZ(pitch * amount, yaw * amount, 0)
end

-- ground locomotion like the default Animate script: idle <-> walk <-> run,
-- with the walk cycle's speed matched to how fast the rig actually moves
function Rig:loco(speed)
	speed = speed or 0
	local moving = speed > 0.6
	if moving then
		if self.LocoMode ~= "Walk" then
			self.LocoMode = "Walk"
			self:play("Walk", 0.22, 1, 1)
			self:stop("Idle", 0.3)
		end
		local tr = self.Tracks.Walk
		if tr then tr:AdjustSpeed(math.clamp(speed / 14.5, 0.35, 1.8)) end
	elseif self.LocoMode ~= "Idle" then
		self.LocoMode = "Idle"
		self:stop("Walk", 0.28)
		self:play("Idle", 0.3, 1, 1)
	end
end

-- a one-at-a-time "action" animation layered over locomotion (wave, dance...)
function Rig:action(name, fade, speed)
	if self.ActionName == name then return end
	if self.ActionName then self:stop(self.ActionName, fade or 0.3) end
	self.ActionName = name
	if name then self:play(name, fade or 0.3, speed or 1, 1) end
end

function Rig:setCF(cf)
	self.Root.CFrame = cf
end

function Rig:cf() return self.Root.CFrame end

function Rig:play(name, fade, speed, weight)
	if not self.Animator then return end
	local track = self.Tracks[name]
	if not track then
		local a = Instance.new("Animation")
		a.AnimationId = "rbxassetid://" .. (ANIMS[name] or name)
		local ok, tr = pcall(function() return self.Animator:LoadAnimation(a) end)
		if not ok then return end
		track = tr
		self.Tracks[name] = track
	end
	track.Looped = true
	if not track.IsPlaying then track:Play(fade or 0.25, weight or 1, speed or 1) end
	track:AdjustSpeed(speed or 1)
	track:AdjustWeight(weight or 1, fade or 0.25)
	return track
end

function Rig:stop(name, fade)
	local t = self.Tracks[name]
	if t and t.IsPlaying then t:Stop(fade or 0.25) end
end

function Rig:stopAll(fade)
	for _, t in pairs(self.Tracks) do
		if t.IsPlaying then t:Stop(fade or 0.25) end
	end
	self.LocoMode = nil
	self.ActionName = nil
end

function Rig:alpha(a)
	for _, p in ipairs(self.Parts) do
		p.LocalTransparencyModifier = 1 - a
	end
	for _, d in ipairs(self.Model:GetDescendants()) do
		if d:IsA("Decal") then d.Transparency = 1 - a end
	end
end

function Rig:head() return self.Model:FindFirstChild("Head") end
function Rig:part(name) return self.Model:FindFirstChild(name) end

function Rig:destroy()
	self:stopAll(0)
	self.Model:Destroy()
end

-- the Verity bat in the right hand
function Rig:giveBat()
	local src = Kit.Assets:FindFirstChild("VerityBat")
	local arm = self.Model:FindFirstChild("Right Arm")
	if not src or not arm then return end
	local bat = src:Clone()
	bat.Anchored = false
	bat.CanCollide = false
	bat.CanQuery = false
	bat.CanTouch = false
	bat.Massless = true
	local w = Instance.new("Weld")
	w.Part0 = arm
	w.Part1 = bat
	w.C0 = CFrame.new(0, -1.05, -0.05) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(-2.15, 0, 0) * CFrame.Angles(0, 0, math.rad(-8))
	w.Parent = bat
	bat.Parent = self.Model
	self.Bat = bat
	self.BatWeld = w
	table.insert(self.Parts, bat)
	return bat
end

-- poses (degrees) - rotations in torso space for the limbs,
-- HumanoidRootPart space for the root, torso space for the neck
local A = Kit.A
Kit.Poses = {
	Neutral = {},
	SkydiveFlat = { Root = A(-80, 0, 0), Neck = A(55, 0, 0), RS = A(-20, 0, 115), LS = A(-20, 0, -115), RH = A(18, 0, 14), LH = A(18, 0, -14) },
	Launch = { Root = A(10, 0, 0), Neck = A(-25, 0, 0), RS = A(40, 0, 60), LS = A(40, 0, -60), RH = A(-25, 0, 8), LH = A(30, 0, -6) },
	Float = { Root = A(-12, 0, 0), Neck = A(8, 0, 0), RS = A(20, 0, 50), LS = A(15, 0, -45), RH = A(-8, 0, 10), LH = A(12, 0, -8) },
	Tumble = { Root = A(0, 0, 0), Neck = A(-20, 0, 0), RS = A(120, 0, 40), LS = A(100, 0, -50), RH = A(50, 0, 20), LH = A(-30, 0, -20) },
	-- lying / crawling poses leave the root alone: the whole body is
	-- rotated through the HumanoidRootPart's CFrame instead
	LyingBack = { Neck = A(-10, 0, 0), RS = A(10, 0, 70), LS = A(10, 0, -60), RH = A(0, 0, 12), LH = A(8, 0, -10) },
	LyingFront = { Neck = A(40, 20, 0), RS = A(160, 0, 20), LS = A(20, 0, -30), RH = A(0, 0, 8), LH = A(0, 0, -8) },
	HandsKnees = { Neck = A(45, 0, 0), RS = A(70, 0, 0), LS = A(70, 0, 0), RH = A(90, 0, 4), LH = A(70, 0, -4) },
	Kneel = { Root = A(-15, 0, 0), Neck = A(-15, 0, 0), RS = A(40, 0, 10), LS = A(-10, 0, -8), RH = A(80, 0, 0), LH = A(-5, 0, 0) },
	Crouch = { Root = A(-30, 0, 0), Neck = A(20, 0, 0), RS = A(30, 0, 25), LS = A(25, 0, -25), RH = A(60, 0, 8), LH = A(60, 0, -8) },
	Block = { Root = A(8, 0, 0), Neck = A(-8, 0, 0), RS = A(100, 0, -40), LS = A(100, 0, 40), RH = A(20, 0, 8), LH = A(-20, 0, -8) },
	Blown = { Root = A(40, 0, 0), Neck = A(-40, 0, 0), RS = A(150, 0, 60), LS = A(150, 0, -60), RH = A(-40, 0, 20), LH = A(30, 0, -20) },
	PointUp = { Root = A(4, 0, 0), Neck = A(28, -10, 0), RS = A(172, 0, -8), LS = A(-8, 0, -22), RH = A(-6, 0, 6), LH = A(6, 0, -8) },
	LookUp = { Neck = A(35, 0, 0), RS = A(8, 0, 6), LS = A(8, 0, -6) },
	Brace = { Root = A(-10, 0, 0), Neck = A(20, 0, 0), RS = A(70, 0, 30), LS = A(70, 0, -30), RH = A(25, 0, 12), LH = A(-15, 0, -12) },
	Reach = { Root = A(-5, 0, 0), Neck = A(10, 0, 0), RS = A(90, 0, 0), LS = A(10, 0, -15) },
	Soul = { Root = A(0, 0, 0), Neck = A(-6, 0, 0), RS = A(10, 0, 20), LS = A(10, 0, -20), RH = A(0, 0, 4), LH = A(0, 0, -4) },
	Ascend = { Root = A(6, 0, 0), Neck = A(20, 0, 0), RS = A(172, 0, -6), LS = A(-20, 0, -30), RH = A(-10, 0, 6), LH = A(25, 0, -6) },
	Hero = { Root = A(0, -15, 0), Neck = A(0, 15, 0), RS = A(30, 0, 20), LS = A(-10, 0, -15), RH = A(10, 0, 10), LH = A(-10, 0, -8) },
	-- the first moment the beam takes your weight: arms drift up and out, legs dangle, looking down
	LiftOff = { Root = A(-4, 0, 0), Neck = A(-28, 0, 0), RS = A(22, 0, 78), LS = A(18, 0, -82), RH = A(14, 0, 8), LH = A(-12, 0, -8) },
}

function Kit.mixPose(a, b, t)
	local out = {}
	for k, v in pairs(a) do out[k] = v end
	for k, v in pairs(b) do
		out[k] = (a[k] or CFrame.new()):Lerp(v, t)
	end
	for k, v in pairs(a) do
		if not b[k] then out[k] = v:Lerp(CFrame.new(), t) end
	end
	return out
end

-- keep procedural limbs inside what a body can actually do: arms never swing
-- across/into the head or chest (the higher an arm goes, the further out to the
-- side it has to be), legs never cross through each other, the head stays on.
-- Use it on noise-driven poses (flailing, floating); authored poses like
-- PointUp are left alone.
local LIM = {
	-- (Z past ~105 swings the arm up and over into the head; below 0 across the face)
	RS = { X = { -55, 125 }, Z = { 12, 102 }, Side = 1 },
	LS = { X = { -55, 125 }, Z = { -102, -12 }, Side = -1 },
	RH = { X = { -60, 75 }, Z = { -3, 32 } },
	LH = { X = { -60, 75 }, Z = { -32, 3 } },
	Neck = { X = { -40, 38 }, Y = { -65, 65 }, Z = { -15, 15 } },
}
function Kit.safeArms(pose)
	local out = {}
	for k, v in pairs(pose) do out[k] = v end
	for key, lim in pairs(LIM) do
		local cf = out[key]
		if cf then
			local x, y, z = cf:ToEulerAnglesXYZ()
			x, y, z = math.deg(x), math.deg(y), math.deg(z)
			if lim.X then x = math.clamp(x, lim.X[1], lim.X[2]) end
			if lim.Y then y = math.clamp(y, lim.Y[1], lim.Y[2]) else y = math.clamp(y, -35, 35) end
			if lim.Z then z = math.clamp(z, lim.Z[1], lim.Z[2]) end
			if lim.Side then
				-- raised arms go out to the side, never up past the ear
				local need = math.min(12 + math.max(0, x - 80) * 0.5, 40)
				if lim.Side > 0 then z = math.max(z, need) else z = math.min(z, -need) end
			end
			out[key] = CFrame.fromEulerAnglesXYZ(math.rad(x), math.rad(y), math.rad(z))
		end
	end
	return out
end

-- keyframed pose over time: keys = { {time, poseTable}, ... }
function Kit.posePath(keys, t, ease)
	if t <= keys[1][1] then return keys[1][2] end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b[1] then
			local u = (ease or E.inOutSine)((t - a[1]) / (b[1] - a[1]))
			return Kit.mixPose(a[2], b[2], u)
		end
	end
	return keys[#keys][2]
end

-- live flailing (wind / falling): limbs whip around a base pose
function Kit.flail(t, seed, amount, base)
	amount = amount or 1
	local n = function(o) return math.noise(t * 2.2, seed, o) end
	local f = function(o) return math.noise(t * 7.5, seed, o) end
	local out = {}
	for k, v in pairs(base or {}) do out[k] = v end
	local function add(key, x, y, z)
		out[key] = (out[key] or CFrame.new()) * A(x * amount, y * amount, z * amount)
	end
	add("RS", n(1) * 70 + f(2) * 25, 0, n(3) * 50 + f(4) * 15)
	add("LS", n(5) * 70 + f(6) * 25, 0, n(7) * 50 + f(8) * 15)
	add("RH", n(9) * 45 + f(10) * 12, 0, n(11) * 25)
	add("LH", n(12) * 45 + f(13) * 12, 0, n(14) * 25)
	add("Neck", n(15) * 20 + f(16) * 6, n(17) * 25, 0)
	return out
end

--==================================================
-- HIDING THE REAL WORLD
--==================================================
local hidden = {}
local hideConns = {}
local function hideModel(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		end
	end
	local h = m:FindFirstChildOfClass("Humanoid")
	if h then h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
end

function Kit.hideCharacters(on)
	for _, c in ipairs(hideConns) do c:Disconnect() end
	hideConns = {}
	if on then
		local function watch(p)
			if p.Character then hideModel(p.Character) end
			table.insert(hideConns, p.CharacterAdded:Connect(function(c)
				task.wait()
				hideModel(c)
			end))
		end
		for _, p in ipairs(Players:GetPlayers()) do watch(p) end
		table.insert(hideConns, Players.PlayerAdded:Connect(watch))
		-- LocalTransparencyModifier gets reset by the default camera scripts;
		-- keep stamping it while the cutscene runs
		table.insert(hideConns, RunService.RenderStepped:Connect(function()
			for _, p in ipairs(Players:GetPlayers()) do
				local c = p.Character
				if c then
					for _, d in ipairs(c:GetChildren()) do
						if d:IsA("BasePart") then d.LocalTransparencyModifier = 1
						elseif d:IsA("Accessory") or d:IsA("Tool") then
							local h = d:FindFirstChildWhichIsA("BasePart")
							if h then h.LocalTransparencyModifier = 1 end
						end
					end
				end
			end
		end))
	else
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			if c then
				for _, d in ipairs(c:GetDescendants()) do
					if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
				end
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer end
			end
		end
	end
end

-- streaming: keep the map loaded around the camera
local focusRemote = ReplicatedStorage:FindFirstChild("CutsceneFocus")
local lastFocus = 0
function Kit.stream(pos)
	if not workspace.StreamingEnabled then return end
	focusRemote = focusRemote or ReplicatedStorage:FindFirstChild("CutsceneFocus")
	if os.clock() - lastFocus < 0.4 then return end
	lastFocus = os.clock()
	if focusRemote then focusRemote:FireServer("focus", pos) end
end
function Kit.streamNow(pos)
	if not workspace.StreamingEnabled then return end
	pcall(function() Kit.Player:RequestStreamAroundAsync(pos, 3) end)
end
function Kit.streamStop()
	if focusRemote then focusRemote:FireServer("stop") end
end

--==================================================
-- ZERO-G: smooth, never-repeating drift for floating bodies
-- (layered slow sines at unrelated rates: no jitter, no visible loop)
--==================================================
local function zs(t, seed, f, o) return math.sin(t * f + seed * 2.39 + o) end
function Kit.zeroGPose(t, seed, amount)
	amount = amount or 1
	local a = amount
	return {
		Root = A(-10 + 9 * zs(t, seed, 0.23, 0) * a, 4 * zs(t, seed, 0.17, 1) * a, 0),
		Neck = A(8 + 14 * zs(t, seed, 0.21, 2) * a, 28 * zs(t, seed, 0.13, 3) * a, 5 * zs(t, seed, 0.19, 4) * a),
		RS = A(35 + 38 * zs(t, seed, 0.41, 5) * a + 10 * zs(t, seed, 0.97, 6) * a, 0, 58 + 26 * zs(t, seed, 0.33, 7) * a),
		LS = A(30 + 38 * zs(t, seed, 0.37, 8) * a + 10 * zs(t, seed, 0.89, 9) * a, 0, -55 - 26 * zs(t, seed, 0.29, 10) * a),
		RH = A(-8 + 26 * zs(t, seed, 0.31, 11) * a, 0, 9 + 7 * zs(t, seed, 0.23, 12) * a),
		LH = A(10 + 26 * zs(t, seed, 0.27, 13) * a, 0, -9 - 7 * zs(t, seed, 0.25, 14) * a),
	}
end
-- a slow tumble for the whole body (radians); spinDir 1/-1
function Kit.zeroGRot(t, seed, amount, spinDir)
	amount = amount or 1
	return CFrame.fromEulerAnglesYXZ(
		(0.35 * zs(t, seed, 0.11, 20) + 0.18 * zs(t, seed, 0.07, 21)) * amount,
		t * 0.09 * (spinDir or 1) + 0.5 * zs(t, seed, 0.05, 22),
		(0.3 * zs(t, seed, 0.09, 23) + 0.12 * zs(t, seed, 0.15, 24)) * amount
	)
end
-- a gentle positional drift (studs)
function Kit.zeroGOffset(t, seed, r)
	r = r or 3
	return Vector3.new(zs(t, seed, 0.13, 30) + 0.5 * zs(t, seed, 0.31, 31), zs(t, seed, 0.11, 32) + 0.5 * zs(t, seed, 0.27, 33), zs(t, seed, 0.15, 34) + 0.5 * zs(t, seed, 0.23, 35)) * r
end

--==================================================
-- SOFT RING: an annulus made of radial quads, each one a stretched soft glow
-- (so the ring has a soft inner and outer edge and the overlaps blend; textured
-- discs have hard rims). update(cf) lays it in cf's XY plane.
-- (note: a beam whose transparency is exactly 1 at both ends is culled whole,
-- so soft edges come from the texture, never from a 1..x..1 sequence)
--==================================================
function Kit.softRing(host, n, r0, r1, opts)
	-- a smooth glowing annulus: n exact trapezoid sectors (inner edge Width0, outer
	-- edge Width1) with the soft falloff drawn by a radial transparency profile,
	-- so there are no seams, bumps or sprite spikes round the rim
	opts = opts or {}
	local ring = { N = n, R0 = r0, R1 = r1, Q = {}, Base = 1 - (opts.Alpha or 0.9) }
	local prof = opts.Profile or { 0, 0, 0.3, 0.75, 0.5, 1, 0.7, 0.75, 1, 0 }
	local function seq(base)
		local k = {}
		for i = 1, #prof, 2 do
			k[#k + 1] = NumberSequenceKeypoint.new(prof[i], math.clamp(1 - (1 - base) * prof[i + 1], 0, 0.985))
		end
		return NumberSequence.new(k)
	end
	ring.seq = seq
	for i = 1, n do
		local q = Kit.quad(host, host.CFrame, r1 - r0, 1, opts.Texture, { Brightness = opts.Brightness or 2, Transparency = 0.5, ZOffset = opts.ZOffset })
		q.Segments = opts.Segments or 12
		q.Transparency = seq(ring.Base)
		if opts.ColorSeq then q.Color = opts.ColorSeq end
		ring.Q[i] = q
	end
	local seam = opts.Seam or 1.004
	function ring.update(cf, r0n, r1n, phase, weights)
		r0n, r1n = r0n or ring.R0, r1n or ring.R1
		local hcf = host.CFrame
		local pos, rv, uv = cf.Position, cf.RightVector, cf.UpVector
		local da = 2 * math.pi / ring.N
		for i, q in ipairs(ring.Q) do
			local a = (i - 1) * da + (phase or 0)
			local c, s = math.cos(a), math.sin(a)
			local dir = rv * c + uv * s
			local tan = rv * -s + uv * c
			local r1a = r0n + (r1n - r0n) * (weights and weights(a) or 1)
			q.Attachment0.CFrame = hcf:ToObjectSpace(CFrame.fromMatrix(pos + dir * r0n, dir, tan))
			q.Attachment1.CFrame = hcf:ToObjectSpace(CFrame.fromMatrix(pos + dir * r1a, dir, tan))
			q.Width0 = math.max(0.05, r0n * da * seam)
			q.Width1 = r1a * da * seam
		end
	end
	function ring.setTransparency(v)
		-- a number or a NumberSequence: its most opaque value sets the peak
		local base = v
		if typeof(v) == "NumberSequence" then
			base = 1
			for _, kp in ipairs(v.Keypoints) do base = math.min(base, kp.Value) end
		end
		local ns = seq(base)
		for _, q in ipairs(ring.Q) do q.Transparency = ns end
	end
	function ring.setEnabled(on)
		for _, q in ipairs(ring.Q) do q.Enabled = on end
	end
	return ring
end

--==================================================
-- COSMOS: a deep, scattered field of galaxies, colour nebula streaks,
-- bright stars and real planets around a path. Everything is placed one
-- by one at its own depth and angle, so it parallaxes like a real volume.
--==================================================
Kit.GalaxyTex = { "12383337533", "12383662183", "15057851037", "383165544", "11723866809", "16823444551", "15058513927" }
Kit.NebulaColors = {
	Color3.fromRGB(150, 70, 255), Color3.fromRGB(60, 120, 255), Color3.fromRGB(40, 210, 230),
	Color3.fromRGB(255, 80, 200), Color3.fromRGB(255, 150, 70), Color3.fromRGB(110, 60, 220), Color3.fromRGB(80, 255, 200),
}
-- Roblox caps a part at 2048 studs. Anything bigger is drawn by a stand-in (a
-- plain part with a scaled SpecialMesh) that follows the capped, hidden original:
-- its CFrame, Size (as a ratio), Transparency and Color, so code driving the
-- original needn't know
local MAXP = 2048
function Kit.oversize(p, size)
	if size.X <= MAXP and size.Y <= MAXP and size.Z <= MAXP then
		p.Size = size
		return p
	end
	local k = MAXP / math.max(size.X, size.Y, size.Z)
	local capped = size * k
	p.Size = capped
	if p.Material == Enum.Material.ForceField then
		-- (a ForceField shell can't be drawn by a mesh stand-in: it turns solid. Big
		-- worlds keep their limb glow instead)
		p.LocalTransparencyModifier = 1
		return p
	end
	local f = Instance.new("Part")
	f.Name = p.Name .. "_Big"
	f.Anchored = true
	f.CanCollide = false
	f.CanQuery = false
	f.CanTouch = false
	f.CastShadow = false
	f.Size = capped
	f.Material = p.Material
	f.Color = p.Color
	f.Reflectance = p.Reflectance
	f.Transparency = p.Transparency
	local mesh = Instance.new("SpecialMesh")
	local base
	if p:IsA("MeshPart") then
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = p.MeshId
		mesh.TextureId = p:GetAttribute("ColorMap") or p.TextureID
		base = size / p.MeshSize
	else
		mesh.MeshType = (p:IsA("Part") and p.Shape == Enum.PartType.Ball) and Enum.MeshType.Sphere or Enum.MeshType.Brick
		base = Vector3.one / k
	end
	mesh.Scale = base
	mesh.Parent = f
	f.CFrame = p.CFrame
	p:GetPropertyChangedSignal("CFrame"):Connect(function() f.CFrame = p.CFrame end)
	p:GetPropertyChangedSignal("Size"):Connect(function() mesh.Scale = base * (p.Size.X / capped.X) end)
	p:GetPropertyChangedSignal("Transparency"):Connect(function() f.Transparency = p.Transparency end)
	p:GetPropertyChangedSignal("Color"):Connect(function() f.Color = p.Color end)
	p:GetPropertyChangedSignal("Material"):Connect(function() f.Material = p.Material end)
	p.LocalTransparencyModifier = 1
	f.Parent = p
	return p, f
end

-- a planet's ring (a flat part with the ring image as decals on its two faces):
-- drawn as a quad riding on it instead, so it can be any size
function Kit.oversizeRing(ring, size)
	local tex, col, tr = nil, Color3.new(1, 1, 1), 0
	for _, d in ipairs(ring:GetChildren()) do
		if d:IsA("Decal") then
			tex, col, tr = d.Texture, d.Color3, d.Transparency
			d.Transparency = 1
		end
	end
	ring.Size = Vector3.new(math.min(size.X, MAXP), math.min(size.Y, MAXP), math.min(size.Z, MAXP))
	if not tex then return end
	local capY = ring.Size.Y
	local W = size.Y
	local q = Kit.quad(ring, CFrame.lookAt(ring.Position, ring.Position + ring.CFrame.RightVector), W, W, tex, {
		Color = col, Brightness = 1.3, Emission = 0.25, Influence = 0.75, Transparency = tr,
	})
	ring:GetPropertyChangedSignal("Size"):Connect(function()
		local r = ring.Size.Y / capY
		Kit.setQuadSize(q, W * r, W * r)
	end)
	-- (the ring part itself stays hidden; setting its Transparency to 1 hides the quad)
	ring.Transparency = 0.999
	ring.LocalTransparencyModifier = 1
	ring:GetPropertyChangedSignal("Transparency"):Connect(function()
		q.Enabled = ring.Transparency < 1
	end)
	return q
end

function Kit.planet(name, diameter, cf, parent)
	local folder = Kit.Assets:FindFirstChild("Planets")
	local src = folder and folder:FindFirstChild(name)
	if not src then return nil end
	local p = src:Clone()
	local s = diameter / 10
	p.CFrame = cf
	local ring = p:FindFirstChild("Ring")
	if ring then
		ring.CFrame = cf * src.Ring.CFrame.Rotation
		Kit.oversizeRing(ring, src.Ring.Size * s)
	end
	Kit.oversize(p, src.Size * s)
	p.Parent = parent
	return p
end
-- opts: Center, Radius (or Along = {p0, p1, width}), Galaxies, Clouds, Streaks, Suns, Planets, Seed, Avoid (radius kept clear around the path)
function Kit.cosmos(parent, opts)
	local rng = Random.new(opts.Seed or 1)
	local host = Kit.part({ Name = "CosmosHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(opts.Center or Vector3.zero) }, parent)
	local c = { Host = host, Galaxies = {}, Clouds = {}, Suns = {}, Planets = {} }
	local function spot(minR, maxR)
		if opts.Along then
			local a, b, w = opts.Along[1], opts.Along[2], opts.Along[3]
			local u = rng:NextNumber(-0.15, 1.15)
			local base = a:Lerp(b, u)
			local d = rng:NextUnitVector()
			local axis = (b - a).Unit
			d = (d - axis * d:Dot(axis))
			if d.Magnitude < 1e-3 then d = axis:Cross(Vector3.yAxis) end
			return base + d.Unit * rng:NextNumber(minR or (opts.Avoid or 300), maxR or w)
		end
		return opts.Center + rng:NextUnitVector() * rng:NextNumber(minR or (opts.Avoid or 800), maxR or opts.Radius)
	end
	local look = opts.LookAt or opts.Center or (opts.Along and opts.Along[1]:Lerp(opts.Along[2], 0.5))
	-- galaxies, each on its own
	for _ = 1, opts.Galaxies or 40 do
		local p = spot(opts.GalMin, opts.GalMax)
		local s = rng:NextNumber(opts.GalSize and opts.GalSize[1] or 200, opts.GalSize and opts.GalSize[2] or 900)
		local tilt = CFrame.Angles(rng:NextNumber(-1.2, 1.2), rng:NextNumber(-1.2, 1.2), rng:NextNumber(0, 6.28))
		local col = Color3.fromHSV(rng:NextNumber(), rng:NextNumber(0, 0.35), 1)
		local q = Kit.quad(host, CFrame.lookAt(p, look) * tilt, s, s * rng:NextNumber(0.55, 1), Kit.GalaxyTex[rng:NextInteger(1, #Kit.GalaxyTex)], {
			Color = col, Brightness = rng:NextNumber(1.1, 2.2), Transparency = rng:NextNumber(0, 0.2),
		})
		table.insert(c.Galaxies, q)
	end
	-- colour streaks: long soft ribbons of nebula, several overlapping puffs each
	for _ = 1, opts.Streaks or 10 do
		local p0 = spot(opts.CloudMin, opts.CloudMax)
		local dir = rng:NextUnitVector()
		local len = rng:NextNumber(opts.StreakLen and opts.StreakLen[1] or 1500, opts.StreakLen and opts.StreakLen[2] or 4500)
		local c1 = Kit.NebulaColors[rng:NextInteger(1, #Kit.NebulaColors)]
		local c2 = Kit.NebulaColors[rng:NextInteger(1, #Kit.NebulaColors)]
		local puffs = rng:NextInteger(6, 11)
		local bend = rng:NextUnitVector() * len * 0.25
		for i = 1, puffs do
			local u = (i - 1) / (puffs - 1)
			local pp = p0 + dir * (u - 0.5) * len + bend * math.sin(u * math.pi) + rng:NextUnitVector() * len * 0.04
			local s = len * rng:NextNumber(0.22, 0.4) * (1 - math.abs(u - 0.5))
			local q = Kit.quad(host, CFrame.lookAt(pp, look) * CFrame.Angles(0, 0, rng:NextNumber(0, 6.28)), s * 1.6, s, "10180479311", {
				Color = c1:Lerp(c2, u), Brightness = rng:NextNumber(0.9, 1.6), Transparency = rng:NextNumber(0.35, 0.6),
			})
			table.insert(c.Clouds, q)
		end
	end
	-- loose clouds
	for _ = 1, opts.Clouds or 20 do
		local p = spot(opts.CloudMin, opts.CloudMax)
		local s = rng:NextNumber(600, 2200)
		local q = Kit.quad(host, CFrame.lookAt(p, look) * CFrame.Angles(0, 0, rng:NextNumber(0, 6.28)), s, s * rng:NextNumber(0.5, 0.9), "10180479311", {
			Color = Kit.NebulaColors[rng:NextInteger(1, #Kit.NebulaColors)], Brightness = rng:NextNumber(0.6, 1.1), Transparency = rng:NextNumber(0.55, 0.8),
		})
		table.insert(c.Clouds, q)
	end
	-- bright stars: a hot core + soft halo + a thin cross flare
	for _ = 1, opts.Suns or 14 do
		local p = spot(opts.SunMin, opts.SunMax)
		local col = ({ Color3.fromRGB(255, 240, 220), Color3.fromRGB(190, 215, 255), Color3.fromRGB(255, 200, 150), Color3.fromRGB(230, 190, 255) })[rng:NextInteger(1, 4)]
		local s = rng:NextNumber(opts.SunSize and opts.SunSize[1] or 40, opts.SunSize and opts.SunSize[2] or 160)
		local core = Kit.part({ Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.one * s, CFrame = CFrame.new(p), Material = Enum.Material.Neon, Color = col }, parent)
		local halo = Kit.quad(host, CFrame.lookAt(p, look), s * 7, s * 7, "rbxasset://sky/sun.jpg", { Color = col, Brightness = 1.4, Transparency = 0.2 })
		local flare = Kit.quad(host, CFrame.lookAt(p, look), s * 11, s * 0.35, "1084982817", { Color = col, Brightness = 1.2, Transparency = 0.6 })
		table.insert(c.Suns, { Core = core, Halo = halo, Flare = flare, Pos = p, Size = s })
	end
	-- planets, one by one
	local names = opts.PlanetNames or { "jupiter", "saturn", "uranus", "neptune", "mars", "venus", "mercury", "moon", "io", "europa", "ganymede", "callisto", "titan", "triton", "pluto", "eris", "rhea", "iapetus", "titania", "oberon", "ceres", "haumea", "dione", "umbriel", "charon", "sedna" }
	for i = 1, opts.Planets or 12 do
		local p = spot(opts.PlanetMin, opts.PlanetMax)
		local nm = names[(i - 1) % #names + 1]
		local d = rng:NextNumber(opts.PlanetSize and opts.PlanetSize[1] or 80, opts.PlanetSize and opts.PlanetSize[2] or 600)
		local pl = Kit.planet(nm, d, CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5)), parent)
		if pl then table.insert(c.Planets, { Part = pl, Spin = rng:NextNumber(-0.03, 0.03), CF = pl.CFrame }) end
	end
	-- turn the flat sprites to the camera each frame (halos + flares)
	function c.face(camPos, t)
		for _, s in ipairs(c.Suns) do
			local cf = CFrame.lookAt(s.Pos, camPos)
			Kit.moveQuad(s.Halo, cf)
			Kit.moveQuad(s.Flare, cf * CFrame.Angles(0, 0, 0.4))
		end
		for _, p in ipairs(c.Planets) do
			p.Part.CFrame = p.CF * CFrame.Angles(0, (t or 0) * p.Spin, 0)
			local ring = p.Part:FindFirstChild("Ring")
			if ring then ring.CFrame = p.Part.CFrame * (ring:GetAttribute("Rel") or CFrame.new()) end
		end
	end
	for _, p in ipairs(c.Planets) do
		local ring = p.Part:FindFirstChild("Ring")
		if ring then ring:SetAttribute("Rel", p.Part.CFrame:ToObjectSpace(ring.CFrame)) end
	end
	return c
end

-- a coloured star field in a box (dense, multi-coloured, varied sizes)
function Kit.starField(parent, cf, size, count)
	local box = Kit.part({ Name = "StarField", Size = size, CFrame = cf, Transparency = 1 }, parent)
	local sets = {
		{ "rbxasset://textures/particles/sparkles_main.dds", Color3.fromRGB(255, 255, 255), 5, 0.5 },
		{ "rbxasset://textures/particles/sparkles_main.dds", Color3.fromRGB(170, 200, 255), 4, 0.2 },
		{ "rbxasset://textures/particles/sparkles_main.dds", Color3.fromRGB(255, 190, 240), 4, 0.15 },
		{ "17000879366", Color3.fromRGB(200, 255, 245), 9, 0.15 },
	}
	local em = {}
	for _, st in ipairs(sets) do
		local e = Kit.emitter(box, {
			Texture = st[1], Color = ColorSequence.new(st[2]), Size = Kit.ns(0, st[3] * 0.4, 0.5, st[3], 1, st[3] * 0.4),
			Lifetime = NumberRange.new(20), Speed = NumberRange.new(0), Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Brightness = 3, Rotation = NumberRange.new(0, 360),
			Transparency = Kit.ns(0, 1, 0.1, 0, 0.9, 0, 1, 1),
		})
		table.insert(em, { E = e, N = math.floor(count * st[4]) })
	end
	local f = { Box = box, E = em }
	function f.fill() for _, e in ipairs(f.E) do e.E:Emit(e.N) end end
	return f
end

--==================================================
-- DOME CLOUDS
-- Every cloud in the cutscene is dome-shaped: a puffy cumulus built
-- from the classic cloud mesh (tall in the middle, lower and smaller
-- round the edge, flat-ish underneath), and every cloud particle
-- layer emits from a half-sphere instead of a box.
--==================================================
function Kit.cloud(parent, cf, width, rng, opts)
	opts = opts or {}
	rng = rng or Random.new()
	local src = Kit.Assets:FindFirstChild("CloudMesh")
	local m = Instance.new("Model")
	m.Name = opts.Name or "DomeCloud"
	local top = opts.Color or Color3.fromRGB(255, 255, 255)
	local shade = opts.Shade or Color3.fromRGB(205, 214, 232)
	local k = width * 0.55 / 30
	local function piece(offset, scale, yaw, col)
		local p
		if src then
			p = src:Clone()
			p.Size = src.Size * scale
		else
			p = Instance.new("Part")
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.new(30, 16, 20) * scale
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = col
		p.Transparency = opts.Transparency or 0
		p.CFrame = cf * CFrame.new(offset) * CFrame.Angles(0, yaw, 0)
		for _, c in ipairs(p:GetChildren()) do
			if not c:IsA("SpecialMesh") then c:Destroy() end
		end
		p.Parent = m
		return p
	end
	-- the crown
	piece(Vector3.new(0, 16 * k * 0.18, 0), k, rng:NextNumber(0, 2 * math.pi), top)
	-- the ring of smaller domes round the base
	local n = opts.Pieces or rng:NextInteger(5, 7)
	for i = 1, n do
		local a = i / n * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
		local r = width * rng:NextNumber(0.2, 0.32)
		local sc = k * rng:NextNumber(0.48, 0.72)
		piece(Vector3.new(math.cos(a) * r, -16 * sc * 0.12, math.sin(a) * r), sc, rng:NextNumber(0, 2 * math.pi), top:Lerp(shade, rng:NextNumber(0.25, 0.7)))
	end
	m.Parent = parent
	return m
end

-- set a cloud's opacity (1 = invisible)
function Kit.cloudAlpha(m, tr)
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then p.Transparency = tr end
	end
end

-- a particle emitter that fills a half-sphere (dome) instead of a box
function Kit.domeEmitter(host, props)
	props.Shape = Enum.ParticleEmitterShape.Sphere
	props.ShapePartial = props.ShapePartial or 0.5
	props.EmissionDirection = props.EmissionDirection or Enum.NormalId.Top
	props.ShapeStyle = props.ShapeStyle or Enum.ParticleEmitterShapeStyle.Volume
	return Kit.emitter(host, props)
end

return Kit
