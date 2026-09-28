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
successSound.Volume = 0.25
successSound.Parent = SoundService

local errorSound = Instance.new("Sound")
errorSound.SoundId = "rbxassetid://132281440773764"
errorSound.Volume = 0.12
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
		[0]  = { Cost = 100000,      Multiplier = 1,    Title = "ASCENSION 0",    Item = "N/A", Island = "67 Island" },
		[1]  = { Cost = 250000,      Multiplier = 2,    Title = "ASCENSION I",    Item = "N/A", Island = "N/A" },
		[2]  = { Cost = 500000,      Multiplier = 3,  Title = "ASCENSION II",   Item = "N/A", Island = "N/A" },
		[3]  = { Cost = 1000000,     Multiplier = 4,    Title = "ASCENSION III",  Item = "N/A", Island = "N/A" },
		[4]  = { Cost = 2500000,     Multiplier = 5,  Title = "ASCENSION IV",   Item = "N/A", Island = "N/A" },
		[5]  = { Cost = 5000000,     Multiplier = 6,   Title = "ASCENSION V",    Item = "N/A", Island = "Verity Island" },
		[6]  = { Cost = 10000000,    Multiplier = 7,   Title = "ASCENSION VI",   Item = "N/A", Island = "N/A" },
		[7]  = { Cost = 25000000,    Multiplier = 8, Title = "ASCENSION VII",  Item = "N/A", Island = "N/A" },
		[8]  = { Cost = 50000000,    Multiplier = 9,   Title = "ASCENSION VIII", Item = "N/A", Island = "N/A" },
		[9]  = { Cost = 100000000,   Multiplier = 10,   Title = "ASCENSION IX",   Item = "N/A", Island = "N/A" },
		[10] = { Cost = 250000000,   Multiplier = 11,   Title = "ASCENSION X",    Item = "N/A", Island = "N/A" },
		[11] = { Cost = 500000000,   Multiplier = 12,   Title = "ASCENSION XI",   Item = "N/A", Island = "N/A" },
		[12] = { Cost = 1000000000,  Multiplier = 13,  Title = "ASCENSION XII",  Item = "N/A", Island = "N/A" },
		[13] = { Cost = 2500000000,  Multiplier = 14,  Title = "ASCENSION XIII", Item = "N/A", Island = "N/A" },
		[14] = { Cost = 5000000000,  Multiplier = 15,  Title = "ASCENSION XIV",  Item = "N/A", Island = "N/A" },
		[15] = { Cost = 10000000000, Multiplier = 16,  Title = "ASCENSION XV",   Item = "N/A", Island = "N/A" },
		[16] = { Cost = 18000000000, Multiplier = 17,  Title = "ASCENSION XVI",  Item = "N/A", Island = "N/A" },
		[17] = { Cost = 28000000000, Multiplier = 18,  Title = "ASCENSION XVII", Item = "N/A", Island = "N/A" },
		[18] = { Cost = 40000000000, Multiplier = 19,  Title = "ASCENSION XVIII",Item = "N/A", Island = "N/A" },
		[19] = { Cost = 52000000000, Multiplier = 20,  Title = "ASCENSION XIX",  Item = "N/A", Island = "N/A" },
		[20] = { Cost = 65000000000, Multiplier = 21,  Title = "ASCENSION XX",   Item = "N/A", Island = "N/A" },
		[21] = { Cost = 75000000000, Multiplier = 22, Title = "ASCENSION XXI",  Item = "N/A", Island = "N/A" },
		[22] = { Cost = 84000000000, Multiplier = 23, Title = "ASCENSION XXII", Item = "N/A", Island = "N/A" },
		[23] = { Cost = 90000000000, Multiplier = 24, Title = "ASCENSION XXIII",Item = "N/A", Island = "N/A" },
		[24] = { Cost = 95000000000, Multiplier = 25, Title = "ASCENSION XXIV", Item = "N/A", Island = "N/A" },
		[25] = { Cost = 100000000000, Multiplier = 26, Title = "ASCENSION XXV",  Item = "N/A", Island = "La Peace Island" },
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

local function getRequiredPP(level)
	if ASCENSION_CONFIG.Levels[level] and ASCENSION_CONFIG.Levels[level].Cost then
		return ASCENSION_CONFIG.Levels[level].Cost
	end
	return DEFAULT_BASE_COST * (level + 1)
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
	if currentItem then
		return currentItem == "N/A" and "N/A" or ("New Item: " .. currentItem)
	end

	for level = targetLevel + 1, 100 do
		local futureItem = getItemAtLevel(level)
		if futureItem and futureItem ~= "N/A" then
			return "Next: " .. futureItem .. " (Rebirth " .. level .. ")"
		end
	end
	return "N/A"
end

local function getNextIslandUnlock(targetLevel)
	local currentIsland = getIslandAtLevel(targetLevel)
	if currentIsland then
		return currentIsland == "N/A" and "N/A" or ("New Island: " .. currentIsland)
	end

	for level = targetLevel + 1, 100 do
		local futureIsland = getIslandAtLevel(level)
		if futureIsland and futureIsland ~= "N/A" then
			return "Next: " .. futureIsland .. " (Rebirth " .. level .. ")"
		end
	end
	return "N/A"
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

local function updateUI()
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
		targetCashLabel.Text = string.format("o %dx Cash > %dx Cash", getCashMultiplier(currentLevel), getCashMultiplier(nextLevel))
	end

	if targetItemLabel then
		targetItemLabel.Text = "o " .. getNextItemUnlock(nextLevel)
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