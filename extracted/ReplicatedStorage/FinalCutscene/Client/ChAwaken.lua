--==================================================
-- SPIRAL GALAXY III: VEINS, TRANSFORM, SHOUT
-- Inside you: heart, lungs, arteries and veins, flooded with spiral
-- energy until the whole system goes wild. Then the fist bursts
-- open, the party rises in a column of spiral power, the Verity bat
-- becomes the Spiral Bat, they land, and all of them, together:
-- JUST WHO THE HELL DO YOU THINK WE ARE!
--==================================================
local SK = require(script.Parent:WaitForChild("SpiralKit"))
local Ch = {}

local UP = Vector3.yAxis
local WHITE = Color3.new(1, 1, 1)
local GREEN, LIME = SK.GREEN, SK.LIME

-- the body inside: a giant (S x) version of your body, far away on its own
local V = Vector3.new(-22000, 16000, 16000)
local S = 70
local ART = Color3.fromRGB(125, 12, 28)
local VEIN = Color3.fromRGB(52, 26, 110)
local AIR = Color3.fromRGB(235, 150, 175)
local ARM_OUT, LEG_OUT = 25, 7 -- the pose the giant body is in (degrees)

local function rot2(v, deg)
	local a = math.rad(deg)
	return Vector3.new(v.X * math.cos(a) - v.Y * math.sin(a), v.X * math.sin(a) + v.Y * math.cos(a), v.Z)
end

------------------------------------------------------------------------
-- BUILD: the heart, the arteries, the veins, the lungs
------------------------------------------------------------------------
local function buildBody(ctx, set)
	local K = ctx.kit
	local rng = Random.new(77)
	local B = { Parts = {}, Balls = {}, O = V }
	ctx.Body = B
	local model = Instance.new("Model")
	model.Name = "Vessels"
	model.Parent = set
	local function P(u) return V + u * S end
	local function part(shape, size, cf, col)
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size
		p.CFrame = cf
		p.Material = Enum.Material.SmoothPlastic
		p.Color = col
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = model
		return p
	end
	local function seg(a, b, r, kind, order)
		local len = (b - a).Magnitude
		if len < 0.3 then return end
		local col = kind == "a" and ART or kind == "v" and VEIN or AIR
		local p = part(Enum.PartType.Cylinder, Vector3.new(len + r * 0.8, r * 2, r * 2), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), col)
		table.insert(B.Parts, { Part = p, Order = order, Kind = kind, Base = col })
	end
	local function alveoli(q, r, order)
		for _ = 1, 3 do
			local s = r * rng:NextNumber(2.2, 3.4) + 1.2
			local p = part(Enum.PartType.Ball, Vector3.one * s, CFrame.new(q + rng:NextUnitVector() * s * 0.6), AIR)
			table.insert(B.Parts, { Part = p, Order = order, Kind = "air", Base = AIR, Alv = true })
		end
	end
	local tree
	tree = function(p, dir, len, r, depth, kind, order, bound)
		local q = p + dir * len
		if bound then q = bound(q) end
		seg(p, q, r, kind, order)
		local o2 = order + len
		if depth <= 0 then
			if kind == "air" then alveoli(q, r, o2) end
			return
		end
		for k = 1, 2 do
			local ax = dir:Cross(rng:NextUnitVector())
			ax = ax.Magnitude > 1e-3 and ax.Unit or Vector3.xAxis
			local ang = math.rad(rng:NextNumber(22, 44)) * (k == 1 and 1 or -1)
			local nd = CFrame.fromAxisAngle(ax, ang):VectorToWorldSpace(dir).Unit
			tree(q, nd, len * rng:NextNumber(0.68, 0.82), math.max(r * 0.72, 0.5), depth - 1, kind, o2, bound)
		end
	end
	-- a vessel along a list of points (body units), with side branches
	local function route(pts, r0, r1, kind, order0, every, depth, blen)
		local pieces = {}
		for i = 1, #pts - 1 do
			local a, b = P(pts[i]), P(pts[i + 1])
			local n = math.max(1, math.floor((b - a).Magnitude / (0.28 * S)))
			for j = 1, n do table.insert(pieces, { a:Lerp(b, (j - 1) / n), a:Lerp(b, j / n) }) end
		end
		local order = order0
		local prev
		local N = #pieces
		for i, pc in ipairs(pieces) do
			local a = prev or pc[1]
			local b = pc[2] + (i < N and rng:NextUnitVector() * S * 0.035 or Vector3.zero)
			local r = r0 + (r1 - r0) * (i / N)
			seg(a, b, r, kind, order)
			order += (b - a).Magnitude
			if every and i % every == 0 and i < N then
				local dir = (b - a).Unit
				local sd = dir:Cross(rng:NextUnitVector())
				sd = sd.Magnitude > 1e-3 and sd.Unit or Vector3.xAxis
				tree(b, (dir * 0.5 + sd).Unit, (blen or 0.3) * S, r * 0.6, depth or 1, kind, order)
			end
			prev = b
		end
		return order
	end

	-- the heart
	local H = Vector3.new(-0.18, 0.32, -0.1)
	local src = K.Assets:FindFirstChild("Heart")
	local heart
	if src then
		heart = src:Clone()
		heart.Anchored = true
		heart.CanCollide = false
		heart.CanQuery = false
		heart.CanTouch = false
		for _, d in ipairs(heart:GetChildren()) do if not d:IsA("SpecialMesh") and not d:IsA("SurfaceAppearance") then d:Destroy() end end
	else
		heart = Instance.new("Part")
		heart.Shape = Enum.PartType.Ball
		heart.Anchored = true
		heart.CanCollide = false
	end
	local hs = Vector3.new(20, 26, 15) * 1.9
	heart.Size = hs
	heart.CFrame = CFrame.new(P(H)) * CFrame.Angles(math.rad(10), math.rad(20), math.rad(-25))
	heart.Material = Enum.Material.SmoothPlastic
	heart.Color = Color3.fromRGB(150, 22, 34)
	heart.Parent = model
	B.Heart = heart
	B.HeartSize = hs
	B.HeartCF = heart.CFrame

	-- where the limbs are (the giant body is posed arms-out, legs apart)
	local function arm(sx)
		local piv = Vector3.new(sx * 1, 0.5, 0)
		local th = ARM_OUT * sx
		local c = piv + rot2(Vector3.new(sx * 0.5, -0.5, 0), th)
		return piv, c + rot2(Vector3.new(0, 0.75, 0), th), c, c + rot2(Vector3.new(0, -0.85, 0), th), c + rot2(Vector3.new(0, -1.0, 0), th)
	end
	local function leg(sx)
		local piv = Vector3.new(sx * 1, -1, 0)
		local th = LEG_OUT * sx
		local c = piv + rot2(Vector3.new(-sx * 0.5, -1, 0), th)
		return c + rot2(Vector3.new(0, 0.9, 0), th), c, c + rot2(Vector3.new(0, -0.9, 0), th), c + rot2(Vector3.new(0, -1.0, -0.15), th)
	end
	local headC = Vector3.new(0, 1.55, 0)
	local function headBound(q)
		local rel = (q - P(headC)) / (Vector3.new(0.5, 0.42, 0.45) * S)
		if rel.Magnitude > 1 then q = P(headC) + (rel.Unit * Vector3.new(0.5, 0.42, 0.45) * S) * 0.97 end
		return q
	end

	-- ARTERIES (from the heart outward)
	local BIF = Vector3.new(0.02, -0.92, 0.1)
	local o = route({ H, Vector3.new(-0.12, 0.6, -0.05), Vector3.new(-0.04, 0.8, 0), Vector3.new(0.09, 0.72, 0.06), Vector3.new(0.06, 0.4, 0.14), Vector3.new(0.04, -0.2, 0.14), BIF }, 5.2, 4.2, "a", 0, 2, 1, 0.28)
	for _, sx in ipairs({ 1, -1 }) do
		-- up the neck into the head, branching all through it
		local co = route({ Vector3.new(0.05 * sx, 0.78, 0.02), Vector3.new(0.13 * sx, 1.02, -0.05), Vector3.new(0.15 * sx, 1.3, -0.05), Vector3.new(0.13 * sx, 1.55, 0) }, 3, 2.4, "a", 0.3 * S, nil)
		for k = 1, 4 do
			local dir = Vector3.new(sx * (0.3 + k * 0.15), 1, (k - 2.5) * 0.4).Unit
			tree(P(Vector3.new(0.13 * sx, 1.55, 0)), dir, 0.2 * S, 1.8, 3, "a", co, headBound)
		end
		-- out over the shoulder and down the arm to the hand
		local piv, top, c, wrist, tip = arm(sx)
		route({ Vector3.new(0.1 * sx, 0.74, 0.02), Vector3.new(0.6 * sx, 0.8, 0), piv, top, c, wrist, tip }, 3.4, 1.8, "a", 0.3 * S, 2, 2, 0.26)
		-- down into the leg to the foot
		local ltop, lc, ankle, foot = leg(sx)
		route({ BIF, Vector3.new(0.35 * sx, -1.0, 0.06), ltop, lc, ankle, foot }, 3.8, 2, "a", o, 2, 2, 0.28)
	end
	-- VEINS (the same roads home, a little behind)
	local off = Vector3.new(0, 0, 0.16)
	route({ BIF + off, Vector3.new(0.1, -0.2, 0.2), Vector3.new(0.1, 0.3, 0.18), H + Vector3.new(0.12, 0, 0.1) }, 4.6, 5, "v", 0, 3, 1, 0.24)
	for _, sx in ipairs({ 1, -1 }) do
		route({ Vector3.new(0.2 * sx, 1.5, 0.12), Vector3.new(0.2 * sx, 1.02, 0.1), Vector3.new(0.12 * sx, 0.72, 0.12), H + Vector3.new(0.1, 0.1, 0.1) }, 2.2, 3.4, "v", 0, 2, 2, 0.22)
		local piv, top, c, wrist, tip = arm(sx)
		local sh = Vector3.new(0.07 * sx, -0.05, 0.1)
		route({ tip + sh, wrist + sh, c + sh, top + sh, piv + off, Vector3.new(0.55 * sx, 0.72, 0.12), H + Vector3.new(0.1, 0.1, 0.1) }, 1.5, 3, "v", 0, 2, 2, 0.24)
		local ltop, lc, ankle, foot = leg(sx)
		local ls = Vector3.new(-0.07 * sx, 0, 0.12)
		route({ foot + ls, ankle + ls, lc + ls, ltop + ls, Vector3.new(0.3 * sx, -1, 0.2), BIF + off }, 1.6, 3.4, "v", 0, 2, 2, 0.24)
	end
	-- LUNGS: the windpipe, the bronchial trees, the air sacs
	route({ Vector3.new(0, 1.08, -0.04), Vector3.new(0, 0.62, 0) }, 3.4, 3.4, "air", 0, nil)
	B.Lungs = {}
	for _, sx in ipairs({ 1, -1 }) do
		local lc = Vector3.new(0.47 * sx, 0.28, 0)
		local rad = Vector3.new(0.4, 0.55, 0.36) * S
		local function bound(q)
			local rel = (q - P(lc)) / rad
			if rel.Magnitude > 0.95 then q = P(lc) + rel.Unit * 0.92 * rad end
			return q
		end
		local bo = route({ Vector3.new(0, 0.62, 0), Vector3.new(0.3 * sx, 0.5, 0) }, 2.8, 2.2, "air", 0.47 * S, nil)
		for k = 1, 3 do
			local dir = Vector3.new(sx * 0.6, 0.5 - k * 0.45, (k - 2) * 0.35).Unit
			tree(P(Vector3.new(0.3 * sx, 0.5, 0)), dir, 0.2 * S, 1.8, 4, "air", bo, bound)
		end
		local env = part(Enum.PartType.Ball, Vector3.one, CFrame.new(P(lc)), AIR)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = rad * 2
		mesh.Parent = env
		env.Material = Enum.Material.ForceField
		env.Transparency = 0.3
		table.insert(B.Lungs, { Part = env, Mesh = mesh, Base = rad * 2 })
	end

	-- the road the camera rides: out of the heart, over the arch, down the aorta, into the leg
	do
		local ltop, lc, ankle = leg(1)
		B.Ride = {}
		for _, u in ipairs({ H, Vector3.new(-0.12, 0.6, -0.05), Vector3.new(-0.04, 0.8, 0), Vector3.new(0.09, 0.72, 0.06), Vector3.new(0.06, 0.4, 0.14),
			Vector3.new(0.04, -0.2, 0.14), BIF, Vector3.new(0.35, -1.0, 0.06), ltop, lc, ankle }) do
			table.insert(B.Ride, P(u))
		end
	end
	-- the order everything lights up in (seconds into the Veins chapter)
	local maxA, maxV, maxR = 1, 1, 1
	for _, e in ipairs(B.Parts) do
		if e.Kind == "a" then maxA = math.max(maxA, e.Order) elseif e.Kind == "v" then maxV = math.max(maxV, e.Order) else maxR = math.max(maxR, e.Order) end
	end
	for _, e in ipairs(B.Parts) do
		if e.Kind == "a" then e.T = 2.1 + 3.1 * (e.Order / maxA)
		elseif e.Kind == "air" then e.T = 3.9 + 2.9 * (e.Order / maxR)
		else e.T = 5.3 + 2.8 * (1 - e.Order / maxV) end
	end
	table.sort(B.Parts, function(a, b) return a.T < b.T end)
	B.MaxA, B.MaxV, B.MaxR = maxA, maxV, maxR

	-- blood cells drifting, green sparks later
	local host = K.part({ Name = "CellHost", Size = Vector3.new(2.2, 3.6, 1.2) * S, Transparency = 1, CFrame = CFrame.new(P(Vector3.new(0, 0.3, 0))) }, set)
	B.Cells = K.emitter(host, {
		Texture = "14582794847", Color = ColorSequence.new(Color3.fromRGB(200, 30, 50), Color3.fromRGB(120, 10, 25)), Size = K.ns(0, 0, 0.2, 3.2, 0.8, 3.2, 1, 0),
		Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(180, 180), Rate = 45, Brightness = 1.5,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rotation = NumberRange.new(0, 360), LightEmission = 0.4,
	})
	B.Sparks = K.emitter(host, {
		Texture = "131679330853412", Color = ColorSequence.new(LIME, WHITE), Size = K.ns(0, 0, 0.3, 3.5, 1, 0),
		Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(10, 40), SpreadAngle = Vector2.new(180, 180), Rate = 0, Brightness = 5,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rotation = NumberRange.new(0, 360),
	})
	-- the spiral round the heart (for the end)
	local hh = K.part({ Name = "HeartHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(P(H)) }, set)
	B.Swirl = {
		K.quad(hh, CFrame.new(P(H)), 300, 300, "14426232568", { Color = GREEN, Brightness = 2.5, Transparency = 0.2 }),
		K.quad(hh, CFrame.new(P(H)), 200, 200, "124165682553877", { Color = LIME, Brightness = 3, Transparency = 0.2 }),
		(K.quad(hh, CFrame.new(P(H)), 520, 520, "rbxasset://sky/sun.jpg", { Color = GREEN, Brightness = 2, Transparency = 0.4 })),
	}
	for _, q in ipairs(B.Swirl) do q.Enabled = false end
	B.HeartGlow = SK.glow(K, hh, P(H), 120, GREEN, 3)
	B.HeartGlow.set(P(H), 10, 0)
	B.Inflow = SK.stream(K, hh, 12)
	B.Inflow.off()
	B.HeartLight = Instance.new("PointLight")
	B.HeartLight.Color = Color3.fromRGB(255, 60, 70)
	B.HeartLight.Range = 60
	B.HeartLight.Brightness = 2
	B.HeartLight.Parent = heart
	B.H = P(H)
end

function Ch.build(ctx)
	local K = ctx.kit
	local set = Instance.new("Folder")
	set.Name = "VeinSet"
	ctx.sets.Veins = set
	buildBody(ctx, set)

	-- the transformation's column of spiral power
	local aw = Instance.new("Folder")
	aw.Name = "AwakenSet"
	ctx.sets.Awaken = aw
	local A = {}
	ctx.Aw = A
	local fx = Instance.new("Folder")
	fx.Name = "FX"
	fx.Parent = aw
	A.FX = fx
	local host = K.part({ Name = "ColumnHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(SK.CATCH) }, aw)
	A.Host = host
	A.Helix = {}
	for i = 1, 44 do
		local b = K.part({ Name = "H", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, Material = Enum.Material.Neon, Color = (i % 2 == 0) and GREEN or LIME, Transparency = 1, CFrame = CFrame.new(SK.CATCH) }, aw)
		A.Helix[i] = b
	end
	A.Discs = {
		{ Q = K.quad(host, CFrame.new(SK.CATCH), 90, 90, "14426232568", { Color = GREEN, Brightness = 2.5, Transparency = 0.1 }), S = 90, W = 2 },
		{ Q = K.quad(host, CFrame.new(SK.CATCH), 60, 60, "124165682553877", { Color = LIME, Brightness = 3, Transparency = 0.1 }), S = 60, W = -3 },
		{ Q = K.quad(host, CFrame.new(SK.CATCH), 170, 170, "rbxasset://sky/sun.jpg", { Color = GREEN, Brightness = 1.6, Transparency = 0.35 }), S = 170, W = 0.4 },
	}
	for _, d in ipairs(A.Discs) do d.Q.Enabled = false end
	A.Column = K.ray(host, Vector3.zero, UP, 30, 60, "10365550877", { Color = GREEN, Brightness = 3, Transparency = K.ns(0, 0.2, 0.7, 0.4, 1, 0.97), Speed = 4, Mode = Enum.TextureMode.Wrap, Length = 120, Segments = 10 })
	A.Column2 = K.ray(host, Vector3.zero, UP, 90, 140, "10180479311", { Color = LIME, Brightness = 1.6, Transparency = K.ns(0, 0.5, 0.7, 0.6, 1, 0.97), Speed = 2, Mode = Enum.TextureMode.Wrap, Length = 300, Segments = 10 })
	A.Column.Enabled = false
	A.Column2.Enabled = false
	A.Shafts = {}
	for i = 1, 18 do
		local b = K.ray(host, Vector3.zero, UP, 6, 40, "rbxasset://sky/sun.jpg", { Color = (i % 3 == 0) and WHITE or GREEN, Brightness = 3, Transparency = K.ns(0, 0.1, 1, 0.9), Segments = 1 })
		b.Enabled = false
		A.Shafts[i] = { B = b, Dir = Random.new(i):NextUnitVector(), L = 150 + (i % 5) * 50 }
	end
	A.Wave = K.softRing(host, 64, 10, 40, { Brightness = 3, Alpha = 0 })
	for _, q in ipairs(A.Wave.Q) do q.Color = ColorSequence.new(WHITE, GREEN) end
	A.Wave.setTransparency(0.99)
	A.Glow = SK.glow(K, host, SK.CATCH, 100, GREEN, 3)
	A.Glow.set(SK.CATCH, 1, 0)

	-- the shout's burst of light (warm rays behind the pose, like the old poster)
	local sh = K.part({ Name = "BurstHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(SK.CATCH) }, aw)
	A.BurstHost = sh
	A.Rays = {}
	local rr = Random.new(9)
	for i = 1, 30 do
		local q = K.quad(sh, CFrame.new(SK.CATCH), 100, 10, "rbxasset://sky/sun.jpg", { Color = (i % 2 == 0) and Color3.fromRGB(255, 236, 190) or Color3.fromRGB(255, 160, 70), Brightness = 0.9, Transparency = 0.55 })
		q.Enabled = false
		A.Rays[i] = { Q = q, A = i / 30 * math.pi * 2 + rr:NextNumber(-0.05, 0.05), L = rr:NextNumber(0.7, 1.25), W = rr:NextNumber(0.5, 1.4), P = rr:NextNumber(0, 6) }
	end
	A.BurstGlow = SK.glow(K, sh, SK.CATCH, 100, Color3.fromRGB(255, 170, 80), 2.2)
	A.BurstCore = SK.glow(K, sh, SK.CATCH, 100, Color3.fromRGB(255, 250, 235), 3.5)
	A.BurstGlow.set(SK.CATCH, 1, 0)
	A.BurstCore.set(SK.CATCH, 1, 0)

	-- the shout: a giga drill of spiral power over their heads, rings round
	-- their feet, a column into the sky
	A.Drill = {}
	local cone = K.Assets:FindFirstChild("DrillCone")
	if cone then
		for i, spec in ipairs({ { Enum.Material.ForceField, GREEN, 0 }, { Enum.Material.Neon, LIME, 0.6 } }) do
			local c = cone:Clone()
			for _, d in ipairs(c:GetChildren()) do d:Destroy() end
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.CastShadow = false
			c.Material = spec[1]
			c.Color = spec[2]
			c.Transparency = 1
			c.Parent = aw
			A.Drill[i] = { Part = c, Tr = spec[3], Size = c.Size }
		end
	end
	A.FloorRings = {}
	for i, tex in ipairs({ "14426232568", "124165682553877", "14426232568" }) do
		local q = K.quad(sh, CFrame.new(SK.CATCH), 10, 10, tex, { Color = i == 2 and LIME or GREEN, Brightness = 1.3, Transparency = 0.45 })
		q.Enabled = false
		A.FloorRings[i] = q
	end
	A.SkyCol = K.ray(sh, SK.CATCH, SK.CATCH + UP, 30, 60, "10365550877", { Color = GREEN, Brightness = 2, Transparency = K.ns(0, 1, 0.15, 0.35, 0.8, 0.6, 1, 1), Speed = 6, Mode = Enum.TextureMode.Wrap, Length = 150, Segments = 4 })
	A.SkyCol.Enabled = false
	A.SkyCol2 = K.ray(sh, SK.CATCH, SK.CATCH + UP, 90, 160, "14582794847", { Color = LIME, Brightness = 0.8, Transparency = K.ns(0, 1, 0.15, 0.75, 1, 1), Segments = 4 })
	A.SkyCol2.Enabled = false
end

------------------------------------------------------------------------
-- your body, huge, with the giant's pose (a ghostly shell round the vessels)
------------------------------------------------------------------------
local function makeShell(ctx)
	local K = ctx.kit
	local uid = ctx.roster[ctx.me or 1]
	local ok, rig = pcall(K.rig, uid, ctx.sets.Veins)
	if not ok or not rig then return nil end
	rig:setPose({ RS = K.A(0, 0, ARM_OUT), LS = K.A(0, 0, -ARM_OUT), RH = K.A(0, 0, LEG_OUT), LH = K.A(0, 0, -LEG_OUT) })
	rig:apply(true)
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("Decal") or d:IsA("Texture") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("SurfaceAppearance") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Material = Enum.Material.ForceField
			d.Color = Color3.fromRGB(255, 110, 130)
			d.Transparency = 0.45
			d.CastShadow = false
		end
	end
	pcall(function() rig.Model:ScaleTo(S) end)
	rig.Root.CFrame = CFrame.new(V)
	return rig
end

------------------------------------------------------------------------
-- VEINS: in through your skin to your heart. It beats, weak and red, blood
-- pulsing out through you... the green arrives, the heart catches, and every
-- beat drives spiral energy down every artery, into the lungs, back through
-- the veins, faster and faster until the whole of you goes wild.
------------------------------------------------------------------------
local A_RED, A_HOT = Color3.fromRGB(70, 6, 14), Color3.fromRGB(255, 50, 60)
local V_RED, V_HOT = Color3.fromRGB(28, 12, 60), Color3.fromRGB(150, 70, 255)
local A_GRN, A_GHOT = Color3.fromRGB(20, 110, 45), Color3.fromRGB(215, 255, 215)
local V_GRN, V_GHOT = Color3.fromRGB(20, 90, 80), Color3.fromRGB(160, 255, 230)
local AIR_D, AIR_G = Color3.fromRGB(120, 60, 80), Color3.fromRGB(150, 255, 110)
function Ch.Veins(ctx, t0, dur)
	local K = ctx.kit
	local B = ctx.Body
	local set = ctx.sets.Veins
	set.Parent = ctx.stage
	-- (the arena and everything else would show through; they wait off-stage)
	if ctx.stashArena then ctx.stashArena() end
	for _, name in ipairs({ "Arena", "Hand", "Entry", "EntryVoid" }) do
		if ctx.sets[name] then ctx.sets[name].Parent = nil end
	end
	for _, rig in pairs(ctx.rigs) do rig.Model.Parent = nil end
	K.lighting("Inner", 0)
	K.Atmo.Density = 0.2 -- (thin enough to see the whole body through)
	K.Grade.TintColor = Color3.fromRGB(255, 225, 225)
	K.Grade.Saturation = 0.1
	K.Grade.Contrast = 0.25
	K.Grade.Brightness = 0
	K.vignette(0.35, Color3.new(0, 0, 0), 0.3)
	K.muffle(0, 0.3)
	local shell = makeShell(ctx)
	local shellParts = {}
	if shell then for _, p in ipairs(shell.Parts) do table.insert(shellParts, p) end end
	local IGN = 2.6 -- the heart catches
	-- this run's flood: the arteries from the heart out, the lungs, then the veins home
	for _, e in ipairs(B.Parts) do
		if e.Kind == "a" then e.T = IGN + 0.15 + 2.8 * (e.Order / B.MaxA)
		elseif e.Kind == "air" then e.T = 4.6 + 2.2 * (e.Order / B.MaxR)
		else e.T = 5.4 + 2.2 * (1 - e.Order / B.MaxV) end
		e.Part.Material = Enum.Material.Neon
		e.Part.Color = e.Kind == "a" and A_RED or e.Kind == "v" and V_RED or AIR_D
	end
	B.Heart.Color = Color3.fromRGB(150, 22, 34)
	B.Heart.Material = Enum.Material.SmoothPlastic
	local cue = K.once()
	local cam = SK.camera(K)
	local shot = 0
	local Hc = B.H
	local beat = ctx.CrushBeat
	if not beat or not beat.Parent then beat = K.loop(K.S.Heartbeat, 0.9, 0.2) end
	ctx.CrushBeat = beat
	K.fade(0, 0.35, Color3.fromRGB(200, 255, 200))
	-- the ride down the aorta
	local rideKeys, acc = {}, 0
	for i, p in ipairs(B.Ride) do
		if i > 1 then acc += (p - B.Ride[i - 1]).Magnitude end
		table.insert(rideKeys, { acc, p })
	end
	local ride = SK.path(rideKeys)
	local rideLen = acc
	local rideS
	local beats = {}
	local phase, lastBeat = 0, -1
	local FLICK = { GREEN, LIME, WHITE, Color3.fromRGB(120, 255, 220), GREEN }
	local SPEED, W = 300, 26
	SK.run(K, t0, dur, function(t, dt)
		local insane = K.k(t, 8.4, 9.3)
		local lit0 = t >= IGN
		----------------------------------------------------------------
		-- the heart: slow and failing, then green, then racing
		----------------------------------------------------------------
		local rate = t < IGN and 0.9 or K.lerp(1.5, 3.6, K.k(t, IGN, 10.4))
		phase += dt * rate
		local ph = phase % 1
		local beatN = math.floor(phase)
		if beatN ~= lastBeat or (t >= IGN and not beats.ign) then
			lastBeat = beatN
			if t >= IGN and not beats.ign then beats.ign = true phase = math.floor(phase) + 0.001 ph = 0.001 end
			table.insert(beats, t)
			if #beats > 5 then table.remove(beats, 1) end
			K.sfx(K.S.Heartbeat, t < IGN and 0.7 or 1, t < IGN and 0.8 or K.lerp(1, 1.4, insane))
			if t > IGN then
				K.shake(0.5 + insane * 2, 0.22, 20, true)
				B.Sparks:Emit(math.floor(12 + insane * 40))
			end
		end
		local pump = math.exp(-ph * 9) + 0.45 * math.exp(-math.max(ph - 0.18, 0) * 11) * (ph > 0.18 and 1 or 0)
		B.Heart.Size = B.HeartSize * (1 + pump * (t < IGN and 0.07 or K.lerp(0.12, 0.22, K.k(t, IGN, 9))))
		B.Heart.CFrame = B.HeartCF * CFrame.Angles(0, 0, math.rad(pump * 3))
		beat.PlaybackSpeed = rate * 0.9
		beat.Volume = t < IGN and 0.4 or 0.7
		-- the green arrives at the heart
		local inflow = K.k(t, 1.5, IGN, K.E.inQuad)
		if inflow > 0 and t < IGN + 0.5 then
			B.Inflow.set(Hc + Vector3.new(40, 70, -560), Hc, inflow, 9, t, 5)
		else
			B.Inflow.off()
		end
		local ignite = K.k(t, IGN, IGN + 0.3)
		B.Heart.Color = Color3.fromRGB(150, 22, 34):Lerp(GREEN, ignite)
		B.Heart.Material = ignite > 0.5 and Enum.Material.Neon or Enum.Material.SmoothPlastic
		B.HeartGlow.set(Hc, (110 + pump * 70) * (1 + insane), ignite * (0.55 + 0.35 * pump) + (1 - ignite) * pump * 0.25)
		B.HeartLight.Color = Color3.fromRGB(255, 60, 70):Lerp(GREEN, ignite)
		B.HeartLight.Brightness = 2 + ignite * 6 + pump * 5
		B.HeartLight.Range = 60 + ignite * 70

		----------------------------------------------------------------
		-- the blood: every beat, a pulse runs out through the arteries
		-- (and back up the veins); the green floods in behind the first
		----------------------------------------------------------------
		for _, e in ipairs(B.Parts) do
			local lit = t >= e.T
			local base, hot
			if e.Kind == "a" then
				base, hot = lit and A_GRN or A_RED, lit and A_GHOT or A_HOT
			elseif e.Kind == "v" then
				base, hot = lit and V_GRN or V_RED, lit and V_GHOT or V_HOT
			else
				base, hot = lit and AIR_G or AIR_D, lit and WHITE or AIR_D
			end
			local p = 0
			if e.Kind ~= "air" then
				for _, tb in ipairs(beats) do
					local f = (t - tb) * SPEED * (lit0 and 1.25 or 1)
					local d = (e.Order - f) / W
					if d > -3 and d < 3 then p = math.max(p, math.exp(-d * d)) end
				end
				if not lit then p *= 0.8 end
			else
				p = lit and (0.35 + 0.35 * math.sin(t * K.lerp(2.5, 8, insane) + e.Order * 0.02)) or 0
			end
			local c = base:Lerp(hot, p)
			-- the moment the green reaches it: a white flash
			if lit and t - e.T < 0.35 then c = c:Lerp(WHITE, 1 - (t - e.T) / 0.35) end
			e.Part.Color = c
		end
		-- the lungs fill and breathe
		local breath = K.k(t, 4.4, 7) * (0.5 + 0.5 * math.sin(t * K.lerp(2, 7, insane)))
		for _, L in ipairs(B.Lungs) do
			L.Mesh.Scale = L.Base * (1 + 0.08 * breath + insane * 0.05 * math.sin(t * 23))
			L.Part.Color = AIR:Lerp(LIME, K.k(t, 4.6, 6.8))
		end
		-- your skin turns green, and beats with the heart
		local sg = K.k(t, 5.2, 6.4)
		for _, p in ipairs(shellParts) do
			p.Color = Color3.fromRGB(255, 110, 130):Lerp(Color3.fromRGB(110, 255, 170), sg):Lerp(WHITE, pump * 0.15 * sg)
		end
		B.Cells.Rate = 45 * (1 - K.k(t, 3, 6))
		B.Sparks.Rate = K.lerp(0, 60, K.k(t, IGN, 7)) + insane * 400
		-- insane: everything strobes and surges
		if insane > 0 then
			for _ = 1, math.floor(60 + insane * 160) do
				local e = B.Parts[math.random(1, #B.Parts)]
				if e then e.Part.Color = FLICK[math.random(1, #FLICK)] end
			end
			for i, q in ipairs(B.Swirl) do
				q.Enabled = true
				K.moveQuad(q, CFrame.lookAt(Hc, K.Cam.CF.Position) * CFrame.Angles(0, 0, t * (i == 2 and -4 or 3)))
				local sz = ({ 300, 200, 520 })[i] * (0.6 + insane * 0.8 + pump * 0.2)
				K.setQuadSize(q, sz, sz)
			end
			K.Grade.TintColor = WHITE:Lerp(GREEN, 0.2 + 0.2 * math.sin(t * 30))
			K.Blur.Enabled = true
			K.Blur.Size = insane * (4 + 4 * math.sin(t * 25))
		end

		----------------------------------------------------------------
		-- camera
		----------------------------------------------------------------
		if t < 2.35 then
			if shot ~= 1 then shot = 1 cam.cut() end
			-- you, from outside... then straight in through your chest to your heart
			local e = K.E.inOutCubic and K.E.inOutCubic(K.k(t, 0.2, 2.35)) or SK.s(t, 0.2, 2.35)
			local from = V + Vector3.new(160, 30, -760)
			local to = Hc + Vector3.new(24, 12, -64)
			local p = from:Lerp(to, e)
			local tgt = (V + UP * 25):Lerp(Hc, K.k(e, 0, 0.7))
			cam.go(CFrame.lookAt(p, tgt) * CFrame.Angles(0, 0, e * 0.25), K.lerp(46, 64, e), dt, 12)
		elseif t < IGN + 0.2 then
			if shot ~= 2 then shot = 2 cam.cut() end
			-- right at your heart: the green pours in
			local a = 0.35 + (t - 2.35) * 0.3
			local p = Hc + Vector3.new(math.sin(a) * 68, 12, -math.cos(a) * 68)
			cam.go(CFrame.lookAt(p, Hc), 60, dt, 10)
			K.shake(0.3 + inflow * 0.8, 0.1, 18, true)
		elseif t < 5.5 then
			if shot ~= 3 then shot = 3 cam.cut() end
			-- chasing the first beat of green as it floods down through you
			local front = math.clamp((t - IGN - 0.15) / 2.8 * B.MaxA, 0, rideLen * 0.95)
			rideS = rideS and (rideS + (front - rideS) * math.min(1, dt * 4)) or 0
			local p = ride.at(rideS)
			cam.go(CFrame.lookAt(p + Vector3.new(55, 22, -125), p + Vector3.new(0, -12, 0)) * CFrame.Angles(0, 0, math.sin(t * 1.5) * 0.06), 58, dt, 9)
		elseif t < 7.5 then
			if shot ~= 4 then shot = 4 cam.cut() end
			-- round your chest: the lungs filling with light, the veins carrying it home
			local e = K.k(t, 5.5, 7.5, K.E.inOutSine)
			local a = -0.8 + e * 1.3
			local c = V + UP * 22
			local p = c + Vector3.new(math.sin(a) * 230, 30 - e * 20, -math.cos(a) * 230)
			cam.go(CFrame.lookAt(p, c), 60, dt, 7)
		elseif t < 8.6 then
			if shot ~= 5 then shot = 5 cam.cut() end
			-- all of you, alight, pulsing
			local e = K.k(t, 7.5, 8.6)
			local p = V + Vector3.new(-50, 35, -K.lerp(520, 440, e))
			cam.go(CFrame.lookAt(p, V + UP * 10), 52, dt, 7)
		else
			if shot ~= 6 then shot = 6 cam.cut() end
			-- it all goes wild: spiralling in to the blazing heart
			local e = K.k(t, 8.6, dur, K.E.inCubic)
			local a = -0.95 + e * 7
			local d = K.lerp(420, 40, e)
			local p = Hc + Vector3.new(math.sin(a) * d, K.lerp(80, 5, e), -math.cos(a) * d)
			cam.go(CFrame.lookAt(p, Hc) * CFrame.Angles(0, 0, e * 2), K.lerp(62, 100, e) + math.sin(t * 20) * 6 * insane, dt, 12)
			K.shake(1.2 + insane * 2, 0.1, 24, true)
		end

		cue("skin", t >= 1.3, function() K.sfx(K.S.Whoosh, 0.8, 1.4) end)
		cue("inflow", t >= 1.5, function()
			K.sfx(K.S.GreenAura, 0.9, 1)
			K.sfx(K.S.Riser, 0.7, 1.2)
		end)
		cue("ignite", t >= IGN, function()
			K.sfx(K.S.Boom, 0.9, 1.2)
			K.sfx(K.S.TonalHit, 0.8, 1.3)
			K.flash(0.3, GREEN, 0.7)
			K.kick(-8, 0.4)
			K.tween(K.Grade, 1, { TintColor = Color3.fromRGB(225, 255, 230), Saturation = 0.25 })
		end)
		cue("race", t >= IGN + 0.3, function() K.sfx(K.S.Electric, 0.8, 0.8) K.sfx(K.S.Rush, 0.7, 1.1) end)
		cue("lungs", t >= 4.6, function() K.sfx(K.S.Rush, 0.6, 1.4) end)
		cue("wild", t >= 8.4, function()
			K.sfx(K.S.Overdrive, 1, 1)
			K.sfx(K.S.Broly, 0.8, 1.2)
			K.sfx(K.S.Riser, 1, 1.4)
			ctx.fadeMusic(1, 0.5)
		end)
		cue("white", t >= dur - 0.3, function()
			K.fade(1, 0.25, WHITE)
		end)
	end)
	K.Blur.Enabled = false
	for _, q in ipairs(B.Swirl) do q.Enabled = false end
	B.Inflow.off()
	if shell then shell:destroy() end
	set.Parent = nil
	for _, rig in pairs(ctx.rigs) do rig.Model.Parent = ctx.stage end
end

------------------------------------------------------------------------
-- the stone stays in his chest from the Absorb on
------------------------------------------------------------------------
local shoutSpice
local function holdGem(ctx, SB, rootCF, t)
	local st = ctx.LapisSteal
	if not (st and st.Gem and st.Stolen) then return end
	local look = ctx.BossHome.LookVector
	local chest = SB.R.cf("UpperTorso", rootCF)
	local core = chest.Position + look * 60 + UP * 12
	st.Gem:PivotTo(CFrame.new(core) * (st.Off or CFrame.new()):Inverse() * CFrame.Angles(0, t * 0.8, 0))
	local H = ctx.HandFX
	if H then H.Core.set(core + look * 10, 100, 0.55 + 0.2 * math.sin(t * 4)) end
end

-- the True Lapeace's storm of light would blow out every close-up of the
-- party: it's dimmed for the shout and the last line, and back for the fight
local function shrineFx(ctx, on)
	local bf = SK.arena(ctx)
	local shrine = bf and bf:FindFirstChild("LapisShrine")
	if not shrine then return end
	ctx.ShrineFx = ctx.ShrineFx or {}
	for _, d in ipairs(shrine:GetDescendants()) do
		if d:IsA("Beam") or d:IsA("ParticleEmitter") or d:IsA("Light") then
			if not on then
				if ctx.ShrineFx[d] == nil then ctx.ShrineFx[d] = d.Enabled end
				d.Enabled = false
			elseif ctx.ShrineFx[d] ~= nil then
				d.Enabled = ctx.ShrineFx[d]
			end
		end
	end
	if on then ctx.ShrineFx = nil end
end
Ch.shrineFx = shrineFx

local function standCF(ctx, slot)
	local p = ctx.TL.ArenaStand(slot)
	local home = ctx.BossHome
	return CFrame.lookAt(p, Vector3.new(home.X, p.Y, home.Z))
end

-- after the fist bursts open they stay up in the realm (the arena isn't there
-- yet - it only appears when they land on it, at the very end): a line of them
-- hovering in the light, facing him
local function hoverCF(ctx, slot, t)
	local home = ctx.BossHome
	local c = ctx.HoverCentre or (SK.CATCH + UP * 60)
	local n = math.max(ctx.n or 1, 1)
	local face = home.Position + UP * 250
	local to = Vector3.new(face.X, c.Y, face.Z) - c
	local side = to.Unit:Cross(UP).Unit
	local p = c + side * (((slot - 1) - (n - 1) / 2) * 9) + UP * (math.sin(slot * 1.7) * 1.5 + math.sin((t or 0) * 1.3 + slot) * 0.8)
	return CFrame.lookAt(p, Vector3.new(face.X, p.Y, face.Z))
end
Ch.hoverCF = hoverCF

------------------------------------------------------------------------
-- TRANSFORM: the fist bursts open; spiral power; the Spiral Bat
------------------------------------------------------------------------
function Ch.Transform(ctx, t0, dur)
	local K = ctx.kit
	local A = ctx.Aw
	if ctx.restoreArena then ctx.restoreArena() end
	ctx.hideBoss(true)
	for _, name in ipairs({ "Arena", "Hand" }) do if ctx.sets[name] then ctx.sets[name].Parent = ctx.stage end end
	ctx.Boss.Parent = ctx.sets.Arena
	ctx.sets.Awaken.Parent = ctx.stage
	K.lighting("Arena", 0)
	K.Grade.TintColor = Color3.fromRGB(230, 255, 235)
	K.Grade.Saturation = 0.2
	K.Grade.Contrast = 0.2
	K.vignette(0.25, Color3.new(0, 0, 0), 0.3)
	K.Blur.Enabled = false
	K.Bloom.Intensity = 0.35
	K.Bloom.Threshold = 1.4
	K.fade(0, 0.25, WHITE)
	local SB = SK.boss(ctx, K)
	local home = ctx.BossHome
	local look, right = home.LookVector, home.RightVector
	local cue = K.once()
	local cam = SK.camera(K)
	local shot = 0
	local me = ctx.myRig
	for _, rig in pairs(ctx.rigs) do
		SK.powerUp(K, rig)
		rig.Smooth = 12
	end
	local BLAST = 0.9
	local base -- the palm surface at the moment it bursts open
	local startCF = {}
	local batIn = {}
	local LAND0, LAND1 = 7.8, 9.3
	SK.run(K, t0, dur, function(t, dt)
		----------------------------------------------------------------
		-- him: the fist blasted open, the giant thrown back
		----------------------------------------------------------------
		local recoil = K.k(t, BLAST, BLAST + 0.6, K.E.outCubic) * (1 - K.k(t, 3, 5.5, K.E.inOutSine) * 0.6)
		local rootCF = ctx.BossHome * CFrame.new(0, 60 + math.sin((t + 30) * 1.3) * 2, 0) * CFrame.new(0, -recoil * 10, recoil * 45) * CFrame.Angles(math.rad(recoil * 9), 0, 0)
		ctx.BossRoot.CFrame = rootCF
		SB.reset()
		local surf, hcf
		if t < 4.4 then
			SB.body({ Waist = K.A(-14 + recoil * 22, 10 - recoil * 20, 0), LeftShoulder = K.A(-5 + recoil * 60, 0, -30 - recoil * 30), LeftElbow = K.A(18 + recoil * 60, 0, 0) })
			SK.hang(SB, "Left", 0.3, 0.4)
			-- (from the fist he held them in, blown open and flung back)
			local palm = SK.holdPalm(ctx, t + 30, 1) + (-look * 70 + UP * 60 - right * 30) * recoil
			local R = SK.fistRot(home)
			local F = R.YVector:Lerp(UP, recoil * 0.6).Unit
			local N = R.ZVector:Lerp(-look + UP * 0.3, recoil)
			hcf = SB.hand("Right", palm, F, N, SK.FIST_POLE(home), rootCF)
			local shake = t < BLAST and K.k(t, 0, BLAST) or 0
			local curl = t < BLAST and 0.84 or K.lerp(0.84, -0.1, K.k(t, BLAST, BLAST + 0.25, K.E.outQuad))
			SB.Hands.Right.H.pose(curl, t < BLAST and -0.15 or 0.9, t < BLAST and 1 or 0, (t < BLAST and 2.5 + shake * 2 or 0.6 * (1 - K.k(t, BLAST, 3))), t)
			surf = CFrame.new(hcf:PointToWorldSpace(SK.fistSlot(ctx, 1)))
		else
			-- (standing tall again, arms down, staring at them)
			SB.body({ Waist = K.A(4, 0, 0), RightShoulder = K.A(-4, 0, 14), LeftShoulder = K.A(-4, 0, -14), RightElbow = K.A(12, 0, 0), LeftElbow = K.A(12, 0, 0) })
			SK.hang(SB, "Right", 0.55, 0.2)
			SK.hang(SB, "Left", 0.55, 0.2)
		end
		if not base and surf and t >= BLAST then base = surf end
		base = base or surf
		if base and t >= BLAST and not ctx.HoverCentre then ctx.HoverCentre = base.Position + UP * 58 end
		local headCF = SB.R.cf("Head", rootCF)
		holdGem(ctx, SB, rootCF, t)

		----------------------------------------------------------------
		-- the column of spiral power and the party rising in it
		----------------------------------------------------------------
		local col = base and base.Position or SK.CATCH
		local rise = K.k(t, BLAST + 0.2, 4.2, K.E.outCubic)
		local centre = col + UP * K.lerp(3, 58, rise)
		local power = K.k(t, BLAST, 3.2)
		local myPos
		for slot, rig in pairs(ctx.rigs) do
			local s = SK.palmSlot(ctx, slot)
			local cf, pose
			if t < BLAST then
				cf = SK.inFist(hcf, SK.fistSlot(ctx, slot), headCF.Position, 1)
				pose = SK.gripPose(K, t, slot, 0, 0.7)
				startCF[slot] = cf
			else
				-- floating up in the column, turning slowly round it... then, the power
				-- standing them up, drifting out into a line in the air, facing him
				local a = slot / math.max(ctx.n, 1) * math.pi * 2 + t * 0.4
				local r = ctx.n > 1 and K.lerp(6, 12, rise) or 0
				local p = centre + Vector3.new(math.cos(a) * r, math.sin(slot * 1.7) * 2 + math.sin(t * 1.3 + slot) * 0.8, math.sin(a) * r)
				local face = Vector3.new(headCF.Position.X, p.Y + 20, headCF.Position.Z)
				cf = CFrame.lookAt(p, face)
				if t < BLAST + 0.5 and startCF[slot] then cf = startCF[slot]:Lerp(cf, K.k(t, BLAST, BLAST + 0.5, K.E.outQuad)) end
				local line = K.k(t, LAND0, LAND0 + 1.2, K.E.inOutSine)
				if line > 0 then cf = cf:Lerp(hoverCF(ctx, slot, t), line) end
				-- head bowed, limp... then the eyes open and the power stands them up
				local wake = K.k(t, 4.5, 5.2, K.E.outBack)
				pose = K.mixPose(K.mixPose(K.Poses.Float, { Neck = K.A(-35, 0, 0), RS = K.A(10, 0, 25), LS = K.A(10, 0, -25) }, 1 - wake), K.Poses.Hero, wake)
				-- the bat raised to the sky
				local lift = K.k(t, 5.9, 6.5, K.E.outBack) * (1 - K.k(t, 7.4, 7.8))
				if lift > 0 then pose.RS = (pose.RS or CFrame.new()):Lerp(K.A(168, 0, 12), lift) end
			end
			rig:setCF(cf)
			rig:setPose(pose)
			rig:apply()
			SK.powerLevel(rig, t, power)
			if rig.SP then
				rig.SP.Aura.Rate = power * 40
				rig.SP.Sparks.Rate = power * 25
			end
			-- the bat forms in the hand, then becomes the Spiral Bat
			if t >= 5.8 and not batIn[slot] then
				batIn[slot] = true
				if not rig.Bat then rig:giveBat() end
				if rig.Bat then rig.Bat.LocalTransparencyModifier = 1 end
			end
			if rig.Bat and batIn[slot] then
				rig.Bat.LocalTransparencyModifier = 1 - K.k(t, 5.8, 6.3)
			end
			if rig == me then myPos = cf.Position end
		end
		myPos = myPos or centre

		-- effects in the column
		local on = t >= BLAST and t < LAND0 + 0.6
		local fade = K.k(t, LAND0 - 0.3, LAND0 + 0.6)
		A.Column.Enabled = on
		A.Column2.Enabled = on
		if on then
			A.Column.Attachment0.WorldPosition = col
			A.Column.Attachment1.WorldPosition = col + UP * 2500
			A.Column.Width0 = K.lerp(10, 36, power) * (1 - fade)
			A.Column.Width1 = K.lerp(20, 70, power) * (1 - fade)
			A.Column2.Attachment0.WorldPosition = col
			A.Column2.Attachment1.WorldPosition = col + UP * 2500
			A.Column2.Width0 = K.lerp(30, 110, power) * (1 - fade)
			A.Column2.Width1 = K.lerp(60, 180, power) * (1 - fade)
		end
		for i, b in ipairs(A.Helix) do
			local strand = i % 2
			local k = math.floor((i - 1) / 2)
			local u = k / 22
			local a = u * math.pi * 6 + t * 3 + strand * math.pi
			local r = 16 + math.sin(u * math.pi) * 6
			b.CFrame = CFrame.new(col + Vector3.new(math.cos(a) * r, u * 120 * rise, math.sin(a) * r))
			b.Transparency = on and (0.05 + fade) or 1
		end
		for _, d in ipairs(A.Discs) do
			d.Q.Enabled = on and fade < 0.99
			if d.Q.Enabled then
				K.moveQuad(d.Q, CFrame.lookAt(col + UP * 1, col + UP * 2) * CFrame.Angles(0, 0, t * d.W))
				local s = d.S * power * (1 - fade)
				K.setQuadSize(d.Q, s, s)
				d.Q.Brightness = 1.2
			end
		end
		-- the light bursting out of the fist
		local burst = t < BLAST + 0.4 and K.k(t, 0.1, BLAST) or (1 - K.k(t, BLAST + 0.4, BLAST + 1.2))
		local fist = (surf or base) and (surf or base).Position or SK.CATCH
		for _, s in ipairs(A.Shafts) do
			s.B.Enabled = burst > 0.02
			if s.B.Enabled then
				s.B.Attachment0.WorldPosition = fist
				s.B.Attachment1.WorldPosition = fist + s.Dir * s.L * (0.4 + burst)
				s.B.Width1 = 20 + burst * 40
			end
		end
		A.Glow.set(t < BLAST + 0.5 and fist or centre, t < BLAST + 0.5 and (60 + burst * 260) or 90, t < BLAST + 0.5 and burst or power * 0.18 * (1 - fade))

		----------------------------------------------------------------
		-- camera
		----------------------------------------------------------------
		local face = headCF.Position
		local head = me and me:head() and me:head().CFrame or CFrame.new(myPos)
		if t < BLAST + 0.45 then
			if shot ~= 1 then shot = 1 cam.cut() end
			-- his fist, blazing, and bursting
			local p = fist + right * 150 + look * 30 + UP * 10
			cam.go(CFrame.lookAt(p, fist), 50, dt, 10)
			K.shake(0.8 + K.k(t, 0, BLAST) * 1.5, 0.1, 22, true)
		elseif t < 3.2 then
			if shot ~= 2 then shot = 2 cam.cut() end
			-- beneath them, looking up the column as they rise
			local e = K.k(t, BLAST + 0.45, 3.2)
			local p = col + right * 55 + look * 25 + UP * K.lerp(-6, 20, e)
			cam.go(CFrame.lookAt(p, centre + UP * 4), K.lerp(62, 54, e), dt, 8)
		elseif t < 4.4 then
			if shot ~= 3 then shot = 3 cam.cut() end
			-- round them, floating in the light
			local a = t * 0.6
			local p = centre + Vector3.new(math.cos(a) * 34, 4, math.sin(a) * 34)
			cam.go(CFrame.lookAt(p, centre), 55, dt, 8)
		elseif t < 5.7 then
			if shot ~= 4 then shot = 4 cam.cut() end
			-- your face: the eyes open
			local p = head.Position + head.LookVector * 3 + head.RightVector * 0.5 - head.UpVector * 0.3
			cam.go(CFrame.lookAt(p, head.Position), K.lerp(45, 35, K.k(t, 4.4, 5.7)), dt, 10)
		elseif t < LAND0 then
			if shot ~= 5 then shot = 5 cam.cut() end
			-- low under the raised bat as it becomes a drill
			local rt = me and me:part("Right Arm")
			local hand = rt and (rt.CFrame * CFrame.new(0, -1, 0)).Position or head.Position
			local p = head.Position + head.LookVector * 12 - head.UpVector * 3 + head.RightVector * 5
			cam.go(CFrame.lookAt(p, hand:Lerp(head.Position, 0.3)), 52, dt, 9)
		elseif t < 9.6 then
			if shot ~= 6 then shot = 6 cam.cut() end
			-- in front of them as they spread out into a line in the air, blazing
			local st = hoverCF(ctx, ctx.me or 1, t)
			local e = K.k(t, LAND0, 9.6, K.E.outSine)
			local p = st.Position + st.LookVector * K.lerp(12, 20, e) + UP * K.lerp(-1, 2, e) + st.RightVector * 5
			cam.go(CFrame.lookAt(p, st.Position + UP * 1.5), K.lerp(55, 60, e), dt, 8)
		else
			if shot ~= 8 then shot = 8 cam.cut() end
			-- behind them: the party, blazing green in the void, facing the titan
			local st = hoverCF(ctx, ctx.me or 1, t)
			local p = st.Position - st.LookVector * 18 + UP * 2 + st.RightVector * 5
			cam.go(CFrame.lookAt(p, face:Lerp(st.Position, 0.35)), 52, dt, 6)
		end

		----------------------------------------------------------------
		-- beats
		----------------------------------------------------------------
		cue("rumble", t >= 0.05, function()
			K.sfx(K.S.Electric, 0.9, 0.7)
			K.sfx(K.S.Riser, 0.9, 1.5)
		end)
		cue("blast", t >= BLAST, function()
			K.sfx(K.S.Boom, 1, 0.8, { Reverb = 3 })
			K.sfx(K.S.BigHit, 1)
			K.sfx(K.S.GreenAura, 1, 1)
			K.sfx(K.S.Cannon, 0.8, 0.8)
			K.shake(5, 1.4)
			K.kick(20, 0.8)
			K.flash(0.4, GREEN, 1)
			local m = SK.models(ctx)
			table.insert(m, ctx.Boss)
			task.spawn(K.impact, m, "GBG", 0.05)
			ctx.setMusic(K.S.M_Battle, 0.85, 0.2)
			local c = fist
			local t1 = os.clock()
			local conn
			conn = game:GetService("RunService").RenderStepped:Connect(function()
				local u = math.clamp((os.clock() - t1) / 1.2, 0, 1)
				local r0 = 10 + 600 * (1 - (1 - u) ^ 3)
				A.Wave.update(CFrame.lookAt(c, c + UP), r0, r0 + 30 + u * 140, u * 2)
				A.Wave.setTransparency(math.min(0.99, 0.05 + u ^ 1.3 * 0.95))
				if u >= 1 then conn:Disconnect() end
			end)
			K.vfx("ForceField-Break-01", CFrame.new(c), A.FX, 8, 14, 4)
		end)
		cue("roar", t >= BLAST + 0.3, function() K.sfx(K.S.Hell, 0.8, 0.6) end)
		cue("eyes", t >= 4.55, function()
			K.sfx(K.S.TonalHit, 1, 1.2)
			K.sfx(K.S.Sting, 0.7, 1)
			K.flash(0.2, LIME, 0.6)
			K.kick(-8, 0.4)
			for _, rig in pairs(ctx.rigs) do
				if rig.SP then rig.SP.Sparks:Emit(40) end
			end
		end)
		cue("batIn", t >= 5.8, function()
			K.sfx(K.S.Ring, 0.8, 1.1)
			K.sfx(K.S.FireWhoosh, 0.7, 1.3)
		end)
		cue("spiralBat", t >= 6.7, function()
			for _, rig in pairs(ctx.rigs) do
				SK.spiralBat(K, rig)
				if rig.Bat then rig.Bat.LocalTransparencyModifier = 0 end
			end
			task.spawn(K.impact, SK.models(ctx), "GBG", 0.05)
			K.sfx(K.S.BigHit, 1)
			K.sfx(K.S.Broly, 0.8, 1.1)
			K.sfx(K.S.Overdrive, 0.8, 1.2)
			K.flash(0.5, GREEN, 0.7)
			K.shake(2.5, 1)
			K.kick(12, 0.7)
		end)
		K.stream(col)
	end)
	for _, s in ipairs(A.Shafts) do s.B.Enabled = false end
	A.Column.Enabled = false
	A.Column2.Enabled = false
	for _, b in ipairs(A.Helix) do b.Transparency = 1 end
	for _, d in ipairs(A.Discs) do d.Q.Enabled = false end
	A.Glow.set(SK.CATCH, 1, 0)
end

------------------------------------------------------------------------
-- SHOUT: JUST WHO THE HELL DO YOU THINK WE ARE!
------------------------------------------------------------------------
function Ch.Shout(ctx, t0, dur)
	local K = ctx.kit
	local A = ctx.Aw
	if ctx.restoreArena then ctx.restoreArena() end
	ctx.hideBoss(true)
	ctx.sets.Arena.Parent = ctx.stage
	ctx.Boss.Parent = ctx.sets.Arena
	ctx.sets.Awaken.Parent = ctx.stage
	local SB = SK.boss(ctx, K)
	local home = ctx.BossHome
	local cue = K.once()
	local cam = SK.camera(K)
	local shot = 0
	local me = ctx.myRig
	local order = {}
	for slot, rig in pairs(ctx.rigs) do
		SK.powerUp(K, rig)
		if not rig.Bat then rig:giveBat() end
		SK.spiralBat(K, rig)
		if rig ~= me then table.insert(order, slot) end
	end
	table.sort(order)
	-- quick cuts on up to two of the others, then you
	local cuts = {}
	for i = 1, math.min(2, #order) do table.insert(cuts, order[i]) end
	table.insert(cuts, ctx.me or 1)
	local HERO = 0.45 * #cuts
	local shoutText
	local speed = K.frame("ShoutLines", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 44 }, K.Gui)
	local lines = Instance.new("ImageLabel")
	lines.BackgroundTransparency = 1
	lines.Image = K.SpeedLines
	lines.ImageColor3 = Color3.fromRGB(255, 225, 170)
	lines.ImageTransparency = 1
	lines.AnchorPoint = Vector2.new(0.5, 0.5)
	lines.Position = UDim2.fromScale(0.5, 0.42)
	lines.Size = UDim2.fromScale(1.7, 1.7)
	lines.SizeConstraint = Enum.SizeConstraint.RelativeXX
	lines.ZIndex = 44
	lines.Parent = speed
	K.lighting("Arena", 0)
	K.Grade.TintColor = Color3.fromRGB(255, 245, 230)
	K.Grade.Saturation = 0.25
	K.Grade.Contrast = 0.22
	K.vignette(0.3, Color3.new(0, 0, 0), 0.3)
	local spice = shoutSpice(ctx)
	shrineFx(ctx, false)
	do
		local prev = ctx.onFight
		ctx.onFight = function()
			shrineFx(ctx, true)
			if prev then pcall(prev) else pcall(function() require(script.Parent:WaitForChild("ChArena")).onFight(ctx) end) end
		end
	end
	SK.run(K, t0, dur, function(t, dt)
		-- him: towering, staring
		local rootCF = home * CFrame.new(0, 60 + math.sin(t * 1.3) * 2, 25)
		ctx.BossRoot.CFrame = rootCF
		SB.reset()
		SB.body({ Waist = K.A(4, 0, 0), RightShoulder = K.A(-4, 0, 14), LeftShoulder = K.A(-4, 0, -14), RightElbow = K.A(12, 0, 0), LeftElbow = K.A(12, 0, 0) })
		SK.hang(SB, "Right", 0.55, 0.2)
		SK.hang(SB, "Left", 0.55, 0.2)
		holdGem(ctx, SB, rootCF, t)
		local face = SB.R.cf("Head", rootCF).Position
		SB.lookAt(hoverCF(ctx, ctx.me or 1, t).Position, 1, rootCF)
		-- the party: each throws the drill up at the sky
		for slot, rig in pairs(ctx.rigs) do
			local st = hoverCF(ctx, slot, t)
			local at = 0
			for i, s in ipairs(cuts) do if s == slot then at = (i - 1) * 0.45 end end
			if at == 0 and slot ~= cuts[1] then at = 0.2 + (slot % 3) * 0.1 end
			local u = K.k(t, at, at + 0.3, K.E.outBack)
			local pose = K.mixPose(K.Poses.Hero, K.Poses.PointUp, u)
			-- (a little breathing in the pose so nobody freezes solid)
			pose.Neck = (pose.Neck or CFrame.new()) * K.A(math.sin(t * 2 + slot) * 2, 0, 0)
			rig:setCF(st * CFrame.new(0, 0, 0))
			rig:setPose(pose)
			rig:apply()
			SK.powerLevel(rig, t, 1)
			if rig.SP then
				rig.SP.Aura.Rate = 14
				rig.SP.Aura.Size = K.ns(0, 2.2, 1, 0.3)
				rig.SP.Sparks.Rate = 20
			end
		end

		----------------------------------------------------------------
		-- camera
		----------------------------------------------------------------
		local heroOn = t >= HERO
		if not heroOn then
			local i = math.clamp(math.floor(t / 0.45) + 1, 1, #cuts)
			if shot ~= i then shot = i cam.cut() end
			-- snap-cuts: low, close, each one throwing their arm up
			local rig = ctx.rigs[cuts[i]]
			local st = hoverCF(ctx, cuts[i], t)
			local head = rig and rig:head() and rig:head().Position or st.Position + UP * 1.5
			local p = st.Position + st.LookVector * 5 - UP * 2.4 + st.RightVector * ((i % 2 == 0) and -2.5 or 2.5)
			cam.go(CFrame.lookAt(p, head + UP * 1.5) * CFrame.Angles(0, 0, (i % 2 == 0 and 1 or -1) * 0.12), 58, dt, 12)
		else
			if shot ~= 99 then shot = 99 cam.cut() end
			-- THE pose: from the ground at their feet, looking up at the raised drill
			local st = hoverCF(ctx, ctx.me or 1, t)
			local e = K.k(t, HERO, dur, K.E.outSine)
			local p = st.Position + st.LookVector * K.lerp(14, 12, e) - UP * 1.7 + st.RightVector * 2.2
			local tgt = st.Position + UP * 2.2
			cam.go(CFrame.lookAt(p, tgt) * CFrame.Angles(0, 0, -0.1), K.lerp(54, 48, e), dt, 10)
		end

		-- the burst of warm light behind the pose
		local burstOn = heroOn and t < dur - 0.3
		local camCF = K.Cam.CF
		local st = hoverCF(ctx, ctx.me or 1, t)
		local centre = st.Position + UP * 3
		local toCam = (camCF.Position - centre).Unit
		local bpos = centre - toCam * 110
		local grow = K.k(t, HERO, HERO + 0.35, K.E.outBack)
		local R = camCF.RightVector
		local U = camCF.UpVector
		for i, r in ipairs(A.Rays) do
			r.Q.Enabled = burstOn and (i % 2 == 1)
			if burstOn then
				local a = r.A + t * 0.12
				local dir = R * math.cos(a) + U * math.sin(a)
				local len = 260 * r.L * grow * (0.9 + 0.1 * math.sin(t * 3 + r.P))
				local wdt = 16 * r.W * grow * (0.8 + 0.3 * math.sin(t * 5 + r.P))
				local c = bpos + dir * (len * 0.5 + 30 * grow)
				local yv = toCam:Cross(dir)
				K.moveQuad(r.Q, CFrame.fromMatrix(c, dir, yv))
				K.setQuadSize(r.Q, len, wdt)
			end
		end
		A.BurstGlow.set(bpos, 170 * grow, burstOn and 0.28 or 0)
		A.BurstCore.set(bpos, 40 * grow * (1 + 0.1 * math.sin(t * 14)), burstOn and 0.55 or 0)
		lines.ImageTransparency = burstOn and (0.45 + 0.15 * math.sin(t * 20)) or 1
		lines.Rotation = t * 25
		spice(t, HERO + 0.25, 1)

		----------------------------------------------------------------
		-- beats
		----------------------------------------------------------------
		for i = 1, #cuts do
			cue("cut" .. i, t >= (i - 1) * 0.45, function()
				K.sfx(K.S.CutIn, 0.8, 1 + i * 0.08)
				K.sfx(K.S.Whoosh, 0.6, 1.4)
			end)
		end
		cue("hero", t >= HERO, function()
			K.flash(0.35, Color3.fromRGB(255, 240, 210), 0.9)
			K.sfx(K.S.TonalHit, 1, 1)
			K.sfx(K.S.BigHit, 1)
			K.sfx(K.S.Cannon, 0.6, 1.2)
			K.shake(2, 0.6)
		end)
		cue("shout", t >= HERO + 0.25, function()
			shoutText = SK.rainbowShout(K, "JUST WHO THE HELL\nDO YOU THINK WE ARE!", { Scale = 0.11, Position = UDim2.fromScale(0.5, 0.83), Per = 0.03 })
			K.sfx(K.S.Broly, 1, 1)
			K.sfx(K.S.Overdrive, 0.9, 1)
			K.sfx(K.S.GreenAura, 0.8, 1.1)
			K.shake(3.5, 1.4)
			K.kick(-10, 0.8)
			ctx.fadeMusic(1, 0.2)
			task.spawn(K.impact, SK.models(ctx), "YWY", 0.05)
		end)
		cue("end", t >= dur - 0.45, function()
			if shoutText then shoutText.stop() end
			K.flash(0.4, WHITE, 0.8)
		end)
	end)
	for _, r in ipairs(A.Rays) do r.Q.Enabled = false end
	A.BurstGlow.set(SK.CATCH, 1, 0)
	A.BurstCore.set(SK.CATCH, 1, 0)
	if shoutText then shoutText.stop() end
	speed:Destroy()
	-- (the drill, the rings and the column carry on into the last line)
end

------------------------------------------------------------------------
-- the extra punch on a shout: a giga drill of spiral power over the party,
-- spinning rings round their feet, a column of green into the sky, and a
-- rainbow pulse through the grade. Returns spice(t, at, amount).
------------------------------------------------------------------------
shoutSpice = function(ctx)
	local K = ctx.kit
	local A = ctx.Aw
	local mid, n = Vector3.zero, 0
	for slot in pairs(ctx.rigs) do mid += hoverCF(ctx, slot, 0).Position n += 1 end
	mid = n > 0 and mid / n or hoverCF(ctx, 1, 0).Position
	local floor = mid - UP * 3.2 -- (at their feet, up in the air)
	local cue = K.once()
	return function(t, at, amount)
		local u = K.k(t, at, at + 0.45, K.E.outBack) * (amount or 1)
		local on = u > 0.01
		-- the drill, point up, spinning
		for i, d in ipairs(A.Drill) do
			d.Part.Transparency = on and (d.Tr + (1 - d.Tr) * (1 - math.min(u, 1)) * 0.8) or 1
			if on then
				local sc = (i == 1 and 1 or 0.7) * u
				d.Part.Size = Vector3.new(34 * sc, 110 * sc, 34 * sc)
				d.Part.CFrame = CFrame.new(floor + UP * (70 + 70 * u)) * CFrame.Angles(0, t * (i == 1 and 7 or -9), 0)
			end
		end
		-- rings round their feet
		for i, q in ipairs(A.FloorRings) do
			q.Enabled = on
			if on then
				K.moveQuad(q, CFrame.lookAt(floor + UP * (0.3 + i * 0.1), floor + UP * 10) * CFrame.Angles(0, 0, t * (i == 2 and -3 or 2) + i))
				local sz = (40 + i * 22) * u * (1 + 0.06 * math.sin(t * 9 + i))
				K.setQuadSize(q, sz, sz)
			end
		end
		-- the column into the sky
		A.SkyCol.Enabled = on
		A.SkyCol2.Enabled = on
		if on then
			for _, b in ipairs({ A.SkyCol, A.SkyCol2 }) do
				b.Attachment0.WorldPosition = floor + UP * 120
				b.Attachment1.WorldPosition = floor + UP * (120 + 2400 * math.min(u, 1))
			end
			A.SkyCol.Width0 = 16 * u
			A.SkyCol.Width1 = 60 * u
			A.SkyCol2.Width0 = 50 * u
			A.SkyCol2.Width1 = 160 * u
		end
		-- a rainbow pulse through the picture as it hits
		local pulse = on and (1 - K.k(t, at + 0.1, at + 1.2)) or 0
		if pulse > 0 then K.Grade.TintColor = Color3.fromHSV((t * 2.4) % 1, 0.22 * pulse, 1) end
		cue("hit" .. at, on, function()
			K.sfx(K.S.Electric, 0.9, 0.9)
			K.sfx(K.S.FireWhoosh, 0.8, 0.8)
			for _, rig in pairs(ctx.rigs) do if rig.SP then rig.SP.Sparks:Emit(60) end end
		end)
	end
end
local function spiceOff(ctx)
	local A = ctx.Aw
	for _, d in ipairs(A.Drill) do d.Part.Transparency = 1 end
	for _, q in ipairs(A.FloorRings) do q.Enabled = false end
	A.SkyCol.Enabled = false
	A.SkyCol2.Enabled = false
end

------------------------------------------------------------------------
-- I AM: your own line, up in the void... then you and the Anti-Spiral both
-- drop and land at the same moment - and only now is the arena there, under
-- you. One last wide look at the two of you before the fight.
------------------------------------------------------------------------
function Ch.IAm(ctx, t0, dur)
	local K = ctx.kit
	local A = ctx.Aw
	if ctx.restoreArena then ctx.restoreArena() end
	ctx.hideBoss(true)
	ctx.sets.Arena.Parent = ctx.stage
	ctx.Boss.Parent = ctx.sets.Arena
	ctx.sets.Awaken.Parent = ctx.stage
	local SB = SK.boss(ctx, K)
	local home = ctx.BossHome
	local look, right = home.LookVector, home.RightVector
	local AC = ctx.TL.ArenaCenter
	local cue = K.once()
	local cam = SK.camera(K)
	local shot = 0
	local me = ctx.myRig
	local mine = ctx.me or 1
	local spice = shoutSpice(ctx)
	for _, rig in pairs(ctx.rigs) do
		SK.powerUp(K, rig)
		if not rig.Bat then rig:giveBat() end
		SK.spiralBat(K, rig)
	end
	local text
	local DROP, LAND = 2.7, 3.75 -- the fall, and the moment everyone hits the arena together
	K.lighting("Arena", 0)
	K.vignette(0.3, Color3.new(0, 0, 0), 0.3)
	local speed = K.frame("IAmLines", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 44 }, K.Gui)
	local lines = Instance.new("ImageLabel")
	lines.BackgroundTransparency = 1
	lines.Image = K.SpeedLines
	lines.ImageColor3 = Color3.fromRGB(190, 255, 200)
	lines.ImageTransparency = 1
	lines.AnchorPoint = Vector2.new(0.5, 0.5)
	lines.Position = UDim2.fromScale(0.5, 0.42)
	lines.Size = UDim2.fromScale(1.7, 1.7)
	lines.SizeConstraint = Enum.SizeConstraint.RelativeXX
	lines.ZIndex = 44
	lines.Parent = speed
	local from = {}
	SK.run(K, t0, dur, function(t, dt)
		----------------------------------------------------------------
		-- him: hovering... heaving himself up... and dropping onto the arena
		----------------------------------------------------------------
		local rise = K.k(t, DROP - 0.5, DROP, K.E.outQuad)
		local fall = K.k(t, DROP, LAND, K.E.inQuad)
		local y = t < DROP and (K.lerp(60, 150, rise) + math.sin(t * 1.3) * 2 * (1 - rise)) or K.lerp(150, 0, fall)
		local hit = t >= LAND and math.exp(-(t - LAND) / 0.25) * math.min((t - LAND) / 0.06, 1) or 0
		local rootCF = home * CFrame.new(0, y - hit * 16, K.lerp(25, 0, fall))
		ctx.BossRoot.CFrame = rootCF
		SB.reset()
		local stance = K.k(t, LAND + 0.1, LAND + 1.1, K.E.outBack)
		local brace = fall * (1 - K.k(t, LAND, LAND + 0.4))
		SB.body({
			Waist = K.A(K.lerp(4, -10, stance) - brace * 8 - hit * 10, 0, 0),
			RightShoulder = K.A(-4 + stance * 20 + brace * 35, 0, 14 + stance * 40 + brace * 35),
			LeftShoulder = K.A(-4 + stance * 20 + brace * 35, 0, -14 - stance * 40 - brace * 35),
			RightElbow = K.A(12 + stance * 30, 0, 0), LeftElbow = K.A(12 + stance * 30, 0, 0),
		})
		SK.hang(SB, "Right", K.lerp(0.55, 0.85, stance), 0.2)
		SK.hang(SB, "Left", K.lerp(0.55, 0.85, stance), 0.2)
		local face = SB.R.cf("Head", rootCF).Position
		SB.lookAt(t < LAND and hoverCF(ctx, mine, t).Position or standCF(ctx, mine).Position, 1, rootCF)

		----------------------------------------------------------------
		-- the party: you point the Spiral Bat at him... then everyone drops
		----------------------------------------------------------------
		local myPos
		for slot, rig in pairs(ctx.rigs) do
			local stand = standCF(ctx, slot)
			local cf, pose
			if t < DROP then
				cf = hoverCF(ctx, slot, t)
				from[slot] = cf
				if slot == mine then
					local u = K.k(t, 0.15, 0.45, K.E.outBack)
					pose = K.mixPose(K.Poses.PointUp, K.Poses.Reach, u)
					pose.RS = (pose.RS or CFrame.new()):Lerp(K.A(95, 0, -6), u)
					pose.Neck = K.A(K.lerp(20, 8, u), 0, 0)
				else
					pose = K.Poses.PointUp
				end
			elseif t < LAND then
				-- the drop: a short hop out of the line, then straight down with him
				local u = K.k(t, DROP, LAND, K.E.inQuad)
				local p0 = (from[slot] or hoverCF(ctx, slot, t)).Position
				local p2 = stand.Position
				local p1 = p0:Lerp(p2, 0.35) + UP * 30
				local p = p0:Lerp(p1, u):Lerp(p1:Lerp(p2, u), u)
				local ahead = Vector3.new(p2.X - p0.X, 0, p2.Z - p0.Z)
				ahead = ahead.Magnitude > 1e-3 and ahead.Unit or stand.LookVector
				cf = CFrame.lookAt(p, p + ahead) * CFrame.Angles(math.rad(-30) * math.sin(math.pi * u), 0, 0)
				pose = K.mixPose(K.Poses.Launch, K.Poses.Crouch, K.k(u, 0.55, 1))
			else
				-- the landing: down on one knee... and up, bat ready
				local up2 = K.k(t, LAND + 0.45, LAND + 1.2, K.E.inOutSine)
				cf = stand * CFrame.new(0, K.lerp(-1.2, 0, up2), 0)
				pose = K.mixPose(K.Poses.Kneel, K.Poses.Hero, up2)
			end
			rig:setCF(cf)
			rig:setPose(pose)
			rig:apply()
			SK.powerLevel(rig, t, 1)
			if rig.SP then
				rig.SP.Aura.Rate = 14
				rig.SP.Sparks.Rate = 20
			end
			if rig == me then myPos = cf.Position end
		end
		myPos = myPos or hoverCF(ctx, mine, t).Position
		-- (the drill and the rings die away as they drop)
		spice(t, 0, 1 - K.k(t, DROP - 0.4, DROP))

		----------------------------------------------------------------
		-- camera
		----------------------------------------------------------------
		if t < DROP then
			if shot ~= 1 then shot = 1 cam.cut() end
			-- you, low and close, the drill of light above, him beyond
			local hov = hoverCF(ctx, mine, t)
			local head = me and me:head() and me:head().CFrame or hov * CFrame.new(0, 1.5, 0)
			local e = K.k(t, 0, DROP, K.E.outSine)
			local p = head.Position + hov.LookVector * K.lerp(6, 9, e) - UP * K.lerp(2, 1.2, e) + hov.RightVector * K.lerp(2.2, 3.4, e)
			local tgt = head.Position + (face - head.Position).Unit * K.lerp(0.3, 1.6, e) - UP * 0.4
			cam.go(CFrame.lookAt(p, tgt) * CFrame.Angles(0, 0, -0.08), K.lerp(46, 56, e), dt, 12)
		elseif t < LAND then
			if shot ~= 2 then shot = 2 cam.cut() end
			-- dropping with you, him dropping beyond: nothing below yet but the void
			local to = Vector3.new(face.X - myPos.X, 0, face.Z - myPos.Z).Unit
			local sd = to:Cross(UP).Unit
			local p = myPos - to * 22 + UP * 9 + sd * 8
			cam.go(CFrame.lookAt(p, myPos:Lerp(face, 0.25)), 62, dt, 10, myPos)
		else
			if shot ~= 3 then shot = 3 cam.cut() end
			-- THE final look: the arena, the titan and the party, facing off
			local e = K.k(t, LAND, dur, K.E.outSine)
			local a = K.lerp(-0.55, -0.35, e)
			local dir = CFrame.Angles(0, a, 0):VectorToWorldSpace(-right)
			local p = AC + dir * K.lerp(640, 560, e) + UP * K.lerp(190, 150, e)
			cam.go(CFrame.lookAt(p, AC + UP * K.lerp(90, 70, e)), K.lerp(58, 54, e), dt, 6)
		end
		lines.ImageTransparency = (t > 0.35 and t < DROP - 0.2) and (0.5 + 0.15 * math.sin(t * 20)) or 1
		lines.Rotation = t * 25

		----------------------------------------------------------------
		-- beats
		----------------------------------------------------------------
		cue("line", t >= 0.35, function()
			text = SK.rainbowShout(K, "JUST WHO THE HELL\nDO YOU THINK I AM!", { Scale = 0.12, Position = UDim2.fromScale(0.5, 0.8), Per = 0.03 })
			K.sfx(K.S.Broly, 1, 1.05)
			K.sfx(K.S.Overdrive, 0.9, 1.1)
			K.sfx(K.S.TonalHit, 1, 1.1)
			K.shake(3.5, 1.2)
			K.kick(-12, 0.8)
			K.flash(0.3, Color3.fromRGB(220, 255, 220), 0.8)
			task.spawn(K.impact, { me and me.Model }, "GWG", 0.05)
		end)
		cue("drop", t >= DROP - 0.5, function()
			if text then text.stop() end
			K.sfx(K.S.Hell, 0.8, 0.5, { Reverb = 3 })
			K.sfx(K.S.Whoosh, 1, 0.7)
		end)
		cue("fall", t >= DROP, function()
			K.sfx(K.S.FireWhoosh, 0.9, 0.8)
			K.sfx(K.S.Rush, 0.7, 1.2)
		end)
		cue("land", t >= LAND, function()
			-- and there it is, under all of you
			ctx.arenaMap(true)
			K.flash(0.5, WHITE, 1)
			K.sfx(K.S.Boom, 1, 0.7, { Reverb = 3 })
			K.sfx(K.S.BigHit, 1, 0.6)
			K.sfx(K.S.RockBoom, 1, 0.5)
			K.sfx(K.S.Thump, 1)
			K.shake(5, 1.5, 12)
			K.kick(-10, 0.6)
			local c = AC + UP * 1
			local t1 = os.clock()
			local conn
			conn = game:GetService("RunService").RenderStepped:Connect(function()
				local u = math.clamp((os.clock() - t1) / 1.3, 0, 1)
				local r0 = 20 + 700 * (1 - (1 - u) ^ 3)
				A.Wave.update(CFrame.lookAt(c, c + UP), r0, r0 + 40 + u * 150, u * 2)
				A.Wave.setTransparency(math.min(0.99, 0.05 + u ^ 1.3 * 0.95))
				if u >= 1 then conn:Disconnect() end
			end)
			for slot in pairs(ctx.rigs) do
				local p = standCF(ctx, slot).Position
				K.vfx("Shoot-01", CFrame.new(p.X, AC.Y + 0.6, p.Z) * CFrame.Angles(math.rad(90), 0, 0), A.FX, 0.9, 2, 2)
			end
		end)
		cue("roar", t >= LAND + 0.8, function()
			K.sfx(K.S.Hell, 0.9, 0.5, { Reverb = 3 })
			K.shake(2.5, 1.4, 12)
		end)
		K.stream(t < LAND and myPos or AC)
	end)
	if text then text.stop() end
	spiceOff(ctx)
	speed:Destroy()
end

return Ch
