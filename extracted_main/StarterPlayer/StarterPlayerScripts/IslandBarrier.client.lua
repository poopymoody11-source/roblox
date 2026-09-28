--==================================================
-- ISLAND BARRIER  (client)
--
-- The dome round every island you haven't unlocked turns solid for you, so
-- an Elytra glides off it instead of through. Flying close shows a lock
-- banner; bouncing off (or being put back out by IslandGuard) flashes it.
-- Unlocking an island -- ascending, or buying Unlock All Islands / a bundle
-- -- opens its dome immediately.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local modules = ReplicatedStorage:WaitForChild("AccessibleModules")
local AscensionData = require(modules:WaitForChild("AscensionDataModule"))
local Monetization = require(modules:WaitForChild("MonetizationData"))
local notice = ReplicatedStorage:WaitForChild("AccessibleEvents"):WaitForChild("IslandLocked")

local ISLANDS = {
	["67Island"] = "67 Island",
	["VerityIsland"] = "Verity Island",
	["LaPeaceIsland"] = "LaPeace Island",
}

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)

local function ascensions()
	local ls = player:FindFirstChild("leaderstats")
	local stat = ls and (ls:FindFirstChild("Ascensions") or ls:FindFirstChild("Rebirths") or ls:FindFirstChild("Ascension"))
	return stat and stat.Value or 0
end

local function allowed(name)
	return ascensions() >= (AscensionData.Islands[name] or 0) or Monetization.HasIslandAccess(player, name)
end

-- banner
local gui = Instance.new("ScreenGui")
gui.Name = "IslandLock"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")
local banner = Instance.new("Frame")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, -160)
banner.Size = UDim2.fromOffset(440, 64)
banner.Visible = false
banner.BackgroundColor3 = Color3.new(1, 1, 1)
banner.Parent = gui
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 16)
local g = Instance.new("UIGradient", banner)
g.Rotation = 90
g.Color = ColorSequence.new(Color3.fromRGB(96, 30, 40), Color3.fromRGB(34, 12, 22))
local st = Instance.new("UIStroke", banner)
st.Color = Color3.fromRGB(255, 110, 90)
st.Thickness = 2.5
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 6)
title.Size = UDim2.new(1, -32, 0, 30)
title.FontFace = FONT
title.TextScaled = true
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = banner
local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Position = UDim2.fromOffset(16, 36)
sub.Size = UDim2.new(1, -32, 0, 20)
sub.FontFace = FONT
sub.TextScaled = true
sub.TextColor3 = Color3.fromRGB(255, 200, 190)
sub.Parent = banner

local shownFor, hideAt = nil, 0
local function show(name, flash)
	local need = AscensionData.Islands[name] or 0
	title.Text = "\u{1F512}  " .. string.upper(name) .. " IS LOCKED"
	sub.Text = ("Reach %d ascensions or get Unlock All Islands"):format(need)
	hideAt = os.clock() + 2.5
	if shownFor ~= name then
		shownFor = name
		banner.Visible = true
		TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 70) }):Play()
	end
	if flash then
		st.Thickness = 6
		TweenService:Create(st, TweenInfo.new(0.4), { Thickness = 2.5 }):Play()
	end
end

notice.OnClientEvent:Connect(function(name) show(name, true) end)

local domes = {}
local islands = workspace:WaitForChild("Islands")
for folder, name in pairs(ISLANDS) do
	local isl = islands:WaitForChild(folder, 20)
	local ff = isl and isl:FindFirstChild("ForceField")
	if ff then
		table.insert(domes, { part = ff, name = name, radius = ff.Size.X / 2, solid = nil })
	end
end

local function refresh()
	for _, d in ipairs(domes) do
		local solid = not allowed(d.name)
		if solid ~= d.solid then
			d.solid = solid
			d.part.CanCollide = solid
			d.part.CanQuery = false -- never let the camera snap in against it
			d.part.CanTouch = false
		end
	end
end

refresh()
player.AttributeChanged:Connect(function(attr)
	if attr:sub(1, 5) == "Pass_" then refresh() end
end)
task.spawn(function()
	while true do
		task.wait(2)
		refresh()
	end
end)

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		for _, d in ipairs(domes) do
			if d.solid and (root.Position - d.part.Position).Magnitude < d.radius + 45 then
				show(d.name, false)
			end
		end
	end
	if shownFor and os.clock() > hideAt then
		shownFor = nil
		local tw = TweenService:Create(banner, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -160) })
		tw:Play()
		tw.Completed:Once(function()
			if not shownFor then banner.Visible = false end
		end)
	end
end)
