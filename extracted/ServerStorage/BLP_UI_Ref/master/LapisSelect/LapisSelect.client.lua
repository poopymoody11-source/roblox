local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local lapisRemote = ReplicatedStorage:WaitForChild("LapisRemote", 10)

local gui = script.Parent
local masterGui = gui.Parent
local container = gui:WaitForChild("Container")
local buttonsFrame = gui:WaitForChild("buttons")
local closeFrame = gui:WaitForChild("close")
local titleFrame = gui:FindFirstChild("title")

local itemsFrame = container:WaitForChild("items")
local list = itemsFrame:WaitForChild("list")

local playerStats = localPlayer:WaitForChild("PlayerStats")
local lapisStats = playerStats:WaitForChild("Lapis")
local discoveredStats = playerStats:WaitForChild("Discovered")

local activePlatform = nil
local selectedItemName = nil
local menuOpen = false -- tracks whether the whole panel session is
-- active (used for input gating / distance
-- checks) -- container/buttons/close/title all
-- show and hide together with this now
local MAX_DISTANCE = 20

--==================================================
-- SOUND EFFECTS & HIGHLIGHT
--==================================================
local successSound = Instance.new("Sound", SoundService)
successSound.SoundId = "rbxassetid://10066947742"
successSound.Volume = 0.25

local errorSound = Instance.new("Sound", SoundService)
errorSound.SoundId = "rbxassetid://132281440773764"
errorSound.Volume = 0.12

local containerStroke = container:FindFirstChild("ContainerGlow") or Instance.new("UIStroke")
containerStroke.Name = "ContainerGlow"
containerStroke.Thickness = 4
containerStroke.Color = Color3.fromRGB(35, 35, 35)
containerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
containerStroke.Parent = container

TweenService:Create(containerStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	Thickness = 7, Color = Color3.fromRGB(150, 150, 150)
}):Play()

--==================================================
-- NOTIFICATIONS & ANIMATIONS
--==================================================
local notifLabel = gui:FindFirstChild("Notification") or Instance.new("TextLabel")
notifLabel.Name = "Notification"
notifLabel.Size = UDim2.new(0.8, 0, 0.06, 0)
notifLabel.Position = UDim2.new(0.1, 0, 0.03, 0)
notifLabel.BackgroundTransparency = 1
notifLabel.TextScaled = true
notifLabel.Visible = false
notifLabel.ZIndex = 100
notifLabel.Parent = gui

local notifStroke = Instance.new("UIStroke")
notifStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
notifStroke.Thickness = 2
notifStroke.Parent = notifLabel

local activeAnim = nil

local function showNotification(message, isError)
	-- NOTE: no longer gated behind container.Visible -- Retrieve
	-- happens without the placement menu ever opening, and it still
	-- needs to show a popup.
	notifLabel.Text = message
	notifLabel.TextColor3 = isError and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(85, 255, 127)
	if isError then SoundService:PlayLocalSound(errorSound) else SoundService:PlayLocalSound(successSound) end

	if activeAnim then activeAnim:Cancel() end
	notifLabel.Position = UDim2.new(0.1, 0, 0.01, 0)
	notifLabel.TextTransparency = 1
	notifStroke.Transparency = 1
	notifLabel.Visible = true

	local popTween = TweenService:Create(notifLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.1, 0, 0.03, 0), TextTransparency = 0
	})
	TweenService:Create(notifStroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	popTween:Play()
	activeAnim = popTween

	task.delay(1.8, function()
		if notifLabel.Text == message then
			local exitTween = TweenService:Create(notifLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.1, 0, 0.01, 0), TextTransparency = 1
			})
			TweenService:Create(notifStroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			exitTween:Play()
			exitTween.Completed:Connect(function() if notifLabel.TextTransparency == 1 then notifLabel.Visible = false end end)
		end
	end)
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

			local endPos = UDim2.new(0.5 + (math.random() - 0.5) * 0.9, 0, 0.5 + (math.random() - 0.9) * 0.9, 0)
			local tween = TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = endPos, TextTransparency = 1, Size = UDim2.new(0, 24, 0, 24)
			})
			tween:Play()
			tween.Completed:Connect(function() p:Destroy() end)
		end)
	end
end

local function popSlotAnimation(slot)
	if not slot:GetAttribute("OriginalSize") then slot:SetAttribute("OriginalSize", slot.Size) end
	local orig = slot:GetAttribute("OriginalSize")
	slot.Size = UDim2.new(orig.X.Scale * 1.08, orig.X.Offset, orig.Y.Scale * 1.08, orig.Y.Offset)
	TweenService:Create(slot, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Size = orig }):Play()
end

--==================================================
-- INVENTORY SYNC & HELPER LOGIC
--==================================================
local function getDynamicInvList()
	if masterGui and masterGui:FindFirstChild("InventoryGui") then
		local cont = masterGui.InventoryGui:FindFirstChild("Container")
		if cont and cont:FindFirstChild("items") then return cont.items:FindFirstChild("list") end
	end
	return nil
end

local function updateSlotVisuals(slot)
	local itemName = slot.Name -- e.g. normal_lapis
	local invList = getDynamicInvList()

	if invList then
		local invSlot = invList:FindFirstChild(itemName)
		if invSlot then
			slot:SetAttribute("IsFavorited", invSlot:GetAttribute("IsFavorited") == true)
			slot:SetAttribute("IsAutoSell", invSlot:GetAttribute("IsAutoSell") == true)
		end
	end

	local discVal = discoveredStats:FindFirstChild(itemName)
	local isDiscovered = discVal and discVal.Value == true or false
	local isFavorited = isDiscovered and (slot:GetAttribute("IsFavorited") == true)
	local isAutoSell = isDiscovered and (slot:GetAttribute("IsAutoSell") == true)

	local overlay = slot:FindFirstChild("SlotHighlightOverlay")
	local badge = slot:FindFirstChild("ModeBadge")
	local amountFrame = slot:FindFirstChild("amount")

	if amountFrame then
		amountFrame.ZIndex = 30
		for _, child in ipairs(amountFrame:GetDescendants()) do if child:IsA("GuiObject") then child.ZIndex = 31 end end
	end

	if isFavorited or isAutoSell then
		if not overlay then
			overlay = Instance.new("Frame")
			overlay.Name = "SlotHighlightOverlay"
			overlay.Size = UDim2.new(1, 0, 1, 0)
			overlay.BackgroundTransparency = 1
			overlay.ZIndex = 20
			overlay.Parent = slot
			local corner = slot:FindFirstChildOfClass("UICorner")
			if corner then corner:Clone().Parent = overlay end
		end

		local strokeName = "SlotStroke"
		local stroke = overlay:FindFirstChild(strokeName) or Instance.new("UIStroke")
		stroke.Name = strokeName
		stroke.Thickness = 3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = isAutoSell and Color3.fromRGB(50, 220, 50) or Color3.fromRGB(255, 215, 0)
		stroke.Parent = overlay
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
			badgeStroke.Parent = badge
		end
		badge.Text = isAutoSell and "💵" or "★"
		badge.TextColor3 = isAutoSell and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(255, 220, 50)
		badge.Visible = true
	else
		if overlay then overlay.Visible = false end
		if badge then badge.Visible = false end
	end

	-- Selection highlight -- shows which lapis is currently picked to
	-- be placed (separate from the favorite/auto-sell badge above).
	local selectionOverlay = slot:FindFirstChild("PlaceSelectionGlow")
	if not selectionOverlay then
		selectionOverlay = Instance.new("Frame")
		selectionOverlay.Name = "PlaceSelectionGlow"
		selectionOverlay.Size = UDim2.new(1, 0, 1, 0)
		selectionOverlay.BackgroundTransparency = 0.85
		selectionOverlay.BackgroundColor3 = Color3.fromRGB(50, 220, 90)
		selectionOverlay.ZIndex = 25
		selectionOverlay.Parent = slot

		local stroke = Instance.new("UIStroke")
		stroke.Name = "GlowStroke"
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(60, 230, 100)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = selectionOverlay

		local corner = slot:FindFirstChildOfClass("UICorner")
		if corner then corner:Clone().Parent = selectionOverlay end
	end
	selectionOverlay.Visible = (slot.Name == selectedItemName)
end

local function updateAllSlotVisuals()
	for _, slot in ipairs(list:GetChildren()) do
		if slot:IsA("GuiObject") then updateSlotVisuals(slot) end
	end
end

local function updateSlot(slot)
	local itemName = slot.Name

	local intVal = lapisStats:FindFirstChild(itemName)
	local count = intVal and intVal.Value or 0

	local discVal = discoveredStats:FindFirstChild(itemName)
	local isDiscovered = discVal and discVal.Value == true

	local amountFrame = slot:FindFirstChild("amount")
	if amountFrame then 
		amountFrame.Visible = isDiscovered
		local textLabel = amountFrame:FindFirstChild("Frame") and amountFrame.Frame:FindFirstChild("TextLabel")
		if textLabel then textLabel.Text = "[" .. tostring(count) .. "x]" end
	end

	local lockedOverlay = slot:FindFirstChild("locked")
	if lockedOverlay then lockedOverlay.Visible = not isDiscovered end

	updateSlotVisuals(slot)
end

--==================================================
-- BINDINGS & STAT WATCHERS
--==================================================
local function setupInventoryAttributeSync(slot)
	task.spawn(function()
		local itemName = slot.Name
		local invList = getDynamicInvList()

		while not invList do
			task.wait(1)
			invList = getDynamicInvList()
		end

		local invSlot = invList:WaitForChild(itemName, 10)
		if invSlot then
			invSlot:GetAttributeChangedSignal("IsFavorited"):Connect(function()
				slot:SetAttribute("IsFavorited", invSlot:GetAttribute("IsFavorited"))
				updateSlotVisuals(slot)
			end)
			invSlot:GetAttributeChangedSignal("IsAutoSell"):Connect(function()
				slot:SetAttribute("IsAutoSell", invSlot:GetAttribute("IsAutoSell"))
				updateSlotVisuals(slot)
			end)
		end
	end)
end

-- Clicking a slot now only SELECTS it (highlights it + collapses the
-- item grid so the Place button is reachable). It does NOT place
-- anything by itself anymore -- see placeSelected() below, bound to
-- the "all" button under buttonsFrame.
local function selectSlot(slot)
	local itemName = slot.Name
	local discVal = discoveredStats:FindFirstChild(itemName)

	if not (discVal and discVal.Value) then
		showNotification("LAPIS NOT DISCOVERED!", true)
		return
	end

	if slot:GetAttribute("IsFavorited") == true then
		showNotification("CANNOT PLACE FAVORITED LAPIS!", true)
		return
	end

	local intVal = lapisStats:FindFirstChild(itemName)
	if not (intVal and intVal.Value > 0) then
		showNotification("YOU HAVE 0 OF THIS ITEM!", true)
		return
	end

	selectedItemName = itemName
	popSlotAnimation(slot)
	spawnSparkles(slot, "✨", Color3.fromRGB(255, 200, 50))
	updateAllSlotVisuals()

	-- Just highlight the selection (green outline via
	-- PlaceSelectionGlow below) -- the whole panel stays visible so
	-- the player can still browse/reconsider. Everything only hides
	-- together once placement is actually confirmed by the server
	-- (see the OnClientEvent handler at the bottom of this script).
end

local function bindSlotInteraction(slot)
	setupInventoryAttributeSync(slot)
	local lastClickTime = 0

	local function trigger()
		if not menuOpen or tick() - lastClickTime < 0.12 then return end
		lastClickTime = tick()
		selectSlot(slot)
	end

	local function hook(obj)
		if obj:IsA("GuiButton") then obj.Activated:Connect(trigger)
		elseif obj:IsA("GuiObject") then
			obj.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then trigger() end
			end)
		end
	end

	hook(slot)
	for _, child in ipairs(slot:GetDescendants()) do if child:IsA("GuiObject") then hook(child) end end
end

for _, slot in ipairs(list:GetChildren()) do
	if slot:IsA("GuiObject") then
		bindSlotInteraction(slot)
		updateSlot(slot)
	end
end

list.ChildAdded:Connect(function(slot)
	if slot:IsA("GuiObject") then
		bindSlotInteraction(slot)
		updateSlot(slot)
	end
end)

local function watchStat(val)
	val:GetPropertyChangedSignal("Value"):Connect(function()
		local slot = list:FindFirstChild(val.Name)
		if slot then updateSlot(slot) end
	end)
	local slot = list:FindFirstChild(val.Name)
	if slot then updateSlot(slot) end
end

for _, val in ipairs(lapisStats:GetChildren()) do watchStat(val) end
lapisStats.ChildAdded:Connect(watchStat)
for _, val in ipairs(discoveredStats:GetChildren()) do watchStat(val) end
discoveredStats.ChildAdded:Connect(watchStat)

--==================================================
-- PLACE BUTTON (the "all" folder under buttonsFrame)
--==================================================

local function placeSelected()
	if not menuOpen then return end

	if not selectedItemName then
		showNotification("SELECT A LAPIS FIRST!", true)
		return
	end

	local itemName = selectedItemName
	local slot = list:FindFirstChild(itemName)

	-- Re-validate -- state may have changed since selecting (sold it,
	-- favorited it, etc.) while the confirm screen was up.
	if slot and slot:GetAttribute("IsFavorited") == true then
		showNotification("CANNOT PLACE FAVORITED LAPIS!", true)
		return
	end

	local intVal = lapisStats:FindFirstChild(itemName)
	if not (intVal and intVal.Value > 0) then
		showNotification("YOU HAVE 0 OF THIS ITEM!", true)
		return
	end

	if not activePlatform then
		showNotification("NO PLATFORM SELECTED!", true)
		return
	end

	lapisRemote:FireServer("Place", itemName, activePlatform)
end

local placeButtonFolder = buttonsFrame:FindFirstChild("all")
if placeButtonFolder then
	local function hookPlace(obj)
		if obj:IsA("GuiButton") then
			obj.Activated:Connect(placeSelected)
		elseif obj:IsA("GuiObject") then
			obj.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					placeSelected()
				end
			end)
		end
	end
	hookPlace(placeButtonFolder)
	for _, child in ipairs(placeButtonFolder:GetDescendants()) do
		if child:IsA("GuiObject") then hookPlace(child) end
	end
else
	warn("[LapisSelect] Could not find 'all' (Place) button under buttonsFrame")
end

--==================================================
-- MENU VISIBILITY
--==================================================
local function setMenuVisible(visible)
	menuOpen = visible
	container.Visible = visible
	closeFrame.Visible = visible
	buttonsFrame.Visible = visible
	if titleFrame then titleFrame.Visible = visible end

	if visible then
		selectedItemName = nil
		for _, slot in ipairs(list:GetChildren()) do
			if slot:IsA("GuiObject") then updateSlot(slot) end
		end
	else
		activePlatform = nil
		selectedItemName = nil
	end
end
setMenuVisible(false)

local actualCloseBtn = closeFrame:FindFirstChildOfClass("TextButton") or closeFrame:FindFirstChildOfClass("ImageButton") or closeFrame
actualCloseBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then setMenuVisible(false) end
end)

--==================================================
-- PROXIMITY PROMPT: Select (open menu) vs Retrieve (skip menu)
--==================================================

local function hookPrompt(prompt)
	if prompt.Parent and prompt.Parent.Name == "Collector" then
		prompt.Triggered:Connect(function(player)
			if player ~= localPlayer then return end

			local platformLapis = prompt.Parent.Parent:FindFirstChild("PlatformLapis")
			if not platformLapis then return end

			if prompt:GetAttribute("HasLapis") then
				-- Already occupied -- retrieve directly, no menu.
				lapisRemote:FireServer("Retrieve", platformLapis)
			else
				activePlatform = platformLapis
				setMenuVisible(true)
			end
		end)
	end
end

for _, obj in ipairs(workspace:GetDescendants()) do if obj:IsA("ProximityPrompt") then hookPrompt(obj) end end
workspace.DescendantAdded:Connect(function(obj) if obj:IsA("ProximityPrompt") then hookPrompt(obj) end end)

RunService.RenderStepped:Connect(function()
	if not menuOpen or not activePlatform then return end
	local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - activePlatform.Position).Magnitude > MAX_DISTANCE then
		setMenuVisible(false)
	end
end)

--==================================================
-- SERVER RESPONSES
--==================================================

lapisRemote.OnClientEvent:Connect(function(action, msg, isError)
	showNotification(msg, isError)

	if action == "Place" and not isError then
		-- Placement confirmed -- fully close the panel now.
		selectedItemName = nil
		updateAllSlotVisuals()
		setMenuVisible(false)
	end
	-- "Retrieve" never opened the menu in the first place, so there's
	-- nothing else to reset here besides the notification above.
end)