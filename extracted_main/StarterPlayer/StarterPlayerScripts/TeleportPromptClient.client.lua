local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local function getTeleportMenu()
	local screen = playerGui:FindFirstChild("Screen")
	local master = screen and screen:FindFirstChild("master")
	return master and master:FindFirstChild("teleport")
end

local function setMenuVisible(menuInstance, visible)
	if not menuInstance then return end
	for _, child in ipairs(menuInstance:GetChildren()) do
		if child:IsA("GuiObject")
			and child.Name ~= "icon"
			and child.Name ~= "keybind"
			and not child.Name:lower():find("notification") then
			child.Visible = visible
		end
	end
end

local function openTeleportMenu()
	setMenuVisible(getTeleportMenu(), true)
end

local function hookPrompt(prompt)
	prompt.Triggered:Connect(function(player)
		if player ~= localPlayer then return end
		openTeleportMenu()
	end)
end

local function handleTagged(instance)
	if instance:IsA("ProximityPrompt") then
		hookPrompt(instance)
	else
		local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then hookPrompt(prompt) end
	end
end

for _, inst in ipairs(CollectionService:GetTagged("TeleportPad")) do
	handleTagged(inst)
end

CollectionService:GetInstanceAddedSignal("TeleportPad"):Connect(handleTagged)