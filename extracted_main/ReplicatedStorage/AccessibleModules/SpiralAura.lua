--==================================================
-- SPIRAL AURA  v2   (client, built entirely in code)
--
-- The reward for finishing the game: Gurren Lagann's
-- spiral power as a full area effect, not just a glow.
--
--   THE DRILL    three gold/emerald helix strands wound
--                around a white-hot core, tapering to a
--                spinning point overhead. The stripes are
--                what make it read as TURNING.
--   THE RUNE     a rune circle burned into the ground
--                under you -- three counter-rotating
--                rings, twelve glyphs, eight cracks that
--                breathe outward. It raycasts down, so it
--                lies flat on whatever you're standing on
--                instead of floating at a fixed height.
--   THE VORTEX   debris torn off the floor and dragged up
--                the drill, plus dust being sucked inward
--   THE ORBIT    three trailed shards on a tilted ring
--   THE PULSE    every few seconds the whole thing flares
--                and throws a shockwave across the ground;
--                landing from a jump does it too
--
-- Neon clips any channel near 255 straight to white, which
-- is why v1 read as a cloud of white flakes. Every colour
-- here is deliberately deep so the drill keeps its gold.
--
-- Used by TitleAura for any title whose Aura is "spiral".
--==================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SpiralAura = {}
SpiralAura.__index = SpiralAura

local GOLD    = Color3.fromRGB(255, 170, 20)
local AMBER   = Color3.fromRGB(226, 92, 10)
local EMERALD = Color3.fromRGB(18, 168, 78)
local LIME    = Color3.fromRGB(150, 235, 90)
local DEEP    = Color3.fromRGB(0, 70, 35)
local WHITE   = Color3.new(1, 1, 1)

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local STRANDS   = 3
local PER_STRAND = 13
-- The drill rises from the shoulders UP. Wrapping it round the body buried
-- the player in gold: you could not see who was wearing it, which rather
-- defeats the point of a reward aura.
local DRILL_BASE_R = 3.1
local DRILL_HEIGHT = 9
local DRILL_FOOT = 1.7

local container = workspace:FindFirstChild("ClientAuras")
if not container then
	container = Instance.new("Folder")
	container.Name = "ClientAuras"
	container.Parent = workspace
end

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
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do e[k] = v end
	e.Parent = parent
	return e
end

--==================================================

function SpiralAura.new(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local self = setmetatable({}, SpiralAura)
	self.character = character
	self.root = root
	self.humanoid = character:FindFirstChildOfClass("Humanoid")
	self.t0 = os.clock()
	self.connections = {}
	self.plates = {}
	self.rings = {}
	self.glyphs = {}
	self.cracks = {}
	self.circles = {}
	self.motes = {}
	self.orbiters = {}
	self.groundY = root.Position.Y - 3
	self.nextGroundCheck = 0
	self.nextPulse = 3

	local folder = Instance.new("Folder")
	folder.Name = "SpiralAura"
	folder.Parent = container
	self.folder = folder

	local budget = lowGraphics() and 0.45 or 1

	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.rayParams.FilterDescendantsInstances = { character, container }

	--------------------------------------------------
	-- THE DRILL
	--------------------------------------------------
	local strands = math.max(1, math.floor(STRANDS * budget))
	local perStrand = math.max(6, math.floor(PER_STRAND * budget))

	for s = 1, strands do
		local phase = (s - 1) / strands * math.pi * 2
		for i = 1, perStrand do
			local t = (i - 1) / math.max(perStrand - 1, 1)
			local size = 1.55 - t * 1.22
			-- every third segment is the dark emerald stripe: without it the
			-- helix is a smooth glow and you cannot see it rotating at all
			local stripe = (i % 3 == 0)
			local p = part({
				Name = "DrillPlate",
				Size = Vector3.new(size * 1.95, size * 0.3, size * 0.85),
				-- deliberately off max: Neon clips a 255 channel to white and the
				-- drill loses its colour entirely
				Color = stripe and EMERALD or Color3.fromRGB(236, 152, 18):Lerp(AMBER, t * 0.75),
				Material = stripe and Enum.Material.SmoothPlastic or Enum.Material.Neon,
				Transparency = stripe and 0.15 or 0.26,
				Parent = folder,
			})
			table.insert(self.plates, { p = p, t = t, turn = phase + t * math.pi * 4.6 })
		end
	end

	-- white-hot core running up the middle of the helix
	self.spine = part({
		Name = "DrillCore",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(DRILL_HEIGHT, 0.7, 0.7),
		Color = Color3.fromRGB(255, 236, 190),
		Transparency = 0.45,
		Parent = folder,
	})

	self.tip = part({
		Name = "DrillTip",
		Size = Vector3.new(0.95, 2.6, 0.95),
		Color = GOLD,
		Transparency = 0.02,
		Parent = folder,
	})
	local tipMesh = Instance.new("SpecialMesh")
	tipMesh.MeshType = Enum.MeshType.FileMesh
	tipMesh.MeshId = "rbxassetid://1033714"
	tipMesh.Scale = Vector3.new(0.55, 1.8, 0.55)
	tipMesh.Parent = self.tip

	--------------------------------------------------
	-- GALAXY RINGS on a tilted axis
	--------------------------------------------------
	for i = 1, 2 do
		local r = part({
			Name = "GalaxyRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 9.4 - i * 2.4, 9.4 - i * 2.4),
			Color = (i == 1) and GOLD or EMERALD,
			Material = Enum.Material.ForceField,
			Transparency = 0.35,
			Parent = folder,
		})
		table.insert(self.rings, { p = r, dir = (i == 1) and 1 or -1, tilt = math.rad(i == 1 and 28 or -34) })
	end

	--------------------------------------------------
	-- THE RUNE CIRCLE  (the area effect)
	--------------------------------------------------
	-- A Roblox cylinder is a solid DISC, not a ring -- laid on grass at any
	-- useful transparency it just tints the floor. Real rings are built out
	-- of short tangent segments, which is also what makes them look carved.
	local function segmentRing(radius, segments, colour, thickness)
		local ring = { parts = {}, radius = radius }
		for i = 1, segments do
			local seg = part({
				Name = "RuneRing",
				Size = Vector3.new(thickness, 0.07, (2 * math.pi * radius / segments) * 0.82),
				Color = colour,
				Transparency = 0.12,
				Parent = folder,
			})
			table.insert(ring.parts, { p = seg, angle = (i - 1) / segments * math.pi * 2 })
		end
		return ring
	end

	local segs = lowGraphics() and 12 or 22
	self.circles = {
		segmentRing(7.6, segs, GOLD, 0.34),
		segmentRing(5.1, math.floor(segs * 0.7), EMERALD, 0.26),
	}
	self.circles[1].dir, self.circles[1].speed = 1, 0.5
	self.circles[2].dir, self.circles[2].speed = -1, 0.85

	-- soft glow pool under the rings so the ground reads as lit, not painted
	self.pool = part({
		Name = "RunePool",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, 16, 16),
		Color = GOLD,
		Material = Enum.Material.ForceField,
		Transparency = 0.62,
		Parent = folder,
	})

	local glyphCount = lowGraphics() and 6 or 12
	for i = 1, glyphCount do
		local g = part({
			Name = "RuneGlyph",
			Size = Vector3.new(0.85, 0.06, 1.7),
			Color = GOLD,
			Transparency = 0.2,
			Parent = folder,
		})
		table.insert(self.glyphs, { p = g, angle = (i - 1) / glyphCount * math.pi * 2, tall = (i % 3 == 0) })
	end

	local crackCount = lowGraphics() and 4 or 8
	for i = 1, crackCount do
		local c = part({
			Name = "RuneCrack",
			Size = Vector3.new(0.3, 0.05, 6),
			Color = AMBER,
			Transparency = 0.25,
			Parent = folder,
		})
		table.insert(self.cracks, { p = c, angle = (i - 1) / crackCount * math.pi * 2 })
	end

	--------------------------------------------------
	-- DEBRIS VORTEX -- torn off the floor and dragged up
	--------------------------------------------------
	local moteCount = lowGraphics() and 6 or 14
	for i = 1, moteCount do
		local m = part({
			Name = "VortexShard",
			Size = Vector3.new(0.3 + math.random() * 0.35, 0.22, 0.3 + math.random() * 0.35),
			Color = (i % 2 == 0) and GOLD or LIME,
			Material = (i % 3 == 0) and Enum.Material.SmoothPlastic or Enum.Material.Neon,
			Transparency = 0.1,
			Parent = folder,
		})
		table.insert(self.motes, {
			p = m,
			phase = (i - 1) / moteCount,
			speed = 0.34 + math.random() * 0.2,
			spin = Vector3.new(math.random(), math.random(), math.random()).Unit * (3 + math.random() * 4),
		})
	end

	--------------------------------------------------
	-- ORBITERS -- three trailed shards on a tilted ring
	--------------------------------------------------
	local orbCount = lowGraphics() and 1 or 3
	for i = 1, orbCount do
		local o = part({
			Name = "SpiralShard",
			Size = Vector3.new(0.55, 0.55, 1.5),
			Color = (i == 2) and EMERALD or GOLD,
			Transparency = 0.05,
			Parent = folder,
		})
		local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, 0.25, 0) a0.Parent = o
		local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -0.25, 0) a1.Parent = o
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 0.5
		trail.LightEmission = 1
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Color = ColorSequence.new(GOLD, EMERALD)
		trail.Transparency = NumberSequence.new(0.25, 1)
		trail.Parent = o
		table.insert(self.orbiters, { p = o, phase = (i - 1) / orbCount * math.pi * 2 })
	end

	--------------------------------------------------
	-- CORE GLOW + PARTICLES
	--------------------------------------------------
	local core = part({ Name = "Core", Size = Vector3.one * 0.2, Transparency = 1, Parent = folder })
	self.core = core

	local light = Instance.new("PointLight")
	light.Color = GOLD
	-- kept modest: a big bright light on top of the game's bloom washed
	-- the whole screen out when you stood still
	light.Range = 15
	light.Brightness = 1.1
	light.Shadows = false
	light.Parent = core
	self.light = light

	emitter(core, {
		Name = "Helix", Texture = SPARK, Color = ColorSequence.new(GOLD, EMERALD), LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(8, 13),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(13, 13),
		Rate = lowGraphics() and 14 or 36, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300),
		Acceleration = Vector3.new(0, 7, 0),
	})
	emitter(core, {
		Name = "Mist", Texture = SMOKE, Color = ColorSequence.new(AMBER, DEEP), LightEmission = 0.9,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.74), NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(5, 11), Lifetime = NumberRange.new(1.2, 1.8),
		Speed = NumberRange.new(0.5, 1.5), Rate = lowGraphics() and 3 or 8,
		Acceleration = Vector3.new(0, 2.5, 0),
	})

	-- ground dust being pulled INTO the drill: negative speed + upward drag
	self.suck = part({ Name = "Suck", Size = Vector3.one * 0.2, Transparency = 1, Parent = folder })
	emitter(self.suck, {
		Name = "Intake", Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(120, 105, 70), DEEP),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.68), NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(3.5, 0.5), Lifetime = NumberRange.new(0.9, 1.4),
		-- negative speed = pulled inward. NumberRange wants min first, and
		-- getting that backwards throws, which kills the whole aura build.
		Speed = NumberRange.new(-22, -16), EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(180, 180), Rate = lowGraphics() and 5 or 16,
		Acceleration = Vector3.new(0, 16, 0), Drag = 1.5,
	})

	self.burst = emitter(core, {
		Name = "Burst", Texture = SPARK, Color = ColorSequence.new(GOLD, EMERALD), LightEmission = 1,
		Size = NumberSequence.new(1.3, 0), Lifetime = NumberRange.new(0.5, 0.95),
		Speed = NumberRange.new(30, 55), SpreadAngle = Vector2.new(180, 180),
		Rate = 0, Drag = 4, Enabled = false,
	})

	--------------------------------------------------
	-- NAMEPLATE
	--------------------------------------------------
	local head = character:FindFirstChild("Head") or root
	local bb = Instance.new("BillboardGui")
	bb.Name = "SpiralPlate"
	bb.Size = UDim2.fromScale(9, 1.5)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 4.4, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 150
	bb.Adornee = head
	bb.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "\u{2b50} SPIRAL POWER \u{2b50}"
	label.TextColor3 = WHITE
	label.Parent = bb
	local ls = Instance.new("UIStroke")
	ls.Thickness = 3
	ls.Color = DEEP
	ls.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ls.Parent = label
	self.plateGrad = Instance.new("UIGradient")
	self.plateGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(0.4, LIME),
		ColorSequenceKeypoint.new(0.6, WHITE),
		ColorSequenceKeypoint.new(1, EMERALD),
	})
	self.plateGrad.Parent = label
	self.nameplate = bb

	--------------------------------------------------
	-- HOOKS
	--------------------------------------------------
	if self.humanoid then
		table.insert(self.connections, self.humanoid.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Landed then
				self:shockwave()
			end
		end))
	end

	table.insert(self.connections, RunService.RenderStepped:Connect(function(dt)
		self:update(dt)
	end))

	self:shockwave()
	return self
end

--==================================================
-- the ground the rune sits on
--==================================================

function SpiralAura:refreshGround()
	local root = self.root
	if not root or not root.Parent then return end
	local origin = root.Position
	local hit = workspace:Raycast(origin, Vector3.new(0, -60, 0), self.rayParams)
	if hit then
		self.groundY = hit.Position.Y + 0.06
	else
		self.groundY = origin.Y - 3
	end
end

--==================================================
-- the pulse
--==================================================

function SpiralAura:shockwave()
	if not self.root or not self.root.Parent then return end
	local pos = Vector3.new(self.root.Position.X, self.groundY + 0.3, self.root.Position.Z)

	for i = 1, 2 do
		local ring = part({
			Name = "Shock", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 3, 3),
			Color = (i == 1) and GOLD or EMERALD, Material = Enum.Material.Neon,
			Transparency = 0.15,
			CFrame = CFrame.new(pos + Vector3.new(0, i * 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = self.folder,
		})
		TweenService:Create(ring,
			TweenInfo.new(0.7 + i * 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.22, 30 + i * 8, 30 + i * 8), Transparency = 1 }):Play()
		task.delay(0.95 + i * 0.15, function() if ring.Parent then ring:Destroy() end end)
	end

	-- the drill flares white for a moment
	self.flare = 1
	if self.burst then self.burst:Emit(26) end
end

--==================================================

function SpiralAura:update(dt)
	local root = self.root
	if not root or not root.Parent or not self.character.Parent then
		self:Destroy()
		return
	end

	local t = os.clock() - self.t0
	local centre = root.CFrame.Position
	local spin = t * 2.6
	local pulse = (math.sin(t * 3) + 1) / 2

	-- ground is only worth re-checking a few times a second
	if t > self.nextGroundCheck then
		self.nextGroundCheck = t + 0.1
		self:refreshGround()
	end
	local groundY = self.groundY
	local floor = Vector3.new(centre.X, groundY, centre.Z)

	-- periodic flare
	if t > self.nextPulse then
		self.nextPulse = t + 4.5
		self:shockwave()
	end
	self.flare = math.max((self.flare or 0) - dt * 2.2, 0)
	local flare = self.flare

	self.core.CFrame = CFrame.new(centre - Vector3.new(0, 2, 0))
	self.suck.CFrame = CFrame.new(floor + Vector3.new(0, 0.4, 0))
	self.light.Brightness = 0.9 + pulse * 0.7 + flare * 2

	--------------------------------------------------
	-- drill
	--------------------------------------------------
	for _, plate in ipairs(self.plates) do
		local a = plate.turn + spin
		local r = DRILL_BASE_R - plate.t * (DRILL_BASE_R - 0.35)
		local y = DRILL_FOOT + plate.t * DRILL_HEIGHT + math.sin(t * 2 + plate.t * 6) * 0.12
		local pos = centre + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		plate.p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0.6, math.cos(a)))
			* CFrame.Angles(0, 0, math.rad(24))
		if plate.p.Material == Enum.Material.Neon then
			plate.p.Transparency = math.max(0.26 - flare * 0.2, 0)
			plate.p.Color = Color3.fromRGB(236, 152, 18):Lerp(WHITE, flare * 0.7)
		end
	end

	self.spine.CFrame = CFrame.new(centre + Vector3.new(0, DRILL_FOOT + DRILL_HEIGHT / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	self.spine.Transparency = 0.48 - flare * 0.3

	self.tip.CFrame = CFrame.new(centre + Vector3.new(0, DRILL_FOOT + DRILL_HEIGHT + 0.5 + math.sin(t * 2) * 0.2, 0))
		* CFrame.Angles(0, spin * 2.2, 0)

	--------------------------------------------------
	-- galaxy rings
	--------------------------------------------------
	for _, ring in ipairs(self.rings) do
		ring.p.CFrame = CFrame.new(centre)
			* CFrame.Angles(ring.tilt, t * 1.1 * ring.dir, math.sin(t * 0.8) * 0.2)
			* CFrame.Angles(0, 0, math.rad(90))
	end

	--------------------------------------------------
	-- rune circle on the floor
	--------------------------------------------------
	self.pool.CFrame = CFrame.new(floor + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90))
	self.pool.Transparency = 0.64 + pulse * 0.1 - flare * 0.25

	for i, ring in ipairs(self.circles) do
		local spinOffset = t * ring.speed * ring.dir
		local r = ring.radius + math.sin(t * 1.6 + i) * 0.18 + flare * 0.9
		local alpha = 0.12 + pulse * 0.12 - flare * 0.12
		for _, seg in ipairs(ring.parts) do
			local a = seg.angle + spinOffset
			seg.p.CFrame = CFrame.new(floor + Vector3.new(math.cos(a) * r, 0.05 + i * 0.03, math.sin(a) * r))
				* CFrame.Angles(0, -a, 0)
			seg.p.Transparency = alpha
		end
	end

	local glyphR = 4.6 + math.sin(t * 1.3) * 0.3
	for _, g in ipairs(self.glyphs) do
		local a = g.angle + t * 0.55
		local h = g.tall and 0.5 or 0.1
		g.p.CFrame = CFrame.new(floor + Vector3.new(math.cos(a) * glyphR, 0.16 + h, math.sin(a) * glyphR))
			* CFrame.Angles(0, -a, 0)
		g.p.Transparency = 0.2 + math.sin(t * 4 + g.angle * 3) * 0.14 - flare * 0.2
	end

	for _, c in ipairs(self.cracks) do
		local a = c.angle - t * 0.28
		local reach = 6 + math.sin(t * 2.2 + c.angle * 2) * 2.2 + flare * 5
		c.p.Size = Vector3.new(0.3, 0.05, reach)
		c.p.CFrame = CFrame.new(floor + Vector3.new(math.cos(a) * (reach / 2 + 1.6), 0.1, math.sin(a) * (reach / 2 + 1.6)))
			* CFrame.Angles(0, -a + math.pi / 2, 0)
		c.p.Transparency = 0.3 + pulse * 0.25 - flare * 0.3
	end

	--------------------------------------------------
	-- debris vortex
	--------------------------------------------------
	for _, m in ipairs(self.motes) do
		local k = (m.phase + t * m.speed) % 1
		local a = k * math.pi * 6
		local r = 6.2 - k * 5.4
		-- funnel up off the floor and into the base of the drill
		local y = groundY + 0.2 + k * (centre.Y + DRILL_FOOT + 1.5 - groundY)
		m.p.CFrame = CFrame.new(centre.X + math.cos(a) * r, y, centre.Z + math.sin(a) * r)
			* CFrame.Angles(t * m.spin.X, t * m.spin.Y, t * m.spin.Z)
		-- fade in off the floor, fade out into the tip
		m.p.Transparency = 0.08 + math.max(0, (k - 0.75) / 0.25) * 0.9 + math.max(0, (0.08 - k) / 0.08) * 0.9
	end

	--------------------------------------------------
	-- orbiters
	--------------------------------------------------
	for _, o in ipairs(self.orbiters) do
		local a = o.phase + t * 1.5
		local r = 5.4
		local y = centre.Y + math.sin(a * 2) * 2.2
		local pos = Vector3.new(centre.X + math.cos(a) * r, y, centre.Z + math.sin(a) * r)
		o.p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0.2, math.cos(a)))
	end

	self.plateGrad.Offset = Vector2.new(math.sin(t * 1.1) * 0.6, 0)
end

function SpiralAura:Destroy()
	for _, connection in ipairs(self.connections) do
		pcall(function() connection:Disconnect() end)
	end
	self.connections = {}
	if self.nameplate then pcall(function() self.nameplate:Destroy() end) end
	self.nameplate = nil
	if self.folder then self.folder:Destroy() end
	self.folder = nil
end

return SpiralAura
