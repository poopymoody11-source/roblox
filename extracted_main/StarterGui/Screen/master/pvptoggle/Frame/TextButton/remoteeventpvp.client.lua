local ReplicatedStorage = game:GetService("ReplicatedStorage")
local pvpEvent = ReplicatedStorage:WaitForChild("AccessibleEvents"):WaitForChild("pvptoggle")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local button = script.Parent
local frame = button.Parent
local label = frame:FindFirstChild("TextLabel")
local stroke = frame:FindFirstChildOfClass("UIStroke")

local ON_COLOR = Color3.fromRGB(85, 255, 127)
local OFF_COLOR = Color3.fromRGB(255, 70, 70)
local baseStrokeColor = stroke and stroke.Color

-- The label mirrors the server's PvpEnabled attribute, so it's
-- always the truth (also after respawning or an admin toggle).
local function refresh()
	local on = player:GetAttribute("PvpEnabled") == true
	local locked = player:GetAttribute("PvpLocked") == true
	local shielded = (player:GetAttribute("SpawnProtectedUntil") or 0) > workspace:GetServerTimeNow()
	if label then
		if locked and shielded then
			label.Text = "PVP: 🛡️"
		elseif locked then
			label.Text = "PVP: 🔒"
		else
			label.Text = on and "PVP: ✅" or "PVP: ❌"
		end
	end
	if stroke then
		stroke.Color = on and ON_COLOR or (baseStrokeColor or OFF_COLOR)
	end
end

player:GetAttributeChangedSignal("PvpEnabled"):Connect(refresh)
player:GetAttributeChangedSignal("PvpLocked"):Connect(refresh)
player:GetAttributeChangedSignal("SpawnProtectedUntil"):Connect(function()
	refresh()
	task.delay(30.2, refresh)
end)
refresh()

button.MouseButton1Click:Connect(function()
	pvpEvent:FireServer()
end)