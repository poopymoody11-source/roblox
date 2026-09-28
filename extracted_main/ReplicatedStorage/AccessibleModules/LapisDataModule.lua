--==================================================
-- LAPIS DATA
--
-- Value      = sell price (PP per lapis sold).
-- PlotValue  = PP/second the lapis generates on a plot platform.
--
-- The ladder is tiered by island, matching the pads in
-- LapisSpawner.PAD_CONFIG:
--   pad A (Starter)  normal / golden / diamond
--   pad C (67)       67 / hell / totem
--   pad B (Verity)   verity / emerald / rgb
--   pad D (LaPeace)  malevolent / interstellar / lapeace
--
-- RarityChance is a percent roll made every SpawnDelay
-- seconds, so spawns/sec = (RarityChance/100)/SpawnDelay
-- while under MaxCap.
--==================================================

local LapisConfig = {}


-- Was 3000, which let thousands of models pile up and tanked
-- the server. 400 is far more than a full pad ever shows.
LapisConfig.MaxGlobalLapis = 400

LapisConfig.Items = {

	-- ---------- Starter Island (pad A) ----------
	{
		Name = "normal_lapis",
		Value = 20,
		PlotValue = 1, -- PP/sec on a plot platform
		RarityChance = 70,
		SpawnDelay = 0.8,
		MaxCap = 100,
		DoAnim = true,
	},
	{
		Name = "golden_lapis",
		Value = 80,
		PlotValue = 4, -- PP/sec on a plot platform
		RarityChance = 35,
		SpawnDelay = 2,
		MaxCap = 35,
		DoAnim = true,
	},
	{
		Name = "diamond_lapis",
		Value = 160,
		PlotValue = 8, -- PP/sec on a plot platform
		RarityChance = 18,
		SpawnDelay = 3.5,
		MaxCap = 18,
		DoAnim = true,
	},

	-- ---------- 67 Island (pad C, 2 rebirths) ----------
	{
		Name = "67_lapis",
		Value = 300,
		PlotValue = 15, -- PP/sec on a plot platform
		RarityChance = 35,
		SpawnDelay = 2.5,
		MaxCap = 22,
		DoAnim = true,
	},
	{
		Name = "hell_lapis",
		Value = 500,
		PlotValue = 25, -- PP/sec on a plot platform
		RarityChance = 22,
		SpawnDelay = 4,
		MaxCap = 14,
		DoAnim = true,
	},
	{
		Name = "totem_lapis",
		Value = 800,
		PlotValue = 40, -- PP/sec on a plot platform
		RarityChance = 12,
		SpawnDelay = 6,
		MaxCap = 9,
		DoAnim = true,
	},

	-- ---------- Verity Island (pad B, 8 rebirths) ----------
	{
		Name = "verity_lapis",
		Value = 1600,
		PlotValue = 80, -- PP/sec on a plot platform
		RarityChance = 30,
		SpawnDelay = 4,
		MaxCap = 12,
		DoAnim = true,
	},
	{
		Name = "emerald_lapis",
		Value = 2600,
		PlotValue = 130, -- PP/sec on a plot platform
		RarityChance = 18,
		SpawnDelay = 6,
		MaxCap = 9,
		DoAnim = true,
	},
	{
		Name = "rgb_lapis",
		Value = 5000,
		PlotValue = 250, -- PP/sec on a plot platform
		RarityChance = 8,
		SpawnDelay = 12,
		MaxCap = 5,
		DoAnim = true,
	},

	-- ---------- LaPeace Island (pad D, 15 rebirths) ----------
	{
		Name = "malevolent_lapis",
		Value = 8000,
		PlotValue = 400, -- PP/sec on a plot platform
		RarityChance = 25,
		SpawnDelay = 6,
		MaxCap = 9,
		DoAnim = true,
	},
	{
		Name = "interstellar_lapis",
		Value = 14000,
		PlotValue = 700, -- PP/sec on a plot platform
		RarityChance = 14,
		SpawnDelay = 10,
		MaxCap = 6,
		DoAnim = true,
	},
	{
		Name = "lapeace_lapis",
		Value = 24000,
		PlotValue = 1200, -- PP/sec on a plot platform
		RarityChance = 6,
		SpawnDelay = 20,
		MaxCap = 3,
		DoAnim = true,
	},
}

--==================================================
-- INVENTORY INFO
--
-- What the inventory's info panel (and the lapis bar at
-- the bottom of the screen) shows when you click a lapis.
-- Pure flavour + display -- nothing here touches balance.
--   DisplayName  -- shown as the title
--   Island       -- where it spawns
--   Rarity       -- the label + colour of the rarity tag
--   Description  -- the blurb
--==================================================

LapisConfig.Rarities = {
	Common    = Color3.fromRGB(200, 200, 200),
	Uncommon  = Color3.fromRGB(110, 230, 110),
	Rare      = Color3.fromRGB(90, 170, 255),
	Epic      = Color3.fromRGB(190, 110, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic    = Color3.fromRGB(255, 80, 120),
}

LapisConfig.Info = {
	normal_lapis = {
		DisplayName = "Normal Lapis", Island = "Starter Island", Rarity = "Common",
		Description = "The most common type of lapis. Found pretty much everywhere around the region. Sells for, sadly, not much...",
	},
	golden_lapis = {
		DisplayName = "Golden Lapis", Island = "Starter Island", Rarity = "Uncommon",
		Description = "A lapis that fell into a pot of gold and never recovered. Shiny, heavy, and worth four normal ones.",
	},
	diamond_lapis = {
		DisplayName = "Diamond Lapis", Island = "Starter Island", Rarity = "Rare",
		Description = "Squeezed under the Starter Island for a million years until it came out sparkling. The best rock a beginner can find.",
	},
	["67_lapis"] = {
		DisplayName = "67 Lapis", Island = "67 Island", Rarity = "Uncommon",
		Description = "Nobody knows why it's called 67. Nobody knows why it's so loud about it. Only found on 67 Island.",
	},
	hell_lapis = {
		DisplayName = "Hell Lapis", Island = "67 Island", Rarity = "Rare",
		Description = "Pulled out of the lava cracks of 67 Island. Still warm. Hold it with your staff, not your hands.",
	},
	totem_lapis = {
		DisplayName = "Totem Lapis", Island = "67 Island", Rarity = "Epic",
		Description = "Carved from an ancient totem that refused to stay buried. Rumour says it brings luck. It doesn't, but it sells great.",
	},
	verity_lapis = {
		DisplayName = "Verity Lapis", Island = "Verity Island", Rarity = "Rare",
		Description = "Glows with the golden light of Verity Island. It can only tell the truth, and the truth is: it's worth a lot.",
	},
	emerald_lapis = {
		DisplayName = "Emerald Lapis", Island = "Verity Island", Rarity = "Epic",
		Description = "Green, glowing and very precious. Every trader on Verity Island would give up their whole shop for one.",
	},
	rgb_lapis = {
		DisplayName = "RGB Lapis", Island = "Verity Island", Rarity = "Legendary",
		Description = "It couldn't pick a colour, so it picked all of them. The rarest lapis on Verity Island and the flashiest one you'll own.",
	},
	malevolent_lapis = {
		DisplayName = "Malevolent Lapis", Island = "LaPeace Island", Rarity = "Epic",
		Description = "A dark lapis humming with bad intentions. Found on LaPeace Island by the players brave enough to go looking.",
	},
	interstellar_lapis = {
		DisplayName = "Interstellar Lapis", Island = "LaPeace Island", Rarity = "Legendary",
		Description = "Crashed into LaPeace Island from somewhere far beyond the sky. Look closely and tiny galaxies swirl inside.",
	},
	lapeace_lapis = {
		DisplayName = "La Peace Lapis", Island = "LaPeace Island", Rarity = "Mythic",
		Description = "The rarest lapis in existence, born on LaPeace Island itself. Holding one means you are one step closer to becoming La Peace.",
	},
}

local byName = {}
for _, item in ipairs(LapisConfig.Items) do byName[item.Name] = item end

-- Everything the info panel needs for one lapis, in one table.
-- Unknown names still return something sensible.
function LapisConfig.GetInfo(name)
	local item = byName[name] or {}
	local info = LapisConfig.Info[name] or {}
	local rarity = info.Rarity or "Common"
	return {
		Name = name,
		DisplayName = info.DisplayName or (name:gsub("_", " ")),
		Island = info.Island or "???",
		Rarity = rarity,
		RarityColor = LapisConfig.Rarities[rarity] or Color3.new(1, 1, 1),
		Description = info.Description or "A mysterious lapis.",
		Value = item.Value or 0,
		-- average seconds between spawns while under the cap
		SpawnEvery = (item.SpawnDelay and item.RarityChance and item.RarityChance > 0)
			and item.SpawnDelay / (item.RarityChance / 100) or nil,
	}
end

return LapisConfig
