-- ModuleScript | ServerStorage.BossUtil
-- Shared helpers for the attack modules. Everything spawned here goes into boss.Effects.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Util = {}

-- ------------------------------------------------------------------------------------------
-- Screen shake + positional sound (used by meteor impacts and anything else that wants them)
-- ------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shakeRemote = ReplicatedStorage:FindFirstChild("BossScreenShake")
if not shakeRemote then
	shakeRemote = Instance.new("RemoteEvent")
	shakeRemote.Name = "BossScreenShake"
	shakeRemote.Parent = ReplicatedStorage
end

-- Shakes every player's camera; strongest at `point`, fading out to nothing at `range` studs.
-- (the client side lives in StarterPlayerScripts > BossScreenShakeClient)
function Util.Shake(point, intensity, duration, range)
	shakeRemote:FireAllClients(point, intensity or 1, duration or 0.5, range or 200)
end

-- One-off 3D sound at a point; cleans itself up
function Util.Sound(boss, point, soundId, volume, speed)
	local holder = Instance.new("Part")
	holder.Name = "SfxHolder"
	holder.Size = Vector3.one * 0.2
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CFrame = CFrame.new(point)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 1
	s.PlaybackSpeed = speed or 1
	s.RollOffMinDistance = 40
	s.RollOffMaxDistance = 600
	s.Parent = holder
	holder.Parent = (boss and boss.Effects) or workspace
	s:Play()
	Debris:AddItem(holder, 6)
end

Util.METEOR_SOUND = "rbxassetid://114743565978001"

local PLAYER_SLOP = 2.5        -- roughly the size of a character around its root part
local DEFLECT_SPEED_MULT = 1.8 -- a batted-back projectile flies this much faster
local DEFLECT_DAMAGE = 60      -- damage to the boss when a batted-back projectile lands (a type's DeflectDamage wins)
local BOSS_HIT_SLOP = 10       -- extra reach around the boss's parts for batted-back projectiles
local DEFLECT_COLOR = Color3.fromRGB(120, 255, 170)

-- Explosion assets that only burst once: their emitters are switched off right after the burst so
-- only the particles already in the air fade out, then the asset is removed. Any other explosion
-- asset is simply removed shortly after its longest particle lifetime.
local ONE_SHOT_EXPLOSIONS = {
	MeteorExplosion = true,
	GalaxyExplosion = true,
}

-- ------------------------------------------------------------------------------------------
-- Arena and players
-- ------------------------------------------------------------------------------------------

-- Snap a point onto the arena floor and keep it inside the disc (margin = studs from the edge)
function Util.GroundPoint(arena, point, margin)
	local flat = Vector3.new(point.X - arena.Center.X, 0, point.Z - arena.Center.Z)
	local maxRadius = arena.Radius - (margin or 0)
	if flat.Magnitude > maxRadius then
		flat = flat.Unit * maxRadius
	end
	return Vector3.new(arena.Center.X + flat.X, arena.SurfaceY, arena.Center.Z + flat.Z)
end

function Util.RandomPointInArena(arena, margin)
	local radius = math.sqrt(math.random()) * math.max(arena.Radius - (margin or 0), 0)
	local angle = math.random() * math.pi * 2
	return Vector3.new(
		arena.Center.X + math.cos(angle) * radius,
		arena.SurfaceY,
		arena.Center.Z + math.sin(angle) * radius
	)
end

-- Every living target within `radius` (flat distance) of `point`
function Util.TargetsInRadius(boss, point, radius)
	local hit = {}
	for _, root in boss:GetTargets() do
		local offset = root.Position - point
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius then
			table.insert(hit, root)
		end
	end
	return hit
end

function Util.DamageInRadius(boss, point, radius, damage)
	for _, root in Util.TargetsInRadius(boss, point, radius) do
		local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(damage)
		end
	end
end

-- Launches a player's character. A client normally simulates its own character, so the server
-- takes over the physics for the duration of the launch; otherwise the push can get ignored.
-- `velocity` is the launch velocity in studs/second, `stunTime` is how long the character stays limp.
function Util.Knockback(root, velocity, stunTime)
	local character = root.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local player = Players:GetPlayerFromCharacter(character)

	task.spawn(function()
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		humanoid.PlatformStand = true -- limp, so walking/friction doesn't eat the launch
		RunService.Heartbeat:Wait()
		root.AssemblyLinearVelocity = velocity

		task.wait(stunTime)

		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
		if player and root.Parent then
			pcall(function()
				root:SetNetworkOwner(player)
			end)
		end
	end)
end

-- Visual only: no knockback, doesn't break joints
function Util.Blast(boss, point, radius)
	local boom = Instance.new("Explosion")
	boom.Position = point
	boom.BlastRadius = radius
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.Parent = boss.Effects
end

-- ------------------------------------------------------------------------------------------
-- Assets from ServerStorage.BossAbilities: cloning, moving and scaling them
-- ------------------------------------------------------------------------------------------

local function getAsset(name)
	local folder = ServerStorage:FindFirstChild("BossAbilities")
	local asset = folder and folder:FindFirstChild(name)
	if not asset then
		warn(("BossUtil: ServerStorage.BossAbilities.%s not found"):format(name))
	end
	return asset
end

-- Anchors everything and turns off collisions so a cloned asset can be moved by script
local function makeInert(instance)
	local function apply(part)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
	end
	if instance:IsA("BasePart") then
		apply(instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			apply(descendant)
		end
	end
end
Util.MakeInert = makeInert

local function extentsRadius(instance)
	local size = if instance:IsA("Model") then instance:GetExtentsSize() else instance.Size
	return math.max(size.X, size.Y, size.Z) / 2
end

-- Scales a freshly-cloned Model (via ScaleTo) or BasePart (via Size) in place, without touching
-- its particle emitters. Doesn't move it: ScaleTo keeps the pivot fixed, and setting Size keeps a
-- part's Position.
local function scaleProjectile(instance, factor)
	if factor == 1 then return end
	if instance:IsA("Model") then
		instance:ScaleTo(factor)
	elseif instance:IsA("BasePart") then
		instance.Size *= factor
	end
end

-- Every keypoint's value and envelope times `factor`; keypoint times are untouched, so each
-- emitter keeps its own unique curve shape, just bigger.
local function scaleSequence(sequence, factor)
	local keypoints = {}
	for i, keypoint in sequence.Keypoints do
		keypoints[i] = NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * factor, keypoint.Envelope * factor)
	end
	return NumberSequence.new(keypoints)
end

-- Size curve, Speed and Acceleration are lengths, so they scale. Lifetime, Rate, Drag, Rotation
-- and the rest are not lengths and stay as authored.
local function scaleEmitter(emitter, factor)
	emitter.Size = scaleSequence(emitter.Size, factor)
	emitter.Speed = NumberRange.new(emitter.Speed.Min * factor, emitter.Speed.Max * factor)
	emitter.Acceleration *= factor
end

local function scaleEmitters(instance, factor)
	for _, item in instance:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			scaleEmitter(item, factor)
		end
	end
end

-- Sum of every emitter Size keypoint under `instance`. Only used to notice whether
-- Model:ScaleTo already scaled the emitters, so we never scale them twice.
local function emitterSizeTotal(instance)
	local total = 0
	for _, item in instance:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			for _, keypoint in item.Size.Keypoints do
				total += keypoint.Value + keypoint.Envelope
			end
		end
	end
	return total
end

-- Scales a freshly-cloned Model or Part AND every ParticleEmitter inside it. Doesn't move it.
local function scaleAsset(instance, factor)
	if factor == 1 then return end

	if instance:IsA("Model") then
		local before = emitterSizeTotal(instance)
		instance:ScaleTo(factor)
		if math.abs(emitterSizeTotal(instance) - before) > 1e-4 then
			return -- ScaleTo already scaled the emitters
		end
	elseif instance:IsA("BasePart") then
		-- setting Size doesn't move a part's attachments, so scale their offsets by hand
		instance.Size *= factor
		for _, item in instance:GetDescendants() do
			if item:IsA("Attachment") then
				item.Position *= factor
			end
		end
	end

	scaleEmitters(instance, factor)
end

-- ------------------------------------------------------------------------------------------
-- Warnings and explosions
-- ------------------------------------------------------------------------------------------

-- Flat warning indicator on the floor using ServerStorage.BossAbilities.MeteorWarning,
-- scaled to `radius`. Removed after `duration` seconds. Doesn't yield.
function Util.Telegraph(boss, point, radius, duration)
	local template = getAsset("MeteorWarning")
	if not template then return end

	local warning = template:Clone()
	makeInert(warning)

	local baseRadius = extentsRadius(template)
	if baseRadius > 0 then
		scaleAsset(warning, radius / baseRadius)
	end

	if warning:IsA("PVInstance") then
		warning:PivotTo(CFrame.new(point + Vector3.new(0, 0.1, 0)))
	end
	warning.Parent = boss.Effects

	Debris:AddItem(warning, duration)
end

-- Clones an explosion asset at `point` and emits every ParticleEmitter in it, using each
-- emitter's "EmitCount" attribute for the particle count (10 if it has none).
-- `scale` (optional) enlarges the asset and its emitters before it plays.
-- Yields, so run it with task.spawn.
function Util.PlayExplosion(boss, assetName, point, scale)
	local template = getAsset(assetName)
	if not template then return end

	local effect = template:Clone()
	local holder = effect
	if effect:IsA("PVInstance") then
		if scale then
			scaleAsset(effect, scale)
		end
		effect:PivotTo(CFrame.new(point))
		makeInert(effect)
	else
		-- a bare Attachment or ParticleEmitter needs a part to sit on
		holder = Instance.new("Part")
		holder.Size = Vector3.one * 0.2
		holder.Transparency = 1
		holder.CFrame = CFrame.new(point)
		makeInert(holder)
		effect.Parent = holder
	end
	holder.Parent = boss.Effects

	task.wait() -- give the clone a frame to replicate before emitting
	if not holder.Parent then return end

	local longest = 1
	for _, item in holder:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			item:Emit(item:GetAttribute("EmitCount") or 10)
			longest = math.max(longest, item.Lifetime.Max)
		end
	end

	if not ONE_SHOT_EXPLOSIONS[assetName] then
		Debris:AddItem(holder, longest + 0.5)
		return
	end

	-- one-shot: stop new particles, let the ones in the air fade out, then remove it
	for _, item in holder:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			item.Enabled = false
		end
	end
	task.wait(longest)
	if holder.Parent then
		holder:Destroy()
	end
end

-- A projectile type exploding at `point`: explosion visual, area damage, then its OnExplode hook.
-- `def` is an entry from BossProjectileTypes.
function Util.Detonate(boss, def, point, damage)
	if not boss.Alive then return end

	if def.Explosion then
		task.spawn(Util.PlayExplosion, boss, def.Explosion, point, def.ExplosionScale)
	elseif def.Explosion == nil then
		Util.Blast(boss, point, def.BlastRadius) -- placeholder until the type gets its own explosion asset
	end -- (Explosion = false means no visual at all)

	local victims = Util.TargetsInRadius(boss, point, def.BlastRadius)
	for _, root in victims do
		local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(damage)
		end
	end

	if def.OnExplode then
		local ok, err = pcall(def.OnExplode, {
			Boss = boss,
			Def = def,
			Position = point,
			Victims = victims, -- root parts of the players caught in the blast
			Damage = damage,
		})
		if not ok then
			warn("Projectile OnExplode error:", err)
		end
	end
end

-- ------------------------------------------------------------------------------------------
-- Typed projectiles (see BossProjectileTypes)
-- ------------------------------------------------------------------------------------------

-- Every live projectile, so weapons (the Verity Bat) can find and deflect them.
-- [projectile instance] = state table
Util.ActiveProjectiles = {}

local function bossAimPoint(boss)
	local model = boss.Model
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
	return torso and torso.Position or model:GetPivot().Position
end

-- Bats a projectile back at the boss. Returns true if it was deflected.
function Util.Deflect(projectile, player)
	local state = Util.ActiveProjectiles[projectile]
	if not state or state.deflected or not state.def.Deflectable then return false end

	state.deflected = true
	state.deflectedBy = player
	state.elapsed = 0
	state.lifetime = 6
	state.speed = state.def.Speed * DEFLECT_SPEED_MULT
	local toBoss = bossAimPoint(state.boss) - state.position
	state.direction = if toBoss.Magnitude > 1e-3 then toBoss.Unit else state.direction

	if projectile:IsA("BasePart") then
		projectile.Color = DEFLECT_COLOR
	end
	for _, item in projectile:GetDescendants() do
		if item:IsA("BasePart") then
			item.Color = DEFLECT_COLOR
		elseif item:IsA("ParticleEmitter") then
			item.Color = ColorSequence.new(DEFLECT_COLOR)
		end
	end
	return true
end

-- Fires one projectile of a type from BossProjectileTypes. Doesn't yield.
-- It explodes when it gets near a player, or (optionally) when it reaches the arena floor.
-- The asset's front (-Z / LookVector) points along the flight direction, plus the type's RotationOffset.
-- A deflected projectile flies at the boss instead and damages it on contact.
-- opts: Position, Direction, DamageMultiplier, Lifetime, ExplodeOnFloor
function Util.FireProjectile(boss, def, opts)
	local template = getAsset(def.Template)
	if not template then return end
	-- hard ceiling on live projectiles: a runaway volley can't pile up thousands of parts
	local live = 0
	for _ in Util.ActiveProjectiles do live += 1 end
	if live >= 120 then return end
	if not opts.Direction or opts.Direction.Magnitude < 1e-3 then return end

	local projectile = template:Clone()
	makeInert(projectile)
	if def.RandomScale then
		scaleProjectile(projectile, 1 + math.random() * (def.RandomScale - 1))
	end

	local rotation = CFrame.identity
	if def.RotationOffset then
		local r = def.RotationOffset
		rotation = CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
	end

	local state = {
		boss = boss,
		def = def,
		position = opts.Position,
		direction = opts.Direction.Unit,
		speed = def.Speed,
		elapsed = 0,
		lifetime = opts.Lifetime or 8,
		deflected = false,
	}
	projectile:PivotTo(CFrame.lookAt(state.position, state.position + state.direction) * rotation)
	projectile.Parent = boss.Effects
	Util.ActiveProjectiles[projectile] = state

	local hitRadius = def.HitRadius or extentsRadius(projectile)
	state.radius = hitRadius
	local damage = def.Damage * (opts.DamageMultiplier or 1)
	local arena = boss.Arena
	local connection

	local function cleanup()
		if connection then connection:Disconnect() end
		Util.ActiveProjectiles[projectile] = nil
		projectile:Destroy()
	end

	local function explode(point)
		cleanup()
		Util.Detonate(boss, def, point, damage)
	end

	local function hitBoss(point)
		cleanup()
		if def.Explosion then
			task.spawn(Util.PlayExplosion, boss, def.Explosion, point, def.ExplosionScale)
		end
		local humanoid = boss.Humanoid
		if humanoid and humanoid.Health > 0 and boss.Model:GetAttribute("Invulnerable") ~= true then
			humanoid:TakeDamage(def.DeflectDamage or DEFLECT_DAMAGE)
		end
	end

	connection = RunService.Heartbeat:Connect(function(dt)
		state.elapsed += dt
		if state.elapsed >= state.lifetime or not projectile.Parent then
			cleanup()
			return
		end

		if state.deflected then
			local toAim = bossAimPoint(boss) - state.position
			if toAim.Magnitude > 1e-3 then -- .Unit of a zero vector is NaN and would fling the part to nowhere
				state.direction = state.direction:Lerp(toAim.Unit, math.min(1, dt * 4)).Unit
			end
		end

		state.position += state.direction * state.speed * dt
		local projectileCFrame = CFrame.lookAt(state.position, state.position + state.direction) * rotation
		projectile:PivotTo(projectileCFrame)

		-- A batted-back projectile only looks for the boss; it can't hurt players anymore
		if state.deflected then
			for _, part in boss.Model:GetChildren() do
				if part:IsA("BasePart") then
					local localPos = part.CFrame:PointToObjectSpace(state.position)
					local reach = part.Size / 2 + Vector3.one * (BOSS_HIT_SLOP + hitRadius * 0.5)
					if math.abs(localPos.X) <= reach.X and math.abs(localPos.Y) <= reach.Y and math.abs(localPos.Z) <= reach.Z then
						hitBoss(state.position)
						return
					end
				end
			end
			return
		end

		-- Player contact: a sphere around the projectile, or (with HitHeight) a flat disc oriented like it
		local maxRadius = hitRadius + PLAYER_SLOP
		for _, root in boss:GetTargets() do
			if def.HitHeight == nil then
				if (root.Position - state.position).Magnitude <= maxRadius then
					explode(state.position)
					return
				end
			else
				local localPos = projectileCFrame:PointToObjectSpace(root.Position)
				local flatDist = Vector2.new(localPos.X, localPos.Z).Magnitude
				local maxHeight = (def.HitHeight / 2) + PLAYER_SLOP
				if flatDist <= maxRadius and math.abs(localPos.Y) <= maxHeight then
					explode(state.position)
					return
				end
			end
		end

		-- Floor contact
		if opts.ExplodeOnFloor and state.position.Y <= arena.SurfaceY + 1 then
			local flat = Vector3.new(state.position.X - arena.Center.X, 0, state.position.Z - arena.Center.Z)
			if flat.Magnitude <= arena.Radius then
				explode(Vector3.new(state.position.X, arena.SurfaceY, state.position.Z))
				return
			end
		end
	end)
end

-- ------------------------------------------------------------------------------------------
-- Meteor: BossAbilities.<Template> (a Model) falls onto a telegraphed spot, then
-- BossAbilities.<Explosion> (a Part) plays there. Both are scaled by `Scale`, emitters included.
-- Yields until it lands, so run it with task.spawn if you want to fire several at once.
-- p: Template, Explosion, Scale, Radius (warning disc AND hitbox), Damage, Warning (seconds
--   from spawn to impact), FallHeight (studs above the landing height it starts from)
-- ------------------------------------------------------------------------------------------

local function largestPart(model)
	local best, bestVolume = nil, -1
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local size = descendant.Size
			local volume = size.X * size.Y * size.Z
			if volume > bestVolume then
				best, bestVolume = descendant, volume
			end
		end
	end
	return best
end

function Util.Meteor(boss, point, p)
	local template = getAsset(p.Template)
	if not template then return end

	Util.Telegraph(boss, point, p.Radius, p.Warning)

	local meteor = template:Clone()
	scaleAsset(meteor, p.Scale)
	makeInert(meteor)

	-- Work out where the model's pivot must be so the bottom of its main mesh touches the floor
	local pivot = meteor:GetPivot()
	local mesh = largestPart(meteor)
	local meshBottomY = mesh.Position.Y - mesh.Size.Y / 2
	local landingY = point.Y + (pivot.Position.Y - meshBottomY)

	local orientation = pivot.Rotation
	local landing = Vector3.new(point.X, landingY, point.Z)
	local start = landing + Vector3.new(0, p.FallHeight, 0)

	meteor:PivotTo(CFrame.new(start) * orientation)
	meteor.Parent = boss.Effects

	local elapsed = 0
	while elapsed < p.Warning do
		elapsed += RunService.Heartbeat:Wait()
		if not meteor.Parent or not boss.Alive then
			meteor:Destroy()
			return
		end
		local alpha = math.min(elapsed / p.Warning, 1)
		meteor:PivotTo(CFrame.new(start:Lerp(landing, alpha * alpha)) * orientation)
	end
	meteor:Destroy()

	if boss.Alive then
		Util.DamageInRadius(boss, point, p.Radius, p.Damage)
		task.spawn(Util.PlayExplosion, boss, p.Explosion, point, p.Scale)
		-- the ground jumps: camera shake that fades with distance + a heavy boom
		Util.Shake(point, 1.6, 0.7, p.Radius * 8)
		Util.Sound(boss, point, Util.METEOR_SOUND, 2, 0.9 + math.random() * 0.2)
	end
end

-- ==========================================================================================
-- Procedural VFX: shockwave rings, floor cracks, light pillars, spark bursts, charge-ups and
-- warning zones. All built from parts and emitters in code, so no asset has to exist for them.
-- The arena is a floating disc, so floor effects are clipped to it instead of hanging in space.
-- ==========================================================================================

Util.GOLD = Color3.fromRGB(255, 200, 92)
Util.EMBER = Color3.fromRGB(255, 110, 60)
Util.VIOLET = Color3.fromRGB(176, 104, 255)
Util.CYAN = Color3.fromRGB(120, 230, 255)
Util.WHITE = Color3.fromRGB(255, 248, 235)

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
Util.SPARK_TEXTURE = SPARK_TEXTURE
Util.SMOKE_TEXTURE = SMOKE_TEXTURE

local function fxPart(boss, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local parent = (boss and boss.Effects) or workspace
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end
Util.FxPart = fxPart

local function fxFolder(boss, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = boss.Effects
	return folder
end
Util.FxFolder = fxFolder

-- true when a point is over the arena floor
function Util.OnArena(arena, point, margin)
	local flat = Vector3.new(point.X - arena.Center.X, 0, point.Z - arena.Center.Z)
	return flat.Magnitude <= arena.Radius - (margin or 0)
end

function Util.FloorPoint(arena, point)
	return Vector3.new(point.X, arena.SurfaceY, point.Z)
end

local function emitterOn(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	e.Rotation = NumberRange.new(0, 360)
	for key, value in props do
		e[key] = value
	end
	e.Parent = parent
	return e
end
Util.Emitter = emitterOn

-- Expanding ring of neon segments sliding out across the floor. Doesn't yield.
-- opts: From, To, Time, Color, Thickness, Height, Segments, Y
function Util.Ring(boss, point, opts)
	opts = opts or {}
	local arena = boss.Arena
	local segments = opts.Segments or 32
	local from, to = opts.From or 4, opts.To or 120
	local duration = opts.Time or 0.55
	local thickness, height = opts.Thickness or 5, opts.Height or 3
	local y = opts.Y or (arena.SurfaceY + height / 2)
	local centre = Vector3.new(point.X, y, point.Z)

	local folder = fxFolder(boss, "RingFx")
	local parts = table.create(segments)
	for i = 1, segments do
		parts[i] = fxPart(boss, {
			Name = "RingSeg",
			Color = opts.Color or Util.GOLD,
			Transparency = 1,
			Size = Vector3.new(thickness, height, 4),
			CFrame = CFrame.new(centre),
			Parent = folder,
		})
	end

	task.spawn(function()
		local elapsed = 0
		while elapsed < duration and folder.Parent do
			elapsed += RunService.Heartbeat:Wait()
			local alpha = math.min(elapsed / duration, 1)
			local radius = from + (to - from) * (1 - (1 - alpha) ^ 3)
			local fade = alpha ^ 1.6
			local arc = (math.pi * 2 * radius) / segments
			for i, part in parts do
				local angle = (i / segments) * math.pi * 2
				local pos = centre + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
				if not Util.OnArena(arena, pos, 1) then
					part.Transparency = 1
				else
					part.Transparency = 0.05 + fade * 0.95
					part.Size = Vector3.new(thickness * (1 - fade * 0.6), height * (1 - fade * 0.8) + 0.2, arc + 1.5)
					part.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
				end
			end
		end
		folder:Destroy()
	end)
end

-- Jagged glowing fissures running out from a point along the floor. Doesn't yield.
-- opts: Count, Length, Width, Color, Time, Angle (centre direction, radians), Spread (radians)
function Util.Cracks(boss, point, opts)
	opts = opts or {}
	local arena = boss.Arena
	local y = arena.SurfaceY + 0.2
	local length = opts.Length or 70
	local life = opts.Time or 1.8
	local folder = fxFolder(boss, "CrackFx")

	for n = 1, opts.Count or 7 do
		local angle
		if opts.Angle then
			angle = opts.Angle + (math.random() - 0.5) * (opts.Spread or math.pi)
		else
			angle = (n / (opts.Count or 7)) * math.pi * 2 + math.random() * 0.6
		end
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local cursor = Vector3.new(point.X, y, point.Z)
		local travelled = 0
		local guard = 0
		while travelled < length and guard < 40 do
			guard += 1
			local step = math.random(7, 16)
			local nextPoint = cursor + dir * step
			local onFloor = Util.OnArena(arena, nextPoint, 1)
			if onFloor and Util.OnArena(arena, cursor, 1) then
				local mid = (cursor + nextPoint) / 2
				local w = (opts.Width or 4) * (1 - travelled / length) + 0.7
				fxPart(boss, {
					Name = "Crack",
					Color = opts.Color or Util.GOLD,
					Size = Vector3.new(w, 0.35, step + 0.8),
					CFrame = CFrame.lookAt(mid, mid + dir),
					Transparency = 0.05,
					Parent = folder,
				})
			end
			cursor = nextPoint
			travelled += step
			dir = (dir + Vector3.new((math.random() - 0.5) * 0.8, 0, (math.random() - 0.5) * 0.8)).Unit
		end
	end

	task.delay(life * 0.4, function()
		if not folder.Parent then return end
		local info = TweenInfo.new(life * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, part in folder:GetChildren() do
			TweenService:Create(part, info, {
				Transparency = 1,
				Size = Vector3.new(0.2, 0.2, part.Size.Z),
				Color = Util.EMBER,
			}):Play()
		 end
		Debris:AddItem(folder, life * 0.6 + 0.2)
	end)
end

-- A column of light that punches up out of the floor and thins away. Doesn't yield.
-- opts: Height, Radius, Color, Time
function Util.Pillar(boss, point, opts)
	opts = opts or {}
	local height = opts.Height or 90
	local radius = opts.Radius or 10
	local life = opts.Time or 0.7
	local base = Util.FloorPoint(boss.Arena, point)
	local upright = CFrame.Angles(0, 0, math.rad(90))

	local column = fxPart(boss, {
		Name = "Pillar",
		Shape = Enum.PartType.Cylinder,
		Color = opts.Color or Util.GOLD,
		Size = Vector3.new(6, radius * 2, radius * 2),
		CFrame = CFrame.new(base + Vector3.new(0, 3, 0)) * upright,
		Transparency = 0.15,
	})
	TweenService:Create(column, TweenInfo.new(life, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(height, radius * 0.5, radius * 0.5),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * upright,
		Transparency = 1,
	}):Play()
	Debris:AddItem(column, life + 0.2)
end

-- A one-off particle burst. Doesn't yield.
-- opts: Color, Count, Speed, Size, Lifetime, Spread, Drag, Gravity, Texture, Direction
function Util.Sparks(boss, point, opts)
	opts = opts or {}
	local lifetime = opts.Lifetime or 0.9
	local speed = opts.Speed or 60
	local spread = opts.Spread or 180
	local holder = fxPart(boss, {
		Name = "SparkFx",
		Size = Vector3.one * 0.2,
		Transparency = 1,
		Material = Enum.Material.SmoothPlastic,
		CFrame = if opts.Direction
			then CFrame.lookAt(point, point + opts.Direction) * CFrame.Angles(-math.pi / 2, 0, 0)
			else CFrame.new(point),
	})
	local emitter = emitterOn(holder, {
		Texture = opts.Texture or SPARK_TEXTURE,
		Color = ColorSequence.new(opts.Color or Util.GOLD, opts.EndColor or opts.Color or Util.EMBER),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, opts.Size or 6),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(lifetime * 0.55, lifetime),
		Speed = NumberRange.new(speed * 0.35, speed),
		SpreadAngle = Vector2.new(spread, spread),
		Drag = opts.Drag or 3,
		Acceleration = Vector3.new(0, -(opts.Gravity or 50), 0),
		RotSpeed = NumberRange.new(-240, 240),
		EmissionDirection = Enum.NormalId.Top,
	})
	task.defer(function()
		if holder.Parent then
			emitter:Emit(opts.Count or 40)
		end
	end)
	Debris:AddItem(holder, lifetime + 1)
end

-- Rolling dust / smoke thrown up by an impact. Doesn't yield.
function Util.Dust(boss, point, opts)
	opts = opts or {}
	Util.Sparks(boss, Util.FloorPoint(boss.Arena, point) + Vector3.new(0, 2, 0), {
		Texture = SMOKE_TEXTURE,
		Color = opts.Color or Color3.fromRGB(214, 196, 170),
		EndColor = opts.EndColor or Color3.fromRGB(120, 104, 96),
		Count = opts.Count or 18,
		Size = opts.Size or 26,
		Speed = opts.Speed or 55,
		Lifetime = opts.Lifetime or 1.6,
		Spread = 80,
		Drag = 2.5,
		Gravity = -6,
	})
end

-- Energy gathering onto a part while the boss winds up: particles pulled in from all around,
-- a growing glow and a light. Returns stop(); call it when the wind-up is over.
-- opts: Color, Size, Reach, Rate, Brightness, Range
function Util.Charge(boss, part, opts)
	opts = opts or {}
	if not part then return function() end end
	local colour = opts.Color or Util.GOLD
	local reach = opts.Reach or 90

	local attachment = Instance.new("Attachment")
	attachment.Name = "ChargeFx"
	attachment.Parent = part

	local gather = emitterOn(attachment, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(Util.WHITE, colour),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.25, opts.Size or 14),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0),
			NumberSequenceKeypoint.new(1, 0.2),
		}),
		-- negative speed = pulled inward. NumberRange wants the smaller number first.
		Speed = NumberRange.new(-reach, -reach * 0.6),
		Lifetime = NumberRange.new(0.5, 0.75),
		SpreadAngle = Vector2.new(180, 180),
		Rate = opts.Rate or 110,
		RotSpeed = NumberRange.new(-180, 180),
	})
	gather.Enabled = true

	local core = emitterOn(attachment, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(colour),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, (opts.Size or 14) * 2.2),
			NumberSequenceKeypoint.new(1, (opts.Size or 14) * 3),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Speed = NumberRange.new(0, 0),
		Lifetime = NumberRange.new(0.25, 0.35),
		Rate = 30,
		LockedToPart = true,
	})
	core.Enabled = true

	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = opts.Range or 60
	light.Brightness = 0
	light.Shadows = false
	light.Parent = attachment
	TweenService:Create(light, TweenInfo.new(opts.RampTime or 1), { Brightness = opts.Brightness or 6 }):Play()

	return function()
		gather.Enabled = false
		core.Enabled = false
		TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()
		Debris:AddItem(attachment, 1)
	end
end

-- Warning footprint drawn as pulsing floor tiles in concentric rings, clipped to the arena.
-- Pulses faster as the strike gets closer. Removes itself after `duration`. Returns its folder.
function Util.FloorZone(boss, centre, radius, duration, colour)
	local arena = boss.Arena
	local y = arena.SurfaceY + 0.15
	local folder = fxFolder(boss, "ZoneFx")
	colour = colour or Color3.fromRGB(255, 80, 60)

	local rings = math.clamp(math.floor(radius / 20), 2, 7)
	for r = 1, rings do
		local ringRadius = radius * (r / rings)
		local segments = math.clamp(math.floor(ringRadius / 8), 8, 48)
		for i = 1, segments do
			local angle = (i / segments) * math.pi * 2 + r * 0.37
			local pos = Vector3.new(centre.X + math.cos(angle) * ringRadius, y, centre.Z + math.sin(angle) * ringRadius)
			if Util.OnArena(arena, pos, 1) then
				local tile = fxPart(boss, {
					Name = "ZoneTile",
					Color = colour,
					Size = Vector3.new(if r == rings then 3.2 else 1.6, 0.3, (math.pi * 2 * ringRadius) / segments * 0.72),
					CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(angle), 0, math.cos(angle))),
					Transparency = 1,
					Parent = folder,
				})
				tile:SetAttribute("Ring", r / rings)
			end
		end
	end

	task.spawn(function()
		local elapsed, phase = 0, 0
		while elapsed < duration and folder.Parent do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			local urgency = math.clamp(elapsed / duration, 0, 1)
			phase += dt * (5 + urgency * 16)
			local appear = math.clamp(elapsed / 0.25, 0, 1)
			for _, tile in folder:GetChildren() do
				local ring = tile:GetAttribute("Ring") or 1
				local pulse = 0.5 + 0.5 * math.sin(phase - ring * 4)
				tile.Transparency = 1 - appear * (0.25 + pulse * 0.45 + urgency * 0.25)
			end
		end
		if folder.Parent then folder:Destroy() end
	end)

	return folder
end

-- Brief flash of the boss's Highlight (the rig already has one). Doesn't yield.
function Util.FlashBoss(boss, colour, time)
	local hl = boss.Model:FindFirstChildOfClass("Highlight")
	if not hl then return end
	-- remember the real resting look once, so overlapping flashes never save each other's
	-- mid-flash values as the "original" and leave the boss stuck glowing
	if hl:GetAttribute("RestFillT") == nil then
		hl:SetAttribute("RestFillT", hl.FillTransparency)
		hl:SetAttribute("RestFill", hl.FillColor)
	end
	local restT = hl:GetAttribute("RestFillT")
	local rest = hl:GetAttribute("RestFill")
	local token = (hl:GetAttribute("FlashToken") or 0) + 1
	hl:SetAttribute("FlashToken", token)

	hl.FillColor = colour or Util.WHITE
	hl.FillTransparency = math.min(restT, 0.35)
	local tween = TweenService:Create(hl, TweenInfo.new(time or 0.4), { FillTransparency = restT })
	tween:Play()
	tween.Completed:Once(function()
		if hl:GetAttribute("FlashToken") == token then
			hl.FillColor = rest
			hl.FillTransparency = restT
		end
	end)
end

-- Plays one of BossAttacks.Anims by name if it has an id. Returns the track or nil.
function Util.PlayAnim(boss, name, fade, weight, speed)
	local anims = ServerStorage:FindFirstChild("BossAttacks")
	anims = anims and anims:FindFirstChild("Anims")
	local anim = anims and anims:FindFirstChild(name)
	if not anim or anim.AnimationId == "" then return nil end
	local ok, track = pcall(function()
		local t = boss:GetTrack(anim)
		t:Play(fade or 0.15, weight or 1, speed or 1)
		return t
	end)
	return if ok then track else nil
end

return Util