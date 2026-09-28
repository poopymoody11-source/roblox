--==================================================
-- ELYTRA FLIGHT  (CLIENT)
--
-- Toggle is a DOUBLE TAP OF JUMP, not F.
--
-- F was already the RobuxShop keybind -- the shop panel
-- shows [F] in the corner -- so pressing it to fly also
-- opened the shop. Jump also works on phones and
-- gamepads for free: UserInputService.JumpRequest fires
-- for the on-screen jump button and the A button, not
-- just the space bar.
--
-- The first time a player has the Elytra, an on-screen
-- prompt explains the control. The moment they fly, it
-- is gone for good (the server remembers).
--==================================================

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local flightSystem = script.Parent
local toggleEvent = flightSystem:WaitForChild("ToggleFlightEvent")
local movementEvent = flightSystem:WaitForChild("UpdateMovementEvent")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- How close together the two jumps have to be. Long enough
-- to be comfortable, short enough that bunny-hopping up a
-- hill doesn't launch you into the sky.
local DOUBLE_TAP_WINDOW = 0.35

-- JumpRequest fires SEVERAL times for one press of space (and
-- keeps firing while it's held). That's why one tap started
-- flight: the repeats of a single press looked like a double
-- tap. Events closer together than this are the same press.
local SAME_PRESS_GAP = 0.1

local isFlying = false
local connection = nil
local lastJump = 0        -- start time of the previous distinct press
local lastJumpEvent = 0   -- time of the most recent JumpRequest of any kind

-- Create Animation Objects
local idleAnim = Instance.new("Animation")
idleAnim.AnimationId = "rbxassetid://98064442064539"

local moveAnim = Instance.new("Animation")
moveAnim.AnimationId = "rbxassetid://113671177001121"

local idleTrack = nil
local moveTrack = nil

-- FIX: Exact Roblox core movement directions mapped perfectly
local function getManualMoveDirection()
	local forward = UIS:IsKeyDown(Enum.KeyCode.W) and -1 or 0
	local backward = UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0
	local left = UIS:IsKeyDown(Enum.KeyCode.A) and -1 or 0
	local right = UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0

	local moveX = left + right     -- Negative is Left, Positive is Right
	local moveZ = forward + backward -- Negative is Forward, Positive is Backward

	if moveX ~= 0 or moveZ ~= 0 then
		return Vector3.new(moveX, 0, moveZ).Unit
	end
	return Vector3.new(0, 0, 0)
end

local function sendFlightData()
	local character = player.Character
	if not character then return end

	local moveDirection = getManualMoveDirection()
	movementEvent:FireServer(camera.CFrame, moveDirection)

	-- Handle clean animation crossfades. The dedicated move
	-- animation (113671177001121) doesn't load for this game,
	-- so if it's empty we keep the glide animation running and
	-- just speed it up -- the server lays the body flat into a
	-- superman dive while moving, which sells the motion.
	local moveOk = moveTrack and moveTrack.Length > 0
	if idleTrack then
		if moveDirection.Magnitude > 0 then
			if moveOk then
				if not moveTrack.IsPlaying then moveTrack:Play(0.15) end
				if idleTrack.IsPlaying then idleTrack:Stop(0.15) end
			else
				if not idleTrack.IsPlaying then idleTrack:Play(0.15) end
				idleTrack:AdjustSpeed(1.6)
			end
		else
			if not idleTrack.IsPlaying then idleTrack:Play(0.15) end
			idleTrack:AdjustSpeed(1)
			if moveTrack and moveTrack.IsPlaying then moveTrack:Stop(0.15) end
		end
	end
end

--==================================================
-- THE ON-SCREEN PROMPT
--
-- Built in code so the Elytra accessory stays a single
-- self-contained object -- nothing to wire up in
-- StarterGui, and it travels with the model.
--==================================================

local hintGui, hintLabel, hintTween

local function buildHint()
	if hintGui and hintGui.Parent then return end

	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end

	-- This script is cloned into every new character, so on a
	-- respawn a fresh copy runs while the old ScreenGui is still
	-- there (ResetOnSpawn is off). Reuse it instead of stacking
	-- a second prompt on top of the first.
	local existing = playerGui:FindFirstChild("ElytraHint")
	if existing then
		hintGui = existing
		hintLabel = existing:FindFirstChild("Text", true)
		return
	end

	hintGui = Instance.new("ScreenGui")
	hintGui.Name = "ElytraHint"
	hintGui.ResetOnSpawn = false
	hintGui.IgnoreGuiInset = true
	hintGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	hintGui.DisplayOrder = 40
	hintGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Pill"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.87, 0)
	frame.Size = UDim2.new(0.28, 0, 0.062, 0)
	frame.BackgroundColor3 = Color3.fromRGB(18, 14, 10)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = hintGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(240, 232, 103)
	stroke.Transparency = 0.15
	stroke.Parent = frame

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 6.2
	ratio.Parent = frame

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Text"
	hintLabel.BackgroundTransparency = 1
	hintLabel.Size = UDim2.new(0.92, 0, 0.7, 0)
	hintLabel.Position = UDim2.new(0.04, 0, 0.15, 0)
	hintLabel.Font = Enum.Font.GothamBold
	hintLabel.TextScaled = true
	hintLabel.TextColor3 = Color3.fromRGB(255, 252, 235)
	hintLabel.Text = "DOUBLE TAP  [ SPACE ]  TO FLY"
	hintLabel.Parent = frame

	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 2
	textStroke.Color = Color3.fromRGB(0, 0, 0)
	textStroke.Parent = hintLabel

	-- Touch devices have no space bar
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then
		hintLabel.Text = "DOUBLE TAP JUMP TO FLY"
	end

	-- Slow pulse so it reads as a prompt rather than furniture
	hintTween = TweenService:Create(
		stroke,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.75 }
	)
	hintTween:Play()
end

local function setHintVisible(visible)
	if visible then
		buildHint()
		if hintGui then hintGui.Enabled = true end
	elseif hintGui then
		hintGui.Enabled = false
	end
end

-- One-shot prompt. The server owns the flag (ElytraHint, backed by the
-- persistent grant ledger) and clears it the first time the player actually
-- flies, so the hint shows until it has done its job and then never again --
-- not after a respawn, not after a rejoin.
local function inCutscene()
	for k, v in pairs(player:GetAttributes()) do
		if v and k:sub(1, 8) == "HideHud_" then return true end
	end
	local cam = workspace.CurrentCamera
	return cam ~= nil and cam.CameraType == Enum.CameraType.Scriptable
end
local function syncHint()
	setHintVisible(player:GetAttribute("ElytraHint") == true and not isFlying and not inCutscene())
end
-- tucked away while a cutscene has the screen
player.AttributeChanged:Connect(function(k) if k:sub(1, 8) == "HideHud_" then syncHint() end end)
workspace.CurrentCamera:GetPropertyChangedSignal("CameraType"):Connect(function() syncHint() end)

-- kept as a name so the landing/spawn call sites stay readable
local function flashHint()
	syncHint()
end

player:GetAttributeChangedSignal("ElytraHint"):Connect(syncHint)
task.defer(syncHint)

--==================================================
-- TOGGLING FLIGHT
--==================================================

local flownRemote = ReplicatedStorage:FindFirstChild("ElytraFlown")

local function setFlying(flying)
	isFlying = flying
	toggleEvent:FireServer(flying) -- the state we want, not "toggle"

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animateScript = character and character:FindFirstChild("Animate")

	if isFlying then
		-- Disable the default character movement script completely
		-- to prevent animation glitching
		if animateScript then
			animateScript.Disabled = true
		end

		if animator then
			for _, track in pairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0)
			end

			-- No animation tracks any more: the uploaded flight animations
			-- either don't load for this game or barely move. The pose is
			-- now set on the SERVER (superman dive while moving, hover pose
			-- while still) by posing the joints, so everyone sees it.
		end

		connection = RunService.RenderStepped:Connect(sendFlightData)

		-- They've flown: hide the prompt (the server still records it).
		setHintVisible(false)
		if player:GetAttribute("ElytraHint") == true then
			flownRemote = flownRemote or ReplicatedStorage:FindFirstChild("ElytraFlown")
			if flownRemote then
				flownRemote:FireServer()
			end
		end
	else
		if connection then
			connection:Disconnect()
			connection = nil
		end
		task.defer(flashHint) -- landed: remind them how to take off again

		if idleTrack then idleTrack:Stop(0.1); idleTrack = nil end
		if moveTrack then moveTrack:Stop(0.1); moveTrack = nil end

		if animateScript then
			animateScript.Disabled = false
		end
		-- The humanoid's state belongs to this client, so the server's
		-- GettingUp doesn't always land -- that left you stuck in the
		-- flight pose ("animation didn't reset"). Do it here as well.
		if humanoid and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end

-- The wings can be removed and re-given while you're in the air (the
-- pass re-applies them). This copy of the script dies with them, so it
-- must hand the normal animations back or they stay switched off.
script.Destroying:Connect(function()
	if connection then connection:Disconnect() connection = nil end
	if not isFlying then return end
	isFlying = false
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animateScript = character and character:FindFirstChild("Animate")
	if animateScript then animateScript.Disabled = false end
	if humanoid and humanoid.Health > 0 then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)

--==================================================
-- DOUBLE TAP JUMP
--
-- JumpRequest rather than a Space keybind: it also
-- fires for the mobile jump button and a gamepad's A,
-- so flight works everywhere without separate bindings.
-- It repeats while jump is held, which is why the window
-- is closed immediately after a successful toggle.
--==================================================

UIS.JumpRequest:Connect(function()
	local now = os.clock()
	local gap = now - lastJumpEvent
	lastJumpEvent = now

	-- Repeat of the press we already counted (or jump being held).
	if gap < SAME_PRESS_GAP then return end

	if now - lastJump <= DOUBLE_TAP_WINDOW then
		lastJump = 0
		setFlying(not isFlying)
	else
		lastJump = now
	end
end)

-- A fresh copy of the wings while an older copy had the normal
-- animations switched off (it was removed without being destroyed):
-- switch them back on, we're not flying yet.
task.defer(function()
	local character = player.Character
	local animateScript = character and character:FindFirstChild("Animate")
	if animateScript and animateScript.Disabled and not isFlying and not inCutscene() then
		animateScript.Disabled = false
	end
end)

-- Flight state lives on the server per character. A respawn
-- clears it there, so the client has to forget too or the
-- next double tap reads as "stop flying" and does nothing.
player.CharacterAdded:Connect(function()
	isFlying = false
	lastJump = 0
	lastJumpEvent = 0
	if connection then
		connection:Disconnect()
		connection = nil
	end
	idleTrack = nil
	moveTrack = nil
	task.defer(flashHint)
end)
