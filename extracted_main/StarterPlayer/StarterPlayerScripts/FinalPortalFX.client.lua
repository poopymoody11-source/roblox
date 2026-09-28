--==================================================
-- FINAL BOSS PORTAL  --  looks + teleport cinematic (client)
--
-- 1. Every base's nether portal (Upgrades > Purchases >
--    bossfight) gets a living vortex once it's unlocked:
--    swirling particles in the opening, crackling energy arcs
--    round the frame, orbiting obsidian shards, a spinning
--    rune circle on the floor, rising embers, a pulsing light
--    and a FINAL BOSS sign. Purely client-side and only built
--    while you're near it, so it costs nothing elsewhere.
--    It follows the portal's prompt: hidden until the upgrade
--    is bought.
--
-- 2. When a Final Boss party starts, everyone in it gets a
--    teleport cinematic: pulled into the nearest portal while
--    the camera closes in, then a purple vortex swallows the
--    screen and fades to black as the teleport happens.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local plotsFolder = workspace:WaitForChild("Islands"):WaitForChild("StarterIsland"):WaitForChild("IslandPlots")

local PURPLE = Color3.fromRGB(170, 60, 255)
local MAGENTA = Color3.fromRGB(255, 60, 220)
local DEEP = Color3.fromRGB(60, 0, 110)
local VIEW_DISTANCE = 220
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local holder = workspace:FindFirstChild("ClientAuras") or Instance.new("Folder")
holder.Name = "ClientAuras"
holder.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	return p
end

--==================================================
-- PORTAL GEOMETRY
-- The opening is the magenta "nether" blocks; everything
-- is laid out in the teleport part's space so it works
-- for the rotated copies of the plot too.
--==================================================

local function measure(model)
	local tp = model:FindFirstChild("teleport")
	if not tp then return nil end
	local basis = tp.CFrame
	local mn, mx
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("BasePart") and (d.BrickColor == BrickColor.new("Magenta") or d == tp) then
			local rel = basis:PointToObjectSpace(d.Position)
			local h = d.Size / 2
			mn = mn and mn:Min(rel - h) or rel - h
			mx = mx and mx:Max(rel + h) or rel + h
		end
	end
	if not mn then return nil end
	local centerRel = (mn + mx) / 2
	local size = mx - mn
	local platform = model:FindFirstChild("Platform")

	-- Face the portal INTO the base (towards the plot's middle), so
	-- "in front of the portal" is where players actually stand.
	local cf = basis * CFrame.new(centerRel)
	local plot = model:FindFirstAncestor("IslandPlots") and model
	while plot and plot.Parent and plot.Parent.Name ~= "IslandPlots" do plot = plot.Parent end
	local hitbox = plot and plot:FindFirstChild("Hitbox")
	if hitbox then
		local toCenter = hitbox.Position - cf.Position
		if cf.LookVector:Dot(toCenter) < 0 then
			cf = cf * CFrame.Angles(0, math.pi, 0)
		end
	end

	return {
		CFrame = cf,       -- LookVector points out of the portal into the base
		Plot = plot,
		Width = size.X, Height = size.Y,
		FloorY = platform and (platform.Position.Y + platform.Size.Y / 2) or (basis.Position.Y - size.Y / 2),
		Prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true),
	}
end

--==================================================
-- BUILD / ANIMATE ONE PORTAL
--==================================================

local function build(geo)
	local folder = Instance.new("Folder")
	folder.Name = "FinalPortalFX"
	folder.Parent = holder
	local cf, w, h = geo.CFrame, geo.Width, geo.Height
	local b = { folder = folder, t0 = os.clock(), shards = {} }

	-- the opening: a thin glowing sheet full of swirling particles
	-- sits just in front of the nether blocks (negative Z = out towards the base)
	local sheet = part({ Size = Vector3.new(w, h, 0.15), CFrame = cf * CFrame.new(0, 0, -1.15), Color = PURPLE, Transparency = 0.55, Material = Enum.Material.ForceField, Parent = folder })
	b.sheet = sheet
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = SPARK
	swirl.Color = ColorSequence.new(MAGENTA, PURPLE)
	swirl.LightEmission = 1
	swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	swirl.Lifetime = NumberRange.new(0.8, 1.4)
	swirl.Speed = NumberRange.new(0.5, 1.5)
	swirl.Rotation = NumberRange.new(0, 360)
	swirl.RotSpeed = NumberRange.new(-200, 200)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Shape = Enum.ParticleEmitterShape.Box
	swirl.Rate = 40
	swirl.Parent = sheet
	local suck = Instance.new("ParticleEmitter") -- wisps pulled into the portal
	suck.Texture = SMOKE
	suck.Color = ColorSequence.new(PURPLE, DEEP)
	suck.LightEmission = 0.8
	suck.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.6), NumberSequenceKeypoint.new(1, 1) })
	suck.Size = NumberSequence.new(2.5, 0.5)
	suck.Lifetime = NumberRange.new(1.2, 1.8)
	suck.Speed = NumberRange.new(-3, -1.5)
	suck.EmissionDirection = Enum.NormalId.Front
	suck.SpreadAngle = Vector2.new(35, 35)
	suck.Rate = 10
	suck.Parent = sheet

	local light = Instance.new("PointLight")
	light.Color = PURPLE
	light.Range = 22
	light.Brightness = 3
	light.Shadows = false
	light.Parent = sheet
	b.light = light

	-- crackling energy arcs up both sides of the frame
	local function att(p, pos) local a = Instance.new("Attachment") a.Position = pos a.Parent = p return a end
	b.arcs = {}
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (w / 2 + 1.2)
		local a0 = att(sheet, Vector3.new(x, -h / 2 - 0.5, -1))
		local a1 = att(sheet, Vector3.new(x, h / 2 + 0.5, -1))
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1 = 0.35, 0.35
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 12
		beam.Texture = SPARK
		beam.TextureSpeed = 3
		beam.TextureLength = 2
		beam.Color = ColorSequence.new(MAGENTA, PURPLE)
		beam.Transparency = NumberSequence.new(0.1)
		beam.Parent = sheet
		table.insert(b.arcs, beam)
	end
	-- top arc bridging the frame
	do
		local a0 = att(sheet, Vector3.new(-w / 2 - 1.2, h / 2 + 1.2, -1))
		local a1 = att(sheet, Vector3.new(w / 2 + 1.2, h / 2 + 1.2, -1))
		local beam = b.arcs[1]:Clone()
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Parent = sheet
		table.insert(b.arcs, beam)
	end

	-- rune circle on the floor in front of the portal
	local front = cf * CFrame.new(0, 0, -6)
	local floorPos = Vector3.new(front.Position.X, geo.FloorY + 0.08, front.Position.Z)
	b.runes = {}
	for i, c in ipairs({ PURPLE, MAGENTA }) do
		local r = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 11 - i * 3, 11 - i * 3), Color = c, Material = Enum.Material.ForceField, Transparency = 0, Parent = folder })
		r:SetAttribute("Base", floorPos)
		table.insert(b.runes, r)
	end
	b.floorPos = floorPos
	local embers = part({ Size = Vector3.new(8, 0.2, 8), CFrame = CFrame.new(floorPos), Transparency = 1, Parent = folder })
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SPARK
	pe.Color = ColorSequence.new(MAGENTA, PURPLE)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(1.5, 2.5)
	pe.Speed = NumberRange.new(2, 4)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.SpreadAngle = Vector2.new(15, 15)
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.Rate = 14
	pe.Parent = embers

	-- orbiting obsidian shards with purple glow
	for i = 1, 6 do
		local s = part({ Size = Vector3.new(0.9, 1.4, 0.9), Color = Color3.fromRGB(25, 10, 40), Material = Enum.Material.Granite, Parent = folder })
		local core = part({ Size = Vector3.new(0.5, 0.9, 0.5), Color = MAGENTA, Transparency = 0.2, Parent = folder })
		table.insert(b.shards, { part = s, core = core, phase = i / 6 * math.pi * 2, tilt = (i % 2 == 0) and 1 or -1 })
	end

	-- FINAL BOSS sign
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(12, 2.2)
	bb.StudsOffsetWorldSpace = Vector3.new(0, h / 2 + 8, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Adornee = sheet
	bb.Parent = folder
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.Text = "☠ FINAL BOSS ☠"
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = DEEP
	st.Parent = lbl
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, MAGENTA), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, PURPLE) })
	grad.Parent = lbl
	b.grad = grad

	return b
end

local function animate(b, geo)
	local t = os.clock() - b.t0
	local pulse = (math.sin(t * 2.4) + 1) / 2
	local cf, w, h = geo.CFrame, geo.Width, geo.Height

	b.sheet.Transparency = 0.45 + pulse * 0.25
	b.light.Brightness = 2 + pulse * 3
	for _, arc in ipairs(b.arcs) do
		arc.CurveSize0 = math.noise(t * 5, arc.Width0 * 10) * 3
		arc.CurveSize1 = math.noise(arc.Width1 * 10, t * 5) * 3
	end
	for i, r in ipairs(b.runes) do
		local dir = (i == 1) and 1 or -1
		r.CFrame = CFrame.new(b.floorPos + Vector3.new(0, i * 0.03, 0)) * CFrame.Angles(0, t * 0.8 * dir, 0) * CFrame.Angles(0, 0, math.rad(90))
	end
	for _, s in ipairs(b.shards) do
		local a = s.phase + t * 0.9
		-- ellipse just outside the obsidian frame, drifting in front of it
		local rx, ry = (w / 2 + 7) * math.cos(a), (h / 2 + 6) * math.sin(a)
		local pos = cf * CFrame.new(rx, ry, -2.5 + math.sin(a * 2) * 1.2 * s.tilt)
		local spin = CFrame.Angles(t * 1.5, t * 2 * s.tilt, 0)
		s.part.CFrame = CFrame.new(pos.Position) * spin
		s.core.CFrame = s.part.CFrame
	end
	b.grad.Offset = Vector2.new(math.sin(t * 1.5) * 0.5, 0)
end

--==================================================
-- TRACK EVERY PLOT'S PORTAL
--==================================================

local portals = {}  -- [model] = { geo = ..., fx = built|nil }

local function track(plot)
	local purchases = plot:WaitForChild("Upgrades", 10)
	purchases = purchases and purchases:WaitForChild("Purchases", 10)
	local model = purchases and purchases:WaitForChild("bossfight", 10)
	if not model or portals[model] then return end
	local geo = measure(model)
	if geo then portals[model] = { geo = geo } end
end

for _, plot in ipairs(plotsFolder:GetChildren()) do task.spawn(track, plot) end
plotsFolder.ChildAdded:Connect(function(p) task.spawn(track, p) end)

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	for model, info in pairs(portals) do
		local geo = info.geo
		local owner = geo.Plot and geo.Plot:FindFirstChild("Owner")
		local claimed = owner == nil or owner.Value ~= ""
		local unlocked = claimed and model.Parent ~= nil and (geo.Prompt == nil or geo.Prompt.Enabled)
		local near = camPos and (camPos - geo.CFrame.Position).Magnitude <= VIEW_DISTANCE
		if unlocked and near then
			if not info.fx then info.fx = build(geo) end
			animate(info.fx, geo)
		elseif info.fx then
			info.fx.folder:Destroy()
			info.fx = nil
		end
		if not model.Parent then portals[model] = nil end
	end
end)

--==================================================
-- TELEPORT CINEMATIC
--==================================================

local playerGui = player:WaitForChild("PlayerGui")
local overlay = Instance.new("ScreenGui")
overlay.Name = "PortalWarp"
overlay.IgnoreGuiInset = true
overlay.ResetOnSpawn = false
overlay.DisplayOrder = 200
overlay.Enabled = false
overlay.Parent = playerGui

local black = Instance.new("Frame")
black.Size = UDim2.fromScale(1, 1)
black.BackgroundColor3 = Color3.new(0, 0, 0)
black.BackgroundTransparency = 1
black.ZIndex = 1
black.Parent = overlay

-- concentric spinning rings = the vortex
local rings = {}
for i = 1, 7 do
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.BackgroundTransparency = 1
	f.ZIndex = 2
	local ar = Instance.new("UIAspectRatioConstraint") ar.Parent = f
	Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke")
	st.Thickness = 10
	st.Color = Color3.new(1, 1, 1)
	st.Transparency = 1
	st.Parent = f
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, MAGENTA), ColorSequenceKeypoint.new(0.5, PURPLE), ColorSequenceKeypoint.new(1, DEEP) })
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 0) })
	g.Parent = st
	f.Parent = overlay
	rings[i] = { frame = f, stroke = st, grad = g, k = i }
end

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.5)
title.Size = UDim2.fromScale(0.6, 0.1)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.TextScaled = true
title.TextColor3 = Color3.new(1, 1, 1)
title.TextTransparency = 1
title.Text = "ENTERING THE FINAL BOSS..."
title.ZIndex = 5
title.Parent = overlay
local titleStroke = Instance.new("UIStroke")
titleStroke.Thickness = 3
titleStroke.Color = DEEP
titleStroke.Transparency = 1
titleStroke.Parent = title

local warp = nil -- active cinematic state

local function nearestPortal()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local best, bestD = nil, 120
	for _, info in pairs(portals) do
		local d = (info.geo.CFrame.Position - root.Position).Magnitude
		if d < bestD then best, bestD = info.geo, d end
	end
	return best
end

local function beginWarp()
	if warp then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	warp = { t0 = os.clock(), geo = nearestPortal(), root = root, fov = workspace.CurrentCamera.FieldOfView }
	overlay.Enabled = true

	warp.cc = Instance.new("ColorCorrectionEffect")
	warp.cc.Name = "PortalWarpCC"
	warp.cc.Parent = Lighting
	TweenService:Create(warp.cc, TweenInfo.new(3), { TintColor = Color3.fromRGB(220, 170, 255), Saturation = 0.3, Contrast = 0.2 }):Play()
	warp.blur = Instance.new("BlurEffect")
	warp.blur.Name = "PortalWarpBlur"
	warp.blur.Size = 0
	warp.blur.Parent = Lighting

	if warp.geo and root then
		-- float you up to the portal mouth, facing in
		local target = warp.geo.CFrame * CFrame.new(0, 0, -2.5)
		root.Anchored = true
		local goal = CFrame.lookAt(target.Position, warp.geo.CFrame.Position)
		TweenService:Create(root, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = goal }):Play()
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		local camGoal = CFrame.lookAt((warp.geo.CFrame * CFrame.new(3, 2, -14)).Position, warp.geo.CFrame.Position)
		TweenService:Create(cam, TweenInfo.new(2.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = camGoal }):Play()
	end
end

local function plunge()
	beginWarp()
	warp.plunge = os.clock()
	TweenService:Create(title, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	TweenService:Create(titleStroke, TweenInfo.new(0.6), { Transparency = 0 }):Play()
	TweenService:Create(warp.blur, TweenInfo.new(1.5), { Size = 24 }):Play()
	TweenService:Create(workspace.CurrentCamera, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { FieldOfView = 120 }):Play()
	if warp.geo and warp.root then
		TweenService:Create(warp.root, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = warp.geo.CFrame * CFrame.new(0, 0, 2) }):Play()
	end
	task.delay(1.6, function()
		if warp then TweenService:Create(black, TweenInfo.new(1), { BackgroundTransparency = 0 }):Play() end
	end)
end

local function endWarp()
	if not warp then return end
	local w = warp
	warp = nil
	TweenService:Create(black, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	TweenService:Create(titleStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	for _, r in ipairs(rings) do r.stroke.Transparency = 1 end
	local cam = workspace.CurrentCamera
	TweenService:Create(cam, TweenInfo.new(0.6), { FieldOfView = w.fov or 70 }):Play()
	cam.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
	if w.root and w.root.Parent then w.root.Anchored = false end
	if w.cc then w.cc:Destroy() end
	if w.blur then w.blur:Destroy() end
	task.delay(0.7, function() if not warp then overlay.Enabled = false end end)
end

-- spin the vortex rings
RunService.RenderStepped:Connect(function()
	if not warp then return end
	local t = os.clock() - warp.t0
	local p = warp.plunge and math.clamp((os.clock() - warp.plunge) / 1.6, 0, 1) or math.clamp(t / 3, 0, 0.35)
	for _, r in ipairs(rings) do
		-- rings rush inward and spin faster as you go in
		local phase = ((t * (0.35 + p) + r.k / #rings) % 1)
		local s = 1.6 * (1 - phase)
		r.frame.Size = UDim2.fromScale(s, s)
		r.stroke.Thickness = 4 + 22 * (1 - phase) * p
		r.stroke.Transparency = 1 - p * math.sin(phase * math.pi)
		r.grad.Rotation = (t * 240 * (1 + p * 2) + r.k * 40) % 360
	end
	local cam = workspace.CurrentCamera
	if warp.plunge and cam then
		cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(1.5 * p))
	end
end)

local remote = ReplicatedStorage:WaitForChild("FinalBossLobby", 30)
if remote then
	remote.OnClientEvent:Connect(function(action, a)
		if action == "Countdown" then
			beginWarp()
		elseif action == "Teleporting" then
			plunge()
		elseif action == "Closed" then
			endWarp()
		elseif action == "State" and type(a) == "table" and not a.Starting and warp then
			-- teleport didn't happen (Studio, or it failed): bring them back
			task.delay(1.5, endWarp)
		end
	end)
end

-- if a teleport fails on Roblox's side the character is still here
game:GetService("TeleportService").TeleportInitFailed:Connect(function(p)
	if p == player then endWarp() end
end)
