--==================================================
-- THE SPIRAL BAT (server)
-- Builds the bat (a drill-headed Gurren bat: black grip, gold
-- fittings, a spiral-grooved barrel and a spinning green drill
-- tip), hands it to everyone, and checks what they do with it:
--   click  - swing (3-hit combo). A swing as a hit lands on
--            you is a PARRY: you take nothing, he takes it.
--   Q      - Spiral Dash: a burst of speed with brief i-frames.
--   E      - Drill Break: hurl a spiral drill at his core.
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local B = {}

local GREEN = Color3.fromRGB(70, 255, 120)
local LIME = Color3.fromRGB(190, 255, 90)
local GOLD = Color3.fromRGB(255, 200, 70)
local BLACK = Color3.fromRGB(18, 20, 22)
local STEEL = Color3.fromRGB(34, 44, 40)

local TOOL_NAME = "SpiralBat"
B.TOOL_NAME = TOOL_NAME

--------------------------------------------------------------------------
-- the model (everything runs along the Handle's +Y, grip at the origin)
--------------------------------------------------------------------------
local function part(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	return p
end

-- a cylinder standing along the handle's Y axis, `len` long, centred at y
local function rod(tool, handle, name, y, len, dia, color, material)
	local p = part({
		Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, dia, dia),
		Color = color, Material = material or Enum.Material.Metal,
	})
	local w = Instance.new("Weld")
	w.Part0 = handle
	w.Part1 = p
	w.C0 = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
	w.Parent = p
	p.Parent = tool
	return p
end

local function ball(tool, handle, name, y, dia, color, material)
	local p = part({ Name = name, Shape = Enum.PartType.Ball, Size = Vector3.one * dia, Color = color, Material = material or Enum.Material.Metal })
	local w = Instance.new("Weld")
	w.Part0 = handle
	w.Part1 = p
	w.C0 = CFrame.new(0, y, 0)
	w.Parent = p
	p.Parent = tool
	return p
end

-- a small block welded to `base` at c0 (for the spiral strands and fins)
local function chip(tool, base, name, c0, size, color, material)
	local p = part({ Name = name, Size = size, Color = color, Material = material or Enum.Material.Neon })
	local w = Instance.new("Weld")
	w.Part0 = base
	w.Part1 = p
	w.C0 = c0
	w.Parent = p
	p.Parent = tool
	return p
end

-- the barrel's radius at height y (it flares from the grip to the drill)
local BARREL_Y0, BARREL_Y1 = 1.0, 4.2
local function barrelR(y)
	local u = math.clamp((y - BARREL_Y0) / (BARREL_Y1 - BARREL_Y0), 0, 1)
	return 0.21 + 0.18 * u ^ 1.3
end

local function drillCone()
	local src = ReplicatedStorage:FindFirstChild("FinalCutscene")
	src = src and src:FindFirstChild("Assets")
	src = src and src:FindFirstChild("DrillCone")
	if src and src:IsA("MeshPart") then
		local d = src:Clone()
		for _, c in ipairs(d:GetChildren()) do c:Destroy() end
		d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, false, true
		return d
	end
	local d = part({ Size = Vector3.one })
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.FileMesh
	m.MeshId = "rbxassetid://1778999"
	m.Parent = d
	return d
end
B.drillCone = drillCone

function B.buildTool()
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = "Spiral Bat"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new()

	-- the grip: black, taped in green
	local handle = part({ Name = "Handle", Size = Vector3.new(0.36, 1.7, 0.36), Transparency = 1 })
	handle.Parent = tool
	rod(tool, handle, "Grip", 0, 1.7, 0.36, BLACK, Enum.Material.Fabric)
	for i = 0, 4 do
		local w = chip(tool, handle, "Tape" .. i, CFrame.new(0, -0.62 + i * 0.3, 0) * CFrame.Angles(0, 0, math.rad(90 - 14)),
			Vector3.new(0.07, 0.395, 0.395), GREEN, Enum.Material.Neon)
		w.Shape = Enum.PartType.Cylinder
	end
	-- the pommel: gold, with a spiral gem
	ball(tool, handle, "Knob", -0.95, 0.56, GOLD)
	rod(tool, handle, "KnobCollar", -0.78, 0.1, 0.44, GOLD)
	ball(tool, handle, "Gem", -1.2, 0.26, GREEN, Enum.Material.Neon)
	-- the guard, with fins
	rod(tool, handle, "Guard", 0.9, 0.14, 0.7, GOLD)
	for s = -1, 1, 2 do
		chip(tool, handle, "Fin", CFrame.new(s * 0.42, 0.92, 0) * CFrame.Angles(0, 0, math.rad(-s * 35)), Vector3.new(0.34, 0.12, 0.1), GOLD, Enum.Material.Metal)
	end

	-- the barrel: gunmetal, flaring toward the drill
	local segs = 8
	for i = 1, segs do
		local y0 = BARREL_Y0 + (i - 1) * (BARREL_Y1 - BARREL_Y0) / segs
		local y1 = BARREL_Y0 + i * (BARREL_Y1 - BARREL_Y0) / segs
		rod(tool, handle, "Barrel" .. i, (y0 + y1) / 2, (y1 - y0) + 0.02, 2 * barrelR((y0 + y1) / 2), STEEL, Enum.Material.Metal)
	end
	-- its core showing through, and the gold bands
	local core = rod(tool, handle, "Core", 2.55, 0.5, 2 * barrelR(2.55) + 0.05, GREEN, Enum.Material.Neon)
	local shell = rod(tool, handle, "CoreShell", 2.55, 0.62, 2 * barrelR(2.55) + 0.14, LIME, Enum.Material.ForceField)
	shell.Transparency = 0.2
	rod(tool, handle, "BandLow", 1.35, 0.1, 2 * barrelR(1.35) + 0.08, GOLD)
	rod(tool, handle, "BandMid", 3.1, 0.1, 2 * barrelR(3.1) + 0.08, GOLD)
	rod(tool, handle, "Crown", BARREL_Y1 + 0.08, 0.2, 2 * barrelR(BARREL_Y1) + 0.14, GOLD)

	-- the spiral: two glowing strands winding up the barrel
	local turns, per = 2.5, 16
	for strand = 0, 1 do
		for i = 0, per - 1 do
			local u = i / (per - 1)
			local y = BARREL_Y0 + 0.15 + u * (BARREL_Y1 - BARREL_Y0 - 0.3)
			local a = strand * math.pi + u * turns * 2 * math.pi
			local r = barrelR(y) + 0.02
			local pos = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
			-- (each chip lies along the helix: tangent is its long axis)
			local tangent = Vector3.new(-math.sin(a) * r * turns * 2 * math.pi, BARREL_Y1 - BARREL_Y0, math.cos(a) * r * turns * 2 * math.pi).Unit
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local cf = CFrame.fromMatrix(pos, tangent, out)
			chip(tool, handle, "Spiral", cf, Vector3.new(0.3, 0.07, 0.1), strand == 0 and GREEN or LIME, Enum.Material.Neon)
		end
	end

	-- the drill: a spinning lime cone with dark flutes (the client spins it)
	local drill = drillCone()
	drill.Name = "Drill"
	drill.Size = Vector3.new(1.0, 2.1, 1.0)
	drill.Color = LIME
	drill.Material = Enum.Material.Neon
	local dw = Instance.new("Weld")
	dw.Name = "DrillWeld"
	dw.Part0 = handle
	dw.Part1 = drill
	dw.C0 = CFrame.new(0, BARREL_Y1 + 0.2 + 1.05, 0)
	dw.Parent = drill
	drill.Parent = tool
	for f = 0, 2 do
		for i = 0, 6 do
			local u = i / 6
			local y = -0.95 + u * 1.8               -- (drill space: base -1.05 .. tip +1.05)
			local r = 0.5 * (1 - (y + 1.05) / 2.1) + 0.02
			local a = f * 2 * math.pi / 3 + u * 1.6 * math.pi
			local pos = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
			local tangent = Vector3.new(-math.sin(a) * r * 1.6 * math.pi, 1.8, math.cos(a) * r * 1.6 * math.pi).Unit
			chip(tool, drill, "Flute", CFrame.fromMatrix(pos, tangent, Vector3.new(math.cos(a), 0, math.sin(a))),
				Vector3.new(0.3, 0.06, 0.09 * (1 - u * 0.6)), Color3.fromRGB(20, 70, 30), Enum.Material.Metal)
		end
	end
	local tipGlow = Instance.new("Attachment")
	tipGlow.Name = "Tip"
	tipGlow.Position = Vector3.new(0, 1.05, 0)
	tipGlow.Parent = drill

	-- swing trail (the client turns it on mid-swing)
	local t0 = Instance.new("Attachment")
	t0.Name = "TrailBase"
	t0.Position = Vector3.new(0, 1.6, 0)
	t0.Parent = handle
	local t1 = Instance.new("Attachment")
	t1.Name = "TrailTip"
	t1.Position = Vector3.new(0, 6.3, 0)
	t1.Parent = handle
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = t0
	trail.Attachment1 = t1
	trail.Lifetime = 0.2
	trail.MinLength = 0.05
	trail.LightEmission = 1
	trail.Brightness = 4
	trail.Texture = "rbxassetid://10365550877"
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), GREEN)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.5), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
	trail.Enabled = false
	trail.Parent = handle

	-- spiral energy off the core, and its light
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparks"
	e.Texture = "rbxassetid://11381556016"
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	e.Color = ColorSequence.new(GREEN, LIME)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.3, 0.55)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 10
	e.LightEmission = 1
	e.Brightness = 2.5
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = core
	local light = Instance.new("PointLight")
	light.Color = GREEN
	light.Range = 9
	light.Brightness = 1.4
	light.Parent = core
	return tool
end

--------------------------------------------------------------------------
-- handing it out
--------------------------------------------------------------------------
local template

local function give(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	-- (the old bat goes)
	for _, holder in ipairs({ backpack, char }) do
		if holder then
			for _, c in ipairs(holder:GetChildren()) do
				if c:IsA("Tool") and (c.Name == "VerityBat" or c.Name == "Bat") then c:Destroy() end
			end
		end
	end
	if backpack and not backpack:FindFirstChild(TOOL_NAME) and not (char and char:FindFirstChild(TOOL_NAME)) then
		template:Clone().Parent = backpack
	end
end

--------------------------------------------------------------------------
-- actions
--------------------------------------------------------------------------
function B.init(F)
	local S, cfg = F.S, F.Config.Bat
	-- (the clients read the cooldowns for their ability bar from here)
	local shared = ReplicatedStorage:WaitForChild("AntiSpiralFight")
	shared:SetAttribute("SwingCooldown", cfg.SwingCooldown)
	shared:SetAttribute("ComboReset", cfg.ComboReset)
	shared:SetAttribute("DashCooldown", cfg.DashCooldown)
	shared:SetAttribute("DrillCooldown", cfg.DrillCooldown)
	template = B.buildTool()
	for _, name in ipairs({ "VerityBat", "Bat" }) do
		local old = StarterPack:FindFirstChild(name)
		if old then old:Destroy() end
	end
	template:Clone().Parent = StarterPack
	local function hook(p)
		p.CharacterAdded:Connect(function()
			task.wait(0.5)
			give(p)
		end)
		if p.Character then give(p) end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do hook(p) end

	local last = {} -- [player] = { Swing, Dash, Drill }
	Players.PlayerRemoving:Connect(function(p) last[p] = nil end)

	local function ready(player)
		if workspace:GetAttribute("FC_State") ~= "Fight" then return nil end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (hum and root and hum.Health > 0 and char:FindFirstChild(TOOL_NAME)) then return nil end
		last[player] = last[player] or { Swing = 0, Dash = 0, Drill = 0 }
		return char, root, last[player]
	end

	local function melee(player, root, combo)
		-- anything with a Humanoid in front of you that isn't a player (minions)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ex = {}
		for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ex, p.Character) end end
		params.FilterDescendantsInstances = ex
		local centre = root.Position + root.CFrame.LookVector * (cfg.MeleeRange * 0.5)
		local seen = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(centre, cfg.MeleeRange * 0.7, params)) do
			local m = part:FindFirstAncestorOfClass("Model")
			while m and not m:FindFirstChildOfClass("Humanoid") do m = m:FindFirstAncestorOfClass("Model") end
			if m and not seen[m] then
				seen[m] = true
				-- (not him: his body is only ever where the clients draw it)
				local h = m:FindFirstChildOfClass("Humanoid")
				if m ~= F.Model and h and h.Health > 0 then
					h:TakeDamage(cfg.MeleeDamage * (combo == 3 and 1.6 or 1))
				end
			end
		end
	end

	F.BatRemote.OnServerEvent:Connect(function(player, action, a, b)
		local char, root, cd = ready(player)
		if not char then return end
		local now = S.now()
		if action == "swing" then
			if now - cd.Swing < cfg.SwingCooldown * 0.8 then return end
			cd.Swing = now
			local combo = (type(a) == "number") and math.clamp(math.floor(a), 1, 3) or 1
			-- parry claims: the hits this swing met (validated against live hits)
			if type(b) == "table" and type(b.T) == "number" and math.abs(b.T - now) < 1.5 and type(b.Ids) == "table" then
				for i = 1, math.min(#b.Ids, 4) do
					local id = b.Ids[i]
					if type(id) == "string" and F.isLive(id) then F.claim(player, id, b.T) end
				end
			end
			melee(player, root, combo)
			F.BatFxRemote:FireAllClients("swing", player.UserId, combo)
		elseif action == "dash" then
			if now - cd.Dash < cfg.DashCooldown * 0.9 then return end
			cd.Dash = now
			player:SetAttribute("IFrameUntil", now + cfg.DashIFrames)
			F.BatFxRemote:FireAllClients("dash", player.UserId)
		elseif action == "drill" then
			if now - cd.Drill < cfg.DrillCooldown * 0.95 then return end
			if not F.Alive then return end
			cd.Drill = now
			local from = root.Position + Vector3.new(0, 1.5, 0)
			local target = F.chestAt(now + 0.5)
			local travel = (target - from).Magnitude / cfg.DrillSpeed
			F.BatFxRemote:FireAllClients("drill", player.UserId, { From = from, T0 = now, T1 = now + travel })
			task.delay(travel, function()
				if F.Alive then F.damageBoss(cfg.DrillDamage, player, "drill") end
			end)
		end
	end)
end

return B
