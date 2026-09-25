--==================================================
-- ATTACK 2: FIST SLAM (client)
-- He rears back, fist high, and red zones open on the arena.
-- As they fill, he drives the fist down - and a violet fist of
-- his power crashes into every zone, one after another.
--==================================================
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local A = {}

local function poses(side)
	local s = side == "Right" and 1 or -1
	local S1, E1 = side .. "Shoulder", side .. "Elbow"
	local O1 = (side == "Right" and "Left" or "Right") .. "Shoulder"
	local windup = { Waist = { 10, -14 * s, 0 }, [S1] = { 175, 0, 12 * s }, [E1] = { 75, 0, 0 }, [O1] = { 20, 0, -35 * s } }
	local slam = { Waist = { -26, 18 * s, 0 }, [S1] = { 62, 0, 6 * s }, [E1] = { 0, 0, 0 }, [O1] = { 30, 0, -45 * s } }
	return windup, slam
end

local function fist(K, Fx, size)
	local src = ReplicatedStorage:FindFirstChild("FinalCutscene")
	src = src and src:FindFirstChild("Assets") and src.Assets:FindFirstChild("AntiSpiralHand")
	local f
	if src then
		f = src:Clone()
		for _, c in ipairs(f:GetChildren()) do c:Destroy() end
		f.Anchored, f.CanCollide, f.CanQuery, f.CanTouch = true, false, false, false
	else
		f = K.part({ Shape = Enum.PartType.Ball }, nil)
	end
	f.Name = "SpectralFist"
	f.Size = Vector3.new(0.47, 1, 0.41) * size
	f.Material = Enum.Material.Neon
	f.Color = Fx.VIOLET
	f.Transparency = 0.15
	f.Parent = Fx.Folder
	local a0 = Instance.new("Attachment") a0.Position = Vector3.new(size * 0.2, size * 0.4, 0) a0.Parent = f
	local a1 = Instance.new("Attachment") a1.Position = Vector3.new(-size * 0.2, size * 0.4, 0) a1.Parent = f
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.25
	tr.LightEmission = 1
	tr.Color = ColorSequence.new(Fx.VIOLET_HOT, Fx.VIOLET)
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	tr.Parent = f
	return f
end

function A.start(ctx, d)
	local K, S, Fx, Warn, Rig = ctx.K, ctx.S, ctx.Fx, ctx.Warn, ctx.Rig
	local epoch = ctx.epoch()
	local zones = {}
	local first = d.Zones[1] and d.Zones[1].T or (S.now() + 1.5)
	local last = d.Zones[#d.Zones] and d.Zones[#d.Zones].T or first
	for _, z in ipairs(d.Zones) do
		local shape = { Kind = "circle", P = z.P, R = z.R }
		local ent = { Z = z, Zone = Fx.zone(shape, d.T0, z.T), Fist = nil }
		table.insert(zones, ent)
		Warn.add({ Id = z.Id, T = z.T, Shape = shape, Name = "FIST", Target = z.Target, Rad = z.R, Pos = function() return z.P + Vector3.new(0, 4, 0) end })
	end
	local windup, slam = poses(d.Hand)
	local strike = first - 0.3
	Rig:act({
		Until = last + 0.9,
		Root = function(t)
			-- (rocks back, then drops his weight into it)
			local back = K.k(t, d.T0, strike - 0.1) * (1 - K.k(t, strike - 0.1, first))
			local drop = K.k(t, strike, first, K.E.outCubic) * (1 - K.k(t, last + 0.2, last + 0.9))
			return CFrame.new(0, -18 * drop, 0) * CFrame.Angles(math.rad(4 * back - 6 * drop), 0, 0)
		end,
		Upper = function(t)
			if t < strike then
				Rig:pose(Rig.REST, windup, K.k(t, d.T0, strike - 0.1, K.E.outCubic))
			elseif t < last + 0.2 then
				Rig:pose(windup, slam, K.k(t, strike, first, K.E.inQuad))
			else
				Rig:pose(slam, Rig.REST, K.k(t, last + 0.2, last + 0.9))
			end
			ctx.SK.hang(Rig.SB, d.Hand, 1, 0)
			ctx.SK.hang(Rig.SB, d.Hand == "Right" and "Left" or "Right", 0.6, 0.1)
			if zones[1] then Rig.SB.lookAt(zones[1].Z.P, 0.9, Rig.RootCF) end
			return true
		end,
	})
	K.sfx(K.S.Riser, 0.6, 1.3)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = S.now()
		if ctx.epoch() ~= epoch then
			conn:Disconnect()
			for _, e in ipairs(zones) do
				e.Zone.destroy()
				if e.Fist then e.Fist:Destroy() end
			end
			return
		end
		local alive = false
		for _, e in ipairs(zones) do
			local z = e.Z
			if not e.Done then
				alive = true
				e.Zone.update(now)
				-- the fist comes down out of the sky over the last half second
				local fall = 0.5
				if now >= z.T - fall then
					if not e.Fist then
						e.Fist = fist(K, Fx, z.R * 1.5)
						K.sfx(K.S.FireWhoosh, 0.5, 0.8)
					end
					local u = K.E.inQuad(K.remap(now, z.T - fall, z.T))
					local top = z.P + Vector3.new(0, 260, 0)
					local bottom = z.P + Vector3.new(0, e.Fist.Size.Y * 0.45, 0)
					e.Fist.CFrame = CFrame.new(top:Lerp(bottom, u)) * CFrame.Angles(0, math.rad(z.T * 50 % 360), 0)
				end
				if now >= z.T then
					e.Done = true
					e.Zone.destroy()
					local f = e.Fist
					if Warn.claimed(z.Id) then
						-- parried: the fist is knocked away and shatters into green light
						Fx.parryBurst(z.P + Vector3.new(0, 6, 0), false)
						if f then
							f.Color = Fx.GREEN
							K.tween(f, 0.35, { CFrame = f.CFrame + Vector3.new(0, 60, 0), Transparency = 1 })
						end
					else
						Fx.blast(z.P, z.R * 1.4, Fx.VIOLET, { Sound = K.S.RockBoom, Shake = 2, Volume = 1.2 })
						if f then
							K.tween(f, 0.5, { Transparency = 1, Size = f.Size * 1.15 })
						end
					end
					if f then task.delay(0.6, function() f:Destroy() end) end
				end
			end
		end
		if not alive then conn:Disconnect() end
	end)
end

return A
