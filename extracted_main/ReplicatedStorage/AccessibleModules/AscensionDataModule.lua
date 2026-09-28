--==================================================
-- ASCENSION DATA  --  SINGLE SOURCE OF TRUTH
--
-- Every system that cares about ascensions reads this
-- module: AscensionService (charging), SellServerScript
-- and BaseLapisIncome (the income multiplier),
-- TeleportService / TeleportClient (island gating),
-- AscensionClient (the rebirth UI) and adminScript.
--
-- Balance target (Sept 2026 retune): the whole run up to the
-- Final Boss in ~25 minutes -- ascension 25 at ~16 min, the
-- "end" upgrade ~4 min later, plus the quests. Every cost is
-- the old curve x0.3 (lapis spawns are also ~4x denser now
-- that they're client-side). Old values: 1000, 3300, 24000...
-- 51000000.
--==================================================

local AscensionData = {}

-- Rebirths required to teleport to each island.
AscensionData.Islands = {
	["67 Island"]      = 2,
	["Verity Island"]  = 8,
	["LaPeace Island"] = 15,
}

-- Cost of the Nth ascension (index N = going from N-1 to N).
-- (x1.3 again with the denser lapis: 6x spawns instead of 4x)
AscensionData.Costs = {
	390,        1290,       9360,       24700,      31200,
	58500,      70200,      156000,     897000,     1053000,
	1170000,    1300000,    1950000,    2210000,    2470000,
	2600000,    5070000,    5460000,    6240000,    6630000,
	8970000,    9360000,    18200000,   18200000,   19500000,
}

-- Past the table, keep scaling geometrically so the game
-- never runs out of ascensions to sell.
AscensionData.OverflowGrowth = 1.25

-- Income multiplier granted per ascension. Applied to BOTH
-- selling lapis and passive plot income, so the mid-game
-- does not go flat between slot-power tiers.
AscensionData.MultiplierPerAscension = 0.5

--==================================================

function AscensionData.GetCost(currentLevel)
	currentLevel = tonumber(currentLevel) or 0
	if currentLevel < 0 then currentLevel = 0 end

	local index = currentLevel + 1
	local listed = AscensionData.Costs[index]
	if listed then
		return listed
	end

	local last = AscensionData.Costs[#AscensionData.Costs]
	local steps = index - #AscensionData.Costs
	return math.floor(last * (AscensionData.OverflowGrowth ^ steps))
end

function AscensionData.GetMultiplier(ascensions)
	ascensions = tonumber(ascensions) or 0
	if ascensions < 0 then ascensions = 0 end
	return 1 + AscensionData.MultiplierPerAscension * ascensions
end

--==================================================
-- GAMEPASS-AWARE COSTS
--
-- The 2x Ascensions pass halves what every ascension
-- costs rather than granting two levels per purchase:
-- doubling the level would skip island unlock steps
-- and the titles tied to them, while halving the cost
-- just makes the same climb twice as fast.
--
-- MonetizationData is required lazily so this module
-- stays safe to require from anywhere, including
-- before MonetizationData exists in an older place
-- file. Ownership lives in a replicated attribute, so
-- the client-side rebirth UI gets the same answer the
-- server does with no extra remote.
--==================================================

local Monetization

local function getMonetization()
	if Monetization ~= nil then
		return Monetization or nil
	end

	local modules = game:GetService("ReplicatedStorage"):FindFirstChild("AccessibleModules")
	local moduleScript = modules and modules:FindFirstChild("MonetizationData")

	if moduleScript then
		local ok, result = pcall(require, moduleScript)
		if ok and type(result) == "table" then
			Monetization = result
			return Monetization
		end
	end

	Monetization = false
	return nil
end

function AscensionData.GetCostMultiplier(player)
	local mon = getMonetization()
	if not mon then return 1 end
	return mon.GetAscensionCostMultiplier(player)
end

-- The cost THIS player pays to buy their next ascension.
-- Every caller -- the ascension handler, the rebirth UI,
-- the admin /ascend command -- must use this rather than
-- GetCost, or a pass holder gets charged full price
-- somewhere and the numbers stop matching the button.
function AscensionData.GetCostFor(player, currentLevel)
	local base = AscensionData.GetCost(currentLevel)
	local multiplier = AscensionData.GetCostMultiplier(player)

	if multiplier == 1 then
		return base
	end

	return math.max(1, math.floor(base * multiplier))
end

function AscensionData.GetIslandRequirement(islandName)
	return AscensionData.Islands[islandName] or 0
end

return AscensionData
