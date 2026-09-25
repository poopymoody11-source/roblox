--==================================================
-- ATTACK 4: CONSTELLATION LANCES (client)
-- He points to the sky. Stars ignite over the arena and join
-- into constellations; each line burns red on the floor below,
-- and then comes down as a blade of starlight.
--==================================================
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local A = {}

local UP = Vector3.yAxis
local HIGH = 150

local POINT = {
	Waist = { 8, -10, 0 }, RightShoulder = { 172, 0, 16 }, RightElbow = { 4, 0, 0 },
	LeftShoulder = { 14, 0, -20 }, LeftElbow = { 20, 0, 0 },
}
local SWEEP = {
	Waist = { -18, 14, 0 }, RightShoulder = { 70, 0, 20 }, RightElbow = { 0, 0, 0 },
	LeftShoulder = { 20, 0, -30 }, LeftElbow = { 20, 0, 0 },
}

function A.start(ctx, d)
	local K, S, Fx, Warn, Rig, SK = ctx.K, ctx.S, ctx.Fx, ctx.Warn, ctx.Rig, ctx.SK
	local epoch = ctx.epoch()
	local host = K.part({ Name = "LanceHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(S.CENTER + UP * HIGH) }, Fx.Folder)
	local first = d.Lines[1].T
	local last = d.Lines[#d.Lines].T
	local items = {}
	for i, l in ipairs(d.Lines) do
		local shape = { Kind = "line", A = l.A, B = l.B, W = l.W }
		local sa, sb = l.A + UP * HIGH, l.B + UP * HIGH
		local appear = d.T0 + 0.1 + (i - 1) * 0.12
		local e = {
			L = l, Shape = shape, SA = sa, SB = sb, Appear = appear,
			StarA = SK.glow(K, host, sa, 30, Color3.fromRGB(255, 240, 255), 4),
			StarB = SK.glow(K, host, sb, 30, Color3.fromRGB(255, 240, 255), 4),
			Link = (K.ray(host, sa, sa, 1.2, 1.2, nil, { Color = Color3.fromRGB(230, 200, 255), Brightness = 3, Segments = 1 })),
			Zone = Fx.zone(shape, appear + 0.3, l.T),
		}
		e.Link.Enabled = false
		table.insert(items, e)
		Warn.add({ Id = l.Id, T = l.T, Shape = shape, Name = "LANCE", Target = l.Target, Rad = 20, Pos = function() return l.A:Lerp(l.B, 0.5) + UP * 3 end })
	end
	Rig:act({
		Until = last + 1,
		Upper = function(t)
			if t < first - 0.25 then
				Rig:pose(Rig.REST, POINT, K.k(t, d.T0, d.T0 + 0.6, K.E.outCubic))
			elseif t < last + 0.2 then
				Rig:pose(POINT, SWEEP, K.k(t, first - 0.25, first + 0.1, K.E.inQuad))
			else
				Rig:pose(SWEEP, Rig.REST, K.k(t, last + 0.2, last + 1))
			end
			SK.hang(Rig.SB, "Right", 0.2, 0.3)
			SK.hang(Rig.SB, "Left", 0.6, 0.1)
			Rig.SB.lookAt(S.CENTER + UP * HIGH, 0.8, Rig.RootCF)
			return true
		end,
	})
	Warn.callout("CONSTELLATION LANCES")
	K.sfx(K.S.Choir, 0.5, 1.1)
	K.sfx(K.S.Sting, 0.5, 1.2)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = S.now()
		if ctx.epoch() ~= epoch then
			conn:Disconnect()
			for _, e in ipairs(items) do e.Zone.destroy() end
			host:Destroy()
			return
		end
		local alive = false
		for i, e in ipairs(items) do
			local l = e.L
			-- the stars ignite, then the line draws between them
			local lit = K.k(now, e.Appear, e.Appear + 0.25, K.E.outBack)
			local tw = 0.85 + 0.15 * math.sin(now * 12 + i)
			local gone = K.k(now, l.T, l.T + 0.4)
			e.StarA.set(e.SA, 30 * lit * tw, lit * (1 - gone))
			e.StarB.set(e.SB, 30 * lit * tw, lit * (1 - gone))
			local draw = K.k(now, e.Appear + 0.2, e.Appear + 0.6)
			e.Link.Enabled = draw > 0 and gone < 1
			e.Link.Attachment0.WorldPosition = e.SA
			e.Link.Attachment1.WorldPosition = e.SA:Lerp(e.SB, draw)
			e.Link.Transparency = NumberSequence.new(0.1 + 0.9 * gone)
			if not e.Done then
				alive = true
				e.Zone.update(now)
				if now >= l.T then
					e.Done = true
					e.Zone.destroy()
					A.lance(ctx, e, Warn.claimed(l.Id))
				end
			elseif gone < 1 then
				alive = true
			end
		end
		if not alive then
			conn:Disconnect()
			host:Destroy()
		end
	end)
end

-- a blade of starlight down the line
function A.lance(ctx, e, parried)
	local K, Fx = ctx.K, ctx.Fx
	local l = e.L
	local a, b = l.A, l.B
	local mid = a:Lerp(b, 0.5)
	local dir = (b - a)
	local len = dir.Magnitude
	local blade = K.part({ Name = "Lance", Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, CFrame = CFrame.new(mid) }, Fx.Folder)
	local q = K.quad(blade, CFrame.fromMatrix(mid + UP * HIGH / 2, dir.Unit, UP), len, HIGH, "10365550877", {
		Color = parried and Fx.GREEN or Color3.fromRGB(245, 225, 255), Brightness = 6, Transparency = K.ns(0, 0, 0.8, 0.2, 1, 0.6),
	})
	local q2 = K.quad(blade, CFrame.fromMatrix(mid + UP * HIGH / 2, dir.Unit, UP) * CFrame.Angles(0, math.pi / 2, 0), l.W, HIGH, nil, {
		Color = Fx.VIOLET, Brightness = 3, Transparency = 0.3,
	})
	local t0 = os.clock()
	task.spawn(function()
		while blade.Parent do
			local u = (os.clock() - t0) / 0.45
			if u >= 1 then break end
			q.Transparency = NumberSequence.new(math.clamp(u ^ 0.7, 0, 1))
			q2.Transparency = NumberSequence.new(math.clamp(0.3 + u, 0, 1))
			q.Width0 = HIGH * (1 - 0.3 * u)
			q.Width1 = q.Width0
			task.wait()
		end
		blade:Destroy()
	end)
	if parried then
		Fx.parryBurst(mid + UP * 4, false)
	else
		for i = 0, 2 do
			Fx.blast(a:Lerp(b, 0.15 + i * 0.35), l.W * 0.9, Fx.VIOLET, { Column = false, Shake = 0.9, Volume = i == 1 and 1 or 0 })
		end
		Fx.sound(K.S.Lightning, mid, 1, 1.1, 900)
	end
	Debris:AddItem(blade, 1)
end

return A
