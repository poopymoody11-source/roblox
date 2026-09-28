-- ModuleScript | ServerStorage.BossStingers   (directly in ServerStorage, NOT in BossAttacks)
-- A family of throwable tools handed out when a minion dies (stacking), thrown at the boss for
-- damage. All types share the exact same throw/fly/hit mechanic -- see Types below to add one or
-- change its damage.
--
-- Throwing: click with one equipped. The throw animation plays, and it leaves the hand at the
-- animation's "Throw" marker (or after ThrowDelay if the marker hasn't fired), then flies in a
-- straight line toward wherever the player's mouse was pointing, as a full clone of the tool
-- (every part it has, joints and scripts stripped out). It only damages the boss if that line
-- actually passes through the boss's hitbox; otherwise it just flies past and despawns. Each
-- throw costs one from the stack; the last one removes the tool.
--
-- Spiral Power integration: the moment a player's SpiralActive attribute turns true (see
-- ServerStorage.SpiralEnergy / the Spiral Power server script), a Stinger they're carrying or
-- holding is silently upgraded into a Drill, same stack count, same equipped state.
--
-- Needs, per type in Types below:
--   ServerStorage.BossAbilities.<TypeName>          the Tool (with a Handle)
-- Needs once, regardless of how many types you have:
--   ReplicatedStorage.PlayerAnims.StingerThrow     the throw Animation
--   A LocalScript in StarterPlayerScripts (see StingerAimClient.lua) that fires
--   ReplicatedStorage.StingerAim with the mouse's hit point on every click. The RemoteEvent
--   itself is created automatically if it doesn't exist.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Util = require(ServerStorage:WaitForChild("BossUtil"))

local Stingers = {}

local Config = {
	Speed = 160,           -- flight speed, studs per second
	ThrowMarker = "Throw", -- animation event for the moment the stinger leaves the hand
	ThrowDelay = 0.25,     -- if the marker hasn't fired by then, throw anyway. Raise it if your marker is later.
	Cooldown = 0.75,       -- seconds from one throw to the next (0 for none)
	HitSlop = 4,           -- extra reach around the boss's bounding box
	HitEffect = nil,       -- optional: name of an explosion asset in BossAbilities, played where it lands
	MaxLifetime = 3,       -- seconds a thrown tool can fly before it's cleaned up as a miss
}

-- One entry per throwable type. The key is both the Tool's name in ServerStorage.BossAbilities
-- and the value stored on the tool's StingerType attribute. Everything except Damage is shared
-- (see Config above) -- add a type here to get the exact same throw/fly/hit behavior as Stinger.
local Types = {
	Stinger = { Damage = 200, RotationOffset = Vector3.new(90, 0, 0) }, -- tweak this to fix the facing
	Drill = { Damage = 400 }, -- same as Stinger, just double damage
}

local tracks = setmetatable({}, { __mode = "k" })   -- [character] = loaded throw AnimationTrack
local toolBoss = setmetatable({}, { __mode = "k" }) -- [tool] = boss it was granted for

-- ------------------------------------------------------------------------------------------
-- Aiming: the client sends where its mouse was pointing when it clicked, since the server has
-- no way to know that on its own. Only used to pick a direction -- whether that direction
-- actually connects with the boss is still simulated and checked server-side in launch().
-- ------------------------------------------------------------------------------------------

local remote = ReplicatedStorage:FindFirstChild("StingerAim")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "StingerAim"
	remote.Parent = ReplicatedStorage
end

local pendingAim = setmetatable({}, { __mode = "k" }) -- [player] = last mouse hit point sent

remote.OnServerEvent:Connect(function(player, hitPosition)
	if typeof(hitPosition) == "Vector3" then
		pendingAim[player] = hitPosition
	end
end)

-- ------------------------------------------------------------------------------------------
-- The stack
-- ------------------------------------------------------------------------------------------

local function findIn(container, typeName)
	if not container then return nil end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("StingerType") == typeName then
			return child
		end
	end
	return nil
end

-- The tool is renamed to show its count ("Stinger (x2)", "Drill (x2)"), so it's recognised by
-- the StingerType attribute, not by name.
local function setCount(tool, count)
	tool:SetAttribute("Count", count)
	local typeName = tool:GetAttribute("StingerType")
	tool.Name = if count > 1 then typeName .. " (x" .. count .. ")" else typeName
end

local function removeOne(tool)
	local count = (tool:GetAttribute("Count") or 1) - 1
	if count <= 0 then
		tool:Destroy()
	else
		setCount(tool, count)
	end
end

-- ------------------------------------------------------------------------------------------
-- Throwing
-- ------------------------------------------------------------------------------------------

local function getTrack(character, humanoid)
	local cached = tracks[character]
	if cached then return cached end

	local folder = ReplicatedStorage:FindFirstChild("PlayerAnims")
	local animation = folder and folder:FindFirstChild("StingerThrow")
	if not animation then
		warn("BossStingers: ReplicatedStorage.PlayerAnims.StingerThrow not found")
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	tracks[character] = track
	return track
end

-- Stingers can only be thrown while the boss is fighting and can take damage
local function canHitBoss(boss)
	return boss.Started and boss.Alive and boss.Model:GetAttribute("Invulnerable") ~= true
end

-- The thrown projectile is a full clone of the tool -- every part it has, not just Handle, so
-- nothing about its actual appearance gets left behind. Scripts are stripped, and so are any
-- joints/welds (the grip that holds it in the player's hand): left in place, they'd still point
-- at the real hand and drag the clone back toward the player instead of letting it fly free.
local function makeProjectile(tool)
	local projectile = tool:Clone()
	for _, item in projectile:GetDescendants() do
		if item:IsA("BaseScript") or item:IsA("JointInstance") or item:IsA("WeldConstraint") then
			item:Destroy()
		end
	end
	Util.MakeInert(projectile)
	return projectile
end

local function damageBoss(boss, point, damage)
	if boss.Humanoid.Health > 0 and boss.Model:GetAttribute("Invulnerable") ~= true then
		boss.Humanoid:TakeDamage(damage)
	end
	if Config.HitEffect then
		task.spawn(Util.PlayExplosion, boss, Config.HitEffect, point)
	end
end

-- Flies the projectile in a straight line along `direction`, facing the way it's travelling so
-- it actually reads as a thrown object (an optional rotationOffset corrects for a mesh whose
-- modeled "front" isn't -Z). Only damages the boss if the flight path genuinely enters the
-- boss's (re-checked every frame, so a moving boss can't be missed or cheesed) bounding box;
-- otherwise it just flies for MaxLifetime seconds and despawns as a miss. Doesn't yield.
local function launch(boss, projectile, origin, direction, damage, rotationOffset)
	local rotation = CFrame.identity
	if rotationOffset then
		rotation = CFrame.Angles(math.rad(rotationOffset.X), math.rad(rotationOffset.Y), math.rad(rotationOffset.Z))
	end

	local position = origin
	local elapsed = 0
	projectile:PivotTo(CFrame.lookAt(position, position + direction) * rotation)
	projectile.Parent = boss.Effects -- wiped with everything else when the boss dies

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= Config.MaxLifetime or not projectile.Parent or not boss.Alive then
			connection:Disconnect()
			if projectile.Parent then
				projectile:Destroy()
			end
			return
		end

		position += direction * Config.Speed * dt
		projectile:PivotTo(CFrame.lookAt(position, position + direction) * rotation)

		local boxCFrame, boxSize = boss.Model:GetBoundingBox()
		local reach = boxSize / 2 + Vector3.one * Config.HitSlop
		local localPos = boxCFrame:PointToObjectSpace(position)
		if math.abs(localPos.X) <= reach.X and math.abs(localPos.Y) <= reach.Y and math.abs(localPos.Z) <= reach.Z then
			connection:Disconnect()
			projectile:Destroy()
			damageBoss(boss, position, damage)
		end
	end)
end

-- One throw: play the animation, wait for the release moment, spend a stinger, launch it.
-- Yields until the stinger has left the hand.
local function throw(boss, tool, character, humanoid, player)
	local track = getTrack(character, humanoid)

	-- Release at the "Throw" marker; if it hasn't fired by ThrowDelay, release anyway
	local reachedMarker = false
	local connection
	if track then
		connection = track:GetMarkerReachedSignal(Config.ThrowMarker):Connect(function()
			reachedMarker = true
		end)
		track:Play()
	end

	local started = os.clock()
	while not reachedMarker and os.clock() - started < Config.ThrowDelay do
		task.wait()
	end
	if connection then
		connection:Disconnect()
	end

	-- Still holding it, still alive, and the boss can still be hit?
	if tool.Parent ~= character or humanoid.Health <= 0 or not canHitBoss(boss) then
		if track then
			track:Stop(0.1)
		end
		return
	end

	local handle = tool:FindFirstChild("Handle")
	local root = character:FindFirstChild("HumanoidRootPart")
	local origin = if handle then handle.Position elseif root then root.Position else nil
	if not origin then return end

	local typeConfig = Types[tool:GetAttribute("StingerType")] or Types.Stinger

	-- Aim at wherever the player's mouse last pointed; if we never heard from the client
	-- (script not present, mouse pointed exactly at the throw origin, etc.), fall back to the
	-- boss's center so a throw is never wasted on a zero-length direction.
	local function towardBoss()
		return boss.Model:GetBoundingBox().Position - origin
	end

	local aimPoint = pendingAim[player]
	local direction = if aimPoint then aimPoint - origin else towardBoss()
	if direction.Magnitude < 0.01 then
		direction = towardBoss()
	end
	direction = direction.Unit

	local projectile = makeProjectile(tool) -- copied before removeOne, which may destroy the tool
	removeOne(tool)
	launch(boss, projectile, origin, direction, typeConfig.Damage, typeConfig.RotationOffset)
end

local function attach(boss, tool)
	toolBoss[tool] = boss
	local busy = false

	tool.Activated:Connect(function()
		if busy then return end

		local character = tool.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (player and humanoid) or humanoid.Health <= 0 or not canHitBoss(boss) then return end

		busy = true
		local startedAt = os.clock()
		local ok, err = pcall(throw, boss, tool, character, humanoid, player)
		if not ok then
			warn("BossStingers throw error:", err)
		end

		local remaining = Config.Cooldown - (os.clock() - startedAt)
		if remaining > 0 then
			task.wait(remaining)
		end
		busy = false
	end)
end

-- ------------------------------------------------------------------------------------------
-- Rewards
-- ------------------------------------------------------------------------------------------

-- Gives the player a throwable of `typeName` (defaults to "Stinger"), or adds one to the
-- matching stack they already have. Pass "Drill" (or any other key you add to Types) once you've
-- wired up how it's earned.
function Stingers.Grant(boss, player, typeName)
	typeName = typeName or "Stinger"
	if not Types[typeName] then
		warn("BossStingers: '" .. typeName .. "' isn't in Types")
		return
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local abilities = ServerStorage:FindFirstChild("BossAbilities")
	local template = abilities and abilities:FindFirstChild(typeName)
	if not template then
		warn("BossStingers: add a Tool named " .. typeName .. " to ServerStorage.BossAbilities")
		return
	end

	-- in the Backpack, or held in the Character
	local existing = findIn(backpack, typeName) or findIn(player.Character, typeName)
	if existing then
		setCount(existing, (existing:GetAttribute("Count") or 1) + 1)
		return
	end

	local tool = template:Clone()
	tool:SetAttribute("StingerType", typeName)
	setCount(tool, 1)
	attach(boss, tool)
	tool.Parent = backpack
end

-- Swaps a player's held/carried `fromType` for `toType`, keeping its stack count and staying
-- equipped if it was equipped. No-op if they aren't carrying one.
function Stingers.Convert(player, fromType, toType)
	if not Types[fromType] or not Types[toType] then return end

	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	local old = (backpack and findIn(backpack, fromType)) or (character and findIn(character, fromType))
	if not old then return end

	local boss = toolBoss[old]
	if not boss then return end -- shouldn't happen; every granted tool is attached with a boss

	local abilities = ServerStorage:FindFirstChild("BossAbilities")
	local template = abilities and abilities:FindFirstChild(toType)
	if not template then
		warn("BossStingers: add a Tool named " .. toType .. " to ServerStorage.BossAbilities")
		return
	end

	local count = old:GetAttribute("Count") or 1
	local wasEquipped = old.Parent == character

	local tool = template:Clone()
	tool:SetAttribute("StingerType", toType)
	setCount(tool, count)
	attach(boss, tool)
	tool.Parent = if wasEquipped then character else backpack

	old:Destroy()
end

-- Convenience wrapper for the common case: turn a held/carried Stinger into a Drill.
function Stingers.UpgradeToDrill(player)
	Stingers.Convert(player, "Stinger", "Drill")
end

-- ------------------------------------------------------------------------------------------
-- Spiral Power integration: activating it upgrades a carried Stinger into a Drill
-- ------------------------------------------------------------------------------------------

local function watchSpiralActivate(player)
	player:GetAttributeChangedSignal("SpiralActive"):Connect(function()
		if player:GetAttribute("SpiralActive") == true then
			Stingers.UpgradeToDrill(player)
		end
	end)
end

Players.PlayerAdded:Connect(watchSpiralActivate)
for _, existingPlayer in Players:GetPlayers() do
	watchSpiralActivate(existingPlayer)
end

return Stingers