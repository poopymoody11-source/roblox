--==================================================
-- SELL CLIENT (PERMANENT UNLOCKS & ASCENSION NOTIFICATIONS)
-- Place in: StarterGui > Screen > master > Sell > SellCient
-- Type: LocalScript
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer

-- Remotes
local sellRemote = ReplicatedStorage:WaitForChild("SellRemote", 10)

-- UI References
local sellGui = script.Parent
local masterGui = sellGui.Parent
local container = sellGui:WaitForChild("Container")
local buttonsFrame = sellGui:WaitForChild("buttons")
local closeFrame = sellGui:WaitForChild("close")
local titleFrame = sellGui:FindFirstChild("title")

local itemsFrame = container:WaitForChild("items")
local list = itemsFrame:WaitForChild("list")

-- Find InventoryGui list to sync Favorites & AutoSell
local inventoryList = masterGui 
	and masterGui:FindFirstChild("InventoryGui")
	and masterGui.InventoryGui:FindFirstChild("Container")
	and masterGui.InventoryGui.Container:FindFirstChild("items")
	and masterGui.InventoryGui.Container.items:FindFirstChild("list")

-- State Variables
local selectedItemName = nil
local activeSellPart = nil -- Tracks which part opened the shop

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
-- PULSING RED CONTAINER HIGHLIGHT
--==================================================

local containerStroke = container:FindFirstChild("ContainerRedGlow")
if not containerStroke then
	containerStroke = Instance.new("UIStroke")
	containerStroke.Name = "ContainerRedGlow"
	containerStroke.Thickness = 4
	containerStroke.Color = Color3.fromRGB(230, 40, 40)
	containerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	containerStroke.Parent = container
end

local pulseTween = TweenService:Create(containerStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	Thickness = 7,
	Color = Color3.fromRGB(255, 90, 90)
})
pulseTween:Play()


--==================================================
-- NOTIFICATION SYSTEM
--==================================================

local notifLabel = sellGui:FindFirstChild("SellNotification")
if not notifLabel then
	notifLabel = Instance.new("TextLabel")
	notifLabel.Name = "SellNotification"
	notifLabel.Size = UDim2.new(0.8, 0, 0.06, 0)
	notifLabel.Position = UDim2.new(0.1, 0, 0.03, 0)
	notifLabel.BackgroundTransparency = 1
	notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	notifLabel.TextStrokeTransparency = 1
	notifLabel.TextScaled = true
	notifLabel.Text = ""
	notifLabel.Visible = false
	notifLabel.ZIndex = 100
	notifLabel.Parent = sellGui

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

	notifLabel.Position = UDim2.new(0.1, 0, 0.01, 0)
	notifLabel.TextTransparency = 1
	if stroke then stroke.Transparency = 1 end
	notifLabel.Visible = true

	local popTween = TweenService:Create(notifLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.1, 0, 0.03, 0),
		TextTransparency = 0
	})

	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	end

	popTween:Play()
	activeAnim = popTween

	task.delay(1.8, function()
		if notifLabel.Text == message then
			local exitTween = TweenService:Create(notifLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.1, 0, 0.01, 0),
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
-- ANIMATION & PARTICLE EFFECTS
--==================================================

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
-- MENU VISIBILITY
--==================================================

local function setSellMenuVisible(visible)
	container.Visible = visible
	buttonsFrame.Visible = visible
	closeFrame.Visible = visible
	if titleFrame then titleFrame.Visible = visible end

	if not visible then
		selectedItemName = nil
		activeSellPart = nil
		workspace:SetAttribute("OpenSellMode", false)
		if notifLabel then notifLabel.Visible = false end
	end
end

setSellMenuVisible(false)

local actualCloseBtn = closeFrame:FindFirstChildOfClass("TextButton") or closeFrame:FindFirstChildOfClass("ImageButton") or closeFrame
actualCloseBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		setSellMenuVisible(false)
	end
end)


--==================================================
-- HELPER FUNCTIONS
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

local function formatItemDisplayName(rawName)
	local cleaned = rawName:gsub("_", " ")
	return string.upper(cleaned)
end

local function createGlowStroke(parent, name, isGreen)
	local stroke = parent:FindFirstChild(name)
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = name
		stroke.Thickness = 3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = parent
	end

	if isGreen then
		stroke.Color = Color3.fromRGB(50, 220, 50)
	else
		stroke.Color = Color3.fromRGB(255, 215, 0)
	end

	return stroke
end


--==================================================
-- STAT REFERENCES
--==================================================

local playerStats = localPlayer:WaitForChild("PlayerStats")
local lapisStats = playerStats:WaitForChild("Lapis")
local discoveredStats = playerStats:WaitForChild("Discovered")


--==================================================
-- SLOT SYNC WITH INVENTORY GUI
--==================================================

local function syncSlotWithInventory(slot)
	if not inventoryList then return end
	local invSlot = inventoryList:FindFirstChild(slot.Name)
	if invSlot then
		slot:SetAttribute("IsFavorited", invSlot:GetAttribute("IsFavorited") == true)
		slot:SetAttribute("IsAutoSell", invSlot:GetAttribute("IsAutoSell") == true)
	end
end

local function setupInventoryAttributeSync(slot)
	if not inventoryList then return end
	local invSlot = inventoryList:FindFirstChild(slot.Name)
	if invSlot then
		invSlot:GetAttributeChangedSignal("IsFavorited"):Connect(function()
			slot:SetAttribute("IsFavorited", invSlot:GetAttribute("IsFavorited"))
			if slot:GetAttribute("IsFavorited") and selectedItemName == slot.Name then
				selectedItemName = nil
			end
			updateSlotVisuals(slot)
		end)
		invSlot:GetAttributeChangedSignal("IsAutoSell"):Connect(function()
			slot:SetAttribute("IsAutoSell", invSlot:GetAttribute("IsAutoSell"))
			updateSlotVisuals(slot)
		end)
	end
end


--==================================================
-- SLOT HIGHLIGHTS & BADGES
--==================================================

function updateSlotVisuals(slot)
	syncSlotWithInventory(slot)

	local discVal = discoveredStats:FindFirstChild(slot.Name)
	local isDiscovered = discVal and discVal.Value == true or false

	local isFavorited = isDiscovered and (slot:GetAttribute("IsFavorited") == true)
	local isAutoSell = isDiscovered and (slot:GetAttribute("IsAutoSell") == true)
	local isSelected = isDiscovered and (slot.Name == selectedItemName)

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
			overlay.BackgroundTransparency = 1
			overlay.ZIndex = 20
			overlay.Parent = slot

			local existingCorner = slot:FindFirstChildOfClass("UICorner")
			if existingCorner then existingCorner:Clone().Parent = overlay end
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

	local selectionOverlay = slot:FindFirstChild("SellSelectionGlow")
	if not selectionOverlay then
		selectionOverlay = Instance.new("Frame")
		selectionOverlay.Name = "SellSelectionGlow"
		selectionOverlay.Size = UDim2.new(1, 0, 1, 0)
		selectionOverlay.BackgroundTransparency = 0.85
		selectionOverlay.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		selectionOverlay.ZIndex = 25
		selectionOverlay.Parent = slot

		local stroke = Instance.new("UIStroke")
		stroke.Name = "GlowStroke"
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(255, 60, 60)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = selectionOverlay

		local corner = slot:FindFirstChildOfClass("UICorner")
		if corner then corner:Clone().Parent = selectionOverlay end
	end

	selectionOverlay.Visible = isSelected
end


--==================================================
-- PERMANENT UNLOCK LOGIC
--==================================================

local function applySlot(slot, count)
	local amountLabel = findAmountLabel(slot)
	if amountLabel then
		amountLabel.Text = "[" .. tostring(count) .. "x]"
	end

	local discVal = discoveredStats:FindFirstChild(slot.Name)
	local isDiscovered = discVal and discVal.Value == true or false

	local lockedOverlay = findLockedOverlay(slot)
	if lockedOverlay then
		lockedOverlay.Visible = not isDiscovered
	end

	local amountFrame = findAmountFrame(slot)
	if amountFrame then
		amountFrame.Visible = isDiscovered
	end

	updateSlotVisuals(slot)
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
		if child:IsA("GuiObject") then hook(child) end
	end
end


--==================================================
-- SLOT SELECTION & STAT WATCHING
--==================================================

local function updateAllSlotVisuals()
	for _, slot in ipairs(list:GetChildren()) do
		if slot:IsA("GuiObject") then
			updateSlotVisuals(slot)
		end
	end
end

local function bindSlotInteraction(slot)
	setupInventoryAttributeSync(slot)

	bindUniversalClick(slot, function()
		if slot:GetAttribute("IsFavorited") == true then
			showNotification("CANNOT SELL FAVORITED ITEM!", true)
			return
		end

		local discVal = discoveredStats:FindFirstChild(slot.Name)
		local isDiscovered = discVal and discVal.Value == true

		if not isDiscovered then
			showNotification("YOU HAVE NOT DISCOVERED THIS LAPIS YET!", true)
			return
		end

		local intVal = lapisStats:FindFirstChild(slot.Name)
		local count = intVal and intVal.Value or 0

		if count > 0 then
			selectedItemName = slot.Name
			popSlotAnimation(slot)
			spawnSparkles(slot, "✨", Color3.fromRGB(255, 200, 50))
			updateAllSlotVisuals()
		else
			showNotification("YOU HAVE 0 OF THIS ITEM!", true)
		end
	end)
end

local function refreshItem(itemType)
	local slot = list:FindFirstChild(itemType)
	if not slot then return end

	local value = lapisStats:FindFirstChild(itemType)
	local count = value and value.Value or 0

	applySlot(slot, count)

	if count <= 0 and selectedItemName == itemType then
		selectedItemName = nil
		updateAllSlotVisuals()
	end
end

local function watchValue(value)
	refreshItem(value.Name)
	value:GetPropertyChangedSignal("Value"):Connect(function()
		refreshItem(value.Name)
	end)
end

for _, value in ipairs(lapisStats:GetChildren()) do
	if value:IsA("IntValue") then watchValue(value) end
end

lapisStats.ChildAdded:Connect(function(value)
	if value:IsA("IntValue") then watchValue(value) end
end)

for _, discVal in ipairs(discoveredStats:GetChildren()) do
	discVal:GetPropertyChangedSignal("Value"):Connect(function()
		refreshItem(discVal.Name)
		updateAllSlotVisuals()
	end)
end

discoveredStats.ChildAdded:Connect(function(discVal)
	discVal:GetPropertyChangedSignal("Value"):Connect(function()
		refreshItem(discVal.Name)
		updateAllSlotVisuals()
	end)
end)

for _, slot in ipairs(list:GetChildren()) do
	if slot:IsA("GuiObject") then
		bindSlotInteraction(slot)
		refreshItem(slot.Name)
	end
end


--==================================================
-- QUANTITY BUTTON HANDLERS & SERVER FEEDBACK
--==================================================

local quantityButtonsData = {
	{name = "one", mode = "One"},
	{name = "quarter", mode = "Quarter"},
	{name = "half", mode = "Half"},
	{name = "all", mode = "All"},
}

local function sellSelectedItem(mode)
	if not selectedItemName then
		showNotification("SELECT AN ITEM TO SELL FIRST!", true)
		return
	end

	local slot = list:FindFirstChild(selectedItemName)
	if slot and slot:GetAttribute("IsFavorited") == true then
		showNotification("CANNOT SELL FAVORITED ITEM!", true)
		return
	end

	local intVal = lapisStats:FindFirstChild(selectedItemName)
	local currentCount = intVal and intVal.Value or 0

	if currentCount > 0 then
		local sellAmount = 1

		if mode == "One" then
			sellAmount = 1
		elseif mode == "Quarter" then
			sellAmount = math.clamp(math.floor(currentCount * 0.25), 1, currentCount)
		elseif mode == "Half" then
			sellAmount = math.clamp(math.floor(currentCount * 0.50), 1, currentCount)
		elseif mode == "All" then
			sellAmount = currentCount
		end

		if sellRemote then
			sellRemote:FireServer("SellItem", selectedItemName, sellAmount)
		end
	else
		showNotification("NO ITEMS LEFT TO SELL!", true)
	end
end

sellRemote.OnClientEvent:Connect(function(action, itemName, amount, totalEarnings, multiplier)
	if action == "SellSuccess" then
		local slot = list:FindFirstChild(itemName)
		if slot then
			popSlotAnimation(slot)
			spawnSparkles(slot, "💵", Color3.fromRGB(85, 255, 127))
		end

		local message = string.format("SOLD %dx %s FOR +$%d (%dx Multiplier!)", amount, formatItemDisplayName(itemName), totalEarnings, multiplier)
		showNotification(message, false)
	end
end)

for _, btnData in ipairs(quantityButtonsData) do
	local btnFolder = buttonsFrame:FindFirstChild(btnData.name)
	if btnFolder then
		bindUniversalClick(btnFolder, function()
			sellSelectedItem(btnData.mode)
		end)
	end
end


--==================================================
-- DISTANCE PROXIMITY CHECKER & TRIGGER LISTENER
--==================================================

local MAX_SELL_DISTANCE = 20 -- Adjust stud distance threshold as needed

workspace:GetAttributeChangedSignal("OpenSellMode"):Connect(function()
	local val = workspace:GetAttribute("OpenSellMode")
	if val ~= nil and val ~= false then
		selectedItemName = nil

		-- Automatically find the closest non-player part when opening
		local character = localPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")

		if rootPart then
			local closestPart = nil
			local shortestDist = math.huge

			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("BasePart") then
					-- Check if part belongs to any player's character and skip it
					local isCharacterPart = false
					for _, p in ipairs(Players:GetPlayers()) do
						if p.Character and obj:IsDescendantOf(p.Character) then
							isCharacterPart = true
							break
						end
					end

					if not isCharacterPart then
						local dist = (rootPart.Position - obj.Position).Magnitude
						if dist < shortestDist then
							shortestDist = dist
							closestPart = obj
						end
					end
				end
			end
			activeSellPart = closestPart
		end

		setSellMenuVisible(true)
		updateAllSlotVisuals()

		for _, slot in ipairs(list:GetChildren()) do
			if slot:IsA("GuiObject") then
				refreshItem(slot.Name)
			end
		end
	end
end)

-- Continuously monitor distance to the specific sell part while the UI is open
RunService.RenderStepped:Connect(function()
	if not container.Visible then return end

	local character = localPlayer.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

	if not humanoidRootPart then return end

	if activeSellPart and activeSellPart.Parent then
		local distance = (humanoidRootPart.Position - activeSellPart.Position).Magnitude
		if distance > MAX_SELL_DISTANCE then
			setSellMenuVisible(false)
		end
	else
		setSellMenuVisible(false)
	end
end)


--==================================================
-- CLOSE ON OTHER UI SHORTCUTS (G, F, R, T)
--==================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not container.Visible then return end

	if input.KeyCode == Enum.KeyCode.G 
		or input.KeyCode == Enum.KeyCode.F 
		or input.KeyCode == Enum.KeyCode.R 
		or input.KeyCode == Enum.KeyCode.T then
		setSellMenuVisible(false)
	end
end)