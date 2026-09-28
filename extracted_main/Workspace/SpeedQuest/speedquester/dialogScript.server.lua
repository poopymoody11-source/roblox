-- services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local claimquest = ReplicatedStorage:WaitForChild("ClaimQuestReward")


local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- Locates the "Head" part (assuming this script is inside the parent model)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local head = script.Parent:WaitForChild("Head") 
local assetToClone = ReplicatedStorage:WaitForChild("SpewAsset")

local SPEW_SPEED = 0.1 
local LIFETIME = 4 
local SPEW_DURATION = 3 

local function spewForThreeSeconds()
	local startTime = os.clock()

	while os.clock() - startTime < SPEW_DURATION do
		local clone = assetToClone:Clone()
		
		-- Move the entire model to the head's position
		clone:PivotTo(head.CFrame)
		clone.Parent = workspace

		local forceX = math.random(30, 60) 
		local forceY = math.random(10, 30)
		local forceZ = math.random(-10, 10)

		local linVel = Vector3.new(forceX, forceY, forceZ)
		local angVel = Vector3.new(
			math.random(-15, 15), 
			math.random(-15, 15), 
			math.random(-15, 15)
		)

		-- Loop through every part inside the model to apply physics
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
				part.Anchored = false 
				part.AssemblyLinearVelocity = linVel
				part.AssemblyAngularVelocity = angVel
			end
		end

		Debris:AddItem(clone, LIFETIME)

		task.wait(SPEW_SPEED)
	end
end


-- Start the spewer

-- modules
local DialogModule = require(ReplicatedStorage:WaitForChild("DialogModule"))

-- references
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local questFrame = playerGui:WaitForChild("Screen"):WaitForChild("master"):WaitForChild("QuestUI"):WaitForChild("Frame")
local questlist = questFrame:WaitForChild("ScrollingFrame")

local npc = script.Parent -- Reference to the NPC model
local prompt = npc:WaitForChild("ProximityPrompt")

local dialogObject = DialogModule.new("Mr Speed", npc, prompt)
dialogObject:addDialog("Help i dropped my keys in obby", {"ok i help", "goodbye"})

local playerStats = player:WaitForChild("PlayerStats")
local ClaimedQuests = playerStats:WaitForChild("ClaimedQuests")
local questActive = false
local questCompleted = false
if ClaimedQuests:FindFirstChild("CarKeyQuest") then
	questActive = true
	questCompleted = true
end
-- __questSync: keep up with admin resets / claims made elsewhere
local function __questSync(child)
	if child and child.Name ~= "CarKeyQuest" then return end
	local done = ClaimedQuests:FindFirstChild("CarKeyQuest") ~= nil
	questCompleted = done
	if done then questActive = true
	elseif child == nil or child.Parent == nil then questActive = false end
end
ClaimedQuests.ChildAdded:Connect(__questSync)
ClaimedQuests.ChildRemoved:Connect(function(c) if c.Name == "CarKeyQuest" then questActive = false questCompleted = false end end)
player:GetAttributeChangedSignal("QuestsRefresh"):Connect(function() task.wait(0.2) if not ClaimedQuests:FindFirstChild("CarKeyQuest") then questActive = false questCompleted = false end end)

prompt.Triggered:Connect(function(triggeringPlayer)
	-- Only trigger for the local player running this script
	if triggeringPlayer ~= player then return end

	if not questActive then
		dialogObject:triggerDialog(player, 1)
	else
		local hasCarKey = playerStats:FindFirstChild("hasCarKey")

		if hasCarKey and hasCarKey.Value == true and not questCompleted then
			questCompleted = true

			dialogObject:hideGui("thanks for getting my keys", true)
			task.wait(1)
			dialogObject:hideGui("heres some diamonds")
			claimquest:FireServer("CarKeyQuest")
			spewForThreeSeconds()
		elseif questCompleted then
			dialogObject:hideGui("watch out for evil speed")
		else
			dialogObject:hideGui("i eat rocks")
		end    
	end
end)

-- logic to go through dialogs
dialogObject.responded:Connect(function(responseNum, dialogNum)
	if dialogNum == 1 then
		if responseNum == 1 then
			dialogObject:hideGui("thanks")
			claimquest:FireServer("StartQuest", "CarKeyQuest") -- accepted: now it shows in the quest list
			questFrame.Visible = true

			local newQuest = Instance.new("TextLabel")
			newQuest.Name = "carkeyquest"
			newQuest.Text = "get his keys"
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
			dialogObject:hideGui("aw man")
		end
	end
end)