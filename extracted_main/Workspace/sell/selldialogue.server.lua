--==================================================
-- NPC DIALOGUE & SELL SCRIPT
-- Place in: Workspace > [Your NPC] > Script
-- Type: Script (Server)
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DialogModule = require(ReplicatedStorage:WaitForChild("DialogModule"))

local sellRemote = ReplicatedStorage:FindFirstChild("SellRemote")
if not sellRemote then
	sellRemote = Instance.new("RemoteEvent")
	sellRemote.Name = "SellRemote"
	sellRemote.Parent = ReplicatedStorage
end

local npc = script.Parent
local prompt = npc:WaitForChild("ProximityPrompt")

local dialogObject = DialogModule.new("Merchant", npc, prompt)
dialogObject:addDialog("Hello! Would you like to sell your items?", {"Yes, open sell menu", "No, thanks"})

local currentInteractingPlayer = nil

prompt.Triggered:Connect(function(triggeringPlayer)
	currentInteractingPlayer = triggeringPlayer
	dialogObject:triggerDialog(triggeringPlayer, 1)
end)

dialogObject.responded:Connect(function(responseNum, dialogNum)
	if dialogNum == 1 then
		if responseNum == 1 and currentInteractingPlayer then
			dialogObject:hideGui("Opening store...")

			-- Ensure ScreenGui is Enabled on Server
			local playerGui = currentInteractingPlayer:WaitForChild("PlayerGui")
			local screen = playerGui:WaitForChild("Screen", 5)
			local master = screen and screen:WaitForChild("master", 5)
			local sellGui = master and master:WaitForChild("Sell", 5)

			if sellGui then
				if sellGui:IsA("LayerCollector") then sellGui.Enabled = true else sellGui.Visible = true end
			end

			-- Signal the Client to set frame visibilities to true
			workspace:SetAttribute("OpenSellMode", tick())

		elseif responseNum == 2 then
			dialogObject:hideGui("Come back anytime!")
			currentInteractingPlayer = nil
		end
	end
end)