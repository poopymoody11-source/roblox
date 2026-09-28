local RunService = game:GetService("RunService")

local frame = script.Parent

-- Customization Settings
local SPEED = 2          -- Speed of the pink color shift
local MIN_HUE = 0.80     -- Deep pink / magenta end of spectrum
local MAX_HUE = 0.95     -- Soft rose pink end of spectrum

RunService.RenderStepped:Connect(function()
	-- Smoothly cycle back and forth through pink hues
	local sineWave = (math.sin(tick() * SPEED) + 1) / 2
	local currentHue = MIN_HUE + (sineWave * (MAX_HUE - MIN_HUE))

	frame.BackgroundColor3 = Color3.fromHSV(currentHue, 0.75, 1)
end)