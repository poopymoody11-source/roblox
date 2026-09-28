--==================================================
-- ASCENSION CLIENT CONTROLLER (FIXED REMOTE)
-- Place as a LocalScript: rebirth -> AscensionClient
--==================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

if not game:IsLoaded() then
	game.Loaded:Wait()
end

--==================================================
-- UI REFERENCES (MATCHING EXPLORER CASING)
--==================================================
local screenGui = script.Parent -- rebirth

-- Title frame directly under rebirth
local titleFrame = screenGui:WaitForChild("title", 10)
local titleTextLabel = titleFrame and (titleFrame:FindFirstChildWhichIsA("TextLabel", true) or titleFrame:WaitForChild("TextLabel", 5))

-- Container & Bar elements
local container = screenGui:WaitForChild("Container", 10)

local barContainer = container and container:WaitForChild("Bar", 10)
local outerFrame = barContainer and barContainer:WaitForChild("Frame", 5)
local fillFrame = outerFrame and outerFrame:FindFirstChild("Frame")
local barTextLabel = barContainer and barContainer:FindFirstChildWhichIsA("TextLabel", true)

-- ENFORCE CLIPS DESCENDANTS & FILL ALIGNMENT
if barContainer then barContainer.ClipsDescendants = true end
if outerFrame then outerFrame.ClipsDescendants = true end

if fillFrame then
	fillFrame.ClipsDescendants = true
	fillFrame.Position = UDim2.new(0, 0, 0, 0)
	fillFrame.AnchorPoint = Vector2.new(0, 0)
	fillFrame.ZIndex = 2
end

-- Re-parent bar text to outerFrame so green fill bar scaling never affects text overlay
if barTextLabel and outerFrame then
	barTextLabel.Parent = outerFrame
	barTextLabel.Size = UDim2.new(1, 0, 1, 0)
	barTextLabel.Position = UDim2.new(0, 0, 0, 0)
	barTextLabel.AnchorPoint = Vector2.new(0, 0)
	barTextLabel.BackgroundTransparency = 1
	barTextLabel.TextXAlignment = Enum.TextXAlignment.Center
	barTextLabel.TextYAlignment = Enum.TextYAlignment.Center
	barTextLabel.ZIndex = 10
end

-- Buttons and Info Labels
local buyButton = container and (container:FindFirstChild("buy") or container:FindFirstChild("Buy"))
local cashLabel = container and (container:FindFirstChild("cash") or container:FindFirstChild("Cash"))
local itemLabel = container and (container:FindFirstChild("item") or container:FindFirstChild("Item"))
local islandLabel = container and (container:FindFirstChild("island") or container:FindFirstChild("Island"))

local function getTextObject(instance)
	if not instance then return nil end
	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		return instance
	end
	return instance:FindFirstChildWhichIsA("TextLabel", true)
end

local targetCashLabel = getTextObject(cashLabel)
local targetItemLabel = getTextObject(itemLabel)
local targetIslandLabel = getTextObject(islandLabel)

-- Remote Event Setup (Matching LeaderstatsSetup: AccessibleEvents > ShopEvent)
local accessibleEvents = ReplicatedStorage:WaitForChild("AccessibleEvents", 10)
local shopEvent = accessibleEvents and accessibleEvents:WaitForChild("ShopEvent", 10)

--==================================================
-- SOUND EFFECTS
--==================================================
local successSound = Instance.new("Sound")
successSound.SoundId = "rbxassetid://10066947742"
successSound.Volume = 0.15
successSound.Parent = SoundService

local errorSound = Instance.new("Sound")
errorSound.SoundId = "rbxassetid://132281440773764"
errorSound.Volume = 0.08
errorSound.Parent = SoundService

--==================================================
-- NOTIFICATION UI SETUP
--==================================================
local notifLabel = screenGui:FindFirstChild("AscensionNotification")
if not notifLabel then
	notifLabel = Instance.new("TextLabel")
	notifLabel.Name = "AscensionNotification"
	notifLabel.Size = UDim2.new(0.6, 0, 0.06, 0)
	notifLabel.Position = UDim2.new(0.2, 0, 0.03, 0)
	notifLabel.BackgroundTransparency = 1
	notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	notifLabel.TextStrokeTransparency = 1
	notifLabel.RichText = false
	notifLabel.TextScaled = true
	notifLabel.Text = ""
	notifLabel.Visible = false
	notifLabel.ZIndex = 100
	notifLabel.Parent = screenGui

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Parent = notifLabel
end

local activeAnim = nil

local function showNotification(message, isError)
	notifLabel.Text = message

	local stroke = notifLabel:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = Color3.fromRGB(0, 0, 0) end

	if isError then
		notifLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		SoundService:PlayLocalSound(errorSound)
	else
		notifLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
		SoundService:PlayLocalSound(successSound)
	end

	if activeAnim then activeAnim:Cancel() end

	notifLabel.Position = UDim2.new(0.2, 0, 0.01, 0)
	notifLabel.TextTransparency = 1
	if stroke then stroke.Transparency = 1 end
	notifLabel.Visible = true

	local popTween = TweenService:Create(notifLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.2, 0, 0.03, 0),
		TextTransparency = 0
	})

	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	end

	popTween:Play()
	activeAnim = popTween

	task.delay(2, function()
		if notifLabel.Text == message then
			local exitTween = TweenService:Create(notifLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.2, 0, 0.01, 0),
				TextTransparency = 1
			})
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
			exitTween:Play()
			exitTween.Completed:Connect(function()
				if notifLabel.TextTransparency == 1 then
					notifLabel.Visible = false
				end
			end)
		end
	end)
end

--==================================================
-- ASCENSION CUSTOM CONFIGURATION (LEVELS 0 TO 25)
--==================================================
local DEFAULT_BASE_COST = 100000

local ASCENSION_CONFIG = {
	Levels = {
		[0] = { Cost = 1000, Multiplier = 1,    Title = "ASCENSION 0",    Item = "N/A", Island = "N/A" },
		[1] = { Cost = 3300, Multiplier = 1.5,    Title = "ASCENSION I",    Item = "N/A", Island = "N/A" },
		[2] = { Cost = 24000, Multiplier = 2,  Title = "ASCENSION II",   Item = "N/A", Island = "67 Island" },
		[3] = { Cost = 63000, Multiplier = 2.5,    Title = "ASCENSION III",  Item = "N/A", Island = "N/A" },
		[4] = { Cost = 79000, Multiplier = 3,  Title = "ASCENSION IV",   Item = "N/A", Island = "N/A" },
		[5] = { Cost = 150000, Multiplier = 3.5,   Title = "ASCENSION V",    Item = "N/A", Island = "N/A" },
		[6] = { Cost = 180000, Multiplier = 4,   Title = "ASCENSION VI",   Item = "N/A", Island = "N/A" },
		[7] = { Cost = 410000, Multiplier = 4.5, Title = "ASCENSION VII",  Item = "N/A", Island = "N/A" },
		[8] = { Cost = 2300000, Multiplier = 5,   Title = "ASCENSION VIII", Item = "N/A", Island = "Verity Island" },
		[9] = { Cost = 2700000, Multiplier = 5.5,   Title = "ASCENSION IX",   Item = "N/A", Island = "N/A" },
		[10] = { Cost = 3000000, Multiplier = 6,   Title = "ASCENSION X",    Item = "N/A", Island = "N/A" },
		[11] = { Cost = 3400000, Multiplier = 6.5,   Title = "ASCENSION XI",   Item = "N/A", Island = "N/A" },
		[12] = { Cost = 5100000, Multiplier = 7,  Title = "ASCENSION XII",  Item = "N/A", Island = "N/A" },
		[13] = { Cost = 5600000, Multiplier = 7.5,  Title = "ASCENSION XIII", Item = "N/A", Island = "N/A" },
		[14] = { Cost = 6200000, Multiplier = 8,  Title = "ASCENSION XIV",  Item = "N/A", Island = "N/A" },
		[15] = { Cost = 6800000, Multiplier = 8.5,  Title = "ASCENSION XV",   Item = "N/A", Island = "LaPeace Island" },
		[16] = { Cost = 13000000, Multiplier = 9,  Title = "ASCENSION XVI",  Item = "N/A", Island = "N/A" },
		[17] = { Cost = 14000000, Multiplier = 9.5,  Title = "ASCENSION XVII", Item = "N/A", Island = "N/A" },
		[18] = { Cost = 16000000, Multiplier = 10,  Title = "ASCENSION XVIII",Item = "N/A", Island = "N/A" },
		[19] = { Cost = 17000000, Multiplier = 10.5,  Title = "ASCENSION XIX",  Item = "N/A", Island = "N/A" },
		[20] = { Cost = 23000000, Multiplier = 11,  Title = "ASCENSION XX",   Item = "N/A", Island = "N/A" },
		[21] = { Cost = 24000000, Multiplier = 11.5, Title = "ASCENSION XXI",  Item = "N/A", Island = "N/A" },
		[22] = { Cost = 45000000, Multiplier = 12, Title = "ASCENSION XXII", Item = "N/A", Island = "N/A" },
		[23] = { Cost = 48000000, Multiplier = 12.5, Title = "ASCENSION XXIII",Item = "N/A", Island = "N/A" },
		[24] = { Cost = 51000000, Multiplier = 13, Title = "ASCENSION XXIV", Item = "N/A", Island = "N/A" },
		[25] = { Cost = 63750000, Multiplier = 13.5, Title = "ASCENSION XXV",  Item = "N/A", Island = "N/A" },
	},
	Items = {},
	Islands = {},
}

local abbreviations = {"", "K", "M", "B", "T", "Qa", "Qi"}

local function formatNumber(value)
	if not value or value < 1000 then return tostring(math.floor(value or 0)) end
	local magnitude = math.floor(math.log10(value) / 3)
	local scaled = value / (10 ^ (magnitude * 3))
	return string.format("%.1f%s", scaled, abbreviations[magnitude + 1] or "??")
end

--==================================================
-- WHAT THE NEXT ASCENSION COSTS
--
-- Read from AscensionDataModule, never from the local
-- ASCENSION_CONFIG.Levels table below. That table is a
-- display fallback only: it had already drifted from
-- the server's numbers, and it knows nothing about the
-- 2x Ascensions pass, so a pass holder would have seen
-- full price on the bar and then ascended at half.
--
-- GetCostFor reads the player's Pass_DoubleAscensions
-- attribute, which replicates, so this matches the
-- server exactly.
--==================================================

local AscensionData do
	local modules = game:GetService("ReplicatedStorage"):WaitForChild("AccessibleModules", 10)
	local moduleScript = modules and modules:WaitForChild("AscensionDataModule", 10)
	if moduleScript then
		local ok, result = pcall(require, moduleScript)
		if ok then AscensionData = result end
	end
end

local function getRequiredPP(level)
	if AscensionData and AscensionData.GetCostFor then
		return AscensionData.GetCostFor(player, level)
	end

	-- Fallbacks below only run if the module failed to load.
	if ASCENSION_CONFIG.Levels[level] and ASCENSION_CONFIG.Levels[level].Cost then
		return ASCENSION_CONFIG.Levels[level].Cost
	end

	return math.floor(51000000 * (1.25 ^ (level - 24)))
end

local function getCashMultiplier(level)
	if ASCENSION_CONFIG.Levels[level] and ASCENSION_CONFIG.Levels[level].Multiplier then
		return ASCENSION_CONFIG.Levels[level].Multiplier
	end
	return level + 1
end

local function getTitleText(level)
	if ASCENSION_CONFIG.Levels[level] and ASCENSION_CONFIG.Levels[level].Title then
		return ASCENSION_CONFIG.Levels[level].Title
	end
	return "ASCENSION " .. tostring(level)
end

local function getItemAtLevel(level)
	if ASCENSION_CONFIG.Levels[level] and ASCENSION_CONFIG.Levels[level].Item then
		return ASCENSION_CONFIG.Levels[level].Item
	end
	return ASCENSION_CONFIG.Items[level]
end

local function getIslandAtLevel(level)
	if ASCENSION_CONFIG.Levels[level] and ASCENSION_CONFIG.Levels[level].Island then
		return ASCENSION_CONFIG.Levels[level].Island
	end
	return ASCENSION_CONFIG.Islands[level]
end

local function getNextItemUnlock(targetLevel)
	local currentItem = getItemAtLevel(targetLevel)
	if currentItem and currentItem ~= "N/A" then
		return "New Item: " .. currentItem
	end

	for level = targetLevel + 1, 100 do
		local futureItem = getItemAtLevel(level)
		if futureItem and futureItem ~= "N/A" then
			return "Next: " .. futureItem .. " (Rebirth " .. level .. ")"
		end
	end
	return nil
end

local function getNextIslandUnlock(targetLevel)
	local currentIsland = getIslandAtLevel(targetLevel)
	if currentIsland and currentIsland ~= "N/A" then
		return "New Island: " .. currentIsland
	end

	for level = targetLevel + 1, 100 do
		local futureIsland = getIslandAtLevel(level)
		if futureIsland and futureIsland ~= "N/A" then
			return "Next: " .. futureIsland .. " (Rebirth " .. level .. ")"
		end
	end
	return "All islands unlocked!"
end

--==================================================
-- STAT RETRIEVAL & UI UPDATES
--==================================================
local function getLeaderstat(possibleNames)
	local leaderstats = player:FindFirstChild("leaderstats") or player:FindFirstChild("stats") or player:FindFirstChild("Leaderstats")
	if not leaderstats then return nil end
	for _, name in ipairs(possibleNames) do
		local stat = leaderstats:FindFirstChild(name)
		if stat then return stat end
	end
	return nil
end

local function getStats()
	local ppStat = getLeaderstat({"PeacePoints", "peacepoints", "Peace Points", "PP", "Money", "Cash", "Points"})
	local ascensionStat = getLeaderstat({"Ascensions", "Ascension", "Rebirths", "Rebirth", "Ascend", "Stage", "Level"})

	local currentPP = ppStat and ppStat.Value or 0
	local currentLevel = ascensionStat and ascensionStat.Value or 0

	return currentPP, currentLevel
end

local updateReady -- (the "ASCENSION READY" pill, set up further down)

local function updateUI()
	if updateReady then task.defer(updateReady) end
	local currentPP, currentLevel = getStats()
	local requiredPP = getRequiredPP(currentLevel)
	local nextLevel = currentLevel + 1

	if titleTextLabel then
		titleTextLabel.Text = getTitleText(currentLevel)
	end

	local progressRatio = math.clamp(currentPP / requiredPP, 0, 1)

	if fillFrame then
		TweenService:Create(fillFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(progressRatio, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0)
		}):Play()
	end

	if barTextLabel then
		barTextLabel.Text = string.format("%s PP / %s PP", formatNumber(currentPP), formatNumber(requiredPP))
	end

	if targetCashLabel then
		targetCashLabel.Text = string.format("o %dx PP > %dx PP", getCashMultiplier(currentLevel), getCashMultiplier(nextLevel))
	end

	if targetItemLabel then
		local item = getNextItemUnlock(nextLevel)
		targetItemLabel.Text = item and ("o " .. item) or ""
		targetItemLabel.Visible = item ~= nil
	end

	if targetIslandLabel then
		targetIslandLabel.Text = "o " .. getNextIslandUnlock(nextLevel)
	end
end

--==================================================
-- BUTTON CLICK BINDING
--==================================================
local function bindClick(obj, callback)
	if not obj then return end

	if obj:IsA("GuiButton") then
		obj.MouseButton1Click:Connect(callback)
	else
		local childButton = obj:FindFirstChildWhichIsA("GuiButton", true)
		if childButton then
			childButton.MouseButton1Click:Connect(callback)
		else
			obj.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					callback()
				end
			end)
		end
	end
end

bindClick(buyButton, function()
	local currentPP, currentLevel = getStats()
	local requiredPP = getRequiredPP(currentLevel)

	if currentPP < requiredPP then
		showNotification("NEED " .. formatNumber(requiredPP) .. " PEACEPOINTS TO ASCEND!", true)
	else
		showNotification("SUCCESSFULLY ASCENDED!", false)
		if shopEvent then
			shopEvent:FireServer("Ascend") -- FIXED: Firing ShopEvent instead of old ascendEvent
		end
	end
end)

--==================================================
-- SKIP WITH ROBUX  ("buyR$" button)
-- Buys the Skip Ascension developer product; the server
-- ascends you in ProcessReceipt (MonetizationService).
--==================================================
local MarketplaceService = game:GetService("MarketplaceService")
local skipButton = container and container:FindFirstChild("buyR$")
local MonetizationData do
	local modules = ReplicatedStorage:WaitForChild("AccessibleModules", 10)
	local ok, result = pcall(function() return require(modules:WaitForChild("MonetizationData")) end)
	if ok then MonetizationData = result end
end
local skipInfo = MonetizationData and MonetizationData.SkipAscension

if skipButton and skipInfo then
	local skipLabel = skipButton:FindFirstChildWhichIsA("TextLabel")
	local function currentTier()
		local _, level = getStats()
		return MonetizationData.SkipTierFor(level)
	end
	local function refreshSkip()
		local tier = currentTier()
		if skipLabel then
			skipLabel.Text = (tier and tier.Id ~= 0) and ("SKIP R$" .. tier.Price) or "SKIP (SOON)"
		end
	end
	refreshSkip()
	task.spawn(function()
		local ls = player:WaitForChild("leaderstats", 20)
		local asc = ls and (ls:WaitForChild("Ascensions", 10) or ls:FindFirstChild("Rebirths"))
		if asc then asc.Changed:Connect(refreshSkip) end
		refreshSkip()
	end)

	bindClick(skipButton, function()
		local tier = currentTier()
		if not tier or tier.Id == 0 then
			showNotification("SKIP ASCENSION IS COMING NEVER!", true)
			return
		end
		pcall(function()
			MarketplaceService:PromptProductPurchase(player, tier.Id)
		end)
	end)

	local doneEvent = ReplicatedStorage:WaitForChild("SkipAscensionDone", 10)
	if doneEvent then
		doneEvent.OnClientEvent:Connect(function(level)
			showNotification("ASCENSION SKIPPED! NOW ASCENSION " .. tostring(level), false)
			updateUI()
		end)
	end
end

--==================================================
-- AUTOMATIC SYNC & LISTENERS
--==================================================
local hookedStats = {}

local function hookStat(stat)
	if stat and not hookedStats[stat] then
		hookedStats[stat] = true
		stat.Changed:Connect(updateUI)
		if stat:IsA("ValueBase") then
			stat:GetPropertyChangedSignal("Value"):Connect(updateUI)
		end
	end
end

--==================================================
-- "ASCENSION READY" PILL
-- Pops out next to the [R] button the moment you have
-- enough PP to ascend, pulses so you notice, and opens
-- the ascend menu when tapped. Goes away once you
-- ascend or open the menu. Button + Activated, so it
-- works with mouse, touch and gamepad.
--==================================================
do
	local icon = screenGui:FindFirstChild("icon")
	local old = screenGui:FindFirstChild("AscendReady")
	if old then old:Destroy() end

	local pill = Instance.new("TextButton")
	pill.Name = "AscendReady"
	pill.AnchorPoint = Vector2.new(1, 0.5)
	pill.Size = UDim2.fromScale(0.1, 0.042)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Text = ""
	pill.AutoButtonColor = true
	pill.Visible = false
	pill.ZIndex = 20
	pill.Parent = screenGui
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0.5, 0)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(120, 255, 140), Color3.fromRGB(40, 190, 80))
	grad.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(10, 50, 20)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = pill
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 3.6
	ar.Parent = pill
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.9)
	label.Position = UDim2.fromScale(0.03, 0.05)
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	-- (TextWrapped must stay ON: switching it off also switches TextScaled
	-- off, which is why this text came out tiny. The no-break space keeps
	-- it on one line.)
	label.TextScaled = true
	label.Text = "ASCEND\u{00A0}READY!"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.ZIndex = 21
	label.Parent = pill
	local ls = Instance.new("UIStroke")
	ls.Thickness = 2
	ls.Color = Color3.fromRGB(10, 50, 20)
	ls.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = pill

	-- sits just left of the [R] button (and follows it if it moves)
	local function place()
		if not icon then
			pill.Position = UDim2.fromScale(0.915, 0.57)
			return
		end
		pill.Position = UDim2.new(
			icon.Position.X.Scale - 0.006, icon.Position.X.Offset,
			icon.Position.Y.Scale + icon.Size.Y.Scale / 2, icon.Position.Y.Offset + icon.Size.Y.Offset / 2)
	end
	place()
	if icon then
		icon:GetPropertyChangedSignal("Position"):Connect(place)
		icon:GetPropertyChangedSignal("Size"):Connect(place)
	end

	local ding = Instance.new("Sound")
	ding.SoundId = "rbxassetid://10066947742"
	ding.Volume = 0.2
	ding.Parent = SoundService

	local pulse = TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 })
	local wasReady = false

	local function menuOpen()
		return container ~= nil and container.Visible
	end

	updateReady = function()
		local pp, level = getStats()
		local ready = pp >= getRequiredPP(level)
		local show = ready and not menuOpen()
		if show and not pill.Visible then
			pill.Visible = true
			scale.Scale = 0
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			task.delay(0.36, function() if pill.Visible then pulse:Play() end end)
		elseif not show and pill.Visible then
			pulse:Cancel()
			pill.Visible = false
		end
		-- a little ding the moment you first cross the line
		if ready and not wasReady then SoundService:PlayLocalSound(ding) end
		wasReady = ready
	end

	pill.Activated:Connect(function()
		-- open the ascend menu the same way the [R] key does
		for _, child in ipairs(screenGui:GetChildren()) do
			if child:IsA("GuiObject") and child ~= pill and child.Name ~= "icon" and child.Name ~= "keybind"
				and not child.Name:lower():find("notification") then
				child.Visible = true
			end
		end
		updateReady()
	end)
	if container then
		container:GetPropertyChangedSignal("Visible"):Connect(updateReady)
	end
	-- (closing ANY menu hides every child of this frame, the pill too -
	-- so it re-checks itself twice a second rather than only on PP changes)
	task.spawn(function()
		while pill.Parent do
			task.wait(0.5)
			pcall(updateReady)
		end
	end)
end

updateUI()

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 20) or player:WaitForChild("stats", 5)
	if leaderstats then
		for _, child in ipairs(leaderstats:GetChildren()) do
			hookStat(child)
		end

		leaderstats.ChildAdded:Connect(function(child)
			hookStat(child)
			updateUI()
		end)
	end

	for _ = 1, 20 do
		updateUI()
		task.wait(0.5)
	end
end)