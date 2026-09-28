-- LocalScript | StarterPlayerScripts.StingerAimClient
-- Companion to BossStingers.lua. The server has no way to know where a player's mouse is
-- pointing on its own, so this watches for an equipped Stinger tool and, on every click, sends
-- the mouse's hit point to the server via ReplicatedStorage.StingerAim. BossStingers uses the
-- most recent point it's received from you to aim your next throw.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("StingerAim")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local function isStinger(instance)
	return instance:IsA("Tool") and instance:GetAttribute("StingerType") ~= nil
end

local function onChildAdded(child)
	if not isStinger(child) then return end

	-- child:Destroy() (the last stinger being thrown) or unequipping disconnects this on its own
	child.Activated:Connect(function()
		remote:FireServer(mouse.Hit.Position)
	end)
end

local function watch(character)
	for _, child in character:GetChildren() do
		onChildAdded(child)
	end
	character.ChildAdded:Connect(onChildAdded)
end

if player.Character then
	watch(player.Character)
end
player.CharacterAdded:Connect(watch)