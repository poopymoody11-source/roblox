--==================================================
-- BOSS PORTAL REVEAL  (client)
-- Buying "The End?" doesn't just flick the portal on: the sky
-- splits, a pillar of light slams into the base, the portal builds
-- itself piece by piece from the ground up, shockwaves roll out
-- and it bursts into life. The buyer's camera swings round to watch.
--==================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local remote = game:GetService("ReplicatedStorage"):WaitForChild("BossPortalReveal")

local PURPLE = Color3.fromRGB(170, 80, 255)
local GOLD = Color3.fromRGB(255, 210, 90)
local WHITE = Color3.new(1, 1, 1)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	p.Parent = workspace
	return p
end
local function sound(id, vol, speed, at)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = vol
	s.PlaybackSpeed = speed or 1
	if at then
		s.RollOffMaxDistance = 400
		s.Parent = at
	else
		s.Parent = SoundService
	end
	s:Play()
	Debris:AddItem(s, 8)
end
local function ring(center, color, r1, t, y)
	local r = part({ Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.1, Size = Vector3.new(0.4, 2, 2),
		CFrame = CFrame.new(center + Vector3.new(0, y or 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	TweenService:Create(r, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.4, r1 * 2, r1 * 2), Transparency = 1 }):Play()
	Debris:AddItem(r, t + 0.1)
end
local function burst(pos, color, n, speed, size)
	local a = part({ Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(pos) })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(WHITE, color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(size or 1.2, 0)
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 2
	e.Rate = 0
	e.Parent = a
	e:Emit(n)
	Debris:AddItem(a, 2)
end
local function smoke(pos, n)
	local a = part({ Transparency = 1, Size = Vector3.new(10, 1, 10), CFrame = CFrame.new(pos) })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(120, 90, 160), Color3.fromRGB(40, 20, 60))
	e.Size = NumberSequence.new(4, 14)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.2, 2.2)
	e.Speed = NumberRange.new(14, 30)
	e.SpreadAngle = Vector2.new(85, 5)
	e.EmissionDirection = Enum.NormalId.Top
	e.Drag = 3
	e.Rate = 0
	e.Parent = a
	e:Emit(n)
	Debris:AddItem(a, 3)
end

local function reveal(portal, ownerId)
	if not portal or not portal.Parent then return end
	local cf, size = portal:GetBoundingBox()
	local center = cf.Position
	local ground = center - Vector3.new(0, size.Y / 2, 0)
	local me = ownerId == player.UserId
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not me and (not root or (root.Position - center).Magnitude > 450) then return end

	-- hide it, then build it back up bottom to top
	local parts = {}
	for _, d in ipairs(portal:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) d.LocalTransparencyModifier = 1 end
	end
	table.sort(parts, function(a, b) return a.Position.Y < b.Position.Y end)

	-- the buyer's camera: a slow push round the portal
	local cam = workspace.CurrentCamera
	local camConn
	if me then
		cam.CameraType = Enum.CameraType.Scriptable
		local t0 = os.clock()
		local look = cf.LookVector
		local startCF = cam.CFrame
		camConn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			local a = math.rad(-40 + t * 14)
			local dist = 46 - math.min(t, 5) * 2
			local want = CFrame.lookAt(center + Vector3.new(math.sin(a) * dist, 8 + size.Y * 0.2, math.cos(a) * dist) + look * 0, center + Vector3.new(0, 1, 0))
			local k = math.min(t / 0.8, 1)
			cam.CFrame = startCF:Lerp(want, k * k * (3 - 2 * k))
			if t < 5.4 then
				local sh = (t > 1.1 and t < 1.6) and 0.9 or ((t > 4.2 and t < 4.9) and 0.6 or 0.06)
				cam.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.02 * sh, (math.random() - 0.5) * 0.02 * sh, 0)
			end
		end)
	end

	-- 1. the sky splits: a pillar of light slams down
	sound(1837830314, 0.5, 0.45) -- rumble
	local pillar = part({ Shape = Enum.PartType.Cylinder, Color = PURPLE, Transparency = 0.2,
		Size = Vector3.new(400, 0.5, 0.5), CFrame = CFrame.new(ground + Vector3.new(0, 200, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	local core = part({ Shape = Enum.PartType.Cylinder, Color = WHITE, Transparency = 0.1,
		Size = Vector3.new(400, 0.2, 0.2), CFrame = pillar.CFrame })
	TweenService:Create(pillar, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(400, size.X * 0.9, size.X * 0.9) }):Play()
	TweenService:Create(core, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(400, size.X * 0.35, size.X * 0.35) }):Play()
	local light = Instance.new("PointLight")
	light.Color = PURPLE
	light.Range = 60
	light.Brightness = 0
	light.Parent = core
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 8 }):Play()
	task.wait(1.1)
	sound(1837830314, 0.8, 0.8, core) -- impact
	ring(ground, PURPLE, 60, 1.1)
	ring(ground, GOLD, 42, 0.9, 0.6)
	smoke(ground + Vector3.new(0, 1, 0), 40)
	burst(ground + Vector3.new(0, 2, 0), PURPLE, 90, 70, 1.6)

	-- 2. it builds itself, piece by piece, from the ground up
	local step = 2.2 / math.max(#parts, 1)
	for i, p in ipairs(parts) do
		task.delay(i * step, function()
			if not p.Parent then return end
			local v = Instance.new("NumberValue")
			v.Value = 1
			v.Changed:Connect(function(x) if p.Parent then p.LocalTransparencyModifier = x end end)
			TweenService:Create(v, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Value = 0 }):Play()
			Debris:AddItem(v, 0.5)
			burst(p.Position, (i % 2 == 0) and GOLD or PURPLE, 14, 22, 0.8)
			if i % 3 == 0 then sound(10066947742, 0.25, 0.8 + i * 0.05, p) end
		end)
	end
	task.wait(2.6)

	-- 3. it comes alive
	sound(1837830314, 1, 0.55, core)
	ring(ground, WHITE, 90, 1.4)
	ring(ground, PURPLE, 70, 1.2, 1.2)
	ring(center, GOLD, 50, 1, 0)
	burst(center, GOLD, 160, 90, 2)
	smoke(ground + Vector3.new(0, 1, 0), 30)
	TweenService:Create(pillar, TweenInfo.new(1.2), { Size = Vector3.new(400, 0.2, 0.2), Transparency = 1 }):Play()
	TweenService:Create(core, TweenInfo.new(1.2), { Size = Vector3.new(400, 0.1, 0.1), Transparency = 1 }):Play()
	TweenService:Create(light, TweenInfo.new(1.2), { Brightness = 0 }):Play()
	Debris:AddItem(pillar, 1.3)
	Debris:AddItem(core, 1.3)
	for _, p in ipairs(parts) do if p.Parent then p.LocalTransparencyModifier = 0 end end

	if me then
		-- a banner
		local gui = Instance.new("ScreenGui")
		gui.Name = "PortalRevealBanner"
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 80
		gui.Parent = player:WaitForChild("PlayerGui")
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.26)
		l.Size = UDim2.fromScale(0.7, 0.1)
		l.BackgroundTransparency = 1
		l.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
		l.TextScaled = true
		l.TextColor3 = WHITE
		l.Text = "THE FINAL BOSS AWAITS..."
		l.Parent = gui
		local st = Instance.new("UIStroke")
		st.Thickness = 4
		st.Color = Color3.fromRGB(40, 10, 70)
		st.Parent = l
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, PURPLE), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, GOLD) })
		g.Parent = l
		local sc = Instance.new("UIScale")
		sc.Scale = 2
		sc.Parent = l
		TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TweenService:Create(g, TweenInfo.new(2.5, Enum.EasingStyle.Linear), { Offset = Vector2.new(1, 0) }):Play()
		task.delay(2.6, function()
			TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			TweenService:Create(st, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			task.delay(0.6, function() gui:Destroy() end)
		end)
		task.wait(1.6)
		if camConn then camConn:Disconnect() end
		cam.CameraType = Enum.CameraType.Custom
	end
end

remote.OnClientEvent:Connect(function(portal, ownerId)
	task.spawn(reveal, portal, ownerId)
end)
