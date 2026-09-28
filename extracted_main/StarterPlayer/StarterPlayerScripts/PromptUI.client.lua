--==================================================
-- PROMPT UI  (client)
--
-- Every ProximityPrompt in the game drawn in the house style instead of
-- Roblox's default grey box: a dark violet pill with a gold edge, a gold key
-- badge, the action in FredokaOne and the object underneath.
--
--   * pops in / out with a little spring
--   * hold prompts fill a gold bar along the bottom of the pill
--   * a flash + bounce when it triggers
--   * keyboard shows the key, gamepad shows the button, touch shows TAP --
--     and the badge itself is tappable
--
-- Prompts are switched to Style = Custom locally, so nothing on the server
-- has to change and new prompts are picked up as they appear.
--==================================================

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local INK = Color3.fromRGB(16, 12, 30)
local TOP = Color3.fromRGB(74, 54, 136)
local BOTTOM = Color3.fromRGB(26, 18, 50)
local GOLD = Color3.fromRGB(255, 204, 84)
local WHITE = Color3.new(1, 1, 1)
local DIM = Color3.fromRGB(206, 198, 236)

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- take over every prompt, now and later
local function adopt(prompt)
	if prompt:IsA("ProximityPrompt") then
		prompt.Style = Enum.ProximityPromptStyle.Custom
	end
end
for _, d in ipairs(workspace:GetDescendants()) do adopt(d) end
workspace.DescendantAdded:Connect(adopt)

local holder = new("ScreenGui", { Name = "PromptUI", ResetOnSpawn = false, Parent = playerGui })

-- SELF-HEAL: cinematics (HideHud_* attributes) and the tutorial switch this gui
-- off while they play; if one of them never switched it back (interrupted,
-- errored, two of them overlapping) every prompt in the game vanished until you
-- rejoined. Now it follows what's actually wanted, every half second.
local function hudWanted()
	for k, v in pairs(player:GetAttributes()) do
		if v and (k:sub(1, 8) == "HideHud_" or k == "HideAura_Tutorial") then return false end
	end
	return true
end
task.spawn(function()
	while true do
		task.wait(0.5)
		if not holder.Parent or holder.Parent ~= playerGui then
			local ok = pcall(function() holder.Parent = playerGui end)
			if not ok then
				holder = new("ScreenGui", { Name = "PromptUI", ResetOnSpawn = false, Parent = playerGui })
			end
		end
		local want = hudWanted()
		if holder.Enabled ~= want then holder.Enabled = want end
	end
end)

local GAMEPAD_NAMES = {
	ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y",
	ButtonL1 = "LB", ButtonR1 = "RB", ButtonL2 = "LT", ButtonR2 = "RT",
	DPadUp = "↑", DPadDown = "↓", DPadLeft = "←", DPadRight = "→",
}

local KEY_NAMES = {
	Return = "⏎", Space = "SPACE", LeftShift = "SHIFT", RightShift = "SHIFT",
	LeftControl = "CTRL", RightControl = "CTRL", Tab = "TAB", Backspace = "⌫",
	One = "1", Two = "2", Three = "3", Four = "4", Five = "5",
	Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
}

local function keyLabel(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		local n = prompt.GamepadKeyCode.Name
		return GAMEPAD_NAMES[n] or n
	end
	local n = prompt.KeyboardKeyCode.Name
	return KEY_NAMES[n] or n
end

local function build(prompt, inputType)
	local actionText = prompt.ActionText ~= "" and prompt.ActionText or "Interact"
	local objectText = prompt.ObjectText
	local hasObject = objectText ~= ""

	-- The card grows with its text. It used to be a fixed 250px, so a long
	-- action/object line pushed the pill wider than the billboard and the
	-- left end -- the E key badge -- got clipped off ("E doesn't show").
	local TextService = game:GetService("TextService")
	local function textW(t, size)
		local ok, v = pcall(function() return TextService:GetTextSize(t, size, Enum.Font.FredokaOne, Vector2.new(4000, 200)) end)
		return ok and v.X or #t * size * 0.55
	end
	local labelW = math.max(44, 18 + #keyLabel(prompt, inputType) * 13)
	local contentW = math.max(textW(actionText, 24), hasObject and textW(objectText, 15) or 0)
	local cardW = math.max(250, math.ceil(8 + labelW + 12 + contentW + 18 + 24))

	local bb = new("BillboardGui", {
		Name = "Prompt",
		-- AlwaysOnTop billboards don't draw reliably here; instead the card is
		-- pulled a few studs toward the camera (StudsOffset Z is camera-space)
		-- so the NPC or prop it belongs to can't swallow it.
		AlwaysOnTop = false,
		Size = UDim2.fromOffset(cardW, hasObject and 74 or 60),
		ClipsDescendants = false,
		-- honour the prompt's UIOffset (pixels) so two prompts on one spot stack
		SizeOffset = Vector2.new(prompt.UIOffset.X / cardW, 0.5 - prompt.UIOffset.Y / (hasObject and 74 or 60)),
		StudsOffset = Vector3.new(0, 1.4, 3),
		LightInfluence = 0,
		ResetOnSpawn = false,
		Adornee = prompt.Parent,
		Parent = holder,
	})
	local scale = new("UIScale", { Scale = 0.5, Parent = bb })

	local pill = new("CanvasGroup", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 1, -8),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		GroupTransparency = 1,
		Parent = bb,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 16) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(TOP, BOTTOM) }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 18) }),
	})
	-- the stroke sits outside the CanvasGroup so it isn't clipped
	local edge = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 1, -8),
		BackgroundTransparency = 1,
		Parent = bb,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 16) }),
		new("UIStroke", { Color = GOLD, Thickness = 2.5, Transparency = 1 }),
	})
	local edgeStroke = edge:FindFirstChildOfClass("UIStroke")

	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = pill,
	})

	-- key badge
	local label = keyLabel(prompt, inputType)
	local badgeW = math.max(44, 18 + #label * 13)
	local badge = new("TextButton", {
		Name = "Key",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(badgeW, 44),
		BackgroundColor3 = GOLD,
		AutoButtonColor = false,
		FontFace = FONT,
		Text = label,
		TextSize = (#label > 2) and 18 or 26,
		TextColor3 = INK,
		Parent = pill,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 12) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(230, 205, 150)) }),
	})

	local texts = new("Frame", {
		Name = "Texts",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = pill,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local action = new("TextLabel", {
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = FONT,
		Text = actionText,
		TextSize = 24,
		TextColor3 = WHITE,
		Parent = texts,
	}, { new("UIStroke", { Thickness = 1.5, Color = INK }) })
	local object
	if hasObject then
		object = new("TextLabel", {
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			FontFace = FONT,
			Text = objectText,
			TextSize = 15,
			TextColor3 = DIM,
			Parent = texts,
		})
	end

	-- hold bar along the bottom
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -8, 1, 0),
		Size = UDim2.new(0, 0, 0, 5),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Visible = prompt.HoldDuration > 0,
		Parent = pill,
	}, { new("UIGradient", { Color = ColorSequence.new(GOLD, WHITE) }) })
	-- UIListLayout would place the bar; keep it out of the flow
	bar:SetAttribute("Ignore", true)
	bar.Parent = nil
	local barHolder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(0, 0, 0, 5),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = bb,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	bar.Position = UDim2.fromScale(0, 0)
	bar.AnchorPoint = Vector2.zero
	bar.Size = UDim2.fromScale(0, 1)
	bar.Parent = barHolder

	-- keep the edge + bar the same width as the pill
	local function syncWidth()
		local w = pill.AbsoluteSize.X / math.max(scale.Scale, 0.01)
		edge.Size = UDim2.new(0, w, 1, -8)
		barHolder.Size = UDim2.new(0, math.max(w - 28, 0), 0, 5)
	end
	pill:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncWidth)
	task.defer(syncWidth)

	-- tap / click the badge
	local holding = false
	badge.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = true
			prompt:InputHoldBegin()
		end
	end)
	badge.InputEnded:Connect(function(input)
		if holding and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
			holding = false
			prompt:InputHoldEnd()
		end
	end)

	-- appear
	tween(scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(pill, 0.18, { GroupTransparency = 0 })
	tween(edgeStroke, 0.18, { Transparency = 0 })

	local conns = {}
	local holdTween
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration <= 0 then return end
		bar.Size = UDim2.fromScale(0, 1)
		holdTween = tween(bar, prompt.HoldDuration, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
		tween(scale, 0.12, { Scale = 0.95 })
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then holdTween:Cancel() end
		tween(bar, 0.15, { Size = UDim2.fromScale(0, 1) })
		tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	end))
	table.insert(conns, prompt.Triggered:Connect(function()
		-- flash + bounce
		badge.BackgroundColor3 = WHITE
		tween(badge, 0.35, { BackgroundColor3 = GOLD })
		scale.Scale = 1.12
		tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		edgeStroke.Thickness = 5
		tween(edgeStroke, 0.35, { Thickness = 2.5 })
	end))
	-- text can change while shown (e.g. a quest step)
	table.insert(conns, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		action.Text = prompt.ActionText ~= "" and prompt.ActionText or "Interact"
	end))
	if object then
		table.insert(conns, prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
			object.Text = prompt.ObjectText
		end))
	end

	return function()
		for _, c in ipairs(conns) do c:Disconnect() end
		if holding then pcall(function() prompt:InputHoldEnd() end) end
		tween(scale, 0.16, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(pill, 0.16, { GroupTransparency = 1 })
		tween(edgeStroke, 0.16, { Transparency = 1 })
		task.delay(0.18, function() bb:Destroy() end)
	end
end

local active = {}

-- Your own overhead nameplate / title floats right between the camera and
-- whatever you're standing in front of, and it draws over the prompt -- after
-- a respawn the camera sits straight behind you, so every prompt looked like
-- it had vanished. While any prompt is up, your own tags step aside.
local hiddenOwnTags = {}
local function ownTagsHidden(hide)
	if hide then
		local ch = player.Character
		if not ch then return end
		for _, g in ipairs(workspace:GetDescendants()) do
			if g:IsA("BillboardGui") and g.Enabled and not hiddenOwnTags[g]
				and (g:IsDescendantOf(ch) or (g.Adornee and g.Adornee:IsDescendantOf(ch))) then
				hiddenOwnTags[g] = true
				g.Enabled = false
			end
		end
	else
		for g in pairs(hiddenOwnTags) do
			if g.Parent then g.Enabled = true end
		end
		table.clear(hiddenOwnTags)
	end
end
local function refreshOwnTags()
	ownTagsHidden(next(active) ~= nil or player:GetAttribute("InDialog") == true)
end
player:GetAttributeChangedSignal("InDialog"):Connect(function() refreshOwnTags() end)
player.CharacterAdded:Connect(function()
	-- tags from the old body are gone; start clean
	table.clear(hiddenOwnTags)
	task.defer(refreshOwnTags)
end)

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
	if active[prompt] then active[prompt]() end
	active[prompt] = build(prompt, inputType)
	refreshOwnTags()
	local conn
	conn = prompt.PromptHidden:Connect(function()
		conn:Disconnect()
		if active[prompt] then
			active[prompt]()
			active[prompt] = nil
			refreshOwnTags()
		end
	end)
end)
