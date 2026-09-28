local part = script.Parent
local head = part.Parent.Parent:WaitForChild("Head")
local wobbleAngle = 8 -- degrees
local wobbleSpeed = 2 -- speed

while true do
	local time = os.clock()

	-- Calculate wobble rotation
	local x = math.sin(time * wobbleSpeed) * math.rad(wobbleAngle)
	local z = math.cos(time * wobbleSpeed) * math.rad(wobbleAngle)

	-- Calculate position 0.5 studs above the head
	local targetPosition = head.Position + Vector3.new(0, 1.5 + (head.Size.Y / 2) + (part.Size.Y / 2), 0)

	-- Apply both position and rotation to CFrame
	part.CFrame = CFrame.new(targetPosition) * CFrame.Angles(x, 0, z)

	task.wait()
end
