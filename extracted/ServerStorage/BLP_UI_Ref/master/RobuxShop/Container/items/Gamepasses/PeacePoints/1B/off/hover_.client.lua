local RunService = game:GetService("RunService")

local icon = script.Parent

-- Customization Settings
local SWAY_SPEED = 1     -- How fast it tilts back and forth
local SWAY_ANGLE = 6    -- How many degrees it rotates left and right

local baseRotation = icon.Rotation

RunService.RenderStepped:Connect(function()
	-- Smoothly rocks back and forth around its starting rotation
	icon.Rotation = baseRotation + math.sin(tick() * SWAY_SPEED) * SWAY_ANGLE
end)