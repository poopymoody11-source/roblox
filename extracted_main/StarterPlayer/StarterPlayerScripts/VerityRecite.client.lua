--==================================================
-- VERITY'S RECITAL  (client)
--
-- Verity hands you a piece of paper. Equip it (or talk to
-- her again) and this prompt opens: the lines on the paper,
-- one highlighted at a time, and a box to recite each one.
-- Get them all right and the server completes VerityQuest2
-- and the Cruelty portal rises out of the ground.
--
-- Also owns the portal's visibility: it stays buried until
-- VerityQuest2 is done, and is raised straight away on join
-- for anyone who already did it (it used to stay underground
-- after a rejoin).
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local VerityWords = require(ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("VerityWords"))
local claimRemote = ReplicatedStorage:WaitForChild("ClaimQuestReward")

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end
local function stroke(th, color)
	return new("UIStroke", { Thickness = th, Color = color or Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function textStroke(th)
	return new("UIStroke", { Thickness = th or 2, Color = Color3.new(0, 0, 0) })
end

local okSound = new("Sound", { SoundId = "rbxassetid://10066947742", Volume = 0.15, Parent = SoundService })
local badSound = new("Sound", { SoundId = "rbxassetid://132281440773764", Volume = 0.1, Parent = SoundService })

--==================================================
-- UI  (same look as the rest of the menus: FredokaOne,
-- thick black outlines, rounded panels, green buttons)
--==================================================

local PAPER = Color3.fromRGB(240, 226, 188)
local INK = Color3.fromRGB(70, 48, 28)
local GOLD = Color3.fromRGB(255, 214, 70)
local GREEN = Color3.fromRGB(39, 229, 1)

local gui = new("ScreenGui", { Name = "VerityRecite", ResetOnSpawn = false, DisplayOrder = 30, Enabled = false, IgnoreGuiInset = true, Parent = playerGui })
local openEvent = new("BindableEvent", { Name = "Open", Parent = gui })

local dim = new("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Parent = gui })

local card = new("Frame", {
	Name = "Card",
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.42, 0.56),
	BackgroundColor3 = PAPER, Parent = gui,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 16) }),
	stroke(5),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 195, 150)) }),
	new("UISizeConstraint", { MinSize = Vector2.new(330, 300), MaxSize = Vector2.new(560, 440) }),
})

-- banner on top, like the other menus' title tabs
local banner = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.6, 0, 0, 48),
	BackgroundColor3 = GOLD, Parent = card,
}, { new("UICorner", { CornerRadius = UDim.new(0, 12) }), stroke(5) })
new("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "VERITY'S WORDS", Font = Enum.Font.FredokaOne,
	TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Parent = banner,
}, { textStroke(3), new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })

-- close X (red, like the menus' close button)
local closeBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = Color3.fromRGB(220, 40, 40), Text = "X", Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), Parent = card,
}, { new("UICorner", { CornerRadius = UDim.new(0, 10) }), stroke(4), textStroke(2) })

local hint = new("TextLabel", {
	Position = UDim2.new(0, 20, 0, 34), Size = UDim2.new(1, -40, 0, 22), BackgroundTransparency = 1,
	Text = "Recite each line out loud, one at a time", Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = INK, TextTransparency = 0.25, Parent = card,
})

local linesFrame = new("Frame", {
	Position = UDim2.new(0, 20, 0, 62), Size = UDim2.new(1, -40, 1, -170), BackgroundTransparency = 1, Parent = card,
}, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }) })

local lineLabels = {}
for i, line in ipairs(VerityWords.Lines) do
	lineLabels[i] = new("TextLabel", {
		Name = "Line" .. i, LayoutOrder = i, Size = UDim2.new(1, 0, 1 / #VerityWords.Lines, -4), BackgroundTransparency = 1,
		Text = line, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = INK, Parent = linesFrame,
	}, { new("UITextSizeConstraint", { MaxTextSize = 30 }) })
end

local box = new("TextBox", {
	Name = "ReciteBox",
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -62), Size = UDim2.new(1, -40, 0, 42),
	BackgroundColor3 = Color3.fromRGB(40, 32, 50), Text = "", PlaceholderText = "Type the highlighted line...",
	PlaceholderColor3 = Color3.fromRGB(170, 160, 190), Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), ClearTextOnFocus = false, Parent = card,
}, { new("UICorner", { CornerRadius = UDim.new(0, 10) }), stroke(4), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })

local reciteBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(0.42, 0, 0, 42),
	BackgroundColor3 = GREEN, Text = "RECITE", Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), Parent = card,
}, { new("UICorner", { CornerRadius = UDim.new(0, 10) }), stroke(3, Color3.new(1, 1, 1)), textStroke(2), new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }) })

local feedback = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 10), Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1, Text = "", Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.fromRGB(255, 90, 90), Parent = card,
}, { textStroke(2) })

--==================================================
-- LOGIC
--==================================================

local current = 1
local busy = false

local function stats() return player:FindFirstChild("PlayerStats") end
local function claimed(name)
	local s = stats()
	local c = s and s:FindFirstChild("ClaimedQuests")
	return c ~= nil and c:FindFirstChild(name) ~= nil
end
local function owesRecital() return claimed("VerityQuest") and not claimed("VerityQuest2") end

local function paint()
	for i, lbl in ipairs(lineLabels) do
		local line = VerityWords.Lines[i]
		if i < current then
			lbl.Text = "✓ " .. line
			lbl.TextColor3 = Color3.fromRGB(40, 140, 40)
			lbl.TextTransparency = 0
		elseif i == current then
			lbl.Text = "▶ " .. line .. " ◀"
			lbl.TextColor3 = Color3.fromRGB(150, 70, 200)
			lbl.TextTransparency = 0
		else
			lbl.Text = line
			lbl.TextColor3 = INK
			lbl.TextTransparency = 0.55
		end
	end
end

local function say(text, good)
	feedback.Text = text
	feedback.TextColor3 = good and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 90, 90)
end

local function open()
	if not owesRecital() or busy then return end
	current = 1
	box.Text = ""
	say("")
	paint()
	gui.Enabled = true
	card.Size = UDim2.fromScale(0.36, 0.48)
	TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.42, 0.56) }):Play()
	task.defer(function() box:CaptureFocus() end)
end

local function close()
	gui.Enabled = false
	box:ReleaseFocus()
end

local function shake()
	local base = UDim2.fromScale(0.5, 0.52)
	for _, dx in ipairs({ -10, 10, -7, 7, -3, 0 }) do
		card.Position = base + UDim2.fromOffset(dx, 0)
		task.wait(0.03)
	end
	card.Position = base
end

local function submit()
	if busy or not gui.Enabled then return end
	if VerityWords.Matches(box.Text, current) then
		SoundService:PlayLocalSound(okSound)
		current += 1
		box.Text = ""
		paint()
		if current > #VerityWords.Lines then
			busy = true
			say("The words are spoken... the way is open!", true)
			claimRemote:FireServer("VerityQuest2", VerityWords.Full())
			TweenService:Create(card, TweenInfo.new(0.4), { BackgroundColor3 = GOLD }):Play()
			task.wait(1.6)
			card.BackgroundColor3 = PAPER
			close()
			busy = false
		else
			say("Good. Next line...", true)
			box:CaptureFocus()
		end
	else
		SoundService:PlayLocalSound(badSound)
		say("That's not what the paper says!", false)
		task.spawn(shake)
		box:CaptureFocus()
	end
end

reciteBtn.MouseButton1Click:Connect(submit)
box.FocusLost:Connect(function(enter) if enter then submit() end end)
closeBtn.MouseButton1Click:Connect(close)
openEvent.Event:Connect(open)

-- equipping the paper opens the prompt
local function watchCharacter(char)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") and c.Name == "VerityPaper" then open() end
	end)
end
if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(watchCharacter)

--==================================================
-- THE CRUELTY PORTAL
--==================================================

local RISE = 10
local portalRaised = false

-- its swirl particles poke up through the ground while it's buried
-- (and gave the secret away), so they stay off until it rises
local function setPortalFx(on)
	local folder = workspace:FindFirstChild("VerityQuest")
	local portal = folder and folder:FindFirstChild("CrueltyPortal")
	if not portal then return end
	for _, d in ipairs(portal:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Light") then d.Enabled = on end
	end
	-- The CHALLENGE prompt is on the portal itself. Prompt visibility is a
	-- client-side property, so turning it off here hides it for THIS player
	-- only -- exactly what's wanted, since whether you've recited is personal.
	local prompt = portal:FindFirstChildOfClass("ProximityPrompt")
	if prompt then prompt.Enabled = on end
end

local function raisePortal(animated)
	if portalRaised then return end
	local folder = workspace:FindFirstChild("VerityQuest")
	local portal = folder and folder:FindFirstChild("CrueltyPortal")
	if not portal then return end
	portalRaised = true
	setPortalFx(true)
	local goal = portal.CFrame * CFrame.new(0, RISE, 0)
	if not animated then
		portal.CFrame = goal
		return
	end
	-- rumble up out of the ground with a flash
	local flash = new("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon, Color = Color3.fromRGB(170, 60, 255), Transparency = 0.2,
		Size = Vector3.one * 2, CFrame = goal, Parent = workspace,
	})
	TweenService:Create(flash, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 26, Transparency = 1 }):Play()
	task.delay(1.3, function() flash:Destroy() end)
	TweenService:Create(portal, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal }):Play()
end

task.spawn(function()
	local s = player:WaitForChild("PlayerStats", 30)
	local c = s and s:WaitForChild("ClaimedQuests", 30)
	if not c then return end
	if c:FindFirstChild("VerityQuest2") then
		raisePortal(false)
	else
		setPortalFx(false)
	end
	c.ChildAdded:Connect(function(v)
		if v.Name == "VerityQuest2" then raisePortal(true) end
	end)
end)
