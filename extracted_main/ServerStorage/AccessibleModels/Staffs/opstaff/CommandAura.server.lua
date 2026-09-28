--==================================================
-- COMMAND BLOCK AURA  (runs on each client)
-- The OP Staff's command block gets a floating wireframe cage,
-- orbiting mini command cubes with trails, drifting code bits and
-- a little terminal above it typing out commands.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local tool = script.Parent
local container = tool:WaitForChild("commandblock_lapis", 10)
if not container then return end
local cube = container:FindFirstChild("model") or container:FindFirstChildWhichIsA("BasePart", true)

local holder = workspace:FindFirstChild("ClientAuras")
if not holder then
	holder = Instance.new("Folder")
	holder.Name = "ClientAuras"
	holder.Parent = workspace
end

local GREEN = Color3.fromRGB(90, 255, 140)
local PURPLE = Color3.fromRGB(190, 110, 255)
local ORANGE = Color3.fromRGB(255, 170, 60)

local built = nil

local function part(size, color, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.Color = color
	p.Parent = parent
	return p
end

local COMMANDS = {
	"/give @s op_lapis 64", "/fling @e[r=55]", "/effect give @p la_peace", "/tp @a ~ ~50 ~",
	"/gamemode creative", "/summon lapis ~ ~1 ~", "/op MrMajou", "/time set day", "/execute as @e run peace",
}

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "CommandAura_" .. tostring(math.random(1, 1e9))
	folder.Parent = holder

	local b = { folder = folder, orbs = {}, edges = {}, t0 = os.clock() }

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

	-- orbiting mini command cubes
	local colors = { GREEN, PURPLE, ORANGE, GREEN, PURPLE, ORANGE, GREEN, PURPLE }
	for i = 1, 8 do
		local o = part(Vector3.one * 0.32, colors[i], folder)
		local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, 0.12, 0) a0.Parent = o
		local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -0.12, 0) a1.Parent = o
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.35
		tr.LightEmission = 1
		tr.Color = ColorSequence.new(colors[i])
		tr.Transparency = NumberSequence.new(0.1, 1)
		tr.FaceCamera = true
		tr.Parent = o
		table.insert(b.orbs, {
			part = o,
			ring = (i <= 4) and 1 or 2,
			phase = (i % 4) / 4 * math.pi * 2,
		})
	end

	-- drifting code bits
	local emitterPart = part(Vector3.one * 0.1, GREEN, folder)
	emitterPart.Transparency = 1
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(GREEN, PURPLE)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.6, 1.1)
	pe.Speed = NumberRange.new(1.5, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = 18
	pe.Parent = emitterPart
	b.emitter = emitterPart

	local light = Instance.new("PointLight")
	light.Color = GREEN
	light.Range = 10
	light.Brightness = 2
	light.Parent = emitterPart
	b.light = light

	-- little terminal above the block
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(5, 0.8)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 60
	bb.Adornee = emitterPart
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

local function destroy()
	if built then built.folder:Destroy() built = nil end
end

local function isActive()
	if not tool:IsDescendantOf(workspace) then return false end
	if not cube or not cube.Parent then return false end
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - cube.Position).Magnitude > 140 then return false end
	return true
end

RunService.RenderStepped:Connect(function()
	if not isActive() then
		destroy()
		return
	end
	if not built then built = build() end
	local b = built
	local t = os.clock() - b.t0
	local center = cube.Position

	-- cage: slow tumble around the block
	local cageCF = CFrame.new(center) * CFrame.Angles(t * 0.6, t * 0.9, t * 0.4)
	local pulse = (math.sin(t * 3) + 1) / 2
	for _, e in ipairs(b.edges) do
		local pa, pb = cageCF:PointToWorldSpace(e.a), cageCF:PointToWorldSpace(e.b)
		e.part.CFrame = CFrame.lookAt((pa + pb) / 2, pb)
		e.part.Color = GREEN:Lerp(PURPLE, pulse)
	end

	-- orbs: two tilted rings
	for _, o in ipairs(b.orbs) do
		local r = (o.ring == 1) and 2.6 or 3.3
		local speed = (o.ring == 1) and 2.4 or -1.8
		local tilt = (o.ring == 1) and CFrame.Angles(math.rad(30), 0, 0) or CFrame.Angles(0, 0, math.rad(-40))
		local a = o.phase + t * speed
		local pos = center + (tilt:VectorToWorldSpace(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)))
		o.part.CFrame = CFrame.new(pos) * CFrame.Angles(t * 3, t * 2, 0)
	end

	b.emitter.CFrame = CFrame.new(center)
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
end)

tool.AncestryChanged:Connect(function()
	if not tool:IsDescendantOf(game) then destroy() end
end)
