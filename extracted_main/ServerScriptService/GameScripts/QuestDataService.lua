--==================================================
-- QUEST DATA SERVICE
-- Place in: ServerScriptService > GameScripts > QuestDataService
-- Mirrors saved quest data into player.PlayerStats so client
-- scripts can read it directly (same pattern as Lapis/Discovered
-- in the leaderstats script).
--==================================================

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local QUEST_DATASTORE_NAME = "PlayerQuestData_v1"
local AUTO_SAVE_INTERVAL = 180
local SAVE_COOLDOWN = 6.5

local questStore = DataStoreService:GetDataStore(QUEST_DATASTORE_NAME)

print("[QuestDataService] module loaded")

local QuestDataService = {}

local playerSessionData = {}
local lastSaveTimes = {}

local DEFAULT_DATA = {
	ClaimedQuests = {},
	StartedQuests = {}, -- quests you've talked to the giver about (shown in the quest list)
	CanGoIn = false,
	DefeatedCruelty = false,
}

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function deepCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = (type(v) == "table") and deepCopy(v) or v
	end
	return copy
end

local function summarize(data)
	local claimed = {}
	for questName, isClaimed in pairs(data.ClaimedQuests or {}) do
		if isClaimed then
			table.insert(claimed, questName)
		end
	end
	return "CanGoIn=" .. tostring(data.CanGoIn) .. ", ClaimedQuests=[" .. table.concat(claimed, ", ") .. "]"
end

--==================================================
-- PlayerStats replication (client-readable)
--==================================================

local function ensureStatsFolder(player)
	local stats = player:FindFirstChild("PlayerStats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "PlayerStats"
		stats.Parent = player
	end
	return stats
end

local function ensureClaimedQuestsFolder(stats)
	local folder = stats:FindFirstChild("ClaimedQuests")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClaimedQuests"
		folder.Parent = stats
	end
	return folder
end

local function ensureStartedQuestsFolder(stats)
	local folder = stats:FindFirstChild("StartedQuests")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "StartedQuests"
		folder.Parent = stats
	end
	return folder
end

local function setFlag(folder, name)
	if not folder:FindFirstChild(name) then
		local flag = Instance.new("BoolValue")
		flag.Name = name
		flag.Value = true
		flag.Parent = folder
	end
end

-- Rebuilds PlayerStats.ClaimedQuests / PlayerStats.cangoin from the
-- session table. Called on join so previously-claimed quests show up
-- for the client immediately, without waiting for a new claim.
local function syncInstancesFromSession(player, session)
	local stats = ensureStatsFolder(player)
	local claimedFolder = ensureClaimedQuestsFolder(stats)

	for questName, isClaimed in pairs(session.ClaimedQuests) do
		if isClaimed and not claimedFolder:FindFirstChild(questName) then
			local flag = Instance.new("BoolValue")
			flag.Name = questName
			flag.Value = true
			flag.Parent = claimedFolder
		end
	end

	local startedFolder = ensureStartedQuestsFolder(stats)
	for questName, isStarted in pairs(session.StartedQuests or {}) do
		if isStarted then setFlag(startedFolder, questName) end
	end

	local cangoin = stats:FindFirstChild("cangoin")
	if not cangoin then
		cangoin = Instance.new("BoolValue")
		cangoin.Name = "cangoin"
		cangoin.Parent = stats
	end
	cangoin.Value = session.CanGoIn

	if session.DefeatedCruelty and not stats:FindFirstChild("defeatedCruelty") then
		local b = Instance.new("BoolValue")
		b.Name = "defeatedCruelty"
		b.Value = true
		b.Parent = stats
	end
end

--==================================================
-- Load / Save
--==================================================

local function loadQuestData(player)
	local success, result = pcall(function()
		return questStore:GetAsync(keyFor(player))
	end)

	if not success then
		warn("[QuestDataService] GetAsync FAILED for " .. player.Name .. ": " .. tostring(result))
		return deepCopy(DEFAULT_DATA)
	end

	if type(result) == "table" then
		local loaded = {
			ClaimedQuests = result.ClaimedQuests or {},
			StartedQuests = result.StartedQuests or {},
			CanGoIn = result.CanGoIn or false,
			DefeatedCruelty = result.DefeatedCruelty or (result.ClaimedQuests and result.ClaimedQuests.VerityQuest3) or false,
		}
		-- older saves: anything already claimed was obviously started
		for questName, isClaimed in pairs(loaded.ClaimedQuests) do
			if isClaimed then loaded.StartedQuests[questName] = true end
		end
		print("[QuestDataService] loaded existing save for " .. player.Name .. " -> " .. summarize(loaded))
		return loaded
	end

	print("[QuestDataService] no existing save for " .. player.Name .. " — using defaults")
	return deepCopy(DEFAULT_DATA)
end

local function saveQuestData(player, forced)
	local userId = player.UserId
	local now = os.clock()

	if not forced and lastSaveTimes[userId] and (now - lastSaveTimes[userId] < SAVE_COOLDOWN) then
		print("[QuestDataService] skipped save for " .. player.Name .. " (cooldown)")
		return
	end
	lastSaveTimes[userId] = now

	local session = playerSessionData[userId]
	if not session then
		warn("[QuestDataService] no session data to save for " .. player.Name)
		return
	end

	local success, err = pcall(function()
		questStore:SetAsync(keyFor(player), session)
	end)

	if success then
		print("[QuestDataService] SAVED for " .. player.Name .. " -> " .. summarize(session))
	else
		warn("[QuestDataService] SetAsync FAILED for " .. player.Name .. ": " .. tostring(err))
	end
end

--==================================================
-- Public API
--==================================================

-- Raw session table (ClaimedQuests, CanGoIn), or nil if not loaded yet.
-- Mainly useful as a "has this player's data loaded?" check.
function QuestDataService.GetData(player)
	return playerSessionData[player.UserId]
end

-- Blocks (via task.wait) until this player's quest data has loaded, or
-- the timeout (seconds, default 10) elapses. Returns true if it loaded
-- in time, false if it timed out. Mirrors InventoryService.WaitUntilLoaded.
function QuestDataService.WaitUntilLoaded(player, timeout)
	timeout = timeout or 10
	local waited = 0
	while not playerSessionData[player.UserId] and waited < timeout do
		task.wait(0.1)
		waited += 0.1
	end
	return playerSessionData[player.UserId] ~= nil
end

function QuestDataService.IsQuestClaimed(player, questName)
	local session = playerSessionData[player.UserId]
	return session ~= nil and session.ClaimedQuests[questName] == true
end

-- Marks a quest claimed in the session table AND updates
-- PlayerStats.ClaimedQuests.<questName> so clients see it immediately.
-- Does not save by itself -- call QuestDataService.Save(player, true)
-- after, same as the leaderstats script does after BuyOrEquip.
function QuestDataService.SetQuestClaimed(player, questName)
	local session = playerSessionData[player.UserId]
	if not session then
		warn("[QuestDataService] tried to claim '" .. questName .. "' before data loaded for " .. player.Name)
		return
	end
	session.ClaimedQuests[questName] = true

	local stats = ensureStatsFolder(player)
	local claimedFolder = ensureClaimedQuestsFolder(stats)
	local flag = claimedFolder:FindFirstChild(questName)
	if not flag then
		flag = Instance.new("BoolValue")
		flag.Name = questName
		flag.Parent = claimedFolder
	end
	flag.Value = true
end

-- The player has talked to this quest's giver: it now shows in their
-- quest list. Saves on its own (it's a rare event).
function QuestDataService.StartQuest(player, questName)
	local session = playerSessionData[player.UserId]
	if not session then return false end
	session.StartedQuests = session.StartedQuests or {}
	if session.StartedQuests[questName] then return true end
	session.StartedQuests[questName] = true
	setFlag(ensureStartedQuestsFolder(ensureStatsFolder(player)), questName)
	saveQuestData(player, true)
	return true
end

function QuestDataService.IsQuestStarted(player, questName)
	local session = playerSessionData[player.UserId]
	return session ~= nil and session.StartedQuests ~= nil and session.StartedQuests[questName] == true
end

function QuestDataService.GetCanGoIn(player)
	local session = playerSessionData[player.UserId]
	return session ~= nil and session.CanGoIn == true
end

-- Sets CanGoIn in the session table AND updates PlayerStats.cangoin.
-- Does not save by itself -- call QuestDataService.Save(player, true) after.
function QuestDataService.SetCanGoIn(player, value)
	local session = playerSessionData[player.UserId]
	if not session then
		warn("[QuestDataService] tried to set CanGoIn before data loaded for " .. player.Name)
		return
	end
	session.CanGoIn = value

	local stats = ensureStatsFolder(player)
	local cangoin = stats:FindFirstChild("cangoin")
	if not cangoin then
		cangoin = Instance.new("BoolValue")
		cangoin.Name = "cangoin"
		cangoin.Parent = stats
	end
	cangoin.Value = value
end

-- Beat Cruelty: remembered for good (and mirrored as PlayerStats.defeatedCruelty)
function QuestDataService.SetDefeatedCruelty(player)
	local session = playerSessionData[player.UserId]
	if session then session.DefeatedCruelty = true end
	local stats = ensureStatsFolder(player)
	local tag = stats:FindFirstChild("defeatedCruelty")
	if not tag then
		tag = Instance.new("BoolValue")
		tag.Name = "defeatedCruelty"
		tag.Parent = stats
	end
	tag.Value = true
	if session then saveQuestData(player, true) end
end

-- Call right after a meaningful change (like a quest claim) to force
-- an immediate save instead of waiting for the next autosave / leave /
-- server close.
function QuestDataService.Save(player, forced)
	saveQuestData(player, forced)
end

--==================================================
-- Admin helpers (used by the /cmds admin panel)
--==================================================

QuestDataService.ALL_QUESTS = {
	"HomelessQuest", "ToiletQuest", "TungQuest", "CarKeyQuest",
	"VillagerQuest", "VerityQuest", "VerityQuest2", "VerityQuest3",
}

-- Wipes every claimed quest and the villager access, in the save and
-- in PlayerStats, then saves.
function QuestDataService.ResetQuests(player)
	local session = playerSessionData[player.UserId]
	if not session then return false end
	session.ClaimedQuests = {}
	session.StartedQuests = {}
	session.CanGoIn = false
	session.DefeatedCruelty = false
	local stats = ensureStatsFolder(player)
	local claimedFolder = ensureClaimedQuestsFolder(stats)
	claimedFolder:ClearAllChildren()
	ensureStartedQuestsFolder(stats):ClearAllChildren()
	for _, name in ipairs({ "defeatedCruelty", "hasCarKey" }) do
		local v = stats:FindFirstChild(name)
		if v then v:Destroy() end
	end
	QuestDataService.SetCanGoIn(player, false)
	saveQuestData(player, true)
	return true
end

-- Marks every quest done (including the villager access) and saves.
function QuestDataService.GiveAllQuests(player)
	local session = playerSessionData[player.UserId]
	if not session then return false end
	session.StartedQuests = session.StartedQuests or {}
	local startedFolder = ensureStartedQuestsFolder(ensureStatsFolder(player))
	for _, questName in ipairs(QuestDataService.ALL_QUESTS) do
		QuestDataService.SetQuestClaimed(player, questName)
		session.StartedQuests[questName] = true
		setFlag(startedFolder, questName)
	end
	QuestDataService.SetCanGoIn(player, true)
	-- the dungeon finale: the door counts as opened, and "come back when
	-- everything's done" is now ready to finish (the good ending plays)
	QuestDataService.SetQuestClaimed(player, "DungeonDoor")
	for _, q in ipairs({ "DungeonDoor", "DungeonReturn" }) do
		session.StartedQuests[q] = true
		setFlag(startedFolder, q)
	end
	saveQuestData(player, true)
	return true
end

--==================================================
-- Lifecycle
--==================================================

local function onPlayerAdded(player)
	print("[QuestDataService] loading data for " .. player.Name)
	local session = loadQuestData(player)
	playerSessionData[player.UserId] = session
	syncInstancesFromSession(player, session)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	print("[QuestDataService] " .. player.Name .. " leaving — forcing save")
	saveQuestData(player, true)
	playerSessionData[player.UserId] = nil
	lastSaveTimes[player.UserId] = nil
end)

task.spawn(function()
	while true do
		task.wait(AUTO_SAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			saveQuestData(player)
		end
	end
end)

game:BindToClose(function()
	print("[QuestDataService] server closing — forcing save for all players")
	for _, player in ipairs(Players:GetPlayers()) do
		saveQuestData(player, true)
	end
end)

return QuestDataService