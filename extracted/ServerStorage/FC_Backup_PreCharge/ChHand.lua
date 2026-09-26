--==================================================
-- SPIRAL GALAXY II: ABSORB, CRUSH, FUNNEL
-- With the party held in his right hand, the Anti-Spiral tears the
-- True Lapeace out of its shrine (the pedestal crumbles away, every
-- other kind of lapis wheeling round it) and takes it into himself.
-- Then he closes his fist... and as all hope goes, every galaxy in
-- the realm pours its spiral energy into the one he's holding.
--==================================================
local SK = require(script.Parent:WaitForChild("SpiralKit"))
local ChArena = require(script.Parent:WaitForChild("ChArena"))
local Ch = {}

local UP = Vector3.yAxis
local WHITE = Color3.new(1, 1, 1)

------------------------------------------------------------------------
-- how he holds them (continues exactly from the end of the Catch)
------------------------------------------------------------------------
local function holdRoot(ctx, t)
	return ctx.BossHome * CFrame.new(0, 60 + math.sin(t * 1.3) * 2, 0)
end

-- the party stuck in his fist, legs inside his fingers.
-- fn(slot) -> lookAt, pose, sink
local function placeInFist(ctx, hcf, t, fn)
	local K = ctx.kit
	local myPos
	for slot, rig in pairs(ctx.rigs) do
		local off = SK.fistSlot(ctx, slot)
		local lookAt, pose, sink = fn(slot)
		local cf = SK.inFist(hcf, off, lookAt, sink)
		rig:setCF(cf)
		rig:setPose(pose or SK.gripPose(K, t, slot, 0.5, 0))
		rig:apply()
		if rig == ctx.myRig then myPos = cf.Position end
	end
	return myPos or hcf:PointToWorldSpace(SK.fistSlot(ctx, 1))
end

local function galaxySources(ctx)
	local realm = SK.realm(ctx)
	local list = {}
	local function add(stage, name)
		local st = realm and realm:FindFirstChild(stage)
		local p = st and st:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			local disk = p:FindFirstChild("Disk")
			table.insert(list, { Name = name, Pos = p.Position, Part = p, R = disk and disk.Width0 / 2 or 2600 })
		end
	end
	-- (in the order the camera visits them)
	add("Galaxies", "Hero2")
	add("Galaxies", "Hero5")
	add("SoulNebula", "SoulHost")
	add("Galaxies", "Hero1")
	add("Galaxies", "Hero7")
	add("Pillars", "PillarsHost")
	add("Galaxies", "Hero4")
	add("Galaxies", "Hero6")
	add("Galaxies", "Hero3")
	add("GreatSpiral", "SpiralHost")
	if #list == 0 then
		local AC = ctx.TL.ArenaCenter
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			table.insert(list, { Name = "G" .. i, Pos = AC + Vector3.new(math.cos(a) * 20000, (i % 3 - 1) * 6000, math.sin(a) * 20000), R = 3000 })
		end
	end
	return list
end

------------------------------------------------------------------------
-- BUILD
------------------------------------------------------------------------
function Ch.build(ctx)
	local K = ctx.kit
	local set = Instance.new("Folder")
	set.Name = "HandSet"
	ctx.sets.Hand = set
	local H = {}
	ctx.HandFX = H
	local fx = Instance.new("Folder")
	fx.Name = "FX"
	fx.Parent = set
	H.FX = fx
	local host = K.part({ Name = "HandHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(SK.CATCH) }, set)
	H.Host = host

	--------------------------------------------------------------------
	-- every other kind of lapis (they wheel round the True Lapeace)
	--------------------------------------------------------------------
	H.Lapis = {}
	local src = K.Assets:FindFirstChild("LapisVisuals")
	for _, m in ipairs(src and src:GetChildren() or {}) do
		if m:IsA("Model") and m.Name ~= "lapeace_lapis" then
			local c = m:Clone()
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CastShadow = false
				elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Highlight") then
					d:Destroy()
				elseif d:IsA("ParticleEmitter") then
					d.Rate = math.min(d.Rate, 25)
				elseif d:IsA("Light") then
					d.Enabled = false
				end
			end
			-- same size for all of them, whatever their model came as
			local gem
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("UnionOperation") and (not gem or d.Size.Magnitude > gem.Size.Magnitude) then gem = d end
			end
			-- (by the whole model: some carry a planet or a demon round the gem)
			local ext = c:GetExtentsSize()
			local ref = math.max(ext.X, ext.Y, ext.Z, 0.1)
			pcall(function() c:ScaleTo(c:GetScale() * 20 / ref) end)
			local centre = gem and gem.Position or c:GetPivot().Position
			c:PivotTo(CFrame.new(SK.CATCH))
			local off = c:GetPivot():ToObjectSpace(CFrame.new(gem and gem.Position or centre))
			local parts, emit, decals = {}, {}, {}
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("BasePart") then table.insert(parts, d) d.LocalTransparencyModifier = 1
				elseif d:IsA("Decal") or d:IsA("Texture") then table.insert(decals, { d, d.Transparency }) d.Transparency = 1
				elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then table.insert(emit, { d, d.Enabled }) d.Enabled = false end
			end
			c.Parent = set
			table.insert(H.Lapis, { Model = c, Off = off, Parts = parts, Decals = decals, Emit = emit, Shown = false })
		end
	end
	function H.lapisAlpha(L, a)
		for _, p in ipairs(L.Parts) do p.LocalTransparencyModifier = 1 - a end
		for _, d in ipairs(L.Decals) do d[1].Transparency = 1 - (1 - d[2]) * a end
		local on = a > 0.5
		if on ~= L.Shown then
			L.Shown = on
			for _, e in ipairs(L.Emit) do e[1].Enabled = on and e[2] end
		end
	end
	-- (a lapis's centre goes to cf)
	function H.lapisAt(L, cf)
		L.Model:PivotTo(cf * L.Off:Inverse())
	end

	--------------------------------------------------------------------
	-- the pull, the absorption
	--------------------------------------------------------------------
	H.Tether = K.ray(host, Vector3.zero, UP, 5, 2, nil, { Color = Color3.fromRGB(140, 170, 255), Brightness = 4, Transparency = K.ns(0, 0.1, 1, 0.3), Segments = 12 })
	H.Tether2 = K.ray(host, Vector3.zero, UP, 26, 8, "10180479311", { Color = Color3.fromRGB(70, 80, 230), Brightness = 2, Transparency = K.ns(0, 0.45, 1, 0.7), Speed = 3, Mode = Enum.TextureMode.Wrap, Length = 60, Segments = 12 })
	H.Tether.Enabled = false
	H.Tether2.Enabled = false
	H.Wave = K.softRing(host, 64, 10, 40, { Brightness = 3, Alpha = 0 })
	for _, q in ipairs(H.Wave.Q) do q.Color = ColorSequence.new(Color3.fromRGB(200, 210, 255)) end
	H.Wave.setTransparency(0.99)
	H.Core = SK.glow(K, host, SK.CATCH, 80, Color3.fromRGB(160, 185, 255), 3)
	H.Core.set(SK.CATCH, 10, 0)
	H.Dust = K.emitter(host, {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(210, 190, 150), Color3.fromRGB(120, 100, 150)), Size = K.ns(0, 6, 1, 22),
		Transparency = K.ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(1.5, 2.8), Speed = NumberRange.new(6, 22), SpreadAngle = Vector2.new(180, 180),
		Rate = 0, LightEmission = 0, LightInfluence = 0.3, Rotation = NumberRange.new(0, 360), Acceleration = Vector3.new(0, 10, 0),
	})
	H.Motes = K.emitter(host, {
		Texture = "131679330853412", Color = ColorSequence.new(Color3.fromRGB(255, 225, 150)), Size = K.ns(0, 0, 0.3, 1.8, 1, 0),
		Lifetime = NumberRange.new(1, 2.2), Speed = NumberRange.new(8, 30), SpreadAngle = Vector2.new(180, 180), Rate = 0, Brightness = 4,
		Acceleration = Vector3.new(0, 20, 0),
	})

	--------------------------------------------------------------------
	-- inside the fist: the first green spark of hope
	--------------------------------------------------------------------
	H.Hope = SK.glow(K, host, SK.CATCH, 10, SK.GREEN, 4)
	H.Hope.set(SK.CATCH, 1, 0)
	H.FistGlow = SK.glow(K, host, SK.CATCH, 200, SK.GREEN, 3)
	H.FistGlow.set(SK.CATCH, 1, 0)
	H.FistLight = Instance.new("PointLight")
	H.FistLight.Color = SK.GREEN
	H.FistLight.Range = 60
	H.FistLight.Brightness = 0
	H.FistLight.Parent = host

	--------------------------------------------------------------------
	-- the galaxies' spiral energy
	--------------------------------------------------------------------
	local sh = K.part({ Name = "StreamHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(SK.CATCH) }, set)
	H.Streams = {}
	for i = 1, 10 do
		H.Streams[i] = SK.stream(K, sh, 12)
		H.Streams[i].off()
	end
	H.Bursts = {}
	for i = 1, 10 do
		H.Bursts[i] = SK.burst(K, sh)
		H.Bursts[i].set(SK.CATCH, SK.CATCH + UP, 1, 0, 0)
	end
	H.Flares = {}
	for i = 1, 10 do
		local f = { G = SK.glow(K, sh, SK.CATCH, 100, SK.GREEN, 2.5), C = SK.glow(K, sh, SK.CATCH, 100, Color3.fromRGB(220, 255, 220), 4) }
		f.G.set(SK.CATCH, 1, 0)
		f.C.set(SK.CATCH, 1, 0)
		H.Flares[i] = f
	end
end

------------------------------------------------------------------------
-- the shrine
------------------------------------------------------------------------
local function shrineParts(ctx)
	local bf = SK.arena(ctx)
	local shrine = bf and bf:FindFirstChild("LapisShrine")
	if not shrine then return nil end
	local S = { Shrine = shrine, Gem = shrine:FindFirstChild("TrueLapeace"), Steps = {}, Fx = {} }
	for _, c in ipairs(shrine:GetChildren()) do
		if c:IsA("BasePart") and c.Name ~= "AuraHost" then table.insert(S.Steps, c) end
	end
	local aura = shrine:FindFirstChild("AuraHost")
	if aura then
		for _, d in ipairs(aura:GetDescendants()) do
			if d:IsA("Beam") or d:IsA("ParticleEmitter") or d:IsA("Light") then table.insert(S.Fx, d) end
		end
	end
	return S
end

local function setGemVisible(gem, on)
	if not gem then return end
	for _, d in ipairs(gem:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = on and 0 or 1
		elseif d:IsA("ParticleEmitter") or d:IsA("Highlight") or d:IsA("Beam") or d:IsA("Light") then
			d.Enabled = on
		end
	end
end

-- the fight: the stone stays in him, and the pedestal stays gone
local function onFight(ctx)
	pcall(ChArena.onFight, ctx)
	local S = shrineParts(ctx)
	if not S then return end
	for _, p in ipairs(S.Steps) do
		p.LocalTransparencyModifier = 1
		p.CanCollide = false
		p.CanQuery = false
	end
	for _, d in ipairs(S.Fx) do d.Enabled = false end
end
Ch.onFight = onFight

------------------------------------------------------------------------
-- ABSORB: he takes the True Lapeace
------------------------------------------------------------------------
function Ch.Absorb(ctx, t0, dur)
	local K = ctx.kit
	local H = ctx.HandFX
	local set = ctx.sets.Hand
	set.Parent = ctx.stage
	ctx.sets.Arena.Parent = ctx.stage
	ctx.Boss.Parent = ctx.sets.Arena
	if ctx.restoreArena then ctx.restoreArena() end
	ctx.hideBoss(true)
	for _, q in ipairs(ctx.LapisAura or {}) do q.Transparency = K.ns(1) end
	K.lighting("Arena", 0)
	K.fade(0, 0.3)
	local SB = SK.boss(ctx, K)
	local home = ctx.BossHome
	local look, right = home.LookVector, home.RightVector
	local cue = K.once()
	local cam = SK.camera(K)
	local shot = 0
	local S = shrineParts(ctx)
	local gem = S and S.Gem
	local gemHome = gem and gem:GetPivot()
	local gemOff = gem and gemHome:ToObjectSpace(CFrame.new(gem:GetBoundingBox().Position)) or CFrame.new()
	local lp0 = gem and (gemHome * gemOff).Position or ctx.TL.LapisPos
	local steal = { Gem = gem, Home = gemHome, Off = gemOff, Stolen = false }
	ctx.LapisSteal = steal
	ctx.onFight = function() onFight(ctx) end
	-- the stone's own storm of effects is too much this close: just its shine
	local gemFx = {}
	if gem then
		for _, d in ipairs(gem:GetDescendants()) do
			if (d:IsA("ParticleEmitter") and d.Name ~= "Shine") or d:IsA("Beam") or d:IsA("Light") then table.insert(gemFx, { d, d.Enabled }) end
		end
	end
	local stepBase = {}
	for _, p in ipairs(S and S.Steps or {}) do stepBase[p] = p.CFrame end
	local ABSORB_AT = 10.1
	local n = #H.Lapis
	K.tween(K.Grade, 0.8, { TintColor = Color3.fromRGB(225, 222, 255), Saturation = -0.1, Contrast = 0.2, Brightness = -0.02 })

	SK.run(K, t0, dur, function(t, dt)
		----------------------------------------------------------------
		-- him
		----------------------------------------------------------------
		local rootCF = holdRoot(ctx, t)
		ctx.BossRoot.CFrame = rootCF
		local straighten = K.k(t, 0, 2.2, K.E.inOutSine)
		local reach = K.k(t, 2.2, 4.4, K.E.inOutSine)
		local pull = K.k(t, 6.0, 9.0, K.E.inOutSine)
		local press = K.k(t, 9.2, ABSORB_AT, K.E.inCubic)
		local after = K.k(t, ABSORB_AT + 0.3, ABSORB_AT + 1.6, K.E.inOutSine)
		SB.reset()
		SB.body({ Waist = K.A(K.lerp(-22, -8, straighten) + press * 6 - after * 4, K.lerp(-6, 8, reach) * (1 - press), 0) })
		-- right hand: keeps them in his fist
		local palm = SK.holdPalm(ctx, t, 0)
		local hcf = SK.holdFist(ctx, SB, palm, rootCF)
		SB.Hands.Right.H.pose(SK.GRIP, 0.05, 0.8)
		local surf = CFrame.new(hcf:PointToWorldSpace(SK.fistSlot(ctx, 1)))
		-- left hand: out toward the shrine, then to his chest
		local lsh = (SB.R.cf("UpperTorso", rootCF) * CFrame.new(SB.R.B[SB.R.joint("LeftShoulder", "LeftUpperArm")].C0.Position)).Position
		local toStone = (lp0 - lsh).Unit
		local reachPos = lsh + toStone * 230
		local chestCF = SB.R.cf("UpperTorso", rootCF)
		local chestFront = chestCF.Position + look * 72 + UP * 12
		local restL = lsh + look * 60 - UP * 120 - right * 20
		local lpos, lF, lN
		if t < 9.2 then
			lpos = restL:Lerp(reachPos, reach)
			lN = toStone:Lerp(-UP, 1 - reach)
			lF = (UP - toStone * UP:Dot(toStone)).Unit:Lerp(look, 1 - reach)
			lpos = lpos:Lerp(lsh + look * 150 + UP * 10 - right * 30, pull * 0.8)
			lN = lN:Lerp(-right * 0.5 + look * 0.2 - UP * 0.2, pull)
		else
			lpos = (lsh + look * 150 + UP * 10 - right * 30):Lerp(chestFront + look * 30, press)
			lN = (-right * 0.5 + look * 0.2 - UP * 0.2):Lerp(-look, press)
			lF = look:Lerp(UP, press)
			lpos = lpos + look * 30 * after
		end
		local lcf = SB.hand("Left", lpos, lF, lN, Vector3.new(0, -1, 0) + right * 0.6, rootCF)
		local lcurl = t < 9.2 and K.lerp(0.35, 0.05, reach) + pull * 0.2 or K.lerp(0.25, 0.75, K.k(t, 9.2, 9.7)) * (1 - after * 0.5)
		SB.Hands.Left.H.pose(lcurl, K.lerp(0.1, 0.7, reach) * (1 - pull), 0.3)
		local lpalm = lcf * CFrame.new(0, 0, 18)
		local headCF = SB.R.cf("Head", rootCF)
		-- where he looks: at the party, then the stone, then them again
		local lookTgt
		if t < 1.5 then lookTgt = surf.Position
		elseif t < ABSORB_AT + 0.8 then lookTgt = lp0:Lerp(lpalm.Position, pull)
		else lookTgt = surf.Position end
		SB.lookAt(lookTgt, 1, rootCF)

		----------------------------------------------------------------
		-- the stone and its ring of lapis
		----------------------------------------------------------------
		local lift = K.k(t, 4.4, 5.8, K.E.outCubic)
		local tremble = lift * (1 - pull) * 1.5
		local up = lp0 + UP * 34 * lift + Vector3.new(math.noise(t * 11, 1) * tremble, math.noise(t * 11, 2) * tremble, math.noise(t * 11, 3) * tremble)
		local mid = (up + lpalm.Position) / 2 + UP * 90 + look * 40
		local gp = up:Lerp(mid, pull):Lerp(mid:Lerp(lpalm.Position, pull), pull)
		local core = chestCF.Position + look * 60 + UP * 12
		if t >= ABSORB_AT then gp = core elseif t >= 9.2 then gp = lpalm.Position:Lerp(core, press) end
		local spin = t * (0.8 + pull * 6)
		if gem then
			gem:PivotTo(CFrame.new(gp) * gemOff:Inverse() * CFrame.Angles(0, spin, 0))
			-- (its storm snuffs out as he rises for it; the shine stays)
			local snuff = K.k(t, 2.4, 3.6)
			for _, e in ipairs(gemFx) do e[1].Enabled = e[2] and snuff < 1 and math.random() > snuff end
		end
		-- the others: materialise in a ring round it and wheel about it, spinning
		local show = K.k(t, 4.6, 6.0)
		local ringR = t < ABSORB_AT and K.lerp(30, 62, show) * (1 - pull * 0.3) or K.lerp(60, 150, K.k(t, ABSORB_AT, ABSORB_AT + 0.8, K.E.outCubic)) * (1 - K.k(t, 11.6, 12.8, K.E.inCubic))
		local ringAxis = t < ABSORB_AT and CFrame.Angles(0.35, t * 0.2, 0) or CFrame.lookAt(Vector3.zero, look) * CFrame.Angles(math.rad(90), 0, 0)
		local turn = t * (0.9 + pull * 3.5 + (t >= ABSORB_AT and 2 or 0))
		for i, L in ipairs(H.Lapis) do
			local a = i / n * math.pi * 2 + turn
			local sink = t >= ABSORB_AT and K.k(t, 11.4 + i * 0.09, 12.1 + i * 0.09, K.E.inCubic) or 0
			local p = gp + (CFrame.new() * ringAxis):VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a))) * ringR * (1 - sink)
			H.lapisAt(L, CFrame.new(p) * CFrame.Angles(0.3 * math.sin(t + i), t * 2.2 + i, 0))
			local alpha = K.k(t, 4.6 + i * 0.08, 5.4 + i * 0.08) * (1 - K.k(sink, 0.85, 1))
			H.lapisAlpha(L, alpha)
			cue("lapis" .. i, alpha > 0.1, function() K.sfx(K.S.Ring, 0.25, 0.8 + i * 0.06) end)
			cue("sink" .. i, sink > 0.95, function()
				K.sfx(K.S.TonalHit, 0.35, 1.2 + i * 0.05)
				K.flash(0.12, Color3.fromRGB(200, 215, 255), 0.25)
			end)
		end
		-- the tether
		local teth = t >= 5.4 and t < 9.4
		H.Tether.Enabled = teth
		H.Tether2.Enabled = teth
		if teth then
			H.Tether.Attachment0.WorldPosition = lpalm.Position
			H.Tether.Attachment1.WorldPosition = gp
			H.Tether2.Attachment0.WorldPosition = lpalm.Position
			H.Tether2.Attachment1.WorldPosition = gp
			H.Tether.Width0 = 4 + math.noise(t * 20) * 3
			H.Tether2.Width0 = 26 + math.sin(t * 13) * 8
		end
		-- the core in his chest
		local cg = t >= ABSORB_AT and (0.55 + 0.25 * math.sin(t * 4)) or 0
		H.Core.set(core + look * 10, 90 + cg * 40, cg)

		----------------------------------------------------------------
		-- the shrine crumbles away
		----------------------------------------------------------------
		if S then
			for i, p in ipairs(S.Steps) do
				local d = K.k(t, 4.3 + i * 0.12, 5.6 + i * 0.12)
				p.LocalTransparencyModifier = d
				local b = stepBase[p]
				if b and d > 0 and d < 1 then
					p.CFrame = b * CFrame.new(math.noise(t * 17, i) * 0.6, -d * 2, math.noise(t * 17, i + 9) * 0.6)
				end
			end
			for _, d in ipairs(S.Fx) do d.Enabled = t < 4.3 and d.Enabled end
		end
		H.Host.CFrame = CFrame.new(lp0 - UP * 30)
		H.Dust.Rate = (t > 4.3 and t < 6) and 70 or 0
		H.Motes.Rate = (t > 4.3 and t < 7) and 40 or 0

		----------------------------------------------------------------
		-- the party in his fist
		----------------------------------------------------------------
		local myPos = placeInFist(ctx, hcf, t, function(slot)
			local focus = lp0:Lerp(gp, 0.8)
			local pose = SK.gripPose(K, t, slot, 0.8 * (1 - K.k(t, 5.8, 6.4)), 0)
			pose = K.mixPose(pose, K.Poses.Reach, K.k(t, 6.2 + slot * 0.1, 7.4) * (1 - K.k(t, ABSORB_AT, ABSORB_AT + 0.6)) * (slot == ctx.me and 1 or 0.6))
			pose.Neck = K.A(t < 4 and 30 or K.lerp(-10, 25, pull), 0, 0)
			return t < 4 and headCF.Position or focus, pose, 0
		end)

		----------------------------------------------------------------
		-- camera
		----------------------------------------------------------------
		local face = headCF.Position
		if t < 2.2 then
			if shot ~= 1 then shot = 1 cam.cut() end
			-- beside his fist: the party stuck in it, his face beyond
			local e = K.k(t, 0, 2.2)
			local fp = surf.Position
			local p = fp + look * 60 - right * 50 + UP * K.lerp(12, 6, e)
			cam.go(CFrame.lookAt(p, fp:Lerp(face, 0.4)), K.lerp(50, 44, e), dt, 8)
		elseif t < 4.3 then
			if shot ~= 2 then shot = 2 cam.cut() end
			-- behind the stone: his hand coming down for it
			local e = K.k(t, 2.2, 4.3)
			local p = lp0 + Vector3.new(-75, 12, 38) + (lp0 - lsh).Unit * 40
			cam.go(CFrame.lookAt(p, lp0:Lerp(lpalm.Position, 0.55)), K.lerp(58, 50, e), dt, 8)
		elseif t < 6.2 then
			if shot ~= 3 then shot = 3 cam.cut() end
			-- round the stone as the shrine falls away and the lapis gather
			-- (always from the arena side, so he's behind it, not in front)
			local a = math.pi + (t - 4.3) * 0.35 - 0.35
			local p = gp + Vector3.new(math.cos(a) * 110, 18, math.sin(a) * 110)
			cam.go(CFrame.lookAt(p, gp), 52, dt, 10)
		elseif t < 9.2 then
			if shot ~= 4 then shot = 4 cam.cut() end
			-- riding with it, torn toward his hand
			local p = gp - look * 70 + UP * 26 + right * 60
			cam.go(CFrame.lookAt(p, gp:Lerp(lpalm.Position, 0.4)), 56, dt, 7)
		elseif t < 12.4 then
			if shot ~= 5 then shot = 5 cam.cut() end
			-- in front of him: into his chest it goes
			local e = K.k(t, 9.2, 12.4)
			local p = core + look * K.lerp(420, 360, e) + right * 110 + UP * -30
			cam.go(CFrame.lookAt(p, core:Lerp(face, 0.25)), 48, dt, 8)
		else
			if shot ~= 6 then shot = 6 cam.cut() end
			-- from his palm, up at him
			local head = ctx.myRig and ctx.myRig:head() and ctx.myRig:head().Position or myPos
			local to = (face - head).Unit
			local p = head - to * 9 + UP * 1.2 + to:Cross(UP).Unit * 3
			cam.go(CFrame.lookAt(p, face:Lerp(core, 0.3)), 50, dt, 8)
		end

		----------------------------------------------------------------
		-- beats
		----------------------------------------------------------------
		cue("line1", t >= 0.8, function() K.say("SPIRAL APES.", 1.0, { Scale = 0.09 }) end)
		cue("reach", t >= 2.3, function()
			K.sfx(K.S.Riser, 0.7, 0.8)
			K.sfx(K.S.Electric, 0.5, 0.6)
		end)
		cue("line2", t >= 3.0, function() K.say("YOU HAVE CRAWLED\nFAR ENOUGH.", 1.1, { Scale = 0.075 }) end)
		cue("crumble", t >= 4.3, function()
			K.sfx(K.S.RockBoom, 0.9, 0.8)
			K.sfx(K.S.Rumble, 0.8)
			K.shake(1.5, 1.5)
			if S then
				for _, p in ipairs(S.Steps) do K.vfx("Smoke-01", p.CFrame, H.FX, 2, 8, 4) end
			end
		end)
		cue("tear", t >= 6.0, function()
			K.sfx(K.S.Whoosh, 1, 0.5, { Reverb = 3 })
			K.sfx(K.S.Portal2, 0.6, 0.8)
			K.shake(1.5, 1.5)
		end)
		cue("line3", t >= 6.6, function() K.say("THIS LIGHT\nWAS NEVER YOURS.", 1.1, { Scale = 0.075 }) end)
		cue("absorb", t >= ABSORB_AT, function()
			steal.Stolen = true
			K.sfx(K.S.Boom, 1, 0.6, { Reverb = 3 })
			K.sfx(K.S.TonalHit, 1, 0.5)
			K.sfx(K.S.Thunder, 0.7)
			K.shake(3.5, 1.2)
			K.kick(-10, 0.8)
			K.flash(0.35, Color3.fromRGB(215, 225, 255), 0.8)
			task.spawn(K.impact, { ctx.Boss }, "WB", 0.05)
			K.tween(K.Grade, 1.6, { TintColor = Color3.fromRGB(175, 185, 255), Saturation = -0.4, Brightness = -0.08, Contrast = 0.35 })
			ctx.fadeMusic(0.9, 0.3)
			local c = core
			local t1 = os.clock()
			local conn
			conn = game:GetService("RunService").RenderStepped:Connect(function()
				local u = math.clamp((os.clock() - t1) / 1.4, 0, 1)
				local r0 = 20 + 800 * (1 - (1 - u) ^ 3)
				H.Wave.update(CFrame.lookAt(c, c + look), r0, r0 + 40 + u * 180, u * 2)
				H.Wave.setTransparency(math.min(0.99, 0.1 + u ^ 1.4 * 0.9))
				if u >= 1 or not set.Parent then conn:Disconnect() end
			end)
		end)
		cue("line4", t >= 12.3, function()
			K.sfx(K.S.Thunder, 0.6)
			K.say("HERE, YOUR EVOLUTION ENDS.", 1.2, { Scale = 0.075 })
		end)
		K.stream(lp0)
	end)
	H.Tether.Enabled = false
	H.Tether2.Enabled = false
	H.Dust.Rate = 0
	H.Motes.Rate = 0
	for _, L in ipairs(H.Lapis) do H.lapisAlpha(L, 0) end
	if S then
		for _, p in ipairs(S.Steps) do
			p.LocalTransparencyModifier = 1
			if stepBase[p] then p.CFrame = stepBase[p] end
		end
		for _, d in ipairs(S.Fx) do d.Enabled = false end
	end
	steal.Stolen = true
	ctx.AbsorbCore = true
end

-- the stone stays in his chest (after the Absorb) as a cold core
local function holdGem(ctx, SB, rootCF, t)
	local st = ctx.LapisSteal
	if not (st and st.Gem and st.Stolen) then return end
	local look = ctx.BossHome.LookVector
	local chest = SB.R.cf("UpperTorso", rootCF)
	local core = chest.Position + look * 60 + UP * 12
	local off = st.Off or CFrame.new()
	st.Gem:PivotTo(CFrame.new(core) * off:Inverse() * CFrame.Angles(0, t * 0.8, 0))
	local H = ctx.HandFX
	H.Core.set(core + look * 10, 100, 0.55 + 0.2 * math.sin(t * 4))
end

------------------------------------------------------------------------
-- CRUSH: his fist closes on them
------------------------------------------------------------------------
function Ch.Crush(ctx, t0, dur)
	local K = ctx.kit
	local H = ctx.HandFX
	ctx.sets.Hand.Parent = ctx.stage
	ctx.sets.Arena.Parent = ctx.stage
	ctx.Boss.Parent = ctx.sets.Arena
	if ctx.restoreArena then ctx.restoreArena() end
	ctx.hideBoss(true)
	local SB = SK.boss(ctx, K)
	local home = ctx.BossHome
	local look, right = home.LookVector, home.RightVector
	local cue = K.once()
	local cam = SK.camera(K)
	local shot = 0
	local me = ctx.myRig
	local beat = K.loop(K.S.Heartbeat, 0, 0.1)
	if ctx.LapisSteal == nil then K.lighting("Arena", 0) K.fade(0, 0.3) end
	K.tween(K.Grade, 5, { Saturation = -0.85, Contrast = 0.4, Brightness = -0.12, TintColor = Color3.fromRGB(200, 200, 215) })
	K.vignette(0.55, Color3.new(0, 0, 0), 3)
	K.muffle(0.55, 3)
	ctx.fadeMusic(0.25, 4)
	SK.run(K, t0, dur, function(t, dt)
		local rootCF = holdRoot(ctx, t + 14)
		ctx.BossRoot.CFrame = rootCF
		local squeeze = K.k(t, 0.3, 3.6, K.E.inOutSine)
		local crush = K.k(t, 3.6, 6.0, K.E.inOutSine)
		SB.reset()
		SB.body({
			Waist = K.A(-8 - squeeze * 6, 10 * squeeze, 0),
			LeftShoulder = K.A(-5, 0, -30), LeftElbow = K.A(18, 0, 0),
		})
		SK.hang(SB, "Left", 0.5, 0.1)
		-- the fist lifts toward his face as it closes
		local palm = SK.holdPalm(ctx, t + 14, squeeze)
		local hcf = SK.holdFist(ctx, SB, palm, rootCF)
		-- (and when the life starts going out of them, it squeezes harder still)
		local dying = K.k(t, 4.4, 6.6, K.E.inOutSine)
		local curl = SK.GRIP + squeeze * 0.12 + crush * 0.1 + dying * 0.12
		SB.Hands.Right.H.pose(curl, 0.05 - squeeze * 0.2, 0.8 + squeeze * 0.2, 0.3 + crush * 0.8 + dying * 0.6, t)
		local surf = CFrame.new(hcf:PointToWorldSpace(SK.fistSlot(ctx, 1)))
		local headCF = SB.R.cf("Head", rootCF)
		SB.lookAt(surf.Position, 1, rootCF)
		holdGem(ctx, SB, rootCF, t)

		-- the party: shoving at his fingers, then crushed... going limp, head back
		local myPos = placeInFist(ctx, hcf, t, function(slot)
			local strain = K.k(t, 0.3, 1.2) * (1 - dying)
			local pose = SK.gripPose(K, t, slot, strain * (1 + crush * 0.6), dying)
			-- gasping: the head jerks back as the fingers bite
			pose.Neck = (pose.Neck or CFrame.new()) * K.A(crush * (1 - dying) * 18 + math.sin(t * 5 + slot) * 3 * squeeze * (1 - dying), 0, 0)
			return headCF.Position, pose, squeeze * 0.4 + crush * 0.5 + dying * 0.6
		end)

		-- the world goes grey, the heart slows
		beat.Volume = 0.6 + crush * 0.4
		beat.PlaybackSpeed = K.lerp(1.3, 0.7, K.k(t, 2, dur))

		-- camera
		local face = headCF.Position
		if t < 2.2 then
			if shot ~= 1 then shot = 1 cam.cut() end
			-- side on: the fingers folding over them
			local p = surf.Position + right * 150 + UP * 20 - look * 30
			cam.go(CFrame.lookAt(p, surf.Position), 44, dt, 8)
		elseif t < 4.6 then
			if shot ~= 2 then shot = 2 cam.cut() end
			-- close over the fist: you, shoving back with everything you have
			local hd = me and me:head() and me:head().CFrame or CFrame.new(myPos)
			local fwd = hd.LookVector
			local fp = me and me.Torso and me.Torso.Position or myPos
			local toBoss = (headCF.Position - fp)
			toBoss = Vector3.new(toBoss.X, 0, toBoss.Z).Unit
			-- (from his side of the fist, so it's your face, not the back of your head)
			local p = fp + toBoss * 13 + UP * 6 + toBoss:Cross(UP).Unit * 5
			cam.go(CFrame.lookAt(p, fp + UP * 0.5) * CFrame.Angles(0, 0, math.sin(t * 2) * 0.05), 55, dt, 10)
			K.shake(0.6 + crush, 0.1, 14, true)
		elseif t < 6.4 then
			if shot ~= 3 then shot = 3 cam.cut() end
			-- your face, low and close
			local head = me and me:head() and me:head().CFrame or CFrame.new(myPos)
			local p = head.Position + head.LookVector * 3.2 - head.UpVector * 0.8 + head.RightVector * 0.6
			cam.go(CFrame.lookAt(p, head.Position), K.lerp(50, 38, K.k(t, 4.6, 6.4)), dt, 10)
		else
			if shot ~= 4 then shot = 4 cam.cut() end
			-- back out: his fist, his face, a world drained of colour
			local e = K.k(t, 6.4, dur, K.E.outSine)
			local p = surf.Position + right * K.lerp(90, 420, e) + UP * K.lerp(10, 60, e) - look * K.lerp(10, 80, e)
			cam.go(CFrame.lookAt(p, surf.Position:Lerp(face, 0.4 * e)), K.lerp(46, 38, e), dt, 6)
		end

		cue("grip", t >= 0.3, function()
			K.sfx(K.S.MetalHit, 0.6, 0.35)
			K.sfx(K.S.DarkDrone, 0.8, 0.6)
		end)
		cue("creak", t >= 2.4, function()
			K.sfx(K.S.RockBoom, 0.5, 0.5)
			K.shake(1.5, 2)
		end)
		cue("crush", t >= 3.8, function()
			K.sfx(K.S.Punch2, 0.7, 0.6)
			K.sfx(K.S.BodyFall, 0.8, 0.7)
			K.shake(2.5, 1)
			K.kick(-6, 0.5)
			task.spawn(K.impact, SK.models(ctx), "BW", 0.06)
		end)
		cue("dark", t >= dur - 1.4, function()
			K.fade(0.82, 1.3)
			K.vignette(0.85, Color3.new(0, 0, 0), 1.3)
			ctx.fadeMusic(0, 1.2)
		end)
		K.stream(SK.CATCH)
	end)
	ctx.CrushBeat = beat
end

------------------------------------------------------------------------
-- FUNNEL: every galaxy pours its spiral energy into the fist
------------------------------------------------------------------------
function Ch.Funnel(ctx, t0, dur)
	local K = ctx.kit
	local H = ctx.HandFX
	ctx.sets.Hand.Parent = ctx.stage
	ctx.sets.Arena.Parent = ctx.stage
	ctx.Boss.Parent = ctx.sets.Arena
	if ctx.restoreArena then ctx.restoreArena() end
	ctx.hideBoss(true)
	local SB = SK.boss(ctx, K)
	local home = ctx.BossHome
	local look, right = home.LookVector, home.RightVector
	local AC = ctx.TL.ArenaCenter
	local cue = K.once()
	local cam = SK.camera(K)
	local shot = -1
	local me = ctx.myRig
	local src = galaxySources(ctx)
	local NS = math.min(#src, #H.Streams)
	local CUT0, CUT = 0.9, 0.34 -- the fast cuts: when they start, how long each lasts
	local cutsEnd = CUT0 + NS * CUT
	local beat = ctx.CrushBeat or K.loop(K.S.Heartbeat, 0.8, 0.1)
	if not ctx.CrushBeat then K.lighting("Arena", 0) end
	-- each galaxy turns green as it gives up its light (put back afterwards)
	local tint = {}
	for i = 1, NS do
		local g = src[i]
		tint[i] = {}
		if g.Part then
			for _, b in ipairs(g.Part:GetChildren()) do
				if b:IsA("Beam") then table.insert(tint[i], { b, b.Color, b.Brightness }) end
			end
		end
	end
	local GREENSEQ = ColorSequence.new(SK.GREEN, SK.LIME)
	K.muffle(0.4, 0.5)
	SK.run(K, t0, dur, function(t, dt)
		local rootCF = holdRoot(ctx, t + 22)
		local flinch = K.k(t, 6.4, 7.0, K.E.outBack)
		ctx.BossRoot.CFrame = rootCF * CFrame.Angles(-math.rad(4) * flinch, 0, 0)
		rootCF = ctx.BossRoot.CFrame
		SB.reset()
		SB.body({ Waist = K.A(-14 + flinch * 6, 10 - flinch * 16, 0), LeftShoulder = K.A(-5 + flinch * 40, 0, -30 - flinch * 20), LeftElbow = K.A(18 + flinch * 50, 0, 0) })
		SK.hang(SB, "Left", 0.5, 0.1)
		local palm = SK.holdPalm(ctx, t + 22, 1)
		local hcf = SK.holdFist(ctx, SB, palm, rootCF)
		-- (the fist trembles harder as the light builds inside it)
		local build = K.k(t, cutsEnd + 1.6, dur - 0.6)
		SB.Hands.Right.H.pose(0.96 - build * 0.12, -0.15, 1, 1 + build * 1.5, t)
		local surf = CFrame.new(hcf:PointToWorldSpace(SK.fistSlot(ctx, 1)))
		local headCF = SB.R.cf("Head", rootCF)
		SB.lookAt(surf.Position:Lerp(headCF.Position + look * 300, flinch * 0.3), 1, rootCF)
		holdGem(ctx, SB, rootCF, t)
		local fist = hcf:PointToWorldSpace(Vector3.new(14, 22, 16))
		local myPos = placeInFist(ctx, hcf, t, function(slot)
			return headCF.Position, SK.gripPose(K, t, slot, 0, 1 - build * 0.3), 1.5 - build * 0.5
		end)
		-- the spark inside you
		local myTorso = me and me.Torso and me.Torso.Position or myPos
		local hope = K.k(t, 0.2, 0.7) * (0.6 + 0.4 * math.sin(t * 9))
		H.Hope.set(myTorso, K.lerp(2, 6, build), math.max(hope, build))
		-- the light leaking out between his fingers
		local arrive = K.k(t, cutsEnd + 1.0, cutsEnd + 2.8)
		H.FistGlow.set(fist, K.lerp(40, 260, arrive) * (1 + 0.1 * math.sin(t * 17)), arrive * 0.9)
		H.FistLight.Parent = SB.Hands.Right.H.Palm
		H.FistLight.Brightness = arrive * 8
		H.FistLight.Range = 40 + arrive * 80

		-- every galaxy: a flare, then a river of green light toward the fist
		for i = 1, NS do
			local g = src[i]
			local at = CUT0 + (i - 1) * CUT
			local fl = H.Flares[i]
			local d = (g.Pos - fist).Magnitude
			local flare = K.k(t, at - 0.06, at + 0.16, K.E.outCubic)
			local sz = math.clamp(d * 0.22, 2500, 16000)
			fl.G.set(g.Pos, sz * (0.8 + 0.2 * flare), flare * 0.22)
			fl.C.set(g.Pos, 1, 0)
			-- its heart becomes a green whirlpool pouring out toward you
			H.Bursts[i].set(g.Pos, fist, math.min(g.R * 0.7, 7000), flare * (1 - 0.35 * K.k(t, dur - 1.5, dur)), t + i)
			local green = flare > 0.01
			if tint[i].On ~= green then
				tint[i].On = green
				for _, e in ipairs(tint[i]) do
					e[1].Color = green and GREENSEQ or e[2]
					e[1].Brightness = e[3] * (green and 1.5 or 1)
				end
			end
			local head = K.k(t, at + 0.12, at + 0.12 + K.lerp(2.6, 3.4, math.clamp(d / 35000, 0, 1)), K.E.inQuad)
			local w = math.clamp(d * 0.012, 120, 420)
			H.Streams[i].set(g.Pos, fist, head, w, t + i, 5)
			cue("flare" .. i, flare > 0, function()
				K.sfx(K.S.Electric, 0.35, 1 + i * 0.07)
				K.sfx(K.S.TonalHit, 0.35, 1.1 + i * 0.06)
			end)
		end

		----------------------------------------------------------------
		-- camera
		----------------------------------------------------------------
		local face = headCF.Position
		if t < CUT0 then
			if shot ~= 0 then shot = 0 cam.cut() end
			-- in the dark of his fist: one small green light
			local head = me and me:head() and me:head().Position or myPos
			local p = myTorso + (head - myTorso).Unit * 1 + (face - myTorso).Unit * 3.5 + right * 0.8
			cam.go(CFrame.lookAt(p, myTorso), 40, dt, 12)
		elseif t < cutsEnd then
			-- snap, snap, snap: every galaxy in the realm
			local i = math.clamp(math.floor((t - CUT0) / CUT) + 1, 1, NS)
			if shot ~= i then shot = i cam.cut() end
			local g = src[i]
			local toA = (fist - g.Pos).Unit
			local sd = toA:Cross(UP).Unit * (i % 2 == 0 and 1 or -1)
			local u = (t - CUT0 - (i - 1) * CUT) / CUT
			-- off to one side of it, so its river is seen tearing out across the frame
			local R = math.min(g.R, 14000)
			-- behind it and off to one side: its whirlpool heart, and the river pouring away toward you
			local p = g.Pos - toA * R * K.lerp(1.0, 0.8, u) + sd * R * 0.9 + UP * R * 0.45
			cam.go(CFrame.lookAt(p, g.Pos + toA * R * 0.7) * CFrame.Angles(0, 0, (i % 2 == 0 and 1 or -1) * 0.1), K.lerp(64, 56, u), dt, 12)
		elseif t < cutsEnd + 1.9 then
			if shot ~= 100 then shot = 100 cam.cut() end
			-- from high above: every river converging on one point
			local e = K.k(t, cutsEnd, cutsEnd + 1.9)
			local p = AC + Vector3.new(-5200, 9500, 6400) * K.lerp(1, 0.8, e)
			cam.go(CFrame.lookAt(p, fist), 62, dt, 5)
		elseif t < dur - 1.4 then
			if shot ~= 101 then shot = 101 cam.cut() end
			-- they reach him: his fist blazing, the giant flinching
			local e = K.k(t, cutsEnd + 1.9, dur - 1.4)
			local p = fist + right * 330 + look * 120 + UP * K.lerp(-40, 0, e)
			cam.go(CFrame.lookAt(p, fist:Lerp(face, 0.3)), K.lerp(46, 40, e), dt, 7)
			K.shake(0.8 + e, 0.1, 18, true)
		else
			if shot ~= 102 then shot = 102 cam.cut() end
			-- and into you: through his fingers, into your chest
			local e = K.k(t, dur - 1.4, dur, K.E.inCubic)
			local from = fist + right * 180 + look * 60
			local to = myTorso + (fist + right * 100 - myTorso).Unit * 2.2
			cam.go(CFrame.lookAt(from:Lerp(to, e), myTorso), K.lerp(46, 16, e), dt, 30)
		end

		----------------------------------------------------------------
		-- beats
		----------------------------------------------------------------
		cue("glint", t >= 0.25, function()
			K.fade(0.3, 0.5)
			K.sfx(K.S.Ring, 0.8, 1.2)
			K.sfx(K.S.Heartbeat, 1, 1)
			beat.PlaybackSpeed = 0.9
		end)
		cue("cuts", t >= CUT0, function()
			K.fade(0, 0.1)
			K.vignette(0.2, Color3.new(0, 0, 0), 0.4)
			K.muffle(0, 0.3)
			K.tween(K.Grade, 0.4, { Saturation = 0.25, Contrast = 0.25, Brightness = 0, TintColor = Color3.fromRGB(225, 255, 225) })
			ctx.setMusic(K.S.M_Universe, 0.7, 0.2)
			K.sfx(K.S.GreenAura, 0.8, 1)
		end)
		cue("converge", t >= cutsEnd, function()
			K.sfx(K.S.Riser, 1, 0.9)
			K.sfx(K.S.Overdrive, 0.7, 0.9)
		end)
		cue("arrive", t >= cutsEnd + 1.9, function()
			K.sfx(K.S.Boom, 1, 0.8)
			K.sfx(K.S.Electric, 0.8, 0.7)
			K.shake(3, 1.5)
			K.flash(0.3, SK.GREEN, 0.6)
			beat.PlaybackSpeed = 1.5
			beat.Volume = 1
		end)
		cue("into", t >= dur - 1.4, function()
			K.sfx(K.S.Whoosh, 1, 1.3)
			K.sfx(K.S.Heartbeat, 1, 1.4)
		end)
		cue("white", t >= dur - 0.35, function()
			K.fade(1, 0.3, Color3.fromRGB(200, 255, 200))
		end)
		-- (the galaxies are always loaded; jumping the streaming focus 20,000+ studs
		-- to each one paused the game to load around them)
		K.stream(fist)
	end)
	for _, s in ipairs(H.Streams) do s.off() end
	for _, b in ipairs(H.Bursts) do b.set(SK.CATCH, SK.CATCH + UP, 1, 0, 0) end
	for _, list in pairs(tint) do for _, e in ipairs(list) do e[1].Color = e[2] e[1].Brightness = e[3] end end
	for _, f in ipairs(H.Flares) do f.G.set(SK.CATCH, 1, 0) f.C.set(SK.CATCH, 1, 0) end
	H.Hope.set(SK.CATCH, 1, 0)
	H.FistGlow.set(SK.CATCH, 1, 0)
	H.FistLight.Brightness = 0
	ctx.CrushBeat = beat
end

return Ch
