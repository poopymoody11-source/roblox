--==================================================
-- SKY ATMOSPHERE  v3  (client)
--
-- One feeling: you are a very long way up, standing on
-- nothing, above an unbroken floor of cloud with a
-- mountain range somewhere far below it.
--
-- The static half of that lives in Workspace.Horizon
-- (the cloud deck and the studded peaks, built once in
-- Edit mode). This script does the moving half:
--
--   1  DECK FOG    puffs riding on the cloud deck so it
--                  reads as cloud rather than a white
--                  floor. The deck is real geometry --
--                  particles alone leave gaps you can see
--                  straight through from above.
--   2  UNDER FOG   thick mist hanging under every island
--                  and spilling off its rim. This is what
--                  sells "floating": the islands end in
--                  weather, not in a clean cut.
--   3  HIGH CLOUDS Roblox's own volumetric layer above.
--   4  DRIFTERS    banks passing between the islands.
--   5  WISPS       thin streaks ripping past the camera.
--                  Parallax is the real altitude cue.
--   6  BIRDS       V-flocks with flapping wings.
--   7  TRIM        atmosphere tuned so the horizon
--                  SURVIVES -- the old density+offset
--                  erased everything past ~2000 studs,
--                  which is exactly where the peaks are.
--
-- Everything is client-side and graphics-budgeted.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer

local function lowGraphics()
	return player:GetAttribute("Set_LowGraphics") == true
end
local LOW = lowGraphics()

local WORLD_CENTRE = Vector3.new(160, 250, 1420)
local DECK_Y = -150       -- must match Workspace.Horizon.CloudDeck
local DRIFT_Y = 190

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

--==================================================
-- 7. LIGHTING TRIM
--==================================================

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	-- Enough haze that the cloud deck dissolves into the sky at distance.
	-- Too little and it ends as a hard white plane against the horizon; too
	-- much (the v2 numbers) and it erases the peaks entirely.
	atmosphere.Density = 0.34
	atmosphere.Offset = 0.1
	atmosphere.Haze = 1.05
	atmosphere.Glare = 0.2
	atmosphere.Color = Color3.fromRGB(212, 228, 248)
	atmosphere.Decay = Color3.fromRGB(126, 150, 194)
end

local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then
	dof.FarIntensity = 0.12
	dof.FocusDistance = 60
	dof.InFocusRadius = 420
	dof.NearIntensity = 0
end

if not LOW then
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if not rays then
		rays = Instance.new("SunRaysEffect")
		rays.Name = "SkyGlare"
		rays.Parent = Lighting
	end
	rays.Intensity = 0.06
	rays.Spread = 0.9
end

--==================================================
-- 3. HIGH CLOUDS
--==================================================

pcall(function()
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then return end
	local clouds = terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Parent = terrain
	end
	clouds.Enabled = true
	clouds.Cover = LOW and 0.42 or 0.58
	clouds.Density = LOW and 0.4 or 0.62
	clouds.Color = Color3.fromRGB(253, 254, 255)
end)

--==================================================
-- SCAFFOLDING
--==================================================

local holder = workspace:FindFirstChild("SkyAmbience")
if holder then holder:Destroy() end
holder = Instance.new("Folder")
holder.Name = "SkyAmbience"
holder.Parent = workspace

local function anchor(cframe, size, name)
	local p = Instance.new("Part")
	p.Name = name or "Anchor"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Locked = true
	p.Transparency = 1
	p.Size = size
	p.CFrame = cframe
	p.Parent = holder
	return p
end

local function puffEmitter(host, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.LightInfluence = 1
	e.LockedToPart = false
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-2, 2)
	e.SpreadAngle = Vector2.new(6, 6)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	for k, v in pairs(props) do e[k] = v end
	e.Parent = host
	return e
end

--==================================================
-- 1. DECK FOG
--
-- Sits ON the geometry deck and breaks its surface up.
-- Concentrated where you can actually see it (under and
-- around the islands) rather than spread evenly over
-- eighteen thousand studs of it.
--==================================================

local deckStations = LOW and 10 or 30
for i = 1, deckStations do
	local a = (i - 1) / deckStations * math.pi * 2 * 2.4   -- spiral out, not a ring
	local r = 300 + (i / deckStations) * 3200 + math.random(0, 500)
	local pos = Vector3.new(
		WORLD_CENTRE.X + math.cos(a) * r,
		DECK_Y + 26 + math.random(0, 40),
		WORLD_CENTRE.Z + math.sin(a) * r)
	local host = anchor(CFrame.new(pos), Vector3.new(900, 30, 900), "DeckFog")
	puffEmitter(host, {
		-- brighter than the deck underneath it, so the lumps have relief
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(240, 248, 255)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.18, 0.08),
			NumberSequenceKeypoint.new(0.82, 0.08),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(math.random(340, 640)),
		Lifetime = NumberRange.new(50, 85),
		Speed = NumberRange.new(1, 4),
		Rate = LOW and 0.14 or 0.26,
		Acceleration = Vector3.new(1.4, 0, 0.7),
		ZOffset = -6,
	})
end

--==================================================
-- 2. UNDER-ISLAND FOG
--
-- Two parts per island: a deep column of mist hanging
-- underneath, and a thinner skirt spilling over the rim.
--==================================================

local function fogUnder(islandModel)
	local mn, mx
	for _, d in ipairs(islandModel:GetDescendants()) do
		if d:IsA("BasePart") then
			local p, h = d.Position, d.Size / 2
			mn = mn and mn:Min(p - h) or p - h
			mx = mx and mx:Max(p + h) or p + h
		end
	end
	if not mn then return end
	local centre = (mn + mx) / 2
	local width = math.max(mx.X - mn.X, mx.Z - mn.Z)

	-- the column: big, slow, heavy, falling away underneath
	local column = anchor(
		CFrame.new(centre.X, mn.Y - 30, centre.Z),
		Vector3.new(width * 0.85, 130, width * 0.85), "IslandFog")
	puffEmitter(column, {
		Color = ColorSequence.new(Color3.fromRGB(250, 253, 255), Color3.fromRGB(196, 218, 246)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.38),
			NumberSequenceKeypoint.new(0.75, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(width * 0.3, width * 0.62),
		Lifetime = NumberRange.new(12, 20),
		Speed = NumberRange.new(1, 4),
		Rate = LOW and 1.2 or 3.4,
		SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0.6, -2.4, 0.4),
		ZOffset = -3,
	})

	-- the skirt: thin stuff clinging to the underside and peeling off the rim
	local skirt = anchor(
		CFrame.new(centre.X, mn.Y + 22, centre.Z),
		Vector3.new(width * 1.02, 26, width * 1.02), "IslandSkirt")
	puffEmitter(skirt, {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 232, 252)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(width * 0.16, width * 0.34),
		Lifetime = NumberRange.new(9, 15),
		Speed = NumberRange.new(2, 6),
		Rate = LOW and 1 or 2.8,
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(1.2, -1.2, 0.8),
		ZOffset = -2,
	})
end

task.spawn(function()
	local islands = workspace:WaitForChild("Islands", 30)
	if not islands then return end
	for _, island in ipairs(islands:GetChildren()) do
		pcall(fogUnder, island)
	end
end)

--==================================================
-- 4. DRIFTERS
--==================================================

local drifters = {}
local driftCount = LOW and 3 or 7
for i = 1, driftCount do
	local a = (i - 1) / driftCount * math.pi * 2
	local radius = 520 + math.random(0, 520)
	local host = anchor(CFrame.new(WORLD_CENTRE), Vector3.new(220, 50, 220), "Drifter")
	puffEmitter(host, {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(222, 236, 252)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.42),
			NumberSequenceKeypoint.new(0.75, 0.42),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(math.random(150, 260)),
		Lifetime = NumberRange.new(22, 36),
		Speed = NumberRange.new(2, 6),
		Rate = LOW and 0.12 or 0.28,
		Acceleration = Vector3.new(0, 0.2, 0),
		ZOffset = -3,
	})
	table.insert(drifters, {
		p = host, angle = a, radius = radius,
		y = DRIFT_Y + math.random(-90, 170),
		speed = 0.005 + math.random() * 0.009,
		bob = math.random() * 10,
	})
end

--==================================================
-- 5. WISPS
--==================================================

local wispAnchor = anchor(CFrame.new(WORLD_CENTRE), Vector3.new(120, 50, 120), "Wisps")
local wisps = Instance.new("ParticleEmitter")
wisps.Texture = SMOKE
wisps.LightInfluence = 1
wisps.Color = ColorSequence.new(Color3.new(1, 1, 1))
wisps.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0.72),
	NumberSequenceKeypoint.new(0.8, 0.78),
	NumberSequenceKeypoint.new(1, 1),
})
wisps.Size = NumberSequence.new(22, 46)
wisps.Lifetime = NumberRange.new(2.4, 4)
wisps.Speed = NumberRange.new(60, 105)
wisps.SpreadAngle = Vector2.new(9, 4)
wisps.Rate = LOW and 0.5 or 1.6
wisps.Shape = Enum.ParticleEmitterShape.Box
wisps.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
wisps.Squash = NumberSequence.new(1.8)
wisps.ZOffset = -2
wisps.Parent = wispAnchor

--==================================================
-- 6. MOTES AROUND THE PLAYER
--==================================================

local moteAnchor = anchor(CFrame.new(WORLD_CENTRE), Vector3.new(70, 40, 70), "Motes")
local motes = Instance.new("ParticleEmitter")
motes.Texture = SPARK
motes.Color = ColorSequence.new(Color3.fromRGB(255, 255, 240), Color3.fromRGB(200, 230, 255))
motes.LightEmission = 0.8
motes.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.25, 0.45),
	NumberSequenceKeypoint.new(0.75, 0.45),
	NumberSequenceKeypoint.new(1, 1),
})
motes.Size = NumberSequence.new(0.22, 0.05)
motes.Lifetime = NumberRange.new(4, 8)
motes.Speed = NumberRange.new(0.5, 2)
motes.Rate = LOW and 4 or 14
motes.SpreadAngle = Vector2.new(180, 180)
motes.Shape = Enum.ParticleEmitterShape.Box
motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
motes.Acceleration = Vector3.new(0.4, 0.6, 0)
motes.Parent = moteAnchor

--==================================================
-- BIRDS  v3
--
-- Gull-style silhouettes: a body, head and tail, and two-part wings that
-- bend at the elbow so the downstroke reads as a real flap instead of a
-- see-saw. Most are dark, some are white gulls. Every bird alternates
-- bursts of flapping with long glides, and every group flies its own
-- looping path at its own height, so the sky is scattered rather than
-- a handful of circles round the same point. All moved in one BulkMoveTo.
--==================================================

local BIRD_TONES = {
	Color3.fromRGB(46, 44, 56), Color3.fromRGB(58, 54, 66), Color3.fromRGB(38, 38, 48),
	Color3.fromRGB(236, 238, 244), Color3.fromRGB(214, 218, 228),
}
local birdParts, birdCFrames = {}, {}

local function birdPart(class, size, colour, model)
	local p = Instance.new(class)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Locked = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = colour
	p.Size = size
	p.Parent = model
	return p
end

local function makeBird(scale)
	local model = Instance.new("Model")
	model.Name = "Bird"
	model.Parent = holder
	local tone = BIRD_TONES[math.random(#BIRD_TONES)]
	local tip = tone:Lerp(Color3.new(0, 0, 0), 0.35)
	local bird = { model = model, scale = scale }
	bird.body = birdPart("Part", Vector3.new(0.5, 0.42, 1.7) * scale, tone, model)
	bird.head = birdPart("Part", Vector3.new(0.34, 0.32, 0.4) * scale, tone, model)
	bird.tail = birdPart("WedgePart", Vector3.new(0.5, 0.1, 0.8) * scale, tip, model)
	bird.wings = {}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(bird.wings, {
			side = side,
			inner = birdPart("Part", Vector3.new(1.3, 0.08, 0.72) * scale, tone, model),
			outer = birdPart("WedgePart", Vector3.new(0.08, 0.6, 1.5) * scale, tip, model),
		})
	end
	return bird
end

local flocks = {}
local function makeFlock(count, centre, radius, height, speed, scale, formation)
	formation = formation or "scatter"
	local list = {}
	for i = 1, count do
		local b = makeBird(scale * (0.85 + math.random() * 0.3))
		if formation == "v" then
			local rank = math.ceil(i / 2)
			local side = (i % 2 == 0) and 1 or -1
			b.slot = (i == 1) and Vector3.zero or Vector3.new(side * rank * 2.6 * scale, rank * 0.35 * scale, rank * 3.1 * scale)
			b.wander = 0.25 * scale
		else
			local spread = (formation == "pair") and 3.5 or ((formation == "lone") and 0 or 11)
			b.slot = Vector3.new(
				(math.random() - 0.5) * spread * 2.4 * scale,
				(math.random() - 0.5) * spread * 1.2 * scale,
				(math.random() - 0.15) * spread * 2.8 * scale)
			b.wander = (formation == "pair") and 0.8 * scale or 2.4 * scale
		end
		b.flapOffset = math.random() * math.pi * 2
		b.flapSpeed = 7 + math.random() * 3
		b.glideOffset = math.random() * 20
		b.glideRate = 0.18 + math.random() * 0.12
		b.wobbleA = math.random() * math.pi * 2
		b.wobbleB = math.random() * math.pi * 2
		b.wobbleRate = 0.35 + math.random() * 0.5
		table.insert(list, b)
	end
	-- each group gets its own figure-of-eight-ish loop, not a shared circle
	table.insert(flocks, {
		birds = list, centre = centre, radius = radius, height = height, speed = speed,
		phase = math.random() * math.pi * 2,
		squash = 0.45 + math.random() * 0.55,
		twist = math.random() * math.pi * 2,
		dir = (math.random() < 0.5) and 1 or -1,
		formation = formation,
	})
end

do
	local rng = Random.new(1337)
	local function around(r0, r1)
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(r0, r1)
		return Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
	end
	if not LOW then
		-- loose scatters spread right round the islands at every height
		for i = 1, 7 do
			local c = WORLD_CENTRE + around(150, 950) + Vector3.new(0, rng:NextNumber(-60, 320), 0)
			makeFlock(rng:NextInteger(6, 11), c, rng:NextNumber(180, 520), rng:NextNumber(20, 60), rng:NextNumber(0.07, 0.16), rng:NextNumber(1.6, 3.2), "scatter")
		end
		-- two proper Vs
		makeFlock(7, WORLD_CENTRE + around(300, 700) + Vector3.new(0, 90, 0), 380, 26, 0.12, 2, "v")
		makeFlock(5, WORLD_CENTRE + around(500, 900) + Vector3.new(0, 240, 0), 520, 30, 0.09, 2.6, "v")
		-- pairs and singles everywhere else
		for i = 1, 6 do
			makeFlock(2, WORLD_CENTRE + around(100, 1100) + Vector3.new(0, rng:NextNumber(-40, 280), 0), rng:NextNumber(150, 500), 30, rng:NextNumber(0.1, 0.22), rng:NextNumber(1.3, 2.4), "pair")
		end
		for i = 1, 8 do
			makeFlock(1, WORLD_CENTRE + around(80, 1200) + Vector3.new(0, rng:NextNumber(-60, 340), 0), rng:NextNumber(120, 600), 40, rng:NextNumber(0.1, 0.26), rng:NextNumber(1.2, 2.6), "lone")
		end
		-- a few birds round the starter island itself, close enough to see
		makeFlock(6, Vector3.new(145, 205, 1480), 190, 22, 0.18, 1.3, "scatter")
		makeFlock(2, Vector3.new(60, 180, 1600), 120, 16, 0.24, 1.1, "pair")
	else
		makeFlock(7, WORLD_CENTRE + Vector3.new(-380, 150, 260), 340, 40, 0.13, 2.4, "scatter")
		makeFlock(5, WORLD_CENTRE + Vector3.new(420, 60, -300), 260, 26, 0.17, 1.9, "v")
		makeFlock(5, Vector3.new(145, 205, 1480), 190, 22, 0.18, 1.3, "scatter")
	end
end

local function place(p, cf)
	local n = #birdParts + 1
	birdParts[n] = p
	birdCFrames[n] = cf
end

local function updateBirds(t)
	table.clear(birdParts)
	table.clear(birdCFrames)
	for _, flock in ipairs(flocks) do
		local a = flock.phase + t * flock.speed * flock.dir
		-- loop shape: an ellipse with a figure-eight wobble, rotated per flock
		local function pathAt(ang)
			local x = math.cos(ang) * flock.radius
			local z = math.sin(ang) * flock.radius * flock.squash + math.sin(ang * 2) * flock.radius * 0.2
			local off = CFrame.Angles(0, flock.twist, 0):VectorToWorldSpace(Vector3.new(x, 0, z))
			return flock.centre + off + Vector3.new(0, math.sin(ang * 1.5) * flock.height * 0.4, 0)
		end
		local lead = pathAt(a)
		local heading = pathAt(a + 0.02 * flock.dir) - lead
		if heading.Magnitude < 1e-4 then heading = Vector3.new(0, 0, -1) end
		local base = CFrame.lookAt(lead, lead + heading)

		for _, b in ipairs(flock.birds) do
			local s = b.scale
			local wob = Vector3.new(
				math.sin(t * b.wobbleRate + b.wobbleA),
				math.sin(t * b.wobbleRate * 1.37 + b.wobbleB) * 0.7,
				math.cos(t * b.wobbleRate * 0.81 + b.wobbleA)) * b.wander
			-- bank into the turn, plus a little personal roll
			local bank = math.rad(22) * math.sin(a * 2) * flock.dir + math.rad(6) * math.sin(t * b.wobbleRate + b.wobbleB)
			local body = base * CFrame.new(b.slot + wob) * CFrame.Angles(0, 0, bank)
			place(b.body, body)
			place(b.head, body * CFrame.new(0, 0.12 * s, -1.0 * s))
			place(b.tail, body * CFrame.new(0, 0.02 * s, 1.15 * s) * CFrame.Angles(0, math.rad(180), 0))

			-- glide most of the time, flap in bursts
			local glide = math.sin(t * b.glideRate + b.glideOffset)
			local flap = (glide > 0.35) and math.sin(t * b.flapSpeed + b.flapOffset)
				or (0.12 + math.sin(t * 1.3 + b.flapOffset) * 0.05)
			for _, w in ipairs(b.wings) do
				local side = w.side
				local shoulder = body * CFrame.new(side * 0.22 * s, 0.1 * s, -0.1 * s)
				local innerCF = shoulder * CFrame.Angles(0, 0, side * math.rad(38) * flap) * CFrame.new(side * 0.65 * s, 0, 0)
				place(w.inner, innerCF)
				-- the outer wing folds against the stroke: that bend is what
				-- makes it look like a bird, not a propeller
				local elbow = innerCF * CFrame.new(side * 0.65 * s, 0, 0)
				place(w.outer, elbow * CFrame.Angles(0, 0, -side * math.rad(26) * flap) * CFrame.new(side * 0.72 * s, 0, 0.1 * s)
					* CFrame.Angles(0, 0, side * math.rad(90)))
			end
		end
	end
	if #birdParts > 0 then
		workspace:BulkMoveTo(birdParts, birdCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

--==================================================
-- DRIFT
--==================================================

RunService.RenderStepped:Connect(function()
	local t = os.clock()

	for _, c in ipairs(drifters) do
		local a = c.angle + t * c.speed
		c.p.CFrame = CFrame.new(
			WORLD_CENTRE.X + math.cos(a) * c.radius,
			c.y + math.sin(t * 0.1 + c.bob) * 8,
			WORLD_CENTRE.Z + math.sin(a) * c.radius)
	end

	updateBirds(t)

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		moteAnchor.CFrame = CFrame.new(root.Position)
		wispAnchor.CFrame = CFrame.new(root.Position + Vector3.new(-140, 22, 30))
	end
end)
