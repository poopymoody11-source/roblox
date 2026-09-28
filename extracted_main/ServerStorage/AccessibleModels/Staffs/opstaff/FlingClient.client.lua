--==================================================
-- COMMAND STAFF  (CLIENT)
-- Click / tap to fire the fling shockwave where you aim.
-- Shows "CLICK TO FLING" while held until used once
-- (same style as the Elytra prompt).
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local tool = script.Parent
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local flingRemote = ReplicatedStorage:WaitForChild("StaffFling")

local COOLDOWN = 1.6
local lastFire = 0
local equipped = false

--------------------------------------------------
-- hint
--------------------------------------------------
local hintGui

local function buildHint()
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then return end
	hintGui = pg:FindFirstChild("StaffHint")
	if hintGui then return end

	hintGui = Instance.new("ScreenGui")
	hintGui.Name = "StaffHint"
	hintGui.ResetOnSpawn = false
	hintGui.IgnoreGuiInset = true
	hintGui.DisplayOrder = 40
	hintGui.Enabled = false
	hintGui.Parent = pg

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.87, 0)
	frame.Size = UDim2.new(0.28, 0, 0.062, 0)
	frame.BackgroundColor3 = Color3.fromRGB(18, 14, 10)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = hintGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 150, 60)
	stroke.Transparency = 0.15
	stroke.Parent = frame
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 6.2
	ratio.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0.92, 0, 0.7, 0)
	label.Position = UDim2.new(0.04, 0, 0.15, 0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 252, 235)
	label.Text = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		and "TAP TO FLING  (PVP ON)" or "CLICK TO FLING  (PVP ON)"
	label.Parent = frame
	local ts = Instance.new("UIStroke")
	ts.Thickness = 2
	ts.Color = Color3.new(0, 0, 0)
	ts.Parent = label

	TweenService:Create(stroke, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.75 }):Play()
end

local function syncHint()
	-- One-shot: shown while the staff is held, but only until the player has
	-- actually flung something once. The server persists that in the grant
	-- ledger and clears the StaffHint attribute, so it never comes back.
	local show = equipped and player:GetAttribute("StaffHint") ~= false and not (function()
		for k, v in pairs(player:GetAttributes()) do if v and k:sub(1, 8) == "HideHud_" then return true end end
		return workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable
	end)()
	if show then buildHint() end
	if hintGui then hintGui.Enabled = show end
end

player:GetAttributeChangedSignal("StaffHint"):Connect(syncHint)

--------------------------------------------------
-- camera kick for the shooter
--------------------------------------------------
local function kick()
	local cam = workspace.CurrentCamera
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 0.25 then conn:Disconnect() return end
		local a = (1 - t / 0.25) * 0.6
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * a * 2), math.rad((math.random() - 0.5) * a * 2), 0)
	end)
end

--------------------------------------------------
-- fire
--------------------------------------------------
tool.Activated:Connect(function()
	local now = os.clock()
	-- vs Cruelty every click counts (server caps it at ~4/s)
	local cc = workspace:FindFirstChild("CrueltyCutscene")
	local bossUp = cc and cc:FindFirstChild("Cruelty_Active") ~= nil
	if now - lastFire < (bossUp and 0.25 or COOLDOWN) then return end
	lastFire = now

	flingRemote:FireServer(mouse.Hit and mouse.Hit.Position or nil)
	kick()

	if player:GetAttribute("StaffHint") ~= false then
		player:SetAttribute("StaffHint", false) -- hide instantly; server persists it
		local r = ReplicatedStorage:FindFirstChild("StaffFlung")
		if r then r:FireServer() end
		syncHint()
	end
end)

tool.Equipped:Connect(function()
	equipped = true
	syncHint()
end)

tool.Unequipped:Connect(function()
	equipped = false
	syncHint()
end)

tool.AncestryChanged:Connect(function()
	if not tool:IsDescendantOf(game) then
		equipped = false
		syncHint()
	end
end)
