--==================================================
-- CRUELTY ENTRY CINEMATIC  v2  (client)
--
-- The camera half of going down to Cruelty. The server owns where the
-- character is (CrueltyLobbyService); everything here is camera, VFX,
-- colour and sound.
--
--   1  THE PULL    the portal swells into a vortex; you're lifted off your
--                  feet and dragged in. The camera starts over your
--                  shoulder, creeps in on a dolly-zoom, then whips after
--                  you as you're yanked through.
--   2  THE TUNNEL  a wormhole of rings -- violet bleeding to crimson --
--                  that the camera rockets down, rolling faster and faster.
--   3  THE DROP    you burst out above the arena and fall; the camera rides
--                  alongside and swings underneath as you go head-first.
--   4  IMPACT      hard shake, dust; the camera slams to floor level.
--   5  GET UP      it lifts and circles round behind you as you stand,
--                  ending on what's waiting across the arena.
--
-- Every camera move is spring-smoothed. Control always comes back, even if
-- a step errors or you respawn mid-way.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("CrueltyLobby")

local VIOLET = Color3.fromRGB(150, 60, 255)
local MAGENTA = Color3.fromRGB(255, 70, 200)
local CRIMSON = Color3.fromRGB(230, 30, 40)
local WHITE = Color3.new(1, 1, 1)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local running = false
local landed = false
local diveArgs = nil

--==================================================
-- overlay + post effects
--==================================================

local gui = Instance.new("ScreenGui")
gui.Name = "CrueltyEntry"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 80
gui.Enabled = false
gui.Parent = playerGui

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = WHITE
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 5
flash.Parent = gui

local vignette = Instance.new("ImageLabel")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundTransparency = 1
vignette.Image = "rbxasset://textures/ui/Vignette.png"
vignette.ImageColor3 = VIOLET
vignette.ImageTransparency = 1
vignette.ScaleType = Enum.ScaleType.Stretch
vignette.Parent = gui

local function bar(anchorY, posY)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, anchorY)
	f.Position = UDim2.fromScale(0.5, posY)
	f.Size = UDim2.fromScale(1, 0)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.ZIndex = 4
	f.Parent = gui
	return f
end
local topBar, bottomBar = bar(0, 0), bar(1, 1)

local blur, cc
local function ensureEffects()
	if not (blur and blur.Parent) then
		blur = Instance.new("BlurEffect")
		blur.Name = "CrueltyEntryBlur"
		blur.Size = 0
		blur.Parent = Lighting
	end
	if not (cc and cc.Parent) then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "CrueltyEntryCC"
		cc.Parent = Lighting
	end
end
local function clearEffects()
	if blur then blur:Destroy() blur = nil end
	if cc then cc:Destroy() cc = nil end
end

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function play(id, volume, speed)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	SoundService:PlayLocalSound(s)
	task.delay(8, function() s:Destroy() end)
	return s
end

local function flashTo(colour, holdIn, fadeOut)
	flash.BackgroundColor3 = colour
	tween(flash, holdIn or 0.08, { BackgroundTransparency = 0 })
	task.delay((holdIn or 0.08) + 0.02, function()
		tween(flash, fadeOut or 0.6, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
	end)
end

-- spring-smoothed camera: every stage just says where it WANTS the camera,
-- and this glides there, so cuts between stages never jerk
local camCF, camFov = nil, 70
local shakeAmp, shakeUntil = 0, 0
local function drive(targetCF, targetFov, dt, stiffness)
	local cam = workspace.CurrentCamera
	local k = 1 - math.exp(-(stiffness or 10) * dt)
	camCF = camCF and camCF:Lerp(targetCF, k) or targetCF
	camFov = camFov + ((targetFov or camFov) - camFov) * k
	local out = camCF
	if os.clock() < shakeUntil then
		local s = shakeAmp * ((shakeUntil - os.clock()) / 0.6)
		out = out * CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
			* CFrame.Angles(0, 0, math.rad((math.random() - 0.5) * s * 3))
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = out
	cam.FieldOfView = math.clamp(camFov, 20, 120)
end
local function shake(amount, duration)
	shakeAmp = amount
	shakeUntil = os.clock() + (duration or 0.6)
end

-- run fn(dt, alpha) every frame for `duration` seconds
local function over(duration, fn)
	local t0 = os.clock()
	while running do
		local dt = RunService.RenderStepped:Wait()
		local a = math.clamp((os.clock() - t0) / duration, 0, 1)
		fn(dt, a)
		if a >= 1 then break end
	end
end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end

--==================================================
-- 1. THE PULL
--==================================================

local function buildVortex(portalCF)
	local folder = Instance.new("Folder")
	folder.Name = "CrueltyVortex"
	folder.Parent = workspace

	local core = part(folder, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = Color3.fromRGB(20, 0, 30), CFrame = portalCF })
	local shell = part(folder, { Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Color = VIOLET, Material = Enum.Material.ForceField, CFrame = portalCF })
	local att = Instance.new("Attachment")
	att.Parent = core
	local suck = Instance.new("ParticleEmitter")
	suck.Texture = SPARK
	suck.Color = ColorSequence.new(WHITE, MAGENTA)
	suck.LightEmission = 1
	suck.LightInfluence = 0
	suck.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(1, 0) })
	suck.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(1, 0.4) })
	-- negative speed: pulled IN. NumberRange wants the smaller number first.
	suck.Speed = NumberRange.new(-34, -20)
	suck.Lifetime = NumberRange.new(0.5, 0.8)
	suck.SpreadAngle = Vector2.new(180, 180)
	suck.Rate = 160
	suck.Parent = att
	local wisps = Instance.new("ParticleEmitter")
	wisps.Texture = SMOKE
	wisps.Color = ColorSequence.new(VIOLET, Color3.fromRGB(30, 0, 50))
	wisps.LightEmission = 0.6
	wisps.LightInfluence = 0
	wisps.Size = NumberSequence.new(6, 1)
	wisps.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) })
	wisps.Speed = NumberRange.new(-16, -9)
	wisps.Lifetime = NumberRange.new(0.8, 1.2)
	wisps.SpreadAngle = Vector2.new(180, 180)
	wisps.RotSpeed = NumberRange.new(-200, 200)
	wisps.Rate = 30
	wisps.Parent = att
	local light = Instance.new("PointLight")
	light.Color = VIOLET
	light.Range = 30
	light.Brightness = 0
	light.Parent = core

	local rings = {}
	for r = 1, 3 do
		local segs = {}
		for i = 1, 20 do
			segs[i] = part(folder, { Name = "Ring", Size = Vector3.new(0.3, 0.3, 1), Color = (r == 2) and WHITE or ((r == 1) and VIOLET or MAGENTA), Transparency = 0.1 })
		end
		rings[r] = segs
	end
	return { folder = folder, core = core, shell = shell, light = light, rings = rings, cf = portalCF }
end

local function poseVortex(v, t, a)
	local grow = 1 + a * 2.6
	v.core.Size = Vector3.one * (1.6 + a * 5)
	v.shell.Size = Vector3.one * (2.6 + a * 7 + math.sin(t * 20) * 0.3)
	v.light.Brightness = 1 + a * 6
	-- rings lie in the portal's own plane (its LookVector is the normal)
	for r, segs in ipairs(v.rings) do
		local radius = (2.2 + r * 1.3) * grow
		local n = #segs
		for i, seg in ipairs(segs) do
			local ang = (i / n) * math.pi * 2 + t * (r % 2 == 0 and -4 or 3) * (1 + a * 3)
			local local_ = Vector3.new(math.cos(ang) * radius, math.sin(ang) * radius, 0)
			local tangent = Vector3.new(-math.sin(ang), math.cos(ang), 0)
			local pos = v.cf:PointToWorldSpace(local_)
			seg.Size = Vector3.new(0.25 + a * 0.2, 0.25 + a * 0.2, (math.pi * 2 * radius) / n * 0.7)
			seg.CFrame = CFrame.lookAt(pos, pos + v.cf:VectorToWorldSpace(tangent))
		end
	end
end

local function stagePull(portalCF, duration)
	local char = player.Character
	if not char then return end
	local v = buildVortex(portalCF)
	play("rbxassetid://9114446852", 0.5, 0.55) -- low whoosh building up
	tween(vignette, 0.8, { ImageTransparency = 0.3 })
	tween(topBar, 0.7, { Size = UDim2.fromScale(1, 0.1) }, Enum.EasingStyle.Quart)
	tween(bottomBar, 0.7, { Size = UDim2.fromScale(1, 0.1) }, Enum.EasingStyle.Quart)
	cc.TintColor = Color3.fromRGB(225, 205, 255)

	local startBody = char:GetPivot().Position
	local toPortal = (portalCF.Position - startBody)
	local flat = Vector3.new(toPortal.X, 0, toPortal.Z)
	flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
	local side = flat:Cross(Vector3.yAxis)
	local t0 = os.clock()
	camCF = workspace.CurrentCamera.CFrame
	camFov = workspace.CurrentCamera.FieldOfView

	over(duration, function(dt, a)
		local t = os.clock() - t0
		poseVortex(v, t, a)
		local body = char:GetPivot().Position
		local target, fov
		if a < 0.45 then
			-- over the shoulder, creeping in; FOV tightens (dolly-zoom)
			local k = a / 0.45
			local eye = body - flat * (11 - k * 3) + side * 3.5 + Vector3.new(0, 3.2 - k * 0.8, 0)
			target = CFrame.lookAt(eye, portalCF.Position:Lerp(body, 0.25))
			fov = 70 - k * 22
		else
			-- yanked: the camera whips after you, FOV blows wide
			local k = (a - 0.45) / 0.55
			local eye = body - flat * (6 + k * 2) + side * (3.5 - k * 3) + Vector3.new(0, 2.4, 0)
			target = CFrame.lookAt(eye, body:Lerp(portalCF.Position, 0.6))
			fov = 48 + k * 62
		end
		blur.Size = a * a * 16
		cc.Contrast = a * 0.25
		cc.Saturation = -a * 0.2
		drive(target, fov, dt, a < 0.45 and 5 or 14)
		if a > 0.55 then shake(0.25 + a * 0.5, 0.2) end
	end)

	play("rbxassetid://114743565978001", 0.7, 1.5)
	flashTo(Color3.fromRGB(235, 210, 255), 0.06, 0.4)
	task.delay(0.5, function() v.folder:Destroy() end)
end

--==================================================
-- 2. THE TUNNEL
--==================================================

local TUNNEL_ORIGIN = Vector3.new(0, 14000, 0)

local function stageTunnel(duration)
	local folder = Instance.new("Folder")
	folder.Name = "CrueltyTunnel"
	folder.Parent = workspace
	local RINGS, SPACING, RADIUS, SEGS = 44, 14, 11, 16
	local length = RINGS * SPACING
	for r = 1, RINGS do
		local k = r / RINGS
		local colour = VIOLET:Lerp(CRIMSON, k)
		local z = -r * SPACING
		local twist = r * 0.21
		for i = 1, SEGS do
			local ang = (i / SEGS) * math.pi * 2 + twist
			local pos = TUNNEL_ORIGIN + Vector3.new(math.cos(ang) * RADIUS, math.sin(ang) * RADIUS, z)
			local tangent = Vector3.new(-math.sin(ang), math.cos(ang), 0)
			part(folder, {
				Name = "Seg",
				Size = Vector3.new(0.4, 0.4, (math.pi * 2 * RADIUS) / SEGS * ((i % 2 == 0) and 0.9 or 0.45)),
				CFrame = CFrame.lookAt(pos, pos + tangent),
				Color = (i % 4 == 0) and WHITE or colour,
				Transparency = (i % 2 == 0) and 0.05 or 0.35,
			})
		end
	end
	-- long light streaks down the walls
	for i = 1, 8 do
		local ang = (i / 8) * math.pi * 2
		local pos = TUNNEL_ORIGIN + Vector3.new(math.cos(ang) * (RADIUS - 1.2), math.sin(ang) * (RADIUS - 1.2), -length / 2)
		part(folder, { Name = "Streak", Size = Vector3.new(0.12, 0.12, length), CFrame = CFrame.new(pos), Color = WHITE, Transparency = 0.5 })
	end

	camCF = CFrame.new(TUNNEL_ORIGIN + Vector3.new(0, 0, 10))
	cc.TintColor = Color3.fromRGB(255, 200, 235)
	play("rbxassetid://9114446852", 0.6, 1.25)
	local roll = 0
	over(duration, function(dt, a)
		local e = a * a * (3 - 2 * a)
		local z = 10 - e * (length - 20)
		roll += dt * (2 + a * 9)
		local pos = TUNNEL_ORIGIN + Vector3.new(math.sin(a * 9) * 1.5, math.cos(a * 7) * 1.5, z)
		local cf = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)) * CFrame.Angles(0, 0, roll)
		camCF = cf -- the tunnel is its own shot: no smoothing lag here
		drive(cf, 100 + a * 15, dt, 40)
		blur.Size = 6 + math.sin(a * math.pi) * 8
		cc.TintColor = Color3.fromRGB(235, 205, 255):Lerp(Color3.fromRGB(255, 190, 190), a)
	end)
	flashTo(Color3.fromRGB(255, 225, 225), 0.05, 0.5)
	folder:Destroy()
end

--==================================================
-- 3-5. THE DROP, IMPACT, GET UP
--==================================================

local function wind(root)
	local holder = Instance.new("Attachment")
	holder.Name = "CrueltyDiveWind"
	holder.Parent = root
	local streaks = Instance.new("ParticleEmitter")
	streaks.Texture = SPARK
	streaks.Color = ColorSequence.new(WHITE, CRIMSON)
	streaks.LightEmission = 1
	streaks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 1.4), NumberSequenceKeypoint.new(1, 0) })
	streaks.Transparency = NumberSequence.new(0.2, 1)
	streaks.Lifetime = NumberRange.new(0.35, 0.6)
	streaks.Speed = NumberRange.new(40, 70)
	streaks.EmissionDirection = Enum.NormalId.Top
	streaks.SpreadAngle = Vector2.new(24, 24)
	streaks.Rate = 90
	streaks.Parent = holder
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 40, 60), Color3.fromRGB(30, 8, 12))
	smoke.Size = NumberSequence.new(3, 9)
	smoke.Transparency = NumberSequence.new(0.6, 1)
	smoke.Lifetime = NumberRange.new(0.6, 1)
	smoke.Speed = NumberRange.new(6, 14)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.SpreadAngle = Vector2.new(40, 40)
	smoke.Rate = 26
	smoke.Parent = holder
	return holder
end

--------------------------------------------------
-- THE SKY YOU FALL THROUGH
--   above the deck: blue sky, soft white clouds, gulls
--   the deck: a thick bank of cloud you punch straight through
--   below it: another world -- blood-red cloud, black spires, a blood
--   moon, rock floating in the air, crows, red lightning, and a ring of
--   rune stones you dive right through the middle of
--------------------------------------------------
local CLOUD_TEX = "rbxasset://textures/particles/smoke_main.dds"
local CLOUD = Color3.fromRGB(250, 250, 255)
local CLOUD_SHADE = Color3.fromRGB(214, 222, 238)
local RED_CLOUD = Color3.fromRGB(150, 32, 40)
local RED_SHADE = Color3.fromRGB(70, 8, 14)

-- soft, billboarded cloud: an invisible box full of big smoke puffs that
-- sit perfectly still (much softer than stacked balls)
local function cloudBank(folder, cframe, size, count, puff, top, shade, transparency)
	local box = part(folder, { Name = "CloudBank", Size = size, CFrame = cframe, Transparency = 1, Material = Enum.Material.SmoothPlastic })
	local e = Instance.new("ParticleEmitter")
	e.Texture = CLOUD_TEX
	e.Color = ColorSequence.new(top, shade)
	e.LightEmission = 0.08
	e.LightInfluence = 0.55
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, puff, puff * 0.35), NumberSequenceKeypoint.new(1, puff, puff * 0.35) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, transparency or 0.25), NumberSequenceKeypoint.new(1, transparency or 0.25) })
	e.Lifetime = NumberRange.new(60)
	e.Speed = NumberRange.new(0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-4, 4)
	e.Rate = 0
	e.LockedToPart = true
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = box
	e:Emit(count)
	return box
end

local function makeBird(folder, scale, dark)
	local bodyCol = dark and Color3.fromRGB(18, 14, 16) or WHITE
	local wingCol = dark and Color3.fromRGB(28, 20, 24) or Color3.fromRGB(235, 235, 240)
	local tipCol = dark and Color3.fromRGB(8, 6, 8) or Color3.fromRGB(70, 70, 80)
	local body = part(folder, { Name = "Body", Material = Enum.Material.SmoothPlastic, Color = bodyCol, Size = Vector3.new(0.55, 0.45, 1.5) * scale })
	local head = part(folder, { Name = "Head", Material = Enum.Material.SmoothPlastic, Color = bodyCol, Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5 * scale })
	local beak = part(folder, { Name = "Beak", Material = dark and Enum.Material.Neon or Enum.Material.SmoothPlastic, Color = dark and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(255, 180, 60), Size = Vector3.new(0.12, 0.1, 0.35) * scale })
	local wings = {}
	for side = -1, 1, 2 do
		local inner = part(folder, { Name = "Wing", Material = Enum.Material.SmoothPlastic, Color = wingCol, Size = Vector3.new(1.3, 0.08, 0.75) * scale })
		local outer = part(folder, { Name = "Tip", Material = Enum.Material.SmoothPlastic, Color = tipCol, Size = Vector3.new(1.1, 0.07, 0.55) * scale })
		wings[side] = { inner = inner, outer = outer }
	end
	return { body = body, head = head, beak = beak, wings = wings, scale = scale, phase = math.random() * 6 }
end

local function poseBird(b, cf, t)
	local s = b.scale
	local flap = math.sin(t * 9 + b.phase) * 0.7
	b.body.CFrame = cf
	b.head.CFrame = cf * CFrame.new(0, 0.2 * s, -0.85 * s)
	b.beak.CFrame = cf * CFrame.new(0, 0.15 * s, -1.2 * s)
	for side = -1, 1, 2 do
		local w = b.wings[side]
		local root = cf * CFrame.new(side * 0.25 * s, 0.1 * s, -0.1 * s) * CFrame.Angles(0, 0, side * flap)
		w.inner.CFrame = root * CFrame.new(side * 0.65 * s, 0, 0)
		local tip = root * CFrame.new(side * 1.3 * s, 0, 0) * CFrame.Angles(0, 0, side * flap * 0.6)
		w.outer.CFrame = tip * CFrame.new(side * 0.55 * s, 0, 0.05 * s)
	end
end

-- the dive path (mirrors CrueltyLobbyService): a curve from far out and
-- high up down into the arena, with a calm stretch at the start
local CALM = 0.3
local function makePath(startPos, landingPos)
	local across = (startPos - landingPos) * Vector3.new(1, 0, 1)
	local dist = across.Magnitude
	across = dist > 1 and across.Unit or Vector3.new(1, 0, 0)
	local height = startPos.Y - landingPos.Y
	local P0, P2 = startPos, landingPos
	local P1 = P2 + across * dist * 0.12 + Vector3.new(0, height * 0.5, 0)
	local function bez(u)
		local v = 1 - u
		return P0 * (v * v) + P1 * (2 * v * u) + P2 * (u * u)
	end
	local function progress(a)
		if a < CALM then return 0.05 * (a / CALM) end
		return 0.05 + 0.95 * ((a - CALM) / (1 - CALM)) ^ 1.7
	end
	return bez, progress, across
end

local function flock(folder, crossPoint, when, duration, dark, count)
	local dirAng = math.random() * math.pi * 2
	local dir = Vector3.new(math.cos(dirAng), 0, math.sin(dirAng))
	local side = dir:Cross(Vector3.yAxis)
	local f = { birds = {}, dir = dir, cross = crossPoint + side * (10 + math.random() * 10), tc = when * duration, speed = dark and 46 or 30 }
	for bi = 1, count do
		local row = math.ceil((bi - 1) / 2)
		local lr = (bi % 2 == 0) and 1 or -1
		local b = makeBird(folder, (dark and 2.1 or 1.7) + math.random() * 0.4, dark)
		b.off = -dir * row * 4 + side * lr * row * 3.4 + Vector3.new(0, (math.random() - 0.5) * 2.5, 0)
		table.insert(f.birds, b)
	end
	return f
end

local function jaggedRock(folder, cf, size, colour)
	local rock = part(folder, { Name = "Rock", Material = Enum.Material.Slate, Color = colour or Color3.fromRGB(46, 18, 22), Size = size, CFrame = cf })
	for i = 1, 2 do
		local s2 = size * (0.45 + math.random() * 0.25)
		part(folder, { Name = "Chunk", Material = Enum.Material.Slate, Color = rock.Color, Size = s2,
			CFrame = cf * CFrame.new((math.random() - 0.5) * size.X * 0.6, (math.random() - 0.5) * size.Y * 0.5, (math.random() - 0.5) * size.Z * 0.6) * CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3) })
	end
	return rock
end

local function buildSky(startPos, landingPos, duration)
	local folder = Instance.new("Folder")
	folder.Name = "CrueltySky"
	folder.Parent = workspace
	local bez, progress, across = makePath(startPos, landingPos)
	local side = across:Cross(Vector3.yAxis)
	local col = Vector3.new(landingPos.X, 0, landingPos.Z)
	local deckY = landingPos.Y + 600

	-- a sky full of cloud along the whole route: big banks off to the sides,
	-- and banks sitting right ON the path that you fly straight through
	for i = 1, 34 do
		local u = math.random() * 0.62
		local p = bez(u)
		if p.Y > deckY + 30 then
			-- keep the calm stretch clear: nothing within ~70 studs of the route
			local sgn = (math.random() < 0.5) and -1 or 1
			local off = side * sgn * (70 + math.random() * 200) + across * ((math.random() - 0.5) * 160) + Vector3.new(0, -30 - math.random() * 90, 0)
			local w = 50 + math.random() * 80
			cloudBank(folder, CFrame.new(p + off), Vector3.new(w, 12, w * 0.7), 18, 38 + math.random() * 18, CLOUD, CLOUD_SHADE, 0.28)
		end
	end
	for i = 1, 7 do
		local u = 0.12 + (i / 7) * 0.42
		local p = bez(u)
		if p.Y > deckY + 30 then
			cloudBank(folder, CFrame.new(p + side * ((math.random() - 0.5) * 20)), Vector3.new(60, 16, 60), 40, 32, CLOUD, CLOUD_SHADE, 0.35)
		end
	end
	-- the deck: a thick layer of cloud, white on top and red underneath
	local deckCentre = bez(0.55)
	deckCentre = Vector3.new(deckCentre.X, 0, deckCentre.Z):Lerp(col, 0.5)
	cloudBank(folder, CFrame.new(deckCentre + Vector3.new(0, deckY + 8, 0)), Vector3.new(900, 14, 900), 420, 75, CLOUD, CLOUD_SHADE, 0.12)
	cloudBank(folder, CFrame.new(deckCentre + Vector3.new(0, deckY - 12, 0)), Vector3.new(900, 14, 900), 300, 75, RED_CLOUD, RED_SHADE, 0.18)
	-- below: red cloud and floating rock round the last stretch
	for i = 1, 16 do
		local u = 0.65 + math.random() * 0.3
		local p = bez(u)
		local off = side * ((math.random() - 0.5) * 300) + across * ((math.random() - 0.5) * 200)
		local w = 50 + math.random() * 70
		cloudBank(folder, CFrame.new(p + off), Vector3.new(w, 10, w * 0.7), 14, 40, RED_CLOUD, RED_SHADE, 0.35)
	end
	for i = 1, 20 do
		local u = 0.62 + math.random() * 0.32
		local p = bez(u)
		local off = side * ((math.random() - 0.5) * 140) + across * ((math.random() - 0.5) * 80)
		if off.Magnitude < 22 then off = side * 28 end
		local sz = Vector3.new(4 + math.random() * 10, 3 + math.random() * 7, 4 + math.random() * 10)
		local cf = CFrame.new(p + off) * CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3)
		jaggedRock(folder, cf, sz)
		if i % 3 == 0 then
			part(folder, { Name = "Seam", Color = Color3.fromRGB(255, 50, 40), Size = Vector3.new(0.3, sz.Y * 0.9, sz.Z * 1.02), CFrame = cf })
		end
	end
	-- a ring of rune stones the path runs through
	local ringU = 0.8
	local ringC = bez(ringU)
	local tan = (bez(ringU + 0.01) - bez(ringU - 0.01)).Unit
	local ringCF = CFrame.lookAt(ringC, ringC + tan)
	local runes = {}
	for i = 1, 22 do
		local ang = (i / 22) * math.pi * 2
		local pos = ringCF:PointToWorldSpace(Vector3.new(math.cos(ang) * 30, math.sin(ang) * 30, 0))
		local cf = CFrame.lookAt(pos, ringC)
		part(folder, { Name = "RuneStone", Material = Enum.Material.Slate, Color = Color3.fromRGB(34, 14, 18), Size = Vector3.new(4, 7, 2.5), CFrame = cf })
		table.insert(runes, part(folder, { Name = "Rune", Color = Color3.fromRGB(255, 45, 45), Size = Vector3.new(1.6, 4.4, 0.2), CFrame = cf * CFrame.new(0, 0, -1.3) }))
	end
	local ringGlow = part(folder, { Name = "RingGlow", Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 40, 40), Transparency = 0.55, Size = Vector3.new(0.4, 64, 64), CFrame = ringCF * CFrame.Angles(0, math.rad(90), 0) })
	ringGlow.Material = Enum.Material.ForceField
	-- embers rising through the red world
	local emberBox = part(folder, { Name = "Embers", Size = Vector3.new(300, 500, 300), CFrame = CFrame.new(bez(0.82)), Transparency = 1 })
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/fire_sparks_main.dds"
	em.Color = ColorSequence.new(Color3.fromRGB(255, 160, 90), Color3.fromRGB(255, 40, 30))
	em.LightEmission = 1
	em.LightInfluence = 0
	em.Size = NumberSequence.new(0.9, 0.1)
	em.Lifetime = NumberRange.new(3, 5)
	em.Speed = NumberRange.new(6, 14)
	em.EmissionDirection = Enum.NormalId.Top
	em.Shape = Enum.ParticleEmitterShape.Box
	em.Rate = 220
	em.Parent = emberBox

	-- birds timed to cross the route right as you get there
	local flocks = {}
	for _, when in ipairs({ 0.06, 0.16, 0.26, 0.38, 0.48 }) do
		table.insert(flocks, flock(folder, bez(progress(when)) + Vector3.new(0, -4, 0), when, duration, false, 7))
	end
	for _, when in ipairs({ 0.72, 0.8 }) do
		table.insert(flocks, flock(folder, bez(progress(when)), when, duration, true, 9))
	end

	local lastBolt = 0
	local function update(t, below)
		for _, f in ipairs(flocks) do
			local centre = f.cross + f.dir * f.speed * (t - f.tc)
			local bob = math.sin(t * 1.3) * 1.5
			for _, b in ipairs(f.birds) do
				local p = centre + b.off + Vector3.new(0, bob, 0)
				poseBird(b, CFrame.lookAt(p, p + f.dir) * CFrame.Angles(0, 0, math.sin(t * 0.8 + b.phase) * 0.15), t)
			end
		end
		for i, g in ipairs(runes) do
			g.Transparency = 0.05 + 0.5 * (0.5 + 0.5 * math.sin(t * 4 - i * 0.6))
		end
		if below and t - lastBolt > 0.3 + math.random() * 0.5 then
			lastBolt = t
			local ang = math.random() * math.pi * 2
			local r = 180 + math.random() * 220
			local top = col + Vector3.new(math.cos(ang) * r, landingPos.Y + 560, math.sin(ang) * r)
			local prev = top
			local segs = {}
			for k = 1, 8 do
				local nxt = top + Vector3.new((math.random() - 0.5) * 30, -k * 55, (math.random() - 0.5) * 30)
				local len = (nxt - prev).Magnitude
				table.insert(segs, part(folder, { Name = "Bolt", Color = (k % 3 == 0) and WHITE or Color3.fromRGB(255, 60, 60), Size = Vector3.new(1.4, 1.4, len), CFrame = CFrame.lookAt((prev + nxt) / 2, nxt) }))
				prev = nxt
			end
			task.delay(0.12, function() for _, p in ipairs(segs) do p:Destroy() end end)
		end
	end
	return folder, update, deckY
end

local function partyRoots(ids)
	local roots = {}
	for _, id in ipairs(ids or {}) do
		local p = Players:GetPlayerByUserId(id)
		local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then table.insert(roots, r) end
	end
	return roots
end

local function smooth(a) return a * a * (3 - 2 * a) end

-- the atmospheric aura each diver drags behind them: long streak trails off
-- the shoulders and a stretched shell of wind that heats up as you fall
local function diveAura(root)
	local folder = Instance.new("Folder")
	folder.Name = "DiveAura"
	folder.Parent = workspace
	local a0 = Instance.new("Attachment") a0.Position = Vector3.new(-1.3, 0.8, 0) a0.Parent = root
	local a1 = Instance.new("Attachment") a1.Position = Vector3.new(1.3, 0.8, 0) a1.Parent = root
	local a2 = Instance.new("Attachment") a2.Position = Vector3.new(0, -1.2, 0) a2.Parent = root
	local trails = {}
	for _, pair in ipairs({ { a0, a2 }, { a2, a1 } }) do
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = pair[1], pair[2]
		tr.Lifetime = 0.9
		tr.LightEmission = 0.8
		tr.FaceCamera = true
		tr.Color = ColorSequence.new(WHITE, Color3.fromRGB(150, 210, 255))
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		tr.WidthScale = NumberSequence.new(1, 0.2)
		tr.Parent = root
		table.insert(trails, tr)
	end
	local shell = part(folder, { Name = "WindShell", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = Color3.fromRGB(190, 225, 255), Size = Vector3.new(6, 6, 10), Transparency = 1 })
	local streakAtt = Instance.new("Attachment") streakAtt.Parent = shell
	local streaks = Instance.new("ParticleEmitter")
	streaks.Texture = SPARK
	streaks.Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 215, 255))
	streaks.LightEmission = 1
	streaks.LightInfluence = 0
	streaks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(1, 0) })
	streaks.Transparency = NumberSequence.new(0.2, 1)
	streaks.Lifetime = NumberRange.new(0.25, 0.45)
	streaks.Speed = NumberRange.new(40, 70)
	streaks.EmissionDirection = Enum.NormalId.Back
	streaks.SpreadAngle = Vector2.new(12, 12)
	streaks.Rate = 0
	streaks.Parent = streakAtt
	local last = root.Position
	local aura = { folder = folder, trails = trails, shell = shell, streaks = streaks }
	function aura.update(dt, speedK, red)
		local p = root.Position
		local vel = (p - last) / math.max(dt, 1 / 240)
		last = p
		local dir = vel.Magnitude > 1 and vel.Unit or Vector3.new(0, -1, 0)
		shell.CFrame = CFrame.lookAt(p + dir * 1.5, p + dir * 3)
		shell.Size = Vector3.new(5.5, 5.5, 8 + speedK * 8)
		shell.Transparency = 1 - speedK * 0.75
		local hot = red and Color3.fromRGB(255, 120, 70) or Color3.fromRGB(190, 225, 255)
		shell.Color = hot
		streaks.Rate = speedK * 140
		streaks.Color = red and ColorSequence.new(WHITE, Color3.fromRGB(255, 90, 60)) or ColorSequence.new(WHITE, Color3.fromRGB(170, 215, 255))
		for _, tr in ipairs(trails) do
			tr.Color = red and ColorSequence.new(Color3.fromRGB(255, 220, 200), Color3.fromRGB(255, 60, 50)) or ColorSequence.new(WHITE, Color3.fromRGB(150, 210, 255))
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75 - speedK * 0.5), NumberSequenceKeypoint.new(1, 1) })
		end
	end
	function aura.destroy()
		folder:Destroy()
		for _, tr in ipairs(trails) do tr:Destroy() end
		a0:Destroy() a1:Destroy() a2:Destroy()
	end
	return aura
end

-- Wind on the body: every diver's arms and legs are thrown about by the
-- air (client-side joint offsets, so everyone sees everyone flail), with a
-- constant buffeting shake that gets harder the faster you fall.
local LIMBS = {
	{ "RightShoulder", "arm", 1 }, { "LeftShoulder", "arm", -1 },
	{ "RightElbow", "fore", 1 }, { "LeftElbow", "fore", -1 },
	{ "RightHip", "leg", 1 }, { "LeftHip", "leg", -1 },
	{ "RightKnee", "shin", 1 }, { "LeftKnee", "shin", -1 },
	{ "Neck", "neck", 0 }, { "Waist", "waist", 0 },
	{ "Right Shoulder", "arm6", 1 }, { "Left Shoulder", "arm6", -1 },
	{ "Right Hip", "leg6", 1 }, { "Left Hip", "leg6", -1 },
}
local function limbRig(character)
	local joints = {}
	for _, spec in ipairs(LIMBS) do
		local m = character:FindFirstChild(spec[1], true)
		if m and m:IsA("Motor6D") then
			table.insert(joints, { m = m, base = m.C0, kind = spec[2], side = spec[3], seed = math.random() * 10 })
		end
	end
	local rig = {}
	function rig.update(t, speedK)
		local calm = 1 - speedK
		for _, j in ipairs(joints) do
			local s, sd = j.side, j.seed
			local flap = math.sin(t * (7 + speedK * 9) + sd)
			local wob = math.sin(t * 2.3 + sd * 1.7)
			local jit = (math.random() - 0.5) * 0.12 * (0.3 + speedK)
			local cf
			if j.kind == "arm" or j.kind == "arm6" then
				local spread = math.rad(80) * calm + math.rad(20) * speedK
				local back = math.rad(-25) * calm + math.rad(-150) * speedK
				cf = CFrame.Angles(back + flap * 0.25 * (0.4 + speedK) + jit, 0, s * (spread + wob * 0.25) + flap * 0.15 * s)
			elseif j.kind == "fore" then
				cf = CFrame.Angles(math.rad(25) + flap * 0.35 * (0.5 + speedK) + jit, 0, 0)
			elseif j.kind == "leg" or j.kind == "leg6" then
				local spread = math.rad(22) * calm + math.rad(8) * speedK
				cf = CFrame.Angles(math.rad(-15) * calm + flap * 0.3 * (0.3 + speedK) + jit, 0, s * (spread + wob * 0.12))
			elseif j.kind == "shin" then
				cf = CFrame.Angles(math.rad(-40) * calm + math.rad(-10) * speedK - math.abs(flap) * 0.3 + jit, 0, 0)
			elseif j.kind == "neck" then
				cf = CFrame.Angles(math.rad(35) * calm + math.rad(-20) * speedK + jit * 0.5, wob * 0.2, 0)
			else
				cf = CFrame.Angles(jit, wob * 0.08, jit * 0.8 + math.sin(t * 13 + sd) * 0.05 * speedK)
			end
			j.m.C0 = j.base * cf
		end
	end
	function rig.restore()
		for _, j in ipairs(joints) do
			if j.m.Parent then j.m.C0 = j.base end
		end
	end
	return rig
end

local function stageDrop(duration, landingPos, partyIds, startPos)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	landingPos = landingPos or (char:GetPivot().Position - Vector3.new(0, 300, 0))
	startPos = startPos or char:GetPivot().Position
	local sky, skyUpdate, deckY = buildSky(startPos, landingPos, duration)
	local bez, progress = makePath(startPos, landingPos)

	-- auras on everybody diving with you
	local auras = {}
	local roots = partyRoots(partyIds)
	if #roots == 0 then roots = { root } end
	for _, r in ipairs(roots) do auras[r] = diveAura(r) end
	local rigs = {}
	for _, r in ipairs(roots) do
		if r.Parent then rigs[r] = limbRig(r.Parent) end
	end

	-- a calm start: soft grade, gentle music, just the wind
	tween(vignette, 0.8, { ImageColor3 = WHITE, ImageTransparency = 0.8 })
	cc.TintColor = Color3.fromRGB(255, 244, 232)
	cc.Contrast = 0.04
	cc.Saturation = 0.05
	blur.Size = 0
	local music = SoundService:FindFirstChild("BossMusic")
	local calmTrack = music and music:FindFirstChild("DiveCalm")
	if calmTrack then
		calmTrack.TimePosition = 0
		calmTrack.Volume = 0
		calmTrack:Play()
		tween(calmTrack, 1.5, { Volume = calmTrack:GetAttribute("TargetVolume") or 0.5 })
	end
	-- three layers of wind: a soft high breeze for the calm, a roaring rush
	-- that swells as you pick up speed, and the flapping buffet, plus gusts
	local function loop(id, vol, speed)
		local snd = Instance.new("Sound")
		snd.SoundId = id
		snd.Looped = true
		snd.Volume = vol
		snd.PlaybackSpeed = speed
		snd.Parent = SoundService
		snd:Play()
		return snd
	end
	local windBreeze = loop("rbxassetid://9119392620", 0.35, 1)
	local windRush = loop("rbxassetid://9125742262", 0, 0.8)
	local windLoop = loop("rbxasset://sounds/action_falling.mp3", 0.1, 0.6)
	local nextGust = 1.5

	local cam = workspace.CurrentCamera
	local relEye, relLook
	local crossed, cut, plunged = false, false, false
	local orbit = 0
	local t0 = os.clock()
	over(duration + 0.1, function(dt, a)
		local t = os.clock() - t0
		skyUpdate(t, crossed)
		local body = char:GetPivot().Position

		-- the middle of the party
		local centroid, n = Vector3.zero, 0
		for _, r in ipairs(partyRoots(partyIds)) do
			if (r.Position - body).Magnitude < 90 then
				centroid += r.Position
				n += 1
			end
		end
		centroid = n > 0 and centroid / n or body
		local focus = body:Lerp(centroid, 0.4)

		-- how hard you're falling, 0..1
		local speedK = math.clamp((a - CALM) / 0.35, 0, 1)
		for _, au in pairs(auras) do au.update(dt, speedK, crossed) end
		windLoop.Volume = 0.1 + speedK * 0.55
		windLoop.PlaybackSpeed = 0.6 + speedK * 0.5
		windRush.Volume = speedK * 0.9
		windRush.PlaybackSpeed = 0.8 + speedK * 0.35
		windBreeze.Volume = 0.35 * (1 - speedK * 0.6)
		if t > nextGust then
			nextGust = t + 1.2 + math.random() * 1.6
			play("rbxassetid://9119462099", 0.25 + speedK * 0.3, 0.9 + math.random() * 0.3)
		end
		for _, rig in pairs(rigs) do rig.update(t, speedK) end

		if a >= CALM and not plunged then
			-- the tip-over: the plunge begins
			plunged = true
			play("rbxassetid://9114446852", 0.55, 0.7)
			shake(0.5, 0.5)
			tween(cc, 2, { TintColor = Color3.fromRGB(235, 245, 255), Contrast = 0.1, Saturation = 0 })
		end

		if not cut and ((body.Y - landingPos.Y) > 75 and a < 0.985) then
			-- the camera sits AHEAD of you along the dive, looking back up at
			-- your face and your friends, and slowly turns round the line of
			-- the fall
			local u = progress(a)
			local tangent = (bez(math.min(u + 0.01, 1)) - bez(math.max(u - 0.01, 0)))
			tangent = tangent.Magnitude > 0.01 and tangent.Unit or Vector3.new(0, -1, 0)
			local ref = math.abs(tangent.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
			local sideA = tangent:Cross(ref).Unit
			local upA = sideA:Cross(tangent).Unit
			orbit += dt * (0.18 + speedK * 0.55)
			local ahead = 17 - speedK * 6
			local swing = (math.cos(orbit) * sideA + math.sin(orbit) * upA) * (7 + speedK * 3)
			local eye = tangent * ahead + swing
			-- during the calm, hang back wider and a little above
			if a < CALM + 0.05 then
				eye = eye:Lerp(tangent * 12 + upA * 9 + sideA * 16, 1 - smooth(math.clamp((a - (CALM - 0.1)) / 0.15, 0, 1)))
			end
			-- at certain moments the camera drops in right behind your head,
			-- angled down past it, so you see the clouds rushing up at you
			local headW = math.max(
				smooth(math.clamp((a - 0.37) / 0.04, 0, 1)) * (1 - smooth(math.clamp((a - 0.5) / 0.04, 0, 1))),
				smooth(math.clamp((a - 0.64) / 0.04, 0, 1)) * (1 - smooth(math.clamp((a - 0.76) / 0.04, 0, 1)))
			)
			local head = char:FindFirstChild("Head")
			local headLook
			if head and headW > 0 then
				local hp = head.Position - body
				eye = eye:Lerp(hp - tangent * 4.5 + upA * 2.2, headW)
				headLook = hp + tangent * 40
			end
			local k = 1 - math.exp(-6 * dt)
			relEye = relEye and relEye:Lerp(eye, k) or eye
			local look = (centroid - body) * 0.5
			if headLook then look = look:Lerp(headLook, headW) end
			relLook = relLook and relLook:Lerp(look, k) or look
			camCF = CFrame.lookAt(focus + relEye, focus + relLook) * CFrame.Angles(0, 0, math.sin(t * 0.6) * 0.05 * speedK)
			drive(camCF, 70 + speedK * 30, dt, 40)
			blur.Size = speedK * 3
			if speedK > 0.6 then shake(0.15 + speedK * 0.25, 0.2) end

			-- punching through the cloud deck: white-out, then another world
			if not crossed and (focus + relEye).Y < deckY - 4 then
				crossed = true
				flashTo(WHITE, 0.05, 0.9)
				shake(1.1, 0.7)
				blur.Size = 22
				play("rbxassetid://9114446852", 0.6, 0.8)
				play("rbxassetid://114743565978001", 0.45, 0.5)
				if calmTrack then tween(calmTrack, 0.6, { Volume = 0 }) task.delay(0.7, function() calmTrack:Stop() end) end
				player:SetAttribute("CrueltyRealm", true)
				tween(cc, 1.4, { TintColor = Color3.fromRGB(255, 212, 206), Contrast = 0.16, Saturation = 0.05 })
				tween(vignette, 1.2, { ImageColor3 = CRIMSON, ImageTransparency = 0.3 })
			end
		else
			-- hard cut to the arena floor, looking up at everyone coming in
			if not cut then
				cut = true
				local incoming = (body - landingPos) * Vector3.new(1, 0, 1)
				incoming = incoming.Magnitude > 1 and incoming.Unit or Vector3.new(0, 0, 1)
				relEye = landingPos - incoming * 18 + Vector3.new(0, 3, 0)
				camCF = CFrame.lookAt(relEye, body)
				camFov = 72
				shake(0.4, 0.4)
			end
			drive(CFrame.lookAt(relEye, centroid:Lerp(landingPos, 0.15)), 66, dt, 14)
			blur.Size = 2
		end
	end)
	local waited = 0
	while running and not landed and waited < 3 do
		waited += RunService.RenderStepped:Wait()
		skyUpdate(os.clock() - t0, true)
	end
	for _, au in pairs(auras) do au.destroy() end
	for _, rig in pairs(rigs) do rig.restore() end
	windLoop:Destroy()
	windRush:Destroy()
	windBreeze:Destroy()
	if calmTrack and calmTrack.IsPlaying then calmTrack:Stop() end
	player:SetAttribute("CrueltyRealm", true)
	task.delay(2, function() sky:Destroy() end)

	-- IMPACT
	local ground = landingPos or char:GetPivot().Position
	play("rbxassetid://83382878583668", 1, 0.85)
	play("rbxassetid://114743565978001", 0.6, 0.8)
	shake(1.6, 0.6)
	flashTo(Color3.fromRGB(255, 200, 190), 0.03, 0.35)
	blur.Size = 20
	tween(blur, 0.7, { Size = 2 })
	cc.TintColor = Color3.fromRGB(255, 190, 170)
	tween(cc, 1.4, { TintColor = Color3.fromRGB(255, 228, 220), Contrast = 0.08 })

	local lowAngle = math.random() * math.pi * 2
	camCF = CFrame.lookAt(ground + Vector3.new(math.cos(lowAngle) * 7, 1.5, math.sin(lowAngle) * 7), ground + Vector3.new(0, 1, 0))
	camFov = 92
	over(1.5, function(dt, a)
		local target = char:GetPivot().Position
		local eye = ground + Vector3.new(math.cos(lowAngle) * (7 - a * 2.2), 1.5 + a * 0.5, math.sin(lowAngle) * (7 - a * 2.2))
		drive(CFrame.lookAt(eye, target + Vector3.new(0, 0.6, 0)), 60, dt, 8)
	end)

	-- GET UP -> REVEAL
	play("rbxasset://sounds/action_get_up.mp3", 0.7, 0.9)
	local cutscene = workspace:FindFirstChild("CrueltyCutscene")
	local bossModel = cutscene and cutscene:FindFirstChild("Cruelty")
	local bossRoot = bossModel and bossModel:FindFirstChild("HumanoidRootPart")
	local bossPos = bossRoot and bossRoot.Position or (ground + Vector3.new(0, 0, 60))
	over(2.1, function(dt, a)
		local e = 1 - (1 - a) * (1 - a)
		local body = char:GetPivot().Position
		local toBoss = Vector3.new(bossPos.X, body.Y, bossPos.Z) - body
		toBoss = toBoss.Magnitude > 1 and toBoss.Unit or Vector3.new(0, 0, 1)
		local behind = body - toBoss * (8 + e * 4) + Vector3.new(0, 4 + e * 2.5, 0)
		local sidePos = ground + Vector3.new(math.cos(lowAngle) * 5, 2.1, math.sin(lowAngle) * 5)
		local eye = sidePos:Lerp(behind, e)
		local look = body:Lerp(Vector3.new(bossPos.X, body.Y + 2, bossPos.Z), e * 0.75) + Vector3.new(0, 1.4, 0)
		drive(CFrame.lookAt(eye, look), 62 + e * 8, dt, 7)
	end)
end

--==================================================
-- orchestration
--==================================================

local function restore()
	running = false
	player:SetAttribute("HideHud_CrueltyEntry", nil)
	diveArgs = nil
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then cam.CameraSubject = hum end
	end
	tween(topBar, 0.5, { Size = UDim2.fromScale(1, 0) })
	tween(bottomBar, 0.5, { Size = UDim2.fromScale(1, 0) })
	tween(vignette, 0.5, { ImageTransparency = 1 })
	if blur then tween(blur, 0.5, { Size = 0 }) end
	if cc then tween(cc, 0.5, { TintColor = WHITE, Brightness = 0, Saturation = 0, Contrast = 0 }) end
	for _, n in ipairs({ "CrueltyVortex", "CrueltyTunnel", "CrueltySky" }) do
		local f = workspace:FindFirstChild(n)
		if f then f:Destroy() end
	end
	task.delay(0.7, function()
		if not running then
			gui.Enabled = false
			clearEffects()
		end
	end)
end

local function begin()
	running = true
	player:SetAttribute("HideHud_CrueltyEntry", true)
	landed = false
	ensureEffects()
	gui.Enabled = true
	vignette.ImageColor3 = VIOLET
end

local function waitForDive(timeout)
	local waited = 0
	while running and not diveArgs and waited < timeout do
		waited += task.wait(0.03)
	end
	return diveArgs
end

local function runFull(portalCF, pullTime, tunnelTime)
	begin()
	stagePull(portalCF, pullTime)
	if not running then return end
	stageTunnel(tunnelTime)
	if not running then return end
	local args = waitForDive(4)
	if args then stageDrop(args[1], args[2], args[3], args[4]) end
	task.wait(0.3)
	restore()
end

local function runDiveOnly(duration, landingPos, partyIds, startPos)
	begin()
	stageDrop(duration, landingPos, partyIds, startPos)
	task.wait(0.3)
	restore()
end

local fullRunning = false
remote.OnClientEvent:Connect(function(action, a, b, c, d)
	if action == "Portal" then
		fullRunning = true
		diveArgs = nil
		task.spawn(function()
			local ok, err = pcall(runFull, a, b or 1.8, c or 1.25)
			fullRunning = false
			if not ok then
				warn("[CrueltyEntry] cinematic failed: " .. tostring(err))
				restore()
			end
		end)
	elseif action == "Dive" then
		if fullRunning then
			diveArgs = { a or 2.3, b, c, d }
		elseif not running then
			task.spawn(function()
				local ok, err = pcall(runDiveOnly, a or 2.3, b, c, d)
				if not ok then
					warn("[CrueltyEntry] dive failed: " .. tostring(err))
					restore()
				end
			end)
		end
	elseif action == "DiveLanded" then
		landed = true
	end
end)

player.CharacterAdded:Connect(function()
	if running then restore() end
end)
