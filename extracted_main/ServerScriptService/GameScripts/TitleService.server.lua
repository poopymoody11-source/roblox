--==================================================
-- TITLE SERVICE
--
-- Unlocks, saves and equips titles. The title itself is
-- shown as a CHAT TAG (see StarterPlayerScripts >
-- TitleChatTag) -- this script only owns the state and
-- publishes the equipped id as a player attribute, which
-- replicates to every client.
--
-- Auto-equip rule: until the player deliberately picks a
-- title in the UI, they always wear the BEST one they
-- own. v1 only auto-equipped while you were still on the
-- starter title, so the first unlock stuck forever and
-- reaching 25 ascensions appeared to do nothing.
--
-- Hook for systems that don't exist yet:
--     _G.GrantTitle(player, "cruelty_slayer")
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local modules = ReplicatedStorage:WaitForChild("AccessibleModules")
local TitleData = require(modules:WaitForChild("TitleDataModule"))
local GameScripts = ServerScriptService:WaitForChild("GameScripts")

local store = DataStoreService:GetDataStore("PlayerTitles_v1")
local BadgeService = game:GetService("BadgeService")

--==================================================
-- BADGES
-- Each title has a matching badge (ids live in
-- TitleDataModule.BadgeIds). Awarded the moment the title
-- unlocks, and re-checked on join so players who earned a
-- title before its badge existed still get it.
--==================================================

local badgeChecked = {} -- [userId] = { [badgeId] = true }

local function awardBadge(player, titleId)
	local ids = TitleData.BadgeIds
	local badgeId = ids and ids[titleId]
	if type(badgeId) ~= "number" or badgeId <= 0 then return end
	local seen = badgeChecked[player.UserId]
	if not seen then
		seen = {}
		badgeChecked[player.UserId] = seen
	end
	if seen[badgeId] then return end
	seen[badgeId] = true
	task.spawn(function()
		local okHas, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
		end)
		if okHas and has then return end
		local ok, err = pcall(function()
			return BadgeService:AwardBadge(player.UserId, badgeId)
		end)
		if not ok then
			seen[badgeId] = nil -- try again next time
			warn("[TitleService] badge " .. titleId .. " failed: " .. tostring(err))
		end
	end)
end

local CONFIG = {
	CHECK_INTERVAL = 5,
}

-- session[userId] = {Unlocked, Equipped, PeakPP, ManualPick}
local session = {}

--==================================================
-- REMOTE
--==================================================

local events = ReplicatedStorage:FindFirstChild("AccessibleEvents")
if not events then
	events = Instance.new("Folder")
	events.Name = "AccessibleEvents"
	events.Parent = ReplicatedStorage
end

local titleRemote = events:FindFirstChild("TitleRemote")
if not titleRemote then
	titleRemote = Instance.new("RemoteEvent")
	titleRemote.Name = "TitleRemote"
	titleRemote.Parent = events
end

--==================================================
-- PERSISTENCE
--==================================================

local function keyFor(userId) return "Titles_" .. userId end

local function load(player)
	local userId = player.UserId
	local data = {
		Unlocked = {},
		Equipped = TitleData.DefaultTitle,
		PeakPP = 0,
		ManualPick = false,
		AuraEnabled = true,
	}

	local ok, saved = pcall(function() return store:GetAsync(keyFor(userId)) end)
	if ok and type(saved) == "table" then
		if type(saved.Unlocked) == "table" then
			for _, id in ipairs(saved.Unlocked) do
				if TitleData.ById[id] then data.Unlocked[id] = true end
			end
		end
		if type(saved.Equipped) == "string" and TitleData.ById[saved.Equipped] then
			data.Equipped = saved.Equipped
		end
		data.PeakPP = tonumber(saved.PeakPP) or 0
		data.ManualPick = saved.ManualPick == true
		if type(saved.Blocked) == "table" then data.Blocked = saved.Blocked end
		if saved.AuraEnabled ~= nil then
			data.AuraEnabled = saved.AuraEnabled == true
		end
	end

	data.Unlocked[TitleData.DefaultTitle] = true
	session[userId] = data
end

local function save(player)
	local data = session[player.UserId]
	if not data then return end

	local list = {}
	for id, unlocked in pairs(data.Unlocked) do
		if unlocked then table.insert(list, id) end
	end

	pcall(function()
		store:SetAsync(keyFor(player.UserId), {
			Unlocked = list,
			Equipped = data.Equipped,
			PeakPP = data.PeakPP,
			ManualPick = data.ManualPick,
			AuraEnabled = data.AuraEnabled,
			Blocked = data.Blocked,
		})
	end)
end

--==================================================
-- STATE PUBLISHING
--==================================================

local function setEquipped(player, titleId)
	local data = session[player.UserId]
	if not data then return end
	data.Equipped = titleId
	-- Replicates to every client; TitleChatTag and TitleAura read these.
	player:SetAttribute("EquippedTitle", titleId)
	player:SetAttribute("AuraEnabled", data.AuraEnabled ~= false)
end

local function pushState(player)
	local data = session[player.UserId]
	if not data then return end

	local unlocked = {}
	for id, on in pairs(data.Unlocked) do
		if on then table.insert(unlocked, id) end
	end

	titleRemote:FireClient(player, "State", {
		Unlocked = unlocked,
		Equipped = data.Equipped,
		ManualPick = data.ManualPick,
		AuraEnabled = data.AuraEnabled ~= false,
	})
end

--==================================================
-- UNLOCKING
--==================================================

local function grant(player, titleId, silent)
	local data = session[player.UserId]
	if not data or not TitleData.ById[titleId] then return false end
	if data.Unlocked[titleId] then return false end

	data.Unlocked[titleId] = true
	awardBadge(player, titleId)

	-- Wear the best thing you own, unless you've chosen for yourself.
	if not data.ManualPick then
		setEquipped(player, TitleData.GetBest(data.Unlocked))
	end

	if not silent then
		titleRemote:FireClient(player, "Unlocked", titleId)
	end
	pushState(player)
	return true
end

_G.GrantTitle = function(player, titleId)
	return grant(player, titleId, false)
end
-- wear a title you own right now (and its aura), e.g. SPIRAL KING the moment
-- you come back from beating the Final Boss. Returns true once it's on.
_G.EquipTitle = function(player, titleId)
	local data = session[player.UserId]
	if not data or not data.Unlocked[titleId] then return false end
	data.AuraEnabled = true
	setEquipped(player, titleId)
	pushState(player)
	return true
end

-- true = owns it, false = doesn't, nil = their titles haven't loaded yet
-- (GrantTitle returns false for BOTH "already had it" and "not loaded",
-- so callers that must not miss a grant check this)
_G.HasTitle = function(player, titleId)
	local data = session[player.UserId]
	if not data then return nil end
	return data.Unlocked[titleId] == true
end

local function getUpgradeService()
	local mod = GameScripts:FindFirstChild("BaseUpgradeService")
	if not mod then return nil end
	local ok, service = pcall(require, mod)
	return ok and service or nil
end

local function evaluate(player)
	local data = session[player.UserId]
	if not data then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	local ascensions, pp = 0, 0
	local statsKnown = leaderstats ~= nil
	if leaderstats then
		local a = leaderstats:FindFirstChild("Ascensions") or leaderstats:FindFirstChild("Rebirths")
		local p = leaderstats:FindFirstChild("PeacePoints")
		ascensions = a and a.Value or 0
		pp = p and p.Value or 0
	end

	if pp > data.PeakPP then data.PeakPP = pp end

	-- The developer title is only for the people in TitleData.DeveloperIds.
	if data.Unlocked.developer and not TitleData.IsDeveloper(player) then
		data.Unlocked.developer = nil
		if data.Equipped == "developer" then
			setEquipped(player, TitleData.GetBest(data.Unlocked))
		end
		pushState(player)
	end

	local upgrades = getUpgradeService()
	local userId = player.UserId
	local granted = false

	for _, title in ipairs(TitleData.Titles) do
		if not data.Unlocked[title.Id] then
			-- earned: true = qualifies, false = definitely doesn't,
			-- nil = data not loaded / mid-rebuild (e.g. during an ascension).
			-- nil must never un-block a title after a reset, or the title
			-- pops back "randomly" the moment the data reappears.
			local earned = nil

			if title.Check == "default" then
				earned = true
			elseif title.Check == "manual" then
				earned = false
			elseif title.Check == "ascensions" then
				if statsKnown then earned = ascensions >= (title.Amount or 0) end
			elseif title.Check == "peacepoints" then
				if statsKnown then earned = data.PeakPP >= (title.Amount or 0) end
			elseif title.Check == "bossfight" then
				if upgrades then earned = upgrades.GetBossfightUnlocked(userId) == true end
			elseif title.Check == "allupgrades" then
				earned = upgrades ~= nil
					and upgrades.GetLapisSlotTier(userId) >= 4
					and upgrades.GetSlotPowerTier(userId) >= 4
					and upgrades.GetTeleportUnlocked(userId) == true
					and upgrades.GetBossfightUnlocked(userId) == true
				if not upgrades then earned = nil end
			elseif title.Check == "alldiscovered" then
				local stats = player:FindFirstChild("PlayerStats")
				local discovered = stats and stats:FindFirstChild("Discovered")
				if discovered then
					local all, any = true, false
					for _, flag in ipairs(discovered:GetChildren()) do
						any = true
						if not flag.Value then
							all = false
							break
						end
					end
					if any then earned = all end
				end
			elseif title.Check == "quests" then
				local qpMod = GameScripts:FindFirstChild("QuestProgress")
				local ok, qp = pcall(require, qpMod)
				if ok and qp then
					local okDone, done = pcall(qp.AllDone, player)
					if okDone and done ~= nil then earned = done == true end
				end
			elseif title.Check == "developer" then
				earned = TitleData.IsDeveloper(player)
			elseif title.Check == "cruelty" then
				-- ONLY for actually killing him (the fight sets this flag, and only
				-- for players who were alive and never died that fight)
				local stats = player:FindFirstChild("PlayerStats")
				local flag = stats and stats:FindFirstChild("defeatedCruelty")
				earned = flag ~= nil and flag.Value == true
			end
			-- "manual" is never earned automatically -- that is the point.

			-- After an admin title reset, titles you still qualify for are NOT
			-- handed straight back; you have to earn them again (the condition
			-- has to go false and then true). Developer titles are exempt.
			if title.Check ~= "developer" then
				data.Blocked = data.Blocked or {}
				-- block anything you qualify for OR that we can't tell yet
				if data.BlockOnNextEvaluate and earned ~= false then
					data.Blocked[title.Id] = true
				end
				if data.Blocked[title.Id] then
					if earned == false then data.Blocked[title.Id] = nil end
					earned = false
				end
			end

			if earned == true and grant(player, title.Id, false) then
				granted = true
				if title.Id == "developer" then
					-- devs wear it straight away, even if they'd picked another title
					setEquipped(player, "developer")
					pushState(player)
				end
			end
		end
	end

	data.BlockOnNextEvaluate = nil

	-- Safety net: if something got unlocked in a past session while the
	-- auto-equip rule was broken, correct it now.
	if not granted and not data.ManualPick then
		local best = TitleData.GetBest(data.Unlocked)
		if best ~= data.Equipped then
			setEquipped(player, best)
			pushState(player)
		end
	end
end

--==================================================
-- LIFECYCLE
--==================================================

local function onPlayerAdded(player)
	load(player)

	local data = session[player.UserId]
	if not data.ManualPick then
		data.Equipped = TitleData.GetBest(data.Unlocked)
	end
	player:SetAttribute("EquippedTitle", data.Equipped)
	player:SetAttribute("AuraEnabled", data.AuraEnabled ~= false)

	-- hand out badges for titles owned before the badge existed
	for id, on in pairs(data.Unlocked) do
		if on then awardBadge(player, id) end
	end

	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 20)
		if not leaderstats then return end
		for _, statName in ipairs({"Ascensions", "Rebirths", "PeacePoints"}) do
			local stat = leaderstats:FindFirstChild(statName)
			if stat then
				stat.Changed:Connect(function()
					evaluate(player)
				end)
			end
		end
		evaluate(player)
		pushState(player)
	end)

	task.delay(3, function()
		if player.Parent then
			evaluate(player)
			pushState(player)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	session[player.UserId] = nil
	badgeChecked[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

--==================================================
-- CLIENT REQUESTS
--==================================================

titleRemote.OnServerEvent:Connect(function(player, action, titleId)
	local data = session[player.UserId]
	if not data then return end

	if action == "GetState" then
		pushState(player)

	elseif action == "Equip" then
		if type(titleId) ~= "string" then return end
		if not data.Unlocked[titleId] then
			titleRemote:FireClient(player, "Error", "YOU HAVEN'T UNLOCKED THAT TITLE!")
			return
		end
		data.ManualPick = true
		setEquipped(player, titleId)
		pushState(player)

	elseif action == "AutoBest" then
		data.ManualPick = false
		setEquipped(player, TitleData.GetBest(data.Unlocked))
		pushState(player)

	elseif action == "ToggleAura" then
		data.AuraEnabled = not (data.AuraEnabled ~= false)
		player:SetAttribute("AuraEnabled", data.AuraEnabled)
		pushState(player)
	end
end)

--==================================================
-- ADMIN / OTHER-SCRIPT HOOKS
--
-- _G.GrantTitle(player, id)   award a title (used by /title give
--                             and by systems that don't exist yet)
-- _G.ResetTitles(player)      wipe titles back to the starter one,
--                             called by /reset in adminScript
-- _G.ListTitles()             returns every id, for /title list
--==================================================

_G.ResetTitles = function(player)
	local data = session[player.UserId]
	if not data then return false end

	data.Unlocked = {[TitleData.DefaultTitle] = true}
	data.Equipped = TitleData.DefaultTitle
	data.ManualPick = false
	data.PeakPP = 0
	data.AuraEnabled = true

	setEquipped(player, TitleData.DefaultTitle)
	save(player)
	pushState(player)

	-- Nothing comes straight back except the developer title and the
	-- titles that come with gamepasses; everything else has to be earned
	-- again from here.
	data.Blocked = {}
	data.BlockOnNextEvaluate = true
	task.delay(0.5, function()
		if not player.Parent then return end
		evaluate(player)
		if type(_G.RefreshPasses) == "function" then
			pcall(_G.RefreshPasses, player) -- re-grants gamepass titles
		end
		save(player)
	end)
	return true
end

_G.ListTitles = function()
	local ids = {}
	for _, title in ipairs(TitleData.Titles) do
		table.insert(ids, title.Id)
	end
	return ids
end

--==================================================
-- PERIODIC SWEEP (covers upgrades / discovery)
--==================================================

task.spawn(function()
	while task.wait(CONFIG.CHECK_INTERVAL) do
		for _, player in ipairs(Players:GetPlayers()) do
			pcall(evaluate, player)
		end
	end
end)
