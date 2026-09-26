--==================================================
-- CHAPTERS 3-5: SPACE, DRAG, VORTEX
-- One continuous solar system, shared by all three chapters.
--
-- SPACE  (22s) out of the atmosphere into Earth orbit; then a pause to take
--        it all in (Saturn, then the whole system turning), to wondering
--        music. Then, high above the system, a GIGANTIC Anti-Spiral portal
--        tears open, its violet aura spreads over everything, and the
--        worlds start to spiral up its funnel into it.
-- DRAG   (13s) the pull takes the party: a head-first dive at the portal,
--        the camera riding behind, smashing through the Moon, meteors, a
--        comet, Mars, Jupiter and Saturn's rings (knocked tumbling by every hit).
-- VORTEX (5s)  the last stretch, straight on into the portal
--        (the PORTAL chapter in ChHole carries on from there)
--
-- Everything moves on one clock T (seconds since SPACE began), so
-- the three chapters line up exactly and time can be frozen.
--==================================================
local Ch = {}

local pi = math.pi
local EARTH_R = 1000
local SUN_D = 5200             -- the Sun (5x the Earth here: the real 109x won't fit)
local HOVER = 380              -- the party's height above the Earth
local SUN_DIST = 16000         -- Earth -> Sun
local PORTAL_H = 30000         -- the portal hangs this far above the Sun, over the whole system
local PORTAL_R = 14000         -- its dark core (REALLY big)
local ORB = 3                  -- orbits run fast enough to watch the planets move
local T_OPEN = 12.4            -- (SPACE clock) the portal tears open above the system
local T_PULL = 15.2            -- its aura spreads and everything starts to funnel in
local T_GO = 22                -- the party is taken (end of SPACE)
local T_END = 40               -- through the portal (end of VORTEX)
local T_HAND, T_FREEZE, T_THAW = 1e9, 1e9, 1e9   -- (no hand, no look-back freeze any more)

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
	SOL.Pp = SOL.S + up * PORTAL_H + d * 2500
	SOL.Axis = (SOL.S - SOL.Pp).Unit    -- the portal hangs over the system, facing down onto it
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
	{ 22, 0 }, { 23.6, 0.035 }, { 25.4, 0.1 }, { 27.4, 0.2 }, { 30.4, 0.4 }, { 33.2, 0.62 }, { 35, 0.78 }, { 40, 1 },
}
-- the crash targets and where along the flight they're met
local CRASH = {
	{ Key = "Moon",    T = 23.6, F = 0.035 },
	{ Key = "Meteor1", T = 24.5, Meteor = true },
	{ Key = "Comet1",  T = 25.4, F = 0.1 },
	{ Key = "Meteor2", T = 26.4, Meteor = true },
	{ Key = "Mars",    T = 27.4, F = 0.2 },
	{ Key = "Meteor3", T = 28.9, Meteor = true },
	{ Key = "Jupiter", T = 30.4, F = 0.4 },
	{ Key = "Meteor4", T = 31.9, Meteor = true },
	{ Key = "Saturn",  T = 33.2, F = 0.62, Rings = true },
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
		-- an atmosphere: a thin shell that glows at the edges (ForceField is brightest
		-- where you look through it edge-on, exactly like real air seen from space)
		if opts.Atmo then
			local sh = K.Assets.PlanetMesh:Clone()
			sh.Name = name .. "Atmo"
			sh.TextureID = ""
			sh.Material = Enum.Material.ForceField
			sh.Color = opts.Atmo
			sh.Transparency = opts.AtmoT or 0
			sh.Anchored = true
			sh.CanCollide = false
			sh.CanQuery = false
			sh.CanTouch = false
			sh.CastShadow = false
			K.oversize(sh, Vector3.one * diameter * (opts.AtmoScale or 1.035))
			sh.Parent = set
			b.Atmo = sh
			b.AtmoSize0 = sh.Size
		end
		-- a glowing trail along its orbit behind it
		if opts.Trail and opts.Orbit then
			b.Trail = {}
			local tc = opts.TrailColor or opts.Atmo or opts.Rim or Color3.new(1, 1, 1)
			local tw = math.min(diameter * 0.035, 150) + 30
			for i = 1, 18 do
				local tb = K.ray(host, SOL.S, SOL.S + Vector3.new(0, 1, 0), tw, tw, nil, {
					Color = tc, Brightness = 1.5, Segments = 2, Transparency = K.ns(0, math.min(0.97, 0.5 + i * 0.026), 1, math.min(0.98, 0.526 + i * 0.026)),
				})
				table.insert(b.Trail, tb)
			end
		end
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
	K.oversize(sun, Vector3.one * SUN_D)
	sun.Material = Enum.Material.Neon
	sun.Color = Color3.fromRGB(255, 176, 88)
	sun.Anchored = true
	sun.CanCollide = false
	sun.CanQuery = false
	sun.CastShadow = false
	sun.Parent = set
	SOL.Sun = sun
	-- (a soft, contained glow: the old giant glare and rays washed out half the sky)
	SOL.SunGlows = {
		{ Q = K.quad(host, CFrame.new(SOL.S), SUN_D * 1.9, SUN_D * 1.9, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(255, 205, 140), Brightness = 1.2, Transparency = 0.2 }), S = SUN_D * 1.9 },
		{ Q = K.quad(host, CFrame.new(SOL.S), SUN_D * 4, SUN_D * 4, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(255, 150, 80), Brightness = 0.55, Transparency = 0.55 }), S = SUN_D * 4 },
		{ Q = K.quad(host, CFrame.new(SOL.S), SUN_D * 8, SUN_D * 8, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(255, 120, 60), Brightness = 0.25, Transparency = 0.78 }), S = SUN_D * 8 },
	}
	-- pointed rays: long thin spikes of light round the disc, sharp at the tips
	SOL.SunRays = {}
	for i = 1, 16 do
		local long = i % 2 == 1
		local b = K.ray(host, SOL.S, SOL.S + Vector3.new(0, 1, 0), SUN_D * (long and 0.1 or 0.06), 0, nil, {
			Color = Color3.fromRGB(255, 215, 150), Brightness = long and 1.4 or 1, Segments = 2, Transparency = K.ns(0, 0.45, 0.5, 0.8, 1, 1),
		})
		table.insert(SOL.SunRays, { B = b, A = i / 16 * pi * 2 + rng:NextNumber(-0.12, 0.12), L = long and rng:NextNumber(2.2, 3.2) or rng:NextNumber(1.3, 1.9), Ph = rng:NextNumber(0, 6) })
	end
	-- a boiling surface: slow-turning layers of plasma over the disc
	SOL.SunSurf = {}
	for i, c in ipairs({ Color3.fromRGB(255, 110, 30), Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 80, 20) }) do
		local q = K.quad(host, CFrame.new(SOL.S), SUN_D * (0.98 + i * 0.03), SUN_D * (0.98 + i * 0.03), "10180479311", { Color = c, Brightness = 1.4, Transparency = 0.35 + i * 0.08 })
		table.insert(SOL.SunSurf, { Q = q, W = (i % 2 == 0 and 1 or -1) * (0.015 + i * 0.01) })
	end
	-- prominences: loops of fire arcing off the limb
	SOL.Proms = {}
	for i = 1, 7 do
		local b = K.ray(host, SOL.S, SOL.S + Vector3.new(0, 1, 0), SUN_D * 0.05, SUN_D * 0.02, "10180479311", {
			Color = Color3.fromRGB(255, 120, 50), Brightness = 2.2, Segments = 16, Transparency = K.ns(0, 0.3, 0.5, 0.1, 1, 0.4),
		})
		table.insert(SOL.Proms, { B = b, A = i / 7 * pi * 2 + rng:NextNumber(-0.3, 0.3), Span = rng:NextNumber(0.12, 0.3), H = rng:NextNumber(0.25, 0.6), Ph = rng:NextNumber(0, 6) })
	end
	SOL.Corona = K.softRing(host, 64, 1, 2, {
		Texture = "1084982817", Brightness = 3, Alpha = 0.95,
		ColorSeq = ColorSequence.new(Color3.fromRGB(255, 245, 220), Color3.fromRGB(255, 120, 40)),
		Profile = { 0, 1, 0.15, 0.9, 0.4, 0.45, 0.7, 0.15, 1, 0 },
	})
	local sl = Instance.new("PointLight")
	sl.Range = 0
	sl.Brightness = 0
	sl.Color = Color3.fromRGB(255, 220, 170)
	sl.Parent = sun

	--------------------------------------------------------------------
	-- the planets, their orbits and moons
	--   Orbit = { radius, phase (radians from the Earth's side), speed }
	--   Suck  = { start T, duration } for being pulled into the portal
	--------------------------------------------------------------------
	-- the Earth (a proper textured world now) + its air
	local earth = body("Earth", "earth", EARTH_R * 2, { Spin = 0.01, Rim = Color3.fromRGB(110, 175, 255), RimAlpha = 0.9, RimWidth = 0.05, Atmo = Color3.fromRGB(90, 160, 255), AtmoScale = 1.025 })
	earth.Fixed = earthCenter(ctx)
	earth.Tilt = CFrame.Angles(math.rad(-20), 0, math.rad(23))
	local air = K.Assets.PlanetMesh:Clone()
	air.Name = "AirGlow"
	air.TextureID = ""
	air.Size = Vector3.one * (EARTH_R + 16) * 2
	air.Color = Color3.fromRGB(110, 170, 255)
	air.Material = Enum.Material.Neon
	air.Transparency = 0.94
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

	-- sizes follow the real ones relative to the Earth (the giants really are huge),
	-- and every world with air wears it: a glowing shell, a limb glow, and a trail
	-- of light along the path it has just travelled
	body("Moon", "moon", 540, { Parent = "Earth", Orbit = { 2900, 2.4, 0.035 }, Spin = 0.01, Rim = Color3.fromRGB(200, 200, 215), RimAlpha = 0.3 })
	body("Mercury", "mercury", 760, { Orbit = { 6400, 0.62, 0.075 }, Suck = { 16, 10 }, Rim = Color3.fromRGB(200, 170, 150), RimAlpha = 0.25, Trail = true, TrailColor = Color3.fromRGB(220, 190, 170) })
	body("Venus", "venus", 1900, { Orbit = { 10200, -0.78, 0.05 }, Suck = { 16.8, 11 }, Rim = Color3.fromRGB(255, 215, 140), RimAlpha = 0.85, RimWidth = 0.09, Atmo = Color3.fromRGB(255, 205, 120), AtmoScale = 1.05, Trail = true })
	body("Mars", "mars", 1060, { Orbit = { 22000, 0.92, 0.026 }, Rim = Color3.fromRGB(255, 130, 90), RimAlpha = 0.5, Atmo = Color3.fromRGB(255, 140, 100), AtmoScale = 1.02, Trail = true })
	body("Jupiter", "jupiter", 7000, { Orbit = { 33000, 0.34, 0.016 }, Spin = 0.08, Rim = Color3.fromRGB(240, 200, 150), RimAlpha = 0.6, RimWidth = 0.08, Atmo = Color3.fromRGB(255, 215, 170), AtmoScale = 1.03, Trail = true })
	body("Io", "io", 400, { Parent = "Jupiter", Orbit = { 5400, 0.3, 0.2 }, Suck = { 24, 7 }, Rim = Color3.fromRGB(255, 230, 120), RimAlpha = 0.25 })
	body("Europa", "europa", 350, { Parent = "Jupiter", Orbit = { 6600, 2.1, 0.15 }, Suck = { 24.6, 7.5 }, Rim = Color3.fromRGB(220, 230, 255), RimAlpha = 0.25 })
	body("Ganymede", "ganymede", 560, { Parent = "Jupiter", Orbit = { 8200, 3.9, 0.11 }, Suck = { 25.2, 8 }, Rim = Color3.fromRGB(200, 200, 210), RimAlpha = 0.25 })
	body("Callisto", "callisto", 520, { Parent = "Jupiter", Orbit = { 10000, 5.2, 0.08 }, Suck = { 25.8, 8.5 }, Rim = Color3.fromRGB(180, 170, 160), RimAlpha = 0.25 })
	body("Saturn", "saturn", 6000, { Orbit = { 42000, -0.42, 0.012 }, Spin = 0.07, Rim = Color3.fromRGB(255, 225, 160), RimAlpha = 0.55, RimWidth = 0.08, Atmo = Color3.fromRGB(255, 225, 165), AtmoScale = 1.03, Trail = true })
	body("Titan", "titan", 520, { Parent = "Saturn", Orbit = { 8600, 1.2, 0.09 }, Suck = { 26, 9 }, Rim = Color3.fromRGB(255, 180, 90), RimAlpha = 0.6, Atmo = Color3.fromRGB(255, 170, 80), AtmoScale = 1.08 })
	body("Uranus", "uranus", 3400, { Orbit = { 49500, -1.18, 0.009 }, Suck = { 17.5, 14 }, Rim = Color3.fromRGB(150, 235, 255), RimAlpha = 0.8, RimWidth = 0.08, Atmo = Color3.fromRGB(150, 235, 255), AtmoScale = 1.04, Trail = true })
	body("Neptune", "neptune", 3300, { Orbit = { 54000, 1.45, 0.007 }, Suck = { 18, 14 }, Rim = Color3.fromRGB(90, 140, 255), RimAlpha = 0.8, RimWidth = 0.08, Atmo = Color3.fromRGB(80, 130, 255), AtmoScale = 1.04, Trail = true })
	body("Pluto", "pluto", 380, { Orbit = { 57500, 0.2, 0.005 }, Suck = { 16.4, 12 }, Rim = Color3.fromRGB(230, 210, 190), RimAlpha = 0.25, Trail = true, TrailColor = Color3.fromRGB(210, 200, 190) })
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
	SOL.AsteroidBand = band(24400, 28400, Color3.fromRGB(200, 170, 140), Color3.fromRGB(150, 130, 115), 0.4)
	SOL.CometBand = band(59500, 64500, Color3.fromRGB(190, 230, 255), Color3.fromRGB(120, 170, 255), 0.3)
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
	for i = 1, 420 do
		local sz = rng:NextNumber(40, 160)
		if rng:NextNumber() < 0.07 then sz = rng:NextNumber(220, 420) end
		local r = rock(sz, Color3.fromRGB(rng:NextInteger(90, 130), rng:NextInteger(78, 110), rng:NextInteger(68, 98)))
		table.insert(SOL.Rocks, {
			Part = r, Kind = "Belt", Rad = rng:NextNumber(24500, 28300), Ang = rng:NextNumber(0, 2 * pi), H = rng:NextNumber(-500, 500),
			W = rng:NextNumber(0.012, 0.02), Spin = rng:NextUnitVector() * rng:NextNumber(0.1, 0.6), Rot = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			Suck = { rng:NextNumber(16, 30), rng:NextNumber(7, 12) },
		})
	end
	for i = 1, 220 do
		local sz = rng:NextNumber(60, 240)
		local r = rock(sz, Color3.fromRGB(rng:NextInteger(170, 210), rng:NextInteger(200, 230), rng:NextInteger(225, 255)), Enum.Material.Ice)
		table.insert(SOL.Rocks, {
			Part = r, Kind = "Icy", Rad = rng:NextNumber(59700, 64300), Ang = rng:NextNumber(0, 2 * pi), H = rng:NextNumber(-900, 900),
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
			Suck = { rng:NextNumber(15.5, 19), rng:NextNumber(6, 10) }, Drift = rng:NextUnitVector() * rng:NextNumber(3, 12),
		})
	end

	-- the belts as streams: the bigger rocks drag faint dusty trails along their
	-- orbits, and clouds of dust and glinting grit ride round with the belt
	local nt = 0
	for _, rk in ipairs(SOL.Rocks) do
		if (rk.Kind == "Belt" or rk.Kind == "Icy") and nt < 150 and rng:NextNumber() < 0.45 then
			nt += 1
			local p = rk.Part
			local sz = math.max(p.Size.X, p.Size.Y, p.Size.Z)
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, sz * 0.25, 0)
			a0.Parent = p
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -sz * 0.25, 0)
			a1.Parent = p
			local tr = Instance.new("Trail")
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.FaceCamera = true
			tr.Lifetime = rk.Kind == "Icy" and 5 or 3
			tr.MinLength = 20
			tr.LightEmission = 0.6
			tr.Brightness = 1.2
			tr.Color = rk.Kind == "Icy" and ColorSequence.new(Color3.fromRGB(200, 235, 255), Color3.fromRGB(110, 160, 255)) or ColorSequence.new(Color3.fromRGB(235, 205, 170), Color3.fromRGB(150, 120, 95))
			tr.Transparency = K.ns(0, 0.55, 1, 1)
			tr.WidthScale = K.ns(0, 1, 1, 0.2)
			tr.Parent = p
		end
	end
	SOL.BeltDust = {}
	for i = 1, 28 do
		local icy = i > 20
		local hostP = K.part({ Name = "BeltDust", Size = Vector3.new(icy and 3200 or 2400, 600, icy and 3200 or 2400), Transparency = 1 }, set)
		local dust = K.emitter(hostP, {
			Texture = "10180479311", Color = ColorSequence.new(icy and Color3.fromRGB(170, 210, 255) or Color3.fromRGB(190, 160, 130)),
			Size = K.ns(0, icy and 900 or 700, 1, icy and 1400 or 1100), Transparency = K.ns(0, 1, 0.2, 0.8, 0.8, 0.82, 1, 1),
			Lifetime = NumberRange.new(16, 20), Speed = NumberRange.new(0), Rate = 1.2, LockedToPart = true,
			Shape = Enum.ParticleEmitterShape.Box, LightEmission = 0.2, LightInfluence = 0.5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-2, 2),
		})
		local grit = K.emitter(hostP, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(icy and Color3.fromRGB(210, 235, 255) or Color3.fromRGB(255, 225, 190)),
			Size = K.ns(0, 30, 0.5, 60, 1, 0), Transparency = K.ns(0, 0.2, 1, 1), Lifetime = NumberRange.new(6, 12), Speed = NumberRange.new(0), Rate = 14,
			LockedToPart = true, Shape = Enum.ParticleEmitterShape.Box, Brightness = 2, Rotation = NumberRange.new(0, 360),
		})
		table.insert(SOL.Emitters, dust)
		table.insert(SOL.Emitters, grit)
		table.insert(SOL.BeltDust, { Part = hostP, Dust = dust, Grit = grit, Icy = icy, Ang = (icy and (i - 20) / 8 or i / 20) * 2 * pi + rng:NextNumber(-0.1, 0.1), Rad = icy and rng:NextNumber(60000, 64000) or rng:NextNumber(25000, 27800), H = rng:NextNumber(-250, 250) })
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
		local coma = K.quad(chost, CFrame.new(), cd.S * 7, cd.S * 7, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(170, 225, 255), Brightness = 1.3, Transparency = 0.3 })
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
			Suck = (not cd.Key) and { rng:NextNumber(16, 24), rng:NextNumber(5, 9) } or nil,
		}
		table.insert(SOL.Comets, c)
		if cd.Key then SOL.ByKey[cd.Key] = c end
	end

	--------------------------------------------------------------------
	-- the sky: stars, a Milky Way band, far galaxies and nebulae
	--------------------------------------------------------------------
	SOL.Cosmos = K.cosmos(set, {
		Center = earthCenter(ctx), Radius = 70000, Avoid = 64000, Seed = 31, LookAt = earthCenter(ctx),
		-- (no galaxies or coloured nebulae here: those belong to the Anti-Spiral's universe)
		Galaxies = 0, GalMin = 64000, GalMax = 72000, GalSize = { 2500, 9000 },
		Streaks = 0, StreakLen = { 20000, 45000 }, Clouds = 0, CloudMin = 62000, CloudMax = 72000,
		Suns = 0, Planets = 0,
	})
	SOL.Band = {}
	local bandAxis = CFrame.Angles(math.rad(62), math.rad(35), math.rad(20))
	local bandCols = { Color3.fromRGB(255, 205, 160), Color3.fromRGB(230, 170, 150), Color3.fromRGB(180, 150, 230), Color3.fromRGB(255, 225, 190), Color3.fromRGB(150, 120, 210) }
	for i = 1, 70 do
		local a = (i - 1) / 70 * pi * 2
		local dir = (bandAxis * CFrame.new(math.cos(a), rng:NextNumber(-0.06, 0.06), math.sin(a))).Position.Unit
		local sz = rng:NextNumber(14000, 26000)
		local q = K.quad(host, CFrame.new(), sz * 1.7, sz, "10180479311", {
			Color = bandCols[rng:NextInteger(1, #bandCols)]:Lerp(Color3.fromRGB(235, 225, 215), 0.4), Brightness = rng:NextNumber(0.45, 0.75), Transparency = rng:NextNumber(0.74, 0.88),
		})
		table.insert(SOL.Band, { Q = q, Dir = dir, R = rng:NextNumber(0, 6.28) })
	end

	-- the stars: thousands of them "at infinity" (on a shell that rides with the
	-- camera), thickest along the Milky Way, in every star colour
	local starHost = K.part({ Name = "StarField", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new() }, set)
	SOL.StarField = starHost
	SOL.BrightStars = {}
	local STAR_R = 86000
	local function addStar(dir, w, col, bright, alpha)
		local p = dir * STAR_R
		local side = dir:Cross(Vector3.yAxis)
		side = side.Magnitude > 0.01 and side.Unit or Vector3.xAxis
		local a0 = Instance.new("Attachment")
		a0.Position = p - side * w / 2
		a0.Parent = starHost
		local a1 = Instance.new("Attachment")
		a1.Position = p + side * w / 2
		a1.Parent = starHost
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = w
		b.Width1 = w
		b.FaceCamera = true
		b.Segments = 1
		b.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		b.TextureMode = Enum.TextureMode.Stretch
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = bright
		b.Color = ColorSequence.new(col)
		b.Transparency = NumberSequence.new(alpha)
		b.Parent = starHost
		return b
	end
	local starCols = {
		Color3.fromRGB(170, 195, 255), Color3.fromRGB(140, 175, 255), Color3.fromRGB(205, 220, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 245, 225), Color3.fromRGB(255, 225, 180), Color3.fromRGB(255, 200, 140), Color3.fromRGB(255, 165, 120), Color3.fromRGB(255, 130, 110),
		Color3.fromRGB(200, 160, 255), Color3.fromRGB(255, 170, 225), Color3.fromRGB(150, 230, 255),
	}
	for i = 1, 4200 do
		local dir
		if rng:NextNumber() < 0.45 then
			local a = rng:NextNumber(0, 2 * pi)
			dir = (bandAxis * CFrame.new(math.cos(a), rng:NextNumber(-0.12, 0.12) * rng:NextNumber(), math.sin(a))).Position.Unit
		else
			dir = rng:NextUnitVector()
		end
		local bright = rng:NextNumber() ^ 6
		local b = addStar(dir, 170 + bright * 650, starCols[rng:NextInteger(1, #starCols)], 1.5 + bright * 3, math.clamp(0.55 - bright * 0.6 + rng:NextNumber(-0.1, 0.15), 0, 0.9))
		if bright > 0.35 then table.insert(SOL.BrightStars, { B = b, Ph = rng:NextNumber(0, 6), Base = b.Brightness }) end
	end
	-- star clusters: tight knots of young stars, all purple, pink and blue, each
	-- sitting in its own faint glowing cloud
	local clusterCols = { Color3.fromRGB(175, 110, 255), Color3.fromRGB(255, 130, 215), Color3.fromRGB(110, 150, 255), Color3.fromRGB(130, 215, 255), Color3.fromRGB(220, 160, 255) }
	for c = 1, 16 do
		local center = rng:NextUnitVector()
		local spread = rng:NextNumber(0.025, 0.06)
		local t1 = center:Cross(Vector3.yAxis)
		if t1.Magnitude < 0.01 then t1 = center:Cross(Vector3.xAxis) end
		t1 = t1.Unit
		local t2 = center:Cross(t1).Unit
		local hueA = clusterCols[rng:NextInteger(1, #clusterCols)]
		local hueB = clusterCols[rng:NextInteger(1, #clusterCols)]
		for g = 1, 3 do
			local off = (t1 * rng:NextNumber(-1, 1) + t2 * rng:NextNumber(-1, 1)) * spread * 0.4
			local gp = (center + off).Unit * STAR_R * 1.01
			local gs = STAR_R * spread * rng:NextNumber(2.2, 3.4)
			K.quad(starHost, CFrame.lookAt(gp, Vector3.zero) * CFrame.Angles(0, 0, rng:NextNumber(0, 6.28)), gs, gs, g == 1 and "rbxasset://sky/sun.jpg" or "10180479311", {
				Color = hueA:Lerp(hueB, rng:NextNumber()), Brightness = g == 1 and 0.5 or 0.7, Transparency = g == 1 and 0.5 or 0.72,
			})
		end
		for _ = 1, rng:NextInteger(60, 130) do
			local rr = spread * (rng:NextNumber() ^ 1.8)
			local a = rng:NextNumber(0, 2 * pi)
			local dir = (center + (t1 * math.cos(a) + t2 * math.sin(a)) * rr).Unit
			local bright = rng:NextNumber() ^ 4
			local col = hueA:Lerp(hueB, rng:NextNumber()):Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.35))
			local b = addStar(dir, 150 + bright * 600, col, 2 + bright * 3, math.clamp(0.4 - bright * 0.4 + rng:NextNumber(-0.1, 0.15), 0, 0.85))
			if bright > 0.4 then table.insert(SOL.BrightStars, { B = b, Ph = rng:NextNumber(0, 6), Base = b.Brightness }) end
		end
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
	-- (the old flat rings aren't drawn any more: the portal is now the same swirl
	-- that opened over the field at the start, scaled up to swallow a solar system)
	for _, pr in ipairs(SOL.PRings) do pr.R.setEnabled(false) end
	SOL.PCore.Transparency = K.ns(1)
	SOL.PCore2.Transparency = K.ns(1)
	local ptex = { "14426232568", "116996021489973", "18823306900", "124165682553877", "14477910720" }
	local pcols = { Color3.fromRGB(150, 60, 255), Color3.fromRGB(255, 200, 255), Color3.fromRGB(190, 110, 255), Color3.fromRGB(90, 30, 200), Color3.fromRGB(120, 50, 230) }
	local pbright = { 2.2, 1.2, 2.6, 2.0, 1.4 }
	SOL.PQuads = {}
	for i = 1, 5 do
		table.insert(SOL.PQuads, (K.quad(ph, CFrame.new(SOL.Pp), 1, 1, ptex[i], { Color = pcols[i], Brightness = pbright[i], Transparency = 1 })))
	end
	SOL.PDark = K.quad(ph, CFrame.new(SOL.Pp), 1, 1, "1084982817", { Color = Color3.fromRGB(4, 0, 10), Brightness = 1, Emission = 0, Transparency = 1 })
	-- its aura: a vast violet glow that spreads out over the whole system
	SOL.PAura = {}
	for i, sz in ipairs({ 6, 12 }) do
		table.insert(SOL.PAura, { Q = K.quad(ph, CFrame.new(SOL.Pp), 1, 1, "rbxasset://sky/sun.jpg", { Color = i == 1 and Color3.fromRGB(190, 110, 255) or Color3.fromRGB(120, 60, 220), Brightness = 0.6, Transparency = 1 }), S = sz })
	end
	-- the funnel: swirls stacked from the portal down toward the Sun, wide at the bottom
	SOL.PFunnel = {}
	for i = 1, 7 do
		local k = (i % 5) + 1
		table.insert(SOL.PFunnel, { Q = K.quad(ph, CFrame.new(SOL.Pp), 1, 1, ptex[k], { Color = pcols[k]:Lerp(Color3.fromRGB(255, 220, 255), 0.15), Brightness = 1.4, Transparency = 1 }), Z = i / 8, Spin = (i % 2 == 0 and -1 or 1) * (0.25 + i * 0.05) })
	end

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
	SOL.HandVeins.Enabled = false -- (no hand any more)

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
	return orbitPos(SOL, center, o[1], o[2] + T * o[3] * ORB, b.Incl)
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
	if T <= T_GO then return 0 end
	if T >= T_END then return 1 end
	return monotone(FLIGHT, T)
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
		target = target + side * ((SOL.ByKey[key] and SOL.ByKey[key].R or 800) * 1.9)
	else
		-- (the centre sits a radius on down the path, so they meet its SURFACE on the beat)
		local b = SOL.ByKey[key]
		local _, fwd = flightFrame(ctx, cr.F)
		target = target + fwd * ((b and b.R or 0) * 0.9)
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
			Brightness = i <= 3 and 1.4 or 0.9, Transparency = 0.55,
		})
		table.insert(puffs, { Q = q, S0 = math.min(D, 2600) * (i <= 3 and 1.2 or 0.7), Grow = rng:NextNumber(1.5, 3), P = pos + rng:NextUnitVector() * D * 0.25 })
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
			p.Q.Transparency = K.ns(math.min(0.99, 0.55 + t / 1.1))
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
		local a = r.A + T * 0.015
		local d = sunCF.RightVector * math.cos(a) + sunCF.UpVector * math.sin(a)
		local L = SUN_D * r.L * (0.9 + 0.1 * math.sin(T * 1.7 + r.Ph))
		r.B.Attachment0.WorldPosition = SOL.S + d * SUN_D * 0.42
		r.B.Attachment1.WorldPosition = SOL.S + d * L
	end
	rimUpdate(SOL.Corona, SOL.S, SUN_D / 2, camPos, 0.35 + math.sin(T * 1.3) * 0.03)
	-- the boiling surface and the prominences on the limb
	local toCamS = (camPos - SOL.S).Unit
	for _, q in ipairs(SOL.SunSurf or {}) do
		K.moveQuad(q.Q, CFrame.lookAt(SOL.S + toCamS * SUN_D * 0.52, camPos) * CFrame.Angles(0, 0, T * q.W))
	end
	do
		local fr = CFrame.lookAt(SOL.S, camPos)
		for _, pr in ipairs(SOL.Proms or {}) do
			local a0 = pr.A - pr.Span / 2
			local a1 = pr.A + pr.Span / 2
			local R = SUN_D * 0.5
			local d0 = fr.RightVector * math.cos(a0) + fr.UpVector * math.sin(a0)
			local d1 = fr.RightVector * math.cos(a1) + fr.UpVector * math.sin(a1)
			local out = (d0 + d1).Unit
			pr.B.Attachment0.WorldCFrame = CFrame.fromMatrix(SOL.S + d0 * R, out, fr.LookVector)
			pr.B.Attachment1.WorldCFrame = CFrame.fromMatrix(SOL.S + d1 * R, -out, fr.LookVector)
			local h = R * pr.H * (0.85 + math.sin(T * 0.6 + pr.Ph) * 0.15)
			pr.B.CurveSize0 = h
			pr.B.CurveSize1 = h
		end
	end
	-- the stars ride with the camera (they're "at infinity"); the bright ones twinkle
	if SOL.StarField then
		SOL.StarField.CFrame = CFrame.new(camPos)
		for _, st in ipairs(SOL.BrightStars) do st.B.Brightness = st.Base * (0.8 + 0.2 * math.sin(T * 3 + st.Ph)) end
	end
	-- the belts' dust clouds ride round with the belts
	for _, bd in ipairs(SOL.BeltDust or {}) do
		local w = bd.Icy and 0.004 or 0.012
		local p0 = orbitPos(SOL, SOL.S, bd.Rad, bd.Ang + T * w * ORB) + SOL.N * bd.H
		local pp, sk = pulled(SOL, p0, { 18 + (bd.Ang % 1) * 6, 10 }, T)
		bd.Part.CFrame = CFrame.lookAt(pp, pp + (SOL.S - pp).Unit:Cross(SOL.N)) 
		local on = sk < 0.9
		bd.Dust.Enabled = on
		bd.Grit.Enabled = on
	end

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
				if b.Atmo then b.Atmo.Transparency = 1 end
				if b.Trail then for _, tb in ipairs(b.Trail) do tb.Enabled = false end end
				swallowFlash = 1
			else
				local cf = CFrame.new(p) * b.Tilt * CFrame.Angles(0, T * b.Spin, 0)
				-- (the ringed world they fly through turns its rings square across their path)
				local cr = SOL.CrashByKey and SOL.CrashByKey[b.Key]
				if cr and cr.Rings and b.RingRel then
					local u = smooth((T - (cr.T - 5.5)) / 5.5)
					if u > 0 then
						local _, ffwd = flightFrame(ctx, cr.F)
						local nW = cf:VectorToWorldSpace(b.RingRel.RightVector)
						if nW:Dot(ffwd) < 0 then ffwd = -ffwd end
						local ax = nW:Cross(ffwd)
						if ax.Magnitude > 1e-4 then
							local ang = math.acos(math.clamp(nW:Dot(ffwd), -1, 1)) * u
							cf = CFrame.new(p) * CFrame.fromAxisAngle(ax.Unit, ang) * cf.Rotation
						end
					end
				end
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
				if b.Atmo then
					b.Atmo.CFrame = CFrame.new(p)
					if b.AtmoScaleNow ~= scale then b.AtmoScaleNow = scale b.Atmo.Size = b.AtmoSize0 * math.max(scale, 0.02) end
				end
				if b.Trail then
					-- the trail of light along the orbit it has just come round
					local o = b.Orbit
					local center = b.Parent and (SOL.ByKey[b.Parent].Pos or SOL.S) or SOL.S
					local fade = 1 - math.clamp(s * 3, 0, 1)
					local step = math.clamp(b.D * 0.7 / o[1], 0.003, 0.03)
					local shift = p - base
					local nT = #b.Trail
					local prev = p
					for i, tb in ipairs(b.Trail) do
						local q = orbitPos(SOL, center, o[1], o[2] + T * o[3] * ORB - i * step, b.Incl) + shift * (1 - i / nT)
						tb.Attachment0.WorldPosition = prev
						tb.Attachment1.WorldPosition = q
						tb.Enabled = fade > 0.02 and shift.Magnitude < o[1] * 0.3
						prev = q
					end
				end
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
				base = orbitPos(SOL, SOL.S, r.Rad, r.Ang + T * r.W * ORB) + SOL.N * r.H
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
		local p = camPos + q.Dir * 84000
		K.moveQuad(q.Q, CFrame.lookAt(p, camPos) * CFrame.Angles(0, 0, q.R))
	end
	return swallowFlash
end

--------------------------------------------------------------------------
-- the portal, at size `open` (0..1), spinning `spin` fast
--------------------------------------------------------------------------
local function drawPortal(ctx, T, camPos, open, spin, aura)
	local K = ctx.kit
	local SOL = ctx.SOL
	local P = SOL.Pp
	aura = aura or 0
	local o = math.max(open, 0.001)
	local R = PORTAL_R * o
	local vis = open > 0.01
	local a = vis and math.clamp(open * 1.4, 0, 1) or 0
	-- it faces down onto the system, turned a little toward the camera so it never goes edge-on
	local n = SOL.Axis:Lerp((camPos - P).Unit, 0.15).Unit
	local up = math.abs(n:Dot(SOL.B)) > 0.95 and SOL.A or SOL.B
	local face = CFrame.lookAt(P, P + n, up)
	-- the swirl: the same five layers as the portal over the field, scaled up
	local k = PORTAL_R * 2 / 150
	for i, q in ipairs(SOL.PQuads) do
		local sz = (i == 2 and 120 or 250 - i * 14) * k * o
		K.moveQuad(q, face * CFrame.new(0, 0, -i * 40) * CFrame.Angles(0, 0, T * spin * (i % 2 == 0 and -1 or 1) * (0.25 + i * 0.07)))
		K.setQuadSize(q, sz, sz)
		q.Transparency = K.ns(1 - 0.88 * a)
	end
	-- the dark heart
	K.moveQuad(SOL.PDark, face * CFrame.new(0, 0, -240) * CFrame.Angles(0, 0, T * 0.3))
	K.setQuadSize(SOL.PDark, R * 1.5, R * 1.5)
	SOL.PDark.Transparency = K.ns(1 - a)
	-- the aura: a violet glow spreading out over everything
	for i, au in ipairs(SOL.PAura) do
		K.moveQuad(au.Q, CFrame.lookAt(P, camPos) * CFrame.Angles(0, 0, T * 0.02 * i))
		local sz = PORTAL_R * au.S * (0.3 + 0.7 * aura)
		K.setQuadSize(au.Q, sz, sz)
		au.Q.Transparency = K.ns(1 - (i == 1 and 0.35 or 0.2) * aura * a)
	end
	-- the funnel: swirls stacked down toward the Sun, wide at the bottom
	for _, fz in ipairs(SOL.PFunnel) do
		local z = fz.Z
		local c = P + SOL.Axis * (PORTAL_H * 0.85 * z)
		local r = K.lerp(R * 1.2, 26000, z ^ 0.8) * math.min(1, aura * 1.2 + 0.001)
		K.moveQuad(fz.Q, CFrame.lookAt(c, c + SOL.Axis, up) * CFrame.Angles(0, 0, T * fz.Spin * spin))
		K.setQuadSize(fz.Q, r * 2, r * 2)
		fz.Q.Transparency = K.ns(1 - 0.35 * aura * a * (1 - z * 0.5))
	end
	-- streams of light spiralling up the funnel and into the core
	for _, st in ipairs(SOL.PStreams) do
		local on = aura > 0.05 and vis
		st.Beam.Enabled = on
		if on then
			local z = (st.Z + T * st.Speed * 0.5 * spin) % 1
			local function at(zz)
				local rr = K.lerp(st.R * 6000, R * 0.8, zz ^ 0.7)
				local aa = st.A + zz * st.Twist * 2 + T * 0.15 * spin
				return (face * CFrame.new(math.cos(aa) * rr, math.sin(aa) * rr, -(1 - zz) * PORTAL_H * 0.9)).Position
			end
			st.Beam.Attachment0.WorldPosition = at(z)
			st.Beam.Attachment1.WorldPosition = at(math.min(z + 0.06, 1))
			st.Beam.Width0 = K.lerp(700, 150, z)
			st.Beam.Width1 = K.lerp(600, 100, z)
			st.Beam.Transparency = K.ns(0, 1, 0.3, 1 - 0.7 * aura * math.min(1, z * 4, (1 - z) * 6), 1, 1)
		end
	end
	return face
end

-- everything under the portal's violet aura (0..1)
local AMB0, OAMB0 = Color3.fromRGB(14, 15, 22), Color3.fromRGB(22, 24, 34)
local function setAura(ctx, a)
	local L = game:GetService("Lighting")
	L.Ambient = AMB0:Lerp(Color3.fromRGB(70, 36, 110), a)
	L.OutdoorAmbient = OAMB0:Lerp(Color3.fromRGB(110, 60, 160), a)
	ctx.kit.Grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(222, 200, 255), a)
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
	SOL.W0 = hoverPoint(ctx, 1, T_GO)
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
		drawSolar(ctx, T, cam.Position, dt)
		local open = K.k(T, T_OPEN, T_OPEN + 2.6, E.outBack)
		local aura = K.k(T, T_OPEN + 1.2, T_PULL + 2.5)
		local face = drawPortal(ctx, T, cam.Position, open, 1 + K.k(T, T_PULL, dur) * 1.5, aura)
		setAura(ctx, aura)
		K.starShellUpdate(stars, cam.Position, 0)

		-- the party: holding station in orbit, calm, until the pull takes hold
		local pullOn = K.k(T, T_PULL, dur, E.inQuad)
		local toPortal = (SOL.Pp - cam.Position).Unit
		local center
		for slot, rig in pairs(ctx.rigs) do
			local p = hoverPoint(ctx, slot, T) + K.zeroGOffset(t * 0.6, slot, 0.8)
			local tug = (SOL.Pp - p).Unit
			p = p + tug * (pullOn * pullOn * 40)
			local radial = (p - SOL.ByKey.Earth.Fixed).Unit
			local fwd0 = SOL.B:Cross(radial).Unit
			local yaw = (slot - 1) * 0.9 + t * 0.03
			local body = CFrame.fromMatrix(p, fwd0:Cross(radial).Unit, radial) * CFrame.Angles(0, yaw, 0)
			body = body * CFrame.Angles(math.sin(t * 0.37 + slot) * 0.06, 0, math.sin(t * 0.29 + slot * 2) * 0.05)
			if pullOn > 0 then
				-- tipping over, head first, toward it
				local toward = CFrame.lookAt(p, p + tug) * CFrame.Angles(math.rad(-70), 0, 0)
				body = body:Lerp(toward, pullOn * 0.85)
			end
			rig:setCF(body)
			local pose = K.mixPose(K.Poses.Float, K.zeroGPose(t * 0.7, slot, 0.35), 0.5)
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

		-- camera: 0-4.2 out of the blue; 4.2-6.4 close on you; 6.4-12.4 the showcase
		-- (Saturn, then the whole system from above); 12.4-15.2 the portal tears open
		-- over it all; 15.2-18.6 everything funnelling up into it; 18.6-22 the pull
		if t < 4.2 then
			local e = K.k(t, 0, 4.2, E.inOutSine)
			local down = CFrame.lookAt(center + radial * 45 + SOL.B * 8, center - radial * 400, SOL.A)
			local back = -SOL.D
			local rev = CFrame.lookAt(center + back * 70 + radial * 24 + SOL.B * 22, center + SOL.D * 400 + radial * 60) * CFrame.Angles(0, 0, math.rad(-6))
			K.setCam(down:Lerp(rev, e), K.lerp(74, 60, e))
		elseif t < 6.4 then
			local e = K.k(t, 4.2, 6.4)
			local p = head + (rcf.LookVector * 6 + rcf.RightVector * 2.5 - radial * 1.2) * K.lerp(1.15, 0.95, e)
			K.setCam(CFrame.lookAt(p, head, radial), 38)
		elseif t < 9.4 then
			-- gliding round Saturn on its sunlit side, its moons wheeling past
			local e = K.k(t, 6.4, 9.4, E.inOutSine)
			local sat = SOL.ByKey.Saturn
			local sp = sat.Pos or SOL.S
			local toSun = (SOL.S - sp).Unit
			local tan = SOL.N:Cross(toSun).Unit
			local dir = (toSun * 0.55 + tan * K.lerp(-0.85, 0.35, e) + SOL.N * K.lerp(0.4, 0.2, e)).Unit
			local p = sp + dir * (sat.R or 3000) * K.lerp(3.3, 2.5, e)
			K.setCam(CFrame.lookAt(p, sp + (SOL.S - sp) * 0.04, SOL.N), 50)
		elseif t < T_OPEN then
			-- high above it all: the whole system turning, every orbit at once
			local e = K.k(t, 9.4, T_OPEN, E.inOutSine)
			local a = K.lerp(-0.5, 0.25, e)
			local hor = SOL.A * math.cos(a) + SOL.B * math.sin(a)
			local p = SOL.S + hor * K.lerp(56000, 48000, e) + SOL.N * K.lerp(16000, 22000, e)
			K.setCam(CFrame.lookAt(p, SOL.S + hor * 12000, SOL.N), 58)
		elseif t < T_PULL then
			-- up at the portal as it tears open, then pulling back to take in the system below it
			local e = K.k(t, T_OPEN + 0.6, T_PULL, E.inOutSine)
			local wide = SOL.S + SOL.A * 38000 - SOL.N * 8000
			local dirW = (wide - SOL.Pp).Unit
			local p = SOL.Pp + dirW * K.lerp(34000, (wide - SOL.Pp).Magnitude, e)
			local look = SOL.Pp:Lerp(SOL.S + SOL.N * 14000, e)
			K.setCam(CFrame.lookAt(p, look), K.lerp(62, 70, e))
			K.shake(0.1 + math.min(open, 1) * 0.3, 0.1, 12, true)
		elseif t < 18.6 then
			-- a slow turn round the system as its worlds spiral up into the funnel
			local e = K.k(t, T_PULL, 18.6, E.inOutSine)
			local a = K.lerp(0, -0.5, e)
			local hor = SOL.A * math.cos(a) + SOL.B * math.sin(a)
			local p = SOL.S + hor * K.lerp(38000, 44000, e) - SOL.N * K.lerp(8000, 9000, e)
			K.setCam(CFrame.lookAt(p, SOL.S + SOL.N * 14000), K.lerp(70, 72, e))
			K.shake(0.25, 0.1, 14, true)
		else
			-- over their shoulders: the portal filling the sky, the pull taking them
			local e = K.k(t, 18.6, dur, E.inQuad)
			local p = center - toPortal * K.lerp(34, 16, e) + radial * K.lerp(10, 4, e) + SOL.B * 8
			K.setCam(CFrame.lookAt(p, center + toPortal * 800), K.lerp(52, 70, e))
			K.shake(0.3 + e * 1.4, 0.1, 18, true)
		end
		cue("wonder", t >= 3.2, function()
			ctx.setMusic(K.S.M_Wonder, 0.6, 2.5)
		end)
		cue("open", t >= T_OPEN, function()
			K.sfx(K.S.Portal, 1, 0.5, { Reverb = 3 })
			K.sfx(K.S.DarkDrone, 0.8, 0.7)
			K.sfx(K.S.Thunder, 0.6, 0.6)
			K.muffle(0, 1.5)
			ctx.fadeMusic(0.25, 2)
			K.gradePunch(0.2, 0, 1.5)
			rumble = K.loop(K.S.Rumble, 0.5, 1)
		end)
		cue("pull", t >= T_PULL, function()
			K.sfx(K.S.Riser, 0.9, 0.7)
			K.sfx(K.S.Whoosh, 0.9, 0.6)
		end)
		cue("drop", t >= dur - 0.5, function()
			SOL.EpicOn = true
			ctx.setMusic(K.S.M_EpicAnime, 0.75, 0.3, 46)
		end)
		cue("yank", t >= dur - 0.25, function()
			K.sfx(K.S.Whoosh, 1, 0.5)
			K.sfx(K.S.BigHit, 0.7, 1.2)
			K.flash(0.3, Color3.fromRGB(190, 170, 255), 0.35)
		end)
		if open > 0.3 and math.random() < 0.08 then portalBolt(ctx, face, PORTAL_R * math.min(open, 1) * 1.2) end
		K.stream(center)
	end)
	K.fadeSound(amb, 0, 1, true)
	if rumble then K.fadeSound(rumble, 0, 1, true) end
end

--------------------------------------------------------------------------
-- the flight (DRAG and VORTEX share it): a head-first dive at the portal,
-- knocked tumbling for a moment by everything they smash through
--------------------------------------------------------------------------
local function flyParty(ctx, T, t, wild)
	local K = ctx.kit
	local SOL = ctx.SOL
	local f = progress(T)
	local p0, fwd, side, up = flightFrame(ctx, f)
	local hit = T - (SOL.LastHitT or -99)
	local st = hit < 1.2 and (1 - hit / 1.2) ^ 1.5 or 0
	local center
	for slot, rig in pairs(ctx.rigs) do
		local a = slot * 2.4 + t * 0.3
		local r = ctx.n > 1 and (5 + (slot % 3) * 3) or 0
		local lag = ((slot - 1) % 4) * 4
		local p = p0 - fwd * lag + side * math.cos(a) * r + up * math.sin(a) * r + K.zeroGOffset(t * 1.5, slot, 0.8)
		p = p + (side * math.sin(hit * 11 + slot) + up * math.cos(hit * 8 + slot)) * st * 3
		-- head first, belly down, arms out in front
		local body = CFrame.lookAt(p, p + fwd, up) * CFrame.Angles(math.rad(-90), 0, 0)
		-- a slow roll in the dive, and a hard tumble after a hit
		local dirS = slot % 2 == 0 and 1 or -1
		body = body * CFrame.Angles(st * math.sin(hit * 7) * 1.1, math.sin(t * 0.8 + slot) * 0.25 + st * hit * 9 * dirS, st * math.cos(hit * 6) * 0.7)
		rig:setCF(body)
		local dive = { Neck = K.A(45, 0, 0), RS = K.A(160, 0, -12), LS = K.A(150, 0, 14), RH = K.A(-14, 0, 6), LH = K.A(-6, 0, -8) }
		local pose = K.mixPose(dive, K.zeroGPose(t * 1.6, slot, 0.5), 0.25 + wild * 0.15)
		if st > 0 then pose = K.mixPose(pose, K.flail(t, slot, 1.3, K.Poses.Blown), st) end
		rig:setPose(K.safeArms(pose))
		rig:apply()
		if rig == ctx.myRig then center = p end
	end
	return center or p0, fwd, side, up, f
end

local function updateStreaks(ctx, camPos, fwd, rush, t, on)
	for _, st in ipairs(ctx.SOL.Streaks) do
		st.Beam.Enabled = on
		if on then
			local z = (st.Z + t * st.Speed * (0.6 + rush * 2.4)) % 1
			local b = CFrame.lookAt(camPos, camPos + fwd) * CFrame.new(math.cos(st.Ang) * st.R, math.sin(st.Ang) * st.R, -z * 500 + 150)
			st.Beam.Attachment0.WorldPosition = b.Position
			st.Beam.Attachment1.WorldPosition = (b * CFrame.new(0, 0, 20 + rush * 260)).Position
			st.Beam.Width0 = 0.06 + rush * 0.3
		end
	end
end

-- a meteor: a burning rock hurtling head-on at the party along their path
local function spawnMeteor(ctx, c)
	local K = ctx.kit
	local rocks = K.Assets.Rocks:GetChildren()
	local r = rocks[math.random(1, #rocks)]:Clone()
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CanTouch = false
	r.CastShadow = false
	r.Size = r.Size / math.max(r.Size.X, r.Size.Y, r.Size.Z) * 220
	r.Material = Enum.Material.Slate
	r.Color = Color3.fromRGB(95, 80, 72)
	r.Parent = ctx.SOL.FX
	K.emitter(r, {
		Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(Color3.fromRGB(255, 190, 110), Color3.fromRGB(255, 90, 40)),
		Size = K.ns(0, 120, 1, 20), Transparency = K.ns(0, 0.2, 1, 1), Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(0, 0), Rate = 80, Brightness = 3,
	})
	c.Rock = r
end

-- the crashes: every target that the party reaches blows apart
local function doCrashes(ctx, T, fwd)
	local K = ctx.kit
	local SOL = ctx.SOL
	for _, c in ipairs(CRASH) do
		if c.Meteor then
			if not c.Done then
				if not c.Rock and T >= c.T - 1.6 then spawnMeteor(ctx, c) end
				if c.Rock and T < c.T then
					local hp, hf = flightFrame(ctx, progress(c.T))
					c.Rock.CFrame = CFrame.new(hp + hf * (c.T - T) * 1400) * CFrame.Angles(T * 1.3, T * 0.9, 0)
				end
				if T >= c.T then
					c.Done = true
					local pos = c.Rock and c.Rock.Position or flightPoint(ctx, progress(T))
					if c.Rock then c.Rock:Destroy() c.Rock = nil end
					burst(ctx, pos, 520, Color3.fromRGB(150, 120, 100), fwd)
					SOL.LastHitT = T
					K.sfx(K.S.RockBoom, 1, 1.1)
					K.sfx(K.S.BigHit, 0.6, 1.2)
					K.shake(2.5, 0.6)
					K.kick(8, 0.5)
					K.flash(0.25, Color3.fromRGB(255, 200, 150), 0.25)
				end
			end
		else
			local hitNow = false
			if not c.Done and not c.Rings and T >= c.T - 3 then
				local b0 = SOL.ByKey[c.Key]
				if b0 and b0.Pos and b0.R then
					local pp = flightPoint(ctx, progress(T))
					hitNow = (b0.Pos - pp).Magnitude < b0.R * 1.05 + 150
				end
			end
			if not c.Done and (T >= c.T or hitNow) then
				c.Done = true
				SOL.LastHitT = T
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
						K.flash(0.3, Color3.fromRGB(190, 230, 255), 0.3)
						K.shake(3, 0.8)
					elseif c.Rings then
						-- Saturn: straight through the rings, which shatter into ice
						if b.Ring then b.Ring.Transparency = 1 b.Ring = nil end
						burst(ctx, flightPoint(ctx, c.F), 2600, Color3.fromRGB(235, 215, 170), fwd, true)
						K.sfx(K.S.Glass2, 1, 0.7)
						K.sfx(K.S.Glass3, 0.9, 0.9)
						K.sfx(K.S.Whoosh, 1, 0.6)
						K.flash(0.3, Color3.fromRGB(255, 235, 200), 0.3)
						K.shake(3.5, 1)
					else
						burst(ctx, b.Pos, b.D, b.Part.Color == Color3.new(0, 0, 0) and Color3.fromRGB(170, 150, 130) or b.Part.Color, fwd)
						b.Gone = true
						b.Part.Transparency = 1
						if b.Ring then b.Ring.Transparency = 1 end
						if b.Rim then b.Rim.setEnabled(false) end
						if b.Atmo then b.Atmo.Transparency = 1 end
						if b.Trail then for _, tb in ipairs(b.Trail) do tb.Enabled = false end end
						K.sfx(K.S.BigHit, 1, 0.8)
						K.sfx(K.S.RockBoom, 1, 0.9)
						K.sfx(K.S.Boom, 0.8, 0.7)
						K.shake(4, 1.1)
						K.kick(14, 0.7)
						K.flash(0.3, Color3.fromRGB(255, 220, 190), 0.3)
					end
				end
			end
		end
	end
end

local function flightSetup(ctx)
	local SOL = ctx.SOL
	if not SOL.W0 then
		solarFrame(ctx, ctx.kit.lightDir())
		SOL.W0 = hoverPoint(ctx, 1, T_GO)
		SOL.CrashByKey = {}
		for _, c in ipairs(CRASH) do SOL.CrashByKey[c.Key] = c end
	end
	if not SOL.EpicOn then
		-- (when previewing from here: the music the pull drops into)
		SOL.EpicOn = true
		ctx.setMusic(ctx.kit.S.M_EpicAnime, 0.75, 0.3, 46)
	end
end

-- the chase camera's roll round the dive axis: it swings round now and then
local function chaseAngle(t)
	local function k(x, a, b) x = math.clamp((x - a) / (b - a), 0, 1) return x * x * (3 - 2 * x) end
	return 0.9 * k(t, 1.5, 3.5) - 1.6 * k(t, 5.5, 7.5) + 1.2 * k(t, 9, 11) + math.sin(t * 0.7) * 0.12
end

--------------------------------------------------------------------------
-- DRAG: diving at the portal, the camera riding behind, smashing through
-- the Moon, meteors, a comet, Mars and Jupiter
--------------------------------------------------------------------------
function Ch.Drag(ctx, t0, dur)
	local K = ctx.kit
	local SOL = ctx.SOL
	local set = ctx.sets.Solar
	set.Parent = ctx.stage
	local OFF = ctx.TL.Chapter("Drag").Start - ctx.TL.Chapter("Space").Start
	K.lighting("Space", 0)
	flightSetup(ctx)
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
		drawPortal(ctx, T, camPos, 1, 2.5 + t * 0.1, 0.4)
		setAura(ctx, 1)
		K.starShellUpdate(stars, camPos, 0)
		local center, fwd, side, up, f = flyParty(ctx, T, t, 1)
		local speed = (flightPoint(ctx, progress(T + 0.05)) - flightPoint(ctx, f)).Magnitude / 0.05
		local rush01 = math.clamp(speed / 2000, 0, 1)
		doCrashes(ctx, T, fwd)

		-- the chase: behind and a little above, rolling round the dive now and then;
		-- knocked back a little by every hit
		local ang = chaseAngle(t)
		local cu = up * math.cos(ang) + side * math.sin(ang)
		local hit = T - (SOL.LastHitT or -99)
		local jolt = hit < 0.8 and (1 - hit / 0.8) or 0
		local dist = 17 + math.sin(t * 0.6) * 3 + jolt * 8
		local camP = center - fwd * dist + cu * (5.5 + jolt * 3)
		local camCF = CFrame.lookAt(camP, center + fwd * 140 + cu * 2, cu)
		K.setCam(camCF, 68 + rush01 * 10 + jolt * 8)
		K.shake(0.25 + rush01 * 0.5, 0.1, 30, true)
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
-- VORTEX: the last stretch, straight on into the portal
--------------------------------------------------------------------------
function Ch.Vortex(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local SOL = ctx.SOL
	local set = ctx.sets.Solar
	set.Parent = ctx.stage
	local OFF = ctx.TL.Chapter("Vortex").Start - ctx.TL.Chapter("Space").Start
	local DRAG = ctx.TL.Chapter("Drag").Duration or ctx.TL.Chapter("Drag").Dur or 13
	K.lighting("Space", 0)
	flightSetup(ctx)
	local stars = SOL.Stars or K.starShell(set)
	SOL.Stars = stars
	local rush = K.loop(K.S.Rush, 0.7, 0.4, 1)
	local drone = K.loop(K.S.DarkDrone, 0.5, 1.5)
	for _, rig in pairs(ctx.rigs) do rig.Smooth = 8 end
	local cue = K.once()
	local ang0 = chaseAngle(DRAG)

	K.run(t0, dur, function(t, dt)
		local T = t + OFF
		local camPos = K.Cam.CF.Position
		drawSolar(ctx, T, camPos, dt)
		local e = K.k(t, 0, dur, E.inQuad)
		local face = drawPortal(ctx, T, camPos, 1 + e * 0.15, 3.5 + e * 4, 0.4 + e * 0.4)
		setAura(ctx, 1)
		K.starShellUpdate(stars, camPos, 0)
		local center, fwd, side, up = flyParty(ctx, T, t + DRAG, 1)
		doCrashes(ctx, T, fwd)
		-- behind them, the spin winding up as the swirl takes them
		local roll = ang0 + e * e * 5
		local cu = up * math.cos(roll) + side * math.sin(roll)
		local camP = center - fwd * K.lerp(17, 9, e) + cu * K.lerp(5.5, 3, e)
		local camCF = CFrame.lookAt(camP, SOL.Pp, cu)
		K.setCam(camCF, K.lerp(72, 115, e))
		K.shake(0.6 + e * 2, 0.1, 25, true)
		-- inside the swirl: its layers wrap round the camera into a spinning tunnel
		local tun = K.k(t, 0.3, 2.5)
		if tun > 0 then
			if not SOL.TunnelTint then
				SOL.TunnelTint = true
				local tints = { Color3.fromRGB(190, 110, 255), Color3.fromRGB(140, 70, 255), Color3.fromRGB(235, 170, 255), Color3.fromRGB(110, 90, 255) }
				for i, fz in ipairs(SOL.PFunnel) do fz.Q.Color = ColorSequence.new(tints[(i % #tints) + 1]) end
			end
			for i, fz in ipairs(SOL.PFunnel) do
				local d = 150 * i * i + 200
				local pos = (camCF * CFrame.new(0, 0, -d)).Position
				K.moveQuad(fz.Q, CFrame.lookAt(pos, camCF.Position) * CFrame.Angles(0, 0, t * fz.Spin * 6))
				K.setQuadSize(fz.Q, d * 3.4, d * 3.4)
				fz.Q.Transparency = K.ns(1 - 0.6 * tun)
			end
		end
		updateStreaks(ctx, camCF.Position, fwd, 0.8 + e * 0.2, t, true)
		K.Grade.Saturation = 0.12 + e * 0.15
		if math.random() < 0.12 then portalBolt(ctx, face, PORTAL_R) end
		cue("near", t >= 0.2, function()
			K.sfx(K.S.Portal2, 0.8, 0.5, { Reverb = 3 })
			K.sfx(K.S.Riser, 0.8, 0.6)
		end)
		cue("in", t >= dur - 0.35, function()
			K.sfx(K.S.Portal, 1, 0.6, { Reverb = 3 })
			K.sfx(K.S.Whoosh, 1, 0.4)
			K.flash(0.5, Color3.fromRGB(210, 180, 255), 0.8)
		end)
		K.stream(center)
	end)
	updateStreaks(ctx, Vector3.zero, Vector3.zAxis, 0, 0, false)
	K.fadeSound(rush, 0, 0.5, true)
	K.fadeSound(drone, 0, 0.5, true)
	K.letterbox(true, 0.4) -- (the bars stay on for the rest of the cutscene)
	K.Grade.Saturation = 0.12
	K.Grade.TintColor = Color3.new(1, 1, 1)
	set.Parent = nil
end

return Ch
