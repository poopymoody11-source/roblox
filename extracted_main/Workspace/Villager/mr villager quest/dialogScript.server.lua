-- services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local claimquest = ReplicatedStorage:WaitForChild("ClaimQuestReward")
--modules
local DialogModule = require(ReplicatedStorage.DialogModule)




--references
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local questFrame = playerGui:WaitForChild("Screen").master.QuestUI.Frame
local questlist = questFrame:WaitForChild("ScrollingFrame")



local npc = script.Parent -- Reference to the NPC model
local npcGui = npc:WaitForChild("Head"):WaitForChild("gui")
local prompt = npc:WaitForChild("ProximityPrompt")

local dialogObject = DialogModule.new("Farmer", npc, prompt)
dialogObject:addDialog("Hello I am Mr Villager", {"can i come in","i like your house", "eat my poo"})
dialogObject:addDialog("maybe if you do me a favor", {"screw you", "alright"})
dialogObject:addDialog("Get me 10 lapis from 67 island and ill think about it (67, hell or totem - any mix)", {"okay", "no bye"})
dialogObject:addDialog("do you have my 67 island lapis", {"yea here you go", "not for you"})
--
local playerStats = player:WaitForChild("PlayerStats")
-- any lapis from 67 island counts (they're summed)
local ISLAND_LAPIS = { "67_lapis", "hell_lapis", "totem_lapis" }
local function islandLapis()
	local total = 0
	local folder = playerStats:FindFirstChild("Lapis")
	for _, n in ipairs(ISLAND_LAPIS) do
		local v = folder and folder:FindFirstChild(n)
		total += v and v.Value or 0
	end
	return total
end
-- PlayerStats.cangoin ALWAYS exists (QuestDataService creates it on
-- join with Value=false), so checking that it exists made everyone
-- look like they'd already finished. Read its VALUE, live.
local function canGoIn()
	local v = playerStats:FindFirstChild("cangoin")
	return v ~= nil and v.Value == true
end
local questActive = canGoIn()
local questCompleted = canGoIn()
-- __questSync: an admin quest reset turns cangoin back off
local function __watchCanGoIn(val)
	val.Changed:Connect(function()
		questCompleted = val.Value == true
		if not questCompleted then questActive = false end
	end)
end
local __cg = playerStats:FindFirstChild("cangoin")
if __cg then __watchCanGoIn(__cg) end
playerStats.ChildAdded:Connect(function(c) if c.Name == "cangoin" then __watchCanGoIn(c) end end)

local function canGoInKeyLine()
	local has = player.Backpack:FindFirstChild("VillagerKey") or (player.Character and player.Character:FindFirstChild("VillagerKey"))
	if has then return "you can come in, go ahead. use my key on the villager door" end
	return "you can come in, but you need my KEY. it's the glowing one right next to me"
end

-- what happens when triggered
prompt.Triggered:Connect(function(player)
	questCompleted = canGoIn()
	if questCompleted then
		questActive = true
		dialogObject:hideGui(canGoInKeyLine())
		return
	end
	if questActive == false then
		dialogObject:triggerDialog(player, 1)
	else

		local have = islandLapis()
		if have >= 10 then
			dialogObject:triggerDialog(player, 4)
		else
			dialogObject:hideGui("i still need " .. (10 - have) .. " more lapis from 67 island")
		end	
	end
end)

-- logic to go through dialogs
dialogObject.responded:Connect(function(responseNum, dialogNum)
	if dialogNum == 1 then
		if responseNum == 1 then
			dialogObject:hideGui("hmmmm", true)
			task.wait(2)
			dialogObject:triggerDialog(player, 2)
		end
		if responseNum == 2 then
			dialogObject:hideGui("me too me too")
		end
		if responseNum == 3 then
			dialogObject:hideGui("go away freak")
		end
	end
	if dialogNum == 2 then
		if responseNum == 1 then
			dialogObject:hideGui("screw you too")
		end
		if responseNum == 2 then
			dialogObject:triggerDialog(player, 3)
		end
	end
	if dialogNum == 3 then
		if responseNum == 1 then
			dialogObject:hideGui("okay go now")
			claimquest:FireServer("StartQuest", "VillagerQuest") -- accepted: now it shows in the quest list

			-- Dynamically fetch the UI so it doesn't break after death
			local currentScreen = player.PlayerGui:FindFirstChild("Screen")
			if currentScreen then
				local currentQuestFrame = currentScreen.master.QuestUI.Frame
				local currentQuestList = currentQuestFrame.ScrollingFrame

				currentQuestFrame.Visible = true

				local newQuest = Instance.new("TextLabel")
				newQuest.Name = "EmeraldQuest"
				newQuest.Text = "• Get 10 lapis from 67 island"
				newQuest.Size = UDim2.new(1, 0, 0, 30)
				newQuest.BackgroundTransparency = 1
				newQuest.TextColor3 = Color3.fromRGB(255, 255, 255)
				newQuest.TextSize = 16
				newQuest.TextXAlignment = Enum.TextXAlignment.Left
				newQuest.Parent = currentQuestList
				newQuest.Visible = true
			end

			questActive = true
			questCompleted = false
		end
		if responseNum == 2 then
			dialogObject:hideGui("bye bye")
		end
	end
	if dialogNum == 4 then
		if responseNum == 1 then
			dialogObject:hideGui("thanks...", true)
			questCompleted = true
			questActive = true
			claimquest:FireServer("VillagerQuest")
			
			task.wait(4)
			dialogObject:hideGui("you can come in now. grab the glowing KEY right next to me, the door needs it")
		else
			dialogObject:hideGui("alright tell me when")
		end
	end
end)
