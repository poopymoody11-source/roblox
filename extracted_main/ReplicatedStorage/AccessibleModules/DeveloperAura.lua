--==================================================
-- DEVELOPER AURA  (client, built entirely in code)
--
-- Used by StarterPlayerScripts.TitleAura for the "developer" title.
--   * DEVELOPER nameplate with an animated gradient + glitch
--   * two rings of letters orbiting the body (they pass behind
--     you, so the text actually wraps around the character)
--   * rising helix of code glyphs
--   * spinning rune circle on the ground, neon cracks, shockwaves
--   * chunks of the ground torn up and orbiting you
--   * lightning strikes into the ground nearby
--   * big pulsing light + the world tints purple when you're close
--==================================================

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local DeveloperAura = {}
DeveloperAura.__index = DeveloperAura

local PURPLE = Color3.fromRGB(170, 90, 255)
local VIOLET = Color3.fromRGB(110, 40, 255)
local CYAN = Color3.fromRGB(80, 230, 255)
local GOLD = Color3.fromRGB(255, 210, 90)
local WHITE = Color3.new(1, 1, 1)

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local container = workspace:FindFirstChild("ClientAuras")
if not container then
	container = Instance.new("Folder")
	container.Name = "ClientAuras"
	container.Parent = workspace
end

local active = {} -- set of live auras (for the world tint)

local function lowGraphics()
	return Players.LocalPlayer and Players.LocalPlayer:GetAttribute("Set_LowGraphics") == true
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Locked = true
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function gradient(parent, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, VIOLET),
		ColorSequenceKeypoint.new(0.35, PURPLE),
		ColorSequenceKeypoint.new(0.55, CYAN),
		ColorSequenceKeypoint.new(0.75, GOLD),
		ColorSequenceKeypoint.new(1, VIOLET),
	})
	g.Rotation = rot or 0
	g.Parent = parent
	return g
end

local function glyphLabel(parent, text, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = text
	l.Font = font or Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = WHITE
	l.Parent = parent
	local s = Instance.new("UIStroke")
	s.Color = VIOLET
	s.Thickness = 2
	s.Parent = l
	return l
end

local function circleFrame(parent, scale, thickness, color, transparency)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(scale, scale)
	f.BackgroundTransparency = 1
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color
	s.Transparency = transparency or 0
	s.Parent = f
	return f, s
end

-- A flat part with a SurfaceGui on top (rune circle, shockwaves)
local function groundDecal(folder, size)
	local p = part({ Name = "Ground", Size = Vector3.new(size, 0.05, size), Transparency = 1 })
	p.Parent = folder
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(512, 512)
	sg.LightInfluence = 0
	sg.Brightness = 3
	sg.MaxDistance = 250
	sg.Adornee = p
	sg.Parent = p
	return p, sg
end

--==================================================

function DeveloperAura.new(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if not root then return nil end

	local self = setmetatable({}, DeveloperAura)
	self.character = character
	self.root = root
	self.low = lowGraphics()
	self.t0 = os.clock()
	self.connections = {}
	self.gradients = {}

	local folder = Instance.new("Folder")
	folder.Name = "DevAura_" .. character.Name
	folder.Parent = container
	self.folder = folder

	-- centre part: follows the root with no rotation; everything orbits it
	local center = part({ Name = "Center", Size = Vector3.one * 0.2, Transparency = 1 })
	center.Parent = folder
	self.center = center

	local light = Instance.new("PointLight")
	light.Color = PURPLE
	light.Range = 24
	light.Brightness = 3
	light.Shadows = false
	light.Parent = center
	self.light = light

	--------------------------------------------------
	-- particles (emitter slab at the feet)
	--------------------------------------------------
	local slab = part({ Name = "Emitter", Size = Vector3.new(6, 0.2, 6), Transparency = 1 })
	slab.Parent = folder
	self.slab = slab

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK
	sparks.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, CYAN), ColorSequenceKeypoint.new(0.5, PURPLE), ColorSequenceKeypoint.new(1, GOLD) })
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	sparks.Lifetime = NumberRange.new(1.2, 2.2)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.Rate = self.low and 15 or 45
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.SpreadAngle = Vector2.new(10, 10)
	sparks.Acceleration = Vector3.new(0, 2, 0)
	sparks.RotSpeed = NumberRange.new(-180, 180)
	sparks.Parent = slab

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE
	smoke.Color = ColorSequence.new(Color3.fromRGB(40, 0, 80), Color3.fromRGB(10, 0, 25))
	smoke.LightEmission = 0.2
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Speed = NumberRange.new(1, 3)
	smoke.Rate = self.low and 4 or 12
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.RotSpeed = NumberRange.new(-40, 40)
	smoke.Parent = slab

	local rootAtt = Instance.new("Attachment")
	rootAtt.Parent = center
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = SPARK
	stars.Color = ColorSequence.new(WHITE, PURPLE)
	stars.LightEmission = 1
	stars.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1.2), NumberSequenceKeypoint.new(1, 0) })
	stars.Lifetime = NumberRange.new(0.6, 1)
	stars.Speed = NumberRange.new(6, 12)
	stars.SpreadAngle = Vector2.new(180, 180)
	stars.Rate = self.low and 6 or 18
	stars.Drag = 4
	stars.Parent = rootAtt

	--------------------------------------------------
	-- orbiting wisps with trails
	--------------------------------------------------
	self.wisps = {}
	for i = 1, 3 do
		local w = part({ Name = "Wisp", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, Material = Enum.Material.Neon, Color = (i == 2) and CYAN or PURPLE })
		w.Parent = folder
		local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, 0.2, 0) a0.Parent = w
		local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -0.2, 0) a1.Parent = w
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.45
		tr.LightEmission = 1
		tr.Color = ColorSequence.new(w.Color, WHITE)
		tr.Transparency = NumberSequence.new(0, 1)
		tr.WidthScale = NumberSequence.new(1, 0)
		tr.FaceCamera = true
		tr.Parent = w
		table.insert(self.wisps, w)
	end

	--------------------------------------------------
	-- letter rings (BillboardGuis on attachments around the centre)
	--------------------------------------------------
	local function makeRing(text, radius, height, tilt, speed, size, font)
		local ring = { radius = radius, height = height, tilt = tilt, speed = speed, items = {} }
		local chars = {}
		for _, cp in utf8.codes(text) do table.insert(chars, utf8.char(cp)) end
		for i, ch in ipairs(chars) do
			local att = Instance.new("Attachment")
			att.Parent = center
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(size, size)
			bb.LightInfluence = 0
			bb.Brightness = 2
			bb.MaxDistance = 160
			bb.Adornee = att
			bb.Parent = att
			local l = glyphLabel(bb, ch, font)
			table.insert(self.gradients, gradient(l, 90))
			table.insert(ring.items, { att = att, phase = (i - 1) / #chars * math.pi * 2, label = l })
		end
		return ring
	end
	self.rings = {
		makeRing("DEVELOPER", 4.2, -0.4, 0, 1.4, 1.5, Enum.Font.GothamBlack),
		makeRing("✦DEV✦DEV✦DEV", 3.2, 0.9, math.rad(32), -2.1, 0.9, Enum.Font.Arcade),
	}

	--------------------------------------------------
	-- rising helix of code glyphs
	--------------------------------------------------
	self.helix = {}
	if not self.low then
		local glyphs = { "</>", "{ }", "01", "10", "fn", "#", "&&", "::", "=>", "[ ]", "!=", ";" }
		for i, g in ipairs(glyphs) do
			local att = Instance.new("Attachment")
			att.Parent = center
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(1.1, 0.7)
			bb.LightInfluence = 0
			bb.MaxDistance = 120
			bb.Adornee = att
			bb.Parent = att
			local l = glyphLabel(bb, g, Enum.Font.Code)
			l.TextColor3 = CYAN
			table.insert(self.helix, { att = att, label = l, phase = (i - 1) / #glyphs })
		end
	end

	--------------------------------------------------
	-- nameplate
	--------------------------------------------------
	if head then
		local bb = Instance.new("BillboardGui")
		bb.Name = "DevNameplate"
		bb.Size = UDim2.fromScale(8, 2.2)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 3.3, 0)
		bb.LightInfluence = 0
		bb.MaxDistance = 200
		bb.AlwaysOnTop = false
		bb.Adornee = head
		bb.Parent = folder
		local main = Instance.new("TextLabel")
		main.BackgroundTransparency = 1
		main.Size = UDim2.fromScale(1, 0.68)
		main.Font = Enum.Font.GothamBlack
		main.Text = "⚡ DEVELOPER ⚡"
		main.TextScaled = true
		main.TextColor3 = WHITE
		main.Parent = bb
		local st = Instance.new("UIStroke") st.Thickness = 3 st.Color = Color3.fromRGB(20, 0, 40) st.Parent = main
		table.insert(self.gradients, gradient(main, 0))
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0, 0.66)
		sub.Size = UDim2.fromScale(1, 0.32)
		sub.Font = Enum.Font.Code
		sub.Text = "// " .. character.Name .. " built this world"
		sub.TextScaled = true
		sub.TextColor3 = CYAN
		sub.Parent = bb
		local st2 = Instance.new("UIStroke") st2.Thickness = 1.5 st2.Color = Color3.fromRGB(0, 0, 0) st2.Parent = sub
		-- glitch copy
		local ghost = main:Clone()
		ghost.Name = "Ghost"
		ghost.TextColor3 = Color3.fromRGB(255, 40, 90)
		ghost.TextTransparency = 1
		ghost.ZIndex = 0
		for _, c in ipairs(ghost:GetChildren()) do if c:IsA("UIGradient") then c:Destroy() end end
		ghost.Parent = bb
		self.nameMain, self.nameGhost, self.nameplate = main, ghost, bb
	end

	--------------------------------------------------
	-- ground: rune circle + cracks
	--------------------------------------------------
	local rune, runeGui = groundDecal(folder, 15)
	self.rune = rune
	local spin = Instance.new("Frame")
	spin.BackgroundTransparency = 1
	spin.AnchorPoint = Vector2.new(0.5, 0.5)
	spin.Position = UDim2.fromScale(0.5, 0.5)
	spin.Size = UDim2.fromScale(1, 1)
	spin.Parent = runeGui
	circleFrame(spin, 0.97, 6, PURPLE, 0.1)
	circleFrame(spin, 0.86, 2, CYAN, 0.3)
	circleFrame(spin, 0.55, 4, PURPLE, 0.2)
	-- rune letters around the circle
	local runeText = "DEVELOPER ✦ DEVELOPER ✦ "
	local runeChars = {}
	for _, cp in utf8.codes(runeText) do table.insert(runeChars, utf8.char(cp)) end
	for i, ch in ipairs(runeChars) do
		local ang = (i - 1) / #runeChars * math.pi * 2
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Size = UDim2.fromScale(0.07, 0.07)
		l.Position = UDim2.fromScale(0.5 + math.cos(ang) * 0.455, 0.5 + math.sin(ang) * 0.455)
		l.Rotation = math.deg(ang) + 90
		l.Font = Enum.Font.Arcade
		l.Text = ch
		l.TextScaled = true
		l.TextColor3 = WHITE
		l.Parent = spin
	end
	-- inner hexagram-ish lines
	for i = 0, 5 do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = UDim2.new(0.55, 0, 0, 3)
		line.Rotation = i * 30
		line.BackgroundColor3 = PURPLE
		line.BackgroundTransparency = 0.25
		line.BorderSizePixel = 0
		line.Parent = spin
	end
	local counter = Instance.new("Frame")
	counter.BackgroundTransparency = 1
	counter.AnchorPoint = Vector2.new(0.5, 0.5)
	counter.Position = UDim2.fromScale(0.5, 0.5)
	counter.Size = UDim2.fromScale(0.5, 0.5)
	counter.Parent = runeGui
	for i = 0, 2 do
		local tri = Instance.new("Frame")
		tri.AnchorPoint = Vector2.new(0.5, 0.5)
		tri.Position = UDim2.fromScale(0.5, 0.5)
		tri.Size = UDim2.fromScale(0.7, 0.7)
		tri.Rotation = i * 30
		tri.BackgroundTransparency = 1
		tri.Parent = counter
		local s = Instance.new("UIStroke") s.Color = GOLD s.Thickness = 2 s.Transparency = 0.2 s.Parent = tri
	end
	self.runeSpin, self.runeCounter = spin, counter

	self.cracks = {}
	for i = 1, (self.low and 0 or 7) do
		local len = math.random(40, 90) / 10
		local c = part({ Name = "Crack", Size = Vector3.new(0.15, 0.06, len), Material = Enum.Material.Neon, Color = PURPLE })
		c.Parent = folder
		table.insert(self.cracks, { part = c, angle = (i / 7) * math.pi * 2 + math.random() * 0.5, len = len })
	end

	--------------------------------------------------
	-- torn-up ground chunks
	--------------------------------------------------
	self.debris = {}
	for i = 1, (self.low and 0 or 9) do
		local s = math.random(35, 90) / 100
		local d = part({ Name = "Debris", Size = Vector3.new(s, s * 0.8, s * 1.1), Material = Enum.Material.Slate, Color = Color3.fromRGB(90, 90, 100) })
		d.Parent = folder
		table.insert(self.debris, {
			part = d, phase = math.random() * math.pi * 2, radius = math.random(55, 95) / 10,
			height = math.random(5, 35) / 10, speed = (math.random() * 0.5 + 0.3) * (math.random(0, 1) == 0 and -1 or 1),
			spin = Vector3.new(math.random(), math.random(), math.random()) * 2,
		})
	end

	--------------------------------------------------
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.rayParams.FilterDescendantsInstances = { character, container }

	self.nextShock = os.clock() + 0.5
	self.nextBolt = os.clock() + 1
	self.nextGlitch = os.clock() + 1.5
	self.groundY = root.Position.Y - 3
	self.groundMat, self.groundColor = nil, nil

	table.insert(self.connections, RunService.RenderStepped:Connect(function(dt) self:update(dt) end))
	active[self] = true
	return self
end

function DeveloperAura:shockwave(pos)
	local p, sg = groundDecal(self.folder, 3)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.08, 0))
	local _, s = circleFrame(sg, 0.96, 10, CYAN, 0)
	local _, s2 = circleFrame(sg, 0.8, 4, PURPLE, 0.2)
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(p, info, { Size = Vector3.new(34, 0.05, 34) }):Play()
	TweenService:Create(s, info, { Transparency = 1 }):Play()
	TweenService:Create(s2, info, { Transparency = 1 }):Play()
	task.delay(1.15, function() p:Destroy() end)
end

function DeveloperAura:bolt(from, to)
	local segments = 7
	local points = { from }
	for i = 1, segments - 1 do
		local t = i / segments
		local p = from:Lerp(to, t) + Vector3.new(math.random(-10, 10) / 10, math.random(-6, 6) / 10, math.random(-10, 10) / 10)
		table.insert(points, p)
	end
	table.insert(points, to)
	local parts = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		local seg = part({ Name = "Bolt", Size = Vector3.new(0.18, 0.18, len), Material = Enum.Material.Neon, Color = (i % 2 == 0) and CYAN or WHITE })
		seg.CFrame = CFrame.lookAt((a + b) / 2, b)
		seg.Parent = self.folder
		table.insert(parts, seg)
	end
	local flash = part({ Name = "Flash", Size = Vector3.one * 0.2, Transparency = 1, Position = to })
	local pl = Instance.new("PointLight") pl.Color = CYAN pl.Range = 14 pl.Brightness = 6 pl.Parent = flash
	flash.Parent = self.folder
	table.insert(parts, flash)
	-- scorch ring where it hits
	self:shockwaveSmall(to)
	task.delay(0.08, function()
		for _, p in ipairs(parts) do
			if p:IsA("BasePart") and p.Name == "Bolt" then
				TweenService:Create(p, TweenInfo.new(0.15), { Transparency = 1 }):Play()
			end
		end
		TweenService:Create(pl, TweenInfo.new(0.2), { Brightness = 0 }):Play()
	end)
	task.delay(0.3, function() for _, p in ipairs(parts) do p:Destroy() end end)
end

function DeveloperAura:shockwaveSmall(pos)
	local p, sg = groundDecal(self.folder, 1)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.08, 0))
	local _, s = circleFrame(sg, 0.9, 8, WHITE, 0)
	local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(p, info, { Size = Vector3.new(6, 0.05, 6) }):Play()
	TweenService:Create(s, info, { Transparency = 1 }):Play()
	task.delay(0.45, function() p:Destroy() end)
end

function DeveloperAura:update(dt)
	local root = self.root
	if not root.Parent or not self.folder.Parent then
		self:Destroy()
		return
	end
	local now = os.clock()
	local t = now - self.t0
	local rp = root.Position

	-- ground height under the player
	local hit = workspace:Raycast(rp, Vector3.new(0, -14, 0), self.rayParams)
	if hit then
		self.groundY = hit.Position.Y
		self.groundMat, self.groundColor = hit.Material, hit.Instance.Color
	else
		self.groundY = rp.Y - 3
	end
	local gy = self.groundY

	self.center.CFrame = CFrame.new(rp)
	self.slab.CFrame = CFrame.new(rp.X, gy + 0.2, rp.Z)
	self.light.Brightness = 3 + math.sin(t * 4) * 1.5

	-- rune circle
	self.rune.CFrame = CFrame.new(rp.X, gy + 0.04, rp.Z)
	self.runeSpin.Rotation = (t * 25) % 360
	self.runeCounter.Rotation = (-t * 50) % 360

	-- gradients scroll
	local off = Vector2.new(math.sin(t * 1.5) * 0.5, 0)
	for _, g in ipairs(self.gradients) do g.Offset = off end

	-- letter rings
	for _, ring in ipairs(self.rings) do
		local tiltCF = CFrame.Angles(ring.tilt, 0, ring.tilt * 0.5)
		for _, item in ipairs(ring.items) do
			local a = item.phase + t * ring.speed
			local local3 = Vector3.new(math.cos(a) * ring.radius, 0, math.sin(a) * ring.radius)
			item.att.Position = tiltCF:VectorToWorldSpace(local3) + Vector3.new(0, ring.height + math.sin(t * 2 + item.phase) * 0.15, 0)
		end
	end

	-- helix
	for _, h in ipairs(self.helix) do
		local k = (h.phase + t * 0.25) % 1
		local a = k * math.pi * 6
		h.att.Position = Vector3.new(math.cos(a) * 2.4, -2.8 + k * 7, math.sin(a) * 2.4)
		h.label.TextTransparency = (k < 0.1) and (1 - k / 0.1) or ((k > 0.8) and ((k - 0.8) / 0.2) or 0)
	end

	-- wisps
	for i, w in ipairs(self.wisps) do
		local a = t * (2.5 + i * 0.4) + i * 2.1
		local y = math.sin(t * 1.3 + i) * 2.2
		local r = 2.2 + math.sin(t * 0.9 + i) * 0.4
		w.CFrame = CFrame.new(rp + Vector3.new(math.cos(a) * r, y, math.sin(a) * r))
	end

	-- cracks pulse
	for _, c in ipairs(self.cracks) do
		local dir = Vector3.new(math.cos(c.angle), 0, math.sin(c.angle))
		local startR = 2.5
		local mid = Vector3.new(rp.X, gy + 0.03, rp.Z) + dir * (startR + c.len / 2)
		c.part.CFrame = CFrame.lookAt(mid, mid + dir)
		c.part.Transparency = 0.25 + (math.sin(t * 6 + c.angle * 3) + 1) * 0.3
	end

	-- debris orbit
	for _, d in ipairs(self.debris) do
		local a = d.phase + t * d.speed
		local pos = Vector3.new(rp.X + math.cos(a) * d.radius, gy + d.height + math.sin(t * 1.7 + d.phase) * 0.5, rp.Z + math.sin(a) * d.radius)
		d.part.CFrame = CFrame.new(pos) * CFrame.Angles(t * d.spin.X, t * d.spin.Y, t * d.spin.Z)
		if self.groundMat and self.groundMat ~= Enum.Material.Air then
			d.part.Material = self.groundMat
			d.part.Color = self.groundColor
		end
	end

	-- events
	if now >= self.nextShock then
		self.nextShock = now + 2.4
		self:shockwave(Vector3.new(rp.X, gy, rp.Z))
	end
	if not self.low and now >= self.nextBolt then
		self.nextBolt = now + 0.5 + math.random() * 1.1
		local ang = math.random() * math.pi * 2
		local dist = math.random(40, 110) / 10
		local target = Vector3.new(rp.X + math.cos(ang) * dist, gy + 0.1, rp.Z + math.sin(ang) * dist)
		local ground = workspace:Raycast(target + Vector3.new(0, 6, 0), Vector3.new(0, -14, 0), self.rayParams)
		if ground then target = ground.Position end
		self:bolt(rp + Vector3.new(0, 1.5, 0), target)
	end
	if self.nameGhost and now >= self.nextGlitch then
		self.nextGlitch = now + 1 + math.random() * 2.5
		local g, m = self.nameGhost, self.nameMain
		task.spawn(function()
			for _ = 1, 4 do
				g.TextTransparency = 0.3
				g.Position = UDim2.fromOffset(math.random(-6, 6), math.random(-3, 3))
				m.Position = UDim2.fromOffset(math.random(-3, 3), 0)
				task.wait(0.04)
			end
			g.TextTransparency = 1
			m.Position = UDim2.new()
		end)
	end
end

function DeveloperAura:Destroy()
	if self.dead then return end
	self.dead = true
	active[self] = nil
	for _, c in ipairs(self.connections) do c:Disconnect() end
	if self.folder then self.folder:Destroy() end
end

--==================================================
-- the world tints purple around developers
--==================================================
local cc = Lighting:FindFirstChild("DevAuraTint")
if not cc then
	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DevAuraTint"
	cc.Parent = Lighting
end
cc.Enabled = false
local tintTarget = 0
local tint = 0
RunService.Heartbeat:Connect(function(dt)
	local cam = workspace.CurrentCamera
	local best = 0
	if cam then
		for aura in pairs(active) do
			if aura.root and aura.root.Parent then
				local d = (aura.root.Position - cam.CFrame.Position).Magnitude
				best = math.max(best, 1 - math.clamp((d - 12) / 28, 0, 1))
			end
		end
	end
	tintTarget = best
	tint += (tintTarget - tint) * math.min(1, dt * 4)
	if tint < 0.01 then
		cc.Enabled = false
		return
	end
	cc.Enabled = true
	local pulse = 1 + math.sin(os.clock() * 3) * 0.15
	cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(215, 190, 255), tint * pulse)
	cc.Saturation = 0.25 * tint
	cc.Contrast = 0.12 * tint
end)

return DeveloperAura
