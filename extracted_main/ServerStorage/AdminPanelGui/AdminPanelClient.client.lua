--==================================================
-- ADMIN PANEL  (client)   -- /cmds to open
-- Only cloned into the admins' PlayerGui (MrMajou, ncncncbnc) by AdminPanelService.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = script.Parent
local remote = ReplicatedStorage:WaitForChild("AdminPanelRemote")
local openEvent = ReplicatedStorage:WaitForChild("AdminPanelOpen")

local C = {
	bg = Color3.fromRGB(22, 22, 30), panel = Color3.fromRGB(32, 32, 44),
	btn = Color3.fromRGB(52, 52, 72), btnHover = Color3.fromRGB(72, 72, 100),
	accent = Color3.fromRGB(120, 90, 255), danger = Color3.fromRGB(200, 60, 70),
	good = Color3.fromRGB(80, 200, 120), text = Color3.new(1, 1, 1), dim = Color3.fromRGB(170, 170, 190),
}

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }) end
local function stroke(c, t) return new("UIStroke", { Color = c or Color3.fromRGB(80, 80, 110), Thickness = t or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end

--------------------------------------------------
-- frame
--------------------------------------------------
local main = new("Frame", {
	Name = "Main", Parent = gui, Size = UDim2.fromOffset(600, 460), Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.bg, Visible = false, Active = true,
}, { corner(12), stroke(C.accent, 2) })
new("UISizeConstraint", { Parent = main, MaxSize = Vector2.new(600, 460) })

local top = new("Frame", { Parent = main, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.panel }, { corner(12) })
new("TextLabel", {
	Parent = top, Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1,
	Text = "⚙ ADMIN PANEL", Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
})
local close = new("TextButton", {
	Parent = top, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -36, 0, 5), BackgroundColor3 = C.danger,
	Text = "X", Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = C.text,
}, { corner(8) })

-- dragging
do
	local dragging, startPos, startMouse
	top.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, startPos, startMouse = true, main.Position, i.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startMouse
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

--------------------------------------------------
-- controls row: target + amount
--------------------------------------------------
local controls = new("Frame", { Parent = main, Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 48), BackgroundTransparency = 1 })
new("TextLabel", { Parent = controls, Size = UDim2.fromOffset(60, 36), BackgroundTransparency = 1, Text = "Target", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.dim })
local targetBtn = new("TextButton", {
	Parent = controls, Size = UDim2.fromOffset(210, 36), Position = UDim2.fromOffset(62, 0), BackgroundColor3 = C.btn,
	Text = player.Name .. "  (change)", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.text,
}, { corner(8), stroke() })
new("TextLabel", { Parent = controls, Size = UDim2.fromOffset(70, 36), Position = UDim2.fromOffset(284, 0), BackgroundTransparency = 1, Text = "Amount", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.dim })
local amountBox = new("TextBox", {
	Parent = controls, Size = UDim2.new(1, -358, 0, 36), Position = UDim2.fromOffset(358, 0), BackgroundColor3 = C.panel,
	Text = "", PlaceholderText = "e.g. 1000000", Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = C.text,
	PlaceholderColor3 = C.dim, ClearTextOnFocus = false,
}, { corner(8), stroke() })

local targetName = player.Name

--------------------------------------------------
-- body
--------------------------------------------------
local body = new("ScrollingFrame", {
	Parent = main, Size = UDim2.new(1, -24, 1, -134), Position = UDim2.fromOffset(12, 92), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarImageColor3 = C.accent,
}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local status = new("TextLabel", {
	Parent = main, Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 1, -38), BackgroundColor3 = C.panel,
	Text = "Ready.", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, { corner(8), new("UIPadding", { PaddingLeft = UDim.new(0, 10) }) })

local function setStatus(ok, msg)
	status.Text = (ok and "✅ " or "❌ ") .. tostring(msg):gsub("\n", "  ")
	status.TextColor3 = ok and C.good or C.danger
end

--------------------------------------------------
-- picker popup (lists of lapis / passes / titles / players)
--------------------------------------------------
local picker = new("Frame", {
	Parent = main, Size = UDim2.fromOffset(260, 300), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = C.panel, Visible = false, ZIndex = 20, Active = true,
}, { corner(10), stroke(C.accent, 2) })
local pickerTitle = new("TextLabel", { Parent = picker, Size = UDim2.new(1, -40, 0, 32), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 })
local pickerClose = new("TextButton", { Parent = picker, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -32, 0, 4), BackgroundColor3 = C.danger, Text = "X", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = C.text, ZIndex = 21 }, { corner(6) })
local pickerList = new("ScrollingFrame", {
	Parent = picker, Size = UDim2.new(1, -16, 1, -42), Position = UDim2.fromOffset(8, 36), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 21,
}, { new("UIListLayout", { Padding = UDim.new(0, 4) }) })
pickerClose.MouseButton1Click:Connect(function() picker.Visible = false end)

local function pick(title, options, callback)
	pickerTitle.Text = title
	for _, c in ipairs(pickerList:GetChildren()) do if c:IsA("GuiButton") then c:Destroy() end end
	for _, opt in ipairs(options) do
		local b = new("TextButton", {
			Parent = pickerList, Size = UDim2.new(1, -8, 0, 28), BackgroundColor3 = C.btn, Text = opt,
			Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text, ZIndex = 22,
		}, { corner(6) })
		b.MouseButton1Click:Connect(function()
			picker.Visible = false
			callback(opt)
		end)
	end
	picker.Visible = true
end

targetBtn.MouseButton1Click:Connect(function()
	local names = {}
	for _, p in ipairs(Players:GetPlayers()) do table.insert(names, p.Name) end
	pick("Choose target", names, function(n)
		targetName = n
		targetBtn.Text = n .. "  (change)"
	end)
end)

--------------------------------------------------
-- actions
--------------------------------------------------
local meta = { Lapis = {}, Passes = {}, Titles = {} }
task.spawn(function()
	local ok, m = remote:InvokeServer("Meta")
	if ok and type(m) == "table" then meta = m end
end)

local busy = false
local function run(action, id)
	if busy then return end
	busy = true
	status.Text = "…" status.TextColor3 = C.dim
	local ok, a, b = pcall(function() return remote:InvokeServer(action, targetName, amountBox.Text, id) end)
	busy = false
	if not ok then setStatus(false, a) else setStatus(a, b) end
end

local confirmArmed = {}
local order = 0
local function section(title, buttons)
	order += 1
	local sec = new("Frame", { Parent = body, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panel, LayoutOrder = order }, {
		corner(10), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }),
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	new("TextLabel", { Parent = sec, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = title, Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0 })
	local grid = new("Frame", { Parent = sec, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1 }, {
		new("UIGridLayout", { CellSize = UDim2.new(0.333, -6, 0, 34), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, def in ipairs(buttons) do
		local color = def.Danger and C.danger or C.btn
		local b = new("TextButton", {
			Parent = grid, BackgroundColor3 = color, Text = def.Label, Font = Enum.Font.GothamBold, TextSize = 13,
			TextColor3 = C.text, TextWrapped = true, AutoButtonColor = true, LayoutOrder = i,
		}, { corner(8) })
		b.MouseButton1Click:Connect(function()
			if def.Danger and not confirmArmed[b] then
				confirmArmed[b] = true
				b.Text = "Click again to confirm"
				task.delay(2.5, function() confirmArmed[b] = nil if b.Parent then b.Text = def.Label end end)
				return
			end
			confirmArmed[b] = nil
			b.Text = def.Label
			if def.Pick then
				pick(def.Label, meta[def.Pick] or {}, function(id) run(def.Action, id) end)
			else
				run(def.Action)
			end
		end)
	end
end

section("💰 Peace Points", {
	{ Label = "Add PP (amount)", Action = "AddPP" },
	{ Label = "Set PP (amount)", Action = "SetPP" },
	{ Label = "+1 Trillion PP", Action = "MaxPP" },
})
section("⬆ Ascension", {
	{ Label = "Ascend", Action = "Ascend" },
	{ Label = "Set Ascensions (amount)", Action = "SetAscension" },
	{ Label = "Give EVERYTHING", Action = "GiveEverything" },
	{ Label = "⭐ GIVE ME ALL ITEMS (full save)", Action = "GiveEverythingPlus" },
})
section("💎 Lapis", {
	{ Label = "Give Lapis… (amount)", Action = "GiveLapis", Pick = "Lapis" },
})
section("📜 Quests", {
	{ Label = "Give All Quests", Action = "GiveAllQuests" },
	{ Label = "Reset Quests", Action = "ResetQuests", Danger = true },
})
section("🎟 Gamepasses", {
	{ Label = "Refresh / List Passes", Action = "RefreshPasses" },
	{ Label = "Give Pass…", Action = "GivePass", Pick = "Passes" },
	{ Label = "Reset Passes", Action = "ResetPasses", Danger = true },
})
section("🏷 Titles", {
	{ Label = "Give Title…", Action = "GiveTitle", Pick = "Titles" },
	{ Label = "Reset Titles", Action = "ResetTitles", Danger = true },
})
section("🏠 Base Upgrades", {
	{ Label = "Reset Upgrades", Action = "ResetUpgrades", Danger = true },
})
section("🧍 Player", {
	{ Label = "Heal", Action = "Heal" },
	{ Label = "Bring To Me", Action = "BringHere" },
	{ Label = "Go To Them", Action = "GoTo" },
})
section("⚠ Danger", {
	{ Label = "WIPE DATA", Action = "WipeData", Danger = true },
})

--------------------------------------------------
-- open / close
--------------------------------------------------
local function setOpen(open)
	if open == main.Visible then return end
	-- tells the server, which flags it for everyone else so the floating
	-- ADMINISTRATOR console appears in front of this player
	task.spawn(function()
		pcall(function() remote:InvokeServer("SetPanelOpen", open) end)
	end)
	if open then
		main.Visible = true
		main.Size = UDim2.fromOffset(540, 414)
		TweenService:Create(main, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(600, 460) }):Play()
	else
		main.Visible = false
		picker.Visible = false
	end
end
close.MouseButton1Click:Connect(function() setOpen(false) end)
openEvent.OnClientEvent:Connect(function() setOpen(true) end)

task.spawn(function()
	local cmd = TextChatService:WaitForChild("AdminCmdsCommand", 30)
	if cmd then
		cmd.Triggered:Connect(function(source)
			if source and source.UserId == player.UserId then setOpen(true) end
		end)
	end
end)

--------------------------------------------------
-- topbar button (next to the chat button) so you don't have to type /cmds
--------------------------------------------------
do
	local topGui = Instance.new("ScreenGui")
	topGui.Name = "AdminTopbarButton"
	topGui.IgnoreGuiInset = true
	topGui.ResetOnSpawn = false
	topGui.DisplayOrder = 90
	topGui.Parent = player:WaitForChild("PlayerGui")
	local b = Instance.new("TextButton")
	b.Name = "AdminButton"
	b.AnchorPoint = Vector2.new(0, 0)
	b.Position = UDim2.fromOffset(176, 12)
	b.Size = UDim2.fromOffset(44, 44)
	b.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	b.BackgroundTransparency = 0.3
	b.Text = "⚙"
	b.TextSize = 22
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.fromRGB(200, 170, 255)
	b.Parent = topGui
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke", b)
	st.Color = C.accent
	st.Thickness = 1.5

	-- Sit right after Roblox's own topbar buttons (menu, chat, ...).
	-- TopbarInset is the free strip to the right of them, so this
	-- lands next to the chat button on every device and never covers it.
	local GuiService = game:GetService("GuiService")
	local function place()
		local inset = GuiService.TopbarInset
		local h = inset.Height > 0 and inset.Height or 58
		local size = math.clamp(h - 14, 32, 44)
		b.Size = UDim2.fromOffset(size, size)
		-- (one slot further right: the ★ titles button sits next to chat now)
		b.Position = UDim2.fromOffset((inset.Min.X > 0 and inset.Min.X or 164) + 4 + size + 8, math.floor((h - size) / 2))
	end
	place()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)

	local tip = Instance.new("TextLabel")
	tip.BackgroundTransparency = 1
	tip.Position = UDim2.new(0.5, 0, 1, 2)
	tip.AnchorPoint = Vector2.new(0.5, 0)
	tip.Size = UDim2.fromOffset(90, 16)
	tip.Font = Enum.Font.GothamBold
	tip.TextSize = 12
	tip.TextColor3 = Color3.new(1, 1, 1)
	tip.TextStrokeTransparency = 0.4
	tip.Text = "ADMIN"
	tip.Visible = false
	tip.Parent = b
	b.MouseEnter:Connect(function() tip.Visible = true end)
	b.MouseLeave:Connect(function() tip.Visible = false end)
	b.MouseButton1Click:Connect(function()
		setOpen(not main.Visible)
	end)
end
