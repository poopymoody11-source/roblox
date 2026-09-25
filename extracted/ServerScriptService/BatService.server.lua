--==================================================
-- VERITY BAT  (server)  -- ported from BECOME LA PEACE's SwingScript
--
-- Same swing visuals, beam, 3-hit combo and ground slam, but in the
-- boss fight:
--   * it can NEVER hurt other players (no PvP here)
--   * it hits the boss (and its minions) anywhere on their body
--   * swinging near an Energy Orb bats it back into the boss
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local BossUtil = require(ServerStorage:WaitForChild("BossUtil"))

local remotes = ReplicatedStorage:WaitForChild("BatRemotes")
local Swing = remotes:WaitForChild("Swing")
local SwingVisuals = remotes:WaitForChild("SwingVisuals")
local GroundSlam = remotes:WaitForChild("GroundSlam")
local GroundSlamVisual = remotes:WaitForChild("GroundSlamVisual")

local assets = ReplicatedStorage:WaitForChild("BatAssets")
local SwingBeam = assets:WaitForChild("SwingBeam")
local SlamVFX = assets:WaitForChild("SlamVFX")

local CONFIG = {
	BAT_DAMAGE = 25,        -- per hit on the boss / minions
	SLAM_DAMAGE = 50,       -- third hit ground slam (VerityBat = 2x regular)
	HIT_RANGE = 18,         -- studs from the player to the surface of what they hit
	DEFLECT_RANGE = 16,     -- how close an energy orb has to be to bat it back
	SWING_COOLDOWN = 0.18,
}

local function isPlayerCharacter(model)
	return model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
end

local function isBoss(model)
	return model ~= nil and model:GetAttribute("Invulnerable") ~= nil
end

local function hasBat(character)
	return character and (character:FindFirstChild("VerityBat") or character:FindFirstChild("Bat")) ~= nil
end

local function canDamage(model)
	if not model or isPlayerCharacter(model) then return false end
	if model:GetAttribute("Invulnerable") == true then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

-- distance from a point to the surface of a part's box
local function distToPart(part, point)
	local lp = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	local clamped = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
	return (lp - clamped).Magnitude
end

--==================================================
-- deflecting energy orbs
--==================================================
local function tryDeflect(player, rootPart)
	local deflected = 0
	local look = rootPart.CFrame.LookVector
	for projectile, state in pairs(BossUtil.ActiveProjectiles) do
		if not state.deflected and state.def.Deflectable and projectile.Parent then
			local offset = state.position - rootPart.Position
			local reach = CONFIG.DEFLECT_RANGE + (state.radius or 2)
			if offset.Magnitude <= reach and (offset.Magnitude < 5 or look:Dot(offset.Unit) > -0.25) then
				if BossUtil.Deflect(projectile, player) then
					deflected += 1
					-- a little pop where it was hit
					local flash = Instance.new("Part")
					flash.Anchored, flash.CanCollide, flash.CanQuery, flash.CanTouch = true, false, false, false
					flash.Shape = Enum.PartType.Ball
					flash.Material = Enum.Material.Neon
					flash.Color = Color3.fromRGB(150, 255, 190)
					flash.Size = Vector3.one * 3
					flash.CFrame = CFrame.new(state.position)
					flash.Parent = workspace
					TweenService:Create(flash, TweenInfo.new(0.25), { Size = Vector3.one * 12, Transparency = 1 }):Play()
					Debris:AddItem(flash, 0.3)
				end
			end
		end
	end
	return deflected
end

--==================================================
-- swing visuals (+ the deflect check, timed to the "Hit" marker)
--==================================================
local lastSwing = {}

SwingVisuals.OnServerEvent:Connect(function(player, currentM1, BatType)
	local character = player.Character
	if not hasBat(character) then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	if type(currentM1) ~= "number" then return end
	BatType = (character:FindFirstChild("VerityBat") and "VerityBat") or "Bat"

	local now = os.clock()
	if lastSwing[player] and now - lastSwing[player] < CONFIG.SWING_COOLDOWN then return end
	lastSwing[player] = now

	tryDeflect(player, rootPart)

	local offset = CFrame.new(0, 0, -1)
	if currentM1 == 1 then
		if BatType == "VerityBat" then
			offset = offset * CFrame.Angles(0, math.rad(90), math.rad(-190))
		end
		offset = offset * CFrame.Angles(0, 0, math.rad(-10))
	elseif currentM1 == 2 then
		if BatType == "VerityBat" then
			offset = offset * CFrame.Angles(0, math.rad(90), 0)
		else
			offset = offset * CFrame.Angles(0, 0, math.rad(-160))
		end
	elseif currentM1 == 3 then
		if BatType == "VerityBat" then
			offset = offset * CFrame.Angles(0, 0, math.rad(-90))
		else
			offset = offset * CFrame.Angles(0, math.rad(180), math.rad(-90))
		end
	end

	local SwingVfx = (BatType == "VerityBat") and assets:FindFirstChild("UpgradedSlash") or assets:FindFirstChild("RegularSwingVFX")
	if SwingVfx then
		local activeVfx = SwingVfx:Clone()
		activeVfx.Anchored = false
		activeVfx.CanCollide = false
		activeVfx.CanQuery = false
		activeVfx.Massless = true
		activeVfx.Parent = workspace
		local weld = Instance.new("Weld")
		weld.Part0 = rootPart
		weld.Part1 = activeVfx
		weld.C0 = offset
		weld.Parent = activeVfx
		task.delay(0.05, function()
			for _, child in ipairs(activeVfx:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					if currentM1 == 2 and BatType == "VerityBat" then child.Rotation = NumberRange.new(-90) end
					if currentM1 == 3 then child.Rotation = NumberRange.new(180) end
					child:Emit(5)
				end
			end
		end)
		Debris:AddItem(activeVfx, 1)
	end

	if BatType == "VerityBat" then
		local beamclone = SwingBeam:Clone()
		for _, part in ipairs(beamclone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.CanQuery = false
				part.Massless = true
			end
		end
		local primary = beamclone:WaitForChild("primary")
		local weld = Instance.new("Weld")
		weld.Part0 = rootPart
		weld.Part1 = primary
		weld.C0 = offset
		weld.Parent = primary
		beamclone.Parent = workspace

		local beams = {}
		for _, d in ipairs(beamclone:GetDescendants()) do
			if d:IsA("Beam") then
				table.insert(beams, { beam = d, w0 = d.Width0, w1 = d.Width1, tr = d.Transparency })
				d.Width0, d.Width1 = 0, 0
				d.Transparency = NumberSequence.new(1)
				d.Enabled = true
			end
		end

		local LIFETIME, FADE_IN, FADE_OUT, ROT = 0.5, 0.15, 0.2, 720
		local elapsed = 0
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			weld.C0 = offset * CFrame.Angles(math.rad(180), math.rad(ROT * elapsed), 0)
			local alpha
			if elapsed < FADE_IN then
				alpha = TweenService:GetValue(elapsed / FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			elseif elapsed > LIFETIME - FADE_OUT then
				alpha = 1 - TweenService:GetValue((elapsed - (LIFETIME - FADE_OUT)) / FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			else
				alpha = 1
			end
			for _, b in ipairs(beams) do
				b.beam.Width0 = b.w0 * alpha
				b.beam.Width1 = b.w1 * alpha
				local kps = {}
				for i, kp in ipairs(b.tr.Keypoints) do
					kps[i] = NumberSequenceKeypoint.new(kp.Time, 1 - (1 - kp.Value) * alpha)
				end
				b.beam.Transparency = NumberSequence.new(kps)
			end
			if elapsed >= LIFETIME or not beamclone.Parent then conn:Disconnect() end
		end)
		Debris:AddItem(beamclone, LIFETIME)
	end
end)

--==================================================
-- damage (boss + minions only)
--==================================================
Swing.OnServerEvent:Connect(function(player, hitPart, currentM1)
	if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") or not hitPart.Parent then return end
	local character = player.Character
	if not hasBat(character) then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local model = hitPart:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	if not canDamage(model) then return end -- players are never hit
	if distToPart(hitPart, rootPart.Position) > CONFIG.HIT_RANGE then return end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid:TakeDamage(CONFIG.BAT_DAMAGE)

	-- knock minions back; the boss is far too big to move
	if not isBoss(model) and currentM1 ~= 3 then
		local enemyRoot = model:FindFirstChild("HumanoidRootPart")
		if enemyRoot and not enemyRoot.Anchored then
			local dir = (enemyRoot.Position - rootPart.Position) * Vector3.new(1, 0, 1)
			dir = dir.Magnitude > 0 and dir.Unit or rootPart.CFrame.LookVector
			enemyRoot.AssemblyLinearVelocity = dir * 45 + Vector3.new(0, 20, 0)
		end
	end
end)

--==================================================
-- ground slam (3rd hit)
--==================================================
local function raycastGround(worldPos, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return workspace:Raycast(worldPos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), params)
end

GroundSlam.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not hasBat(character) then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	local mult = character:FindFirstChild("VerityBat") and 2 or 1

	local exclude = { character }
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(exclude, p.Character) end end

	local forwardPoint = rootPart.Position + rootPart.CFrame.LookVector * 6.5
	local mainHit = raycastGround(forwardPoint, exclude) or raycastGround(rootPart.Position, exclude)
	if not mainHit then return end
	local slamPosition = mainHit.Position
	local color = mainHit.Instance:IsA("Terrain") and workspace.Terrain:GetMaterialColor(mainHit.Material) or mainHit.Instance.Color

	-- damage boss / minions in range (never players)
	local radius = 5 * mult
	local damaged = {}
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	for _, part in ipairs(workspace:GetPartBoundsInRadius(slamPosition, radius + 4, params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		while model and not model:FindFirstChildOfClass("Humanoid") do model = model:FindFirstAncestorOfClass("Model") end
		if model and not damaged[model] and canDamage(model) then
			damaged[model] = true
			model:FindFirstChildOfClass("Humanoid"):TakeDamage(CONFIG.SLAM_DAMAGE * mult / 2)
		end
	end

	-- ring of rubble (client) + slam vfx
	local ring = {}
	local count = 14 * mult
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local h = raycastGround(slamPosition + Vector3.new(math.cos(a), 0, math.sin(a)) * 4.5 * mult, exclude)
		if h and math.abs(h.Position.Y - slamPosition.Y) <= 2 then table.insert(ring, h.Position) end
	end
	GroundSlamVisual:FireAllClients(slamPosition, mainHit.Material, color, ring)

	if mult == 2 and SlamVFX then
		local v = SlamVFX:Clone()
		v.Anchored = true
		v.CanCollide = false
		v.CFrame = CFrame.new(slamPosition + Vector3.new(0, 0.2, 0))
		v.Parent = workspace
		task.delay(0.05, function()
			for _, e in ipairs(v:GetDescendants()) do
				if e:IsA("ParticleEmitter") then e:Emit(e:GetAttribute("EmitCount") or 1) end
			end
		end)
		Debris:AddItem(v, 3)
	end
end)

Players.PlayerRemoving:Connect(function(p) lastSwing[p] = nil end)

-- Studio-only test hook: ServerStorage.BatTest:Invoke(player) deflects every
-- energy orb within 150 studs of that player (used to verify deflect damage).
if RunService:IsStudio() then
	local test = Instance.new("BindableFunction")
	test.Name = "BatTest"
	test.OnInvoke = function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return 0 end
		local n, seen = 0, 0
		for projectile, state in pairs(BossUtil.ActiveProjectiles) do
			seen += 1
			if (state.position - root.Position).Magnitude < 150 and BossUtil.Deflect(projectile, player) then n += 1 end
		end
		return n, seen
	end
	test.Parent = ServerStorage
end
