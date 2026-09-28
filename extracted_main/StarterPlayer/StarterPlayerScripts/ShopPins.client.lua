--==================================================
-- SHOP PINS  (client)
-- Floating pins over the Staff Shop and the Sell Stand, in the same style
-- as the base pins: an icon in a ring, a title, and a bouncing V arrow.
--==================================================

local RunService = game:GetService("RunService")

local DARK = Color3.fromRGB(16, 14, 26)
local WHITE = Color3.new(1, 1, 1)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)

local PINS = {
	{ model = "shop", title = "SHOP", sub = "staffs & gear", icon = "\u{1F6D2}", main = Color3.fromRGB(90, 190, 255), deep = Color3.fromRGB(30, 110, 210) },
	{ model = "sell", title = "SELL", sub = "lapis \u{2192} PP", icon = "\u{1F4B0}", main = Color3.fromRGB(110, 235, 130), deep = Color3.fromRGB(30, 150, 70) },
	{ model = "BaseUpgradeDialog", child = "Meshy_AI_The_Wandering_Sage_0824055920_texture", title = "UPGRADES", sub = "boost your base", icon = "\u{2B06}\u{FE0F}", main = Color3.fromRGB(255, 200, 70), deep = Color3.fromRGB(200, 110, 20) },
}

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end
local function textStroke(t)
	return new("UIStroke", { Thickness = t, Color = DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

local container = workspace:FindFirstChild("ClientAuras") or new("Folder", { Name = "ClientAuras", Parent = workspace })
local folder = new("Folder", { Name = "ShopPins", Parent = container })

-- one continuous V (two capsules sharing the tip circle), same as the base pins
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
local function makeChevron(parent, colour)
	local holder = new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.62, 0.62), Parent = parent,
	}, { new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local bars = {}
	for _, side in ipairs({ -1, 1 }) do
		vBar(holder, side, V_LEN + V_OUTLINE * 2, V_THICK + V_OUTLINE * 2, DARK, 2)
		table.insert(bars, vBar(holder, side, V_LEN, V_THICK, colour, 3))
		local shine = vBar(holder, side, V_LEN - V_THICK * 0.9, V_THICK * 0.28, WHITE, 4)
		shine.Position += UDim2.fromScale(side * 0.012, -0.045)
		shine.BackgroundTransparency = 0.45
	end
	return holder, bars
end

local entries = {}

local function build(spec, model, index)
	local cf, size = model:GetBoundingBox()
	local top = cf.Position + Vector3.new(0, size.Y / 2 + 6, 0)
	local anchor = new("Part", {
		Name = spec.title .. "_Pin", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(top), Parent = folder,
	})
	local bb = new("BillboardGui", {
		Size = UDim2.new(5, 44, 8, 70), SizeOffset = Vector2.new(0, 0.5), LightInfluence = 0, AlwaysOnTop = true, MaxDistance = 400, Parent = anchor,
	})
	local stack = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = bb })
	local ring = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.62, 0.62), BackgroundColor3 = spec.main, Parent = stack,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Thickness = 3, Color = DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		new("UIGradient", { Rotation = 45, Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 170, 170)) }),
	})
	local inner = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.84, 0.84), BackgroundColor3 = spec.deep, Parent = ring,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(spec.main, spec.deep) }),
	})
	local icon = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.7, 0.7),
		BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, Text = spec.icon, Parent = inner,
	})
	new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.17),
		BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, TextColor3 = WHITE, Text = spec.title, Parent = stack,
	}, { new("UIStroke", { Thickness = 3.5, Color = spec.deep, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }) })
	new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.665), Size = UDim2.fromScale(1, 0.085),
		BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, TextColor3 = WHITE, Text = spec.sub, Parent = stack,
	}, { textStroke(2) })
	local chevron, bars = makeChevron(stack, spec.main)
	table.insert(entries, { bb = bb, ring = ring, icon = icon, chevron = chevron, bars = bars, phase = index * 1.3 })
end

for i, spec in ipairs(PINS) do
	task.spawn(function()
		local model = workspace:WaitForChild(spec.model, 30)
		if model and spec.child then model = model:WaitForChild(spec.child, 30) end
		if model then build(spec, model, i) end
	end)
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, e in ipairs(entries) do
		e.bb.StudsOffsetWorldSpace = Vector3.new(0, math.sin(t * 2 + e.phase) * 0.35, 0)
		local jab = math.max(0, math.sin(t * 3.4 + e.phase))
		e.chevron.Position = UDim2.fromScale(0.5, 0.97 + jab * 0.03)
		for _, bar in ipairs(e.bars) do bar.BackgroundTransparency = 0.1 * (1 - jab) end
		e.ring.Rotation = math.sin(t * 1.5 + e.phase) * 5
		e.icon.Rotation = math.sin(t * 2.2 + e.phase) * 8
	end
end)
