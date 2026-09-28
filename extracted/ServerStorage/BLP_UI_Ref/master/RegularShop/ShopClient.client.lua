--==================================================
-- REGULAR SHOP & DIALOGUE CLIENT SCRIPT (UPDATED)
-- Place in: Your RegularShop Gui > LocalScript
-- Type: LocalScript
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local accessibleEvents = ReplicatedStorage:WaitForChild("AccessibleEvents")
local shopEvent = accessibleEvents:WaitForChild("ShopEvent")
local shopRemote = accessibleEvents:WaitForChild("ShopRemote")

local DialogModule = require(ReplicatedStorage:WaitForChild("DialogModule"))

local regularShop = script.Parent
local container = regularShop:WaitForChild("Container")
local cloaklist = container:WaitForChild("cloaklist")

-- Main ImageLabel located at the bottom of cloaklist
local bottomImageLabel = cloaklist:WaitForChild("ImageLabel", 5)

-- Category Buttons
local cloaksButton = regularShop:FindFirstChild("Cloaks", true) or regularShop:WaitForChild("Cloaks", 5)
local staffsButton = regularShop:FindFirstChild("Staffs", true) or regularShop:WaitForChild("Staffs", 5)
local closeButton = regularShop:FindFirstChild("close", true) or regularShop:WaitForChild("close", 5)

-- Colors
local GREEN_BG = Color3.fromRGB(50, 205, 50)
local PURPLE_BG = Color3.fromRGB(150, 50, 210)

-- Sounds
local successSound = Instance.new("Sound")
successSound.SoundId = "rbxassetid://10066947742"
successSound.Volume = 0.25
successSound.Parent = SoundService

local errorSound = Instance.new("Sound")
errorSound.SoundId = "rbxassetid://132281440773764"
errorSound.Volume = 0.12
errorSound.Parent = SoundService

local switchSound = Instance.new("Sound")
switchSound.SoundId = "rbxassetid://6895079853"
switchSound.Volume = 0.2
switchSound.Parent = SoundService

local ITEMS = {
	"normal_lapis", "golden_lapis", "diamond_lapis", "emerald_lapis",
	"rgb_lapis", "totem_lapis", "verity_lapis", "hell_lapis",
	"67_lapis", "lapeace_lapis", "malevolent_lapis", "interstellar_lapis",
	"op_lapis"
}

local currentCategory = "Staffs"
local equippedItem = "Staffs_normal_lapis"
local ownedItems = { Staffs_normal_lapis = true }
local itemBaseTitles = {}

-- Hide Container by default on start
container.Visible = false

local function getTextLabel(instance)
	if instance:IsA("TextLabel") then return instance end
	for _, child in ipairs(instance:GetChildren()) do
		local found = getTextLabel(child)
		if found then return found end
	end
	return nil
end

local function getItemTitleLabel(itemFrame)
	local imgLabel = itemFrame:FindFirstChildOfClass("ImageLabel") or itemFrame:FindFirstChild("ImageLabel")
	if imgLabel then
		local textBtn = imgLabel:FindFirstChildOfClass("TextButton") or imgLabel:FindFirstChild("TextButton")
		if textBtn then
			return textBtn:FindFirstChildOfClass("TextLabel") or textBtn:FindFirstChild("TextLabel")
		end
	end
	return nil
end

local function getLockedFrame(itemFrame)
	return itemFrame:FindFirstChild("locked", true)
end

-- Pre-store base item titles
for _, itemName in ipairs(ITEMS) do
	local frame = cloaklist:FindFirstChild(itemName)
	if frame then
		local titleLabel = getItemTitleLabel(frame)
		if titleLabel then
			local cleanText = titleLabel.Text:gsub("%s*Staff%s*", ""):gsub("%s*Cloak%s*", "")
			itemBaseTitles[frame] = cleanText
		end
	end
end

-- Font Auto-Detection
local shopFont = Enum.Font.FredokaOne
for _, itemName in ipairs(ITEMS) do
	local frame = cloaklist:FindFirstChild(itemName)
	if frame then
		local label = getTextLabel(frame)
		if label then
			shopFont = label.Font
			break
		end
	end
end

-- Floating Notification UI Setup
local notifLabel = regularShop:FindFirstChild("ShopNotification")
if not notifLabel then
	notifLabel = Instance.new("TextLabel")
	notifLabel.Name = "ShopNotification"
	notifLabel.Size = UDim2.new(0.6, 0, 0.06, 0)
	notifLabel.Position = UDim2.new(0.2, 0, 0.03, 0)
	notifLabel.BackgroundTransparency = 1
	notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	notifLabel.TextStrokeTransparency = 1
	notifLabel.RichText = false
	notifLabel.TextScaled = true
	notifLabel.Font = shopFont
	notifLabel.Text = ""
	notifLabel.Visible = false
	notifLabel.ZIndex = 100
	notifLabel.Parent = regularShop

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Parent = notifLabel
end

for _, child in ipairs(notifLabel:GetChildren()) do
	if child:IsA("UIGradient") then
		child:Destroy()
	end
end

local activeAnim = nil

local function showNotification(message, isError)
	notifLabel.Text = message
	notifLabel.Font = shopFont

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

local function updateUI()
	for _, itemName in ipairs(ITEMS) do
		local frame = cloaklist:FindFirstChild(itemName)
		if frame then
			local itemKey = currentCategory .. "_" .. itemName
			local isOwned = (ownedItems[itemKey] == true) or (ownedItems[itemName] == true) or (equippedItem == itemKey)

			local lockedFrame = getLockedFrame(frame)
			if lockedFrame then
				if currentCategory == "Cloaks" then
					lockedFrame.Visible = true
				else
					lockedFrame.Visible = not isOwned
				end
				if lockedFrame:IsA("GuiObject") then lockedFrame.Active = false end
			end

			local buyFrame = frame:FindFirstChild("buy")
			if buyFrame then
				local textLabel = getTextLabel(buyFrame)
				if textLabel then
					if currentCategory == "Cloaks" then
						textLabel.Text = "COMING SOON"
					elseif equippedItem == itemKey then
						textLabel.Text = "EQUIPPED"
					elseif isOwned then
						textLabel.Text = "EQUIP"
					else
						textLabel.Text = "PURCHASE"
					end
				end
			end
		end
	end
end

local function setCategory(category)
	currentCategory = category
	SoundService:PlayLocalSound(switchSound)

	local targetColor = (category == "Cloaks") and PURPLE_BG or GREEN_BG
	local categorySuffix = (category == "Cloaks") and "Cloak" or "Staff"

	if bottomImageLabel then
		TweenService:Create(bottomImageLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = targetColor,
			ImageColor3 = targetColor
		}):Play()

		local innerImage = bottomImageLabel:FindFirstChildOfClass("ImageLabel")
		if innerImage then
			TweenService:Create(innerImage, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = targetColor,
				ImageColor3 = targetColor
			}):Play()
		end
	end

	for _, itemName in ipairs(ITEMS) do
		local frame = cloaklist:FindFirstChild(itemName)
		if frame then
			local titleLabel = getItemTitleLabel(frame)
			if titleLabel then
				local baseName = itemBaseTitles[frame] or titleLabel.Text
				titleLabel.Text = baseName .. " " .. categorySuffix
			end
		end
	end

	updateUI()
end

local function bindCategoryButton(btn, category)
	local function trigger()
		if currentCategory ~= category then setCategory(category) end
	end
	local function attachListener(obj)
		if obj:IsA("GuiButton") then
			obj.MouseButton1Click:Connect(trigger)
		elseif obj:IsA("GuiObject") then
			obj.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					trigger()
				end
			end)
		end
	end
	attachListener(btn)
	for _, child in ipairs(btn:GetDescendants()) do attachListener(child) end
end

if cloaksButton then bindCategoryButton(cloaksButton, "Cloaks") end
if staffsButton then bindCategoryButton(staffsButton, "Staffs") end

local function closeShop()
	container.Visible = false
	SoundService:PlayLocalSound(switchSound)
end

if closeButton then
	local function attachCloseListener(obj)
		if obj:IsA("GuiButton") then
			obj.MouseButton1Click:Connect(closeShop)
		elseif obj:IsA("GuiObject") then
			obj.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					closeShop()
				end
			end)
		end
	end
	attachCloseListener(closeButton)
	for _, child in ipairs(closeButton:GetDescendants()) do 
		attachCloseListener(child)
	end
end

-- Distance Check loop to auto-close shop when walking away
local distanceConn = nil
local function monitorDistance(npc)
	if distanceConn then distanceConn:Disconnect() end

	distanceConn = RunService.RenderStepped:Connect(function()
		if not container.Visible then
			distanceConn:Disconnect()
			return
		end

		local char = player.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		if rootPart and npc then
			local npcPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Part") or npc.PrimaryPart or npc:FindFirstChildOfClass("BasePart")
			if npcPart then
				local distance = (rootPart.Position - npcPart.Position).Magnitude
				if distance > 18 then
					closeShop()
					distanceConn:Disconnect()
				end
			end
		end
	end)
end

-- Dialogue Integration via RemoteEvent
shopRemote.OnClientEvent:Connect(function(action, npc)
	if action == "OpenDialog" and npc then
		local prompt = npc:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then return end

		local dialogObject = DialogModule.new("Merchant", npc, prompt)
		dialogObject:addDialog("Hello! Would you like to open the item shop?", {"Yes, open item shop", "No, thanks"})
		dialogObject:triggerDialog(player, 1)

		task.spawn(function()
			task.wait(0.05)
			for _, desc in ipairs(npc:GetDescendants()) do
				if desc:IsA("BillboardGui") then
					desc.AlwaysOnTop = true
					for _, subDesc in ipairs(desc:GetDescendants()) do
						if subDesc:IsA("TextLabel") or subDesc:IsA("TextButton") then
							subDesc.TextColor3 = Color3.fromRGB(255, 60, 60)
						end
					end
				end
			end
		end)

		local connection
		connection = dialogObject.responded:Connect(function(responseNum, dialogNum)
			if dialogNum == 1 then
				if responseNum == 1 then
					dialogObject:hideGui("Opening store...")
					regularShop.Enabled = true
					container.Visible = true
					SoundService:PlayLocalSound(switchSound)
					monitorDistance(npc)
				elseif responseNum == 2 then
					dialogObject:hideGui("Come back anytime!")
				end
				connection:Disconnect()
			end
		end)
	end
end)

-- Bind Purchase/Equip Button Listeners
for _, itemName in ipairs(ITEMS) do
	local frame = cloaklist:FindFirstChild(itemName)
	if frame then
		local buyFrame = frame:FindFirstChild("buy")
		if buyFrame then
			local lastClick = 0
			local function triggerPurchase()
				if os.clock() - lastClick < 0.4 then return end
				lastClick = os.clock()
				if currentCategory == "Cloaks" then
					showNotification("CLOAKS ARE COMING SOON!", true)
					return
				end
				shopEvent:FireServer("BuyOrEquip", itemName, currentCategory)
			end
			local function attachListener(obj)
				if obj:IsA("GuiButton") then
					obj.MouseButton1Click:Connect(triggerPurchase)
				elseif obj:IsA("GuiObject") then
					obj.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							triggerPurchase()
						end
					end)
				end
			end
			attachListener(buyFrame)
			for _, child in ipairs(buyFrame:GetDescendants()) do attachListener(child) end
		end
	end
end

shopEvent.OnClientEvent:Connect(function(action, data, category)
	if action == "Init" or action == "LoadData" then
		if type(data) == "table" then
			ownedItems = data
		else
			ownedItems = { Staffs_normal_lapis = true }
		end

		if type(category) == "string" then
			equippedItem = category
		else
			equippedItem = "Staffs_normal_lapis"
		end
		updateUI()
	elseif action == "BuySuccess" then
		category = category or currentCategory
		local itemKey = category .. "_" .. data
		ownedItems[itemKey] = true
		equippedItem = itemKey
		updateUI()
		showNotification("PURCHASE SUCCESSFUL!", false)
	elseif action == "EquipSuccess" then
		category = category or currentCategory
		local itemKey = category .. "_" .. data
		ownedItems[itemKey] = true
		equippedItem = itemKey
		updateUI()
		showNotification((category == "Cloaks" and "CLOAK" or "STAFF") .. " EQUIPPED!", false)
	elseif action == "BuyError" then
		showNotification(data, true)
	end
end)

setCategory("Staffs")