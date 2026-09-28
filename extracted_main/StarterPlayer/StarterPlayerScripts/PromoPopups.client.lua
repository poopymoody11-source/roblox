--==================================================
-- PROMO POPUPS  (client)
--
-- 1. Every few minutes a small gamepass offer slides in from the
--    left: one random pass the player DOESN'T own yet. BUY opens the
--    normal Robux prompt, X dismisses it, it also leaves by itself.
-- 2. Like + favorite the game for 10,000 PP (once): a card offers it now
--    and then until it's claimed (replaces Roblox's own favorite prompt).
--
-- Never shows during the intro cutscene or the tutorial.
-- Tune the timings in CONFIG.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Monetization = require(ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("MonetizationData"))

local CONFIG = {
	FIRST_PASS_DELAY = 150,      -- seconds after joining before the first offer
	PASS_INTERVAL_MIN = 330,     -- then one every 5.5..9 minutes
	PASS_INTERVAL_MAX = 540,
	PASS_SHOW_TIME = 12,         -- how long an offer stays up
	FAVORITE_DELAY = 600,        -- ask to favorite after 10 minutes
}

-- The same artwork the Robux shop uses for each pass, so the popup and the
-- shop page read as the same product. Falls back to the Roblox gamepass
-- thumbnail if a key isn't listed here.
local SHOP_ICONS = {
	DoubleMoney      = "rbxthumb://type=Asset&id=10827597498&w=420&h=420",
	DoubleAscensions = "rbxthumb://type=Asset&id=18367579979&w=420&h=420",
	UnlockAllIslands = "rbxassetid://3153322768",
	OpStaff          = "rbxassetid://1177220575",
	Elytra           = "rbxassetid://86985228579459",
	AutoSell         = "rbxassetid://15506906740",
	OpRobe           = "rbxassetid://2155016056",
	Admin            = "rbxassetid://1177226489",
	VerityBundle     = "rbxassetid://72449061338513",
	LaPeaceBundle    = "rbxassetid://79764642487535",
}

local BLURBS = {
	DoubleMoney = "Earn DOUBLE PP from everything - selling lapis and your base.",
	DoubleAscensions = "Ascending costs HALF as much.",
	UnlockAllIslands = "Skip the grind: every island unlocked now.",
	OpStaff = "The Command Staff. Fling everyone. Pull everything.",
	Elytra = "Double-tap jump and FLY across the islands.",
	AutoSell = "Lapis sells itself the moment you pick it up.",
	VerityBundle = "1,400 lapis, permanent 1.5x PP + an upgraded Verity Staff+.",
	LaPeaceBundle = "The ultimate bundle: permanent 2x PP, La Peace Staff+ and 1,450 top-tier lapis.",
}

local function busy()
	if playerGui:FindFirstChild("IntroCutscene") then return true end
	local tut = playerGui:FindFirstChild("Tutorial")
	return tut ~= nil and tut.Enabled
end

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end

--==================================================
-- OFFER CARD
--==================================================

local INCON = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)
local INCON_I = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
local FRED = Font.new("rbxasset://fonts/families/FredokaOne.json")
local PANEL = Color3.fromRGB(83, 74, 70)
local PATTERN = "rbxassetid://83787990994298"   -- same dotted texture as the quest panel
local BTN_PATTERN = "rbxassetid://967375948"    -- same texture as the side buttons
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

local function stroke(t, col) return new("UIStroke", { Thickness = t, Color = col or BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function tstroke(t) return new("UIStroke", { Thickness = t, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }) end
local function grad(a, b) return new("UIGradient", { Rotation = -90, Color = ColorSequence.new(a, b) }) end

local gui = new("ScreenGui", { Name = "PassOffer", ResetOnSpawn = false, DisplayOrder = 20, Parent = playerGui })
-- Sits directly above the quest panel on the left, anchored by its BOTTOM
-- edge so it grows upward and never overlaps the quest list.
local HIDDEN = UDim2.new(0, -380, 0.30, 0)
local SHOWN = UDim2.new(0, 16, 0.30, 0)

local card = new("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = HIDDEN, Size = UDim2.fromOffset(340, 134),
	BackgroundColor3 = PANEL, Visible = false, Parent = gui,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 16) }),
	stroke(5),
	grad(Color3.fromRGB(150, 142, 153), Color3.fromRGB(46, 20, 55)),
	new("UIScale", { Name = "Pop", Scale = 1 }),
	new("ImageLabel", { Name = "Pattern", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = PATTERN, ImageTransparency = 0.75, ZIndex = 1 }, {
		new("UICorner", { CornerRadius = UDim.new(0, 16) }),
	}),
})
local cardScale = card.Pop

-- "GAMEPASS" tab sitting on the top edge, like the QUESTS tab
local tab = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(18, 0), Size = UDim2.fromOffset(128, 30),
	BackgroundColor3 = PANEL, ZIndex = 6, Parent = card,
}, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	stroke(4),
	grad(Color3.fromRGB(255, 226, 120), Color3.fromRGB(214, 120, 20)),
	new("TextLabel", { Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), BackgroundTransparency = 1, FontFace = FRED, Text = "GAMEPASS", TextScaled = true, TextColor3 = WHITE, ZIndex = 7 }, { tstroke(2.5) }),
})

-- icon, in a tile styled like the side buttons
local tile = new("Frame", {
	Position = UDim2.fromOffset(14, 24), Size = UDim2.fromOffset(92, 92), BackgroundColor3 = Color3.fromRGB(170, 85, 0), ZIndex = 3, Parent = card,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 14) }),
	stroke(4),
	grad(Color3.fromRGB(71, 27, 13), Color3.fromRGB(240, 232, 103)),
	new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = BTN_PATTERN, ImageTransparency = 0.8, ZIndex = 3 }, { new("UICorner", { CornerRadius = UDim.new(0, 14) }) }),
})
local icon = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86),
	BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = tile,
}, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
-- rotating shine behind the icon
local shine = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62),
	BackgroundTransparency = 1, ZIndex = 3, Parent = tile,
})
for k = 0, 1 do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Rotation = k * 45,
		BackgroundColor3 = Color3.fromRGB(255, 244, 180), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 3, Parent = shine,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
end

local nameLabel = new("TextLabel", {
	Position = UDim2.fromOffset(118, 20), Size = UDim2.new(1, -156, 0, 28), BackgroundTransparency = 1,
	FontFace = FRED, TextScaled = true, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = card,
}, { tstroke(2.5), new("UITextSizeConstraint", { MaxTextSize = 26 }) })
local blurb = new("TextLabel", {
	Position = UDim2.fromOffset(118, 50), Size = UDim2.new(1, -128, 0, 42), BackgroundTransparency = 1,
	FontFace = INCON, TextSize = 13, TextWrapped = true, TextColor3 = Color3.fromRGB(240, 232, 220),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5, Parent = card,
}, { tstroke(1.5) })
local buy = new("TextButton", {
	Position = UDim2.fromOffset(118, 94), Size = UDim2.fromOffset(160, 30), BackgroundColor3 = Color3.fromRGB(46, 190, 90),
	FontFace = FRED, TextSize = 17, TextColor3 = WHITE, Text = "BUY", AutoButtonColor = false, ZIndex = 5, ClipsDescendants = true, Parent = card,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 10) }),
	stroke(3.5),
	grad(Color3.fromRGB(20, 110, 50), Color3.fromRGB(130, 255, 140)),
	tstroke(2),
	new("UIScale", { Name = "Press", Scale = 1 }),
})
local buyShine = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.3, 0.5), Size = UDim2.new(0, 18, 2, 0), Rotation = 20,
	BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 6, Parent = buy,
})
-- the button stroke above is Border; text stroke is the Contextual one
local close = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = Color3.fromRGB(235, 60, 60), FontFace = INCON_I, TextSize = 18,
	TextColor3 = WHITE, Text = "X", AutoButtonColor = false, ZIndex = 8, Parent = card,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(3.5), tstroke(2) })
-- time-left bar along the bottom
local timerBack = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -30, 0, 5),
	BackgroundColor3 = Color3.fromRGB(30, 22, 30), BorderSizePixel = 0, ZIndex = 5, Parent = card,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local timerFill = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 205, 80), BorderSizePixel = 0, ZIndex = 6, Parent = timerBack,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

-- idle animation: spinning shine, bobbing icon, shine sweep over BUY
task.spawn(function()
	local RunService = game:GetService("RunService")
	local sweepT = 0
	RunService.RenderStepped:Connect(function(dt)
		if not card.Visible then return end
		local t = os.clock()
		shine.Rotation = (t * 40) % 360
		icon.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 2.6) * 3)
		icon.Rotation = math.sin(t * 1.7) * 4
		sweepT += dt
		local k = (sweepT % 2.4) / 0.6
		buyShine.Position = UDim2.fromScale(-0.3 + math.min(k, 1) * 1.6, 0.5)
	end)
end)

local function hover(btn, scale)
	local sc = btn:FindFirstChild("Press")
	btn.MouseEnter:Connect(function()
		if sc then TweenService:Create(sc, TweenInfo.new(0.12), { Scale = scale }):Play() end
	end)
	btn.MouseLeave:Connect(function()
		if sc then TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play() end
	end)
end
hover(buy, 1.06)

local currentPass = nil
local showToken = 0

local function hide()
	showToken += 1
	currentPass = nil
	TweenService:Create(cardScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Scale = 0.9 }):Play()
	local tw = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = HIDDEN, Rotation = -6 })
	tw:Play()
	tw.Completed:Once(function() if not currentPass then card.Visible = false end end)
end

local iconCache = {}
local function passIcon(pass)
	local shop = SHOP_ICONS[pass.Key]
	if shop then return shop end
	if iconCache[pass.Id] ~= nil then return iconCache[pass.Id] end
	local ok, info = pcall(function() return MarketplaceService:GetProductInfo(pass.Id, Enum.InfoType.GamePass) end)
	local img = (ok and info and info.IconImageAssetId and info.IconImageAssetId ~= 0)
		and ("rbxassetid://" .. info.IconImageAssetId) or ""
	iconCache[pass.Id] = img
	return img
end

local function pickPass()
	local pool, all = {}, {}
	for _, pass in ipairs(Monetization.Passes) do
		local benefit = Monetization.Benefits[pass.Key]
		if not pass.ComingSoon and not (benefit and benefit.ComingSoon) and pass.Id ~= 0 then
			table.insert(all, pass)
			if not Monetization.Owns(player, pass.Key) then
				table.insert(pool, pass)
			end
		end
	end
	-- Players who own everything (you, in Studio / as the owner, get every
	-- pass for free) used to never see a popup at all -- which is why it
	-- looked broken. They still get offers, shown as "OWNED" (gift it).
	if #pool == 0 then pool = all end
	if #pool == 0 then return nil end
	return pool[math.random(#pool)]
end

local function showOffer()
	if busy() or currentPass or gui:GetAttribute("FavUp") then return end
	local pass = pickPass()
	if not pass then return end
	currentPass = pass
	showToken += 1
	local my = showToken
	nameLabel.Text = pass.Name
	blurb.Text = BLURBS[pass.Key] or ""
	buy.Text = Monetization.Owns(player, pass.Key) and "OWNED  (GIFT)" or ("BUY  " .. Monetization.FormatRobux(pass.Price))
	icon.Image = passIcon(pass)
	card.Position = HIDDEN
	card.Rotation = -8
	cardScale.Scale = 0.85
	card.Visible = true
	TweenService:Create(card, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = SHOWN, Rotation = 0 }):Play()
	TweenService:Create(cardScale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	timerFill.Size = UDim2.fromScale(1, 1)
	TweenService:Create(timerFill, TweenInfo.new(CONFIG.PASS_SHOW_TIME, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
	task.delay(CONFIG.PASS_SHOW_TIME, function()
		if showToken == my then hide() end
	end)
end

buy.MouseButton1Click:Connect(function()
	local pass = currentPass
	if pass then
		pcall(function() MarketplaceService:PromptGamePassPurchase(player, pass.Id) end)
	end
	hide()
end)
close.MouseButton1Click:Connect(hide)
-- Studio preview hook: set the player attribute "DebugPassOffer" to force an offer
if game:GetService("RunService"):IsStudio() then
	player:GetAttributeChangedSignal("DebugPassOffer"):Connect(function() showOffer() end)
end

task.spawn(function()
	task.wait(CONFIG.FIRST_PASS_DELAY)
	while true do
		showOffer()
		task.wait(math.random(CONFIG.PASS_INTERVAL_MIN, CONFIG.PASS_INTERVAL_MAX))
	end
end)

--==================================================
-- LIKE + FAVORITE REWARD (replaces Roblox's own favorite prompt)
-- Favorite the game and you get 10,000 PP, once. Until you have,
-- a little card in the game's style pops up now and then offering
-- it; its button opens the favorite prompt. Favoriting from the
-- game page works too: it's noticed and paid out automatically.
--==================================================
local favRemote = ReplicatedStorage:WaitForChild("FavoriteReward", 30)
local FAV_FIRST, FAV_EVERY, FAV_MAX = 120, 480, 4 -- first card after 2 min, then every 8, at most 4 a session

local favCard = new("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = HIDDEN, Size = UDim2.fromOffset(340, 134),
	BackgroundColor3 = PANEL, Visible = false, Parent = gui,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 16) }),
	stroke(5),
	grad(Color3.fromRGB(150, 142, 153), Color3.fromRGB(46, 20, 55)),
	new("UIScale", { Name = "Pop", Scale = 1 }),
	new("ImageLabel", { Name = "Pattern", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = PATTERN, ImageTransparency = 0.75, ZIndex = 1 }, {
		new("UICorner", { CornerRadius = UDim.new(0, 16) }),
	}),
})
local favScale = favCard.Pop
new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(18, 0), Size = UDim2.fromOffset(128, 30),
	BackgroundColor3 = PANEL, ZIndex = 6, Parent = favCard,
}, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	stroke(4),
	grad(Color3.fromRGB(140, 255, 150), Color3.fromRGB(20, 140, 60)),
	new("TextLabel", { Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), BackgroundTransparency = 1, FontFace = FRED, Text = "FREE PP", TextScaled = true, TextColor3 = WHITE, ZIndex = 7 }, { tstroke(2.5) }),
})
local favTile = new("Frame", {
	Position = UDim2.fromOffset(14, 24), Size = UDim2.fromOffset(92, 92), BackgroundColor3 = Color3.fromRGB(170, 85, 0), ZIndex = 3, Parent = favCard,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 14) }),
	stroke(4),
	grad(Color3.fromRGB(71, 27, 13), Color3.fromRGB(240, 232, 103)),
	new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = BTN_PATTERN, ImageTransparency = 0.8, ZIndex = 3 }, { new("UICorner", { CornerRadius = UDim.new(0, 14) }) }),
})
local favStar = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.9),
	BackgroundTransparency = 1, FontFace = FRED, TextScaled = true, Text = "⭐", ZIndex = 4, Parent = favTile,
})
local favTitle = new("TextLabel", {
	Position = UDim2.fromOffset(118, 20), Size = UDim2.new(1, -156, 0, 28), BackgroundTransparency = 1, FontFace = FRED, TextScaled = true,
	Text = "LIKE + FAVORITE!", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = favCard,
}, { tstroke(2.5), new("UITextSizeConstraint", { MaxTextSize = 26 }) })
local favBlurb = new("TextLabel", {
	Position = UDim2.fromOffset(118, 50), Size = UDim2.new(1, -128, 0, 42), BackgroundTransparency = 1,
	FontFace = INCON, TextSize = 14, TextWrapped = true, TextColor3 = Color3.fromRGB(240, 232, 220),
	Text = "Like and favorite BECOME LA PEACE to get 10,000 PP!",
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5, Parent = favCard,
}, { tstroke(1.5) })
local favBtn = new("TextButton", {
	Position = UDim2.fromOffset(118, 94), Size = UDim2.fromOffset(160, 30), BackgroundColor3 = Color3.fromRGB(46, 190, 90),
	FontFace = FRED, TextSize = 17, TextColor3 = WHITE, Text = "FAVORITE  +10K PP", AutoButtonColor = false, ZIndex = 5, Parent = favCard,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 10) }),
	stroke(3.5),
	grad(Color3.fromRGB(20, 110, 50), Color3.fromRGB(130, 255, 140)),
	tstroke(2),
	new("UIScale", { Name = "Press", Scale = 1 }),
})
hover(favBtn, 1.06)
local favClose = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = Color3.fromRGB(235, 60, 60), FontFace = INCON_I, TextSize = 18,
	TextColor3 = WHITE, Text = "X", AutoButtonColor = false, ZIndex = 8, Parent = favCard,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(3.5), tstroke(2) })

local favUp = false
local function favHide()
	if not favUp then return end
	favUp = false
	gui:SetAttribute("FavUp", false)
	TweenService:Create(favScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Scale = 0.9 }):Play()
	local tw = TweenService:Create(favCard, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = HIDDEN, Rotation = -6 })
	tw:Play()
	tw.Completed:Once(function() if not favUp then favCard.Visible = false end end)
end
local function favShow(title, blurbText, btnText, hold)
	if currentPass then hide() end
	favTitle.Text = title
	favBlurb.Text = blurbText
	favBtn.Text = btnText or "FAVORITE  +10K PP"
	favBtn.Visible = btnText ~= false
	favUp = true
	gui:SetAttribute("FavUp", true)
	favCard.Position = HIDDEN
	favCard.Rotation = -8
	favScale.Scale = 0.85
	favCard.Visible = true
	TweenService:Create(favCard, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = SHOWN, Rotation = 0 }):Play()
	TweenService:Create(favScale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local my = favCard:GetAttribute("Show") or 0
	favCard:SetAttribute("Show", my + 1)
	task.delay(hold or 14, function()
		if favCard:GetAttribute("Show") == my + 1 then favHide() end
	end)
end
-- the star bobs while it's up
game:GetService("RunService").RenderStepped:Connect(function()
	if not favCard.Visible then return end
	local t = os.clock()
	favStar.Rotation = math.sin(t * 2.2) * 12
	favStar.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 2.8) * 3)
end)

local function isFavorited()
	local ok, fav = pcall(function()
		return AvatarEditorService:GetFavoriteAsync(game.PlaceId, Enum.AvatarItemType.Asset)
	end)
	return ok and fav == true
end
local function claimed() return player:GetAttribute("FavRewardClaimed") == true end
local function tryClaim()
	if claimed() or not favRemote then return end
	if isFavorited() then favRemote:FireServer("Claim") end
end

favBtn.MouseButton1Click:Connect(function()
	pcall(function() AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true) end)
end)
favClose.MouseButton1Click:Connect(favHide)
AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
	if result == Enum.AvatarPromptResult.Success then
		favHide()
		task.wait(1)
		tryClaim()
	end
end)
if favRemote then
	favRemote.OnClientEvent:Connect(function(kind, amount)
		if kind == "Granted" then
			favShow("THANK YOU!!", ("+%s PP for favoriting BECOME LA PEACE!"):format(Monetization.FormatNumber and Monetization.FormatNumber(amount) or "10,000"), false, 6)
		end
	end)
end

task.spawn(function()
	-- (wait for the server to say whether it's been claimed already)
	local t0 = os.clock()
	while player:GetAttribute("FavRewardClaimed") == nil and os.clock() - t0 < 30 do task.wait(0.5) end
	if claimed() then return end
	-- already a favorite (from before, or from the game page): just pay it out
	tryClaim()
	task.wait(FAV_FIRST)
	local shown = 0
	while not claimed() and shown < FAV_MAX do
		while busy() or currentPass do task.wait(3) end
		if claimed() then return end
		if isFavorited() then
			tryClaim()
		else
			shown += 1
			favShow("LIKE + FAVORITE!", "Like and favorite BECOME LA PEACE to get 10,000 PP!", "FAVORITE  +10K PP", 14)
		end
		-- (checks quietly in between, in case they favorite from the game page)
		local waited = 0
		while waited < FAV_EVERY and not claimed() do
			task.wait(30)
			waited += 30
			if not claimed() and isFavorited() then tryClaim() end
		end
	end
end)
