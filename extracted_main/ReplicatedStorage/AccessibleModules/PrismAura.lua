--==================================================
-- PRISM AURA  (Epic -- client, built in code)
--
--   SHARDS     crystal shards on two tilted, counter-rotating orbits,
--              each glowing a different colour that cycles through the
--              spectrum
--   LATTICE    light beams strung shard-to-shard, so the orbit reads as
--              a turning crystal cage
--   APEX       a spinning crystal over your head scattering sparkles
--   SIGIL      two interlocked hexagons on the floor, hue-cycling
--   REFRACT    every few seconds (and on a jump) the shards burst
--              outward in a flash and snap back
--==================================================

local AuraKit = require(script.Parent:WaitForChild("AuraKit"))

local Prism = {}

local function hue(h, s, v)
	return Color3.fromHSV(h % 1, s or 0.75, v or 1)
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, hue(0)), ColorSequenceKeypoint.new(0.17, hue(0.1)),
	ColorSequenceKeypoint.new(0.33, hue(0.17)), ColorSequenceKeypoint.new(0.5, hue(0.35)),
	ColorSequenceKeypoint.new(0.67, hue(0.55)), ColorSequenceKeypoint.new(0.83, hue(0.72)),
	ColorSequenceKeypoint.new(1, hue(0.85)),
})

local function update(k, dt, t)
	local pos = k.root.Position
	k:place(k.core, CFrame.new(pos))

	-- refraction burst clock
	if t >= k.nextBurst then
		k.nextBurst = t + 4.5
		k.burst = 1
		k.flash:Emit(AuraKit.lowGraphics() and 12 or 26)
	end
	k.burst = math.max(0, k.burst - dt * 1.8)
	local push = (k.burst ^ 2) * 1.6 + k.flare * 1.1

	for i, s in ipairs(k.shards) do
		local a = s.phase + t * s.speed * s.dir
		local r = 3 + push + math.sin(t * 1.5 + i) * 0.15
		local orbit = CFrame.Angles(s.tilt, s.yaw, 0)
		local off = orbit:VectorToWorldSpace(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		local p = pos + Vector3.new(0, 0.3 + math.sin(t * 2 + i) * 0.2, 0) + off
		k:place(s.p, CFrame.new(p) * CFrame.Angles(t * 1.3 + i, t * 2 + i, 0.785))
		s.p.Color = hue(s.h + t * 0.12 + 0.08, 0.25, 1)
		s.core.Color = hue(s.h + t * 0.12, 0.8, 1)
		k:place(s.core, CFrame.new(p) * CFrame.Angles(t * 1.3 + i, t * 2 + i, 0.785))
	end
	for _, b in ipairs(k.beams) do
		b.Color = ColorSequence.new(hue(b:GetAttribute("H") + t * 0.12), hue(b:GetAttribute("H") + 0.15 + t * 0.12))
		b.Transparency = NumberSequence.new(0.35 - k.burst * 0.3)
	end

	-- apex crystal over the head
	local head = k.character:FindFirstChild("Head")
	local top = head and (head.Position + Vector3.new(0, head.Size.Y * 0.5 + 1.5, 0)) or (pos + Vector3.new(0, 3.6, 0))
	top += Vector3.new(0, math.sin(t * 2) * 0.15, 0)
	k:place(k.apex, CFrame.new(top) * CFrame.Angles(0, t * 1.6, 0) * CFrame.Angles(0.785, 0, 0.785))
	k:place(k.apexCore, CFrame.new(top) * CFrame.Angles(0, -t * 2.3, 0) * CFrame.Angles(0.785, 0, 0.785))
	k.apex.Color = hue(t * 0.15, 0.5, 1)
	k.apexCore.Color = hue(t * 0.15 + 0.5, 0.6, 1)
	k.light.Color = hue(t * 0.15, 0.6, 1)
	k.light.Brightness = 1.8 + k.burst * 3

	-- sigil
	local g = Vector3.new(pos.X, k.groundY + 0.07, pos.Z)
	for i, e in ipairs(k.hex) do
		local set = (i <= 6) and 0 or 1
		local j = (i - 1) % 6
		local rot = (set == 0) and (t * 0.35) or (-t * 0.35 + math.pi / 6)
		local R = (set == 0) and (3.5 + k.burst * 0.6) or 2.7
		local a1 = rot + j * math.pi / 3
		local a2 = a1 + math.pi / 3
		local p1 = g + Vector3.new(math.cos(a1) * R, 0, math.sin(a1) * R)
		local p2 = g + Vector3.new(math.cos(a2) * R, 0, math.sin(a2) * R)
		e.Size = Vector3.new(0.1, 0.05, (p2 - p1).Magnitude + 0.1)
		k:place(e, CFrame.lookAt((p1 + p2) / 2, p2))
		e.Color = hue(j / 6 + t * 0.1 + set * 0.5, 0.65, 1)
		e.Transparency = 0.15 + 0.3 * (0.5 + 0.5 * math.sin(t * 3 - j))
	end
	for i, d in ipairs(k.glints) do
		local a = (i / #k.glints) * math.pi * 2 + t * 0.35
		k:place(d, CFrame.new(g + Vector3.new(math.cos(a) * 3.5, 0.08, math.sin(a) * 3.5)) * CFrame.Angles(0, t * 2, 0))
	end
end

function Prism.new(character)
	local k = AuraKit.new(character, "PrismAura", update)
	if not k then return nil end
	k.nextBurst = 2.5
	k.burst = 0

	k.light = Instance.new("PointLight")
	k.light.Range = 18
	k.light.Shadows = false
	k.light.Parent = k.core

	k.shards = {}
	local count = AuraKit.count(8, 5)
	for i = 1, count do
		local ring = (i % 2 == 0) and 1 or 2
		-- a slim neon crystal inside a shimmering force-field sheath. (Glass
		-- read as matte coloured blocks and buried the glow.)
		local shell = k:part({
			Name = "Shard", Size = Vector3.new(0.36, 1.25, 0.36),
			Material = Enum.Material.ForceField, Transparency = 0,
		})
		local core = k:part({ Name = "ShardCore", Size = Vector3.new(0.16, 1.0, 0.16), Transparency = 0 })
		local att = k:attachment(core)
		k.shards[i] = {
			p = shell, core = core, att = att, h = i / count,
			phase = (i / count) * math.pi * 2, speed = 1.1, dir = (ring == 1) and 1 or -1,
			tilt = (ring == 1) and math.rad(22) or math.rad(-28), yaw = (ring == 1) and 0 or math.rad(60),
		}
	end
	-- lattice: beam from each shard to the next one on the same orbit
	k.beams = {}
	for i, s in ipairs(k.shards) do
		local nextShard = k.shards[((i + 1) % #k.shards) + 1]
		if nextShard then
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = s.att, nextShard.att
			b.Width0, b.Width1 = 0.12, 0.12
			b.FaceCamera = true
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Segments = 1
			b:SetAttribute("H", s.h)
			b.Parent = s.core
			table.insert(k.beams, b)
		end
	end

	k.apex = k:part({ Name = "Apex", Size = Vector3.one * 0.8, Material = Enum.Material.ForceField, Transparency = 0 })
	k.apexCore = k:part({ Name = "ApexCore", Size = Vector3.one * 0.42, Transparency = 0 })
	k:emitter(k.apexCore, {
		Texture = AuraKit.SPARK,
		Color = RAINBOW,
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -3, 0),
		Rate = AuraKit.lowGraphics() and 8 or 18,
		RotSpeed = NumberRange.new(-200, 200),
	})

	k.hex = {}
	for i = 1, 12 do
		k.hex[i] = k:part({ Name = "Hex", Size = Vector3.new(0.14, 0.05, 1.8) })
	end
	k.glints = {}
	for i = 1, 6 do
		k.glints[i] = k:part({ Name = "Glint", Size = Vector3.new(0.3, 0.08, 0.3), Color = Color3.new(1, 1, 1) })
	end

	-- glitter around the body
	k:emitter(k.core, {
		Texture = AuraKit.SPARK,
		Color = RAINBOW,
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.25), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Rate = AuraKit.lowGraphics() and 8 or 20,
		RotSpeed = NumberRange.new(-200, 200),
	})
	-- refraction flash
	k.flash = k:emitter(k.core, {
		Texture = AuraKit.SPARK,
		Color = RAINBOW,
		LightEmission = 1,
		Size = NumberSequence.new(0.5, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(10, 18),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		Rate = 0,
	})
	k.onJump = function(self) self.flash:Emit(AuraKit.lowGraphics() and 8 or 16) end
	return k
end

return Prism
