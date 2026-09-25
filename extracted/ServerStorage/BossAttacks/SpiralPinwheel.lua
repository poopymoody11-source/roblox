-- ModuleScript | ServerStorage.BossAttacks.SpiralPinwheel
-- The boss hurls a spinning core over the middle of the arena. It hovers, winds up, then spins
-- arms of energy orbs out across the floor like the hands of a clock -- a rotating spiral of shots
-- you dodge by moving with the rotation between the arms. It ends by imploding in a burst.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ServerStorage = game:GetService("ServerStorage")
local Util = require(ServerStorage:WaitForChild("BossUtil"))
local ProjectileTypes = require(ServerStorage:WaitForChild("BossProjectileTypes"))

local SpiralPinwheel = {}

SpiralPinwheel.MinRange = 0
SpiralPinwheel.MaxRange = math.huge

SpiralPinwheel.Defaults = {
	Arms = 4,
	Volleys = 10,          -- shots per arm
	VolleyGap = 0.22,      -- seconds between rings of shots
	TurnPerVolley = 11,    -- degrees the arms rotate between volleys
	HoverHeight = 55,      -- core height above the floor
	Tilt = 16,             -- degrees the shots aim downward, so they land across the arena
	Windup = 1.0,
	Type = "EnergyOrb",
	DamageMultiplier = 0.8,
	Color = Util.VIOLET,
	Recovery = 0.7,
}

local function buildCore(boss, at, colour)
	local folder = Util.FxFolder(boss, "PinwheelCore")
	local core = Util.FxPart(boss, {
		Name = "Core", Shape = Enum.PartType.Ball, Color = Util.WHITE,
		Size = Vector3.one * 7, CFrame = CFrame.new(at), Parent = folder,
	})
	local shell = Util.FxPart(boss, {
		Name = "Shell", Shape = Enum.PartType.Ball, Color = colour, Material = Enum.Material.ForceField,
		Size = Vector3.one * 16, CFrame = CFrame.new(at), Parent = folder,
	})
	local att = Instance.new("Attachment")
	att.Parent = core
	local trail = Util.Emitter(att, {
		Texture = Util.SPARK_TEXTURE,
		Color = ColorSequence.new(Util.WHITE, colour),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Speed = NumberRange.new(4, 18),
		Lifetime = NumberRange.new(0.5, 0.9),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 90,
		Enabled = true,
	})
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = 90
	light.Brightness = 5
	light.Parent = core

	-- blades: flat neon vanes that spin with the arms so the rotation is readable
	local blades = {}
	for i = 1, 8 do
		blades[i] = Util.FxPart(boss, {
			Name = "Vane", Color = if i % 2 == 0 then Util.WHITE else colour,
			Size = Vector3.new(2.2, 0.8, 18), CFrame = CFrame.new(at), Transparency = 0.2, Parent = folder,
		})
	end
	return { folder = folder, core = core, shell = shell, blades = blades, trail = trail, light = light }
end

local function poseCore(c, at, angle, scale, t)
	c.core.CFrame = CFrame.new(at)
	c.core.Size = Vector3.one * 7 * scale
	c.shell.CFrame = CFrame.new(at)
	c.shell.Size = Vector3.one * (16 + math.sin(t * 14) * 1.5) * scale
	for i, blade in c.blades do
		local a = angle + (i / #c.blades) * math.pi * 2
		local reach = (i % 2 == 0 and 14 or 20) * scale
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = at + dir * reach
		blade.Size = Vector3.new(2.2 * scale, 0.8, 18 * scale)
		blade.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, math.rad(25))
	end
end

function SpiralPinwheel.Execute(boss, target, isCancelled, p)
	local arena = boss.Arena
	local def = ProjectileTypes[p.Type]
	if not def then
		warn("SpiralPinwheel: no projectile type", p.Type)
		return
	end

	local hand = boss.Model:FindFirstChild("RightHand") or boss.Root
	local hover = Vector3.new(arena.Center.X, arena.SurfaceY + p.HoverHeight, arena.Center.Z)

	-- throw: charge in the hand, then the core arcs over to the middle of the arena
	Util.PlayAnim(boss, "Throw", 0.15, 1, 0.9)
	local stop = Util.Charge(boss, hand, { Color = p.Color, Size = 16, Reach = 110, RampTime = 0.5 })
	task.wait(0.55)
	stop()
	if isCancelled() then return end

	local c = buildCore(boss, hand.Position, p.Color)
	local start = hand.Position
	local flight, elapsed = 0.75, 0
	local angle = math.random() * math.pi * 2
	Util.Sound(boss, start, Util.METEOR_SOUND, 1, 1.6)
	while elapsed < flight do
		if isCancelled() then c.folder:Destroy() return end
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local u = math.min(elapsed / flight, 1)
		local pos = start:Lerp(hover, u) + Vector3.new(0, math.sin(u * math.pi) * 120, 0)
		angle += dt * 9
		poseCore(c, pos, angle, 0.6 + u * 0.4, elapsed)
	end

	-- arrival: a slam of light straight down and a warning ring the width of the pattern
	Util.Pillar(boss, hover, { Height = p.HoverHeight + 30, Radius = 12, Color = p.Color, Time = 0.5 })
	Util.Ring(boss, hover, { From = 10, To = arena.Radius, Time = 0.7, Color = p.Color, Thickness = 4, Height = 2 })
	Util.Shake(hover, 0.9, 0.35, 400)
	local zone = Util.FloorZone(boss, hover, 40, p.Windup + p.Volleys * p.VolleyGap, p.Color)

	elapsed = 0
	while elapsed < p.Windup do
		if isCancelled() then c.folder:Destroy() zone:Destroy() return end
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local spin = 3 + (elapsed / p.Windup) * 10
		angle += dt * spin
		poseCore(c, hover + Vector3.new(0, math.sin(elapsed * 6) * 2, 0), angle, 1 + elapsed / p.Windup * 0.25, elapsed)
	end

	-- the spiral
	local armAngle = angle
	local tilt = math.rad(p.Tilt)
	for v = 1, p.Volleys do
		if isCancelled() then break end
		for a = 1, p.Arms do
			local theta = armAngle + (a / p.Arms) * math.pi * 2
			local flat = Vector3.new(math.cos(theta), 0, math.sin(theta))
			local dirn = (flat * math.cos(tilt) - Vector3.new(0, math.sin(tilt), 0)).Unit
			Util.FireProjectile(boss, def, {
				Position = hover + flat * 12,
				Direction = dirn,
				DamageMultiplier = p.DamageMultiplier,
				Lifetime = 5,
				ExplodeOnFloor = true,
			})
		end
		Util.Sparks(boss, hover, { Color = Util.WHITE, EndColor = p.Color, Count = 12, Speed = 70, Size = 4, Lifetime = 0.5, Gravity = 0 })
		armAngle += math.rad(p.TurnPerVolley)

		local gapLeft = p.VolleyGap
		while gapLeft > 0 do
			local dt = RunService.Heartbeat:Wait()
			gapLeft -= dt
			angle += dt * 13
			poseCore(c, hover, angle, 1.25, os.clock())
		end
	end
	if zone.Parent then zone:Destroy() end

	-- implosion: shrink hard, then burst
	for _, part in c.folder:GetChildren() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Size = Vector3.one * 0.2 }):Play()
		end
	end
	task.wait(0.25)
	c.trail.Enabled = false
	for _, part in c.folder:GetChildren() do
		if part:IsA("BasePart") then part.Transparency = 1 end
	end
	Debris:AddItem(c.folder, 1)
	if boss.Alive then
		Util.Sparks(boss, hover, { Color = Util.WHITE, EndColor = p.Color, Count = 90, Speed = 180, Size = 10, Lifetime = 1.1, Gravity = 30 })
		Util.Ring(boss, hover, { From = 6, To = 120, Time = 0.5, Color = Util.WHITE, Thickness = 5, Height = 3 })
		Util.Shake(hover, 1.2, 0.4, 400)
		Util.Sound(boss, hover, Util.METEOR_SOUND, 1.8, 1.3)
	end

	task.wait(p.Recovery)
end

return SpiralPinwheel
