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

local MarketplaceService = game:GetService("MarketplaceService")
local Monetization = accessibleModules and require(accessibleModules:WaitForChild("MonetizationData"))
local ascModule = accessibleModules and accessibleModules:FindFirstChild("AscensionDataModule")
local okAsc, AscensionData = pcall(function() return ascModule and require(ascModule) end)
if not okAsc then AscensionData = nil end

--==================================================
-- AUTOSELL PRICE + GAMEPASS
-- Mirrors AutoSellService.creditPP exactly: base value x ascension
-- multiplier x money passes, so the number on screen is what you get.
--==================================================

local baseValues = {}
if LapisData and type(LapisData.Items) == "table" then
	for _, item in ipairs(LapisData.Items) do
		if item.Name and item.Value then baseValues[item.Name] = item.Value end
	end
end

local function formatPP(n)
	n = math.floor(n or 0)
	for _, u in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
		if n >= u[1] then
			return (("%.1f"):format(n / u[1]):gsub("%.0$", "")) .. u[2]
		end
	end
	return tostring(n)
end

local function sellPriceEach(itemName)
	local base = baseValues[itemName]
	if not base then return nil end
	local ls = localPlayer:FindFirstChild("leaderstats")
	local asc = ls and (ls:FindFirstChild("Ascensions") or ls:FindFirstChild("Rebirths"))
	local mult = 1
	if AscensionData and AscensionData.GetMultiplier then
		mult = AscensionData.GetMultiplier(asc and asc.Value or 0) or 1
	end
	if Monetization then mult *= Monetization.GetMoneyMultiplier(localPlayer) end
	return math.floor(base * mult)
end

local function ownsAutoSell()
	return Monetization == nil or Monetization.Owns(localPlayer, "AutoSell")
end

local function promptAutoSellPass()
	local pass = Monetization and Monetization.GetByKey("AutoSell")
	if pass then
		pcall(function() MarketplaceService:PromptGamePassPurchase(localPlayer, pass.Id) end)
	end
end

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
successSound.Volume = 0.15
successSound.Parent = SoundService

local errorSound = Instance.new("Sound")
errorSound.SoundId = "rbxassetid://132281440773764"
errorSound.Volume = 0.08
errorSound.Parent = SoundService

local favoriteSound = Instance.new("Sound")
favoriteSound.SoundId = "rbxassetid://10066947742" -- old id 6023023208 no longer loads
favoriteSound.Volume = 0.2
favoriteSound.Parent = SoundService

local unfavoriteSound = Instance.new("Sound")
unfavoriteSound.SoundId = "rbxassetid://132281440773764"
unfavoriteSound.Volume = 0.1
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

	-- "+X PP": what each one actually auto-sells for right now.
	-- Sits directly under the money badge in the slot's top-left corner.
	local priceTag = slot:FindFirstChild("AutoSellPrice")
	local price = isAutoSell and sellPriceEach(slot.Name)
	if price then
		if not priceTag then
			priceTag = Instance.new("TextLabel")
			priceTag.Name = "AutoSellPrice"
			priceTag.BackgroundTransparency = 1
			priceTag.AnchorPoint = Vector2.new(0, 0)
			priceTag.Position = UDim2.new(0, 2, 0.3, 0)
			priceTag.Size = UDim2.new(0.76, 0, 0.17, 0)
			priceTag.TextScaled = true
			priceTag.Font = Enum.Font.FredokaOne
			priceTag.TextXAlignment = Enum.TextXAlignment.Left
			priceTag.TextColor3 = Color3.fromRGB(120, 255, 140)
			priceTag.ZIndex = 41
			priceTag.Parent = slot
			local s = Instance.new("UIStroke")
			s.Thickness = 1.5
			s.Color = Color3.fromRGB(0, 40, 10)
			s.Parent = priceTag
		end
		priceTag.Text = "+" .. formatPP(price) .. " PP"
		priceTag.TextColor3 = ownsAutoSell() and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(170, 170, 170)
		priceTag.Visible = true
	elseif priceTag then
		priceTag.Visible = false
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

	-- Auto Sell is a gamepass: without it, offer it instead of entering the mode
	if not isAutoSellMode and not ownsAutoSell() then
		showNotification("AUTOSELL NEEDS THE AUTO SELL GAMEPASS!", true)
		promptAutoSellPass()
		updateActiveModeGlows()
		return
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
-- INFO PANEL (click a lapis -> see what it is)
-- The right-hand panel shows a big copy of the clicked
-- slot, its rarity / island / value, and a description
-- from LapisDataModule.Info. Undiscovered lapis stay a
-- mystery ("???") so there's still something to find.
--==================================================

local infoText = infoFrame and infoFrame:FindFirstChild("text")
local rateLabel = infoText and infoText:FindFirstChild("rate")
local descLabel = infoText and infoText:FindFirstChild("info")
if rateLabel then rateLabel.RichText = true end

-- the designed preview slot (normal_lapis) marks where the big icon goes
local previewPos, previewSize, previewAnchor, previewZ
do
	local designed = infoFrame and infoFrame:FindFirstChild("normal_lapis")
	if designed then
		previewPos, previewSize = designed.Position, designed.Size
		previewAnchor, previewZ = designed.AnchorPoint, designed.ZIndex
	end
end

local STRIP = { amount = true, SlotHighlightOverlay = true, ModeBadge = true, AutoSellPrice = true, SelectedStroke = true }
local selectedName = nil

local function isDiscoveredName(name)
	local d = discoveredStats and discoveredStats:FindFirstChild(name)
	return d and d.Value == true or false
end

local function markSelected(name)
	for _, slot in ipairs(list:GetChildren()) do
		if slot:IsA("GuiObject") then
			local s = slot:FindFirstChild("SelectedStroke")
			if slot.Name == name then
				if not s then
					s = Instance.new("UIStroke")
					s.Name = "SelectedStroke"
					s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					s.Color = Color3.fromRGB(255, 255, 255)
					s.Thickness = 3
					s.Parent = slot
				end
				s.Enabled = true
			elseif s then
				s.Enabled = false
			end
		end
	end
end

local function showLapisInfo(name)
	if not infoFrame then return end
	local slot = list:FindFirstChild(name)
	if not slot then return end
	selectedName = name
	markSelected(name)

	local discovered = isDiscoveredName(name)

	-- big preview: a clean copy of the inventory slot's art
	for _, c in ipairs(infoFrame:GetChildren()) do
		if c:IsA("GuiObject") and c ~= infoText and c.Name ~= "ImageLabel" then
			c:Destroy()
		end
	end
	if previewPos then
		local copy = slot:Clone()
		for _, d in ipairs(copy:GetDescendants()) do
			if STRIP[d.Name] or d:IsA("LuaSourceContainer") then d:Destroy() end
		end
		local lock = copy:FindFirstChild("locked")
		if lock then lock.Visible = not discovered end
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("GuiButton") then d.Active = false; d.AutoButtonColor = false end
		end
		copy:SetAttribute("OriginalSize", nil)
		copy.Name = "Preview_" .. name
		copy.AnchorPoint = previewAnchor
		copy.Position = previewPos
		copy.Size = previewSize
		copy.ZIndex = previewZ
		copy.Parent = infoFrame
		local full = previewSize
		copy.Size = UDim2.new(full.X.Scale * 0.85, 0, full.Y.Scale * 0.85, 0)
		TweenService:Create(copy, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = full }):Play()
	end

	local info = LapisData and LapisData.GetInfo and LapisData.GetInfo(name)
	if not info then return end

	if rateLabel then
		if discovered then
			local each = sellPriceEach(name) or info.Value
			local hex = info.RarityColor:ToHex()
			rateLabel.Text = ('<font color="#%s">%s</font> - %s\nValue: %s PP each\nSpawns about every %ss'):format(
				hex, string.upper(info.Rarity), info.Island, formatPP(each),
				info.SpawnEvery and tostring(math.max(1, math.floor(info.SpawnEvery + 0.5))) or "?")
		else
			rateLabel.Text = ('<font color="#%s">%s</font>\nFound on: %s\nValue: ???'):format(
				info.RarityColor:ToHex(), string.upper(info.Rarity), info.Island)
		end
	end
	if descLabel then
		if discovered then
			descLabel.Text = info.Description
		else
			descLabel.Text = "You haven't found this lapis yet. Pick one up on " .. info.Island .. " to learn more about it!"
		end
	end
end

-- other scripts (the lapis bar) ask the panel to show a lapis through this
local showEvent = screenGui:FindFirstChild("ShowLapisInfo")
if not showEvent then
	showEvent = Instance.new("BindableEvent")
	showEvent.Name = "ShowLapisInfo"
	showEvent.Parent = screenGui
end
showEvent.Event:Connect(showLapisInfo)


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

		-- every click shows the lapis in the info panel
		showLapisInfo(slot.Name)

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

			if not ownsAutoSell() then
				showNotification("AUTOSELL NEEDS THE AUTO SELL GAMEPASS!", true)
				promptAutoSellPass()
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
					local each = sellPriceEach(slot.Name)
					showNotification("AUTOSELL ON FOR " .. formattedName
						.. (each and (" (+" .. formatPP(each) .. " PP EACH)") or ""), false)
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
			-- Authoritative: mirror the server exactly (clears stale badges too),
			-- so what you see ticked is exactly what gets auto-sold.
			local favs = type(data.Favorites) == "table" and data.Favorites or {}
			local sells = type(data.AutoSell) == "table" and data.AutoSell or {}
			for _, slot in ipairs(list:GetChildren()) do
				if slot:IsA("GuiObject") then
					slot:SetAttribute("IsFavorited", favs[slot.Name] == true or nil)
					slot:SetAttribute("IsAutoSell", sells[slot.Name] == true or nil)
					updateSlotHighlight(slot)
				end
			end
		end
	end)
	-- The server's join-time push usually lands before this script runs.
	task.defer(function()
		inventoryRemote:FireServer("RequestInit")
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

-- start the panel on the first lapis so it's never showing stale text
showLapisInfo("normal_lapis")

-- discovering a lapis while it's selected reveals it right away
if discoveredStats then
	local function watchDisc(v)
		v:GetPropertyChangedSignal("Value"):Connect(function()
			if v.Name == selectedName then showLapisInfo(selectedName) end
		end)
	end
	for _, v in ipairs(discoveredStats:GetChildren()) do watchDisc(v) end
	discoveredStats.ChildAdded:Connect(watchDisc)
end

if favoriteFrame then
	bindUniversalClick(favoriteFrame, toggleFavoriteMode)
end

if autoSellFrame then
	bindUniversalClick(autoSellFrame, toggleAutoSellMode)
end

-- keep the "+X PP" tags honest when the multiplier changes
local function refreshAllHighlights()
	for _, slot in ipairs(list:GetChildren()) do
		if slot:IsA("GuiObject") then updateSlotHighlight(slot) end
	end
end
task.spawn(function()
	local ls = localPlayer:WaitForChild("leaderstats", 30)
	local asc = ls and (ls:WaitForChild("Ascensions", 10) or ls:FindFirstChild("Rebirths"))
	if asc then asc.Changed:Connect(refreshAllHighlights) end
end)
localPlayer:GetAttributeChangedSignal("Pass_DoubleMoney"):Connect(refreshAllHighlights)
localPlayer:GetAttributeChangedSignal("Pass_AutoSell"):Connect(refreshAllHighlights)

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
	if not container.Visible then return end	-- no menus while a cutscene has the screen (e.g. the QTE keys)
	for k, v in pairs(game:GetService("Players").LocalPlayer:GetAttributes()) do
		if v and k:sub(1, 8) == "HideHud_" then return end
	end

	if input.KeyCode == Enum.KeyCode.F then
		toggleFavoriteMode()
	elseif input.KeyCode == Enum.KeyCode.V then
		toggleAutoSellMode()
	end
end)