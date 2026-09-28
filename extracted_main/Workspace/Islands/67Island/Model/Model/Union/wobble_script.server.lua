local part = script.Parent

local originalCFrame = part.CFrame

local wobbleAngle = 1 -- degrees
local wobbleSpeed = 1.2 -- speed

while true do
	local time = os.clock()

	local x = math.sin(time * wobbleSpeed) * math.rad(wobbleAngle)
	local z = math.cos(time * wobbleSpeed) * math.rad(wobbleAngle)

	part.CFrame = originalCFrame * CFrame.Angles(x, 0, z)

	task.wait()
end