--==================================================
-- CHAPTER 2: LAUNCH (space itself lives in ChSolar)
-- Riding the Anti-Spiral's beam up through every layer of the
-- sky: out of the storm and over a sea of cloud, through the
-- cirrus, the ozone shimmer, meteors and silver night-clouds,
-- the aurora curtains, and finally through the Karman line
-- into black space above the Earth. A long quiet float with
-- the planets, then the pull that drags everyone away.
--==================================================
local Ch = {}

local pi = math.pi
local EARTH_R = 1000
local function O(ctx) return ctx.TL.SpaceOrigin end
local function earthCenter(ctx) return O(ctx) + Vector3.new(0, -1380, 0) end

-- launch altitude profile (studs above the start of the chapter), keyed every 2s
-- (it starts at the lift-off's hand-over speed, ~390 studs/s, so the climb has no
-- seam between the chapters: the virtual point before the first key sets that slope)
local ALT = { 0, 800, 1560, 2290, 2990, 3660, 4330, 5000, 5750, 6300 }
local ALT_PRE = -775
local function altOffset(t)
	local i = math.clamp(math.floor(t / 2) + 1, 1, #ALT - 1)
	local u = math.clamp((t - (i - 1) * 2) / 2, 0, 1.5)
	local p0 = i == 1 and ALT_PRE or ALT[i - 1]
	local p1 = ALT[i]
	local p2 = ALT[i + 1]
	local p3 = ALT[math.min(i + 2, #ALT)]
	local u2, u3 = u * u, u * u * u
	return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3)
end

-- layer heights, relative to where the chapter starts
local L_CLOUDTOP = 60
local L_CIRRUS = 900
local L_OZONE = 2000
local L_METEOR0, L_METEOR1 = 2500, 3900
local L_NOCTI = 3350
local L_AUR0, L_AUR1 = 3950, 4950
local L_KARMAN = 5600

function Ch.build(ctx)
	local K = ctx.kit
	local rng = Random.new(21)
	local G = ctx.G
	local M = ctx.TL.Meadow
	------------------------------------------------------------------
	-- the atmosphere, layer by layer, stacked over the beam column
	------------------------------------------------------------------
	local sky = Instance.new("Folder")
	sky.Name = "AtmoSet"
	ctx.sets.Sky = sky
	local axis = G and G.ColBase or M.Position
	local ground = axis.Y
	-- where the chapter starts (same maths as the end of the grass chapter)
	local A0 = ctx.TL.LaunchY(ctx.TL.LiftHandOver)
	ctx.AtmoA0 = A0
	local function at(off) return ground + A0 + off end
	local A = {}
	ctx.Atmo = A
	local host = K.part({ Name = "AtmoHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(axis) }, sky)
	A.Host = host
	local function flatQuad(y, size, tex, opts)
		return K.quad(host, CFrame.new(axis.X, y, axis.Z) * CFrame.Angles(-pi / 2, 0, 0), size, size, tex, opts)
	end
	local function slab(name, y, w, h)
		return K.part({ Name = name, Size = Vector3.new(w, h, w), CFrame = CFrame.new(axis.X, y, axis.Z), Transparency = 1 }, sky)
	end

	-- 1. the sea of cloud. Everything up here is round: the cloud world is a sphere
	-- (a planet 30k studs across, so its horizon really curves away and dips as you
	-- climb) carpeted with dome-shaped cumulus, plus soft dome-shaped wisps
	local seaY = at(L_CLOUDTOP)
	local R_PLANET = 30000
	local pc = Vector3.new(axis.X, seaY - 55 - R_PLANET, axis.Z)
	A.PlanetC = pc
	A.PlanetR = R_PLANET
	-- (matte: a shiny sphere this size catches a huge sun glint that blows out the frame)
	local world = K.part({ Name = "CloudWorld", Size = Vector3.one, Color = Color3.fromRGB(222, 229, 243), Material = Enum.Material.Plastic, Reflectance = 0, CFrame = CFrame.new(pc) }, sky)
	local wm = Instance.new("SpecialMesh")
	wm.MeshType = Enum.MeshType.Sphere
	wm.Scale = Vector3.one * R_PLANET * 2
	wm.Parent = world
	A.SeaBase = world
	local function onWorld(sArc, phi, lift)
		local th = sArc / R_PLANET
		local dir = Vector3.new(math.sin(th) * math.cos(phi), math.cos(th), math.sin(th) * math.sin(phi))
		local right = dir:Cross(Vector3.zAxis)
		right = right.Magnitude > 0.01 and right.Unit or Vector3.xAxis
		return CFrame.fromMatrix(pc + dir * (R_PLANET + (lift or 0)), right, dir)
	end
	A.SeaClouds = {}
	local srng = Random.new(3030)
	-- scattered at random (no rings or rows), bigger and closer together the
	-- further out they are, so from high up it reads as a continuous sea of cloud
	-- with a gap where the beam punched through
	local placed = {}
	local function clear(p, r)
		for _, q in ipairs(placed) do
			if (q.P - p).Magnitude < (q.R + r) * 0.62 then return false end
		end
		return true
	end
	local tries = 0
	while #A.SeaClouds < 190 and tries < 2400 do
		tries += 1
		local u = srng:NextNumber()
		local arc = 150 + 7300 * math.sqrt(u)
		local phi = srng:NextNumber(0, 2 * pi)
		local cw = K.lerp(260, 1500, arc / 7450) * srng:NextNumber(0.7, 1.35)
		local cf = onWorld(arc, phi, -cw * 0.07)
		if clear(cf.Position, cw * 0.5) then
			table.insert(placed, { P = cf.Position, R = cw * 0.5 })
			local c = K.cloud(sky, cf * CFrame.Angles(0, srng:NextNumber(0, 2 * pi), 0), cw, srng, {
				Pieces = arc < 2000 and srng:NextInteger(5, 7) or srng:NextInteger(4, 5),
				Color = Color3.fromRGB(236, 240, 248), Shade = Color3.fromRGB(176, 188, 214),
			})
			table.insert(A.SeaClouds, c)
		end
	end
	-- soft dome-shaped wisps over the cloud tops round the beam
	local seaProps = {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)), Size = K.ns(0, 260, 1, 360),
		Transparency = K.ns(0, 0.3, 0.9, 0.35, 1, 1), Lifetime = NumberRange.new(80, 90), Speed = NumberRange.new(0.2, 0.8),
		LightEmission = 0, LightInfluence = 0.2, Rotation = NumberRange.new(-8, 8), RotSpeed = NumberRange.new(-1, 1),
	}
	A.Sea = K.domeEmitter(slab("CloudSea", seaY - 40, 2048, 240), seaProps)
	A.SeaRing = {}
	-- the thickness of the air seen from above: flat sheets of cloud and haze lying at
	-- different heights (each one a field of big soft puffs laid face-up), so as you
	-- climb and look back down you see layer under layer under layer, and two thin
	-- veils of blue haze wrapped round the whole world that you pass up through
	A.Strata = {}
	local strata = {
		{ Off = 320, Tr = 0.45, Col = Color3.fromRGB(250, 252, 255), Size = { 500, 900 }, N = 70 },
		{ Off = 1150, Tr = 0.6, Col = Color3.fromRGB(236, 243, 255), Size = { 600, 1100 }, N = 60 },
		{ Off = 2050, Tr = 0.7, Col = Color3.fromRGB(210, 228, 255), Size = { 700, 1300 }, N = 55 },
		{ Off = 2950, Tr = 0.78, Col = Color3.fromRGB(185, 215, 255), Size = { 800, 1500 }, N = 50 },
		{ Off = 3800, Tr = 0.84, Col = Color3.fromRGB(165, 200, 255), Size = { 900, 1700 }, N = 45 },
	}
	for li, L in ipairs(strata) do
		local ems = {}
		for gx = -1, 1 do
			for gz = -1, 1 do
				local slabP = K.part({ Name = "Stratum" .. li, Size = Vector3.new(2040, 6, 2040), CFrame = CFrame.new(axis.X + gx * 2000, at(L.Off) + (gx * 7 + gz * 13) % 40, axis.Z + gz * 2000), Transparency = 1 }, sky)
				local e = K.emitter(slabP, {
					Texture = "10180479311", Color = ColorSequence.new(L.Col), Size = K.ns(0, L.Size[1], 1, L.Size[2]),
					Transparency = K.ns(0, 1, 0.08, L.Tr, 0.92, L.Tr + 0.04, 1, 1), Lifetime = NumberRange.new(19, 20),
					Speed = NumberRange.new(0.3, 0.6), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(0, 0),
					Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Shape = Enum.ParticleEmitterShape.Box,
					LightEmission = 0.15, LightInfluence = 0.6, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-1.5, 1.5),
				})
				table.insert(ems, e)
			end
		end
		table.insert(A.Strata, { Off = L.Off, E = ems, N = L.N, Done = false })
	end
	-- haze veils: huge thin shells round the cloud world
	A.Veils = {}
	for vi, v in ipairs({ { H = 450, Tr = 0.82, Col = Color3.fromRGB(200, 222, 255) }, { H = 1600, Tr = 0.88, Col = Color3.fromRGB(130, 175, 255) }, { H = 3300, Tr = 0.93, Col = Color3.fromRGB(90, 140, 255) } }) do
		local shell = K.part({ Name = "HazeVeil" .. vi, Size = Vector3.one, Color = v.Col, Material = Enum.Material.SmoothPlastic, Transparency = v.Tr, CFrame = CFrame.new(pc) }, sky)
		local sm = Instance.new("SpecialMesh")
		sm.MeshType = Enum.MeshType.Sphere
		sm.Scale = Vector3.one * (R_PLANET + 55 + v.H) * 2
		sm.Parent = shell
		table.insert(A.Veils, shell)
	end
	A.SeaNear = K.domeEmitter(slab("CloudSeaNear", seaY - 30, 900, 160), {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 212, 232)), Size = K.ns(0, 110, 1, 170),
		Transparency = K.ns(0, 0.1, 0.1, 0.1, 0.9, 0.15, 1, 1), Lifetime = NumberRange.new(80, 90), Speed = NumberRange.new(0.2, 0.8),
		LightEmission = 0.05, LightInfluence = 1, Rotation = NumberRange.new(-10, 10), RotSpeed = NumberRange.new(-2, 2),
	})
	-- dome clouds strung up the way, between the cloud sea and the cirrus: the
	-- party rockets straight past (and through) them
	A.Passing = {}
	for i = 1, 26 do
		local a = srng:NextNumber(0, 2 * pi)
		local rr = (i % 4 == 0) and srng:NextNumber(30, 90) or srng:NextNumber(110, 460)
		local h = K.lerp(L_CLOUDTOP + 140, L_CIRRUS + 500, (i - 1) / 25) + srng:NextNumber(-40, 40)
		local c = K.cloud(sky, CFrame.new(axis.X + math.cos(a) * rr, at(h), axis.Z + math.sin(a) * rr), srng:NextNumber(80, 240), srng, {
			Color = Color3.fromRGB(252, 253, 255), Shade = Color3.fromRGB(200, 212, 235),
		})
		table.insert(A.Passing, c)
	end
	-- 2. cirrus: high wispy streaks
	A.Cirrus = K.domeEmitter(slab("Cirrus", at(L_CIRRUS) - 250, 7000, 700), {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(245, 250, 255)), Size = K.ns(0, 260, 1, 420),
		Transparency = K.ns(0, 0.55, 0.15, 0.55, 0.85, 0.6, 1, 1), Lifetime = NumberRange.new(80, 90), Speed = NumberRange.new(0.2, 1),
		LightEmission = 0.2, LightInfluence = 0.8,
		Rotation = NumberRange.new(-8, 8), Squash = K.ns(0, -0.75),
	})
	-- 3. the ozone layer: a faint shimmering sheet
	A.Ozone = flatQuad(at(L_OZONE), 14000, "14426232568", { Color = Color3.fromRGB(120, 200, 255), Brightness = 0.6, Transparency = 1 })
	A.OzoneGlow = K.domeEmitter(slab("OzoneGlow", at(L_OZONE) - 200, 6000, 500), {
		Texture = "1084982817", Color = ColorSequence.new(Color3.fromRGB(110, 190, 255), Color3.fromRGB(160, 120, 255)), Size = K.ns(0, 300, 1, 450),
		Transparency = K.ns(0, 0.8, 0.2, 0.8, 0.8, 0.85, 1, 1), Lifetime = NumberRange.new(80, 90), Speed = NumberRange.new(0),
		Brightness = 1,
	})
	-- 4. meteors burning up
	A.Meteors = {}
	for i = 1, 14 do
		local b = K.ray(host, axis, axis + Vector3.new(0, 1, 0), 6, 0.2, "1053548563", {
			Color = i % 3 == 0 and Color3.fromRGB(150, 255, 190) or Color3.fromRGB(255, 200, 140), Brightness = 6, Segments = 1,
			Transparency = K.ns(0, 0, 1, 1),
		})
		local head = K.quad(host, CFrame.new(axis), 30, 30, "1084982817", { Color = Color3.fromRGB(255, 240, 210), Brightness = 4 })
		b.Enabled = false
		table.insert(A.Meteors, {
			Beam = b, Head = head, Phase = rng:NextNumber(0, 1), Period = rng:NextNumber(1.1, 2.2),
			Ang = rng:NextNumber(0, 2 * pi), R = rng:NextNumber(150, 900), Dir = Vector3.new(rng:NextNumber(-0.6, 0.6), -1, rng:NextNumber(-0.6, 0.6)).Unit,
			Y = rng:NextNumber(L_METEOR0, L_METEOR1),
		})
	end
	-- 5. noctilucent (silver-blue night) clouds
	A.Nocti = K.domeEmitter(slab("Nocti", at(L_NOCTI) - 250, 7000, 700), {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(150, 215, 255), Color3.fromRGB(200, 170, 255)), Size = K.ns(0, 240, 1, 380),
		Transparency = K.ns(0, 0.45, 0.15, 0.45, 0.85, 0.55, 1, 1), Lifetime = NumberRange.new(80, 90), Speed = NumberRange.new(0.2, 1),
		LightEmission = 0.25, LightInfluence = 0.3,
		Brightness = 1, Rotation = NumberRange.new(-10, 10), Squash = K.ns(0, -0.55),
	})
	-- 6. aurora curtains (vertical ribbons that sway)
	A.Curtains = {}
	local auroraCols = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 255, 110)), ColorSequenceKeypoint.new(0.3, Color3.fromRGB(30, 220, 150)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(70, 110, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 50, 255)),
	})
	for c = 1, 6 do
		local segs = {}
		-- (kept well away from the party: up close a curtain is just a flat slab of
		-- colour; from a distance it reads as a sweeping, curving ribbon of light)
		local r = (c <= 2) and rng:NextNumber(480, 700) or rng:NextNumber(750, 1400)
		local a0 = rng:NextNumber(0, 2 * pi)
		local span = rng:NextNumber(1.2, 2.4)
		local n = 20
		local pts = {}
		for i = 0, n do
			local a = a0 + span * i / n
			local rr = r + math.sin(i * 0.7 + c) * r * 0.25
			table.insert(pts, Vector3.new(axis.X + math.cos(a) * rr, 0, axis.Z + math.sin(a) * rr))
		end
		for i = 1, n do
			local a0b = Instance.new("Attachment")
			local a1b = Instance.new("Attachment")
			a0b.Parent = host
			a1b.Parent = host
			local b = Instance.new("Beam")
			b.Attachment0 = a0b
			b.Attachment1 = a1b
			b.FaceCamera = false
			b.Segments = 10 -- the fade along the curtain needs sample points
			b.Texture = ""
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Brightness = 2
			b.Color = auroraCols
			b.Transparency = NumberSequence.new(1)
			b.Parent = host
			table.insert(segs, { Beam = b, P0 = pts[i], P1 = pts[i + 1], I = i })
		end
		table.insert(A.Curtains, { Segs = segs, Seed = c * 3.1, H = rng:NextNumber(0.75, 1) })
	end
	-- 7. the Karman line: a thin electric-blue boundary
	A.Karman = flatQuad(at(L_KARMAN), 16000, nil, { Color = Color3.fromRGB(70, 150, 255), Brightness = 1, Transparency = 1 })
	A.Karman.Texture = ""
	A.KarmanGlow = K.domeEmitter(slab("KarmanGlow", at(L_KARMAN) - 200, 6000, 500), {
		Texture = "1084982817", Color = ColorSequence.new(Color3.fromRGB(90, 170, 255)), Size = K.ns(0, 360, 1, 520),
		Transparency = K.ns(0, 0.7, 0.2, 0.7, 0.8, 0.75, 1, 1), Lifetime = NumberRange.new(80, 90), Speed = NumberRange.new(0),
		Brightness = 1.3,
	})
	-- crossing FX: a ring blasting out across each layer + particles torn off it
	A.Rings = {}
	for i = 1, 3 do
		table.insert(A.Rings, (flatQuad(ground, 1, "18823306900", { Color = Color3.new(1, 1, 1), Brightness = 3, Transparency = 1 })))
	end
	local burst = K.part({ Name = "LayerBurst", Size = Vector3.new(160, 4, 160), Transparency = 1, CFrame = CFrame.new(axis) }, sky)
	A.BurstHost = burst
	A.Burst = K.emitter(burst, {
		Texture = "10180479311", Color = ColorSequence.new(Color3.new(1, 1, 1)), Size = K.ns(0, 30, 1, 90),
		Transparency = K.ns(0, 0.2, 0.7, 0.6, 1, 1), Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(120, 260),
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Drag = 1.5, LightEmission = 0.4, LightInfluence = 0.5,
		Rotation = NumberRange.new(0, 360), EmissionDirection = Enum.NormalId.Top,
	})
	-- air rushing past the party
	local rush = K.part({ Name = "Rush", Size = Vector3.new(160, 20, 160), Transparency = 1 }, sky)
	A.RushHost = rush
	A.Rush = K.emitter(rush, {
		Texture = "1053548563", Color = ColorSequence.new(Color3.fromRGB(240, 245, 255)), Size = K.ns(0, 0.7),
		Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(-520, -440), Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = K.ns(0, 4), Transparency = K.ns(0, 0.5), Brightness = 2, EmissionDirection = Enum.NormalId.Top,
	})
	A.Vapor = K.emitter(rush, {
		Texture = "10180479311", Color = ColorSequence.new(Color3.new(1, 1, 1)), Size = K.ns(0, 12, 1, 30),
		Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(-380, -300), Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Transparency = K.ns(0, 0.6, 1, 1), LightEmission = 0.3,
		LightInfluence = 0.6, EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360),
	})
	A.Dome = K.dome(sky, 3200)
	-- the thin blue glow of the air along the curved horizon of the cloud world
	local limbHost = K.part({ Name = "AtmoLimbHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(pc) }, sky)
	A.Limb = K.softRing(limbHost, 48, 1, 2, {
		Texture = "1084982817", Brightness = 2.2, Alpha = 0.85, Segments = 10,
		ColorSeq = ColorSequence.new(Color3.fromRGB(150, 205, 255), Color3.fromRGB(60, 120, 255)),
		Profile = { 0, 0, 0.25, 0.9, 0.5, 1, 0.75, 0.5, 1, 0 },
	})

end

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
local function layoutRig(ctx, slot)
	-- a loose cluster so everyone is in frame together
	local n = ctx.n
	local a = (slot - 1) / math.max(n, 1) * pi * 2
	local r = n > 1 and (5 + n * 0.8) or 0
	return Vector3.new(math.cos(a) * r, math.sin(slot * 1.7) * 3, math.sin(a) * r)
end

local function lerpC(a, b, t) return a:Lerp(b, math.clamp(t, 0, 1)) end

-- the sky's look at a given altitude above the chapter start
local SKY = {
	-- off, horizon, zenith, alpha, stars, sun
	-- (the dome paints the whole sky from the start: the island skybox has hard seams up close)
	{ 0,    Color3.fromRGB(215, 232, 255), Color3.fromRGB(80, 150, 240), 0.9, 0.0, 0.3 },
	{ 900,  Color3.fromRGB(190, 215, 255), Color3.fromRGB(45, 105, 220), 0.93, 0.0, 0.45 },
	{ 2000, Color3.fromRGB(150, 195, 255), Color3.fromRGB(18, 50, 150), 0.96, 0.05, 0.6 },
	{ 3350, Color3.fromRGB(60, 110, 200), Color3.fromRGB(4, 10, 45), 0.98, 0.4, 0.75 },
	{ 4200, Color3.fromRGB(22, 45, 110), Color3.fromRGB(1, 2, 12), 0.99, 0.75, 0.85 },
	{ 5600, Color3.fromRGB(10, 22, 60), Color3.fromRGB(0, 0, 4), 1.0, 1.0, 1.0 },
}
local function skyAt(off)
	for i = 1, #SKY - 1 do
		local a, b = SKY[i], SKY[i + 1]
		if off <= b[1] then
			local u = math.clamp((off - a[1]) / (b[1] - a[1]), 0, 1)
			return lerpC(a[2], b[2], u), lerpC(a[3], b[3], u), a[4] + (b[4] - a[4]) * u, a[5] + (b[5] - a[5]) * u, a[6] + (b[6] - a[6]) * u
		end
	end
	local l = SKY[#SKY]
	return l[2], l[3], l[4], l[5], l[6]
end

------------------------------------------------------------------------
-- LAUNCH
------------------------------------------------------------------------
function Ch.Launch(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local G = ctx.G
	local A = ctx.Atmo
	local sky = ctx.sets.Sky
	sky.Parent = ctx.stage
	-- the grass set stays for the column (the portal and arm are hidden under the clouds)
	ctx.sets.Grass.Parent = ctx.stage
	G.Arm.Parent = nil
	-- the island is left behind for good: its horizon mountains would poke up through
	-- the cloud sea and its far islands would float about in space (client-side only)
	if ctx.hideBase then ctx.hideBase() end
	if ctx.stashArena then ctx.stashArena() end
	local axis = G.ColBase
	local ground = axis.Y
	local base = ground + ctx.AtmoA0

	K.lighting("Upper", 0)
	K.Grade.Brightness = 0
	K.fade(0, 0.5, Color3.new(1, 1, 1))
	local wind = K.loop(K.S.Rush, 0.9, 0.3)
	local tunnel = K.loop(K.S.Tunnel, 0.5, 0.6)
	K.sfx(K.S.Whoosh, 1, 0.8)
	K.sfx(K.S.FireWhoosh, 0.8, 0.7)
	-- the layers are filled once the camera is up here: emitters far from the
	-- camera don't emit, so doing it before the first launch frame loses them
	local skyFilled = false
	local function fillSky()
		-- the puffs go out in shades, so the sea has some depth to it
		for _, c in ipairs({ Color3.fromRGB(255, 255, 255), Color3.fromRGB(228, 234, 246), Color3.fromRGB(200, 210, 232), Color3.fromRGB(176, 188, 216) }) do
			A.Sea.Color = ColorSequence.new(c)
			A.Sea:Emit(75)
			for _, e in ipairs(A.SeaRing) do
				e.Color = ColorSequence.new(c)
				e:Emit(18)
			end
		end
		A.SeaNear:Emit(160)
		A.Cirrus:Emit(240)
		A.OzoneGlow:Emit(120)
		A.Nocti:Emit(260)
		A.KarmanGlow:Emit(140)
	end

	local cue = K.once()
	local ringStart = {}
	local function crossing(key, i, off, color, snd)
		cue(key, true, function()
			ringStart[i] = { T = K.now(), Y = base + off, Color = color }
			A.BurstHost.CFrame = CFrame.new(axis.X, base + off, axis.Z)
			A.Burst.Color = ColorSequence.new(color)
			A.Burst:Emit(40)
			-- (no flash or kick per layer: each one is just a ring of light and a rush of air,
			-- so the climb reads as one continuous exit rather than a string of effects)
			K.sfx(snd or K.S.Whoosh, 0.55, 0.9)
		end)
	end

	for slot, rig in pairs(ctx.rigs) do
		rig.Smooth = 10
		-- (procedural pose only while floating: an animation track on top of it
		-- can swing the arms through the head)
		rig:stopAll(0.25)
	end
	local lt0 = 26 - 20.25 -- where the grass chapter left the launch clock

	K.run(t0, dur, function(t, dt)
		local off = altOffset(t)
		local y = base + off
		------------------------------------------------------------
		-- the party, still spiralling up the beam
		------------------------------------------------------------
		local calm = K.k(off, 1500, 4500)
		local center
		for slot, rig in pairs(ctx.rigs) do
			local lt = lt0 + t
			local ang = slot * 2.1 + lt * (0.7 + slot * 0.06) * (1 - calm * 0.6)
			local r = 20 + (slot % 4) * 9
			local p = Vector3.new(axis.X + math.cos(ang) * r, y + math.sin(slot * 1.3) * 6 * K.k(t, 0, 2), axis.Z + math.sin(ang) * r)
			local spin = lt * (1.4 + slot * 0.15) * (1 - calm * 0.7)
			rig:setCF(CFrame.new(p) * CFrame.Angles((math.sin(lt * 2 + slot) * 0.6 + 0.4) * (1 - calm * 0.6), spin, math.cos(lt * 1.6 + slot) * 0.5 * (1 - calm * 0.5)))
			-- (smooth drifting limbs instead of wind-flail jitter)
			local pose = K.mixPose(K.mixPose(K.Poses.Launch, K.Poses.Float, calm), K.zeroGPose(t * K.lerp(2.2, 1, calm), slot, 1.2), 0.55)
			-- (no hands through the head while they drift)
			rig:setPose(K.safeArms(pose))
			rig:apply()
			if rig == ctx.myRig then center = p end
		end
		center = center or Vector3.new(axis.X, y, axis.Z)

		------------------------------------------------------------
		-- the meadow that came up with them: the fastest bits keep pace a while,
		-- then everything drops away below
		------------------------------------------------------------
		if G.Lift then
			local camY = K.Cam.CF.Position.Y
			for _, d in ipairs(G.Lift) do
				if d.Loose and not d.Gone then
					local yy = G.liftContinue(d, t, off)
					if t > 7 or (yy and yy < camY - 900) then G.liftDone(d) end
				end
			end
		end

		------------------------------------------------------------
		-- the beam: still around them at first, then it fades away below
		------------------------------------------------------------
		local colA = 1 - K.k(t, 1.8, 4)
		if colA > 0.01 then
			G.column(ground, y + 180, 1, colA, t + 26)
			G.columnFX(t + 26, y, colA)
			G.Sparks.Rate = 260 * colA
			G.SparkHost.CFrame = CFrame.new(axis.X, y - 250, axis.Z)
		else
			G.hideColumn()
		end

		------------------------------------------------------------
		-- sky + light by altitude
		------------------------------------------------------------
		local camPos = K.Cam.CF.Position
		local camOff = camPos.Y - base
		local hor, zen, alpha, stars, sunA = skyAt(camOff)
		-- how far below eye level the round world's horizon is from up here
		local horizonDip = math.deg(math.acos(math.clamp(A.PlanetR / math.max((camPos - A.PlanetC).Magnitude, A.PlanetR), 0, 1)))
		K.domeUpdate(A.Dome, camPos, hor, zen, alpha, stars, K.lightDir(), sunA, 0, horizonDip)
		-- the cloud tops are lit white by a hard sun up here: rein the bloom in so
		-- they read as clouds, not glowing blobs
		local hi = K.k(camOff, 1800, 4200)
		K.Bloom.Threshold = K.lerp(1.15, 1.75, hi)
		K.Bloom.Intensity = K.lerp(0.9, 0.45, hi)
		-- the cloud floor far below turns into the blue haze of the atmosphere seen from above
		A.SeaBase.Color = Color3.fromRGB(222, 229, 243):Lerp(Color3.fromRGB(40, 82, 165), K.k(camOff, 1200, 5200))
		-- the glow of the air hugging the curved horizon: sits exactly on the
		-- silhouette of the cloud world as seen from the camera
		do
			local toCam = camPos - A.PlanetC
			local dd = toCam.Magnitude
			local R = A.PlanetR
			if dd > R + 1 then
				local dir = toCam / dd
				local rs = R * math.sqrt(dd * dd - R * R) / dd
				local ctr = A.PlanetC + dir * (R * R / dd)
				local limbA = K.k(camOff, 700, 3200)
				A.Limb.update(CFrame.lookAt(ctr, camPos), rs * 0.992, rs * (1.02 + 0.03 * limbA))
				A.Limb.setTransparency(1 - 0.85 * limbA)
			end
		end
		local Lighting = game:GetService("Lighting")
		Lighting.OutdoorAmbient = Color3.fromRGB(120, 135, 165):Lerp(Color3.fromRGB(55, 60, 85), K.k(camOff, 1500, 5600))
		Lighting.Ambient = Color3.fromRGB(70, 80, 105):Lerp(Color3.fromRGB(30, 32, 48), K.k(camOff, 1500, 5600))
		K.Atmo.Density = 0.12 * (1 - K.k(camOff, 300, 1800))
		K.Atmo.Haze = 0.4 * (1 - K.k(camOff, 300, 1800))
		K.Grade.Contrast = 0.12 + K.k(camOff, 1500, 5600) * 0.1

		------------------------------------------------------------
		-- layers
		------------------------------------------------------------
		-- the ozone sheet ripples, the Karman line hums
		K.moveQuad(A.Ozone, CFrame.new(axis.X, base + L_OZONE, axis.Z) * CFrame.Angles(-pi / 2, 0, t * 0.05))
		A.Karman.Transparency = NumberSequence.new(1)
		-- meteors
		local metA = K.k(off, L_METEOR0 - 900, L_METEOR0) * (1 - K.k(off, L_METEOR1 + 400, L_METEOR1 + 1200))
		for i, m in ipairs(A.Meteors) do
			local ph = ((t + m.Phase * m.Period) % m.Period) / m.Period
			local startP = Vector3.new(axis.X + math.cos(m.Ang + i) * m.R, base + m.Y + 300, axis.Z + math.sin(m.Ang + i) * m.R)
			local headP = startP + m.Dir * ph * 900
			local tail = headP - m.Dir * (120 + ph * 160)
			m.Beam.Enabled = metA > 0.02
			m.Beam.Attachment0.WorldPosition = headP
			m.Beam.Attachment1.WorldPosition = tail
			m.Beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - metA), NumberSequenceKeypoint.new(1, 1) })
			K.moveQuad(m.Head, CFrame.lookAt(headP, camPos))
			m.Head.Transparency = NumberSequence.new(1 - metA * (0.8 + math.sin(t * 40 + i) * 0.2))
		end
		-- aurora curtains sway and shimmer
		local aurA = K.k(camOff, L_AUR0 - 900, L_AUR0 - 200) * (1 - K.k(camOff, L_AUR1 + 300, L_AUR1 + 900))
		for ci, c in ipairs(A.Curtains) do
			for _, s in ipairs(c.Segs) do
				local w0 = Vector3.new(math.noise(s.I * 0.3, t * 0.4, c.Seed) * 60, 0, math.noise(s.I * 0.3, c.Seed, t * 0.4) * 60)
				local w1 = Vector3.new(math.noise((s.I + 1) * 0.3, t * 0.4, c.Seed) * 60, 0, math.noise((s.I + 1) * 0.3, c.Seed, t * 0.4) * 60)
				local p0 = s.P0 + w0
				local p1 = s.P1 + w1
				local mid = (p0 + p1) / 2
				local tan = (p1 - p0)
				local h = (L_AUR1 - L_AUR0) * c.H
				local bottom = Vector3.new(mid.X, base + L_AUR0, mid.Z)
				local topP = bottom + Vector3.new(0, h, 0)
				s.Beam.Attachment0.WorldCFrame = CFrame.fromMatrix(bottom, Vector3.yAxis, tan.Unit)
				s.Beam.Attachment1.WorldCFrame = CFrame.fromMatrix(topP, Vector3.yAxis, tan.Unit)
				s.Beam.Width0 = tan.Magnitude + 0.5
				s.Beam.Width1 = tan.Magnitude + 0.5
				local flick = 0.75 + math.noise(s.I * 0.5, t * 1.5, ci) * 0.5
				local a = math.clamp(aurA * flick, 0, 1)
				s.Beam.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 1 - a * 0.9),
					NumberSequenceKeypoint.new(0.35, 1 - a * 0.75), NumberSequenceKeypoint.new(0.7, 1 - a * 0.35), NumberSequenceKeypoint.new(1, 1),
				})
			end
		end
		-- air rushing past, thinning out as the air does
		local thick = 1 - K.k(off, 800, 5200)
		A.RushHost.CFrame = CFrame.new(center + Vector3.new(0, 90, 0))
		A.Rush.Rate = 260 * thick + 20
		A.Vapor.Rate = 70 * thick
		if off < L_KARMAN then
			wind.Volume = 0.9 * thick + 0.05
			tunnel.Volume = 0.5 * thick
		end
		-- crossings
		if off >= L_CLOUDTOP then crossing("cloud", 1, L_CLOUDTOP, Color3.fromRGB(255, 255, 255), K.S.FireWhoosh) end
		if off >= L_CIRRUS then crossing("cirrus", 2, L_CIRRUS, Color3.fromRGB(220, 235, 255)) end
		if off >= L_OZONE then crossing("ozone", 3, L_OZONE, Color3.fromRGB(130, 200, 255), K.S.TonalHit) end
		if off >= L_NOCTI then crossing("nocti", 1, L_NOCTI, Color3.fromRGB(160, 220, 255)) end
		if off >= L_AUR0 then crossing("aurora", 2, L_AUR0, Color3.fromRGB(110, 255, 170), K.S.TonalHit) end
		for i, r in ipairs(A.Rings) do
			local rs = ringStart[i]
			if rs then
				local e = math.clamp((K.now() - rs.T) / 1.4, 0, 1)
				local s = 60 + E.outCubic(e) * 2600
				K.setQuadSize(r, s, s)
				K.moveQuad(r, CFrame.new(axis.X, rs.Y, axis.Z) * CFrame.Angles(-pi / 2, 0, e))
				r.Color = ColorSequence.new(rs.Color)
				r.Transparency = NumberSequence.new(0.35 + 0.65 * e)
			else
				r.Transparency = NumberSequence.new(1)
			end
		end
		cue("thin", off > 4200, function()
			K.muffle(0.5, 2.5)
			K.sfx(K.S.Heartbeat, 0.45, 0.85, { Life = 8 })
			ctx.fadeMusic(0.3, 2)
		end)
		-- the Karman line
		cue("karman", off >= L_KARMAN, function()
			K.sfx(K.S.TonalHit, 0.6, 0.8)
			K.fadeSound(wind, 0, 0.8, true)
			K.fadeSound(tunnel, 0, 0.8, true)
			K.muffle(1, 0.8)
		end)
		-- through the last of the air: the frame fills with the thin blue of the upper
		-- atmosphere, and the next shot comes out of that same blue
		cue("exit", t >= dur - 0.9, function()
			K.fade(1, 0.85, Color3.fromRGB(150, 195, 255))
			K.sfx(K.S.Whoosh, 0.7, 0.6)
		end)
		K.Blur.Size = 16 * K.k(t, dur - 1.4, dur, E.inQuad)

		------------------------------------------------------------
		-- CAMERA
		------------------------------------------------------------
		local rcf = ctx.myRig and ctx.myRig:cf() or CFrame.new(center)
		local head = ctx.myRig and ctx.myRig:head() and ctx.myRig:head().Position or center
		local out = Vector3.new(center.X - axis.X, 0, center.Z - axis.Z)
		out = out.Magnitude > 0.1 and out.Unit or Vector3.xAxis
		if t < 2.4 then
			-- just above the sea of cloud: they burst out of it riding the beam
			-- (the camera sits on the cloud tops as they punch out of the sea, then is
			-- dragged up after them)
			local e = K.k(t, 0, 2.4)
			local follow = K.k(t, 0.35, 2.4, E.inQuad)
			local y0 = base + L_CLOUDTOP + 150
			local p = Vector3.new(axis.X, K.lerp(y0, math.max(y0, center.Y - 70), follow), axis.Z) + Vector3.new(330, 0, 150) * K.lerp(1, 0.55, follow)
			K.setCam(CFrame.lookAt(p, center:Lerp(Vector3.new(axis.X, center.Y, axis.Z), 0.3)), K.lerp(52, 64, e))
			K.shake(0.4, 0.1, 25, true)
		elseif t < 8.8 then
			-- one long climbing move: alongside them, slowly swinging round and under
			-- as the cloud sea falls away and the sky deepens to black
			local e = K.k(t, 2.4, 8.8, E.inOutSine)
			local side = out:Cross(Vector3.yAxis)
			local a = K.lerp(0, 1.25, e)
			local dir = out * math.cos(a) + side * math.sin(a)
			local p = center + dir * K.lerp(42, 60, e) + Vector3.new(0, K.lerp(-6, -18, e), 0)
			K.setCam(CFrame.lookAt(p, center + Vector3.new(0, K.lerp(6, 18, e), 0)) * CFrame.Angles(0, 0, math.rad(K.lerp(-6, 8, e))), K.lerp(58, 55, e))
			K.shake(0.3 * (1 - e), 0.1, 25, true)
		elseif t < 11.2 then
			-- close on your face: meteors streaking behind, the first stars
			local p = head + rcf.LookVector * 6 + rcf.RightVector * 2 + Vector3.new(0, -2.2, 0)
			K.setCam(CFrame.lookAt(p, head + Vector3.new(0, 0.8, 0)), 40)
		else
			-- the last look back before space: over their shoulders at the whole round
			-- world below. The cloud sea curves away to a glowing blue horizon, the sky
			-- above goes black and the stars come out; the camera drifts back and
			-- tilts down as they climb away from it.
			local e = K.k(t, 11.2, dur, E.inOutSine)
			local sd = K.lightDir()
			local flat = Vector3.new(sd.X, 0, sd.Z)
			flat = flat.Magnitude > 0.05 and flat.Unit or Vector3.xAxis
			-- side-lit: every dome cloud gets a bright side and a shadowed side
			local view = flat:Cross(Vector3.yAxis).Unit
			local p = center - view * K.lerp(16, 30, e) + Vector3.new(0, K.lerp(7, 22, e), 0)
			local dipNow = math.deg(math.acos(math.clamp(A.PlanetR / math.max((p - A.PlanetC).Magnitude, A.PlanetR), 0, 1)))
			-- aim a little under the horizon, so the curve of the world sits across the upper frame
			local pitch = math.rad(-(dipNow + K.lerp(5, 16, e)))
			local look = p + (view * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)) * 100
			local rush = K.k(t, dur - 1.4, dur, E.inQuad)
			K.setCam(CFrame.lookAt(p, look) * CFrame.Angles(0, 0, math.rad(K.lerp(-4, 3, e))), K.lerp(58, 68, e) + 14 * rush)
		end
		if not skyFilled then
			skyFilled = true
			fillSky()
		end
		-- lay each stratum down as the camera comes up toward it (emitters far from
		-- the camera don't emit), so they're all in place below for the look back down
		for _, st in ipairs(A.Strata or {}) do
			if not st.Done and camOff > st.Off - 1400 then
				st.Done = true
				for _, e in ipairs(st.E) do e:Emit(math.ceil(st.N / 9)) end
			end
		end
		K.stream(camPos)
	end)
	A.Rush.Rate = 0
	A.Vapor.Rate = 0
	G.hideColumn()
	K.domeHide(A.Dome)
	sky.Parent = nil
	ctx.sets.Grass.Parent = nil
end


return Ch
