--==================================================
-- OP STAFF COMMAND-BLOCK AURA  (client, one script for every staff)
--
-- Replaces the old CommandAura script that lived INSIDE the tool.
-- That one died with the tool on ascend/reset/respawn before it could
-- clean up, so its parts were left floating in workspace.ClientAuras.
-- This lives in PlayerScripts, never dies, and tears an aura down the
-- same frame its staff disappears.
--
-- The look: the command block levitates on a scrolling tractor beam
-- from the staff tip, inside a tumbling wireframe cage and a pulsing
-- force-field shell, with two spinning hex-field halos underneath,
-- orbiting mini command cubes tethered to it by crackling beams, code
-- sparks, and a little terminal typing commands above it.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BLOCK_NAME = "commandblock_lapis"
local VIEW_DISTANCE = 140

local GREEN = Color3.fromRGB(90, 255, 140)
local PURPLE = Color3.fromRGB(190, 110, 255)
local ORANGE = Color3.fromRGB(255, 170, 60)
local CYAN = Color3.fromRGB(90, 230, 255)

local COMMANDS = {
	"/give @s op_lapis 64", "/fling @e[r=55]", "/effect give @p la_peace", "/tp @a ~ ~50 ~",
	"/gamemode creative", "/summon lapis ~ ~1 ~", "/op @s", "/time set day", "/execute as @e run peace",
	"/gravity @s off", "/levitate command_block",
}

local holder = workspace:FindFirstChild("ClientAuras")
if not holder then
	holder = Instance.new("Folder")
	holder.Name = "ClientAuras"
	holder.Parent = workspace
end
-- leftovers from the old per-tool script
for _, f in ipairs(holder:GetChildren()) do
	if f.Name:find("^CommandAura_") then f:Destroy() end
end

local function part(size, color, parent, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	if shape then p.Shape = shape end
	p.Size = size
	p.Color = color
	p.Parent = parent
	return p
end

local function attach(p, pos)
	local a = Instance.new("Attachment")
	if pos then a.Position = pos end
	a.Parent = p
	return a
end

--==================================================
-- BUILD
--==================================================

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "OpStaffAura"
	folder.Parent = holder

	local b = { folder = folder, orbs = {}, edges = {}, t0 = os.clock() }

	-- core (invisible) the beams, light and particles hang off
	local core = part(Vector3.one * 0.1, GREEN, folder)
	core.Transparency = 1
	b.core = core
	local coreAtt = attach(core)

	-- base point at the staff tip for the tractor beam
	local base = part(Vector3.one * 0.1, GREEN, folder)
	base.Transparency = 1
	b.base = base
	local baseAtt = attach(base)

	-- tractor beam: staff tip -> block, texture scrolls upward
	local beam = Instance.new("Beam")
	beam.Attachment0 = baseAtt
	beam.Attachment1 = coreAtt
	beam.Width0 = 0.5
	beam.Width1 = 2.2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 0.8
	beam.TextureSpeed = 2.5
	beam.Color = ColorSequence.new(GREEN, CYAN)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 0.75),
	})
	beam.Parent = core
	-- solid inner core of the beam
	local inner = beam:Clone()
	inner.Texture = ""
	inner.Width0, inner.Width1 = 0.12, 0.5
	inner.Transparency = NumberSequence.new(0.55, 0.8)
	inner.Parent = core

	-- wireframe cage (12 edges of a cube)
	local s = 1.9
	local corners = {}
	for _, x in ipairs({ -s, s }) do for _, y in ipairs({ -s, s }) do for _, z in ipairs({ -s, s }) do
		table.insert(corners, Vector3.new(x, y, z))
	end end end
	for i = 1, #corners do
		for j = i + 1, #corners do
			local d = corners[i] - corners[j]
			local axes = (d.X ~= 0 and 1 or 0) + (d.Y ~= 0 and 1 or 0) + (d.Z ~= 0 and 1 or 0)
			if axes == 1 then
				local e = part(Vector3.new(0.07, 0.07, d.Magnitude), GREEN, folder)
				e.Transparency = 0.2
				table.insert(b.edges, { part = e, a = corners[i], b = corners[j] })
			end
		end
	end

	-- pulsing force-field shell around the block
	local shell = part(Vector3.one * 3.4, GREEN, folder, Enum.PartType.Ball)
	shell.Material = Enum.Material.ForceField
	shell.Transparency = 0.1
	b.shell = shell

	-- two hex-field halos under the block (flat cylinders)
	b.halos = {}
	for i, c in ipairs({ GREEN, PURPLE }) do
		local h = part(Vector3.new(0.05, 4.6 - i * 0.9, 4.6 - i * 0.9), c, folder, Enum.PartType.Cylinder)
		h.Material = Enum.Material.ForceField
		h.Transparency = 0
		table.insert(b.halos, h)
	end

	-- orbiting mini command cubes, the first three tethered by crackling beams
	local colors = { GREEN, PURPLE, ORANGE, CYAN, PURPLE, ORANGE }
	for i = 1, #colors do
		local o = part(Vector3.one * 0.32, colors[i], folder)
		local a0 = attach(o, Vector3.new(0, 0.12, 0))
		local a1 = attach(o, Vector3.new(0, -0.12, 0))
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.35
		tr.LightEmission = 1
		tr.Color = ColorSequence.new(colors[i])
		tr.Transparency = NumberSequence.new(0.1, 1)
		tr.FaceCamera = true
		tr.Parent = o
		local tether
		if i <= 3 then
			tether = Instance.new("Beam")
			tether.Attachment0 = coreAtt
			tether.Attachment1 = attach(o)
			tether.Width0, tether.Width1 = 0.06, 0.03
			tether.LightEmission = 1
			tether.LightInfluence = 0
			tether.FaceCamera = true
			tether.Segments = 8
			tether.Color = ColorSequence.new(colors[i])
			tether.Transparency = NumberSequence.new(0.2, 0.6)
			tether.Parent = core
		end
		table.insert(b.orbs, {
			part = o,
			tether = tether,
			ring = (i <= 3) and 1 or 2,
			phase = (i % 3) / 3 * math.pi * 2,
		})
	end

	-- code sparks + faint green mist
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(GREEN, PURPLE)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.6, 1.1)
	pe.Speed = NumberRange.new(1.5, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = 16
	pe.Parent = core

	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(GREEN, CYAN)
	mist.LightEmission = 0.8
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new(1.2, 2.5)
	mist.Lifetime = NumberRange.new(1, 1.6)
	mist.Speed = NumberRange.new(0.3, 0.8)
	mist.Acceleration = Vector3.new(0, 1.2, 0)
	mist.Rate = 5
	mist.Parent = base

	local light = Instance.new("PointLight")
	light.Color = GREEN
	light.Range = 10
	light.Brightness = 2
	light.Shadows = false
	light.Parent = core
	b.light = light

	-- little terminal above the block
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(5, 0.8)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 60
	bb.Adornee = core
	bb.Parent = folder
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(10, 12, 10)
	lbl.BackgroundTransparency = 0.35
	lbl.Font = Enum.Font.Code
	lbl.TextScaled = true
	lbl.TextColor3 = GREEN
	lbl.Text = ""
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0.2, 0)
	b.label = lbl
	b.cmdIndex = math.random(#COMMANDS)
	b.cmdStart = os.clock()

	return b
end

--==================================================
-- TRACKING
-- [tool] = { cube = BasePart, spin = BasePart?, aura = built|nil }
--==================================================

local tracked = {}

local function drop(tool)
	local info = tracked[tool]
	if info and info.aura then info.aura.folder:Destroy() end
	tracked[tool] = nil
end

local function consider(tool)
	if tracked[tool] or not tool:IsA("Tool") then return end
	local block = tool:FindFirstChild(BLOCK_NAME)
	if not block then return end
	local cube = block:FindFirstChild("model") or block:FindFirstChildWhichIsA("BasePart", true)
	if not cube then return end
	tracked[tool] = { cube = cube, spin = tool:FindFirstChild("Spin") }
	tool.Destroying:Connect(function() drop(tool) end)
end

local function watchCharacter(character)
	for _, c in ipairs(character:GetChildren()) do consider(c) end
	character.ChildAdded:Connect(consider)
end
local function watchPlayer(p)
	if p.Character then watchCharacter(p.Character) end
	p.CharacterAdded:Connect(watchCharacter)
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)

-- display copies in the shop (workspace.staffs)
task.spawn(function()
	local staffs = workspace:WaitForChild("staffs", 30)
	if not staffs then return end
	for _, c in ipairs(staffs:GetChildren()) do consider(c) end
	staffs.ChildAdded:Connect(consider)
end)

--==================================================
-- ANIMATE
--==================================================

local function animate(b, cube, spin)
	local t = os.clock() - b.t0
	local center = cube.Position
	local pulse = (math.sin(t * 3) + 1) / 2

	b.core.CFrame = CFrame.new(center)
	if spin and spin.Parent then
		b.base.CFrame = CFrame.new(spin.Position + Vector3.new(0, spin.Size.Y / 2, 0))
	else
		b.base.CFrame = CFrame.new(center - Vector3.new(0, 2.2, 0))
	end

	-- cage: slow tumble, green <-> purple
	local cageCF = CFrame.new(center) * CFrame.Angles(t * 0.6, t * 0.9, t * 0.4)
	local cageColor = GREEN:Lerp(PURPLE, pulse)
	for _, e in ipairs(b.edges) do
		local pa, pb = cageCF:PointToWorldSpace(e.a), cageCF:PointToWorldSpace(e.b)
		e.part.CFrame = CFrame.lookAt((pa + pb) / 2, pb)
		e.part.Color = cageColor
	end

	-- breathing shell
	local sz = 3.3 + pulse * 0.5
	b.shell.Size = Vector3.new(sz, sz, sz)
	b.shell.CFrame = CFrame.new(center) * CFrame.Angles(0, t * 0.5, 0)
	b.shell.Color = cageColor

	-- halos: flat under the block, counter-spinning, gently tilting
	for i, h in ipairs(b.halos) do
		local dir = (i == 1) and 1 or -1
		local y = -1.7 - i * 0.35 + math.sin(t * 2 + i) * 0.08
		h.CFrame = CFrame.new(center + Vector3.new(0, y, 0))
			* CFrame.Angles(math.sin(t * 0.8 + i) * 0.12, t * 1.6 * dir, math.cos(t * 0.7) * 0.12)
			* CFrame.Angles(0, 0, math.rad(90))
	end

	-- orbs on two tilted rings; tethers crackle
	for _, o in ipairs(b.orbs) do
		local r = (o.ring == 1) and 2.7 or 3.4
		local speed = (o.ring == 1) and 2.4 or -1.8
		local tilt = (o.ring == 1) and CFrame.Angles(math.rad(30), 0, 0) or CFrame.Angles(0, 0, math.rad(-40))
		local a = o.phase + t * speed
		local pos = center + tilt:VectorToWorldSpace(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		o.part.CFrame = CFrame.new(pos) * CFrame.Angles(t * 3, t * 2, 0)
		if o.tether then
			o.tether.CurveSize0 = math.noise(t * 6, o.phase) * 2
			o.tether.CurveSize1 = math.noise(o.phase, t * 6) * 2
		end
	end

	b.light.Brightness = 1.5 + pulse * 2

	-- typewriter commands
	local cmd = COMMANDS[b.cmdIndex]
	local elapsed = os.clock() - b.cmdStart
	local shown = math.min(#cmd, math.floor(elapsed * 16))
	local cursor = (math.floor(elapsed * 3) % 2 == 0) and "_" or " "
	b.label.Text = "> " .. cmd:sub(1, shown) .. cursor
	if elapsed > #cmd / 16 + 1.4 then
		b.cmdIndex = b.cmdIndex % #COMMANDS + 1
		b.cmdStart = os.clock()
	end
end

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	for tool, info in pairs(tracked) do
		if not tool.Parent or not tool:IsDescendantOf(game) or not info.cube.Parent then
			drop(tool) -- staff gone (ascend, reset, death, sold...)
		else
			local active = tool:IsDescendantOf(workspace)
				and (not camPos or (camPos - info.cube.Position).Magnitude <= VIEW_DISTANCE)
			if active then
				if not info.aura then info.aura = build() end
				animate(info.aura, info.cube, info.spin)
			elseif info.aura then
				info.aura.folder:Destroy()
				info.aura = nil
			end
			-- back in the backpack: keep watching in case it's re-equipped
			if not tool:IsDescendantOf(workspace) and not tool:IsDescendantOf(Players) then
				drop(tool)
			end
		end
	end
end)
