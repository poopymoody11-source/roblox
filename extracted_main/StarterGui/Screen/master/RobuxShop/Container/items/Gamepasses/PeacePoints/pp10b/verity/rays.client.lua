local RunService = game:GetService("RunService")

local container = script.Parent
local raysBackground = container:WaitForChild("Rays")
local verityIcon = container:WaitForChild("verity")
local uiStroke = verityIcon:FindFirstChildOfClass("UIStroke")

-- Customization Settings
local ROTATION_SPEED = 25    -- Speed of spinning rays (degrees per second)
local GLOW_SPEED = 3.5       -- Speed of the glowing/pulsing effect
local MIN_RAY_TRANSPARENCY = 0.0  -- Brightest ray state
local MAX_RAY_TRANSPARENCY = 0.45 -- Dimmest ray state

RunService.RenderStepped:Connect(function(deltaTime)
	-- Continuous rotation for background rays
	if raysBackground then
		raysBackground.Rotation = (raysBackground.Rotation + ROTATION_SPEED * deltaTime) % 360

		-- Pulsing glow transparency on rays
		local glowFactor = (math.sin(tick() * GLOW_SPEED) + 1) / 2
		raysBackground.ImageTransparency = MIN_RAY_TRANSPARENCY + (glowFactor * (MAX_RAY_TRANSPARENCY - MIN_RAY_TRANSPARENCY))
	end

	-- Pulsing glow outline on the verity icon frame
	if uiStroke then
		local glowFactor = (math.sin(tick() * GLOW_SPEED) + 1) / 2
		uiStroke.Transparency = glowFactor * 0.6
	end
end)