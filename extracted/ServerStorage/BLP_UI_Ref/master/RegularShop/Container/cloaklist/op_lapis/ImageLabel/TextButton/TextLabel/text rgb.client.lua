local RunService = game:GetService("RunService")

local textObject = script.Parent -- TextLabel, TextButton, or TextBox

local SPEED = 0.5 -- Speed multiplier (Lower = slower rainbow, Higher = faster)

RunService.RenderStepped:Connect(function()
	local hue = (os.clock() * SPEED) % 1
	textObject.TextColor3 = Color3.fromHSV(hue, 1, 1)
end)