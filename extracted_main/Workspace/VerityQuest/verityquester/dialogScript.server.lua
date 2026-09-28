-- services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

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

-- the recite prompt lives in StarterPlayerScripts > VerityRecite
local function openRecite()
	local gui = playerGui:WaitForChild("VerityRecite", 10)
	local open = gui and gui:FindFirstChild("Open")
	if open then open:Fire() end
end



local dialogObject = DialogModule.new("verity", npc, prompt)
dialogObject:addDialog("Hey, I'm verity! Ask me anything", {"upgrade my bat", "whats the capital of paris"})

local playerStats = player:WaitForChild("PlayerStats")
local ClaimedQuests = playerStats:WaitForChild("ClaimedQuests")

-- State is read LIVE from PlayerStats every time you talk to him, so it
-- can never drift from the save (the old version cached it at load).
local accepted = false
local function has(name) return ClaimedQuests:FindFirstChild(name) ~= nil end
local function started()
	local s = playerStats:FindFirstChild("StartedQuests")
	return accepted or has("VerityQuest") or (s ~= nil and s:FindFirstChild("VerityQuest") ~= nil)
end
local function verityLapis()
	local l = playerStats:FindFirstChild("Lapis")
	local v = l and l:FindFirstChild("verity_lapis")
	return v and v.Value or 0
end

-- Verity UPGRADES your bat, so you need one first (Tung's quest gives it).
-- Without this he handed out the paper to people with nothing to upgrade.
local function hasBat()
	for _, holder in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		if holder and (holder:FindFirstChild("Bat") or holder:FindFirstChild("VerityBat")) then
			return true
		end
	end
	return false
end

prompt.Triggered:Connect(function(triggeringPlayer)
	-- Only trigger for the local player running this script
	if triggeringPlayer ~= player then return end

	if has("VerityQuest3") then
		dialogObject:hideGui("Hey! It's me Verity! Ask me anything.")

	elseif has("VerityQuest2") then
		if playerStats:FindFirstChild("defeatedCruelty") then
			dialogObject:hideGui("Great job! Here's your upgrade!")
			claimquest:FireServer("VerityQuest3")
		else
			dialogObject:hideGui("The portal is open. Hop in. Whatever is waiting inside... end it for me.")
		end

	elseif has("VerityQuest") then
		-- he already gave you the paper: recite it
		dialogObject:hideGui("Read the words on my paper out loud. Every. Single. Line.")
		task.wait(1.2)
		openRecite()

	elseif not started() then
		if not hasBat() then
			dialogObject:hideGui("I upgrade BATS, sweetie. Go get one from Tung first, then come back to me ~merciii")
			return
		end
		dialogObject:triggerDialog(player, 1)

	elseif not hasBat() then
		dialogObject:hideGui("You lost your bat?! Get another one from Tung -- I can't upgrade thin air.")

	elseif verityLapis() >= 20 then
		claimquest:FireServer("VerityQuest")
		dialogObject:hideGui("I see you have gathered 20 verity lapis...", true)
		task.wait(1.2)
		dialogObject:hideGui("Take this piece of paper and recite the words written on it, one line at a time.", true)
		-- wait for the server to hand the paper over, then open the prompt
		local t = 0
		while not has("VerityQuest") and t < 5 do task.wait(0.1) t += 0.1 end
		task.wait(1)
		openRecite()

	else
		dialogObject:hideGui("I see you haven't completed your quest yet and you had the AUDACITY to come back to me. ("
			.. math.min(verityLapis(), 20) .. "/20 verity lapis)")
	end
end)

-- logic to go through dialogs
dialogObject.responded:Connect(function(responseNum, dialogNum)
	if dialogNum == 1 then
		if responseNum == 1 then
			dialogObject:hideGui("Collect 20 Verity Lapis and then return to me ~merciii")
			questFrame.Visible = true
			-- adds it to the quest list (QuestUI draws the row)
			claimquest:FireServer("StartQuest", "VerityQuest")
			accepted = true
		elseif responseNum == 2 then
			dialogObject:hideGui("Oui Oui Oui it is France merci~!")
		end
	end
	if dialogNum == 2 then
		
	end
end)