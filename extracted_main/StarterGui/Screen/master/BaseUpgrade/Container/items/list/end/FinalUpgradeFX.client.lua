--==================================================
-- THE END?  -  the last upgrade gets the full treatment:
-- a spinning gold/purple edge, a shimmer sweeping across it,
-- sparks drifting up out of it and a slow heartbeat pulse.
--==================================================
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local row = script.Parent
local panel = row:WaitForChild("2")
local button = row:WaitForChild("upgrade")
local title = row:WaitForChild("TextLabel")

local PURPLE = Color3.fromRGB(170, 80, 255)
local GOLD = Color3.fromRGB(255, 210, 90)
local PINK = Color3.fromRGB(255, 120, 230)

-- the edge: a gradient running round the outline
local edge = row:FindFirstChildOfClass("UIStroke")
local edgeGrad
if edge then
	edge.Thickness = 6
	edge.Color = Color3.new(1, 1, 1)
	edgeGrad = Instance.new("UIGradient")
	edgeGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PURPLE), ColorSequenceKeypoint.new(0.25, GOLD), ColorSequenceKeypoint.new(0.5, PINK),
		ColorSequenceKeypoint.new(0.75, GOLD), ColorSequenceKeypoint.new(1, PURPLE),
	})
	edgeGrad.Parent = edge
end

-- the title gets a gold-to-white sheen
local titleGrad = Instance.new("UIGradient")
titleGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.5, GOLD), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) })
titleGrad.Parent = title
local titleScale = Instance.new("UIScale")
titleScale.Parent = title
local btnScale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
btnScale.Parent = button

-- a shimmer across the panel
panel.ClipsDescendants = true
local shine = Instance.new("Frame")
shine.Name = "Shine"
shine.AnchorPoint = Vector2.new(0.5, 0.5)
shine.Size = UDim2.new(0.12, 0, 2.4, 0)
shine.Position = UDim2.fromScale(-0.2, 0.5)
shine.Rotation = 20
shine.BackgroundColor3 = Color3.new(1, 1, 1)
shine.BorderSizePixel = 0
shine.ZIndex = panel.ZIndex + 1
local sg = Instance.new("UIGradient")
sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.65), NumberSequenceKeypoint.new(1, 1) })
sg.Parent = shine
shine.Parent = panel

-- sparks drifting up out of the row
local sparks = {}
local sparkLayer = Instance.new("Frame")
sparkLayer.BackgroundTransparency = 1
sparkLayer.Size = UDim2.fromScale(1, 1)
sparkLayer.ClipsDescendants = true
sparkLayer.ZIndex = panel.ZIndex + 2
sparkLayer.Parent = panel
for i = 1, 14 do
	local s = Instance.new("TextLabel")
	s.BackgroundTransparency = 1
	s.Text = (i % 3 == 0) and "✦" or "•"
	s.TextScaled = true
	s.TextColor3 = (i % 2 == 0) and GOLD or PINK
	s.Size = UDim2.fromScale(0.03, 0.18)
	s.ZIndex = sparkLayer.ZIndex
	s.Parent = sparkLayer
	table.insert(sparks, { L = s, X = math.random(), Speed = 0.15 + math.random() * 0.25, Phase = math.random() * 10 })
end

local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	if not row.Visible then return end
	local t = os.clock() - t0
	if edgeGrad then edgeGrad.Rotation = (t * 90) % 360 end
	titleGrad.Offset = Vector2.new(math.sin(t * 1.4) * 0.8, 0)
	local beat = math.max(0, math.sin(t * 2.6)) ^ 6
	titleScale.Scale = 1 + beat * 0.06
	btnScale.Scale = 1 + beat * 0.03
	local sweep = (t % 3.2) / 3.2
	shine.Position = UDim2.fromScale(-0.2 + sweep * 1.6, 0.5)
	for _, s in ipairs(sparks) do
		local y = 1.1 - ((t * s.Speed + s.Phase) % 1.3)
		s.L.Position = UDim2.fromScale(s.X + math.sin(t * 2 + s.Phase) * 0.02, y)
		s.L.TextTransparency = 0.2 + 0.8 * math.clamp(1 - y, 0, 1) ^ 2
	end
end)
