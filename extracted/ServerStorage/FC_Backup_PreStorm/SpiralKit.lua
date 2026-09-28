--==================================================
-- SPIRAL KIT
-- Shared tools for the Spiral Galaxy half of the final cutscene
-- (ChEntry, ChHand, ChAwaken): a smooth chapter clock, smooth
-- paths, a damped camera, the Anti-Spiral's arm IK and his
-- giant catching hand, 4-D tesseracts, shattering panes, spiral
-- energy streams and the rainbow shout.
--==================================================
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local SK = {}

SK.GREEN = Color3.fromRGB(70, 255, 120)
SK.LIME = Color3.fromRGB(190, 255, 90)
SK.VIOLET = Color3.fromRGB(150, 90, 255)
SK.CYAN = Color3.fromRGB(90, 220, 255)

--------------------------------------------------------------------------
-- a smooth chapter clock
-- K.run hands each frame the raw server clock, which nudges back and forth
-- as the client re-syncs (that's the stutter in fast moves). This runs on
-- the local clock and eases toward the server's, so motion stays silky but
-- every client still ends up in step. (A frozen review clock holds it still.)
--------------------------------------------------------------------------
function SK.run(K, t0, dur, fn)
	local done = false
	local name = "FC_SRun_" .. tostring(math.random(1, 1e9))
	local lastServer = K.now()
	local t = math.max(0, lastServer - t0)
	local lastClock = os.clock()
	local traced = false
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 5, function()
		local now = os.clock()
		local dt = math.min(now - lastClock, 0.1)
		lastClock = now
		local s = K.now()
		local advanced = s > lastServer + 1e-5
		lastServer = s
		local target = s - t0
		if advanced then t += dt end
		local err = target - t
		if math.abs(err) > 0.35 then t = target else t += err * math.min(1, dt * 1.5) end
		if t >= dur then done = true return end
		local ok, e = xpcall(fn, debug.traceback, math.max(t, 0), advanced and dt or 0)
		if not ok then
			if not traced then traced = true warn("[FinalCutscene] " .. tostring(e)) else warn("[FinalCutscene] " .. tostring(e):match("^[^\n]*")) end
		end
	end)
	while not done and not K.Aborted do RunService.RenderStepped:Wait() end
	RunService:UnbindFromRenderStep(name)
	pcall(fn, dur, 0)
end

--------------------------------------------------------------------------
-- a camera that glides: follows its target with critical damping, so a
-- shot that tracks a tumbling body never jitters; cut() jumps cleanly
--------------------------------------------------------------------------
function SK.camera(K)
	local c = { CF = nil, Fov = 70, Snap = true }
	function c.cut() c.Snap = true c.Anchor = nil end
	-- anchor: the point the shot is following; the camera is carried along with it
	-- exactly, and only the framing is smoothed (so a fast fall never lags off-screen)
	function c.go(cf, fov, dt, sharp, anchor)
		fov = fov or c.Fov
		if anchor and c.Anchor and c.CF and not c.Snap then c.CF = c.CF + (anchor - c.Anchor) end
		c.Anchor = anchor
		if c.Snap or not c.CF or not dt or dt <= 0 then
			if c.Snap or not c.CF then c.CF, c.Fov = cf, fov end
			c.Snap = false
		else
			local a = 1 - math.exp(-(sharp or 10) * dt)
			c.CF = c.CF:Lerp(cf, a)
			c.Fov = c.Fov + (fov - c.Fov) * a
		end
		K.setCam(c.CF, c.Fov)
	end
	return c
end

--------------------------------------------------------------------------
-- smooth paths through timed points (Hermite, so speed is continuous too)
--------------------------------------------------------------------------
function SK.path(keys)
	-- keys = { {t, Vector3}, ... } sorted by t
	local n = #keys
	local m = {}
	for i = 1, n do
		local a = keys[math.max(i - 1, 1)]
		local b = keys[math.min(i + 1, n)]
		local dt = b[1] - a[1]
		m[i] = dt > 0 and (b[2] - a[2]) / dt or Vector3.zero
	end
	local P = {}
	function P.at(t)
		if t <= keys[1][1] then return keys[1][2] + m[1] * (t - keys[1][1]) end
		if t >= keys[n][1] then return keys[n][2] + m[n] * (t - keys[n][1]) end
		local i = 1
		while keys[i + 1][1] < t do i += 1 end
		local t0, t1 = keys[i][1], keys[i + 1][1]
		local h = t1 - t0
		local u = (t - t0) / h
		local u2, u3 = u * u, u * u * u
		return keys[i][2] * (2 * u3 - 3 * u2 + 1) + m[i] * h * (u3 - 2 * u2 + u) + keys[i + 1][2] * (-2 * u3 + 3 * u2) + m[i + 1] * h * (u3 - u2)
	end
	function P.vel(t)
		local e = 0.02
		return (P.at(t + e) - P.at(t - e)) / (2 * e)
	end
	return P
end

-- 0..1 smoothly over [a, b]
function SK.s(x, a, b)
	local u = math.clamp((x - a) / (b - a), 0, 1)
	return u * u * (3 - 2 * u)
end

--------------------------------------------------------------------------
-- where things live
--------------------------------------------------------------------------
function SK.arena(ctx)
	return workspace:FindFirstChild("BossFight") or ctx.StashedArena
end
function SK.realm(ctx)
	local bf = SK.arena(ctx)
	return bf and bf:FindFirstChild("GalaxyRealm")
end

-- formation offsets for the party around a centre (tight enough to share a palm)
function SK.offset(ctx, slot, spread)
	local n = math.max(ctx.n or 1, 1)
	if n <= 1 then return Vector3.zero end
	local a = (slot - 1) / n * math.pi * 2 + 0.4
	local r = (spread or 5) * (0.7 + 0.15 * n)
	return Vector3.new(math.cos(a) * r, math.sin(slot * 1.7) * 1.2, math.sin(a) * r)
end

-- a body tumbling out of control: smooth, never jittery (no high-frequency noise)
function SK.tumble(K, t, slot, amount)
	local base = K.mixPose(K.Poses.Blown, K.Poses.Tumble, 0.5 + 0.5 * math.sin(t * 0.9 + slot))
	local wob = K.zeroGPose(t * 2.2, slot, 1.6 * (amount or 1))
	return K.safeArms(K.mixPose(base, wob, 0.55))
end

--------------------------------------------------------------------------
-- THE ANTI-SPIRAL'S BODY: forward kinematics + two-bone arm IK
-- (all worked out from the joints themselves, so it's exact on the frame)
--------------------------------------------------------------------------
function SK.bossRig(ctx)
	local boss = ctx.Boss
	local J, B = {}, {}
	for _, d in ipairs(boss:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			J[d.Name .. "@" .. d.Part1.Name] = d
			J[d.Name] = J[d.Name] or d
			B[d] = { C0 = d.C0, C1 = d.C1 }
		end
	end
	local R = { Boss = boss, J = J, B = B, Root = ctx.BossRoot, Rot = {} }
	local function joint(name, part1) return J[name .. "@" .. part1] or J[name] end
	R.joint = joint
	-- set a joint's rotation (in its parent part's space)
	function R.set(name, part1, rot)
		local m = joint(name, part1)
		if not m then return end
		local b = B[m]
		m.C0 = CFrame.new(b.C0.Position) * rot * b.C0.Rotation
		R.Rot[m] = rot
	end
	function R.clear()
		for m, b in pairs(B) do m.C0 = b.C0 end
		R.Rot = {}
	end
	-- world CFrame of a part, following the chain from the root with the rotations set so far
	local chainOf = { LowerTorso = { "Root", "LowerTorso" }, UpperTorso = { "Waist", "UpperTorso" }, Head = { "Neck", "Head" },
		RightUpperArm = { "RightShoulder", "RightUpperArm" }, RightLowerArm = { "RightElbow", "RightLowerArm" }, RightHand = { "RightWrist", "RightHand" },
		LeftUpperArm = { "LeftShoulder", "LeftUpperArm" }, LeftLowerArm = { "LeftElbow", "LeftLowerArm" }, LeftHand = { "LeftWrist", "LeftHand" } }
	local parentOf = { LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso", RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm",
		RightHand = "RightLowerArm", LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm" }
	function R.cf(partName, rootCF)
		if partName == "HumanoidRootPart" then return rootCF or R.Root.CFrame end
		local c = chainOf[partName]
		local m = joint(c[1], c[2])
		local pcf = R.cf(parentOf[partName], rootCF)
		return pcf * m.C0 * m.C1:Inverse()
	end
	-- aim an arm so its wrist lands on `target` (world), elbow bending toward `pole`
	function R.reach(side, target, pole, rootCF)
		local S, E, W = side .. "Shoulder", side .. "Elbow", side .. "Wrist"
		local UA, LA = side .. "UpperArm", side .. "LowerArm"
		local ms, me, mw = joint(S, UA), joint(E, LA), joint(W, side .. "Hand")
		local bs, be, bw = B[ms], B[me], B[mw]
		local ut = R.cf("UpperTorso", rootCF)
		local sW = (ut * CFrame.new(bs.C0.Position)).Position
		local sJ = bs.C1.Position            -- shoulder joint in the upper arm
		local eJ = be.C0.Position            -- elbow joint in the upper arm
		local eL = be.C1.Position            -- elbow joint in the lower arm
		local wL = bw.C0.Position            -- wrist joint in the lower arm
		local Lu, Ll = (eJ - sJ).Magnitude, (wL - eL).Magnitude
		local toT = target - sW
		local d = math.clamp(toT.Magnitude, math.abs(Lu - Ll) + 1, Lu + Ll - 1)
		local dir = toT.Magnitude > 1e-3 and toT.Unit or -Vector3.yAxis
		local a = (Lu * Lu - Ll * Ll + d * d) / (2 * d)
		local h = math.sqrt(math.max(Lu * Lu - a * a, 0))
		local bend = pole - dir * pole:Dot(dir)
		bend = bend.Magnitude > 1e-3 and bend.Unit or dir:Cross(Vector3.xAxis).Unit
		local eW = sW + dir * a + bend * h
		local wW = sW + dir * d
		local function aim(localA, localRef, worldA, worldRef)
			-- the rotation taking localA -> worldA (twist fixed by the ref axes)
			local la = localA.Unit
			local lr = (localRef - la * localRef:Dot(la)).Unit
			local lc = la:Cross(lr)
			local wa = worldA.Unit
			local wr = (worldRef - wa * worldRef:Dot(wa))
			wr = wr.Magnitude > 1e-3 and wr.Unit or wa:Cross(Vector3.yAxis).Unit
			local wc = wa:Cross(wr)
			local Lm = CFrame.fromMatrix(Vector3.zero, la, lr, lc)
			local Wm = CFrame.fromMatrix(Vector3.zero, wa, wr, wc)
			return Wm * Lm:Inverse()
		end
		local side3 = bend:Cross(dir)
		-- upper arm
		local Rua = aim(eJ - sJ, Vector3.new(0, 0, 1), eW - sW, side3)
		local uaCF = CFrame.new(sW - Rua * sJ) * Rua
		local rs = (ut * CFrame.new(bs.C0.Position)):Inverse() * uaCF * bs.C1
		ms.C0 = CFrame.new(bs.C0.Position) * rs.Rotation * bs.C0.Rotation
		-- lower arm
		local Rla = aim(wL - eL, Vector3.new(0, 0, 1), wW - eW, side3)
		local laCF = CFrame.new(eW - Rla * eL) * Rla
		local re = (uaCF * CFrame.new(be.C0.Position)):Inverse() * laCF * be.C1
		me.C0 = CFrame.new(be.C0.Position) * re.Rotation * be.C0.Rotation
		return laCF, wW
	end
	return R
end

--------------------------------------------------------------------------
-- THE GIANT HAND: palm + jointed fingers, welded to his forearm, in his
-- black-and-white look. pose(curl, spread) opens or closes it.
-- Hand space: +Y along the fingers, palm faces +Z, thumb on +X.
--------------------------------------------------------------------------
function SK.giantHand(K, lowerArm, wristC0, parent, opts)
	opts = opts or {}
	local mirror = opts.Left and -1 or 1
	local model = Instance.new("Model")
	model.Name = opts.Name or "GiantHand"
	local col = Color3.fromRGB(17, 17, 17)
	local function part(name, shape, size)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.Material = Enum.Material.Neon
		p.Color = col
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Anchored = false
		p.Parent = model
		return p
	end
	local function weld(p0, p1, c0)
		local w = Instance.new("Weld")
		w.Part0 = p0
		w.Part1 = p1
		w.C0 = c0
		w.Parent = p1
		return w
	end
	local S = opts.Scale or 1
	local palmW, palmL, palmT = 50 * S, 54 * S, 17 * S
	local palm = part("Palm", Enum.PartType.Block, Vector3.new(palmW, palmL, palmT))
	local pm = Instance.new("SpecialMesh")
	pm.MeshType = Enum.MeshType.Sphere -- (a rounded palm, not a box)
	pm.Scale = Vector3.new(1.05, 1.1, 1)
	pm.Parent = palm
	local wristW = weld(lowerArm, palm, wristC0 * CFrame.new(0, 0, 0))
	-- the heel of the hand: a thick rounded wrist that overlaps back into the forearm,
	-- so from any angle the hand grows out of the arm instead of sitting against it
	local heel = part("Heel", Enum.PartType.Block, Vector3.new(palmW * 0.9, palmL * 0.75, palmT * 2.1))
	local hm = Instance.new("SpecialMesh")
	hm.MeshType = Enum.MeshType.Sphere
	hm.Parent = heel
	weld(palm, heel, CFrame.new(0, -palmL * 0.42, 0))
	local H = { Model = model, Palm = palm, WristWeld = wristW, WristC0 = wristC0, Fingers = {}, Size = Vector3.new(palmW, palmL, palmT) }
	-- fingers: x across the palm, length, radius
	local defs = {
		{ X = -0.36, L = 40, R = 6.2 }, -- pinky side (-X for a right hand)
		{ X = -0.12, L = 47, R = 7.0 },
		{ X = 0.12, L = 50, R = 7.4 },
		{ X = 0.36, L = 46, R = 7.0 },
	}
	for fi, fd in ipairs(defs) do
		local segs = {}
		local prev = palm
		local prevC0 = CFrame.new(fd.X * palmW * mirror, palmL * 0.47, 0)
		local lens = { 0.44, 0.32, 0.24 }
		for si = 1, 3 do
			local L = fd.L * S * lens[si]
			local r = fd.R * S * (1 - (si - 1) * 0.1)
			-- a knuckle (ball) and the bone (cylinder along +Y)
			local knuckle = part("K" .. fi .. si, Enum.PartType.Ball, Vector3.one * r * 2.05)
			local bone = part("F" .. fi .. si, Enum.PartType.Cylinder, Vector3.new(L, r * 2, r * 2))
			local kw = weld(prev, knuckle, prevC0)
			local bw = weld(knuckle, bone, CFrame.new(0, L / 2, 0) * CFrame.Angles(0, 0, math.rad(90)))
			table.insert(segs, { Knuckle = knuckle, Weld = kw, Base = prevC0, L = L })
			prev = knuckle
			prevC0 = CFrame.new(0, L, 0)
			if si == 3 then
				local tip = part("T" .. fi, Enum.PartType.Ball, Vector3.one * r * 1.9)
				weld(knuckle, tip, CFrame.new(0, L, 0))
			end
		end
		table.insert(H.Fingers, { Segs = segs, X = fd.X })
	end
	-- the thumb, off the side of the palm, angled out and forward
	do
		local segs = {}
		local prev = palm
		local prevC0 = CFrame.new(0.5 * palmW * mirror, -palmL * 0.08, palmT * 0.2) * CFrame.Angles(0, 0, math.rad(-42) * mirror)
		for si = 1, 2 do
			local L = 22 * S
			local r = 7.4 * S * (1 - (si - 1) * 0.12)
			local knuckle = part("KT" .. si, Enum.PartType.Ball, Vector3.one * r * 2.05)
			local bone = part("FT" .. si, Enum.PartType.Cylinder, Vector3.new(L, r * 2, r * 2))
			local kw = weld(prev, knuckle, prevC0)
			weld(knuckle, bone, CFrame.new(0, L / 2, 0) * CFrame.Angles(0, 0, math.rad(90)))
			table.insert(segs, { Knuckle = knuckle, Weld = kw, Base = prevC0, L = L })
			prev = knuckle
			prevC0 = CFrame.new(0, L, 0)
		end
		local tip = part("TT", Enum.PartType.Ball, Vector3.one * 12 * S)
		weld(prev, tip, CFrame.new(0, 22 * S, 0))
		H.Thumb = { Segs = segs }
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.new(0, 0, 0)
	hl.FillTransparency = 0.99
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model
	H.HL = hl
	model.Parent = parent
	-- curl 0 = flat open, 1 = a closed fist; spread fans the fingers; thumb 0..1 folds it in
	function H.pose(curl, spread, thumb, tremble, t)
		curl = curl or 0
		spread = spread or 0
		for fi, f in ipairs(H.Fingers) do
			local fan = (f.X) * (0.5 + spread) * 0.9 * mirror
			for si, s in ipairs(f.Segs) do
				local c = curl * ({ 80, 95, 70 })[si] + (tremble or 0) * math.sin((t or 0) * 23 + fi * 1.7 + si) * 3
				local rot = CFrame.Angles(math.rad(c), 0, 0)
				if si == 1 then rot = CFrame.Angles(0, 0, -fan) * rot end
				s.Weld.C0 = s.Base * rot
			end
		end
		for si, s in ipairs(H.Thumb.Segs) do
			local c = (thumb or curl) * ({ 55, 60 })[si]
			s.Weld.C0 = s.Base * CFrame.Angles(math.rad(c), math.rad(-(thumb or curl) * 30) * mirror, 0)
		end
	end
	-- the palm's surface in world space (where the party stands)
	function H.palmCF(laCF)
		local wcf = (laCF or H.WristWeld.Part0.CFrame) * H.WristWeld.C0
		return wcf * CFrame.new(0, 0, palmT * 0.5)
	end
	function H.setWrist(c0)
		H.WristWeld.C0 = c0
		H.WristC0 = c0
	end
	H.pose(0, 0, 0)
	return H
end

--------------------------------------------------------------------------
-- A TESSERACT: a 4-D hypercube turning through the 4th dimension,
-- projected into 3-D and drawn as glowing edges
--------------------------------------------------------------------------
function SK.tesseract(K, host, color, width)
	local verts = {}
	for i = 0, 15 do
		verts[i + 1] = { (i % 2 == 0) and -1 or 1, (math.floor(i / 2) % 2 == 0) and -1 or 1, (math.floor(i / 4) % 2 == 0) and -1 or 1, (math.floor(i / 8) % 2 == 0) and -1 or 1 }
	end
	local edges = {}
	for a = 1, 16 do
		for b = a + 1, 16 do
			local diff = 0
			for k = 1, 4 do if verts[a][k] ~= verts[b][k] then diff += 1 end end
			if diff == 1 then table.insert(edges, { a, b }) end
		end
	end
	local beams = {}
	for i, e in ipairs(edges) do
		local b = K.ray(host, Vector3.zero, Vector3.yAxis, width, width, "10365550877", {
			Color = color, Brightness = 3, Transparency = 0.15, Segments = 1, Mode = Enum.TextureMode.Wrap, Length = 60, Speed = 1.5,
		})
		beams[i] = b
	end
	local T = { Beams = beams, Width = width, Visible = true }
	function T.update(cf, size, a1, a2, a3, alpha)
		local p3 = {}
		local c1, s1 = math.cos(a1), math.sin(a1)
		local c2, s2 = math.cos(a2), math.sin(a2)
		local c3, s3 = math.cos(a3), math.sin(a3)
		for i, v in ipairs(verts) do
			local x, y, z, w = v[1], v[2], v[3], v[4]
			-- rotate in the XW, YW and ZX planes
			x, w = x * c1 - w * s1, x * s1 + w * c1
			y, w = y * c2 - w * s2, y * s2 + w * c2
			z, x = z * c3 - x * s3, z * s3 + x * c3
			local f = 2.6 / (2.6 - w * 0.9)
			p3[i] = { cf:PointToWorldSpace(Vector3.new(x, y, z) * f * size), f }
		end
		for i, e in ipairs(edges) do
			local b = beams[i]
			local A, B = p3[e[1]], p3[e[2]]
			b.Attachment0.WorldPosition = A[1]
			b.Attachment1.WorldPosition = B[1]
			b.Width0 = T.Width * A[2]
			b.Width1 = T.Width * B[2]
			if alpha then b.Transparency = NumberSequence.new(alpha) end
		end
	end
	function T.show(on)
		if T.Visible == on then return end
		T.Visible = on
		for _, b in ipairs(beams) do b.Enabled = on end
	end
	return T
end

--------------------------------------------------------------------------
-- A 4-D PANE: a vast sheet of crystal lattice (a hexagonal grid of light
-- lines on smoked glass) - the membrane between two layers of space.
-- break(point, dir) smashes it: shards, a ring, the glass-break flash.
--------------------------------------------------------------------------
function SK.pane(K, parent, cf, size, color, accent)
	local model = Instance.new("Model")
	model.Name = "Pane"
	local host = K.part({ Name = "PaneHost", Size = Vector3.one, Transparency = 1, CFrame = cf }, model)
	-- the sheet itself (glass, so it catches the light and tints what's behind)
	local sheets = {}
	local n = 3
	local cell = size / n
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local c = cf * CFrame.new((i - (n - 1) / 2) * cell, 0, (j - (n - 1) / 2) * cell)
			local g = K.part({ Name = "Sheet", Size = Vector3.new(math.min(cell, 2048), 0.6, math.min(cell, 2048)), CFrame = c, Material = Enum.Material.ForceField, Color = color, Transparency = 0.84 }, model)
			table.insert(sheets, g)
		end
	end
	-- the lattice: three families of parallel lines = a triangular/hex grid
	local lines = {}
	local L = size * 0.5
	local spacing = size / 14
	for fam = 0, 2 do
		local ang = fam * math.pi / 3
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local nrm = Vector3.new(-math.sin(ang), 0, math.cos(ang))
		for k = -7, 7 do
			local mid = nrm * (k * spacing)
			local half = math.sqrt(math.max(L * L - (k * spacing) ^ 2, 0))
			if half > 10 then
				local p0 = cf:PointToWorldSpace(mid - dir * half)
				local p1 = cf:PointToWorldSpace(mid + dir * half)
				local b = K.ray(host, p0, p1, (k % 3 == 0) and 7 or 4, (k % 3 == 0) and 7 or 4, "10365550877", {
					Color = (k % 3 == 0) and accent or color, Brightness = (k % 3 == 0) and 3 or 1.8, Transparency = (k % 3 == 0) and 0.1 or 0.45,
					FaceCamera = false, Segments = 1, Mode = Enum.TextureMode.Wrap, Length = 80, Speed = (fam == 1) and -2 or 2,
				})
				-- lay the ribbon flat in the pane (a flat beam's width runs along its
				-- attachments' Y axis, so Y goes across the line, inside the sheet)
				local dW = (p1 - p0).Unit
				local nW = cf:VectorToWorldSpace(nrm)
				b.Attachment0.WorldCFrame = CFrame.fromMatrix(p0, dW, nW)
				b.Attachment1.WorldCFrame = CFrame.fromMatrix(p1, dW, nW)
				table.insert(lines, b)
			end
		end
	end
	-- glowing nodes where the lines cross (a few, not all: a sparkle, not a grid of dots)
	local rng = Random.new(math.floor(cf.Y))
	local nodes = K.emitter(K.part({ Name = "NodeHost", Size = Vector3.new(size * 0.9, 1, size * 0.9), CFrame = cf, Transparency = 1 }, model), {
		Texture = "131679330853412", Color = ColorSequence.new(accent), Size = K.ns(0, 0, 0.5, 16, 1, 0), Transparency = K.ns(0, 0.1, 1, 0.1),
		Lifetime = NumberRange.new(0.8, 1.4), Rate = 30, Speed = NumberRange.new(0), Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Brightness = 3, Rotation = NumberRange.new(0, 90), LightEmission = 1,
	})
	-- a rim of light round the edge
	local rim = K.softRing(host, 80, L * 0.96, L * 1.04, { Brightness = 3, Alpha = 0.8, Texture = "1084982817" })
	rim.update(cf * CFrame.Angles(math.rad(90), 0, 0), L * 0.96, L * 1.04)
	for _, q in ipairs(rim.Q) do q.Color = ColorSequence.new(accent, color) end
	local wave = K.softRing(host, 64, 10, 40, { Brightness = 3, Alpha = 0 })
	wave.setTransparency(0.99)
	model.Parent = parent
	local P = { Model = model, Sheets = sheets, Lines = lines, Nodes = nodes, Rim = rim, Wave = wave, CF = cf, Size = size, Color = color, Accent = accent, Broken = false }
	function P.setAlpha(a)
		for _, g in ipairs(sheets) do g.Transparency = 1 - 0.16 * a end
		for _, b in ipairs(lines) do b.Enabled = a > 0.02 end
		nodes.Enabled = a > 0.02
		rim.setEnabled(a > 0.02)
	end
	-- smash it where the party goes through
	function P.shatter(point, fx)
		if P.Broken then return end
		P.Broken = true
		K.sfx(K.S.Glass1, 1, 0.8)
		K.sfx(K.S.Glass2, 0.9, 0.6)
		K.sfx(K.S.Boom, 0.7, 1.2)
		task.delay(0.07, function() K.sfx(K.S.Glass3, 0.9, 0.7) end)
		-- (the classic glass/forcefield break, big)
		K.vfx("ForceField-Break-01", CFrame.new(point), fx, 22, 18, 4)
		K.vfx("Shield-Break-01", CFrame.new(point), fx, 20, 22, 4)
		local shards = {}
		for i = 1, 70 do
			local w = Instance.new("WedgePart")
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w.CanTouch = false
			w.CastShadow = false
			w.Material = (i % 3 == 0) and Enum.Material.Neon or Enum.Material.ForceField
			w.Color = (i % 3 == 0) and accent or color:Lerp(Color3.new(1, 1, 1), 0.3)
			w.Transparency = (i % 3 == 0) and 0.15 or 0.2
			local sz = rng:NextNumber(6, 45)
			w.Size = Vector3.new(0.4, sz, sz * rng:NextNumber(0.3, 0.9))
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0, 140)
			w.CFrame = CFrame.new(point + cf:VectorToWorldSpace(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
			w.Parent = fx
			local out = cf:VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a)))
			table.insert(shards, { Part = w, CF = w.CFrame, Vel = out * rng:NextNumber(150, 520) - cf.UpVector * rng:NextNumber(60, 380), Spin = rng:NextUnitVector() * rng:NextNumber(2, 10) })
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			local wu = math.clamp(t / 1.2, 0, 1)
			local r0 = 30 + P.Size * 0.55 * (1 - (1 - wu) ^ 3)
			P.Wave.update(CFrame.lookAt(point, point + cf.UpVector), r0, r0 + 80 + wu * 200, t)
			P.Wave.setTransparency(math.min(0.99, 0.05 + wu ^ 1.5))
			for _, q in ipairs(P.Wave.Q) do q.Color = ColorSequence.new(Color3.new(1, 1, 1), accent) end
			-- the sheet cracks outward from the hole and blinks away
			local gone = math.clamp((t - 0.05) / 0.9, 0, 1)
			P.setAlpha(1 - gone)
			for _, sh in ipairs(shards) do
				sh.Part.CFrame = CFrame.new(sh.CF.Position + sh.Vel * t) * sh.CF.Rotation * CFrame.fromAxisAngle(sh.Spin.Unit, sh.Spin.Magnitude * t)
				if t > 1.2 then sh.Part.Transparency = math.min(1, sh.Part.Transparency + 0.03) end
			end
			if t > 2.6 then
				conn:Disconnect()
				for _, sh in ipairs(shards) do sh.Part:Destroy() end
				P.Wave.setTransparency(0.99)
			end
		end)
	end
	return P
end

--------------------------------------------------------------------------
-- SPIRAL ENERGY STREAMS: a river of green light that corkscrews from a
-- source to a target: three braided strands round a white-hot core, a soft
-- sheath, rings of energy riding along it, and a blazing, spinning head that
-- sheds sparks. set(src, dst, head, width, t) - head 0..1 is how far it has
-- reached.
--------------------------------------------------------------------------
local SOFT_TEX = "14582794847"
local SPIRAL_TEX, SPIRAL2_TEX = "14426232568", "124165682553877"
function SK.stream(K, host, n)
	local S = { Strands = {}, Core = {}, Sheath = {}, Rings = {} }
	n = n or 14
	local cols = { SK.GREEN, SK.LIME, Color3.fromRGB(120, 255, 220) }
	for k = 1, 3 do
		local list = {}
		for i = 1, n do
			local b = K.ray(host, Vector3.zero, Vector3.yAxis, 10, 10, "10365550877", {
				Color = cols[k], Brightness = 3.5, Transparency = 0.1, Segments = 2, Mode = Enum.TextureMode.Wrap, Length = 300, Speed = 5 + k,
			})
			b.Enabled = false
			list[i] = b
		end
		S.Strands[k] = list
	end
	for i = 1, math.max(4, math.floor(n / 2)) do
		local b = K.ray(host, Vector3.zero, Vector3.yAxis, 10, 10, "10365550877", { Color = Color3.fromRGB(235, 255, 235), Brightness = 5, Transparency = 0, Segments = 2, Mode = Enum.TextureMode.Wrap, Length = 500, Speed = 9 })
		b.Enabled = false
		S.Core[i] = b
	end
	for i = 1, 4 do
		local b = K.ray(host, Vector3.zero, Vector3.yAxis, 10, 10, SOFT_TEX, { Color = SK.GREEN, Brightness = 1.4, Transparency = 0.45, Segments = 4 })
		b.Enabled = false
		S.Sheath[i] = b
	end
	for i = 1, 5 do
		local q = K.quad(host, CFrame.new(), 10, 10, i % 2 == 0 and SPIRAL_TEX or SPIRAL2_TEX, { Color = i % 2 == 0 and SK.LIME or SK.GREEN, Brightness = 3, Transparency = 0.15 })
		q.Enabled = false
		S.Rings[i] = q
	end
	S.HeadGlow = SK.glow(K, host, Vector3.zero, 10, SK.GREEN, 3, SOFT_TEX)
	S.HeadCore = SK.glow(K, host, Vector3.zero, 10, Color3.fromRGB(240, 255, 240), 5, SOFT_TEX)
	S.HeadSpin = K.quad(host, CFrame.new(), 10, 10, SPIRAL_TEX, { Color = SK.LIME, Brightness = 4, Transparency = 0.05 })
	S.HeadSpin.Enabled = false
	S.HeadAtt = Instance.new("Attachment")
	S.HeadAtt.Parent = host
	S.Sparks = K.emitter(S.HeadAtt, {
		Texture = "131679330853412", Color = ColorSequence.new(Color3.fromRGB(230, 255, 230), SK.GREEN), Size = K.ns(0, 0, 0.2, 1, 1, 0),
		Lifetime = NumberRange.new(0.5, 1.1), Speed = NumberRange.new(0, 0), SpreadAngle = Vector2.new(180, 180), Rate = 0, Brightness = 6,
		LightEmission = 1, Drag = 2, LockedToPart = false,
	})
	function S.set(src, dst, head, width, t, twist)
		local on = head > 0.001
		for _, list in ipairs(S.Strands) do for _, b in ipairs(list) do b.Enabled = on end end
		for _, b in ipairs(S.Core) do b.Enabled = on end
		for _, b in ipairs(S.Sheath) do b.Enabled = on end
		local flying = on and head < 0.999
		if not on then
			for _, q in ipairs(S.Rings) do q.Enabled = false end
			S.HeadSpin.Enabled = false
			S.HeadGlow.set(src, 1, 0)
			S.HeadCore.set(src, 1, 0)
			S.Sparks.Rate = 0
			return
		end
		local d = dst - src
		local L = d.Magnitude
		local dir = d / L
		local side = dir:Cross(math.abs(dir.Y) > 0.9 and Vector3.xAxis or Vector3.yAxis).Unit
		local up = side:Cross(dir)
		local R = L * 0.045 + width
		twist = twist or 7
		local function axis(u)
			-- (the whole river snakes a little as it goes)
			local w = math.sin(u * math.pi) * R * 0.5
			return src + d * u + (side * math.sin(u * 5 + t * 0.7) + up * math.cos(u * 4 - t * 0.5)) * w * 0.4
		end
		local function strand(u, k)
			local a = u * twist * math.pi + t * 5 + (k - 1) * math.pi * 2 / 3
			local r = R * math.sin(u * math.pi) ^ 0.6 * (1 - u * 0.5) * 0.55
			return axis(u) + (side * math.cos(a) + up * math.sin(a)) * r
		end
		local function wid(u) return width * (0.45 + 0.55 * math.sin(math.min(u, 1) * math.pi) ^ 0.5) end
		for k, list in ipairs(S.Strands) do
			local cnt = #list
			for i, b in ipairs(list) do
				local u0, u1 = (i - 1) / cnt * head, i / cnt * head
				b.Attachment0.WorldPosition = strand(u0, k)
				b.Attachment1.WorldPosition = strand(u1, k)
				b.Width0 = wid(u0) * 0.8
				b.Width1 = wid(u1) * 0.8
			end
		end
		local cc = #S.Core
		for i, b in ipairs(S.Core) do
			local u0, u1 = (i - 1) / cc * head, i / cc * head
			b.Attachment0.WorldPosition = axis(u0)
			b.Attachment1.WorldPosition = axis(u1)
			b.Width0 = wid(u0) * 0.35
			b.Width1 = wid(u1) * 0.35
		end
		local sc = #S.Sheath
		for i, b in ipairs(S.Sheath) do
			local u0, u1 = (i - 1) / sc * head, i / sc * head
			b.Attachment0.WorldPosition = axis(u0)
			b.Attachment1.WorldPosition = axis(u1)
			b.Width0 = wid(u0) * 4.5
			b.Width1 = wid(u1) * 4.5
		end
		-- rings of energy riding along it
		for i, q in ipairs(S.Rings) do
			local u = ((t * 0.35 + i / #S.Rings) % 1) * head
			q.Enabled = u > 0.02
			if q.Enabled then
				local p = axis(u)
				K.moveQuad(q, CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, t * (i % 2 == 0 and 4 or -5)))
				local s = R * 1.3 * math.sin(math.max(u, 0.05) * math.pi) ^ 0.5 + width * 2
				K.setQuadSize(q, s, s)
			end
		end
		-- the head
		local hp = axis(head)
		S.HeadSpin.Enabled = flying
		S.HeadGlow.set(hp, width * 9 * (1 + 0.15 * math.sin(t * 20)), flying and 0.85 or 0)
		S.HeadCore.set(hp, width * 3.5, flying and 1 or 0)
		if flying then
			K.moveQuad(S.HeadSpin, CFrame.lookAt(hp, hp + dir) * CFrame.Angles(0, 0, t * 9))
			K.setQuadSize(S.HeadSpin, width * 7, width * 7)
		end
		S.HeadAtt.WorldPosition = hp
		S.Sparks.Rate = flying and 60 or 0
		S.Sparks.Size = K.ns(0, 0, 0.2, width * 0.35, 1, 0)
		S.Sparks.Speed = NumberRange.new(width * 0.5, width * 2)
		S.Sparks.Acceleration = -dir * width * 3
	end
	function S.off()
		for _, list in ipairs(S.Strands) do for _, b in ipairs(list) do b.Enabled = false end end
		for _, b in ipairs(S.Core) do b.Enabled = false end
		for _, b in ipairs(S.Sheath) do b.Enabled = false end
		for _, q in ipairs(S.Rings) do q.Enabled = false end
		S.HeadSpin.Enabled = false
		S.HeadGlow.set(Vector3.zero, 1, 0)
		S.HeadCore.set(Vector3.zero, 1, 0)
		S.Sparks.Rate = 0
	end
	return S
end

--------------------------------------------------------------------------
-- A GALAXY ERUPTING: its heart turns into a green vortex that pours out
-- toward `toward`. set(pos, toward, size, amount, t)
--------------------------------------------------------------------------
function SK.burst(K, host)
	local B = {}
	-- (see-through, so the galaxy itself still shows under its green vortex)
	B.V1 = K.quad(host, CFrame.new(), 10, 10, SPIRAL_TEX, { Color = SK.GREEN, Brightness = 2.4, Transparency = 0.45 })
	B.V2 = K.quad(host, CFrame.new(), 10, 10, SPIRAL2_TEX, { Color = SK.LIME, Brightness = 2.6, Transparency = 0.5 })
	B.V3 = K.quad(host, CFrame.new(), 10, 10, SPIRAL_TEX, { Color = Color3.fromRGB(150, 255, 220), Brightness = 1.6, Transparency = 0.6 })
	-- its spiral arms, lit up green and pouring inward: the spiral power being
	-- drawn out of the galaxy's own spiral (the river to the fist starts at its heart)
	B.Arms = {}
	local ARMS, SEGS = 4, 12
	for a = 1, ARMS do
		local list = {}
		for i = 1, SEGS do
			local b = K.ray(host, Vector3.zero, Vector3.yAxis, 10, 10, "10365550877", {
				Color = (a % 2 == 0) and SK.LIME or SK.GREEN, Brightness = 4, Transparency = 0.1, Segments = 2,
				Mode = Enum.TextureMode.Wrap, Length = 2500, Speed = -3,
			})
			b.Enabled = false
			list[i] = b
		end
		B.Arms[a] = list
	end
	B.Glow = SK.glow(K, host, Vector3.zero, 10, SK.GREEN, 2.5, SOFT_TEX)
	B.Core = SK.glow(K, host, Vector3.zero, 10, Color3.fromRGB(235, 255, 235), 5, SOFT_TEX)
	B.Rays = {}
	local r = Random.new(3)
	for i = 1, 10 do
		local b = K.ray(host, Vector3.zero, Vector3.yAxis, 10, 1, "rbxasset://sky/sun.jpg", { Color = (i % 3 == 0) and Color3.new(1, 1, 1) or SK.GREEN, Brightness = 3, Transparency = K.ns(0, 0.1, 1, 1), Segments = 1 })
		b.Enabled = false
		B.Rays[i] = { B = b, D = r:NextUnitVector(), L = r:NextNumber(0.6, 1.3), P = r:NextNumber(0, 6) }
	end
	for _, q in ipairs({ B.V1, B.V2, B.V3 }) do q.Enabled = false end
	function B.set(pos, toward, size, amount, t)
		local on = amount > 0.01
		for _, q in ipairs({ B.V1, B.V2, B.V3 }) do q.Enabled = on end
		for _, r2 in ipairs(B.Rays) do r2.B.Enabled = on end
		-- (a heart of light, not a white-out over the whole galaxy)
		B.Glow.set(pos, size * 0.8 * (0.8 + 0.2 * amount), on and amount * 0.22 or 0)
		B.Core.set(pos, size * 0.06 * (1 + 0.15 * math.sin(t * 17)), on and amount * 0.6 or 0)
		for _, list in ipairs(B.Arms) do for _, b in ipairs(list) do b.Enabled = on end end
		if not on then return end
		do
			local dir0 = (toward - pos).Unit
			local e1 = dir0:Cross(math.abs(dir0.Y) > 0.9 and Vector3.xAxis or Vector3.yAxis).Unit
			local e2 = dir0:Cross(e1)
			local R = size * 0.62
			local spin = t * 0.35
			for a, list in ipairs(B.Arms) do
				local a0 = (a - 1) / #B.Arms * math.pi * 2 + spin
				local n = #list
				local function at(u) -- u = 1 at the rim, 0 at the heart
					local th = a0 + (1 - u) * math.pi * 2.3
					local r = R * (0.08 + 0.92 * u) * math.min(1, amount * 1.4)
					return pos + (e1 * math.cos(th) + e2 * math.sin(th)) * r + dir0 * (1 - u) * size * 0.05
				end
				for i, b in ipairs(list) do
					local u0, u1 = 1 - (i - 1) / n, 1 - i / n
					b.Attachment0.WorldPosition = at(u0)
					b.Attachment1.WorldPosition = at(u1)
					local w0 = size * (0.035 + 0.06 * (1 - u0)) * amount
					local w1 = size * (0.035 + 0.06 * (1 - u1)) * amount
					b.Width0, b.Width1 = w0, w1
				end
			end
		end
		local dir = (toward - pos).Unit
		local s = size * amount
		K.moveQuad(B.V1, CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, t * 3))
		K.setQuadSize(B.V1, s * 1.3, s * 1.3)
		K.moveQuad(B.V2, CFrame.lookAt(pos + dir * s * 0.08, pos + dir) * CFrame.Angles(0, 0, -t * 5))
		K.setQuadSize(B.V2, s * 0.8, s * 0.8)
		K.moveQuad(B.V3, CFrame.lookAt(pos + dir * s * 0.2, pos + dir) * CFrame.Angles(0, 0, t * 7))
		K.setQuadSize(B.V3, s * 0.45, s * 0.45)
		for _, r2 in ipairs(B.Rays) do
			local len = s * r2.L * (0.7 + 0.3 * math.sin(t * 9 + r2.P))
			r2.B.Attachment0.WorldPosition = pos
			r2.B.Attachment1.WorldPosition = pos + r2.D * len
			r2.B.Width0 = s * 0.06
		end
	end
	return B
end

--------------------------------------------------------------------------
-- THE SHOUT: a rainbow, glitching, slamming line of type
--------------------------------------------------------------------------
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 70)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 255, 120)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(60, 200, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(150, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 200)),
})
SK.RAINBOW = RAINBOW

local widthCache = {}
local function glyphW(c, font, size)
	local key = c .. size
	if widthCache[key] then return widthCache[key] end
	local p = Instance.new("GetTextBoundsParams")
	p.Text = c
	p.Font = font
	p.Size = size
	p.Width = 10000
	local ok, v = pcall(function() return TextService:GetTextBoundsAsync(p) end)
	local w = ok and v.X or size * 0.55
	if c == " " then w = size * 0.3 end
	widthCache[key] = w
	return w
end

-- returns a handle; handle.stop() shatters it away
function SK.rainbowShout(K, text, opts)
	opts = opts or {}
	local cam = workspace.CurrentCamera
	local vp = cam.ViewportSize
	local font = opts.Font or K.Fonts.Shout
	local size = math.floor(math.clamp(vp.Y * (opts.Scale or 0.13), 34, 150))
	local holder = K.frame("RainbowShout", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = opts.Position or UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(vp.X, size * 3), ZIndex = 62 }, K.Layer)
	local lines = string.split(text, "\n")
	local letters = {}
	local gap = size * 0.98
	local top = -(#lines - 1) * gap / 2
	local idx = 0
	for li, line in ipairs(lines) do
		local ws, total = {}, 0
		for c in line:gmatch(utf8.charpattern) do
			local w = glyphW(c, font, size) * 1.04
			table.insert(ws, { c, w })
			total += w
		end
		local x = -total / 2
		for _, cw in ipairs(ws) do
			local c, w = cw[1], cw[2]
			if c ~= " " then
				idx += 1
				local base = UDim2.new(0.5, x + w / 2, 0.5, top + (li - 1) * gap)
				local function mk(z)
					local l = Instance.new("TextLabel")
					l.BackgroundTransparency = 1
					l.AnchorPoint = Vector2.new(0.5, 0.5)
					l.Size = UDim2.fromOffset(w * 1.8, size * 1.5)
					l.Position = base
					l.FontFace = font
					l.TextSize = size
					l.Text = c
					l.TextColor3 = Color3.new(1, 1, 1)
					l.TextTransparency = 1
					l.ZIndex = z
					l.Parent = holder
					return l
				end
				-- a thick black drop shadow, two chromatic ghosts, then the rainbow letter
				local shadow = mk(61)
				shadow.TextColor3 = Color3.new(0, 0, 0)
				local ghostA = mk(62)
				local ghostB = mk(62)
				local main = mk(64)
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = math.max(3, size / 14)
				stroke.Color = Color3.new(0, 0, 0)
				stroke.Transparency = 1
				stroke.Parent = main
				local grad = Instance.new("UIGradient")
				grad.Color = RAINBOW
				grad.Rotation = 90
				grad.Parent = main
				-- a hot white shine across the top of each letter
				local shine = mk(65)
				local sg = Instance.new("UIGradient")
				sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(1, 1) })
				sg.Rotation = 90
				sg.Parent = shine
				local scale = Instance.new("UIScale")
				scale.Scale = 4
				scale.Parent = main
				table.insert(letters, { Main = main, Shadow = shadow, A = ghostA, B = ghostB, Shine = shine, Stroke = stroke, Grad = grad, Scale = scale, Base = base, I = idx, In = false })
			end
			x += w
		end
	end
	local per = opts.Per or 0.035
	local t0 = os.clock()
	local alive = true
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local glitch = math.random() < 0.08
		for _, L in ipairs(letters) do
			local at = (L.I - 1) * per
			local u = math.clamp((t - at) / 0.22, 0, 1)
			if u > 0 and not L.In then
				L.In = true
				L.Main.TextTransparency = 0
				L.Shadow.TextTransparency = 0.1
				L.Stroke.Transparency = 0
				L.Shine.TextTransparency = 0.2
				L.A.TextTransparency = 0.35
				L.B.TextTransparency = 0.35
			end
			if L.In then
				-- slam: overshoot and settle
				local s = u < 1 and (1 + (1 - u) ^ 2 * 3 - math.sin(u * math.pi) * 0.25) or (1 + math.sin(t * 7 + L.I * 0.6) * 0.04)
				L.Scale.Scale = s
				-- the rainbow flows through the whole line
				local hueShift = (t * 0.9 + L.I * 0.07) % 1
				L.Grad.Offset = Vector2.new(0, (hueShift - 0.5) * 1.6)
				L.Grad.Rotation = 90 + math.sin(t * 2 + L.I) * 25
				local wob = math.sin(t * 9 + L.I * 1.3) * 2 + (glitch and math.random(-7, 7) or 0)
				local bob = math.sin(t * 6 + L.I * 0.8) * 3
				L.Main.Position = L.Base + UDim2.fromOffset(wob * 0.4, bob)
				L.Main.Rotation = math.sin(t * 5 + L.I) * 4 * (u < 1 and 3 or 1)
				L.Shine.Position = L.Main.Position
				L.Shine.Rotation = L.Main.Rotation
				L.Shadow.Position = L.Base + UDim2.fromOffset(size * 0.06, size * 0.08 + bob)
				L.Shadow.Rotation = L.Main.Rotation
				local sp = 3 + math.sin(t * 11 + L.I) * 2.5 + (glitch and 8 or 0)
				L.A.Position = L.Base + UDim2.fromOffset(-sp, bob)
				L.B.Position = L.Base + UDim2.fromOffset(sp, bob + (glitch and 3 or 0))
				L.A.TextColor3 = Color3.fromHSV((hueShift + 0.33) % 1, 0.9, 1)
				L.B.TextColor3 = Color3.fromHSV((hueShift + 0.66) % 1, 0.9, 1)
				L.A.Rotation = L.Main.Rotation
				L.B.Rotation = L.Main.Rotation
			end
		end
	end)
	local H = { Holder = holder }
	function H.stop()
		if not alive then return end
		alive = false
		for _, L in ipairs(letters) do
			local dir = UDim2.fromOffset(math.random(-90, 90), -math.random(60, 200))
			for _, l in ipairs({ L.Main, L.Shadow, L.A, L.B, L.Shine }) do
				TweenService:Create(l, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, Position = L.Base + dir, Rotation = math.random(-120, 120) }):Play()
			end
			TweenService:Create(L.Stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
		task.delay(0.5, function()
			conn:Disconnect()
			holder:Destroy()
		end)
	end
	return H
end

--------------------------------------------------------------------------
-- THE ANTI-SPIRAL, DRIVEN: body pose, head aim, and two giant hands that
-- are placed by where the palm should be (the arm follows by IK, and the
-- hand is laid exactly on the wrist the arm actually reaches)
--------------------------------------------------------------------------
local PALM_OUT = 27 -- wrist -> palm centre (hand scale 1)
function SK.boss(ctx, K)
	if ctx.SB then return ctx.SB end
	local boss = ctx.Boss
	local R = SK.bossRig(ctx)
	local SB = { R = R, Boss = boss, Root = ctx.BossRoot, Home = ctx.BossHome, Hands = {} }
	for _, side in ipairs({ "Right", "Left" }) do
		local mitt = boss:FindFirstChild(side .. "Hand")
		local la = boss:FindFirstChild(side .. "LowerArm")
		local wj = R.joint(side .. "Wrist", side .. "Hand")
		local wc = R.B[wj].C0
		local H = SK.giantHand(K, la, wc, boss, { Left = side == "Left", Name = side .. "GiantHand" })
		-- (the body's own highlight already outlines everything under the model)
		if H.HL then H.HL:Destroy() H.HL = nil end
		if mitt then mitt.Transparency = 1 end
		SB.Hands[side] = { H = H, Mitt = mitt, LA = la, CF = nil, Rest = wc }
		H.pose(0.35, 0.1, 0.3)
	end
	ctx.SB = SB
	-- whole-body pose: Waist / Neck / shoulders as rotations (degrees via K.A)
	function SB.body(pose)
		for key, rot in pairs(pose) do
			local part1 = ({ Waist = "UpperTorso", Neck = "Head", Root = "LowerTorso",
				RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm", LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm" })[key]
			if part1 then R.set(key, part1, rot) end
		end
	end
	function SB.reset()
		R.clear()
	end
	-- a neck rotation that turns his head toward a world point
	function SB.lookAt(pos, amount, rootCF)
		local ut = R.cf("UpperTorso", rootCF)
		local head = R.cf("Head", rootCF)
		local d = ut:VectorToObjectSpace(pos - head.Position)
		if d.Magnitude < 1e-3 then return CFrame.new() end
		d = d.Unit
		local yaw = math.clamp(math.atan2(-d.X, -d.Z), -1.1, 1.1)
		local pitch = math.clamp(math.asin(math.clamp(d.Y, -1, 1)), -0.9, 0.7)
		amount = amount or 1
		R.set("Neck", "Head", CFrame.fromEulerAnglesYXZ(pitch * amount, yaw * amount, 0))
	end
	-- put a hand's palm centre near `palmPos`, fingers along F, palm facing N.
	-- returns the palm's real CFrame (hand space: +Y fingers, +Z out of the palm)
	function SB.hand(side, palmPos, F, N, pole, rootCF)
		local h = SB.Hands[side]
		F = F.Unit
		N = N - F * N:Dot(F)
		N = N.Magnitude > 1e-3 and N.Unit or F:Cross(Vector3.xAxis).Unit
		local X = F:Cross(N)
		local wristTarget = palmPos - F * PALM_OUT
		local laCF, wW = R.reach(side, wristTarget, pole or Vector3.new(0, -1, 0), rootCF)
		local cf = CFrame.fromMatrix(wW + F * PALM_OUT, X, F, N)
		h.H.setWrist(laCF:Inverse() * cf)
		h.CF = cf
		return cf
	end
	-- the palm's surface (where people stand), same axes as the palm
	function SB.surface(side)
		local h = SB.Hands[side]
		return h.CF and (h.CF * CFrame.new(0, 0, h.H.Size.Z * 0.5)) or nil
	end
	return SB
end

-- a body standing on a surface frame (surface: +Z = up out of it), at local (x, y)
-- on it, facing toward a world point (projected into the surface)
function SK.standOn(surf, x, y, lookAt, height)
	local up = surf.ZVector
	local pos = surf:PointToWorldSpace(Vector3.new(x, y, 0)) + up * (height or 3)
	local fwd = lookAt - pos
	fwd = fwd - up * fwd:Dot(up)
	if fwd.Magnitude < 1e-3 then fwd = surf.YVector end
	fwd = fwd.Unit
	return CFrame.fromMatrix(pos, fwd:Cross(up), up, -fwd)
end
-- lying on the back on a surface, head toward `headDir` (a world direction in the surface)
function SK.lieOn(surf, x, y, headDir, height)
	local up = surf.ZVector
	local pos = surf:PointToWorldSpace(Vector3.new(x, y, 0)) + up * (height or 1.1)
	local hd = headDir - up * headDir:Dot(up)
	hd = hd.Magnitude > 1e-3 and hd.Unit or surf.YVector
	-- front (-Z) faces up
	local Z = -up
	return CFrame.fromMatrix(pos, hd:Cross(Z), hd, Z)
end

-- where each of the party sits on the palm (x across, y along the fingers)
local PALM_SLOTS = {
	Vector2.new(0, 1), Vector2.new(9, 7), Vector2.new(-9, 6), Vector2.new(8, -7),
	Vector2.new(-8, -8), Vector2.new(1, 13), Vector2.new(0, -13), Vector2.new(15, 0),
}
function SK.palmSlot(ctx, slot)
	if (ctx.n or 1) <= 1 then return Vector2.new(0, 0) end
	return PALM_SLOTS[((slot - 1) % #PALM_SLOTS) + 1]
end

--------------------------------------------------------------------------
-- SPIRAL POWER ON A BODY: green veins over the skin, a glow, eyes, aura
--------------------------------------------------------------------------
function SK.powerUp(K, rig)
	if rig.SP then return rig.SP end
	local SP = { Veins = {} }
	rig.SP = SP
	local function vein(part, a, b, w)
		if not part then return end
		local a0 = Instance.new("Attachment")
		a0.Position = a
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Position = b
		a1.Parent = part
		local bm = Instance.new("Beam")
		bm.Attachment0 = a0
		bm.Attachment1 = a1
		bm.Width0 = (w or 0.14) * 1.7
		bm.Width1 = (w or 0.14) * 0.8
		bm.Color = ColorSequence.new(SK.GREEN, SK.LIME)
		bm.LightEmission = 1
		bm.LightInfluence = 0
		bm.Brightness = 4
		bm.FaceCamera = true
		bm.Segments = 10
		bm.CurveSize0 = math.random(-10, 10) / 10
		bm.CurveSize1 = math.random(-10, 10) / 10
		bm.Transparency = NumberSequence.new(1)
		bm.Parent = part
		table.insert(SP.Veins, { Beam = bm, Phase = math.random() * 2 })
	end
	local T = rig.Torso
	for i = 1, 4 do
		local x = (i - 2.5) * 0.4
		vein(T, Vector3.new(x * 0.5, 0.2, -0.52), Vector3.new(x * 1.8, 0.95, -0.52), 0.12)
		vein(T, Vector3.new(x * 0.5, -0.1, -0.52), Vector3.new(x * 1.4, -0.95, -0.52), 0.12)
		vein(T, Vector3.new(x * 0.5, 0.1, 0.52), Vector3.new(x * 1.6, 0.9, 0.52), 0.1)
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
	-- glowing eyes (two small neon slits on the face)
	SP.Eyes = {}
	if head then
		for _, sx in ipairs({ -0.22, 0.22 }) do
			local e = Instance.new("Part")
			e.Name = "SpiralEye"
			e.Size = Vector3.new(0.26, 0.09, 0.05)
			e.Material = Enum.Material.Neon
			e.Color = Color3.fromRGB(210, 255, 200)
			e.CanCollide = false
			e.CanQuery = false
			e.CanTouch = false
			e.Massless = true
			e.CastShadow = false
			e.Transparency = 1
			local w = Instance.new("Weld")
			w.Part0 = head
			w.Part1 = e
			w.C0 = CFrame.new(sx, 0.12, -0.6)
			w.Parent = e
			e.Parent = rig.Model
			table.insert(SP.Eyes, e)
		end
	end
	local h = Instance.new("Highlight")
	h.FillColor = SK.GREEN
	h.FillTransparency = 1
	h.OutlineColor = SK.LIME
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = rig.Model
	SP.Glow = h
	SP.Aura = K.emitter(rig.Torso, {
		Texture = "11381556016", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = ColorSequence.new(SK.GREEN, SK.LIME), Size = K.ns(0, 3.4, 1, 0.5), Lifetime = NumberRange.new(0.45, 0.8),
		Speed = NumberRange.new(4, 10), SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Top, Rate = 0, Brightness = 4,
		Rotation = NumberRange.new(0, 360), Shape = Enum.ParticleEmitterShape.Box, LockedToPart = false,
	})
	SP.Sparks = K.emitter(rig.Torso, {
		Texture = "131679330853412", Color = ColorSequence.new(SK.LIME, Color3.new(1, 1, 1)), Size = K.ns(0, 0.8, 1, 0),
		Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(6, 16), SpreadAngle = Vector2.new(180, 180), Rate = 0, Brightness = 5,
		Rotation = NumberRange.new(0, 360),
	})
	local pl = Instance.new("PointLight")
	pl.Color = SK.GREEN
	pl.Range = 16
	pl.Brightness = 0
	pl.Parent = rig.Torso
	SP.Light = pl
	return SP
end

-- how strongly the power shows (0..1); t drives the pulse
function SK.powerLevel(rig, t, amount)
	local SP = rig.SP
	if not SP then return end
	for _, v in ipairs(SP.Veins) do
		local head = ((t * 1.6 + v.Phase) % 1)
		local a = 1 - amount
		v.Beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, math.min(1, a + 0.15)),
			NumberSequenceKeypoint.new(math.clamp(head - 0.1, 0.01, 0.97), math.min(1, a + 0.3)),
			NumberSequenceKeypoint.new(math.clamp(head, 0.02, 0.98), a * 0.2),
			NumberSequenceKeypoint.new(1, math.min(1, a + 0.25)),
		})
	end
	SP.Glow.FillTransparency = 1 - amount * (0.06 + 0.03 * math.sin(t * 8))
	SP.Glow.OutlineTransparency = 1 - amount * 0.85
	for _, e in ipairs(SP.Eyes) do e.Transparency = 1 - math.clamp(amount * 1.4 - 0.2, 0, 1) end
	SP.Light.Brightness = amount * 3
end

-- the Spiral Bat: the Verity bat becomes a glowing green drill
function SK.spiralBat(K, rig)
	local bat = rig.Bat
	if not bat or rig.SpiralBat then return end
	rig.SpiralBat = true
	bat.Material = Enum.Material.Neon
	bat.Color = Color3.fromRGB(40, 200, 95)
	local src = K.Assets:FindFirstChild("DrillCone")
	if src then
		local cone = src:Clone()
		cone.Anchored = false
		cone.CanCollide = false
		cone.CanQuery = false
		cone.CanTouch = false
		cone.Massless = true
		cone.Material = Enum.Material.Neon
		cone.Color = SK.LIME
		cone.Size = cone.Size * 1.1
		for _, d in ipairs(cone:GetChildren()) do if not d:IsA("SpecialMesh") then d:Destroy() end end
		local w = Instance.new("Weld")
		w.Part0 = bat
		w.Part1 = cone
		w.C0 = CFrame.new(-bat.Size.X / 2 - cone.Size.Y * 0.45, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		w.Parent = cone
		cone.Parent = rig.Model
		rig.Cone = cone
		rig.ConeWeld = w
		rig.ConeC0 = w.C0
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(bat.Size.X / 2, 0, 0)
	a0.Parent = bat
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-bat.Size.X / 2 - 1.5, 0, 0)
	a1.Parent = bat
	for i = 1, 2 do
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = 0.55
		b.Width1 = 0.2
		b.Color = ColorSequence.new(i == 1 and SK.GREEN or SK.LIME)
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
		Texture = "11381556016", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = ColorSequence.new(SK.GREEN, SK.LIME), Size = K.ns(0, 1.5, 1, 0), Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(1, 4), SpreadAngle = Vector2.new(180, 180), Rate = 30, Brightness = 2.5, Rotation = NumberRange.new(0, 360),
	})
	local pl = Instance.new("PointLight")
	pl.Color = SK.GREEN
	pl.Range = 14
	pl.Brightness = 2
	pl.Parent = bat
end

-- all the party's models (for impact frames)
function SK.models(ctx)
	local m = {}
	for _, rig in pairs(ctx.rigs) do table.insert(m, rig.Model) end
	return m
end

-- a soft green glow ball: a camera-facing sprite (glow texture) at p
function SK.glow(K, host, p, size, color, bright, tex)
	local b = K.ray(host, p, p + Vector3.yAxis, size, size, tex or "rbxasset://sky/sun.jpg", { Color = color, Brightness = bright or 2, Transparency = 0, Segments = 1 })
	local G = { Beam = b }
	function G.set(pos, s, alpha)
		b.Attachment0.WorldPosition = pos - Vector3.yAxis * s * 0.5
		b.Attachment1.WorldPosition = pos + Vector3.yAxis * s * 0.5
		b.Width0 = s
		b.Width1 = s
		b.Enabled = alpha > 0.01
		b.Transparency = NumberSequence.new(math.clamp(1 - alpha, 0, 1))
	end
	return G
end


-- a hand hanging loose at the end of an arm posed by FK (no IK), fingers down
function SK.hang(SB, side, curl, spread)
	local h = SB.Hands[side]
	local turn = side == "Right" and -math.pi / 2 or math.pi / 2
	h.H.setWrist(CFrame.new(h.Rest.Position) * CFrame.Angles(math.pi, 0, 0) * CFrame.Angles(0, turn, 0) * CFrame.new(0, 27, 0))
	h.CF = nil
	if curl then h.H.pose(curl, spread or 0.1, curl) end
end

-- the fall shared by Ejected, Layers and Descent: a smooth path through
-- timed points (G = seconds since the Ejected chapter began)
SK.CATCH = Vector3.new(131, 252, 19981)    -- where his right palm settles with the party on it
SK.MOUTH = Vector3.new(-655, 15010, 20530) -- the portal's exit, high in 4-D space
SK.DIRE = Vector3.new(0.78, 0.3, -0.55).Unit
function SK.fall(ctx)
	if ctx.FallPath then return ctx.FallPath, ctx.FallG end
	local B = ctx.TL.ByName
	local e0 = B.Ejected.Start
	-- (the Float chapter between Layers and Descent is a pause in the fall, not
	-- part of it: the path's clock skips over it)
	local fl = B.Float and B.Float.Dur or 0
	local G = { Layers = B.Layers.Start - e0, Descent = B.Descent.Start - e0 - fl, Catch = B.Catch.Start - e0 - fl }
	local M, D, U = SK.MOUTH, SK.DIRE, Vector3.yAxis
	ctx.FallPath = SK.path({
		{ 0, M },
		{ 0.5, M + D * 230 + U * 30 },
		{ 1.6, M + D * 520 },
		{ 3.2, M + D * 690 - U * 200 },
		{ G.Layers, M + D * 760 - U * 760 },
		{ G.Descent, Vector3.new(SK.CATCH.X - 30, 7200, SK.CATCH.Z + 20) },
		{ G.Catch, Vector3.new(SK.CATCH.X, 1150, SK.CATCH.Z) },
	})
	ctx.FallG = G
	return ctx.FallPath, G
end

-- the spin of a body flung out of the portal: violent at first, settling
function SK.spinAngle(G)
	return 13 / 0.45 * (1 - math.exp(-0.45 * G)) + 1.1 * G
end

--------------------------------------------------------------------------
-- THE FIST: he holds them in his closed right hand, legs inside his
-- fingers and bodies sticking out of the top. Hand held fingers along his
-- look, palm facing his left, so the index/thumb side is up.
--------------------------------------------------------------------------
SK.HOLD = SK.CATCH + Vector3.new(0, 10, 0) -- palm centre while he holds them
SK.GRIP = 0.62                             -- the curl that closes round them
local FIST_SLOTS = {                       -- hand space (x up out of the fist)
	Vector3.new(25, 31, 17), Vector3.new(25, 31, 11), Vector3.new(25, 31, 23), Vector3.new(25, 31, 29),
	Vector3.new(25, 37, 14), Vector3.new(25, 37, 26), Vector3.new(25, 25, 21), Vector3.new(25, 37, 20),
}
function SK.fistSlot(ctx, slot)
	return FIST_SLOTS[((slot - 1) % #FIST_SLOTS) + 1]
end
-- the fist's rotation (hand space axes) for his home frame
function SK.fistRot(home)
	local F, N = home.LookVector, -home.RightVector
	return CFrame.fromMatrix(Vector3.zero, F:Cross(N), F, N)
end
SK.FIST_POLE = function(home) return Vector3.new(0, -1, 0) - home.RightVector * 0.6 end
-- the palm centre that puts slot 1 of the fist on `point`
function SK.gripPalm(home, point)
	return point - SK.fistRot(home):VectorToWorldSpace(FIST_SLOTS[1])
end
-- where he holds the fist (lift raises it toward his face)
function SK.holdPalm(ctx, t, lift)
	local look = ctx.BossHome.LookVector
	return SK.HOLD + (Vector3.yAxis * 30 - look * 20) * (lift or 0) + Vector3.new(0, math.sin(t * 1.3 + 1) * 2, 0)
end
-- put the right hand in the fist orientation at `palm`; returns the hand CF
function SK.holdFist(ctx, SB, palm, rootCF)
	local home = ctx.BossHome
	local R = SK.fistRot(home)
	return SB.hand("Right", palm, R.YVector, R.ZVector, SK.FIST_POLE(home), rootCF)
end
-- a body held in the fist at hand-space `off`, upright along the fist, facing
-- a world point; sink pushes it down into the fingers
function SK.inFist(handCF, off, lookAt, sink)
	local up = handCF.XVector
	local pos = handCF:PointToWorldSpace(off) - up * (sink or 0)
	local fwd = lookAt - pos
	fwd = fwd - up * fwd:Dot(up)
	if fwd.Magnitude < 1e-3 then fwd = -handCF.YVector end
	fwd = fwd.Unit
	return CFrame.fromMatrix(pos, fwd:Cross(up), up, -fwd)
end
-- upper-body poses for someone stuck in the fist: strain 0 = stunned,
-- 1 = shoving at the fingers; dying 0..1 goes limp, head thrown back
function SK.gripPose(K, t, slot, strain, dying)
	strain = strain or 0
	local w = t * 7 + slot * 1.9
	local pose = {
		Root = K.A(-8 + math.sin(w * 0.5) * 5 * strain, math.sin(w * 0.3) * 10 * strain, 0),
		Neck = K.A(12 + math.sin(w * 0.7) * 6 * strain, math.sin(w * 0.4) * 15 * strain, 0),
		RS = K.A(35 + math.sin(w) * 22 * strain, 0, 42 + math.sin(w * 1.3) * 12 * strain),
		LS = K.A(35 + math.sin(w + 2) * 22 * strain, 0, -42 - math.sin(w * 1.1 + 1) * 12 * strain),
		RH = K.A(20, 0, 10), LH = K.A(20, 0, -10),
	}
	if dying and dying > 0 then
		local sway = math.sin(t * 1.7 + slot) * 3
		local limp = { Root = K.A(18, 0, 7), Neck = K.A(36, 14 + sway, 9), RS = K.A(20, 0, 58), LS = K.A(16, 0, -52), RH = K.A(0, 0, 8), LH = K.A(0, 0, -8) }
		pose = K.mixPose(pose, limp, dying)
	end
	return pose
end
-- his open right hand drawn far back and up behind him, ready to snatch
-- (draw 0..1 pulls it further back); returns the palm CF (hand space)
function SK.windCF(home, rootPos, draw)
	draw = draw or 0
	local look, right, up = home.LookVector, home.RightVector, Vector3.yAxis
	local p = rootPos + up * (250 + draw * 16) + right * (165 + draw * 8) - look * (70 + draw * 34)
	local F = (up - look * 0.3 * draw).Unit
	local N = (look + up * 0.1).Unit
	N = (N - F * N:Dot(F)).Unit
	return CFrame.fromMatrix(p, F:Cross(N), F, N)
end
SK.WIND_POLE = function(home) return Vector3.new(0, -1, 0) + home.RightVector * 0.8 - home.LookVector * 0.3 end
-- the wide side-on shot of the wind-up and the snatch (e 0..1 = a slow push)
function SK.catchCam(home, C, e)
	local mid = C:Lerp(home.Position + Vector3.yAxis * 330, 0.4)
	local p = mid + home.RightVector * (600 - 90 * e) + home.LookVector * 70 + Vector3.yAxis * 20
	return CFrame.lookAt(p, mid + Vector3.yAxis * 50), 46
end
-- where slot 1 meets the fist when he snatches them
SK.SNATCH = Vector3.new(SK.CATCH.X, 420, SK.CATCH.Z + 17)

--------------------------------------------------------------------------
-- THE AURA SHOUT: the line slams in word by word, every word burning with
-- its own aura of spiral power (flickering, rising, glowing copies of it).
-- opts: Scale, Position, Per (seconds between words), Font, Aura, Aura2,
-- Speaker, SpeakerColor. Returns { stop = fn }.
--------------------------------------------------------------------------
function SK.auraShout(K, text, opts)
	opts = opts or {}
	local TweenService = game:GetService("TweenService")
	local RunService = game:GetService("RunService")
	local TextService = game:GetService("TextService")
	local vp = workspace.CurrentCamera.ViewportSize
	local size = math.floor(math.clamp(vp.Y * (opts.Scale or 0.1), 30, 130))
	local font = opts.Font or K.Fonts.Shout
	local aura = opts.Aura or SK.GREEN
	local aura2 = opts.Aura2 or SK.LIME
	local per = opts.Per or 0.16
	local holder = Instance.new("Frame")
	holder.Name = "AuraShout"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = opts.Position or UDim2.fromScale(0.5, 0.8)
	holder.Size = UDim2.fromOffset(vp.X, size * 3)
	holder.ZIndex = 70
	holder.Parent = K.Layer
	local function width(s)
		local p = Instance.new("GetTextBoundsParams")
		p.Text = s
		p.Font = font
		p.Size = size
		p.Width = 100000
		local ok, v = pcall(function() return TextService:GetTextBoundsAsync(p) end)
		return ok and v.X or #s * size * 0.55
	end
	-- lay the words out
	local words = {}
	local lines = string.split(text, "\n")
	local gap = size * 1.15
	local top = -(#lines - 1) * gap / 2
	local spaceW = size * 0.3
	for li, line in ipairs(lines) do
		local row, total = {}, 0
		for _, w in ipairs(string.split(line, " ")) do
			if w ~= "" then
				local x = width(w)
				table.insert(row, { w, x })
				total += x
			end
		end
		total += spaceW * math.max(#row - 1, 0)
		local x = -total / 2
		for _, e in ipairs(row) do
			table.insert(words, { Text = e[1], W = e[2], Base = UDim2.new(0.5, x + e[2] / 2, 0.5, top + (li - 1) * gap) })
			x += e[2] + spaceW
		end
	end
	local function label(txt, z, parent)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.fromScale(1, 1)
		l.FontFace = font
		l.TextSize = size
		l.Text = txt
		l.TextTransparency = 1
		l.ZIndex = z
		l.Parent = parent
		return l
	end
	for i, W in ipairs(words) do
		local g = Instance.new("Frame")
		g.BackgroundTransparency = 1
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = W.Base
		g.Size = UDim2.fromOffset(W.W + size * 1.2, size * 2)
		g.ZIndex = 70
		g.Parent = holder
		local sc = Instance.new("UIScale")
		sc.Scale = 2.6
		sc.Parent = g
		-- the aura: glowing copies, flickering and rising off the word like flame
		local auras = {}
		for k = 1, 3 do
			local a = label(W.Text, 70 + k, g)
			a.TextColor3 = (k == 2) and aura2 or aura
			local st = Instance.new("UIStroke")
			st.Thickness = size * (0.07 + k * 0.06)
			st.Color = (k == 2) and aura2 or aura
			st.LineJoinMode = Enum.LineJoinMode.Round
			st.Transparency = 1
			st.Parent = a
			local gr = Instance.new("UIGradient")
			gr.Rotation = -90
			gr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.25), NumberSequenceKeypoint.new(1, 1) })
			gr.Parent = st
			auras[k] = { L = a, S = st, G = gr, T = 0.2 + k * 0.17, Th = st.Thickness }
		end
		-- the word itself: white-hot, fading to spiral green at its foot
		local main = label(W.Text, 76, g)
		main.TextColor3 = Color3.new(1, 1, 1)
		local ms = Instance.new("UIStroke")
		ms.Thickness = math.max(2, size / 14)
		ms.Color = Color3.fromRGB(8, 30, 14)
		ms.Transparency = 1
		ms.Parent = main
		local mg = Instance.new("UIGradient")
		mg.Rotation = 90
		mg.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(225, 255, 215)),
			ColorSequenceKeypoint.new(1, aura2),
		})
		mg.Parent = main
		W.G, W.Scale, W.Auras, W.Main, W.MainStroke, W.On = g, sc, auras, main, ms, false
	end
	-- who's shouting
	local untag
	if opts.Speaker then
		untag = K.nameTag(holder, opts.Speaker, top - size * 0.72, math.floor(size * 0.3), opts.SpeakerColor or aura2, 80)
	end
	-- word by word
	local alive = true
	local t0 = os.clock()
	for i, W in ipairs(words) do
		task.delay((i - 1) * per, function()
			if not alive then return end
			W.On = os.clock()
			W.G.Rotation = math.random(-12, 12)
			TweenService:Create(W.Scale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			TweenService:Create(W.G, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Rotation = 0 }):Play()
			TweenService:Create(W.Main, TweenInfo.new(0.1), { TextTransparency = 0 }):Play()
			TweenService:Create(W.MainStroke, TweenInfo.new(0.1), { Transparency = 0 }):Play()
			for _, A in ipairs(W.Auras) do
				TweenService:Create(A.L, TweenInfo.new(0.15), { TextTransparency = 0.55 }):Play()
			end
			K.shake(0.9, 0.16, 20, true)
			if opts.Sound ~= false then K.sfx(K.S.TonalHit, 0.35, 0.9 + i * 0.05) end
		end)
	end
	-- the aura burns while it holds
	local conn = RunService.RenderStepped:Connect(function()
		if not alive then return end
		local t = os.clock() - t0
		for i, W in ipairs(words) do
			if W.On then
				local since = os.clock() - W.On
				local flare = math.exp(-since / 0.25) -- (each word flares as it lands)
				for k, A in ipairs(W.Auras) do
					local flick = 0.5 + 0.5 * math.noise(t * 7 + i * 3.1, k * 1.7)
					A.S.Thickness = A.Th * (0.8 + 0.45 * flick + flare * 1.4)
					A.S.Transparency = math.clamp(A.T + (1 - flick) * 0.25 - flare * 0.3, 0, 0.95)
					-- the flames licking upward
					A.G.Offset = Vector2.new(0, -((t * (0.9 + k * 0.25) + i * 0.37) % 1) * 0.35)
					A.L.Position = UDim2.new(0.5, math.noise(t * 5, i, k) * size * 0.04, 0.5, -size * 0.03 * k * (0.6 + 0.4 * flick))
				end
				W.Main.Position = UDim2.new(0.5, math.noise(t * 11, i) * size * 0.015, 0.5, math.noise(i, t * 11) * size * 0.015)
			end
		end
	end)
	local S = {}
	function S.stop()
		if not alive then return end
		alive = false
		if untag then untag() end
		for _, W in ipairs(words) do
			TweenService:Create(W.Scale, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1.35 }):Play()
			TweenService:Create(W.Main, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			TweenService:Create(W.MainStroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			for _, A in ipairs(W.Auras) do
				TweenService:Create(A.L, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				TweenService:Create(A.S, TweenInfo.new(0.3), { Transparency = 1, Thickness = A.Th * 3 }):Play()
			end
		end
		task.delay(0.4, function()
			conn:Disconnect()
			holder:Destroy()
		end)
	end
	return S
end
return SK
