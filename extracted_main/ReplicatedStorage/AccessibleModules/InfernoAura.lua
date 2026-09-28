--==================================================
-- INFERNO AURA  (Legendary -- client, built in code)
--
--   BODY FIRE   real flame particles pouring off your feet and hands
--   MANTLE      tongues of fire standing round your shoulders, each
--               flickering to its own rhythm
--   MOLTEN RING a glowing ring on the floor with cracks running out
--               of it, burning hotter and cooler
--   FIREBALLS   three fireballs on a figure-eight orbit, trailing flame
--   ERUPTION    every few seconds (and when you land) a ring of fire
--               bursts out across the ground with a shower of embers
--==================================================

local AuraKit = require(script.Parent:WaitForChild("AuraKit"))

local HOT   = Color3.fromRGB(255, 196, 70)
local FLAME = Color3.fromRGB(255, 110, 20)
local RED   = Color3.fromRGB(205, 30, 10)
local COAL  = Color3.fromRGB(60, 16, 8)

local Inferno = {}

local function flicker(t, seed)
	return 0.5 + 0.25 * math.sin(t * 11 + seed) + 0.25 * math.sin(t * 17.3 + seed * 2.1)
end

local function update(k, dt, t)
	local rcf = k.root.CFrame
	local pos = rcf.Position
	local g = k.groundY
	k:place(k.core, CFrame.new(pos))
	k:place(k.foot, CFrame.new(pos.X, g + 0.2, pos.Z))
	k.light.Brightness = 2 + flicker(t, 0) * 1.5 + k.erupt * 3

	if t >= k.nextErupt then
		k.nextErupt = t + 5
		k.erupt = 1
		k.burst:Emit(AuraKit.lowGraphics() and 20 or 45)
	end
	k.erupt = math.max(0, k.erupt - dt * 1.3)

	-- mantle: real flames on the shoulders, roaring harder on a jump
	for _, e in ipairs(k.mantle) do
		e.Rate = (AuraKit.lowGraphics() and 10 or 26) * (1 + k.flare + k.erupt)
	end

	-- molten ring + cracks
	local gp = Vector3.new(pos.X, g + 0.07, pos.Z)
	local rn = #k.ring
	for i, seg in ipairs(k.ring) do
		local a = (i / rn) * math.pi * 2 + t * 0.25
		k:place(seg, AuraKit.ringCF(gp, a, 3.3))
		local f = flicker(t * 0.4, i)
		seg.Color = FLAME:Lerp(HOT, f)
		seg.Transparency = 0.05 + (1 - f) * 0.3
	end
	for i, c in ipairs(k.cracks) do
		local a = c.a + t * 0.25
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local len = c.len * (0.8 + 0.2 * math.sin(t * 2 + i)) + k.erupt * 1.2
		local mid = gp + dir * (3.3 + len / 2)
		c.p.Size = Vector3.new(0.14, 0.05, len)
		k:place(c.p, CFrame.lookAt(mid, mid + dir))
		c.p.Transparency = 0.1 + 0.4 * (1 - flicker(t * 0.6, i * 3))
	end

	-- eruption shockwave ring
	local er = k.erupt
	local wr = 1 + (1 - er) * 7
	local wn = #k.wave
	for i, seg in ipairs(k.wave) do
		if er <= 0 then
			seg.Transparency = 1
		else
			k:place(seg, AuraKit.ringCF(Vector3.new(pos.X, g + 0.2, pos.Z), (i / wn) * math.pi * 2, wr))
			seg.Size = Vector3.new(0.3 * er + 0.05, 0.6 * er + 0.05, (math.pi * 2 * wr) / wn * 0.8)
			seg.Transparency = 1 - er
		end
	end

	-- fireballs on a figure-eight
	for i, fb in ipairs(k.balls) do
		local a = t * 1.7 + fb.phase
		local off = Vector3.new(math.sin(a) * 2.6, 0.6 + math.sin(a * 2) * 0.9, math.sin(a) * math.cos(a) * 2.6)
		off = CFrame.Angles(0, fb.phase + t * 0.3, 0):VectorToWorldSpace(off)
		k:place(fb.p, CFrame.new(pos + off))
		fb.p.Size = Vector3.one * (0.45 + flicker(t, i * 5) * 0.2)
	end
end

function Inferno.new(character)
	local k = AuraKit.new(character, "InfernoAura", update)
	if not k then return nil end
	k.nextErupt = 3
	k.erupt = 0

	k.light = Instance.new("PointLight")
	k.light.Color = FLAME
	k.light.Range = 18
	k.light.Shadows = false
	k.light.Parent = k.core

	-- flame mantle: fire pouring up off both shoulders and the back of the
	-- neck. (Neon bars here read as posts sticking out of the head.)
	k.mantle = {}
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso then
		for _, off in ipairs({ Vector3.new(-0.85, 0.75, 0.1), Vector3.new(0.85, 0.75, 0.1), Vector3.new(0, 0.8, 0.45) }) do
			local att = Instance.new("Attachment")
			att.Name = "InfernoMantle"
			att.Position = off
			att.Parent = torso
			table.insert(k.connections, { Disconnect = function() att:Destroy() end })
			table.insert(k.mantle, k:emitter(att, {
				Texture = AuraKit.FIRE,
				Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, HOT), ColorSequenceKeypoint.new(0.45, FLAME), ColorSequenceKeypoint.new(1, RED) }),
				LightEmission = 1,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3), NumberSequenceKeypoint.new(0.5, 1.0), NumberSequenceKeypoint.new(1, 0.15) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.6, 0.25), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.5, 0.8),
				Speed = NumberRange.new(2.5, 4.5),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(18, 18),
				Acceleration = Vector3.new(0, 5, 0),
				Rate = AuraKit.lowGraphics() and 10 or 26,
				RotSpeed = NumberRange.new(-60, 60),
			}))
		end
	end
	k.ring = {}
	for i = 1, AuraKit.count(26, 14) do
		k.ring[i] = k:part({ Name = "Molten", Size = Vector3.new(0.2, 0.06, 0.72), Color = FLAME })
	end
	k.cracks = {}
	for i = 1, AuraKit.count(8, 5) do
		local p = k:part({ Name = "Crack", Size = Vector3.new(0.14, 0.05, 1), Color = FLAME })
		k.cracks[i] = { p = p, a = (i / 8) * math.pi * 2 + math.random() * 0.4, len = 0.8 + math.random() * 1.2 }
	end
	k.wave = {}
	for i = 1, AuraKit.count(24, 12) do
		k.wave[i] = k:part({ Name = "Wave", Size = Vector3.new(0.3, 0.6, 1), Color = HOT, Transparency = 1 })
	end
	k.balls = {}
	for i = 1, AuraKit.count(3, 2) do
		local p = k:part({ Name = "Fireball", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = HOT })
		k:trail(p, ColorSequence.new(HOT, RED), 0.45, 0.22)
		k:emitter(p, {
			Texture = AuraKit.FIRE,
			Color = ColorSequence.new(HOT, RED),
			LightEmission = 1,
			Size = NumberSequence.new(0.6, 0.1),
			Transparency = NumberSequence.new(0.2, 1),
			Lifetime = NumberRange.new(0.25, 0.4),
			Speed = NumberRange.new(0.5, 1),
			Rate = AuraKit.lowGraphics() and 10 or 22,
		})
		k.balls[i] = { p = p, phase = (i / 3) * math.pi * 2 }
	end

	-- body fire from the feet
	k.foot = k:part({ Name = "Foot", Size = Vector3.one * 0.2, Transparency = 1 })
	k:emitter(k.foot, {
		Texture = AuraKit.FIRE,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, HOT), ColorSequenceKeypoint.new(0.5, FLAME), ColorSequenceKeypoint.new(1, RED) }),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(0.6, 1.5), NumberSequenceKeypoint.new(1, 0.3) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 4, 0),
		Rate = AuraKit.lowGraphics() and 14 or 34,
		RotSpeed = NumberRange.new(-90, 90),
	})
	-- hands
	for _, name in ipairs({ "RightHand", "LeftHand", "Right Arm", "Left Arm" }) do
		local hand = character:FindFirstChild(name)
		if hand and hand:IsA("BasePart") then
			local att = Instance.new("Attachment")
			att.Name = "InfernoHand"
			att.Parent = hand
			table.insert(k.connections, { Disconnect = function() att:Destroy() end })
			k:emitter(att, {
				Texture = AuraKit.FIRE,
				Color = ColorSequence.new(HOT, RED),
				LightEmission = 1,
				Size = NumberSequence.new(0.7, 0.1),
				Transparency = NumberSequence.new(0.3, 1),
				Lifetime = NumberRange.new(0.35, 0.6),
				Speed = NumberRange.new(1, 3),
				EmissionDirection = Enum.NormalId.Top,
				Acceleration = Vector3.new(0, 6, 0),
				Rate = AuraKit.lowGraphics() and 8 or 18,
			})
		end
	end
	-- embers and heat smoke
	k:emitter(k.core, {
		Texture = AuraKit.EMBERS,
		Color = ColorSequence.new(HOT, FLAME),
		LightEmission = 1,
		Size = NumberSequence.new(0.3, 0.05),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, 4, 0),
		Drag = 1,
		Rate = AuraKit.lowGraphics() and 10 or 24,
		RotSpeed = NumberRange.new(-200, 200),
	})
	k:emitter(k.core, {
		Texture = AuraKit.SMOKE,
		Color = ColorSequence.new(COAL, Color3.fromRGB(20, 12, 10)),
		LightEmission = 0,
		Size = NumberSequence.new(1.5, 4),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.5, 2.2),
		Speed = NumberRange.new(2, 3),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(20, 20),
		Rate = AuraKit.lowGraphics() and 2 or 5,
	})
	k.burst = k:emitter(k.foot, {
		Texture = AuraKit.EMBERS,
		Color = ColorSequence.new(HOT, RED),
		LightEmission = 1,
		Size = NumberSequence.new(0.45, 0),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(75, 75),
		Acceleration = Vector3.new(0, -12, 0),
		Drag = 2,
		Rate = 0,
	})
	k.onLand = function(self)
		self.erupt = 1
		self.burst:Emit(AuraKit.lowGraphics() and 12 or 26)
	end
	return k
end

return Inferno
