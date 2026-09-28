--==================================================
-- TIDE AURA  (Rare -- client, built in code)
--
--   WHIRLPOOL  two strands of water spiralling up around you from the
--              feet to above the head, tightening as they rise
--   CREST      a rolling wave running round your waist
--   RIPPLES    rings that spread across the floor and fade
--   DROPLETS   orbiting water beads with spray trails
--   BUBBLES    rising, plus mist at the feet; landing makes a splash
--==================================================

local AuraKit = require(script.Parent:WaitForChild("AuraKit"))

local AQUA  = Color3.fromRGB(40, 190, 230)
local TEAL  = Color3.fromRGB(18, 130, 170)
local FOAM  = Color3.fromRGB(210, 246, 255)
local DEEP  = Color3.fromRGB(10, 70, 140)

local Tide = {}

local function update(k, dt, t)
	local pos = k.root.Position
	local g = k.groundY
	k:place(k.core, CFrame.new(pos))
	k:place(k.foot, CFrame.new(pos.X, g + 0.3, pos.Z))
	k.light.Brightness = 1.6 + 0.6 * math.sin(t * 2)

	-- whirlpool: strands rising from the floor to above the head
	local height = (pos.Y + 3.4) - g
	for _, s in ipairs(k.strands) do
		local n = #s.segs
		for i, seg in ipairs(s.segs) do
			local u = (i - 1) / (n - 1)
			local a = s.phase + u * math.pi * 3.2 - t * 3.2
			local r = 2.7 - u * 1.1 + math.sin(t * 2 + u * 6) * 0.08
			local y = g + 0.2 + u * height
			local p = Vector3.new(pos.X + math.cos(a) * r, y, pos.Z + math.sin(a) * r)
			-- tangent along the helix so each piece lies along the flow
			-- sized to the gap to the next piece so the strand reads as one
			-- continuous ribbon of water, not a scatter of blocks
			local un = i / (n - 1)
			local an2 = s.phase + un * math.pi * 3.2 - t * 3.2
			local rn2 = 2.7 - un * 1.1
			local p2 = Vector3.new(pos.X + math.cos(an2) * rn2, g + 0.2 + un * height, pos.Z + math.sin(an2) * rn2)
			local gap = (p2 - p).Magnitude
			seg.Size = Vector3.new(0.26 - u * 0.14, 0.1, gap + 0.12)
			k:place(seg, CFrame.lookAt((p + p2) / 2, p2))
			seg.Transparency = 0.1 + u * 0.5 + 0.08 * math.sin(t * 5 + i)
		end
	end

	-- crest: a travelling wave around the waist
	local cn = #k.crest
	for i, c in ipairs(k.crest) do
		local a = (i / cn) * math.pi * 2 + t * 0.9
		local wave = math.sin(a * 3 - t * 4)
		local r = 3.1 + wave * 0.15
		local cf = AuraKit.ringCF(Vector3.new(pos.X, pos.Y - 0.6 + wave * 0.45, pos.Z), a, r)
		k:place(c, cf * CFrame.Angles(math.rad(-20) * wave, 0, 0))
		c.Size = Vector3.new(0.1, 0.08 + (wave + 1) * 0.12, (math.pi * 2 * r) / cn * 0.9)
		c.Transparency = 0.15 + (1 - (wave + 1) / 2) * 0.6
	end

	-- ripples: rings expanding outward, staggered
	for ri, ring in ipairs(k.ripples) do
		local life = ((t * 0.55) + ri / #k.ripples) % 1
		local r = 1 + life * 5.2
		local n = #ring
		for i, seg in ipairs(ring) do
			k:place(seg, AuraKit.ringCF(Vector3.new(pos.X, g + 0.06, pos.Z), (i / n) * math.pi * 2 + ri, r))
			seg.Size = Vector3.new(0.12 * (1 - life) + 0.04, 0.05, (math.pi * 2 * r) / n * 0.6)
			seg.Transparency = 0.1 + life * 0.9
		end
	end

	-- droplets
	for i, d in ipairs(k.drops) do
		local a = d.phase + t * d.speed
		local tilt = CFrame.Angles(d.tilt, d.phase, 0)
		local off = tilt:VectorToWorldSpace(Vector3.new(math.cos(a) * 2.3, 0, math.sin(a) * 2.3))
		k:place(d.p, CFrame.new(pos + Vector3.new(0, 0.4, 0) + off))
	end
end

function Tide.new(character)
	local k = AuraKit.new(character, "TideAura", update)
	if not k then return nil end

	k.light = Instance.new("PointLight")
	k.light.Color = AQUA
	k.light.Range = 16
	k.light.Shadows = false
	k.light.Parent = k.core

	k.strands = {}
	local per = AuraKit.count(30, 16)
	for s = 1, 2 do
		local segs = {}
		for i = 1, per do
			local u = (i - 1) / (per - 1)
			segs[i] = k:part({
				Name = "Whirl",
				Size = Vector3.new(0.34 - u * 0.2, 0.16, 1.2 - u * 0.4),
				Color = (i % 4 == 0) and FOAM or ((s == 1) and AQUA or TEAL),
				Material = Enum.Material.Neon,
			})
		end
		k.strands[s] = { segs = segs, phase = (s - 1) * math.pi }
	end

	k.crest = {}
	for i = 1, AuraKit.count(28, 14) do
		k.crest[i] = k:part({ Name = "Crest", Size = Vector3.new(0.1, 0.2, 0.9), Color = (i % 3 == 0) and FOAM or AQUA })
	end

	k.ripples = {}
	for ri = 1, 3 do
		local ring = {}
		for i = 1, AuraKit.count(20, 12) do
			ring[i] = k:part({ Name = "Ripple", Size = Vector3.new(0.1, 0.05, 0.6), Color = FOAM })
		end
		k.ripples[ri] = ring
	end

	k.drops = {}
	for i = 1, AuraKit.count(5, 3) do
		local p = k:part({ Name = "Droplet", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.34, Color = FOAM })
		k:trail(p, ColorSequence.new(FOAM, AQUA), 0.35, 0.14)
		k.drops[i] = { p = p, phase = i * 1.3, speed = 2 + (i % 3) * 0.6, tilt = math.rad(15 + i * 22) }
	end

	-- bubbles
	k:emitter(k.core, {
		Texture = AuraKit.SPARK,
		Color = ColorSequence.new(FOAM, AQUA),
		LightEmission = 0.6,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.2, 0.7),
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(1, 2.5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 3, 0),
		Drag = 1.2,
		Rate = AuraKit.lowGraphics() and 8 or 20,
	})
	-- mist at the feet
	k.foot = k:part({ Name = "Foot", Size = Vector3.one * 0.2, Transparency = 1 })
	k:emitter(k.foot, {
		Texture = AuraKit.SMOKE,
		Color = ColorSequence.new(FOAM, TEAL),
		LightEmission = 0.4,
		Size = NumberSequence.new(2, 5),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.4, 2),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(80, 80),
		Rate = AuraKit.lowGraphics() and 3 or 7,
	})
	k.splash = k:emitter(k.foot, {
		Texture = AuraKit.SPARK,
		Color = ColorSequence.new(FOAM, AQUA),
		LightEmission = 0.8,
		Size = NumberSequence.new(0.35, 0),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(65, 65),
		Acceleration = Vector3.new(0, -30, 0),
		Rate = 0,
	})
	k.onLand = function(self) self.splash:Emit(AuraKit.lowGraphics() and 14 or 30) end
	return k
end

return Tide
