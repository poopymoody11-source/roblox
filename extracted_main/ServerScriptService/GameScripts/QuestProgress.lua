--==================================================
-- QUEST PROGRESS  (server helper)
--
-- One place that knows what "every quest" means. Used by
-- BaseUpgradeService (the final Bossfight upgrade needs
-- all quests done) and TitleService (Quest Master title).
--==================================================

local QuestDataService = require(script.Parent:WaitForChild("QuestDataService"))

local QuestProgress = {}

-- Every quest, with the name shown to players.
QuestProgress.Quests = {
	{ Id = "HomelessQuest", Name = "Find the hobo's lost pet rat" },
	{ Id = "ToiletQuest",   Name = "Feed the hungry guy" },
	{ Id = "TungQuest",     Name = "Bring Tung 25 Gold Lapis" },
	{ Id = "CarKeyQuest",   Name = "Find the keys in the obby" },
	{ Id = "VillagerQuest", Name = "Bring Mr Villager 10 lapis from 67 Island", CanGoIn = true },
	{ Id = "VerityQuest",   Name = "Gather 20 Verity Lapis" },
	{ Id = "VerityQuest2",  Name = "Recite Verity's words" },
	{ Id = "VerityQuest3",  Name = "Enter the Portal" },
}

function QuestProgress.IsDone(player, quest)
	if quest.CanGoIn then
		-- the villager quest is stored as CanGoIn rather than a claim
		return QuestDataService.GetCanGoIn(player)
	end
	return QuestDataService.IsQuestClaimed(player, quest.Id)
end

-- Returns done (bool), completedCount, total, missingNames
function QuestProgress.AllDone(player)
	local missing = {}
	local done = 0
	for _, q in ipairs(QuestProgress.Quests) do
		if QuestProgress.IsDone(player, q) then
			done += 1
		else
			table.insert(missing, q.Name)
		end
	end
	return #missing == 0, done, #QuestProgress.Quests, missing
end

-- The final (Bossfight) base upgrade: every quest AND going back into the
-- dungeon once they're all done (DungeonReturn -- the Anti-Spiral ending).
-- Returns done (bool), completedCount, total (9), missingNames
function QuestProgress.FinalDone(player)
	local _, done, total, missing = QuestProgress.AllDone(player)
	total += 1
	if QuestDataService.IsQuestClaimed(player, "DungeonReturn") then
		done += 1
	else
		table.insert(missing, "Go back into the dungeon")
	end
	return #missing == 0, done, total, missing
end

return QuestProgress
