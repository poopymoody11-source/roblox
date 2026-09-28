--==================================================
-- ASCENDANT AURA  v2  (Mythic -- client, built in code)
--
-- A saint's radiance, not a glowing tube:
--   CROWN      a gold halo over the head with rays standing up out of
--              it, turning slowly
--   AUREOLE    a sunburst of light rays fanned out behind the
--              shoulders, breathing in length
--   WINGS      three layers of light feathers off the back, drifting
--              in a slow beat; they flare wide on a jump
--   SEAL       a sacred-geometry circle on the ground -- two
--              counter-rotating rings, a hexagram and six diamonds --
--              that hugs the floor wherever you stand
--   MOTES      gold motes rising, white feathers falling
--==================================================

local AuraKit = require(script.Parent:WaitForChild("AuraKit"))

local GOLD  = Color3.fromRGB(255, 184, 48)
local DEEP  = Color3.fromRGB(214, 128, 16)
local PALE  = Color3.fromRGB(255, 232, 170)
local SKY   = Color3.fromRGB(120, 196, 255)
local WHITE = Color3.new(1, 1, 1)

local Ascendant = {}

local function update(k, dt, t)
	local root = k.root
	local rcf = root.CFrame
	local pos = rcf.Position
	local flat = CFrame.new(pos) * CFrame.Angles(0, math.atan2(-rcf.LookVector.X, -rcf.LookVector.Z), 0)
	local pulse = 0.5 + 0.5 * math.sin(t * 2.1)
	local flare = k.flare

	k:place(k.core, CFrame.new(pos))
	k.light.Brightness = 2.2 + pulse * 1.5 + flare * 3

	-- CROWN: halo ring + standing rays, above the head
	local head = k.character:FindFirstChild("Head")
	local top = head and (head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.9, 0)) or (pos + Vector3.new(0, 3.1, 0))
	top += Vector3.new(0, math.sin(t * 1.8) * 0.08, 0)
	local spin = t * 0.7
	local n = #k.halo
	for i, seg in ipairs(k.halo) do
		k:place(seg, AuraKit.ringCF(top, (i / n) * math.pi * 2 + spin, 1.05))
	end
	local rn = #k.spikes
	for i, sp in ipairs(k.spikes) do
		local a = (i / rn) * math.pi * 2 + spin
		local len = 0.55 + 0.25 * math.sin(t * 3 + i)
		local base = top + Vector3.new(math.cos(a) * 1.05, 0, math.sin(a) * 1.05)
		sp.Size = Vector3.new(0.12, len, 0.12)
		k:place(sp, CFrame.new(base + Vector3.new(0, len / 2 + 0.05, 0)) * CFrame.Angles(0, -a, math.rad(-12)))
	end

	-- AUREOLE: rays fanned out behind the shoulders, in the back plane
	-- centred behind the head and pushed well back, so the rays frame the
	-- silhouette instead of bursting out of it
	local backCentre = rcf * CFrame.new(0, 1.9, 1.6)
	local an = #k.rays
	for i, ray in ipairs(k.rays) do
		local a = (i / an) * math.pi * 2 + t * 0.2
		-- long/short alternating, with a slow sweep of brightness round the ring
		local len = ((i % 2 == 0) and 1.25 or 0.8) + flare * 0.9
		local dir = Vector3.new(math.cos(a), math.sin(a), 0)
		ray.Size = Vector3.new(0.07, 0.07, len)
		local localPos = dir * (1.6 + len / 2)
		k:place(ray, backCentre * CFrame.lookAt(localPos, localPos + dir))
		local sweep = 0.5 + 0.5 * math.sin(a * 2 - t * 2.5)
		ray.Transparency = 0.2 + 0.45 * (1 - sweep) - flare * 0.15
	end
	local sn = #k.sunRing
	for i, seg in ipairs(k.sunRing) do
		local a = (i / sn) * math.pi * 2 - t * 0.4
		local p = Vector3.new(math.cos(a) * 1.5, math.sin(a) * 1.5, 0)
		k:place(seg, backCentre * CFrame.lookAt(p, p + Vector3.new(-math.sin(a), math.cos(a), 0)))
	end

	-- WINGS: three layers of feathers, slow beat, flare on jump
	local beat = math.sin(t * 1.7) * 0.12
	local spread = 0.45 + flare * 0.75 + beat
	for _, w in ipairs(k.wings) do
		local side = w.side
		for _, f in ipairs(w.feathers) do
			local layer, idx = f.layer, f.idx
			local fan = math.rad(-8 + idx * 17) -- feathers fan from down-and-out to up-and-out
			local reach = (1.2 + layer * 0.55)
			local root2 = rcf * CFrame.new(side * 0.45, 1.05 - layer * 0.12, 0.7 + layer * 0.12)
			-- negative yaw on the right (and positive on the left) sweeps the
			-- feathers BACK; the other sign drove them forward into the body
			local cf = root2
				* CFrame.Angles(0, -side * (0.35 + spread * (0.6 + layer * 0.25)), 0)
				* CFrame.Angles(0, 0, side * fan)
				* CFrame.new(side * reach, 0, 0)
			k:place(f.p, cf)
			f.p.Transparency = 0.05 + layer * 0.12 - flare * 0.05
		end
	end

	-- SEAL on the ground
	local g = Vector3.new(pos.X, k.groundY + 0.08, pos.Z)
	local on = #k.outer
	for i, seg in ipairs(k.outer) do
		k:place(seg, AuraKit.ringCF(g, (i / on) * math.pi * 2 + t * 0.3, 4.1))
	end
	local inn = #k.inner
	for i, seg in ipairs(k.inner) do
		k:place(seg, AuraKit.ringCF(g, (i / inn) * math.pi * 2 - t * 0.45, 2.9))
	end
	for i, line in ipairs(k.hexagram) do
		-- two triangles inscribed in the inner ring
		local tri = (i <= 3) and 0 or math.pi / 3
		local j = (i - 1) % 3
		local a1 = tri + j * (math.pi * 2 / 3) - t * 0.45
		local a2 = a1 + math.pi * 2 / 3
		local p1 = g + Vector3.new(math.cos(a1) * 2.9, 0, math.sin(a1) * 2.9)
		local p2 = g + Vector3.new(math.cos(a2) * 2.9, 0, math.sin(a2) * 2.9)
		local mid = (p1 + p2) / 2
		line.Size = Vector3.new(0.07, 0.05, (p2 - p1).Magnitude)
		k:place(line, CFrame.lookAt(mid, p2))
	end
	for i, d in ipairs(k.diamonds) do
		local a = (i / #k.diamonds) * math.pi * 2 + t * 0.3
		local p = g + Vector3.new(math.cos(a) * 3.5, 0.05, math.sin(a) * 3.5)
		k:place(d, CFrame.new(p) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, math.rad(45), 0))
		d.Transparency = 0.1 + 0.5 * (0.5 + 0.5 * math.sin(t * 3 + i))
	end
	local sealGlow = 0.18 + 0.3 * (1 - pulse) - flare * 0.15
	for _, seg in ipairs(k.outer) do seg.Transparency = sealGlow end
	for _, line in ipairs(k.hexagram) do line.Transparency = sealGlow + 0.15 end
	k:place(k.floorCore, CFrame.new(g + Vector3.new(0, 0.2, 0)))
end

function Ascendant.new(character)
	local k = AuraKit.new(character, "AscendantAura", update)
	if not k then return nil end

	k.light = Instance.new("PointLight")
	k.light.Color = GOLD
	k.light.Range = 22
	k.light.Shadows = false
	k.light.Parent = k.core

	-- crown
	k.halo = {}
	for i = 1, AuraKit.count(18, 10) do
		k.halo[i] = k:part({ Name = "Halo", Size = Vector3.new(0.14, 0.14, 0.42), Color = (i % 2 == 0) and PALE or GOLD })
	end
	k.spikes = {}
	for i = 1, AuraKit.count(9, 5) do
		k.spikes[i] = k:part({ Name = "CrownRay", Size = Vector3.new(0.12, 0.6, 0.12), Color = PALE, Transparency = 0.1 })
	end

	-- aureole
	k.rays = {}
	for i = 1, AuraKit.count(16, 8) do
		k.rays[i] = k:part({ Name = "Ray", Size = Vector3.new(0.07, 0.07, 1), Color = (i % 2 == 0) and PALE or GOLD })
	end
	k.sunRing = {}
	for i = 1, AuraKit.count(20, 10) do
		k.sunRing[i] = k:part({ Name = "SunRing", Size = Vector3.new(0.08, 0.08, 0.5), Color = GOLD, Transparency = 0.1 })
	end

	-- wings: 2 sides x 3 layers x 4 feathers
	k.wings = {}
	local perLayer = AuraKit.lowGraphics() and 3 or 4
	for _, side in ipairs({ -1, 1 }) do
		local feathers = {}
		for layer = 1, 3 do
			for idx = 1, perLayer do
				local len = 2.1 + layer * 0.5 - idx * 0.18
				local p = k:part({
					Name = "Feather",
					Size = Vector3.new(len, 0.08, 0.26 - layer * 0.04),
					Color = (layer == 1) and PALE or ((layer == 2) and GOLD or SKY),
					Transparency = 0.2,
				})
				table.insert(feathers, { p = p, layer = layer, idx = idx })
			end
		end
		table.insert(k.wings, { side = side, feathers = feathers })
	end

	-- seal
	k.outer = {}
	for i = 1, AuraKit.count(30, 16) do
		k.outer[i] = k:part({ Name = "SealOuter", Size = Vector3.new(0.14, 0.05, 0.62), Color = GOLD })
	end
	k.inner = {}
	for i = 1, AuraKit.count(22, 12) do
		k.inner[i] = k:part({ Name = "SealInner", Size = Vector3.new(0.09, 0.05, 0.5), Color = (i % 2 == 0) and PALE or DEEP, Transparency = 0.2 })
	end
	k.hexagram = {}
	for i = 1, 6 do
		k.hexagram[i] = k:part({ Name = "Hexagram", Size = Vector3.new(0.07, 0.05, 4), Color = PALE })
	end
	k.diamonds = {}
	for i = 1, 6 do
		k.diamonds[i] = k:part({ Name = "Diamond", Size = Vector3.new(0.34, 0.06, 0.34), Color = PALE })
	end

	-- particles
	k:emitter(k.core, {
		Texture = AuraKit.SPARK,
		Color = ColorSequence.new(PALE, GOLD),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.34), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.05, 0.4),
		Lifetime = NumberRange.new(1.4, 2.2),
		Speed = NumberRange.new(1.5, 3.5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 3.5, 0),
		Drag = 1,
		Rate = AuraKit.lowGraphics() and 10 or 24,
		RotSpeed = NumberRange.new(-120, 120),
	})
	-- feathers drifting down from above
	local sky = k:attachment(k.core, Vector3.new(0, 5, 0))
	k:emitter(sky, {
		Texture = AuraKit.SPARK,
		Color = ColorSequence.new(WHITE, PALE),
		LightEmission = 0.8,
		Size = NumberSequence.new(0.22, 0.05),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(0.3, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -1.2, 0),
		Rate = AuraKit.lowGraphics() and 3 or 8,
		RotSpeed = NumberRange.new(-60, 60),
	})
	-- faint glow pool on the floor
	k.floorCore = k:part({ Name = "FloorCore", Size = Vector3.one * 0.2, Transparency = 1 })
	k:emitter(k.floorCore, {
		Texture = AuraKit.SMOKE,
		Color = ColorSequence.new(GOLD, DEEP),
		LightEmission = 0.9,
		Size = NumberSequence.new(3, 6),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.5, 2),
		Speed = NumberRange.new(0.2, 0.6),
		Rate = AuraKit.lowGraphics() and 2 or 5,
	})
	return k
end

return Ascendant
