--==================================================
-- CHAPTERS 7-9: ANTI-SPIRAL SPACE, BARRIERS, CRASH
-- Waking up adrift in the Anti-Spiral's domain, then
-- falling through its dimensional barriers (they burst like
-- glass) and crashing, tumbling, into the arena.
--==================================================
local Ch = {}

local FALL_TOP = 5950
-- height above the arena floor over the Barriers chapter (t, y)
local FALL_KNOTS = {
	{ 0, 5950 }, { 1.6, 4960 }, { 2.0, 4800 }, { 4.6, 3790 }, { 5.0, 3700 }, { 5.6, 3645 }, { 6.2, 3440 },
	{ 8.0, 2600 }, { 10.4, 1660 }, { 10.8, 1500 }, { 12, 1100 },
}
local BARRIERS = { { Y = 4800, T = 2.0 }, { Y = 3700, T = 5.0 }, { Y = 2600, T = 8.0 }, { Y = 1500, T = 10.8 } }

local function fallY(t)
	if t <= FALL_KNOTS[1][1] then return FALL_KNOTS[1][2] end
	for i = 1, #FALL_KNOTS - 1 do
		local a, b = FALL_KNOTS[i], FALL_KNOTS[i + 1]
		if t <= b[1] then
			local u = (t - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * u
		end
	end
	return FALL_KNOTS[#FALL_KNOTS][2]
end

-- where each slot lands, and where it skids to a stop
local function landPoint(ctx, slot)
	local AC = ctx.TL.ArenaCenter
	local n = ctx.n
	local z = ((slot - 1) - (n - 1) / 2) * 13
	return AC + Vector3.new(-152 + (slot % 2) * 9, 0, z)
end
local function restPoint(ctx, slot)
	local AC = ctx.TL.ArenaCenter
	local n = ctx.n
	local z = ((slot - 1) - (n - 1) / 2) * 11
	return AC + Vector3.new(-92 - (slot % 3) * 5, 0, z * 1.1)
end
Ch.restPoint = restPoint

local function fallXZ(ctx, slot, t)
	-- a loose spread that funnels toward each landing point
	local lp = landPoint(ctx, slot)
	local a = slot * 1.9 + t * 0.35
	local spread = 26 * (1 - math.clamp(t / 12, 0, 1)) + 4
	return Vector3.new(lp.X + math.cos(a) * spread, 0, lp.Z + math.sin(a) * spread)
end

function Ch.build(ctx)
	local K = ctx.kit
	local AC = ctx.TL.ArenaCenter
	local rng = Random.new(77)
	local set = Instance.new("Folder")
	set.Name = "AntiSet"
	ctx.sets.Anti = set
	local top = AC + Vector3.new(-150, FALL_TOP, 0)
	ctx.AntiTop = top

	-- the Anti-Spiral's sigils: huge hex rings slowly turning around you
	local host = K.part({ Name = "SigilHost", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(top) }, set)
	ctx.SigilHost = host
	ctx.Sigils = {}
	for i = 1, 7 do
		local s = 700 + i * 380
		local cf = CFrame.new(top) * CFrame.Angles(rng:NextNumber(-1.2, 1.2), rng:NextNumber(0, 6), rng:NextNumber(-1.2, 1.2))
		local q = K.quad(host, cf, s, s, i % 2 == 0 and "3423005094" or "18823306900", {
			Color = i % 2 == 0 and Color3.fromRGB(90, 170, 255) or Color3.fromRGB(150, 110, 255), Brightness = 1.4, Transparency = 0.55,
		})
		table.insert(ctx.Sigils, { Q = q, Base = cf, Speed = rng:NextNumber(-0.05, 0.05) })
	end
	-- the Anti-Spiral's domain: galaxies at every depth and angle, long streaks of
	-- colour, bright stars (each placed on its own, so it has real depth)
	ctx.AntiCosmos = K.cosmos(set, {
		Center = top + Vector3.new(0, -1800, 0), Radius = 5200, Avoid = 700, Seed = 41, LookAt = top + Vector3.new(0, -1500, 0),
		Galaxies = 90, GalSize = { 120, 700 }, Streaks = 18, StreakLen = { 1500, 4200 }, Clouds = 24,
		Suns = 26, SunSize = { 14, 60 }, Planets = 0,
	})
	local nb = K.part({ Name = "AntiNebula", Size = Vector3.new(2400, 1600, 2400), CFrame = CFrame.new(top), Transparency = 1 }, set)
	ctx.AntiNebula = K.emitter(nb, {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(80, 50, 200), Color3.fromRGB(30, 140, 255)), Size = K.ns(0, 300, 1, 500),
		Lifetime = NumberRange.new(18, 20), Speed = NumberRange.new(0), Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rate = 2, Brightness = 0.6, Transparency = K.ns(0, 1, 0.3, 0.85, 0.7, 0.85, 1, 1),
		Rotation = NumberRange.new(0, 360),
	})
	ctx.AntiStars = K.emitter(nb, {
		Texture = "17000879366", Color = ColorSequence.new(Color3.fromRGB(230, 235, 255)), Size = K.ns(0, 0, 0.2, 5, 0.8, 5, 1, 0),
		Lifetime = NumberRange.new(16, 20), Speed = NumberRange.new(0), Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rate = 60, Brightness = 3,
	})

	-- the barriers: nested geodesic domes over the arena (you fall in through the top
	-- of each one), built from ForceField facets with a hex pattern on each
	ctx.Barriers = {}
	local domeC = Vector3.new(AC.X - 150, AC.Y, AC.Z)
	for i, b in ipairs(BARRIERS) do
		local R = b.Y
		local tile = math.clamp(R * 0.2, 300, 1000)
		local dth = tile / R
		local bh = K.part({ Name = "BarrierHost" .. i, Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(domeC + Vector3.new(0, R, 0)) }, set)
		local tiles = {}
		local hue = ({ Color3.fromRGB(120, 90, 255), Color3.fromRGB(90, 140, 255), Color3.fromRGB(150, 90, 255), Color3.fromRGB(80, 170, 255) })[i]
		for ring = 0, 4 do
			local th = ring * dth
			local count = ring == 0 and 1 or math.max(6, math.floor(2 * math.pi * math.sin(th) * R / tile + 0.5))
			for k = 1, count do
				local ph = (k - 1) / count * 2 * math.pi + ring * 0.37
				local dir = Vector3.new(math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph))
				local pos = domeC + dir * R
				local tan = dir:Cross(Vector3.new(math.cos(ph + 1), 0, math.sin(ph + 1))).Unit
				local cf = CFrame.fromMatrix(pos, tan, dir)
				local w = tile * 1.12
				local part = K.part({ Name = "Facet", Size = Vector3.new(w, 1, w), CFrame = cf, Material = Enum.Material.ForceField, Color = hue, Transparency = 0 }, set)
				local hex = K.quad(bh, CFrame.lookAt(pos + dir * 1.2, pos + dir * 3), w, w, "3423005094", { Color = Color3.fromRGB(140, 190, 255), Brightness = 1.6, Transparency = 0.35 })
				table.insert(tiles, { Part = part, Hex = hex, Pos = pos, Dir = dir, CF = cf })
			end
		end
		local wave = K.softRing(bh, 40, 10, 40, { Brightness = 3, Alpha = 0 })
		for _, q in ipairs(wave.Q) do q.Color = ColorSequence.new(Color3.fromRGB(230, 220, 255)) end
		table.insert(ctx.Barriers, { Tiles = tiles, Host = bh, Wave = wave, Y = AC.Y + b.Y, R = R, T = b.T, Center = domeC, Tile = tile, Hue = hue })
	end
	ctx.Shards = Instance.new("Folder", set)
	ctx.Shards.Name = "Shards"
	-- a key light that rides with the party: the domain is so dark that the
	-- bodies otherwise read as black holes against black space
	local pl = K.part({ Name = "PartyLight", Size = Vector3.new(1, 1, 1), Transparency = 1 }, set)
	ctx.PartyLight = pl
	for _, off in ipairs({ Vector3.new(0, 14, 6), Vector3.new(0, -16, -6) }) do
		local a = Instance.new("Attachment")
		a.Position = off
		a.Parent = pl
		local l = Instance.new("PointLight")
		l.Range = 44
		l.Brightness = 1.3
		l.Color = Color3.fromRGB(200, 185, 255)
		l.Shadows = false
		l.Parent = a
	end
	-- rushing air streaks around the camera while falling
	local streak = K.part({ Name = "FallStreaks", Size = Vector3.new(80, 10, 80), Transparency = 1 }, set)
	ctx.FallStreakHost = streak
	ctx.FallStreaks = K.emitter(streak, {
		Texture = "1053548563", Color = ColorSequence.new(Color3.fromRGB(210, 220, 255)), Size = K.ns(0, 0.5),
		Lifetime = NumberRange.new(0.25, 0.35), Speed = NumberRange.new(420, 520), Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = K.ns(0, 3), Transparency = K.ns(0, 0.45), Brightness = 2, EmissionDirection = Enum.NormalId.Top,
	})
end

-- burst a dome: the facets round the hole are blown out and spin away, a
-- shockwave races across the curve, and the rest of the dome flickers out
local function shatter(ctx, b, point)
	local K = ctx.kit
	if b.Broken then return end
	b.Broken = true
	K.sfx(K.S.Glass1, 1, 0.8)
	K.sfx(K.S.Glass2, 0.8, 0.6)
	K.sfx(K.S.Boom, 0.8, 1.1)
	task.delay(0.06, function() K.sfx(K.S.Glass3, 0.9, 0.7) end)
	K.flash(0.18, Color3.fromRGB(215, 200, 255), 0.45)
	K.vfx("ForceField-Break-01", CFrame.new(point), ctx.Shards, 18, 18, 4)
	K.vfx("Shield-Break-01", CFrame.new(point), ctx.Shards, 16, 22, 4)
	local rng = Random.new()
	local flying, fading = {}, {}
	for _, tl in ipairs(b.Tiles) do
		local d = (tl.Pos - point).Magnitude
		if d < b.Tile * 1.7 then
			local out = (tl.Pos - point)
			out = out.Magnitude > 1 and out.Unit or rng:NextUnitVector()
			tl.Hex.Transparency = K.ns(1)
			table.insert(flying, { T = tl, Vel = out * rng:NextNumber(90, 260) + Vector3.new(0, -rng:NextNumber(40, 200), 0), Spin = rng:NextUnitVector() * rng:NextNumber(0.6, 2.4) })
		else
			table.insert(fading, { T = tl, Delay = d / (b.R * 1.2) })
		end
	end
	-- a shower of small glass shards at the hole
	local shards = {}
	for i = 1, 60 do
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.CastShadow = false
		w.Material = i % 3 == 0 and Enum.Material.Neon or Enum.Material.SmoothPlastic
		w.Color = i % 3 == 0 and Color3.fromRGB(170, 200, 255) or Color3.fromRGB(205, 190, 255)
		w.Transparency = 0.25
		w.Reflectance = i % 3 == 0 and 0 or 0.55
		local sz = rng:NextNumber(4, 26)
		w.Size = Vector3.new(0.4, sz, sz * rng:NextNumber(0.4, 1.2))
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, 70)
		w.CFrame = CFrame.new(point + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		w.Parent = ctx.Shards
		table.insert(shards, { Part = w, CF = w.CFrame, Vel = Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(60, 260) + Vector3.new(0, rng:NextNumber(-260, 60), 0), Spin = rng:NextUnitVector() * rng:NextNumber(2, 9) })
	end
	local waveCF = CFrame.lookAt(point, point + Vector3.new(0, 1, 0))
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - t0
		local wu = math.clamp(t / 1.1, 0, 1)
		local r0 = 20 + b.R * 0.9 * (1 - (1 - wu) ^ 3)
		b.Wave.update(waveCF, r0, r0 + 60 + wu * 120, t)
		b.Wave.setTransparency(K.ns(math.min(0.99, 0.05 + wu ^ 1.5)))
		for _, f in ipairs(flying) do
			local tl = f.T
			tl.Part.CFrame = CFrame.new(tl.CF.Position + f.Vel * t + Vector3.new(0, -40 * t * t, 0)) * tl.CF.Rotation * CFrame.fromAxisAngle(f.Spin.Unit, f.Spin.Magnitude * t)
			tl.Part.Transparency = math.min(1, t / 2.2)
		end
		for _, f in ipairs(fading) do
			local u = math.clamp((t - f.Delay) / 0.8, 0, 1)
			local flick = (u > 0 and u < 1 and math.random() < 0.3) and 0.4 or 0
			f.T.Part.Transparency = math.min(1, u + flick)
			f.T.Hex.Transparency = K.ns(math.min(0.99, 0.35 + u * 0.65 + flick))
		end
		for _, sh in ipairs(shards) do
			sh.Part.CFrame = CFrame.new(sh.CF.Position + sh.Vel * t + Vector3.new(0, -60 * t * t, 0)) * sh.CF.Rotation * CFrame.fromAxisAngle(sh.Spin.Unit, sh.Spin.Magnitude * t)
			if t > 1.4 then sh.Part.Transparency = math.min(1, sh.Part.Transparency + 0.03) end
		end
		if t > 2.6 then
			conn:Disconnect()
			b.Wave.setTransparency(K.ns(0.99))
			for _, tl in ipairs(b.Tiles) do tl.Part.Transparency = 1 tl.Hex.Transparency = K.ns(1) end
			for _, sh in ipairs(shards) do sh.Part:Destroy() end
		end
	end)
end

------------------------------------------------------------------------
-- ANTI-SPIRAL SPACE
------------------------------------------------------------------------
function Ch.AntiSpace(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local set = ctx.sets.Anti
	set.Parent = ctx.stage
	local top = ctx.AntiTop
	for _, b in ipairs(ctx.Barriers) do
		b.Broken = false
		for _, tl in ipairs(b.Tiles) do
			tl.Part.CFrame = tl.CF
			tl.Part.Transparency = 0
			tl.Hex.Transparency = K.ns(0.35)
		end
		b.Wave.setTransparency(K.ns(0.99))
	end
	-- a faint lavender rim on everyone so they read against the void
	ctx.AntiHL = ctx.AntiHL or {}
	for _, rig in pairs(ctx.rigs) do
		if rig.Model and not ctx.AntiHL[rig] then
			local h = Instance.new("Highlight")
			h.Name = "AntiRim"
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.FillColor = Color3.fromRGB(170, 150, 255)
			h.FillTransparency = 0.88
			h.OutlineColor = Color3.fromRGB(205, 190, 255)
			h.OutlineTransparency = 0.35
			h.Parent = rig.Model
			ctx.AntiHL[rig] = h
		end
	end
	K.lighting("Anti", 0)
	K.fade(1, 0)
	K.fade(0, 3)
	ctx.AntiStars:Emit(900)
	ctx.AntiNebula:Emit(30)
	ctx.setMusic(K.S.M_Universe, 0.6, 3)
	local amb = K.loop(K.S.SpaceAmb, 0.35, 3, 0.8)
	local cue = K.once()
	local me = ctx.myRig
	-- hide the real boss and the arena's own lighting FX while we're up here
	ctx.hideBoss(true)

	K.run(t0, dur, function(t, dt)
		for _, s in ipairs(ctx.Sigils) do
			K.moveQuad(s.Q, s.Base * CFrame.Angles(0, 0, t * s.Speed))
		end
		ctx.AntiCosmos.face(K.Cam.CF.Position, t)
		local grab = K.k(t, 6.3, dur, E.inQuad)
		local center
		for slot, rig in pairs(ctx.rigs) do
			local xz = fallXZ(ctx, slot, 0)
			-- adrift in every direction: each body at its own depth, slowly turning
			-- head over heels (not all lying in one flat plane)
			local depth = ((slot * 37) % 7 - 3) * 6
			local p = Vector3.new(xz.X, top.Y + depth, xz.Z) + K.zeroGOffset(t, slot, 5) - Vector3.new(0, grab * 40, 0)
			local drift = CFrame.fromEulerAnglesYXZ(math.rad(140) + t * 0.18 * (slot % 2 == 0 and 1 or -1), slot * 1.3, math.rad(25) * math.sin(slot))
			local body = CFrame.new(p) * drift * K.zeroGRot(t, slot, 1.3, slot % 2 == 0 and 1 or -1)
			local dive = CFrame.new(p) * CFrame.Angles(math.rad(-70), slot * 0.8, 0)
			rig:setCF(body:Lerp(dive, grab))
			local pose = K.mixPose(K.zeroGPose(t, slot, 1.2), K.mixPose(K.Poses.SkydiveFlat, K.zeroGPose(t * 2.5, slot, 0.8), 0.3), grab)
			pose.Neck = (pose.Neck or CFrame.new()) * K.A(0, math.sin(t * 0.3 + slot) * 25, 0)
			rig:setPose(pose)
			rig:apply()
			if rig == me then center = p end
		end
		center = center or top
		ctx.PartyLight.CFrame = CFrame.new(center)
		if t < 4.2 then
			-- slowly pulling back from you adrift, revealing where you are
			local e = K.k(t, 0, 4.2, E.outSine)
			local head = me and me:head() and me:head().Position or center
			local p = head + Vector3.new(K.lerp(3, 40, e), K.lerp(1, 18, e), K.lerp(6, 70, e))
			K.setCam(CFrame.lookAt(p, head) * CFrame.Angles(0, 0, math.rad(-15 * (1 - e))), K.lerp(40, 65, e))
		else
			-- huge wide: tiny people against the sea of galaxies, the first barrier below
			local e = K.k(t, 4.2, dur, E.inOutSine)
			local p = center + Vector3.new(K.lerp(-260, -200, e), K.lerp(90, 40, e), K.lerp(260, 200, e))
			K.setCam(CFrame.lookAt(p, center + Vector3.new(0, -220 * e, 0)), 60)
		end
		cue("grab", t >= 6.3, function()
			K.sfx(K.S.Rumble, 0.8)
			K.sfx(K.S.Whoosh, 0.8, 0.8)
			K.shake(1.4, 1.6)
			K.gradePunch(0.3, 0, 1, Color3.fromRGB(210, 200, 255))
		end)
		K.stream(center)
	end)
	K.fadeSound(amb, 0, 1, true)
end

------------------------------------------------------------------------
-- BARRIERS
------------------------------------------------------------------------
function Ch.Barriers(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local set = ctx.sets.Anti
	set.Parent = ctx.stage
	local AC = ctx.TL.ArenaCenter
	local me = ctx.myRig
	local cue = K.once()
	local wind = K.loop(K.S.Rush, 0.9, 0.5)
	ctx.setMusic(K.S.M_Trailer, 0.65, 0.5)
	ctx.FallStreaks.Rate = 220
	if ctx.restoreArena then ctx.restoreArena() end
	ctx.hideBoss(true)

	K.run(t0, dur, function(t, dt)
		local center, centerY
		for slot, rig in pairs(ctx.rigs) do
			local lagT = t - (slot - 1) * 0.04
			local y = AC.Y + fallY(lagT) + math.sin(slot * 2.3) * 8
			local xz = fallXZ(ctx, slot, t)
			local p = Vector3.new(xz.X, y, xz.Z)
			rig:setCF(CFrame.new(p) * CFrame.Angles(math.rad(-80) + math.sin(t * 2 + slot) * 0.25, slot * 0.8 + math.sin(t * 0.5) * 0.3, math.sin(t * 1.3 + slot) * 0.35))
			-- (wind-whipped limbs, but smooth: slow layered motion over the skydive pose)
			rig:setPose(K.mixPose(K.Poses.SkydiveFlat, K.zeroGPose(t * 3.5, slot, 1.1), 0.35))
			rig:apply()
			if rig == me then center, centerY = p, y end
		end
		center = center or Vector3.new(AC.X - 150, AC.Y + fallY(t), AC.Z)
		ctx.FallStreakHost.CFrame = CFrame.new(center - Vector3.new(0, 60, 0))
		ctx.PartyLight.CFrame = CFrame.new(center)
		ctx.AntiCosmos.face(K.Cam.CF.Position, t)
		-- shatter each barrier as the party reaches it
		for i, b in ipairs(ctx.Barriers) do
			if not b.Broken and center.Y <= b.Y + 6 then
				shatter(ctx, b, Vector3.new(center.X, b.Y, center.Z))
				K.shake(2.2, 1)
				K.kick(12, 0.6)
				local subjects = {}
				for _, rig in pairs(ctx.rigs) do table.insert(subjects, rig.Model) end
				task.spawn(K.impact, subjects, i % 2 == 0 and "BW" or "WV", 0.05)
			end
		end
		-- camera: a different angle for each barrier
		if t < 3.2 then
			-- below barrier 1 looking up as they smash through toward you
			local b = ctx.Barriers[1]
			-- (a long lens while they're far up there, opening wide as they arrive)
			local p = Vector3.new(center.X + 16, b.Y - 45, center.Z + 20)
			K.setCam(CFrame.lookAt(p, center), K.lerp(26, 76, K.k(t, 0.3, 2.1, E.inQuad)))
		elseif t < 6.4 then
			-- side, with a speed ramp through barrier 2
			local b = ctx.Barriers[2]
			-- (high enough that the next plane reads as a floor rushing up under them)
			local p = Vector3.new(center.X - 38, center.Y + 24, center.Z + 24)
			K.setCam(CFrame.lookAt(p, Vector3.new(center.X, center.Y - 12, center.Z)), K.k(t, 4.6, 5.6) > 0 and 48 or 62)
		elseif t < 9.2 then
			-- first person, face down, the glass rushing up at you
			local head = me and me:head() and me:head().Position or center
			local cf = CFrame.lookAt(head + Vector3.new(0, -1.2, 0), head + Vector3.new(0, -100, 0.1)) * CFrame.Angles(0, 0, t * 0.4)
			K.setCam(cf, 80)
		else
			-- top-down: through the last one, the arena opening up below
			local p = center + Vector3.new(5, 24, 7)
			K.setCam(CFrame.lookAt(p, center + Vector3.new(0, -200, 0)), 72)
		end
		K.shake(0.35, 0.1, 30, true)
		cue("arenaGlow", t >= 10, function()
			K.lighting("Arena", 2)
		end)
		K.stream(Vector3.new(center.X, math.max(center.Y - 600, AC.Y + 50), center.Z))
	end)
	K.fadeSound(wind, 0.4, 0.3)
	ctx.Wind = wind
end

------------------------------------------------------------------------
-- CRASH
------------------------------------------------------------------------
local function stumble(ctx, rig, slot, tr, rest, facing)
	-- tr = seconds since this rig came to rest; returns root CF + pose
	local K = ctx.kit
	local A = K.A
	local floor = ctx.TL.ArenaCenter.Y
	local keys = {
		{ 0.0, { pitch = -88, h = 0.55, pose = { Neck = A(35, 25, 0), RS = A(160, 0, 25), LS = A(20, 0, -35), RH = A(0, 0, 6), LH = A(0, 0, -6) } } },
		{ 1.0, { pitch = -86, h = 0.6, pose = { Neck = A(40, -10, 0), RS = A(120, 0, 10), LS = A(40, 0, -20), RH = A(6, 0, 6), LH = A(-4, 0, -6) } } },
		{ 1.9, { pitch = -58, h = 1.9, pose = { Neck = A(35, 0, 0), RS = A(58, 0, 6), LS = A(58, 0, -6), RH = A(95, 0, 4), LH = A(80, 0, -4) } } },
		{ 2.9, { pitch = -12, h = 2.05, pose = { Neck = A(-5, 0, 0), RS = A(45, 0, 12), LS = A(-5, 0, -10), RH = A(88, 0, 0), LH = A(-58, 0, 0) } } },
		{ 3.8, { pitch = -18, h = 2.6, pose = { Neck = A(8, 0, 0), RS = A(30, 0, 22), LS = A(24, 0, -22), RH = A(40, 0, 8), LH = A(20, 0, -8) } } },
		{ 4.6, { pitch = 4, h = 3.0, pose = { Neck = A(10, 0, 0), RS = A(8, 0, 10), LS = A(6, 0, -10), RH = A(-8, 0, 3), LH = A(10, 0, -3) } } },
	}
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if tr <= keys[i + 1][1] then a, b = keys[i], keys[i + 1] break end
	end
	local u = (b[1] > a[1]) and math.clamp((tr - a[1]) / (b[1] - a[1]), 0, 1) or 1
	u = K.E.inOutSine(u)
	local pitch = K.lerp(a[2].pitch, b[2].pitch, u)
	local h = K.lerp(a[2].h, b[2].h, u)
	local pose = K.mixPose(a[2].pose, b[2].pose, u)
	-- wobble when first standing
	local wob = K.k(tr, 3.6, 4.4) * (1 - K.k(tr, 4.8, 6))
	pose.Neck = pose.Neck * K.A(0, 0, math.sin(tr * 5 + slot) * 6 * wob)
	local step = K.k(tr, 4.3, 4.9) * 1.6
	local pos = rest + facing.LookVector * step
	local cf = CFrame.new(pos.X, floor + h, pos.Z) * facing.Rotation * CFrame.Angles(math.rad(pitch), 0, math.rad(math.sin(tr * 4 + slot) * 5 * wob))
	return cf, pose
end
Ch.stumble = stumble

function Ch.Crash(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local set = ctx.sets.Anti
	set.Parent = ctx.stage
	local AC = ctx.TL.ArenaCenter
	local floor = AC.Y
	local me = ctx.myRig
	local cue = K.once()
	ctx.hideBoss(true)
	K.lighting("Arena", 0.5)
	local startH = {}
	for slot, rig in pairs(ctx.rigs) do startH[slot] = rig:cf().Position.Y - floor end
	local facing = CFrame.lookAt(Vector3.zero, Vector3.new(1, 0, 0))
	local LAND = 2.2

	K.run(t0, dur, function(t, dt)
		local center
		for slot, rig in pairs(ctx.rigs) do
			local myLand = LAND + ((slot - 1) % 4) * 0.12
			local lp = landPoint(ctx, slot)
			local rp = restPoint(ctx, slot)
			if t < myLand then
				-- tumbling the last stretch
				local u = t / myLand
				local h = K.lerp(startH[slot] or 1100, 1.5, E.inQuad(u))
				local xz = fallXZ(ctx, slot, 12):Lerp(Vector3.new(lp.X, 0, lp.Z), u)
				rig:setCF(CFrame.new(xz.X, floor + h, xz.Z) * CFrame.Angles(t * (5 + slot * 0.4), slot, t * 3))
				rig:setPose(K.flail(t, slot, 1.4, K.Poses.Tumble))
			else
				local tb = t - myLand
				local SK = 2.2 -- bounce + skid time
				if tb < SK then
					-- bounce, bounce, slide
					local u = tb / SK
					local x = K.lerp(lp.X, rp.X, E.outCubic(u))
					local z = K.lerp(lp.Z, rp.Z, E.outCubic(u))
					local h
					if tb < 0.75 then h = 1 + math.sin(tb / 0.75 * math.pi) * 9
					elseif tb < 1.2 then h = 1 + math.sin((tb - 0.75) / 0.45 * math.pi) * 2.5
					else h = 0.6 end
					local roll = tb < 1.2 and tb * 10 or 0
					local cf = CFrame.new(x, floor + h, z) * facing.Rotation
					if tb < 1.2 then
						cf = cf * CFrame.Angles(roll, 0, math.sin(roll) * 0.4)
					else
						cf = cf * CFrame.Angles(math.rad(-88), 0, 0)
					end
					rig:setCF(cf)
					rig:setPose(tb < 1.2 and K.flail(t, slot, 1.2, K.Poses.Tumble) or K.Poses.LyingFront)
					-- dust trail while sliding
					if tb > 1.2 and not rig.Skid then
						rig.Skid = true
						K.vfx("Smoke-01", CFrame.new(x, floor + 1, z), set, 2, 8, 3)
					end
				else
					local tr = tb - SK - ((slot - 1) % 3) * 0.25
					local cf, pose = stumble(ctx, rig, slot, math.max(tr, 0), rp, facing)
					rig:setCF(cf)
					pose.Neck = pose.Neck * K.A(K.k(tr, 4.6, 6) * 8, 0, 0)
					rig:setPose(pose)
				end
			end
			rig:apply()
			if rig == me then center = rig:cf().Position end
			local key = "land" .. slot
			cue(key, t >= myLand, function()
				K.vfx("Big-Crack-01", CFrame.new(lp.X, floor + 0.6, lp.Z), set, 0.9, 10, 3)
				K.vfx("Realistic-Explosion-01", CFrame.new(lp.X, floor + 1, lp.Z), set, 0.8, 8, 3)
				K.vfx("Shoot-01", CFrame.new(lp.X, floor + 0.8, lp.Z) * CFrame.Angles(math.rad(90), 0, 0), set, 2.2, 3, 3)
				if slot == 1 or rig == me then
					K.sfx(K.S.BigHit, 1)
					K.sfx(K.S.RockBoom, 0.9)
					K.sfx(K.S.BodyFall, 0.9)
					K.shake(3, 1.4)
					K.kick(-14, 0.7)
				else
					K.sfx(K.S.Thump, 0.6)
				end
				if slot == 1 then
					local subjects = {}
					for _, r in pairs(ctx.rigs) do table.insert(subjects, r.Model) end
					task.spawn(K.impact, subjects, "WBY", 0.05)
				end
			end)
		end
		center = center or restPoint(ctx, 1)
		ctx.FallStreaks.Rate = t < LAND and 220 or 0
		ctx.FallStreakHost.CFrame = CFrame.new(center - Vector3.new(0, 60, 0))
		-- the arena lights them from here on: the rider light and the rim fade out
		local keep = 1 - K.k(t, LAND, LAND + 1.5)
		ctx.PartyLight.CFrame = CFrame.new(center)
		-- (the light stays on, warm and low, as a key on the faces against the glowing floor)
		local warm = K.k(t, LAND, LAND + 1.5)
		for _, a in ipairs(ctx.PartyLight:GetChildren()) do
			local l = a:FindFirstChildOfClass("PointLight")
			if l then
				l.Brightness = 1.3 * keep + 0.7 * warm
				l.Color = Color3.fromRGB(200, 185, 255):Lerp(Color3.fromRGB(255, 225, 180), warm)
			end
		end
		for _, h in pairs(ctx.AntiHL or {}) do
			h.OutlineTransparency = 1 - 0.65 * keep
			h.FillTransparency = 1 - 0.12 * keep
		end
		cue("windOff", t >= LAND, function()
			if ctx.Wind then K.fadeSound(ctx.Wind, 0, 0.3, true) ctx.Wind = nil end
			ctx.fadeMusic(0.2, 1.2)
		end)

		-- camera
		if t < LAND then
			-- chasing you from above as the gold floor rushes up
			local p = center + Vector3.new(-14, 26, 12)
			K.setCam(CFrame.lookAt(p, center + Vector3.new(4, -30, 0)) * CFrame.Angles(0, 0, t * 0.6), 78)
		elseif t < 4.8 then
			-- low wide from the side: the crash, bounce, skid
			local mid = (landPoint(ctx, 1) + restPoint(ctx, 1)) / 2
			local p = mid + Vector3.new(-10, 5, 70)
			K.setCam(CFrame.lookAt(p, mid + Vector3.new(6, 1, 0)), 55)
		elseif t < 7.4 then
			-- close: you pushing yourself up off the glowing floor
			local e = K.k(t, 4.8, 7.4)
			local p = center + Vector3.new(K.lerp(9, 7, e), K.lerp(2, 3.5, e), K.lerp(7, 5, e))
			K.setCam(CFrame.lookAt(p, center + Vector3.new(0, 0.5, 0)), 45)
		else
			-- over the shoulders: the shrine far ahead, glowing
			local e = K.k(t, 7.4, dur, E.inOutSine)
			local p = center + Vector3.new(-8, K.lerp(2.4, 3.2, e), 5)
			K.setCam(CFrame.lookAt(p, ctx.TL.LapisPos - Vector3.new(0, 20, 0)), K.lerp(50, 44, e))
		end
		K.stream(center)
	end)
	for _, h in pairs(ctx.AntiHL or {}) do h:Destroy() end
	ctx.AntiHL = nil
	for _, a in ipairs(ctx.PartyLight:GetChildren()) do
		local l = a:FindFirstChildOfClass("PointLight")
		if l then l.Brightness = 1.3 l.Color = Color3.fromRGB(200, 185, 255) end
	end
	set.Parent = nil
end

return Ch
