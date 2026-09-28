local TweenService = game:GetService("TweenService")

local Player = game:GetService("Players")
local player = Player.LocalPlayer

local trigger = script.Parent
local villager = workspace:WaitForChild("Villager", 5)
local targetModel = villager and villager:WaitForChild("IronGolem", 5)

local moveTime = 1.5 -- Time in seconds for the movement
local moveDistance = 9 -- Distance in studs

local isTriggered = false

-- Helper function to smoothly animate model's pivot CFrame
local function moveModel(fromCFrame, toCFrame)
	if not targetModel then return end

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = fromCFrame

	local connection = cframeValue.Changed:Connect(function(newCFrame)
		targetModel:PivotTo(newCFrame)
	end)

	local tweenInfo = TweenInfo.new(moveTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(cframeValue, tweenInfo, {Value = toCFrame})

	tween:Play()
	tween.Completed:Wait() -- Pause script execution until the tween finishes

	connection:Disconnect()
	cframeValue:Destroy()
end

trigger.Touched:Connect(function(hit)
	if isTriggered then return end
	--local cangoin = false
	
	
	local character = hit.Parent
	local hitPlayer = game.Players:GetPlayerFromCharacter(character)

	-- 1. Stop if it wasn't a player, OR if it wasn't the local player
	if not hitPlayer or hitPlayer ~= player then 
		return 
	end

	-- 2. Safely check for PlayerStats
	local playerStats = hitPlayer:FindFirstChild("PlayerStats")
	if playerStats then
		local cangoin = playerStats:FindFirstChild("cangoin")

		-- 3. If they have the stat, let them pass without triggering the trap
		if cangoin and cangoin.Value == true then
			print("Player is allowed in, skipping trap!")
			return
		end
	end


		
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid and humanoid.Health > 0 then
		isTriggered = true -- Prevent multiple simultaneous triggers

		humanoid.WalkSpeed = 0
		
		local startCFrame = targetModel:GetPivot()
		local raisedCFrame = startCFrame + Vector3.new(0, moveDistance, 0)

		-- 1. Move model up
		moveModel(startCFrame, raisedCFrame)

		-- 2. Wait 1 second and kill player
		task.wait(1)
		humanoid.Health = 0

		-- 3. Wait 3 seconds
		task.wait(3)

		-- 4. Move model back down to start position
		moveModel(raisedCFrame, startCFrame)

		-- 5. Reset trigger lock so it can activate again
		isTriggered = false
	end
end)