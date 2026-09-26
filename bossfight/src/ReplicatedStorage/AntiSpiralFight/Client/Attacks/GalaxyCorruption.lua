--==================================================
-- SET PIECE: GALAXY CORRUPTION (client)
-- He reaches up and takes the sky: every galaxy in the realm
-- turns to his violet (the cutscene's green whirlpools, in his
-- colours), a river of his power pouring into each. Then they
-- open fire - a storm of star-bolts and lances raining down on
-- the arena, faster and faster - and finish by all converging
-- on each of you at once.
--==================================================
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local A = {}

local UP = Vector3.yAxis
local SKY = 1500 -- (the galaxies are tens of thousands of studs out: shots come from this far along their line)

local REACH = {
	Waist = { 16, 0, 0 }, RightShoulder = { 160, 0, 40 }, LeftShoulder = { 160, 0, -40 },
	RightElbow = { 8, 0, 0 }, LeftElbow = { 8, 0, 0 },
}
local CONDUCT_R = {
	Waist = { 6, -10, 0 }, RightShoulder = { 120, 0, 20 }, LeftShoulder = { 150, 0, -45 },
	RightElbow = { 0, 0, 0 }, LeftElbow = { 20, 0, 0 },
}
local CONDUCT_L = {
	Waist = { 6, 10, 0 }, RightShoulder = { 150, 0, 45 }, LeftShoulder = { 120, 0, -20 },
	RightElbow = { 20, 0, 0 }, LeftElbow = { 0, 0, 0 },
}

-- where each galaxy is (the realm's hero galaxies), or evenly round the sky if they
-- haven't streamed in
local function galaxies(S, n)
	local list = {}
	local bf = workspace:FindFirstChild("BossFight")
	local realm = bf and bf:FindFirstChild("GalaxyRealm")
	local gm = realm and realm:FindFirstChild("Galaxies")
	for i = 1, n do
		local part = gm and gm:FindFirstChild("Hero" .. i)
		local pos
		if part and part:IsA("BasePart") then
			pos = part.Position
		else
			local a = (i - 1) / n * math.pi * 2
			pos = S.CENTER + Vector3.new(math.cos(a) * 20000, 6000 + (i % 3) * 3000, math.sin(a) * 20000)
		end
		local dir = (pos - S.CENTER).Unit
		if dir.Y < 0.25 then dir = (dir + Vector3.new(0, 0.5, 0)).Unit end
		list[i] = { Real = pos, Sky = S.CENTER + dir * SKY, Dir = dir }
	end
	return list
end

function A.start(ctx, d)
	local K, S, Fx, Warn, Rig, SK = ctx.K, ctx.S, ctx.Fx, ctx.Warn, ctx.Rig, ctx.SK
	local epoch = ctx.epoch()
	local G = galaxies(S, d.Galaxies)
	ctx.Corruption = { G = G, Pulse = {} }
	Warn.callout("GALAXY CORRUPTION")
	ctx.Cam.follow(d.EndT + 3)
	Fx.say("EVERY GALAXY IN THIS REALM\nBELONGS TO ME.", 1.5, true)
	task.delay(math.max(d.StormT - S.now() - 0.2, 0), function()
		if ctx.epoch() == epoch then Fx.say("FALL, SPIRAL APES.", 1.1, true) end
	end)
	-- his pose: reaching up to take the sky... then conducting the storm
	Rig:act({
		Until = d.EndT + 3.5,
		Root = function(t)
			local rise = K.k(t, d.T0, d.StormT - 0.8) * (1 - K.k(t, d.EndT + 2.5, d.EndT + 3.5))
			return CFrame.new(0, 30 * rise, 0) * CFrame.Angles(math.rad(8 * rise), 0, 0)
		end,
		Upper = function(t)
			local up = K.k(t, d.T0, d.T0 + 0.9, K.E.outCubic) * (1 - K.k(t, d.EndT + 2.5, d.EndT + 3.5))
			if t < d.StormT then
				Rig:pose(Rig.REST, REACH, up)
			else
				local beat = math.floor((t - d.StormT) / 0.5) % 2 == 0
				local w = 0.5 + 0.5 * math.sin((t - d.StormT) * math.pi * 2)
				Rig:pose(REACH, beat and CONDUCT_R or CONDUCT_L, w * up)
			end
			SK.hang(Rig.SB, "Right", 0.15, 0.8)
			SK.hang(Rig.SB, "Left", 0.15, 0.8)
			Rig.SB.lookAt(Rig.RootCF.Position + Vector3.new(0, 2000, 0) + Rig.RootCF.LookVector * 800, 0.9 * up, Rig.RootCF)
			return true
		end,
	})
	-- the cut-in: high over the arena, the whole sky turning
	ctx.Cam.cut(function(now)
		local u = K.remap(now, d.T0 + 0.4, d.StormT - 0.4)
		local toBoss = S.flat(ctx.chest() - S.CENTER).Unit
		local from = S.CENTER - toBoss * (260 + 60 * u) + UP * (90 + 50 * u)
		return CFrame.lookAt(from, ctx.chest() + UP * (300 + 400 * u)), 80
	end, d.T0 + 0.3, d.StormT - 0.3, 0.35)
	Fx.hold(Fx.VIOLET, 0.45, 2.5)
	K.sfx(K.S.DarkDrone, 0.9, 0.7)
	K.sfx(K.S.Choir, 0.6, 0.6)
	-- each galaxy: a violet whirlpool at the galaxy itself, one in the sky over the
	-- arena along its line, and a river of his power running into it
	local host = K.part({ Name = "CorruptHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(S.CENTER) }, Fx.Folder)
	for i, g in ipairs(G) do
		g.Far = Fx.galaxy(host)
		g.Near = Fx.galaxy(host)
		g.River = K.ray(host, S.CENTER, S.CENTER + UP, 30, 60, "10365550877", { Color = Fx.VIOLET, Brightness = 4, Segments = 10, Mode = Enum.TextureMode.Wrap, Length = 400, Speed = -6, Transparency = 0.2 })
		g.River.Enabled = false
		g.At = d.T0 + 0.6 + (i - 1) * 0.28
		g.Flare = 0
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = S.now()
		if ctx.epoch() ~= epoch or now > d.EndT + 4 then
			conn:Disconnect()
			host:Destroy()
			Fx.hold(nil, 0, 1.2)
			ctx.Corruption = nil
			return
		end
		local hand = ctx.handPos and ctx.handPos("Right") or ctx.chest()
		for i, g in ipairs(G) do
			local on = K.k(now, g.At, g.At + 0.35, K.E.outBack) * (1 - K.k(now, d.EndT + 2.2, d.EndT + 3.6))
			local fl = math.max(0, 1 - (os.clock() - (ctx.Corruption.Pulse[i] or 0)) / 0.35)
			g.Far.set(g.Real, S.CENTER, (g.Real - S.CENTER).Magnitude * 0.18, on, now + i)
			g.Near.set(g.Sky, S.CENTER, 170 * (1 + 0.3 * fl), on * (0.85 + 0.15 * fl), now * 1.3 + i)
			-- the river: from his hand up into it, while it turns
			local rv = K.k(now, g.At - 0.3, g.At + 0.2) * (1 - K.k(now, d.StormT - 0.2, d.StormT + 0.6))
			g.River.Enabled = rv > 0.01
			if g.River.Enabled then
				g.River.Attachment0.WorldPosition = hand
				g.River.Attachment1.WorldPosition = g.Sky
				g.River.Transparency = NumberSequence.new(1 - 0.85 * rv)
			end
		end
	end)
	-- as each one turns: a flare and a crack of thunder
	for i, g in ipairs(G) do
		task.delay(math.max(g.At - S.now(), 0), function()
			if ctx.epoch() ~= epoch then return end
			Fx.vfx("Lighting-03", g.Sky, 10, nil, 2)
			K.sfx(K.S.Electric, 0.5, 0.8 + i * 0.05)
			K.sfx(K.S.TonalHit, 0.35, 0.7 + i * 0.05)
		end)
	end
	task.delay(math.max(d.StormT - S.now(), 0), function()
		if ctx.epoch() ~= epoch then return end
		Fx.impact("VBV", 0.05)
		ctx.Cam.punch(-14, 0.5)
		K.sfx(K.S.Thunder, 1, 0.6)
	end)
end

local function fromOf(ctx, i)
	local C = ctx.Corruption
	if not C then return ctx.S.CENTER + Vector3.new(0, 1400, 0) end
	local g = C.G[((i - 1) % #C.G) + 1]
	C.Pulse[((i - 1) % #C.G) + 1] = os.clock()
	return g.Sky
end

-- a star-bolt: streaks down from a galaxy onto a red zone
function A.bolt(ctx, d)
	local K, S, Fx, Warn = ctx.K, ctx.S, ctx.Fx, ctx.Warn
	local epoch = ctx.epoch()
	local from = fromOf(ctx, d.From)
	local shape = { Kind = "circle", P = d.To, R = d.R }
	local zone = Fx.zone(shape, d.T0, d.T)
	local star = K.part({ Name = "CorruptStar", Shape = Enum.PartType.Ball, Size = Vector3.one * 7, Material = Enum.Material.Neon, Color = Color3.fromRGB(245, 215, 255), CFrame = CFrame.new(from) }, Fx.Folder)
	local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, 3, 0) a0.Parent = star
	local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -3, 0) a1.Parent = star
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.35
	tr.LightEmission = 1
	tr.Brightness = 5
	tr.FaceCamera = true
	tr.Color = ColorSequence.new(Color3.new(1, 1, 1), Fx.VIOLET)
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	tr.Parent = star
	local function at(now)
		local u = K.remap(now, d.T0 + 0.35, d.T)
		return from:Lerp(d.To + UP * 3, K.E.inQuad(u))
	end
	Warn.add({ Id = d.Id, T = d.T, Shape = shape, Name = "CORRUPTED STAR", Rad = 8, Pos = at })
	ctx.Qte.track(d.Id, at)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = S.now()
		if ctx.epoch() ~= epoch then conn:Disconnect() zone.destroy() star:Destroy() return end
		zone.update(now)
		star.CFrame = CFrame.new(at(now))
		if now >= d.T then
			conn:Disconnect()
			zone.destroy()
			if ctx.Qte.claimed(d.Id) then
				Fx.parryBurst(d.To + UP * 3, false)
			else
				Fx.blast(d.To, d.R * 1.3, Fx.VIOLET, { Shake = 0.7, Volume = 0.7, Pack = false })
				Fx.vfx("Lighting-01", d.To + UP * 6, 2, nil, 2)
			end
			star:Destroy()
		end
	end)
	Debris:AddItem(star, d.T - S.now() + 2)
end

-- a lance: a sheet of light from a galaxy down onto a line
function A.lance(ctx, d)
	local K, S, Fx, Warn = ctx.K, ctx.S, ctx.Fx, ctx.Warn
	local epoch = ctx.epoch()
	local from = fromOf(ctx, d.From)
	local shape = { Kind = "line", A = d.A, B = d.B, W = d.W }
	local zone = Fx.zone(shape, d.T0, d.T)
	Warn.add({ Id = d.Id, T = d.T, Shape = shape, Name = "GALACTIC LANCE", Rad = 20, Pos = function() return d.A:Lerp(d.B, 0.5) + UP * 3 end })
	local host = K.part({ Name = "LanceHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(d.A) }, Fx.Folder)
	local rays = {}
	for i = 0, 4 do
		local b = K.ray(host, from, d.A:Lerp(d.B, i / 4), 0.6, 0.6, nil, { Color = Fx.RED, Brightness = 2, Segments = 1, Transparency = 0.5 })
		rays[i] = b
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = S.now()
		if ctx.epoch() ~= epoch then conn:Disconnect() zone.destroy() host:Destroy() return end
		zone.update(now)
		local u = K.remap(now, d.T0, d.T)
		for _, b in pairs(rays) do
			b.Width0, b.Width1 = 0.4 + 2 * u, 0.4 + 2 * u
			b.Color = ColorSequence.new(Fx.RED:Lerp(Color3.new(1, 1, 1), u * u))
		end
		if now >= d.T then
			conn:Disconnect()
			zone.destroy()
			local parried = ctx.Qte.claimed(d.Id)
			for _, b in pairs(rays) do
				b.Width0, b.Width1 = 14, 8
				b.Color = ColorSequence.new(parried and Fx.GREEN or Color3.fromRGB(245, 225, 255))
				b.Brightness = 6
				b.Transparency = NumberSequence.new(0)
				K.tween(b, 0.4, { Width0 = 0, Width1 = 0 })
			end
			if not parried then
				for i = 0, 2 do Fx.blast(d.A:Lerp(d.B, 0.2 + i * 0.3), d.W, Fx.VIOLET, { Column = false, Shake = 0.8, Volume = i == 1 and 1 or 0, Pack = false }) end
				Fx.sound(K.S.Lightning, d.A:Lerp(d.B, 0.5), 1, 1.1, 900)
			else
				Fx.parryBurst(d.A:Lerp(d.B, 0.5) + UP * 3, false)
			end
			Debris:AddItem(host, 0.5)
		end
	end)
end

-- the finale: every galaxy converging on you
function A.finale(ctx, d)
	local K, S, Fx, Warn = ctx.K, ctx.S, ctx.Fx, ctx.Warn
	local epoch = ctx.epoch()
	local C = ctx.Corruption
	local shape = { Kind = "circle", P = d.P, R = d.R }
	local zone = Fx.zone(shape, d.T0, d.T)
	Warn.add({ Id = d.Id, T = d.T, Shape = shape, Name = "EVERY GALAXY", Target = d.User, Rad = d.R, Pos = function() return d.P + UP * 4 end })
	if d.User == ctx.player.UserId then Warn.callout("EVERY GALAXY - MOVE!") end
	local host = K.part({ Name = "FinaleHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(d.P) }, Fx.Folder)
	local rays = {}
	for i, g in ipairs(C and C.G or {}) do
		local b = K.ray(host, g.Sky, d.P, 0.5, 0.5, "10365550877", { Color = Fx.RED, Brightness = 3, Segments = 1, Mode = Enum.TextureMode.Wrap, Length = 60, Speed = -8, Transparency = 0.4 })
		rays[i] = b
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = S.now()
		if ctx.epoch() ~= epoch then conn:Disconnect() zone.destroy() host:Destroy() return end
		zone.update(now)
		local u = K.remap(now, d.T0, d.T)
		for _, b in ipairs(rays) do
			b.Width0, b.Width1 = 0.5 + 6 * u * u, 0.5 + 3 * u * u
			b.Color = ColorSequence.new(Fx.RED:Lerp(Fx.VIOLET_HOT, u))
		end
		if now >= d.T then
			conn:Disconnect()
			zone.destroy()
			local parried = ctx.Qte.claimed(d.Id)
			for _, b in ipairs(rays) do
				b.Width0, b.Width1 = 30, 18
				b.Color = ColorSequence.new(parried and Fx.GREEN or Color3.new(1, 1, 1))
				b.Brightness = 7
				b.Transparency = NumberSequence.new(0)
				K.tween(b, 0.6, { Width0 = 0, Width1 = 0 })
			end
			if d.User == ctx.player.UserId then
				Fx.impact(parried and "GWG" or "RBR", 0.05)
				ctx.Cam.punch(-16, 0.5)
			end
			if parried then
				Fx.parryBurst(d.P + UP * 4, true)
			else
				Fx.blast(d.P, d.R * 2, Fx.VIOLET, { Shake = 2.5, Volume = 1.3 })
			end
			Debris:AddItem(host, 0.7)
		end
	end)
end

return A
