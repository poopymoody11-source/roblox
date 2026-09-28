-- services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
-- modules
local DialogModule = require(ReplicatedStorage:WaitForChild("DialogModule"))

local claimquest = ReplicatedStorage:WaitForChild("ClaimQuestReward")
-- references
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local questFrame = playerGui:WaitForChild("Screen"):WaitForChild("master"):WaitForChild("QuestUI"):WaitForChild("Frame")
local questlist = questFrame:WaitForChild("ScrollingFrame")

local npc = script.Parent -- Reference to the NPC model
local prompt = npc:WaitForChild("ProximityPrompt")

local dialogObject = DialogModule.new("toilet", npc, prompt)
dialogObject:addDialog("bro im hungry", {"...", "what are you doing here"},{"do you know where i can find evil speed?"})
dialogObject:addDialog("can you get me food", {"nah no thanks", "sure"})
dialogObject:addDialog("do you got food for me",{"yeah dont worry", "nope"})
local playerStats = player:WaitForChild("PlayerStats")
local ClaimedQuests = playerStats:WaitForChild("ClaimedQuests")
local questActive = false
local questCompleted = false
if ClaimedQuests:FindFirstChild("ToiletQuest") then
	questActive = true
	questCompleted = true
end
-- __questSync: keep up with admin resets / claims made elsewhere
local function __questSync(child)
	if child and child.Name ~= "ToiletQuest" then return end
	local done = ClaimedQuests:FindFirstChild("ToiletQuest") ~= nil
	questCompleted = done
	if done then questActive = true
	elseif child == nil or child.Parent == nil then questActive = false end
end
ClaimedQuests.ChildAdded:Connect(__questSync)
ClaimedQuests.ChildRemoved:Connect(function(c) if c.Name == "ToiletQuest" then questActive = false questCompleted = false end end)
player:GetAttributeChangedSignal("QuestsRefresh"):Connect(function() task.wait(0.2) if not ClaimedQuests:FindFirstChild("ToiletQuest") then questActive = false questCompleted = false end end)




local head = script.Parent:WaitForChild("Head")

local assetToClone = ReplicatedStorage:WaitForChild("SpewAsset2")

local SPEW_SPEED = 0.01
local LIFETIME = 4 
local SPEW_DURATION = 5

local function spew()
	local startTime = os.clock()

	while os.clock() - startTime < SPEW_DURATION do
		local clone = assetToClone:Clone()

		-- Move the entire model to the head's position
		clone:PivotTo(head.CFrame)
		clone.Parent = workspace

		local forceX = math.random(-60, -30) 
		local forceY = math.random(10, 30)
		local forceZ = math.random(-15, 15)

		local linVel = Vector3.new(forceX, forceY, forceZ)
		local angVel = Vector3.new(
			math.random(-15, 15), 
			math.random(-15, 15), 
			math.random(-15, 15)
		)

		-- Loop through every part inside the model to apply physics
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false 
				part.AssemblyLinearVelocity = linVel
				part.AssemblyAngularVelocity = angVel
			end
		end

		Debris:AddItem(clone, LIFETIME)

		task.wait(SPEW_SPEED)
	end
end


prompt.Triggered:Connect(function(triggeringPlayer)
	-- Only trigger for the local player running this script
	if triggeringPlayer ~= player then return end

	if not questActive then
		dialogObject:triggerDialog(player, 1)
	else
		local hasInBackpack = player.Backpack:FindFirstChild("Poop")
		local hasInCharacter = player.Character:FindFirstChild("Poop")
		if not questCompleted and (hasInBackpack or hasInCharacter) then
			dialogObject:triggerDialog(player, 3)
		elseif questCompleted then
			dialogObject:hideGui("thank you sir")
		else
			dialogObject:hideGui("im starving")
		end	
	end
end)

-- logic to go through dialogs
dialogObject.responded:Connect(function(responseNum, dialogNum)
	if dialogNum == 1 then
		if responseNum == 1 then
			dialogObject:triggerDialog(player, 2)
		elseif responseNum == 2 then
			dialogObject:hideGui("skibidi toilet is dead", true)
			task.wait(0.5)
			dialogObject:hideGui("so my island ran out of budget")
		elseif responseNum == 3 then
			dialogObject:hideGui("i saw him last on 67 island", true)
			task.wait(0.5)
			dialogObject:hideGui("try looking there")
		end
	end
	
	if dialogNum == 2 then
		if responseNum == 1 then
			dialogObject:hideGui("ahh ok")
		elseif responseNum == 2 then
			dialogObject:hideGui("ay thanks")
			claimquest:FireServer("StartQuest", "ToiletQuest") -- accepted: now it shows in the quest list
			questActive = true
		end
	end
	
	if dialogNum == 3 then
		if responseNum == 1 then
			questActive = true
			questCompleted = true
			dialogObject:hideGui("thank you have some lapis")
			spew()
			claimquest:FireServer("toiletquest")
		elseif responseNum == 2 then
			dialogObject:hideGui("man im hungry")
		end
	end
end)