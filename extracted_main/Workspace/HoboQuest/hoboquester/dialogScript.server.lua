-- services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local claimquest = ReplicatedStorage:WaitForChild("ClaimQuestReward")
-- modules
local DialogModule = require(ReplicatedStorage:WaitForChild("DialogModule"))
-- (it used to WaitForChild the Poop tool lying in the world here. The script
-- never used it, and on a real server it isn't there for the client, so the
-- wait never finished and the Homeless Guy never became talkable.)

-- references
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local questFrame = playerGui:WaitForChild("Screen"):WaitForChild("master"):WaitForChild("QuestUI"):WaitForChild("Frame")
local questlist = questFrame:WaitForChild("ScrollingFrame")

local npc = script.Parent -- Reference to the NPC model
local prompt = npc:WaitForChild("ProximityPrompt")

local dialogObject = DialogModule.new("verity", npc, prompt)
dialogObject:addDialog("hey can you find my pet rat for me", {"sure", "loser i dont help peasants"})
dialogObject:addDialog("did you find my rat?", {"yeah hes by the big cheese slice", "no hes dead"})
dialogObject:addDialog("hey whats up",{"can i have some more poop", "are you gonna get your rat"})
local playerStats = player:WaitForChild("PlayerStats")
local ClaimedQuests = playerStats:WaitForChild("ClaimedQuests")
local questActive = false
local questCompleted = false
if ClaimedQuests:FindFirstChild("HomelessQuest") then
	questActive = true
	questCompleted = true
end
-- __questSync: keep up with admin resets / claims made elsewhere
local function __questSync(child)
	if child and child.Name ~= "HomelessQuest" then return end
	local done = ClaimedQuests:FindFirstChild("HomelessQuest") ~= nil
	questCompleted = done
	if done then questActive = true
	elseif child == nil or child.Parent == nil then questActive = false end
end
ClaimedQuests.ChildAdded:Connect(__questSync)
ClaimedQuests.ChildRemoved:Connect(function(c) if c.Name == "HomelessQuest" then questActive = false questCompleted = false end end)
player:GetAttributeChangedSignal("QuestsRefresh"):Connect(function() task.wait(0.2) if not ClaimedQuests:FindFirstChild("HomelessQuest") then questActive = false questCompleted = false end end)




prompt.Triggered:Connect(function(triggeringPlayer)
	-- Only trigger for the local player running this script
	if triggeringPlayer ~= player then return end
	-- read the quest state fresh every time (it can replicate in after this
	-- script started, which used to offer the quest again to people who'd done it)
	if ClaimedQuests:FindFirstChild("HomelessQuest") then
		questActive = true
		questCompleted = true
	end

	if not questActive then
		dialogObject:triggerDialog(player, 1)
	else
		local foundRat = playerStats:FindFirstChild("foundRat")

		if foundRat and foundRat.Value == true and not questCompleted then


			dialogObject:triggerDialog(player, 2)

		elseif questCompleted then
			dialogObject:triggerDialog(player, 3)
		else
			dialogObject:hideGui("my rat likes cheese")
		end	
	end
end)

-- logic to go through dialogs
dialogObject.responded:Connect(function(responseNum, dialogNum)
	if dialogNum == 1 then
		if responseNum == 1 then
			dialogObject:hideGui("thanks. he likes eating cheese.")
			claimquest:FireServer("StartQuest", "HomelessQuest") -- accepted: now it shows in the quest list
			questFrame.Visible = true

			local newQuest = Instance.new("TextLabel")
			newQuest.Name = "homeless quest"
			newQuest.Text = "find rat"
			newQuest.Size = UDim2.new(1, 0, 0, 30)
			newQuest.BackgroundTransparency = 1
			newQuest.TextColor3 = Color3.fromRGB(255, 255, 255)
			newQuest.TextSize = 16
			newQuest.TextXAlignment = Enum.TextXAlignment.Left
			newQuest.Parent = questlist
			newQuest.Visible = true

			questActive = true
			questCompleted = false
		elseif responseNum == 2 then
			dialogObject:hideGui(":(")
		end
	end
	
	if dialogNum == 2 then
		if responseNum == 1 then
			questCompleted = true
			questActive = true
			dialogObject:hideGui("thanks for telling me", true)
			task.wait(1)
			dialogObject:hideGui("here have some poop")
			claimquest:FireServer("ratquest")
		elseif responseNum == 2 then
			dialogObject:hideGui("NOOOOOOOOO")
		end
	end
	if dialogNum == 3 then
		if responseNum == 1 then
			dialogObject:hideGui("yeah sure i guess")
			claimquest:FireServer("ratquest")
		elseif responseNum == 2 then
			dialogObject:hideGui("ill go get him later")
		end
	end
end)