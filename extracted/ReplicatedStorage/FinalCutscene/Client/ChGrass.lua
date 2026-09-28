--==================================================
-- CHAPTER 1: GRASS
-- The party hanging out in the middle of the Become La Peace
-- island -> the sky turns -> a portal tears open -> the
-- Anti-Spiral's arm reaches down and slams its open hand
-- palm-up on the field -> the palm charges -> a colossal beam
-- erupts out of it and launches everyone into the sky.
--==================================================
local Ch = {}

local pi = math.pi
local ARM_S = 1.6          -- scale of the boss forearm / upper arm
local HAND_LEN = 110       -- giant hand, wrist to fingertip
local COL_R = 88           -- beam column radius

-- when things happen (chapter seconds)
local T_STORM = 9.6
local T_PORTAL = 11.4
local T_ARM = 13.6
local T_SLAM = 16.2
local T_CHARGE = 17.6
local T_FIRE = 20.0

--------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------
local function bezier(a, c, b, u)
	local v = 1 - u
	return a * (v * v) + c * (2 * v * u) + b * (u * u)
end

-- distance along a trapezoid speed profile: accelerate, cruise, brake
local function trapezoid(t, dur, acc)
	acc = math.min(acc, dur / 2)
	local vmax = 1 / (dur - acc)
	if t <= 0 then return 0 end
	if t >= dur then return 1 end
	if t < acc then return 0.5 * vmax / acc * t * t end
	if t > dur - acc then
		local r = dur - t
		return 1 - 0.5 * vmax / acc * r * r
	end
	return 0.5 * vmax * acc + vmax * (t - acc)
end

local function lerpAngle(a, b, k)
	local d = (b - a + pi) % (2 * pi) - pi
	return a + d * k
end

-- where everyone regroups when the sky turns (meadow frame, facing the hand)
local GATHER = {
	Vector3.new(-3, 0, 12), Vector3.new(7, 0, 10), Vector3.new(-11, 0, 15), Vector3.new(14, 0, 15),
	Vector3.new(-17, 0, 20), Vector3.new(2, 0, 20), Vector3.new(20, 0, 22), Vector3.new(-7, 0, 24),
}

local EMOTES = {
	{ "Wave", 2.6 }, { "Dance1", 3.4 }, { "Laugh", 2.4 }, { "Cheer", 2.6 }, { "Point", 2.2 },
	{ "Dance2", 3.2 }, { "Sit", 3.8 }, { "Look", 2.8 }, { "Dance3", 3.0 },
}

-- arc-length table for a bezier, so a walk moves at an even pace along the
-- whole curve (plain bezier u bunches up on the bends: the feet slide)
local function arcTable(a, c, b)
	local n = 24
	local lens = { 0 }
	local prev = a
	for i = 1, n do
		local p = bezier(a, c, b, i / n)
		lens[i + 1] = lens[i] + (p - prev).Magnitude
		prev = p
	end
	return lens
end

local function uAtDist(lens, d)
	local n = #lens - 1
	local total = lens[#lens]
	if d <= 0 then return 0 end
	if d >= total then return 1 end
	for i = 1, n do
		if lens[i + 1] >= d then
			local f = (d - lens[i]) / math.max(lens[i + 1] - lens[i], 1e-4)
			return (i - 1 + f) / n
		end
	end
	return 1
end

local TURN = 0.4 -- seconds spent turning on the spot before setting off

-- a deterministic little life for each slot: stroll somewhere, stop,
-- do something (wave, dance, sit in the grass...), stroll again
local function makePlan(ctx, slot)
	local M = ctx.TL.Meadow
	local rng = Random.new(4000 + slot * 131)
	local n = math.max(ctx.n, 1)
	local a0 = (slot - 1) / n * 2 * pi + 0.4
	local spread = n > 1 and math.min(pi / n * 1.6, 1.3) or 1.4
	local function spot()
		local a = a0 + rng:NextNumber(-spread, spread)
		local r = rng:NextNumber(9, 34)
		return (M * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r * 0.9 + 6)).Position
	end
	local segs = {}
	local pos = spot()
	local t = -rng:NextNumber(0, 1.5)
	local walking = slot % 2 == 1
	local used = {}
	while t < T_STORM + 1 do
		if walking then
			local to = spot()
			local dist = (to - pos).Magnitude
			if dist < 6 then
				to = pos + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(6, 10))
				dist = (to - pos).Magnitude
			end
			local speed = rng:NextNumber(6.2, 8.4)
			local mid = (pos + to) / 2
			local side = (to - pos):Cross(Vector3.yAxis).Unit
			-- gentler bends: a walk is mostly straight, it just drifts a little
			local ctrl = mid + side * dist * rng:NextNumber(-0.16, 0.16)
			local lens = arcTable(pos, ctrl, to)
			local len = lens[#lens]
			local dur = TURN + len / speed + 0.55
			local tan0 = ctrl - pos
			table.insert(segs, {
				Kind = "Walk", T0 = t, T1 = t + dur, A = pos, C = ctrl, B = to,
				Lens = lens, Len = len, Yaw0 = math.atan2(-tan0.X, -tan0.Z),
			})
			pos = to
			t += dur
		else
			local pick
			for _ = 1, 6 do
				pick = EMOTES[rng:NextInteger(1, #EMOTES)]
				if not used[pick[1]] then break end
			end
			used[pick[1]] = true
			local dur = pick[2] + rng:NextNumber(-0.3, 0.6)
			local faceYaw = rng:NextNumber(0, 2 * pi)
			table.insert(segs, { Kind = "Emote", T0 = t, T1 = t + dur, At = pos, Anim = pick[1], FaceYaw = faceYaw })
			t += dur
		end
		walking = not walking
	end
	return segs
end

local function evalPlan(segs, t)
	for _, s in ipairs(segs) do
		if t < s.T1 then return s end
	end
	return segs[#segs]
end

local function planPos(s, t)
	if s.Kind == "Walk" then
		-- turn on the spot first, then an even pace along the curve (by arc length)
		local wt = t - s.T0 - TURN
		if wt <= 0 then return s.A end
		local frac = trapezoid(wt, s.T1 - s.T0 - TURN, 0.55)
		return bezier(s.A, s.C, s.B, uAtDist(s.Lens, frac * s.Len))
	end
	return s.At
end

--------------------------------------------------------------------------
-- BUILD
--------------------------------------------------------------------------
function Ch.build(ctx)
	local K = ctx.kit
	local set = Instance.new("Folder")
	set.Name = "GrassSet"
	ctx.sets.Grass = set
	local M = ctx.TL.Meadow
	local G = {}
	ctx.G = G
	local up = Vector3.yAxis
	local ground = M.Position.Y

	----------------------------------------------------------------
	-- geometry of the hand landing + the portal it comes from
	----------------------------------------------------------------
	local handSrc = K.Assets:FindFirstChild("GiantHand")
	local hk = HAND_LEN / handSrc.Size.Y
	local handSize = handSrc.Size * hk
	local F = -M.LookVector                          -- fingers point back at the party
	local N = up                                     -- palm faces the sky
	local handCenter = (M * CFrame.new(0, 0, -74)).Position + Vector3.new(0, handSize.Z / 2 - 2, 0)
	G.LandCF = CFrame.fromMatrix(handCenter, F:Cross(N), F) * CFrame.Angles(0, pi, 0) -- mesh palm is its -Z
	G.Palm = handCenter + N * (handSize.Z / 2 + 2)
	G.ColBase = Vector3.new(G.Palm.X, ground, G.Palm.Z)
	G.Wrist = handCenter - F * (HAND_LEN / 2 - 8)
	G.PortalPos = (M * CFrame.new(0, 215, -300)).Position
	G.ArmDir = (G.Wrist - G.PortalPos).Unit
	G.OutFinal = (G.Wrist - G.PortalPos).Magnitude
	G.PortalCF = CFrame.lookAt(G.PortalPos, G.Wrist)
	ctx.PortalCF = G.PortalCF
	G.Ground = ground

	----------------------------------------------------------------
	-- portal
	----------------------------------------------------------------
	local portalCF = G.PortalCF
	local host = K.part({ Name = "PortalHost", Size = Vector3.one, Transparency = 1, CFrame = portalCF }, set)
	G.PortalHost = host
	local rings = {}
	local tex = { "14426232568", "116996021489973", "18823306900", "124165682553877", "14477910720" }
	local cols = { Color3.fromRGB(150, 60, 255), Color3.fromRGB(255, 200, 255), Color3.fromRGB(190, 110, 255), Color3.fromRGB(90, 30, 200), Color3.fromRGB(120, 50, 230) }
	local bright = { 2.2, 1.2, 2.6, 2.0, 1.4 }
	for i = 1, 5 do
		local b = K.quad(host, portalCF * CFrame.new(0, 0, -i * 0.7) * CFrame.Angles(0, pi, 0), 1, 1, tex[i], {
			Color = cols[i], Brightness = bright[i], Transparency = 0.12,
		})
		table.insert(rings, b)
	end
	G.PortalRings = rings
	G.PortalCore = K.part({ Name = "PortalCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1, 1), Color = Color3.fromRGB(6, 0, 14), Material = Enum.Material.Neon, CFrame = portalCF * CFrame.Angles(0, math.rad(90), 0), Transparency = 1 }, set)
	G.PortalSuck = K.emitter(host, {
		Texture = "1084982817", Color = ColorSequence.new(Color3.fromRGB(190, 120, 255)), Size = K.ns(0, 34, 1, 4),
		Transparency = K.ns(0, 1, 0.3, 0.3, 1, 1), Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(-140, -90),
		Shape = Enum.ParticleEmitterShape.Disc, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 3,
		EmissionDirection = Enum.NormalId.Front, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
	})
	G.PortalArcs = K.emitter(host, {
		Texture = "1053548563", Color = ColorSequence.new(Color3.fromRGB(230, 200, 255)), Size = K.ns(0, 6, 1, 1),
		Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(60, 120), Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Brightness = 6, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = K.ns(0, 2.5), EmissionDirection = Enum.NormalId.Front,
	})
	host.Size = Vector3.new(150, 150, 1)
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(170, 100, 255)
	pl.Range = 0
	pl.Brightness = 6
	pl.Shadows = false
	pl.Parent = host
	G.PortalLight = pl

	----------------------------------------------------------------
	-- the Anti-Spiral's arm: boss forearm + upper arm, and a giant open hand
	----------------------------------------------------------------
	local src = K.Assets.AntiSpiral
	local arm = Instance.new("Model")
	arm.Name = "AntiSpiralArm"
	local function prep(p, scale)
		for _, d in ipairs(p:GetChildren()) do
			if not d:IsA("SpecialMesh") then d:Destroy() end
		end
		if scale then p.Size = p.Size * scale end
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = true
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(38, 22, 64)
		p.Reflectance = 0.05
		p.Transparency = 1
		p.Parent = arm
		return p
	end
	G.Lower = prep(src.RightLowerArm:Clone(), ARM_S)
	G.Upper = prep(src.RightUpperArm:Clone(), ARM_S)
	G.Hand = prep(handSrc:Clone(), nil)
	G.Hand.Size = handSize
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(120, 60, 220)
	hl.FillTransparency = 0.82
	hl.OutlineColor = Color3.fromRGB(235, 220, 255)
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = arm
	G.ArmHL = hl
	arm.Parent = set
	G.Arm = arm
	-- purple energy crawling over the arm
	G.ArmVeins = K.emitter(G.Lower, {
		Texture = "1053548563", Color = ColorSequence.new(Color3.fromRGB(200, 120, 255)), Size = K.ns(0, 3, 1, 0),
		Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(4, 12), Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Brightness = 4, LockedToPart = true,
	})
	G.HandVeins = K.emitter(G.Hand, {
		Texture = "1053548563", Color = ColorSequence.new(Color3.fromRGB(220, 160, 255)), Size = K.ns(0, 3, 1, 0),
		Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(2, 8), Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Brightness = 4, LockedToPart = true,
	})

	----------------------------------------------------------------
	-- palm charge
	----------------------------------------------------------------
	local glow = K.part({ Name = "PalmGlow", Shape = Enum.PartType.Ball, Size = Vector3.one, Color = Color3.fromRGB(235, 215, 255), Material = Enum.Material.Neon, Transparency = 1, CFrame = CFrame.new(G.Palm) }, set)
	G.PalmGlow = glow
	local gl = Instance.new("PointLight")
	gl.Color = Color3.fromRGB(180, 120, 255)
	gl.Range = 0
	gl.Brightness = 10
	gl.Parent = glow
	G.PalmLight = gl
	local suckHost = K.part({ Name = "PalmSuckHost", Shape = Enum.PartType.Ball, Size = Vector3.one * 70, Transparency = 1, CFrame = CFrame.new(G.Palm) }, set)
	G.PalmSuckHost = suckHost
	G.PalmFlip = K.emitter(glow, {
		Texture = "15041986621", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = ColorSequence.new(Color3.fromRGB(215, 175, 255)), Size = K.ns(0, 40, 1, 70), Lifetime = NumberRange.new(0.45, 0.6),
		Speed = NumberRange.new(0), Brightness = 4, Rotation = NumberRange.new(0, 360),
	})
	G.PalmSuck = K.emitter(suckHost, {
		Texture = "1053548563", Color = ColorSequence.new(Color3.fromRGB(235, 215, 255)), Size = K.ns(0, 4, 1, 0.6),
		Lifetime = NumberRange.new(0.45, 0.6), Speed = NumberRange.new(-200, -150), Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Brightness = 5,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = K.ns(0, 2.5),
	})

	-- ground: a glowing vortex around the hand + cracks that light up
	local gHost = K.part({ Name = "GroundHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(G.ColBase + Vector3.new(0, 0.4, 0)) }, set)
	G.GroundHost = gHost
	local flat = CFrame.new(G.ColBase + Vector3.new(0, 0.5, 0)) * CFrame.Angles(-pi / 2, 0, 0)
	G.GroundRing = K.quad(gHost, flat, 1, 1, "18823306900", { Color = Color3.fromRGB(190, 120, 255), Brightness = 3, Transparency = 1 })
	G.GroundSwirl = K.quad(gHost, flat, 1, 1, "14426232568", { Color = Color3.fromRGB(160, 80, 255), Brightness = 2, Transparency = 1 })
	G.GroundSwirl2 = K.quad(gHost, flat, 1, 1, "124165682553877", { Color = Color3.fromRGB(230, 190, 255), Brightness = 1.5, Transparency = 1 })
	G.FlatCF = flat
	G.Cracks = {}
	local crng = Random.new(77)
	for i = 1, 26 do
		local a = i / 26 * 2 * pi + crng:NextNumber(-0.1, 0.1)
		local len = crng:NextNumber(30, 120)
		local r0 = crng:NextNumber(30, 70)
		local p0 = G.ColBase + Vector3.new(math.cos(a) * r0, 0.25, math.sin(a) * r0)
		local a2 = a + crng:NextNumber(-0.25, 0.25)
		local p1 = p0 + Vector3.new(math.cos(a2), 0, math.sin(a2)) * len
		local c = K.part({ Name = "Crack", Size = Vector3.new(crng:NextNumber(0.8, 1.8), 0.3, (p1 - p0).Magnitude), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Material = Enum.Material.Neon, Color = Color3.fromRGB(200, 130, 255), Transparency = 1 }, set)
		table.insert(G.Cracks, { Part = c, R = r0 })
	end
	-- wind + grit rushing in toward the hand while it charges
	local windHost = K.part({ Name = "WindHost", Size = Vector3.new(260, 30, 260), Transparency = 1, CFrame = CFrame.new(G.ColBase + Vector3.new(0, 8, 0)) }, set)
	G.Wind = K.emitter(windHost, {
		Texture = "1053548563", Color = ColorSequence.new(Color3.fromRGB(230, 215, 255)), Size = K.ns(0, 1.4, 1, 0.2),
		Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(-160, -110), Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = K.ns(0, 4), Brightness = 2, EmissionDirection = Enum.NormalId.Top,
	})
	local gritHost = K.part({ Name = "GritHost", Size = Vector3.new(220, 2, 220), Transparency = 1, CFrame = CFrame.new(G.ColBase + Vector3.new(0, 1, 0)) }, set)
	G.Grit = K.emitter(gritHost, {
		Texture = "17000879366", Color = ColorSequence.new(Color3.fromRGB(120, 100, 80)), Size = K.ns(0, 0.6, 1, 0.3),
		Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(10, 30), Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Brightness = 1, LightEmission = 0, LightInfluence = 1,
		Acceleration = Vector3.new(0, 25, 0), EmissionDirection = Enum.NormalId.Top,
	})
	-- slam dust
	local dustHost = K.part({ Name = "DustHost", Size = Vector3.new(120, 4, 120), Transparency = 1, CFrame = CFrame.new(handCenter.X, ground + 3, handCenter.Z) }, set)
	G.Dust = K.emitter(dustHost, {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(150, 140, 130)), Size = K.ns(0, 20, 1, 60),
		Transparency = K.ns(0, 0.3, 0.6, 0.6, 1, 1), Lifetime = NumberRange.new(2.2, 3.4), Speed = NumberRange.new(60, 130),
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Drag = 2.5, LightEmission = 0, LightInfluence = 1, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30),
		EmissionDirection = Enum.NormalId.Top,
	})
	-- shock rings on the ground
	G.Shock = {}
	for i = 1, 3 do
		table.insert(G.Shock, (K.quad(gHost, flat, 1, 1, "18823306900", { Color = Color3.fromRGB(235, 220, 255), Brightness = 3, Transparency = 1 })))
	end
	-- debris that gets thrown around
	G.Debris = {}
	local rocks = K.Assets.Rocks:GetChildren()
	for i = 1, 30 do
		local r = rocks[crng:NextInteger(1, #rocks)]:Clone()
		local k = crng:NextNumber(2, 7)
		r.Size = r.Size / math.max(r.Size.X, r.Size.Y, r.Size.Z) * k
		r.Anchored = true
		r.CanCollide = false
		r.CanQuery = false
		r.CanTouch = false
		r.Color = Color3.fromRGB(95, 80, 62)
		r.Transparency = 1
		r.Parent = set
		local a = crng:NextNumber(0, 2 * pi)
		table.insert(G.Debris, {
			Part = r, Dir = Vector3.new(math.cos(a), 0, math.sin(a)), R = crng:NextNumber(20, 110), Vy = crng:NextNumber(40, 110),
			Vh = crng:NextNumber(10, 50), Spin = crng:NextUnitVector() * crng:NextNumber(2, 8), Rise = crng:NextNumber(40, 160),
		})
	end

	----------------------------------------------------------------
	-- the beam column (stacked cylinders: parts can't be longer than 2048)
	----------------------------------------------------------------
	local colFolder = Instance.new("Folder")
	colFolder.Name = "Column"
	colFolder.Parent = set
	local function stack(name, color, material, count)
		local list = {}
		for i = 1, count do
			table.insert(list, K.part({ Name = name .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 1, 1), Color = color, Material = material, Transparency = 1 }, colFolder))
		end
		return list
	end
	G.ColCore = stack("Core", Color3.fromRGB(245, 235, 255), Enum.Material.Neon, 4)
	G.ColMid = stack("Mid", Color3.fromRGB(175, 95, 255), Enum.Material.Neon, 4)
	G.ColShell = stack("Shell", Color3.fromRGB(205, 140, 255), Enum.Material.ForceField, 4)
	local colHost = K.part({ Name = "ColumnHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(G.ColBase) }, colFolder)
	G.ColHost = colHost
	-- rings that race up the column
	G.ColRings = {}
	for i = 1, 7 do
		table.insert(G.ColRings, (K.quad(colHost, CFrame.new(G.ColBase), 1, 1, "18823306900", { Color = Color3.fromRGB(230, 200, 255), Brightness = 2.5, Transparency = 1 })))
	end
	-- a triple helix of energy winding up the column
	G.Helix = {}
	for strand = 1, 3 do
		local segs = {}
		for _ = 1, 18 do
			local b = K.ray(colHost, G.ColBase, G.ColBase + Vector3.new(0, 1, 0), 5, 5, "1053548563", {
				Color = strand == 2 and Color3.fromRGB(255, 220, 255) or Color3.fromRGB(190, 110, 255), Brightness = 4, Segments = 1,
			})
			b.Enabled = false
			table.insert(segs, b)
		end
		table.insert(G.Helix, segs)
	end
	-- sparks streaming up
	local sparkHost = K.part({ Name = "SparkHost", Size = Vector3.new(COL_R * 1.4, 4, COL_R * 1.4), Transparency = 1, CFrame = CFrame.new(G.ColBase + Vector3.new(0, 4, 0)) }, colFolder)
	G.SparkHost = sparkHost
	G.Sparks = K.emitter(sparkHost, {
		Texture = "1053548563", Color = ColorSequence.new(Color3.fromRGB(245, 225, 255), Color3.fromRGB(170, 90, 255)), Size = K.ns(0, 3, 1, 0.5),
		Lifetime = NumberRange.new(1.4, 2.2), Speed = NumberRange.new(260, 460), Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = K.ns(0, 4), Brightness = 5, EmissionDirection = Enum.NormalId.Top,
	})
	local cl = Instance.new("PointLight")
	cl.Color = Color3.fromRGB(190, 130, 255)
	cl.Range = 0
	cl.Brightness = 10
	cl.Parent = sparkHost
	G.ColLight = cl
	-- the beam lights up the field around its base
	G.BaseLights = {}
	for i = 1, 6 do
		local a = i / 6 * 2 * pi
		local lh = K.part({ Name = "BaseLight" .. i, Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(G.ColBase + Vector3.new(math.cos(a) * 70, 6, math.sin(a) * 70)) }, colFolder)
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(200, 140, 255)
		l.Range = 0
		l.Brightness = 4
		l.Shadows = false
		l.Parent = lh
		table.insert(G.BaseLights, l)
	end
	G.RideHL = {}
	-- riders show as silhouettes inside the glare of the beam
	function G.rideHL(alpha)
		for _, h in ipairs(G.RideHL) do
			h.Enabled = alpha > 0.02
			h.FillTransparency = 1 - 0.7 * alpha
			h.OutlineTransparency = 1 - alpha
		end
	end

	-- lay the column out from y0 to y1 at a given size (0..1) and alpha
	function G.column(y0, y1, size, alpha, t)
		size = size or 1
		alpha = alpha or 1
		local len = math.max(y1 - y0, 0.1)
		local n = math.clamp(math.ceil(len / 2000), 1, 4)
		local seg = len / n
		local wob = 1 + math.sin(t * 38) * 0.04
		local function lay(list, radius, tr, spin)
			for i, p in ipairs(list) do
				if i <= n and alpha > 0.01 and size > 0.01 then
					local cy = y0 + seg * (i - 0.5)
					p.Size = Vector3.new(seg + 0.5, radius * 2, radius * 2)
					p.CFrame = CFrame.new(G.ColBase.X, cy, G.ColBase.Z) * CFrame.Angles(0, t * spin, pi / 2)
					p.Transparency = 1 - (1 - tr) * alpha
				else
					p.Transparency = 1
				end
			end
		end
		lay(G.ColCore, COL_R * 0.24 * size * wob, 0.05, 0)
		lay(G.ColMid, COL_R * 0.5 * size * wob, 0.68, 0)
		lay(G.ColShell, COL_R * size, 0.1, 0.6)
		G.rideHL(alpha * math.min(size * 2, 1))
	end
	function G.hideColumn()
		for _, l in ipairs({ G.ColCore, G.ColMid, G.ColShell }) do for _, p in ipairs(l) do p.Transparency = 1 end end
		for _, r in ipairs(G.ColRings) do r.Transparency = NumberSequence.new(1) end
		for _, s in ipairs(G.Helix) do for _, b in ipairs(s) do b.Enabled = false end end
		G.Sparks.Rate = 0
		G.ColLight.Range = 0
		for _, l in ipairs(G.BaseLights) do l.Range = 0 end
		G.rideHL(0)
	end
	-- rings + helix near a focus height (only drawn where the camera is)
	function G.columnFX(t, focusY, alpha)
		for i, r in ipairs(G.ColRings) do
			local span = 900
			local y = focusY - 300 + ((i / #G.ColRings) * span + t * 520) % span
			local s = COL_R * 2.6 * (0.9 + 0.1 * math.sin(t * 5 + i))
			K.setQuadSize(r, s, s)
			K.moveQuad(r, CFrame.new(G.ColBase.X, y, G.ColBase.Z) * CFrame.Angles(-pi / 2, 0, t * 2 + i))
			r.Transparency = NumberSequence.new(1 - 0.75 * alpha)
		end
		for strand, segs in ipairs(G.Helix) do
			local base = strand / 3 * 2 * pi
			local function pt(k)
				local y = focusY - 260 + k * 34
				local a = base + y * 0.02 - t * 5
				local r = COL_R * 0.72
				return Vector3.new(G.ColBase.X + math.cos(a) * r, y, G.ColBase.Z + math.sin(a) * r)
			end
			for i, b in ipairs(segs) do
				b.Enabled = alpha > 0.02
				b.Attachment0.WorldPosition = pt(i - 1)
				b.Attachment1.WorldPosition = pt(i)
				b.Transparency = NumberSequence.new(1 - alpha * 0.9)
			end
		end
	end

	----------------------------------------------------------------
	-- sky: storm deck + lightning + birds
	----------------------------------------------------------------
	-- (a dome of cloud, not a slab: from below it sags into a round, bellied ceiling)
	local deck = K.part({ Name = "StormDeck", Size = Vector3.new(1800, 220, 1800), Transparency = 1, CFrame = CFrame.new(G.PortalPos.X, ground + 470, G.PortalPos.Z + 150) }, set)
	G.StormDeck = deck
	G.Storm = K.domeEmitter(deck, {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(95, 70, 140), Color3.fromRGB(55, 35, 90)), Size = K.ns(0, 140, 0.5, 230, 1, 280),
		Transparency = K.ns(0, 1, 0.2, 0.25, 0.8, 0.35, 1, 1), Lifetime = NumberRange.new(9, 12), Speed = NumberRange.new(1, 4),
		EmissionDirection = Enum.NormalId.Bottom, LightEmission = 0.15, LightInfluence = 0.6,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-8, 8),
	})
	-- a swirl of cloud dragged round the portal
	local swirlHost = K.part({ Name = "SwirlHost", Size = Vector3.new(320, 320, 1), Transparency = 1, CFrame = portalCF }, set)
	G.Swirl = K.emitter(swirlHost, {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(150, 110, 210)), Size = K.ns(0, 60, 1, 150),
		Transparency = K.ns(0, 1, 0.25, 0.35, 1, 1), Lifetime = NumberRange.new(3, 4.5), Speed = NumberRange.new(-60, -30),
		Shape = Enum.ParticleEmitterShape.Disc, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Front,
		LightEmission = 0.3, LightInfluence = 0.4, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, -20),
	})
	G.Bolts = Instance.new("Folder")
	G.Bolts.Name = "Bolts"
	G.Bolts.Parent = set
	-- seagulls
	G.Birds = {}
	local brng = Random.new(9)
	local gull = K.Assets:FindFirstChild("Gull")
	for _ = 1, 14 do
		local m = gull:Clone()
		local sc = brng:NextNumber(0.7, 1.1)
		m:ScaleTo(sc)
		m.Parent = set
		local body = m:FindFirstChild("Body")
		local lw, rw = m:FindFirstChild("LeftWing"), m:FindFirstChild("RightWing")
		table.insert(G.Birds, {
			Model = m, Body = body, L = lw, R = rw,
			LRel = body.CFrame:ToObjectSpace(lw.CFrame), RRel = body.CFrame:ToObjectSpace(rw.CFrame),
			Root = 0.9 * sc,
			Home = (M * CFrame.new(brng:NextNumber(-140, 140), brng:NextNumber(35, 90), brng:NextNumber(-160, 60))).Position,
			Phase = brng:NextNumber(0, 6), Radius = brng:NextNumber(14, 36), Speed = brng:NextNumber(0.25, 0.45) * (brng:NextNumber() < 0.5 and -1 or 1),
			Flee = Vector3.new(brng:NextNumber(-1, 1), brng:NextNumber(0.35, 0.8), brng:NextNumber(0.3, 1)).Unit,
		})
	end

	----------------------------------------------------------------
	-- THE LIFT: the hand's shockwave tears the meadow loose. Trees, bushes,
	-- rocks, crates, the shop stalls, flowers and clumps of turf all float up
	-- with the party, slowly at first, then flung skyward and tumbling.
	----------------------------------------------------------------
	local liftSet = Instance.new("Folder")
	liftSet.Name = "Lift"
	liftSet.Parent = set
	G.Lift = {}
	local lrng = Random.new(505)
	local axis = G.ColBase
	local function addLift(obj, orig, big)
		local cf = obj:IsA("Model") and obj:GetPivot() or obj.CFrame
		local rel = Vector3.new(cf.X - axis.X, 0, cf.Z - axis.Z)
		local dist = rel.Magnitude
		local d = {
			Obj = obj, Orig = orig, Base = cf, Big = big,
			R = dist, Ang = math.atan2(rel.Z, rel.X), Y0 = cf.Y - ground,
			-- the shock rolls outward from the beam: near things go first
			Delay = 0.1 + dist / 240 + lrng:NextNumber(0, 0.35),
			Rate = lrng:NextNumber(0.78, 1.1), Factor = lrng:NextNumber(0.55, 1.02),
			Swirl = lrng:NextNumber(0.25, 0.7) * (lrng:NextNumber() < 0.8 and 1 or -1),
			SpinAxis = lrng:NextUnitVector(), SpinRate = lrng:NextNumber(0.5, 2.2) * (big and 0.45 or 1),
			Keep = lrng:NextNumber(0.62, 1.02),
		}
		table.insert(G.Lift, d)
		return d
	end
	local function prepClone(src)
		local c = src:Clone()
		for _, x in ipairs(c:GetDescendants()) do
			if x:IsA("BasePart") then
				x.Anchored = true
				x.CanCollide = false
				x.CanQuery = false
				x.CanTouch = false
				x.LocalTransparencyModifier = 0
			elseif x:IsA("LuaSourceContainer") or x:IsA("ProximityPrompt") or x:IsA("ClickDetector") or x:IsA("BillboardGui") then
				x:Destroy()
			end
		end
		if c:IsA("BasePart") then
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.LocalTransparencyModifier = 0
		end
		c.Parent = liftSet
		return c
	end

	-- (1 and 2 are gathered when the chapter starts, not here: the map streams in
	-- round the meadow only once the party is standing in it)
	function G.gatherMeadow()
	if G.Gathered then return end
	G.Gathered = true
	-- 1. whatever is really standing on the meadow round the beam
	local map = workspace:FindFirstChild("LaPeaceMap")
	local LIFT_R = 155
	if map then
		local picked = { flower = 0, tuft = 0 }
		local cands = {}
		for _, x in ipairs(map:GetDescendants()) do
			local n = x.Name:lower()
			local kind
			if x:IsA("Model") and (n == "bush" or n == "wood crate" or n == "lantern" or n == "flower" or n == "tuft" or ((n == "buy" or n == "sell") and x:FindFirstChild("GearShop", true))) then
				kind = n
			elseif x:IsA("BasePart") and n:match("^rock%d") then
				kind = "rock"
			end
			if kind and not x:FindFirstChildWhichIsA("Humanoid", true) then
				local ok, cf = pcall(function() return x:IsA("Model") and x:GetPivot() or x.CFrame end)
				if ok then
					local dist = Vector3.new(cf.X - axis.X, 0, cf.Z - axis.Z).Magnitude
					if dist < LIFT_R and math.abs(cf.Y - ground) < 30 then
						table.insert(cands, { X = x, Kind = kind, D = dist })
					end
				end
			end
		end
		table.sort(cands, function(a, b) return a.D < b.D end)
		for _, c in ipairs(cands) do
			local cap = (c.Kind == "flower" or c.Kind == "tuft") and 34 or 999
			picked[c.Kind] = (picked[c.Kind] or 0) + 1
			if picked[c.Kind] <= cap then
				local big = c.Kind == "buy" or c.Kind == "sell" or c.Kind == "bush"
				local clone = prepClone(c.X)
				for _, x in ipairs(clone:IsA("BasePart") and { clone } or clone:GetDescendants()) do
					if x:IsA("BasePart") then x.LocalTransparencyModifier = 1 end
				end
				addLift(clone, c.X, big)
			end
		end
	end

	-- 2. a handful of trees round the field (they stand there all along)
	local treeSrc
	if map then
		for _, x in ipairs(map:GetDescendants()) do
			if x:IsA("Model") and (x.Name == "Tree" or x.Name == "Trees") then
				local _, s = x:GetBoundingBox()
				if s.Y > 12 and s.Y < 60 then treeSrc = x break end
			end
		end
	end
	G.Trees = {}
	if treeSrc then
		-- (none on the party's side of the hand, where the cameras look from)
		local angs = { 200, 232, 262, 300, 330, 356, 18, 150, 125 }
		for i, deg in ipairs(angs) do
			local a = math.rad(deg + lrng:NextNumber(-8, 8))
			local rr = lrng:NextNumber(96, 150)
			local tree = prepClone(treeSrc)
			pcall(function() tree:ScaleTo(tree:GetScale() * lrng:NextNumber(1.35, 1.9)) end)
			local cf, s = tree:GetBoundingBox()
			local bottom = cf.Y - s.Y / 2
			local pivot = tree:GetPivot()
			local pos = Vector3.new(axis.X + math.cos(a) * rr, ground + (pivot.Y - bottom) - 0.6, axis.Z + math.sin(a) * rr)
			tree:PivotTo(CFrame.new(pos) * CFrame.Angles(0, lrng:NextNumber(0, 2 * pi), 0))
			local d = addLift(tree, nil, true)
			table.insert(G.Trees, d)
		end
	end
	-- dirt and grass crumbling off anything big as it lifts
	for _, d in ipairs(G.Lift) do
		if d.Big and not d.Crumble then
			local hostPart = d.Obj:IsA("Model") and (d.Obj.PrimaryPart or d.Obj:FindFirstChildWhichIsA("BasePart", true)) or d.Obj
			if hostPart then
				d.Crumble = K.emitter(hostPart, {
					Texture = "17000879366", Color = ColorSequence.new(Color3.fromRGB(110, 88, 62), Color3.fromRGB(80, 110, 50)), Size = K.ns(0, 0.9, 1, 0.4),
					Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(1, 4), Acceleration = Vector3.new(0, -40, 0),
					LightEmission = 0, LightInfluence = 1, Brightness = 1, SpreadAngle = Vector2.new(180, 180),
				})
			end
		end
	end
	end -- G.gatherMeadow

	-- 3. clumps of turf and rock ripped straight out of the ground
	local rockSrc = K.Assets.Rocks:GetChildren()
	for i = 1, 26 do
		local r = rockSrc[lrng:NextInteger(1, #rockSrc)]:Clone()
		local k = lrng:NextNumber(2.5, 8)
		r.Size = r.Size / math.max(r.Size.X, r.Size.Y, r.Size.Z) * k
		r.Anchored = true
		r.CanCollide = false
		r.CanQuery = false
		r.CanTouch = false
		r.Color = (i % 3 == 0) and Color3.fromRGB(86, 128, 58) or Color3.fromRGB(104, 84, 62)
		r.Material = (i % 3 == 0) and Enum.Material.Grass or Enum.Material.Ground
		local a = lrng:NextNumber(0, 2 * pi)
		local rr = lrng:NextNumber(24, 145)
		r.CFrame = CFrame.new(axis.X + math.cos(a) * rr, ground - k * 0.3, axis.Z + math.sin(a) * rr) * CFrame.Angles(lrng:NextNumber(0, 6), lrng:NextNumber(0, 6), 0)
		r.Transparency = 1 -- they only exist once they're torn loose
		r.Parent = liftSet
		local d = addLift(r, nil, k > 6)
		d.Hidden = true
	end

	-- a ring of dust torn up where the ground lets go
	local tearHost = K.part({ Name = "TearHost", Size = Vector3.new(300, 4, 300), Transparency = 1, CFrame = CFrame.new(axis + Vector3.new(0, 2, 0)) }, set)
	G.Tear = K.emitter(tearHost, {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(150, 135, 115)), Size = K.ns(0, 8, 1, 26),
		Transparency = K.ns(0, 0.5, 0.6, 0.75, 1, 1), Lifetime = NumberRange.new(2, 3.2), Speed = NumberRange.new(6, 18),
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top,
		LightEmission = 0, LightInfluence = 1, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20), Acceleration = Vector3.new(0, 12, 0),
	})

	local function spinAngle(d, li)
		-- the spin builds with the speed of the rise
		if li < 2.5 then return d.SpinRate * 0.22 * li * li end
		return d.SpinRate * (0.22 * 6.25 + 1.1 * (li - 2.5))
	end
	-- place one lifted thing at launch clock lt (lt < 0: still on the ground)
	function G.liftPlace(d, lt, t)
		local li = lt - d.Delay
		if li <= 0 then
			if d.Hidden then return end
			-- the charge makes everything loose buzz before it goes
			local buzz = (t and t > T_CHARGE) and K.k(t, T_CHARGE, T_FIRE) * 0.12 or 0
			local cf = d.Base + Vector3.new(math.noise(t or 0, d.R, 1), math.noise(t or 0, d.R, 2), math.noise(t or 0, d.R, 3)) * buzz
			if d.Obj:IsA("Model") then d.Obj:PivotTo(cf) else d.Obj.CFrame = cf end
			return
		end
		if not d.Loose then
			d.Loose = true
			if d.Orig then
				for _, x in ipairs(d.Orig:IsA("BasePart") and { d.Orig } or d.Orig:GetDescendants()) do
					if x:IsA("BasePart") then x.LocalTransparencyModifier = 1 end
				end
			end
			if d.Hidden then d.Obj.Transparency = 0 end
			if d.Orig then
				for _, x in ipairs(d.Obj:IsA("BasePart") and { d.Obj } or d.Obj:GetDescendants()) do
					if x:IsA("BasePart") then x.LocalTransparencyModifier = 0 end
				end
			end
			if d.Crumble then d.Crumble.Rate = 22 end
			G.Tear.Parent.CFrame = CFrame.new(axis.X + math.cos(d.Ang) * d.R, ground + 2, axis.Z + math.sin(d.Ang) * d.R)
			G.Tear:Emit(d.Big and 6 or 2)
		end
		if d.Crumble then d.Crumble.Rate = li < 2.2 and 22 or 0 end
		local rise = (ctx.TL.LaunchY(li * d.Rate) - 3) * d.Factor + li * 0.9
		local pull = K.k(rise, 0, 320) * 0.35
		local ang = d.Ang + d.Swirl * 0.35 * li * K.k(li, 0.6, 3.5)
		local rr = d.R * (1 - pull)
		local pos = Vector3.new(axis.X + math.cos(ang) * rr, ground + d.Y0 + rise, axis.Z + math.sin(ang) * rr)
		local cf = CFrame.new(pos) * CFrame.fromAxisAngle(d.SpinAxis, spinAngle(d, li)) * (d.Base - d.Base.Position)
		if d.Obj:IsA("Model") then d.Obj:PivotTo(cf) else d.Obj.CFrame = cf end
		d.Last = { Pos = pos, Ang = ang, R = rr, Li = li, Y = pos.Y }
	end
	-- after the hand-over (Launch chapter): the ones that kept up drift with the party
	-- a while, then fall away below. off = altitude gained since the hand-over
	function G.liftContinue(d, t, off)
		local L = d.Last
		if not L or d.Gone then return end
		local li = L.Li + t
		local y = L.Y + off * d.Keep - 40 * t * t * (1.05 - d.Keep)
		local ang = L.Ang + d.Swirl * 0.35 * t
		local pos = Vector3.new(axis.X + math.cos(ang) * L.R, y, axis.Z + math.sin(ang) * L.R)
		local cf = CFrame.new(pos) * CFrame.fromAxisAngle(d.SpinAxis, spinAngle(d, li)) * (d.Base - d.Base.Position)
		if d.Obj:IsA("Model") then d.Obj:PivotTo(cf) else d.Obj.CFrame = cf end
		return y
	end
	function G.liftDone(d)
		d.Gone = true
		if d.Obj:IsA("Model") then d.Obj:PivotTo(CFrame.new(0, -5000, 0)) else d.Obj.CFrame = CFrame.new(0, -5000, 0) end
	end

	----------------------------------------------------------------
	-- low dome clouds you rise up through (below the storm deck)
	----------------------------------------------------------------
	G.LowClouds = {}
	local crng2 = Random.new(808)
	for i = 1, 16 do
		local a = i / 16 * 2 * pi + crng2:NextNumber(-0.2, 0.2)
		local rr = (i % 3 == 0) and crng2:NextNumber(20, 70) or crng2:NextNumber(110, 360)
		local h = K.lerp(150, 420, (i - 1) / 15) + crng2:NextNumber(-20, 20)
		local w = crng2:NextNumber(70, 150)
		local c = K.cloud(set, CFrame.new(axis.X + math.cos(a) * rr, ground + h, axis.Z + math.sin(a) * rr), w, crng2, {
			Color = Color3.fromRGB(236, 234, 246), Shade = Color3.fromRGB(168, 160, 196),
		})
		table.insert(G.LowClouds, c)
	end
end

--------------------------------------------------------------------------
-- lightning
--------------------------------------------------------------------------
local function bolt(ctx, from, to, color, width, branches)
	local K = ctx.kit
	local pts = { from }
	local n = 9
	for i = 1, n - 1 do
		local p = from:Lerp(to, i / n)
		local off = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (from - to).Magnitude * 0.13
		table.insert(pts, p + off)
	end
	table.insert(pts, to)
	local parts = {}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local w = width * (1 - i / (#pts + 2))
		table.insert(parts, K.part({ Size = Vector3.new(w, w, (a - b).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Material = Enum.Material.Neon, Color = color }, ctx.G.Bolts))
		if branches and math.random() < 0.3 then
			local e = b + Vector3.new(math.random(-40, 40), -math.random(20, 60), math.random(-40, 40))
			table.insert(parts, K.part({ Size = Vector3.new(w * 0.5, w * 0.5, (e - b).Magnitude), CFrame = CFrame.lookAt((b + e) / 2, e), Material = Enum.Material.Neon, Color = color }, ctx.G.Bolts))
		end
	end
	task.delay(0.08, function()
		for _, p in ipairs(parts) do K.tween(p, 0.18, { Transparency = 1 }) end
		task.delay(0.22, function() for _, p in ipairs(parts) do p:Destroy() end end)
	end)
end

--------------------------------------------------------------------------
-- the chapter
--------------------------------------------------------------------------
function Ch.Grass(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local G = ctx.G
	local set = ctx.sets.Grass
	set.Parent = ctx.stage
	local M = ctx.TL.Meadow
	local ground = G.Ground

	K.lighting("Day", 0)
	K.Rays.Enabled = true
	K.Rays.Intensity = 0.06
	K.Rays.Spread = 0.8
	K.fade(1, 0)
	K.fade(0, 1.4)
	K.letterbox(true, 1)
	local meadow = K.loop(K.S.Meadow, 0.4, 2)
	local birdsSnd = K.loop(K.S.Birds, 0.35, 2)
	ctx.setMusic(K.S.M_Andromeda, 0.35, 2)
	K.stream(M.Position)
	-- the trees, stalls, bushes and flowers that get torn up later
	G.gatherMeadow()

	-- hide the arm until it's needed
	G.Hand.Transparency = 1
	G.Lower.Transparency = 1
	G.Upper.Transparency = 1
	G.hideColumn()

	-- rigs: plans, starting positions
	local plans = {}
	local gatherFrom = {}
	for slot, rig in pairs(ctx.rigs) do
		rig.Model.Parent = ctx.stage
		rig:clearPose()
		rig:stopAll(0)
		rig.Smooth = 12
		plans[slot] = makePlan(ctx, slot)
		local s = evalPlan(plans[slot], 0)
		local p = planPos(s, 0)
		rig.Yaw = s.FaceYaw or 0
		rig:setCF(CFrame.new(p + Vector3.new(0, 3, 0)) * CFrame.Angles(0, rig.Yaw, 0))
		rig:loco(0)
		-- the spot each one runs back to when the sky turns
		rig.GatherDelay = 0.5 + (slot % 4) * 0.15
		local tg = T_STORM + rig.GatherDelay
		gatherFrom[slot] = planPos(evalPlan(plans[slot], tg), tg)
		rig.Gather = (M * CFrame.new(GATHER[((slot - 1) % #GATHER) + 1])).Position
		rig.GatherDur = math.max((rig.Gather - gatherFrom[slot]).Magnitude / 11, 0.8)
	end
	local me = ctx.myRig
	local cue = K.once()
	local lastBolt = 0
	local stormOn = false
	local portalCF = G.PortalCF
	local portalPos = G.PortalPos

	local function launchY(lt)
		return ground + ctx.TL.LaunchY(lt)
	end
	ctx.LaunchY = launchY

	local function armAt(t)
		-- how far the wrist has come out of the portal
		if t < T_ARM then return -200 end
		local e = K.k(t, T_ARM, T_SLAM, E.inCubic)
		return K.lerp(-70, G.OutFinal, e)
	end

	K.run(t0, dur, function(t, dt)
		local lt = t - (T_FIRE + 0.25)
		----------------------------------------------------------------
		-- the party
		----------------------------------------------------------------
		for slot, rig in pairs(ctx.rigs) do
			local plan = plans[slot]
			local pos, speed, wantYaw, sit = nil, 0, rig.Yaw, 0
			local locoSpeed
			local pose = {}
			local lookAt
			if t < T_STORM + rig.GatherDelay then
				local s = evalPlan(plan, t)
				pos = planPos(s, t)
				if s.Kind == "Walk" then
					rig:action(nil, 0.35)
					if t < s.T0 + TURN then
						-- turning on the spot toward where they're headed: small shuffle steps
						wantYaw = s.Yaw0
						local left = math.abs((s.Yaw0 - (rig.Yaw or s.Yaw0) + pi) % (2 * pi) - pi)
						locoSpeed = left > 0.25 and 3 or 0
						lookAt = pos + Vector3.new(0, 4.5, 0) + Vector3.new(-math.sin(s.Yaw0), 0, -math.cos(s.Yaw0)) * 20
					else
						local ahead = planPos(s, math.min(t + 0.08, s.T1))
						local v = ahead - pos
						speed = v.Magnitude / 0.08
						if v.Magnitude > 0.01 then wantYaw = math.atan2(-v.X, -v.Z) end
						lookAt = pos + Vector3.new(0, 4.5, 0) + (v.Magnitude > 0.01 and v.Unit * 20 or Vector3.zero)
					end
				else
					wantYaw = s.FaceYaw
					local anim = s.Anim
					if anim == "Sit" then
						sit = K.k(t, s.T0, s.T0 + 0.6) * (1 - K.k(t, s.T1 - 0.6, s.T1))
						rig:action(sit > 0.3 and "Sit" or nil, 0.35)
					elseif anim == "Look" then
						rig:action(nil, 0.35)
						pose.Neck = K.A(8 + math.sin(t * 0.7) * 6, math.sin((t - s.T0) * 1.3) * 60, 0)
					else
						-- stop the dance a beat before walking off again
						rig:action((t < s.T1 - 0.35) and anim or nil, 0.35)
					end
					-- hang out with whoever is nearest
					if anim ~= "Look" then
						local best, bd
						for _, other in pairs(ctx.rigs) do
							if other ~= rig then
								local d = (other:cf().Position - pos).Magnitude
								if not bd or d < bd then bd, best = d, other end
							end
						end
						if best and bd < 26 then
							local op = best:cf().Position
							wantYaw = math.atan2(-(op.X - pos.X), -(op.Z - pos.Z))
							lookAt = best:head() and best:head().Position
						end
					end
				end
			else
				-- the sky turns: everyone jogs back together, facing where the portal opens
				rig:action(nil, 0.3)
				local tt = t - (T_STORM + rig.GatherDelay)
				local u = trapezoid(tt, rig.GatherDur, 0.4)
				local from = gatherFrom[slot]
				pos = from:Lerp(rig.Gather, u)
				local v = rig.Gather - from
				if tt < rig.GatherDur then
					local u2 = trapezoid(tt + 0.05, rig.GatherDur, 0.4)
					speed = (u2 - u) * v.Magnitude / 0.05
					if v.Magnitude > 0.1 then wantYaw = math.atan2(-v.X, -v.Z) end
				else
					local fwd = portalPos - pos
					wantYaw = math.atan2(-fwd.X, -fwd.Z)
				end
				lookAt = (t > T_SLAM + 1.2) and G.PalmGlow.Position or portalPos
			end
			-- turn smoothly toward where they're going
			-- (faster than before, so nobody walks sideways while still turning)
			rig.Yaw = lerpAngle(rig.Yaw or wantYaw, wantYaw, 1 - math.exp(-11 * dt))
			-- (no fake bob: the walk cycle already moves the body; a second bob on the
			-- root made everyone look like they were floating along)
			local cf = CFrame.new(pos + Vector3.new(0, 3 - sit * 1.45, 0)) * CFrame.Angles(0, rig.Yaw, 0)
			-- lean into the walk, bank a little into turns
			local turnRate = 0
			if rig.PrevYaw and dt > 0 then turnRate = ((rig.Yaw - rig.PrevYaw + pi) % (2 * pi) - pi) / dt end
			rig.PrevYaw = rig.Yaw
			pose.Root = K.A(-math.min(speed, 12) * 0.3, 0, math.clamp(turnRate * 2, -4, 4))

			-- reacting to the world
			if t >= T_STORM + rig.GatherDelay then
				pose = K.mixPose(pose, K.Poses.LookUp, K.k(t, T_PORTAL - 0.8, T_PORTAL + 0.8) * 0.6)
				if t > T_ARM + 1.2 and t < T_SLAM then
					pose = K.mixPose(pose, K.Poses.Brace, K.k(t, T_ARM + 1.2, T_SLAM - 0.3) * 0.8)
				end
			end
			if t >= T_SLAM and t < T_FIRE + 0.25 then
				-- the slam knocks everyone off balance
				local st = t - T_SLAM
				local falls = slot % 3 == 1
				local shove = (1 - math.exp(-st * 6)) * (falls and 5 or 3)
				cf = cf + (-M.LookVector) * shove
				if falls then
					local keys = { { 0, K.Poses.Brace }, { 0.35, K.Poses.Kneel }, { 1.2, K.Poses.Kneel }, { 1.9, K.Poses.Brace } }
					pose = K.mixPose(pose, K.posePath(keys, st), 1)
					local down = K.k(st, 0.1, 0.4, E.outQuad) * (1 - K.k(st, 1.2, 1.9))
					cf = cf * CFrame.new(0, -1.6 * down, 0) * CFrame.Angles(math.rad(12) * down, 0, 0)
				else
					local sway = math.exp(-st * 2.5)
					pose = K.mixPose(pose, K.Poses.Brace, 0.9)
					cf = cf * CFrame.Angles(math.rad(-14) * sway * math.sin(st * 9), 0, math.rad(8) * sway * math.sin(st * 7 + slot))
				end
				if t > T_CHARGE then
					local tr = K.k(t, T_CHARGE, T_FIRE)
					pose = K.mixPose(pose, K.Poses.Brace, 0.7 + tr * 0.3)
					pose.Root = (pose.Root or CFrame.new()) * K.A(-10 * tr + math.noise(t * 12, slot) * 4, 0, math.noise(t * 11, slot, 3) * 4)
					cf = cf * CFrame.new(0, tr * tr * 1.2, 0)
				end
			end
			if not rig.LaunchFrom and lt >= 0 then
				rig.LaunchFrom = cf.Position
				rig.LaunchYaw = rig.Yaw
				rig.LiftPose = pose
			end
			if lt >= 0 then
				-- LIFT-OFF. First the beam just... takes their weight: feet leave the grass,
				-- a slow, eerie float with arms drifting up and legs dangling. Then it builds,
				-- and builds, into a violent rise where nobody has any control at all.
				local startP = rig.LaunchFrom
				local y = startP.Y + (ctx.TL.LaunchY(lt) - 3)
				local wild = K.k(lt, 1.2, 3.9, E.inQuad)          -- how out of control they are
				local drift = K.k(lt, 0.9, 4.6, E.inOutSine)       -- pulled into the spiral round the beam
				local ang = slot * 2.1 + lt * (0.7 + slot * 0.06)
				local r = 20 + (slot % 4) * 9
				local orbitP = Vector3.new(G.ColBase.X + math.cos(ang) * r, y, G.ColBase.Z + math.sin(ang) * r)
				-- a little sway while they still hang there
				local sway = Vector3.new(math.noise(lt * 0.9, slot, 1), 0, math.noise(lt * 0.9, slot, 2)) * 0.8 * (1 - wild)
				local p = Vector3.new(startP.X, y, startP.Z):Lerp(orbitP, drift) + sway
				-- upright and bewildered -> tumbling end over end
				local calmRot = CFrame.Angles(0, rig.LaunchYaw or 0, 0)
					* CFrame.Angles(math.rad(6) * math.sin(lt * 1.3 + slot), 0, math.rad(5) * math.sin(lt * 1.1 + slot * 2))
				local wildRot = CFrame.Angles(math.sin(lt * 2 + slot) * 0.6 + 0.4, lt * (1.4 + slot * 0.15), math.cos(lt * 1.6 + slot) * 0.5)
				cf = CFrame.new(p) * calmRot:Lerp(wildRot, wild)
				-- the pose: from bracing, arms float up and out, head down at the ground
				-- dropping away... then limbs thrown about by the rush
				local float = K.mixPose(rig.LiftPose or K.Poses.Brace, K.Poses.LiftOff, K.k(lt, 0, 1.1))
				float = K.mixPose(float, K.flail(t * 0.35, slot, 0.25, float), 1)
				pose = K.mixPose(float, K.flail(t, slot, 0.3 + 0.8 * wild, K.Poses.Launch), wild)
				-- (no hands through the head: flailing limbs stay where a body can put them)
				pose = K.safeArms(pose)
				lookAt = nil
				rig.Smooth = K.lerp(6, 12, wild)
				if rig.LocoMode ~= "Air" then
					rig:stopAll(0.35)
					rig.LocoMode = "Air"
				end
				-- (no Fall animation on top: it throws the arms up over the head and,
				-- stacked on the procedural pose, pushed the hands into the face)
			else
				rig:loco(locoSpeed or speed)
			end
			if lookAt and rig:head() then
				pose.Neck = (pose.Neck or CFrame.new()) * rig:lookRot(lookAt, 0.85)
			end
			rig:setCF(cf)
			rig:setPose(pose)
			rig:apply()
		end

		----------------------------------------------------------------
		-- seagulls: lazy circles, then they scatter
		----------------------------------------------------------------
		local flee = K.k(t, T_STORM - 0.4, T_STORM + 4, E.inQuad)
		for i, b in ipairs(G.Birds) do
			local a = t * b.Speed + b.Phase
			local p = b.Home + Vector3.new(math.cos(a) * b.Radius, math.sin(a * 1.3) * 3, math.sin(a) * b.Radius)
			local fwd = Vector3.new(-math.sin(a), 0, math.cos(a)) * math.sign(b.Speed)
			if flee > 0 then
				p = p + b.Flee * flee * 520
				fwd = fwd:Lerp(b.Flee, math.min(1, flee * 5))
			end
			local gliding = flee == 0 and math.sin(t * 0.8 + i) > 0.3
			local flap = gliding and math.sin(t * 2 + i) * 0.08 or math.sin(t * (flee > 0 and 20 or 9) + i) * 0.75
			local bank = flee > 0 and 0 or -0.35 * math.sign(b.Speed)
			local cf = CFrame.lookAt(p, p + fwd) * CFrame.Angles(0, 0, bank)
			b.Body.CFrame = cf
			local r = b.Root
			b.L.CFrame = cf * CFrame.new(-r, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(r, 0, 0) * b.LRel
			b.R.CFrame = cf * CFrame.new(r, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-r, 0, 0) * b.RRel
		end

		----------------------------------------------------------------
		-- the sky turns
		----------------------------------------------------------------
		cue("storm", t >= T_STORM, function()
			K.lighting("Storm", 2.4)
			K.Rays.Enabled = false
			K.sfx(K.S.Tunnel, 0.5, 0.7)
			K.sfx(K.S.Rumble, 0.8)
			K.sfx(K.S.DarkDrone, 0.5, 0.9)
			K.fadeSound(meadow, 0, 2, true)
			K.fadeSound(birdsSnd, 0, 1.2, true)
			ctx.setMusic(K.S.M_Doom, 0.55, 2.5)
			K.shake(0.5, 2.5, 8)
			stormOn = true
			G.Storm.Rate = 26
			G.Storm:Emit(90)
		end)
		local open = K.k(t, T_PORTAL, T_PORTAL + 2.2, E.outBack)
		local spin = t * 0.9
		for i, b in ipairs(G.PortalRings) do
			local s = (i == 2 and 120 or (250 - i * 14)) * open * (1 + math.sin(t * 3 + i) * 0.03)
			K.setQuadSize(b, s, s)
			K.moveQuad(b, portalCF * CFrame.new(0, 0, -i * 0.7) * CFrame.Angles(0, pi, spin * (i % 2 == 0 and -1 or 1) * (0.5 + i * 0.25)))
		end
		G.PortalCore.Size = Vector3.new(0.4, 150 * open, 150 * open)
		G.PortalCore.Transparency = open > 0.02 and 0 or 1
		G.PortalSuck.Rate = open > 0.2 and 70 or 0
		G.PortalArcs.Rate = open > 0.2 and 40 or 0
		G.Swirl.Rate = open > 0.1 and 16 or 0
		G.PortalLight.Range = 60 * open
		cue("portal", t >= T_PORTAL, function()
			K.sfx(K.S.Portal, 1, 0.75)
			K.sfx(K.S.Portal2, 0.7, 0.7)
			K.sfx(K.S.Thunder, 0.9)
			K.flash(0.6, Color3.fromRGB(200, 150, 255), 0.6)
			K.shake(1.4, 1.6)
			K.kick(8, 0.8)
			G.Swirl:Emit(40)
		end)
		if stormOn and t - lastBolt > 0.3 and t < T_FIRE + 1 then
			lastBolt = t + math.random() * 0.45
			local a = math.random() * 2 * pi
			local from = portalPos + Vector3.new(math.cos(a) * 110, math.random(40, 140), math.sin(a) * 110)
			local to = from + Vector3.new(math.random(-200, 200), -math.random(120, 330), math.random(-200, 200))
			bolt(ctx, from, to, Color3.fromRGB(215, 160, 255), 2.4, true)
			if math.random() < 0.5 then
				-- the whole sky flickers
				K.Grade.Brightness = 0.12
				task.delay(0.07, function() K.tween(K.Grade, 0.2, { Brightness = 0 }) end)
			end
			if math.random() < 0.35 then K.sfx(K.S.Lightning, 0.35, 0.9 + math.random() * 0.3) end
		end

		----------------------------------------------------------------
		-- the arm reaches down and slams its open hand on the field
		----------------------------------------------------------------
		local out = armAt(t)
		local settle = 0
		if t >= T_SLAM then settle = math.sin(math.min(t - T_SLAM, 0.6) / 0.6 * pi) * math.exp(-(t - T_SLAM) * 3) * 3 end
		local tremble = Vector3.zero
		if t > T_CHARGE then
			tremble = Vector3.new(math.noise(t * 14, 1), math.noise(t * 14, 2), math.noise(t * 14, 3)) * K.k(t, T_CHARGE, T_FIRE) * 0.9
		end
		local wrist = portalPos + G.ArmDir * out + Vector3.new(0, -settle, 0) + tremble
		-- the hand comes down with its fingers slightly raised and flattens on impact
		local tilt = math.rad(22) * (1 - K.k(out, G.OutFinal - 90, G.OutFinal, E.inQuad))
		local rel = CFrame.new(G.Wrist):ToObjectSpace(G.LandCF)
		local handCF = CFrame.new(wrist) * CFrame.fromAxisAngle(G.LandCF.XVector, tilt) * rel
		G.Hand.CFrame = handCF
		local ad = G.ArmDir
		local side = ad:Cross(Vector3.yAxis).Unit
		local yv = -ad
		local xv = yv:Cross(side).Unit
		local lowLen = G.Lower.Size.Y
		G.Lower.CFrame = CFrame.fromMatrix(wrist - ad * (lowLen / 2 - 12), xv, yv)
		local upLen = G.Upper.Size.Y
		G.Upper.CFrame = CFrame.fromMatrix(wrist - ad * (lowLen - 24 + upLen / 2), xv, yv)
		G.Hand.Transparency = out > -60 and 0 or 1
		G.Lower.Transparency = out > -10 and 0 or 1
		G.Upper.Transparency = out > lowLen - 10 and 0 or 1
		G.ArmVeins.Rate = t > T_ARM and (t > T_CHARGE and 120 or 30) or 0
		G.HandVeins.Rate = t > T_ARM and (t > T_CHARGE and 90 or 20) or 0
		G.ArmHL.OutlineColor = Color3.fromRGB(235, 220, 255):Lerp(Color3.fromRGB(200, 120, 255), K.k(t, T_CHARGE, T_FIRE))
		cue("armOut", t >= T_ARM, function()
			K.sfx(K.S.Hell, 0.9, 0.8)
			K.sfx(K.S.Whoosh, 0.8, 0.55)
			K.sfx(K.S.DarkDrone, 0.6, 0.7)
			K.shake(2.2, 2.6)
			K.gradePunch(0.35, -0.05, 1)
			K.vfx("Shoot-01", portalCF, set, 10, 6)
		end)
		cue("whoosh", t >= T_SLAM - 0.7, function()
			K.sfx(K.S.FireWhoosh, 1, 0.6)
		end)
		cue("slam", t >= T_SLAM, function()
			K.sfx(K.S.BigHit, 1, 0.7)
			K.sfx(K.S.RockBoom, 1, 0.8)
			K.sfx(K.S.Boom, 0.9, 0.6)
			K.shake(5, 1.8)
			K.kick(-10, 0.6)
			K.flash(0.35, Color3.fromRGB(255, 245, 235), 0.5)
			G.Dust:Emit(90)
			local subjects = { G.Arm }
			for _, rig in pairs(ctx.rigs) do table.insert(subjects, rig.Model) end
			task.spawn(K.impact, subjects, "WBW", 0.05)
			K.vfx("Big-Crack-01", CFrame.new(G.Hand.Position.X, ground + 0.5, G.Hand.Position.Z), set, 4, 20)
		end)
		-- shockwaves (slam + fire)
		local function shock(ti, i, t1, size)
			if t >= ti and t < ti + t1 then
				local e = K.k(t, ti, ti + t1, E.outCubic)
				K.setQuadSize(G.Shock[i], size * e, size * e)
				K.moveQuad(G.Shock[i], G.FlatCF * CFrame.Angles(0, 0, t))
				G.Shock[i].Transparency = NumberSequence.new(0.1 + 0.9 * e)
			else
				G.Shock[i].Transparency = NumberSequence.new(1)
			end
		end
		shock(T_SLAM, 1, 0.9, 420)
		shock(T_FIRE, 2, 0.8, 700)
		shock(T_FIRE + 0.15, 3, 1.2, 1100)
		-- debris: kicked up by the slam, lifted by the charge, then blasted away
		for i, d in ipairs(G.Debris) do
			if t >= T_SLAM then
				local st = t - T_SLAM
				local h = math.max(0, d.Vy * st - 90 * st * st)
				local p = G.ColBase + d.Dir * (d.R + d.Vh * math.min(st, 1.2)) + Vector3.new(0, h + 1, 0)
				if t > T_CHARGE then
					local lift = K.k(t, T_CHARGE, T_FIRE, E.inQuad)
					p = p + Vector3.new(0, lift * d.Rise * 0.25 + math.sin(t * 3 + i) * lift * 2, 0)
				end
				if t > T_FIRE then
					-- caught by the beam: they float up with everything else
					local ft = t - T_FIRE
					p = p + d.Dir * ft * 6 + Vector3.new(0, (ctx.TL.LaunchY(ft * (0.8 + (i % 5) * 0.06)) - 3) * (0.6 + (i % 4) * 0.12), 0)
				end
				d.Part.Transparency = 0
				d.Part.CFrame = CFrame.new(p) * CFrame.fromAxisAngle(d.Spin.Unit, t * d.Spin.Magnitude * (1 + math.max(0, t - T_FIRE) * 0.4))
			else
				d.Part.Transparency = 1
			end
		end

		-- the meadow tearing loose and floating up (see build)
		if t > T_CHARGE then
			for _, d in ipairs(G.Lift) do G.liftPlace(d, lt, t) end
		end

		----------------------------------------------------------------
		-- charge
		----------------------------------------------------------------
		local charge = K.k(t, T_CHARGE, T_FIRE, E.inQuad)
		local palm = G.Hand.CFrame.Position - G.Hand.CFrame.ZVector * (G.Hand.Size.Z / 2 + 3)
		local glowPos = palm + Vector3.new(0, 6 + charge * 18, 0)
		G.PalmGlow.CFrame = CFrame.new(glowPos)
		G.PalmSuckHost.CFrame = CFrame.new(glowPos)
		G.PalmGlow.Size = Vector3.one * (2 + charge * 44 + math.sin(t * 40) * charge * 4)
		G.PalmGlow.Transparency = (charge > 0.01 and t < T_FIRE + 0.3) and (0.3 - charge * 0.25) or 1
		G.PalmLight.Range = t < T_FIRE + 0.3 and charge * 60 or 0
		G.PalmFlip.Rate = (charge > 0 and t < T_FIRE) and charge * 22 or 0
		G.PalmSuck.Rate = (charge > 0 and t < T_FIRE) and (60 + charge * 260) or 0
		G.Wind.Rate = (t > T_CHARGE and t < T_FIRE) and (220 * charge + 40) or 0
		G.Grit.Rate = (t > T_CHARGE and t < T_FIRE) and 80 or 0
		for _, c in ipairs(G.Cracks) do
			local lit = K.k(t, T_CHARGE + c.R / 100, T_CHARGE + 0.6 + c.R / 100)
			c.Part.Transparency = (t < T_FIRE + 1.5) and (1 - lit * 0.9) or 1
		end
		local ring = K.k(t, T_CHARGE, T_FIRE, E.outCubic)
		local gsize = COL_R * 2.6 * math.max(ring, 0.001)
		K.setQuadSize(G.GroundRing, gsize, gsize)
		K.moveQuad(G.GroundRing, G.FlatCF * CFrame.Angles(0, 0, t * 0.8))
		K.setQuadSize(G.GroundSwirl, gsize * 0.95, gsize * 0.95)
		K.moveQuad(G.GroundSwirl, G.FlatCF * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, 0, -t * 2.2))
		K.setQuadSize(G.GroundSwirl2, gsize * 0.6, gsize * 0.6)
		K.moveQuad(G.GroundSwirl2, G.FlatCF * CFrame.new(0, 0, -0.4) * CFrame.Angles(0, 0, t * 3.5))
		local gt = (t > T_CHARGE and t < T_FIRE + 1.5) and (0.15 + 0.85 * (1 - ring)) or 1
		G.GroundRing.Transparency = NumberSequence.new(gt)
		G.GroundSwirl.Transparency = NumberSequence.new(gt)
		G.GroundSwirl2.Transparency = NumberSequence.new(gt)
		cue("charge", t >= T_CHARGE, function()
			K.sfx(K.S.Riser, 0.9, 0.9)
			K.sfx(K.S.Overdrive, 0.6, 0.7)
			K.sfx(K.S.Electric, 0.5)
			K.sfx(K.S.Choir, 0.35, 0.8)
			ctx.fadeMusic(0.2, 1.5)
		end)
		if t > T_CHARGE and t < T_FIRE then K.shake(0.35 + charge * 0.8, 0.1, 25, true) end

		----------------------------------------------------------------
		-- FIRE: the column erupts out of the palm
		----------------------------------------------------------------
		cue("fire", t >= T_FIRE, function()
			K.sfx(K.S.BeamFire, 1, 0.75)
			K.sfx(K.S.Cannon, 1, 0.8)
			K.sfx(K.S.BigHit, 1, 0.6)
			K.sfx(K.S.Broly, 0.7, 1)
			ctx.setMusic(K.S.M_Astral, 0.65, 0.4)
			K.kick(24, 1)
			K.shake(6, 2.4)
			local subjects = { G.Arm }
			for _, rig in pairs(ctx.rigs) do table.insert(subjects, rig.Model) end
			task.spawn(K.impact, subjects, "WBVWB", 0.055)
			G.Dust:Emit(120)
			K.vfx("Explosion-01", CFrame.new(G.ColBase), set, 5, 25)
			for _, rig in pairs(ctx.rigs) do
				local h = Instance.new("Highlight")
				h.Name = "RideHL"
				h.FillColor = Color3.fromRGB(34, 10, 70)
				h.OutlineColor = Color3.fromRGB(255, 245, 255)
				h.DepthMode = Enum.HighlightDepthMode.Occluded
				h.Enabled = false
				h.Parent = rig.Model
				table.insert(G.RideHL, h)
			end
			task.delay(0.3, function()
				K.flash(0.9)
				K.gradePunch(0.3, 0.05, 1.2, Color3.fromRGB(240, 225, 255))
			end)
		end)
		if t >= T_FIRE then
			local ft = t - T_FIRE
			local grow = K.k(ft, 0, 0.35, E.outCubic)
			local width = K.k(ft, 0, 0.5, E.outBack)
			G.column(ground, K.lerp(palm.Y, ground + 6000, grow), width, 1, t)
			local focus = lt > 0 and launchY(lt) or ground + 100
			G.columnFX(t, focus, K.k(ft, 0.1, 0.6))
			G.Sparks.Rate = 260
			G.SparkHost.CFrame = CFrame.new(G.ColBase.X, math.max(ground + 4, focus - 250), G.ColBase.Z)
			G.ColLight.Range = 60
			local bl = (1 - K.k(ft, 1.5, 4)) * K.k(ft, 0, 0.2)
			for _, l in ipairs(G.BaseLights) do l.Range = 60 * bl end
		end

		----------------------------------------------------------------
		-- CAMERA
		----------------------------------------------------------------
		local myPos = me and me:cf().Position or M.Position
		local head = me and me:head() and me:head().Position or myPos
		local rcf = me and me:cf() or M
		local rig0 = me and me.LaunchFrom
		if t < 4.6 then
			-- drone shot: over the clouds and the mountains, down onto the island
			-- (a slow, even glide: shorter path, and the aim settles with the same easing
			-- as the move, so nothing whips round in the first seconds)
			local e = K.k(t, 0, 4.6, E.outQuad)
			local p = K.spline({
				(M * CFrame.new(-240, 120, 300)).Position,
				(M * CFrame.new(-165, 80, 210)).Position,
				(M * CFrame.new(-95, 40, 125)).Position,
				(M * CFrame.new(-46, 14, 62)).Position,
			}, e)
			local look = (M * CFrame.new(0, 30, -420)).Position:Lerp((M * CFrame.new(0, 4, 6)).Position, K.k(t, 0, 4.6, E.inOutSine))
			K.setCam(CFrame.lookAt(p, look), K.lerp(52, 46, e))
		elseif t < 7.4 then
			-- walking with you: a low tracking shot, the others behind
			local e = K.k(t, 4.6, 7.4)
			local p = head + rcf.RightVector * 11 + rcf.LookVector * K.lerp(7, 3, e) + Vector3.new(0, -1.2, 0)
			K.setCam(CFrame.lookAt(p, head + Vector3.new(0, -0.6, 0) + rcf.LookVector * 2), 40)
		elseif t < T_STORM + 0.8 then
			-- wide at grass height: the party, the shop, the big sky behind
			local e = K.k(t, 7.4, T_STORM + 0.8)
			local p = (M * CFrame.new(K.lerp(-38, -30, e), 2.2, 58)).Position
			local look = (M * CFrame.new(0, K.lerp(12, 40, K.k(t, T_STORM - 0.5, T_STORM + 0.8)), -40)).Position
			K.setCam(CFrame.lookAt(p, look), 52)
		elseif t < T_PORTAL then
			-- close on you as you look up
			local p = head + rcf.LookVector * 6.5 + rcf.RightVector * 2.2 + Vector3.new(0, -1, 0)
			K.setCam(CFrame.lookAt(p, head + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.sin(t * 1.3) * 0.01), 36)
		elseif t < T_ARM then
			-- low behind the group, tilting up to the portal
			local e = K.k(t, T_PORTAL, T_ARM)
			local p = (M * CFrame.new(6, 2.5, 44)).Position
			local look = myPos:Lerp(portalPos, 0.3 + e * 0.6)
			K.setCam(CFrame.lookAt(p, look), K.lerp(55, 70, e))
		elseif t < T_SLAM + 0.05 then
			-- the arm comes down: low in the flowers off to the side, the moon and the domes behind
			local e = K.k(t, T_ARM, T_SLAM, E.inOutSine)
			local p = (M * CFrame.new(K.lerp(-110, -122, e), K.lerp(8, 5, e), K.lerp(-10, 4, e))).Position
			local look = (M * CFrame.new(0, K.lerp(80, 40, e), K.lerp(-150, -95, e))).Position
			K.setCam(CFrame.lookAt(p, look), 62)
		elseif t < T_CHARGE then
			-- behind the party, down in the flowers: the giant open palm planted in front of them
			local e = K.k(t, T_SLAM, T_CHARGE, E.outQuad)
			local p = (M * CFrame.new(K.lerp(-16, -12, e), K.lerp(13, 11, e), K.lerp(47, 40, e))).Position
			K.setCam(CFrame.lookAt(p, (M * CFrame.new(0, 8, -60)).Position), K.lerp(64, 60, e))
		elseif t < T_FIRE then
			-- over your shoulder at the charging palm
			local e = K.k(t, T_CHARGE, T_FIRE, E.inQuad)
			local glow = G.PalmGlow.Position
			local back = Vector3.new(head.X - glow.X, 0, head.Z - glow.Z)
			back = back.Magnitude > 0.1 and back.Unit or -M.LookVector
			local side = back:Cross(Vector3.yAxis)
			local p = head + back * K.lerp(9, 7, e) - side * 3.5 + Vector3.new(0, -1.2, 0)
			K.setCam(CFrame.lookAt(p, glow:Lerp(head, 0.62)), K.lerp(66, 58, e))
		elseif lt < 0.05 then
			local p = (M * CFrame.new(150, 12, 110)).Position
			K.setCam(CFrame.lookAt(p, G.ColBase + Vector3.new(0, 90, 0)), 75)
		elseif lt < 2.1 then
			-- LIFT-OFF, up close and low: your feet leave the grass, flowers and
			-- clumps of turf drift up around you. The camera rises with you, slowly.
			local e = K.k(lt, 0.05, 2.1, E.inOutSine)
			local fromBeam = Vector3.new(myPos.X - G.ColBase.X, 0, myPos.Z - G.ColBase.Z)
			fromBeam = fromBeam.Magnitude > 1 and fromBeam.Unit or -M.LookVector
			local side = fromBeam:Cross(Vector3.yAxis)
			-- (tracks you sideways as the beam starts drawing you in, so you stay close)
			local base = myPos
			local p = Vector3.new(base.X, 0, base.Z) + fromBeam * K.lerp(9, 12, e) + side * K.lerp(6, 8, e)
			p = Vector3.new(p.X, math.max(ground + 1.2, myPos.Y - K.lerp(2.6, 1.2, e)), p.Z)
			local look = myPos + Vector3.new(0, K.lerp(-1.6, 0.4, e), 0)
			K.setCam(CFrame.lookAt(p, look) * CFrame.Angles(0, 0, math.rad(K.lerp(-2, -7, e))), K.lerp(50, 58, e))
			K.shake(0.08 + 0.3 * e, 0.1, 18, true)
		elseif lt < 3.7 then
			-- the rise takes over: the camera stays down in the meadow as you are torn
			-- away up the beam, trees and stalls and rocks ripping loose all round
			local e = K.k(lt, 2.1, 3.7, E.inQuad)
			local fromBeam = Vector3.new(myPos.X - G.ColBase.X, 0, myPos.Z - G.ColBase.Z)
			fromBeam = fromBeam.Magnitude > 1 and fromBeam.Unit or -M.LookVector
			local side = fromBeam:Cross(Vector3.yAxis)
			local anchor = rig0 or myPos
			local p = Vector3.new(anchor.X, ground + K.lerp(3, 7, e), anchor.Z) + fromBeam * K.lerp(16, 30, e) + side * 8
			K.setCam(CFrame.lookAt(p, myPos) * CFrame.Angles(0, 0, math.rad(-6)), K.lerp(60, 74, e))
			K.shake(0.4 + e * 0.9, 0.1, 24, true)
		else
			-- catching up: riding with them now, above, looking down the column past
			-- the tumbling debris at the island falling away, clouds rushing past
			local e = K.k(lt, 3.7, dur - T_FIRE - 0.25)
			local off = CFrame.Angles(0, lt * 0.35, 0) * Vector3.new(12, 0, 0)
			local p = myPos + off + Vector3.new(0, K.lerp(24, 15, e), 0)
			K.setCam(CFrame.lookAt(p, myPos - Vector3.new(0, 26, 0)) * CFrame.Angles(0, 0, lt * 0.2), K.lerp(74, 80, e))
			K.shake(0.7, 0.1, 28, true)
		end
		K.stream(K.Cam.CF.Position)
	end)

	for _, e in ipairs({ G.Storm, G.Swirl, G.PortalSuck, G.PortalArcs, G.Wind, G.Grit, G.PalmFlip, G.PalmSuck, G.ArmVeins, G.HandVeins, G.Tear }) do
		e.Rate = 0
	end
	for _, d in ipairs(G.Debris) do d.Part.Transparency = 1 end
	for _, c in ipairs(G.LowClouds) do c.Parent = nil end
end

return Ch
