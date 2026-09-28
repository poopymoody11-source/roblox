-- ModuleScript | ServerStorage.BossAttacks.GasterRandom
-- A scattered volley: a random number of the boss's 24 ring-mounted Gaster Blasters, chosen at
-- random with no repeats, fire one after another with a random pause between each. Each shot
-- independently rolls one of three aim modes (see ModeWeights below):
--   "Player"    aimed at a random living player
--   "Straight"  the blaster's own fixed line, straight across the map (what GasterCircle always uses)
--   "Random"    a random direction that still crosses the map -- never straight backwards
-- See BossGasterBlasters for the fade-in / warning / beam / fade-out sequence, the animations,
-- and the fixed-aim / wide-hitbox tradeoff for the "Straight" and "Random" shots.
--
-- Needs:
--   ServerStorage.BossAbilities.GasterBlaster   the Gaster Blaster Model (see BossGasterBlasters)
local ServerStorage = game:GetService("ServerStorage")

local GasterRandom = {}

GasterRandom.Defaults = {
	MinCount = 4,
	MaxCount = 10,
	DelayMin = 0.5,
	DelayMax = 2,
	Damage = 35,
	Warning = 0.6,
	BeamHold = 0.4,
	FadeIn = 0.25,
	FadeOut = 0.35,
	BeamWidth = 3,
	HitWidthMultiplier = 10, -- the actual hit width is BeamWidth * this (see BossGasterBlasters)
	RandomSpread = 70,       -- how far a "Random"-mode shot can vary from "Straight" (see BossGasterBlasters)
	ModeWeights = { Player = 1, Straight = 1, Random = 1 }, -- odds each shot uses each aim mode
}

-- Shared with GasterCircle: created once, the first time either attack runs, and reused for the
-- rest of the fight.
local function getBlasters(boss)
	if not boss.GasterBlasters then
		local GasterBlasters = require(ServerStorage:WaitForChild("BossGasterBlasters"))
		local template = ServerStorage:WaitForChild("BossAbilities"):WaitForChild("GasterBlaster")
		boss.GasterBlasters = GasterBlasters.new(boss, template)
	end
	return boss.GasterBlasters
end

-- Weighted random pick of a key from `weights` (e.g. { Player = 1, Straight = 1, Random = 1 })
local function pickMode(weights)
	local total = 0
	for _, weight in weights do
		total += weight
	end

	local roll = math.random() * total
	local last
	for name, weight in weights do
		last = name
		roll -= weight
		if roll <= 0 then
			return name
		end
	end
	return last
end

function GasterRandom.Execute(boss, target, isCancelled, params)
	local blasters = getBlasters(boss)
	local total = #blasters.Blasters
	local count = math.min(math.random(params.MinCount, params.MaxCount), total)

	-- shuffle 1..total, then take the first `count` -- a random subset with no repeats
	local indices = {}
	for i = 1, total do
		indices[i] = i
	end
	for i = total, 2, -1 do
		local j = math.random(i)
		indices[i], indices[j] = indices[j], indices[i]
	end

	for n = 1, count do
		if isCancelled() then return end

		local mode = pickMode(params.ModeWeights)
		local aimTarget = nil
		if mode == "Player" then
			-- a random living player, not just the one the boss is currently tracking, so the
			-- threat spreads across the whole group
			local roots = boss:GetTargets()
			local aimRoot = if #roots > 0 then roots[math.random(#roots)] else target
			aimTarget = if aimRoot then aimRoot.Position else nil
			if not aimTarget then
				mode = "Straight" -- nobody on the arena to aim at
			end
		end

		blasters:Fire(indices[n], {
			Damage = params.Damage,
			Warning = params.Warning,
			BeamHold = params.BeamHold,
			FadeIn = params.FadeIn,
			FadeOut = params.FadeOut,
			BeamWidth = params.BeamWidth,
			HitWidthMultiplier = params.HitWidthMultiplier,
			AimMode = mode,
			Target = aimTarget,
			RandomSpread = params.RandomSpread,
		})

		if n < count then
			task.wait(params.DelayMin + math.random() * (params.DelayMax - params.DelayMin))
		end
	end

	-- let the last blast finish its sequence before the boss moves on to its next attack
	task.wait(params.Warning + params.BeamHold + params.FadeOut)
end

return GasterRandom