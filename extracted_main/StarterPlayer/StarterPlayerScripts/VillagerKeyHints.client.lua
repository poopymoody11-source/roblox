--==================================================
-- VILLAGER KEY HINTS  (client)
-- * once Mr Villager lets you in (and until you've been back
--   into the dungeon), the key gets a floating pin - the same
--   style as the SHOP / SELL / UPGRADES pins - and a glow
-- * trying the villager door without the key tells you
--   exactly where to get one (a card in the game's HUD style)
--==================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local DARK = Color3.fromRGB(16, 14, 26)
local WHITE = Color3.new(1, 1, 1)
local PIN_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local HUD_FONT = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)
local MAIN, DEEP = Color3.fromRGB(255, 205, 70), Color3.fromRGB(205, 120, 20)
local GREEN_A, GREEN_B = Color3.fromRGB(86, 170, 47), Color3.fromRGB(168, 223, 98)

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end

local function hasKey()
	local bp = player:FindFirstChildOfClass("Backpack")
	return (bp and bp:FindFirstChild("VillagerKey")) or (player.Character and player.Character:FindFirstChild("VillagerKey"))
end
local function stats() return player:FindFirstChild("PlayerStats") end
local function canGoIn()
	local s = stats()
	local v = s and s:FindFirstChild("cangoin")
	return v ~= nil and v.Value == true
end
local function claimed(id)
	local s = stats()
	local c = s and s:FindFirstChild("ClaimedQuests")
	return c ~= nil and c:FindFirstChild(id) ~= nil
end
-- the key only matters until you've been back into the dungeon
local function keyStillNeeded()
	return canGoIn() and not claimed("DungeonReturn")
end

--------------------------------------------------------------------
-- the card (same look as the rest of the HUD: grey-violet gradient
-- panel, chunky black outline, Inconsolata, a green pill title)
--------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "KeyHintToast", ResetOnSpawn = false, DisplayOrder = 60, IgnoreGuiInset = true, Parent = player:WaitForChild("PlayerGui") })
local current
local function toast(title, text)
	if current then current:Destroy() end
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.13), Size = UDim2.fromOffset(560, 112), BackgroundTransparency = 1, Parent = gui })
	local sc = new("UIScale", { Scale = 0, Parent = holder })
	local vp = workspace.CurrentCamera.ViewportSize
	local fit = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.55, 1.2)
	local panel = new("Frame", { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 1, -22), BackgroundColor3 = WHITE, Parent = holder }, {
		new("UICorner", { CornerRadius = UDim.new(0, 20) }),
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 5 }),
		new("UIGradient", { Rotation = -90, Color = ColorSequence.new(Color3.fromRGB(148, 142, 153), Color3.fromRGB(46, 20, 55)) }),
	})
	local pill = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(260, 44), BackgroundColor3 = WHITE, ZIndex = 3, Parent = holder }, {
		new("UICorner", { CornerRadius = UDim.new(0, 60) }),
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 5 }),
		new("UIGradient", { Rotation = -90, Color = ColorSequence.new(GREEN_A, GREEN_B) }),
	})
	new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.66), BackgroundTransparency = 1,
		FontFace = HUD_FONT, TextScaled = true, TextColor3 = WHITE, Text = "\u{1F511} " .. title, ZIndex = 4, Parent = pill }, { new("UIStroke", { Thickness = 3 }) })
	new("TextLabel", { Position = UDim2.new(0, 22, 0, 30), Size = UDim2.new(1, -44, 1, -40), BackgroundTransparency = 1, FontFace = HUD_FONT, TextScaled = true, TextWrapped = true,
		RichText = true, TextColor3 = WHITE, Text = text, ZIndex = 2, Parent = panel }, { new("UIStroke", { Thickness = 2 }) })
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = fit }):Play()
	current = holder
	task.delay(4.5, function()
		if current ~= holder then return end
		TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
		task.wait(0.25)
		holder:Destroy()
		if current == holder then current = nil end
	end)
end
local KEY = "<font color=\"#FFD24A\">VILLAGER KEY</font>"

--------------------------------------------------------------------
-- the pin over the key (SHOP / SELL style) + a glow
--------------------------------------------------------------------
local villager = workspace:WaitForChild("Villager", 30)
local keyTool = villager and villager:WaitForChild("VillagerKey", 30)
local keyPart = keyTool and keyTool:WaitForChild("MeshPart", 30)

local V_ANGLE = math.rad(40)
local V_LEN, V_THICK, V_OUTLINE = 0.66, 0.22, 0.07
local TIP = Vector2.new(0.5, 0.9)
local function vBar(holder, side, len, thick, colour, z)
	local capDist = len / 2 - thick / 2
	local centre = TIP - Vector2.new(side * capDist * math.cos(V_ANGLE), capDist * math.sin(V_ANGLE))
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(centre.X, centre.Y), Size = UDim2.fromScale(len, thick),
		Rotation = side * math.deg(V_ANGLE), BackgroundColor3 = colour, BorderSizePixel = 0, ZIndex = z, Parent = holder,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

local marker, pin
local function build()
	marker = new("Folder", { Name = "KeyMarker", Parent = gui })
	local hl = new("Highlight", { Adornee = keyTool, FillColor = MAIN, OutlineColor = WHITE, FillTransparency = 0.4, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = marker })
	TweenService:Create(hl, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.8 }):Play()
	local bb = new("BillboardGui", { Adornee = keyPart, Size = UDim2.new(4, 34, 6.4, 56), SizeOffset = Vector2.new(0, 0.5), StudsOffset = Vector3.new(0, 1.2, 0),
		LightInfluence = 0, AlwaysOnTop = true, MaxDistance = 300, Parent = marker })
	local stack = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = bb })
	local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.62, 0.62), BackgroundColor3 = MAIN, Parent = stack }, {
		new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Thickness = 3, Color = DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		new("UIGradient", { Rotation = 45, Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 170, 170)) }),
	})
	local inner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.84, 0.84), BackgroundColor3 = DEEP, Parent = ring }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(MAIN, DEEP) }),
	})
	local icon = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.7, 0.7),
		BackgroundTransparency = 1, FontFace = PIN_FONT, TextScaled = true, Text = "\u{1F511}", Parent = inner })
	new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.15),
		BackgroundTransparency = 1, FontFace = PIN_FONT, TextScaled = true, TextColor3 = WHITE, Text = "KEY", Parent = stack },
		{ new("UIStroke", { Thickness = 3.5, Color = DEEP, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }) })
	new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.65), Size = UDim2.fromScale(1, 0.085),
		BackgroundTransparency = 1, FontFace = PIN_FONT, TextScaled = true, TextColor3 = WHITE, Text = "opens the villager door", Parent = stack },
		{ new("UIStroke", { Thickness = 2, Color = DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }) })
	local chev = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.62, 0.62), Parent = stack },
		{ new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local bars = {}
	for _, side in ipairs({ -1, 1 }) do
		vBar(chev, side, V_LEN + V_OUTLINE * 2, V_THICK + V_OUTLINE * 2, DARK, 2)
		table.insert(bars, vBar(chev, side, V_LEN, V_THICK, MAIN, 3))
	end
	pin = { bb = bb, ring = ring, icon = icon, chev = chev }
end
local function setMarker(on)
	if on and not marker and keyPart then build()
	elseif not on and marker then marker:Destroy() marker = nil pin = nil end
end
RunService.RenderStepped:Connect(function()
	if not pin then return end
	local t = os.clock()
	pin.bb.StudsOffsetWorldSpace = Vector3.new(0, math.sin(t * 2) * 0.3, 0)
	pin.chev.Position = UDim2.fromScale(0.5, 0.97 + math.max(0, math.sin(t * 3.4)) * 0.03)
	pin.ring.Rotation = math.sin(t * 1.5) * 5
	pin.icon.Rotation = math.sin(t * 2.2) * 10
end)

local function refresh()
	setMarker(keyStillNeeded() and not hasKey())
end

task.spawn(function()
	local s = player:WaitForChild("PlayerStats", 60)
	if not s then return end
	local function hookCanGo(v)
		local was = v.Value == true
		v.Changed:Connect(function()
			refresh()
			if v.Value == true and not was and not hasKey() then
				toast("VILLAGER KEY", "Mr Villager will let you in! Grab the glowing " .. KEY .. " right next to him.")
			end
			was = v.Value == true
		end)
	end
	local cg = s:FindFirstChild("cangoin")
	if cg then hookCanGo(cg) end
	s.ChildAdded:Connect(function(c) if c.Name == "cangoin" then hookCanGo(c) end refresh() end)
	local function watchClaims(f)
		f.ChildAdded:Connect(refresh)
		f.ChildRemoved:Connect(refresh)
	end
	local cq = s:FindFirstChild("ClaimedQuests")
	if cq then watchClaims(cq) end
	s.ChildAdded:Connect(function(c) if c.Name == "ClaimedQuests" then watchClaims(c) end end)
	refresh()
end)
local function watchBackpack()
	local bp = player:WaitForChild("Backpack")
	bp.ChildAdded:Connect(refresh)
	bp.ChildRemoved:Connect(function() task.defer(refresh) end)
end
player.CharacterAdded:Connect(function(ch)
	task.spawn(watchBackpack)
	ch.ChildAdded:Connect(refresh)
	task.delay(1, refresh)
end)
if player.Character then task.spawn(watchBackpack) end

task.spawn(function()
	local dungeon = workspace:WaitForChild("Dungeon", 60)
	local doorPart = dungeon and dungeon:WaitForChild("GoInDoor", 60)
	local prompt = doorPart and doorPart:WaitForChild("Open Door", 60)
	if not prompt then return end
	prompt.Triggered:Connect(function()
		if hasKey() then return end
		refresh()
		if canGoIn() then
			toast("KEY NEEDED", "This door needs the " .. KEY .. "! Grab it next to Mr Villager at his house.")
		else
			toast("LOCKED", "Do Mr Villager's quest to earn his " .. KEY .. ".")
		end
	end)
end)
