--==================================================
-- BOSS FIGHT: EFFECTS (client)
-- The fight's visual kit, built on the cutscene's Kit / SpiralKit:
--   road      - the ring of violet galaxy he walks on, below the rim
--   stomp     - a footfall: a mass of galaxy boils up under the foot + a blast
--   zone      - a red telegraph (circle or line) that fills up to its impact
--   blast     - an impact on the arena (flash, shockwave, sparks, dust)
--   galaxy    - a violet galaxy whirlpool (the cutscene's green one, in his colours)
--   bolt      - a parry's counter: spiral light from you into his chest
--==================================================
local Debris = game:GetService("Debris")

local Fx = {}

local UP = Vector3.yAxis
local VIOLET = Color3.fromRGB(160, 70, 255)
local VIOLET_HOT = Color3.fromRGB(232, 190, 255)
local VIOLET_DEEP = Color3.fromRGB(72, 22, 150)
local MAGENTA = Color3.fromRGB(255, 90, 220)
local RED = Color3.fromRGB(255, 40, 55)
local GREEN = Color3.fromRGB(70, 255, 120)
local LIME = Color3.fromRGB(190, 255, 90)
Fx.VIOLET, Fx.VIOLET_HOT, Fx.VIOLET_DEEP, Fx.MAGENTA, Fx.RED, Fx.GREEN, Fx.LIME = VIOLET, VIOLET_HOT, VIOLET_DEEP, MAGENTA, RED, GREEN, LIME

local SPARK = "1851669703"
local SMOKE = "10180479311"
local SOFT = "14582794847"
local SPIRAL_TEX, SPIRAL2_TEX = "14426232568", "124165682553877"
local ENERGY = "10365550877"

local K, SK, S, folder
local shakeFn = function() end

function Fx.init(kit, spiralKit, shared)
	K, SK, S = kit, spiralKit, shared
	folder = workspace:FindFirstChild("BossFightFx") or Instance.new("Folder")
	folder.Name = "BossFightFx"
	folder.Parent = workspace
	Fx.Folder = folder
end

function Fx.onShake(fn) shakeFn = fn end
function Fx.shake(amp, dur) shakeFn(amp, dur) end
local rollFn = function() end
function Fx.onRoll(fn) rollFn = fn end

--------------------------------------------------------------------------
-- A BIG HIT, felt through the whole screen: a blur, a bloom and sun-ray
-- flare, a contrast punch and a kick of the camera's roll (level 1..3)
--------------------------------------------------------------------------
local posts = {}
local function post(class, name, props)
	local e = posts[name]
	if not e or not e.Parent then
		e = Instance.new(class)
		e.Name = name
		for k, v in pairs(props) do e[k] = v end
		e.Parent = game:GetService("Lighting")
		posts[name] = e
	end
	return e
end
function Fx.bigHit(level)
	level = math.clamp(level or 1, 0.5, 3)
	local blur = post("BlurEffect", "BF_Blur", { Size = 0 })
	blur.Size = 5 * level
	K.tween(blur, 0.35 + 0.1 * level, { Size = 0 })
	local bloom = post("BloomEffect", "BF_Bloom", { Intensity = 0, Size = 40, Threshold = 0.85 })
	bloom.Intensity = 0.8 * level
	K.tween(bloom, 0.5, { Intensity = 0 })
	local rays = post("SunRaysEffect", "BF_Rays", { Intensity = 0, Spread = 0.8 })
	rays.Intensity = 0.12 * level
	K.tween(rays, 0.6, { Intensity = 0 })
	local cc = post("ColorCorrectionEffect", "BF_Punch", { Contrast = 0, Saturation = 0 })
	cc.Contrast = 0.25 * level
	cc.Saturation = 0.25 * level
	K.tween(cc, 0.4, { Contrast = 0, Saturation = 0 })
	rollFn((math.random() < 0.5 and -1 or 1) * 2.5 * level, 0.45)
end

--------------------------------------------------------------------------
-- IMPACT FRAMES (the cutscene's): a few frames of the world flipped to a
-- flat card with every body in silhouette and speed lines, pattern letters
-- W (white card) B (black) R G V Y (red, green, violet, gold cards)
--------------------------------------------------------------------------
local boss
function Fx.setBoss(m) boss = m end
function Fx.impact(pattern, frameTime, extra)
	local subjects = { boss }
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		if p.Character then table.insert(subjects, p.Character) end
	end
	for _, m in ipairs(extra or {}) do table.insert(subjects, m) end
	task.spawn(K.impact, subjects, pattern or "WBW", frameTime or 0.05, { Outline = true })
end

-- one of the game's VFX pack effects (FinalCutscene.Assets.VFX), fired at pos
function Fx.vfx(name, pos, scale, count, life)
	local p: any = pos
	local cf = if typeof(p) == "CFrame" then p else CFrame.new(p)
	return K.vfx(name, cf, folder, scale or 1, count, life or 5)
end

-- a pulse of colour over the whole screen (post grade)
local grade
function Fx.tint(color, strength, dur, contrast)
	grade = grade or Instance.new("ColorCorrectionEffect")
	grade.Name = "BF_Tint"
	grade.Parent = game:GetService("Lighting")
	grade.Enabled = true
	grade.TintColor = Color3.new(1, 1, 1):Lerp(color, strength)
	grade.Contrast = contrast or 0.15
	grade.Saturation = 0.1
	K.tween(grade, dur or 0.6, { TintColor = Color3.new(1, 1, 1), Contrast = 0, Saturation = 0 })
end
-- hold a grade (the sky darkening for his ultimate); nil lets go
function Fx.hold(color, strength, time)
	grade = grade or Instance.new("ColorCorrectionEffect")
	grade.Name = "BF_Tint"
	grade.Parent = game:GetService("Lighting")
	grade.Enabled = true
	if color then
		K.tween(grade, time or 0.8, { TintColor = Color3.new(1, 1, 1):Lerp(color, strength), Brightness = -0.08 * strength, Contrast = 0.2 * strength })
	else
		K.tween(grade, time or 0.8, { TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0 })
	end
end

-- him, speaking: the cutscene's lines (its font, its animation, his name plate)
local LINE_COOLDOWN = 5
local lastLine = 0
function Fx.say(text, hold, force)
	if not force and os.clock() - lastLine < LINE_COOLDOWN then return end
	lastLine = os.clock()
	task.spawn(K.say, text, hold or 1.1, { Scale = 0.066, Speaker = "Anti-Spiral" })
end

-- a 3-D sound at a point (heard from the arena)
function Fx.sound(id, pos, vol, speed, range)
	local host = K.part({ Name = "Snd", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(pos) }, folder)
	local s = K.sfx(id, vol or 1, speed or 1, { Parent = host })
	s.RollOffMaxDistance = range or 1500
	s.RollOffMinDistance = (range or 1500) * 0.15
	Debris:AddItem(host, 8)
	return s
end

local function emitAt(pos, props, count, life)
	local host = K.part({ Name = "FxHost", Size = props.HostSize or Vector3.one, Transparency = 1, CFrame = CFrame.new(pos) }, folder)
	props.HostSize = nil
	local e = K.emitter(host, props)
	e:Emit(count)
	Debris:AddItem(host, life or 4)
	return e, host
end
Fx.emitAt = emitAt

--------------------------------------------------------------------------
-- THE GALAXY ROAD: a ring of violet space round the arena at his feet
--------------------------------------------------------------------------
function Fx.road(floorY)
	local set = Instance.new("Folder")
	set.Name = "GalaxyRoad"
	set.Parent = folder
	local c = Vector3.new(S.CENTER.X, floorY, S.CENTER.Z)
	local host = K.part({ Name = "RoadHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(c) }, set)
	-- a soft glowing band under his path
	local band = K.softRing(host, 72, S.WALK_R - 150, S.WALK_R + 150, { Brightness = 1.6, Alpha = 0.55, Profile = { 0, 0, 0.25, 0.8, 0.5, 1, 0.75, 0.8, 1, 0 } })
	for _, q in ipairs(band.Q) do q.Color = ColorSequence.new(VIOLET_DEEP, VIOLET) end
	band.update(CFrame.lookAt(c + UP * 1, c + UP * 2), S.WALK_R - 150, S.WALK_R + 150, 0)
	local rim = K.softRing(host, 72, S.WALK_R - 8, S.WALK_R + 8, { Brightness = 3, Alpha = 0.5 })
	for _, q in ipairs(rim.Q) do q.Color = ColorSequence.new(VIOLET_HOT, VIOLET) end
	rim.update(CFrame.lookAt(c + UP * 2, c + UP * 3), S.WALK_R - 8, S.WALK_R + 8, 0)
	-- galaxies turning slowly in it
	local swirls = {}
	local n = 10
	for i = 1, n do
		local a = (i - 1) / n * math.pi * 2 + 0.3
		local r = S.WALK_R + (i % 2 == 0 and 60 or -55)
		local p = c + Vector3.new(math.cos(a) * r, 3, math.sin(a) * r)
		local tex = K.GalaxyTex[(i - 1) % #K.GalaxyTex + 1]
		local size = 170 + (i % 3) * 40
		local q = K.quad(host, CFrame.lookAt(p, p + UP), size, size, tex, { Color = (i % 2 == 0) and Color3.fromRGB(200, 140, 255) or Color3.fromRGB(150, 110, 255), Brightness = 1.4, Transparency = 0.35 })
		table.insert(swirls, { Q = q, P = p, Spin = (i % 2 == 0 and 1 or -1) * (0.05 + (i % 3) * 0.02) })
	end
	-- nebula and star motes drifting up off it
	local hosts = {}
	local segs = 16
	for i = 1, segs do
		local a = (i - 0.5) / segs * math.pi * 2
		local p = c + Vector3.new(math.cos(a) * S.WALK_R, 20, math.sin(a) * S.WALK_R)
		local seg = K.part({ Name = "RoadSeg", Size = Vector3.new(230, 20, 2 * math.pi * S.WALK_R / segs), Transparency = 1,
			CFrame = CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a))) }, set) -- (X across the road, Z along it)
		K.emitter(seg, {
			Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(190, 120, 255), Color3.fromRGB(90, 40, 190)),
			Size = K.ns(0, 60, 1, 170), Transparency = K.ns(0, 1, 0.3, 0.72, 0.7, 0.78, 1, 1), Lifetime = NumberRange.new(5, 8),
			Speed = NumberRange.new(2, 8), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-8, 8), Rate = 1.4, Shape = Enum.ParticleEmitterShape.Box, LightEmission = 0.8,
		})
		K.emitter(seg, {
			Texture = SPARK, Color = ColorSequence.new(Color3.new(1, 1, 1), VIOLET_HOT), Size = K.ns(0, 0, 0.2, 9, 1, 0),
			Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(4, 16), SpreadAngle = Vector2.new(30, 30),
			Rate = 4, Brightness = 4, Acceleration = Vector3.new(0, 6, 0), Shape = Enum.ParticleEmitterShape.Box,
		})
		table.insert(hosts, seg)
	end
	local R = { Set = set }
	function R.update(t)
		for _, s in ipairs(swirls) do
			K.moveQuad(s.Q, CFrame.lookAt(s.P, s.P + UP) * CFrame.Angles(0, 0, t * s.Spin))
		end
	end
	return R
end

--------------------------------------------------------------------------
-- STOMPS: where a foot comes down a mass of violet galaxy boils up
-- under it (as in the cutscene's charge), with a blast as it lands
--------------------------------------------------------------------------
local pads, steps = {}, {}
local PAD_R = 115

local function buildStomps()
	if #pads > 0 then return end
	local base = S.CENTER - UP * 400
	for i = 1, 6 do
		local host = K.part({ Name = "PadHost", Size = Vector3.new(2 * PAD_R, 1, 2 * PAD_R), Transparency = 1, CFrame = CFrame.new(base) }, folder)
		local disc = K.part({ Name = "PadDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 2 * PAD_R, 2 * PAD_R), Material = Enum.Material.Neon, Color = Color3.fromRGB(34, 12, 66), Transparency = 1, CFrame = CFrame.new(base) }, folder)
		local swirl = K.quad(host, CFrame.lookAt(base, base + UP), 2 * PAD_R, 2 * PAD_R, SPIRAL_TEX, { Color = Color3.fromRGB(185, 110, 255), Brightness = 2.2, Transparency = 0.15 })
		local swirl2 = K.quad(host, CFrame.lookAt(base, base + UP), 1.3 * PAD_R, 1.3 * PAD_R, SPIRAL2_TEX, { Color = Color3.fromRGB(235, 200, 255), Brightness = 1.6, Transparency = 0.35 })
		swirl.Enabled, swirl2.Enabled = false, false
		local rim = K.softRing(host, 40, PAD_R - 6, PAD_R + 6, { Brightness = 5, Alpha = 0 })
		for _, q in ipairs(rim.Q) do q.Color = ColorSequence.new(Color3.fromRGB(245, 225, 255), VIOLET) end
		rim.setTransparency(0.99)
		local motes = K.emitter(host, {
			Texture = SOFT, Color = ColorSequence.new(Color3.fromRGB(215, 150, 255), Color3.fromRGB(150, 70, 255)),
			Size = K.ns(0, 0, 0.15, 7, 0.8, 5, 1, 0), Lifetime = NumberRange.new(1.6, 3), Speed = NumberRange.new(6, 30),
			SpreadAngle = Vector2.new(20, 20), Brightness = 5, Shape = Enum.ParticleEmitterShape.Box, Acceleration = Vector3.new(0, 12, 0),
		})
		local cloud = K.emitter(host, {
			Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(200, 130, 255), Color3.fromRGB(100, 45, 200)),
			Size = K.ns(0, 60, 1, 200), Transparency = K.ns(0, 0.45, 0.6, 0.65, 1, 1), Lifetime = NumberRange.new(0.9, 1.5),
			Speed = NumberRange.new(10, 50), SpreadAngle = Vector2.new(60, 60), LightEmission = 1,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30), Shape = Enum.ParticleEmitterShape.Box,
		})
		-- its inlay: dotted arms of light spiralling in, and a dotted ring (as in the cutscene)
		local inlay = {}
		for arm = 1, 3 do
			for seg = 1, 8 do
				local b = K.ray(host, base, base + UP, 6, 6, SOFT, { Color = Color3.fromRGB(230, 200, 255), Brightness = 5, Transparency = 0.1, Segments = 1, Mode = Enum.TextureMode.Wrap, Length = 7 })
				b.Enabled = false
				table.insert(inlay, { B = b, Arm = arm, Seg = seg })
			end
		end
		for seg = 1, 16 do
			local b = K.ray(host, base, base + UP, 5, 5, SOFT, { Color = Color3.fromRGB(200, 160, 255), Brightness = 4, Transparency = 0.2, Segments = 1, Mode = Enum.TextureMode.Wrap, Length = 7 })
			b.Enabled = false
			table.insert(inlay, { B = b, Ring = seg })
		end
		table.insert(pads, { Host = host, Disc = disc, Swirl = swirl, Swirl2 = swirl2, Rim = rim, Motes = motes, Cloud = cloud, Inlay = inlay, Spin = math.random() * 6 })
	end
	for i = 1, 5 do
		local host = K.part({ Name = "StepHost", Size = Vector3.new(260, 1, 260), Transparency = 1, CFrame = CFrame.new(base) }, folder)
		local ring = K.softRing(host, 36, 50, 130, { Brightness = 4, Alpha = 0 })
		for _, q in ipairs(ring.Q) do q.Color = ColorSequence.new(VIOLET_HOT, VIOLET) end
		ring.setTransparency(0.99)
		local sparks = K.emitter(host, {
			Texture = SPARK, Color = ColorSequence.new(VIOLET_HOT, VIOLET), Size = K.ns(0, 30, 0.4, 50, 1, 0),
			Lifetime = NumberRange.new(0.8, 1.5), Speed = NumberRange.new(120, 400), SpreadAngle = Vector2.new(35, 35),
			Acceleration = Vector3.new(0, -300, 0), Brightness = 5, Shape = Enum.ParticleEmitterShape.Box,
		})
		local smoke = K.emitter(host, {
			Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(150, 80, 230), Color3.fromRGB(40, 15, 80)),
			Size = K.ns(0, 110, 1, 380), Transparency = K.ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(1.4, 2.4),
			Speed = NumberRange.new(40, 180), SpreadAngle = Vector2.new(80, 80), LightEmission = 0.3,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40), Drag = 2, Shape = Enum.ParticleEmitterShape.Box,
		})
		table.insert(steps, { Host = host, Ring = ring, Sparks = sparks, Smoke = smoke })
	end
end

local nextPad, nextStep = 1, 1
-- a footfall at `pos` (on his floor); power ~0.3 (a shuffle) .. 1.2 (a stamp) .. 3 (an attack)
function Fx.stomp(pos, power)
	buildStomps()
	local P = pads[nextPad]
	nextPad = nextPad % #pads + 1
	P.At, P.Pos, P.Power = os.clock(), pos, power
	local St = steps[nextStep]
	nextStep = nextStep % #steps + 1
	St.At, St.Pos, St.Power = os.clock(), pos, power
	St.Host.CFrame = CFrame.new(pos + UP * 3)
	St.Sparks:Emit(math.floor(24 * power))
	St.Smoke:Emit(math.floor(8 * power))
	Fx.sound(power > 1.5 and K.S.RockBoom or (math.random() < 0.5 and K.S.StepL or K.S.StepR), pos, math.clamp(0.5 + power * 0.4, 0.5, 1.6), 0.55 + math.random() * 0.1, 2500)
	if power > 0.6 then Fx.sound(K.S.Thump, pos, 0.8 * power, 0.7, 2500) end
	Fx.shake(0.35 + power * 0.55, 0.35 + power * 0.2)
end

function Fx.updateStomps()
	local now = os.clock()
	for _, P in ipairs(pads) do
		if P.At then
			local age = now - P.At
			local form = K.E.outCubic(math.clamp(age / 0.25, 0, 1))
			local fade = math.clamp((age - 0.7) / 1.6, 0, 1)
			if fade >= 1 then
				P.At = nil
				P.Disc.Transparency = 1
				P.Swirl.Enabled, P.Swirl2.Enabled = false, false
				P.Rim.setTransparency(0.99)
				P.Motes.Rate, P.Cloud.Rate = 0, 0
				for _, e in ipairs(P.Inlay) do e.B.Enabled = false end
			else
				local r = PAD_R * math.clamp(0.55 + P.Power * 0.4, 0.5, 1.6) * (0.2 + 0.8 * form) * (1 + 0.1 * fade)
				local vis = form * (1 - fade)
				local at = P.Pos + UP * 2
				P.Disc.Size = Vector3.new(3, 2 * r, 2 * r)
				P.Disc.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
				P.Disc.Transparency = 1 - 0.9 * vis
				local flat = CFrame.lookAt(at + UP * 1.8, at + UP * 3)
				P.Swirl.Enabled, P.Swirl2.Enabled = vis > 0.02, vis > 0.02
				K.moveQuad(P.Swirl, flat * CFrame.Angles(0, 0, P.Spin + now * 0.5))
				K.setQuadSize(P.Swirl, 2 * r * 0.98, 2 * r * 0.98)
				K.moveQuad(P.Swirl2, flat * CFrame.Angles(0, 0, -P.Spin - now * 0.9))
				K.setQuadSize(P.Swirl2, 1.3 * r, 1.3 * r)
				P.Swirl.Transparency = NumberSequence.new(1 - 0.85 * vis)
				P.Swirl2.Transparency = NumberSequence.new(1 - 0.65 * vis)
				P.Rim.update(CFrame.lookAt(at + UP * 2.4, at + UP * 4), r - 5, r + 7, now * 0.4)
				P.Rim.setTransparency(math.min(0.99, 1 - vis))
				P.Host.Size = Vector3.new(1.6 * r, 1, 1.6 * r)
				P.Host.CFrame = CFrame.new(at + UP * 3)
				P.Motes.Rate = fade > 0 and 0 or 60 * form
				P.Cloud.Rate = fade > 0 and 0 or 9 * form
				local on = vis > 0.02
				local spin = P.Spin + now * 0.35
				for _, e in ipairs(P.Inlay) do
					e.B.Enabled = on
					if on then
						local p0, p1
						if e.Ring then
							local a0, a1 = (e.Ring - 1) / 16 * math.pi * 2 - spin * 0.6, e.Ring / 16 * math.pi * 2 - spin * 0.6
							p0 = at + Vector3.new(math.cos(a0), 0, math.sin(a0)) * r * 0.55
							p1 = at + Vector3.new(math.cos(a1), 0, math.sin(a1)) * r * 0.55
						else
							local function arm(u) -- u 0 at the heart, 1 at the rim
								local th = (e.Arm - 1) / 3 * math.pi * 2 + spin + u * math.pi * 1.6
								return at + Vector3.new(math.cos(th), 0, math.sin(th)) * r * (0.08 + 0.84 * u)
							end
							p0, p1 = arm((e.Seg - 1) / 8), arm(e.Seg / 8)
						end
						e.B.Attachment0.WorldPosition = p0 + UP * 2.6
						e.B.Attachment1.WorldPosition = p1 + UP * 2.6
						e.B.Transparency = NumberSequence.new(1 - 0.9 * vis)
					end
				end
			end
		end
	end
	for _, St in ipairs(steps) do
		if St.At then
			local u = (now - St.At) / (1.0 * math.sqrt(St.Power))
			if u >= 1 then
				St.At = nil
				St.Ring.setTransparency(0.99)
			else
				local r = St.Power * 110 + St.Power * 600 * (1 - (1 - u) ^ 3)
				St.Ring.update(CFrame.lookAt(St.Pos + UP * 5, St.Pos + UP * 6), r, r + 40 + r * 0.15, u)
				St.Ring.setTransparency(math.min(0.99, 0.05 + u ^ 1.2 * 0.94))
			end
		end
	end
end

--------------------------------------------------------------------------
-- RED ZONES: a telegraph that fills up until its impact at T
--------------------------------------------------------------------------
local function flatDisc(name, pos, r, color, tr)
	return K.part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2 * r, 2 * r), Material = Enum.Material.Neon,
		Color = color, Transparency = tr, CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2) }, folder)
end

-- A shockwave wall rolling out over the floor: solid neon segments (a
-- violet wall, a white crest, a dark base so it reads on the gold) with
-- a violet glow behind, and, when warn is set, a red line racing ahead of
-- it. Additive light alone washes out to white on the gold floor.
--   local w = Fx.shockRing(host, segs, H, W, warn)
--   w.update(origin, radius, on, now)   -- each frame (clips to the arena)
function Fx.shockRing(host, segs, H, W, warn)
	local PARK = CFrame.new(S.CENTER.X, S.CENTER.Y - 450, S.CENTER.Z) -- (out of sight, above the fallen-parts height)
	local function seg(color, material, transparency)
		return K.part({ Name = "ShockSeg", Size = Vector3.one, Color = color, Material = material, Transparency = transparency, CFrame = PARK }, host)
	end
	local walls, crests, bases, aheads, glows = {}, {}, {}, {}, {}
	for i = 1, segs do
		walls[i] = seg(VIOLET, Enum.Material.Neon, 0.05)
		crests[i] = seg(Color3.new(1, 1, 1), Enum.Material.Neon, 0)
		bases[i] = seg(VIOLET_DEEP, Enum.Material.SmoothPlastic, 0)
		if warn then aheads[i] = seg(RED, Enum.Material.Neon, 0.1) end
		local g = K.quad(host, host.CFrame, 1, H * 2.6, SMOKE, { Color = VIOLET, Brightness = 2, Transparency = K.ns(0, 0.35, 0.5, 0.6, 1, 1) })
		g.Enabled = false
		glows[i] = g
	end
	local parts, cfs = {}, {}
	local function put(p, cf, size)
		if p.Size ~= size then p.Size = size end
		parts[#parts + 1] = p
		cfs[#cfs + 1] = cf
	end
	local function park(p)
		if p.CFrame ~= PARK then
			parts[#parts + 1] = p
			cfs[#cfs + 1] = PARK
		end
	end
	local w = {}
	function w.update(o, r, on, now)
		o = Vector3.new(o.X, S.CENTER.Y, o.Z)
		local da = 2 * math.pi / segs
		local ra = r + 14 + 4 * math.sin(now * 20)
		for i = 1, segs do
			local c0, s0 = math.cos((i - 1) * da), math.sin((i - 1) * da)
			local c1, s1 = math.cos(i * da), math.sin(i * da)
			local p0 = o + Vector3.new(c0 * r, 0, s0 * r)
			local p1 = o + Vector3.new(c1 * r, 0, s1 * r)
			local mid = (p0 + p1) / 2
			local show = on and r > 0.5 and S.onArena(mid, -2)
			glows[i].Enabled = show
			if show then
				local along = p1 - p0
				local len = along.Magnitude * 1.04
				local base = CFrame.fromMatrix(mid, along.Unit, UP)
				put(walls[i], base * CFrame.new(0, H / 2, 0), Vector3.new(len, H, 1.2))
				put(crests[i], base * CFrame.new(0, H + 0.3, 0), Vector3.new(len, 0.6, 1.6))
				put(bases[i], base * CFrame.new(0, 0.8, 0), Vector3.new(len, 1.6, W))
				K.moveQuad(glows[i], base * CFrame.new(0, H * 1.3, 0))
				K.setQuadSize(glows[i], len, H * 2.6)
			else
				park(walls[i])
				park(crests[i])
				park(bases[i])
			end
			if warn then
				-- where it'll be in a moment
				local q0 = o + Vector3.new(c0 * ra, 0, s0 * ra)
				local q1 = o + Vector3.new(c1 * ra, 0, s1 * ra)
				local qm = (q0 + q1) / 2
				if on and S.onArena(qm, -2) then
					local along = q1 - q0
					put(aheads[i], CFrame.fromMatrix(qm + UP * 0.15, along.Unit, UP), Vector3.new(along.Magnitude * 1.04, 0.3, 1.8))
				else
					park(aheads[i])
				end
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			table.clear(parts)
			table.clear(cfs)
		end
	end
	return w
end

-- shape: circle / line (see Shared); t0 = when it appears; T = impact
function Fx.zone(shape, t0, T)
	local Z = { Parts = {} }
	local y = S.CENTER.Y + 0.12
	if shape.Kind == "circle" then
		local p = Vector3.new(shape.P.X, y, shape.P.Z)
		local base = flatDisc("ZoneBase", p, shape.R, RED, 0.78)
		local fill = flatDisc("ZoneFill", p + UP * 0.03, 0.1, Color3.fromRGB(255, 70, 70), 0.45)
		local host = K.part({ Name = "ZoneHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(p) }, folder)
		local rim = K.softRing(host, 32, shape.R - 1.2, shape.R + 0.6, { Brightness = 3, Alpha = 0 })
		for _, q in ipairs(rim.Q) do q.Color = ColorSequence.new(Color3.fromRGB(255, 120, 120), RED) end
		table.insert(Z.Parts, base)
		table.insert(Z.Parts, fill)
		table.insert(Z.Parts, host)
		function Z.update(now)
			local u = K.remap(now, t0, T)
			local r = math.max(shape.R * K.E.inQuad(u), 0.1)
			fill.Size = Vector3.new(0.2, 2 * r, 2 * r)
			local pulse = 0.5 + 0.5 * math.sin(now * (8 + 16 * u))
			base.Transparency = 0.82 - 0.14 * pulse * u
			rim.update(CFrame.lookAt(p + UP * 0.25, p + UP * 1), shape.R - 1.2, shape.R + 0.6, now)
			rim.setTransparency(0.35 - 0.3 * pulse * u)
		end
	else
		local a = Vector3.new(shape.A.X, y, shape.A.Z)
		local b = Vector3.new(shape.B.X, y, shape.B.Z)
		local mid, len = a:Lerp(b, 0.5), (b - a).Magnitude
		local cf = CFrame.lookAt(mid, mid + (b - a))
		local base = K.part({ Name = "ZoneBase", Size = Vector3.new(shape.W, 0.2, len), Material = Enum.Material.Neon, Color = RED, Transparency = 0.8, CFrame = cf }, folder)
		local fill = K.part({ Name = "ZoneFill", Size = Vector3.new(0.1, 0.22, len), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 70, 70), Transparency = 0.45, CFrame = cf + UP * 0.03 }, folder)
		local edges = {}
		for s = -1, 1, 2 do
			table.insert(edges, K.part({ Name = "ZoneEdge", Size = Vector3.new(0.45, 0.24, len), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 140, 140), Transparency = 0.2, CFrame = cf * CFrame.new(s * shape.W / 2, 0.05, 0) }, folder))
		end
		table.insert(Z.Parts, base)
		table.insert(Z.Parts, fill)
		for _, e in ipairs(edges) do table.insert(Z.Parts, e) end
		function Z.update(now)
			local u = K.remap(now, t0, T)
			fill.Size = Vector3.new(math.max(shape.W * K.E.inQuad(u), 0.1), 0.22, len)
			local pulse = 0.5 + 0.5 * math.sin(now * (8 + 16 * u))
			base.Transparency = 0.84 - 0.14 * pulse * u
			for _, e in ipairs(edges) do e.Transparency = 0.45 - 0.35 * pulse * u end
		end
	end
	function Z.destroy()
		for _, p in ipairs(Z.Parts) do p:Destroy() end
		Z.Parts = {}
	end
	return Z
end

--------------------------------------------------------------------------
-- IMPACTS
--------------------------------------------------------------------------
function Fx.blast(pos, radius, color, opts)
	opts = opts or {}
	color = color or VIOLET
	local hot = opts.Hot or color:Lerp(Color3.new(1, 1, 1), 0.6)
	local p = Vector3.new(pos.X, S.CENTER.Y + 0.3, pos.Z)
	-- the flash
	local ball = K.part({ Name = "Flash", Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 0.6, Material = Enum.Material.Neon, Color = hot, Transparency = 0.05, CFrame = CFrame.new(p) }, folder)
	K.tween(ball, 0.35, { Size = Vector3.one * radius * 2.4, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Debris:AddItem(ball, 0.4)
	-- the shockwave on the floor
	local host = K.part({ Name = "WaveHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(p) }, folder)
	local ring = K.softRing(host, 32, radius * 0.5, radius, { Brightness = 4, Alpha = 0 })
	for _, q in ipairs(ring.Q) do q.Color = ColorSequence.new(hot, color) end
	local t0 = os.clock()
	task.spawn(function()
		while host.Parent do
			local u = (os.clock() - t0) / 0.55
			if u >= 1 then break end
			local r = radius * (0.4 + 1.6 * K.E.outCubic(u))
			ring.update(CFrame.lookAt(p + UP * 0.4, p + UP * 2), r * 0.8, r * 1.05 + 2, u)
			ring.setTransparency(math.min(0.99, u ^ 1.3))
			task.wait()
		end
		host:Destroy()
	end)
	-- sparks, dust, a column of light
	emitAt(p + UP, {
		Texture = SPARK, Color = ColorSequence.new(hot, color), Size = K.ns(0, radius * 0.35, 1, 0),
		Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(radius * 2, radius * 5), SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -radius * 4, 0), Brightness = 5, EmissionDirection = Enum.NormalId.Top,
	}, math.floor(20 + radius), 2)
	emitAt(p + UP * 2, {
		Texture = SMOKE, Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.3), Color3.fromRGB(30, 15, 50)),
		Size = K.ns(0, radius * 0.6, 1, radius * 2.2), Transparency = K.ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(radius * 0.8, radius * 2), SpreadAngle = Vector2.new(90, 90), LightEmission = 0.4,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40), Drag = 3,
	}, 10, 3)
	if opts.Column ~= false then
		-- (a cylinder part lies along X: stood up on end)
		local col = K.part({ Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(120, radius * 0.7, radius * 0.7), Material = Enum.Material.Neon, Color = hot, Transparency = 0.2,
			CFrame = CFrame.new(p + UP * 60) * CFrame.Angles(0, 0, math.pi / 2) }, folder)
		K.tween(col, 0.45, { Size = Vector3.new(160, radius * 0.05, radius * 0.05), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Debris:AddItem(col, 0.5)
	end
	-- rubble thrown out of it, and a scorch left behind
	if radius >= 10 and opts.Debris ~= false then
		for _ = 1, math.clamp(math.floor(radius / 3), 3, 14) do
			local sz = math.random(10, 26) / 10 * math.clamp(radius / 14, 0.6, 2.2)
			local c = K.part({ Name = "Rubble", Size = Vector3.new(sz, sz * 0.8, sz * 1.1), Material = Enum.Material.Slate,
				Color = Color3.fromRGB(math.random(40, 70), math.random(25, 45), math.random(70, 110)), CFrame = CFrame.new(p) }, folder)
			local dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
			local out = dir * radius * (0.6 + math.random() * 0.8)
			local up = radius * (0.5 + math.random() * 0.8)
			local spin = Vector3.new(math.random(), math.random(), math.random()) * 12
			local r0 = os.clock()
			task.spawn(function()
				local life = 0.9 + math.random() * 0.4
				while c.Parent do
					local u = (os.clock() - r0) / life
					if u >= 1 then break end
					local pos = p + out * u + Vector3.new(0, up * 4 * u * (1 - u), 0)
					c.CFrame = CFrame.new(pos) * CFrame.Angles(spin.X * u, spin.Y * u, spin.Z * u)
					c.Transparency = math.max(0, (u - 0.7) / 0.3)
					task.wait()
				end
				c:Destroy()
			end)
		end
		local scorch = K.part({ Name = "Scorch", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, radius * 1.3, radius * 1.3), Material = Enum.Material.Neon,
			Color = color:Lerp(Color3.new(0, 0, 0), 0.55), Transparency = 0.25, CFrame = CFrame.new(p + UP * 0.05) * CFrame.Angles(0, 0, math.pi / 2) }, folder)
		K.tween(scorch, 3, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(scorch, 3.1)
	end
	-- (the VFX pack's explosion and cracks, for the heavier ones)
	if opts.Pack ~= false and radius >= 12 then
		Fx.vfx("Explosion-01", p + UP * 2, radius / 18, math.floor(8 + radius * 0.3), 4)
		Fx.vfx(radius >= 30 and "Big-Crack-01" or "Crack-01", p + UP * 0.3, radius / (radius >= 30 and 40 or 16), nil, 5)
	end
	Fx.sound(opts.Sound or K.S.Impact, p, opts.Volume or 1, opts.Speed or (0.9 + math.random() * 0.2), 900)
	local cam = workspace.CurrentCamera
	local d = (cam.CFrame.Position - p).Magnitude
	Fx.shake(math.clamp((opts.Shake or 1.2) * (1 - d / 400), 0.15, 2.5), 0.35)
	if (opts.Shake or 1.2) >= 2 and d < 700 then Fx.bigHit((opts.Shake or 2) / 1.5) end
end

--------------------------------------------------------------------------
-- THE VIOLET GALAXY: SK.burst from the cutscene, in the Anti-Spiral's colours
--------------------------------------------------------------------------
-- palette (optional): { main, accent, pale } - his violet by default
function Fx.galaxy(host, palette)
	local C1, C2, C3 = VIOLET, MAGENTA, Color3.fromRGB(210, 170, 255)
	if palette then C1, C2, C3 = palette[1], palette[2], palette[3] end
	local G = {}
	G.V1 = K.quad(host, CFrame.new(), 10, 10, SPIRAL_TEX, { Color = C1, Brightness = 2.4, Transparency = 0.35 })
	G.V2 = K.quad(host, CFrame.new(), 10, 10, SPIRAL2_TEX, { Color = C2, Brightness = 2.6, Transparency = 0.45 })
	G.V3 = K.quad(host, CFrame.new(), 10, 10, SPIRAL_TEX, { Color = C3, Brightness = 1.6, Transparency = 0.55 })
	G.Arms = {}
	local ARMS, SEGS = 4, 10
	for a = 1, ARMS do
		local list = {}
		for i = 1, SEGS do
			local b = K.ray(host, Vector3.zero, UP, 10, 10, ENERGY, {
				Color = (a % 2 == 0) and C2 or C1, Brightness = 4, Transparency = 0.1, Segments = 2,
				Mode = Enum.TextureMode.Wrap, Length = 300, Speed = -3,
			})
			b.Enabled = false
			list[i] = b
		end
		G.Arms[a] = list
	end
	G.Glow = SK.glow(K, host, Vector3.zero, 10, C1, 2.5, SOFT)
	G.Core = SK.glow(K, host, Vector3.zero, 10, C3:Lerp(Color3.new(1, 1, 1), 0.6), 5, SOFT)
	G.Rays = {}
	local r = Random.new(7)
	for i = 1, 8 do
		local b = K.ray(host, Vector3.zero, UP, 10, 1, "rbxasset://sky/sun.jpg", { Color = (i % 3 == 0) and Color3.new(1, 1, 1) or C1, Brightness = 3, Transparency = K.ns(0, 0.1, 1, 1), Segments = 1 })
		b.Enabled = false
		G.Rays[i] = { B = b, D = r:NextUnitVector(), L = r:NextNumber(0.6, 1.3), P = r:NextNumber(0, 6) }
	end
	for _, q in ipairs({ G.V1, G.V2, G.V3 }) do q.Enabled = false end
	-- pos: its heart; toward: the way it faces; size: across; amount 0..1
	function G.set(pos, toward, size, amount, t)
		local on = amount > 0.01
		for _, q in ipairs({ G.V1, G.V2, G.V3 }) do q.Enabled = on end
		for _, r2 in ipairs(G.Rays) do r2.B.Enabled = on end
		for _, list in ipairs(G.Arms) do for _, b in ipairs(list) do b.Enabled = on end end
		G.Glow.set(pos, size * 0.9 * (0.8 + 0.2 * amount), on and amount * 0.3 or 0)
		G.Core.set(pos, size * 0.1 * (1 + 0.15 * math.sin(t * 17)), on and amount * 0.7 or 0)
		if not on then return end
		local dir0 = (toward - pos).Unit
		local e1 = dir0:Cross(math.abs(dir0.Y) > 0.9 and Vector3.xAxis or UP).Unit
		local e2 = dir0:Cross(e1)
		local R = size * 0.62
		local spin = t * 0.6
		for a, list in ipairs(G.Arms) do
			local a0 = (a - 1) / #G.Arms * math.pi * 2 + spin
			local n = #list
			local function at(u)
				local th = a0 + (1 - u) * math.pi * 2.3
				local rr = R * (0.08 + 0.92 * u) * math.min(1, amount * 1.4)
				return pos + (e1 * math.cos(th) + e2 * math.sin(th)) * rr + dir0 * (1 - u) * size * 0.05
			end
			for i, b in ipairs(list) do
				local u0, u1 = 1 - (i - 1) / n, 1 - i / n
				b.Attachment0.WorldPosition = at(u0)
				b.Attachment1.WorldPosition = at(u1)
				b.Width0 = size * (0.035 + 0.06 * (1 - u0)) * amount
				b.Width1 = size * (0.035 + 0.06 * (1 - u1)) * amount
			end
		end
		local s = size * amount
		K.moveQuad(G.V1, CFrame.lookAt(pos, pos + dir0) * CFrame.Angles(0, 0, t * 2))
		K.setQuadSize(G.V1, s * 1.3, s * 1.3)
		K.moveQuad(G.V2, CFrame.lookAt(pos + dir0 * s * 0.08, pos + dir0) * CFrame.Angles(0, 0, -t * 3.5))
		K.setQuadSize(G.V2, s * 0.8, s * 0.8)
		K.moveQuad(G.V3, CFrame.lookAt(pos + dir0 * s * 0.2, pos + dir0) * CFrame.Angles(0, 0, t * 5))
		K.setQuadSize(G.V3, s * 0.45, s * 0.45)
		for _, r2 in ipairs(G.Rays) do
			local len = s * r2.L * (0.7 + 0.3 * math.sin(t * 9 + r2.P))
			r2.B.Attachment0.WorldPosition = pos
			r2.B.Attachment1.WorldPosition = pos + r2.D * len
			r2.B.Width0 = s * 0.06
		end
	end
	return G
end

--------------------------------------------------------------------------
-- PARRY: a green burst at you, and a spiral bolt into his chest
--------------------------------------------------------------------------
function Fx.parryBurst(pos, perfect)
	local col = perfect and Color3.fromRGB(255, 255, 160) or GREEN
	local ball = K.part({ Name = "Parry", Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Material = Enum.Material.Neon, Color = col, Transparency = 0, CFrame = CFrame.new(pos) }, folder)
	K.tween(ball, 0.3, { Size = Vector3.one * (perfect and 26 or 18), Transparency = 1 })
	Debris:AddItem(ball, 0.35)
	emitAt(pos, {
		Texture = "11381556016", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = ColorSequence.new(GREEN, LIME), Size = K.ns(0, 4, 1, 0), Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(25, 70), SpreadAngle = Vector2.new(180, 180), Brightness = 4, Rotation = NumberRange.new(0, 360),
	}, perfect and 40 or 24, 2)
	Fx.vfx("Shield-Break-01", pos, perfect and 1.4 or 1, nil, 3)
	Fx.sound(K.S.MetalHit, pos, 1.2, perfect and 1.25 or 1.05, 400)
	Fx.sound(K.S.Ring, pos, 0.7, perfect and 1.6 or 1.3, 400)
	if perfect then Fx.sound(K.S.Electric, pos, 0.8, 1.2, 400) end
end

function Fx.bolt(from, to, perfect)
	local host = K.part({ Name = "BoltHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(from) }, folder)
	local beams = {}
	for i = 1, perfect and 3 or 2 do
		local b, a0, a1 = K.ray(host, from, from, perfect and 5 or 3, 1.5, ENERGY, {
			Color = (i % 2 == 0) and LIME or GREEN, Brightness = 5, Segments = 24, Mode = Enum.TextureMode.Wrap, Length = 20, Speed = 6,
		})
		b.CurveSize0 = (i % 2 == 0 and 1 or -1) * 40
		b.CurveSize1 = (i % 2 == 0 and -1 or 1) * 60
		table.insert(beams, { B = b, A0 = a0, A1 = a1 })
	end
	local t0 = os.clock()
	local hitDone = false
	task.spawn(function()
		while host.Parent do
			local u = (os.clock() - t0) / 0.3
			local head = from:Lerp(to, K.E.outCubic(math.min(u, 1)))
			for _, b in ipairs(beams) do
				b.A1.WorldPosition = head
				if u > 1 then b.B.Transparency = NumberSequence.new(math.min(1, (u - 1) / 0.6)) end
			end
			if u >= 1 and not hitDone then
				hitDone = true
				local g = K.part({ Name = "BoltHit", Shape = Enum.PartType.Ball, Size = Vector3.one * 20, Material = Enum.Material.Neon, Color = perfect and Color3.fromRGB(255, 255, 170) or GREEN, CFrame = CFrame.new(to) }, folder)
				K.tween(g, 0.4, { Size = Vector3.one * (perfect and 120 or 80), Transparency = 1 })
				Debris:AddItem(g, 0.45)
				emitAt(to, {
					Texture = SPARK, Color = ColorSequence.new(Color3.new(1, 1, 1), GREEN), Size = K.ns(0, 14, 1, 0),
					Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(80, 220), SpreadAngle = Vector2.new(180, 180), Brightness = 5,
				}, 30, 2)
				Fx.sound(K.S.BigHit, to, 1.2, perfect and 1.1 or 1, 2500)
			end
			if u >= 1.6 then break end
			task.wait()
		end
		host:Destroy()
	end)
end

return Fx
