--==================================================
-- FINAL CUTSCENE SERVER
--
-- 1. Players arrive (up to 8) on the copy of the Become La
--    Peace island and can walk around while the rest of the
--    party loads in.
-- 2. When everyone is here (or the wait runs out) the server
--    publishes a shared start time + roster. Every client then
--    plays the same cutscene in lock-step off the server clock.
-- 3. The server keeps the real bodies frozen out of sight,
--    moves them into the arena on cue, and flips the place to
--    "Fight" when the cutscene ends (BossService starts the boss).
--
-- State lives in workspace attributes so late joiners and
-- respawns can always read where things are:
--   FC_State  Waiting | Countdown | Cutscene | Fight
--   FC_Start  server time the cutscene starts
--   FC_Roster comma-separated UserIds in slot order
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FC = ReplicatedStorage:WaitForChild("FinalCutscene")
local TL = require(FC:WaitForChild("Timeline"))

local avatars = FC:FindFirstChild("Avatars") or Instance.new("Folder")
avatars.Name = "Avatars"
avatars.Parent = FC

local function now() return workspace:GetServerTimeNow() end

workspace:SetAttribute("FC_State", "Waiting")
workspace:SetAttribute("FC_Start", 0)
workspace:SetAttribute("FC_Roster", "")
workspace:SetAttribute("FC_Expected", 0)

-- the island spawns from the copied map would drop people onto the
-- tower in the middle of the pool; everyone is placed by script instead
local mapCopy = workspace:FindFirstChild("LaPeaceMap")
if mapCopy then
	for _, d in ipairs(mapCopy:GetDescendants()) do
		if d:IsA("SpawnLocation") then d.Enabled = false end
	end
end

local joinOrder = {}   -- [player] = sequence number
local joinSeq = 0
local firstJoin, lastJoin
local expected = 0
local roster = {}      -- [slot] = player
local slotOf = {}      -- [player] = slot

--------------------------------------------------------
-- avatar stand-ins (R6, built from each player's look)
--------------------------------------------------------
local building = {}
local function buildAvatar(player)
	if building[player] then return end
	building[player] = true
	task.spawn(function()
		local desc
		for _ = 1, 3 do
			local ok, d = pcall(function() return Players:GetHumanoidDescriptionFromUserId(math.max(player.UserId, 1)) end)
			if ok and d then desc = d break end
			task.wait(1)
		end
		if not desc then
			local char = player.Character or player.CharacterAdded:Wait()
			local hum = char and char:WaitForChild("Humanoid", 10)
			if hum then pcall(function() desc = hum:GetAppliedDescription() end) end
		end
		desc = desc or Instance.new("HumanoidDescription")
		desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 1, 1, 1, 1
		desc.BodyTypeScale, desc.ProportionScale = 0, 0
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
		end)
		if ok and model then
			model.Name = tostring(player.UserId)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then d.Anchored = false d.CanCollide = false d.CanTouch = false d.CanQuery = false end
				if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
			end
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then root.Anchored = true end
			model:SetAttribute("DisplayName", player.DisplayName)
			local old = avatars:FindFirstChild(model.Name)
			if old then old:Destroy() end
			model:PivotTo(CFrame.new(0, -5000, 0))
			model.Parent = avatars
		else
			warn("[FinalCutscene] could not build avatar for " .. player.Name .. ": " .. tostring(model))
		end
		building[player] = nil
		player:SetAttribute("FC_AvatarReady", true)
	end)
end

--------------------------------------------------------
-- body placement
--------------------------------------------------------
local function rootOf(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c
end

local function place(player, cf, anchored)
	local root, char = rootOf(player)
	if not root then return end
	char:PivotTo(cf)
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = anchored and true or false
end

local function meadowCF(i)
	local off = TL.MeadowSlots[((i - 1) % #TL.MeadowSlots) + 1]
	return TL.Meadow * CFrame.new(off + Vector3.new(0, 3.2, 0))
end

local function arenaCF(slot)
	local p = TL.ArenaStand(slot)
	return CFrame.lookAt(p, Vector3.new(TL.LapisPos.X, p.Y, TL.LapisPos.Z))
end

local function state() return workspace:GetAttribute("FC_State") end

local function chapterReached(name)
	local start = workspace:GetAttribute("FC_Start") or 0
	return state() == "Cutscene" and now() >= start + TL.Chapter(name).Start
end

local function placeForState(player)
	local st = state()
	local slot = slotOf[player]
	if st == "Fight" then
		place(player, arenaCF(slot or math.random(1, 8)), false)
	elseif st == "Cutscene" then
		if not slot or chapterReached(TL.ArenaChapter) then
			place(player, arenaCF(slot or 8), true)
		else
			place(player, meadowCF(slot), true)
		end
	else
		place(player, meadowCF(joinOrder[player] or 1), false)
	end
end

local function onCharacter(player, char)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root then return end
	task.wait() -- let the default spawn finish first
	placeForState(player)
end

--------------------------------------------------------
-- joining
--------------------------------------------------------
local function inTransit(player)
	-- a party passing through this public server on its way to a private one
	-- (PrivatePartyRouter) never takes part here
	if RunService:IsStudio() then return false end
	if workspace:GetAttribute("IsReservedServer") == true then return false end
	local data = player:GetJoinData()
	local td = data and data.TeleportData
	return type(td) == "table" and td.PrivateParty == true
end

local function onPlayerAdded(player)
	if inTransit(player) then
		player:SetAttribute("FC_Transit", true)
		return
	end
	joinSeq += 1
	joinOrder[player] = joinSeq
	firstJoin = firstJoin or os.clock()
	lastJoin = os.clock()

	local data = player:GetJoinData()
	local td = data and data.TeleportData
	if type(td) == "table" then
		local n = tonumber(td.PartySize)
		if n then expected = math.max(expected, math.clamp(n, 1, TL.MaxPlayers)) end
	end
	workspace:SetAttribute("FC_Expected", expected)

	if state() ~= "Waiting" and state() ~= "Countdown" then
		player:SetAttribute("FC_Late", true)
	end

	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
	buildAvatar(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, p) end

Players.PlayerRemoving:Connect(function(player)
	joinOrder[player] = nil
	slotOf[player] = nil
	local a = avatars:FindFirstChild(tostring(player.UserId))
	if a and state() == "Waiting" then a:Destroy() end
end)

--------------------------------------------------------
-- skip vote: once a majority of the party still here votes to
-- skip, everyone goes straight to the fight
--   FC_SkipVotes / FC_SkipNeeded  the tally shown on the button
--   FC_Skipped                     true once it passed
--------------------------------------------------------
local skipVotes = {}   -- [player] = true
local skipped = false
local skipRemote = FC:FindFirstChild("SkipVote") or Instance.new("RemoteEvent")
skipRemote.Name = "SkipVote"
skipRemote.Parent = FC
workspace:SetAttribute("FC_SkipVotes", 0)
workspace:SetAttribute("FC_SkipNeeded", 1)
workspace:SetAttribute("FC_Skipped", false)

local function tallySkip()
	local voters, votes = 0, 0
	for _, p in ipairs(Players:GetPlayers()) do
		if slotOf[p] then
			voters += 1
			if skipVotes[p] then votes += 1 end
		end
	end
	local needed = math.floor(math.max(voters, 1) / 2) + 1
	workspace:SetAttribute("FC_SkipVotes", votes)
	workspace:SetAttribute("FC_SkipNeeded", needed)
	if not skipped and state() == "Cutscene" and voters > 0 and votes >= needed then
		skipped = true
		workspace:SetAttribute("FC_Skipped", true)
	end
end

skipRemote.OnServerEvent:Connect(function(player, vote)
	if state() ~= "Cutscene" or skipped or not slotOf[player] then return end
	skipVotes[player] = vote == true or nil
	tallySkip()
end)
Players.PlayerRemoving:Connect(function(player)
	skipVotes[player] = nil
	task.defer(tallySkip)
end)

--------------------------------------------------------
-- the schedule
--------------------------------------------------------
local function present()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if joinOrder[p] then table.insert(list, p) end
	end
	table.sort(list, function(a, b) return joinOrder[a] < joinOrder[b] end)
	return list
end

local function allAvatarsReady(list)
	for _, p in ipairs(list) do
		if not avatars:FindFirstChild(tostring(p.UserId)) then return false end
	end
	return true
end

local function beginCountdown()
	local list = present()
	local ids = {}
	for i, p in ipairs(list) do
		if i > TL.MaxPlayers then break end
		roster[i] = p
		slotOf[p] = i
		table.insert(ids, tostring(p.UserId))
	end
	workspace:SetAttribute("FC_Roster", table.concat(ids, ","))
	local start = now() + TL.Countdown + 0.5
	-- Studio: workspace:SetAttribute("FC_DebugFrom", "<chapter>") jumps straight to a chapter
	local dbg = RunService:IsStudio() and workspace:GetAttribute("FC_DebugFrom")
	if dbg and TL.ByName[dbg] then start -= TL.ByName[dbg].Start end
	workspace:SetAttribute("FC_Start", start)
	workspace:SetAttribute("FC_State", "Countdown")
end

task.spawn(function()
	-- WAITING
	while state() == "Waiting" do
		task.wait(0.25)
		local list = present()
		if #list == 0 then
			firstJoin = nil
		elseif firstJoin then
			local elapsed = os.clock() - firstJoin
			local settled = os.clock() - (lastJoin or 0)
			local ready = allAvatarsReady(list) or elapsed > TL.WaitForParty + 10
			local go = false
			if expected > 0 and #list >= expected and settled >= 1.5 then go = true end
			if expected == 0 and elapsed >= TL.GatherMin and settled >= TL.SettleAfterJoin then go = true end
			if elapsed >= TL.WaitForParty then go = true end
			if #list >= TL.MaxPlayers and settled >= 1 then go = true end
			if go and ready then beginCountdown() end
		end
	end

	-- COUNTDOWN
	local start = workspace:GetAttribute("FC_Start")
	while now() < start do task.wait(0.05) end
	workspace:SetAttribute("FC_State", "Cutscene")

	-- freeze everybody where they stand (their clients hide the bodies)
	for _, p in ipairs(Players:GetPlayers()) do
		local root = rootOf(p)
		if root then
			if slotOf[p] then place(p, meadowCF(slotOf[p]), true) else placeForState(p) end
		end
	end

	tallySkip()

	-- into the arena on cue
	local arenaAt = start + TL.Chapter(TL.ArenaChapter).Start
	while now() < arenaAt and not skipped do task.wait(0.1) end
	for _, p in ipairs(Players:GetPlayers()) do
		place(p, arenaCF(slotOf[p] or 8), true)
	end

	-- fight
	local endAt = start + TL.Total
	while (now() < endAt or (RunService:IsStudio() and workspace:GetAttribute("FC_HoldFight"))) and not skipped do task.wait(0.05) end
	if skipped then task.wait(0.6) end -- (the clients fade to black first)
	workspace:SetAttribute("FC_State", "Fight")
	for _, p in ipairs(Players:GetPlayers()) do
		place(p, arenaCF(slotOf[p] or math.random(1, 8)), false)
	end
end)

-- Studio helper: workspace:SetAttribute("FC_ForceStart", true) skips the wait
workspace:GetAttributeChangedSignal("FC_ForceStart"):Connect(function()
	if workspace:GetAttribute("FC_ForceStart") and state() == "Waiting" and #present() > 0 then
		beginCountdown()
	end
end)
