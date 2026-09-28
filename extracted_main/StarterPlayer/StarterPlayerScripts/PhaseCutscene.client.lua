-- Place in: StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local phaseTwoCameraEvent = ReplicatedStorage:WaitForChild("CrueltyPhaseTwoCamera")

local TWEEN_DURATION = 0.2
local LETTER_DELAY = 0.05
local isLocked = false

local function typeOut(label, fullText, delay)
	label.Text = ""
	for i = 1, #fullText do
		label.Text = string.sub(fullText, 1, i)
		task.wait(delay)
	end
end

phaseTwoCameraEvent.OnClientEvent:Connect(function(targetCFrame, duration)
	if isLocked then return end -- ignore overlapping triggers
	isLocked = true

	duration = duration or 2
	local camera = workspace.CurrentCamera

	-- Fetch the dialogue UI safely with timeouts
	local gui = localPlayer:FindFirstChild("PlayerGui")
	local screenGui = gui and gui:WaitForChild("ScreenGui", 5)
	local speakFrame = screenGui and screenGui:WaitForChild("BossSpeakFrame", 5)
	local speakText = speakFrame and speakFrame:WaitForChild("BossSpeak", 5)

	-- Lock camera to Phase Two camera part
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		local tweenInfo = TweenInfo.new(TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(camera, tweenInfo, {CFrame = targetCFrame})
		tween:Play()
		tween.Completed:Wait()
	end

	-- Phase-2 dialogue is delivered by CrueltyFightService through the boss UI
	-- (BossHealthVisual). This script only does the camera push-in now; it used
	-- to type its own old line here, which played over the new one.

	-- Hold focus for the requested duration
	task.wait(math.max(duration - TWEEN_DURATION, 0))

	-- make sure the legacy speak box never lingers
	if speakText and speakFrame then
		speakText.Text = ""
		speakFrame.Visible = false
	end

	-- Restore player camera control
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	isLocked = false
end)