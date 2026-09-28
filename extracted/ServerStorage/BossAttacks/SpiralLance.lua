-- ModuleScript | ServerStorage.BossAttacks.SpiralLance
-- The boss gathers a sun of light over its head, then drives a beam down into the arena and drags
-- it across the floor through the target. The footprint burns; the wake is left split and glowing.
-- The path is drawn on the floor first, so it's always dodgeable by stepping off the line.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ServerStorage = game:GetService("ServerStorage")
local Util = require(ServerStorage:WaitForChild("BossUtil"))

local SpiralLance = {}

SpiralLance.MinRange = 0
SpiralLance.MaxRange = math.huge

SpiralLance.Defaults = {
	Charge = 1.5,          -- seconds the orb grows before the beam fires (path is shown during this)
	SweepTime = 2.8,       -- seconds the beam takes to cross the arena
	SweepLength = 300,     -- studs from start to end of the drag, centred on the target
	BeamRadius = 16,       -- footprint radius; standing inside it burns
	TickDamage = 18,
	TickRate = 0.22,
	Color = Util.GOLD,
	CoreColor = Util.WHITE,
	Recovery = 0.8,
}

local function lerp(a, b, t) return a + (b - a) * t end

local function drawPath(boss, from, to, width, duration, colour)
	local folder = Util.FxFolder(boss, "LancePath")
	local dir = (to - from)
	local length = dir.Magnitude
	if length < 1 then return folder end
	dir = dir.Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local y = boss.Arena.SurfaceY + 0.15
	local dashes = math.floor(length / 12)
	for i = 0, dashes do
		local t = i / dashes
		local centre = from:Lerp(to, t)
		for _, edge in { -1, 1 } do
			local pos = Vector3.new(centre.X, y, centre.Z) + side * edge * width
			if Util.OnArena(boss.Arena, pos, 1) then
				local tile = Util.FxPart(boss, {
					Name = "PathDash", Color = colour, Transparency = 1,
					Size = Vector3.new(1.8, 0.3, 7),
					CFrame = CFrame.lookAt(pos, pos + dir),
					Parent = folder,
				})
				tile:SetAttribute("T", t)
			end
		end
		-- chevrons down the middle pointing the way the beam will travel
		if i % 3 == 0 then
			local pos = Vector3.new(centre.X, y, centre.Z)
			if Util.OnArena(boss.Arena, pos, 1) then
				for _, s in { -1, 1 } do
					local arm = (dir + side * s * 0.9).Unit
					local tile = Util.FxPart(boss, {
						Name = "PathChevron", Color = colour, Transparency = 1,
						Size = Vector3.new(1.6, 0.3, 9),
						CFrame = CFrame.lookAt(pos - arm * 4.5, pos),
						Parent = folder,
					})
					tile:SetAttribute("T", t)
				end
			end
		end
	end
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration and folder.Parent do
			elapsed += RunService.Heartbeat:Wait()
			local u = elapsed / duration
			for _, tile in folder:GetChildren() do
				local t = tile:GetAttribute("T") or 0
				-- a chase light running along the path, faster as it gets closer
				local wave = 0.5 + 0.5 * math.sin((t * 10) - elapsed * (8 + u * 14))
				tile.Transparency = 1 - math.clamp(elapsed / 0.3, 0, 1) * (0.3 + wave * 0.5)
			end
		end
		if folder.Parent then folder:Destroy() end
	end)
	return folder
end

local function makeOrb(boss, at, p)
	local folder = Util.FxFolder(boss, "LanceOrb")
	local core = Util.FxPart(boss, {
		Name = "Core", Shape = Enum.PartType.Ball, Color = p.CoreColor,
		Size = Vector3.one * 2, CFrame = CFrame.new(at), Transparency = 0, Parent = folder,
	})
	local shell = Util.FxPart(boss, {
		Name = "Shell", Shape = Enum.PartType.Ball, Color = p.Color, Material = Enum.Material.ForceField,
		Size = Vector3.one * 4, CFrame = CFrame.new(at), Transparency = 0, Parent = folder,
	})
	local att = Instance.new("Attachment")
	att.Parent = core
	Util.Emitter(att, {
		Texture = Util.SPARK_TEXTURE,
		Color = ColorSequence.new(Util.WHITE, p.Color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 12), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(1, 0.3) }),
		Speed = NumberRange.new(-140, -90),
		Lifetime = NumberRange.new(0.5, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 160,
		Enabled = true,
	})
	local light = Instance.new("PointLight")
	light.Color = p.Color
	light.Range = 120
	light.Brightness = 0
	light.Parent = core

	-- three orbiting rune rings made of segments
	local rings = {}
	for r = 1, 3 do
		local ring = {}
		for s = 1, 14 do
			ring[s] = Util.FxPart(boss, {
				Name = "Rune", Color = if r == 2 then Util.WHITE else p.Color,
				Size = Vector3.new(1.2, 1.2, 3), CFrame = CFrame.new(at), Transparency = 1, Parent = folder,
			})
		end
		rings[r] = ring
	end

	local state = { folder = folder, core = core, shell = shell, light = light, rings = rings, size = 2, at = at, spin = 0 }
	return state
end

local function updateOrb(state, size, dt, glow)
	state.size = size
	state.spin += dt
	state.core.Size = Vector3.one * size * 0.55
	state.shell.Size = Vector3.one * size * (1 + 0.06 * math.sin(state.spin * 18))
	state.light.Brightness = glow * 8
	state.light.Range = 60 + size * 2
	for r, ring in state.rings do
		local radius = size * (0.75 + r * 0.22)
		local tilt = CFrame.Angles(state.spin * (0.6 + r * 0.35), r * 1.1, state.spin * 0.4 * r)
		for s, seg in ring do
			local a = (s / #ring) * math.pi * 2 + state.spin * (r % 2 == 0 and -2.2 or 1.8)
			local local_ = Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			local pos = state.at + (tilt:VectorToWorldSpace(local_))
			local tangent = tilt:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a)))
			seg.Size = Vector3.new(0.6 + size * 0.03, 0.6 + size * 0.03, (math.pi * 2 * radius) / #ring * 0.6)
			seg.CFrame = CFrame.lookAt(pos, pos + tangent)
			seg.Transparency = 1 - glow * 0.9
		end
	end
end

function SpiralLance.Execute(boss, target, isCancelled, p)
	local arena = boss.Arena
	local head = boss.Model:FindFirstChild("Head") or boss.Root
	local towardArena = Vector3.new(arena.Center.X - head.Position.X, 0, arena.Center.Z - head.Position.Z).Unit
	local orbAt = head.Position + Vector3.new(0, head.Size.Y * 0.9 + 30, 0) + towardArena * 40

	-- path: a line through the target, across the boss's line of sight so it reads as a sweep
	local aim = Util.GroundPoint(arena, target.Position, 10)
	local across = Vector3.new(-towardArena.Z, 0, towardArena.X)
	if math.random() < 0.5 then across = -across end
	local tilt = (math.random() - 0.5) * 0.7
	local dir = (across + towardArena * tilt).Unit
	local from = Util.GroundPoint(arena, aim - dir * p.SweepLength / 2, 8)
	local to = Util.GroundPoint(arena, aim + dir * p.SweepLength / 2, 8)

	Util.PlayAnim(boss, "Meteor", 0.25, 1, 0.8)
	Util.FlashBoss(boss, p.Color, p.Charge)
	local path = drawPath(boss, from, to, p.BeamRadius, p.Charge + p.SweepTime + 0.2, p.Color)
	local orb = makeOrb(boss, orbAt, p)
	Util.Sound(boss, orbAt, Util.METEOR_SOUND, 1.4, 0.32)

	local function cleanup()
		if path.Parent then path:Destroy() end
		if orb.folder.Parent then orb.folder:Destroy() end
	end

	-- charge: the orb swells and the rune rings spin up
	local elapsed = 0
	while elapsed < p.Charge do
		if isCancelled() then cleanup() return end
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local u = elapsed / p.Charge
		updateOrb(orb, lerp(4, 38, u ^ 0.7), dt, u)
	end

	-- fire
	Util.FlashBoss(boss, Util.WHITE, 0.3)
	Util.Shake(from, 1.4, 0.4, 500)
	Util.Sound(boss, from, Util.METEOR_SOUND, 2.2, 1.25)
	Util.Pillar(boss, from, { Height = 140, Radius = p.BeamRadius, Color = Util.WHITE, Time = 0.5 })

	local beam = Util.FxPart(boss, {
		Name = "LanceBeam", Shape = Enum.PartType.Cylinder, Color = p.Color,
		Size = Vector3.new(1, 1, 1), Transparency = 0.1, Parent = orb.folder,
	})
	local beamCore = Util.FxPart(boss, {
		Name = "LanceCore", Shape = Enum.PartType.Cylinder, Color = p.CoreColor,
		Size = Vector3.new(1, 1, 1), Transparency = 0, Parent = orb.folder,
	})
	local foot = Util.FxPart(boss, {
		Name = "LanceFoot", Shape = Enum.PartType.Cylinder, Color = p.Color,
		Size = Vector3.new(1.2, p.BeamRadius * 2, p.BeamRadius * 2), Transparency = 0.2, Parent = orb.folder,
	})
	local footAtt = Instance.new("Attachment")
	footAtt.Parent = foot
	local spray = Util.Emitter(footAtt, {
		Texture = Util.SPARK_TEXTURE,
		Color = ColorSequence.new(Util.WHITE, p.Color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Speed = NumberRange.new(40, 110),
		Lifetime = NumberRange.new(0.4, 0.9),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -120, 0),
		Drag = 2,
		EmissionDirection = Enum.NormalId.Right, -- the foot is a cylinder turned upright: +X is up
		Rate = 140,
		Enabled = true,
	})
	local smoke = Util.Emitter(footAtt, {
		Texture = Util.SMOKE_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 170), Color3.fromRGB(90, 70, 60)),
		LightEmission = 0.3,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 30) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Speed = NumberRange.new(10, 30),
		Lifetime = NumberRange.new(1, 1.6),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Right,
		Rate = 25,
		Enabled = true,
	})

	local upright = CFrame.Angles(0, 0, math.rad(90))
	local tickClock, crackClock = 0, 0
	elapsed = 0
	while elapsed < p.SweepTime do
		if isCancelled() then cleanup() return end
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		tickClock += dt
		crackClock += dt
		local u = elapsed / p.SweepTime
		local eased = u * u * (3 - 2 * u)
		local ground = from:Lerp(to, eased)
		ground = Vector3.new(ground.X, arena.SurfaceY, ground.Z)

		updateOrb(orb, 38 + math.sin(elapsed * 30) * 2, dt, 1)

		local span = orbAt - ground
		local mid = (orbAt + ground) / 2
		local flicker = 1 + math.sin(elapsed * 55) * 0.12
		local width = p.BeamRadius * 1.3 * flicker
		beam.Size = Vector3.new(span.Magnitude, width, width)
		beam.CFrame = CFrame.lookAt(mid, orbAt) * CFrame.Angles(0, math.rad(90), 0)
		beamCore.Size = Vector3.new(span.Magnitude, width * 0.45, width * 0.45)
		beamCore.CFrame = beam.CFrame
		foot.CFrame = CFrame.new(ground + Vector3.new(0, 0.6, 0)) * upright
		foot.Size = Vector3.new(1.2, p.BeamRadius * 2.4 * flicker, p.BeamRadius * 2.4 * flicker)

		if tickClock >= p.TickRate then
			tickClock = 0
			for _, root in Util.TargetsInRadius(boss, ground, p.BeamRadius) do
				local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:TakeDamage(p.TickDamage)
					Util.Sparks(boss, root.Position, { Color = Util.WHITE, EndColor = p.Color, Count = 10, Speed = 40, Size = 3, Lifetime = 0.4 })
				end
			end
		end
		if crackClock >= 0.3 then
			crackClock = 0
			Util.Cracks(boss, ground, { Count = 3, Length = 26, Width = 3, Color = p.Color, Time = 2.6 })
			Util.Ring(boss, ground, { From = p.BeamRadius * 0.5, To = p.BeamRadius * 2.6, Time = 0.35, Color = p.Color, Thickness = 2.5, Height = 1.5, Segments = 18 })
			Util.Shake(ground, 0.5, 0.25, 250)
		end
	end

	-- the beam cuts out and the orb collapses in a flash
	spray.Enabled = false
	smoke.Enabled = false
	beam:Destroy()
	beamCore:Destroy()
	Util.Pillar(boss, to, { Height = 160, Radius = p.BeamRadius * 1.3, Color = Util.WHITE, Time = 0.6 })
	Util.Ring(boss, to, { From = 6, To = 90, Time = 0.5, Color = p.Color, Thickness = 6, Height = 4 })
	Util.Sparks(boss, orbAt, { Color = Util.WHITE, EndColor = p.Color, Count = 70, Speed = 160, Size = 9, Lifetime = 1, Gravity = 20 })
	Util.Sound(boss, orbAt, Util.METEOR_SOUND, 1.6, 1.5)
	for _, part in orb.folder:GetChildren() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Size = Vector3.one * 0.1, Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(orb.folder, 1.2)
	if path.Parent then path:Destroy() end

	task.wait(p.Recovery)
end

return SpiralLance
