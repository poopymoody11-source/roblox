--==================================================
-- THE SPIRAL BAT (client)
--   Click / tap / R2  - swing (a 3-hit combo; the 3rd slams the ground).
--                       Swing as a hit lands on you to PARRY it.
--   Q / ButtonB       - Spiral Dash: a burst of speed, brief i-frames
--   E / ButtonY       - Drill Break: charge and hurl a spiral drill at his core
-- During the fight the bat is always in your hand (the backpack bar is
-- hidden). Also draws everyone's bat effects and spins every drill tip.
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Bat = {}

local TOOL = "SpiralBat"
local GREEN = Color3.fromRGB(70, 255, 120)
local LIME = Color3.fromRGB(190, 255, 90)
local WHITE = Color3.new(1, 1, 1)
-- (the Become La Peace UI look: chunky black outlines, purple gradient cards,
-- Inconsolata Bold with black strokes)
local FONT = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)
local CARD_A, CARD_B = Color3.fromRGB(70, 25, 140), Color3.fromRGB(150, 70, 255)
local KEY_A, KEY_B = Color3.fromRGB(215, 205, 235), Color3.new(1, 1, 1)
local KEY_TEXT = Color3.fromRGB(60, 20, 120)

local player = Players.LocalPlayer
local K, S, Fx, Warn, net, shared, Cam
local getChest -- () -> his chest position

local combo, lastSwing = 0, 0
local lastDash, lastDrill = -99, -99
local charging = false
local tracks = {}
local hud, slots = nil, {}
local active = false -- the fight is on

local function cfgAttr(name, default)
	local v = shared:GetAttribute(name)
	return type(v) == "number" and v or default
end

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

--------------------------------------------------------------------------
-- the ability bar
--------------------------------------------------------------------------
local function stroke(p, color, th, mode)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = th or 4
	if mode then s.ApplyStrokeMode = mode end
	s.Parent = p
	return s
end
local function grad(p, a, b, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rot or -90
	g.Parent = p
	return g
end
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = r c.Parent = p return c end
local function label(parent, props, th)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.TextScaled = true
	t.TextColor3 = WHITE
	for k, v in pairs(props) do t[k] = v end
	t.Parent = parent
	if (th or 3) > 0 then stroke(t, Color3.new(0, 0, 0), th or 3) end
	return t
end

local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpiralBatHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -16)
	bar.Size = UDim2.fromScale(0.36, 0.12)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 3.9
	ar.Parent = bar
	local ll = Instance.new("UIListLayout")
	ll.FillDirection = Enum.FillDirection.Horizontal
	ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ll.VerticalAlignment = Enum.VerticalAlignment.Center
	ll.Padding = UDim.new(0.025, 0)
	ll.Parent = bar
	local touch = UIS.TouchEnabled and not UIS.KeyboardEnabled
	local pad = UIS.GamepadEnabled and not UIS.KeyboardEnabled
	local defs = {
		{ Key = "Swing", Glyph = touch and "TAP" or pad and "R2" or "M1", Name = "SWING / PARRY" },
		{ Key = "Dash", Glyph = pad and "B" or "Q", Name = "SPIRAL DASH" },
		{ Key = "Drill", Glyph = pad and "Y" or "E", Name = "DRILL BREAK" },
	}
	for i, d in ipairs(defs) do
		local card = Instance.new("Frame")
		card.Name = d.Key
		card.Size = UDim2.fromScale(0.31, 1)
		card.BackgroundColor3 = WHITE
		card.LayoutOrder = i
		card.Parent = bar
		corner(card, UDim.new(0.18, 0))
		local cs = stroke(card, Color3.new(0, 0, 0), 4, Enum.ApplyStrokeMode.Border)
		grad(card, CARD_A, CARD_B)
		-- the keycap
		local cap = Instance.new("Frame")
		cap.AnchorPoint = Vector2.new(0, 0.5)
		cap.Position = UDim2.fromScale(0.07, 0.5)
		cap.Size = UDim2.fromScale(0.62, 0.62)
		cap.SizeConstraint = Enum.SizeConstraint.RelativeYY
		cap.BackgroundColor3 = WHITE
		cap.ZIndex = 2
		cap.Parent = card
		corner(cap, UDim.new(0.25, 0))
		stroke(cap, Color3.new(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)
		grad(cap, KEY_A, KEY_B)
		label(cap, { Text = d.Glyph, Size = UDim2.fromScale(0.8, 0.7), Position = UDim2.fromScale(0.1, 0.15), TextColor3 = KEY_TEXT, ZIndex = 3 }, 0)
		-- the name
		label(card, { Text = d.Name, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.95, 0.5), Size = UDim2.fromScale(0.5, 0.42), ZIndex = 2, TextXAlignment = Enum.TextXAlignment.Left }, 2.5)
		-- cooldown: a dark sheet that drains away, and the seconds left
		local cd = Instance.new("Frame")
		cd.Name = "Cooldown"
		cd.AnchorPoint = Vector2.new(0, 1)
		cd.Position = UDim2.fromScale(0, 1)
		cd.Size = UDim2.fromScale(1, 0)
		cd.BackgroundColor3 = Color3.fromRGB(10, 5, 25)
		cd.BackgroundTransparency = 0.3
		cd.ZIndex = 4
		cd.Parent = card
		corner(cd, UDim.new(0.18, 0))
		local secs = label(card, { Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.55), ZIndex = 5, Visible = false }, 3)
		local sc = Instance.new("UIScale")
		sc.Parent = card
		slots[d.Key] = { Card = card, Stroke = cs, Cooldown = cd, Secs = secs, Scale = sc, Ready = true }
	end
	hud = gui
end

local function pulse(key, color)
	local s = slots[key]
	if not s then return end
	s.Scale.Scale = 1.12
	tween(s.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	s.Stroke.Color = color or WHITE
	tween(s.Stroke, 0.35, { Color = Color3.new(0, 0, 0) })
end

--------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------
local function myChar()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then return nil end
	return c, hum, root
end

local function equipped()
	local c = player.Character
	return c and c:FindFirstChild(TOOL)
end

local function track(hum, name)
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return nil end
	tracks[animator] = tracks[animator] or {}
	local t = tracks[animator][name]
	if t then return t end
	local folder = ReplicatedStorage:FindFirstChild("SwingAnims")
	local anim = folder and folder:FindFirstChild(name)
	if not anim then return nil end
	local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
	if not ok then return nil end
	tr.Priority = Enum.AnimationPriority.Action
	tracks[animator][name] = tr
	return tr
end

local function trailOn(tool, dur)
	local h = tool and tool:FindFirstChild("Handle")
	local tr = h and h:FindFirstChild("SwingTrail")
	if not tr then return end
	tr.Enabled = true
	task.delay(dur, function() if tr.Parent then tr.Enabled = false end end)
end

--------------------------------------------------------------------------
-- swing effects (the old Verity Bat's slash + swing beam, and a ground slam)
--------------------------------------------------------------------------
local SLASH_OFFSETS = {
	CFrame.new(0, 0, -1) * CFrame.Angles(0, math.rad(90), math.rad(-190)) * CFrame.Angles(0, 0, math.rad(-10)),
	CFrame.new(0, 0, -1) * CFrame.Angles(0, math.rad(90), 0),
	CFrame.new(0, 0, -1) * CFrame.Angles(0, 0, math.rad(-90)),
}

local function slashFx(char, n)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local assets = ReplicatedStorage:FindFirstChild("BatAssets")
	if not (root and assets) then return end
	local offset = SLASH_OFFSETS[n] or SLASH_OFFSETS[1]
	local slash = assets:FindFirstChild("UpgradedSlash")
	if slash then
		local v = slash:Clone()
		v.Anchored, v.CanCollide, v.CanQuery, v.CanTouch, v.Massless = false, false, false, false, true
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = root, v, offset
		w.Parent = v
		v.Parent = Fx.Folder
		task.delay(0.05, function()
			for _, e in ipairs(v:GetDescendants()) do
				if e:IsA("ParticleEmitter") then
					if n == 2 then e.Rotation = NumberRange.new(-90) end
					if n == 3 then e.Rotation = NumberRange.new(180) end
					e:Emit(5)
				end
			end
		end)
		Debris:AddItem(v, 1)
	end
	local beamSrc = assets:FindFirstChild("SwingBeam")
	local primary = beamSrc and beamSrc:FindFirstChild("primary")
	if primary then
		local m = beamSrc:Clone()
		local prim = m:FindFirstChild("primary")
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true end
		end
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = root, prim, offset
		w.Parent = prim
		m.Parent = Fx.Folder
		local beams = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("Beam") then
				table.insert(beams, { B = d, W0 = d.Width0, W1 = d.Width1, T = d.Transparency })
				d.Width0, d.Width1, d.Enabled = 0, 0, true
			end
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local e = os.clock() - t0
			w.C0 = offset * CFrame.Angles(math.rad(180), math.rad(720 * e), 0)
			local a = e < 0.12 and K.E.outQuad(e / 0.12) or 1 - K.E.inQuad(math.clamp((e - 0.3) / 0.2, 0, 1))
			for _, b in ipairs(beams) do
				b.B.Width0, b.B.Width1 = b.W0 * a, b.W1 * a
			end
			if e >= 0.5 or not m.Parent then
				conn:Disconnect()
				m:Destroy()
			end
		end)
	end
end

local function slamFx(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, Fx.Folder }
	local from = root.Position + root.CFrame.LookVector * 6 + Vector3.new(0, 4, 0)
	local hit = workspace:Raycast(from, Vector3.new(0, -14, 0), params)
	local at = hit and hit.Position or (root.Position + root.CFrame.LookVector * 6 - Vector3.new(0, 3, 0))
	-- rubble thrown up in a ring
	local mat = hit and hit.Material or Enum.Material.Slate
	local col = hit and (hit.Instance:IsA("BasePart") and hit.Instance.Color) or Color3.fromRGB(60, 40, 90)
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local p = at + Vector3.new(math.cos(a) * 5.5, 0, math.sin(a) * 5.5)
		local c = K.part({ Name = "Rubble", Size = Vector3.new(math.random(8, 18) / 10, math.random(8, 18) / 10, math.random(8, 18) / 10), Material = mat, Color = col,
			CFrame = CFrame.new(p) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6) }, Fx.Folder)
		tween(c, 0.15, { CFrame = c.CFrame + Vector3.new(0, 0.9, 0) }, Enum.EasingStyle.Back)
		task.delay(0.45, function() tween(c, 0.45, { CFrame = c.CFrame - Vector3.new(0, 2, 0), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end)
		Debris:AddItem(c, 1.1)
	end
	-- a green shockwave and the old slam burst
	local host = K.part({ Name = "SlamHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(at) }, Fx.Folder)
	local ring = K.softRing(host, 28, 2, 4, { Brightness = 5, Alpha = 0 })
	for _, q in ipairs(ring.Q) do q.Color = ColorSequence.new(WHITE, GREEN) end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = (os.clock() - t0) / 0.45
		if u >= 1 then conn:Disconnect() host:Destroy() return end
		local r = 3 + 16 * K.E.outCubic(u)
		ring.update(CFrame.lookAt(at + Vector3.new(0, 0.3, 0), at + Vector3.new(0, 2, 0)), r * 0.7, r, u * 4)
		ring.setTransparency(u)
	end)
	local src = ReplicatedStorage:FindFirstChild("BatAssets") and ReplicatedStorage.BatAssets:FindFirstChild("SlamVFX")
	if src then
		local v = src:Clone()
		v.Anchored, v.CanCollide = true, false
		v.CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0))
		v.Parent = Fx.Folder
		task.delay(0.05, function()
			for _, e in ipairs(v:GetDescendants()) do
				if e:IsA("ParticleEmitter") then e:Emit(e:GetAttribute("EmitCount") or 1) end
			end
		end)
		Debris:AddItem(v, 3)
	end
	Fx.sound(K.S.RockBoom, at, 0.7, 1.4, 250)
end

--------------------------------------------------------------------------
-- the parry's impact frame: a flash of the world into light, a beat of hit-stop
--------------------------------------------------------------------------
local impact
local function impactFrame(perfect)
	impact = impact or Instance.new("ColorCorrectionEffect")
	impact.Name = "BF_ParryFrame"
	impact.Parent = Lighting
	impact.Enabled = true
	impact.Saturation = perfect and -1 or -0.6
	impact.Contrast = perfect and 1.4 or 0.8
	impact.Brightness = perfect and 0.35 or 0.2
	impact.TintColor = perfect and Color3.fromRGB(255, 255, 200) or Color3.fromRGB(200, 255, 215)
	tween(impact, perfect and 0.35 or 0.22, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = WHITE })
	local _, hum = myChar()
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		local playing = animator:GetPlayingAnimationTracks()
		for _, t in ipairs(playing) do t:AdjustSpeed(0.05) end
		task.delay(perfect and 0.12 or 0.08, function()
			for _, t in ipairs(playing) do t:AdjustSpeed(1.25) end
		end)
	end
	local cam = workspace.CurrentCamera
	cam.FieldOfView -= perfect and 8 or 5
	Cam.shake(perfect and 1.6 or 1, 0.25)
end
Bat.impactFrame = impactFrame

--------------------------------------------------------------------------
-- actions
--------------------------------------------------------------------------
local function swing()
	if not active or charging then return end
	local char, hum, root = myChar()
	local tool = equipped()
	if not (hum and tool) then return end
	local now = os.clock()
	if now - lastSwing < cfgAttr("SwingCooldown", 0.28) then return end
	combo = (now - lastSwing > cfgAttr("ComboReset", 0.9)) and 1 or (combo % 3 + 1)
	lastSwing = now
	local ids = Warn.tryParry(S.now())
	net.Bat:FireServer("swing", combo, { T = S.now(), Ids = ids })
	local tr = track(hum, "Swing" .. combo)
	if tr then tr:Play(0.05, 1, 1.25) end
	trailOn(tool, 0.3)
	K.sfx(K.S.Whoosh, 0.55, 1.3 + combo * 0.08)
	pulse("Swing")
	local n = combo
	task.delay(0.08, function()
		slashFx(char, n)
		if n == 3 then slamFx(char) end
	end)
	if #ids > 0 then
		-- (instant feedback; the server's verdict follows)
		Fx.parryBurst(root.Position + root.CFrame.LookVector * 3, false)
		impactFrame(false)
	end
end

local function dash()
	if not active then return end
	local c, hum, root = myChar()
	if not (c and equipped()) then return end
	local now = os.clock()
	if now - lastDash < cfgAttr("DashCooldown", 2.2) then return end
	lastDash = now
	net.Bat:FireServer("dash")
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then dir = root.CFrame.LookVector end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = dir * 105 + Vector3.new(0, 4, 0)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	Debris:AddItem(lv, 0.17)
	Debris:AddItem(att, 0.17)
	workspace.CurrentCamera.FieldOfView += 9
	K.sfx(K.S.Whoosh, 0.9, 0.9)
	K.sfx(K.S.Electric, 0.35, 1.5)
	pulse("Dash", GREEN)
end

local function drill()
	if not active or charging then return end
	local _, hum, root = myChar()
	if not (hum and equipped()) then return end
	local now = os.clock()
	if now - lastDrill < cfgAttr("DrillCooldown", 7) then return end
	lastDrill = now
	charging = true
	pulse("Drill", GREEN)
	-- the wind-up: spiral energy pouring into the bat
	local tool = equipped()
	local core = tool and tool:FindFirstChild("Core")
	if core then
		local e = K.emitter(core, {
			Texture = "1851669703", Color = ColorSequence.new(WHITE, GREEN), Size = K.ns(0, 0, 0.3, 0.8, 1, 0),
			Lifetime = NumberRange.new(0.3, 0.35), Speed = NumberRange.new(-24, -18), SpreadAngle = Vector2.new(180, 180),
			Rate = 0, Brightness = 5, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		})
		e:Emit(40)
		Debris:AddItem(e, 1)
	end
	local tr = track(hum, "Swing3")
	if tr then tr:Play(0.1, 1, 0.55) end
	K.sfx(K.S.Riser, 0.6, 2.2)
	K.sfx(K.S.GreenAura, 0.6, 1.3)
	task.delay(0.32, function()
		charging = false
		if not active then return end
		net.Bat:FireServer("drill")
		if tr then tr:AdjustSpeed(1.6) end
		workspace.CurrentCamera.FieldOfView += 6
		Cam.shake(0.8, 0.2)
		if root.Parent then Fx.parryBurst(root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 2, 0), false) end
	end)
end

--------------------------------------------------------------------------
-- everyone's bat effects
--------------------------------------------------------------------------
local function charOf(userId)
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character
end

local function dashFx(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local from = root.Position
	Fx.emitAt(from, {
		Texture = "11381556016", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = ColorSequence.new(GREEN, LIME), Size = K.ns(0, 3, 1, 0), Lifetime = NumberRange.new(0.25, 0.5),
		Speed = NumberRange.new(8, 25), SpreadAngle = Vector2.new(180, 180), Brightness = 3, Rotation = NumberRange.new(0, 360),
	}, 22, 1.5)
	-- green afterimages along the dash
	for k = 0, 3 do
		task.delay(k * 0.04, function()
			for _, p in ipairs(char:GetChildren()) do
				if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" then
					local g = K.part({ Name = "Ghost", Size = p.Size, CFrame = p.CFrame, Material = Enum.Material.Neon, Color = k % 2 == 0 and GREEN or LIME, Transparency = 0.4 + k * 0.1 }, Fx.Folder)
					tween(g, 0.35, { Transparency = 1 })
					Debris:AddItem(g, 0.4)
				end
			end
		end)
	end
	-- a spiral streak from where you were
	task.delay(0.17, function()
		if not root.Parent then return end
		local host = K.part({ Name = "DashStreak", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(from) }, Fx.Folder)
		for i = 1, 2 do
			local b = K.ray(host, from, root.Position, 2.5, 0.4, "10365550877", { Color = i == 1 and GREEN or LIME, Brightness = 4, Segments = 16, Mode = Enum.TextureMode.Wrap, Length = 6, Speed = 4 })
			b.CurveSize0, b.CurveSize1 = (i == 1 and 3 or -3), (i == 1 and -3 or 3)
			task.spawn(function()
				local t0 = os.clock()
				while b.Parent and os.clock() - t0 < 0.4 do
					b.Transparency = NumberSequence.new((os.clock() - t0) / 0.4)
					RunService.RenderStepped:Wait()
				end
			end)
		end
		Debris:AddItem(host, 0.45)
	end)
end

local function drillFx(data)
	local from, t0, t1 = data.From, data.T0, data.T1
	local src = ReplicatedStorage:FindFirstChild("FinalCutscene")
	src = src and src:FindFirstChild("Assets") and src.Assets:FindFirstChild("DrillCone")
	local d
	if src then
		d = src:Clone()
		for _, c in ipairs(d:GetChildren()) do c:Destroy() end
		d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
	else
		d = K.part({ Size = Vector3.one }, nil)
	end
	d.Name = "DrillBreak"
	d.Material = Enum.Material.Neon
	d.Color = LIME
	d.CFrame = CFrame.new(from)
	d.Parent = Fx.Folder
	local shell = K.part({ Name = "DrillShell", Shape = Enum.PartType.Ball, Size = Vector3.one * 6, Material = Enum.Material.ForceField, Color = GREEN, Transparency = 0.1 }, Fx.Folder)
	-- two ribbons of spiral light corkscrewing round its flight
	local host = K.part({ Name = "DrillHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(from) }, Fx.Folder)
	local ribbons = {}
	for i = 1, 2 do
		local a0 = Instance.new("Attachment") a0.Parent = host
		local a1 = Instance.new("Attachment") a1.Parent = host
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.5
		tr.LightEmission = 1
		tr.Brightness = 5
		tr.Texture = "rbxassetid://10365550877"
		tr.Color = ColorSequence.new(WHITE, i == 1 and GREEN or LIME)
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		tr.Parent = host
		ribbons[i] = { A0 = a0, A1 = a1 }
	end
	K.emitter(d, {
		Texture = "1851669703", Color = ColorSequence.new(WHITE, GREEN), Size = K.ns(0, 3, 1, 0),
		Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(4, 12), SpreadAngle = Vector2.new(180, 180), Rate = 80, Brightness = 4,
	})
	Fx.sound(K.S.Cannon, from, 1, 1.15, 800)
	Fx.sound(K.S.Overdrive, from, 0.6, 1.3, 800)
	local spin = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local now = S.now()
		local u = math.clamp((now - t0) / math.max(t1 - t0, 0.05), 0, 1)
		local to = getChest()
		local function at(v) return from:Lerp(to, v) + Vector3.new(0, math.sin(math.pi * v) * 45, 0) end
		local p, ahead = at(u), at(math.min(u + 0.02, 1))
		spin += dt * 25
		local size = 4 + 14 * K.E.inQuad(u) -- (it grows as it flies: a GIGA drill by the time it lands)
		d.Size = Vector3.new(size * 0.5, size, size * 0.5)
		if (ahead - p).Magnitude > 0.01 then
			local cf = CFrame.lookAt(p, ahead)
			d.CFrame = cf * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, spin, 0)
			shell.CFrame = cf
			shell.Size = Vector3.one * size * 0.75
			for i, r in ipairs(ribbons) do
				local a = spin * 0.6 + (i - 1) * math.pi
				local off = (cf.RightVector * math.cos(a) + cf.UpVector * math.sin(a)) * size * 0.45
				r.A0.WorldPosition = p + off
				r.A1.WorldPosition = p + off * 1.3
			end
		end
		if u >= 1 then
			conn:Disconnect()
			d:Destroy()
			shell:Destroy()
			task.delay(0.5, function() host:Destroy() end)
			-- the break: a green galaxy bursts open on his chest
			local burstHost = K.part({ Name = "BreakHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(to) }, Fx.Folder)
			local g = Fx.galaxy(burstHost, { Fx.GREEN, Fx.LIME, Color3.fromRGB(220, 255, 220) })
			local tb = os.clock()
			local c2
			c2 = RunService.RenderStepped:Connect(function()
				local e = os.clock() - tb
				local amt = K.E.outCubic(math.min(e / 0.25, 1)) * (1 - K.k(e, 0.5, 1.1))
				g.set(to, from, 160 * (0.6 + 0.4 * math.min(e / 0.3, 1)), amt, e * 3)
				if e > 1.1 then c2:Disconnect() burstHost:Destroy() end
			end)
			Fx.bolt(from:Lerp(to, 0.9), to, true)
			Fx.emitAt(to, {
				Texture = "11381556016", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				Color = ColorSequence.new(GREEN, LIME), Size = K.ns(0, 40, 1, 0), Lifetime = NumberRange.new(0.4, 0.8),
				Speed = NumberRange.new(60, 160), SpreadAngle = Vector2.new(180, 180), Brightness = 4, Rotation = NumberRange.new(0, 360),
			}, 36, 2)
			Fx.sound(K.S.Boom, to, 1.2, 1.1, 3000)
			Cam.shake(1.2, 0.4)
		end
	end)
end

--------------------------------------------------------------------------
-- keeping the bat in hand
--------------------------------------------------------------------------
local backpackHidden = false
local function keepEquipped()
	if not active then
		if backpackHidden then
			backpackHidden = false
			pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true) end)
		end
		return
	end
	if not backpackHidden then
		backpackHidden = true
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
	end
	local c, hum = myChar()
	if not c or c:FindFirstChild(TOOL) then return end
	local bp = player:FindFirstChildOfClass("Backpack")
	local tool = bp and bp:FindFirstChild(TOOL)
	if tool then hum:EquipTool(tool) end
end

--------------------------------------------------------------------------
-- setup
--------------------------------------------------------------------------
function Bat.init(ctx)
	K, S, Fx, Warn, net, Cam = ctx.K, ctx.S, ctx.Fx, ctx.Warn, ctx.Net, ctx.Cam
	shared = ReplicatedStorage:WaitForChild("AntiSpiralFight")
	getChest = ctx.chest
	buildHud()

	local function hookTool(tool)
		if tool:IsA("Tool") and tool.Name == TOOL and not tool:GetAttribute("BF_Hooked") then
			tool:SetAttribute("BF_Hooked", true)
			tool.Activated:Connect(swing)
		end
	end
	local function hookChar(char)
		for _, c in ipairs(char:GetChildren()) do hookTool(c) end
		char.ChildAdded:Connect(hookTool)
		local bp = player:WaitForChild("Backpack")
		for _, c in ipairs(bp:GetChildren()) do hookTool(c) end
		bp.ChildAdded:Connect(hookTool)
	end
	if player.Character then task.spawn(hookChar, player.Character) end
	player.CharacterAdded:Connect(hookChar)

	local function bind(name, fn, ...)
		ContextActionService:BindAction(name, function(_, state)
			if state == Enum.UserInputState.Begin and equipped() then fn() return Enum.ContextActionResult.Sink end
			return Enum.ContextActionResult.Pass
		end, true, ...)
	end
	bind("SpiralDash", dash, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	bind("DrillBreak", drill, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
	pcall(function()
		ContextActionService:SetTitle("SpiralDash", "DASH")
		ContextActionService:SetTitle("DrillBreak", "DRILL")
		ContextActionService:SetPosition("SpiralDash", UDim2.new(1, -170, 1, -150))
		ContextActionService:SetPosition("DrillBreak", UDim2.new(1, -95, 1, -205))
	end)

	net.BatFx.OnClientEvent:Connect(function(kind, userId, data)
		local char = charOf(userId)
		if kind == "swing" then
			-- (your own swings already drew themselves)
			if userId ~= player.UserId and char then
				trailOn(char:FindFirstChild(TOOL), 0.3)
				slashFx(char, data)
				if data == 3 then slamFx(char) end
			end
		elseif kind == "dash" then
			dashFx(char)
		elseif kind == "drill" and type(data) == "table" then
			drillFx(data)
		end
	end)

	task.spawn(function()
		while true do
			pcall(keepEquipped)
			task.wait(0.2)
		end
	end)

	-- spin every drill tip; keep the ability bar current
	RunService.RenderStepped:Connect(function(dt)
		for _, p in ipairs(Players:GetPlayers()) do
			local tool = p.Character and p.Character:FindFirstChild(TOOL)
			local drillPart = tool and tool:FindFirstChild("Drill")
			local w = drillPart and drillPart:FindFirstChild("DrillWeld")
			if w then
				local fast = (p == player and (charging or os.clock() - lastSwing < 0.4)) and 5 or 1
				w.C0 = w.C0 * CFrame.Angles(0, dt * 9 * fast, 0)
			end
		end
		if hud then
			hud.Enabled = active and equipped() ~= nil
			if hud.Enabled then
				local now = os.clock()
				local function cd(key, last, total)
					local s = slots[key]
					local left = math.max(total - (now - last), 0)
					s.Cooldown.Size = UDim2.fromScale(1, math.clamp(left / total, 0, 1))
					s.Secs.Visible = left > 0.35
					if s.Secs.Visible then s.Secs.Text = string.format("%.1f", left) end
					-- (a pop when it comes back)
					local ready = left <= 0
					if ready and not s.Ready then pulse(key, LIME) end
					s.Ready = ready
				end
				cd("Swing", lastSwing, cfgAttr("SwingCooldown", 0.28))
				cd("Dash", lastDash, cfgAttr("DashCooldown", 2.2))
				cd("Drill", lastDrill, cfgAttr("DrillCooldown", 7))
			end
		end
	end)
end

function Bat.setActive(on)
	active = on
end

return Bat
