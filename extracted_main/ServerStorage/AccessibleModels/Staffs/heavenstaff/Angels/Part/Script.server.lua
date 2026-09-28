local primaryPart = script.Parent
local model = primaryPart.Parent
local tool = model.Parent

-- Configuration
local DISTANCE_BACK = 10
local DISTANCE_UP = 10
local GLIDE_SPEED = 0.1     -- Lower is smoother/slower gliding (0.01 to 0.3)
local FLOAT_AMPLITUDE = 0.3 -- How high/low it floats
local FLOAT_SPEED = 2       -- How fast it floats

local RunService = game:GetService("RunService")
local character = nil
local updateConnection = nil

-- Function to handle the continuous gliding and floating
local function startFloating()
	local startTime = os.clock()

	updateConnection = RunService.Heartbeat:Connect(function()
		if not character or not character:FindFirstChild("HumanoidRootPart") then return end

		local hrp = character.HumanoidRootPart

		-- 1. Calculate the ideal target position (10 back, 10 up based on player orientation)
		local idealPosition = hrp.Position - (hrp.CFrame.LookVector * DISTANCE_BACK) + (Vector3.new(0, 1, 0) * DISTANCE_UP)

		-- 2. Calculate the ideal target rotation (matching player facing direction)
		local idealRotation = CFrame.Angles(0, math.atan2(-hrp.CFrame.LookVector.X, -hrp.CFrame.LookVector.Z), 0)
		local targetBaseCFrame = CFrame.new(idealPosition) * idealRotation

		-- 3. GLIDE: Smoothly interpolate the model's current frame towards the target base frame
		local currentBaseCFrame = primaryPart.CFrame
		local newBaseCFrame = currentBaseCFrame:Lerp(targetBaseCFrame, GLIDE_SPEED)

		-- 4. FLOAT: Calculate the local up-and-down wave offset
		local wave = math.sin((os.clock() - startTime) * FLOAT_SPEED) * FLOAT_AMPLITUDE
		local waveOffset = Vector3.new(0, wave, 0)

		-- Apply everything to the model
		model:PivotTo(newBaseCFrame + waveOffset)
	end)
end

-- Stop everything
local function stopFloating()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
end

-- Watch for the tool being equipped
tool.Equipped:Connect(function()
	character = tool.Parent
	if character and character:FindFirstChild("HumanoidRootPart") then
		primaryPart.Anchored = true
		startFloating()
	end
end)

-- Watch for the tool being unequipped
tool.Unequipped:Connect(function()
	stopFloating()
	character = nil
	primaryPart.Anchored = false
end)
