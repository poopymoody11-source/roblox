-- ModuleScript | ServerStorage.BossAttacks.GasterCircle
-- Fires all 24 of the boss's ring-mounted Gaster Blasters in order around the ring, one per
-- second, sweeping the full circle `Laps` times. Every blaster fires along its own fixed line
-- straight across the map -- see BossGasterBlasters for the fade-in / warning / beam / fade-out
-- sequence, the animations, and the fixed-aim / wide-hitbox tradeoff.
--
-- Needs:
--   ServerStorage.BossAbilities.GasterBlaster   the Gaster Blaster Model (see BossGasterBlasters)
local ServerStorage = game:GetService("ServerStorage")

local GasterCircle = {}

GasterCircle.Defaults = {
	Laps = 2,
	Delay = 0.3,
	Damage = 35,
	Warning = 0.6,
	BeamHold = 0.4,
	FadeIn = 0.25,
	FadeOut = 0.35,
	BeamWidth = 3,
	HitWidthMultiplier = 10, -- the actual hit width is BeamWidth * this (see BossGasterBlasters)
}

-- Shared with GasterRandom: created once, the first time either attack runs, and reused for the
-- rest of the fight.
local function getBlasters(boss)
	if not boss.GasterBlasters then
		local GasterBlasters = require(ServerStorage:WaitForChild("BossGasterBlasters"))
		local template = ServerStorage:WaitForChild("BossAbilities"):WaitForChild("GasterBlaster")
		boss.GasterBlasters = GasterBlasters.new(boss, template)
	end
	return boss.GasterBlasters
end

function GasterCircle.Execute(boss, target, isCancelled, params)
	local blasters = getBlasters(boss)
	local total = #blasters.Blasters

	for lap = 1, params.Laps do
		for i = 1, total do
			if isCancelled() then return end

			blasters:Fire(i, {
				Damage = params.Damage,
				Warning = params.Warning,
				BeamHold = params.BeamHold,
				FadeIn = params.FadeIn,
				FadeOut = params.FadeOut,
				BeamWidth = params.BeamWidth,
				HitWidthMultiplier = params.HitWidthMultiplier,
			})

			task.wait(params.Delay)
		end
	end

	task.wait(params.Warning + params.BeamHold + params.FadeOut)
end

return GasterCircle