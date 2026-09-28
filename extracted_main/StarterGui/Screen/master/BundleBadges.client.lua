--==================================================
-- BUNDLE BADGES  (client)
--
-- Bought the Verity / La Peace bundle? The matching staff
-- card in the staff shop gets a gold "UPGRADED" badge
-- (and a coloured border). Reads the Pass_<Key>
-- attribute MonetizationService sets, so it updates the
-- moment a purchase lands.
--==================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local master = script.Parent

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)

local BUNDLES = {
	{ Pass = "VerityBundle", StaffCard = "verity_lapis", BundleCard = "veritybundle",
		A = Color3.fromRGB(255, 225, 90), B = Color3.fromRGB(255, 160, 20) },
	{ Pass = "LaPeaceBundle", StaffCard = "lapeace_lapis", BundleCard = "lapeacebundle",
		A = Color3.fromRGB(255, 245, 210), B = Color3.fromRGB(255, 120, 220) },
}

local function makeBadge(parent, text, a, b, pos, size, anchor, rot)
	local old = parent:FindFirstChild("BundleBadge")
	if old then return old end
	local badge = Instance.new("Frame")
	badge.Name = "BundleBadge"
	badge.AnchorPoint = anchor or Vector2.new(1, 0)
	badge.Position = pos
	badge.Size = size
	badge.Rotation = rot or 8
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.ZIndex = 20
	badge.Active = false
	Instance.new("UICorner", badge).CornerRadius = UDim.new(0.5, 0)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(a, b)
	g.Parent = badge
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Color3.fromRGB(40, 25, 5)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = badge
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.94, 0.86)
	t.Position = UDim2.fromScale(0.03, 0.07)
	t.FontFace = FONT
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = Color3.fromRGB(60, 35, 0)
	t.ZIndex = 21
	t.Parent = badge
	-- shine sweeping across it every few seconds
	local shine = Instance.new("UIGradient")
	shine.Name = "Shine"
	shine.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.45, 0),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(0.55, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	shine.Offset = Vector2.new(-1, 0)
	shine.Parent = t
	task.spawn(function()
		while badge.Parent do
			shine.Offset = Vector2.new(-1, 0)
			TweenService:Create(shine, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) }):Play()
			task.wait(3)
		end
	end)
	badge.Parent = parent
	-- another UI script switches TextScaled off on new labels; keep it on
	t:GetPropertyChangedSignal("TextScaled"):Connect(function()
		if not t.TextScaled then t.TextScaled = true end
	end)
	task.defer(function() t.TextScaled = true end)
	return badge
end

local function find(path)
	local node = master
	for _, n in ipairs(path) do
		node = node and node:FindFirstChild(n)
	end
	return node
end

local function refresh()
	for _, b in ipairs(BUNDLES) do
		local owns = player:GetAttribute("Pass_" .. b.Pass) == true

		local card = find({ "RegularShop", "Container", "cloaklist", b.StaffCard })
		if card then
			local badge = card:FindFirstChild("BundleBadge")
			if owns then
				makeBadge(card, "UPGRADED", b.A, b.B, UDim2.fromScale(0.5, 0.7), UDim2.fromScale(1.08, 0.19), Vector2.new(0.5, 0.5), -7)
				local st = card:FindFirstChildOfClass("UIStroke")
				if st then
					if st:GetAttribute("PreBundleColor") == nil then st:SetAttribute("PreBundleColor", st.Color) end
					st.Color = b.B
				end
			elseif badge then
				badge:Destroy()
				local st = card:FindFirstChildOfClass("UIStroke")
				if st and st:GetAttribute("PreBundleColor") then st.Color = st:GetAttribute("PreBundleColor") end
			end
		end

		local bundle = find({ "RobuxShop", "Container", "items", "Gamepasses", b.BundleCard })
		if bundle then
			local badge = bundle:FindFirstChild("BundleBadge")
			-- (the bundle card's own button already says OWNED)
			if badge then
				badge:Destroy()
			end
		end
	end
end

player.AttributeChanged:Connect(function(attr)
	if attr == "Pass_VerityBundle" or attr == "Pass_LaPeaceBundle" then refresh() end
end)
refresh()
-- shop cards can be rebuilt by the shop scripts; keep the badges on
task.spawn(function()
	while script.Parent do
		task.wait(5)
		refresh()
	end
end)
