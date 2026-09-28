--==================================================
-- CHAPTERS 3-5: SPACE, DRAG, VORTEX
-- One continuous solar system, shared by all three chapters.
--
-- SPACE  (17s) hovering in Earth orbit, calm and stable, while the
--        whole solar system turns: the sun, the planets on their
--        orbits with their moons, comets, the asteroid belt and the
--        icy comet belt. Then, on the far side of the sun, a GIANT
--        Anti-Spiral portal tears open and a colossal hand pushes
--        out of it, and everything starts to be pulled toward it.
-- DRAG   (13s) the pull takes the party: launched across the solar
--        system, smashing straight through the Moon, a comet, Mars
--        and Jupiter as everything is sucked toward the portal.
-- VORTEX (17s) past the hand, through Saturn's rings, into the
--        swirl... at the very edge they turn to look back, and
--        everything freezes: the whole world they're leaving, held
--        mid-fall, while sad piano plays. Then it takes them.
--        (the PORTAL chapter in ChHole carries on from there)
--
-- Everything moves on one clock T (seconds since SPACE began), so
-- the three chapters line up exactly and time can be frozen.
--==================================================
local Ch = {}

local pi = math.pi
local EARTH_R = 1000
local HOVER = 380              -- the party's height above the Earth
local SUN_DIST = 16000         -- Earth -> Sun
local PORTAL_BEHIND = 30000    -- Sun -> portal, on the far side
local PORTAL_R = 3000          -- the dark core
local T_OPEN = 11.0            -- (SPACE clock) the portal tears open
local T_HAND = 12.2            -- the hand pushes out
local T_PULL = 13.8            -- the pull begins
local T_FREEZE = 41.5          -- (VORTEX t = 11.5) they look back: time stops
local T_THAW = 45.8            -- ...and it takes them
local T_END = 47

local function O(ctx) return ctx.TL.SpaceOrigin end
local function earthCenter(ctx) return O(ctx) + Vector3.new(0, -EARTH_R - HOVER, 0) end

local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

--------------------------------------------------------------------------
-- the frame of the solar system, from the direction the light comes from
--------------------------------------------------------------------------
local function solarFrame(ctx, lightDir)
	local SOL = ctx.SOL
	local ec = earthCenter(ctx)
	local d = lightDir.Unit
	SOL.D = d
	SOL.S = ec + d * SUN_DIST
	-- the orbital plane (ecliptic): contains the Earth-Sun line, tilted up a little
	local up = (Vector3.yAxis - d * d:Dot(Vector3.yAxis)).Unit
	SOL.N = up
	SOL.A = -d                          -- from the sun toward the Earth (angle 0)
	SOL.B = up:Cross(SOL.A).Unit
	SOL.Pp = SOL.S + d * PORTAL_BEHIND + up * 7000
	SOL.Axis = (SOL.S - SOL.Pp).Unit    -- the portal faces the solar system
end

local function orbitPos(SOL, center, radius, ang, incl)
	local p = center + (SOL.A * math.cos(ang) + SOL.B * math.sin(ang)) * radius
	if incl then p = p + SOL.N * math.sin(ang + incl[2]) * radius * incl[1] end
	return p
end

-- monotone interpolation through (T, value) keys (no overshoot)
local function monotone(keys, x)
	local n = #keys
	if x <= keys[1][1] then return keys[1][2] end
	if x >= keys[n][1] then return keys[n][2] end
	local i = 1
	while keys[i + 1][1] < x do i += 1 end
	local function slope(k)
		if k <= 1 then return (keys[2][2] - keys[1][2]) / (keys[2][1] - keys[1][1]) end
		if k >= n then return (keys[n][2] - keys[n - 1][2]) / (keys[n][1] - keys[n - 1][1]) end
		local s0 = (keys[k][2] - keys[k - 1][2]) / (keys[k][1] - keys[k - 1][1])
		local s1 = (keys[k + 1][2] - keys[k][2]) / (keys[k + 1][1] - keys[k][1])
		if s0 * s1 <= 0 then return 0 end
		return 2 / (1 / s0 + 1 / s1)
	end
	local x0, y0, x1, y1 = keys[i][1], keys[i][2], keys[i + 1][1], keys[i + 1][2]
	local h = x1 - x0
	local u = (x - x0) / h
	local m0, m1 = slope(i) * h, slope(i + 1) * h
	local u2, u3 = u * u, u * u * u
	return (2 * u3 - 3 * u2 + 1) * y0 + (u3 - 2 * u2 + u) * m0 + (-2 * u3 + 3 * u2) * y1 + (u3 - u2) * m1
end

-- how far along the flight to the portal the party is (0..1), by the solar clock
local FLIGHT = {
	{ 17, 0 }, { 18.8, 0.02 }, { 21.2, 0.075 }, { 23.4, 0.165 }, { 27.5, 0.36 }, { 30, 0.45 },
	{ 33.6, 0.63 }, { 38, 0.83 }, { T_FREEZE, 0.93 },
}
-- the crash targets and where along the flight they're met
local CRASH = {
	{ Key = "Moon",    T = 18.8, F = 0.02 },
	{ Key = "Comet1",  T = 21.2, F = 0.075 },
	{ Key = "Mars",    T = 23.4, F = 0.165 },
	{ Key = "Jupiter", T = 27.5, F = 0.36 },
	{ Key = "Saturn",  T = 33.6, F = 0.63, Rings = true },
}

--------------------------------------------------------------------------
-- BUILD
--------------------------------------------------------------------------
function Ch.build(ctx)
	local K = ctx.kit
	local rng = Random.new(77)
	local set = Instance.new("Folder")
	set.Name = "SolarSet"
	ctx.sets.Solar = set
	ctx.SOL = { Bodies = {}, ByKey = {}, Rims = {}, Comets = {}, Rocks = {}, Emitters = {} }
	local SOL = ctx.SOL
	solarFrame(ctx, Vector3.new(-0.742, 0.539, -0.399))
	local host = K.part({ Name = "SolarHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(SOL.S) }, set)
	SOL.Host = host

	local function rim(color, alpha, width)
		local r = K.softRing(host, 40, 1, 2, {
			Texture = "1084982817", Brightness = 2.4, Alpha = alpha or 0.8, Segments = 6,
			ColorSeq = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color),
			Profile = { 0, 0, 0.18, 1, 0.45, 0.55, 1, 0 },
		})
		r.Width = width or 0.06
		return r
	end
	local function body(key, name, diameter, opts)
		opts = opts or {}
		local p = K.planet(name, diameter, CFrame.new(SOL.S), set)
		if not p then return nil end
		p.CastShadow = false
		local b = {
			Key = key, Part = p, R = diameter / 2, D = diameter, Size0 = p.Size,
			Orbit = opts.Orbit, Parent = opts.Parent, Spin = opts.Spin or rng:NextNumber(0.02, 0.06),
			Tilt = CFrame.Angles(rng:NextNumber(-0.35, 0.35), 0, rng:NextNumber(-0.35, 0.35)),
			Suck = opts.Suck, Color = opts.Color or Color3.fromRGB(200, 200, 210),
		}
		local ring = p:FindFirstChild("Ring")
		if ring then
			b.Ring = ring
			b.RingRel = p.CFrame:ToObjectSpace(ring.CFrame)
			b.RingSize0 = ring.Size
		end
		if opts.Rim then b.Rim = rim(opts.Rim, opts.RimAlpha, opts.RimWidth) end
		table.insert(SOL.Bodies, b)
		SOL.ByKey[key] = b
		return b
	end

	--------------------------------------------------------------------
	-- the Sun: a blazing core, layered corona, rays and a lens flare
	--------------------------------------------------------------------
	local sun = K.Assets.PlanetMesh:Clone()
	sun.Name = "Sun"
	sun.TextureID = ""
	sun.Size = Vector3.one * 2000
	sun.Material = Enum.Material.Neon
	sun.Color = Color3.fromRGB(255, 214, 140)
	sun.Anchored = true
	sun.CanCollide = false
	sun.CanQuery = false
	sun.CastShadow = false
	sun.Parent = set
	SOL.Sun = sun
	SOL.SunGlows = {
		{ Q = K.quad(host, CFrame.new(SOL.S), 7000, 7000, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(255, 225, 170), Brightness = 3, Transparency = 0 }), S = 7000 },
		{ Q = K.quad(host, CFrame.new(SOL.S), 18000, 18000, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(255, 180, 110), Brightness = 1.6, Transparency = 0.25 }), S = 18000 },
		{ Q = K.quad(host, CFrame.new(SOL.S), 42000, 42000, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(255, 150, 90), Brightness = 0.7, Transparency = 0.55 }), S = 42000 },
	}
	SOL.SunRays = {}
	for i = 1, 6 do
		local q = K.quad(host, CFrame.new(SOL.S), 30000 + i * 2500, 260, "1084982817", { Color = Color3.fromRGB(255, 225, 190), Brightness = 1.4, Transparency = 0.55 })
		table.insert(SOL.SunRays, { Q = q, A = i / 6 * pi + rng:NextNumber(-0.2, 0.2), W = rng:NextNumber(-0.03, 0.03) })
	end
	SOL.Corona = K.softRing(host, 64, 1, 2, {
		Texture = "1084982817", Brightness = 3, Alpha = 0.95,
		ColorSeq = ColorSequence.new(Color3.fromRGB(255, 245, 220), Color3.fromRGB(255, 120, 40)),
		Profile = { 0, 1, 0.15, 0.9, 0.4, 0.45, 0.7, 0.15, 1, 0 },
	})
	local sl = Instance.new("PointLight")
	sl.Range = 60
	sl.Brightness = 2
	sl.Color = Color3.fromRGB(255, 220, 170)
	sl.Parent = sun

	--------------------------------------------------------------------
	-- the planets, their orbits and moons
	--   Orbit = { radius, phase (radians from the Earth's side), speed }
	--   Suck  = { start T, duration } for being pulled into the portal
	--------------------------------------------------------------------
	-- the Earth (a proper textured world now) + its air
	local earth = body("Earth", "earth", EARTH_R * 2, { Spin = 0.01, Rim = Color3.fromRGB(110, 175, 255), RimAlpha = 0.9, RimWidth = 0.05 })
	earth.Fixed = earthCenter(ctx)
	earth.Tilt = CFrame.Angles(math.rad(-20), 0, math.rad(23))
	local air = K.Assets.PlanetMesh:Clone()
	air.Name = "AirGlow"
	air.TextureID = ""
	air.Size = Vector3.one * (EARTH_R + 16) * 2
	air.Color = Color3.fromRGB(110, 170, 255)
	air.Material = Enum.Material.Neon
	air.Transparency = 0.9
	air.Anchored = true
	air.CanCollide = false
	air.CanQuery = false
	air.CastShadow = false
	air.CFrame = CFrame.new(earth.Fixed)
	air.Parent = set
	local airHL = Instance.new("Highlight")
	airHL.FillTransparency = 1
	airHL.OutlineColor = Color3.fromRGB(130, 190, 255)
	airHL.OutlineTransparency = 0.3
	airHL.DepthMode = Enum.HighlightDepthMode.Occluded
	airHL.Parent = air
	SOL.Air = air

	body("Moon", "moon", 540, { Parent = "Earth", Orbit = { 2900, 2.4, 0.035 }, Spin = 0.01, Rim = Color3.fromRGB(200, 200, 215), RimAlpha = 0.4 })
	body("Mercury", "mercury", 520, { Orbit = { 5600, 0.62, 0.075 }, Suck = { 19.5, 11 }, Rim = Color3.fromRGB(200, 170, 150), RimAlpha = 0.35 })
	body("Venus", "venus", 950, { Orbit = { 9800, -0.78, 0.05 }, Suck = { 21, 12.5 }, Rim = Color3.fromRGB(255, 215, 140), RimAlpha = 0.85 })
	body("Mars", "mars", 760, { Orbit = { 21500, 0.92, 0.026 }, Rim = Color3.fromRGB(255, 130, 90), RimAlpha = 0.6 })
	body("Jupiter", "jupiter", 2000, { Orbit = { 28500, 0.34, 0.016 }, Spin = 0.08, Rim = Color3.fromRGB(240, 200, 150), RimAlpha = 0.6 })
	body("Io", "io", 170, { Parent = "Jupiter", Orbit = { 1700, 0.3, 0.2 }, Suck = { 24, 7 } })
	body("Europa", "europa", 150, { Parent = "Jupiter", Orbit = { 2200, 2.1, 0.15 }, Suck = { 24.6, 7.5 } })
	body("Ganymede", "ganymede", 240, { Parent = "Jupiter", Orbit = { 2800, 3.9, 0.11 }, Suck = { 25.2, 8 } })
	body("Callisto", "callisto", 220, { Parent = "Jupiter", Orbit = { 3500, 5.2, 0.08 }, Suck = { 25.8, 8.5 } })
	body("Saturn", "saturn", 1800, { Orbit = { 35500, -0.42, 0.012 }, Spin = 0.07, Rim = Color3.fromRGB(255, 225, 160), RimAlpha = 0.55 })
	body("Titan", "titan", 230, { Parent = "Saturn", Orbit = { 2800, 1.2, 0.09 }, Suck = { 26, 9 } })
	body("Uranus", "uranus", 1250, { Orbit = { 41500, -1.18, 0.009 }, Suck = { 24, 16 }, Rim = Color3.fromRGB(150, 235, 255), RimAlpha = 0.8 })
	body("Neptune", "neptune", 1200, { Orbit = { 46500, 1.45, 0.007 }, Suck = { 25, 15 }, Rim = Color3.fromRGB(90, 140, 255), RimAlpha = 0.8 })
	body("Pluto", "pluto", 200, { Orbit = { 52000, 0.2, 0.005 }, Suck = { 20, 13 } })
	-- orbit inclinations (a real system isn't perfectly flat)
	for _, b in ipairs(SOL.Bodies) do
		if b.Orbit then b.Incl = { rng:NextNumber(-0.05, 0.05), rng:NextNumber(0, 2 * pi) } end
	end
	-- a glittering dust ring round Saturn's rings
	SOL.SaturnDust = K.softRing(host, 72, 1, 2, {
		Texture = "17000879366", Brightness = 1.6, Alpha = 0.5, Segments = 6,
		ColorSeq = ColorSequence.new(Color3.fromRGB(255, 235, 200), Color3.fromRGB(210, 190, 160)),
		Profile = { 0, 0, 0.1, 0.7, 0.35, 0.4, 0.5, 0.8, 0.75, 0.5, 1, 0 },
	})

	--------------------------------------------------------------------
	-- the asteroid belt (between Mars and Jupiter) and the icy comet
	-- belt out past Neptune: a band of dust + real rocks in each
	--------------------------------------------------------------------
	local function band(r0, r1, colA, colB, alpha, tex)
		return K.softRing(host, 160, r0, r1, {
			Texture = tex or "10180479311", Brightness = 1.2, Alpha = alpha, Segments = 8,
			ColorSeq = ColorSequence.new(colA, colB),
			Profile = { 0, 0, 0.2, 0.7, 0.45, 1, 0.6, 0.6, 0.8, 0.8, 1, 0 },
		})
	end
	SOL.AsteroidBand = band(23200, 26200, Color3.fromRGB(200, 170, 140), Color3.fromRGB(150, 130, 115), 0.45)
	SOL.CometBand = band(55000, 61000, Color3.fromRGB(190, 230, 255), Color3.fromRGB(120, 170, 255), 0.35)
	local rocks = K.Assets.Rocks:GetChildren()
	local function rock(size, color, material)
		local r = rocks[rng:NextInteger(1, #rocks)]:Clone()
		r.Anchored = true
		r.CanCollide = false
		r.CanQuery = false
		r.CanTouch = false
		r.CastShadow = false
		r.Size = r.Size / math.max(r.Size.X, r.Size.Y, r.Size.Z) * size
		r.Color = color
		if material then r.Material = material end
		r.Parent = set
		return r
	end
	-- belt rocks (orbit the sun); near-field rocks (a debris cloud round the party)
	for i = 1, 260 do
		local sz = rng:NextNumber(40, 160)
		if rng:NextNumber() < 0.07 then sz = rng:NextNumber(220, 420) end
		local r = rock(sz, Color3.fromRGB(rng:NextInteger(90, 130), rng:NextInteger(78, 110), rng:NextInteger(68, 98)))
		table.insert(SOL.Rocks, {
			Part = r, Kind = "Belt", Rad = rng:NextNumber(23300, 26100), Ang = rng:NextNumber(0, 2 * pi), H = rng:NextNumber(-500, 500),
			W = rng:NextNumber(0.012, 0.02), Spin = rng:NextUnitVector() * rng:NextNumber(0.1, 0.6), Rot = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			Suck = { rng:NextNumber(16, 30), rng:NextNumber(7, 12) },
		})
	end
	for i = 1, 150 do
		local sz = rng:NextNumber(60, 240)
		local r = rock(sz, Color3.fromRGB(rng:NextInteger(170, 210), rng:NextInteger(200, 230), rng:NextInteger(225, 255)), Enum.Material.Ice)
		table.insert(SOL.Rocks, {
			Part = r, Kind = "Icy", Rad = rng:NextNumber(55200, 60800), Ang = rng:NextNumber(0, 2 * pi), H = rng:NextNumber(-900, 900),
			W = rng:NextNumber(0.003, 0.006), Spin = rng:NextUnitVector() * rng:NextNumber(0.1, 0.4), Rot = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			Suck = { rng:NextNumber(17, 26), rng:NextNumber(8, 14) },
		})
	end
	for i = 1, 170 do
		local sz = rng:NextNumber(4, 30)
		if rng:NextNumber() < 0.08 then sz = rng:NextNumber(45, 90) end
		local r = rock(sz, Color3.fromRGB(rng:NextInteger(80, 120), rng:NextInteger(72, 105), rng:NextInteger(66, 95)))
		table.insert(SOL.Rocks, {
			Part = r, Kind = "Near", Rad = rng:NextNumber(260, 1900), Ang = rng:NextNumber(0, 2 * pi), H = rng:NextNumber(-260, 260),
			W = rng:NextNumber(0.004, 0.012), Spin = rng:NextUnitVector() * rng:NextNumber(0.1, 0.7), Rot = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			Suck = { rng:NextNumber(14.2, 17.5), rng:NextNumber(6, 10) }, Drift = rng:NextUnitVector() * rng:NextNumber(3, 12),
		})
	end

	--------------------------------------------------------------------
	-- comets: a blazing icy head, a coma, a straight blue ion tail and a
	-- curved golden dust tail, both always streaming away from the Sun
	--------------------------------------------------------------------
	local cometDefs = {
		-- { start offset from the Earth (in solar frame A,B,N), velocity (A,B,N), size }
		{ Key = "Comet1", P = Vector3.new(-2500, 9000, 2200), V = Vector3.new(160, -620, -40), S = 90 },
		{ P = Vector3.new(6000, -11000, 3500), V = Vector3.new(-260, 900, -120), S = 70 },
		{ P = Vector3.new(-14000, -4000, 5200), V = Vector3.new(700, 260, -210), S = 110 },
		{ P = Vector3.new(9000, 14000, -2500), V = Vector3.new(-380, -700, 160), S = 60 },
		{ P = Vector3.new(-6000, 2500, 900), V = Vector3.new(300, -120, 20), S = 45 },
		{ P = Vector3.new(20000, -2000, 7000), V = Vector3.new(-900, 150, -300), S = 130 },
		{ P = Vector3.new(-9000, -16000, -4000), V = Vector3.new(350, 950, 250), S = 80 },
	}
	for i, cd in ipairs(cometDefs) do
		local head = K.part({ Name = "CometHead", Shape = Enum.PartType.Ball, Size = Vector3.one * cd.S, Material = Enum.Material.Neon, Color = Color3.fromRGB(215, 240, 255) }, set)
		local chost = K.part({ Name = "CometHost", Size = Vector3.one, Transparency = 1 }, set)
		local coma = K.quad(chost, CFrame.new(), cd.S * 14, cd.S * 14, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(170, 225, 255), Brightness = 2.2, Transparency = 0.05 })
		local ion = K.ray(chost, Vector3.zero, Vector3.new(0, 0, 1), cd.S * 3.5, cd.S * 0.4, "1084982817", {
			Color = Color3.fromRGB(120, 190, 255), Brightness = 3, Segments = 12, Transparency = K.ns(0, 0.05, 0.6, 0.45, 1, 1),
		})
		ion.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255), Color3.fromRGB(70, 130, 255))
		local dust = K.ray(chost, Vector3.zero, Vector3.new(0, 0, 1), cd.S * 5, cd.S * 9, "10180479311", {
			Color = Color3.fromRGB(255, 230, 180), Brightness = 1.6, Segments = 16, Transparency = K.ns(0, 0.15, 0.5, 0.55, 1, 1),
		})
		dust.Color = ColorSequence.new(Color3.fromRGB(255, 250, 235), Color3.fromRGB(230, 170, 110))
		local trail = K.emitter(head, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(200, 235, 255)),
			Size = K.ns(0, cd.S * 0.25, 1, 0), Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(2, 10), Rate = 40,
			SpreadAngle = Vector2.new(180, 180), Brightness = 3, Transparency = K.ns(0, 0, 1, 1),
		})
		table.insert(SOL.Emitters, trail)
		local c = {
			Key = cd.Key, Head = head, Host = chost, Coma = coma, Ion = ion, Dust = dust, Trail = trail, S = cd.S,
			P0 = cd.P, V = cd.V, TailLen = cd.S * rng:NextNumber(38, 60), Curve = rng:NextNumber(-0.25, 0.25) * cd.S * 40,
			Suck = { rng:NextNumber(14.5, 22), rng:NextNumber(5, 9) },
		}
		table.insert(SOL.Comets, c)
		if cd.Key then SOL.ByKey[cd.Key] = c end
	end

	--------------------------------------------------------------------
	-- the sky: stars, a Milky Way band, far galaxies and nebulae
	--------------------------------------------------------------------
	SOL.Cosmos = K.cosmos(set, {
		Center = earthCenter(ctx), Radius = 70000, Avoid = 64000, Seed = 31, LookAt = earthCenter(ctx),
		Galaxies = 34, GalMin = 64000, GalMax = 72000, GalSize = { 2500, 9000 },
		Streaks = 8, StreakLen = { 20000, 45000 }, Clouds = 14, CloudMin = 62000, CloudMax = 72000,
		Suns = 0, Planets = 0,
	})
	SOL.Band = {}
	local bandAxis = CFrame.Angles(math.rad(62), math.rad(35), math.rad(20))
	local bandCols = { Color3.fromRGB(255, 205, 160), Color3.fromRGB(230, 170, 150), Color3.fromRGB(180, 150, 230), Color3.fromRGB(255, 225, 190), Color3.fromRGB(150, 120, 210) }
	for i = 1, 80 do
		local a = (i - 1) / 80 * pi * 2
		local dir = (bandAxis * CFrame.new(math.cos(a), rng:NextNumber(-0.06, 0.06), math.sin(a))).Position.Unit
		local sz = rng:NextNumber(12000, 22000)
		local q = K.quad(host, CFrame.new(), sz * 1.7, sz, "10180479311", {
			Color = bandCols[rng:NextInteger(1, #bandCols)], Brightness = rng:NextNumber(1, 1.6), Transparency = rng:NextNumber(0.3, 0.55),
		})
		table.insert(SOL.Band, { Q = q, Dir = dir, R = rng:NextNumber(0, 6.28) })
	end

	--------------------------------------------------------------------
	-- THE PORTAL: a colossal Anti-Spiral vortex on the far side of the Sun
	--------------------------------------------------------------------
	local ph = K.part({ Name = "PortalHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(SOL.Pp) }, set)
	SOL.PHost = ph
	local function pring(r0, r1, cA, cB, alpha, bright, tex, prof)
		return K.softRing(ph, 64, r0, r1, {
			Texture = tex, Brightness = bright, Alpha = alpha, Segments = 8, ColorSeq = ColorSequence.new(cA, cB),
			Profile = prof or { 0, 0, 0.15, 1, 0.5, 0.6, 1, 0 },
		})
	end
	SOL.PRings = {
		-- a wide, faint violet halo
		{ R = pring(1, 2, Color3.fromRGB(150, 80, 255), Color3.fromRGB(60, 20, 140), 0.45, 1.2, "10180479311", { 0, 0.3, 0.2, 1, 0.6, 0.4, 1, 0 }), R0 = 1.0, R1 = 6.2, Spin = 0.05, Arms = 0 },
		-- the swirling accretion arms
		{ R = pring(1, 2, Color3.fromRGB(230, 120, 255), Color3.fromRGB(110, 40, 220), 0.85, 2.4, "10180479311"), R0 = 1.05, R1 = 4.2, Spin = 0.35, Arms = 3 },
		{ R = pring(1, 2, Color3.fromRGB(120, 230, 255), Color3.fromRGB(60, 90, 255), 0.75, 2.2, "10180479311"), R0 = 1.1, R1 = 3.4, Spin = -0.5, Arms = 4 },
		{ R = pring(1, 2, Color3.fromRGB(255, 150, 230), Color3.fromRGB(150, 50, 255), 0.7, 2, "1084982817"), R0 = 1.0, R1 = 2.4, Spin = 0.8, Arms = 5 },
		-- the blazing edge of the core
		{ R = pring(1, 2, Color3.fromRGB(245, 235, 255), Color3.fromRGB(170, 120, 255), 0.97, 3.5, "1084982817", { 0, 0, 0.3, 1, 0.55, 0.7, 1, 0 }), R0 = 0.97, R1 = 1.22, Spin = 1.2, Arms = 0 },
	}
	-- the dark heart of it (no light at all: it drinks it)
	SOL.PCore = K.quad(ph, CFrame.new(SOL.Pp), 10, 10, "1084982817", { Color = Color3.new(0, 0, 0), Brightness = 1, Emission = 0, Transparency = 0 })
	SOL.PCore2 = K.quad(ph, CFrame.new(SOL.Pp), 10, 10, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(8, 0, 20), Brightness = 1, Emission = 0, Transparency = 0 })
	-- streams of light spiralling into it
	SOL.PStreams = {}
	for i = 1, 90 do
		local b = K.ray(ph, SOL.Pp, SOL.Pp + Vector3.new(0, 0, 1), 40, 4, "1053548563", {
			Color = Color3.fromRGB(200, 170, 255), Brightness = 3, Segments = 10, Transparency = K.ns(0, 1, 0.3, 0.2, 1, 1),
		})
		b.Color = ColorSequence.new(Color3.fromRGB(150, 230, 255), Color3.fromRGB(200, 110, 255))
		b.Enabled = false
		table.insert(SOL.PStreams, { Beam = b, A = rng:NextNumber(0, 2 * pi), Z = rng:NextNumber(), Speed = rng:NextNumber(0.15, 0.35), R = rng:NextNumber(2.2, 6), Twist = rng:NextNumber(1.2, 2.4) })
	end
	-- lightning crawling round the rim
	SOL.PBolts = Instance.new("Folder")
	SOL.PBolts.Name = "Bolts"
	SOL.PBolts.Parent = set

	-- the Anti-Spiral's arm and hand, reaching out of the portal
	local function bigMesh(name, meshId, native, length)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.one
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(34, 20, 60)
		p.Transparency = 1
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.FileMesh
		m.MeshId = meshId
		m.Scale = Vector3.one * (length / native.Y)
		m.Parent = p
		p.Parent = set
		return p, native * (length / native.Y)
	end
	local hand = K.Assets.GiantHand
	local lower = K.Assets.AntiSpiral.RightLowerArm
	local upper = K.Assets.AntiSpiral.RightUpperArm
	SOL.Hand, SOL.HandSize = bigMesh("PortalHand", hand.MeshId, hand.MeshSize, 5200)
	SOL.Lower, SOL.LowerSize = bigMesh("PortalForearm", lower.MeshId, lower.MeshSize, 6200)
	SOL.Upper, SOL.UpperSize = bigMesh("PortalUpperArm", upper.MeshId, upper.MeshSize, 6600)
	local arm = Instance.new("Model")
	arm.Name = "PortalArm"
	for _, p in ipairs({ SOL.Hand, SOL.Lower, SOL.Upper }) do p.Parent = arm end
	arm.Parent = set
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(120, 60, 220)
	hl.FillTransparency = 0.8
	hl.OutlineColor = Color3.fromRGB(235, 215, 255)
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Enabled = false
	hl.Parent = arm
	SOL.ArmHL = hl
	-- energy crawling over the hand
	SOL.HandHost = K.part({ Name = "HandFX", Size = Vector3.new(4000, 4000, 1400), Transparency = 1 }, set)
	SOL.HandVeins = K.emitter(SOL.HandHost, {
		Texture = "1053548563", Color = ColorSequence.new(Color3.fromRGB(210, 150, 255)), Size = K.ns(0, 160, 1, 0),
		Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(50, 200), Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Brightness = 4,
	})
	table.insert(SOL.Emitters, SOL.HandVeins)

	--------------------------------------------------------------------
	-- flight FX: star streaks riding the camera, the pull's tethers
	--------------------------------------------------------------------
	local sh = K.part({ Name = "StreakHost", Size = Vector3.one, Transparency = 1 }, set)
	SOL.Streaks = {}
	for _ = 1, 80 do
		local b = K.ray(sh, Vector3.zero, Vector3.new(0, 0, -1), 0.4, 0.02, nil, { Color = Color3.fromRGB(215, 205, 255), Transparency = K.ns(0, 1, 0.5, 0.25, 1, 1), Brightness = 3, Segments = 2 })
		b.Enabled = false
		table.insert(SOL.Streaks, { Beam = b, Ang = rng:NextNumber(0, 6.28), R = rng:NextNumber(12, 110), Z = rng:NextNumber(), Speed = rng:NextNumber(0.8, 1.5) })
	end
	SOL.FX = Instance.new("Folder")
	SOL.FX.Name = "FX"
	SOL.FX.Parent = set
end

--------------------------------------------------------------------------
-- where everything is at solar time T
--------------------------------------------------------------------------
-- the pull toward the portal: returns the spiralled position and how far in (0..1)
local function pulled(SOL, base, suck, T)
	if not suck then return base, 0 end
	local s = math.clamp((T - suck[1]) / suck[2], 0, 1)
	if s <= 0 then return base, 0 end
	s = s * s * (1.4 - 0.4 * s)
	local rel = base - SOL.Pp
	local rot = CFrame.fromAxisAngle(SOL.Axis, s * 2.6)
	local p = SOL.Pp + rot:VectorToWorldSpace(rel) * (1 - s) ^ 1.25
	return p, s
end

local function bodyBase(ctx, b, T)
	local SOL = ctx.SOL
	if b.Fixed then return b.Fixed end
	local center = SOL.S
	if b.Parent then center = SOL.ByKey[b.Parent].Pos or center end
	local o = b.Orbit
	return orbitPos(SOL, center, o[1], o[2] + T * o[3], b.Incl)
end

-- the party's flight line toward the portal
local function flightPoint(ctx, f)
	local SOL = ctx.SOL
	local W0 = SOL.W0
	local dir = SOL.Pp - W0
	local side = dir:Cross(SOL.N).Unit
	local up = side:Cross(dir).Unit
	local wig = side * math.sin(f * pi * 2.6) * 2600 * (1 - f) + up * math.sin(f * pi * 1.7) * 1500 * (1 - f)
	return W0 + dir * f + wig
end

local function flightFrame(ctx, f)
	local p = flightPoint(ctx, f)
	local q = flightPoint(ctx, math.min(f + 0.002, 1.001))
	local fwd = (q - p).Unit
	local side = fwd:Cross(ctx.SOL.N).Unit
	local up = side:Cross(fwd).Unit
	return p, fwd, side, up
end

local function progress(T)
	if T <= 17 then return 0 end
	if T <= T_FREEZE then return monotone(FLIGHT, T) end
	if T <= T_THAW then return FLIGHT[#FLIGHT][2] end
	local u = math.clamp((T - T_THAW) / (T_END - T_THAW), 0, 1)
	local a = FLIGHT[#FLIGHT][2]
	return a + (1.0 - a) * u * u
end

-- a crash target is drawn onto the flight line in the seconds before impact
local function crashPull(ctx, key, pos, T)
	local SOL = ctx.SOL
	local cr = SOL.CrashByKey and SOL.CrashByKey[key]
	if not cr then return pos end
	local target = flightPoint(ctx, cr.F)
	if cr.Rings then
		-- (for Saturn: the planet sits off to the side so they fly through the RINGS)
		local _, fwd, side = flightFrame(ctx, cr.F)
		target = target + side * 1500
	end
	local u = smooth((T - (cr.T - 5.5)) / 5.5)
	return pos:Lerp(target, u)
end

local function rimUpdate(ring, center, radius, camPos, width, alpha)
	local toCam = camPos - center
	local dd = toCam.Magnitude
	if dd <= radius * 1.01 then ring.setEnabled(false) return end
	ring.setEnabled(true)
	local dir = toCam / dd
	local rs = radius * math.sqrt(dd * dd - radius * radius) / dd
	local ctr = center + dir * (radius * radius / dd)
	ring.update(CFrame.lookAt(ctr, camPos), rs * 0.985, rs * (1 + width))
	if alpha then ring.setTransparency(1 - alpha) end
end

--------------------------------------------------------------------------
-- the crash: a world breaking apart as they tear through it
--------------------------------------------------------------------------
local function burst(ctx, pos, D, col, dir, icy)
	local K = ctx.kit
	local fx = ctx.SOL.FX
	local rng = Random.new()
	local rocks = K.Assets.Rocks:GetChildren()
	local chunks = {}
	for i = 1, 60 do
		local r = rocks[rng:NextInteger(1, #rocks)]:Clone()
		r.Anchored = true
		r.CanCollide = false
		r.CanQuery = false
		r.CanTouch = false
		r.CastShadow = false
		local k = D * rng:NextNumber(0.03, 0.14)
		r.Size = r.Size / math.max(r.Size.X, r.Size.Y, r.Size.Z) * k
		local h, s, v = col:ToHSV()
		r.Color = Color3.fromHSV(h, s * rng:NextNumber(0.6, 1), v * rng:NextNumber(0.45, 0.9))
		r.Material = icy and Enum.Material.Ice or (i % 6 == 0 and Enum.Material.Neon or Enum.Material.Slate)
		if r.Material == Enum.Material.Neon then r.Color = Color3.fromRGB(255, 150, 60) end
		local out = rng:NextUnitVector()
		r.CFrame = CFrame.new(pos + out * D * 0.45) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		r.Parent = fx
		table.insert(chunks, { Part = r, CF = r.CFrame, Vel = out * rng:NextNumber(D * 0.5, D * 1.4) + dir * rng:NextNumber(0, D * 0.8), Spin = rng:NextUnitVector() * rng:NextNumber(1, 5) })
	end
	local host = K.part({ Name = "Burst", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(pos) }, fx)
	local puffs = {}
	for i = 1, 10 do
		local q = K.quad(host, CFrame.new(pos), D, D, i <= 3 and "rbxasset://sky/sun.jpg" or "10180479311", {
			Color = i <= 3 and (icy and Color3.fromRGB(190, 230, 255) or Color3.fromRGB(255, 190, 110)) or col:Lerp(Color3.new(1, 1, 1), 0.25),
			Brightness = i <= 3 and 1.8 or 1.1, Transparency = 0.3,
		})
		table.insert(puffs, { Q = q, S0 = D * (i <= 3 and 1.2 or 0.7), Grow = rng:NextNumber(1.5, 3), P = pos + rng:NextUnitVector() * D * 0.25 })
	end
	local wave = K.softRing(host, 40, D * 0.5, D * 0.9, { Brightness = 3, Alpha = 0.9 })
	for _, q in ipairs(wave.Q) do q.Color = ColorSequence.new(Color3.fromRGB(255, 240, 220), col) end
	local t0 = K.now()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = K.now() - t0 -- (the solar freeze stops the debris mid-air too)
		if ctx.SOL.Frozen then return end
		local camPos = workspace.CurrentCamera.CFrame.Position
		if t > 4 or not host.Parent then
			conn:Disconnect()
			host:Destroy()
			for _, ch in ipairs(chunks) do ch.Part:Destroy() end
			return
		end
		local parts, cfs = {}, {}
		for i, ch in ipairs(chunks) do
			parts[i] = ch.Part
			cfs[i] = CFrame.new(ch.CF.Position + ch.Vel * t) * ch.CF.Rotation * CFrame.fromAxisAngle(ch.Spin.Unit, ch.Spin.Magnitude * t)
			if t > 3 then ch.Part.Transparency = math.min(1, t - 3) end
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		for _, p in ipairs(puffs) do
			K.moveQuad(p.Q, CFrame.lookAt(p.P, camPos))
			local s = p.S0 * (1 + t * p.Grow * 0.7)
			K.setQuadSize(p.Q, s, s)
			p.Q.Transparency = K.ns(math.min(0.99, 0.3 + t / 1.6))
		end
		local we = math.clamp(t / 1.2, 0, 1)
		local r0 = D * (0.5 + we * 3)
		wave.update(CFrame.lookAt(pos, pos + dir), r0, r0 + D * (0.4 + we * 0.8))
		wave.setTransparency(K.ns(math.min(0.99, 0.1 + we * 0.9)))
	end)
end

--------------------------------------------------------------------------
-- draw the whole solar system at time T for a camera at camPos
--------------------------------------------------------------------------
local function drawSolar(ctx, T, camPos, dt)
	local K = ctx.kit
	local SOL = ctx.SOL
	-- the Sun
	SOL.Sun.CFrame = CFrame.new(SOL.S) * CFrame.Angles(0, T * 0.02, 0)
	local sunCF = CFrame.lookAt(SOL.S, camPos)
	for i, g in ipairs(SOL.SunGlows) do
		local pulse = 1 + math.sin(T * (0.7 + i * 0.3)) * 0.03
		K.moveQuad(g.Q, sunCF * CFrame.Angles(0, 0, T * 0.01 * i))
		K.setQuadSize(g.Q, g.S * pulse, g.S * pulse)
	end
	for _, r in ipairs(SOL.SunRays) do
		K.moveQuad(r.Q, sunCF * CFrame.Angles(0, 0, r.A + T * r.W))
	end
	rimUpdate(SOL.Corona, SOL.S, 1000, camPos, 0.9 + math.sin(T * 1.3) * 0.05)

	-- planets + moons (parents first: the list is in that order)
	local swallowFlash = 0
	for _, b in ipairs(SOL.Bodies) do
		if not b.Gone then
			local base = bodyBase(ctx, b, T)
			local p, s = pulled(SOL, base, b.Suck, T)
			p = crashPull(ctx, b.Key, p, T)
			b.Pos = p
			local scale = 1 - s ^ 3
			if s >= 0.999 then
				b.Gone = true
				b.Part.Transparency = 1
				if b.Ring then b.Ring.Transparency = 1 end
				if b.Rim then b.Rim.setEnabled(false) end
				swallowFlash = 1
			else
				local cf = CFrame.new(p) * b.Tilt * CFrame.Angles(0, T * b.Spin, 0)
				if s > 0 then
					-- tumbling as it's dragged in
					cf = cf * CFrame.fromAxisAngle(SOL.Axis:Cross(Vector3.yAxis).Unit, s * s * 3)
				end
				if math.abs(scale - (b.LastScale or 1)) > 0.01 then
					b.LastScale = scale
					b.Part.Size = b.Size0 * math.max(scale, 0.02)
					if b.Ring then b.Ring.Size = b.RingSize0 * math.max(scale, 0.02) end
				end
				b.Part.CFrame = cf
				if b.Ring then
					local rel = b.RingRel
					b.Ring.CFrame = cf * CFrame.new(rel.Position * scale) * rel.Rotation
				end
				if b.Rim then rimUpdate(b.Rim, p, b.R * scale, camPos, b.Rim.Width) end
			end
		end
	end
	local earth = SOL.ByKey.Earth
	SOL.Air.CFrame = CFrame.new(earth.Pos)
	-- Saturn's glittering ring dust
	local sat = SOL.ByKey.Saturn
	if sat and not sat.Gone and sat.Ring then
		local rc = sat.Ring.CFrame
		local sc = sat.LastScale or 1
		SOL.SaturnDust.update(CFrame.fromMatrix(rc.Position, rc.YVector, rc.ZVector), sat.R * 1.3 * sc, sat.R * 2.6 * sc, T * 0.05)
		SOL.SaturnDust.setEnabled(true)
	else
		SOL.SaturnDust.setEnabled(false)
	end

	-- the two belts (bands in the orbital plane, slowly turning)
	local plane = CFrame.fromMatrix(SOL.S, SOL.A, SOL.B)
	local beltFade = 1 - math.clamp((T - 18) / 14, 0, 1)
	SOL.AsteroidBand.update(plane, 23200, 26200, T * 0.012)
	SOL.CometBand.update(plane, 55000, 61000, T * 0.004)
	if math.abs(beltFade - (SOL.LastBeltFade or -1)) > 0.02 then
		SOL.LastBeltFade = beltFade
		SOL.AsteroidBand.setTransparency(1 - 0.45 * beltFade)
		SOL.CometBand.setTransparency(1 - 0.35 * beltFade)
	end
	-- rocks
	local parts, cfs = SOL.RockParts or {}, SOL.RockCFs or {}
	SOL.RockParts, SOL.RockCFs = parts, cfs
	local n = 0
	for _, r in ipairs(SOL.Rocks) do
		if not r.Gone then
			local base
			if r.Kind == "Near" then
				local ec = earth.Pos
				base = ec + (SOL.A * math.cos(r.Ang + T * r.W) + SOL.B * math.sin(r.Ang + T * r.W)) * (EARTH_R + HOVER + r.Rad * 0.35) + SOL.N * r.H
				base = base + (SOL.W0 or ec) - ec - SOL.N * (EARTH_R + HOVER) + r.Drift * T
			else
				base = orbitPos(SOL, SOL.S, r.Rad, r.Ang + T * r.W) + SOL.N * r.H
			end
			local p, s = pulled(SOL, base, r.Suck, T)
			if s >= 0.999 then
				r.Gone = true
				r.Part.Transparency = 1
			else
				n += 1
				parts[n] = r.Part
				cfs[n] = CFrame.new(p) * r.Rot * CFrame.fromAxisAngle(r.Spin.Unit, T * r.Spin.Magnitude * (1 + s * 6))
			end
		end
	end
	for i = n + 1, #parts do parts[i] = nil cfs[i] = nil end
	if n > 0 then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end

	-- comets
	for _, c in ipairs(SOL.Comets) do
		if not c.Gone then
			local ec = earth.Fixed
			local off = c.P0 + c.V * T
			local base = ec + SOL.A * off.X + SOL.B * off.Y + SOL.N * off.Z
			local p, s = pulled(SOL, base, c.Suck, T)
			p = crashPull(ctx, c.Key, p, T)
			if s >= 0.999 then
				c.Gone = true
				c.Head.Transparency = 1
				c.Coma.Transparency = K.ns(1)
				c.Ion.Enabled = false
				c.Dust.Enabled = false
				c.Trail.Rate = 0
			else
				c.Head.CFrame = CFrame.new(p)
				c.Pos = p
				-- tails stream away from the Sun; once the pull is on, they bend toward the portal
				local away = (p - SOL.S).Unit
				local toP = (SOL.Pp - p).Unit
				local tail = away:Lerp(-toP, s).Unit
				local L = c.TailLen * (1 + s * 1.5)
				c.Ion.Attachment0.WorldPosition = p
				c.Ion.Attachment1.WorldPosition = p + tail * L
				c.Dust.Attachment0.WorldPosition = p
				c.Dust.Attachment1.WorldPosition = p + (tail + (p - camPos).Unit:Cross(tail) * 0.18).Unit * L * 0.7
				c.Dust.CurveSize1 = c.Curve
				K.moveQuad(c.Coma, CFrame.lookAt(p, camPos))
			end
		end
	end

	-- the sky
	SOL.Cosmos.face(camPos, T)
	for _, q in ipairs(SOL.Band) do
		local p = camPos + q.Dir * 64000
		K.moveQuad(q.Q, CFrame.lookAt(p, camPos) * CFrame.Angles(0, 0, q.R))
	end
	return swallowFlash
end

--------------------------------------------------------------------------
-- the portal, at size `open` (0..1), spinning `spin` fast
--------------------------------------------------------------------------
local function drawPortal(ctx, T, camPos, open, spin)
	local K = ctx.kit
	local SOL = ctx.SOL
	local P = SOL.Pp
	local R = PORTAL_R * math.max(open, 0.001)
	-- the portal is a flat swirl facing the solar system; tilt it toward the camera a
	-- little so it never goes edge-on
	local n = SOL.Axis:Lerp((camPos - P).Unit, 0.45).Unit
	local up = math.abs(n:Dot(Vector3.yAxis)) > 0.95 and Vector3.xAxis or Vector3.yAxis
	local face = CFrame.lookAt(P, P + n, up)
	for i, pr in ipairs(SOL.PRings) do
		local ph = T * pr.Spin * spin
		local weights
		if pr.Arms > 0 then
			local arms = pr.Arms
			weights = function(a) return 0.25 + 0.75 * (0.5 + 0.5 * math.cos(arms * (a - ph) + i)) end
		end
		pr.R.update(face * CFrame.new(0, 0, -i * 2), R * pr.R0, R * pr.R1 * (1 + math.sin(T * 0.8 + i) * 0.03), ph, weights)
	end
	for i, pr in ipairs(SOL.PRings) do
		if pr.LastOpen ~= open then pr.R.setEnabled(open > 0.01) end
		pr.LastOpen = open
	end
	K.moveQuad(SOL.PCore, face * CFrame.new(0, 0, 20))
	K.setQuadSize(SOL.PCore, R * 2.3, R * 2.3)
	K.moveQuad(SOL.PCore2, face * CFrame.new(0, 0, 25) * CFrame.Angles(0, 0, T))
	K.setQuadSize(SOL.PCore2, R * 1.6, R * 1.6)
	SOL.PCore.Transparency = K.ns(open > 0.01 and 0 or 1)
	SOL.PCore2.Transparency = K.ns(open > 0.01 and 0 or 1)
	-- streams of light spiralling in
	for _, st in ipairs(SOL.PStreams) do
		st.Beam.Enabled = open > 0.2
		if open > 0.2 then
			local z = (st.Z + T * st.Speed * spin) % 1
			local r0 = R * st.R * (1 - z) + R * 1.02 * z
			local a0 = st.A + z * st.Twist + T * 0.2 * spin
			local a1 = a0 + 0.35
			local r1 = math.max(R * 1.0, r0 - R * 0.6)
			st.Beam.Attachment0.WorldPosition = (face * CFrame.new(math.cos(a0) * r0, math.sin(a0) * r0, -5)).Position
			st.Beam.Attachment1.WorldPosition = (face * CFrame.new(math.cos(a1) * r1, math.sin(a1) * r1, -5)).Position
			st.Beam.Width0 = R * 0.03 * (1 - z) + 10
			st.Beam.Width1 = R * 0.004
			st.Beam.Transparency = K.ns(0, 1, 0.3, 1 - 0.8 * open * math.min(1, z * 5), 1, 1)
		end
	end
	return face
end

local function portalBolt(ctx, face, R)
	local K = ctx.kit
	local SOL = ctx.SOL
	local a = math.random() * 2 * pi
	local r0 = R * (1.05 + math.random() * 0.5)
	local pts = {}
	local n = 9
	for i = 0, n do
		local u = i / n
		local ang = a + u * (0.5 + math.random() * 0.5)
		local rr = r0 * (1 - u * 0.25) + (math.random() - 0.5) * R * 0.12
		table.insert(pts, (face * CFrame.new(math.cos(ang) * rr, math.sin(ang) * rr, -30)).Position)
	end
	local parts = {}
	for i = 1, #pts - 1 do
		local p0, p1 = pts[i], pts[i + 1]
		local w = R * 0.012 * (1 - i / (#pts + 1))
		table.insert(parts, K.part({ Size = Vector3.new(w, w, (p1 - p0).Magnitude), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Material = Enum.Material.Neon, Color = Color3.fromRGB(225, 190, 255) }, SOL.PBolts))
	end
	task.delay(0.09, function()
		for _, p in ipairs(parts) do K.tween(p, 0.2, { Transparency = 1 }) end
		task.delay(0.25, function() for _, p in ipairs(parts) do p:Destroy() end end)
	end)
end

-- the arm, `out` (0..1) of the way out of the portal
local function drawArm(ctx, T, out, face)
	local SOL = ctx.SOL
	local P = SOL.Pp
	local vis = out > 0.01
	SOL.ArmHL.Enabled = vis
	for _, p in ipairs({ SOL.Hand, SOL.Lower, SOL.Upper }) do p.Transparency = vis and 0 or 1 end
	if not vis then return end
	-- reaching out of the swirl toward the Sun, a little off the centre line
	local ad = SOL.Axis
	local side = ad:Cross(SOL.N).Unit
	local base = P + side * 1600 - SOL.N * 900
	local sway = Vector3.new(math.noise(T * 0.2, 1), math.noise(T * 0.2, 2), math.noise(T * 0.2, 3)) * 300
	local reach = -4000 + out * 15500
	local wrist = base + ad * reach + sway
	-- the hand: fingers along the reach, palm turned toward the solar system's plane
	local F = (ad + SOL.N * 0.25 * math.sin(T * 0.3)).Unit
	local palm = -SOL.N
	local handLen = SOL.HandSize.Y
	local handC = wrist + F * (handLen * 0.5 - 150)
	SOL.Hand.CFrame = CFrame.fromMatrix(handC, F:Cross(palm).Unit, F) * CFrame.Angles(0, pi, 0)
	local yv = -ad
	local xv = yv:Cross(side).Unit
	local lowLen = SOL.LowerSize.Y
	SOL.Lower.CFrame = CFrame.fromMatrix(wrist - ad * (lowLen * 0.5 - 250), xv, yv)
	local upLen = SOL.UpperSize.Y
	SOL.Upper.CFrame = CFrame.fromMatrix(wrist - ad * (lowLen - 500 + upLen * 0.5), xv, yv)
	SOL.HandHost.CFrame = SOL.Hand.CFrame
	SOL.HandVeins.Rate = 60
	SOL.HandTip = wrist + F * handLen
	SOL.Wrist = wrist
end

--------------------------------------------------------------------------
-- freezing time
--------------------------------------------------------------------------
local function setFrozen(ctx, on)
	local SOL = ctx.SOL
	SOL.Frozen = on
	for _, e in ipairs(SOL.Emitters) do
		e.TimeScale = on and 0 or 1
	end
	for _, d in ipairs(ctx.sets.Solar:GetDescendants()) do
		if d:IsA("ParticleEmitter") then d.TimeScale = on and 0 or 1 end
	end
end

--------------------------------------------------------------------------
-- the party
--------------------------------------------------------------------------
local function hoverPoint(ctx, slot, T)
	-- a loose group, holding station just above the Earth, gliding slowly
	-- along their orbit (the world turns beneath them)
	local SOL = ctx.SOL
	local ec = SOL.ByKey.Earth.Fixed
	local n = ctx.n
	local a = (slot - 1) / math.max(n, 1) * pi * 2
	local r = n > 1 and (6 + n) or 0
	local orbit = CFrame.fromAxisAngle(SOL.B, T * 0.0035)
	local rel = orbit:VectorToWorldSpace(SOL.N * (EARTH_R + HOVER))
	local lateral = SOL.A * math.cos(a) * r + SOL.B * math.sin(a) * r
	return ec + rel + lateral + SOL.N * math.sin(slot * 1.7) * 2
end

--------------------------------------------------------------------------
-- SPACE
--------------------------------------------------------------------------
function Ch.Space(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local SOL = ctx.SOL
	local set = ctx.sets.Solar
	set.Parent = ctx.stage
	K.lighting("Space", 0)
	solarFrame(ctx, K.lightDir())
	SOL.W0 = hoverPoint(ctx, 1, 17)
	SOL.CrashByKey = {}
	for _, c in ipairs(CRASH) do SOL.CrashByKey[c.Key] = c end
	-- (the launch ends looking down into the blue of the upper air: we come out of the
	-- same blue, still looking down, at the planet we just left)
	K.fade(1, 0, Color3.fromRGB(150, 195, 255))
	K.fade(0, 1.8, Color3.fromRGB(150, 195, 255))
	K.Blur.Size = 16
	K.tween(K.Blur, 2.2, { Size = 0 })
	K.muffle(0.35, 2)
	local amb = K.loop(K.S.SpaceAmb, 0.4, 3)
	ctx.setMusic(K.S.M_Altitudes, 0.6, 3)
	local stars = K.starShell(set)
	SOL.Stars = stars
	local cue = K.once()
	for _, rig in pairs(ctx.rigs) do
		rig.Smooth = 4
		rig:stopAll(0.3)
	end
	local rumble

	K.run(t0, dur, function(t, dt)
		local T = t
		local cam = K.Cam.CF
		local flash = drawSolar(ctx, T, cam.Position, dt)
		local open = K.k(T, T_OPEN, T_OPEN + 2.4, E.outBack)
		local face = drawPortal(ctx, T, cam.Position, open, 1 + K.k(T, T_PULL, dur) * 1.5)
		drawArm(ctx, T, K.k(T, T_HAND, dur + 13, E.outCubic) * 0.55, face)
		K.starShellUpdate(stars, cam.Position, 1)

		-- the party: HOLDING STATION in orbit. Upright to the Earth, barely drifting,
		-- limbs relaxed; the calm before it all goes wrong
		local pullOn = K.k(T, T_PULL, dur, E.inQuad)
		local toPortal = (SOL.Pp - cam.Position).Unit
		local center
		for slot, rig in pairs(ctx.rigs) do
			local p = hoverPoint(ctx, slot, T) + K.zeroGOffset(t * 0.6, slot, 0.8)
			-- once the pull starts they're tugged toward the portal
			local tug = (SOL.Pp - p).Unit
			p = p + tug * (pullOn * pullOn * 40)
			local radial = (p - SOL.ByKey.Earth.Fixed).Unit
			local fwd0 = SOL.B:Cross(radial).Unit
			local yaw = (slot - 1) * 0.9 + t * 0.03
			local body = CFrame.fromMatrix(p, fwd0:Cross(radial).Unit, radial) * CFrame.Angles(0, yaw, 0)
			-- a very gentle sway, not a tumble
			body = body * CFrame.Angles(math.sin(t * 0.37 + slot) * 0.06, 0, math.sin(t * 0.29 + slot * 2) * 0.05)
			if pullOn > 0 then
				local toward = CFrame.lookAt(p, p - tug) * CFrame.Angles(math.rad(-70), 0, 0)
				body = body:Lerp(toward, pullOn * 0.85)
			end
			rig:setCF(body)
			local pose = K.mixPose(K.Poses.Float, K.zeroGPose(t * 0.7, slot, 0.35), 0.5)
			-- looking round at it all, then down at the Earth
			pose.Neck = (pose.Neck or CFrame.new()) * K.A(K.k(t, 1, 4) * -10, math.sin(t * 0.25 + slot) * 20, 0)
			if pullOn > 0 then pose = K.mixPose(pose, K.mixPose(K.Poses.Blown, K.zeroGPose(t * 2.5, slot, 1.2), 0.4), pullOn) end
			rig:setPose(K.safeArms(pose))
			rig:apply()
			if rig == ctx.myRig then center = p end
		end
		center = center or hoverPoint(ctx, 1, T)
		local head = ctx.myRig and ctx.myRig:head() and ctx.myRig:head().Position or center
		local rcf = ctx.myRig and ctx.myRig:cf() or CFrame.new(center)
		local ec = SOL.ByKey.Earth.Fixed
		local radial = (center - ec).Unit

		-- camera
		if t < 4.2 then
			-- out of the blue: looking down at the Earth, then tilting up as the Sun
			-- breaks over its curve and the whole system spreads across the sky
			local e = K.k(t, 0, 4.2, E.inOutSine)
			local down = CFrame.lookAt(center + radial * 45 + SOL.B * 8, center - radial * 400, SOL.A)
			local back = -SOL.D
			local rev = CFrame.lookAt(center + back * 70 + radial * 24 + SOL.B * 22, center + SOL.D * 400 + radial * 60) * CFrame.Angles(0, 0, math.rad(-6))
			K.setCam(down:Lerp(rev, e), K.lerp(74, 60, e))
		elseif t < 7.4 then
			-- close on you: calm, weightless, the blue world turning below
			local e = K.k(t, 4.2, 7.4)
			local p = head + (rcf.LookVector * 6 + rcf.RightVector * 2.5 - radial * 1.2) * K.lerp(1.15, 0.95, e)
			K.setCam(CFrame.lookAt(p, head, radial), 38)
		elseif t < 10.6 then
			-- the solar system: a slow pan across the Sun, the planets on their
			-- orbits, a comet streaking past, the belt glittering
			local e = K.k(t, 7.4, 10.6, E.inOutSine)
			local p = center - SOL.D * 30 + radial * 10
			local a = SOL.S + SOL.B * K.lerp(-16000, 9000, e) + SOL.N * K.lerp(-1500, 2500, e)
			K.setCam(CFrame.lookAt(p, a, radial), K.lerp(46, 40, e))
		elseif t < T_PULL then
			-- far beyond the Sun, the dark tears open, and something reaches out of it
			local e = K.k(t, 10.6, T_PULL, E.inOutSine)
			local p = center - SOL.D * 40 + radial * 12 + SOL.B * 12
			local look = SOL.S:Lerp(SOL.Pp, K.lerp(0.55, 0.9, e))
			K.setCam(CFrame.lookAt(p, look, radial), K.lerp(34, 26, e))
			K.shake(0.15 + open * 0.4, 0.1, 12, true)
		else
			-- over their shoulders: the pull has them, everything leaning toward it
			local e = K.k(t, T_PULL, dur, E.inQuad)
			local p = center - toPortal * K.lerp(34, 16, e) + radial * K.lerp(10, 4, e) + SOL.B * 8
			K.setCam(CFrame.lookAt(p, center + toPortal * 800), K.lerp(48, 70, e))
			K.shake(0.3 + e * 1.4, 0.1, 18, true)
		end
		cue("open", t >= T_OPEN, function()
			K.sfx(K.S.Portal, 1, 0.5, { Reverb = 3 })
			K.sfx(K.S.DarkDrone, 0.8, 0.7)
			K.sfx(K.S.Thunder, 0.6, 0.6)
			K.muffle(0, 1.5)
			ctx.fadeMusic(0.12, 2)
			K.gradePunch(0.25, 0, 1.5, Color3.fromRGB(210, 190, 255))
			rumble = K.loop(K.S.Rumble, 0.5, 1)
		end)
		cue("hand", t >= T_HAND, function()
			K.sfx(K.S.Hell, 0.8, 0.6)
			K.sfx(K.S.Portal2, 0.7, 0.5)
		end)
		cue("pull", t >= T_PULL, function()
			K.sfx(K.S.Riser, 0.9, 0.7)
			K.sfx(K.S.Whoosh, 0.9, 0.6)
			ctx.setMusic(K.S.M_Trailer, 0.65, 1.5)
		end)
		cue("yank", t >= dur - 0.25, function()
			K.sfx(K.S.Whoosh, 1, 0.5)
			K.sfx(K.S.BigHit, 0.7, 1.2)
			K.flash(0.3, Color3.fromRGB(190, 170, 255), 0.7)
		end)
		if open > 0.3 and math.random() < 0.08 then portalBolt(ctx, face, PORTAL_R * open) end
		K.stream(center)
	end)
	K.fadeSound(amb, 0, 1, true)
	if rumble then K.fadeSound(rumble, 0, 1, true) end
end

--------------------------------------------------------------------------
-- the flight (DRAG and VORTEX share it)
--------------------------------------------------------------------------
local function flyParty(ctx, T, t, wild)
	local K = ctx.kit
	local f = progress(T)
	local p0, fwd, side, up = flightFrame(ctx, f)
	local center
	for slot, rig in pairs(ctx.rigs) do
		local a = slot * 2.4 + t * 0.4
		local r = ctx.n > 1 and (6 + (slot % 3) * 4) or 0
		local lag = ((slot - 1) % 4) * 3
		local p = p0 - fwd * lag + side * math.cos(a) * r + up * math.sin(a) * r + K.zeroGOffset(t * 2, slot, 1.5)
		local body = CFrame.lookAt(p, p - fwd, up) * CFrame.Angles(math.rad(-75), 0, 0)
		rig:setCF(body * K.zeroGRot(t * (1.5 + wild * 2), slot, 0.3 + wild * 0.6, slot % 2 == 0 and 1 or -1))
		local pose = K.mixPose(K.zeroGPose(t * (2 + wild * 2), slot, 1.1), K.Poses.Blown, 0.5)
		rig:setPose(K.safeArms(pose))
		rig:apply()
		if rig == ctx.myRig then center = p end
	end
	return center or p0, fwd, side, up, f
end

local function updateStreaks(ctx, camPos, fwd, rush, t, on)
	local K = ctx.kit
	for _, st in ipairs(ctx.SOL.Streaks) do
		st.Beam.Enabled = on
		if on then
			local z = (st.Z + t * st.Speed * (0.6 + rush * 2.4)) % 1
			local b = CFrame.lookAt(camPos, camPos + fwd) * CFrame.new(math.cos(st.Ang) * st.R, math.sin(st.Ang) * st.R, -z * 500 + 150)
			st.Beam.Attachment0.WorldPosition = b.Position
			st.Beam.Attachment1.WorldPosition = (b * CFrame.new(0, 0, 20 + rush * 260)).Position
			st.Beam.Width0 = 0.2 + rush * 0.9
		end
	end
end

-- the crashes happen here: every target that the party reaches blows apart
local function doCrashes(ctx, T, fwd)
	local K = ctx.kit
	local SOL = ctx.SOL
	for _, c in ipairs(CRASH) do
		if not c.Done and T >= c.T then
			c.Done = true
			local b = SOL.ByKey[c.Key]
			if b then
				if b.Head then
					-- a comet: the head bursts into ice and light
					burst(ctx, b.Pos, 700, Color3.fromRGB(190, 230, 255), fwd, true)
					b.Gone = true
					b.Head.Transparency = 1
					b.Coma.Transparency = K.ns(1)
					b.Ion.Enabled = false
					b.Dust.Enabled = false
					b.Trail.Rate = 0
					K.sfx(K.S.Glass1, 1, 0.8)
					K.sfx(K.S.FireWhoosh, 1, 0.7)
					K.flash(0.45, Color3.fromRGB(190, 230, 255), 0.8)
					K.shake(3, 0.8)
				elseif c.Rings then
					-- Saturn: straight through the rings, which shatter into ice
					if b.Ring then b.Ring.Transparency = 1 b.Ring = nil end
					burst(ctx, flightPoint(ctx, c.F), 2600, Color3.fromRGB(235, 215, 170), fwd, true)
					K.sfx(K.S.Glass2, 1, 0.7)
					K.sfx(K.S.Glass3, 0.9, 0.9)
					K.sfx(K.S.Whoosh, 1, 0.6)
					K.flash(0.35, Color3.fromRGB(255, 235, 200), 0.6)
					K.shake(3.5, 1)
				else
					burst(ctx, b.Pos, b.D, b.Part.Color == Color3.new(0, 0, 0) and Color3.fromRGB(170, 150, 130) or b.Part.Color, fwd)
					b.Gone = true
					b.Part.Transparency = 1
					if b.Ring then b.Ring.Transparency = 1 end
					if b.Rim then b.Rim.setEnabled(false) end
					K.sfx(K.S.BigHit, 1, 0.8)
					K.sfx(K.S.RockBoom, 1, 0.9)
					K.sfx(K.S.Boom, 0.8, 0.7)
					K.shake(4, 1.1)
					K.kick(14, 0.7)
					K.flash(0.35, Color3.fromRGB(255, 220, 190), 0.6)
				end
				local subjects = {}
				for _, rig in pairs(ctx.rigs) do table.insert(subjects, rig.Model) end
				task.spawn(K.impact, subjects, "WBW", 0.045)
			end
		end
	end
end

--------------------------------------------------------------------------
-- DRAG
--------------------------------------------------------------------------
function Ch.Drag(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local SOL = ctx.SOL
	local set = ctx.sets.Solar
	set.Parent = ctx.stage
	local OFF = ctx.TL.Chapter("Drag").Start - ctx.TL.Chapter("Space").Start
	K.lighting("Space", 0)
	if not SOL.W0 then
		solarFrame(ctx, K.lightDir())
		SOL.W0 = hoverPoint(ctx, 1, 17)
		SOL.CrashByKey = {}
		for _, c in ipairs(CRASH) do SOL.CrashByKey[c.Key] = c end
	end
	local stars = SOL.Stars or K.starShell(set)
	SOL.Stars = stars
	local rush = K.loop(K.S.Rush, 0.8, 0.4, 1.1)
	local tunnel = K.loop(K.S.Tunnel, 0.6, 0.6, 0.9)
	for _, rig in pairs(ctx.rigs) do rig.Smooth = 8 end
	local cue = K.once()

	K.run(t0, dur, function(t, dt)
		local T = t + OFF
		local camPos = K.Cam.CF.Position
		drawSolar(ctx, T, camPos, dt)
		local face = drawPortal(ctx, T, camPos, 1, 2 + t * 0.1)
		drawArm(ctx, T, 0.55 + K.k(T, 17, 40) * 0.45, face)
		K.starShellUpdate(stars, camPos, 1)
		local center, fwd, side, up, f = flyParty(ctx, T, t, 1)
		local speed = (flightPoint(ctx, progress(T + 0.05)) - flightPoint(ctx, f)).Magnitude / 0.05
		local rush01 = math.clamp(speed / 2000, 0, 1)
		doCrashes(ctx, T, fwd)
		local head = ctx.myRig and ctx.myRig:head() and ctx.myRig:head().Position or center
		local rcf = ctx.myRig and ctx.myRig:cf() or CFrame.new(center)

		-- camera (T 17 -> 30); crashes at 18.8 Moon, 21.2 comet, 23.4 Mars, 27.5 Jupiter
		local camCF, fov
		if t < 1.8 then
			-- over their shoulders, yanked off into the dark, the grey Moon rushing up
			local e = K.k(t, 0, 1.8, E.inQuad)
			camCF = CFrame.lookAt(center - fwd * K.lerp(26, 14, e) + up * K.lerp(9, 5, e) + side * 5, center + fwd * 300)
			fov = K.lerp(62, 82, e)
		elseif t < 4.2 then
			-- ahead of them looking back: the Moon in pieces, a comet blazing toward them
			local e = K.k(t, 1.8, 4.2)
			camCF = CFrame.lookAt(center + fwd * K.lerp(16, 24, e) + up * 3 - side * 6, center - fwd * 60) * CFrame.Angles(0, 0, math.rad(-8))
			fov = 66
			if t > 3.3 then
				-- whip round for the comet
				local e2 = K.k(t, 3.3, 4.2, E.inQuad)
				camCF = camCF:Lerp(CFrame.lookAt(center - fwd * 18 + up * 4 + side * 6, center + fwd * 400), e2)
				fov = K.lerp(66, 84, e2)
			end
		elseif t < 6.4 then
			-- side tracking: Mars dragged into their path, swelling, and then they hit it
			local e = K.k(t, 4.2, 6.4, E.inQuad)
			camCF = CFrame.lookAt(center + side * K.lerp(34, 18, e) + up * 5 - fwd * 10, center + fwd * K.lerp(40, 120, e))
			fov = K.lerp(56, 80, e)
		elseif t < 8.2 then
			-- close on you, torn along, fighting it
			camCF = CFrame.lookAt(head + rcf.LookVector * 5.5 + rcf.RightVector * 2 + rcf.UpVector * 0.6, head, rcf.UpVector) * CFrame.Angles(0, 0, math.sin(t * 2) * 0.05)
			fov = 44
		elseif t < 9.4 then
			-- far and wide: a thin streak across a solar system being sucked away
			local e = K.k(t, 8.2, 9.4)
			camCF = CFrame.lookAt(center + side * 1800 + up * 700 - fwd * K.lerp(1500, 500, e), center + fwd * 2500)
			fov = 55
		else
			-- low chase into the giant: Jupiter fills the frame... and bursts
			local e = K.k(t, 9.4, 10.5, E.inQuad)
			camCF = CFrame.lookAt(center - fwd * 16 - up * 5 + side * 4, center + fwd * 300 + up * 20) * CFrame.Angles(0, 0, e * 0.3)
			fov = K.lerp(64, 88, e)
			if t > 10.5 then
				local e2 = K.k(t, 10.5, dur)
				camCF = CFrame.lookAt(center - fwd * K.lerp(12, 30, e2) + up * 6, center + fwd * 900)
				fov = K.lerp(88, 74, e2)
			end
		end
		K.setCam(camCF, fov)
		K.shake(0.35 + rush01 * 0.9, 0.1, 30, true)
		updateStreaks(ctx, camCF.Position, fwd, rush01, t, true)
		rush.PlaybackSpeed = 0.9 + rush01 * 0.5
		cue("grab", t >= 0, function()
			K.sfx(K.S.Whoosh, 1, 0.6)
			K.sfx(K.S.DarkDrone, 0.7, 1.2)
			K.shake(2, 0.8)
		end)
		K.stream(center)
	end)
	updateStreaks(ctx, Vector3.zero, Vector3.zAxis, 0, 0, false)
	K.fadeSound(rush, 0, 0.8, true)
	K.fadeSound(tunnel, 0, 0.8, true)
end

--------------------------------------------------------------------------
-- VORTEX
--------------------------------------------------------------------------
function Ch.Vortex(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local SOL = ctx.SOL
	local set = ctx.sets.Solar
	set.Parent = ctx.stage
	local OFF = ctx.TL.Chapter("Vortex").Start - ctx.TL.Chapter("Space").Start
	K.lighting("Space", 0)
	if not SOL.W0 then
		solarFrame(ctx, K.lightDir())
		SOL.W0 = hoverPoint(ctx, 1, 17)
		SOL.CrashByKey = {}
		for _, c in ipairs(CRASH) do SOL.CrashByKey[c.Key] = c end
	end
	local stars = SOL.Stars or K.starShell(set)
	SOL.Stars = stars
	local rush = K.loop(K.S.Rush, 0.7, 0.4, 1)
	local drone = K.loop(K.S.DarkDrone, 0.5, 1.5)
	for _, rig in pairs(ctx.rigs) do rig.Smooth = 8 end
	local cue = K.once()
	local fz = T_FREEZE - OFF    -- (VORTEX t of the freeze)
	local th = T_THAW - OFF
	local frozenPose = {}
	local lastT = 0

	K.run(t0, dur, function(t, dt)
		local realT = t + OFF
		-- solar time stands still during the freeze
		local T = realT
		if realT >= T_FREEZE and realT < T_THAW then T = T_FREEZE end
		local frozen = realT >= T_FREEZE and realT < T_THAW
		if frozen ~= (SOL.Frozen or false) then setFrozen(ctx, frozen) end
		local camPos = K.Cam.CF.Position
		if not frozen then
			local flash = drawSolar(ctx, T, camPos, dt)
			if flash > 0 then K.flash(0.25, Color3.fromRGB(200, 160, 255), 0.35) end
		else
			-- (the world is held, but its glows still turn to face the drifting camera)
			drawSolar(ctx, T, camPos, 0)
		end
		local spin = frozen and 0 or (3 + K.k(realT, 30, T_FREEZE) * 3)
		local face = drawPortal(ctx, frozen and T_FREEZE or realT, camPos, 1 + K.k(realT, 30, T_FREEZE) * 0.25, spin)
		drawArm(ctx, T, 1, face)
		K.starShellUpdate(stars, camPos, 1)

		-- the party
		local f = progress(realT)
		local p0, fwd, side, up = flightFrame(ctx, f)
		local center
		local look = K.k(t, fz - 1.1, fz - 0.1, E.inOutSine)   -- turning to look back
		for slot, rig in pairs(ctx.rigs) do
			if frozen and frozenPose[slot] then
				-- held, like everything else... just breathing
				local fp = frozenPose[slot]
				rig:setCF(fp.CF * CFrame.new(0, math.sin(realT * 1.2 + slot) * 0.05, 0))
				rig:apply()
			else
				local wild = 1 - look
				local a = slot * 2.4 + t * 0.4
				local r = ctx.n > 1 and (6 + (slot % 3) * 4) or 0
				local lag = ((slot - 1) % 4) * 3
				local p = p0 - fwd * lag + side * math.cos(a) * r + up * math.sin(a) * r + K.zeroGOffset(t * 2, slot, 1.5 * wild + 0.3)
				local dragged = CFrame.lookAt(p, p - fwd, up) * CFrame.Angles(math.rad(-75), 0, 0) * K.zeroGRot(t * 3, slot, 0.8, slot % 2 == 0 and 1 or -1)
				-- turning in the pull to face everything they're leaving behind
				local back = CFrame.lookAt(p, p - fwd, up) * CFrame.Angles(math.rad(-10), 0, 0)
				local body = dragged:Lerp(back, look)
				if realT >= T_THAW then
					local u = K.k(realT, T_THAW, T_END, E.inQuad)
					body = body * CFrame.Angles(u * 2, u * 3, 0)
				end
				rig:setCF(body)
				local pose = K.mixPose(K.zeroGPose(t * 3, slot, 1.2), K.Poses.Blown, 0.5)
				-- reaching back toward home
				local reachBack = K.mixPose(K.Poses.Float, K.Poses.Reach, 0.7)
				reachBack.Neck = K.A(8, 0, 0)
				pose = K.mixPose(pose, reachBack, look)
				rig:setPose(K.safeArms(pose))
				rig:apply()
				if realT < T_FREEZE then frozenPose[slot] = { CF = body } end
			end
			if rig == ctx.myRig then center = rig:cf().Position end
		end
		center = center or p0
		local head = ctx.myRig and ctx.myRig:head() and ctx.myRig:head().Position or center
		local rcf = ctx.myRig and ctx.myRig:cf() or CFrame.new(center)
		local toP = (SOL.Pp - center).Unit

		-- camera (VORTEX t): 0-4 through the wreckage toward the portal; 4-8.5 past the
		-- hand and Saturn's rings (T 33.6 = t 3.6); 8.5-10.4 into the swirl; 10.4-11.5
		-- they turn; 11.5-15.8 FROZEN; 15.8-17 taken
		local camCF, fov
		if t < 3.2 then
			local e = K.k(t, 0, 3.2, E.inOutSine)
			camCF = CFrame.lookAt(center - fwd * K.lerp(30, 18, e) + up * K.lerp(12, 6, e) + side * 8, center + fwd * 3000)
			fov = K.lerp(60, 72, e)
		elseif t < 4.4 then
			-- through the rings
			local e = K.k(t, 3.2, 4.4)
			camCF = CFrame.lookAt(center + side * 26 + up * 4 - fwd * 6, center + fwd * 80) * CFrame.Angles(0, 0, e * 0.4)
			fov = 70
		elseif t < 8.5 then
			-- the hand: they fly past colossal fingers, the swirl filling the sky beyond
			local e = K.k(t, 4.4, 8.5, E.inOutSine)
			local tip = SOL.HandTip or SOL.Pp
			local p = center - fwd * K.lerp(40, 24, e) + up * K.lerp(20, 8, e) - side * 14
			camCF = CFrame.lookAt(p, center:Lerp(tip, 0.02) + fwd * 1200)
			fov = K.lerp(62, 74, e)
			K.shake(0.5 + e * 0.6, 0.1, 18, true)
		elseif t < fz - 1.1 then
			-- into the swirl: everything dragged down around them into the dark
			local e = K.k(t, 8.5, fz - 1.1, E.inQuad)
			camCF = CFrame.lookAt(center - toP * K.lerp(22, 14, e) + up * 5, SOL.Pp) * CFrame.Angles(0, 0, t * 0.3)
			fov = K.lerp(70, 88, e)
			K.shake(0.8 + e * 1.2, 0.1, 22, true)
		elseif t < fz + 1.6 then
			-- close on your face as you turn to look back... and it all stops
			local e = K.k(t, fz - 1.1, fz + 1.6, E.outCubic)
			local p = head + rcf.LookVector * K.lerp(7, 4.5, e) + rcf.RightVector * 1.6 + rcf.UpVector * 0.4
			camCF = CFrame.lookAt(p, head, rcf.UpVector)
			fov = K.lerp(50, 36, e)
		elseif t < th then
			-- what you see: the whole world you're leaving, held in place
			-- (planets frozen mid-fall, the Sun, the tiny blue Earth), drifting ever
			-- so slowly further away
			local e = K.k(t, fz + 1.6, th, E.inOutSine)
			local backDir = -toP
			local p = head + backDir * K.lerp(3, 6, e) + rcf.UpVector * 1.2 - rcf.RightVector * 1.8
			local target = SOL.ByKey.Earth.Pos:Lerp(SOL.S, 0.35)
			camCF = CFrame.lookAt(p, target)
			fov = K.lerp(40, 30, e)
		else
			-- time lets go: pulled backward into the dark
			local e = K.k(t, th, dur, E.inQuad)
			camCF = CFrame.lookAt(head - toP * K.lerp(6, 3, e) + up * 1.5, SOL.Pp) * CFrame.Angles(0, 0, t * K.lerp(0.5, 4, e))
			fov = K.lerp(80, 118, e)
			K.shake(1 + e * 2.5, 0.1, 25, true)
		end
		K.setCam(camCF, fov)
		updateStreaks(ctx, camCF.Position, fwd, frozen and 0 or 0.8, t, not frozen and t < fz - 1.1)
		if not frozen then doCrashes(ctx, T, fwd) end
		if not frozen and math.random() < 0.12 then portalBolt(ctx, face, PORTAL_R) end

		-- the colour of it: violet as they near the portal; grey and still in the freeze
		local near = K.k(realT, 30, T_FREEZE)
		if frozen then
			K.Grade.Saturation = K.lerp(K.Grade.Saturation, -0.75, 1 - math.exp(-4 * dt))
			K.Grade.TintColor = Color3.fromRGB(215, 222, 255)
			K.Grade.Contrast = 0.1
		elseif realT < T_FREEZE then
			K.Grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(225, 205, 255), near)
			K.Grade.Saturation = 0.12
		else
			K.Grade.Saturation = K.lerp(-0.75, 0.2, K.k(realT, T_THAW, T_THAW + 0.4))
			K.Grade.TintColor = Color3.fromRGB(215, 222, 255):Lerp(Color3.fromRGB(220, 190, 255), K.k(realT, T_THAW, T_END))
		end

		cue("near", t >= 8.5, function()
			K.sfx(K.S.Portal2, 0.8, 0.5, { Reverb = 3 })
			K.sfx(K.S.Riser, 0.8, 0.6)
		end)
		cue("freeze", t >= fz, function()
			-- everything stops. only a piano.
			K.stopAllSounds(0.15)
			task.delay(0.2, function()
				ctx.setMusic(K.S.M_Sad, 0.8, 0.6)
			end)
			K.sfx(K.S.TonalHit, 0.45, 0.5, { Reverb = 4 })
			K.vignette(0.55, Color3.new(0, 0, 0), 1.5)
			K.letterbox(true, 1)
		end)
		cue("thaw", t >= th, function()
			K.sfx(K.S.Portal, 1, 0.6, { Reverb = 3 })
			K.sfx(K.S.Whoosh, 1, 0.4)
			K.flash(0.4, Color3.fromRGB(210, 180, 255), 0.7)
			K.vignette(0.3, Color3.new(0, 0, 0), 0.5)
			ctx.fadeMusic(0.55, 1)
		end)
		lastT = T
		K.stream(center)
	end)
	setFrozen(ctx, false)
	updateStreaks(ctx, Vector3.zero, Vector3.zAxis, 0, 0, false)
	K.fadeSound(rush, 0, 0.5, true)
	K.fadeSound(drone, 0, 0.5, true)
	K.vignette(0, nil, 0.3)
	K.letterbox(true, 0.4) -- (the bars stay on for the rest of the cutscene)
	K.Grade.Saturation = 0.12
	K.Grade.TintColor = Color3.new(1, 1, 1)
	set.Parent = nil
end

return Ch
