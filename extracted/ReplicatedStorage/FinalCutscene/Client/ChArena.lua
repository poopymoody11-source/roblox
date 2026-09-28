--==================================================
-- CHAPTERS 10-12: APPROACH, REVEAL, PUNCH
-- The walk up to True Lapeace (the closer you get, the more
-- the world bends), the Anti-Spiral rising from beyond the
-- edge of the arena, and the punch you try to block.
--==================================================
local Ch = {}

local function walkTarget(ctx, slot)
	local AC = ctx.TL.ArenaCenter
	local n = ctx.n
	local z = ((slot - 1) - (n - 1) / 2) * 8.5
	return AC + Vector3.new(-36 - (slot % 2) * 7, 0, z)
end
Ch.walkTarget = walkTarget

-- where the punch throws everyone (they get up here, and the fight
-- starts from TL.ArenaStand, just in front of it)
local function knockPoint(ctx, slot)
	local s = ctx.TL.ArenaStand(slot)
	return Vector3.new(s.X - 7, ctx.TL.ArenaCenter.Y, s.Z)
end
Ch.knockPoint = knockPoint

function Ch.build(ctx)
	local K = ctx.kit
	local set = Instance.new("Folder")
	set.Name = "ArenaSet"
	ctx.sets.Arena = set
	-- the Anti-Spiral stand-in (the real one is hidden on this screen)
	local boss = K.Assets.AntiSpiral:Clone()
	boss.Name = "AntiSpiralCutscene"
	for _, d in ipairs(boss:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = d.Name == "HumanoidRootPart"
		end
	end
	local hb = boss:FindFirstChild("Hitbox")
	if hb then hb:Destroy() end
	local hum = boss:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.PlatformStand = true
	end
	boss.Parent = set
	ctx.Boss = boss
	ctx.BossRoot = boss:FindFirstChild("HumanoidRootPart")
	ctx.BossHome = ctx.BossRoot.CFrame
	-- R15 joints we pose
	ctx.BossJ = {}
	ctx.BossBase = {}
	for _, d in ipairs(boss:GetDescendants()) do
		if d:IsA("Motor6D") then
			ctx.BossJ[d.Name] = d
			ctx.BossBase[d.Name] = d.C0
		end
	end
	-- dark energy that gathers on the fist
	local fist = boss:FindFirstChild("RightHand")
	ctx.FistAura = K.emitter(fist, {
		Texture = "15041986621", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = ColorSequence.new(Color3.fromRGB(120, 160, 255)), Size = K.ns(0, 60, 1, 120), Lifetime = NumberRange.new(0.4, 0.6),
		Speed = NumberRange.new(0), Brightness = 4, Rotation = NumberRange.new(0, 360), Rate = 0,
	})
	ctx.BossSmoke = K.emitter(ctx.BossRoot, {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(10, 10, 30)), Size = K.ns(0, 60, 1, 180),
		Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(20, 60), SpreadAngle = Vector2.new(180, 180), Rate = 0,
		LightEmission = 0, LightInfluence = 0.2, Transparency = K.ns(0, 0.3, 1, 1), Rotation = NumberRange.new(0, 360),
	})
	-- (the True Lapeace is gone from the game: no halo, sparkles or light for it)
	ctx.LapisAura = {}
end

local function bossPose(ctx, pose)
	for name, m in pairs(ctx.BossJ) do
		local base = ctx.BossBase[name]
		local r = pose[name]
		m.C0 = r and (CFrame.new(base.Position) * r * base.Rotation) or base
	end
end
Ch.bossPose = bossPose

local function faceQuads(ctx, list, center)
	local K = ctx.kit
	local cam = workspace.CurrentCamera.CFrame
	for i, q in ipairs(list) do
		K.moveQuad(q, CFrame.lookAt(center, cam.Position) * CFrame.Angles(0, 0, os.clock() * 0.2 * i))
	end
end

------------------------------------------------------------------------
-- APPROACH
------------------------------------------------------------------------
function Ch.Approach(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local set = ctx.sets.Arena
	set.Parent = ctx.stage
	ctx.Boss.Parent = nil -- not yet
	ctx.hideBoss(true)
	K.lighting("Arena", 0)
	local AC = ctx.TL.ArenaCenter
	local lp = ctx.TL.LapisPos
	local me = ctx.myRig
	local cue = K.once()
	local rest = {}
	local facing = CFrame.lookAt(Vector3.zero, Vector3.new(1, 0, 0))
	for slot, rig in pairs(ctx.rigs) do
		rest[slot] = rig:cf().Position
		rig:clearPose()
		rig:play("Walk", 0.4, 0.62)
	end
	ctx.setMusic(K.S.Choir, 0, 0)
	ctx.fadeMusic(0.55, 5)
	local amb = K.loop(K.S.SpaceAmb, 0.3, 2, 1.2)
	ctx.LapisSparkle.Rate = 20
	K.DOF.Enabled = true
	K.DOF.FarIntensity = 0
	K.DOF.InFocusRadius = 60

	K.run(t0, dur, function(t, dt)
		local center
		for slot, rig in pairs(ctx.rigs) do
			local wt = walkTarget(ctx, slot)
			local start = rest[slot] or wt
			local delay = ((slot - 1) % 3) * 0.3
			local u = K.k(t, 0.8 + delay, dur - 0.8, E.inOutSine)
			local p = Vector3.new(K.lerp(start.X, wt.X, u), AC.Y + 3, K.lerp(start.Z, wt.Z, u))
			local bob = math.sin(t * 5.5 + slot) * 0.06
			rig:setCF(CFrame.lookAt(p + Vector3.new(0, bob, 0), Vector3.new(lp.X, p.Y, lp.Z)))
			-- heads lift toward the light; arms drift up at the end
			local near = K.k(u, 0.55, 1)
			local pose = { Neck = K.A(8 + near * 16, math.sin(t * 0.7 + slot) * 8, 0) }
			if slot == ctx.me or near > 0.6 then
				pose = K.mixPose(pose, K.Poses.Reach, K.k(t, dur - 2.5, dur - 0.6))
			end
			rig:setPose(pose)
			rig:apply()
			if u >= 0.999 then rig:stop("Walk", 0.5) rig:play("Idle", 0.5) end
			if rig == me then center = p end
		end
		center = center or walkTarget(ctx, 1)
		-- the closer you are, the stronger the pull of it
		local dist = (Vector3.new(center.X, 0, center.Z) - Vector3.new(lp.X, 0, lp.Z)).Magnitude
		local near = 1 - math.clamp((dist - 38) / 60, 0, 1)
		faceQuads(ctx, ctx.LapisAura, lp)
		K.setQuadSize(ctx.LapisAura[1], 110 + near * 90, 110 + near * 90)
		K.setQuadSize(ctx.LapisAura[2], 160 + near * 120 + math.sin(t * 2) * 10, 160 + near * 120 + math.sin(t * 2) * 10)
		ctx.LapisLight.Brightness = near * 6
		K.Bloom.Intensity = 0.55 + near * 0.55
		K.Bloom.Size = 28 + near * 14
		K.Grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 244, 215), near)
		K.Grade.Brightness = near * 0.03
		K.Blur.Enabled = near > 0.3
		K.Blur.Size = (near - 0.3) * 8 * (0.7 + 0.3 * math.sin(t * 3))
		K.vignette(0.35 * near, Color3.fromRGB(255, 240, 210), 0.1)
		local warp = near * near

		-- camera
		local head = me and me:head() and me:head().Position or center
		if t < 4.2 then
			local e = K.k(t, 0, 4.2)
			local p = center + Vector3.new(K.lerp(-30, -24, e), K.lerp(7, 5, e), K.lerp(14, 10, e))
			K.setCam(CFrame.lookAt(p, lp - Vector3.new(0, 20, 0)), 48)
		elseif t < 8.2 then
			-- in front of the group, backing away toward the lapis
			local e = K.k(t, 4.2, 8.2)
			local p = center + Vector3.new(K.lerp(26, 20, e), 4, K.lerp(-6, 4, e))
			K.setCam(CFrame.lookAt(p, center + Vector3.new(0, 2, 0)), 50)
		else
			-- over your shoulder, the lapis swallowing the frame, reality warping
			local e = K.k(t, 8.2, dur)
			local p = head + Vector3.new(-5, 1.2, 2.2)
			local sway = CFrame.Angles(math.sin(t * 2.3) * 0.03 * warp, math.sin(t * 1.7) * 0.03 * warp, math.sin(t * 1.1) * 0.08 * warp)
			K.setCam(CFrame.lookAt(p, lp) * sway, K.lerp(55, 36, e) + math.sin(t * 4) * 4 * warp)
		end
		cue("choirSwell", t >= 6, function() K.sfx(K.S.Riser, 0.4, 1.2) end)
		cue("silence", t >= dur - 0.35, function()
			ctx.fadeMusic(0, 0.25)
			K.fadeSound(amb, 0, 0.25, true)
		end)
		K.stream(center)
	end)
	ctx.LapisSparkle.Rate = 0
end

------------------------------------------------------------------------
-- REVEAL: he rises out of the void beyond the edge, unfurls, and takes
-- the True Lapeace from the middle of the arena, right out from under you
------------------------------------------------------------------------
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

function Ch.Reveal(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local set = ctx.sets.Arena
	set.Parent = ctx.stage
	local boss = ctx.Boss
	boss.Parent = set
	local home = ctx.BossHome
	local lp0 = ctx.TL.LapisPos
	local me = ctx.myRig
	local cue = K.once()
	K.DOF.Enabled = false
	K.Blur.Enabled = false
	K.tween(K.Bloom, 0.6, { Intensity = 0.55, Size = 28 }) -- (Approach swelled it)
	K.vignette(0.5, Color3.new(0, 0, 0), 0.4)
	K.tween(K.Grade, 0.6, { TintColor = Color3.fromRGB(210, 205, 255), Brightness = -0.06, Contrast = 0.3, Saturation = -0.2 })
	local head = boss:FindFirstChild("Head")
	local hand = boss:FindFirstChild("RightHand")
	local chest = boss:FindFirstChild("UpperTorso") or boss:FindFirstChild("Torso")

	-- the real True Lapeace on its shrine (moved locally; he keeps it)
	local bf = workspace:FindFirstChild("BossFight") or ctx.StashedArena
	local shrine = bf and bf:FindFirstChild("LapisShrine")
	local gem = shrine and shrine:FindFirstChild("TrueLapeace")
	local gemHome = gem and gem:GetPivot()
	local shrineAura = shrine and shrine:FindFirstChild("AuraHost")
	local steal = { Gem = gem, Home = gemHome }
	ctx.LapisSteal = steal
	ctx.onFight = function() Ch.onFight(ctx) end

	-- a column of void boiling up where he rises, with a cold rim of light
	local ph = K.part({ Name = "VoidPillar", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(home.Position) }, set)
	local base = Vector3.new(home.X, lp0.Y - 520, home.Z)
	local pillars = {}
	for i = 1, 3 do
		local w = 330 - i * 70
		local b = K.ray(ph, base, base + Vector3.new(0, 1500, 0), w, w * 1.3, "10180479311", {
			Emission = 0, Color = Color3.fromRGB(8, 6, 22), Transparency = K.ns(0, 0.98, 0.15, 0.25, 0.7, 0.35, 1, 0.98),
			Speed = 0.25 + i * 0.12, Mode = Enum.TextureMode.Wrap, Length = 380 + i * 60, Segments = 10,
		})
		table.insert(pillars, { B = b, W = w })
	end
	local rim = K.ray(ph, base, base + Vector3.new(0, 1500, 0), 420, 520, "10180479311", {
		Color = Color3.fromRGB(90, 110, 255), Brightness = 2.5, Transparency = K.ns(0, 0.98, 0.2, 0.35, 0.7, 0.45, 1, 0.98),
		Speed = 0.6, Mode = Enum.TextureMode.Wrap, Length = 500, Segments = 10,
	})
	-- the pull: a thread of his energy from the palm to the stone
	local tether = K.ray(ph, lp0, lp0 + Vector3.new(0, 1, 0), 4, 2, nil, { Color = Color3.fromRGB(130, 160, 255), Brightness = 4, Transparency = K.ns(0, 0.1, 1, 0.3), Segments = 12 })
	local tether2 = K.ray(ph, lp0, lp0 + Vector3.new(0, 1, 0), 14, 6, "10180479311", { Color = Color3.fromRGB(70, 80, 220), Brightness = 2, Transparency = K.ns(0, 0.5, 1, 0.7), Speed = 3, Mode = Enum.TextureMode.Wrap, Length = 40, Segments = 12 })
	tether.Enabled = false
	tether2.Enabled = false
	local wave = K.softRing(ph, 64, 10, 40, { Brightness = 3, Alpha = 0 })
	for _, q in ipairs(wave.Q) do q.Color = ColorSequence.new(Color3.fromRGB(190, 200, 255)) end
	wave.setTransparency(0.99)

	local shrineParts = {}
	if shrineAura then
		for _, d in ipairs(shrineAura:GetDescendants()) do
			if d:IsA("Beam") or d:IsA("ParticleEmitter") or d:IsA("Light") then table.insert(shrineParts, d) end
		end
	end
	-- the stone's own storm of effects is snuffed as he rises (it buried every shot
	-- in glare); from here its light is ours, small and controlled
	local gemFx = {}
	if gem then
		for _, d in ipairs(gem:GetDescendants()) do
			-- (all but its gentle shine)
			if (d:IsA("ParticleEmitter") and d.Name ~= "Shine") or d:IsA("Beam") or d:IsA("Light") then table.insert(gemFx, d) end
		end
		-- let the stone's own blue show through its white highlight
		for _, h in ipairs(gem:GetDescendants()) do
			if h:IsA("Highlight") then h.FillTransparency = 0.75 end
		end
	end
	for _, q in ipairs(ctx.LapisAura) do q.Color = ColorSequence.new(Color3.fromRGB(255, 228, 170)) end
	local rest = {}
	for slot, rig in pairs(ctx.rigs) do rest[slot] = walkTarget(ctx, slot) end
	local absorbed = false
	local absorbAt = 10.9

	K.run(t0, dur, function(t, dt)
		----------------------------------------------------------------
		-- the titan: hunched and limp as the void lifts him, then unfurling
		----------------------------------------------------------------
		local rise = K.k(t, 0.8, 5.0, E.outCubic)
		local settle = K.k(t, 4.4, 5.0, E.outSine) * (1 - K.k(t, 5.0, 6.2, E.inOutSine))
		local y = K.lerp(-720, 0, rise) + settle * 14
		ctx.BossRoot.CFrame = home * CFrame.new(0, y, 0) * CFrame.Angles(0, math.sin(t * 0.5) * 0.04 * (1 - rise), math.sin(t * 0.7) * 0.03 * (1 - rise))
		local unfold = K.k(t, 3.9, 5.3, E.inOutSine)
		local reachIn = K.k(t, 6.6, 7.8, E.inOutSine)
		local grabIn = K.k(t, absorbAt - 0.6, absorbAt, E.inOutSine)
		local rel = K.k(t, absorbAt + 0.9, absorbAt + 2, E.inOutSine)
		local breathe = math.sin(t * 1.2) * 2
		local function m3(a, b, c, d)
			return K.lerp(K.lerp(K.lerp(a, b, reachIn), c, grabIn), d, rel)
		end
		local idleRS = K.lerp(6, 12, unfold)
		local spread = K.lerp(4, 24, unfold)
		bossPose(ctx, {
			Neck = K.A(K.lerp(-34, -8 + breathe, unfold) + reachIn * 6 * (1 - rel), -reachIn * 10 * (1 - rel), 0),
			Waist = K.A(K.lerp(-20, 4 + breathe * 0.5, unfold) - reachIn * 8 * (1 - rel) + grabIn * 6 * (1 - rel), reachIn * 14 * (1 - rel), 0),
			RightShoulder = K.A(m3(idleRS, 80, 18, idleRS), 0, m3(spread, 8, -20, spread)),
			RightElbow = K.A(m3(K.lerp(14, 8, unfold), 4, 125, 8), 0, 0),
			LeftShoulder = K.A(idleRS, 0, -spread),
			LeftElbow = K.A(K.lerp(14, 22, unfold), 0, 0),
		})
		ctx.BossSmoke.Rate = rise < 1 and 30 or 6
		-- the void column pours up while he rises, then thins away
		local vp = K.k(t, 0.3, 1.2) * (1 - K.k(t, 5.2, 7.5))
		for _, p in ipairs(pillars) do
			p.B.Width0 = p.W * (0.3 + 0.7 * vp)
			p.B.Width1 = p.W * 1.3 * (0.3 + 0.7 * vp)
			p.B.Enabled = vp > 0.01
		end
		rim.Enabled = vp > 0.01
		rim.Brightness = 2.5 * vp

		----------------------------------------------------------------
		-- the stone: trembles, lifts, and is torn across the arena to his hand
		----------------------------------------------------------------
		local handPos = hand and hand.Position or (home.Position + Vector3.new(0, 150, 0))
		local lift = K.k(t, 7.0, 8.2, E.outCubic)
		local fly = K.k(t, 8.4, absorbAt - 0.5, E.inCubic)
		local shake = lift * (1 - fly) * 1.6
		local up = lp0 + Vector3.new(0, 26 * lift, 0) + Vector3.new(math.noise(t * 11, 1) * shake, math.noise(t * 11, 2) * shake, math.noise(t * 11, 3) * shake)
		local mid = (up + handPos) / 2 + Vector3.new(0, 70, 55)
		local gp = up:Lerp(mid, fly):Lerp(mid:Lerp(handPos, fly), fly)
		if t >= absorbAt - 0.5 then gp = handPos end
		local cposNow = chest and chest.Position or handPos
		if absorbed then
			-- pressed into his chest: a cold core
			gp = cposNow + home.LookVector * ((chest and chest.Size.Z or 90) * 0.5 + 22)
		end
		if gem then
			gem:PivotTo(CFrame.new(gp) * gemHome.Rotation * CFrame.Angles(0, t * (0.6 + fly * 9), 0))
		end
		local snuff = K.k(t, 0.8, 1.8)
		for _, d in ipairs(gemFx) do d.Enabled = snuff < 1 and math.random() > snuff end
		if ctx.LapisAuraHost then ctx.LapisAuraHost.CFrame = CFrame.new(gp) end
		faceQuads(ctx, ctx.LapisAura, gp)
		-- its halo: dims once he's up, flares as it's taken, gone once he has it
		local dim = K.k(t, 0.5, 1.8)
		local flare = lift * (1 - K.k(t, absorbAt - 0.3, absorbAt))
		local pulse = 0.5 + 0.5 * math.sin(t * 5)
		ctx.LapisAura[1].Transparency = K.ns(math.min(0.99, 0.55 + 0.25 * dim - 0.25 * flare - (absorbed and 0.1 * pulse or 0)))
		ctx.LapisAura[2].Transparency = K.ns(math.min(0.99, 0.35 + 0.4 * dim - 0.2 * flare + (absorbed and 0.2 or 0)))
		local qs = absorbed and (70 + pulse * 20) or (110 - dim * 50 + flare * 30)
		K.setQuadSize(ctx.LapisAura[1], qs, qs)
		K.setQuadSize(ctx.LapisAura[2], qs * 1.3, qs * 1.3)
		if absorbed then
			for _, q in ipairs(ctx.LapisAura) do q.Color = ColorSequence.new(Color3.fromRGB(150, 175, 255)) end
		end
		ctx.LapisSparkle.Rate = absorbed and 0 or (fly > 0 and 60 or lift * 25)
		ctx.LapisLight.Brightness = absorbed and 0 or (1 + flare * 4)
		-- the tether, flickering
		local teth = t >= 7.0 and not absorbed
		tether.Enabled = teth
		tether2.Enabled = teth
		if teth then
			tether.Attachment0.WorldPosition = handPos
			tether.Attachment1.WorldPosition = gp
			tether2.Attachment0.WorldPosition = handPos
			tether2.Attachment1.WorldPosition = gp
			tether.Width0 = 3 + math.noise(t * 20) * 2
			tether2.Width0 = 16 + math.sin(t * 13) * 5
		end
		-- the shrine's own light gutters out as the darkness rises
		local gutter = K.k(t, 0.8, 2.2)
		for _, d in ipairs(shrineParts) do
			d.Enabled = gutter < 1 and math.random() > gutter * 0.8
		end

		----------------------------------------------------------------
		-- the party: back away, bracing... then reaching after it
		----------------------------------------------------------------
		local grabbed = K.k(t, absorbAt, absorbAt + 0.3, E.outCubic)
		for slot, rig in pairs(ctx.rigs) do
			local wt = rest[slot]
			local back = K.k(t, 1.2 + slot * 0.05, 2.4, E.outCubic) * 3 + K.k(t, 7.2, 8.4, E.inOutSine) * -2.5 + grabbed * 1.5
			local p = Vector3.new(wt.X - back, ctx.TL.ArenaCenter.Y + 3, wt.Z)
			local look = Vector3.new(home.X, p.Y, home.Z):Lerp(Vector3.new(gp.X, p.Y, gp.Z), lift * (1 - fly * 0.5))
			rig:setCF(CFrame.lookAt(p, look))
			local pose = K.mixPose(K.Poses.Neutral, K.Poses.Brace, K.k(t, 1.2, 2.2))
			local want = K.k(t, 7.2 + (slot % 3) * 0.15, 8.2, E.inOutSine) * (1 - grabbed)
			pose = K.mixPose(pose, K.Poses.Reach, want * (slot == ctx.me and 1 or 0.7))
			pose.Neck = K.A(K.lerp(10, 38, rise) * (1 - lift) + lift * K.lerp(12, 30, fly), 0, 0)
			rig:setPose(pose)
			rig:apply()
		end

		----------------------------------------------------------------
		-- camera
		----------------------------------------------------------------
		local face = head and head.Position or (home.Position + Vector3.new(0, 190, 0))
		local cpos = chest and chest.Position or face - Vector3.new(0, 60, 0)
		local center = me and me:cf().Position or rest[1] or lp0
		if t < 5.0 then
			-- worm's-eye past the stone as the titan rises
			-- (off to the side, so the stone's glow isn't sat on top of him)
			local p = center + Vector3.new(-6, -1.2, 26)
			K.setCam(CFrame.lookAt(p, face:Lerp(lp0, 0.4 * (1 - rise))), 70)
		elseif t < 6.6 then
			-- his face, pushing in
			local e = K.k(t, 5.0, 6.6)
			local p = face + home.LookVector * K.lerp(190, 150, e) + Vector3.new(0, -16, 0)
			K.setCam(CFrame.lookAt(p, face), 42)
		elseif t < 8.4 then
			-- behind the party: his hand comes down over the arena for the stone
			local e = K.k(t, 6.6, 8.4, E.inOutSine)
			-- (low behind them, so they're black shapes against it, reaching)
			local p = center + Vector3.new(-20 + e * 4, 2.5, 22)
			K.setCam(CFrame.lookAt(p, center:Lerp(lp0:Lerp(handPos, 0.3), 0.75) + Vector3.new(0, 6, 0)), K.lerp(70, 64, e))
		elseif t < absorbAt - 0.5 then
			-- riding along with the stone as it's torn away
			local p = gp + Vector3.new(-40, 14, 60)
			K.setCam(CFrame.lookAt(p, gp:Lerp(handPos, 0.35)), 52)
		elseif t < absorbAt + 1.2 then
			-- his fist closing on it, and pressing it into his chest
			local e = K.k(t, absorbAt - 0.5, absorbAt + 1.2)
			local p = cpos + home.LookVector * K.lerp(470, 420, e) + home.RightVector * 140 + Vector3.new(0, -50, 0)
			K.setCam(CFrame.lookAt(p, cpos:Lerp(handPos, 0.4 * (1 - e))), 50)
		else
			-- down at the party from over his shoulder
			local e = K.k(t, absorbAt + 1.2, dur)
			local p = face + home.RightVector * 90 - home.LookVector * 40 + Vector3.new(0, 40, 0)
			K.setCam(CFrame.lookAt(p, center:Lerp(lp0, 0.3)), K.lerp(45, 38, e))
		end

		----------------------------------------------------------------
		-- beats
		----------------------------------------------------------------
		cue("rise", t >= 0.8, function()
			K.sfx(K.S.Hell, 1, 0.6)
			K.sfx(K.S.Rumble, 0.9)
			K.sfx(K.S.DarkDrone, 0.7)
			K.shake(2.5, 4.2, 10)
			ctx.setMusic(K.S.M_Doom, 0.7, 1.5)
		end)
		cue("eyes", t >= 4.6, function()
			K.sfx(K.S.TonalHit, 0.9)
			K.flash(0.4, Color3.fromRGB(200, 210, 255), 0.5)
			K.kick(-8, 0.6)
		end)
		cue("line1", t >= 5.1, function()
			K.say("SPIRAL APES.", 1.0, { Scale = 0.09 })
		end)
		cue("reach", t >= 6.8, function()
			K.sfx(K.S.Riser, 0.8, 0.8)
			K.sfx(K.S.Electric, 0.5, 0.6)
		end)
		cue("line2", t >= 7.3, function()
			K.say("YOU HAVE CRAWLED\nFAR ENOUGH.", 1.1, { Scale = 0.075 })
		end)
		cue("tear", t >= 8.4, function()
			K.sfx(K.S.Whoosh, 1, 0.5, { Reverb = 3 })
			K.sfx(K.S.Portal2, 0.6, 0.8)
			K.shake(1.5, 1.5)
		end)
		cue("line3", t >= 9.0, function()
			K.say("THIS LIGHT\nWAS NEVER YOURS.", 1.1, { Scale = 0.075 })
		end)
		cue("absorb", t >= absorbAt, function()
			absorbed = true
			steal.Stolen = true
			K.sfx(K.S.Boom, 1, 0.6, { Reverb = 3 })
			K.sfx(K.S.TonalHit, 1, 0.5)
			K.sfx(K.S.Thunder, 0.7)
			K.shake(3.5, 1.2)
			K.kick(-10, 0.8)
			K.flash(0.35, Color3.fromRGB(215, 225, 255), 0.8)
			local subjects = { ctx.Boss }
			task.spawn(K.impact, subjects, "WB", 0.05)
			-- the gold drains out of the world
			K.tween(K.Grade, 1.6, { TintColor = Color3.fromRGB(175, 185, 255), Saturation = -0.4, Brightness = -0.08, Contrast = 0.35 })
			ctx.fadeMusic(0.9, 0.3)
			-- a ring of his light ripples out from his chest
			local c = cpos
			local look = home.LookVector
			local t1 = os.clock()
			local conn
			conn = game:GetService("RunService").RenderStepped:Connect(function()
				local u = math.clamp((os.clock() - t1) / 1.4, 0, 1)
				local r0 = 20 + 700 * (1 - (1 - u) ^ 3)
				wave.update(CFrame.lookAt(c, c + look), r0, r0 + 40 + u * 160, u * 2)
				wave.setTransparency(math.min(0.99, 0.1 + u ^ 1.4 * 0.9))
				if u >= 1 or not ph.Parent then conn:Disconnect() end
			end)
		end)
		cue("line4", t >= absorbAt + 1.5, function()
			K.sfx(K.S.Thunder, 0.6)
			K.say("HERE, YOUR EVOLUTION ENDS.", 1.2, { Scale = 0.075 })
		end)
	end)
	tether.Enabled = false
	tether2.Enabled = false
	for _, d in ipairs(shrineParts) do d.Enabled = false end
	if gem and not steal.Stolen then gem:PivotTo(gemHome) end
	if steal.Stolen then
		setGemVisible(gem, false)
		for _, q in ipairs(ctx.LapisAura) do q.Transparency = K.ns(1) end
	end
end

-- the fight: the stone stays gone from the shrine, and he wears it in his chest
function Ch.onFight(ctx)
	local st = ctx.LapisSteal
	if not (st and st.Gem and st.Stolen) then return end
	st.Gem:PivotTo(st.Home)
	setGemVisible(st.Gem, false)
	local bf = workspace:FindFirstChild("BossFight")
	local real = bf and bf:FindFirstChild("Anti-Spiral")
	local torso = real and (real:FindFirstChild("UpperTorso") or real:FindFirstChild("Torso"))
	if not torso or real:FindFirstChild("StolenLapeace") then return end
	local core = st.Gem:Clone()
	core.Name = "StolenLapeace"
	for _, d in ipairs(core:GetDescendants()) do
		if d:IsA("WeldConstraint") or d:IsA("Weld") then d:Destroy() end
	end
	pcall(function() core:ScaleTo(2.2) end)
	core:PivotTo(torso.CFrame * CFrame.new(0, torso.Size.Y * 0.1, -torso.Size.Z * 0.5 - 2))
	for _, d in ipairs(core:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.LocalTransparencyModifier = 0
			local w = Instance.new("WeldConstraint")
			w.Part0 = d
			w.Part1 = torso
			w.Parent = d
		elseif d:IsA("ParticleEmitter") or d:IsA("Highlight") or d:IsA("Beam") or d:IsA("Light") then
			d.Enabled = true
		end
	end
	core.Parent = real
end

------------------------------------------------------------------------
-- PUNCH
------------------------------------------------------------------------
function Ch.Punch(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local set = ctx.sets.Arena
	set.Parent = ctx.stage
	local home = ctx.BossHome
	local AC = ctx.TL.ArenaCenter
	local me = ctx.myRig
	local cue = K.once()
	for _, rig in pairs(ctx.rigs) do
		if not rig.Bat then rig:giveBat() end
	end
	local IMPACT = 2.25
	local startPos = {}
	for slot, rig in pairs(ctx.rigs) do startPos[slot] = rig:cf().Position end

	K.run(t0, dur, function(t, dt)
		-- the swing
		local wind = K.k(t, 0.1, 1.6, E.inOutSine)
		local swing = K.k(t, 1.6, IMPACT, E.inCubic)
		local recover = K.k(t, IMPACT + 0.8, dur, E.inOutSine)
		local function L(a, b, c) return K.lerp(K.lerp(a, b, wind), c, swing) end
		bossPose(ctx, {
			Waist = K.A(L(0, 6, -10) * (1 - recover), L(0, -32, 20) * (1 - recover), 0),
			RightShoulder = K.A(L(8, -40, 46) * (1 - recover * 0.7), 0, L(6, 28, -16)),
			RightElbow = K.A(L(0, 95, 4) * (1 - recover), 0, 0),
			LeftShoulder = K.A(L(8, 30, -10), 0, -8),
			Neck = K.A(L(-8, 5, -22), L(0, 10, -5), 0),
			Root = K.A(L(0, 4, -10) * (1 - recover), 0, 0),
		})
		ctx.FistAura.Rate = (wind > 0.2 and t < IMPACT) and 22 or 0
		-- (the stone sits in the middle of the arena, so he's further off: he lunges in)
		local lunge = K.lerp(K.lerp(0, 30, wind), 150, swing) * (1 - recover)
		ctx.BossRoot.CFrame = home * CFrame.new(0, 0, -lunge) * CFrame.Angles(math.rad(-6) * swing * (1 - recover), 0, 0)

		-- the party: block... and get launched
		for slot, rig in pairs(ctx.rigs) do
			local sp = startPos[slot]
			local kp = knockPoint(ctx, slot)
			if t < IMPACT + 0.05 then
				local brace = K.k(t, 0.6 + slot * 0.04, 1.5, E.outBack)
				rig:setCF(CFrame.lookAt(sp, Vector3.new(home.X, sp.Y, home.Z)))
				local pose = K.mixPose(K.Poses.Brace, K.Poses.Block, brace)
				pose.RS = pose.RS * K.A(math.noise(t * 12, slot) * 4, 0, 0)
				rig:setPose(pose)
			else
				local tf = t - IMPACT
				local FLY = 1.5
				-- slow-mo for a beat, then fast
				local u = tf < 0.45 and (tf / 0.45) * 0.08 or K.lerp(0.08, 1, E.outCubic(math.min(1, (tf - 0.45) / FLY)))
				local p = sp:Lerp(Vector3.new(kp.X, sp.Y, kp.Z), u)
				local h = math.sin(math.min(u, 1) * math.pi) * 26
				local spin = u * math.pi * 3.2
				local cf
				if u < 1 then
					cf = CFrame.lookAt(p, Vector3.new(home.X, p.Y, home.Z)) * CFrame.new(0, h, 0) * CFrame.Angles(spin, 0, math.sin(u * 6 + slot) * 0.5)
					rig:setPose(K.flail(t, slot, 0.8, K.Poses.Blown))
				else
					-- crumpled on their backs
					local skid = K.k(tf - 0.45 - FLY, 0, 0.6, E.outCubic) * 5
					local q = Vector3.new(kp.X - skid, AC.Y + 0.6, kp.Z)
					cf = CFrame.lookAt(q, Vector3.new(home.X, q.Y, home.Z)) * CFrame.Angles(math.rad(88), 0, math.rad(8 * ((slot % 2) * 2 - 1)))
					rig:setPose(K.Poses.LyingBack)
				end
				rig:setCF(cf)
			end
			rig:apply()
		end
		local center = me and me:cf().Position or knockPoint(ctx, 1)

		-- camera
		if t < 1.6 then
			-- wide side: the titan winding up over the tiny party
			local e = K.k(t, 0, 1.6)
			local mid = (center + home.Position) / 2
			-- (high enough to hold his head as well as the party at his feet, and inside
			-- the ring of galaxies so none of them drift between us and him)
			local p = mid + Vector3.new(0, 80, 470 - e * 30)
			K.setCam(CFrame.lookAt(p, mid + Vector3.new(0, 105, 0)), 56)
		elseif t < IMPACT then
			-- your eyes: the fist filling the sky, bat up
			local head = me and me:head() and me:head().Position or center
			local fist = ctx.Boss:FindFirstChild("RightHand")
			local fp = fist and fist.Position or home.Position
			K.setCam(CFrame.lookAt(head + Vector3.new(-3.5, 1.5, 3.2), fp), K.lerp(60, 80, K.k(t, 1.6, IMPACT)))
		elseif t < IMPACT + 2.1 then
			-- side, following the blast back across the arena
			local p = center + Vector3.new(10, 8, 40)
			K.setCam(CFrame.lookAt(p, center), 60)
		else
			-- top-down on you, lying there
			local e = K.k(t, IMPACT + 2.1, dur)
			local p = center + Vector3.new(0.5, K.lerp(26, 16, e), 0.5)
			K.setCam(CFrame.lookAt(p, center) * CFrame.Angles(0, 0, e * 0.3), 50)
		end

		cue("windup", t >= 0.1, function()
			K.sfx(K.S.Whoosh, 0.9, 0.5)
			K.sfx(K.S.Riser, 0.7, 1.1)
			K.shake(1, 1.5)
		end)
		cue("swing", t >= 1.6, function()
			K.sfx(K.S.FireWhoosh, 1, 0.6)
			K.kick(10, 0.6)
		end)
		cue("impact", t >= IMPACT, function()
			local subjects = { ctx.Boss }
			for _, rig in pairs(ctx.rigs) do table.insert(subjects, rig.Model) end
			task.spawn(K.impact, subjects, "WBRWBW", 0.05, { Outline = true })
			K.sfx(K.S.Punch, 1)
			K.sfx(K.S.Punch2, 1, 0.8)
			K.sfx(K.S.MetalHit, 1)
			K.sfx(K.S.BigHit, 1)
			K.sfx(K.S.Cannon, 0.9, 0.7)
			K.shake(6, 2)
			K.kick(-25, 1.2)
			task.delay(0.33, function()
				K.flash(0.7)
				local c = center
				K.vfx("Shoot-01", CFrame.new(c) * CFrame.Angles(0, 0, math.rad(90)), set, 5, 5, 3)
				K.vfx("Big-Crack-01", CFrame.new(c.X, AC.Y + 0.6, c.Z), set, 1.5, 16, 3)
				K.vfx("Explosion", CFrame.new(c), set, 3, 20, 3)
				K.sfx(K.S.RockBoom, 1)
			end)
		end)
		cue("land", t >= IMPACT + 0.45 + 1.5, function()
			K.sfx(K.S.BodyFall, 1)
			K.sfx(K.S.Thump, 0.8)
			K.shake(1.5, 0.6)
			ctx.fadeMusic(0, 1.5)
		end)
		cue("drain", t >= IMPACT + 2.3, function()
			K.tween(K.Grade, 1.5, { Saturation = -1, Contrast = 0.1, Brightness = -0.05, TintColor = Color3.fromRGB(220, 225, 235) })
			K.muffle(1, 1.5)
			K.sfx(K.S.Ring, 0.25, 1, { Life = 12, Looped = false })
		end)
		K.stream(center)
	end)
	ctx.FistAura.Rate = 0
end

return Ch
