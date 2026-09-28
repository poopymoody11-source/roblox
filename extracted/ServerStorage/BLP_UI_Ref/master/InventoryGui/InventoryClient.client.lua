--==================================================
-- INVENTORY CLIENT (FAVORITE, AUTOSELL & DISCOVERY CONTROLLER)
--
-- Place in: StarterGui > Screen > master > InventoryGui > InventoryClient
-- Type: LocalScript
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer

-- Robust Remote Resolution (handles root, AccessibleEvents, or Remotes folders)
local function getInventoryRemote()
	local remote = ReplicatedStorage:FindFirstChild("InventoryRemote")
		or (ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("InventoryRemote"))
		or (ReplicatedStorage:FindFirstChild("AccessibleEvents") and ReplicatedStorage.AccessibleEvents:FindFirstChild("InventoryRemote"))

	if not remote then
		remote = ReplicatedStorage:WaitForChild("InventoryRemote", 5)
			or (ReplicatedStorage:FindFirstChild("AccessibleEvents") and ReplicatedStorage.AccessibleEvents:WaitForChild("InventoryRemote", 5))
			or (ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:WaitForChild("InventoryRemote", 5))
	end
	return remote
end

local inventoryRemote = getInventoryRemote()

-- Require LapisDataModule safely
local accessibleModules = ReplicatedStorage:WaitForChild("AccessibleModules", 10)
local lapisDataModule = accessibleModules and accessibleModules:WaitForChild("LapisDataModule", 10)
local LapisData = lapisDataModule and require(lapisDataModule) or nil

local screenGui = script.Parent
local container = screenGui:WaitForChild("Container")
local list = container:WaitForChild("items"):WaitForChild("list")

local favoriteFrame = container:FindFirstChild("favorite") or container:FindFirstChild("Favorite")

local autoSellFrame = container:FindFirstChild("autosell")
	or container:FindFirstChild("autoSell")
	or container:FindFirstChild("AutoSell")

local infoFrame = container:FindFirstChild("info")
	or container:FindFirstChild("Info")
	or screenGui:FindFirstChild("info")
	or screenGui:FindFirstChild("Info")
	or (screenGui:FindFirstChild("master") and screenGui.master:FindFirstChild("info"))


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

local favoriteSound = Instance.new("Sound")
favoriteSound.SoundId = "rbxassetid://6023023208"
favoriteSound.Volume = 0.35
favoriteSound.Parent = SoundService

local unfavoriteSound = Instance.new("Sound")
unfavoriteSound.SoundId = "rbxassetid://132281440773764"
unfavoriteSound.Volume = 0.15
unfavoriteSound.Parent = SoundService


--==================================================
-- NOTIFICATION UI SETUP
--==================================================

local notifLabel = screenGui:FindFirstChild("InventoryNotification")
if not notifLabel then
	notifLabel = Instance.new("TextLabel")
	notifLabel.Name = "InventoryNotification"
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
	if not container.Visible then return end

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

	task.delay(1.5, function()
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
-- VISUAL EFFECTS (PULSING GOLD & GREEN BORDERS)
--==================================================

local isFavoriteMode = false
local isAutoSellMode = false

local function createGlowStroke(parent, name, isGreen)
	local stroke = parent:FindFirstChild(name)
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = name
		stroke.Thickness = 4
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Enabled = false
		stroke.Parent = parent

		local strokeGradient = Instance.new("UIGradient")
		strokeGradient.Name = "GlowGradient"
		strokeGradient.Parent = stroke
	end

	local gradient = stroke:FindFirstChild("GlowGradient")
	if isGreen then
		stroke.Color = Color3.fromRGB(50, 220, 50)
		if gradient then
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 255, 150)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 220, 50)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 150)),
			})
		end
	else
		stroke.Color = Color3.fromRGB(255, 215, 0)
		if gradient then
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 170, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 150)),
			})
		end
	end

	return stroke
end

local containerStroke = createGlowStroke(container, "ContainerGlowStroke", false)
local infoStroke = infoFrame and createGlowStroke(infoFrame, "InfoGlowStroke", false)

local pulseTweens = {}

local function startPulsing(strokeObj)
	if not strokeObj then return end
	if pulseTweens[strokeObj] then
		pulseTweens[strokeObj]:Cancel()
	end
	strokeObj.Enabled = true
	strokeObj.Thickness = 3
	local tween = TweenService:Create(strokeObj, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Thickness = 6
	})
	pulseTweens[strokeObj] = tween
	tween:Play()
end

local function stopPulsing(strokeObj)
	if not strokeObj then return end
	if pulseTweens[strokeObj] then
		pulseTweens[strokeObj]:Cancel()
		pulseTweens[strokeObj] = nil
	end
	strokeObj.Thickness = 4
	strokeObj.Enabled = false
end

local function updateButtonHighlight(frame, isModeActive, strokeName, isGreen)
	if not frame then return end

	local overlay = frame:FindFirstChild("ModeOverlayFrame")

	if isModeActive then
		if not overlay then
			overlay = Instance.new("Frame")
			overlay.Name = "ModeOverlayFrame"
			overlay.Size = UDim2.new(1, 0, 1, 0)
			overlay.Position = UDim2.new(0, 0, 0, 0)
			overlay.BackgroundTransparency = 1
			overlay.ZIndex = 20
			overlay.Parent = frame

			local existingCorner = frame:FindFirstChildOfClass("UICorner")
			if existingCorner then
				existingCorner:Clone().Parent = overlay
			else
				local defaultCorner = Instance.new("UICorner")
				defaultCorner.CornerRadius = UDim.new(0, 12)
				defaultCorner.Parent = overlay
			end
		end

		local stroke = createGlowStroke(overlay, strokeName, isGreen)
		overlay.Visible = true
		startPulsing(stroke)
	else
		if overlay then
			local stroke = overlay:FindFirstChild(strokeName)
			if stroke then stopPulsing(stroke) end
			overlay.Visible = false
		end
	end
end

local function updateActiveModeGlows()
	if isFavoriteMode then
		createGlowStroke(container, "ContainerGlowStroke", false)
		if infoFrame then createGlowStroke(infoFrame, "InfoGlowStroke", false) end
		startPulsing(containerStroke)
		if infoStroke then startPulsing(infoStroke) end
	elseif isAutoSellMode then
		createGlowStroke(container, "ContainerGlowStroke", true)
		if infoFrame then createGlowStroke(infoFrame, "InfoGlowStroke", true) end
		startPulsing(containerStroke)
		if infoStroke then startPulsing(infoStroke) end
	else
		stopPulsing(containerStroke)
		if infoStroke then stopPulsing(infoStroke) end
	end

	updateButtonHighlight(favoriteFrame, isFavoriteMode, "FavButtonStroke", false)
	updateButtonHighlight(autoSellFrame, isAutoSellMode, "AutoSellButtonStroke", true)
end

local function spawnSparkles(slot, particleText, particleColor)
	for _ = 1, 6 do
		task.spawn(function()
			local p = Instance.new("TextLabel")
			p.Text = particleText
			p.TextColor3 = particleColor
			p.TextScaled = true
			p.BackgroundTransparency = 1
			p.Size = UDim2.new(0, 16, 0, 16)
			p.AnchorPoint = Vector2.new(0.5, 0.5)
			p.Position = UDim2.new(0.5, 0, 0.5, 0)
			p.ZIndex = 50
			p.Parent = slot

			local randomX = (math.random() - 0.5) * 0.9
			local randomY = (math.random() - 0.9) * 0.9
			local endPos = UDim2.new(0.5 + randomX, 0, 0.5 + randomY, 0)

			local tween = TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = endPos,
				TextTransparency = 1,
				Size = UDim2.new(0, 24, 0, 24)
			})
			tween:Play()
			tween.Completed:Connect(function()
				p:Destroy()
			end)
		end)
	end
end

local function popSlotAnimation(slot)
	if not slot:GetAttribute("OriginalSize") then
		slot:SetAttribute("OriginalSize", slot.Size)
	end
	local orig = slot:GetAttribute("OriginalSize")

	slot.Size = UDim2.new(orig.X.Scale * 1.08, orig.X.Offset, orig.Y.Scale * 1.08, orig.Y.Offset)
	TweenService:Create(slot, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Size = orig
	}):Play()
end


--==================================================
-- SLOT HELPERS & HIGHLIGHTS
--==================================================

local function findAmountLabel(slot)
	local amount = slot:FindFirstChild("amount")
	local frame = amount and amount:FindFirstChild("Frame")
	return frame and frame:FindFirstChild("TextLabel")
end

local function findAmountFrame(slot)
	return slot:FindFirstChild("amount")
end

local function findLockedOverlay(slot)
	return slot:FindFirstChild("locked")
end

local playerStats = localPlayer:WaitForChild("PlayerStats", 10)
local lapisStats = playerStats and playerStats:WaitForChild("Lapis", 10)
local discoveredStats = playerStats and playerStats:WaitForChild("Discovered", 10)

local function updateSlotHighlight(slot)
	local discVal = discoveredStats and discoveredStats:FindFirstChild(slot.Name)
	local isDiscovered = discVal and discVal.Value == true or false

	-- Suppress visual indicators completely if the item is locked/undiscovered after ascension
	local isFavorited = isDiscovered and (slot:GetAttribute("IsFavorited") == true)
	local isAutoSell = isDiscovered and (slot:GetAttribute("IsAutoSell") == true)

	local overlay = slot:FindFirstChild("SlotHighlightOverlay")
	local badge = slot:FindFirstChild("ModeBadge")
	local amountFrame = findAmountFrame(slot)

	if amountFrame then
		amountFrame.ZIndex = 30
		for _, child in ipairs(amountFrame:GetDescendants()) do
			if child:IsA("GuiObject") then child.ZIndex = 31 end
		end
	end

	if isFavorited or isAutoSell then
		if not overlay then
			overlay = Instance.new("Frame")
			overlay.Name = "SlotHighlightOverlay"
			overlay.Size = UDim2.new(1, 0, 1, 0)
			overlay.Position = UDim2.new(0, 0, 0, 0)
			overlay.BackgroundTransparency = 1
			overlay.ZIndex = 20
			overlay.Parent = slot

			local existingCorner = slot:FindFirstChildOfClass("UICorner")
			if existingCorner then
				existingCorner:Clone().Parent = overlay
			else
				local defaultCorner = Instance.new("UICorner")
				defaultCorner.CornerRadius = UDim.new(0, 12)
				defaultCorner.Parent = overlay
			end
		end

		local stroke = createGlowStroke(overlay, "SlotStroke", isAutoSell)
		stroke.Enabled = true
		overlay.Visible = true

		if not badge then
			badge = Instance.new("TextLabel")
			badge.Name = "ModeBadge"
			badge.TextScaled = true
			badge.BackgroundTransparency = 1
			badge.Size = UDim2.new(0.28, 0, 0.28, 0)
			badge.Position = UDim2.new(0, 2, 0, 2)
			badge.ZIndex = 40
			badge.Parent = slot

			local badgeStroke = Instance.new("UIStroke")
			badgeStroke.Thickness = 2
			badgeStroke.Color = Color3.fromRGB(0, 0, 0)
			badgeStroke.Parent = badge
		end

		if isAutoSell then
			badge.Text = "💵"
			badge.TextColor3 = Color3.fromRGB(85, 255, 127)
		else
			badge.Text = "★"
			badge.TextColor3 = Color3.fromRGB(255, 220, 50)
		end
		badge.Visible = true
	else
		if overlay then overlay.Visible = false end
		if badge then badge.Visible = false end
	end
end


--==================================================
-- TOGGLE MODES (MUTUALLY EXCLUSIVE)
--==================================================

local function exitAllModes(silent)
	local wasActive = isFavoriteMode or isAutoSellMode
	isFavoriteMode = false
	isAutoSellMode = false
	updateActiveModeGlows()

	if wasActive and not silent then
		showNotification("MODES OFF", true)
	end
end

local function toggleFavoriteMode()
	if not container.Visible then return end

	if isAutoSellMode then
		isAutoSellMode = false
	end

	isFavoriteMode = not isFavoriteMode
	updateActiveModeGlows()

	if isFavoriteMode then
		showNotification("FAVORITE MODE ON", false)
	else
		showNotification("FAVORITE MODE OFF", true)
	end
end

local function toggleAutoSellMode()
	if not container.Visible then return end

	if isFavoriteMode then
		isFavoriteMode = false
	end

	isAutoSellMode = not isAutoSellMode
	updateActiveModeGlows()

	if isAutoSellMode then
		showNotification("AUTOSELL MODE ON", false)
	else
		showNotification("AUTOSELL MODE OFF", true)
	end
end

local function formatItemDisplayName(rawName)
	local cleaned = rawName:gsub("_", " ")
	return string.upper(cleaned)
end


--==================================================
-- UPDATE ONE SLOT'S COUNT & DISCOVERY LOCK
--==================================================

local warnedMissingAmount = false

local function applySlot(slot, count)
	local amountLabel = findAmountLabel(slot)

	if amountLabel then
		amountLabel.Text = "[" .. tostring(count) .. "x]"
	elseif not warnedMissingAmount then
		warnedMissingAmount = true
		warn("[InventoryClient] " .. slot.Name .. " has no amount > Frame > TextLabel")
	end

	local discVal = discoveredStats and discoveredStats:FindFirstChild(slot.Name)
	local isDiscovered = discVal and discVal.Value == true or false

	local lockedOverlay = findLockedOverlay(slot)
	if lockedOverlay then
		lockedOverlay.Visible = not isDiscovered
	end

	local amountFrame = findAmountFrame(slot)
	if amountFrame then
		amountFrame.Visible = isDiscovered
	end

	-- Clear mode flags on reset/relock
	if not isDiscovered then
		slot:SetAttribute("IsFavorited", nil)
		slot:SetAttribute("IsAutoSell", nil)
	end

	updateSlotHighlight(slot)
end


--==================================================
-- RECURSIVE CLICK BINDING
--==================================================

local function bindUniversalClick(slot, callback)
	local lastClickTime = 0

	local function safeTrigger()
		if not container.Visible then return end
		local now = tick()
		if now - lastClickTime < 0.12 then return end
		lastClickTime = now
		callback()
	end

	local function hook(obj)
		if obj:IsA("GuiButton") then
			obj.Activated:Connect(safeTrigger)
		elseif obj:IsA("GuiObject") then
			obj.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					safeTrigger()
				end
			end)
		end
	end

	hook(slot)
	for _, child in ipairs(slot:GetDescendants()) do
		if child:IsA("GuiObject") then
			hook(child)
		end
	end
end


--==================================================
-- WIRE UP SLOT INTERACTION
--==================================================

local function setupSlotInteraction(slot)
	bindUniversalClick(slot, function()
		local discVal = discoveredStats and discoveredStats:FindFirstChild(slot.Name)
		local isDiscovered = discVal and discVal.Value == true or false
		local formattedName = formatItemDisplayName(slot.Name)

		if isFavoriteMode then
			if slot:GetAttribute("IsAutoSell") == true then
				showNotification("CANNOT FAVORITE AUTOSELL ITEM!", true)
				return
			end

			if isDiscovered then
				local nextState = not (slot:GetAttribute("IsFavorited") == true)
				slot:SetAttribute("IsFavorited", nextState)

				if inventoryRemote then
					inventoryRemote:FireServer("ToggleFavorite", slot.Name)
				end

				if nextState then
					SoundService:PlayLocalSound(favoriteSound)
					spawnSparkles(slot, "★", Color3.fromRGB(255, 225, 80))
					popSlotAnimation(slot)
					showNotification("FAVORITED " .. formattedName, false)
				else
					SoundService:PlayLocalSound(unfavoriteSound)
					showNotification("UNFAVORITED " .. formattedName, true)
				end

				updateSlotHighlight(slot)
			else
				showNotification("CANNOT FAVORITE UNLOCKED ITEM!", true)
			end

		elseif isAutoSellMode then
			if slot:GetAttribute("IsFavorited") == true then
				showNotification("CANNOT AUTOSELL FAVORITED ITEM!", true)
				return
			end

			if isDiscovered then
				local nextState = not (slot:GetAttribute("IsAutoSell") == true)
				slot:SetAttribute("IsAutoSell", nextState)

				if inventoryRemote then
					inventoryRemote:FireServer("ToggleAutoSell", slot.Name)
				end

				if nextState then
					SoundService:PlayLocalSound(favoriteSound)
					spawnSparkles(slot, "💵", Color3.fromRGB(85, 255, 127))
					popSlotAnimation(slot)
					showNotification("AUTOSELL ON FOR " .. formattedName, false)
				else
					SoundService:PlayLocalSound(unfavoriteSound)
					showNotification("AUTOSELL OFF FOR " .. formattedName, true)
				end

				updateSlotHighlight(slot)
			else
				showNotification("CANNOT AUTOSELL UNLOCKED ITEM!", true)
			end
		end
	end)
end


--==================================================
-- WATCH PLAYERSTATS > LAPIS & DISCOVERY
--==================================================

local warnedMissing = {}

local function refreshItem(itemType)
	local slot = list:FindFirstChild(itemType)

	if not slot then
		if not warnedMissing[itemType] then
			warnedMissing[itemType] = true
			warn("[InventoryClient] Player owns '" .. itemType .. "' but items > list has no frame named exactly that.")
		end
		return
	end

	local value = lapisStats and lapisStats:FindFirstChild(itemType)
	local count = value and value.Value or 0

	applySlot(slot, count)
end

local function watchValue(value)
	refreshItem(value.Name)
	value:GetPropertyChangedSignal("Value"):Connect(function()
		refreshItem(value.Name)
	end)
end

if lapisStats then
	for _, value in ipairs(lapisStats:GetChildren()) do
		if value:IsA("IntValue") then
			watchValue(value)
		end
	end

	lapisStats.ChildAdded:Connect(function(value)
		if value:IsA("IntValue") then
			watchValue(value)
		end
	end)
end

if discoveredStats then
	for _, discVal in ipairs(discoveredStats:GetChildren()) do
		discVal:GetPropertyChangedSignal("Value"):Connect(function()
			refreshItem(discVal.Name)
		end)
	end

	discoveredStats.ChildAdded:Connect(function(discVal)
		discVal:GetPropertyChangedSignal("Value"):Connect(function()
			refreshItem(discVal.Name)
		end)
	end)
end


--==================================================
-- LOAD SAVED DATA FROM SERVER
--==================================================

if inventoryRemote then
	inventoryRemote.OnClientEvent:Connect(function(action, data)
		if action == "InitData" and type(data) == "table" then
			if type(data.Favorites) == "table" then
				for itemName, isFav in pairs(data.Favorites) do
					if isFav then
						local slot = list:FindFirstChild(itemName)
						if slot then
							slot:SetAttribute("IsFavorited", true)
							updateSlotHighlight(slot)
						end
					end
				end
			end
			if type(data.AutoSell) == "table" then
				for itemName, isAutoSell in pairs(data.AutoSell) do
					if isAutoSell then
						local slot = list:FindFirstChild(itemName)
						if slot then
							slot:SetAttribute("IsAutoSell", true)
							updateSlotHighlight(slot)
						end
					end
				end
			end
		end
	end)
end


--==================================================
-- INITIAL PASS
--==================================================

for _, slot in ipairs(list:GetChildren()) do
	if slot:IsA("GuiObject") then
		setupSlotInteraction(slot)
		refreshItem(slot.Name)
	end
end

if favoriteFrame then
	bindUniversalClick(favoriteFrame, toggleFavoriteMode)
end

if autoSellFrame then
	bindUniversalClick(autoSellFrame, toggleAutoSellMode)
end

container:GetPropertyChangedSignal("Visible"):Connect(function()
	if not container.Visible then
		exitAllModes(true)
		if notifLabel then
			notifLabel.Visible = false
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not container.Visible then return end

	if input.KeyCode == Enum.KeyCode.F then
		toggleFavoriteMode()
	elseif input.KeyCode == Enum.KeyCode.V then
		toggleAutoSellMode()
	end
end)