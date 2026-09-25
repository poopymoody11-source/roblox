local RunService = game:GetService("RunService")

local guiObject = script.Parent -- Frame, ImageLabel, Button, etc.

local SPEED = 0.5 -- Speed multiplier (Lower = slower rainbow, Higher = faster)

RunService.RenderStepped:Connect(function()
	local hue = (os.clock() * SPEED) % 1
	guiObject.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
end)