local RunService = game:GetService("RunService")

local centerModel = script.Parent
local centerPart = centerModel:WaitForChild("Part", 5) 

if not centerPart then
	warn("Could not find a part named 'Part' inside the script's parent model!")
	return
end

local RADIUS = 100
-- CHANGED: Lowered speed significantly for a very slow, drifting motion
local ROTATION_SPEED = 0.05 

local clouds = {}
for _, object in ipairs(workspace:GetDescendants()) do
	if object.Name == "Cloud" and (object:IsA("BasePart") or object:IsA("Model")) then
		table.insert(clouds, object)

		-- Ensure physics doesn't interfere
		if object:IsA("BasePart") then
			object.Anchored = true
			object.CanCollide = false
		elseif object:IsA("Model") then
			for _, descendant in ipairs(object:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
					descendant.CanCollide = false
				end
			end
		end
	end
end

local numClouds = #clouds
local cloudAngles = {}
for i = 1, numClouds do
	cloudAngles[i] = (i / numClouds) * (math.pi * 2)
end

RunService.Heartbeat:Connect(function(deltaTime)
	if not centerPart or not centerPart.Parent then return end

	local centerCFrame = centerPart.CFrame

	for i, cloud in ipairs(clouds) do
		if cloud and cloud.Parent then
			cloudAngles[i] = cloudAngles[i] + (ROTATION_SPEED * deltaTime)

			local xOffset = math.cos(cloudAngles[i]) * RADIUS
			local zOffset = math.sin(cloudAngles[i]) * RADIUS

			local targetPosition = centerCFrame:PointToWorldSpace(Vector3.new(xOffset, 0, zOffset))

			cloud:PivotTo(CFrame.new(targetPosition, centerCFrame.Position))
		end
	end
end)
