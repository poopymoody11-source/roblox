--==================================================
-- BASE LABELS  (client)
--
-- A floating pin over every plot:
--
--   * yours      -> your avatar headshot in a gold ring, "YOUR BASE",
--                   and a big bouncing V arrow pointing down at the plot,
--                   plus a slow spinning ground ring
--   * someone's  -> their headshot in a green ring, their name, and a
--                   smaller green arrow
--   * empty      -> a small grey arrow and "EMPTY - walk in to claim"
--
-- No box/panel behind anything: the pieces float on their own.
-- Built client-side on purpose: "yours" is per-player.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 200, 70)
local GOLD_DEEP = Color3.fromRGB(214, 140, 20)
local GREEN = Color3.fromRGB(100, 232, 140)
local GREEN_DEEP = Color3.fromRGB(34, 150, 80)
local GREY = Color3.fromRGB(190, 194, 208)
local GREY_DEEP = Color3.fromRGB(110, 114, 130)
local DARK = Color3.fromRGB(16, 14, 26)
local WHITE = Color3.new(1, 1, 1)

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end

local function textStroke(thickness)
	return new("UIStroke", {
		Thickness = thickness, Color = DARK,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

local islands = workspace:WaitForChild("Islands")
local starter = islands:WaitForChild("StarterIsland")
local plotsFolder = starter:WaitForChild("IslandPlots")

local container = workspace:FindFirstChild("ClientAuras")
if not container then
	container = Instance.new("Folder")
	container.Name = "ClientAuras"
	container.Parent = workspace
end

local folder = new("Folder", { Name = "BaseLabels", Parent = container })

--==================================================
-- helpers
--==================================================

local function plotBounds(plot)
	local min, max
	for _, d in ipairs(plot:GetDescendants()) do
		if d:IsA("BasePart") then
			local p = d.Position
			min = min and Vector3.new(math.min(min.X, p.X), math.min(min.Y, p.Y), math.min(min.Z, p.Z)) or p
			max = max and Vector3.new(math.max(max.X, p.X), math.max(max.Y, p.Y), math.max(max.Z, p.Z)) or p
		end
	end
	if not min then return nil end
	return (min + max) / 2, max.Y
end

local function anchorPart(cframe, size, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Locked = true
	p.Material = Enum.Material.Neon
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

local headshots = {}
local function headshotFor(name)
	if headshots[name] then return headshots[name] end
	local target = Players:FindFirstChild(name)
	local userId = target and target.UserId
	if not userId then
		local ok, id = pcall(Players.GetUserIdFromNameAsync, Players, name)
		userId = ok and id or nil
	end
	if not userId then return "" end
	local ok, img = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	if ok and img then
		headshots[name] = img
		return img
	end
	return ""
end

-- One continuous V. Two capsules whose rounded ends share the SAME circle at
-- the tip, so they fuse into a single shape; a dark copy of that shape sits
-- behind as the outline and a thin light copy on top as the shine. (Per-bar
-- strokes drew a seam where the two halves crossed.)
local V_ANGLE = math.rad(40)
local V_LEN, V_THICK, V_OUTLINE = 0.66, 0.22, 0.07
local TIP = Vector2.new(0.5, 0.9)

local function vBar(holder, side, len, thick, colour, z, name)
	local capDist = len / 2 - thick / 2 -- centre -> cap-circle centre
	local centre = TIP - Vector2.new(side * capDist * math.cos(V_ANGLE), capDist * math.sin(V_ANGLE))
	return new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(centre.X, centre.Y),
		Size = UDim2.fromScale(len, thick),
		Rotation = side * math.deg(V_ANGLE),
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = holder,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

local function makeChevron(parent)
	local holder = new("Frame", {
		Name = "Chevron",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(0.8, 0.8),
		Parent = parent,
	}, { new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local bars = {}
	for _, side in ipairs({ -1, 1 }) do
		-- outline: same cap circle, just fatter
		vBar(holder, side, V_LEN + V_OUTLINE * 2, V_THICK + V_OUTLINE * 2, DARK, 2, "Outline")
		table.insert(bars, vBar(holder, side, V_LEN, V_THICK, GOLD, 3, "Fill"))
		local shine = vBar(holder, side, V_LEN - V_THICK * 0.9, V_THICK * 0.28, WHITE, 4, "Shine")
		-- nudge the shine to the upper edge of the fill
		shine.Position += UDim2.fromScale(side * 0.012, -0.045)
		shine.BackgroundTransparency = 0.45
	end
	return holder, bars
end

--==================================================
-- one pin
--==================================================

local labels = {}

local function buildLabel(plot, index)
	local centre, topY = plotBounds(plot)
	if not centre then return end

	local base = Vector3.new(centre.X, topY + 3, centre.Z)
	local anchor = anchorPart(CFrame.new(base), Vector3.one * 0.2, folder)
	anchor.Transparency = 1
	anchor.Name = plot.Name .. "_Label"

	-- Parented to the anchor part (a BillboardGui in a plain Folder doesn't
	-- render) and NOT AlwaysOnTop (those were skipped by the renderer here).
	local bb = new("BillboardGui", {
		Name = "Pin",
		Size = UDim2.new(9, 70, 14, 108),
		LightInfluence = 0,
		AlwaysOnTop = false,
		MaxDistance = 700,
		Parent = anchor,
	})

	local stack = new("Frame", {
		Name = "Stack",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = bb,
	})

	-- avatar headshot in a ring
	local ring = new("Frame", {
		Name = "Avatar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.0),
		Size = UDim2.fromScale(0.6, 0.6),
		BackgroundColor3 = GOLD,
		Parent = stack,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Thickness = 3, Color = DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		new("UIGradient", { Rotation = 45, Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 170, 170)) }),
	})
	local face = new("ImageLabel", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundColor3 = Color3.fromRGB(40, 36, 58),
		Image = "",
		Parent = ring,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	-- little crown badge, owner only
	local crown = new("TextLabel", {
		Name = "Crown",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.5, 0.26),
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextScaled = true,
		Text = "\u{1F451}",
		Visible = false,
		Parent = ring,
	})

	local title = new("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(1, 0.14),
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextScaled = true,
		TextColor3 = GOLD,
		Text = "YOUR BASE",
		Parent = stack,
	}, { textStroke(3), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(220, 220, 220)) }) })

	local sub = new("TextLabel", {
		Name = "Sub",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.605),
		Size = UDim2.fromScale(0.9, 0.08),
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "BASE " .. index,
		Parent = stack,
	}, { textStroke(2) })

	local chevron, bars = makeChevron(stack)

	-- ground ring for your own plot (built lazily)
	local beaconFolder = new("Folder", { Name = plot.Name .. "_Beacon", Parent = folder })

	local entry = {
		plot = plot, index = index, centre = centre, topY = topY,
		bb = bb, ring = ring, face = face, crown = crown, title = title, sub = sub,
		chevron = chevron, bars = bars, beaconFolder = beaconFolder,
		beacon = nil, mine = false, state = nil, owner = nil,
		phase = index * 0.7,
	}

	function entry.buildBeacon()
		if entry.beacon then return end
		local segs = {}
		local N, R = 28, 15
		for i = 1, N do
			local seg = anchorPart(CFrame.new(centre.X, topY + 0.6, centre.Z), Vector3.new(0.5, 0.35, (math.pi * 2 * R) / N * 0.55), beaconFolder)
			seg.Color = (i % 2 == 0) and WHITE or GOLD
			seg.Transparency = 0.1
			segs[i] = seg
		end
		entry.beacon = { segs = segs, R = R }
	end

	function entry.clearBeacon()
		if not entry.beacon then return end
		beaconFolder:ClearAllChildren()
		entry.beacon = nil
	end

	table.insert(labels, entry)
	return entry
end

--==================================================
-- owner state
--==================================================

local function paint(entry, main, deep)
	entry.ring.BackgroundColor3 = main
	entry.title.TextColor3 = main
	for _, bar in ipairs(entry.bars) do
		bar.BackgroundColor3 = main
	end
end

-- Size = studs (scales like a real object) + pixels (a floor, so the pin
-- never shrinks to an unreadable speck at the far side of the island)
local SIZES = {
	mine  = UDim2.new(9, 70, 14, 108),
	other = UDim2.new(6.5, 48, 10, 74),
	empty = UDim2.new(5.5, 40, 6.5, 48),
}

local function refresh(entry)
	local ownerValue = entry.plot:FindFirstChild("Owner")
	local name = ownerValue and ownerValue.Value or ""
	local mine = (name ~= "" and name == player.Name)
	local state = if name == "" then "empty" elseif mine then "mine" else "other"
	if state == entry.state and name == entry.owner then return end
	entry.state, entry.owner, entry.mine = state, name, mine

	if state == "empty" then
		entry.bb.Size = SIZES.empty
		entry.ring.Visible = false
		entry.crown.Visible = false
		entry.title.Position = UDim2.fromScale(0.5, 0.0)
		entry.title.Size = UDim2.fromScale(1, 0.26)
		entry.title.Text = "EMPTY"
		entry.sub.Position = UDim2.fromScale(0.5, 0.27)
		entry.sub.Size = UDim2.fromScale(1, 0.16)
		entry.sub.Text = "walk in to claim"
		entry.sub.TextColor3 = GREY
		entry.chevron.Size = UDim2.fromScale(0.62, 0.62)
		paint(entry, GREY, GREY_DEEP)
		entry.clearBeacon()
		return
	end

	entry.ring.Visible = true
	entry.face.Image = ""
	task.spawn(function()
		local img = headshotFor(name)
		if entry.owner == name then entry.face.Image = img end
	end)

	if state == "mine" then
		entry.bb.Size = SIZES.mine
		entry.crown.Visible = true
		entry.title.Text = "YOUR BASE"
		entry.title.Position = UDim2.fromScale(0.5, 0.47)
		entry.title.Size = UDim2.fromScale(1, 0.14)
		entry.sub.Text = "BASE " .. entry.index
		entry.sub.TextColor3 = WHITE
		entry.sub.Position = UDim2.fromScale(0.5, 0.605)
		entry.sub.Size = UDim2.fromScale(0.9, 0.08)
		entry.chevron.Size = UDim2.fromScale(0.8, 0.8)
		paint(entry, GOLD, GOLD_DEEP)
		entry.buildBeacon()
	else
		entry.bb.Size = SIZES.other
		entry.crown.Visible = false
		local target = Players:FindFirstChild(name)
		entry.title.Text = target and target.DisplayName or name
		entry.title.Position = UDim2.fromScale(0.5, 0.47)
		entry.title.Size = UDim2.fromScale(1, 0.13)
		entry.sub.Text = "BASE " .. entry.index
		entry.sub.TextColor3 = GREY
		entry.sub.Position = UDim2.fromScale(0.5, 0.6)
		entry.sub.Size = UDim2.fromScale(0.9, 0.08)
		entry.chevron.Size = UDim2.fromScale(0.7, 0.7)
		paint(entry, GREEN, GREEN_DEEP)
		entry.clearBeacon()
	end
end

--==================================================
-- build them all, sorted so BASE 1..8 is stable
--==================================================

local plots = plotsFolder:GetChildren()
table.sort(plots, function(a, b)
	local na = tonumber(a.Name:match("%d+") or 0) or 0
	local nb = tonumber(b.Name:match("%d+") or 0) or 0
	if na == nb then return a.Name < b.Name end
	return na < nb
end)

for i, plot in ipairs(plots) do
	local entry = buildLabel(plot, i)
	if entry then
		refresh(entry)
		local ownerValue = plot:FindFirstChild("Owner")
		if ownerValue then
			ownerValue.Changed:Connect(function() refresh(entry) end)
		end
	end
end

task.spawn(function()
	while true do
		task.wait(4)
		for _, entry in ipairs(labels) do refresh(entry) end
	end
end)

--==================================================
-- animation: bob, arrow bounce, spinning ground ring
--==================================================

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, entry in ipairs(labels) do
		local speed = entry.mine and 2.4 or 1.6
		local bob = math.sin(t * speed + entry.phase)
		entry.bb.StudsOffsetWorldSpace = Vector3.new(0, bob * (entry.mine and 0.9 or 0.5), 0)

		-- the arrow jabs downward
		local jab = math.max(0, math.sin(t * (entry.mine and 4.2 or 3) + entry.phase))
		entry.chevron.Position = UDim2.fromScale(0.5, 1 - 0.03 + jab * 0.03)
		local alpha = entry.mine and (0.08 * (1 - jab)) or 0.12
		for _, bar in ipairs(entry.bars) do
			bar.BackgroundTransparency = alpha
		end

		if entry.mine then
			entry.ring.Rotation = math.sin(t * 1.3) * 4
			if entry.beacon then
				local R, segs = entry.beacon.R, entry.beacon.segs
				local N = #segs
				for i, seg in ipairs(segs) do
					local a = (i / N) * math.pi * 2 + t * 0.6
					local pos = Vector3.new(entry.centre.X + math.cos(a) * R, entry.topY + 0.6, entry.centre.Z + math.sin(a) * R)
					seg.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
					seg.Transparency = 0.05 + 0.45 * (0.5 + 0.5 * math.sin(t * 3 - i * 0.45))
				end
			end
		end
	end
end)
