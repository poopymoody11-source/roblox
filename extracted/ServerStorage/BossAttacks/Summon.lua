-- ModuleScript | ServerStorage.BossAttacks.Summon
-- Summons minions that wander the arena and rain spikes down around the players.
-- When a minion dies, the nearest living player is given a Stinger tool (stacking).
-- Needs these in ServerStorage.BossAbilities:
--   MinionTemplate  a rig (Humanoid + HumanoidRootPart, e.g. from Rig Builder)
--   Spike           the spike model or part. Its own scripts are not used: BossSpikes handles the damage.
--   Stinger         the Tool handed out on a minion's death (BossStingers handles stacking and throwing)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Util = require(ServerStorage:WaitForChild("BossUtil"))
local Spikes = require(ServerStorage:WaitForChild("BossSpikes"))
local Stingers = require(ServerStorage:WaitForChild("BossStingers"))

local Summon = {}

local CollectionService = game:GetService("CollectionService")
local Anims = script.Parent:WaitForChild("Anims")

-- Plays one of BossAttacks.Anims on the boss (skips silently if it's missing or has no id)
local function playBossAnim(boss, name)
	local anim = Anims:FindFirstChild(name)
	if not anim or anim.AnimationId == "" then return nil end
	local ok, track = pcall(function() return boss:GetTrack(anim) end)
	if ok and track then
		track:Play(0.15)
		return track
	end
end

-- BossAttacks.Anims.beeanim plays on a minion while it moves. Minions are welded
-- (no Motor6Ds), so the uploaded animation only takes effect once the rig has
-- joints; SpiralClient/BossMinionClient also adds a wing-flutter + bob on the
-- client either way (tag "BossMinion").
local function hookBeeAnim(minion, humanoid)
	CollectionService:AddTag(minion, "BossMinion")
	local anim = Anims:FindFirstChild("beeanim")
	if not anim or anim.AnimationId == "" then return end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	if not ok or not track then return end
	track.Looped = true
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			if not track.IsPlaying then track:Play(0.2) end
		elseif track.IsPlaying then
			track:Stop(0.3)
		end
	end)
end

Summon.MinRange = 0
Summon.MaxRange = math.huge

Summon.Defaults = {
	Count = 3,
	MaxAlive = 6,         -- won't summon past this many living minions
	SpawnRadius = 14,     -- ring distance from a mobile boss
	Windup = 1.5,
	Recovery = 1.0,
	MinionHealth = 120,
	MinionSpeed = 14,

	SpikeInterval = 0.2,  -- how often each minion drops a spike (seconds)
	SpikeRadius = 120,    -- spikes land within this many studs of a random player
	SpikeDelay = 2.5,     -- warning time before a spike erupts
	SpikeWarnRadius = 4,  -- size of the red warning disc
	SpikeRiseTime = 0.2,  -- how long it takes to rise out of the floor
	SpikeHoldTime = 1.5,  -- how long it stays up
	SpikeDamage = 25,     -- damage to each player a spike hits. Set this to what your old Spike script dealt.
	-- SpikeHitRadius = 4,  -- optional overrides for the hitbox. Left out, it's measured from the Spike asset.
	-- SpikeHitHeight = 10,
}

local function getAbility(name)
	local folder = ServerStorage:FindFirstChild("BossAbilities")
	return folder and folder:FindFirstChild(name)
end

-- One BossSpikes manager per boss, created the first time a minion needs it
local function getSpikes(boss)
	if not boss.Spikes then
		local template = getAbility("Spike")
		if not template then
			warn("Summon: add a model or part named Spike to ServerStorage.BossAbilities, or minions won't drop spikes")
			return nil
		end
		boss.Spikes = Spikes.new(boss, template)
	end
	return boss.Spikes
end

-- ------------------------------------------------------------------------------------------
-- Stinger reward
-- ------------------------------------------------------------------------------------------

-- The living player closest to `position`, or nil if nobody is on the arena
local function nearestPlayer(boss, position)
	local best, bestDist = nil, math.huge
	for _, root in boss:GetTargets() do
		local player = Players:GetPlayerFromCharacter(root.Parent)
		local dist = (root.Position - position).Magnitude
		if player and dist < bestDist then
			best, bestDist = player, dist
		end
	end
	return best
end

-- ------------------------------------------------------------------------------------------
-- Minion behavior
-- ------------------------------------------------------------------------------------------

-- Creates a simple health bar BillboardGui above the minion's head
local function createHealthGui(minion, humanoid)
	local head = minion:FindFirstChild("Head") or minion:FindFirstChild("HumanoidRootPart")
	if not head then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthGui"
	billboard.Size = UDim2.new(3.5, 0, 0.4, 0)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 150
	billboard.Parent = head

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	background.BorderSizePixel = 0
	background.Parent = billboard

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(0.3, 0)
	backgroundCorner.Parent = background

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(50, 220, 50)
	fill.BorderSizePixel = 0
	fill.Parent = background

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.3, 0)
	fillCorner.Parent = fill

	-- Update the bar width on damage; the color shifts to red as health drops
	humanoid.HealthChanged:Connect(function(health)
		local pct = math.clamp(health / humanoid.MaxHealth, 0, 1)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(255 * (1 - pct), 220 * pct, 50 * pct)
	end)
end

-- Every so often, walks to a random spot on the disc
local function startMovementLoop(boss, minion, humanoid)
	task.spawn(function()
		while boss.Alive and minion.Parent and humanoid.Health > 0 do
			humanoid:MoveTo(Util.RandomPointInArena(boss.Arena, 6))
			task.wait(math.random(10, 20)) -- 10 to 20 seconds until the next spot
		end
	end)
end

-- Drops spikes around random players for as long as the minion lives. The spikes themselves
-- (warning disc, rising, damage) are run by the BossSpikes manager.
local function startSpikeLoop(boss, minion, humanoid, root, spikes, p)
	if not spikes then return end

	local function isActive()
		return boss.Alive and minion.Parent ~= nil and humanoid.Health > 0 and root.Parent ~= nil
	end

	task.spawn(function()
		while isActive() do
			task.wait(p.SpikeInterval)
			if not isActive() then break end

			local targets = boss:GetTargets()
			if #targets > 0 then
				-- a random spot within SpikeRadius of a random living player
				local targetRoot = targets[math.random(#targets)]
				local angle = math.random() * math.pi * 2
				local dist = math.random() * p.SpikeRadius
				local rawPoint = targetRoot.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

				spikes:Strike(Util.GroundPoint(boss.Arena, rawPoint, 2), {
					Warning = p.SpikeDelay,
					WarnRadius = p.SpikeWarnRadius,
					Rise = p.SpikeRiseTime,
					Hold = p.SpikeHoldTime,
					Damage = p.SpikeDamage,
					HitRadius = p.SpikeHitRadius,
					HitHeight = p.SpikeHitHeight,
					Alive = isActive, -- a spike whose minion died during the warning never erupts
				})
			end
		end
	end)
end

-- Faces the direction it's walking, or the nearest player when standing still.
-- Also deletes the minion if it falls off the arena.
local function startFacingLoop(boss, minion, humanoid, root)
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not (boss.Alive and minion.Parent and humanoid.Health > 0) then
			connection:Disconnect()
			return
		end

		if boss.Arena and root.Position.Y < boss.Arena.SurfaceY - 10 then
			connection:Disconnect()
			minion:Destroy()
			return
		end

		if humanoid.MoveDirection.Magnitude > 0.1 then
			humanoid.AutoRotate = true
			return
		end

		humanoid.AutoRotate = false

		local nearest, nearestDist = nil, math.huge
		for _, targetRoot in boss:GetTargets() do
			local dist = (targetRoot.Position - root.Position).Magnitude
			if dist < nearestDist then
				nearest, nearestDist = targetRoot, dist
			end
		end

		if nearest then
			local lookPosition = Vector3.new(nearest.Position.X, root.Position.Y, nearest.Position.Z)
			root.CFrame = CFrame.lookAt(root.Position, lookPosition)
		end
	end)
end

local function spawnMinion(boss, template, spikes, point, p)
	local minion = template:Clone()
	local humanoid = minion:FindFirstChildOfClass("Humanoid")
	local root = minion:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) then
		minion:Destroy()
		warn("Summon: MinionTemplate needs a Humanoid and a HumanoidRootPart")
		return
	end

	humanoid.MaxHealth = p.MinionHealth
	humanoid.Health = p.MinionHealth
	humanoid.WalkSpeed = p.MinionSpeed

	minion:PivotTo(CFrame.new(point + Vector3.new(0, 4, 0))) -- drops onto the floor
	minion.Parent = boss.Effects -- wiped along with everything else when the boss dies
	pcall(function()
		root:SetNetworkOwner(nil) -- has to be parented first
	end)

	table.insert(boss.Minions, minion)
	createHealthGui(minion, humanoid)
	hookBeeAnim(minion, humanoid)

	humanoid.Died:Connect(function()
		-- the nearest living player gets a Stinger
		if boss.Alive then
			local player = nearestPlayer(boss, root.Position)
			if player then
				Stingers.Grant(boss, player)
			end
		end

		task.delay(2, function()
			if minion.Parent then
				minion:Destroy()
			end
		end)
	end)

	startMovementLoop(boss, minion, humanoid)
	startSpikeLoop(boss, minion, humanoid, root, spikes, p)
	startFacingLoop(boss, minion, humanoid, root)
end

function Summon.Execute(boss, target, isCancelled, p)
	local template = getAbility("MinionTemplate")
	if not template then
		warn("Summon: add a rig named MinionTemplate to ServerStorage.BossAbilities")
		return
	end

	local toSpawn = math.min(p.Count, p.MaxAlive - boss:CountMinions())
	if toSpawn <= 0 then return end

	-- Telegraph the spawn points
	local points = {}
	local startAngle = math.random() * math.pi * 2
	for i = 1, toSpawn do
		if boss.Root.Anchored then
			-- a fixed background boss can't have minions "around" it, so they appear across the arena
			points[i] = Util.RandomPointInArena(boss.Arena, 8)
		else
			local angle = startAngle + (i / toSpawn) * math.pi * 2
			local ring = boss.Root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * p.SpawnRadius
			points[i] = Util.GroundPoint(boss.Arena, ring, 4)
		end
		Util.Telegraph(boss, points[i], 3, p.Windup)
	end

	playBossAnim(boss, "Summon")
	task.wait(p.Windup)
	if isCancelled() then return end

	playBossAnim(boss, "BeeSpawn")

	local spikes = getSpikes(boss)
	for _, point in points do
		spawnMinion(boss, template, spikes, point, p)
	end
	task.wait(p.Recovery)
end

return Summon