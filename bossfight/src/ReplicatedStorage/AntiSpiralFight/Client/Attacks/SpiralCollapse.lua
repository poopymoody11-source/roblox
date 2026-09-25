--==================================================
-- ATTACK 6: SPIRAL COLLAPSE (client)
-- He raises both hands and CLAPS: a black hole tears open over
-- the arena. Its accretion disk spins up, rubble and starlight
-- spiral into it, and it drags everyone toward the middle while
-- the red zone under it fills. Then it collapses - get out, or
-- stand in the middle of it and parry the blast.
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local A = {}

local UP = Vector3.yAxis
local HOLE_H = 55

local RAISE = {
	Waist = { 14, 0, 0 }, RightShoulder = { 172, 0, 22 }, LeftShoulder = { 172, 0, -22 },
	RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 },
}
local CLAP = {
	Waist = { 8, 0, 0 }, RightShoulder = { 165, 0, -4 }, LeftShoulder = { 165, 0, 4 },
	RightElbow = { 22, 0, 0 }, LeftElbow = { 22, 0, 0 },
}
local HOLD = {
	Waist = { -16, 0, 0 }, RightShoulder = { 92, 0, 38 }, LeftShoulder = { 92, 0, -38 },
	RightElbow = { 12, 0, 0 }, LeftElbow = { 12, 0, 0 },
}
local BURST = {
	Waist = { 12, 0, 0 }, RightShoulder = { 70, 0, 75 }, LeftShoulder = { 70, 0, -75 },
	RightElbow = { 5, 0, 0 }, LeftElbow = { 5, 0, 0 },
}

local function rock(K, Fx, size)
	local folder = ReplicatedStorage:FindFirstChild("FinalCutscene")
	folder = folder and folder:FindFirstChild("Assets") and folder.Assets:FindFirstChild("Rocks")
	local pick = folder and folder:FindFirstChild(({ "Rock1", "Rock3", "Rock4", "Rock5" })[math.random(1, 4)])
	local r
	if pick and pick:IsA("BasePart") then
		r = pick:Clone()
		for _, c in ipairs(r:GetChildren()) do if not c:IsA("SurfaceAppearance") then c:Destroy() end end
		r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch = true, false, false, false
		r.Size = r.Size / math.max(r.Size.X, r.Size.Y, r.Size.Z) * size
	else
		r = K.part({ Size = Vector3.one * size, Material = Enum.Material.Slate, Color = Color3.fromRGB(60, 50, 80) }, nil)
	end
	r.Name = "Debris"
	r.Parent = Fx.Folder
	return r
end

function A.start(ctx, d)
	local K, S, Fx, Warn, Rig, SK = ctx.K, ctx.S, ctx.Fx, ctx.Warn, ctx.Rig, ctx.SK
	local epoch = ctx.epoch()
	local player = Players.LocalPlayer
	local c = d.Centre
	local hole = c + UP * HOLE_H
	local clapT = d.OpenT - 0.15
	Warn.callout("SPIRAL COLLAPSE")
	ctx.Fx.say("ALL SPIRALS END\nIN THE VOID.", 1.2)
	-- the cut-in: the hole tearing open over the arena
	ctx.Cam.cut(function(now)
		local u = K.remap(now, d.OpenT - 0.2, d.OpenT + 1.4)
		local toBoss = S.flat(ctx.chest() - c).Unit
		local from = c - toBoss * (150 - 30 * u) + UP * (20 + 15 * u)
		return CFrame.lookAt(from, hole:Lerp(ctx.chest(), 0.2)), 72 - 8 * u
	end, d.OpenT - 0.25, d.OpenT + 1.5, 0.3)

	Rig:act({
		Until = d.BlastT + 1.2,
		Root = function(t)
			local rear = K.k(t, d.T0, clapT) * (1 - K.k(t, clapT, clapT + 0.3))
			local strain = K.k(t, d.OpenT, d.OpenT + 0.5) * (1 - K.k(t, d.BlastT, d.BlastT + 0.8))
			return CFrame.new(0, -10 * strain + 8 * rear, 0) * CFrame.Angles(math.rad(5 * rear - 6 * strain), 0, math.sin(t * 20) * 0.004 * strain)
		end,
		Upper = function(t)
			local curl, spread, tremble = 0.2, 0.6, 0
			if t < clapT - 0.2 then
				Rig:pose(Rig.REST, RAISE, K.k(t, d.T0, clapT - 0.2, K.E.outCubic))
			elseif t < clapT then
				Rig:pose(RAISE, CLAP, K.k(t, clapT - 0.2, clapT, K.E.inQuad))
				spread = 0
			elseif t < d.BlastT then
				Rig:pose(CLAP, HOLD, K.k(t, clapT + 0.1, d.OpenT + 0.6, K.E.outCubic))
				curl, spread, tremble = 0.45, 0.9, 1.5 * K.k(t, d.OpenT, d.BlastT)
			else
				Rig:pose(BURST, Rig.REST, K.k(t, d.BlastT + 0.3, d.BlastT + 1.2))
				curl, spread = 1, 0
			end
			for _, side in ipairs({ "Right", "Left" }) do
				SK.hang(Rig.SB, side, curl, spread)
				Rig.SB.Hands[side].H.pose(curl, spread, curl, tremble, t)
			end
			Rig.SB.lookAt(hole, 0.9, Rig.RootCF)
			return true
		end,
	})

	-- the hole
	local host = K.part({ Name = "HoleHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(hole) }, Fx.Folder)
	local ball = K.part({ Name = "Singularity", Shape = Enum.PartType.Ball, Size = Vector3.one, Material = Enum.Material.SmoothPlastic, Color = Color3.new(0, 0, 0), CFrame = CFrame.new(hole) }, Fx.Folder)
	local lens = K.part({ Name = "Lens", Shape = Enum.PartType.Ball, Size = Vector3.one, Material = Enum.Material.ForceField, Color = Fx.VIOLET, Transparency = 0.2, CFrame = CFrame.new(hole) }, Fx.Folder)
	local disk = K.softRing(host, 48, 1, 2, { Brightness = 4, Alpha = 0, Profile = { 0, 0, 0.15, 1, 0.5, 0.7, 1, 0 } })
	for _, q in ipairs(disk.Q) do q.Color = ColorSequence.new(Color3.fromRGB(255, 230, 255), Fx.MAGENTA) end
	local disk2 = K.softRing(host, 48, 1, 2, { Brightness = 2.5, Alpha = 0 })
	for _, q in ipairs(disk2.Q) do q.Color = ColorSequence.new(Fx.VIOLET, Fx.VIOLET_DEEP) end
	local swirl = K.quad(host, host.CFrame, 1, 1, "14426232568", { Color = Fx.MAGENTA, Brightness = 2.5, Transparency = 0.2 })
	local halo = SK.glow(K, host, hole, 10, Fx.VIOLET, 2.5)
	-- starlight and dust pouring in from all round
	local inflow = K.emitter(K.part({ Name = "InflowHost", Shape = Enum.PartType.Ball, Size = Vector3.one * 260, Transparency = 1, CFrame = CFrame.new(hole) }, host), {
		Texture = "1851669703", Color = ColorSequence.new(Color3.new(1, 1, 1), Fx.VIOLET_HOT), Size = K.ns(0, 2, 0.8, 5, 1, 0),
		Lifetime = NumberRange.new(1.1, 1.3), Speed = NumberRange.new(-120, -100), Rate = 0, Brightness = 5,
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	local dust = K.emitter(inflow.Parent, {
		Texture = "10180479311", Color = ColorSequence.new(Fx.VIOLET, Fx.VIOLET_DEEP), Size = K.ns(0, 30, 1, 4),
		Transparency = K.ns(0, 1, 0.3, 0.6, 1, 1), Lifetime = NumberRange.new(1.2, 1.4), Speed = NumberRange.new(-100, -80),
		Rate = 0, LightEmission = 0.5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	-- rubble torn off the arena, spiralling in
	local rocks = {}
	for i = 1, 16 do
		local r = rock(K, Fx, math.random(3, 9))
		r.Transparency = 1
		local a = i / 16 * math.pi * 2
		table.insert(rocks, { P = r, A = a, R = math.random(90, 190), H = math.random(-40, 10), Spin = Vector3.new(math.random(), math.random(), math.random()), Delay = math.random() * 1.2 })
	end
	local zone = Fx.zone({ Kind = "circle", P = c, R = d.R }, d.T0, d.BlastT)
	Warn.add({ Id = d.Id, T = d.BlastT, Shape = { Kind = "circle", P = c, R = d.R }, Name = "SPIRAL COLLAPSE", Target = "all", Rad = d.R, Pos = function() return hole end })

	local clapped, blasted = false, false
	local roar
	K.sfx(K.S.Riser, 0.7, 0.7)
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local now = S.now()
		if ctx.epoch() ~= epoch or now > d.BlastT + 2 then
			conn:Disconnect()
			zone.destroy()
			host:Destroy()
			ball:Destroy()
			lens:Destroy()
			for _, r in ipairs(rocks) do r.P:Destroy() end
			if roar then K.fadeSound(roar, 0, 0.3, true) end
			return
		end
		if not clapped and now >= clapT then
			clapped = true
			K.sfx(K.S.Punch2, 1, 0.5)
			K.sfx(K.S.Thunder, 0.9, 0.6)
			K.flash(0.25, Color3.new(1, 1, 1), 0.5)
			ctx.Cam.shake(2.2, 0.6)
			ctx.Fx.impact("WB", 0.05)
			ctx.Cam.punch(-12, 0.4)
			Fx.vfx("Tornado-01", c + UP * 5, 4, nil, 6)
			Fx.vfx("Portal-Enter-01", hole, 8, nil, 3)
			roar = K.loop(K.S.Rush, 0.7, 0.8, 0.6)
		end
		zone.update(now)
		-- the hole grows open, spins up, and pulses faster as it nears collapse
		local open = K.k(now, d.OpenT - 0.1, d.OpenT + 0.8, K.E.outBack)
		local collapse = K.k(now, d.BlastT - 0.25, d.BlastT, K.E.inQuad)
		local gone = K.k(now, d.BlastT, d.BlastT + 0.3)
		local u = K.remap(now, d.OpenT, d.BlastT)
		local size = (22 + 6 * math.sin(now * (6 + 20 * u))) * open * (1 - collapse * 0.9) * (1 - gone)
		ball.Size = Vector3.one * math.max(size, 0.05)
		lens.Size = Vector3.one * math.max(size * 1.9, 0.05)
		lens.Transparency = 0.2 + 0.8 * gone
		local tilt = CFrame.lookAt(hole, hole + Vector3.new(0.25, 1, 0.1).Unit)
		local spin = now * (2 + 10 * u)
		disk.update(tilt, size * 0.9, size * 3.2, spin)
		disk.setTransparency(math.clamp(1 - open + gone, 0, 0.99))
		disk2.update(tilt, size * 1.6, size * 5, -spin * 0.6)
		disk2.setTransparency(math.clamp(1 - 0.7 * open + gone, 0, 0.99))
		K.moveQuad(swirl, tilt * CFrame.Angles(0, 0, spin * 1.4))
		K.setQuadSize(swirl, math.max(size * 7, 0.1), math.max(size * 7, 0.1))
		swirl.Transparency = NumberSequence.new(math.clamp(1 - 0.8 * open + gone, 0, 1))
		halo.set(hole, size * 9, 0.4 * open * (1 - gone))
		local pulling = now >= d.OpenT and now < d.BlastT
		inflow.Rate = pulling and 90 or 0
		dust.Rate = pulling and 25 or 0
		-- rubble
		for _, r in ipairs(rocks) do
			local v = K.remap(now, d.OpenT + r.Delay, d.BlastT)
			if v > 0 and v < 1 then
				local rr = r.R * (1 - v) ^ 1.5
				local a = r.A + v * 8 + now * 0.5
				local p = hole + Vector3.new(math.cos(a) * rr, r.H * (1 - v), math.sin(a) * rr)
				r.P.Transparency = 0
				r.P.CFrame = CFrame.new(p) * CFrame.Angles(r.Spin.X * now * 4, r.Spin.Y * now * 4, r.Spin.Z * now * 4)
			else
				r.P.Transparency = 1
			end
		end
		-- the pull (on my own character: it's mine to move)
		if pulling then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and S.onArena(root.Position, -10) and (player:GetAttribute("IFrameUntil") or 0) < now then
				local to = S.flat(c - root.Position)
				if to.Magnitude > 4 then
					local ramp = K.k(now, d.OpenT, d.OpenT + 0.8) * (0.7 + 0.5 * u)
					root.CFrame += to.Unit * d.Strength * ramp * dt
				end
			end
			ctx.Cam.shake(0.25 + 0.5 * u, 0.1)
		end
		-- the collapse
		if not blasted and now >= d.BlastT then
			blasted = true
			if roar then K.fadeSound(roar, 0, 0.2, true) roar = nil end
			if ctx.Qte.claimed(d.Id) then
				Fx.parryBurst(hole, true)
				K.flash(0.4, Fx.GREEN, 0.5)
			else
				local flash = K.part({ Name = "Collapse", Shape = Enum.PartType.Ball, Size = Vector3.one * 10, Material = Enum.Material.Neon, Color = Color3.fromRGB(245, 225, 255), CFrame = CFrame.new(hole) }, Fx.Folder)
				K.tween(flash, 0.5, { Size = Vector3.one * d.R * 2.6, Transparency = 1 })
				Debris:AddItem(flash, 0.55)
				ctx.Fx.impact("BWBW", 0.045)
				ctx.Cam.punch(-18, 0.6)
				Fx.blast(c, d.R, Fx.VIOLET, { Sound = K.S.Boom, Shake = 3.5, Volume = 1.4 })
				Fx.sound(K.S.Hell, c, 0.8, 0.8, 3000)
				K.flash(0.5, Fx.VIOLET_HOT, 0.6)
			end
		end
	end)
end

return A
