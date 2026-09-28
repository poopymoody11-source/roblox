print("UI SCRIPT HAS STARTED RUNNING!")

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local cachedUI = nil
local buttonConnections = {}

local hudErrorSound = Instance.new("Sound", SoundService)
hudErrorSound.SoundId = "rbxassetid://132281440773764"
hudErrorSound.Volume = 0.08

local hudNotifLabel = nil

local TweenService = game:GetService("TweenService")

local hudErrorSound = Instance.new("Sound", SoundService)
hudErrorSound.SoundId = "rbxassetid://132281440773764"
hudErrorSound.Volume = 0.08

local hudNotifLabel = nil
local hudNotifStroke = nil
local hudActiveAnim = nil

local function getHudNotifLabel()
	if hudNotifLabel and hudNotifLabel.Parent then return hudNotifLabel end

	local screen = playerGui:FindFirstChild("Screen")
	if not screen then return nil end

	hudNotifLabel = screen:FindFirstChild("HUDNotification")
	if not hudNotifLabel then
		hudNotifLabel = Instance.new("TextLabel")
		hudNotifLabel.Name = "HUDNotification"
		hudNotifLabel.Size = UDim2.new(0.6, 0, 0.06, 0)
		hudNotifLabel.Position = UDim2.new(0.2, 0, 0.03, 0)
		hudNotifLabel.BackgroundTransparency = 1
		hudNotifLabel.TextScaled = true
		hudNotifLabel.Visible = false
		hudNotifLabel.ZIndex = 100
		hudNotifLabel.Parent = screen

		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Thickness = 2
		stroke.Parent = hudNotifLabel
	end

	hudNotifStroke = hudNotifLabel:FindFirstChildOfClass("UIStroke")
	return hudNotifLabel
end

local function showHudError(message)
	local label = getHudNotifLabel()
	if not label then return end

	label.Text = message
	label.TextColor3 = Color3.fromRGB(255, 80, 80)
	SoundService:PlayLocalSound(hudErrorSound)

	if hudActiveAnim then hudActiveAnim:Cancel() end

	label.Position = UDim2.new(0.2, 0, 0.01, 0)
	label.TextTransparency = 1
	if hudNotifStroke then hudNotifStroke.Transparency = 1 end
	label.Visible = true

	local popTween = TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.2, 0, 0.03, 0), TextTransparency = 0
	})
	if hudNotifStroke then
		TweenService:Create(hudNotifStroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	end
	popTween:Play()
	hudActiveAnim = popTween

	task.delay(1.8, function()
		if label.Text == message then
			local exitTween = TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.2, 0, 0.01, 0), TextTransparency = 1
			})
			if hudNotifStroke then
				TweenService:Create(hudNotifStroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
			exitTween:Play()
			exitTween.Completed:Connect(function()
				if label.TextTransparency == 1 then label.Visible = false end
			end)
		end
	end)
end

local function getUI()
	local screen = playerGui:WaitForChild("Screen", 10)
	if not screen then
		warn("[UI Script] Could not find 'Screen' in PlayerGui!")
		return nil
	end

	local master = screen:WaitForChild("master", 10)
	if not master then
		warn("[UI Script] Could not find 'master' under Screen!")
		return nil
	end

	return {
		master = master,
		inventoryGui = master:FindFirstChild("InventoryGui"),
		openInventory = master:FindFirstChild("OpenInventory"),
		robuxShop = master:FindFirstChild("RobuxShop"),
		regularShop = master:FindFirstChild("RegularShop"),
		teleport = master:FindFirstChild("teleport"),
		rebirth = master:FindFirstChild("rebirth"),
	}
end

local function setMenuVisible(menuInstance, visible)
	if not menuInstance then return end

	for _, child in ipairs(menuInstance:GetChildren()) do
		if child:IsA("GuiObject")
			and child.Name ~= "icon"
			and child.Name ~= "keybind"
			and not child.Name:lower():find("notification") then
			child.Visible = visible
		end
	end
end

local function isMenuOpen(menuInstance)
	if not menuInstance then return false end
	local container = menuInstance:FindFirstChild("Container") or menuInstance
	if container and container:IsA("GuiObject") then
		return container.Visible
	end
	return false
end

local function closeAllMenus(ui)
	if not ui then return end

	if ui.inventoryGui then
		local inventoryElements = { "Container", "Info", "info", "close", "title" }
		for _, name in ipairs(inventoryElements) do
			local elem = ui.inventoryGui:FindFirstChild(name)
			if elem and elem:IsA("GuiObject") then
				elem.Visible = false
			end
		end
	end

	if ui.robuxShop then
		local container = ui.robuxShop:FindFirstChild("Container") or ui.robuxShop
		if container:IsA("GuiObject") then container.Visible = false end
	end

	if ui.regularShop then
		local container = ui.regularShop:FindFirstChild("Container") or ui.regularShop
		if container:IsA("GuiObject") then container.Visible = false end
	end

	setMenuVisible(ui.teleport, false)
	setMenuVisible(ui.rebirth, false)
end

local function toggleTeleport()
	if not cachedUI or not cachedUI.teleport then return end

	-- (teleporting is free for everyone now - no base or upgrade needed)

	local shouldOpen = not isMenuOpen(cachedUI.teleport)
	closeAllMenus(cachedUI)
	setMenuVisible(cachedUI.teleport, shouldOpen)
end

local function toggleRebirth()
	if not cachedUI or not cachedUI.rebirth then return end
	local shouldOpen = not isMenuOpen(cachedUI.rebirth)
	closeAllMenus(cachedUI)
	setMenuVisible(cachedUI.rebirth, shouldOpen)
end

local function toggleRobuxShop()
	if not cachedUI or not cachedUI.robuxShop then return end
	local container = cachedUI.robuxShop:FindFirstChild("Container") or cachedUI.robuxShop
	local shouldOpen = container and not container.Visible
	closeAllMenus(cachedUI)
	if container and container:IsA("GuiObject") then
		container.Visible = shouldOpen
	end
end

local function toggleInventory()
	if not cachedUI or not cachedUI.inventoryGui then return end
	local inv = cachedUI.inventoryGui
	local container = inv:FindFirstChild("Container") or inv
	local shouldOpen = container and not container.Visible

	closeAllMenus(cachedUI)

	local inventoryElements = { "Container", "Info", "info", "close", "title" }
	for _, name in ipairs(inventoryElements) do
		local elem = inv:FindFirstChild(name)
		if elem and elem:IsA("GuiObject") then
			elem.Visible = shouldOpen
		end
	end
end

local function bindClick(instance, callback)
	if not instance then return end

	local buttons = {}
	if instance:IsA("GuiButton") then
		table.insert(buttons, instance)
	end
	for _, child in ipairs(instance:GetDescendants()) do
		if child:IsA("GuiButton") then
			table.insert(buttons, child)
		end
	end

	if #buttons == 0 and instance:IsA("GuiObject") then
		instance.Active = true
		local conn = instance.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				callback()
			end
		end)
		table.insert(buttonConnections, conn)
		return
	end

	for _, btn in ipairs(buttons) do
		btn.ZIndex = math.max(btn.ZIndex, 10)
		local conn = btn.Activated:Connect(callback)
		table.insert(buttonConnections, conn)
	end
end

local function setupAllButtons(ui)
	if not ui or not ui.master then return end

	for _, conn in ipairs(buttonConnections) do
		conn:Disconnect()
	end
	table.clear(buttonConnections)

	for _, descendant in ipairs(ui.master:GetDescendants()) do
		if descendant.Name == "close" then
			bindClick(descendant, function()
				closeAllMenus(cachedUI)
			end)
		end
	end

	if ui.teleport then
		bindClick(ui.teleport:FindFirstChild("icon"), toggleTeleport)
		bindClick(ui.teleport:FindFirstChild("keybind"), toggleTeleport)
	end

	if ui.rebirth then
		bindClick(ui.rebirth:FindFirstChild("icon"), toggleRebirth)
		bindClick(ui.rebirth:FindFirstChild("keybind"), toggleRebirth)
	end

	if ui.robuxShop then
		bindClick(ui.robuxShop:FindFirstChild("icon"), toggleRobuxShop)
		bindClick(ui.robuxShop:FindFirstChild("keybind"), toggleRobuxShop)
	end

	if ui.inventoryGui then
		bindClick(ui.inventoryGui:FindFirstChild("icon"), toggleInventory)
		bindClick(ui.inventoryGui:FindFirstChild("keybind"), toggleInventory)
	end

	if ui.openInventory then
		bindClick(ui.openInventory, toggleInventory)
	end
end

local function setupUI()
	cachedUI = getUI()
	if not cachedUI then return end

	closeAllMenus(cachedUI)
	setupAllButtons(cachedUI)

	local hudMenus = {
		cachedUI.teleport,
		cachedUI.rebirth,
		cachedUI.robuxShop,
		cachedUI.regularShop,
		cachedUI.inventoryGui,
		cachedUI.openInventory
	}

	for _, menu in ipairs(hudMenus) do
		if menu then
			for _, child in ipairs(menu:GetChildren()) do
				if child:IsA("GuiObject") and (child.Name == "icon" or child.Name == "keybind") then
					child.Visible = true
				end
			end
		end
	end
end

-- Force-close the teleport menu immediately if it becomes locked
-- (e.g. via /resetupgrades), even if it's already open.
-- (teleport is always unlocked now: nothing to force-close)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local m1sPerformed = 0
local currentM1 = 0
local m1Debounce = false
local comboEndCooldown = 0.5
local waitBeforeReset = 0.5
local SwingAnims = ReplicatedStorage:WaitForChild("SwingAnims")
local Swing = ReplicatedStorage:WaitForChild("Swing")
local TungQuest = workspace:FindFirstChild("TungQuest")
local templateHitbox = TungQuest:WaitForChild("RegularHitbox")
local upgradedHitbox = TungQuest:WaitForChild("UpgradedHitbox")
local Debris = game:GetService("Debris")
local SwingVisuals = ReplicatedStorage:WaitForChild("SwingVisuals")
local GroundSlam = ReplicatedStorage:WaitForChild("GroundSlam")

local function swing()
	if not m1Debounce then

		m1Debounce = true

		local character = player.Character
		local BatTool = character:FindFirstChild("Bat") or character:FindFirstChild("VerityBat")
		if not BatTool then
			m1Debounce = false
			return
		end
		local BatType = BatTool.Name

		local Handle = BatTool:FindFirstChild("Handle")
		if not character then
			m1Debounce = false
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local animator = humanoid and humanoid:FindFirstChild("Animator")
		if not humanoid or humanoid.Health <= 0 or not animator or not rootPart then
			m1Debounce = false
			return
		end

		m1sPerformed += 1
		currentM1 += 1

		local correspondingM1Anim = SwingAnims:FindFirstChild("Swing"..currentM1)
		if not correspondingM1Anim then
			warn("No M1 animation found for " .. tostring(currentM1))
			currentM1 = 0
			m1Debounce = false
			return
		end

		local m1Track = animator:LoadAnimation(correspondingM1Anim)
		m1Track.Looped = false

		local hitconnection = m1Track:GetMarkerReachedSignal("Hit"):Connect(function()
			SwingVisuals:FireServer(currentM1, BatType)
			if currentM1 == 3 then
				GroundSlam:FireServer(BatType)
			end

			if templateHitbox or upgradedHitbox then
				local activeHitbox
				if BatType == "VerityBat" then
					activeHitbox = upgradedHitbox:Clone()
				else
					activeHitbox = templateHitbox:Clone()
				end
				activeHitbox.CFrame = rootPart.CFrame * CFrame.new(0, 0, -3) 
				activeHitbox.Parent = workspace

				local overlapParams = OverlapParams.new()
				overlapParams.FilterDescendantsInstances = {character}
				overlapParams.FilterType = Enum.RaycastFilterType.Exclude

				local partsInBox = workspace:GetPartsInPart(activeHitbox, overlapParams)
				local hitHumanoids = {} 

				for _, part in ipairs(partsInBox) do
					-- walk up to the model that owns the Humanoid (bosses have nested accessories/meshes)
					local enemyModel = part.Parent
					while enemyModel and enemyModel ~= workspace and not enemyModel:FindFirstChildOfClass("Humanoid") do
						enemyModel = enemyModel.Parent
					end
					if enemyModel == workspace then enemyModel = nil end
					local enemyHumanoid = enemyModel and enemyModel:FindFirstChildOfClass("Humanoid")

					if enemyHumanoid and enemyHumanoid.Health > 0 and not hitHumanoids[enemyHumanoid] then
						hitHumanoids[enemyHumanoid] = true

						local enemyRoot = enemyModel:FindFirstChild("HumanoidRootPart")
						if enemyRoot then
							Swing:FireServer(enemyRoot, currentM1, BatType)
						end
					end
				end

				-- Cruelty: big forgiving hitbox (radius around his body, in front of you)
				local cc = workspace:FindFirstChild("CrueltyCutscene")
				local boss = cc and cc:FindFirstChild("Cruelty_Active")
				local bossHum = boss and boss:FindFirstChildOfClass("Humanoid")
				local bossRoot = boss and boss:FindFirstChild("HumanoidRootPart")
				if bossHum and bossRoot and bossHum.Health > 0 and not hitHumanoids[bossHum] then
					local reach = (BatType == "VerityBat") and 22 or 17
					local ok, size = pcall(function() return boss:GetExtentsSize() end)
					local bodyR = ok and math.min(math.max(size.X, size.Z) * 0.5, 12) or 4
					local off = bossRoot.Position - rootPart.Position
					local flat = Vector3.new(off.X, 0, off.Z)
					local dist = flat.Magnitude - bodyR
					local facing = flat.Magnitude < 0.1 or rootPart.CFrame.LookVector:Dot(flat.Unit) > -0.2
					if dist <= reach and math.abs(off.Y) < 40 and facing then
						hitHumanoids[bossHum] = true
						Swing:FireServer(bossRoot, currentM1, BatType)
					end
				end

				Debris:AddItem(activeHitbox, 2)
			else
				warn("Could not find workspace.TungQuest.RegularHitbox to clone!")
			end
		end)

		m1Track:Play()
		m1Track.Stopped:Wait()
		hitconnection:Disconnect()

		task.spawn(function()
			local oldM1sperformed = m1sPerformed
			task.wait(waitBeforeReset)
			if oldM1sperformed == m1sPerformed then
				currentM1 = 0
			end
		end)

		if currentM1 == 3 then
			task.wait(comboEndCooldown)
			currentM1 = 0
		end

		m1Debounce = false
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end	-- no menus while a cutscene has the screen (e.g. the QTE keys)
	for k, v in pairs(game:GetService("Players").LocalPlayer:GetAttributes()) do
		if v and k:sub(1, 8) == "HideHud_" then return end
	end

	if not cachedUI or not cachedUI.master or not cachedUI.master.Parent then
		cachedUI = getUI()
		if cachedUI then setupAllButtons(cachedUI) end
	end
	if not cachedUI then return end

	local keyCode = input.KeyCode

	if keyCode == Enum.KeyCode.T then
		toggleTeleport()
	elseif keyCode == Enum.KeyCode.R then
		toggleRebirth()
	elseif keyCode == Enum.KeyCode.F then
		toggleRobuxShop()
	elseif keyCode == Enum.KeyCode.G then
		toggleInventory()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		swing()
	end
end)

task.spawn(setupUI)

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	setupUI()
end)