local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local accessibleEvents = ReplicatedStorage:WaitForChild("AccessibleEvents")
local baseUpgradeRemote = accessibleEvents:WaitForChild("BaseUpgradeRemote")

local gui = script.Parent
local container = gui:WaitForChild("Container")
local items = container:WaitForChild("items")
local list = items:WaitForChild("list")

local TRACKS = {
	LapisSlots = {
		FolderName = "lapisslot",
		TierFrames = {"2", "5", "10", "25"},
		UpgradeAction = "UpgradeLapisSlots",
		ConfigKey = "LapisSlotTiers",
	},
	SlotPower = {
		FolderName = "slotpower",
		TierFrames = {"2", "5", "10", "25"},
		UpgradeAction = "UpgradeSlotPower",
		ConfigKey = "SlotPowerTiers",
	},
	Teleport = {
		FolderName = "tp",
		TierFrames = {"2"},
		UpgradeAction = "UpgradeTeleport",
		ConfigKey = "TeleportTier",
	},
	Bossfight = {
		FolderName = "end",
		TierFrames = {"2"},
		UpgradeAction = "UpgradeBossfight",
		ConfigKey = "BossfightTier",
	},
}

local successSound = Instance.new("Sound", SoundService)
successSound.SoundId = "rbxassetid://10066947742"
successSound.Volume = 0.15

local errorSound = Instance.new("Sound", SoundService)
errorSound.SoundId = "rbxassetid://132281440773764"
errorSound.Volume = 0.08

local notifLabel = gui:FindFirstChild("UpgradeNotification")
if not notifLabel then
	notifLabel = Instance.new("TextLabel")
	notifLabel.Name = "UpgradeNotification"
	notifLabel.Size = UDim2.new(0.8, 0, 0.06, 0)
	notifLabel.Position = UDim2.new(0.1, 0, 0.03, 0)
	notifLabel.BackgroundTransparency = 1
	notifLabel.TextScaled = true
	notifLabel.Visible = false
	notifLabel.ZIndex = 100
	notifLabel.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Thickness = 2
	stroke.Parent = notifLabel
end

local notifStroke = notifLabel:FindFirstChildOfClass("UIStroke")
local activeAnim = nil

local function showNotification(message, isError)
	notifLabel.Text = message
	notifLabel.TextColor3 = isError and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(85, 255, 127)
	SoundService:PlayLocalSound(isError and errorSound or successSound)

	if activeAnim then activeAnim:Cancel() end
	notifLabel.Position = UDim2.new(0.1, 0, 0.01, 0)
	notifLabel.TextTransparency = 1
	if notifStroke then notifStroke.Transparency = 1 end
	notifLabel.Visible = true

	local popTween = TweenService:Create(notifLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.1, 0, 0.03, 0), TextTransparency = 0
	})
	if notifStroke then
		TweenService:Create(notifStroke, TweenInfo.new(0.25), {Transparency = 0}):Play()
	end
	popTween:Play()
	activeAnim = popTween

	task.delay(1.8, function()
		if notifLabel.Text == message then
			local exitTween = TweenService:Create(notifLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.1, 0, 0.01, 0), TextTransparency = 1
			})
			if notifStroke then
				TweenService:Create(notifStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
			end
			exitTween:Play()
			exitTween.Completed:Connect(function()
				if notifLabel.TextTransparency == 1 then notifLabel.Visible = false end
			end)
		end
	end)
end

local function spawnSparkles(frame, particleText, particleColor)
	for _ = 1, 8 do
		task.spawn(function()
			local p = Instance.new("TextLabel")
			p.Text = particleText
			p.TextColor3 = particleColor
			p.TextScaled = true
			p.BackgroundTransparency = 1
			p.Size = UDim2.new(0, 18, 0, 18)
			p.AnchorPoint = Vector2.new(0.5, 0.5)
			p.Position = UDim2.new(0.5, 0, 0.5, 0)
			p.ZIndex = 60
			p.Parent = frame

			local endPos = UDim2.new(0.5 + (math.random() - 0.5) * 1.1, 0, 0.5 + (math.random() - 0.9) * 1.1, 0)
			local tween = TweenService:Create(p, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = endPos, TextTransparency = 1, Size = UDim2.new(0, 26, 0, 26)
			})
			tween:Play()
			tween.Completed:Connect(function() p:Destroy() end)
		end)
	end
end

local function popPurchaseAnimation(frame)
	if not frame then return end
	if not frame:GetAttribute("OriginalSize") then
		frame:SetAttribute("OriginalSize", frame.Size)
	end
	local orig = frame:GetAttribute("OriginalSize")

	frame.Size = UDim2.new(orig.X.Scale * 1.15, orig.X.Offset, orig.Y.Scale * 1.15, orig.Y.Offset)
	TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Size = orig
	}):Play()

	spawnSparkles(frame, "✨", Color3.fromRGB(255, 220, 90))
end

local function shakeButton(frame)
	if not frame then return end

	-- (the resting position/colour are remembered ONCE: clicking again mid-shake used
	-- to save the red flash - or the shaken position - as the "original", which is
	-- how the red outline could get stuck on for good)
	if frame:GetAttribute("RestPosition") == nil then frame:SetAttribute("RestPosition", frame.Position) end
	local originalPos = frame:GetAttribute("RestPosition")
	local sequence = TweenInfo.new(0.05, Enum.EasingStyle.Linear)
	local offsets = {8, -8, 6, -6, 3, 0}

	task.spawn(function()
		for _, offset in ipairs(offsets) do
			local tween = TweenService:Create(frame, sequence, {
				Position = UDim2.new(originalPos.X.Scale, originalPos.X.Offset + offset, originalPos.Y.Scale, originalPos.Y.Offset)
			})
			tween:Play()
			tween.Completed:Wait()
		end
		frame.Position = originalPos
	end)

	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		if stroke:GetAttribute("RestColor") == nil then stroke:SetAttribute("RestColor", stroke.Color) end
		local originalColor = stroke:GetAttribute("RestColor")
		local token = (stroke:GetAttribute("FlashToken") or 0) + 1
		stroke:SetAttribute("FlashToken", token)
		stroke.Color = Color3.fromRGB(255, 60, 60)
		task.delay(0.4, function()
			if stroke.Parent and stroke:GetAttribute("FlashToken") == token then
				stroke.Color = originalColor
			end
		end)
	end
end

local serverConfig = nil
local currentTiers = {LapisSlots = 0, SlotPower = 0, Teleport = false, Bossfight = false}
local lastAttemptedFrame = nil

local function getTierFrame(trackConfig, index)
	local folder = list:FindFirstChild(trackConfig.FolderName)
	if not folder then return nil end
	local frameName = trackConfig.TierFrames[index]
	return frameName and folder:FindFirstChild(frameName)
end

local function setPurchasedHighlight(frame, purchased)
	if not frame then return end

	local overlay = frame:FindFirstChild("PurchasedGlow")
	if purchased then
		if not overlay then
			overlay = Instance.new("Frame")
			overlay.Name = "PurchasedGlow"
			overlay.Size = UDim2.new(1, 0, 1, 0)
			overlay.BackgroundTransparency = 0.75
			overlay.BackgroundColor3 = Color3.fromRGB(60, 230, 100)
			overlay.ZIndex = 25
			overlay.Parent = frame

			local stroke = Instance.new("UIStroke")
			stroke.Name = "PurchasedStroke"
			stroke.Thickness = 3
			stroke.Color = Color3.fromRGB(90, 255, 130)
			stroke.Parent = overlay

			local corner = frame:FindFirstChildOfClass("UICorner")
			if corner then corner:Clone().Parent = overlay end

			TweenService:Create(stroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Thickness = 5
			}):Play()
		end
		overlay.Visible = true
	elseif overlay then
		overlay.Visible = false
	end
end

-- 3000000000 -> "3B", 2600000 -> "2.6M", 49000 -> "49K"
local function short(n)
	n = tonumber(n) or 0
	for _, u in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
		if n >= u[1] then
			local v = n / u[1]
			return (v >= 100 and string.format("%d", math.floor(v)) or string.format("%.1f", v):gsub("%.0$", "")) .. u[2]
		end
	end
	return tostring(math.floor(n))
end

local function setCostText(frame, cost)
	if not frame then return end
	local costLabel = frame:FindFirstChild("cost")
	if costLabel and costLabel:IsA("TextLabel") then
		costLabel.Text = short(cost) .. " PP"
	end
end

local function renderLinearTrack(trackName, trackConfig)
	if not serverConfig then return end
	local tierConfigs = serverConfig[trackConfig.ConfigKey]
	if not tierConfigs then return end

	local ownedTier = currentTiers[trackName] or 0

	-- one card per purchasable tier, everything read from the server's config
	-- (the cards used to be one tier off: the first was drawn as a free "base"
	-- tier, so the last real tier - the final 2 lapis slots - had no card)
	for i, tierData in ipairs(tierConfigs) do
		local frame = getTierFrame(trackConfig, i)
		if frame then
			setCostText(frame, tierData.Cost)
			setPurchasedHighlight(frame, i <= ownedTier)
			local asc = frame:FindFirstChild("TextLabel")
			if asc and asc:IsA("TextLabel") then
				asc.Text = tierData.AscensionsRequired .. (tierData.AscensionsRequired == 1 and " Ascension" or " Ascensions")
			end
			local val = frame:FindFirstChild("TierValue")
			if val and val:IsA("TextLabel") and tierData.Value then val.Text = tierData.Value end
		end
	end

	-- the arrows between the cards show how far along you are:
	-- green = done, gold (pulsing) = your next upgrade, grey = later
	local folder = list:FindFirstChild(trackConfig.FolderName)
	if folder then
		for i = 1, #tierConfigs - 1 do
			-- (arrow i sits between card i and card i+1)
			local arrow = folder:FindFirstChild("Arrow" .. i)
			if arrow and arrow:IsA("TextLabel") then
				local old = arrow:GetAttribute("PulseTween")
				if i + 1 <= ownedTier then
					arrow.TextColor3 = Color3.fromRGB(90, 255, 130)
					arrow.TextTransparency = 0
				elseif i + 1 == ownedTier + 1 and ownedTier >= 1 then
					arrow.TextColor3 = Color3.fromRGB(255, 215, 60)
					arrow.TextTransparency = 0
					if not arrow:GetAttribute("Pulsing") then
						arrow:SetAttribute("Pulsing", true)
						TweenService:Create(arrow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { TextTransparency = 0.45 }):Play()
					end
				else
					arrow.TextColor3 = Color3.fromRGB(150, 150, 150)
					arrow.TextTransparency = 0.35
				end
				if not (i + 1 == ownedTier + 1 and ownedTier >= 1) and arrow:GetAttribute("Pulsing") then
					-- stop the pulse (a fresh tween on the same property cancels it)
					arrow:SetAttribute("Pulsing", nil)
					TweenService:Create(arrow, TweenInfo.new(0.1), { TextTransparency = i + 1 <= ownedTier and 0 or 0.35 }):Play()
				end
			end
		end
	end
end

local function renderTeleportTrack()
	local trackConfig = TRACKS.Teleport
	-- (teleport is free for everyone now: its upgrade card is hidden)
	local tpFolder = list:FindFirstChild(trackConfig.FolderName)
	if tpFolder and tpFolder:IsA("GuiObject") then tpFolder.Visible = false return end
	local frame = getTierFrame(trackConfig, 1)
	local tierData = serverConfig and serverConfig.TeleportTier

	if tierData then
		setCostText(frame, tierData.Cost)
	end

	setPurchasedHighlight(frame, currentTiers.Teleport == true)
end

-- the Final Boss upgrade: its price was never filled in (it showed "N/A PP")
local function renderBossfightTrack()
	local frame = getTierFrame(TRACKS.Bossfight, 1)
	local tierData = serverConfig and serverConfig.BossfightTier
	if tierData then
		setCostText(frame, tierData.Cost)
	end
	setPurchasedHighlight(frame, currentTiers.Bossfight == true)
end

local function renderAll()
	renderLinearTrack("LapisSlots", TRACKS.LapisSlots)
	renderLinearTrack("SlotPower", TRACKS.SlotPower)
	renderTeleportTrack()
	renderBossfightTrack()
end

local function findUpgradeButton(trackConfig)
	local folder = list:FindFirstChild(trackConfig.FolderName)
	if not folder then return nil end
	return folder:FindFirstChild("upgrade", true)
end

local function bindUpgradeButton(trackConfig)
	local upgradeFrame = findUpgradeButton(trackConfig)
	if not upgradeFrame then
		warn("[BaseUpgradeClient] Could not find 'upgrade' button for track: " .. trackConfig.FolderName)
		return
	end

	local lastClick = 0
	local function trigger()
		if os.clock() - lastClick < 0.3 then return end
		lastClick = os.clock()
		lastAttemptedFrame = upgradeFrame
		baseUpgradeRemote:FireServer(trackConfig.UpgradeAction)
	end

	local function hook(obj)
		if obj:IsA("GuiButton") then
			obj.Activated:Connect(trigger)
		elseif obj:IsA("GuiObject") then
			obj.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					trigger()
				end
			end)
		end
	end

	hook(upgradeFrame)
	for _, child in ipairs(upgradeFrame:GetDescendants()) do
		if child:IsA("GuiObject") then hook(child) end
	end
end

for _, trackConfig in pairs(TRACKS) do
	bindUpgradeButton(trackConfig)
end

baseUpgradeRemote.OnClientEvent:Connect(function(action, arg1, arg2)
	if action == "State" then
		serverConfig = arg1.Config
		currentTiers.LapisSlots = arg1.LapisSlotTier
		currentTiers.SlotPower = arg1.SlotPowerTier
		currentTiers.Teleport = arg1.TeleportUnlocked
		currentTiers.Bossfight = arg1.BossfightUnlocked
		renderAll()

	elseif action == "UpgradeSuccess" then
		local trackName, newValue = arg1, arg2
		currentTiers[trackName] = newValue
		showNotification("UPGRADED!", false)
		renderAll()

		local trackConfig = TRACKS[trackName]
		if trackConfig then
			local frame
			if trackName == "Teleport" or trackName == "Bossfight" then
				frame = getTierFrame(trackConfig, 1)
			else
				frame = getTierFrame(trackConfig, newValue or 1)
			end
			popPurchaseAnimation(frame)
		end

	elseif action == "Error" then
		showNotification(arg1, true)
		shakeButton(lastAttemptedFrame)
	end
end)

baseUpgradeRemote:FireServer("GetState")

container:GetPropertyChangedSignal("Visible"):Connect(function()
	if container.Visible then
		baseUpgradeRemote:FireServer("GetState")
	end
end)