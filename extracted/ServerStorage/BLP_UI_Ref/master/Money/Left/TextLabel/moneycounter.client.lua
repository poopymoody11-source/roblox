--==================================================
-- PEACEPOINTS UI CONTROLLER
--
-- Place as a LocalScript inside: Money -> Left -> TextLabel
--==================================================

script.Parent.Parent.Visible = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local textLabel = script.Parent
local uiStroke = textLabel:FindFirstChildOfClass("UIStroke")

-- Number abbreviation suffixes (K, M, B, T, etc.)
local abbreviations = {"", "K", "M", "B", "T", "Qa", "Qi"}

local function abbreviateNumber(value)
	if value < 1000 then
		return tostring(math.floor(value))
	end

	local magnitude = math.floor(math.log10(value) / 3)
	local scaled = value / (10 ^ (magnitude * 3))

	-- Format to 1 decimal place (e.g., 1.2M)
	return string.format("%.1f%s", scaled, abbreviations[magnitude + 1] or "??")
end

-- Scales text color and visual effects dynamically based on wealth tier
local function updateVisualTier(value)
	if value >= 1_000_000_000 then -- Billionaire tier: Gold/Rainbow shifting look
		textLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		if uiStroke then
			uiStroke.Color = Color3.fromRGB(150, 50, 255)
			uiStroke.Thickness = 3
		end
	elseif value >= 1_000_000 then -- Millionaire tier: Vibrant Neon Cyan/Blue
		textLabel.TextColor3 = Color3.fromRGB(0, 229, 255)
		if uiStroke then
			uiStroke.Color = Color3.fromRGB(0, 50, 100)
			uiStroke.Thickness = 2.5
		end
	elseif value >= 100_000 then -- Rich tier: Bright Purple
		textLabel.TextColor3 = Color3.fromRGB(180, 50, 255)
		if uiStroke then
			uiStroke.Color = Color3.fromRGB(60, 0, 90)
			uiStroke.Thickness = 2
		end
	else -- Starter tier: Clean Bright Green
		textLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
		if uiStroke then
			uiStroke.Color = Color3.fromRGB(0, 0, 0)
			uiStroke.Thickness = 2
		end
	end
end

local function setupLeaderstats()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then
		textLabel.Text = "0 PP"
		return
	end

	-- Adjust name here if your stat folder uses a different spelling/casing (e.g., "PeacePoints")
	local peacePoints = leaderstats:WaitForChild("PeacePoints", 10) 
		or leaderstats:WaitForChild("peacepoints", 10)
		or leaderstats:WaitForChild("Money", 10)

	if not peacePoints then
		textLabel.Text = "No Stat Found"
		return
	end

	local currentDisplayValue = peacePoints.Value
	local targetValue = peacePoints.Value

	-- Smooth counting animation loop
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		targetValue = peacePoints.Value

		-- Lerp towards target value for smooth number counting animation
		if math.abs(targetValue - currentDisplayValue) > 0.1 then
			currentDisplayValue = currentDisplayValue + (targetValue - currentDisplayValue) * math.min(dt * 12, 1)
		else
			currentDisplayValue = targetValue
		end

		textLabel.Text = abbreviateNumber(currentDisplayValue) .. " PP"
		updateVisualTier(targetValue)
	end)

	player.AncestryChanged:Connect(function()
		if not player.Parent then
			if connection then
				connection:Disconnect()
			end
		end
	end)
end

setupLeaderstats()