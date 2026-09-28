--==================================================
-- NEW LAPIS UNLOCKED  (client)
--
-- LapisDiscoveryService fires AccessibleEvents.LapisDiscovered
-- the first time you get each kind of lapis (per ascension).
-- This drops a card in from the top of the screen, styled like
-- the rest of the HUD: gradient panel, chunky black outline,
-- a pill title on the top edge, Inconsolata Bold -- with the
-- lapis itself spinning in a little window.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local LapisConfig = require(ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("LapisDataModule"))
local templates = ReplicatedStorage:WaitForChild("LocalLapisTemplates", 30)
local remote = ReplicatedStorage:WaitForChild("AccessibleEvents"):WaitForChild("LapisDiscovered", 60)
if not remote then return end

local FONT = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)
local PATTERN = "rbxassetid://83787990994298"
local BLACK = Color3.new(0, 0, 0)

local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(0, 20) c.Parent = p return c end
local function stroke(p, th, color, border)
	local s = Instance.new("UIStroke")
	s.Thickness = th or 5
	s.Color = color or BLACK
	if border then s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	s.Parent = p
	return s
end
local function grad(p, a, b, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rot or -90
	g.Parent = p
	return g
end
local function shadow(p) pcall(function() Instance.new("UIShadow").Parent = p end) end
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do
		if k ~= "StrokeColor" and k ~= "StrokeTh" then l[k] = v end
	end
	l.Parent = parent
	stroke(l, props.StrokeTh or 2, props.StrokeColor or BLACK)
	return l
end
local function darker(c, f) return Color3.new(c.R * f, c.G * f, c.B * f) end

--------------------------------------------------
-- the card
--------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "LapisUnlockedGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")

local HIDDEN = UDim2.new(0.5, 0, 0, -220)
local SHOWN = UDim2.new(0.5, 0, 0, 96)

local root = Instance.new("Frame")
root.Name = "Card"
root.AnchorPoint = Vector2.new(0.5, 0)
root.Position = HIDDEN
root.Size = UDim2.fromOffset(470, 176)
root.BackgroundTransparency = 1
root.Visible = false
root.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = root
local function rescale()
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	scale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720) * 1.05, 0.55, 1.3)
end
rescale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end

-- the colourful frame behind the panel (like the teleport menu's)
local border = Instance.new("Frame")
border.Name = "Border"
border.Position = UDim2.fromOffset(-8, 18)
border.Size = UDim2.new(1, 16, 1, -10)
border.BackgroundColor3 = Color3.new(1, 1, 1)
border.ZIndex = 1
border.Parent = root
corner(border)
stroke(border, 5)
local borderGrad = grad(border, Color3.fromRGB(252, 0, 255), Color3.fromRGB(0, 219, 222))
shadow(border)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Position = UDim2.fromOffset(0, 26)
panel.Size = UDim2.new(1, 0, 1, -26)
panel.BackgroundColor3 = Color3.new(1, 1, 1)
panel.ClipsDescendants = true
panel.ZIndex = 2
panel.Parent = root
corner(panel)
stroke(panel, 5)
local panelGrad = grad(panel, Color3.fromRGB(67, 206, 162), Color3.fromRGB(24, 90, 157))
local pattern = Instance.new("ImageLabel")
pattern.BackgroundTransparency = 1
pattern.Image = PATTERN
pattern.ImageTransparency = 0.75
pattern.Position = UDim2.fromScale(-1.2, -2.6)
pattern.Size = UDim2.fromScale(3.4, 6)
pattern.ZIndex = 2
pattern.Parent = panel

-- a shine sweeping across the panel as it lands
local shine = Instance.new("Frame")
shine.BackgroundColor3 = Color3.new(1, 1, 1)
shine.BackgroundTransparency = 0.6
shine.BorderSizePixel = 0
shine.AnchorPoint = Vector2.new(0.5, 0.5)
shine.Size = UDim2.new(0, 46, 2, 0)
shine.Rotation = 20
shine.Position = UDim2.fromScale(-0.3, 0.5)
shine.ZIndex = 6
shine.Parent = panel
local shineGrad = Instance.new("UIGradient")
shineGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
shineGrad.Parent = shine

-- pill title sitting on the top edge
local pill = Instance.new("Frame")
pill.Name = "Title"
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.Position = UDim2.new(0.5, 0, 0, 0)
pill.Size = UDim2.fromOffset(330, 50)
pill.BackgroundColor3 = Color3.new(1, 1, 1)
pill.ZIndex = 8
pill.Parent = root
corner(pill, UDim.new(0, 60))
stroke(pill, 5)
grad(pill, Color3.fromRGB(255, 220, 90), Color3.fromRGB(240, 140, 40))
shadow(pill)
label(pill, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.7), Text = "NEW LAPIS UNLOCKED!", TextColor3 = BLACK, StrokeColor = Color3.new(1, 1, 1), StrokeTh = 3, ZIndex = 9 })

-- the lapis, spinning in its own window
local window = Instance.new("Frame")
window.Name = "Icon"
window.Position = UDim2.fromOffset(18, 36)
window.Size = UDim2.fromOffset(100, 100)
window.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
window.ZIndex = 4
window.Parent = panel
corner(window)
stroke(window, 5)
local windowGrad = grad(window, Color3.fromRGB(60, 60, 80), Color3.fromRGB(16, 14, 24))
local vpf = Instance.new("ViewportFrame")
vpf.BackgroundTransparency = 1
vpf.Size = UDim2.fromScale(1, 1)
vpf.Ambient = Color3.fromRGB(200, 200, 200)
vpf.LightColor = Color3.new(1, 1, 1)
vpf.LightDirection = Vector3.new(-1, -1, -1)
vpf.ZIndex = 5
vpf.Parent = window
corner(vpf)
local vcam = Instance.new("Camera")
vcam.FieldOfView = 30
vcam.Parent = vpf
vpf.CurrentCamera = vcam

local nameLabel = label(panel, { Position = UDim2.fromOffset(134, 34), Size = UDim2.new(1, -150, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 5, StrokeTh = 3 })

local rarityPill = Instance.new("Frame")
rarityPill.Position = UDim2.fromOffset(134, 80)
rarityPill.Size = UDim2.fromOffset(130, 30)
rarityPill.BackgroundColor3 = Color3.new(1, 1, 1)
rarityPill.ZIndex = 5
rarityPill.Parent = panel
corner(rarityPill, UDim.new(0, 60))
stroke(rarityPill, 3)
local rarityText = label(rarityPill, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.72), Text = "", TextColor3 = BLACK, StrokeColor = Color3.new(1, 1, 1), StrokeTh = 1.5, ZIndex = 6 })

local infoLabel = label(panel, { Position = UDim2.fromOffset(274, 82), Size = UDim2.new(1, -290, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 5 })
local worthLabel = label(panel, { Position = UDim2.fromOffset(134, 116), Size = UDim2.new(1, -150, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = Color3.fromRGB(255, 230, 120), ZIndex = 5 })

local sound = Instance.new("Sound")
sound.SoundId = "rbxassetid://10066947742"
sound.Volume = 0.6
sound.Parent = SoundService

--------------------------------------------------
-- showing one
--------------------------------------------------
local spinConn
--------------------------------------------------
-- PARTICLES: a ViewportFrame can't draw ParticleEmitters, so the lapis's
-- own particles (same textures, same colours) are re-created as little
-- 2D sprites drifting out of the window around it.
--------------------------------------------------
local fxLayer = Instance.new("Frame")
fxLayer.Name = "Particles"
fxLayer.BackgroundTransparency = 1
fxLayer.Size = UDim2.fromScale(1, 1)
fxLayer.ClipsDescendants = true
fxLayer.ZIndex = 6
fxLayer.Parent = window
corner(fxLayer)
local fxSpecs, fxAlive, fxAcc = {}, {}, {}
local function readEmitters(src)
	local list = {}
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("ParticleEmitter") and d.Texture ~= "" and d.Enabled ~= false then
			local flip = false
			pcall(function() flip = d.FlipbookLayout ~= Enum.ParticleFlipbookLayout.None end)
			local kp = d.Color.Keypoints
			local tr = d.Transparency.Keypoints
			table.insert(list, {
				Texture = d.Texture, Flip = flip,
				C0 = kp[1].Value, C1 = kp[#kp].Value,
				T0 = math.clamp(tr[1].Value, 0, 0.9),
				Rate = math.clamp(d.Rate, 2, 40),
				Size = math.clamp(d.Size.Keypoints[1].Value + d.Size.Keypoints[#d.Size.Keypoints].Value, 0.4, 6),
				Rot = d.RotSpeed,
			})
		end
	end
	-- sprite sheets would show as a grid of frames: use them only if there's nothing else
	local plain = {}
	for _, e in ipairs(list) do if not e.Flip then table.insert(plain, e) end end
	if #plain > 0 then list = plain end
	table.sort(list, function(a, b) return a.Rate > b.Rate end)
	local keep = {}
	for i = 1, math.min(#list, 4) do keep[i] = list[i] end
	return keep
end
local function spawnSprite(spec)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = spec.Texture
	if spec.Flip then img.ImageRectSize = Vector2.new(256, 256) end
	img.ImageColor3 = spec.C0
	img.ImageTransparency = spec.T0
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	local sz = math.clamp(spec.Size * 9, 8, 38) * (0.7 + math.random() * 0.6)
	img.Size = UDim2.fromOffset(sz, sz)
	img.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.3, 0.5 + (math.random() - 0.5) * 0.3)
	img.Rotation = math.random(0, 360)
	img.ZIndex = 6
	img.Parent = fxLayer
	local ang = math.random() * math.pi * 2
	local speed = 0.18 + math.random() * 0.3
	table.insert(fxAlive, { I = img, S = spec, Born = os.clock(), Life = 0.8 + math.random() * 0.9,
		V = Vector2.new(math.cos(ang), math.sin(ang) - 0.4) * speed, Spin = (math.random() - 0.5) * 240, Size = sz })
end
RunService.RenderStepped:Connect(function(dt)
	if not root.Visible then return end
	for i, spec in ipairs(fxSpecs) do
		fxAcc[i] = (fxAcc[i] or 0) + dt * spec.Rate
		while fxAcc[i] >= 1 and #fxAlive < 60 do
			fxAcc[i] -= 1
			spawnSprite(spec)
		end
	end
	local now = os.clock()
	for k = #fxAlive, 1, -1 do
		local p = fxAlive[k]
		local a = (now - p.Born) / p.Life
		if a >= 1 or not p.I.Parent then
			p.I:Destroy()
			table.remove(fxAlive, k)
		else
			p.I.Position += UDim2.fromScale(p.V.X * dt, p.V.Y * dt)
			p.I.Rotation += p.Spin * dt
			p.I.ImageColor3 = p.S.C0:Lerp(p.S.C1, a)
			p.I.ImageTransparency = p.S.T0 + (1 - p.S.T0) * a * a
			local s = p.Size * (1 - 0.4 * a)
			p.I.Size = UDim2.fromOffset(s, s)
		end
	end
end)

local function setModel(name)
	vpf:ClearAllChildren()
	corner(vpf)
	vcam = Instance.new("Camera")
	vcam.FieldOfView = 30
	vcam.Parent = vpf
	vpf.CurrentCamera = vcam
	if spinConn then spinConn:Disconnect() spinConn = nil end
	local src = templates and templates:FindFirstChild(name)
	for _, p in ipairs(fxAlive) do p.I:Destroy() end
	table.clear(fxAlive)
	table.clear(fxAcc)
	fxSpecs = src and readEmitters(src) or {}
	-- (a plain lapis with no particles of its own still gets a few sparkles)
	if #fxSpecs == 0 then
		fxSpecs = { { Texture = "rbxasset://textures/particles/sparkles_main.dds", C0 = Color3.new(1, 1, 1), C1 = Color3.fromRGB(255, 230, 150), T0 = 0.1, Rate = 6, Size = 1.2, Flip = false } }
	end
	if not src then return end
	local model = src:Clone()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Sound") then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored = true end
	end
	local cf, size
	if model:IsA("Model") then cf, size = model:GetBoundingBox() else cf, size = model.CFrame, model.Size end
	model.Parent = vpf
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(vcam.FieldOfView / 2)) * 1.05
	local centre = cf.Position
	local base = model:IsA("Model") and model:GetPivot() or model.CFrame
	local offset = centre -- (spin about the middle of the lapis)
	local rel = CFrame.new(centre):ToObjectSpace(base)
	vcam.CFrame = CFrame.lookAt(centre + Vector3.new(0, radius * 0.25, dist), centre)
	local t0 = os.clock()
	spinConn = RunService.RenderStepped:Connect(function()
		if not model.Parent then return end
		local a = (os.clock() - t0) * 1.6
		local target = CFrame.new(offset) * CFrame.Angles(0, a, 0) * rel
		if model:IsA("Model") then model:PivotTo(target) else model.CFrame = target end
	end)
end

local function fmt(n)
	if n >= 1e6 then return (("%.1fM"):format(n / 1e6):gsub("%.0M", "M")) end
	if n >= 1e3 then return (("%.1fK"):format(n / 1e3):gsub("%.0K", "K")) end
	return tostring(n)
end

local queue = {}
local busy = false

local function showNext()
	if busy then return end
	local name = table.remove(queue, 1)
	if not name then return end
	busy = true
	local info = LapisConfig.GetInfo(name)
	nameLabel.Text = string.upper(info.DisplayName)
	rarityText.Text = string.upper(info.Rarity)
	rarityPill.BackgroundColor3 = info.RarityColor
	infoLabel.Text = string.upper(info.Island)
	worthLabel.Text = "SELLS FOR " .. fmt(info.Value) .. " PP"
	-- the panel takes on the rarity's colour
	panelGrad.Color = ColorSequence.new(info.RarityColor, darker(info.RarityColor, 0.35))
	windowGrad.Color = ColorSequence.new(darker(info.RarityColor, 0.45), Color3.fromRGB(16, 14, 24))
	setModel(name)

	root.Visible = true
	root.Position = HIDDEN
	TweenService:Create(root, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = SHOWN }):Play()
	pcall(function() sound:Play() end)
	task.delay(0.35, function()
		shine.Position = UDim2.fromScale(-0.3, 0.5)
		TweenService:Create(shine, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(1.3, 0.5) }):Play()
	end)
	-- a gentle wobble on the title while it's up
	local t0 = os.clock()
	local wob = RunService.RenderStepped:Connect(function()
		pill.Rotation = math.sin((os.clock() - t0) * 3) * 2
		borderGrad.Rotation = -90 + (os.clock() - t0) * 40
	end)
	task.wait(3.6)
	local out = TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = HIDDEN })
	out:Play()
	out.Completed:Wait()
	wob:Disconnect()
	root.Visible = false
	if spinConn then spinConn:Disconnect() spinConn = nil end
	busy = false
	showNext()
end

remote.OnClientEvent:Connect(function(name)
	if type(name) ~= "string" then return end
	table.insert(queue, name)
	task.spawn(showNext)
end)
