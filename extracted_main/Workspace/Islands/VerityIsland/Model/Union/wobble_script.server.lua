local part = script.Parent

local originalCFrame = part.CFrame

local wobbleAngle = 1.5 -- degrees
local wobbleSpeed = 0.93 -- speed

while true do
	local time = os.clock()

	local x = math.sin(time * wobbleSpeed) * math.rad(wobbleAngle)
	local z = math.cos(time * wobbleSpeed) * math.rad(wobbleAngle)

	part.CFrame = originalCFrame * CFrame.Angles(x, 0, z)

	task.wait()
end