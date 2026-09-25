--==================================================
-- ATTACK 3: STOMP QUAKE (client)
-- He shifts his weight, raises one foot high over the galaxy
-- floor... and brings it down. The arena rim takes the blow and
-- walls of violet light roll out across it: jump them, or parry.
--==================================================
local RunService = game:GetService("RunService")

local A = {}

local UP = Vector3.yAxis
local SEGS = 56

local BALANCE = {
	Waist = { 8, 0, 0 }, RightShoulder = { 25, 0, 70 }, LeftShoulder = { 25, 0, -70 },
	RightElbow = { 25, 0, 0 }, LeftElbow = { 25, 0, 0 },
}
local SLAMMED = {
	Waist = { -22, 0, 0 }, RightShoulder = { 40, 0, 28 }, LeftShoulder = { 40, 0, -28 },
	RightElbow = { 10, 0, 0 }, LeftElbow = { 10, 0, 0 },
}

function A.start(ctx, d)
	local K, S, Fx, Warn, Rig = ctx.K, ctx.S, ctx.Fx, ctx.Warn, ctx.Rig
	local epoch = ctx.epoch()
	local side = d.Foot
	local plant = Rig.Feet[side].Plant
	-- (the foot comes down a little toward the arena)
	local toArena = S.flat(S.CENTER - plant).Unit
	local land = plant + toArena * 40
	local LIFT = 300
	local raiseEnd = d.StompT - 0.3
	Rig:act({
		Until = d.StompT + 1.2,
		Root = function(t)
			-- weight onto the other leg, a lean back as the foot rises, a drop on impact
			local shift = K.k(t, d.T0, d.T0 + 0.5) * (1 - K.k(t, d.StompT + 0.3, d.StompT + 1.1))
			local impact = K.k(t, d.StompT - 0.05, d.StompT + 0.1, K.E.outCubic) * (1 - K.k(t, d.StompT + 0.3, d.StompT + 1.1))
			local sx = (side == "Right" and -1 or 1) * 22 * shift
			return CFrame.new(sx, -10 * shift - 30 * impact, 0) * CFrame.Angles(math.rad(6 * shift - 10 * impact), 0, math.rad(-sx * 0.2))
		end,
		Foot = {
			[side] = function(t)
				local up = K.k(t, d.T0 + 0.2, raiseEnd, K.E.outCubic)
				local down = K.k(t, raiseEnd, d.StompT, K.E.inQuad)
				local pos = plant:Lerp(land, down) + UP * LIFT * up * (1 - down)
				return pos, -35 * up * (1 - down) + 10 * down * (1 - K.k(t, d.StompT, d.StompT + 0.2))
			end,
		},
		Upper = function(t)
			if t < d.StompT - 0.1 then
				Rig:pose(Rig.REST, BALANCE, K.k(t, d.T0, d.T0 + 0.6))
			else
				Rig:pose(SLAMMED, Rig.REST, K.k(t, d.StompT + 0.2, d.StompT + 1.1))
			end
			ctx.SK.hang(Rig.SB, "Right", 0.9, 0)
			ctx.SK.hang(Rig.SB, "Left", 0.9, 0)
			Rig.SB.lookAt(S.CENTER, 0.8, Rig.RootCF)
			return true
		end,
	})
	-- after the stomp the foot is planted where it landed
	task.delay(math.max(d.StompT - S.now(), 0) + 0.02, function()
		if ctx.epoch() == epoch then
			Rig.Feet[side].Plant = land
			Rig.Feet[side].LandT = S.now()
		end
	end)
	K.sfx(K.S.Rumble, 0.7, 0.8)
	Warn.callout("STOMP QUAKE")
	ctx.Fx.say("THE UNIVERSE TREMBLES\nAT MY STEP.", 1.2)
	-- the cut-in: over the rim, down at the foot as it comes up... and down
	ctx.Cam.cut(function(now)
		local toBoss = S.flat(d.Origin - S.CENTER).Unit
		local across = toBoss:Cross(Vector3.yAxis)
		local foot = Rig:footGround(d.Foot)
		local from = d.Origin - toBoss * 45 + across * 70 + Vector3.new(0, 30, 0)
		return CFrame.lookAt(from, foot:Lerp(ctx.chest(), 0.45)), 66
	end, d.T0 + 0.3, d.StompT + 0.35, 0.3)
	Warn.pop("JUMP THE SHOCKWAVES!", Color3.fromRGB(255, 200, 220), false, Vector2.new(0.5, 0.3))

	-- the rings: a wall of light (quads round the circle) + a glow on the floor
	local host = K.part({ Name = "QuakeHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(d.Origin) }, Fx.Folder)
	local rings = {}
	for _, r in ipairs(d.Rings) do
		local walls = {}
		for i = 1, SEGS do
			local q = K.quad(host, host.CFrame, 1, r.Shape.H, "10365550877", { Color = Fx.VIOLET_HOT, Brightness = 3.5, Transparency = K.ns(0, 0.05, 0.7, 0.3, 1, 1) })
			q.Enabled = false
			walls[i] = q
		end
		local floor = K.softRing(host, SEGS, 1, 2, { Brightness = 3, Alpha = 0 })
		for _, q in ipairs(floor.Q) do q.Color = ColorSequence.new(Fx.MAGENTA, Fx.VIOLET) end
		floor.setEnabled(false)
		table.insert(rings, { R = r, Walls = walls, Floor = floor })
		Warn.add({ Id = r.Id, Shape = r.Shape, Name = "SHOCKWAVE" })
	end
	local stomped = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = S.now()
		if ctx.epoch() ~= epoch then
			conn:Disconnect()
			host:Destroy()
			return
		end
		if not stomped and now >= d.StompT then
			stomped = true
			Fx.stomp(Rig:printAt(side, land, Rig.Feet[side].Yaw), 3)
			Fx.blast(d.Origin, 30, Fx.VIOLET, { Sound = K.S.Boom, Shake = 3, Volume = 1.3 })
			ctx.Fx.impact("WB", 0.05)
			ctx.Cam.punch(-12, 0.4)
			ctx.Fx.vfx("Big-Crack-01", d.Origin, 1.4, nil, 6)
			K.sfx(K.S.Thunder, 0.8, 0.7)
		end
		local any = false
		local o = Vector3.new(d.Origin.X, S.CENTER.Y, d.Origin.Z)
		for _, ring in ipairs(rings) do
			local sh = ring.R.Shape
			local r = S.ringRadius(sh, now)
			local on = now >= sh.T0 and r < 2 * S.ARENA_R + 20
			if on then any = true end
			local da = 2 * math.pi / SEGS
			for i, q in ipairs(ring.Walls) do
				local a0, a1 = (i - 1) * da, i * da
				local p0 = o + Vector3.new(math.cos(a0) * r, 0, math.sin(a0) * r)
				local p1 = o + Vector3.new(math.cos(a1) * r, 0, math.sin(a1) * r)
				local mid = (p0 + p1) / 2
				local show = on and S.onArena(mid, -2)
				q.Enabled = show
				if show then
					local along = (p1 - p0)
					local len = along.Magnitude
					local cf = CFrame.fromMatrix(mid + UP * sh.H / 2, along.Unit, UP)
					K.moveQuad(q, cf)
					K.setQuadSize(q, len * 1.02, sh.H)
				end
			end
			ring.Floor.setEnabled(on)
			if on then
				ring.Floor.update(CFrame.lookAt(o + UP * 0.3, o + UP * 2), math.max(r - sh.W, 0.1), r + 1, now)
				ring.Floor.setTransparency(0.2)
				-- (the floor glow would show beyond the rim too: fade it as it leaves)
				for i, q in ipairs(ring.Floor.Q) do
					local a = (i - 1) * da
					q.Enabled = S.onArena(o + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), -2)
				end
			end
		end
		if stomped and not any then
			conn:Disconnect()
			host:Destroy()
		end
	end)
end

return A
