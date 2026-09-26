--==================================================
-- SPIRAL GALAXY I: EJECTED, LAYERS, DESCENT, CATCH
-- Spat out of the portal's vortex and spinning out of control,
-- the party falls through layer after layer of 4-D space (each
-- membrane a pane of crystal lattice that shatters as they hit it),
-- drops into the Galaxy Realm, and the Anti-Spiral erupts from the
-- void beneath the arena to catch them in his hand.
--==================================================
local SK = require(script.Parent:WaitForChild("SpiralKit"))
local Ch = {}

local UP = Vector3.yAxis
local SIDE = SK.DIRE:Cross(UP).Unit

-- one palette per layer of 4-D space (it changes at every pane); the last is the realm
local PAL = {
	{ A = Color3.fromRGB(150, 90, 255), B = Color3.fromRGB(90, 220, 255) },
	{ A = Color3.fromRGB(80, 210, 255), B = Color3.fromRGB(255, 80, 210) },
	{ A = Color3.fromRGB(255, 80, 200), B = Color3.fromRGB(255, 200, 110) },
	{ A = Color3.fromRGB(60, 255, 190), B = Color3.fromRGB(170, 110, 255) },
	{ A = Color3.fromRGB(255, 190, 90), B = Color3.fromRGB(90, 230, 255) },
	{ A = Color3.fromRGB(110, 140, 255), B = Color3.fromRGB(255, 110, 170) },
	{ A = Color3.fromRGB(215, 200, 255), B = Color3.fromRGB(150, 90, 255) },
	{ A = Color3.fromRGB(185, 140, 255), B = Color3.fromRGB(255, 205, 120) },
}
-- when each pane is hit (seconds into the Layers chapter)
local PANE_AT = { 1.2, 2.6, 4.2, 5.9, 7.7, 9.8, 12.85 }
local IMPACT = { "WV", "BW", "WB", "VW", "BWB", "WV", "WBW" }

local function outExpo(x) return x >= 1 and 1 or 1 - 2 ^ (-10 * x) end

--------------------------------------------------------------------------
-- where each of the party is in the air
--------------------------------------------------------------------------
local AXES = {}
local function spinCF(slot, g)
	local ax = AXES[slot]
	if not ax then
		local r = Random.new(slot * 7 + 3)
		ax = (r:NextUnitVector() + SIDE * 1.4).Unit
		AXES[slot] = ax
	end
	return CFrame.fromAxisAngle(ax, SK.spinAngle(g) * (slot % 2 == 0 and 1 or -1) + slot * 1.3)
end
local function airPos(ctx, F, slot, g, spread)
	local off = SK.offset(ctx, slot, spread or 9)
	return F.at(g - (slot - 1) * 0.04) + CFrame.Angles(0, g * 0.35, 0):VectorToWorldSpace(off)
end

------------------------------------------------------------------------
-- BUILD
------------------------------------------------------------------------
function Ch.build(ctx)
	local K = ctx.kit
	local set = Instance.new("Folder")
	set.Name = "EntrySet"
	ctx.sets.Entry = set
	local F, G = SK.fall(ctx)
	local rng = Random.new(41)
	local E = { Layer = 0 }
	ctx.Entry = E
	local fx = Instance.new("Folder")
	fx.Name = "FX"
	fx.Parent = set
	E.FX = fx

	--------------------------------------------------------------------
	-- the portal's exit: a violet whirl hanging in 4-D space
	--------------------------------------------------------------------
	local mcf = CFrame.lookAt(SK.MOUTH, SK.MOUTH + SK.DIRE)
	local mh = K.part({ Name = "MouthHost", Size = Vector3.one, Transparency = 1, CFrame = mcf }, set)
	E.Mouth = {
		CF = mcf,
		Q = {
			{ Q = K.quad(mh, mcf, 1100, 1100, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(190, 150, 255), Brightness = 1.4, Transparency = 0.3 }), S = 1100, W = 0.1 },
			{ Q = K.quad(mh, mcf, 720, 720, "14426232568", { Color = Color3.fromRGB(170, 110, 255), Brightness = 2.5, Transparency = 0.05 }), S = 720, W = 1.6 },
			{ Q = K.quad(mh, mcf, 500, 500, "124165682553877", { Color = Color3.fromRGB(110, 220, 255), Brightness = 3, Transparency = 0.05 }), S = 500, W = -2.4 },
			{ Q = K.quad(mh, mcf, 260, 260, "rbxasset://sky/sun.jpg", { Color = Color3.new(1, 1, 1), Brightness = 4, Transparency = 0 }), S = 260, W = 0 },
		},
		Rim = K.softRing(mh, 48, 300, 380, { Brightness = 3, Alpha = 0.8 }),
		Burst = K.emitter(mh, {
			Texture = "122000198974865", Color = ColorSequence.new(Color3.fromRGB(230, 210, 255), Color3.fromRGB(120, 220, 255)),
			Size = K.ns(0, 6, 1, 0), Lifetime = NumberRange.new(0.6, 1.3), Speed = NumberRange.new(350, 900),
			SpreadAngle = Vector2.new(28, 28), EmissionDirection = Enum.NormalId.Front, Rate = 0, Brightness = 5, Rotation = NumberRange.new(0, 360),
		}),
	}
	for _, q in ipairs(E.Mouth.Rim.Q) do q.Color = ColorSequence.new(Color3.fromRGB(220, 200, 255), Color3.fromRGB(140, 80, 255)) end
	function E.mouth(t, open)
		local on = open > 0.01
		for _, m in ipairs(E.Mouth.Q) do
			m.Q.Enabled = on
			if on then
				K.moveQuad(m.Q, mcf * CFrame.Angles(0, 0, t * m.W))
				local s = m.S * open * (1 + 0.05 * math.sin(t * 7 + m.S))
				K.setQuadSize(m.Q, s, s)
			end
		end
		E.Mouth.Rim.setEnabled(on)
		if on then E.Mouth.Rim.update(mcf, 300 * open, 380 * open, -t * 1.5) end
	end

	--------------------------------------------------------------------
	-- the membranes: one pane of crystal lattice between each layer
	--------------------------------------------------------------------
	E.Panes = {}
	for i, at in ipairs(PANE_AT) do
		local g = G.Layers + at
		local c = F.at(g)
		local pal = PAL[i + 1]
		local tilt = CFrame.Angles(rng:NextNumber(-0.1, 0.1), rng:NextNumber(0, 6.28), rng:NextNumber(-0.1, 0.1))
		local cf = CFrame.new(c + Vector3.new(rng:NextNumber(-140, 140), 0, rng:NextNumber(-140, 140))) * tilt
		local P = SK.pane(K, set, cf, i == #PANE_AT and 2600 or 1600, pal.A, pal.B)
		P.G = g
		P.Index = i
		E.Panes[i] = P
	end

	--------------------------------------------------------------------
	-- 4-D solids: tesseracts turning through the 4th dimension in every
	-- layer, and one vast one caging the whole fall
	--------------------------------------------------------------------
	local th = K.part({ Name = "TessHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(SK.MOUTH) }, set)
	E.Tess = {}
	for k = 1, #PANE_AT do
		local g0 = k == 1 and 0.6 or (G.Layers + PANE_AT[k - 1])
		local g1 = G.Layers + PANE_AT[k]
		for j = 1, 4 do
			local g = g0 + (g1 - g0) * (j - 0.5) / 4
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(170, 620)
			local pos = F.at(g) + Vector3.new(math.cos(a) * d, rng:NextNumber(-120, 120), math.sin(a) * d)
			local size = rng:NextNumber(40, 150)
			local T = SK.tesseract(K, th, (j % 2 == 0) and PAL[k].A or PAL[k].B, math.max(2, size * 0.06))
			table.insert(E.Tess, { T = T, Pos = pos, Size = size, Rot = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
				W = Vector3.new(rng:NextNumber(0.3, 0.9), rng:NextNumber(0.2, 0.7), rng:NextNumber(0.1, 0.5)) * (rng:NextNumber() < 0.5 and -1 or 1) })
		end
	end
	E.Cage = SK.tesseract(K, th, PAL[1].A, 14)
	E.Cage2 = SK.tesseract(K, th, PAL[1].B, 8)

	--------------------------------------------------------------------
	-- the "sky" of 4-D space: prismatic clouds of light that ride along
	-- with the fall (recoloured for every layer)
	--------------------------------------------------------------------
	local sh = K.part({ Name = "SkyHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(SK.MOUTH) }, set)
	E.Sky = {}
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local el = rng:NextNumber(-0.9, 0.5)
		local dir = Vector3.new(math.cos(a) * math.cos(el), math.sin(el), math.sin(a) * math.cos(el))
		local s = rng:NextNumber(5000, 9000)
		local tex = (i % 3 == 0) and "15058059008" or "10180479311"
		local q = K.quad(sh, CFrame.new(SK.MOUTH), s, s * rng:NextNumber(0.5, 0.9), tex, { Brightness = 1.1, Transparency = 0.5 })
		table.insert(E.Sky, { Q = q, Dir = dir, D = rng:NextNumber(5500, 7500), Roll = rng:NextNumber(0, 6.28), AB = i % 2 == 0 })
	end
	-- deep glows far below: the direction of the fall
	E.Deep = {}
	for i = 1, 3 do
		local q = K.quad(sh, CFrame.new(SK.MOUTH), 7000 + i * 3000, 7000 + i * 3000, "rbxasset://sky/sun.jpg", { Brightness = 0.8, Transparency = 0.84 })
		table.insert(E.Deep, q)
	end

	--------------------------------------------------------------------
	-- speed: streaks of light rushing up past you, and a volume of dust
	--------------------------------------------------------------------
	local sth = K.part({ Name = "StreakHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(SK.MOUTH) }, set)
	E.Streaks = {}
	for i = 1, 70 do
		local b = K.ray(sth, Vector3.zero, UP, rng:NextNumber(0.8, 2.4), 0.1, "1084982817", { Transparency = K.ns(0, 0.9, 0.5, 0.2, 1, 0.95), Brightness = 3, Segments = 1 })
		table.insert(E.Streaks, { B = b, A = rng:NextNumber(0, 6.28), R = rng:NextNumber(25, 420), Y = SK.MOUTH.Y + rng:NextNumber(-650, 350), L = rng:NextNumber(0.7, 1.4), AB = i % 2 == 0 })
	end
	local dh = K.part({ Name = "DustHost", Size = Vector3.new(700, 700, 700), Transparency = 1, CFrame = CFrame.new(SK.MOUTH) }, set)
	E.DustHost = dh
	E.Dust = K.emitter(dh, {
		Texture = "131679330853412", Size = K.ns(0, 0, 0.25, 2.4, 1, 0), Transparency = K.ns(0, 0.2, 1, 0.4),
		Lifetime = NumberRange.new(1.2, 2.2), Rate = 240, Speed = NumberRange.new(0), Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Brightness = 3, Rotation = NumberRange.new(0, 90), LightEmission = 1,
	})
	E.Light = Instance.new("PointLight")
	E.Light.Range = 60
	E.Light.Brightness = 2.5
	E.Light.Shadows = false
	local la = Instance.new("Attachment")
	la.Position = Vector3.new(0, 125, 0) -- (on the party, not the dust below them)
	la.Parent = dh
	E.Light.Parent = la
	-- a trail behind the party (for the wide shots, where they're specks)
	E.Trail = K.ray(sth, Vector3.zero, UP, 40, 2, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(235, 220, 255), Brightness = 4, Transparency = K.ns(0, 0, 1, 0.8), Segments = 1 })
	E.Trail.Enabled = false

	-- recolour the whole space for layer k
	function E.setLayer(k)
		if E.Layer == k then return end
		E.Layer = k
		local p = PAL[math.clamp(k, 1, #PAL)]
		for _, s in ipairs(E.Sky) do s.Q.Color = ColorSequence.new(s.AB and p.A or p.B) end
		for i, q in ipairs(E.Deep) do q.Color = ColorSequence.new(i == 2 and p.B or p.A) end
		for _, s in ipairs(E.Streaks) do s.B.Color = ColorSequence.new(s.AB and p.A:Lerp(Color3.new(1, 1, 1), 0.5) or p.B:Lerp(Color3.new(1, 1, 1), 0.5)) end
		E.Dust.Color = ColorSequence.new(p.A:Lerp(Color3.new(1, 1, 1), 0.4), p.B)
		E.Light.Color = p.A:Lerp(Color3.new(1, 1, 1), 0.3)
		for _, b in ipairs(E.Cage.Beams) do b.Color = ColorSequence.new(p.A) end
		for _, b in ipairs(E.Cage2.Beams) do b.Color = ColorSequence.new(p.B) end
		K.tween(K.Grade, 0.5, { TintColor = Color3.new(1, 1, 1):Lerp(p.A, 0.18) })
	end

	-- everything that rides along with the fall
	local lastTess = 0
	function E.follow(centre, g, t, speed, camPos)
		dh.CFrame = CFrame.new(centre - UP * 120)
		for _, s in ipairs(E.Sky) do
			local p = centre + s.Dir * s.D
			K.moveQuad(s.Q, CFrame.lookAt(p, centre) * CFrame.Angles(0, 0, s.Roll + t * 0.02))
		end
		for i, q in ipairs(E.Deep) do
			K.moveQuad(q, CFrame.lookAt(centre - UP * (6000 + i * 1500), centre) * CFrame.Angles(0, 0, t * 0.05 * i))
		end
		-- streaks: fixed in the world, recycled round the fall
		local len = math.clamp(speed * 0.16, 20, 170)
		for _, s in ipairs(E.Streaks) do
			if s.Y > centre.Y + 380 then s.Y -= 1050 elseif s.Y < centre.Y - 670 then s.Y += 1050 end
			local p0 = Vector3.new(centre.X + math.cos(s.A) * s.R, s.Y, centre.Z + math.sin(s.A) * s.R)
			s.B.Attachment0.WorldPosition = p0
			s.B.Attachment1.WorldPosition = p0 + UP * len * s.L
		end
		if E.Realm then return end
		E.Cage.update(CFrame.new(centre) * CFrame.Angles(t * 0.11, t * 0.07, 0), 1100, t * 0.35, t * 0.22, t * 0.13)
		E.Cage2.update(CFrame.new(centre) * CFrame.Angles(0, t * -0.09, t * 0.05), 2200, t * -0.21, t * 0.3, t * 0.08)
		-- (only the solids near the camera are worth turning every frame)
		lastTess += 1
		for i, e in ipairs(E.Tess) do
			local near = (e.Pos - camPos).Magnitude < 2600
			e.T.show(near)
			if near or (i + lastTess) % 12 == 0 then
				e.T.update(CFrame.new(e.Pos) * e.Rot * CFrame.Angles(t * e.W.X * 0.3, t * e.W.Y * 0.3, 0), e.Size, t * e.W.X, t * e.W.Y, t * e.W.Z)
			end
		end
	end
	-- leaving 4-D space: the backdrop and solids go, the shards stay
	function E.leave()
		E.Realm = true
		for _, s in ipairs(E.Sky) do s.Q.Enabled = false end
		for _, q in ipairs(E.Deep) do q.Enabled = false end
		E.Cage.show(false)
		E.Cage2.show(false)
		for _, e in ipairs(E.Tess) do e.T.show(false) end
		E.mouth(0, 0)
		for _, P in ipairs(E.Panes) do if not P.Broken then P.setAlpha(0) end end
	end

	--------------------------------------------------------------------
	-- beneath the arena: the Anti-Spiral's own whirlpool (a black spiral
	-- with a cold rim) that tears open for him, and the void he rises on
	--------------------------------------------------------------------
	local home = ctx.BossHome or CFrame.new(282, 15, 20000)
	local vc = CFrame.new(home.X, -1100, home.Z) * CFrame.Angles(math.rad(-90), 0, 0)
	local vset = Instance.new("Folder")
	vset.Name = "VoidSet"
	ctx.sets.EntryVoid = vset
	local vh = K.part({ Name = "VortexHost", Size = Vector3.one, Transparency = 1, CFrame = vc }, vset)
	E.Vortex = { CF = vc, Q = {} }
	-- (the swirl textures are drawn on black, so only additive light can use them: the
	-- darkness is layers of cloud, which has a real alpha, and the arms are cold light)
	for i, d in ipairs({ { 3400, "10180479311", 0.6, true }, { 2600, "10180479311", -0.9, true }, { 1800, "10180479311", 1.3, true },
		{ 3000, "14426232568", 1.0, false }, { 1900, "124165682553877", -1.6, false }, { 1100, "10180479311", -2.2, true } }) do
		local q = d[4] and K.quad(vh, vc, d[1], d[1], d[2], { Emission = 0, Color = Color3.fromRGB(3, 2, 8), Transparency = 0.05 })
			or K.quad(vh, vc, d[1], d[1], d[2], { Color = Color3.fromRGB(120, 140, 255), Brightness = 1.6, Transparency = 0.2 })
		table.insert(E.Vortex.Q, { Q = q, S = d[1], W = d[3] })
	end
	E.Vortex.Rim = K.softRing(vh, 64, 1300, 1600, { Brightness = 2.5, Alpha = 0.8 })
	for _, q in ipairs(E.Vortex.Rim.Q) do q.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255), Color3.fromRGB(80, 90, 255)) end
	E.Vortex.Rim2 = K.softRing(vh, 48, 380, 520, { Brightness = 3, Alpha = 0.9 })
	for _, q in ipairs(E.Vortex.Rim2.Q) do q.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 140, 255)) end
	-- the column of void he rides up
	E.Pillars = {}
	for i = 1, 3 do
		local w = 360 - i * 80
		local b = K.ray(vh, Vector3.zero, UP, w, w * 1.2, "10180479311", {
			Emission = 0, Color = Color3.fromRGB(6, 4, 16), Transparency = K.ns(0, 0.2, 0.8, 0.35, 1, 0.97),
			Speed = 0.8 + i * 0.3, Mode = Enum.TextureMode.Wrap, Length = 380 + i * 60, Segments = 10,
		})
		b.Enabled = false
		table.insert(E.Pillars, { B = b, W = w })
	end
	E.PillarRim = K.ray(vh, Vector3.zero, UP, 520, 640, "10180479311", {
		Color = Color3.fromRGB(110, 130, 255), Brightness = 2.5, Transparency = K.ns(0, 0.3, 0.8, 0.5, 1, 0.97),
		Speed = 1.4, Mode = Enum.TextureMode.Wrap, Length = 500, Segments = 10,
	})
	E.PillarRim.Enabled = false
	-- the roar: a ring of force blasting out across the realm
	E.Roar = K.softRing(vh, 72, 50, 200, { Brightness = 3, Alpha = 0 })
	for _, q in ipairs(E.Roar.Q) do q.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 150, 255)) end
	E.Roar.setTransparency(0.99)
	-- his eyes
	E.EyeGlow = SK.glow(K, vh, home.Position, 120, Color3.fromRGB(215, 230, 255), 4)
	E.EyeGlow.set(home.Position, 10, 0)
	function E.vortex(t, open)
		local on = open > 0.01
		for _, v in ipairs(E.Vortex.Q) do
			v.Q.Enabled = on
			if on then
				K.moveQuad(v.Q, vc * CFrame.Angles(0, 0, t * v.W * 0.35))
				local s = v.S * open
				K.setQuadSize(v.Q, s, s)
			end
		end
		E.Vortex.Rim.setEnabled(on)
		E.Vortex.Rim2.setEnabled(on)
		if on then
			E.Vortex.Rim.update(vc, 1300 * open, 1600 * open, t * 0.3)
			E.Vortex.Rim2.update(vc, 380 * open, 520 * open, -t * 0.8)
		end
	end
	E.vortex(0, 0)
	-- a ring of force (radius r, alpha a) round a point, flat in the world
	function E.roar(pos, r, a)
		E.Roar.update(CFrame.lookAt(pos, pos + UP), r, r + 90 + r * 0.12, r * 0.002)
		E.Roar.setTransparency(math.clamp(1 - a, 0.05, 0.99))
	end
end

------------------------------------------------------------------------
-- KNOCKBACK: hitting a pane of 4-D space isn't free. Each body is shoved
-- back up off the membrane (a sharp recoil that gravity then wins back),
-- knocked sideways, flipped over by the blow, and thrown into a limp,
-- arms-flung "Blown" pose for a moment. ctx.Knocks[slot] = list of hits.
------------------------------------------------------------------------
local RECOIL_PEAK = 0.2 -- seconds until the recoil is at its highest
local function knockAt(ctx, slot, g)
	local list = ctx.Knocks and ctx.Knocks[slot]
	if not list then return Vector3.zero, CFrame.new(), 0 end
	local off, rot, blown = Vector3.zero, CFrame.new(), 0
	for _, k in ipairs(list) do
		local tau = g - k.G
		if tau > 0 then
			local x = tau / RECOIL_PEAK
			off += k.Dir * (x * math.exp(1 - x))
			rot = CFrame.fromAxisAngle(k.Ax, k.Spin * (1 - math.exp(-6 * tau))) * rot
			blown = math.max(blown, math.exp(-tau / 0.45))
		end
	end
	return off, rot, blown
end

-- a pane at normal `up` was just hit at fall time g: knock the whole party back
local function addKnocks(ctx, index, g, up)
	ctx.Knocks = ctx.Knocks or {}
	local back = up.Y >= 0 and up or -up
	for slot in pairs(ctx.rigs) do
		local r = Random.new(index * 131 + slot * 17)
		local lat = r:NextUnitVector()
		lat = lat - back * lat:Dot(back)
		lat = lat.Magnitude > 0.01 and lat.Unit or SIDE
		ctx.Knocks[slot] = ctx.Knocks[slot] or {}
		table.insert(ctx.Knocks[slot], {
			G = g + (slot - 1) * 0.04, -- (each body reaches the pane a beat after the one ahead)
			Dir = back * r:NextNumber(17, 23) + lat * r:NextNumber(6, 12),
			Ax = r:NextUnitVector(),
			Spin = r:NextNumber(2, 3.4) * (r:NextNumber() < 0.5 and -1 or 1),
		})
	end
end

------------------------------------------------------------------------
-- shared per-frame work for the fall
-- returns where you are (knockback included) and where you'd be without it
-- (follow cameras ride the second so the hits read as real jolts on screen)
------------------------------------------------------------------------
local function placeAir(ctx, F, g, spinAmt, skydive, t)
	local K = ctx.kit
	local me = ctx.myRig
	local myPos, myBase
	for slot, rig in pairs(ctx.rigs) do
		local p = airPos(ctx, F, slot, g)
		local koff, krot, blown = knockAt(ctx, slot, g)
		local spin = spinCF(slot, g)
		local flat = CFrame.Angles(0, slot * 0.9 + math.sin(g * 0.3 + slot) * 0.4, math.sin(g * 1.1 + slot) * 0.15)
		local rot = skydive > 0 and spin:Lerp(flat, skydive) or spin
		-- (the flips from the hits fade out once they settle into a skydive)
		if skydive > 0 then krot = krot:Lerp(CFrame.new(), skydive) end
		rig:setCF(CFrame.new(p + koff) * krot * rot)
		local pose = SK.tumble(K, g * 1.4, slot, spinAmt)
		if skydive > 0 then pose = K.mixPose(pose, K.mixPose(K.Poses.SkydiveFlat, K.zeroGPose(g * 3, slot, 1), 0.3), skydive) end
		if blown > 0.01 then pose = K.mixPose(pose, K.Poses.Blown, blown * 0.9) end
		rig:setPose(pose)
		rig:apply()
		if rig == me then myPos = p + koff myBase = p end
	end
	local c = F.at(g)
	return myPos or c, myBase or c
end

------------------------------------------------------------------------
-- EJECTED: blown out of the vortex, spinning out of control
------------------------------------------------------------------------
function Ch.Ejected(ctx, t0, dur)
	local K = ctx.kit
	local E = ctx.Entry
	local F = SK.fall(ctx)
	local set = ctx.sets.Entry
	set.Parent = ctx.stage
	-- (4-D space has nothing else in it: the realm waits off-stage until the fall)
	if ctx.stashArena then ctx.stashArena() end
	K.lighting("Anti", 0)
	K.Blur.Enabled = false
	K.DOF.Enabled = false
	K.fade(1, 0)
	E.setLayer(1)
	local cue = K.once()
	local cam = SK.camera(K)
	for _, rig in pairs(ctx.rigs) do
		rig:stopAll(0)
		rig:clearPose()
		rig.Smooth = 12
	end
	local shot = 0
	SK.run(K, t0, dur, function(t, dt)
		local g = t
		local open = 1 - K.k(t, 2.6, 4.3, K.E.inCubic)
		E.mouth(t, open)
		local centre = F.at(g)
		local myPos = placeAir(ctx, F, g, 1.25, 0, t)
		local speed = F.vel(g).Magnitude
		E.follow(centre, g, t, speed, K.Cam.CF.Position)
		-- camera
		if t < 2.3 then
			if shot ~= 1 then shot = 1 cam.cut() end
			-- beside the mouth: the vortex, then the party blasting out past us
			local base = SK.MOUTH + SK.DIRE * 380 + SIDE * 40 + UP * 14
			local look = SK.MOUTH:Lerp(myPos, K.k(t, 0.3, 1.1))
			cam.go(CFrame.lookAt(base, look), K.lerp(64, 50, K.k(t, 0.3, 2.3)), dt, 6)
		elseif t < 4.4 then
			if shot ~= 2 then shot = 2 cam.cut() end
			-- right behind you as you tumble
			local v = F.vel(g)
			local vd = v.Magnitude > 1 and v.Unit or -UP
			local sd = vd:Cross(UP)
			sd = sd.Magnitude > 0.01 and sd.Unit or SIDE
			local p = myPos - vd * 14 + UP * 4 + sd * 5
			cam.go(CFrame.lookAt(p, myPos) * CFrame.Angles(0, 0, math.sin(t * 2.3) * 0.22), 66, dt, 8, myPos)
			K.shake(0.5, 0.1, 25, true)
		else
			if shot ~= 3 then shot = 3 cam.cut() end
			-- pulling out: specks spinning away into 4-D space, the first membrane below
			local e = K.k(t, 4.4, dur, K.E.outSine)
			local p = centre + SIDE * K.lerp(90, 260, e) + UP * K.lerp(40, 140, e) - SK.DIRE * K.lerp(60, 200, e)
			cam.go(CFrame.lookAt(p, centre - UP * K.lerp(20, 180, e)), 60, dt, 5, centre)
		end
		cue("out", t >= 0.25, function()
			K.fade(0, 0.12)
			K.flash(0.4, Color3.fromRGB(215, 190, 255), 1)
			K.sfx(K.S.Cannon, 1, 0.9)
			K.sfx(K.S.Portal2, 0.9, 0.8)
			K.sfx(K.S.Boom, 0.9, 1.1)
			K.sfx(K.S.Whoosh, 1, 0.7, { Reverb = 2 })
			K.shake(3.5, 1.3)
			K.kick(18, 0.8)
			E.Mouth.Burst:Emit(180)
			K.vfx("Shoot-01", E.Mouth.CF, E.FX, 30, 3, 3)
			ctx.EntryWind = K.loop(K.S.Rush, 0.85, 0.5)
		end)
		cue("impact", t >= 0.55, function()
			task.spawn(K.impact, SK.models(ctx), "WV", 0.045)
		end)
		cue("music", t >= 0.45, function() ctx.setMusic(K.S.M_Trailer, 0.65, 0.4) end)
		cue("shut", t >= 3.9, function()
			K.sfx(K.S.Portal, 0.6, 1.4)
			K.sfx(K.S.TonalHit, 0.5, 0.8)
		end)
	end)
end

------------------------------------------------------------------------
-- LAYERS: falling through the layers of 4-D space
------------------------------------------------------------------------
function Ch.Layers(ctx, t0, dur)
	local K = ctx.kit
	local E = ctx.Entry
	local F, G = SK.fall(ctx)
	local set = ctx.sets.Entry
	set.Parent = ctx.stage
	if ctx.stashArena then ctx.stashArena() end
	if E.Layer == 0 then
		-- (started here directly in a review)
		K.lighting("Anti", 0)
		E.setLayer(1)
		ctx.EntryWind = ctx.EntryWind or K.loop(K.S.Rush, 0.85, 0.3)
		ctx.setMusic(K.S.M_Trailer, 0.65, 0.3)
	end
	K.fade(0, 0.2)
	E.mouth(0, 0)
	ctx.Knocks = {}
	local cue = K.once()
	local cam = SK.camera(K)
	local shot = 0
	-- one shot per pane; most of them fall WITH you (the camera rides your
	-- fall line, so every knockback throws you around the frame)
	local SHOTS = { "chase", "below", "face", "orbit", "trail", "side", "final" }
	SK.run(K, t0, dur, function(t, dt)
		local g = G.Layers + t
		local centre = F.at(g)
		local spinAmt = K.lerp(1.1, 0.8, K.k(t, 0, dur))
		local myPos, myBase = placeAir(ctx, F, g, spinAmt, 0, t)
		local speed = F.vel(g).Magnitude
		E.follow(centre, g, t, speed, K.Cam.CF.Position)
		-- smash each pane as the party reaches it
		for i, P in ipairs(E.Panes) do
			local up = P.CF.UpVector
			local h = (centre - P.CF.Position):Dot(up)
			if not P.Broken and h < 3 then
				local hit = centre - up * h
				P.shatter(hit, E.FX)
				E.setLayer(i + 1)
				addKnocks(ctx, i, g, up)
				K.sfx(K.S.Punch, 0.8, 0.85 + i * 0.03)
				K.sfx(K.S.BodyFall, 0.6, 0.9)
				K.shake(2.6, 1.1)
				K.kick(14, 0.6)
				K.flash(0.25, P.Accent, 0.55)
				K.gradePunch(0.35, 0.05, 0.6, P.Accent)
				K.sfx(K.S.TonalHit, 0.5, 0.7 + i * 0.05)
				task.spawn(K.impact, SK.models(ctx), IMPACT[i], 0.045)
			end
			cue("whoosh" .. i, g >= P.G - 0.45, function() K.sfx(K.S.Whoosh, 0.7, 1.25) end)
		end
		-- camera: a new angle for each pane
		local k = 1
		while k < #E.Panes and g > E.Panes[k].G + 0.3 do k += 1 end
		if k ~= shot then shot = k cam.cut() end
		local P = E.Panes[k]
		local kind = SHOTS[k] or "side"
		-- (follow shots ride mostly on myBase, your fall line without the
		-- knockback, and aim at myPos, so a hit visibly throws you round the
		-- frame without flinging you out of it)
		myBase = myBase:Lerp(myPos, 0.35)
		local aim = myBase:Lerp(myPos, 0.6) -- (aim between: the jolt shows, the body stays in shot)
		if kind == "below" or kind == "final" then
			-- under the pane, looking up as they come smashing through at you
			local hit = F.at(P.G)
			local off = kind == "final" and 110 or 90
			local p = hit - P.CF.UpVector * off + SIDE * (kind == "final" and 130 or 110) + SK.DIRE * 20
			local lens = K.k(g, P.G - (kind == "final" and 2.2 or 1.2), P.G + 0.15, K.E.inQuad)
			cam.go(CFrame.lookAt(p, myPos), K.lerp(kind == "final" and 8 or 10, 72, lens), dt, 14)
		elseif kind == "chase" then
			-- above and behind you, dropping with you: the next pane rushing up below
			local p = myBase + UP * 26 - SK.DIRE * 12 + SIDE * 6
			cam.go(CFrame.lookAt(p, aim - UP * 22) * CFrame.Angles(0, 0, math.sin(t * 1.1) * 0.08), 72, dt, 11, myBase)
		elseif kind == "face" then
			-- skydiving cameraman: just below and in front of you, looking up into
			-- your face as you fall toward the lens (the hit flings you away from it)
			local p = myBase - UP * 12 + SIDE * 9 + SK.DIRE * 5
			cam.go(CFrame.lookAt(p, aim + UP * 1.5), 66, dt, 11, myBase)
		elseif kind == "orbit" then
			-- circling you as you fall
			local a = t * 0.9
			local p = myBase + Vector3.new(math.cos(a) * 20, 6, math.sin(a) * 20)
			cam.go(CFrame.lookAt(p, aim), 68, dt, 11, myBase)
		elseif kind == "side" then
			-- side on, falling alongside you
			local p = myBase + SIDE * 30 + UP * 4
			cam.go(CFrame.lookAt(p, aim), 64, dt, 11, myBase)
		elseif kind == "trail" then
			-- further out and trailing behind: the whole party tumbling down together
			local p = myBase + SIDE * 38 + UP * 20 - SK.DIRE * 22
			cam.go(CFrame.lookAt(p, aim - UP * 6), 58, dt, 10, myBase)
		else
			-- very wide: the whole stack of membranes waiting below
			local p = centre + Vector3.new(430, 170, -270)
			cam.go(CFrame.lookAt(p, centre - UP * 280), 52, dt, 5, centre)
		end
		K.shake(0.3, 0.1, 30, true)
		K.stream(centre)
	end)
end

------------------------------------------------------------------------
-- FLOAT: broken out of 4-D space into the Galaxy Realm. The fall bleeds
-- away to nothing and for a few seconds you're free: drift wherever you
-- like and look around at it all. (Everyone steers their own body on their
-- own screen; the rest of the party drifts on its own.) Then the realm
-- takes hold again and the fall carries on in DESCENT.
------------------------------------------------------------------------
local FLOAT_CONTROL = 2.0  -- when you get control (after the fall has bled off)
local FLOAT_PULL = 1.4     -- seconds at the end where the realm drags you back down
local FLOAT_SPEED = 32     -- top drifting speed (studs/s)
local FLOAT_RANGE = 160    -- how far you can drift from where you stopped

function Ch.Float(ctx, t0, dur)
	local K = ctx.kit
	local E = ctx.Entry
	local F, G = SK.fall(ctx)
	local UIS = game:GetService("UserInputService")
	local cam0 = workspace.CurrentCamera
	ctx.sets.Entry.Parent = ctx.stage
	if ctx.restoreArena then ctx.restoreArena() end
	ctx.hideBoss(true)
	if ctx.sets.Arena then ctx.sets.Arena.Parent = ctx.stage end
	if ctx.Boss then ctx.Boss.Parent = nil end -- (he hasn't risen yet)
	for _, q in ipairs(ctx.LapisAura or {}) do q.Transparency = K.ns(1) end
	if ctx.LapisSparkle then ctx.LapisSparkle.Rate = 0 end
	if ctx.LapisLight then ctx.LapisLight.Brightness = 0 end
	K.lighting("Arena", 0)
	K.Blur.Enabled = false
	K.DOF.Enabled = false
	E.leave()
	E.setLayer(#PAL)
	E.Dust.Rate = 40
	for _, s in ipairs(E.Streaks) do s.B.Enabled = false end
	E.Trail.Enabled = false
	E.vortex(0, 0)
	K.fade(0, 0.2)

	-- where the fall stops: the exit of the last membrane, and how fast they were going
	local gx = G.Descent
	local v0 = F.vel(gx)
	local DECEL = 2.2
	local carry = v0 / DECEL -- how far the fall carries them before it's gone
	local stop = {}
	local startRot = {}
	for slot in pairs(ctx.rigs) do
		local koff, krot = knockAt(ctx, slot, gx)
		stop[slot] = airPos(ctx, F, slot, gx) + koff
		startRot[slot] = krot * spinCF(slot, gx)
		ctx.rigs[slot].Smooth = 14
	end
	local function scripted(slot, t)
		local decel = 1 - math.exp(-DECEL * t)
		local spread = SK.offset(ctx, slot, 9) * 0.9 * SK.s(t, 0, 4)
		local bob = Vector3.new(math.sin(t * 0.37 + slot) * 3, math.sin(t * 0.8 + slot * 1.9) * 1.6, math.cos(t * 0.29 + slot) * 3)
		local pull = t > dur - FLOAT_PULL and -UP * 90 * ((t - (dur - FLOAT_PULL)) / FLOAT_PULL) ^ 2 or Vector3.zero
		return stop[slot] + carry * decel + spread + bob * SK.s(t, 1, 3) + pull
	end

	-- your own drifting
	local me = ctx.myRig
	local myPos, myVel, home
	local yaw, pitch, dist = 0, -0.25, 20
	local faceYaw = 0
	local lookDelta = Vector2.zero
	local zoomDelta = 0
	local rmb = false
	local touches = {} -- [InputObject] = { Side = "move"|"look", Start = Vector3 }
	local touchMove = Vector2.zero
	local conns = {}
	table.insert(conns, UIS.InputBegan:Connect(function(io, gp)
		if io.UserInputType == Enum.UserInputType.MouseButton2 then
			rmb = true
			UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif io.UserInputType == Enum.UserInputType.Touch and not gp then
			local left = io.Position.X < cam0.ViewportSize.X * 0.5
			touches[io] = { Side = left and "move" or "look", Start = io.Position, Last = io.Position }
		end
	end))
	table.insert(conns, UIS.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton2 then
			rmb = false
			UIS.MouseBehavior = Enum.MouseBehavior.Default
		elseif touches[io] then
			if touches[io].Side == "move" then touchMove = Vector2.zero end
			touches[io] = nil
		end
	end))
	table.insert(conns, UIS.InputChanged:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseMovement and rmb then
			lookDelta += Vector2.new(io.Delta.X, io.Delta.Y)
		elseif io.UserInputType == Enum.UserInputType.MouseWheel then
			zoomDelta -= io.Position.Z
		elseif touches[io] then
			local tc = touches[io]
			if tc.Side == "look" then
				lookDelta += Vector2.new(io.Position.X - tc.Last.X, io.Position.Y - tc.Last.Y)
			else
				local d = Vector2.new(io.Position.X - tc.Start.X, io.Position.Y - tc.Start.Y)
				touchMove = d.Magnitude > 8 and (d / math.max(d.Magnitude, 60)) or Vector2.zero
			end
			tc.Last = io.Position
		end
	end))

	-- the prompt
	local isTouch = UIS.TouchEnabled and not UIS.KeyboardEnabled
	-- (in the game's own UI style: chunky black outlines, rounded gradient
	-- panels, a pill title and Inconsolata Bold with black strokes)
	local UI_FONT = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)
	local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(0, 20) c.Parent = p return c end
	local function stroke(p, color, th) local st = Instance.new("UIStroke") st.Color = color or Color3.new(0, 0, 0) st.Thickness = th or 5 st.Parent = p return st end
	local function grad(p, c0, c1) local g = Instance.new("UIGradient") g.Color = ColorSequence.new(c0, c1) g.Rotation = -90 g.Parent = p return g end
	local function label(parent, props)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.FontFace = UI_FONT
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		for k, v in pairs(props) do if k ~= "StrokeColor" and k ~= "StrokeTh" then l[k] = v end end
		l.Parent = parent
		stroke(l, props.StrokeColor or Color3.new(0, 0, 0), props.StrokeTh or 2)
		return l
	end
	local hint = Instance.new("CanvasGroup")
	hint.Name = "FloatHint"
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 0.86, 0)
	hint.Size = UDim2.fromOffset(800, 160)
	hint.GroupTransparency = 1
	hint.ZIndex = 90
	local hintScale = Instance.new("UIScale")
	hintScale.Parent = hint
	local vp0 = cam0.ViewportSize
	local baseScale = math.clamp(math.min(vp0.X / 1280, vp0.Y / 720) * 0.85, 0.45, 1.15)
	hintScale.Scale = baseScale
	-- the panel
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -8)
	panel.Size = UDim2.fromOffset(780, 92)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.ZIndex = 91
	panel.Parent = hint
	corner(panel, UDim.new(0, 24))
	stroke(panel, Color3.new(0, 0, 0), 5)
	grad(panel, Color3.fromRGB(148, 142, 153), Color3.fromRGB(46, 20, 55))
	-- the title pill, riding the top edge
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.new(0.5, 0, 1, -100)
	pill.Size = UDim2.fromOffset(250, 50)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.ZIndex = 93
	pill.Parent = hint
	corner(pill, UDim.new(0, 60))
	stroke(pill, Color3.new(0, 0, 0), 5)
	grad(pill, Color3.fromRGB(196, 150, 255), Color3.fromRGB(86, 44, 176))
	label(pill, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.82, 0.62), TextColor3 = Color3.new(0, 0, 0), Text = "FLOAT FREE", ZIndex = 94, StrokeColor = Color3.new(1, 1, 1), StrokeTh = 3 })
	-- the controls, as key chips
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.new(0.5, 0, 0.5, 8)
	row.Size = UDim2.new(1, -30, 0, 44)
	row.ZIndex = 92
	row.Parent = panel
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Horizontal
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lay.VerticalAlignment = Enum.VerticalAlignment.Center
	lay.Padding = UDim.new(0, 26)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = row
	local chips = isTouch and { { "LEFT SIDE", "DRIFT" }, { "RIGHT SIDE", "LOOK AROUND" } }
		or { { "WASD", "DRIFT" }, { "SPACE / SHIFT", "UP / DOWN" }, { "RIGHT-CLICK", "LOOK" } }
	for i, c in ipairs(chips) do
		local kw = 22 + #c[1] * 11
		local aw = 10 + #c[2] * 11
		local chip = Instance.new("Frame")
		chip.BackgroundTransparency = 1
		chip.Size = UDim2.fromOffset(kw + 10 + aw, 44)
		chip.LayoutOrder = i
		chip.ZIndex = 92
		chip.Parent = row
		local key = Instance.new("Frame")
		key.Position = UDim2.fromOffset(0, 4)
		key.Size = UDim2.fromOffset(kw, 36)
		key.BackgroundColor3 = Color3.new(1, 1, 1)
		key.ZIndex = 93
		key.Parent = chip
		corner(key, UDim.new(0, 10))
		stroke(key, Color3.new(0, 0, 0), 3)
		grad(key, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 160, 190))
		label(key, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -12, 0, 22), TextColor3 = Color3.new(0, 0, 0), Text = c[1], ZIndex = 94, StrokeColor = Color3.new(1, 1, 1), StrokeTh = 1 })
		label(chip, { Position = UDim2.fromOffset(kw + 10, 9), Size = UDim2.fromOffset(aw, 26), TextXAlignment = Enum.TextXAlignment.Left, Text = c[2], ZIndex = 93, StrokeTh = 2 })
	end
	hint.Parent = K.Gui

	local cue = K.once()
	local cam = SK.camera(K)
	local shot = 0
	local ok = pcall(function()
	SK.run(K, t0, dur, function(t, dt)
		local pullOn = t > dur - FLOAT_PULL
		local settle = SK.s(t, 0, 2.6)
		for slot, rig in pairs(ctx.rigs) do
			local p
			if rig == me and myPos then
				p = myPos
			else
				p = scripted(slot, t)
			end
			-- tumbling slows and they right themselves into a lazy float
			local ownYaw = (rig == me and myPos) and faceYaw or (slot * 0.9 + t * 0.12 * (slot % 2 == 0 and 1 or -1))
			local lean = (rig == me and myVel) and math.clamp(myVel.Magnitude / FLOAT_SPEED, 0, 1) * 0.35 or 0
			local upright = CFrame.Angles(0, ownYaw, 0) * CFrame.Angles(-lean + math.sin(t * 0.6 + slot) * 0.06, 0, math.sin(t * 0.45 + slot) * 0.08)
			local rot = startRot[slot]:Lerp(upright, settle)
			if pullOn then rot = rot:Lerp(CFrame.Angles(0, ownYaw, 0) * CFrame.Angles(-0.5, 0, 0), SK.s(t, dur - FLOAT_PULL, dur)) end
			rig:setCF(CFrame.new(p) * rot)
			local drift = K.safeArms(K.mixPose(K.Poses.Float, K.zeroGPose(t * 1.1, slot, 1), 0.55))
			local pose = K.mixPose(SK.tumble(K, (gx + t) * 1.4, slot, 0.6), drift, settle)
			if pullOn then pose = K.mixPose(pose, K.Poses.Blown, SK.s(t, dur - FLOAT_PULL, dur) * 0.7) end
			rig:setPose(pose)
			rig:apply()
		end

		-- your drift: yours to steer from FLOAT_CONTROL until the realm pulls you down
		if me and t >= FLOAT_CONTROL and not myPos then
			myPos = scripted(ctx.me, t)
			home = myPos
			myVel = Vector3.zero
			-- take over the camera from where the intro left it
			if cam.CF then
				local off = cam.CF.Position - myPos
				yaw = math.atan2(off.X, off.Z)
				pitch = -math.asin(math.clamp(off.Unit.Y, -0.95, 0.95))
				dist = math.clamp(off.Magnitude, 12, 40)
			end
			faceYaw = yaw + math.pi
		end
		local centre = scripted(ctx.me or 1, t)
		if myPos then
			-- look
			local pad = Vector2.zero
			local moveIn = Vector3.zero
			pcall(function()
				for _, st in ipairs(UIS:GetGamepadState(Enum.UserInputType.Gamepad1)) do
					if st.KeyCode == Enum.KeyCode.Thumbstick2 and st.Position.Magnitude > 0.15 then pad = Vector2.new(st.Position.X, -st.Position.Y) end
					if st.KeyCode == Enum.KeyCode.Thumbstick1 and st.Position.Magnitude > 0.15 then moveIn += Vector3.new(st.Position.X, 0, -st.Position.Y) end
					if st.KeyCode == Enum.KeyCode.ButtonR2 and st.Position.Z > 0.2 then moveIn += Vector3.new(0, 1, 0) end
					if st.KeyCode == Enum.KeyCode.ButtonL2 and st.Position.Z > 0.2 then moveIn -= Vector3.new(0, 1, 0) end
				end
			end)
			yaw -= (lookDelta.X * 0.006 + pad.X * dt * 2.6)
			pitch = math.clamp(pitch - (lookDelta.Y * 0.006 + pad.Y * dt * 2.2), -1.35, 1.35)
			lookDelta = Vector2.zero
			dist = math.clamp(dist + zoomDelta * 2.5, 10, 45)
			zoomDelta = 0
			-- move (relative to where you're looking)
			if not UIS:GetFocusedTextBox() then
				if UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Up) then moveIn += Vector3.new(0, 0, -1) end
				if UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.Down) then moveIn += Vector3.new(0, 0, 1) end
				if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then moveIn += Vector3.new(-1, 0, 0) end
				if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then moveIn += Vector3.new(1, 0, 0) end
				if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then moveIn += Vector3.new(0, 1, 0) end
				if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then moveIn -= Vector3.new(0, 1, 0) end
			end
			moveIn += Vector3.new(touchMove.X, 0, touchMove.Y)
			local view = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
			-- forward is where the camera looks (so looking down and pushing W dives)
			local fwd = view.LookVector
			local right = fwd:Cross(UP)
			right = right.Magnitude > 0.01 and right.Unit or Vector3.xAxis
			local want = fwd * -moveIn.Z + right * moveIn.X + UP * moveIn.Y
			if want.Magnitude > 1 then want = want.Unit end
			if pullOn then want = Vector3.zero end
			myVel = myVel:Lerp(want * FLOAT_SPEED, 1 - math.exp(-2.4 * dt))
			-- a soft leash back toward where you stopped
			local away = myPos - home
			if away.Magnitude > FLOAT_RANGE then myVel -= away.Unit * (away.Magnitude - FLOAT_RANGE) * 3 * dt end
			myPos += myVel * dt
			if pullOn then
				local u = (t - (dur - FLOAT_PULL)) / FLOAT_PULL
				myPos -= UP * 130 * u * dt * 2
			end
			-- turn to face where you're drifting (or where you're looking)
			local flat = Vector3.new(myVel.X, 0, myVel.Z)
			local targetYaw = flat.Magnitude > 3 and math.atan2(-flat.X, -flat.Z) or faceYaw
			local dy = (targetYaw - faceYaw + math.pi) % (2 * math.pi) - math.pi
			faceYaw += dy * (1 - math.exp(-3 * dt))
			-- orbit camera round you
			local focus = myPos + UP * 1.5
			local cp = focus + view:VectorToWorldSpace(Vector3.new(0, 0, dist))
			if shot ~= 3 then shot = 3 end
			cam.go(CFrame.lookAt(cp, focus), 70, dt, 18, myPos)
			centre = myPos
		else
			-- the intro: out of the last membrane, the fall bleeding away, the realm opening up below
			local mine = ctx.me and scripted(ctx.me, t) or centre
			if t < 1.1 then
				if shot ~= 1 then shot = 1 cam.cut() end
				-- below, looking up as they burst out of the membrane and slow
				local p = stop[ctx.me or 1] + carry * 1.05 + SIDE * 26 - UP * 30
				cam.go(CFrame.lookAt(p, mine), 62, dt, 10)
			else
				if shot ~= 2 then shot = 2 cam.cut() end
				-- swinging round behind you as you come to rest, the realm spread out ahead
				local e = K.k(t, 1.1, FLOAT_CONTROL, K.E.outSine)
				local a = K.lerp(0.6, 0, e)
				local p = mine + Vector3.new(math.sin(a) * 18, K.lerp(4, 6, e), math.cos(a) * 18)
				cam.go(CFrame.lookAt(p, mine + UP * 1.5), 70, dt, 6, mine)
			end
		end
		E.follow(centre, gx, t, 0, K.Cam.CF.Position)

		-- the prompt fades in with control and out before the pull
		local hintA = K.k(t, FLOAT_CONTROL, FLOAT_CONTROL + 0.6) * (1 - K.k(t, dur - FLOAT_PULL - 1.6, dur - FLOAT_PULL - 0.8))
		hint.GroupTransparency = 1 - hintA
		hintScale.Scale = baseScale * (0.92 + 0.08 * K.E.outBack(math.clamp(hintA, 0, 1)))

		cue("out", t >= 0, function()
			K.flash(0.6, Color3.fromRGB(235, 220, 255), 0.55)
			K.sfx(K.S.Whoosh, 0.8, 0.6, { Reverb = 3 })
			if ctx.EntryWind then K.fadeSound(ctx.EntryWind, 0.12, 2) end
			ctx.setMusic(K.S.M_Astral, 0.5, 2.5)
		end)
		cue("calm", t >= 1.2, function() K.sfx(K.S.Choir, 0.35, 1) end)
		cue("pull", t >= dur - FLOAT_PULL, function()
			K.sfx(K.S.DarkDrone, 0.7, 0.9)
			K.sfx(K.S.Whoosh, 0.9, 0.55, { Reverb = 3 })
			K.shake(1, FLOAT_PULL)
			ctx.fadeMusic(0.2, FLOAT_PULL)
			if ctx.EntryWind then K.fadeSound(ctx.EntryWind, 0.7, FLOAT_PULL) end
		end)
		K.stream(centre)
	end)
	end)
	for _, c in ipairs(conns) do c:Disconnect() end
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	hint:Destroy()
	for _, s in ipairs(E.Streaks) do s.B.Enabled = true end
	ctx.Knocks = {} -- (the last hits are long over; DESCENT starts clean)
	if not ok then warn("[FinalCutscene] Float failed") end
end

------------------------------------------------------------------------
-- DESCENT: out of the float... then a hard cut to HIM, charging at them
-- across a floor of his own violet power, every footfall a quake. He
-- plants, crouches and leaps clean out of the frame - and then there's
-- nothing, just you, falling... until his hand comes out of nowhere (CATCH).
------------------------------------------------------------------------
local RUN = {
	From = 1.6,     -- the hard cut to him
	Plant = 8.3,    -- the right foot slams down for the jump-stop (the left a beat later)
	Leap = 8.75,    -- and up he goes
	Gone = 9.5,     -- (cut back to the party)
	Cycle = 1.4,    -- seconds for a left + right stride (slow: he's enormous)
	Stance = 0.34,  -- share of the cycle each foot is on the ground
	Speed = 600,    -- studs/s
	EndBack = 900,  -- how far behind his home he leaps from
	Lift = 190,     -- how high a foot comes up
	Floor = -200,   -- the height of the floor of power he runs on
}
local VIOLET = Color3.fromRGB(160, 70, 255)
local VIOLET_HOT = Color3.fromRGB(232, 190, 255)
local VIOLET_DEEP = Color3.fromRGB(72, 22, 150)
local SWING = 0.55 -- the snatch itself (CATCH)

-- the charge starts as slow, heavy stomps and builds into the full sprint:
-- cadence, stride length and stance all ramp up (tabulated, so every foot
-- still lands exactly where it's planted and the right foot hits the plant)
local RAMP = 3.2
local function ramp(t) local x = math.clamp((t - RUN.From) / RAMP, 0, 1) return x * x * (3 - 2 * x) end
local function cadence(t) return 1 / 2.5 + (1 / RUN.Cycle - 1 / 2.5) * ramp(t) end
local function strideLen(t) return RUN.Speed * RUN.Cycle * (0.5 + 0.5 * ramp(t)) end
local function stanceAt(t) return 0.46 + (RUN.Stance - 0.46) * ramp(t) end
local TAB_DT = 0.01
local PHI, DIST = {}, {}
local TABN = math.floor(RUN.Plant / TAB_DT + 0.5)
do
	local cum = { [0] = 0 }
	PHI[0] = 0
	local phi, dist = 0, 0
	for i = 1, TABN do
		local tm = (i - 0.5) * TAB_DT
		phi += cadence(tm) * TAB_DT
		dist += cadence(tm) * strideLen(tm) * TAB_DT
		PHI[i] = phi
		cum[i] = dist
	end
	local off = math.ceil(PHI[TABN]) - PHI[TABN]
	for i = 0, TABN do
		PHI[i] += off
		DIST[i] = RUN.EndBack + (cum[TABN] - cum[i])
	end
end
local function tabAt(T, t)
	local x = t / TAB_DT
	local i = math.clamp(math.floor(x), 0, TABN - 1)
	local f = x - i
	return T[i] + (T[i + 1] - T[i]) * f
end
local function gait(t)
	if t >= RUN.Plant then return PHI[TABN] + (t - RUN.Plant) / RUN.Cycle end
	if t <= 0 then return PHI[0] + t * cadence(0) end
	return tabAt(PHI, t)
end
-- the moment the gait reaches phase p
local function phaseTime(p)
	if p >= PHI[TABN] then return RUN.Plant + (p - PHI[TABN]) * RUN.Cycle end
	if p <= PHI[0] then return (p - PHI[0]) / cadence(0) end
	local lo, hi = 0, TABN
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if PHI[mid] <= p then lo = mid else hi = mid end
	end
	return (lo + (p - PHI[lo]) / (PHI[hi] - PHI[lo])) * TAB_DT
end
local function stepTime(n, o) return phaseTime(n + o) end

-- how far back from his home he is, along his run
local function runDist(t)
	if t <= RUN.Plant then
		if t <= 0 then return DIST[0] - t * cadence(0) * strideLen(0) end
		return tabAt(DIST, t)
	end
	-- the jump-stop: his momentum bleeds off into the crouch...
	local u = math.min(t - RUN.Plant, 0.45)
	local d = RUN.EndBack - RUN.Speed * (u - u * u / 0.9)
	-- ...then the leap carries him on
	if t > RUN.Leap then d -= 700 * (t - RUN.Leap) end
	return d
end

------------------------------------------------------------------------
-- his legs: a two-bone solve per leg so every planted foot really stays
-- planted on the floor (no skating), knees forward, feet rolling heel-toe
------------------------------------------------------------------------
local function aimRot(localA, localRef, worldA, worldRef)
	local la = localA.Unit
	local lr = localRef - la * localRef:Dot(la)
	lr = lr.Magnitude > 1e-3 and lr.Unit or la:Cross(Vector3.xAxis).Unit
	local lc = la:Cross(lr)
	local wa = worldA.Unit
	local wr = worldRef - wa * worldRef:Dot(wa)
	wr = wr.Magnitude > 1e-3 and wr.Unit or wa:Cross(Vector3.yAxis).Unit
	local wc = wa:Cross(wr)
	return CFrame.fromMatrix(Vector3.zero, wa, wr, wc) * CFrame.fromMatrix(Vector3.zero, la, lr, lc):Inverse()
end

local function chargeLegs(ctx, SB)
	if ctx.ChargeLegs then return ctx.ChargeLegs end
	local R = SB.R
	local home = ctx.BossHome
	SB.reset()
	local lt = R.cf("LowerTorso", home)
	local L = { Home = home }
	for _, side in ipairs({ "Right", "Left" }) do
		local hip = R.joint(side .. "Hip", side .. "UpperLeg")
		local knee = R.joint(side .. "Knee", side .. "LowerLeg")
		local ankle = R.joint(side .. "Ankle", side .. "Foot")
		if not (hip and knee and ankle) then return nil end
		local hb, kb, ab = R.B[hip], R.B[knee], R.B[ankle]
		local g = { Hip = hip, Knee = knee, Ankle = ankle, HB = hb, KB = kb, AB = ab }
		g.sJ, g.eJ, g.eL, g.wL = hb.C1.Position, kb.C0.Position, kb.C1.Position, ab.C0.Position
		g.Lu, g.Ll = (g.eJ - g.sJ).Magnitude, (g.wL - g.eL).Magnitude
		local ul = lt * hb.C0 * hb.C1:Inverse()
		local ll = ul * kb.C0 * kb.C1:Inverse()
		local ft = ll * ab.C0 * ab.C1:Inverse()
		local hipW = (lt * CFrame.new(hb.C0.Position)).Position
		local ankW = ll:PointToWorldSpace(g.wL)
		local foot = ctx.Boss:FindFirstChild(side .. "Foot")
		g.AnkleH = ankW.Y - (ft.Position.Y - (foot and foot.Size.Y or 40) / 2)
		g.HipRel = home:PointToObjectSpace(hipW)
		g.AnkRel = home:PointToObjectSpace(ankW)
		g.FootRel = home.Rotation:Inverse() * ft.Rotation
		g.ToeRel = home:VectorToObjectSpace(ft.Position - ankW)
		-- (each segment's own "forward", so the knee bends the right way whatever the rig)
		g.FwdU = ul:VectorToObjectSpace(home.LookVector)
		g.FwdL = ll:VectorToObjectSpace(home.LookVector)
		g.Reach = math.min(g.Lu + g.Ll, (hipW - ankW).Magnitude + 2)
		L[side] = g
	end
	L.AnkleH = L.Right.AnkleH
	L.HipY = L.Right.HipRel.Y
	-- the hip height over the ankle at which a planted foot is just reachable at
	-- the start and end of its stance
	local half = RUN.Speed * RUN.Stance * RUN.Cycle / 2
	local reach = math.min(L.Right.Reach, L.Left.Reach) * 0.975
	L.H = math.sqrt(math.max(reach * reach - half * half, (reach * 0.6) ^ 2))
	ctx.ChargeLegs = L
	return L
end

local function solveLeg(g, lt, target, pole, footRot)
	local sW = (lt * CFrame.new(g.HB.C0.Position)).Position
	local toT = target - sW
	local d = math.clamp(toT.Magnitude, math.abs(g.Lu - g.Ll) + 1, g.Lu + g.Ll - 0.5)
	local dir = toT.Magnitude > 1e-3 and toT.Unit or -Vector3.yAxis
	local a = (g.Lu * g.Lu - g.Ll * g.Ll + d * d) / (2 * d)
	local h = math.sqrt(math.max(g.Lu * g.Lu - a * a, 0))
	local bend = pole - dir * pole:Dot(dir)
	bend = bend.Magnitude > 1e-3 and bend.Unit or dir:Cross(Vector3.xAxis).Unit
	local eW = sW + dir * a + bend * h
	local wW = sW + dir * d
	local Rul = aimRot(g.eJ - g.sJ, g.FwdU, eW - sW, bend)
	local ulCF = CFrame.new(sW - Rul * g.sJ) * Rul
	local Rll = aimRot(g.wL - g.eL, g.FwdL, wW - eW, bend)
	local llCF = CFrame.new(eW - Rll * g.eL) * Rll
	-- (each motor keeps its joint where it is; only the rotation changes)
	g.Hip.C0 = CFrame.new(g.HB.C0.Position) * (lt:Inverse() * ulCF * g.HB.C1).Rotation
	g.Knee.C0 = CFrame.new(g.KB.C0.Position) * (ulCF:Inverse() * llCF * g.KB.C1).Rotation
	g.Ankle.C0 = CFrame.new(g.AB.C0.Position) * (llCF.Rotation:Inverse() * footRot * g.AB.C1.Rotation)
	return wW
end

-- the ground under a foot (at its ankle), D back from his home along the run
local function footGround(L, side, D)
	local home = L.Home
	local g = L[side]
	return Vector3.new(home.X, RUN.Floor, home.Z) - home.LookVector * D + home.Rotation * Vector3.new(g.AnkRel.X, 0, g.AnkRel.Z)
end
-- where the n'th footfall of a foot lands (the ground under his hip at mid-stance)
local function plantAt(L, side, n)
	local o = side == "Right" and 0 or 0.5
	return footGround(L, side, runDist(phaseTime(n + o + stanceAt(stepTime(n, o)) / 2)))
end
-- the middle of a footprint (for the effects)
local function printAt(L, side, ground)
	local g = L[side]
	return ground + L.Home.Rotation * Vector3.new(g.ToeRel.X, 0, g.ToeRel.Z)
end

-- a foot's ankle target and pitch while running (no plant / leap)
local function strideFoot(ctx, L, side, t)
	local K = ctx.kit
	local o = side == "Right" and 0 or 0.5
	local p = gait(t) - o
	local n = math.floor(p)
	local u = p - n
	local ah = UP * L[side].AnkleH
	local S = stanceAt(stepTime(n, o))
	if u < S then
		-- planted: heel down flat, rolling up onto the toes to push off
		local pitch = K.lerp(12, 0, K.k(u, 0, 0.05)) - 22 * K.k(u, S * 0.6, S)
		return plantAt(L, side, n) + ah, pitch
	end
	-- swinging through: heel kicks up behind, knee drives forward, toes up for the strike
	local w = (u - S) / (1 - S)
	local a, b = plantAt(L, side, n), plantAt(L, side, n + 1)
	local pos = a:Lerp(b, K.E.inOutSine(w)) + UP * RUN.Lift * (0.55 + 0.45 * ramp(t)) * math.sin(math.pi * w ^ 0.8)
	local pitch = K.lerp(-22, -40, K.k(w, 0, 0.25)) + K.k(w, 0.25, 1) * 52
	return pos + ah, pitch
end

-- poses his whole body for time t of the charge; returns his root CFrame
local function chargeBody(ctx, SB, L, t)
	local K = ctx.kit
	local home = L.Home
	local look, right = home.LookVector, home.RightVector
	local cyc = gait(t)
	local ph = 2 * math.pi * cyc
	local c = math.cos(ph)
	local run = 1 - K.k(t, RUN.Plant - 0.12, RUN.Plant + 0.12)
	local pace = 0.45 + 0.55 * ramp(t)
	local bob = math.cos(2 * math.pi * 2 * (cyc - stanceAt(t) / 2)) * run * pace
	local crouch = K.k(t, RUN.Plant, RUN.Leap - 0.05, K.E.outCubic) * (1 - K.k(t, RUN.Leap - 0.05, RUN.Leap + 0.12, K.E.outQuad))
	local air = math.max(t - RUN.Leap, 0)
	local up = K.k(t, RUN.Leap - 0.08, RUN.Leap + 0.3, K.E.outCubic)
	-- the body: low at mid-stance, high in the flight between steps, dropping into the crouch
	local hip2ank = L.H * (0.95 - 0.05 * bob) * (1 - 0.26 * crouch)
	local sway = 10 * math.cos(2 * math.pi * (cyc - RUN.Stance / 2)) * run
	local D = runDist(t)
	local ground = Vector3.new(home.X, RUN.Floor, home.Z) - look * D
	local y = RUN.Floor + L.AnkleH + hip2ank - L.HipY + 1500 * air - 420 * air * air
	local pos = Vector3.new(ground.X, y, ground.Z) + right * sway
	local lean = (4 + 7 * pace + 2 * bob) * run + crouch * 20 + up * 10
	local yaw = 7 * c * run
	local roll = 3 * math.cos(2 * math.pi * (cyc - RUN.Stance / 2)) * run
	local rootCF = CFrame.new(pos) * home.Rotation * CFrame.Angles(-math.rad(lean), math.rad(yaw), math.rad(roll))
	ctx.BossRoot.CFrame = rootCF

	SB.reset()
	-- arms pumping against the legs; flung back for the crouch, thrown up for the leap
	local sw = 38 * run * pace
	SB.body({
		Waist = K.A(-4 + 2 * bob - crouch * 8 + up * 12, -1.6 * yaw, 0),
		Neck = K.A(lean * 0.7 + 4 - up * 14, yaw * 0.6, 0),
		RightShoulder = K.A(K.lerp(12 - sw * c - crouch * 50, 155, up), 0, 14 + up * 18),
		LeftShoulder = K.A(K.lerp(12 + sw * c - crouch * 50, 155, up), 0, -14 - up * 18),
		RightElbow = K.A(K.lerp(70 - 20 * c * run, 18, up), 0, 0),
		LeftElbow = K.A(K.lerp(70 + 20 * c * run, 18, up), 0, 0),
	})
	SK.hang(SB, "Right", K.lerp(0.78, 0.25, up), 0.05)
	SK.hang(SB, "Left", K.lerp(0.78, 0.25, up), 0.05)

	-- legs
	local lt = SB.R.cf("LowerTorso", rootCF)
	local plantR = plantAt(L, "Right", math.floor(gait(RUN.Plant) + 1e-4))
	for _, side in ipairs({ "Right", "Left" }) do
		local g = L[side]
		local target, pitch = strideFoot(ctx, L, side, math.min(t, RUN.Plant))
		if t >= RUN.Plant then
			if side == "Right" then
				target, pitch = plantR + UP * g.AnkleH, 0
			else
				-- the left foot slams down beside it a beat later: the jump-stop
				local q = K.k(t, RUN.Plant, RUN.Plant + 0.14, K.E.inQuad)
				local spot = footGround(L, "Left", runDist(RUN.Plant + RUN.Stance * RUN.Cycle / 2)) + UP * g.AnkleH
				target = target:Lerp(spot, q)
				pitch = K.lerp(pitch, 0, q)
			end
			if air > 0 then
				-- off the floor: feet tucked up under him
				local hipW = rootCF:PointToWorldSpace(g.HipRel)
				local tuck = hipW + rootCF:VectorToWorldSpace(Vector3.new(0, -0.62, 0.32)) * g.Reach
				local b = K.k(air, 0, 0.2, K.E.outQuad)
				target = target:Lerp(tuck, b)
				pitch = K.lerp(pitch, -35, b)
			end
		end
		local footRot = home.Rotation * CFrame.Angles(math.rad(pitch), 0, 0) * g.FootRel
		solveLeg(g, lt, target, look + right * (side == "Right" and 0.15 or -0.15), footRot)
	end
	return rootCF
end

------------------------------------------------------------------------
-- his power, underfoot: no floor at all - each step creates a mass of violet
-- space right where the foot comes down, with a blast as it lands
------------------------------------------------------------------------
local function buildCharge(ctx)
	if ctx.Charge then return ctx.Charge end
	local K = ctx.kit
	local home = ctx.BossHome
	if not home then return nil end
	local C = { Steps = {}, Next = 1, Pads = {} }
	local set = Instance.new("Folder")
	set.Name = "ChargeSet"
	C.Set = set
	local base = Vector3.new(home.X, RUN.Floor, home.Z)
	local wh = K.part({ Name = "WakeHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(base) }, set)
	C.WakeHost = wh
	C.Wake = K.emitter(wh, { Rate = 0 })
	-- the masses of his power: there's no floor until a foot comes down - then a
	-- chunk of violet space boils into being right under it (a glowing core, a
	-- shimmering skin, clouds of nebula and stars), and burns away once it lifts
	local PAD_R = 125 -- (a little galaxy arena, much smaller than the real one)
	for i = 1, 8 do
		local host = K.part({ Name = "PadHost", Size = Vector3.new(2 * PAD_R, 1, 2 * PAD_R), Transparency = 1, CFrame = CFrame.new(base) }, set)
		-- the disc itself: dark violet, like the fight arena's floor
		local disc = K.part({ Name = "PadDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 2 * PAD_R, 2 * PAD_R), Material = Enum.Material.Neon, Color = Color3.fromRGB(34, 12, 66), Transparency = 1, CFrame = CFrame.new(base) }, set)
		-- its galaxy: a spiral of violet light turning slowly across it
		local swirl = K.quad(host, CFrame.lookAt(base, base + UP), 2 * PAD_R, 2 * PAD_R, "14426232568", { Color = Color3.fromRGB(185, 110, 255), Brightness = 2.2, Transparency = 0.15 })
		local swirl2 = K.quad(host, CFrame.lookAt(base, base + UP), 1.3 * PAD_R, 1.3 * PAD_R, "124165682553877", { Color = Color3.fromRGB(235, 200, 255), Brightness = 1.6, Transparency = 0.35 })
		swirl.Enabled, swirl2.Enabled = false, false
		-- its rim: a thin bright ring, like the arena's glowing edge
		local rim = K.softRing(host, 40, PAD_R - 6, PAD_R + 6, { Brightness = 5, Alpha = 0 })
		for _, q in ipairs(rim.Q) do q.Color = ColorSequence.new(Color3.fromRGB(245, 225, 255), VIOLET) end
		rim.setTransparency(0.99)
		-- motes of light drifting up off it (the arena's own glow motes, in violet)
		local motes = K.emitter(host, {
			Texture = "14582794847", Color = ColorSequence.new(Color3.fromRGB(215, 150, 255), Color3.fromRGB(150, 70, 255)),
			Size = K.ns(0, 0, 0.15, 7, 0.8, 5, 1, 0), Lifetime = NumberRange.new(1.6, 3), Speed = NumberRange.new(6, 30),
			SpreadAngle = Vector2.new(20, 20), Brightness = 5, Shape = Enum.ParticleEmitterShape.Box, Acceleration = Vector3.new(0, 12, 0),
		})
		local stars = K.emitter(host, {
			Texture = "1851669703", Color = ColorSequence.new(Color3.new(1, 1, 1), VIOLET_HOT), Size = K.ns(0, 0, 0.2, 30, 1, 0),
			Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(30, 160), SpreadAngle = Vector2.new(70, 70),
			Brightness = 6, Shape = Enum.ParticleEmitterShape.Box, Acceleration = Vector3.new(0, 30, 0),
		})
		local cloud = K.emitter(host, {
			Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(200, 130, 255), Color3.fromRGB(100, 45, 200)),
			Size = K.ns(0, 80, 1, 260), Transparency = K.ns(0, 0.45, 0.6, 0.65, 1, 1), Lifetime = NumberRange.new(0.9, 1.5),
			Speed = NumberRange.new(10, 60), SpreadAngle = Vector2.new(60, 60), LightEmission = 1,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30), Shape = Enum.ParticleEmitterShape.Box,
		})
		-- its inlay: dotted arms of light spiralling in, like the arena's own
		local inlay = {}
		for arm = 1, 3 do
			for seg = 1, 8 do
				local b = K.ray(host, base, base + UP, 6, 6, "14582794847", { Color = Color3.fromRGB(230, 200, 255), Brightness = 5, Transparency = 0.1, Segments = 1, Mode = Enum.TextureMode.Wrap, Length = 7 })
				b.Enabled = false
				table.insert(inlay, { B = b, Arm = arm, Seg = seg })
			end
		end
		for seg = 1, 16 do
			local b = K.ray(host, base, base + UP, 5, 5, "14582794847", { Color = Color3.fromRGB(200, 160, 255), Brightness = 4, Transparency = 0.2, Segments = 1, Mode = Enum.TextureMode.Wrap, Length = 7 })
			b.Enabled = false
			table.insert(inlay, { B = b, Ring = seg })
		end
		table.insert(C.Pads, { Host = host, Disc = disc, Swirl = swirl, Swirl2 = swirl2, Rim = rim, Motes = motes, Stars = stars, Cloud = cloud, Inlay = inlay, Spin = math.random() * 6 })
	end
	local live = {} -- footfall key -> its pad
	-- a footfall's mass: f 0..1 = how far it has formed (it never un-forms)
	function C.form(key, pos, f)
		local P = live[key]
		if not P then
			for _, q in ipairs(C.Pads) do if not q.Key then P = q break end end
			if not P then
				for _, q in ipairs(C.Pads) do if q.Gone and (not P or q.Gone < P.Gone) then P = q end end
			end
			if not P then return end
			if P.Key then live[P.Key] = nil end
			P.Key, P.F, P.Gone = key, 0, nil
			live[key] = P
		end
		P.Pos = pos
		P.F = math.max(P.F, f)
		P.Seen = true
	end
	local function padOff(P)
		P.Disc.Transparency = 1
		P.Swirl.Enabled, P.Swirl2.Enabled = false, false
		P.Rim.setTransparency(0.99)
		P.Motes.Rate, P.Stars.Rate, P.Cloud.Rate = 0, 0, 0
		for _, e in ipairs(P.Inlay) do e.B.Enabled = false end
	end
	local function updatePads()
		local now = os.clock()
		for _, P in ipairs(C.Pads) do
			if P.Key then
				-- (not touched this frame: the foot's gone, it burns away)
				if not P.Seen and not P.Gone then P.Gone = now end
				P.Seen = false
				local fade = P.Gone and math.clamp((now - P.Gone) / 1.6, 0, 1) or 0
				if fade >= 1 then
					live[P.Key] = nil
					P.Key = nil
					padOff(P)
				else
					local g = K.E.outCubic(P.F)
					local k = (0.15 + 0.85 * g) * (1 + 0.12 * fade)
					local r = PAD_R * k
					local at = P.Pos + UP * 2
					local vis = g * (1 - fade)
					P.Disc.Size = Vector3.new(3, 2 * r, 2 * r)
					P.Disc.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
					P.Disc.Transparency = 1 - 0.92 * vis
					local flat = CFrame.lookAt(at + UP * 1.8, at + UP * 3)
					P.Swirl.Enabled = vis > 0.02
					P.Swirl2.Enabled = vis > 0.02
					if P.Swirl.Enabled then
						K.moveQuad(P.Swirl, flat * CFrame.Angles(0, 0, P.Spin + now * 0.5))
						K.setQuadSize(P.Swirl, 2 * r * 0.98, 2 * r * 0.98)
						K.moveQuad(P.Swirl2, flat * CFrame.Angles(0, 0, -P.Spin - now * 0.9))
						K.setQuadSize(P.Swirl2, 1.3 * r, 1.3 * r)
						P.Swirl.Transparency = NumberSequence.new(1 - 0.85 * vis)
						P.Swirl2.Transparency = NumberSequence.new(1 - 0.65 * vis)
					end
					P.Rim.update(CFrame.lookAt(at + UP * 2.4, at + UP * 4), r - 5, r + 7, now * 0.4)
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
					P.Rim.setTransparency(math.min(0.99, 1 - vis))
					P.Host.Size = Vector3.new(1.6 * r, 1, 1.6 * r)
					P.Host.CFrame = CFrame.new(at + UP * 3)
					local forming = P.F < 1 and not P.Gone
					P.Motes.Rate = P.Gone and 0 or (forming and 120 * P.F or 45)
					P.Stars.Rate = P.Gone and 0 or (forming and 50 * P.F or 6)
					P.Cloud.Rate = P.Gone and 0 or (forming and 22 * P.F or 3)
				end
			end
		end
	end
	-- the footfalls' blasts (a small pool, reused)
	for i = 1, 6 do
		local host = K.part({ Name = "StepHost", Size = Vector3.new(380, 1, 380), Transparency = 1, CFrame = CFrame.new(base) }, set)
		local disc = K.part({ Name = "StepDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 260, 260), Material = Enum.Material.Neon, Color = VIOLET_HOT, Transparency = 1, CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.pi / 2) }, set)
		local ring = K.softRing(host, 36, 60, 160, { Brightness = 4, Alpha = 0 })
		for _, q in ipairs(ring.Q) do q.Color = ColorSequence.new(VIOLET_HOT, VIOLET) end
		ring.setTransparency(0.99)
		local sparks = K.emitter(host, {
			Texture = "1851669703", Color = ColorSequence.new(VIOLET_HOT, VIOLET), Size = K.ns(0, 40, 0.4, 65, 1, 0),
			Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(180, 560), SpreadAngle = Vector2.new(35, 35),
			Acceleration = Vector3.new(0, -420, 0), Brightness = 5, Shape = Enum.ParticleEmitterShape.Box,
		})
		local smoke = K.emitter(host, {
			Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(150, 80, 230), Color3.fromRGB(40, 15, 80)),
			Size = K.ns(0, 150, 1, 520), Transparency = K.ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(1.6, 2.6),
			Speed = NumberRange.new(60, 240), SpreadAngle = Vector2.new(80, 80), LightEmission = 0.3,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40), Drag = 2, Shape = Enum.ParticleEmitterShape.Box,
		})
		table.insert(C.Steps, { Host = host, Disc = disc, Ring = ring, Sparks = sparks, Smoke = smoke })
	end
	function C.stomp(pos, power)
		local S = C.Steps[C.Next]
		C.Next = C.Next % #C.Steps + 1
		S.At, S.Pos, S.Power = os.clock(), pos, power
		S.Host.CFrame = CFrame.new(pos + UP * 3)
		S.Sparks:Emit(math.floor(40 * power))
		S.Smoke:Emit(math.floor(14 * power))
	end
	function C.update(boss, t)
		updatePads()
		local now = os.clock()
		for _, S in ipairs(C.Steps) do
			if S.At then
				local u = (now - S.At) / (1.1 * math.sqrt(S.Power))
				if u >= 1 then
					S.At = nil
					S.Disc.Transparency = 1
					S.Ring.setTransparency(0.99)
				else
					local r = S.Power * 150 + S.Power * 850 * (1 - (1 - u) ^ 3)
					S.Ring.update(CFrame.lookAt(S.Pos + UP * 5, S.Pos + UP * 6), r, r + 60 + r * 0.15, u)
					S.Ring.setTransparency(math.min(0.99, 0.05 + u ^ 1.2 * 0.94))
					local s = 260 * math.sqrt(S.Power) * (1 + u * 0.6)
					S.Disc.Size = Vector3.new(3, s, s)
					S.Disc.CFrame = CFrame.new(S.Pos + UP * 3) * CFrame.Angles(0, 0, math.pi / 2)
					S.Disc.Transparency = math.min(1, 0.05 + u ^ 0.7)
				end
			end
		end
	end
	function C.clear()
		for _, S in ipairs(C.Steps) do
			S.At = nil
			S.Disc.Transparency = 1
			S.Ring.setTransparency(0.99)
		end
		for _, P in ipairs(C.Pads) do
			if P.Key then live[P.Key] = nil end
			P.Key, P.Gone = nil, nil
			padOff(P)
		end
		C.Wake.Rate = 0
		set.Parent = nil
	end
	ctx.Charge = C
	return C
end

-- which footfall's mass is forming (or standing) under a foot right now:
-- key, where, how formed. It only starts once the foot is nearly down.
local FORM_FROM = 0.85 -- (share of the swing: the foot's ~70 studs up)
local function footForm(ctx, L, side, t)
	local K = ctx.kit
	if t >= RUN.Leap then return nil end
	if t >= RUN.Plant then
		if side == "Right" then
			local n = math.floor(gait(RUN.Plant) + 1e-4)
			return "Right" .. n, printAt(L, side, plantAt(L, side, n)), 1
		end
		local q = K.k(t, RUN.Plant, RUN.Plant + 0.14, K.E.linear)
		local spot = footGround(L, "Left", runDist(RUN.Plant + RUN.Stance * RUN.Cycle / 2))
		return "LeftPlant", printAt(L, side, spot), math.clamp((q - 0.35) / 0.65, 0, 1)
	end
	local o = side == "Right" and 0 or 0.5
	local p = gait(t) - o
	local n = math.floor(p)
	local u = p - n
	local S = stanceAt(stepTime(n, o))
	if u < S then return side .. n, printAt(L, side, plantAt(L, side, n)), 1 end
	local w = (u - S) / (1 - S)
	if w < FORM_FROM then return nil end
	return side .. (n + 1), printAt(L, side, plantAt(L, side, n + 1)), (w - FORM_FROM) / (1 - FORM_FROM)
end

------------------------------------------------------------------------
-- the snatch, planned from the fall: when his fist closes on them and
-- the line it comes in along (DESCENT ends on the shot CATCH begins with)
------------------------------------------------------------------------
local function snatchPlan(ctx)
	if ctx.SnatchPlan then return ctx.SnatchPlan end
	local K = ctx.kit
	local F, G = SK.fall(ctx)
	local home = ctx.BossHome
	local start, v0 = F.at(G.Catch), F.vel(G.Catch)
	local C = SK.SNATCH
	local tc = math.clamp((start.Y - C.Y) / math.max(-v0.Y, 200), 0.9, 1.5)
	tc = math.max(tc, SWING + 0.35)
	local ts = tc - SWING
	local rootY = K.lerp(170, 200, K.E.inOutSine(ts / tc))
	local wind = SK.windCF(home, home.Position + UP * rootY, 1).Position
	local me = start:Lerp(C, ts / tc)
	local P = { tc = tc, ts = ts, In = (me - wind).Unit }
	ctx.SnatchPlan = P
	return P
end
-- close on you as you fall, looking back down the line his hand will come in on
local function nowhereCam(P, myPos, back)
	local p = myPos + P.In * back + UP * (3 + back * 0.08)
	return CFrame.lookAt(p, myPos - P.In * 40)
end

-- (build the floor of power with everything else, so it's ready before it's needed)
do
	local build0 = Ch.build
	function Ch.build(ctx)
		build0(ctx)
		pcall(buildCharge, ctx)
	end
end
function Ch.Descent(ctx, t0, dur)
	local K = ctx.kit
	local E = ctx.Entry
	local F, G = SK.fall(ctx)
	ctx.sets.Entry.Parent = ctx.stage
	if ctx.restoreArena then ctx.restoreArena() end
	ctx.hideBoss(true)
	K.lighting("Arena", 0)
	K.Blur.Enabled = false
	K.DOF.Enabled = false
	E.leave()
	E.setLayer(#PAL)
	E.Dust.Rate = 120
	ctx.sets.EntryVoid.Parent = ctx.stage
	local arena = ctx.sets.Arena
	arena.Parent = ctx.stage
	ctx.Boss.Parent = nil
	for _, q in ipairs(ctx.LapisAura or {}) do q.Transparency = K.ns(1) end
	if ctx.LapisSparkle then ctx.LapisSparkle.Rate = 0 end
	if ctx.LapisLight then ctx.LapisLight.Brightness = 0 end
	E.vortex(0, 0)
	for _, p in ipairs(E.Pillars) do p.B.Enabled = false end
	E.PillarRim.Enabled = false
	E.Roar.setTransparency(0.99)
	E.Trail.Enabled = false
	local SB = SK.boss(ctx, K)
	local L = chargeLegs(ctx, SB)
	local CH = buildCharge(ctx)
	local home = ctx.BossHome
	local look, right = home.LookVector, home.RightVector
	local AC = ctx.TL.ArenaCenter
	local plan = snatchPlan(ctx)
	local cue = K.once()
	local cam = SK.camera(K)
	local shot = 0
	local lastStep = {}
	local runLoop
	-- the close stomp: the right foot's footfall nearest 2.3 s in
	local closeN = math.floor(gait(2.3) + 0.5)
	local closeT = stepTime(closeN, 0)
	local closeFoot = plantAt(L, "Right", closeN)
	local plantSpot = footGround(L, "Right", runDist(RUN.Plant))
	local near = function(pos)
		local d = (pos - K.Cam.CF.Position).Magnitude
		return math.clamp(1.15 - d / 3800, 0.3, 1)
	end
	local function stomp(pos, power, side)
		CH.stomp(pos, power)
		local n = near(pos)
		K.sfx(K.S.RockBoom, 0.95 * n, 0.5 + math.random() * 0.08)
		K.sfx(K.S.Thump, 1 * n, 0.42 + math.random() * 0.05)
		K.sfx(K.S.Boom, 0.55 * n * power ^ 0.5, 0.55, { Reverb = 2 })
		K.sfx(side == "Left" and K.S.StepL or K.S.StepR, 0.9 * n, 0.3)
		K.shake(0.8 + 3.4 * n * n * math.min(power, 1.6), 0.55, 11)
		K.kick(-2.5 * n * power, 0.3)
	end
	SK.run(K, t0, dur, function(t, dt)
		local g = G.Descent + t
		local centre = F.at(g)
		local sky = K.k(t, 0, 3, K.E.inOutSine)
		local myPos = placeAir(ctx, F, g, 0.7, sky, t)
		local running = t >= RUN.From and t < RUN.Gone
		if not running then E.follow(centre, g, t, F.vel(g).Magnitude, K.Cam.CF.Position) end
		E.Dust.Enabled = not running
		if CH then CH.Set.Parent = running and ctx.stage or nil end
		ctx.Boss.Parent = running and arena or nil

		----------------------------------------------------------------
		-- him: the charge
		----------------------------------------------------------------
		local rootCF, head, gpos
		if running and L then
			rootCF = chargeBody(ctx, SB, L, t)
			local hcf = SB.R.cf("Head", rootCF)
			head = hcf.Position
			gpos = Vector3.new(home.X, RUN.Floor, home.Z) - look * runDist(t)
			if CH then
				for _, side in ipairs({ "Right", "Left" }) do
					local key, pos, f = footForm(ctx, L, side, t)
					if key then CH.form(key, pos, f) end
				end
				CH.update(runDist(t), t)
				CH.WakeHost.CFrame = CFrame.new(gpos + UP * 4) * home.Rotation
				CH.Wake.Rate = 0
			end
			-- his footfalls
			for _, side in ipairs({ "Right", "Left" }) do
				local o = side == "Right" and 0 or 0.5
				local n = math.floor(gait(math.min(t, RUN.Plant + 0.01)) - o)
				if lastStep[side] == nil then
					lastStep[side] = n
				elseif n > lastStep[side] then
					lastStep[side] = n
					stomp(printAt(L, side, plantAt(L, side, n)), 1 + 0.6 * (1 - ramp(t)), side)
				end
			end
			-- the eyes blaze as he nears
			local eyes = 0 -- (a glow here washed his whole face out; his own eyes carry it)
			E.EyeGlow.set(hcf.Position + hcf.LookVector * 40 + hcf.UpVector * 8, 150 + 40 * math.sin(t * 9), eyes * 0.85)
			if ctx.BossSmoke then ctx.BossSmoke.Rate = 18 end
		else
			E.EyeGlow.set(home.Position, 10, 0)
			if ctx.BossSmoke then ctx.BossSmoke.Rate = 0 end
		end

		----------------------------------------------------------------
		-- camera
		----------------------------------------------------------------
		local want = t < RUN.From and 1 or (not running) and 7 or t < 3.3 and 2 or t < 5.0 and 3 or t < 6.6 and 4 or t < 7.8 and 5 or 6
		if want ~= shot then shot = want cam.cut() end
		if shot == 1 then
			-- out of the float: the realm, and the arena a speck far below
			local p = centre + UP * 30 + Vector3.new(8, 0, 10)
			local lk = centre - UP * 500 + (Vector3.new(AC.X, centre.Y, AC.Z) - centre) * 0.1
			cam.go(CFrame.lookAt(p, lk) * CFrame.Angles(0, 0, t * 0.12), K.lerp(80, 72, K.k(t, 0, RUN.From)), dt, 10, centre)
		elseif shot == 2 then
			-- down on the floor of his power: a foot the size of a building comes down right there
			local p = closeFoot + right * 250 + look * 290 + UP * 22
			local e = K.k(t, closeT + 0.1, 3.3, K.E.inOutSine)
			local tgt = (closeFoot + UP * 110 - look * 60):Lerp(rootCF.Position - UP * 60, e)
			cam.go(CFrame.lookAt(p, tgt), 64, dt, 7)
		elseif shot == 3 then
			-- head on and low: charging straight at the lens
			local gap = K.lerp(2100, 900, K.k(t, 3.3, 5.0, K.E.outSine))
			local p = Vector3.new(home.X, RUN.Floor, home.Z) - look * (runDist(t) - gap) + UP * 55 + right * 70
			cam.go(CFrame.lookAt(p, rootCF.Position + UP * 70), 36, dt, 10)
		elseif shot == 4 then
			-- side on, running alongside him: the whole giant in stride
			local p = gpos + right * 1500 + look * 260 + UP * 90
			cam.go(CFrame.lookAt(p, rootCF.Position + UP * 40 + look * 140), 44, dt, 8, gpos)
		elseif shot == 5 then
			-- his face, snarling, the eyes blazing
			local p = head + look * 390 - UP * 80 - right * 120
			cam.go(CFrame.lookAt(p, head + UP * 6), 34, dt, 9, gpos)
		elseif shot == 6 then
			-- the plant... and the leap, right out of the top of the frame
			local p = plantSpot + look * 950 - right * 420 + UP * 28
			local tgt = rootCF.Position + UP * 60
			tgt = Vector3.new(tgt.X, math.min(tgt.Y, RUN.Floor + 620), tgt.Z)
			cam.go(CFrame.lookAt(p, tgt), 52, dt, K.lerp(8, 3, K.k(t, RUN.Leap, RUN.Leap + 0.2)))
		else
			-- nothing. just you, falling
			cam.go(nowhereCam(plan, myPos, 24), 55, dt, 12, myPos)
		end

		----------------------------------------------------------------
		-- beats
		----------------------------------------------------------------
		cue("in", t >= 0, function()
			K.flash(0.5, Color3.fromRGB(230, 210, 255), 0.8)
			K.sfx(K.S.Glass2, 0.8, 0.5)
		end)
		-- (something, very far off)
		cue("far1", t >= 0.75, function()
			K.sfx(K.S.Boom, 0.4, 0.35, { Reverb = 4 })
			K.shake(0.5, 0.7)
		end)
		cue("far2", t >= 1.2, function()
			K.sfx(K.S.Boom, 0.6, 0.33, { Reverb = 4 })
			K.shake(0.9, 0.6)
		end)
		cue("cut", t >= RUN.From, function()
			ctx.setMusic(K.S.M_Doom, 0.85, 0.1)
			K.sfx(K.S.Hell, 0.75, 0.5)
			if ctx.EntryWind then K.fadeSound(ctx.EntryWind, 0, 0.2) end
			runLoop = K.loop(K.S.Rumble, 0.6, 0.3, 0.55)
			K.tween(K.Grade, 0.3, { TintColor = Color3.fromRGB(222, 205, 255), Saturation = -0.05, Contrast = 0.28, Brightness = -0.03 })
		end)
		cue("roar", t >= 6.85, function()
			K.sfx(K.S.Hell, 1, 0.42, { Reverb = 3 })
			K.sfx(K.S.Thunder, 0.6)
			K.shake(2.5, 1, 12)
		end)
		cue("plant", t >= RUN.Plant + 0.14, function()
			-- both feet: the floor of power buckles
			stomp(printAt(L, "Left", footGround(L, "Left", runDist(RUN.Plant + RUN.Stance * RUN.Cycle / 2))), 2.2, "Left")
			K.sfx(K.S.BigHit, 1, 0.5)
			K.sfx(K.S.RockBoom, 1, 0.4)
			K.kick(-8, 0.5)
			K.flash(0.15, VIOLET, 0.3)
		end)
		cue("leap", t >= RUN.Leap, function()
			if CH then CH.stomp(plantSpot, 3.2) end
			K.sfx(K.S.FireWhoosh, 1, 0.45)
			K.sfx(K.S.Whoosh, 1, 0.4, { Reverb = 3 })
			K.sfx(K.S.Cannon, 0.8, 0.5)
			K.shake(4, 1.2, 10)
			K.flash(0.25, VIOLET, 0.45)
		end)
		cue("gone", t >= RUN.Gone, function()
			-- ...and silence
			ctx.fadeMusic(0, 0.35)
			if runLoop then K.fadeSound(runLoop, 0, 0.5, true) runLoop = nil end
			if ctx.EntryWind then K.fadeSound(ctx.EntryWind, 0.45, 0.6) end
			K.tween(K.Grade, 0.4, { TintColor = Color3.fromRGB(215, 220, 255), Saturation = -0.3, Contrast = 0.2, Brightness = -0.04 })
			K.sfx(K.S.DarkDrone, 0.45, 0.7)
		end)
		cue("thump", t >= 10.5, function() K.sfx(K.S.Heartbeat, 0.9, 0.85) end)
		K.stream(running and gpos or centre)
	end)
	if runLoop then K.fadeSound(runLoop, 0, 0.3, true) end
	if CH then CH.clear() end
	if ctx.BossSmoke then ctx.BossSmoke.Rate = 0 end
	E.Trail.Enabled = false
	E.EyeGlow.set(home.Position, 10, 0)
end
------------------------------------------------------------------------
-- CATCH: out of nowhere, his hand
------------------------------------------------------------------------
function Ch.Catch(ctx, t0, dur)
	local K = ctx.kit
	local E = ctx.Entry
	local F, G = SK.fall(ctx)
	ctx.sets.Entry.Parent = ctx.stage
	ctx.sets.EntryVoid.Parent = ctx.stage
	ctx.sets.Arena.Parent = ctx.stage
	ctx.Boss.Parent = nil -- (not until the swing: he comes out of nowhere)
	if ctx.restoreArena then ctx.restoreArena() end
	ctx.hideBoss(true)
	for _, q in ipairs(ctx.LapisAura or {}) do q.Transparency = K.ns(1) end
	if not ctx.EntryWind then K.lighting("Arena", 0) K.fade(0, 0.3) end
	if ctx.Charge then ctx.Charge.clear() end
	local SB = SK.boss(ctx, K)
	local home = ctx.BossHome
	local look, right = home.LookVector, home.RightVector
	local cue = K.once()
	local cam = SK.camera(K)
	local shot = 0
	local me = ctx.myRig
	local start = F.at(G.Catch)
	local C = SK.SNATCH -- where the fist closes on them
	local plan = snatchPlan(ctx)
	local tc, ts = plan.tc, plan.ts
	local FT = 0.5    -- the follow-through after the grab
	local VEND = 320  -- how fast the fist is still travelling as it closes on them
	local gR = SK.fistRot(home)
	local gp = SK.gripPalm(home, C)
	local gcf = CFrame.new(gp) * gR
	local off0 = {}
	for slot in pairs(ctx.rigs) do off0[slot] = airPos(ctx, F, slot, G.Catch) - start end
	-- the way the swing carries on after the grab
	local w1 = SK.windCF(home, home.Position + UP * 200, 1)
	local swingDir = (gp - w1.Position).Unit
	local ftEnd = gp + swingDir * 42 - UP * 20
	-- (Hermite: position and speed both carry smoothly from one leg of the move to the next)
	local function herm(p0, m0, p1, m1, s)
		local s2, s3 = s * s, s * s * s
		return p0 * (2 * s3 - 3 * s2 + 1) + m0 * (s3 - 2 * s2 + s) + p1 * (-2 * s3 + 3 * s2) + m1 * (s3 - s2)
	end
	E.Dust.Rate = 60
	for _, rig in pairs(ctx.rigs) do rig.Smooth = 20 end
	SK.run(K, t0, dur, function(t, dt)
		ctx.Boss.Parent = t >= ts - 0.04 and ctx.sets.Arena or nil
		----------------------------------------------------------------
		-- him: wound up out of sight, the snatch, the follow-through, then holding them
		----------------------------------------------------------------
		local draw = K.k(t, 0, ts, K.E.outSine)
		local yS = K.k(t, ts, tc + 0.3, K.E.inOutSine) -- (his body turning into the swing)
		local settle = K.k(t, tc + 0.15, tc + 2.0, K.E.inOutSine)
		local rootY = t < tc and K.lerp(170, 200, K.k(t, 0, tc, K.E.inOutSine)) or K.lerp(200, 60, settle)
		local breathe = math.sin(t * 1.3) * 2 * settle
		local rootCF = home * CFrame.new(0, rootY + breathe, 0)
		ctx.BossRoot.CFrame = rootCF
		-- (later he raises the fist to look at what he's caught, then lowers it)
		local inspect = K.k(t, 3.8, 6.4, K.E.inOutSine) * (1 - K.k(t, 8.6, 10.6, K.E.inOutSine))
		local lean = K.k(t, 8.5, dur, K.E.inOutSine)
		local yaw = K.lerp(K.lerp(-14, -24, draw), 16, yS)
		yaw = K.lerp(yaw, 0, K.k(t, tc + 0.3, tc + 1.5, K.E.inOutSine))
		SB.reset()
		SB.body({
			Waist = K.A(-2 - 4 * K.k(t, tc, tc + 1) - inspect * 6 - lean * 10 + math.sin(math.pi * yS) * 6 * (1 - settle), yaw - inspect * 6, 0),
			LeftShoulder = K.A(-5 + 20 * (1 - settle), 0, -32 - 10 * (1 - settle)), LeftElbow = K.A(18, 0, 0),
		})
		SK.hang(SB, "Left", 0.4, 0.2)
		local hcf
		if t < ts then
			local w = SK.windCF(home, rootCF.Position, draw)
			hcf = SB.hand("Right", w.Position, w.YVector, w.ZVector, SK.WIND_POLE(home), rootCF)
		elseif t < tc then
			-- the snatch: from rest, accelerating, bowing out to his right and up,
			-- still travelling as the fingers close
			local s = (t - ts) / SWING
			local w = SK.windCF(home, rootCF.Position, 1)
			local p = herm(w.Position, Vector3.zero, gp, swingDir * VEND * SWING, s) + (right * 45 + UP * 35) * math.sin(math.pi * s) ^ 2
			local e = K.E.inOutSine(s)
			local cf = CFrame.new(p) * w.Rotation:Lerp(gR, e)
			hcf = SB.hand("Right", cf.Position, cf.YVector, cf.ZVector, SK.WIND_POLE(home):Lerp(SK.FIST_POLE(home), e), rootCF)
		else
			-- the fist carries on with the swing, eases to a stop, then draws back in to hold them
			local s = math.min((t - tc) / FT, 1)
			local p = herm(gp, swingDir * VEND * FT, ftEnd, Vector3.zero, s)
			local palm = p:Lerp(SK.holdPalm(ctx, t, inspect), K.k(t, tc + FT * 0.5, tc + 2.0, K.E.inOutSine))
			hcf = SK.holdFist(ctx, SB, palm, rootCF)
		end
		-- fingers: splayed wide in the swing, snapping shut round them
		local grip = K.k(t, tc - 0.08, tc + 0.14, K.E.outCubic)
		local clench = math.sin(math.pi * K.k(t, tc, tc + 0.5)) * 0.08
		local open = t < ts and K.lerp(0.12, 0.22, draw) or K.lerp(0.22, 0.04, K.k(t, ts, ts + 0.15))
		local curl = K.lerp(open, SK.GRIP, grip) + clench
		SB.Hands.Right.H.pose(curl, K.lerp(K.lerp(0.8, 0.95, yS), 0.05, grip), K.lerp(0.05, 0.8, grip), 0, t)
		local headCF = SB.R.cf("Head", rootCF)
		local face = headCF.Position
		local myPos = start

		----------------------------------------------------------------
		-- the party: still falling as they were... snatched, struggling
		----------------------------------------------------------------
		for slot, rig in pairs(ctx.rigs) do
			local off = SK.fistSlot(ctx, slot)
			local cf, pose
			if t < tc then
				local u = t / tc
				local g = G.Catch + t
				local target = gcf:PointToWorldSpace(off)
				local p = (start + (off0[slot] or Vector3.zero)):Lerp(target, u)
				local upright = SK.inFist(gcf, off, face, 0)
				-- (the same drift they fell in, so nothing jumps as the chapter changes)
				local flat = CFrame.Angles(0, slot * 0.9 + math.sin(g * 0.3 + slot) * 0.4, math.sin(g * 1.1 + slot) * 0.15)
				local turn = K.k(u, 0.55, 1, K.E.inOutSine)
				cf = CFrame.new(p) * flat:Lerp(upright.Rotation, turn)
				local fall = K.mixPose(K.Poses.SkydiveFlat, K.zeroGPose(g * 3, slot, 1), 0.3)
				pose = K.mixPose(fall, K.Poses.Blown, K.k(u, 0.6, 0.95))
			else
				local tr = t - tc
				cf = SK.inFist(hcf, off, face, 0)
				local strain = K.k(tr, 1.7, 2.7) * (1 - K.k(t, 6.6, 7.4) * 0.6)
				pose = SK.gripPose(K, t, slot, strain, 0)
				-- the jolt of the grab, then winded, head down... then shoving at his fingers
				local slump = K.k(tr, 0.05, 0.35, K.E.outQuad) * (1 - K.k(tr, 1.3, 2.3, K.E.inOutSine))
				pose.Neck = K.A(-50 * slump + K.k(t, 6.6, 7.6, K.E.inOutSine) * 24, 0, 0) * (pose.Neck or CFrame.new())
				if tr < 0.35 then pose = K.mixPose(K.Poses.Blown, pose, K.k(tr, 0, 0.35, K.E.outQuad)) end
			end
			rig:setCF(cf)
			rig:setPose(pose)
			rig:apply()
			if rig == me then myPos = cf.Position end
		end
		SB.lookAt(t < tc and start:Lerp(C, t / tc) or myPos, 1, rootCF)
		E.Dust.Enabled = t < tc + 1
		if t < tc + 1 then E.follow(t < tc and start:Lerp(C, t / tc) or C, G.Catch + t, t, 300, K.Cam.CF.Position) end
		local fist = hcf:PointToWorldSpace(Vector3.new(12, 20, 12))

		----------------------------------------------------------------
		-- camera
		----------------------------------------------------------------
		if t < tc + 0.03 then
			if shot ~= 1 then shot = 1 cam.cut() end
			-- the shot the fall ended on... then he's THERE, his hand rushing up out of
			-- the dark at you, and the camera's thrown back ahead of it
			local e = K.k(t, ts - 0.05, tc, K.E.outCubic)
			cam.go(nowhereCam(plan, myPos, K.lerp(24, 70, e)), K.lerp(55, 60, e), dt, 12, myPos)
		elseif t < tc + 2.4 then
			if shot ~= 2 then shot = 2 cam.cut() end
			-- right in front of you, trapped in his fist as it swings through
			local head = me and me:head() and me:head().CFrame or CFrame.new(myPos + UP * 1.5)
			local fwd = head.LookVector
			local sd = fwd:Cross(UP).Unit
			local e = K.k(t, tc, tc + 2.4, K.E.outSine)
			local p = head.Position + fwd * K.lerp(24, 19, e) + UP * K.lerp(11, 8, e) + sd * 8
			cam.go(CFrame.lookAt(p, head.Position - UP * 4), K.lerp(58, 50, e), dt, 14, myPos)
		elseif t < 6.6 then
			if shot ~= 3 then shot = 3 cam.cut() end
			-- side on: how small you are in his fist, the arena far below
			local e = K.k(t, tc + 2.4, 6.6)
			local p = fist + right * 440 + UP * K.lerp(70, 50, e) - look * 40
			cam.go(CFrame.lookAt(p, fist:Lerp(face, 0.45)), K.lerp(40, 35, e), dt, 6)
		elseif t < 9.2 then
			if shot ~= 4 then shot = 4 cam.cut() end
			-- over your shoulder, up into his face
			local e = K.k(t, 6.6, 9.2)
			local head = me and me:head() and me:head().Position or myPos
			local to = (face - head).Unit
			local sd = to:Cross(UP).Unit
			local p = head - to * 8 + UP * 1.4 + sd * 2.4
			cam.go(CFrame.lookAt(p, face), K.lerp(56, 42, e), dt, 8)
		else
			if shot ~= 5 then shot = 5 cam.cut() end
			-- his face bending down over them
			local e = K.k(t, 9.2, dur)
			local p = face:Lerp(fist, 0.55) + right * 40 + UP * -10
			cam.go(CFrame.lookAt(p, face), K.lerp(48, 40, e), dt, 8)
		end

		----------------------------------------------------------------
		-- beats
		----------------------------------------------------------------
		cue("appear", t >= ts - 0.04, function()
			-- out of nowhere
			K.flash(0.2, Color3.fromRGB(190, 120, 255), 0.45)
			K.sfx(K.S.Portal2, 1, 0.6)
			K.sfx(K.S.Hell, 0.9, 0.5)
			K.sfx(K.S.Whoosh, 1, 0.45, { Reverb = 3 })
			K.sfx(K.S.FireWhoosh, 0.6, 0.6)
			K.shake(2, 0.6)
			if ctx.BossSmoke then ctx.BossSmoke:Emit(30) end
			K.vfx("Smoke-01", CFrame.new(SK.windCF(home, home.Position + UP * 190, 1).Position), E.FX, 6, 16, 3)
		end)
		cue("caught", t >= tc, function()
			K.sfx(K.S.BigHit, 1, 0.8)
			K.sfx(K.S.Punch, 0.9, 0.7)
			K.sfx(K.S.Thump, 0.9, 0.8)
			K.sfx(K.S.MetalHit, 0.5, 0.5)
			K.shake(4.5, 1.2)
			K.kick(-12, 0.7)
			K.flash(0.3, Color3.fromRGB(215, 225, 255), 0.6)
			ctx.setMusic(K.S.M_Doom, 0.8, 0.1)
			local m = SK.models(ctx)
			table.insert(m, ctx.Boss)
			task.spawn(K.impact, m, "WBW", 0.05)
			local f = hcf:PointToWorldSpace(Vector3.new(12, 20, 12))
			K.vfx("Smoke-01", CFrame.new(f), E.FX, 3, 20, 4)
			K.vfx("Shoot-01", CFrame.lookAt(f, f + swingDir), E.FX, 2.5, 3, 3)
			if ctx.EntryWind then K.fadeSound(ctx.EntryWind, 0, 0.8, true) ctx.EntryWind = nil end
		end)
		cue("fingers", t >= tc + 0.1, function() K.sfx(K.S.MetalHit, 0.6, 0.4) end)
		cue("struggle", t >= tc + 1.8, function() K.sfx(K.S.BodyFall, 0.5, 1.2) end)
		cue("groan", t >= 4.2, function() K.sfx(K.S.DarkDrone, 0.6, 0.7) end)
		-- he speaks
		cue("line1", t >= 4.4, function() K.say("SPIRAL APES.", 1.0, { Scale = 0.09, Speaker = "Anti-Spiral" }) end)
		cue("line2", t >= 6.7, function() K.say("YOU HAVE CRAWLED\nFAR ENOUGH.", 1.1, { Scale = 0.075, Speaker = "Anti-Spiral" }) end)
		cue("line3", t >= 9.3, function()
			K.sfx(K.S.Thunder, 0.6)
			K.say("HERE, YOUR EVOLUTION ENDS.", 1.2, { Scale = 0.075, Speaker = "Anti-Spiral" })
		end)
		cue("loom", t >= 9.2, function()
			K.sfx(K.S.Hell, 0.7, 0.45)
			K.shake(1.2, 1.5)
		end)
		K.stream(SK.CATCH)
	end)
	ctx.Boss.Parent = ctx.sets.Arena
	E.Dust.Enabled = false
	E.Trail.Enabled = false
	E.vortex(0, 0)
	for _, p in ipairs(E.Pillars) do p.B.Enabled = false end
	E.PillarRim.Enabled = false
	E.Roar.setTransparency(0.99)
end

return Ch
