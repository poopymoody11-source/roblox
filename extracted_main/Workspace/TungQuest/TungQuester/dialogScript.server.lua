-- services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local claimquest = ReplicatedStorage:WaitForChild("ClaimQuestReward")
-- modules
local DialogModule = require(ReplicatedStorage:WaitForChild("DialogModule"))

-- references
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local questFrame = playerGui:WaitForChild("Screen"):WaitForChild("master"):WaitForChild("QuestUI"):WaitForChild("Frame")
local questlist = questFrame:WaitForChild("ScrollingFrame")

local npc = script.Parent -- Reference to the NPC model
local prompt = npc:WaitForChild("ProximityPrompt")

local dialogObject = DialogModule.new("verity", npc, prompt)
dialogObject:addDialog("hi i need 25 gold lapis", {"ok", "no im broke"})
dialogObject:addDialog("I will reward you handsomely if you get me it", {"yes sir", "no thanks"})
dialogObject:addDialog("hey do you have it",{"yeah here it is", "no not yet"})
dialogObject:addDialog("whats up",{"i lost my bat", "tell me something cool"})
local playerStats = player:WaitForChild("PlayerStats")
local ClaimedQuests = playerStats:WaitForChild("ClaimedQuests")
local questActive = false
local questCompleted = false
if ClaimedQuests:FindFirstChild("TungQuest") then
	questActive = true
	questCompleted = true
end
-- __questSync: keep up with admin resets / claims made elsewhere
local function __questSync(child)
	if child and child.Name ~= "TungQuest" then return end
	local done = ClaimedQuests:FindFirstChild("TungQuest") ~= nil
	questCompleted = done
	if done then questActive = true
	elseif child == nil or child.Parent == nil then questActive = false end
end
ClaimedQuests.ChildAdded:Connect(__questSync)
ClaimedQuests.ChildRemoved:Connect(function(c) if c.Name == "TungQuest" then questActive = false questCompleted = false end end)
player:GetAttributeChangedSignal("QuestsRefresh"):Connect(function() task.wait(0.2) if not ClaimedQuests:FindFirstChild("TungQuest") then questActive = false questCompleted = false end end)
-- already accepted in an earlier session: skip the intro and go straight to "do you have it"
local startedFolder = playerStats:FindFirstChild("StartedQuests")
if startedFolder and startedFolder:FindFirstChild("TungQuest") then
	questActive = true
end
ClaimedQuests.ChildAdded:Connect(function(c)
	if c.Name == "TungQuest" then
		questActive = true
		questCompleted = true
	end
end)

local function goldCount()
	local lapisFolder = playerStats:FindFirstChild("Lapis")
	local goldObj = lapisFolder and lapisFolder:FindFirstChild("golden_lapis")
	return goldObj and goldObj.Value or 0
end




prompt.Triggered:Connect(function(triggeringPlayer)
	-- Only trigger for the local player running this script
	if triggeringPlayer ~= player then return end

	if not questActive then
		dialogObject:triggerDialog(player, 1)
	else
		local gold = goldCount()

		if gold >= 25 and not questCompleted then


			dialogObject:triggerDialog(player, 3)

		elseif questCompleted then
			dialogObject:triggerDialog(player, 4)
		else
			dialogObject:hideGui(("come back when you have 25 gold lapis (%d/25)"):format(gold))
		end	
	end
end)

-- logic to go through dialogs
dialogObject.responded:Connect(function(responseNum, dialogNum)
	if dialogNum == 1 then
		if responseNum == 1 then
			dialogObject:triggerDialog(player, 2)
		elseif responseNum == 2 then
			dialogObject:hideGui("dang alright")
		end
	end
	
	if dialogNum == 2 then
		if responseNum == 1 then
			dialogObject:hideGui("ok thank you")
			claimquest:FireServer("StartQuest", "TungQuest") -- accepted: now it shows in the quest list
			questActive = true
		elseif responseNum == 2 then
			dialogObject:hideGui("alright suit yourself")
		end
	end
	if dialogNum == 3 then
		if responseNum == 1 then
			questActive = true
			questCompleted = true
			dialogObject:hideGui("thanks for the help", true)
			task.wait(0.5)
			dialogObject:hideGui("heres your reward")
			claimquest:FireServer("tungquest")
			task.wait(0.5)
			dialogObject:hideGui("treasure it well")
			
		elseif responseNum == 2 then
			dialogObject:hideGui("i can wait")
		end
	end
	if dialogNum == 4 then
		if responseNum == 1 then
			dialogObject:hideGui("bro...")
			claimquest:FireServer("tungquest")
		elseif responseNum == 2 then
			dialogObject:hideGui("you can upgrade the bat at another npc")
		end
	end
end)