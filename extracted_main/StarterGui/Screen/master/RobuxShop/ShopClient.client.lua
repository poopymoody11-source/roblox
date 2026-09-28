--==================================================
-- ROBUX SHOP CLIENT
--
-- Before this existed the shop was a picture: every
-- PURCHASE button was an ImageButton with nothing
-- connected to it, and the prices were typed into the
-- labels by hand.
--
-- Now every label is written from MonetizationData at
-- runtime, so the card, the purchase prompt and the
-- server all quote the same number by construction --
-- change a price in the module and the shop follows.
--
-- Place as a LocalScript in StarterGui.Screen.master.RobuxShop
--==================================================

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local MonetizationData = require(
	ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("MonetizationData")
)

local shop = script.Parent
local gamepasses = shop:WaitForChild("Container"):WaitForChild("items"):WaitForChild("Gamepasses")
local passesFolder = gamepasses:WaitForChild("Passes")
local productsFolder = gamepasses:WaitForChild("PeacePoints")

local OWNED_COLOR = Color3.fromRGB(70, 170, 90)
local SOON_COLOR = Color3.fromRGB(150, 150, 150)
local OWNED_TEXT = "OWNED"
local BUY_TEXT = "PURCHASE"
local SOON_TEXT = "COMING NEVER"

--==================================================
-- HELPERS
--==================================================

local function findBuyButton(card)
	local buy = card:FindFirstChild("buy")
	if not buy then return nil, nil end
	return buy:FindFirstChildWhichIsA("ImageButton"), buy:FindFirstChildWhichIsA("TextLabel")
end

-- A short bounce so a tap feels like it did something even
-- if the Robux prompt takes a moment to appear.
local function pulse(button)
	if not button then return end

	local original = button.Size
	local shrunk = UDim2.new(
		original.X.Scale * 0.92, original.X.Offset,
		original.Y.Scale * 0.92, original.Y.Offset
	)

	local info = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(button, info, { Size = shrunk }):Play()

	task.delay(0.1, function()
		if button.Parent then
			TweenService:Create(button, info, { Size = original }):Play()
		end
	end)
end

local function setText(instance, text)
	if instance and instance:IsA("TextLabel") then
		instance.Text = text
	end
end

--==================================================
-- GAMEPASS CARDS
--==================================================

local function markOwned(card, isOwned)
	local button, label = findBuyButton(card)

	if label then
		label.Text = isOwned and OWNED_TEXT or BUY_TEXT
		if isOwned then
			label.TextColor3 = OWNED_COLOR
		end
	end

	if button then
		-- Left clickable on purpose when owned: tapping opens the
		-- pass page, which is how a player gifts one to a friend.
		button.AutoButtonColor = not isOwned
	end
end

local function setupPass(pass)
	-- Bundles live directly under Gamepasses, everything else
	-- under Gamepasses.Passes.
	local card = passesFolder:FindFirstChild(pass.Frame)
		or gamepasses:FindFirstChild(pass.Frame)

	if not card then
		warn("[Shop] no card named " .. pass.Frame .. " for " .. pass.Name)
		return
	end

	-- Title. The bundles paint their own name into the artwork,
	-- so only the plain pass cards get overwritten.
	if card.Parent == passesFolder then
		setText(card:FindFirstChild("TextLabel"), pass.Name)
	end

	-- Price. Bundles keep theirs in a separate starburst label.
	local priceText = MonetizationData.FormatRobux(pass.Price)

	if pass.CostFrame then
		local tag = gamepasses:FindFirstChild(pass.CostFrame)
		setText(tag and tag:FindFirstChild(pass.CostLabel or "TextLabel"), priceText)
	else
		setText(card:FindFirstChild(pass.CostLabel or "cost"), priceText)
	end

	local button, label = findBuyButton(card)

	-- A pass marked ComingSoon grants nothing yet and is off sale
	-- on the dashboard. Showing a live PURCHASE button for it would
	-- send players to a prompt that either fails or takes their
	-- Robux for nothing, so the card says so and stays inert.
	if pass.ComingSoon then
		setText(label, SOON_TEXT)
		if label then label.TextColor3 = SOON_COLOR end
		if button then button.AutoButtonColor = false end
		return
	end

	if button then
		button.Activated:Connect(function()
			pulse(button)
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end)
	end

	local attribute = MonetizationData.AttributeFor(pass.Key)

	markOwned(card, player:GetAttribute(attribute) == true)

	-- MonetizationService's web lookup lands a moment after join,
	-- and again the instant a purchase completes, so the card has
	-- to react rather than read once.
	player:GetAttributeChangedSignal(attribute):Connect(function()
		markOwned(card, player:GetAttribute(attribute) == true)
	end)
end

--==================================================
-- PEACEPOINT PACKS
--
-- Developer products, so there is no "owned" state --
-- they can be bought over and over.
--==================================================

local function setupProduct(product)
	local card = productsFolder:FindFirstChild(product.Frame)

	if not card then
		warn("[Shop] no card named " .. product.Frame .. " for " .. product.Label)
		return
	end

	setText(card:FindFirstChild("TextLabel"), product.Label)
	setText(card:FindFirstChild("cost"), MonetizationData.FormatRobux(product.Price))

	local button, label = findBuyButton(card)
	setText(label, BUY_TEXT)

	if button then
		button.Activated:Connect(function()
			pulse(button)
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end)
	end
end

--==================================================

for _, pass in ipairs(MonetizationData.Passes) do
	local ok, err = pcall(setupPass, pass)
	if not ok then
		warn("[Shop] couldn't set up " .. pass.Name .. ": " .. tostring(err))
	end
end

for _, product in ipairs(MonetizationData.Products) do
	local ok, err = pcall(setupProduct, product)
	if not ok then
		warn("[Shop] couldn't set up " .. product.Label .. ": " .. tostring(err))
	end
end
