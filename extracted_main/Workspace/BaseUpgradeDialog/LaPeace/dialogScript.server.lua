-- services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- modules
local DialogModule = require(ReplicatedStorage:WaitForChild("DialogModule"))

-- references
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

local npc = script.Parent -- Reference to the NPC model
local prompt = npc:WaitForChild("ProximityPrompt")

local dialogObject = DialogModule.new("verity", npc, prompt)
dialogObject:addDialog("Hey, do you want to open base upgrades?", {"Yes", "No", "How do I become Lapeace?"})

--==================================================
-- SHOW / HIDE THE BASE UPGRADE PANEL
--
-- Screen has ResetOnSpawn on, so every respawn builds a brand new
-- BaseUpgrade panel. This script used to grab the panel ONCE when it
-- started; after your first death it was showing and hiding the old,
-- destroyed copy -- that's why "sometimes" talking to him opened
-- nothing. The panel is now looked up fresh every time.
--==================================================

local function getPanel()
	local screen = playerGui:FindFirstChild("Screen") or playerGui:WaitForChild("Screen", 5)
	local master = screen and screen:FindFirstChild("master")
	return master and master:FindFirstChild("BaseUpgrade")
end

local hooked = setmetatable({}, { __mode = "k" })

local setBaseUpgradeVisible
local function hookClose(panel)
	if hooked[panel] then return end
	hooked[panel] = true
	local closeFrame = panel:FindFirstChild("close")
	if not closeFrame then return end
	local function attach(obj)
		if obj:IsA("GuiButton") then
			obj.Activated:Connect(function() setBaseUpgradeVisible(false) end)
		elseif obj:IsA("GuiObject") then
			obj.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setBaseUpgradeVisible(false)
				end
			end)
		end
	end
	attach(closeFrame)
	for _, child in ipairs(closeFrame:GetDescendants()) do attach(child) end
end

setBaseUpgradeVisible = function(visible)
	local panel = getPanel()
	if not panel then return end
	hookClose(panel)
	panel.Visible = true
	for _, name in ipairs({ "Container", "close", "title", "Money" }) do
		local f = panel:FindFirstChild(name)
		if f and f:IsA("GuiObject") then f.Visible = visible end
	end
end

local function isOpen()
	local panel = getPanel()
	local container = panel and panel:FindFirstChild("Container")
	return container ~= nil and container.Visible
end

setBaseUpgradeVisible(false)
player.CharacterAdded:Connect(function()
	task.wait(1)
	local panel = getPanel()
	if panel then hookClose(panel) end
end)

--==================================================
-- DIALOG TRIGGER
--==================================================

prompt.Triggered:Connect(function(triggeringPlayer)
	-- Only trigger for the local player running this script
	if triggeringPlayer ~= player then return end

	-- Already open? Talking to him again just closes it, rather than
	-- stacking a second dialog on top of the panel.
	if isOpen() then
		setBaseUpgradeVisible(false)
		return
	end

	dialogObject:triggerDialog(player, 1)
end)

dialogObject.responded:Connect(function(responseNum, dialogNum)
	if dialogNum == 1 then
		if responseNum == 1 then
			dialogObject:hideGui("Opening base upgrades...")
			setBaseUpgradeVisible(true)
			-- Belt and braces: the dialog's own tidy-up runs a moment later and
			-- used to be able to hide the panel again right after opening it.
			task.delay(0.35, function()
				if not isOpen() then setBaseUpgradeVisible(true) end
			end)
		elseif responseNum == 2 then
			dialogObject:hideGui("Alright, come back anytime!")
		elseif responseNum == 3 then
			dialogObject:hideGui("It is said that you must first defeat evil speed.")
		end
	end
end)