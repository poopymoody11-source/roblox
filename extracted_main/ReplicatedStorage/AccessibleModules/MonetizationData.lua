--==================================================
-- MONETIZATION DATA
--
-- Single source of truth for every gamepass in
-- [v1.0] BECOME LA PEACE. The shop UI, the server
-- benefit handlers and the purchase prompts all read
-- from here, so an id or a price can never disagree
-- between the dashboard, the shop card and the code.
--
-- Universe 10766224536 / place 117079564433820.
--
-- Key           -- internal name. Also the suffix of the
--                  player attribute the server publishes:
--                  Pass_<Key> = true when owned. Client
--                  code can read that attribute directly.
-- Frame         -- child of RobuxShop...Gamepasses.Passes
--                  (or of Gamepasses itself for bundles)
--                  that this pass is sold on.
-- CostLabel     -- name of the TextLabel inside Frame that
--                  shows the price. Bundles keep their
--                  price in a separate ImageLabel.
--==================================================

local MonetizationData = {}

MonetizationData.UniverseId = 10766224536

--==================================================
-- GAMEPASSES
--==================================================

MonetizationData.Passes = {
	{
		Key = "DoubleMoney",
		Id = 1985019602,
		-- Keep this as "2x Money" -- it is what the shop card shows.
		Name = "2x Money",
		Price = 199,
		Frame = "2xMoney",
		CostLabel = "cost",
	},
	{
		Key = "DoubleAscensions",
		Id = 1986273340,
		Name = "2x Ascensions",
		Price = 249,
		Frame = "2xAscensions",
		CostLabel = "cost",
	},
	{
		Key = "UnlockAllIslands",
		Id = 1983669850,
		Name = "Unlock All Islands",
		Price = 299,
		Frame = "unlockallislands",
		CostLabel = "cost",
	},
	{
		Key = "OpStaff",
		Id = 1986717210,
		Name = "OP Staff",
		Price = 249,
		Frame = "OPSTAFF",
		CostLabel = "cost",
	},
	{
		Key = "Elytra",
		Id = 1986009366,
		Name = "Elytra",
		Price = 149,
		Frame = "elytra",
		CostLabel = "cost",
	},
	{
		Key = "AutoSell",
		Id = 1985313530,
		Name = "Auto Sell",
		Price = 99,
		Frame = "AutoSell",
		CostLabel = "cost",
	},
	{
		Key = "OpRobe",
		Id = 1982637810,
		Name = "OP Robe",
		Price = 99,
		Frame = "OPROBE",
		CostLabel = "cost",
		-- Off sale on the dashboard; shop card shows COMING NEVER.
		ComingSoon = true,
	},
	{
		Key = "Admin",
		Id = 1986201350,
		Name = "OP Admin",
		Price = 999,
		Frame = "admin",
		CostLabel = "cost",
		-- Off sale until the pass actually does something. The shop
		-- card shows COMING NEVER and won't open a purchase prompt.
		ComingSoon = true,
	},
	{
		Key = "VerityBundle",
		Id = 1986543191,
		Name = "Verity Bundle",
		Price = 299,
		Frame = "veritybundle",
		CostFrame = "veritycost",
		CostLabel = "TextLabel",
	},
	{
		Key = "LaPeaceBundle",
		Id = 1983285859,
		Name = "La Peace Bundle",
		Price = 799,
		Frame = "lapeacebundle",
		CostFrame = "lapeacecost",
		CostLabel = "TextLabel",
	},
}

--==================================================
-- BENEFITS
--
-- What each pass actually does, read by
-- MonetizationService. Kept as data rather than
-- scattered if-statements so adding a pass is a
-- table entry, not a code hunt.
--
-- OneTimeGrant fires once ever per player (tracked in
-- a DataStore) -- consumables like the 99x lapis in a
-- bundle must not re-grant on every rejoin.
-- Permanent effects are read live from the attribute.
--==================================================

MonetizationData.Benefits = {
	DoubleMoney = {
		MoneyMultiplier = 2,
	},
	DoubleAscensions = {
		AscensionCostMultiplier = 0.5,
	},
	UnlockAllIslands = {
		Islands = { "67 Island", "Verity Island", "LaPeace Island" },
	},
	OpStaff = {
		-- Staffs is PERMANENT, not a one-time grant. Ascending wipes
		-- OwnedItems back to the starter staff, so a one-time grant
		-- would be silently deleted by the player's first rebirth
		-- and the ledger would refuse to hand it back.
		Staffs = { "op_lapis" },
	},
	Elytra = {
		Accessory = "Elytra",
	},
	AutoSell = {
		EnablesAutoSell = true,
	},
	OpRobe = {
		-- Built in code by MonetizationService rather than cloned
		-- from a model: a body glow, a trail, and +40% jump.
		-- If you later model an actual Accessory named "OPRobe"
		-- and drop it in AccessibleModels.Accessories, add
		-- Accessory = "OPRobe" here and it will be worn too.
		-- COMING NEVER: grants nothing until it's finished. To turn it
		-- back on, restore RobeEffect = true, remove both ComingSoon
		-- flags, and put the pass back on sale.
		ComingSoon = true,
	},
	Admin = {
		-- Deliberately empty. The pass exists on the dashboard but
		-- grants nothing yet and has been taken OFF SALE, because
		-- selling a pass that does nothing is not something to ship.
		-- To turn it on: add GrantsAdmin = true here, restore the
		-- Pass_Admin check in adminScript's isAdmin(), and flip
		-- "Item for sale" back on in the Creator Dashboard.
		ComingSoon = true,
	},
	-- The bundles were buffed hard: the island alone wasn't worth much
	-- once ascending unlocks it anyway. Each now also gives a permanent
	-- money boost, a PERMANENT upgraded staff (bigger + faster magnet,
	-- extra effects, labelled as the bundle version -- see StaffUpgrade,
	-- applied by MonetizationService) and a lot more lapis.
	VerityBundle = {
		Islands = { "Verity Island" },
		Title = "verity_backer",
		Staffs = { "verity_lapis" },
		MoneyMultiplier = 1.5,
		StaffUpgrade = {
			Tool = "verity",
			Label = "VERITY STAFF+",
			RadiusMult = 2.5,
			Flight = 0.55,
			ColorA = Color3.fromRGB(255, 215, 60),
			ColorB = Color3.fromRGB(90, 150, 255),
		},
		OneTimeGrant = {
			-- Only the lapis is one-time. It is a consumable the
			-- player spends; re-granting it on every join would be
			-- an infinite tap.
			Lapis = { verity_lapis = 99 },
		},
		-- The buffed amount. Its own ledger key, so people who bought
		-- the bundle before the buff get it too (once).
		BonusGrant = {
			Key = "VerityBundle_v2",
			Lapis = { verity_lapis = 900, emerald_lapis = 300, rgb_lapis = 100 },
		},
	},
	LaPeaceBundle = {
		Islands = { "Verity Island", "LaPeace Island" },
		Title = "lapeace_backer",
		Staffs = { "lapeace_lapis" },
		MoneyMultiplier = 2,
		StaffUpgrade = {
			Tool = "heavenstaff",
			Label = "LA PEACE STAFF+",
			RadiusMult = 2.5,
			Flight = 0.45,
			LightBrightness = 0.4, -- white staff: full-strength lights blew it out
			SparkleRate = 12,
			ColorA = Color3.fromRGB(255, 245, 190),
			ColorB = Color3.fromRGB(255, 120, 220),
		},
		OneTimeGrant = {
			Lapis = { lapeace_lapis = 99 },
		},
		BonusGrant = {
			Key = "LaPeaceBundle_v2",
			Lapis = { lapeace_lapis = 900, malevolent_lapis = 300, interstellar_lapis = 150 },
		},
	},
}

--==================================================
-- DEVELOPER PRODUCTS  (repeatable purchases)
--
-- Gamepasses are bought once; these can be bought as
-- many times as the player likes, which is what makes
-- them the right shape for PeacePoints packs.
--
-- Amounts climb faster than prices on purpose -- the
-- big packs are the bulk discount. For scale: the
-- ending upgrade costs 3,000,000,000 PP, and end-game
-- income is roughly 1.3M PP/sec, so the 3B pack is
-- "skip the last ~40 minutes" rather than "win".
--
-- NOTE: this is why PeacePoints had to stop being an
-- IntValue. The 10B pack alone is roughly five times
-- the old 2,147,483,647 ceiling.
--==================================================

MonetizationData.Products = {
	{ Key = "PP25K",  Id = 3713879643, Amount = 25000,       Label = "25K PP",  Price = 29,   Frame = "pp25k" },
	{ Key = "PP250K", Id = 3713879710, Amount = 250000,      Label = "250K PP", Price = 99,   Frame = "pp250k" },
	{ Key = "PP3M",   Id = 3713879792, Amount = 3000000,     Label = "3M PP",   Price = 199,  Frame = "pp3m" },
	{ Key = "PP25M",  Id = 3713879839, Amount = 25000000,    Label = "25M PP",  Price = 349,  Frame = "pp25m" },
	{ Key = "PP150M", Id = 3713879885, Amount = 150000000,   Label = "150M PP", Price = 599,  Frame = "pp150m" },
	{ Key = "PP750M", Id = 3713879937, Amount = 750000000,   Label = "750M PP", Price = 899,  Frame = "pp750m" },
	{ Key = "PP3B",   Id = 3713880001, Amount = 3000000000,  Label = "3B PP",   Price = 1499, Frame = "pp3b" },
	{ Key = "PP10B",  Id = 3713880060, Amount = 10000000000, Label = "10B PP",  Price = 2999, Frame = "pp10b" },
}

--==================================================
-- SKIP ASCENSION  (developer product, repeatable)
--
-- A developer product, not a gamepass: a gamepass can only
-- be bought once, but you want to be able to skip EVERY
-- ascension. Bought from the "SKIP" button on the rebirth
-- menu; the server ascends you the moment it's paid for.
--
-- SETUP: Creator Dashboard > your experience > Monetization
-- > Developer Products > Create. Name it "Skip Ascension",
-- set the price, then paste its ID below. While Id is 0 the
-- SKIP button says "COMING NEVER" and does nothing.
--==================================================

MonetizationData.SkipAscension = {
	Key = "SkipAscension",
	Label = "Skip Ascension",
	-- Price goes up with your ascension level. Each tier is its own
	-- developer product (Creator Dashboard > Monetization > Developer
	-- Products). Paste each product's ID next to its tier. A tier with
	-- Id = 0 shows "SOON" on the button.
	Tiers = {
		{ MinLevel = 0,  MaxLevel = 2,    Price = 15,  Id = 3714416188 },
		{ MinLevel = 3,  MaxLevel = 5,    Price = 25,  Id = 3714416230 },
		{ MinLevel = 6,  MaxLevel = 9,    Price = 39,  Id = 3714416234 },
		{ MinLevel = 10, MaxLevel = 14,   Price = 59,  Id = 3714416245 },
		{ MinLevel = 15, MaxLevel = 19,   Price = 79,  Id = 3714416255 },
		{ MinLevel = 20, MaxLevel = 24,   Price = 99,  Id = 3714416262 },
		{ MinLevel = 25, MaxLevel = 9999, Price = 129, Id = 3714416272 },
	},
}

-- the tier for someone currently at `level` ascensions
function MonetizationData.SkipTierFor(level)
	for _, tier in ipairs(MonetizationData.SkipAscension.Tiers) do
		if level >= tier.MinLevel and level <= tier.MaxLevel then return tier end
	end
	return MonetizationData.SkipAscension.Tiers[#MonetizationData.SkipAscension.Tiers]
end

-- is this product id one of the skip tiers?
function MonetizationData.SkipTierById(productId)
	if not productId or productId == 0 then return nil end
	for _, tier in ipairs(MonetizationData.SkipAscension.Tiers) do
		if tier.Id == productId then return tier end
	end
	return nil
end

--==================================================
-- LOOKUPS
--==================================================

local byKey, byId = {}, {}

for _, pass in ipairs(MonetizationData.Passes) do
	byKey[pass.Key] = pass
	byId[pass.Id] = pass
end

function MonetizationData.GetByKey(key)
	return byKey[key]
end

function MonetizationData.GetById(id)
	return byId[id]
end

local productByKey, productById = {}, {}

for _, product in ipairs(MonetizationData.Products) do
	productByKey[product.Key] = product
	if product.Id ~= 0 then
		productById[product.Id] = product
	end
end

function MonetizationData.GetProductByKey(key)
	return productByKey[key]
end

function MonetizationData.GetProductById(id)
	return productById[id]
end

function MonetizationData.AttributeFor(key)
	return "Pass_" .. key
end

-- The one question every other script actually asks.
-- Attributes replicate, so this is identical on the
-- server and on the client.
function MonetizationData.Owns(player, key)
	if not player then return false end
	return player:GetAttribute("Pass_" .. key) == true
end

-- Money multiplier from all owned passes, multiplied
-- together. Currently only 2x Money contributes, but
-- a future 3x pass stacks without touching every
-- earning script again.
function MonetizationData.GetMoneyMultiplier(player)
	local mult = 1
	if not player then return mult end

	for key, benefit in pairs(MonetizationData.Benefits) do
		if benefit.MoneyMultiplier and MonetizationData.Owns(player, key) then
			mult = mult * benefit.MoneyMultiplier
		end
	end

	return mult
end

-- Ascension cost multiplier. 0.5 with the 2x Ascensions
-- pass, 1 without.
function MonetizationData.GetAscensionCostMultiplier(player)
	local mult = 1
	if not player then return mult end

	for key, benefit in pairs(MonetizationData.Benefits) do
		if benefit.AscensionCostMultiplier and MonetizationData.Owns(player, key) then
			mult = mult * benefit.AscensionCostMultiplier
		end
	end

	return mult
end

-- True when a pass the player owns opens this island
-- regardless of their ascension count.
function MonetizationData.HasIslandAccess(player, islandName)
	if not player or not islandName then return false end

	for key, benefit in pairs(MonetizationData.Benefits) do
		if benefit.Islands and MonetizationData.Owns(player, key) then
			for _, island in ipairs(benefit.Islands) do
				if island == islandName then
					return true
				end
			end
		end
	end

	return false
end

function MonetizationData.FormatRobux(price)
	return "R$" .. tostring(price)
end

return MonetizationData
