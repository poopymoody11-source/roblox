--==================================================
-- PLOT STATS BILLBOARD
-- Place in: ServerScriptService
--
-- Populates each plot's Leaderboard > stats SurfaceGui with the
-- owner's name, icon, and ascensions. Settings buttons show a
-- "COMING NEVER!" popup instead of toggling anything real yet. The
-- whole player card (border glow, background tint, ascensions text
-- color) changes based on ascension tier, capping at an animated
-- rainbow at the max tier.
--==================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local islandsFolder = workspace:WaitForChild("Islands")
local starterIsland = islandsFolder:WaitForChild("StarterIsland")
local plotsFolder = starterIsland:WaitForChild("IslandPlots")

local TOGGLE_NAMES = {"Allow-Players-Plot", "Audio", "LapisSound", "Low-Graphic-Mode", "music", "pvp"}

--==================================================
-- ASCENSION VISUAL TIERS -- edit thresholds/colors here.
-- Ordered low to high; the LAST entry is the max/rainbow tier.
--==================================================

local ASCENSION_TIERS = {
	{MinAscensions = 0,  Color = Color3.fromRGB(255, 255, 255)}, -- plain white, no ascensions yet
	{MinAscensions = 1,  Color = Color3.fromRGB(150, 220, 255)}, -- light blue
	{MinAscensions = 5,  Color = Color3.fromRGB(130, 255, 150)}, -- green
	{MinAscensions = 10, Color = Color3.fromRGB(255, 200, 70)},  -- gold
	{MinAscensions = 25, Rainbow = true},                        -- max tier -- animated rainbow
}

local RAINBOW_CYCLE_SECONDS = 3
local CARD_GLOW_TRANSPARENCY = 0.75 -- how visible the card's background tint is; lower = stronger tint

--==================================================
-- SHARED STATE
--==================================================

local plotConnections = {}     -- [plot] = { connections... }
local rainbowConnections = {}  -- [playerFrame] = Heartbeat connection
local activeAnims = {}         -- [gui] = active popup tween

--==================================================
-- HELPERS
--==================================================

local function getStatsGui(plot)
	local leaderboard = plot:FindFirstChild("Leaderboard")
	local stats = leaderboard and leaderboard:FindFirstChild("stats")
	if not stats then return nil end

	for _, child in ipairs(stats:GetChildren()) do
		if child:IsA("BasePart") then
			local gui = child:FindFirstChildOfClass("SurfaceGui")
			if gui then return gui end
		end
	end
	return nil
end

local function getTierForAscensions(ascensions)
	local best = ASCENSION_TIERS[1]
	for _, tier in ipairs(ASCENSION_TIERS) do
		if ascensions >= tier.MinAscensions then
			best = tier
		end
	end
	return best
end

--==================================================
-- "COMING NEVER" POPUP (lives inside the SurfaceGui itself)
--==================================================

local function getOrCreatePopup(gui)
	local existing = gui:FindFirstChild("ComingSoonNotif")
	if existing then return existing, existing:FindFirstChildOfClass("UIStroke") end

	local notifLabel = Instance.new("TextLabel")
	notifLabel.Name = "ComingSoonNotif"
	notifLabel.Size = UDim2.new(0.8, 0, 0.08, 0)
	notifLabel.Position = UDim2.new(0.1, 0, 0.02, 0)
	notifLabel.BackgroundTransparency = 1
	notifLabel.TextScaled = true
	notifLabel.Font = Enum.Font.FredokaOne
	notifLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
	notifLabel.Text = "COMING NEVER!"
	notifLabel.Visible = false
	notifLabel.ZIndex = 100
	notifLabel.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Parent = notifLabel

	return notifLabel, stroke
end

local function showComingSoon(gui)
	local notifLabel, stroke = getOrCreatePopup(gui)

	if activeAnims[gui] then activeAnims[gui]:Cancel() end

	notifLabel.Position = UDim2.new(0.1, 0, -0.02, 0)
	notifLabel.TextTransparency = 1
	stroke.Transparency = 1
	notifLabel.Visible = true

	local popTween = TweenService:Create(notifLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.1, 0, 0.02, 0), TextTransparency = 0
	})
	TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	popTween:Play()
	activeAnims[gui] = popTween

	task.delay(1.6, function()
		if notifLabel.Text == "COMING NEVER!" and notifLabel.Visible then
			local exitTween = TweenService:Create(notifLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.1, 0, -0.02, 0), TextTransparency = 1
			})
			TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			exitTween:Play()
			exitTween.Completed:Connect(function()
				if notifLabel.TextTransparency == 1 then notifLabel.Visible = false end
			end)
		end
	end)
end

local function setupButtons(gui)
	local frame = gui:FindFirstChild("Frame")
	local buttons = frame and frame:FindFirstChild("buttons")
	if not buttons then
		return -- (the settings buttons were removed from the plot billboard)
	end

	for _, name in ipairs(TOGGLE_NAMES) do
		local buttonFolder = buttons:FindFirstChild(name, true)
		if buttonFolder then
			local imageButton = buttonFolder:FindFirstChildOfClass("ImageButton")
			if imageButton then
				imageButton.Activated:Connect(function()
					showComingSoon(gui)
				end)
			else
				warn("[PlotStatsBillboard] '" .. name .. "' has no ImageButton child -- skipping.")
			end
		else
			warn("[PlotStatsBillboard] Could not find toggle button: " .. name)
		end
	end
end

--==================================================
-- CARD-WIDE TIER VISUALS (border glow + background tint + text color)
--==================================================

local function getOrCreateCardStroke(playerFrame)
	local stroke = playerFrame:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = playerFrame
	end
	return stroke
end

local function getOrCreateCardGlow(playerFrame)
	local glow = playerFrame:FindFirstChild("TierGlow")
	if not glow then
		glow = Instance.new("Frame")
		glow.Name = "TierGlow"
		glow.Size = UDim2.new(1, 0, 1, 0)
		glow.Position = UDim2.new(0, 0, 0, 0)
		glow.BackgroundTransparency = CARD_GLOW_TRANSPARENCY
		glow.ZIndex = 0
		glow.Parent = playerFrame

		local corner = playerFrame:FindFirstChildOfClass("UICorner")
		if corner then corner:Clone().Parent = glow end
	end
	return glow
end

local function stopRainbow(playerFrame)
	if rainbowConnections[playerFrame] then
		rainbowConnections[playerFrame]:Disconnect()
		rainbowConnections[playerFrame] = nil
	end
end

local function startRainbow(playerFrame, stroke, glow, ascensionsLabel)
	stopRainbow(playerFrame)
	rainbowConnections[playerFrame] = RunService.Heartbeat:Connect(function()
		if not playerFrame.Parent then
			stopRainbow(playerFrame)
			return
		end
		local hue = (os.clock() % RAINBOW_CYCLE_SECONDS) / RAINBOW_CYCLE_SECONDS
		local color = Color3.fromHSV(hue, 1, 1)
		stroke.Color = color
		glow.BackgroundColor3 = color
		if ascensionsLabel then
			ascensionsLabel.TextColor3 = color
		end
	end)
end

local function applyCardTierVisual(playerFrame, ascensionsLabel, ascensions)
	local tier = getTierForAscensions(ascensions)
	local stroke = getOrCreateCardStroke(playerFrame)
	local glow = getOrCreateCardGlow(playerFrame)

	if tier.Rainbow then
		stroke.Thickness = 3
		startRainbow(playerFrame, stroke, glow, ascensionsLabel)
	else
		stopRainbow(playerFrame)
		stroke.Thickness = 2
		stroke.Color = tier.Color
		glow.BackgroundColor3 = tier.Color
		if ascensionsLabel then
			ascensionsLabel.TextColor3 = tier.Color
		end
	end
end

--==================================================
-- STATS DISPLAY
--==================================================

local function refreshStats(plot, player)
	local gui = getStatsGui(plot)
	if not gui then return end

	local frame = gui:FindFirstChild("Frame")
	local playerFrame = frame and frame:FindFirstChild("player")
	if not playerFrame then return end

	local nameLabel = playerFrame:FindFirstChild("name")
	local ascensionsLabel = playerFrame:FindFirstChild("ascensions")
	local iconLabel = playerFrame:FindFirstChild("playericon")

	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = player.Name
	end

	local function updateAscensions()
		if not ascensionsLabel or not ascensionsLabel:IsA("TextLabel") then return end
		local leaderstats = player:FindFirstChild("leaderstats")
		local asc = leaderstats and (leaderstats:FindFirstChild("Ascensions") or leaderstats:FindFirstChild("Rebirths"))
		local count = asc and asc.Value or 0
		ascensionsLabel.Text = "Ascensions: " .. tostring(count)
		applyCardTierVisual(playerFrame, ascensionsLabel, count)
	end
	updateAscensions()

	local leaderstats = player:FindFirstChild("leaderstats")
	local asc = leaderstats and (leaderstats:FindFirstChild("Ascensions") or leaderstats:FindFirstChild("Rebirths"))
	if asc then
		plotConnections[plot] = plotConnections[plot] or {}
		table.insert(plotConnections[plot], asc:GetPropertyChangedSignal("Value"):Connect(updateAscensions))
	end

	if iconLabel and iconLabel:IsA("ImageLabel") then
		local success, content = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if success then
			iconLabel.Image = content
		end
	end
end

-- back to a blank card (someone left, or the plot was never claimed).
-- It used to keep the last owner's name, face, ascensions and colours.
local function resetCard(plot)
	local gui = getStatsGui(plot)
	local frame = gui and gui:FindFirstChild("Frame")
	local playerFrame = frame and frame:FindFirstChild("player")
	if not playerFrame then return end
	stopRainbow(playerFrame)
	local nameLabel = playerFrame:FindFirstChild("name")
	if nameLabel and nameLabel:IsA("TextLabel") then nameLabel.Text = "Unclaimed" end
	local asc = playerFrame:FindFirstChild("ascensions")
	if asc and asc:IsA("TextLabel") then
		asc.Text = "Ascensions: [N/A]"
		asc.TextColor3 = Color3.new(1, 1, 1)
	end
	local title = playerFrame:FindFirstChild("titlestat")
	if title and title:IsA("TextLabel") then
		title.Text = "Title: [N/A]"
		title.TextColor3 = Color3.new(1, 1, 1)
	end
	local icon = playerFrame:FindFirstChild("playericon")
	if icon and icon:IsA("ImageLabel") then icon.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png" end
	local stroke = playerFrame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 3
	end
	local glow = playerFrame:FindFirstChild("TierGlow")
	if glow then glow:Destroy() end
end

local function teardownStats(plot)
	if plotConnections[plot] then
		for _, conn in ipairs(plotConnections[plot]) do
			conn:Disconnect()
		end
		plotConnections[plot] = nil
	end

	local gui = getStatsGui(plot)
	local frame = gui and gui:FindFirstChild("Frame")
	local playerFrame = frame and frame:FindFirstChild("player")
	if playerFrame then
		stopRainbow(playerFrame)
	end
end

--==================================================
-- OWNER WATCHING
--==================================================

local function watchPlot(plot)
	local ownerValue = plot:FindFirstChild("Owner")
	if not ownerValue then return end

	local gui = getStatsGui(plot)
	if gui then
		setupButtons(gui)
	else
		warn("[PlotStatsBillboard] Could not find stats SurfaceGui for " .. plot.Name)
	end

	local function handleOwnerChanged()
		teardownStats(plot)

		local ownerName = ownerValue.Value
		if ownerName == "" or ownerName == nil then
			resetCard(plot)
			return
		end

		local player = Players:FindFirstChild(ownerName)
		if not player then
			resetCard(plot)
			return
		end

		refreshStats(plot, player)
	end

	ownerValue:GetPropertyChangedSignal("Value"):Connect(handleOwnerChanged)

	-- (start blank - the Studio copy of the card still says the builder's name)
	handleOwnerChanged()
end

for _, plot in ipairs(plotsFolder:GetChildren()) do
	watchPlot(plot)
end

plotsFolder.ChildAdded:Connect(watchPlot)