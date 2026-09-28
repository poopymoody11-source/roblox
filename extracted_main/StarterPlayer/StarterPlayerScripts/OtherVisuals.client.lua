local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local GroundSlamVisual = ReplicatedStorage:WaitForChild("GroundSlamVisual")
local localPlayer = Players.LocalPlayer

local function spawnRingCube(position, material, color)
	local cube = Instance.new("Part")
	cube.Anchored = true
	cube.CanCollide = false
	cube.Material = material
	cube.Color = color
	cube.Size = Vector3.new(
		math.random(8, 16) / 10,
		math.random(8, 16) / 10,
		math.random(8, 16) / 10
	)

	local randomAngles = CFrame.Angles(
		math.rad(math.random(0, 360)),
		math.rad(math.random(0, 360)),
		math.rad(math.random(0, 360))
	)
	local restCFrame = CFrame.new(position) * randomAngles
	cube.CFrame = restCFrame
	cube.Parent = workspace

	-- Pop up out of the ground
	local popHeight = math.random(3, 10) / 10
	local popTween = TweenService:Create(
		cube,
		TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ CFrame = restCFrame + Vector3.new(0, popHeight, 0) }
	)
	popTween:Play()

	popTween.Completed:Connect(function()
		task.wait(math.random(2, 4) / 10) -- hang briefly, staggered per cube

		local sinkTween = TweenService:Create(
			cube,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = restCFrame - Vector3.new(0, cube.Size.Y, 0), Transparency = 1 }
		)
		sinkTween:Play()
	end)

	Debris:AddItem(cube, 1.2)
end

GroundSlamVisual.OnClientEvent:Connect(function(slamPosition, material, color, ringPositions)
	for _, position in ipairs(ringPositions) do
		spawnRingCube(position, material, color)
	end

	-- Camera shake, scaled by distance
	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local distance = (rootPart.Position - slamPosition).Magnitude
		if distance < 30 then
			local strength = math.clamp(1 - (distance / 30), 0.1, 1)
			-- CameraShakeModule:Shake(strength)
		end
	end
end)