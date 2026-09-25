-- ModuleScript | ServerStorage.BossAttacks.BossProjectile
-- A volley of projectiles fired at the players from the boss's projectile openings:
-- workspace.BossFight.ProjectileSpawns > ProjectileOpening1, 2, 3, 4 (BaseParts).
-- Every opening's ParticleEmitters are on while the attack runs and switch off shortly after.
local ServerStorage = game:GetService("ServerStorage")
local Util = require(ServerStorage:WaitForChild("BossUtil"))
local ProjectileTypes = require(ServerStorage:WaitForChild("BossProjectileTypes"))

local BossProjectile = {}

BossProjectile.MinRange = 0
BossProjectile.MaxRange = math.huge -- the boss can be far from the arena

BossProjectile.Defaults = {
	Count = 30,            -- projectiles per attack
	Types = { EnergyOrb = 0.95, GalaxyProjectile = 0.05 }, -- share of the volley per type (an exact split, shuffled)
	Spread = 40,           -- each shot goes out at a random angle inside this cone (degrees) around its target
	Stagger = 0.15,        -- each shot waits a random 0..Stagger seconds after the previous one
	Windup = 0.8,          -- emitters are already on during this
	Recovery = 0.6,
	EmittersOffDelay = 1,  -- emitters switch off this many seconds after the attack finishes
	DamageMultiplier = 1,  -- scales every type's Damage, handy for phase 2
	ExplodeOnFloor = true, -- shots that miss explode when they reach the arena floor
}

local function getOpenings()
	local bossFight = workspace:FindFirstChild("BossFight")
	local folder = bossFight and bossFight:FindFirstChild("ProjectileSpawns")
	local openings = {}
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") and child.Name:match("^ProjectileOpening%d+$") then
				table.insert(openings, child)
			end
		end
	end
	return openings
end

-- Emitters are shared by every projectile attack, so count how many are using them
local holds = 0

local function setEmitters(openings, enabled)
	for _, opening in openings do
		for _, item in opening:GetDescendants() do
			if item:IsA("ParticleEmitter") then
				item.Enabled = enabled
			end
		end
	end
end

local function holdEmitters(openings)
	holds += 1
	setEmitters(openings, true)
end

local function releaseEmitters(openings, delay)
	task.delay(delay, function()
		holds -= 1
		if holds == 0 then
			setEmitters(openings, false)
		end
	end)
end

-- Splits `count` shots between the types by their shares (exactly, not by chance), then shuffles
local function buildVolley(shares, count)
	local total = 0
	for _, share in shares do
		total += share
	end

	local volley, assigned = {}, 0
	local heaviest, heaviestShare = nil, -1
	for name, share in shares do
		local amount = math.floor(count * share / total + 1e-6)
		for _ = 1, amount do
			table.insert(volley, name)
		end
		assigned += amount
		if share > heaviestShare then
			heaviest, heaviestShare = name, share
		end
	end
	for _ = 1, count - assigned do -- rounding leftovers go to the biggest share
		table.insert(volley, heaviest)
	end

	for i = #volley, 2, -1 do
		local j = math.random(i)
		volley[i], volley[j] = volley[j], volley[i]
	end
	return volley
end

local function fireVolley(boss, target, isCancelled, p, openings)
	local volley = buildVolley(p.Types, p.Count)

	-- BossAttacks.Anims: "Galaxy" when this volley has a galaxy in it, otherwise "Throw"
	local hasGalaxy = table.find(volley, "GalaxyProjectile") ~= nil
	local anims = script.Parent:FindFirstChild("Anims")
	local anim = anims and anims:FindFirstChild(hasGalaxy and "Galaxy" or "Throw")
	if anim and anim.AnimationId ~= "" then
		pcall(function() boss:GetTrack(anim):Play(0.15) end)
	end

	task.wait(p.Windup)

	for _, typeName in volley do
		if isCancelled() then return end

		local def = ProjectileTypes[typeName]
		if def then
			local origin = openings[math.random(#openings)].Position

			-- each shot picks one of the living players, so a group gets shot at, not just one person
			local roots = boss:GetTargets()
			local aimRoot = if #roots > 0 then roots[math.random(#roots)] else target
			if not aimRoot or not aimRoot.Parent then break end -- everyone died mid-volley
			local toTarget = aimRoot.Position - origin
			local yaw = (math.random() - 0.5) * p.Spread

			Util.FireProjectile(boss, def, {
				Position = origin,
				Direction = CFrame.Angles(0, math.rad(yaw), 0) * toTarget.Unit,
				DamageMultiplier = p.DamageMultiplier,
				Lifetime = toTarget.Magnitude / def.Speed + 2, -- long enough to cross the distance
				ExplodeOnFloor = p.ExplodeOnFloor,
			})
		else
			warn(("BossProjectile: no entry called '%s' in BossProjectileTypes"):format(tostring(typeName)))
		end

		task.wait(math.random() * p.Stagger)
	end

	task.wait(p.Recovery)
end

function BossProjectile.Execute(boss, target, isCancelled, p)
	local openings = getOpenings()
	if #openings == 0 then
		warn("BossProjectile: no ProjectileOpening parts found in workspace.BossFight.ProjectileSpawns")
		return
	end

	holdEmitters(openings)
	local ok, err = pcall(fireVolley, boss, target, isCancelled, p, openings)
	releaseEmitters(openings, p.EmittersOffDelay) -- runs even if the attack was cancelled or errored
	if not ok then
		error(err, 0)
	end
end

return BossProjectile