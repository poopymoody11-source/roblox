-- ModuleScript | ServerStorage.BossAttacks.Melee
-- Backhand sweep. Three beats:
--   1. Wind-up: the arm is hauled back in slow motion, energy pours into both hands, the boss
--      flashes and the swing zone lights up on the floor, pulsing faster as the hit gets close.
--   2. Snap: the animation jumps to full speed and the arm whips across the map.
--   3. Impact: a shockwave ring races out from the boss's side, the floor splits, dust and
--      light pillars go up, the camera jolts, and everyone in the zone is launched.
local ServerStorage = game:GetService("ServerStorage")
local Util = require(ServerStorage:WaitForChild("BossUtil"))

local swingAnimation = script.Parent:WaitForChild("Anims"):WaitForChild("Swing")

local Melee = {}

Melee.Defaults = {
	Damage = 40,
	Radius = 150,          -- studs from Origin. Everyone inside gets hit.
	Origin = "Boss",       -- "Boss": radius measured from the boss's root part. "Arena": from the map's center.
	HitMarker = "Hit",     -- animation event name for the moment the arm crosses the map
	HitDelay = 1.15,       -- with no marker in the animation, hit this many seconds after it starts
	KnockbackSpeed = 180,
	KnockbackLift = 180,
	KnockbackTime = 0.7,
	Recovery = 1.0,
	Telegraph = true,      -- pulsing floor footprint, clipped to the arena disc
	WindupSpeed = 0.4,     -- animation speed while the arm is drawn back
	SnapAt = 0.62,         -- fraction of HitDelay at which the arm snaps to SnapSpeed
	SnapSpeed = 1.6,
	RecoverySpeed = 0.55,  -- heavy follow-through
	ChargeColor = Util.EMBER,
	ImpactColor = Util.GOLD,
	Shake = 2.4,
}

local function getOrigin(boss, p)
	if p.Origin == "Arena" then
		return boss.Arena.Center
	end
	return boss.Root.Position
end

function Melee.CanUse(boss, dist, p)
	return #Util.TargetsInRadius(boss, getOrigin(boss, p), p.Radius) > 0
end

local function impact(boss, origin, p)
	local arena = boss.Arena
	local floorOrigin = Util.FloorPoint(arena, origin)

	-- where the wave first touches the arena: the nearest floor point to the boss
	local toBoss = Vector3.new(origin.X - arena.Center.X, 0, origin.Z - arena.Center.Z)
	local edge = if toBoss.Magnitude > arena.Radius
		then arena.Center + toBoss.Unit * (arena.Radius - 6)
		else origin
	edge = Util.FloorPoint(arena, edge)
	local inward = -toBoss.Unit
	local inwardAngle = math.atan2(inward.Z, inward.X)

	-- two stacked rings: a fat bright one and a thin white one just behind it
	Util.Ring(boss, floorOrigin, { From = 20, To = p.Radius + 25, Time = 0.45, Color = p.ImpactColor, Thickness = 9, Height = 7, Segments = 44 })
	task.delay(0.08, function()
		Util.Ring(boss, floorOrigin, { From = 10, To = p.Radius + 5, Time = 0.55, Color = Util.WHITE, Thickness = 3, Height = 2, Segments = 44 })
	end)

	Util.Cracks(boss, edge, { Count = 6, Length = p.Radius * 0.75, Width = 5, Angle = inwardAngle, Spread = math.rad(130), Color = p.ImpactColor, Time = 2.2 })
	Util.Sparks(boss, edge + Vector3.new(0, 4, 0), { Color = Util.WHITE, EndColor = p.ImpactColor, Count = 60, Speed = 140, Size = 7, Lifetime = 1.1, Spread = 70, Direction = inward + Vector3.new(0, 0.6, 0) })

	-- dust + light pillars along the band the arm swept
	for i = 1, 5 do
		local side = (i - 3) / 2
		local lateral = Vector3.new(-inward.Z, 0, inward.X) * side * p.Radius * 0.55
		local spot = edge + inward * math.random(10, math.floor(p.Radius * 0.55)) + lateral
		if Util.OnArena(arena, spot, 4) then
			task.delay(i * 0.035, function()
				Util.Dust(boss, spot, { Count = 10, Size = 30 })
				Util.Pillar(boss, spot, { Height = math.random(60, 110), Radius = math.random(6, 11), Color = p.ImpactColor, Time = 0.6 })
			end)
		end
	end

	Util.Shake(edge, p.Shake, 0.8, p.Radius * 6)
	Util.Sound(boss, edge, Util.METEOR_SOUND, 2.4, 0.72)
	Util.FlashBoss(boss, p.ImpactColor, 0.35)
end

function Melee.Execute(boss, target, isCancelled, p)
	local track = boss:GetTrack(swingAnimation)
	local origin = getOrigin(boss, p)
	local zone

	if p.Telegraph then
		zone = Util.FloorZone(boss, origin, p.Radius, p.HitDelay + 0.1, p.ChargeColor)
	end

	-- wind-up: slow haul back, hands charge up, low rumble
	track:Play(0.2, 1, p.WindupSpeed)
	local stops = {
		Util.Charge(boss, boss.Model:FindFirstChild("RightHand"), { Color = p.ChargeColor, Size = 18, Reach = 120, RampTime = p.HitDelay }),
		Util.Charge(boss, boss.Model:FindFirstChild("LeftHand"), { Color = p.ChargeColor, Size = 18, Reach = 120, RampTime = p.HitDelay }),
	}
	Util.FlashBoss(boss, p.ChargeColor, p.HitDelay * 0.6)
	Util.Sound(boss, origin, Util.METEOR_SOUND, 1.2, 0.38)

	local reachedMarker, snapped = false, false
	local connection = track:GetMarkerReachedSignal(p.HitMarker):Connect(function()
		reachedMarker = true
	end)
	local started = os.clock()
	while not reachedMarker and os.clock() - started < p.HitDelay and not isCancelled() do
		if not snapped and os.clock() - started >= p.HitDelay * p.SnapAt then
			snapped = true
			track:AdjustSpeed(p.SnapSpeed) -- the arm whips across
			for _, stop in stops do stop() end
		end
		task.wait()
	end
	connection:Disconnect()
	for _, stop in stops do stop() end

	if isCancelled() then
		track:Stop(0.3)
		if zone then zone:Destroy() end
		return
	end
	if zone then zone:Destroy() end

	origin = getOrigin(boss, p)
	impact(boss, origin, p)

	for _, root in Util.TargetsInRadius(boss, origin, p.Radius) do
		local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(p.Damage)
		end

		local away = Vector3.new(root.Position.X - origin.X, 0, root.Position.Z - origin.Z)
		if away.Magnitude < 1 then
			local look = boss.Root.CFrame.LookVector
			away = Vector3.new(look.X, 0, look.Z)
		end
		Util.Sparks(boss, root.Position, { Color = Util.WHITE, EndColor = p.ImpactColor, Count = 18, Speed = 50, Size = 3, Lifetime = 0.5 })
		Util.Knockback(root, away.Unit * p.KnockbackSpeed + Vector3.new(0, p.KnockbackLift, 0), p.KnockbackTime)
	end

	-- follow-through: slow the arm so the weight of the swing reads
	track:AdjustSpeed(p.RecoverySpeed)
	task.wait(p.Recovery)
	if track.IsPlaying then
		track:Stop(0.4)
	end
end

return Melee
