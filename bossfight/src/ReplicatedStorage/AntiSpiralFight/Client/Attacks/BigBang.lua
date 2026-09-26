--==================================================
-- ULTIMATE: BIG BANG (client)
-- He rises out of the galaxy floor, the sky goes dark, and every
-- star in the realm pours into a universe cupped between his
-- hands... then he hurls it at the arena.
-- Land all five QTE steps and the cutscene takes over: you,
-- in full spiral power, launch at it, a drill spinning up on
-- your arm, punch it green and drive it back into his chest -
-- GIGA DRILL BREAK. Miss one and it lands.
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local A = {}

local UP = Vector3.yAxis
local RISE = 220

local THROW = {
	Waist = { -30, 0, 0 }, RightShoulder = { 70, 0, 12 }, LeftShoulder = { 70, 0, -12 },
	RightElbow = { 0, 0, 0 }, LeftElbow = { 0, 0, 0 },
}

function A.start(ctx, d)
	local K, S, Fx, Warn, Rig, SK = ctx.K, ctx.S, ctx.Fx, ctx.Warn, ctx.Rig, ctx.SK
	local epoch = ctx.epoch()
	local B = { Green = false, Gone = false, Frozen = nil }
	ctx.BigBang = B
	Warn.callout("!! BIG BANG !!")
	ctx.Cam.follow(d.ThrowT - 0.8)
	Fx.say("I WILL SHOW YOU\nTHE BIRTH OF A UNIVERSE...", 2, true)
	task.delay(math.max(d.ThrowT - S.now() - 0.4, 0), function()
		if ctx.epoch() == epoch then Fx.say("...AND ITS DEATH.", 1.1, true) end
	end)
	K.letterbox(true, 0.8)
	Fx.hold(Fx.VIOLET, 0.6, 1.5)
	K.sfx(K.S.Riser, 1, 0.5)
	K.sfx(K.S.Choir, 0.8, 0.7)
	local rumble = K.loop(K.S.Rumble, 0.8, 1)

	-- the universe's size / where it is
	local function size(now)
		if now < d.ThrowT then return 10 + 80 * K.E.inQuad(K.remap(now, d.T0 + 0.6, d.ThrowT)) end
		return 90 + 70 * K.remap(now, d.ThrowT, d.T)
	end
	local function held()
		local head = ctx.part("Head")
		local h = head and head.Position or ctx.chest()
		return h + UP * 150 + S.flat(S.CENTER - h).Unit * 30
	end
	local throwFrom
	local function orbAt(now)
		if B.Frozen then return B.Frozen(now) end
		if now < d.ThrowT then return held() end
		throwFrom = throwFrom or held()
		local target = S.CENTER + UP * 40
		local u = K.E.inQuad(K.remap(now, d.ThrowT, d.T))
		local mid = throwFrom:Lerp(target, 0.5) + UP * 120
		return throwFrom:Lerp(mid, u):Lerp(mid:Lerp(target, u), u)
	end
	B.OrbAt = orbAt
	B.Size = size

	-- him: up out of the floor, the universe cupped overhead, then hurled
	Rig:act({
		Until = d.T + 5,
		Root = function(t)
			local rise = K.k(t, d.T0, d.T0 + 2.4, K.E.outCubic) * (1 - K.k(t, d.T + 1.5, d.T + 4.5))
			local lurch = K.k(t, d.ThrowT - 0.3, d.ThrowT + 0.2) * (1 - K.k(t, d.ThrowT + 0.6, d.T + 1))
			return CFrame.new(0, RISE * rise, 0) * CFrame.Angles(math.rad(6 * rise - 18 * lurch), 0, 0)
		end,
		Upper = function(t, rootCF)
			if t < d.ThrowT - 0.25 then
				local k = K.k(t, d.T0, d.T0 + 1.2, K.E.outCubic)
				local orb = orbAt(t)
				local s = size(t)
				Rig:pose(Rig.REST, { Waist = { 12, 0, 0 } }, k)
				for _, side in ipairs({ "Right", "Left" }) do
					local sgn = side == "Right" and 1 or -1
					local rest = (rootCF * CFrame.new(sgn * 130, 60, -20)).Position
					local palm = rest:Lerp(orb + rootCF.RightVector * sgn * (s * 0.55 + 10), k)
					local n = (orb - palm).Unit
					local f = (UP - n * UP:Dot(n))
					Rig.SB.hand(side, palm, f.Magnitude > 0.05 and f.Unit or rootCF.LookVector, n, Vector3.new(0, -1, 0) + rootCF.RightVector * sgn, rootCF)
					Rig.SB.Hands[side].H.pose(0.35, 0.6, 0.3, 1.2 * k, t)
				end
				Rig.SB.lookAt(orb, 0.9, rootCF)
			else
				Rig:pose({ Waist = { 12, 0, 0 }, RightShoulder = { 175, 0, 20 }, LeftShoulder = { 175, 0, -20 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 } },
					THROW, K.k(t, d.ThrowT - 0.25, d.ThrowT + 0.15, K.E.inQuad) * (1 - K.k(t, d.T + 1.5, d.T + 4.5)))
				SK.hang(Rig.SB, "Right", 0.1, 0.6)
				SK.hang(Rig.SB, "Left", 0.1, 0.6)
				Rig.SB.lookAt(S.CENTER, 0.8, rootCF)
			end
			return true
		end,
	})

	-- cut-ins: the rise, from low on the arena, turning; then the universe, close
	ctx.Cam.cut(function(now)
		local u = K.remap(now, d.T0, d.T0 + 2.6)
		local chest = ctx.chest()
		local toBoss = S.flat(chest - S.CENTER).Unit
		local a = 0.5 - u * 0.5
		local dir = CFrame.Angles(0, a, 0):VectorToWorldSpace(toBoss)
		local from = S.CENTER + dir * (S.ARENA_R - 30) - dir * 60 + UP * (4 + 10 * u)
		return CFrame.lookAt(from, chest + UP * (60 + 160 * u)), 75
	end, d.T0 + 0.15, d.T0 + 2.6, 0.35)
	ctx.Cam.cut(function(now)
		local orb = orbAt(now)
		local s = size(now)
		local head = ctx.part("Head")
		local toArena = S.flat(S.CENTER - orb).Unit
		local side = toArena:Cross(UP)
		local from = orb + toArena * (s * 2.4 + 60) + side * (s * 0.9) - UP * 30
		return CFrame.lookAt(from, orb:Lerp(head and head.Position or orb, 0.35)), 62
	end, d.ThrowT - 2.0, d.ThrowT - 0.7, 0.3)
	-- as it falls: high over you, looking down - the red zone and the green way out, in plain view
	ctx.Cam.cut(function(now)
		local c = ctx.player.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local me = r and r.Position or S.CENTER
		local out = S.flat(me - S.CENTER)
		out = out.Magnitude > 1 and out.Unit or Vector3.xAxis
		local from = me + out * 45 + UP * 125
		return CFrame.lookAt(from, me:Lerp(S.CENTER, 0.25)), 70
	end, d.ThrowT - 0.6, d.T + 0.5, 0.35)

	-- the universe
	local host = K.part({ Name = "BigBangHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(S.CENTER) }, Fx.Folder)
	local core = K.part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one, Material = Enum.Material.Neon, Color = Color3.fromRGB(250, 235, 255) }, Fx.Folder)
	local shell = K.part({ Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.one, Material = Enum.Material.ForceField, Color = Fx.VIOLET, Transparency = 0.05 }, Fx.Folder)
	local galaxy = Fx.galaxy(host)
	local galaxy2 = Fx.galaxy(host)
	local rings = {}
	for i = 1, 2 do
		local r = K.softRing(host, 40, 1, 2, { Brightness = 4, Alpha = 0 })
		for _, q in ipairs(r.Q) do q.Color = ColorSequence.new(Color3.new(1, 1, 1), i == 1 and Fx.MAGENTA or Fx.VIOLET) end
		rings[i] = r
	end
	local inflowHost = K.part({ Name = "Inflow", Shape = Enum.PartType.Ball, Size = Vector3.one * 500, Transparency = 1, CFrame = CFrame.new(S.CENTER) }, host)
	local inflow = K.emitter(inflowHost, {
		Texture = "1851669703", Color = ColorSequence.new(Color3.new(1, 1, 1), Fx.VIOLET_HOT), Size = K.ns(0, 4, 0.8, 9, 1, 0),
		Lifetime = NumberRange.new(1.4, 1.6), Speed = NumberRange.new(-200, -170), Rate = 0, Brightness = 5,
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	-- rivers of starlight from the sky into it
	local rivers = {}
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local sky = S.CENTER + Vector3.new(math.cos(a) * 1300, 900 + (i % 3) * 300, math.sin(a) * 1300)
		local b = K.ray(host, sky, sky, 20, 40, "10365550877", { Color = i % 2 == 0 and Fx.MAGENTA or Fx.VIOLET, Brightness = 4, Segments = 12, Mode = Enum.TextureMode.Wrap, Length = 300, Speed = -8 })
		b.CurveSize0, b.CurveSize1 = (i % 2 == 0 and 200 or -200), 0
		b.Enabled = false
		rivers[i] = { B = b, Sky = sky }
	end
	local R = d.R or 160
	local zone = Fx.zone({ Kind = "circle", P = S.CENTER, R = R }, d.ThrowT - 1, d.T)
	Warn.add({ Id = d.Id, T = d.T, Shape = { Kind = "circle", P = S.CENTER, R = R }, Name = "BIG BANG", Target = "all", Rad = 90, Pos = function(now) return orbAt(now) end })
	-- the way out: the outer ring of the arena glows green
	local safeHost = K.part({ Name = "SafeHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(S.CENTER) }, host)
	local safe = K.softRing(safeHost, 64, R + 4, S.ARENA_R, { Brightness = 2, Alpha = 0, Profile = { 0, 0, 0.1, 0.6, 0.5, 0.25, 0.9, 0.6, 1, 0 } })
	for _, q in ipairs(safe.Q) do q.Color = ColorSequence.new(Fx.GREEN, Fx.LIME) end
	safe.update(CFrame.lookAt(S.CENTER + UP * 0.3, S.CENTER + UP * 2), R + 4, S.ARENA_R, 0)
	safe.setTransparency(0.99)
	task.delay(math.max(d.ThrowT - 1 - S.now(), 0), function()
		if ctx.epoch() ~= epoch then return end
		safe.setTransparency(0.35)
		Warn.callout("GET TO THE EDGE!")
	end)
	local lastBolt = 0
	local done = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = S.now()
		if ctx.epoch() ~= epoch or now > d.T + 6 then
			conn:Disconnect()
			host:Destroy()
			core:Destroy()
			shell:Destroy()
			zone.destroy()
			if rumble then K.fadeSound(rumble, 0, 0.5, true) end
			K.letterbox(false, 0.6)
			Fx.hold(nil, 0, 1.2)
			return
		end
		local orb = orbAt(now)
		local s = size(now)
		local alive = (not done or B.Frozen ~= nil) and not B.Gone
		local vis = alive and 1 or 0
		local cam = workspace.CurrentCamera.CFrame.Position
		core.Size = Vector3.one * s * 0.35 * vis + Vector3.one * 0.05
		core.CFrame = CFrame.new(orb)
		shell.Size = Vector3.one * s * 0.95 * vis + Vector3.one * 0.05
		shell.CFrame = CFrame.new(orb)
		local green = B.Green
		core.Color = green and Color3.fromRGB(220, 255, 220) or Color3.fromRGB(250, 235, 255)
		shell.Color = green and Fx.GREEN or Fx.VIOLET
		galaxy.set(orb, cam, s * 2.3, vis, now * 1.2)
		galaxy2.set(orb, orb + (orb - cam):Cross(UP), s * 1.6, vis * 0.8, -now * 1.7)
		for i, r in ipairs(rings) do
			local tilt = CFrame.lookAt(orb, orb + Vector3.new(math.sin(now * 0.7 + i), 1.5, math.cos(now * 0.9 + i * 2)).Unit)
			r.update(tilt, s * (0.7 + i * 0.25), s * (0.8 + i * 0.35), now * (2 + i))
			r.setTransparency(alive and 0.1 or 0.99)
		end
		inflowHost.CFrame = CFrame.new(orb)
		inflow.Rate = (now < d.ThrowT and alive) and 160 or 0
		local rv = K.k(now, d.T0 + 0.8, d.T0 + 1.6) * (1 - K.k(now, d.ThrowT - 0.3, d.ThrowT))
		for _, r in ipairs(rivers) do
			r.B.Enabled = rv > 0.01
			if r.B.Enabled then
				r.B.Attachment0.WorldPosition = r.Sky
				r.B.Attachment1.WorldPosition = orb
				r.B.Transparency = NumberSequence.new(1 - 0.8 * rv)
			end
		end
		if now < d.ThrowT and os.clock() - lastBolt > 0.35 then
			lastBolt = os.clock()
			Fx.vfx("Lighting-03", orb + Vector3.new(math.random(-1, 1), math.random(-1, 1), math.random(-1, 1)) * s * 0.6, s / 8, nil, 2)
		end
		zone.update(now)
		ctx.Cam.shake(0.3 + 0.6 * K.remap(now, d.T0, d.T), 0.1)
		-- impact
		if not done and now >= d.T then
			done = true
			zone.destroy()
			if rumble then K.fadeSound(rumble, 0, 0.3, true) rumble = nil end
			if ctx.Qte.claimed(d.Id) then
				A.counter(ctx, d, orb, s)
			else
				K.flash(1, Color3.new(1, 1, 1), 1)
				Fx.impact("WBWBWB", 0.05)
				ctx.Cam.punch(-24, 0.8)
				Fx.blast(S.CENTER, R * 0.8, Fx.VIOLET, { Shake = 5, Volume = 1.6, Sound = K.S.Boom })
				Fx.blast(S.CENTER, R * 1.2, Fx.MAGENTA, { Column = false, Shake = 0, Volume = 0, Pack = false })
				Fx.vfx("Explosion-01", S.CENTER + UP * 20, 12, 40, 6)
				Fx.vfx("Big-Crack-01", S.CENTER, 5, nil, 8)
				K.sfx(K.S.Hell, 1, 0.6)
				K.letterbox(false, 1)
				task.delay(0.5, function() Fx.hold(nil, 0, 1.5) end)
			end
		end
	end)
end

--------------------------------------------------------------------------
-- THE COUNTER: GIGA DRILL BREAK (a cinematic, on your screen)
--------------------------------------------------------------------------
local function drillFor(K, rig)
	local src = ReplicatedStorage:FindFirstChild("FinalCutscene")
	src = src and src:FindFirstChild("Assets") and src.Assets:FindFirstChild("DrillCone")
	local arm = rig:part("Right Arm")
	if not (src and arm) then return nil end
	local d = src:Clone()
	for _, c in ipairs(d:GetChildren()) do c:Destroy() end
	d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, false, true
	d.Material = Enum.Material.Neon
	d.Color = Color3.fromRGB(190, 255, 90)
	d.Size = Vector3.new(0.1, 0.2, 0.1)
	local w = Instance.new("Weld")
	w.Part0, w.Part1 = arm, d
	w.Parent = d
	d.Parent = rig.Model
	return d, w
end

function A.counter(ctx, d, orb0, s0)
	local K, S, Fx, SK = ctx.K, ctx.S, ctx.Fx, ctx.SK
	local player = Players.LocalPlayer
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local B = ctx.BigBang
	local start = CFrame.lookAt(root.Position, Vector3.new(orb0.X, root.Position.Y, orb0.Z))
	-- (your real body steps out of frame while the cutscene you plays)
	local hidden = {}
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") or p:IsA("Decal") then
			hidden[p] = p.LocalTransparencyModifier
			p.LocalTransparencyModifier = 1
		end
	end
	local rig = K.rig(player.UserId, Fx.Folder)
	rig:setCF(start * CFrame.new(0, 0, 0))
	SK.powerUp(K, rig)
	local drill, dw = drillFor(K, rig)
	ctx.Cam.clearCuts()
	K.startCamera()
	K.muffle(0.5, 0.1)
	local c0 = os.clock()
	local HIT1, HIT2, END = 1.15, 2.25, 3.35
	local dirUp = (orb0 - start.Position).Unit
	local lines = Instance.new("ImageLabel")
	lines.BackgroundTransparency = 1
	lines.Image = K.SpeedLines
	lines.AnchorPoint = Vector2.new(0.5, 0.5)
	lines.Position = UDim2.fromScale(0.5, 0.5)
	lines.Size = UDim2.fromScale(1.6, 1.6)
	lines.SizeConstraint = Enum.SizeConstraint.RelativeXX
	lines.ImageColor3 = Color3.fromRGB(200, 255, 210)
	lines.ImageTransparency = 1
	lines.ZIndex = 30
	lines.Parent = ctx.Warn.Gui
	-- the universe follows the cutscene now
	local orbPos = orb0
	B.Frozen = function() return orbPos end
	Fx.impact("GWG", 0.05, { rig.Model })
	K.sfx(K.S.GreenAura, 1, 1)
	K.sfx(K.S.Heartbeat, 1, 1.3)
	local stage = 0
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - c0
		SK.powerLevel(rig, t, 1)
		if rig.SP then
			rig.SP.Aura.Rate = 45
			rig.SP.Sparks.Rate = 60
		end
		if drill then
			local grow = K.k(t, 0.45, 1.0, K.E.outBack)
			drill.Size = Vector3.new(1.7, 3.6, 1.7) * math.max(grow, 0.03)
			dw.C0 = CFrame.new(0, -1 - drill.Size.Y * 0.5, 0) * CFrame.Angles(math.pi, t * 30, 0)
		end
		local chest = ctx.chest()
		if t < 0.5 then
			-- crouched, power blazing
			rig:setCF(start)
			rig:setPose(K.Poses.Crouch)
			rig:apply()
			local head = rig:head()
			local hp = head and head.Position or start.Position
			K.setCam(CFrame.lookAt(start * Vector3.new(2.5, 0.2, -6.5), hp + UP * 0.4), 55)
		elseif t < HIT1 then
			-- the launch
			if stage < 1 then
				stage = 1
				K.sfx(K.S.Whoosh, 1, 0.7)
				K.sfx(K.S.Overdrive, 0.8, 1.2)
				K.shake(1.5, 0.6)
			end
			local u = K.E.inQuad(K.remap(t, 0.5, HIT1))
			local p = start.Position:Lerp(orbPos - dirUp * (s0 * 0.55 + 4), u)
			local cf = CFrame.lookAt(p, orbPos)
			rig:setCF(cf)
			rig:setPose({ Root = K.A(-10, 0, 0), RS = K.A(90, 0, 0), LS = K.A(-40, 0, -30), RH = K.A(-20, 0, 6), LH = K.A(30, 0, -6), Neck = K.A(10, 0, 0) })
			rig:apply()
			lines.ImageTransparency = 0.25
			lines.Rotation = math.random(0, 360)
			K.setCam(CFrame.lookAt(p - cf.LookVector * 16 + UP * 3 + cf.RightVector * 4, orbPos), 80)
		elseif t < HIT2 then
			-- punched green, and driven back into him
			if stage < 2 then
				stage = 2
				B.Green = true
				Fx.impact("WBW", 0.05, { rig.Model })
				K.sfx(K.S.Punch2, 1, 0.8)
				K.sfx(K.S.Boom, 1, 0.9)
				K.shake(3, 0.8)
				K.flash(0.3, Fx.GREEN, 0.6)
				Fx.vfx("Shield-Break-01", orbPos, 10, nil, 3)
				task.spawn(SK.rainbowShout, K, "GIGA DRILL BREAK!!", { Scale = 0.12 })
			end
			local u = K.E.inOutQuad(K.remap(t, HIT1, HIT2))
			local from = orb0
			orbPos = from:Lerp(chest, u)
			local dir = (chest - from).Unit
			local p = orbPos - dir * (s0 * 0.5 + 5)
			rig:setCF(CFrame.lookAt(p, orbPos))
			rig:setPose({ Root = K.A(-15, 0, 0), RS = K.A(90, 0, 0), LS = K.A(-30, 0, -40), RH = K.A(-35, 0, 8), LH = K.A(20, 0, -8), Neck = K.A(15, 0, 0) })
			rig:apply()
			lines.Rotation = math.random(0, 360)
			local side = dir:Cross(UP).Unit
			local mid = orbPos:Lerp(chest, 0.3)
			K.setCam(CFrame.lookAt(mid + side * (140 + 60 * u) + UP * 40, orbPos:Lerp(chest, 0.4)), 60)
		elseif t < END then
			-- it breaks on his chest
			if stage < 3 then
				stage = 3
				lines.ImageTransparency = 1
				Fx.impact("GRGWG", 0.05, { rig.Model })
				K.sfx(K.S.BigHit, 1, 0.8)
				K.sfx(K.S.Boom, 1, 0.7)
				K.sfx(K.S.Hell, 0.6, 1.1)
				K.shake(4, 1.2)
				K.flash(0.5, Color3.fromRGB(200, 255, 210), 0.8)
				B.Gone = true
				if ctx.bossRecoil then ctx.bossRecoil() end
				local burstHost = K.part({ Name = "BreakHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(chest) }, Fx.Folder)
				local g = Fx.galaxy(burstHost, { Fx.GREEN, Fx.LIME, Color3.fromRGB(220, 255, 220) })
				local tb = os.clock()
				local c2
				c2 = RunService.RenderStepped:Connect(function()
					local e = os.clock() - tb
					g.set(chest, workspace.CurrentCamera.CFrame.Position, 380 * (0.6 + 0.4 * math.min(e / 0.3, 1)), K.E.outCubic(math.min(e / 0.25, 1)) * (1 - K.k(e, 0.8, 1.6)), e * 3)
					if e > 1.6 then c2:Disconnect() burstHost:Destroy() end
				end)
				Fx.vfx("Explosion-01", chest, 14, 40, 5)
				Fx.bolt(chest + UP * 40, chest, true)
			end
			local u = K.remap(t, HIT2, END)
			-- you fall away, arms thrown wide
			local p = chest:Lerp(start.Position + UP * 30, K.E.outQuad(u)) + UP * math.sin(math.pi * u) * 60
			rig:setCF(CFrame.lookAt(p, chest) * CFrame.Angles(-u * 4, 0, 0))
			rig:setPose(K.Poses.Blown)
			rig:apply()
			local toBoss = S.flat(chest - S.CENTER).Unit
			K.setCam(CFrame.lookAt(S.CENTER - toBoss * 60 + UP * (30 + 20 * u), chest), 70)
		else
			conn:Disconnect()
			K.fade(1, 0.12)
			task.delay(0.14, function()
				rig:destroy()
				lines:Destroy()
				for p, v in pairs(hidden) do
					if p.Parent then p.LocalTransparencyModifier = v end
				end
				K.stopCamera()
				K.muffle(0, 0.3)
				K.letterbox(false, 0.5)
				Fx.hold(nil, 0, 1)
				K.fade(0, 0.35)
			end)
		end
	end)
end

return A
