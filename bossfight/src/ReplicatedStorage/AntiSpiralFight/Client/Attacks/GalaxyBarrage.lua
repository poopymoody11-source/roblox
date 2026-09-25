--==================================================
-- ATTACK 1: GALAXY BARRAGE (client)
-- He throws his arms up and violet galaxies tear open over the
-- arena; planets, moons and stars pour out of their hearts. Each
-- one gets a red zone where it will land and (if it's yours) the
-- lock-on. Parry one and it's batted straight back into him.
--==================================================
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local A = {}
local Warn

local RAISED = {
	Waist = { 10, 0, 0 }, RightShoulder = { 165, 0, 28 }, LeftShoulder = { 165, 0, -28 },
	RightElbow = { 12, 0, 0 }, LeftElbow = { 12, 0, 0 },
}
local PUSH_R = {
	Waist = { 4, -8, 0 }, RightShoulder = { 120, 0, 20 }, LeftShoulder = { 160, 0, -30 },
	RightElbow = { 0, 0, 0 }, LeftElbow = { 18, 0, 0 },
}
local PUSH_L = {
	Waist = { 4, 8, 0 }, RightShoulder = { 160, 0, 30 }, LeftShoulder = { 120, 0, -20 },
	RightElbow = { 18, 0, 0 }, LeftElbow = { 0, 0, 0 },
}

-- the barrage: the galaxies and his pose (shots arrive separately)
function A.start(ctx, d)
	local K, S, Fx, Rig = ctx.K, ctx.S, ctx.Fx, ctx.Rig
	local epoch = ctx.epoch()
	local host = K.part({ Name = "BarrageHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(S.CENTER) }, Fx.Folder)
	local gals = {}
	for i, p in ipairs(d.Portals) do gals[i] = { G = Fx.galaxy(host), P = p } end
	ctx.Barrage = { Id = d.Id, Pulse = 0, Gals = gals }
	Warn = ctx.Warn
	Warn.callout("GALAXY BARRAGE")
	local B = ctx.Barrage
	Rig:act({
		Until = d.CloseT + 0.8,
		Upper = function(t)
			local up = K.k(t, d.T0, d.OpenT - 0.3)
			local down = K.k(t, d.CloseT - 0.4, d.CloseT + 0.6)
			-- (each shot is a push from one hand)
			local push = math.max(0, 1 - (os.clock() - B.Pulse) / 0.35)
			local target = B.Side == "Left" and PUSH_L or PUSH_R
			if push > 0 and up >= 1 and down <= 0 then
				Rig:pose(RAISED, target, K.E.outQuad(push))
			else
				Rig:pose(Rig.REST, RAISED, up * (1 - down))
			end
			ctx.SK.hang(Rig.SB, "Right", 0.1, 0.7)
			ctx.SK.hang(Rig.SB, "Left", 0.1, 0.7)
			if gals[1] then Rig.SB.lookAt(gals[1].P, 0.9, Rig.RootCF) end
			return true
		end,
	})
	K.sfx(K.S.Portal, 0.9, 0.8)
	K.sfx(K.S.DarkDrone, 0.6, 0.9)
	task.delay(math.max(d.OpenT - ctx.S.now() - 0.2, 0), function() K.sfx(K.S.Portal2, 0.9, 0.9) end)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = S.now()
		if ctx.epoch() ~= epoch or now > d.CloseT + 1 then
			conn:Disconnect()
			host:Destroy()
			return
		end
		local amount = K.k(now, d.T0 + 0.2, d.OpenT, K.E.outCubic) * (1 - K.k(now, d.CloseT - 0.5, d.CloseT + 0.4))
		for i, g in ipairs(gals) do
			-- (each one flares as something is flung out of it)
			local flare = math.max(0, 1 - (os.clock() - (g.Flash or 0)) / 0.3)
			local size = (150 + 10 * math.sin(now * 2 + i)) * (1 + 0.25 * flare)
			g.G.set(g.P, S.CENTER + Vector3.new(0, 20, 0), size, math.min(1, amount * (1 + 0.5 * flare)), now + i)
		end
	end)
end

-- one body out of a galaxy
function A.shot(ctx, d)
	local K, S, Fx, Warn = ctx.K, ctx.S, ctx.Fx, ctx.Warn
	local epoch = ctx.epoch()
	local B = ctx.Barrage
	if B then
		B.Pulse = os.clock()
		B.Side = (B.Side == "Left") and "Right" or "Left"
		local best, bd = nil, math.huge
		for _, g in ipairs(B.Gals) do
			local dd = (g.P - d.From).Magnitude
			if dd < bd then best, bd = g, dd end
		end
		if best then best.Flash = os.clock() end
	end
	local giant = d.Kind == "giant"
	local body
	if (d.Kind == "planet" or giant) and d.Model then
		body = K.planet(d.Model, d.Size, CFrame.new(d.From), Fx.Folder)
	end
	local glow
	if not body then
		-- a star: a white-hot core in a violet glow
		body = K.part({ Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.one * d.Size, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 240, 255), CFrame = CFrame.new(d.From) }, Fx.Folder)
		glow = ctx.SK.glow(K, body, d.From, d.Size * 5, Fx.VIOLET, 3)
	end
	local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, d.Size * 0.4, 0) a0.Parent = body
	local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -d.Size * 0.4, 0) a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.45
	trail.LightEmission = 1
	trail.Brightness = 3
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(Color3.fromRGB(240, 220, 255), Fx.VIOLET)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = body
	K.emitter(body, {
		Texture = "1851669703", Color = ColorSequence.new(Color3.new(1, 1, 1), Fx.VIOLET_HOT), Size = K.ns(0, d.Size * 0.3, 1, 0),
		Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(2, 8), SpreadAngle = Vector2.new(180, 180), Rate = 25, Brightness = 4,
	})
	if giant then
		-- the finale: something the size of a house, glowing, falling on everyone
		glow = ctx.SK.glow(K, body, d.From, d.Size * 3, Fx.VIOLET, 2.5)
		local shell = K.part({ Name = "Corona", Shape = Enum.PartType.Ball, Size = Vector3.one * d.Size * 1.15, Material = Enum.Material.ForceField, Color = Fx.MAGENTA, Transparency = 0.1, CFrame = body.CFrame }, body)
		local w = Instance.new("WeldConstraint") w.Part0, w.Part1 = body, shell w.Parent = shell
		shell.Anchored = false
		Warn.callout("THE LAST WORLD")
		K.sfx(K.S.Rumble, 1, 0.6)
		K.sfx(K.S.Riser, 0.9, 0.7)
	end
	local zone = Fx.zone({ Kind = "circle", P = d.To, R = d.R }, d.T0, d.T)
	local peak = d.From:Lerp(d.To, 0.5) + Vector3.new(0, giant and 20 or 70, 0)
	local function at(u)
		local a = d.From:Lerp(peak, u)
		local b = peak:Lerp(d.To + Vector3.new(0, d.Size * 0.4, 0), u)
		return a:Lerp(b, u)
	end
	Warn.add({
		Id = d.Id, T = d.T, Shape = { Kind = "circle", P = d.To, R = d.R }, Name = d.Name, Target = d.Target, Rad = d.Size,
		Pos = function(now) return at(K.remap(now, d.T0, d.T) ^ 1.25) end,
	})
	K.sfx(d.Kind == "star" and K.S.FireWhoosh or K.S.Whoosh, 0.5, d.Kind == "star" and 1.4 or 0.7)
	local spin = CFrame.Angles(0, 0, 0)
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local now = S.now()
		if ctx.epoch() ~= epoch then
			conn:Disconnect()
			zone.destroy()
			body:Destroy()
			return
		end
		local u = K.remap(now, d.T0, d.T) ^ 1.25
		spin = spin * CFrame.Angles(dt * d.Spin * 0.4, dt * d.Spin, 0)
		body.CFrame = CFrame.new(at(u)) * spin
		if glow then glow.set(body.Position, d.Size * 5, 1) end
		zone.update(now)
		if now >= d.T then
			conn:Disconnect()
			zone.destroy()
			if Warn.claimed(d.Id) then
				-- batted back: it flies home into his chest
				local from = body.Position
				local t0 = os.clock()
				local c2
				c2 = RunService.RenderStepped:Connect(function()
					local v = (os.clock() - t0) / 0.45
					local to = ctx.chest()
					body.CFrame = CFrame.new(from:Lerp(to, K.E.inQuad(math.min(v, 1)))) * spin
					if v >= 1 then
						c2:Disconnect()
						body:Destroy()
					end
				end)
				trail.Color = ColorSequence.new(Fx.LIME, Fx.GREEN)
			else
				Fx.blast(d.To, d.R * 1.6, d.Kind == "star" and Color3.fromRGB(230, 180, 255) or Fx.VIOLET, { Shake = d.Kind == "star" and 0.6 or (giant and 4 or 1.4), Volume = giant and 1.5 or 1 })
				if giant then
					Fx.blast(d.To, d.R * 2.6, Fx.MAGENTA, { Column = false, Shake = 0, Volume = 0 })
					Fx.sound(K.S.Boom, d.To, 1.3, 0.6, 3000)
					K.flash(0.4, Color3.fromRGB(255, 220, 255), 0.5)
				end
				body:Destroy()
			end
		end
	end)
	Debris:AddItem(body, (d.T - S.now()) + 3)
end

return A
