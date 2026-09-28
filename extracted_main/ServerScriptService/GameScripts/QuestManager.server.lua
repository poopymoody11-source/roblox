local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local claimRewardEvent = ReplicatedStorage:WaitForChild("ClaimQuestReward")

local ServerScriptService = game:GetService("ServerScriptService")
local InventoryService = require(ServerScriptService.GameScripts.InventoryService)
local QuestDataService = require(ServerScriptService.GameScripts.QuestDataService)

-- the reward template lives in ServerStorage so nobody can walk into it and
-- pick it up off the ground (which also broke the Homeless Guy for everyone)
local poopTool = game:GetService("ServerStorage"):WaitForChild("QuestTools"):WaitForChild("Poop")
local batTool = ReplicatedStorage.AccessibleModels.Bat
local verityBat = ReplicatedStorage.AccessibleModels.VerityBat
local verityPaper = ReplicatedStorage.AccessibleModels:WaitForChild("VerityPaper")
local VerityWords = require(ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("VerityWords"))

-- NPC lapis rewards: the lapis goes into the inventory here as before, and
-- the client (LapisRewardFX) makes the NPC spit it out and fly it into you.
local accessibleEvents = ReplicatedStorage:WaitForChild("AccessibleEvents")
local lapisRewardFx = accessibleEvents:FindFirstChild("LapisReward") or Instance.new("RemoteEvent")
lapisRewardFx.Name = "LapisReward"
lapisRewardFx.Parent = accessibleEvents

local function spitLapis(player, npc, lapisType, amount)
	lapisRewardFx:FireClient(player, npc, lapisType, amount)
end

--==================================================
-- QUEST GIVERS
-- A quest only shows in your quest list once you've
-- talked to the person who gives it. ProximityPrompt.
-- Triggered also fires on the server, so talking to a
-- giver is detected here with no extra remote.
--==================================================

local GIVERS = {
	{ Path = { "HoboQuest", "hoboquester" },         Quest = "HomelessQuest" },
	{ Path = { "ToiletQuest", "toiletquester" },     Quest = "ToiletQuest" },
	{ Path = { "TungQuest", "TungQuester" },         Quest = "TungQuest" },
	{ Path = { "SpeedQuest", "speedquester" },       Quest = "CarKeyQuest" },
	{ Path = { "Villager", "mr villager quest" },    Quest = "VillagerQuest" },
	{ Path = { "VerityQuest", "verityquester" },     Quest = "VerityQuest" },
}

for _, giver in ipairs(GIVERS) do
	task.spawn(function()
		local obj = workspace
		for _, name in ipairs(giver.Path) do
			obj = obj and obj:WaitForChild(name, 30)
		end
		local prompt = obj and obj:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not prompt then
			warn("[QuestManager] no prompt for quest giver " .. table.concat(giver.Path, "."))
			return
		end
		-- Talking alone no longer adds the quest: it's added when you ACCEPT
		-- it in the dialog (the dialog fires ClaimQuestReward "StartQuest").
		local _ = prompt
	end)
end

--==================================================
-- VERITY'S PAPER
-- Handed out when you bring Verity his 20 lapis, taken
-- back once you've recited it. Re-given on join/respawn
-- while you still owe the recital.
--==================================================

local function owesRecital(player)
	return QuestDataService.IsQuestClaimed(player, "VerityQuest")
		and not QuestDataService.IsQuestClaimed(player, "VerityQuest2")
end

local function givePaper(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end
	if backpack:FindFirstChild("VerityPaper") or (player.Character and player.Character:FindFirstChild("VerityPaper")) then return end
	verityPaper:Clone().Parent = backpack
end

local function takePaper(player)
	for _, holder in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		local t = holder and holder:FindFirstChild("VerityPaper")
		if t then t:Destroy() end
	end
end

local function watchPaper(player)
	if not QuestDataService.WaitUntilLoaded(player) then return end
	if owesRecital(player) then givePaper(player) end
	player.CharacterAdded:Connect(function()
		task.wait(1)
		if owesRecital(player) then givePaper(player) end
	end)
end
Players.PlayerAdded:Connect(watchPaper)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(watchPaper, p) end



--==================================================
-- Re-grant tools tied to permanently-claimed quests
-- (quest data itself persists, but the actual Tool instance
-- doesn't -- so we hand it back if they own it but don't have it)
--==================================================

local function playerHasTool(player, tool)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	return (backpack and backpack:FindFirstChild(tool.Name) ~= nil)
		or (character and character:FindFirstChild(tool.Name) ~= nil)
end

local function grantOwnedTools(player)
	if not QuestDataService.WaitUntilLoaded(player) then
		warn("Quest data never loaded for " .. player.Name .. " — can't grant owned tools")
		return
	end

	-- Verity's upgrade REPLACES the plain bat, so don't hand it back afterwards.
	if QuestDataService.IsQuestClaimed(player, "VerityQuest3") then return end

	if QuestDataService.IsQuestClaimed(player, "TungQuest") then
		player:WaitForChild("Backpack", 5)
		if not playerHasTool(player, batTool) then
			local clonedBat = batTool:Clone()
			clonedBat.Parent = player.Backpack
		end
	end
end

Players.PlayerAdded:Connect(grantOwnedTools)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(grantOwnedTools, player)
end

--==================================================
-- Quest claiming
--==================================================

claimRewardEvent.OnServerEvent:Connect(function(player, questName, arg)
	if not QuestDataService.GetData(player) then
		-- Their save data hasn't finished loading yet (or failed to load).
		-- Don't let anything through until it has.
		warn(player.Name .. " tried to claim a quest before their data finished loading")
		return
	end

	-- dialog accepted (e.g. Verity's "upgrade my bat") -- same as talking to them
	if questName == "StartQuest" then
		if type(arg) == "string" and table.find(QuestDataService.ALL_QUESTS, arg) then
			QuestDataService.StartQuest(player, arg)
		end
		return
	end

	if questName == "VillagerQuest" then
		if QuestDataService.GetCanGoIn(player) then return end -- already done, don't charge twice
		-- any 10 lapis from 67 island (a mix of 67 / hell / totem is fine)
		local KINDS = { "67_lapis", "hell_lapis", "totem_lapis" }
		local total = 0
		for _, k in ipairs(KINDS) do total += InventoryService.GetCount(player, k) or 0 end
		if total < 10 then
			print("not enough 67 island lapis")
			return -- player didn't have enough — nothing was removed
		end
		-- take the most plentiful kinds first
		table.sort(KINDS, function(a, b) return (InventoryService.GetCount(player, a) or 0) > (InventoryService.GetCount(player, b) or 0) end)
		local need = 10
		for _, k in ipairs(KINDS) do
			if need <= 0 then break end
			local take = math.min(need, InventoryService.GetCount(player, k) or 0)
			if take > 0 and InventoryService.Remove(player, k, take) then need -= take end
		end
		if need > 0 then
			print("couldn't take all 10 lapis")
			return
		end

		-- Updates the saved session AND PlayerStats.cangoin (so clients see it)
		QuestDataService.SetCanGoIn(player, true)
		QuestDataService.SetQuestClaimed(player, "VillagerQuest")
		QuestDataService.Save(player, true) -- force save immediately

		print(player.Name .. " can go in!")
	end

	if questName == "CarKeyQuest" then
		local playerStats = player:FindFirstChild("PlayerStats")
		if not playerStats then
			return
		end

		local hasCarKey = playerStats:FindFirstChild("hasCarKey")

		-- SECURITY VERIFICATION:
		-- 1. Do they actually have the key?
		-- 2. Have they NOT claimed this before (checked against saved data)?
		if hasCarKey and hasCarKey.Value == true and not QuestDataService.IsQuestClaimed(player, "CarKeyQuest") then
			-- Updates the saved session AND PlayerStats.ClaimedQuests.CarKeyQuest
			QuestDataService.SetQuestClaimed(player, "CarKeyQuest")
			QuestDataService.Save(player, true) -- force save immediately

			InventoryService.Add(player, "normal_lapis", 1000)
			spitLapis(player, workspace:FindFirstChild("SpeedQuest") and workspace.SpeedQuest:FindFirstChild("speedquester"), "normal_lapis", 1000)
			print("SUCCESS: Securely awarded 1000 lapis to " .. player.Name)
		else
			-- If an exploiter fires the event without having the key, or
			-- fires it again after already claiming, it gets blocked here.
			warn("SECURITY: " .. player.Name .. " attempted to illegally claim CarKeyQuest.")
		end
	end

	if questName == "toiletquest" then
		local playerBackpack = player.Backpack
		local playerCharacter = player.Character
		local poop = playerBackpack:FindFirstChild("Poop")
			or (playerCharacter and playerCharacter:FindFirstChild("Poop"))

		if poop and not QuestDataService.IsQuestClaimed(player, "ToiletQuest") then
			poop:Destroy()
			QuestDataService.SetQuestClaimed(player, "ToiletQuest")
			QuestDataService.Save(player, true) -- force save immediately

			InventoryService.Add(player, "diamond_lapis", 1000)
			spitLapis(player, workspace:FindFirstChild("ToiletQuest") and workspace.ToiletQuest:FindFirstChild("toiletquester"), "diamond_lapis", 1000)
		end
	end

	if questName == "ratquest" then
		if not QuestDataService.IsQuestClaimed(player, "HomelessQuest") then
			QuestDataService.SetQuestClaimed(player, "HomelessQuest")
			QuestDataService.Save(player, true)
		end
		local clonedTool = poopTool:Clone()
		clonedTool.Parent = player.Backpack
		print("Gave poop to " .. player.Name)
	end

	if questName == "tungquest" then
		-- the bat is already upgraded; nothing to hand back
		if QuestDataService.IsQuestClaimed(player, "VerityQuest3") then return end

		if QuestDataService.IsQuestClaimed(player, "TungQuest") then
			-- Already unlocked -- hand the tool back if they lost it,
			-- but don't charge them again.
			if not playerHasTool(player, batTool) then
				local clonedTool = batTool:Clone()
				clonedTool.Parent = player.Backpack
				print("Re-gave lost bat to " .. player.Name)
			end
			return
		end

		local success = InventoryService.Remove(player, "golden_lapis", 25)
		if not success then
			print("not enough gold")
			return -- player didn't have enough — nothing was removed
		end

		QuestDataService.SetQuestClaimed(player, "TungQuest")
		QuestDataService.Save(player, true) -- force save immediately

		local clonedTool = batTool:Clone()
		clonedTool.Parent = player.Backpack
		print("Gave bat to " .. player.Name)
	end
	if questName == "VerityQuest3" then
		if not player.PlayerStats:FindFirstChild("defeatedCruelty") then
			return
		end
		QuestDataService.SetQuestClaimed(player, "VerityQuest3")
		QuestDataService.Save(player, true) -- force save immediately

		-- The upgrade replaces the plain bat rather than sitting next to it.
		for _, holder in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
			local old = holder and holder:FindFirstChild("Bat")
			if old and old:IsA("Tool") then old:Destroy() end
		end
		if not (player.Backpack:FindFirstChild("VerityBat")
			or (player.Character and player.Character:FindFirstChild("VerityBat"))) then
			verityBat:Clone().Parent = player.Backpack
		end
		print("Upgraded " .. player.Name .. "'s bat to the Verity Bat")
	end
	
	-- DUNGEON: got past the villager and opened the door -> Evil Speed turned
	-- you away (the short cutscene). That finishes "open the door" and starts
	-- "finish every quest and come back".
	if questName == "DungeonDoor" then
		if not QuestDataService.GetCanGoIn(player) then return end
		if not QuestDataService.IsQuestClaimed(player, "DungeonDoor") then
			QuestDataService.SetQuestClaimed(player, "DungeonDoor")
			QuestDataService.StartQuest(player, "DungeonReturn")
			QuestDataService.Save(player, true)
		end
		return
	end

	-- DUNGEON: came back with everything done and saw the real ending.
	if questName == "DungeonReturn" then
		if QuestDataService.IsQuestClaimed(player, "DungeonReturn") then return end
		local QuestProgress = require(ServerScriptService.GameScripts.QuestProgress)
		local ok, allDone = pcall(QuestProgress.AllDone, player)
		if not (ok and allDone) then
			warn(player.Name .. " tried to finish the dungeon without every quest done")
			return
		end
		QuestDataService.SetQuestClaimed(player, "DungeonDoor")
		QuestDataService.SetQuestClaimed(player, "DungeonReturn")
		QuestDataService.Save(player, true)
		return
	end

	-- Recited the paper. The client sends the full recital; it has to
	-- match Verity's words exactly (case/punctuation don't matter).
	if questName == "VerityQuest2" then
		if not owesRecital(player) then return end
		if type(arg) ~= "string"
			or VerityWords.Normalize(arg) ~= VerityWords.Normalize(VerityWords.Full()) then
			warn(player.Name .. " sent a wrong Verity recital")
			return
		end
		QuestDataService.SetQuestClaimed(player, "VerityQuest2")
		QuestDataService.StartQuest(player, "VerityQuest3")
		QuestDataService.Save(player, true)
		takePaper(player)
	end

	-- Brought Verity 20 Verity Lapis -> he hands over the paper.
	if questName == "VerityQuest" then
		if QuestDataService.IsQuestClaimed(player, "VerityQuest") then
			if owesRecital(player) then givePaper(player) end -- lost it? here's another
			return
		end
		-- He upgrades a bat, so you have to actually own one.
		local hasBat = false
		for _, holder in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
			if holder and (holder:FindFirstChild("Bat") or holder:FindFirstChild("VerityBat")) then hasBat = true end
		end
		if not hasBat then
			warn(player.Name .. " tried to start Verity's upgrade without a bat")
			return
		end
		if InventoryService.GetCount(player, "verity_lapis") < 20 then
			return
		end
		QuestDataService.SetQuestClaimed(player, "VerityQuest")
		QuestDataService.StartQuest(player, "VerityQuest2")
		QuestDataService.Save(player, true)
		givePaper(player)
	end
end)