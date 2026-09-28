--==================================================
-- SLAYER AURA  (Cruelty Slayer -- client, built in code)
--
-- You put down the thing behind the portal. You wear what's left of it.
--
--   SCYTHES    two crimson reaper blades crossed behind your back,
--              breathing open and shut like wings
--   THORN HALO a black crown of thorns with a blood-red rim, turning
--              slowly behind your head
--   CHAINS     three spectral chains spiralling round your body
--   THE GRIN   a ring of bone teeth round your feet that bite up and
--              down in a wave, over a pool of blood with a red rim
--   SOULS      red wisps rising off the pool, dark smoke off your body
--   REAP       every few seconds (and whenever you jump) a crescent
--              slash sweeps all the way round you
--==================================================

local AuraKit = require(script.Parent:WaitForChild("AuraKit"))

local BLOOD = Color3.fromRGB(200, 16, 30)
local CRIMSON = Color3.fromRGB(255, 50, 60)
local HOT = Color3.fromRGB(255, 140, 150)
local DEEP = Color3.fromRGB(70, 0, 8)
local BLACK = Color3.fromRGB(10, 4, 6)
local BONE = Color3.fromRGB(240, 230, 214)

local Slayer = {}

local BLADE_SEGS = 12
local function bladeShape(u)
	-- widest a third of the way along, needle tip
	return 0.1 + 0.55 * math.sin(math.min(u * 1.35, 1) * math.pi) * (1 - u * 0.55)
end

local function update(k, dt, t)
	local rcf = k.root.CFrame
	local pos = rcf.Position
	local g = k.groundY
	k:place(k.core, CFrame.new(pos))
	local reap = k.reap
	local pulse = 0.5 + 0.5 * math.sin(t * 2.2)
	k.light.Brightness = 1.6 + pulse * 0.8 + reap * 3 + k.flare * 2

	-- ---------- REAP timer ----------
	if t >= k.nextReap then
		k.nextReap = t + 6
		k.reap = 1
		k.reapYaw = math.random() * math.pi * 2
		k.burst:Emit(AuraKit.lowGraphics() and 14 or 30)
	end
	k.reap = math.max(0, k.reap - dt * 1.6)

	-- ---------- SCYTHES ----------
	local open = 0.15 + pulse * 0.12 + k.flare * 0.35 + reap * 0.25
	local back = rcf * CFrame.new(0, 1.0, 0.95)
	for side = -1, 1, 2 do
		local blade = k.blades[side]
		local bcf = back * CFrame.Angles(0, side * 0.35, side * (0.55 + open)) * CFrame.new(side * 0.2, 0, 0)
		-- snath: the long handle, from the small of the back up to the blade
		local handleLen = 3.6
		k:place(blade.handle, bcf * CFrame.new(0, handleLen / 2 - 0.6, 0) * CFrame.Angles(math.rad(90), 0, 0))
		local head = bcf * CFrame.new(0, handleLen - 0.6, 0)
		local R = 2.3
		for i, seg in ipairs(blade.segs) do
			local u = (i - 0.5) / BLADE_SEGS
			local th = math.rad(90 + u * 150) -- sweeps from straight up, curling outward and down
			local th0 = math.rad(90 + (i - 1) / BLADE_SEGS * 150)
			local th1 = math.rad(90 + i / BLADE_SEGS * 150)
			local p0 = Vector3.new(side * (math.cos(th0) * R + R) * -1, math.sin(th0) * R * 0.8, 0)
			local p1 = Vector3.new(side * (math.cos(th1) * R + R) * -1, math.sin(th1) * R * 0.8, 0)
			local mid = (p0 + p1) / 2
			local w = bladeShape(u)
			-- the blade edge sits on the inside of the curve
			local inward = Vector3.new(side * math.cos(th), -math.sin(th) * 0.8, 0).Unit * (w / 2)
			local wp = head:PointToWorldSpace(mid + inward)
			local tangentW = head:VectorToWorldSpace((p1 - p0).Unit)
			local upW = head:VectorToWorldSpace(Vector3.new(0, 0, 1))
			seg.Size = Vector3.new(w, 0.07, (p1 - p0).Magnitude + 0.04)
			k:place(seg, CFrame.lookAt(wp, wp + tangentW, upW))
			local edge = blade.edge[i]
			local ep = head:PointToWorldSpace(mid + inward * 2.05)
			edge.Size = Vector3.new(0.06, 0.08, (p1 - p0).Magnitude + 0.05)
			k:place(edge, CFrame.lookAt(ep, ep + tangentW, upW))
			edge.Transparency = 0.05 + 0.3 * (1 - pulse) - reap * 0.05
		end
	end

	-- ---------- THORN HALO ----------
	local haloC = rcf * CFrame.new(0, 2.5, 0.75) * CFrame.Angles(0, 0, t * 0.35)
	local hn = #k.halo
	for i, seg in ipairs(k.halo) do
		local a = (i / hn) * math.pi * 2
		local p = haloC:PointToWorldSpace(Vector3.new(math.cos(a) * 1.25, math.sin(a) * 1.25, 0))
		local tan = haloC:VectorToWorldSpace(Vector3.new(-math.sin(a), math.cos(a), 0))
		k:place(seg, CFrame.lookAt(p, p + tan))
		seg.Transparency = 0.05 + 0.35 * (0.5 + 0.5 * math.sin(t * 4 - i * 0.6))
	end
	for i, th in ipairs(k.thorns) do
		local a = th.a
		local len = th.len * (1 + reap * 0.5 + k.flare * 0.3)
		local dir = Vector3.new(math.cos(a), math.sin(a), 0)
		local p = haloC:PointToWorldSpace(dir * (1.25 + len / 2))
		th.p.Size = Vector3.new(0.1, 0.1, len)
		k:place(th.p, CFrame.lookAt(p, p + haloC:VectorToWorldSpace(dir)))
	end

	-- ---------- CHAINS ----------
	for c, chain in ipairs(k.chains) do
		for i, link in ipairs(chain) do
			local h = ((i / #chain) + t * 0.12 + c * 0.33) % 1
			local a = h * math.pi * 4 + c * 2.1 + t * 0.9
			local r = 1.7 + math.sin(t * 1.3 + c) * 0.15
			local lp = pos + Vector3.new(math.cos(a) * r, -2.6 + h * 5.2, math.sin(a) * r)
			local tan = Vector3.new(-math.sin(a), 0.35, math.cos(a))
			local cf = CFrame.lookAt(lp, lp + tan) * CFrame.Angles(0, 0, (i % 2 == 0) and math.rad(90) or 0)
			k:place(link, cf)
			-- chains fade out at the very top and bottom of the spiral
			link.Transparency = 0.15 + 0.85 * (1 - math.sin(h * math.pi))
		end
	end

	-- ---------- THE GRIN (ground) ----------
	local gp = Vector3.new(pos.X, g + 0.06, pos.Z)
	k:place(k.pool, CFrame.new(gp) * CFrame.Angles(0, 0, math.rad(90)))
	local rn = #k.rim
	for i, seg in ipairs(k.rim) do
		local a = (i / rn) * math.pi * 2 - t * 0.3
		k:place(seg, AuraKit.ringCF(gp + Vector3.new(0, 0.03, 0), a, 3.35))
		seg.Transparency = 0.05 + 0.4 * (0.5 + 0.5 * math.sin(t * 3 + i * 0.5))
	end
	local tn = #k.teeth
	for i, tooth in ipairs(k.teeth) do
		local a = (i / tn) * math.pi * 2 + t * 0.3
		local bite = math.max(0, math.sin(t * 3.2 - i * 0.55))
		local hgt = 0.35 + bite * 0.75 + reap * 0.6
		tooth.Size = Vector3.new(0.34, hgt, 0.34)
		local tp = gp + Vector3.new(math.cos(a) * 2.9, hgt / 2, math.sin(a) * 2.9)
		-- wedge faces outward so the sloped face points at the player
		k:place(tooth, CFrame.lookAt(tp, tp + Vector3.new(math.cos(a), 0, math.sin(a))))
	end

	-- ---------- REAP slash ----------
	local sn = #k.slash
	for i, seg in ipairs(k.slash) do
		if reap <= 0 then
			seg.Transparency = 1
		else
			local prog = 1 - reap
			local reach = math.clamp(prog * 3, 0, 1) -- the sweep lands in the first third
			local u = i / sn
			if u > reach then
				seg.Transparency = 1
			else
				local r = 2.6 + prog * 3.2
				local a = k.reapYaw + u * math.pi * 1.9
				local c = pos + Vector3.new(0, 0.2 + math.sin(u * math.pi) * 0.6, 0)
				k:place(seg, AuraKit.ringCF(c, a, r) * CFrame.Angles(0, 0, math.rad(12)))
				local w = math.sin(u * math.pi)
				seg.Size = Vector3.new(0.12, 0.25 + w * 0.9 * reap, (math.pi * 2 * r) / sn * 1.05)
				seg.Transparency = 1 - reap * (0.3 + 0.7 * w)
			end
		end
	end
end

function Slayer.new(character)
	local k = AuraKit.new(character, "SlayerAura", update)
	if not k then return nil end
	k.nextReap = 2.5
	k.reap = 0
	k.reapYaw = 0

	k.light = Instance.new("PointLight")
	k.light.Color = BLOOD
	k.light.Range = 16
	k.light.Shadows = false
	k.light.Parent = k.core

	-- scythes
	k.blades = {}
	for side = -1, 1, 2 do
		local b = { segs = {}, edge = {} }
		b.handle = k:part({ Name = "Snath", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.6, 0.14, 0.14), Color = BLACK, Material = Enum.Material.SmoothPlastic })
		-- cylinder axis is X; rotate so it runs along the handle
		b.handle.Size = Vector3.new(0.14, 0.14, 3.6)
		b.handle.Shape = Enum.PartType.Block
		for i = 1, BLADE_SEGS do
			b.segs[i] = k:part({ Name = "Blade", Size = Vector3.new(0.4, 0.07, 0.5), Color = DEEP })
			b.edge[i] = k:part({ Name = "Edge", Size = Vector3.new(0.06, 0.08, 0.5), Color = CRIMSON })
		end
		k.blades[side] = b
	end

	-- thorn halo
	k.halo = {}
	for i = 1, AuraKit.count(24, 14) do
		k.halo[i] = k:part({ Name = "Halo", Size = Vector3.new(0.09, 0.09, 0.36), Color = BLOOD })
	end
	k.thorns = {}
	local nThorns = AuraKit.count(14, 9)
	for i = 1, nThorns do
		local p = k:part({ Name = "Thorn", Size = Vector3.new(0.1, 0.1, 0.5), Color = BLACK, Material = Enum.Material.SmoothPlastic })
		k.thorns[i] = { p = p, a = (i / nThorns) * math.pi * 2 + (math.random() - 0.5) * 0.2, len = (i % 2 == 0) and 0.75 or 0.4 }
	end

	-- chains
	k.chains = {}
	for c = 1, 3 do
		local chain = {}
		for i = 1, AuraKit.count(16, 9) do
			chain[i] = k:part({ Name = "Link", Size = Vector3.new(0.1, 0.26, 0.42), Color = Color3.fromRGB(150, 20, 30) })
		end
		k.chains[c] = chain
	end

	-- the pool, rim and teeth
	k.pool = k:part({ Name = "Pool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 6.4, 6.4), Color = Color3.fromRGB(40, 0, 6), Material = Enum.Material.Glass, Transparency = 0.25 })
	k.rim = {}
	for i = 1, AuraKit.count(30, 16) do
		k.rim[i] = k:part({ Name = "Rim", Size = Vector3.new(0.14, 0.06, 0.75), Color = CRIMSON })
	end
	k.teeth = {}
	for i = 1, AuraKit.count(18, 10) do
		local w = Instance.new("WedgePart")
		w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow, w.Locked = true, false, false, false, false, true
		w.Material = Enum.Material.SmoothPlastic
		w.Color = BONE
		w.Size = Vector3.new(0.34, 0.4, 0.34)
		w.Parent = k.folder
		k.teeth[i] = w
	end

	-- reap slash arc
	k.slash = {}
	for i = 1, AuraKit.count(28, 14) do
		k.slash[i] = k:part({ Name = "Reap", Size = Vector3.new(0.12, 0.6, 1), Color = HOT, Transparency = 1 })
	end

	-- souls rising off the pool
	k.soulSrc = k:part({ Name = "Souls", Size = Vector3.new(5, 0.1, 5), Transparency = 1 })
	table.insert(k.connections, game:GetService("RunService").RenderStepped:Connect(function()
		if k.soulSrc.Parent then
			k.soulSrc.CFrame = CFrame.new(k.root.Position.X, k.groundY + 0.1, k.root.Position.Z)
		end
	end))
	k:emitter(k.soulSrc, {
		Texture = AuraKit.SPARK,
		Color = ColorSequence.new(HOT, BLOOD),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(1.5, 3.5),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(10, 10),
		Acceleration = Vector3.new(0, 1.5, 0),
		Rate = AuraKit.lowGraphics() and 8 or 18,
		RotSpeed = NumberRange.new(-120, 120),
	})
	-- dark smoke clinging to the body
	k:emitter(k.core, {
		Texture = AuraKit.SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(90, 6, 16), BLACK),
		Size = NumberSequence.new(1.2, 3.2),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.7), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 1.2, 0),
		Rate = AuraKit.lowGraphics() and 3 or 8,
	})
	k.burst = k:emitter(k.core, {
		Texture = AuraKit.SPARK,
		Color = ColorSequence.new(HOT, BLOOD),
		LightEmission = 1,
		Size = NumberSequence.new(0.5, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(180, 20),
		Drag = 3,
		Rate = 0,
	})
	k.onJump = function(self)
		self.reap = 1
		self.reapYaw = math.random() * math.pi * 2
		self.burst:Emit(AuraKit.lowGraphics() and 10 or 20)
	end
	return k
end

return Slayer
