-- Black cover from the moment you join until the final-cutscene director
-- is ready (it sets FC_CoverOff), so you never see a half-loaded world.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "CutsceneCover"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ResetOnSpawn = false
local f = Instance.new("Frame")
f.Size = UDim2.fromScale(1, 1)
f.BackgroundColor3 = Color3.new(0, 0, 0)
f.BorderSizePixel = 0
f.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local start = os.clock()
repeat
	task.wait(0.05)
until player:GetAttribute("FC_CoverOff") or os.clock() - start > 20
task.wait(0.2)
TweenService:Create(f, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
task.wait(0.9)
gui:Destroy()
