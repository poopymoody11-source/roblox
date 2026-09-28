--==================================================
-- COMMAND STAFF FLING  (SERVER)
--
-- Clicking with the OP (Command) Staff fires a /tp-style
-- shockwave in the aimed direction. Any player caught in
-- the cone is launched and killed -- but ONLY if both
-- the attacker and the target have PvP switched on.
-- With PvP off it's still a big visual blast, it just
-- can't touch anyone.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local CONFIG = {
	TOOL_NAME = "opstaff",
	COOLDOWN = 1.6,
	RANGE = 55,           -- studs
	CONE_DEG = 38,        -- half-angle of the blast cone
	CLOSE_RADIUS = 7,     -- anyone this close is hit regardless of aim
	LAUNCH_SPEED = 170,
	LAUNCH_UP = 95,
	KILL_DELAY = 0.7,     -- let them fly a bit before they die
}

local remote = ReplicatedStorage:FindFirstChild("StaffFling")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "StaffFling"
	remote.Parent = ReplicatedStorage
end

local lastUse = {}
local lastBossHit = {}
local BOSS_DAMAGE = 100      -- per click against Cruelty
local BOSS_CLICK_CD = 0.22
local BOSS_RANGE = 90

-- Cruelty (the NPC boss) takes BOSS_DAMAGE per click, no PvP needed.
local function crueltyTarget(origin, dir)
	local cc = workspace:FindFirstChild("CrueltyCutscene")
	local boss = cc and cc:FindFirstChild("Cruelty_Active")
	local hum = boss and boss:FindFirstChildOfClass("Humanoid")
	local root = boss and boss:FindFirstChild("HumanoidRootPart")
	if not (hum and root) or hum.Health <= 0 then return nil end
	if boss:GetAttribute("Entering") == true then return nil end
	local to = root.Position - origin
	local dist = to.Magnitude
	if dist > BOSS_RANGE then return nil end
	local flat = to * Vector3.new(1, 0, 1)
	local fdir = dir * Vector3.new(1, 0, 1)
	if dist > 18 and flat.Magnitude > 0.1 and fdir.Magnitude > 0.1 and flat.Unit:Dot(fdir.Unit) < 0.35 then return nil end
	return hum, root
end

local function bossHitFx(pos)
	local p = Instance.new("Part")
	p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(110, 255, 150)
	p.Size = Vector3.new(3, 3, 3)
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(14, 14, 14), Transparency = 1 }):Play()
	Debris:AddItem(p, 0.35)
end

local function pvpOn(player)
	return player:GetAttribute("PvpEnabled") == true
end

local function blastVisual(origin, dir)
	-- expanding ring
	local ring = Instance.new("Part")
	ring.Name = "CommandBlast"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 150, 60)
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.4, 4, 4)
	-- cylinder axis is X: point it along the blast direction
	ring.CFrame = CFrame.lookAt(origin, origin + dir) * CFrame.Angles(0, math.rad(90), 0)
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 34, 34),
		CFrame = ring.CFrame + dir * 22,
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)

	-- beam of green "command" particles down the cone
	local carrier = Instance.new("Part")
	carrier.Anchored = true
	carrier.CanCollide = false
	carrier.CanQuery = false
	carrier.CanTouch = false
	carrier.Transparency = 1
	carrier.Size = Vector3.new(1, 1, 1)
	carrier.CFrame = CFrame.lookAt(origin, origin + dir)
	carrier.Parent = workspace
	local att = Instance.new("Attachment")
	att.Parent = carrier
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(110, 255, 150))
	pe.LightEmission = 1
	pe.Lifetime = NumberRange.new(0.35, 0.6)
	pe.Speed = NumberRange.new(60, 110)
	pe.SpreadAngle = Vector2.new(CONFIG.CONE_DEG * 0.6, CONFIG.CONE_DEG * 0.6)
	pe.EmissionDirection = Enum.NormalId.Front
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(90)
	Debris:AddItem(carrier, 1)

	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://1837830314" -- deep boom (licensed library)
	s.Volume = 0.5
	s.PlaybackSpeed = 0.9
	s.Parent = carrier
	s:Play()

	-- flash of light at the staff
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 70)
	light.Range = 28
	light.Brightness = 6
	light.Parent = carrier
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()

	-- second, green "command" ring chasing the first
	task.delay(0.08, function()
		local ring2 = ring:Clone()
		ring2.Color = Color3.fromRGB(110, 255, 150)
		ring2.Size = Vector3.new(0.3, 3, 3)
		ring2.Transparency = 0.1
		ring2.CFrame = CFrame.lookAt(origin, origin + dir) * CFrame.Angles(0, math.rad(90), 0)
		ring2.Parent = workspace
		TweenService:Create(ring2, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.15, 26, 26),
			CFrame = ring2.CFrame + dir * 34,
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring2, 0.6)
	end)

	-- voxel burst: little glowing command-block cubes blasted down the cone
	local rng = Random.new()
	for i = 1, 18 do
		local cube = Instance.new("Part")
		cube.Anchored = true
		cube.CanCollide = false
		cube.CanQuery = false
		cube.CanTouch = false
		cube.Material = Enum.Material.Neon
		cube.Color = (i % 3 == 0) and Color3.fromRGB(110, 255, 150) or Color3.fromRGB(255, 150, 60)
		local size = rng:NextNumber(0.35, 0.8)
		cube.Size = Vector3.new(size, size, size)
		cube.CFrame = CFrame.new(origin) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0)
		cube.Parent = workspace
		local spread = CFrame.lookAt(Vector3.zero, dir)
			* CFrame.Angles(math.rad(rng:NextNumber(-CONFIG.CONE_DEG, CONFIG.CONE_DEG)), math.rad(rng:NextNumber(-CONFIG.CONE_DEG, CONFIG.CONE_DEG)), 0)
		local travel = spread.LookVector * rng:NextNumber(18, CONFIG.RANGE * 0.8)
		TweenService:Create(cube, TweenInfo.new(rng:NextNumber(0.45, 0.8), Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(origin + travel) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0),
			Size = Vector3.new(0.05, 0.05, 0.05),
			Transparency = 1,
		}):Play()
		Debris:AddItem(cube, 0.9)
	end

	-- "/fling @e" pops up in command-block green like a chat command
	local tag = Instance.new("Part")
	tag.Anchored = true
	tag.CanCollide = false
	tag.CanQuery = false
	tag.CanTouch = false
	tag.Transparency = 1
	tag.Size = Vector3.new(0.2, 0.2, 0.2)
	tag.CFrame = CFrame.new(origin + Vector3.new(0, 3, 0))
	tag.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(7, 1.4)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = tag
	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency = 1
	txt.Size = UDim2.fromScale(1, 1)
	txt.Font = Enum.Font.Code
	txt.TextScaled = true
	txt.TextColor3 = Color3.fromRGB(110, 255, 150)
	txt.Text = "/fling @e[r=" .. CONFIG.RANGE .. "]"
	txt.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Parent = txt
	TweenService:Create(tag, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = tag.CFrame + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(txt, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	TweenService:Create(st, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(tag, 1)
end

local function launch(targetChar, dir)
	local hrp = targetChar:FindFirstChild("HumanoidRootPart")
	local hum = targetChar:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) or hum.Health <= 0 then return end

	hum.PlatformStand = true

	-- A constraint replicates to the target's own client (which
	-- owns their physics), unlike setting velocity from here.
	local att = Instance.new("Attachment")
	att.Name = "FlingAttachment"
	att.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = dir * CONFIG.LAUNCH_SPEED + Vector3.new(0, CONFIG.LAUNCH_UP, 0)
	lv.Parent = hrp
	local av = Instance.new("AngularVelocity")
	av.Attachment0 = att
	av.MaxTorque = math.huge
	av.AngularVelocity = Vector3.new(math.random(-25, 25), math.random(-25, 25), math.random(-25, 25))
	av.Parent = hrp
	Debris:AddItem(lv, 0.3)
	Debris:AddItem(av, 0.6)
	Debris:AddItem(att, 0.6)

	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(255, 150, 60)
	fire.SecondaryColor = Color3.fromRGB(110, 255, 150)
	fire.Size = 6
	fire.Parent = hrp
	Debris:AddItem(fire, 2)

	task.delay(CONFIG.KILL_DELAY, function()
		if hum.Parent then
			hum.Health = 0
		end
	end)
end

remote.OnServerEvent:Connect(function(player, aimPoint)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not (tool and tool.Name == CONFIG.TOOL_NAME) then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp) or hum.Health <= 0 then return end

	local now = os.clock()
	local origin = hrp.Position
	local dir = hrp.CFrame.LookVector
	if typeof(aimPoint) == "Vector3" and aimPoint == aimPoint then
		local flat = (aimPoint - origin) * Vector3.new(1, 0.35, 1)
		if flat.Magnitude > 0.5 then dir = flat.Unit end
	end

	-- Boss fight: every click hits Cruelty for BOSS_DAMAGE
	local bossHum, bossRoot = crueltyTarget(origin, dir)
	if bossHum then
		if lastBossHit[player] and now - lastBossHit[player] < BOSS_CLICK_CD then return end
		lastBossHit[player] = now
		-- never skip his phase-2 shift / final attack in one click: leave a sliver
		local dmg = BOSS_DAMAGE
		if bossHum.Health > bossHum.MaxHealth * 0.2 then
			dmg = math.min(dmg, bossHum.Health - 1)
		end
		bossHum:TakeDamage(dmg)
		bossHitFx(bossRoot.Position)
		if not lastUse[player] or now - lastUse[player] >= CONFIG.COOLDOWN then
			lastUse[player] = now
			blastVisual(origin + dir * 2, dir)
		end
		return
	end

	if lastUse[player] and now - lastUse[player] < CONFIG.COOLDOWN then return end
	lastUse[player] = now

	blastVisual(origin + dir * 2, dir)

	if not pvpOn(player) then return end

	local cosCone = math.cos(math.rad(CONFIG.CONE_DEG))
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and pvpOn(other) and not other:GetAttribute("InCrueltyArena") and not player:GetAttribute("InCrueltyArena") and (other:GetAttribute("SpawnProtectedUntil") or 0) <= workspace:GetServerTimeNow() then
			local oc = other.Character
			local ohrp = oc and oc:FindFirstChild("HumanoidRootPart")
			if ohrp then
				local to = ohrp.Position - origin
				local dist = to.Magnitude
				if dist <= CONFIG.CLOSE_RADIUS
					or (dist <= CONFIG.RANGE and to.Unit:Dot(dir) >= cosCone) then
					local flat = to * Vector3.new(1, 0, 1)
					launch(oc, flat.Magnitude > 0.1 and flat.Unit or dir)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	lastUse[p] = nil
	lastBossHit[p] = nil
end)
