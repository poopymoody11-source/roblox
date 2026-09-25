--==================================================
-- CHAPTERS 13-17: SOUL, AWAKEN, SPLIT, ASCEND, VERSUS
-- Out of your body -> spiral energy -> back in -> the green
-- surges through your veins -> you stand and point to the
-- heavens -> JUST WHO THE HELL DO YOU THINK WE ARE! ->
-- the ascent, the Spiral Bat, and the versus card.
--==================================================
local Ch = {}

local GREEN = Color3.fromRGB(70, 255, 120)
local LIME = Color3.fromRGB(190, 255, 90)

local function knockPoint(ctx, slot)
	local s = ctx.TL.ArenaStand(slot)
	return Vector3.new(s.X - 7, ctx.TL.ArenaCenter.Y, s.Z)
end

local function lyingCF(ctx, slot)
	local kp = knockPoint(ctx, slot)
	local home = ctx.BossHome
	local q = Vector3.new(kp.X - 5, ctx.TL.ArenaCenter.Y + 0.6, kp.Z)
	return CFrame.lookAt(q, Vector3.new(home.X, q.Y, home.Z)) * CFrame.Angles(math.rad(88), 0, math.rad(8 * ((slot % 2) * 2 - 1)))
end

--==================================================
-- INSIDE THE SOUL: a living network of blood vessels round a
-- beating heart. The spiral energy floods it green from the heart
-- outward, the blood races, and the heart starts to hammer.
--==================================================
local INNER = Vector3.new(-12000, 9000, 20000)
local BLOOD = Color3.fromRGB(135, 10, 24)
local WALL = Color3.fromRGB(85, 6, 18)
local WALL_G = Color3.fromRGB(12, 70, 34)

local function buildInner(ctx)
	local K = ctx.kit
	local set = Instance.new("Folder")
	set.Name = "InnerSet"
	ctx.sets.Inner = set
	local rng = Random.new(610)
	local inner = { Branches = {}, Segs = {}, Cells = {}, Phase = 0, LastBeat = -10, MaxD = 0 }
	ctx.Inner = inner
	local host = K.part({ Name = "InnerHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(INNER) }, set)
	inner.Host = host
	-- the heart
	local src = K.Assets:FindFirstChild("Heart")
	local heart
	if src then
		heart = src:Clone()
		heart.Size = src.Size * 1.6
	else
		heart = K.part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 34 }, nil)
	end
	heart.Anchored = true
	heart.CanCollide = false
	heart.CanQuery = false
	heart.CanTouch = false
	heart.CastShadow = false
	heart.Material = Enum.Material.SmoothPlastic
	heart.Color = Color3.fromRGB(140, 20, 32)
	heart.Reflectance = 0.1
	heart.CFrame = CFrame.new(INNER) * CFrame.Angles(math.rad(-8), math.rad(200), math.rad(-14))
	heart.Parent = set
	inner.Heart = heart
	inner.HeartBase = heart.Size
	inner.HeartCF = heart.CFrame
	local hl = Instance.new("Highlight")
	hl.FillColor = GREEN
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.fromRGB(255, 110, 110)
	hl.OutlineTransparency = 0.7
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = heart
	inner.HL = hl
	local pl = Instance.new("PointLight")
	pl.Range = 110
	pl.Brightness = 2
	pl.Color = Color3.fromRGB(255, 70, 70)
	pl.Parent = heart
	inner.Light = pl
	-- a key light that sits between the heart and the lens, so it has shape
	local key = K.part({ Name = "Key", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(INNER) }, set)
	local kl = Instance.new("PointLight")
	kl.Range = 80
	kl.Brightness = 2.5
	kl.Color = Color3.fromRGB(255, 170, 160)
	kl.Parent = key
	inner.Key = key
	inner.KeyLight = kl
	-- soft glow behind it, and the ring each beat sends out
	inner.Glow = K.quad(host, CFrame.new(INNER), 120, 120, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(255, 60, 70), Brightness = 1.2, Transparency = 0.55 })
	inner.Ring = K.softRing(host, 56, 20, 40, { Brightness = 2.5, Alpha = 0 })
	inner.Ring.setTransparency(0.99)

	-- the vessels: a branching tree of translucent tubes, each with a glowing core
	local function node(p, r)
		K.part({ Name = "N", Shape = Enum.PartType.Ball, Size = Vector3.one * r * 2, CFrame = CFrame.new(p), Material = Enum.Material.SmoothPlastic, Color = WALL, Transparency = 0.45, Reflectance = 0.15 }, set)
	end
	local function seg(a, b, r, d0, d1)
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		local wall = K.part({ Name = "V", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len + r * 0.2, r * 2, r * 2), CFrame = cf, Material = Enum.Material.SmoothPlastic, Color = WALL, Transparency = 0.45, Reflectance = 0.15 }, set)
		local core = K.part({ Name = "C", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len + r * 0.2, r * 0.8, r * 0.8), CFrame = cf, Material = Enum.Material.Neon, Color = BLOOD, Transparency = 0.35 }, set)
		table.insert(inner.Segs, { Wall = wall, Core = core, D = (d0 + d1) / 2, G = 0 })
	end
	local count = 0
	local function grow(p, dir, r, depth, dist)
		count += 1
		if count > 100 then return end
		local pts, ds = { p }, { dist }
		local d = dir
		local n = depth == 0 and 5 or rng:NextInteger(3, 5)
		for _ = 1, n do
			d = (d + rng:NextUnitVector() * 0.42).Unit
			local len = math.max(r * rng:NextNumber(5, 8), 5)
			local q = p + d * len
			seg(p, q, r, dist, dist + len)
			node(q, r)
			dist += len
			p = q
			table.insert(pts, p)
			table.insert(ds, dist)
		end
		inner.MaxD = math.max(inner.MaxD, dist)
		table.insert(inner.Branches, { Pts = pts, D = ds, R = r, L = ds[#ds] - ds[1], Depth = depth })
		if depth < 4 then
			for k = 2, #pts do
				if rng:NextNumber() < (depth == 0 and 0.75 or 0.45) then
					grow(pts[k], (d + rng:NextUnitVector() * 1.1).Unit, r * 0.62, depth + 1, ds[k])
				end
			end
		end
	end
	-- seven great vessels out of the heart
	local dirs = { Vector3.new(0, 1, 0.2), Vector3.new(0.7, 0.6, -0.2), Vector3.new(-0.8, 0.5, 0.1), Vector3.new(0.3, -0.8, 0.6), Vector3.new(-0.4, -0.7, -0.6), Vector3.new(0.9, -0.2, 0.5), Vector3.new(-0.6, 0.1, 0.9) }
	for _, dv in ipairs(dirs) do
		local dir = dv.Unit
		grow(INNER + dir * 13, dir, 3.6, 0, 0)
	end
	-- blood cells riding the vessels
	local total = 0
	for _, br in ipairs(inner.Branches) do total += br.L * br.R end
	for _ = 1, 260 do
		local pick = rng:NextNumber() * total
		local br = inner.Branches[1]
		for _, b in ipairs(inner.Branches) do
			pick -= b.L * b.R
			if pick <= 0 then br = b break end
		end
		local c = K.part({ Name = "Cell", Shape = Enum.PartType.Cylinder, Size = Vector3.new(br.R * 0.28, br.R * 0.95, br.R * 0.95), CFrame = CFrame.new(INNER), Material = Enum.Material.Neon, Color = Color3.fromRGB(190, 22, 40) }, set)
		local off = rng:NextUnitVector() * br.R * rng:NextNumber(0.1, 0.55)
		table.insert(inner.Cells, { Part = c, B = br, S = rng:NextNumber() * br.L, Off = off, Spin = rng:NextNumber(1, 5), G = 0 })
	end
	inner.CellParts = {}
	for i, c in ipairs(inner.Cells) do inner.CellParts[i] = c.Part end
end

-- where along a branch a distance s falls
local function alongBranch(br, s)
	local pts, ds = br.Pts, br.D
	local target = ds[1] + s
	for i = 1, #pts - 1 do
		if target <= ds[i + 1] or i == #pts - 1 then
			local u = math.clamp((target - ds[i]) / math.max(ds[i + 1] - ds[i], 0.01), 0, 1)
			return pts[i]:Lerp(pts[i + 1], u), (pts[i + 1] - pts[i]).Unit, target
		end
	end
	return pts[#pts], Vector3.zAxis, target
end

local function heartShape(f)
	-- lub... dub
	return math.exp(-((f - 0.06) / 0.045) ^ 2) + 0.65 * math.exp(-((f - 0.27) / 0.05) ^ 2)
end

-- one frame inside; ti = seconds since we went in
local function updateInner(ctx, ti, dt, heartSound)
	local K = ctx.kit
	local E = K.E
	local inner = ctx.Inner
	local FLOOD = 2.0
	local fl = K.k(ti, FLOOD, FLOOD + 2.8, E.inOutSine)
	local race = K.k(ti, FLOOD, 5.8, E.inQuad)
	local bpm = K.lerp(56, 72, K.k(ti, 0, FLOOD)) + race * 170
	local before = inner.Phase
	inner.Phase += dt * bpm / 60
	local beat = math.floor(inner.Phase) > math.floor(before)
	local f = inner.Phase % 1
	local pulse = heartShape(f)
	-- the heart
	local s = 1 + pulse * (0.07 + 0.09 * race)
	inner.Heart.Size = inner.HeartBase * s
	inner.Heart.CFrame = inner.HeartCF * CFrame.Angles(math.sin(ti * 1.3) * 0.05, ti * 0.15, pulse * 0.04 * (1 + race))
	inner.Heart.Color = Color3.fromRGB(140, 20, 32):Lerp(Color3.fromRGB(150, 60, 50), fl)
	inner.HL.FillTransparency = 1 - fl * (0.06 + 0.16 * pulse)
	inner.HL.OutlineColor = Color3.fromRGB(255, 110, 110):Lerp(LIME, fl)
	inner.HL.OutlineTransparency = 0.7 - fl * 0.5
	inner.Light.Color = Color3.fromRGB(255, 70, 70):Lerp(GREEN, fl)
	inner.Light.Brightness = 1.5 + pulse * (3 + race * 5)
	local cam = workspace.CurrentCamera.CFrame
	inner.Key.CFrame = CFrame.new(INNER + (cam.Position - INNER).Unit * 38 + Vector3.new(0, 12, 0))
	inner.KeyLight.Brightness = 2.2 + pulse * (1.5 + race * 2)
	inner.KeyLight.Color = Color3.fromRGB(255, 170, 160):Lerp(Color3.fromRGB(190, 255, 200), fl * 0.7)
	local gs = (95 + pulse * 45) * (1 + fl * 0.6)
	K.moveQuad(inner.Glow, CFrame.lookAt(INNER, cam.Position))
	K.setQuadSize(inner.Glow, gs, gs)
	inner.Glow.Color = ColorSequence.new(Color3.fromRGB(255, 60, 70):Lerp(GREEN, fl))
	inner.Glow.Transparency = K.ns(math.clamp(0.6 - pulse * 0.2 - fl * 0.15, 0.1, 0.95))
	-- a ring rolls out with every beat
	if beat then
		inner.LastBeat = ti
		K.shake(0.25 + race * 1.1, 0.25, 16, true)
	end
	local rb = ti - inner.LastBeat
	if rb < 0.7 then
		local u = rb / 0.7
		local r0 = 18 + u * (70 + race * 60)
		inner.Ring.update(CFrame.lookAt(INNER, cam.Position), r0, r0 + 8 + u * 20, u)
		inner.Ring.setTransparency(math.min(0.99, 0.5 + u * 0.5))
		for _, q in ipairs(inner.Ring.Q) do q.Color = ColorSequence.new(Color3.fromRGB(255, 90, 90):Lerp(LIME, fl)) end
	else
		inner.Ring.setTransparency(0.99)
	end
	-- the green front races out along every vessel from the heart
	local front = fl * (inner.MaxD + 40)
	for _, sg in ipairs(inner.Segs) do
		local g = math.clamp((front - sg.D) / 22, 0, 1)
		if math.abs(g - sg.G) > 0.03 or (g == 1 and sg.G < 1) then
			sg.G = g
			sg.Core.Color = BLOOD:Lerp(GREEN, g)
			sg.Wall.Color = WALL:Lerp(WALL_G, g)
		end
	end
	-- the blood: slow and dark, then racing and green
	local v = K.lerp(7, 75, race) * (0.7 + pulse * 0.6)
	local cfs = {}
	for i, c in ipairs(inner.Cells) do
		local br = c.B
		c.S = (c.S + dt * v * (0.55 + br.R / 8)) % br.L
		local p, tan, d = alongBranch(br, c.S)
		cfs[i] = CFrame.lookAt(p + c.Off, p + c.Off + tan) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(ti * c.Spin, 0, 0)
		local g = math.clamp((front - d) / 22, 0, 1)
		if math.abs(g - c.G) > 0.05 or (g == 1 and c.G < 1) then
			c.G = g
			c.Part.Color = Color3.fromRGB(190, 22, 40):Lerp(LIME, g)
		end
	end
	workspace:BulkMoveTo(inner.CellParts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	if heartSound then
		heartSound.PlaybackSpeed = math.clamp(bpm / 62, 0.8, 3.6)
		heartSound.Volume = 0.9
	end
	return pulse, fl, race
end

function Ch.build(ctx)
	local K = ctx.kit
	local set = Instance.new("Folder")
	set.Name = "RiseSet"
	ctx.sets.Rise = set
	-- the spiral energy: a pulsing double helix + a turning green vortex
	local sp = Instance.new("Model")
	sp.Name = "SpiralEnergy"
	local core = K.part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.5, Material = Enum.Material.Neon, Color = GREEN, Transparency = 0.1 }, sp)
	sp.PrimaryPart = core
	local balls = {}
	for i = 1, 26 do
		table.insert(balls, K.part({ Name = "H", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7, Material = Enum.Material.Neon, Color = i % 2 == 0 and GREEN or LIME }, sp))
	end
	local light = Instance.new("PointLight", core)
	light.Color = GREEN
	light.Range = 30
	light.Brightness = 5
	local vort = K.part({ Name = "VortexHost", Size = Vector3.one, Transparency = 1 }, sp)
	local q1 = K.quad(vort, CFrame.new(), 14, 14, "14426232568", { Color = GREEN, Brightness = 1.8, Transparency = 0.3 })
	local q2 = K.quad(vort, CFrame.new(), 9, 9, "124165682553877", { Color = LIME, Brightness = 1.8, Transparency = 0.3 })
	local aura = K.emitter(core, {
		Texture = "11381556016", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.OneShot, Color = ColorSequence.new(GREEN), Size = K.ns(0, 3, 1, 0), Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(180, 180), Rate = 40, Brightness = 4, Rotation = NumberRange.new(0, 360),
	})
	sp.Parent = set
	ctx.Spiral = { Model = sp, Core = core, Balls = balls, Light = light, Q = { q1, q2 }, Aura = aura, Host = vort }
	-- streams from the spiral into the soul
	ctx.StreamHost = K.part({ Name = "StreamHost", Size = Vector3.one, Transparency = 1 }, set)
	ctx.Streams = {}
	for i = 1, 7 do
		local b = K.ray(ctx.StreamHost, Vector3.zero, Vector3.new(0, 1, 0), 0.6, 0.2, "10365550877", {
			Color = i % 2 == 0 and GREEN or LIME, Brightness = 4, Speed = 2, Mode = Enum.TextureMode.Wrap, Length = 6, Segments = 20,
		})
		b.CurveSize0 = math.random(-8, 8)
		b.CurveSize1 = math.random(-8, 8)
		b.Enabled = false
		table.insert(ctx.Streams, b)
	end
	-- the column the party rises in
	local col = K.part({ Name = "Column", Size = Vector3.one, Transparency = 1 }, set)
	ctx.ColumnHost = col
	-- the world inside you
	buildInner(ctx)
end

-- a translucent second copy of you
local function makeSoul(ctx)
	local K = ctx.kit
	local uid = ctx.roster[ctx.me or 1]
	local soul = K.rig(uid, ctx.stage)
	for _, p in ipairs(soul.Parts) do p.LocalTransparencyModifier = 0.55 end
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(200, 240, 255)
	h.FillTransparency = 0.65
	h.OutlineColor = Color3.new(1, 1, 1)
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = soul.Model
	soul.Glow = h
	return soul
end

-- green veins crawling over a rig
local function addVeins(ctx, rig)
	local K = ctx.kit
	if rig.Veins then return end
	rig.Veins = {}
	local function vein(part, a, b, w)
		if not part then return end
		local a0 = Instance.new("Attachment", part)
		a0.Position = a
		local a1 = Instance.new("Attachment", part)
		a1.Position = b
		local bm = Instance.new("Beam")
		bm.Attachment0 = a0
		bm.Attachment1 = a1
		bm.Width0 = (w or 0.14) * 1.7
		bm.Width1 = (w or 0.14) * 0.85
		bm.Color = ColorSequence.new(GREEN, LIME)
		bm.LightEmission = 1
		bm.LightInfluence = 0
		bm.Brightness = 4
		bm.FaceCamera = true
		bm.Segments = 12
		bm.CurveSize0 = math.random(-10, 10) / 10
		bm.CurveSize1 = math.random(-10, 10) / 10
		bm.Transparency = NumberSequence.new(1)
		bm.Parent = part
		table.insert(rig.Veins, { Beam = bm, Phase = math.random() * 2 })
	end
	local T = rig.Torso
	for i = 1, 4 do
		local x = (i - 2.5) * 0.4
		vein(T, Vector3.new(x * 0.5, 0.2, -0.52), Vector3.new(x * 1.8, 0.95, -0.52), 0.12)
		vein(T, Vector3.new(x * 0.5, -0.1, -0.52), Vector3.new(x * 1.4, -0.95, -0.52), 0.12)
	end
	for _, arm in ipairs({ "Right Arm", "Left Arm" }) do
		local p = rig:part(arm)
		vein(p, Vector3.new(0, 0.95, -0.51), Vector3.new(0.2, -0.9, -0.51), 0.13)
		vein(p, Vector3.new(0.3, 0.8, 0.51), Vector3.new(-0.2, -0.8, 0.51), 0.1)
	end
	for _, leg in ipairs({ "Right Leg", "Left Leg" }) do
		local p = rig:part(leg)
		vein(p, Vector3.new(0, 0.95, -0.51), Vector3.new(-0.2, -0.9, -0.51), 0.12)
	end
	local head = rig:head()
	vein(head, Vector3.new(0.3, -0.5, -0.55), Vector3.new(0.45, 0.2, -0.55), 0.08)
	vein(head, Vector3.new(-0.3, -0.5, -0.55), Vector3.new(-0.45, 0.25, -0.55), 0.08)
	local h = Instance.new("Highlight")
	h.FillColor = GREEN
	h.FillTransparency = 1
	h.OutlineColor = LIME
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = rig.Model
	rig.GreenGlow = h
	rig.Aura = K.emitter(rig.Torso, {
		Texture = "11381556016", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.OneShot, Color = ColorSequence.new(GREEN, LIME), Size = K.ns(0, 3, 1, 0), Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(3, 8), SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Top, Rate = 0, Brightness = 4,
		Rotation = NumberRange.new(0, 360), Shape = Enum.ParticleEmitterShape.Box,
	})
end

local function veinPulse(rig, t, amount)
	if not rig.Veins then return end
	for _, v in ipairs(rig.Veins) do
		local head = ((t * 1.6 + v.Phase) % 1)
		local a = 1 - amount
		v.Beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, math.min(1, a + 0.2)),
			NumberSequenceKeypoint.new(math.clamp(head - 0.1, 0.01, 0.97), math.min(1, a + 0.35)),
			NumberSequenceKeypoint.new(math.clamp(head, 0.02, 0.98), a * 0.3),
			NumberSequenceKeypoint.new(1, math.min(1, a + 0.3)),
		})
	end
	if rig.GreenGlow then
		rig.GreenGlow.FillTransparency = 1 - amount * (0.1 + 0.06 * math.sin(t * 8))
		rig.GreenGlow.OutlineTransparency = 1 - amount * 0.8
	end
end

-- the Spiral Bat: the bat turns into a glowing drill
local function upgradeBat(ctx, rig)
	local K = ctx.kit
	local bat = rig.Bat
	if not bat or rig.Spiral then return end
	rig.Spiral = true
	bat.Material = Enum.Material.Neon
	bat.Color = Color3.fromRGB(40, 190, 90)
	local cone = K.Assets.DrillCone:Clone()
	cone.Anchored = false
	cone.CanCollide = false
	cone.CanQuery = false
	cone.CanTouch = false
	cone.Massless = true
	cone.Material = Enum.Material.Neon
	cone.Color = LIME
	cone.Size = cone.Size * 1.6
	for _, d in ipairs(cone:GetChildren()) do if not d:IsA("SpecialMesh") then d:Destroy() end end
	local w = Instance.new("Weld")
	w.Part0 = bat
	w.Part1 = cone
	-- the cone points along the bat, past its tip
	w.C0 = CFrame.new(-bat.Size.X / 2 - cone.Size.Y * 0.45, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
	rig.ConeC0 = w.C0
	w.Parent = cone
	cone.Parent = rig.Model
	rig.Cone = cone
	rig.ConeWeld = w
	-- spiral trail wrapping the bat
	local a0 = Instance.new("Attachment", bat)
	a0.Position = Vector3.new(bat.Size.X / 2, 0, 0)
	local a1 = Instance.new("Attachment", bat)
	a1.Position = Vector3.new(-bat.Size.X / 2 - 1.5, 0, 0)
	for i = 1, 2 do
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = 0.5
		b.Width1 = 0.2
		b.Color = ColorSequence.new(i == 1 and GREEN or LIME)
		b.LightEmission = 1
		b.Brightness = 5
		b.Texture = "rbxassetid://10365550877"
		b.TextureSpeed = 3
		b.CurveSize0 = i == 1 and 1.2 or -1.2
		b.CurveSize1 = i == 1 and -1.2 or 1.2
		b.Segments = 16
		b.Parent = bat
	end
	K.emitter(bat, {
		Texture = "11381556016", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.OneShot, Color = ColorSequence.new(GREEN, LIME), Size = K.ns(0, 1.5, 1, 0), Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(1, 4), SpreadAngle = Vector2.new(180, 180), Rate = 30, Brightness = 2.5, Rotation = NumberRange.new(0, 360),
	})
	local pl = Instance.new("PointLight", bat)
	pl.Color = GREEN
	pl.Range = 14
	pl.Brightness = 2
end

------------------------------------------------------------------------
-- SOUL
------------------------------------------------------------------------
function Ch.Soul(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local set = ctx.sets.Rise
	set.Parent = ctx.stage
	local me = ctx.myRig
	local mySlot = ctx.me or 1
	local body = lyingCF(ctx, mySlot)
	local soul = makeSoul(ctx)
	ctx.Soul = soul
	soul:setCF(body * CFrame.new(0, 0, 0))
	local cue = K.once()
	local heart = K.loop(K.S.Heartbeat, 0.7, 0.5, 0.6)
	K.Grade.Saturation = -1
	K.vignette(0.6, Color3.new(0, 0, 0), 1)
	local sp = ctx.Spiral
	sp.Model.Parent = nil
	local home = ctx.BossHome
	-- beats
	local ABS0, ABS1 = 8.6, 10.4 -- the spiral energy pours into the soul
	local IN0 = 10.4 -- ...and we follow it inside
	local OUT = dur - 3.2 -- back out, into the body
	local inside = false
	local lastT = 0

	K.run(t0, dur, function(t, dt)
		local step = math.max(0, t - lastT)
		lastT = t
		-- bodies lie still (tiny breaths)
		for slot, rig in pairs(ctx.rigs) do
			rig:setCF(lyingCF(ctx, slot) * CFrame.new(0, math.sin(t * 1.3 + slot) * 0.03, 0))
			rig:setPose(K.Poses.LyingBack)
			rig:apply()
		end
		-- the soul sits up out of the body and floats upright
		local up = K.k(t, 0.6, 3.4, E.inOutSine)
		local standCF = CFrame.lookAt(body.Position + Vector3.new(0, 4.2, 0), Vector3.new(home.X, body.Position.Y + 4.2, home.Z))
		local soulCF = body:Lerp(standCF, up) * CFrame.new(0, math.sin(t * 1.1) * 0.3 * up, 0)
		local lookLeft = K.k(t, 5.8, 7.2, E.inOutSine)
		local reach = K.k(t, 8.0, 9.2, E.outBack)
		local back = K.k(t, OUT, OUT + 0.5, E.inCubic)
		local leftDir = -standCF.RightVector
		-- (held up against the dark sky: at eye level it vanished into the glowing floor)
		local spPos = standCF.Position + leftDir * 22 + Vector3.new(0, 4.5, 0)
		if back > 0 then
			soulCF = soulCF:Lerp(body, back)
		end
		if ctx.Soul then
			soul:setCF(soulCF)
			local pose = K.mixPose(K.Poses.LyingBack, K.Poses.Soul, up)
			pose.Neck = K.A(-4, 70 * lookLeft, 0)
			pose = K.mixPose(pose, { LS = K.A(80, 0, -60), Neck = K.A(0, 70, 0) }, reach)
			-- (arms open, chest out, as it takes the energy in)
			pose = K.mixPose(pose, { LS = K.A(20, 0, -70), RS = K.A(20, 0, 70), Neck = K.A(25, 20, 0) }, K.k(t, ABS0 + 0.6, ABS1, E.inOutSine))
			soul:setPose(pose)
			soul:apply()
			soul:alpha(K.lerp(0.55, 0.3, math.sin(t * 2) * 0.5 + 0.5) * (1 - back))
			if soul.Glow then soul.Glow.FillColor = Color3.fromRGB(200, 240, 255):Lerp(GREEN, K.k(t, ABS0, ABS1)) end
		end

		-- the spiral energy, pulsing with the heartbeat
		local show = K.k(t, 5.9, 6.8)
		if show > 0 and t < IN0 and not sp.Model.Parent then sp.Model.Parent = set end
		local beat = math.max(0, math.sin(t * math.pi * 2 * 0.8)) ^ 6
		local absorb = K.k(t, ABS0, ABS1, E.inQuad)
		local size = (1 + beat * 0.5) * show * (1 - absorb * 0.8)
		local spc = spPos:Lerp(soulCF.Position, absorb * 0.6)
		sp.Core.CFrame = CFrame.new(spc)
		sp.Core.Size = Vector3.one * math.max(0.05, 2.5 * size)
		sp.Light.Brightness = 3 + beat * 6
		for i, b in ipairs(sp.Balls) do
			local k = (i - 1) / #sp.Balls
			local side = i % 2 == 0 and 1 or -1
			local a = t * 4 + k * math.pi * 4 + (side > 0 and math.pi or 0)
			local y = (k - 0.5) * 9 * size
			b.CFrame = CFrame.new(spc + Vector3.new(math.cos(a) * 1.6 * size, y, math.sin(a) * 1.6 * size))
			b.Size = Vector3.one * math.max(0.05, 0.7 * size)
		end
		local cam = workspace.CurrentCamera.CFrame
		sp.Host.CFrame = CFrame.new(spc)
		K.moveQuad(sp.Q[1], CFrame.lookAt(spc, cam.Position) * CFrame.Angles(0, 0, t * 3))
		K.moveQuad(sp.Q[2], CFrame.lookAt(spc, cam.Position) * CFrame.Angles(0, 0, -t * 5))
		K.setQuadSize(sp.Q[1], 14 * size + 0.01, 14 * size + 0.01)
		K.setQuadSize(sp.Q[2], 9 * size + 0.01, 9 * size + 0.01)
		sp.Aura.Rate = (show > 0.5 and t < IN0) and 40 or 0
		if not inside and t < OUT then
			-- green colour bleeds into the grey world near it
			K.Grade.Saturation = -1 + show * 0.35 + absorb * 0.4
			K.Grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(200, 255, 210), show * 0.6)
		end
		-- streams pour into the soul
		for _, b in ipairs(ctx.Streams) do
			b.Enabled = absorb > 0 and absorb < 1
			b.Attachment0.WorldPosition = spc
			b.Attachment1.WorldPosition = soulCF.Position + Vector3.new(0, 0.5, 0)
			b.Width0 = 0.3 + absorb * 1.2
		end

		-- inside: the veins, the blood, the heart
		if inside then updateInner(ctx, t - IN0, step, heart) end

		-- camera
		if t < 5.2 then
			-- straight down on your body as your soul rises up toward the lens
			local e = K.k(t, 0, 5.2, E.inOutSine)
			local p = body.Position + Vector3.new(0.3, K.lerp(18, 13, e), 0.3)
			K.setCam(CFrame.lookAt(p, body.Position:Lerp(soulCF.Position, 0.5)) * CFrame.Angles(0, 0, e * 0.4), 50)
		elseif t < 9.4 then
			-- over the soul's right shoulder, then turning with it to the left
			-- (the camera swings round behind it, so the shoulder stays in frame)
			local e = K.k(t, 5.2, 7.4, E.inOutSine)
			local fwd = soulCF.LookVector * Vector3.new(1, 0, 1)
			local toSp = (spPos - soulCF.Position) * Vector3.new(1, 0, 1)
			local dir = fwd.Unit:Lerp(toSp.Unit, e).Unit
			local right = dir:Cross(Vector3.yAxis)
			local sh = soulCF.Position - dir * 5.5 + right * 2.4 + Vector3.new(0, 1.0, 0)
			local look = soulCF.Position + dir * 22 + Vector3.new(0, 3.8, 0)
			K.setCam(CFrame.lookAt(sh, look), K.lerp(50, 44, e))
		elseif t < IN0 then
			-- round to the front, and straight into its chest
			local e = K.k(t, 9.4, IN0, E.inCubic)
			local chest = soulCF.Position + Vector3.new(0, 1.2, 0)
			local toSp = ((spPos - soulCF.Position) * Vector3.new(1, 0, 1)).Unit
			local p = chest + toSp * K.lerp(9, 0.6, e) + Vector3.new(0, K.lerp(1.5, 0, e), 0)
			K.setCam(CFrame.lookAt(p, chest), K.lerp(50, 95, e * e))
		elseif t < OUT then
			local ti = t - IN0
			local inner = ctx.Inner
			local H = INNER
			if ti < 2.0 then
				-- racing down alongside one of the great vessels toward the heart
				local br = inner.Branches[1]
				local e = K.k(ti, 0, 2.2, E.outCubic)
				local L = br.L
				local p = alongBranch(br, K.lerp(L, 6, e))
				local side = (p - H):Cross(Vector3.yAxis)
				side = side.Magnitude > 0.1 and side.Unit or Vector3.xAxis
				local cp = p + side * 15 + Vector3.new(0, 7, 0)
				K.setCam(CFrame.lookAt(cp, H:Lerp(p, 0.3)) * CFrame.Angles(0, 0, math.sin(ti * 1.3) * 0.08), K.lerp(80, 58, e))
			elseif ti < 4.4 then
				-- round the heart as the green floods out of it
				local e = K.k(ti, 2.0, 4.4, E.inOutSine)
				local a = K.lerp(0.4, 2.3, e)
				local r = K.lerp(62, 78, e)
				local cp = H + Vector3.new(math.cos(a) * r, 14 - e * 6, math.sin(a) * r)
				K.setCam(CFrame.lookAt(cp, H + Vector3.new(0, 2, 0)), 58)
			else
				-- in on the heart as it hammers
				local e = K.k(ti, 4.4, OUT - IN0, E.inQuad)
				local a = 2.3 + e * 0.4
				local r = K.lerp(60, 30, e)
				local cp = H + Vector3.new(math.cos(a) * r, 8 - e * 4, math.sin(a) * r)
				K.setCam(CFrame.lookAt(cp, H), K.lerp(58, 72, e))
				K.Blur.Enabled = true
				K.Blur.Size = e * 6
			end
		else
			-- snap back down into the body
			local e = K.k(t, OUT, dur)
			local head = me and me:head() and me:head().Position or body.Position
			local p = head + Vector3.new(0, K.lerp(12, 3, e), 0.2)
			K.setCam(CFrame.lookAt(p, head), K.lerp(60, 40, e))
		end
		cue("ring", t >= 0.2, function() K.sfx(K.S.Ring, 0.18, 1, { Life = 6 }) end)
		cue("left", t >= 5.9, function()
			K.sfx(K.S.GreenAura, 0.8)
			K.sfx(K.S.Sting, 0.5, 1.2)
			K.muffle(0.4, 1)
		end)
		cue("absorb", t >= ABS0, function()
			K.sfx(K.S.Riser, 0.9, 1.1)
			K.sfx(K.S.Magic or K.S.GreenAura, 0.6, 1.2)
			heart.PlaybackSpeed = 0.9
		end)
		cue("in", t >= IN0, function()
			inside = true
			ctx.sets.Inner.Parent = ctx.stage
			sp.Model.Parent = nil
			K.lighting("Inner", 0)
			K.flash(0.35, Color3.fromRGB(255, 120, 120), 0.6)
			K.sfx(K.S.Whoosh, 0.9, 0.8)
			K.sfx(K.S.Rumble, 0.5, 0.6)
			K.muffle(0.6, 0.3)
			K.vignette(0.55, Color3.fromRGB(40, 0, 6), 0.3)
		end)
		cue("flood", t >= IN0 + 2.0, function()
			K.sfx(K.S.GreenAura, 1, 0.8)
			K.sfx(K.S.Electric, 0.7)
			K.sfx(K.S.Riser, 0.8, 1.3)
			K.flash(0.3, GREEN, 0.4)
			K.muffle(0.2, 1)
			K.vignette(0.45, Color3.fromRGB(0, 40, 14), 1.5)
		end)
		cue("race", t >= IN0 + 4.4, function()
			K.sfx(K.S.Overdrive, 0.7)
			K.sfx(K.S.Choir, 0.4, 1.3)
		end)
		cue("out", t >= OUT, function()
			inside = false
			ctx.sets.Inner.Parent = nil
			K.Blur.Enabled = false
			K.lighting("Arena", 0)
			K.flash(0.5, GREEN, 1)
		end)
		cue("return", t >= OUT + 0.3, function()
			local subjects = {}
			if ctx.Soul then table.insert(subjects, soul.Model) end
			if me then table.insert(subjects, me.Model) end
			task.spawn(K.impact, subjects, "GWG", 0.05)
			K.sfx(K.S.Whoosh, 1, 1.2)
			K.sfx(K.S.BigHit, 0.9)
			K.flash(0.7, GREEN)
			K.muffle(0, 0.3)
			K.tween(K.Grade, 0.6, { Saturation = 0.35, Contrast = 0.25, TintColor = Color3.fromRGB(215, 255, 225), Brightness = 0 })
			K.vignette(0.3, Color3.fromRGB(0, 60, 20), 0.5)
			sp.Model.Parent = nil
			if ctx.Soul then soul:destroy() ctx.Soul = nil end
			heart.PlaybackSpeed = 1.6
			heart.Volume = 0.7
		end)
	end)
	if ctx.Soul then ctx.Soul:destroy() ctx.Soul = nil end
	if ctx.sets.Inner then ctx.sets.Inner.Parent = nil end
	for _, b in ipairs(ctx.Streams) do b.Enabled = false end
	ctx.Heart = heart
end

------------------------------------------------------------------------
-- AWAKEN
------------------------------------------------------------------------
function Ch.Awaken(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local set = ctx.sets.Rise
	set.Parent = ctx.stage
	local me = ctx.myRig
	local cue = K.once()
	local home = ctx.BossHome
	for _, rig in pairs(ctx.rigs) do
		addVeins(ctx, rig)
		if not rig.Bat then rig:giveBat() end
	end
	local heart = ctx.Heart
	ctx.setMusic(K.S.M_Battle, 0, 0)
	ctx.fadeMusic(0.35, 3)
	local A = K.A

	K.run(t0, dur, function(t, dt)
		local surge = K.k(t, 0, 2.2, E.outQuad)
		for slot, rig in pairs(ctx.rigs) do
			local d = ((slot - 1) % 4) * 0.12
			local tr = t - d
			veinPulse(rig, t + slot, math.min(1, surge + K.k(tr, 5.5, 6.5) * 0.3))
			if rig.Aura then rig.Aura.Rate = 25 + K.k(tr, 5.5, 6.5) * 60 end
			local ly = lyingCF(ctx, slot)
			local stand = ctx.TL.ArenaStand(slot)
			local kp = Vector3.new(ly.Position.X, stand.Y, ly.Position.Z)
			local face = CFrame.lookAt(kp, Vector3.new(home.X, kp.Y, home.Z))
			-- lying -> sit up -> kneel -> stand -> point to the sky
			local keys = {
				{ 0.0, { p = 88, h = 0.6, pose = K.Poses.LyingBack } },
				{ 1.4, { p = 88, h = 0.6, pose = { Neck = A(-20, 0, 0), RS = A(10, 0, 50), LS = A(10, 0, -45) } } },
				{ 2.4, { p = 30, h = 1.3, pose = { Neck = A(-10, 0, 0), RS = A(-20, 0, 25), LS = A(-30, 0, -20), RH = A(80, 0, 5), LH = A(75, 0, -5) } } },
				{ 3.4, { p = -10, h = 2.05, pose = { Neck = A(10, 0, 0), RS = A(30, 0, 15), LS = A(-10, 0, -10), RH = A(88, 0, 0), LH = A(-58, 0, 0) } } },
				{ 4.6, { p = 0, h = 3.0, pose = { Neck = A(15, 0, 0), RS = A(15, 0, 12), LS = A(5, 0, -12), RH = A(-4, 0, 4), LH = A(4, 0, -4) } } },
				{ 6.0, { p = 3, h = 3.0, pose = K.Poses.PointUp } },
			}
			local a, b = keys[1], keys[#keys]
			for i = 1, #keys - 1 do
				if tr <= keys[i + 1][1] then a, b = keys[i], keys[i + 1] break end
			end
			local u = (b[1] > a[1]) and math.clamp((tr - a[1]) / (b[1] - a[1]), 0, 1) or 1
			u = E.inOutSine(u)
			local pitch = K.lerp(a[2].p, b[2].p, u)
			local h = K.lerp(a[2].h, b[2].h, u)
			local pose = K.mixPose(a[2].pose, b[2].pose, u)
			if tr > 6 then pose.RS = pose.RS * A(math.sin(t * 20) * 1.5, 0, 0) end
			rig:setCF(CFrame.new(kp.X, ctx.TL.ArenaCenter.Y + h, kp.Z) * face.Rotation * CFrame.Angles(math.rad(pitch), 0, 0))
			rig:setPose(pose)
			rig:apply()
		end
		if heart then heart.PlaybackSpeed = K.lerp(1.6, 2.6, K.k(t, 0, 5)) heart.Volume = 0.7 * (1 - K.k(t, 5.5, 6.5)) end
		local center = me and me:cf().Position or knockPoint(ctx, 1)
		local head = me and me:head() and me:head().Position or center
		-- camera
		if t < 2.4 then
			-- close on your arm: the veins lighting up
			local arm = me and me:part("Right Arm")
			local ap = arm and arm.Position or center
			K.setCam(CFrame.lookAt(ap + Vector3.new(2.5, 2.2, 2.5), ap), 38)
			K.shake(0.4 + surge, 0.1, 20, true)
		elseif t < 5.6 then
			-- rising with you, low angle
			local e = K.k(t, 2.4, 5.6, E.inOutSine)
			local rcf = me and me:cf() or CFrame.new(center)
			local p = center + rcf.LookVector * 9 + rcf.RightVector * 3 + Vector3.new(0, K.lerp(0.5, 1.2, e), 0)
			K.setCam(CFrame.lookAt(p, head + Vector3.new(0, 0.4, 0)), 50)
		else
			-- pull wide: every one of you pointing to the heavens
			local e = K.k(t, 5.6, dur, E.outCubic)
			local mid = Vector3.zero
			local n = 0
			for _, rig in pairs(ctx.rigs) do mid += rig:cf().Position n += 1 end
			mid /= math.max(n, 1)
			local p = mid + Vector3.new(K.lerp(20, 34, e), K.lerp(2, 5, e), K.lerp(8, 24, e))
			K.setCam(CFrame.lookAt(p, mid + Vector3.new(0, 6, 0)), 60)
		end
		cue("surge", t >= 0, function()
			K.sfx(K.S.Electric, 0.7)
			K.sfx(K.S.GreenAura, 0.8, 0.9)
			K.shake(1.2, 1.2)
		end)
		cue("stand", t >= 3.4, function() K.sfx(K.S.Overdrive, 0.8) end)
		cue("point", t >= 6.0, function()
			K.sfx(K.S.Broly, 0.9)
			K.sfx(K.S.Choir, 0.6, 1.1)
			K.flash(0.4, GREEN, 0.5)
			K.kick(8, 0.6)
			ctx.fadeMusic(0.65, 0.8)
			-- light pours up from every bat
			for _, rig in pairs(ctx.rigs) do
				if rig.Bat then
					local tip = rig.Bat.Position
					local b = K.ray(ctx.ColumnHost, tip, tip + Vector3.new(0, 900, 0), 1.6, 5, "10365550877", { Color = GREEN, Brightness = 4, Speed = 4, Mode = Enum.TextureMode.Wrap, Length = 30 })
					rig.SkyBeam = b
				end
			end
		end)
	end)
end

------------------------------------------------------------------------
-- SPLIT SCREEN: JUST WHO THE HELL DO YOU THINK WE ARE!
------------------------------------------------------------------------
function Ch.Split(ctx, t0, dur)
	local K = ctx.kit
	local gui = K.Gui
	local n = math.max(ctx.n, 1)
	-- (ZIndex under K.Layer, which is where K.say puts the shout)
	local holder = K.frame("Split", { BackgroundColor3 = Color3.fromRGB(4, 20, 8), Size = UDim2.fromScale(1, 1), ZIndex = 35, BackgroundTransparency = 1, ClipsDescendants = true }, gui)
	local bg = Instance.new("UIGradient")
	bg.Color = ColorSequence.new(Color3.fromRGB(10, 60, 20), Color3.fromRGB(0, 10, 4))
	bg.Rotation = 90
	bg.Parent = holder
	K.tween(holder, 0.15, { BackgroundTransparency = 0 })
	local panels = {}
	local order = {}
	for slot in pairs(ctx.rigs) do table.insert(order, slot) end
	table.sort(order)
	local w = 1 / n
	for i, slot in ipairs(order) do
		local rig = ctx.rigs[slot]
		local p = K.frame("Panel" .. i, {
			BackgroundColor3 = Color3.fromRGB(20, 90, 35), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(w * (i - 0.5), 1.6), Size = UDim2.fromScale(w * 1.08, 1.25), Rotation = 7, ZIndex = 71,
		}, holder)
		local st = Instance.new("UIStroke")
		st.Thickness = 5
		st.Color = Color3.fromRGB(0, 0, 0)
		st.Parent = p
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 255, 140)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 120, 50)), ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 30, 10)) })
		g.Rotation = 90
		g.Parent = p
		-- lines radiating behind the avatar
		local lines = Instance.new("ImageLabel")
		lines.BackgroundTransparency = 1
		lines.Image = K.SpeedLines
		lines.ImageColor3 = Color3.fromRGB(200, 255, 200)
		lines.ImageTransparency = 0.3
		lines.Size = UDim2.fromScale(2.2, 2.2)
		lines.Position = UDim2.fromScale(0.5, 0.45)
		lines.AnchorPoint = Vector2.new(0.5, 0.5)
		lines.ZIndex = 72
		lines.Parent = p
		local vp = Instance.new("ViewportFrame")
		vp.BackgroundTransparency = 1
		vp.Size = UDim2.fromScale(1, 1)
		vp.Rotation = -7
		vp.ZIndex = 73
		vp.Ambient = Color3.fromRGB(150, 200, 150)
		vp.LightColor = Color3.fromRGB(200, 255, 200)
		vp.LightDirection = Vector3.new(-1, -1, -1)
		vp.Parent = p
		local ok, clone = pcall(function() return rig.Model:Clone() end)
		if ok and clone then
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Highlight") or d:IsA("PointLight") then d:Destroy() end
				if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
			end
			clone.Parent = vp
			local vcam = Instance.new("Camera")
			local root = clone:FindFirstChild("HumanoidRootPart")
			local head = clone:FindFirstChild("Head")
			local focus = head and head.Position or (root and root.Position) or Vector3.zero
			local rcf = root and root.CFrame or CFrame.new()
			vcam.CFrame = CFrame.lookAt(focus + rcf.LookVector * 7 + Vector3.new(0, -3.2, 0) + rcf.RightVector * 1.2, focus + Vector3.new(0, 1.2, 0))
			vcam.FieldOfView = 50
			vcam.Parent = vp
			vp.CurrentCamera = vcam
		end
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Size = UDim2.fromScale(1, 0.06)
		name.Position = UDim2.fromScale(0, 0.72)
		name.FontFace = K.Fonts.Shout
		name.TextScaled = true
		name.TextColor3 = Color3.fromRGB(230, 255, 210)
		name.Rotation = -7
		name.ZIndex = 74
		local nm = rig.Model:GetAttribute("DisplayName")
		if not nm then
			local pl = game:GetService("Players"):GetPlayerByUserId(tonumber(ctx.roster[slot]) or 0)
			nm = pl and pl.DisplayName or ""
		end
		name.Text = string.upper(nm or "")
		local ns = Instance.new("UIStroke")
		ns.Thickness = 3
		ns.Parent = name
		name.Parent = p
		table.insert(panels, { Frame = p, Lines = lines })
	end
	local cue = K.once()
	local slam = 0.13
	K.run(t0, dur, function(t)
		for i, pn in ipairs(panels) do
			local at = 0.05 + (i - 1) * slam
			local u = K.k(t, at, at + 0.16, K.E.outBack)
			pn.Frame.Position = UDim2.fromScale(w * (i - 0.5), K.lerp(1.6, 0.5, u))
			pn.Lines.Rotation = t * 40 * (i % 2 == 0 and 1 or -1)
			cue("slam" .. i, t >= at + 0.12, function()
				K.sfx(K.S.Punch, 0.5, 1 + i * 0.05)
				K.shake(1.2, 0.3)
			end)
		end
		local after = 0.05 + #panels * slam + 0.1
		cue("shout", t >= after, function()
			K.sfx(K.S.CutIn, 1)
			K.sfx(K.S.BigHit, 1)
			K.shake(3, 1.2)
			K.flash(0.25, Color3.fromRGB(220, 255, 200), 0.6)
			K.say("JUST WHO THE HELL\nDO YOU THINK WE ARE!!", math.max(0.8, dur - after - 1.2), {
				Font = K.Fonts.Shout, Scale = 0.12, Position = UDim2.fromScale(0.5, 0.5), Per = 0.018,
				Gradient = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 160)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 190, 40)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 20)) }),
				SplitA = Color3.fromRGB(60, 255, 120), SplitB = Color3.fromRGB(255, 255, 255), Stroke = 6, Sound = false,
			})
		end)
		cue("out", t >= dur - 0.3, function()
			K.flash(0.4, Color3.new(1, 1, 1))
			K.tween(holder, 0.25, { BackgroundTransparency = 1 })
			for _, pn in ipairs(panels) do K.tween(pn.Frame, 0.25, { Position = pn.Frame.Position + UDim2.fromScale(0, -1.5) }) end
		end)
	end)
	holder:Destroy()
end

------------------------------------------------------------------------
-- ASCEND + THE SPIRAL BAT
------------------------------------------------------------------------
function Ch.Ascend(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local set = ctx.sets.Rise
	set.Parent = ctx.stage
	local me = ctx.myRig
	local cue = K.once()
	local home = ctx.BossHome
	local col = ctx.ColumnHost
	local starts = {}
	for slot, rig in pairs(ctx.rigs) do starts[slot] = rig:cf().Position end
	-- a vortex column around the party
	local mid = Vector3.zero
	local n = 0
	for _, p in pairs(starts) do mid += p n += 1 end
	mid /= math.max(n, 1)
	col.CFrame = CFrame.new(mid)
	local rings = {}
	for i = 1, 6 do
		table.insert(rings, (K.quad(col, CFrame.new(mid + Vector3.new(0, i * 14, 0)) * CFrame.Angles(math.rad(90), 0, 0), 60, 60, i % 2 == 0 and "14426232568" or "124165682553877", { Color = i % 2 == 0 and GREEN or LIME, Brightness = 3, Transparency = 0.25 })))
	end
	local rise = K.emitter(col, {
		Texture = "11381556016", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.OneShot, Color = ColorSequence.new(GREEN, LIME), Size = K.ns(0, 5, 1, 0), Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(40, 70), SpreadAngle = Vector2.new(10, 10), EmissionDirection = Enum.NormalId.Top, Rate = 90, Brightness = 4,
		Shape = Enum.ParticleEmitterShape.Disc, Rotation = NumberRange.new(0, 360),
	})
	col.Size = Vector3.new(60, 1, 60)

	K.run(t0, dur, function(t, dt)
		local up = K.k(t, 0, 3.4, E.inOutSine)
		local down = K.k(t, 4.8, 6.3, E.inOutCubic)
		for slot, rig in pairs(ctx.rigs) do
			local s = starts[slot]
			local stand = ctx.TL.ArenaStand(slot)
			local a = slot * 1.3 + up * 3.5
			local h = up * 55 * (1 - down)
			local r = 4 * up * (1 - down)
			local base = s:Lerp(Vector3.new(stand.X, s.Y, stand.Z), down)
			local p = base + Vector3.new(math.cos(a) * r, h, math.sin(a) * r)
			local face = CFrame.lookAt(p, Vector3.new(home.X, p.Y, home.Z))
			rig:setCF(face * CFrame.Angles(0, (1 - down) * up * math.pi * 2, 0))
			local pose = K.mixPose(K.Poses.PointUp, K.Poses.Ascend, up)
			pose = K.mixPose(pose, { Root = K.A(-6, 0, 0), Neck = K.A(-6, 0, 0), RS = K.A(95, 0, -12), LS = K.A(-20, 0, -28), RH = K.A(18, 0, 6), LH = K.A(-14, 0, -8) }, down)
			rig:setPose(pose)
			rig:apply()
			veinPulse(rig, t + slot, 1)
			-- the drill spins
			if rig.ConeWeld and rig.ConeC0 then rig.ConeWeld.C0 = rig.ConeC0 * CFrame.Angles(0, t * 22, 0) end
			if rig.SkyBeam then
				rig.SkyBeam.Attachment0.WorldPosition = rig.Bat and rig.Bat.Position or p
				rig.SkyBeam.Attachment1.WorldPosition = p + Vector3.new(0, 900, 0)
				rig.SkyBeam.Width0 = 1.6 * (1 - K.k(t, 3.5, 4.5))
				rig.SkyBeam.Width1 = 5 * (1 - K.k(t, 3.5, 4.5))
			end
		end
		for i, q in ipairs(rings) do
			local y = (i * 14 + t * 30) % 90
			local s = 40 + y * 0.6 + math.sin(t * 3 + i) * 4
			K.moveQuad(q, CFrame.new(mid + Vector3.new(0, y, 0)) * CFrame.Angles(math.rad(90), 0, t * (i % 2 == 0 and 2 or -2)))
			K.setQuadSize(q, s * (1 - down * 0.9), s * (1 - down * 0.9))
		end
		rise.Rate = 90 * (1 - down)
		local center = me and me:cf().Position or mid
		if t < 3.6 then
			-- orbiting up with you
			local a = t * 0.8
			local p = center + Vector3.new(math.cos(a) * 16, -4 + t * 2, math.sin(a) * 16)
			K.setCam(CFrame.lookAt(p, center + Vector3.new(0, 3, 0)), 55)
		elseif t < 4.9 then
			-- the bat: on it, from the side and a little below, as it becomes the Spiral Bat
			-- (far enough back that the drill reads as a shape against the vortex)
			local bat = me and me.Bat
			local bp = bat and bat.Position or center
			local rcf = me and me:cf() or CFrame.new(center)
			local e = K.k(t, 3.6, 4.9)
			local p = bp + rcf.LookVector * 7 + rcf.RightVector * K.lerp(6, 4.5, e) + Vector3.new(0, -2.5, 0)
			K.setCam(CFrame.lookAt(p, bp + Vector3.new(0, 0.8, 0)), K.lerp(38, 34, e))
		else
			-- landing: low, heroic, the Anti-Spiral looming beyond
			local e = K.k(t, 4.9, dur)
			local mid2 = Vector3.zero
			local c = 0
			for _, rig in pairs(ctx.rigs) do mid2 += rig:cf().Position c += 1 end
			mid2 /= math.max(c, 1)
			local p = mid2 + Vector3.new(-26, K.lerp(2.5, 1.5, e), K.lerp(-16, -10, e))
			K.setCam(CFrame.lookAt(p, mid2:Lerp(home.Position + Vector3.new(0, 150, 0), 0.25)), 60)
		end
		cue("rise", t >= 0.05, function()
			K.sfx(K.S.Overdrive, 0.9, 0.9)
			K.sfx(K.S.Riser, 0.8, 1.2)
		end)
		cue("bat", t >= 3.7, function()
			for _, rig in pairs(ctx.rigs) do upgradeBat(ctx, rig) end
			local subjects = {}
			for _, rig in pairs(ctx.rigs) do table.insert(subjects, rig.Model) end
			task.spawn(K.impact, subjects, "GBG", 0.05)
			K.sfx(K.S.BigHit, 1)
			K.sfx(K.S.Broly, 0.8, 1.1)
			K.flash(0.5, GREEN, 0.7)
			K.shake(2.5, 1)
			K.kick(12, 0.7)
		end)
		cue("land", t >= 6.3, function()
			K.sfx(K.S.Thump, 0.9)
			K.sfx(K.S.RockBoom, 0.6)
			K.shake(2, 0.6)
			for _, rig in pairs(ctx.rigs) do
				local p = rig:cf().Position
				K.vfx("Shoot-01", CFrame.new(p.X, ctx.TL.ArenaCenter.Y + 0.6, p.Z) * CFrame.Angles(math.rad(90), 0, 0), set, 0.8, 2, 2)
			end
		end)
	end)
	rise.Rate = 0
	for _, q in ipairs(rings) do q.Enabled = false end
	for _, rig in pairs(ctx.rigs) do
		if rig.SkyBeam then rig.SkyBeam:Destroy() rig.SkyBeam = nil end
	end
end

------------------------------------------------------------------------
-- VERSUS
------------------------------------------------------------------------
function Ch.Versus(ctx, t0, dur)
	local K = ctx.kit
	local gui = K.Gui
	-- (ZIndex under K.Layer, which is where K.say puts the name)
	local holder = K.frame("Versus", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 35, ClipsDescendants = true }, gui)
	-- left: your side (green), right: his side (void)
	local left = K.frame("Left", { BackgroundColor3 = Color3.fromRGB(10, 70, 25), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(0.62, 1.5), Rotation = 12, ZIndex = 71 }, holder)
	local right = K.frame("Right", { BackgroundColor3 = Color3.fromRGB(6, 6, 18), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromScale(0.62, 1.5), Rotation = 12, ZIndex = 71 }, holder)
	for _, f in ipairs({ left, right }) do
		local g = Instance.new("UIGradient")
		g.Rotation = 0
		g.Color = f == left and ColorSequence.new(Color3.fromRGB(120, 255, 140), Color3.fromRGB(0, 40, 10)) or ColorSequence.new(Color3.fromRGB(10, 10, 30), Color3.fromRGB(70, 90, 200))
		g.Parent = f
		local st = Instance.new("UIStroke")
		st.Thickness = 8
		st.Color = f == left and Color3.fromRGB(200, 255, 120) or Color3.fromRGB(180, 200, 255)
		st.Parent = f
	end
	local function viewport(parent, models, camCF, fov, amb)
		local vp = Instance.new("ViewportFrame")
		vp.BackgroundTransparency = 1
		vp.Size = UDim2.fromScale(1, 1)
		vp.Rotation = -12
		vp.ZIndex = 72
		vp.Ambient = amb
		vp.LightColor = Color3.new(1, 1, 1)
		vp.LightDirection = Vector3.new(-0.5, -1, -0.3)
		vp.Parent = parent
		for _, m in ipairs(models) do
			local ok, c = pcall(function() return m:Clone() end)
			if ok and c then
				for _, d in ipairs(c:GetDescendants()) do
					if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("PointLight") then d:Destroy() end
					if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
				end
				c.Parent = vp
			end
		end
		local cam = Instance.new("Camera")
		cam.CFrame = camCF
		cam.FieldOfView = fov
		cam.Parent = vp
		vp.CurrentCamera = cam
		return vp
	end
	-- the party lined up
	local models, mid, n = {}, Vector3.zero, 0
	for _, rig in pairs(ctx.rigs) do table.insert(models, rig.Model) mid += rig:cf().Position n += 1 end
	mid /= math.max(n, 1)
	local home = ctx.BossHome
	local toBoss = (Vector3.new(home.X, mid.Y, home.Z) - mid).Unit
	local side = toBoss:Cross(Vector3.new(0, 1, 0)).Unit
	local partyCam = CFrame.lookAt(mid + toBoss * (18 + n * 2.5) + Vector3.new(0, -1, 0) + side * 4, mid + Vector3.new(0, 2, 0))
	local vpL = viewport(left, models, partyCam, 55, Color3.fromRGB(140, 220, 150))
	vpL.Position = UDim2.fromScale(0.22, 0)
	local face = ctx.Boss:FindFirstChild("Head")
	local fp = face and face.Position or home.Position + Vector3.new(0, 200, 0)
	local bossCam = CFrame.lookAt(fp + home.LookVector * 420 + Vector3.new(0, -140, 0), fp + Vector3.new(0, -90, 0))
	local vpR = viewport(right, { ctx.Boss }, bossCam, 50, Color3.fromRGB(90, 100, 160))
	vpR.Position = UDim2.fromScale(-0.18, 0)
	-- VS mark
	local vs = Instance.new("TextLabel")
	vs.BackgroundTransparency = 1
	vs.AnchorPoint = Vector2.new(0.5, 0.5)
	vs.Position = UDim2.fromScale(0.5, 0.45)
	vs.Size = UDim2.fromScale(0.3, 0.3)
	vs.FontFace = K.Fonts.Shout
	vs.TextScaled = true
	vs.Text = "VS"
	vs.TextColor3 = Color3.fromRGB(255, 240, 120)
	vs.TextTransparency = 1
	vs.ZIndex = 76
	local vst = Instance.new("UIStroke")
	vst.Thickness = 8
	vst.Parent = vs
	local vsScale = Instance.new("UIScale")
	vsScale.Scale = 4
	vsScale.Parent = vs
	vs.Parent = holder
	-- lightning split down the middle
	local bolt = Instance.new("ImageLabel")
	bolt.BackgroundTransparency = 1
	bolt.Image = K.SpeedLines -- (the burst image has an opaque grey card behind it)
	bolt.ImageColor3 = Color3.fromRGB(255, 240, 190)
	bolt.ImageTransparency = 1
	bolt.AnchorPoint = Vector2.new(0.5, 0.5)
	bolt.Position = UDim2.fromScale(0.5, 0.45)
	bolt.Size = UDim2.fromScale(0.9, 0.9)
	bolt.SizeConstraint = Enum.SizeConstraint.RelativeYY
	bolt.ZIndex = 75
	bolt.Parent = holder
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.Position = UDim2.fromScale(0.5, 0.76)
	sub.Size = UDim2.fromScale(0.6, 0.05)
	sub.FontFace = K.Fonts.Title
	sub.TextScaled = true
	sub.Text = "F I N A L   B O S S"
	sub.TextColor3 = Color3.fromRGB(230, 235, 255)
	sub.TextTransparency = 1
	sub.ZIndex = 77
	sub.Parent = holder
	local cue = K.once()
	K.setCam(K.Cam.CF, K.Cam.Fov)
	K.run(t0, dur, function(t)
		local inL = K.k(t, 0, 0.35, K.E.outBack)
		local inR = K.k(t, 0.15, 0.5, K.E.outBack)
		left.Position = UDim2.fromScale(K.lerp(0, 0.56, inL), 0.5)
		right.Position = UDim2.fromScale(K.lerp(1, 0.44, inR), 0.5)
		local vsIn = K.k(t, 0.55, 0.8, K.E.outBack)
		vs.TextTransparency = 1 - K.k(t, 0.55, 0.65)
		vsScale.Scale = K.lerp(4, 1, vsIn) + math.sin(t * 30) * 0.02
		bolt.ImageTransparency = t > 0.55 and (0.35 + 0.25 * math.random()) or 1
		bolt.Rotation = t * 50
		sub.TextTransparency = 1 - K.k(t, 1.2, 1.5)
		-- both portraits creep toward the centre
		vpL.Position = UDim2.fromScale(0.22 + t * 0.006, 0)
		vpR.Position = UDim2.fromScale(-0.18 - t * 0.006, 0)
		cue("L", t >= 0.05, function() K.sfx(K.S.Whoosh, 0.9, 1.3) end)
		cue("R", t >= 0.2, function() K.sfx(K.S.Whoosh, 0.9, 1.1) end)
		cue("vs", t >= 0.6, function()
			K.sfx(K.S.TonalHit, 1)
			K.sfx(K.S.BigHit, 1)
			K.shake(3, 0.8)
		end)
		cue("name", t >= 1.5, function()
			K.sfx(K.S.Hell, 0.8, 0.9)
			K.say("ANTI-SPIRAL", 2.6, {
				Scale = 0.16, Position = UDim2.fromScale(0.5, 0.88), Per = 0.04, Sound = false,
				Gradient = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(170, 190, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 60, 255)) }),
			})
		end)
		cue("out", t >= dur - 0.6, function()
			K.flash(0.6)
			K.tween(left, 0.4, { Position = UDim2.fromScale(-0.7, 0.5) })
			K.tween(right, 0.4, { Position = UDim2.fromScale(1.7, 0.5) })
			K.tween(vs, 0.3, { TextTransparency = 1 })
			K.tween(sub, 0.3, { TextTransparency = 1 })
			bolt.Visible = false
		end)
	end)
	holder:Destroy()
end

return Ch
