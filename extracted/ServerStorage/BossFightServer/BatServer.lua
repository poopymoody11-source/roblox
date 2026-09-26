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

function B.buildTool()
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = "Spiral Bat  -  Click: swing / parry   Q: Spiral Dash   E: Drill Break"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new()

	-- the grip, wrapped
	local handle = part({ Name = "Handle", Size = Vector3.new(0.34, 1.6, 0.34), Color = BLACK, Material = Enum.Material.Fabric, Transparency = 1 })
	handle.Parent = tool
	rod(tool, handle, "Grip", 0, 1.6, 0.34, BLACK, Enum.Material.Fabric)
	for i = 0, 3 do
		rod(tool, handle, "Wrap" .. i, -0.55 + i * 0.36, 0.09, 0.37, GREEN, Enum.Material.Neon)
	end
	ball(tool, handle, "Knob", -0.88, 0.52, GOLD)
	rod(tool, handle, "Guard", 0.86, 0.14, 0.62, GOLD)
	rod(tool, handle, "Collar", 1.0, 0.18, 0.46, STEEL)

	-- the barrel: flaring out to the drill
	local segs = 6
	for i = 1, segs do
		local u = (i - 0.5) / segs
		rod(tool, handle, "Barrel" .. i, 1.05 + (i - 0.5) * 0.42, 0.44, 0.4 + 0.3 * u, STEEL, Enum.Material.Metal)
	end
	-- gold bands and the green core showing between them
	rod(tool, handle, "BandLow", 1.55, 0.1, 0.52, GOLD)
	rod(tool, handle, "Core", 2.35, 0.7, 0.62, GREEN, Enum.Material.Neon)
	rod(tool, handle, "BandHigh", 3.2, 0.12, 0.76, GOLD)
	rod(tool, handle, "Crown", 3.62, 0.22, 0.86, GOLD)

	-- the drill tip (spins on the client)
	local src = ReplicatedStorage:FindFirstChild("FinalCutscene")
	src = src and src:FindFirstChild("Assets")
	src = src and src:FindFirstChild("DrillCone")
	local drill
	if src and src:IsA("MeshPart") then
		drill = src:Clone()
		for _, d in ipairs(drill:GetChildren()) do d:Destroy() end
		drill.Anchored, drill.CanCollide, drill.CanQuery, drill.CanTouch, drill.Massless = false, false, false, false, true
		drill.Size = Vector3.new(0.95, 1.9, 0.95)
	else
		drill = part({ Size = Vector3.new(0.95, 1.9, 0.95) })
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.FileMesh
		m.MeshId = "rbxassetid://1778999"
		m.Scale = Vector3.new(0.73, 0.99, 0.76)
		m.Parent = drill
	end
	drill.Name = "Drill"
	drill.Color = LIME
	drill.Material = Enum.Material.Neon
	local dw = Instance.new("Weld")
	dw.Name = "DrillWeld"
	dw.Part0 = handle
	dw.Part1 = drill
	dw.C0 = CFrame.new(0, 3.72 + 0.95, 0)
	dw.Parent = drill
	drill.Parent = tool

	-- spiral grooves up the barrel (two curved beams, counter-wound)
	local a0 = Instance.new("Attachment")
	a0.Name = "SpiralBase"
	a0.Position = Vector3.new(0, 1.0, 0)
	a0.Parent = handle
	local a1 = Instance.new("Attachment")
	a1.Name = "SpiralTip"
	a1.Position = Vector3.new(0, 5.4, 0)
	a1.Parent = handle
	for i = 1, 2 do
		local b = Instance.new("Beam")
		b.Name = "Spiral" .. i
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = 0.32
		b.Width1 = 0.08
		b.Color = ColorSequence.new(i == 1 and GREEN or LIME, Color3.new(1, 1, 1))
		b.LightEmission = 1
		b.Brightness = 4
		b.Texture = "rbxassetid://10365550877"
		b.TextureSpeed = 2.5
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 1.2
		b.CurveSize0 = i == 1 and 0.9 or -0.9
		b.CurveSize1 = i == 1 and -0.9 or 0.9
		b.Segments = 20
		b.FaceCamera = true
		b.Parent = handle
	end
	-- the swing trail (the client turns it on mid-swing)
	local t0 = Instance.new("Attachment")
	t0.Name = "TrailBase"
	t0.Position = Vector3.new(0, 1.6, 0)
	t0.Parent = handle
	local t1 = Instance.new("Attachment")
	t1.Name = "TrailTip"
	t1.Position = Vector3.new(0, 5.5, 0)
	t1.Parent = handle
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = t0
	trail.Attachment1 = t1
	trail.Lifetime = 0.22
	trail.MinLength = 0.05
	trail.LightEmission = 1
	trail.Brightness = 3
	trail.Color = ColorSequence.new(LIME, GREEN)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	trail.Enabled = false
	trail.Parent = handle

	-- spiral sparks off the core, and its light
	local core = tool:FindFirstChild("Core")
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparks"
	e.Texture = "rbxassetid://11381556016"
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	e.Color = ColorSequence.new(GREEN, LIME)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.3, 0.55)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 14
	e.LightEmission = 1
	e.Brightness = 2.5
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = core
	local light = Instance.new("PointLight")
	light.Color = GREEN
	light.Range = 10
	light.Brightness = 1.6
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
