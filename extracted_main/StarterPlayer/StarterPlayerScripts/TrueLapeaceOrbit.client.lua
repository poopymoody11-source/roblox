--==================================================
-- TRUE LAPEACE ORBIT  (client)
--
-- Every lapis in the game circles True Lapeace (Workspace.Dungeon) the
-- same way the ores circle interstellar lapis: the same orbit maths
-- (tumbling theta/phi orbit, spin, random wobble), scaled down to True
-- Lapeace's size. Each orbiting copy keeps ITS OWN EFFECTS (particles,
-- beams, glow, outline); only scripts, sounds and their own orbiting
-- ores are removed. The RGB colour cycle and the La Peace halo wobble
-- (which were scripts) are redone here.
--
-- True Lapeace itself is brought to life: it slowly turns and bobs, its
-- rings turn with it and its light breathes (it used to just sit there).
--
-- The orbit follows True Lapeace wherever it goes (so when the
-- Anti-Spiral drags it into the portal they go with it), hides while
-- True Lapeace is gone, and comes back if it comes back (quest reset).
-- Nothing runs while you're far away from the dungeon.
--==================================================

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dungeon = workspace:WaitForChild("Dungeon")
local trueLapeace = dungeon:WaitForChild("True Lapeace")
local visuals = ReplicatedStorage:WaitForChild("LapisVisuals")

-- interstellar lapis is ~22.5 studs with ores orbiting at 60; True Lapeace
-- is ~4 studs, so everything is scaled by the same ratio
local SCALE = 4 / 22.47
local RADIUS = 60 * SCALE * 1.15
local LAPIS_SIZE = 17 * SCALE * 0.8
local SPEED_THETA, SPEED_PHI = 60, 40
local SPIN_X, SPIN_Y, SPIN_Z = 40, 60, 25
local ACTIVE_RANGE = 300 -- studs from the camera

-- True Lapeace's own idle
local TL_SPIN = 25       -- degrees / sec
local TL_BOB = 0.6       -- studs
local TL_BOB_SPEED = 1.4

local folder = Instance.new("Folder")
folder.Name = "TrueLapeaceOrbit"
folder.Parent = dungeon

local STRIP_CLASS = { Script = true, LocalScript = true, ModuleScript = true, Sound = true }
local STRIP_NAME = { Ores = true, ["67-mini"] = true, ["67-big"] = true }

local rgbTargets = {}   -- Highlights / emitters that cycle through the rainbow
local wobblers = {}     -- La Peace halo parts

local function plainCopy(template)
	local m = template:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d.Parent and (STRIP_CLASS[d.ClassName] or STRIP_NAME[d.Name]) then
			d:Destroy()
		end
	end
	local parts = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Massless = true
		end
	end
	if parts == 0 then m:Destroy() return nil end
	local main = m:FindFirstChild("model")
	if main and main:IsA("BasePart") then m.PrimaryPart = main end
	-- size from the lapis itself, not from its effects
	local biggest = main and math.max(main.Size.X, main.Size.Y, main.Size.Z) or 2
	if biggest > 0 then pcall(function() m:ScaleTo(m:GetScale() * (LAPIS_SIZE / biggest)) end) end
	-- make sure every effect is actually running (some ship disabled and
	-- were only switched on by the lapis' own scripts)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = true
		end
		if template.Name == "rgb_lapis" and (d:IsA("Highlight") or d:IsA("ParticleEmitter")) then
			table.insert(rgbTargets, d)
		end
	end
	return m
end

local orbiters = {}
local rng = Random.new()
for _, template in ipairs(visuals:GetChildren()) do
	if template:IsA("Model") then
		local m = plainCopy(template)
		if m then
			m.Name = template.Name .. "_orbit"
			m.Parent = folder
			table.insert(orbiters, {
				m = m,
				theta = rng:NextNumber(0, 360), phi = rng:NextNumber(0, 360),
				sx = rng:NextNumber(0, 360), sy = rng:NextNumber(0, 360), sz = rng:NextNumber(0, 360),
				amp = rng:NextNumber(5, 30), wspd = rng:NextNumber(0.5, 4),
				px = rng:NextNumber(0, math.pi * 2), py = rng:NextNumber(0, math.pi * 2), pz = rng:NextNumber(0, math.pi * 2),
				my = rng:NextNumber(1.0, 1.6), mz = rng:NextNumber(0.4, 1.0),
			})
		end
	end
end

--------------------------------------------------
-- True Lapeace idle (turn + bob + breathing light)
--------------------------------------------------
local tlMain = trueLapeace:FindFirstChild("model")
local tlHome = tlMain and tlMain.CFrame
local tlParts, tlRel = {}, {}
local lights = {}
if tlMain then
	for _, d in ipairs(trueLapeace:GetDescendants()) do
		if d:IsA("BasePart") then
			-- loose parts (the star) would just fall; pin them
			local welded = false
			for _, w in ipairs(d:GetChildren()) do
				if w:IsA("WeldConstraint") or w:IsA("Weld") then welded = true end
			end
			if not welded then
				d.Anchored = true
				table.insert(tlParts, d)
				tlRel[d] = tlHome:ToObjectSpace(d.CFrame)
			end
		elseif d:IsA("PointLight") then
			table.insert(lights, { l = d, b = d.Brightness, r = d.Range })
		end
	end
end
local cfs = table.create(#tlParts)

for _, o in ipairs(orbiters) do
	local main = o.m.PrimaryPart
	for _, d in ipairs(o.m:GetDescendants()) do
		if main and d:IsA("BasePart") and d.Name:lower():find("halo") then
			table.insert(wobblers, { part = d, orbiter = o, offset = main.CFrame:ToObjectSpace(d.CFrame) })
		end
	end
end

local function centre()
	if tlMain and tlMain.Parent then return tlMain.Position end
	return trueLapeace:GetPivot().Position
end

local time = 0
local tlAngle = 0
RunService.Heartbeat:Connect(function(dt)
	-- gone (taken by the Anti-Spiral): hide the orbit until it's back
	if not trueLapeace:IsDescendantOf(workspace) then
		if folder.Parent then folder.Parent = nil end
		return
	elseif folder.Parent == nil then
		folder.Parent = dungeon
	end
	local cam = workspace.CurrentCamera
	local c = centre()
	if cam and (cam.CFrame.Position - c).Magnitude > ACTIVE_RANGE then return end
	time += dt

	-- True Lapeace turns and bobs, unless something is holding it
	if tlHome and not trueLapeace:GetAttribute("Grabbed") and #tlParts > 0 then
		tlAngle = (tlAngle + math.rad(TL_SPIN) * dt) % (math.pi * 2)
		local bob = math.sin(time * TL_BOB_SPEED) * TL_BOB
		local main = CFrame.new(tlHome.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, tlAngle, 0) * tlHome.Rotation
		for i, p in ipairs(tlParts) do cfs[i] = main * tlRel[p] end
		workspace:BulkMoveTo(tlParts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		c = centre()
	end
	local breathe = 0.75 + 0.25 * math.sin(time * 2.2)
	for _, l in ipairs(lights) do
		if l.l.Parent then
			l.l.Brightness = l.b * breathe
			l.l.Range = l.r * (0.9 + 0.1 * breathe)
		end
	end

	for _, o in ipairs(orbiters) do
		o.theta = (o.theta + SPEED_THETA * dt) % 360
		o.phi = (o.phi + SPEED_PHI * dt) % 360
		local tr, pr = math.rad(o.theta), math.rad(o.phi)
		local offset = Vector3.new(RADIUS * math.sin(pr) * math.cos(tr), RADIUS * math.cos(pr), RADIUS * math.sin(pr) * math.sin(tr))
		o.sx = (o.sx + SPIN_X * dt) % 360
		o.sy = (o.sy + SPIN_Y * dt) % 360
		o.sz = (o.sz + SPIN_Z * dt) % 360
		local wx = math.sin(time * o.wspd + o.px) * o.amp
		local wy = math.sin(time * o.wspd * o.my + o.py) * o.amp
		local wz = math.sin(time * o.wspd * o.mz + o.pz) * o.amp
		o.m:PivotTo(CFrame.new(c + offset) * CFrame.Angles(math.rad(o.sx + wx), math.rad(o.sy + wy), math.rad(o.sz + wz)))
	end
	-- rainbow cycle (rgb lapis)
	local hueCol = Color3.fromHSV((time * 0.33) % 1, 1, 1)
	for _, d in ipairs(rgbTargets) do
		if d.Parent then
			if d:IsA("Highlight") then
				d.FillColor, d.OutlineColor = hueCol, hueCol
			else
				d.Color = ColorSequence.new(hueCol)
			end
		end
	end
	-- halo wobble (la peace lapis)
	for _, w in ipairs(wobblers) do
		local main = w.orbiter.m.PrimaryPart
		if main and w.part.Parent then
			w.part.CFrame = main.CFrame * w.offset * CFrame.Angles(math.sin(time * 2) * math.rad(8), 0, math.cos(time * 2) * math.rad(8))
		end
	end
end)
