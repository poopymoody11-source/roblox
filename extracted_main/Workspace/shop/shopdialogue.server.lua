--==================================================
-- NPC DIALOGUE SERVER SCRIPT
-- Place in: Workspace > [Your NPC] > Script
-- Type: Script (Server)
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local accessibleEvents = ReplicatedStorage:FindFirstChild("AccessibleEvents")
if not accessibleEvents then
	accessibleEvents = Instance.new("Folder")
	accessibleEvents.Name = "AccessibleEvents"
	accessibleEvents.Parent = ReplicatedStorage
end

local shopRemote = accessibleEvents:FindFirstChild("ShopRemote")
if not shopRemote then
	shopRemote = Instance.new("RemoteEvent")
	shopRemote.Name = "ShopRemote"
	shopRemote.Parent = accessibleEvents
end

local npc = script.Parent
local prompt = npc:WaitForChild("ProximityPrompt")

-- Allow prompt to appear through walls
prompt.RequiresLineOfSight = false

prompt.Triggered:Connect(function(player)
	shopRemote:FireClient(player, "OpenDialog", npc)
end)