--==================================================
-- ATTACK 5: ANNIHILATION BEAM (client)
-- He leans over the rim and thrusts out a palm. Violet light
-- rushes into it while a red fan burns across the arena to show
-- where the beam will go... then it fires: a shaft of light from
-- his palm to the floor and a blade of it slicing across the
-- arena as he sweeps it round. Parry it or dash through.
--==================================================
local RunService = game:GetService("RunService")

local A = {}

local UP = Vector3.yAxis
local FAN_SEGS = 16

function A.start(ctx, d)
	local K, S, Fx, Warn, Rig, SK = ctx.K, ctx.S, ctx.Fx, ctx.Warn, ctx.Rig, ctx.SK
	local epoch = ctx.epoch()
	local first, last = d.Sweeps[1].Shape, d.Sweeps[#d.Sweeps].Shape
	local side = d.Hand
	local sgn = side == "Right" and 1 or -1
	local other = side == "Right" and "Left" or "Right"
	local o = Vector3.new(d.Origin.X, S.CENTER.Y, d.Origin.Z)
	Warn.callout("ANNIHILATION BEAM")

	-- the beam's floor angle at t (before it fires: where it will start)
	local function angleAt(t)
		for i, sw in ipairs(d.Sweeps) do
			local sh = sw.Shape
			if t <= sh.T1 or i == #d.Sweeps then
				if t < sh.T0 then
					-- (between sweeps it swings back to the next start)
					local prev = d.Sweeps[i - 1]
					if prev then return prev.Shape.A1 + (sh.A0 - prev.Shape.A1) * K.E.inOutSine(K.remap(t, prev.Shape.T1, sh.T0)) end
					return sh.A0
				end
				return S.sweepAngle(sh, t)
			end
		end
		return first.A0
	end
	local function firing(t)
		for _, sw in ipairs(d.Sweeps) do
			if t >= sw.Shape.T0 and t <= sw.Shape.T1 then return true end
		end
		return false
	end
	local L = first.L

	-- his pose: leaning over the rim, palm thrust out along the beam
	local palmPos = o + UP * 100
	Rig:act({
		Until = last.T1 + 0.9,
		Root = function(t)
			local lean = K.k(t, d.T0, d.FireT - 0.4) * (1 - K.k(t, last.T1 + 0.1, last.T1 + 0.9))
			local kick = firing(t) and 1 or 0
			return CFrame.new(0, -14 * lean, 0) * CFrame.Angles(math.rad(-8 * lean - 2 * kick), 0, 0)
		end,
		Upper = function(t, rootCF)
			local k = K.k(t, d.T0, d.FireT - 0.5, K.E.outCubic) * (1 - K.k(t, last.T1 + 0.1, last.T1 + 0.9))
			local a = angleAt(t)
			local aim = o + Vector3.new(math.cos(a), 0, math.sin(a)) * 140 + UP * 10
			-- (the torso turns to follow the beam)
			local local_ = rootCF:VectorToObjectSpace(S.flat(aim - rootCF.Position).Unit)
			local yaw = math.clamp(math.deg(math.atan2(-local_.X, -local_.Z)), -40, 40)
			Rig:pose(Rig.REST, { Waist = { -12, yaw * 0.8, 0 }, [other .. "Shoulder"] = { 55, 0, -30 * sgn }, [other .. "Elbow"] = { 70, 0, 0 } }, k)
			SK.hang(Rig.SB, other, 0.9, 0)
			local shoulder = (rootCF * CFrame.new(sgn * 95, 130, -10)).Position
			local rest = (rootCF * CFrame.new(sgn * 120, -60, 0)).Position
			local reachTo = shoulder + (aim - shoulder).Unit * 215
			palmPos = rest:Lerp(reachTo, k)
			local n = (aim - palmPos).Unit
			local f = (UP - n * UP:Dot(n))
			f = f.Magnitude > 0.05 and f.Unit or rootCF.LookVector
			Rig.SB.hand(side, palmPos, f, n, Vector3.new(0, -1, 0) + rootCF.RightVector * sgn * 0.5, rootCF)
			local charge = K.k(t, d.T0 + 0.3, d.FireT)
			Rig.SB.Hands[side].H.pose(0.15 - 0.15 * charge, 0.4 + 0.5 * charge, 0.1, charge * 1.5, t)
			Rig.SB.lookAt(aim, 0.9, rootCF)
			return true
		end,
	})

	-- visuals
	local host = K.part({ Name = "BeamHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(o) }, Fx.Folder)
	-- the red fan (where it will sweep)
	local fan = {}
	for i = 1, FAN_SEGS do
		local q = K.quad(host, host.CFrame, 1, 1, nil, { Color = Fx.RED, Brightness = 1.5, Transparency = 0.8 })
		fan[i] = q
	end
	local startLine = K.quad(host, host.CFrame, 1, 1.4, nil, { Color = Color3.fromRGB(255, 120, 120), Brightness = 3, Transparency = 0.1 })
	local function layFan(now)
		local u = K.k(now, d.T0, d.T0 + 0.5)
		local amin, amax = math.min(first.A0, first.A1), math.max(first.A0, first.A1)
		local pulse = 0.5 + 0.5 * math.sin(now * 14)
		for i, q in ipairs(fan) do
			local a0 = amin + (amax - amin) * (i - 1) / FAN_SEGS
			local a1 = amin + (amax - amin) * i / FAN_SEGS
			local am = (a0 + a1) / 2
			local dir = Vector3.new(math.cos(am), 0, math.sin(am))
			local len = L * u
			local mid = o + dir * len / 2 + UP * 0.15
			local w = 2 * math.tan((a1 - a0) / 2) * len * 1.02
			-- (a wedge: narrow at the rim, wide at the far side)
			K.moveQuad(q, CFrame.fromMatrix(mid, dir, dir:Cross(UP)))
			K.setQuadSize(q, len, 1)
			q.Width0, q.Width1 = 0.5, w
			q.Transparency = NumberSequence.new(0.86 - 0.1 * pulse)
			q.Enabled = u > 0
		end
		local a = first.A0
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		K.moveQuad(startLine, CFrame.fromMatrix(o + dir * L * u / 2 + UP * 0.25, dir, dir:Cross(UP)))
		K.setQuadSize(startLine, L * u, 1.6)
	end
	-- the charge at his palm
	local orb = SK.glow(K, host, o, 10, Fx.VIOLET, 3)
	local core = SK.glow(K, host, o, 10, Color3.fromRGB(255, 235, 255), 5)
	local inflow = Fx.emitAt(o, {
		Texture = "1851669703", Color = ColorSequence.new(Color3.new(1, 1, 1), Fx.VIOLET), Size = K.ns(0, 0, 0.3, 8, 1, 0),
		Lifetime = NumberRange.new(0.5, 0.6), Speed = NumberRange.new(-110, -90), SpreadAngle = Vector2.new(180, 180),
		Rate = 0, Brightness = 5, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		HostSize = Vector3.one * 110,
	}, 0, last.T1 - S.now() + 3)
	local inflowHost = inflow.Parent
	-- the beam: palm -> floor, and the blade across the arena
	local shaft = {}
	for i = 1, 3 do
		local b = K.ray(host, o, o, 10, 10, if i == 2 then nil else "10365550877", {
			Color = i == 1 and Fx.VIOLET or i == 2 and Color3.fromRGB(255, 240, 255) or Fx.MAGENTA,
			Brightness = i == 2 and 6 or 4, Segments = 2, Mode = Enum.TextureMode.Wrap, Length = 40, Speed = 12, Transparency = i == 2 and 0 or 0.1,
		})
		b.Enabled = false
		shaft[i] = b
	end
	local blade = K.quad(host, host.CFrame, 1, 18, "10365550877", { Color = Color3.fromRGB(250, 225, 255), Brightness = 5, Transparency = K.ns(0, 0, 0.7, 0.35, 1, 1) })
	local bladeCore = K.quad(host, host.CFrame, 1, 6, nil, { Color = Color3.new(1, 1, 1), Brightness = 6, Transparency = 0.05 })
	local floorBurn = K.quad(host, host.CFrame, 1, first.W, nil, { Color = Fx.MAGENTA, Brightness = 3, Transparency = 0.25 })
	blade.Enabled, bladeCore.Enabled, floorBurn.Enabled = false, false, false
	local sparks = Fx.emitAt(o, {
		Texture = "1851669703", Color = ColorSequence.new(Color3.new(1, 1, 1), Fx.VIOLET_HOT), Size = K.ns(0, 5, 1, 0),
		Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(40, 110), SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -120, 0), Rate = 0, Brightness = 5, EmissionDirection = Enum.NormalId.Top,
	}, 0, last.T1 - S.now() + 3)
	local sparkHost = sparks.Parent

	for _, sw in ipairs(d.Sweeps) do
		Warn.add({ Id = sw.Id, Shape = sw.Shape, Name = "ANNIHILATION BEAM" })
	end
	K.sfx(K.S.Riser, 0.8, 0.8)
	K.sfx(K.S.DarkDrone, 0.7, 1.2)
	local hum
	local fired = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = S.now()
		if ctx.epoch() ~= epoch or now > last.T1 + 1 then
			conn:Disconnect()
			host:Destroy()
			if inflowHost then inflowHost:Destroy() end
			if sparkHost then sparkHost:Destroy() end
			if hum then K.fadeSound(hum, 0, 0.3, true) end
			return
		end
		-- the fan fades as the beam passes over it
		if now < last.T1 then layFan(now) else for _, q in ipairs(fan) do q.Enabled = false end startLine.Enabled = false end
		-- the orb
		local charge = K.k(now, d.T0 + 0.2, d.FireT)
		local on = firing(now)
		local sz = 12 + 60 * charge + (on and 10 * math.sin(now * 40) or 0)
		local after = now > last.T1 and (1 - K.k(now, last.T1, last.T1 + 0.4)) or 1
		orb.set(palmPos, sz * 1.8, (0.3 + 0.5 * charge) * after)
		core.set(palmPos, sz * 0.5, charge * after)
		inflowHost.CFrame = CFrame.new(palmPos)
		inflow.Rate = (now < d.FireT) and 120 * charge or 0
		if not fired and now >= d.FireT then
			fired = true
			hum = K.loop(K.S.BeamFire, 0.8, 0.05, 0.8)
			K.sfx(K.S.Cannon, 1, 0.6)
			K.flash(0.3, Fx.VIOLET_HOT, 0.35)
		end
		-- the beam
		local a = angleAt(now)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local near = o + dir * 18
		local far = o + dir * L
		for i, b in ipairs(shaft) do
			b.Enabled = on
			if on then
				b.Attachment0.WorldPosition = palmPos
				b.Attachment1.WorldPosition = near + UP * 2
				local w = (i == 1 and 26 or i == 2 and 9 or 18) * (1 + 0.08 * math.sin(now * 50 + i))
				b.Width0, b.Width1 = w * 0.8, w * 1.3
			end
		end
		blade.Enabled, bladeCore.Enabled, floorBurn.Enabled = on, on, on
		if on then
			local mid = near:Lerp(far, 0.5)
			local right = dir:Cross(UP)
			K.moveQuad(blade, CFrame.fromMatrix(mid + UP * 9, dir, UP))
			K.setQuadSize(blade, (far - near).Magnitude, 18 + 3 * math.sin(now * 37))
			K.moveQuad(bladeCore, CFrame.fromMatrix(mid + UP * 3, dir, UP))
			K.setQuadSize(bladeCore, (far - near).Magnitude, 6)
			K.moveQuad(floorBurn, CFrame.fromMatrix(mid + UP * 0.2, dir, right))
			K.setQuadSize(floorBurn, (far - near).Magnitude, first.W)
			sparkHost.CFrame = CFrame.new(near)
			sparks.Rate = 160
			ctx.Cam.shake(0.6, 0.1)
		else
			sparks.Rate = 0
		end
		if hum and now > last.T1 then
			K.fadeSound(hum, 0, 0.3, true)
			hum = nil
		end
	end)
end

return A
