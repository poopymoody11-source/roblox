--==================================================
-- TITLE DEFINITIONS  (shared -- safe to require from the client)
--
-- Pure data, no logic, so a future titles UI can read this
-- directly. TitleService evaluates the Check field.
--
-- Check values it understands today:
--   "default"       always unlocked
--   "ascensions"    leaderstats.Ascensions >= Amount
--   "peacepoints"   leaderstats.PeacePoints >= Amount (peak, not spent)
--   "bossfight"     bought the end / bossfight upgrade
--   "allupgrades"   every base upgrade tier maxed
--   "alldiscovered" discovered all 12 lapis types
--   "manual"        PLACEHOLDER -- nothing awards it yet. Call
--                   TitleService.Grant(player, "<id>") when the
--                   system behind it exists.
--==================================================

local TitleData = {}

TitleData.DefaultTitle = "newcomer"

TitleData.Rarities = {
	Common    = Color3.fromRGB(200, 200, 200),
	Uncommon  = Color3.fromRGB(120, 230, 140),
	Rare      = Color3.fromRGB(110, 190, 255),
	Epic      = Color3.fromRGB(200, 130, 255),
	Legendary = Color3.fromRGB(255, 195, 70),
	Mythic    = Color3.fromRGB(255, 95, 120),
	Developer = Color3.fromRGB(170, 90, 255),
}

-- The people who make the game. They get the DEVELOPER title (and its
-- aura) automatically, plus the /cmds admin panel. UserIds, not names,
-- so a rename can't break it.
TitleData.DeveloperIds = {
	-- ONLY these two get the admin panel and the DEVELOPER title
	-- (by UserId, so a renamed account keeps it and a look-alike name doesn't)
	[530967114] = true, -- MrMajou
	[819324632] = true, -- ncncncbnc
}

function TitleData.IsDeveloper(player)
	return player ~= nil and TitleData.DeveloperIds[player.UserId] == true
end

TitleData.Titles = {
	{
		Id = "developer", Name = "DEVELOPER", Rarity = "Developer",
		Description = "Made the game.",
		Check = "developer", Aura = "developer", Hidden = true,
	},
	{
		Id = "newcomer", Name = "Peaceful Beginner", Rarity = "Common",
		Description = "Join the game.",
		Check = "default",
	},
	{
		Id = "awakened", Name = "Awakened", Rarity = "Common",
		Description = "Ascend for the first time.",
		Check = "ascensions", Amount = 1,
	},
	{
		Id = "island_hopper", Name = "Island Hopper", Rarity = "Uncommon",
		Description = "Reach 2 ascensions and unlock 67 Island.",
		Check = "ascensions", Amount = 2,
	},
	{
		Id = "verity_seeker", Name = "Verity Seeker", Rarity = "Rare",
		Description = "Reach 8 ascensions and unlock Verity Island.",
		Check = "ascensions", Amount = 8,
	},
	{
		Id = "la_peace", Name = "La Peace", Rarity = "Mythic",
		Description = "Reach 15 ascensions and unlock LaPeace Island.",
		Check = "ascensions", Amount = 15,
	},
	{
		Id = "transcendent", Name = "Transcendent", Rarity = "Mythic",
		Description = "Reach 50 ascensions.",
		Check = "ascensions", Amount = 50,
	},
	{
		Id = "completionist", Name = "THE ENDING", Rarity = "Mythic",
		-- (no aura: the spiral aura belongs to SPIRAL KING alone, which you
		-- only get by actually beating the Final Boss)
		Description = "Purchase the final upgrade.",
		Check = "bossfight",
	},
	{
		Id = "tycoon", Name = "Tycoon", Rarity = "Legendary",
		Description = "Max out every base upgrade.",
		Check = "allupgrades",
	},
	{
		Id = "collector", Name = "Collector", Rarity = "Epic",
		Description = "Discover every type of lapis.",
		Check = "alldiscovered",
	},
	{
		Id = "peace_lord", Name = "Peace Lord", Rarity = "Legendary",
		Description = "Hold 1,000,000,000 Peace Points at once.",
		Check = "peacepoints", Amount = 1000000000,
	},

	-- ---------- GAMEPASS TITLES ----------
	-- Granted by MonetizationService the moment the matching
	-- bundle is owned, and re-granted on every join so they
	-- survive a data wipe. Check is "manual" because owning
	-- the pass -- not a stat -- is what unlocks them.
	{
		Id = "verity_backer", Name = "Verity", Rarity = "Rare",
		Description = "Own the Verity Bundle.",
		Check = "manual",
	},
	{
		Id = "lapeace_backer", Name = "La Peace Elite", Rarity = "Legendary",
		Description = "Own the La Peace Bundle.",
		Check = "manual",
	},

	-- ---------- PLACEHOLDERS ----------
	-- The systems these depend on aren't built yet. They are already
	-- wired into saving, equipping and the overhead tag -- they just
	-- need TitleService.Grant(player, "<id>") called at the right
	-- moment once the feature exists.
	{
		Id = "cruelty_slayer", Name = "Cruelty Slayer", Rarity = "Epic",
		Description = "Conquer what waits behind Verity's portal and finish her quests.",
		Check = "cruelty",
		Aura = "slayer",
	},
	{
		Id = "quest_master", Name = "Quest Master", Rarity = "Epic",
		Description = "Complete every quest.",
		Check = "quests",
	},
	{
		Id = "speedrunner", Name = "Speedrunner", Rarity = "Legendary",
		Description = "Finish the game in under an hour. (placeholder -- no run timer yet)",
		Check = "manual",
	},
	{
		Id = "og", Name = "OG", Rarity = "Legendary",
		Description = "Played before release. (placeholder -- grant manually)",
		Check = "manual",
	},
	{
		-- Beating the FINAL BOSS in the other experience. Granted by
		-- MonetizationService when a player comes back carrying the
		-- "BeatFinalBoss" teleport flag, or by hand from /cmds.
		Id = "spiral_king", Name = "SPIRAL KING", Rarity = "Mythic",
		Description = "Defeat the Final Boss. Who the h##l do you think you are?",
		Check = "manual", Aura = "spiral",
	},
}

TitleData.ById = {}
for _, title in ipairs(TitleData.Titles) do
	TitleData.ById[title.Id] = title
end

function TitleData.GetColor(titleId)
	local title = TitleData.ById[titleId]
	if not title then return TitleData.Rarities.Common end
	return TitleData.Rarities[title.Rarity] or TitleData.Rarities.Common
end

-- Higher = better. Used to auto-equip the best title a player owns
-- until they deliberately pick one, and to sort the titles UI.
TitleData.RarityRank = {
	Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Developer = 7,
}

for index, title in ipairs(TitleData.Titles) do
	title.Order = index
	title.Rank = TitleData.RarityRank[title.Rarity] or 0
end

-- unlocked = { [titleId] = true }
function TitleData.GetBest(unlocked)
	local best = nil
	for id, isUnlocked in pairs(unlocked) do
		if isUnlocked then
			local title = TitleData.ById[id]
			if title then
				if not best
					or title.Rank > best.Rank
					or (title.Rank == best.Rank and title.Order > best.Order) then
					best = title
				end
			end
		end
	end
	return best and best.Id or TitleData.DefaultTitle
end

--==================================================
-- AURAS
--
-- Rarer title = tougher aura. Rendered client-side by
-- StarterPlayerScripts > TitleAura, which reads the
-- EquippedTitle attribute off each player.
--
-- Override a single title with  Aura = "storm"  in its
-- definition above if you want it to break the rarity rule.
--==================================================

TitleData.AuraByRarity = {
	Common = nil,
	Uncommon = nil,
	Rare = "tide",
	Epic = "prism",
	Legendary = "inferno",
	Mythic = "ascendant",
}

-- Each aura is a real effect from Workspace.effects.Auras,
-- cloned onto the player rather than built out of code.
-- Model is the child of that folder to copy from; Label is
-- what the titles panel calls it.
--
-- The hand-written particle auras these replaced were a
-- placeholder -- one emitter with the title's rarity colour.
-- These are authored effects, so their own colours and
-- timing are left alone.
--
-- Adding a new one: drop the rig into Workspace.effects.Auras
-- and name it here. Any aura whose effects hang off the
-- HumanoidRootPart (all three RNG auras do) ports across
-- rig types for free; ones with per-limb emitters (Fire,
-- Water) are remapped limb by limb in TitleAura.
TitleData.AuraSpecs = {
	-- Built entirely in code by ReplicatedStorage.AccessibleModules.DeveloperAura
	developer = {
		Code = "DeveloperAura",
		Label = "DEVELOPER",
		Cost = 0,
	},
	-- The finish-the-game aura: a Gurren Lagann drill, galaxy rings and
	-- spiral arms, all built in code (AccessibleModules.SpiralAura).
	spiral = {
		Code = "SpiralAura",
		Label = "SPIRAL",
		Cost = 0,
	},
	-- Rare / Epic / Legendary: code-built set pieces (AccessibleModules.
	-- TideAura / PrismAura / InfernoAura, sharing AuraKit). They replaced
	-- the stock Water/RNG/Fire particle rigs, which are still in
	-- Workspace.effects.Auras if you ever want them back (swap Code for
	-- Model = "Water-Aura-01" etc.).
	tide = {
		Code = "TideAura",
		Label = "TIDE",
		Cost = 6,
	},
	prism = {
		Code = "PrismAura",
		Label = "PRISM",
		Cost = 6,
	},
	inferno = {
		Code = "InfernoAura",
		Label = "INFERNO",
		Cost = 6,
	},
	-- Cruelty Slayer only: crossed reaper scythes, a crown of thorns,
	-- chains and a biting ring of teeth (AccessibleModules.SlayerAura).
	slayer = {
		Code = "SlayerAura",
		Label = "SLAYER",
		Cost = 8,
	},
	-- Mythic. Code-built: crown halo, sunburst aureole, three-layer
	-- wings of light and a sacred-geometry seal on the ground.
	ascendant = {
		Code = "AscendantAura",
		Label = "ASCENDANT",
		Cost = 10,
	},
	-- unused by default; set  Aura = "halo"  on a title to use it
	halo = {
		Model = "RNG-Aura-01",
		Label = "HALO",
		Cost = 9,
	},
}

-- Where the aura rigs live. TitleAura falls back to
-- Workspace.effects.Auras if this path is missing.
TitleData.AuraFolder = "effects.Auras"

function TitleData.GetAura(titleId)
	local title = TitleData.ById[titleId]
	if not title then return nil end
	local key = title.Aura or TitleData.AuraByRarity[title.Rarity]
	if not key then return nil end
	return key, TitleData.AuraSpecs[key]
end

--==================================================
-- BADGES
-- Every title also awards a Roblox badge. Create the
-- badges on the Creator Dashboard (Monetization / Engagement
-- > Badges), then paste each badge's ID here. 0 = no badge
-- yet (the title still works, it just skips the badge).
-- Anyone who already owns a title gets the badge the next
-- time they join, so it's safe to fill these in later.
--==================================================

TitleData.BadgeIds = {
	newcomer       = 2220507562259858,
	awakened       = 3852030227985662,
	island_hopper  = 0,
	verity_seeker  = 0,
	la_peace       = 1087381001094240,
	transcendent   = 0,
	completionist  = 2779344313883410,
	tycoon         = 0,
	collector      = 0,
	peace_lord     = 0,
	verity_backer  = 0,
	lapeace_backer = 0,
	cruelty_slayer = 0,
	quest_master   = 3798619442913098,
	speedrunner    = 0,
	og             = 0,
	spiral_king    = 2998582809220098,
}

return TitleData
