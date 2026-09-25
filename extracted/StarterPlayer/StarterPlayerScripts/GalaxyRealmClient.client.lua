--==================================================
-- GALAXY REALM (client)
-- Brings the boss arena's sky to life: the galaxies and the great
-- spiral below turn, stars and constellations twinkle, the rune
-- circles and armillary rings revolve, and the star fragments drift
-- in slow orbits round the island. Everything here is visual only
-- and runs on each client (nothing replicates).
-- The realm itself is built in Studio: workspace.BossFight.GalaxyRealm
--==================================================
local RunService = game:GetService("RunService")

local bossFight = workspace:WaitForChild("BossFight", 60)
if not bossFight then return end
local realm = bossFight:WaitForChild("GalaxyRealm", 60)
if not realm then return end

local CENTER = Vector3.new(0, 0, 20000)
local ACTIVE_RANGE = 9000   -- only animate while the camera is near the arena

local spinners = {}    -- hosts that turn about their own axis (galaxies, runes)
local armillary = {}   -- rings that precess round the island
local twinkles = {}    -- beams whose brightness flickers
local lines = {}       -- constellation lines that shimmer
local cores = {}       -- galaxy cores that breathe
local fragments = {}   -- star fragments that orbit
local comets = {}      -- comets streaking across the sky

-- first-seen poses, kept across re-scans so nothing jumps when more streams in
local baseCF = {}
local fragInfo = {}

local function collect()
	table.clear(spinners) table.clear(armillary) table.clear(twinkles)
	table.clear(lines) table.clear(cores) table.clear(fragments) table.clear(comets)
	for _, d in ipairs(realm:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Spin") then
			baseCF[d] = baseCF[d] or d.CFrame
			local entry = { Part = d, Base = baseCF[d], Spin = d:GetAttribute("Spin") }
			if d.Name:find("^Armillary") then
				entry.Offset = baseCF[d].Position - CENTER
				table.insert(armillary, entry)
			else
				table.insert(spinners, entry)
			end
		elseif d:IsA("Beam") then
			if d.Name == "Twinkle" or d.Name == "ConstStar" then
				table.insert(twinkles, { Beam = d, Base = d:GetAttribute("Base") or 0, Phase = d:GetAttribute("Phase") or 0, Speed = 0.6 + ((d:GetAttribute("Phase") or 0) % 1) * 1.8 })
			elseif d.Name == "ConstLine" then
				table.insert(lines, { Beam = d, Base = d:GetAttribute("Base") or 0.45, Phase = d:GetAttribute("Phase") or 0 })
			elseif d.Name == "Core" then
				table.insert(cores, { Beam = d, Bright = d.Brightness, Phase = d:GetAttribute("Phase") or 0 })
			end
		elseif d:IsA("BasePart") and d.Name == "Comet" and d:GetAttribute("Mid") then
			table.insert(comets, { Part = d, Mid = d:GetAttribute("Mid"), Dir = d:GetAttribute("Dir"), Len = d:GetAttribute("Len") or 30000, Speed = d:GetAttribute("Speed") or 600, Phase = d:GetAttribute("Phase") or 0 })
		elseif d:IsA("Model") and d.Name == "Fragment" and d.PrimaryPart then
			if not fragInfo[d] then
				local pivot = d:GetPivot()
				local rel = pivot.Position - CENTER
				fragInfo[d] = {
					Model = d, Rot = pivot.Rotation, Radius = Vector2.new(rel.X, rel.Z).Magnitude,
					Angle = math.atan2(rel.Z, rel.X), Height = rel.Y,
					Orbit = d:GetAttribute("Orbit") or 0.02, Spin = d:GetAttribute("Spin") or 0.3,
					Bob = d:GetAttribute("Bob") or 1, Phase = d:GetAttribute("Phase") or 0,
				}
			end
			table.insert(fragments, fragInfo[d])
		end
	end
end
collect()

-- the gold arena floor turns slowly about its centre (visual only: the collision
-- floor underneath is a round disc, so nothing about the fight changes)
local dressing = bossFight:FindFirstChild("ArenaDressing")
local DRESS_SPIN = 0.05 -- radians per second
local dressBase = dressing and dressing:GetPivot()
local dressAccum = 0

local t0 = os.clock()
local slowAccum = 0
RunService.RenderStepped:Connect(function(dt)
	if realm.Parent == nil or not realm:IsDescendantOf(workspace) then return end
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - CENTER).Magnitude > ACTIVE_RANGE then return end
	local t = os.clock() - t0

	-- every frame: the things that move
	for _, s in ipairs(spinners) do
		s.Part.CFrame = s.Base * CFrame.Angles(0, 0, t * s.Spin)
	end
	for _, a in ipairs(armillary) do
		local turn = CFrame.Angles(0, t * a.Spin, 0)
		a.Part.CFrame = CFrame.new(CENTER + turn:VectorToWorldSpace(a.Offset)) * turn * a.Base.Rotation * CFrame.Angles(math.sin(t * 0.2 + a.Spin * 50) * 0.06, 0, 0)
	end
	for _, f in ipairs(fragments) do
		local ang = f.Angle + t * f.Orbit
		local pos = CENTER + Vector3.new(math.cos(ang) * f.Radius, f.Height + math.sin(t * 0.6 + f.Phase) * f.Bob, math.sin(ang) * f.Radius)
		f.Model:PivotTo(CFrame.new(pos) * f.Rot * CFrame.Angles(0, t * f.Spin, t * f.Spin * 0.3))
	end
	if dressing and dressBase and dressing.Parent then
		dressAccum += dt
		if dressAccum >= 1 / 30 then
			dressAccum = 0
			local pivot = CFrame.new(CENTER.X, dressBase.Y, CENTER.Z)
			dressing:PivotTo(pivot * CFrame.Angles(0, t * DRESS_SPIN, 0) * pivot:ToObjectSpace(dressBase))
		end
	end
	for _, c in ipairs(comets) do
		local s = (c.Phase * c.Len + t * c.Speed) % c.Len - c.Len / 2
		local pos = c.Mid + c.Dir * s
		c.Part.CFrame = CFrame.lookAt(pos, pos + c.Dir)
	end

	-- ~15 times a second: the twinkling (cheaper, and it reads the same)
	slowAccum += dt
	if slowAccum < 1 / 15 then return end
	slowAccum = 0
	for _, s in ipairs(twinkles) do
		local w = 0.5 + 0.5 * math.sin(t * s.Speed + s.Phase)
		local flick = w * w * w
		s.Beam.Transparency = NumberSequence.new(math.clamp(s.Base + (1 - s.Base) * 0.55 * flick, 0, 0.95))
	end
	for _, l in ipairs(lines) do
		local w = 0.5 + 0.5 * math.sin(t * 0.7 + l.Phase)
		l.Beam.Transparency = NumberSequence.new(math.clamp(l.Base + 0.25 * w, 0, 0.95))
	end
	for _, c in ipairs(cores) do
		c.Beam.Brightness = c.Bright * (0.85 + 0.15 * math.sin(t * 0.9 + c.Phase))
	end
end)

-- (the realm streams in piece by piece: re-scan once things settle)
local pending = false
realm.DescendantAdded:Connect(function()
	if pending then return end
	pending = true
	task.delay(1.5, function()
		pending = false
		collect()
	end)
end)
