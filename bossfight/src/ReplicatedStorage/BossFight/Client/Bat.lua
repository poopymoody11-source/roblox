--==================================================
-- THE SPIRAL BAT (client)
--   Click / tap / R2  - swing (a 3-hit combo). Swing as a hit lands
--                       on you to PARRY it (the prompt shows when).
--   Q / ButtonB       - Spiral Dash: a burst of speed, brief i-frames
--   E / ButtonY       - Drill Break: hurl a spiral drill at his core
-- Also draws everyone's bat effects (trails, dashes, thrown drills)
-- and spins every Spiral Bat's drill tip.
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Bat = {}

local TOOL = "SpiralBat"
local GREEN = Color3.fromRGB(70, 255, 120)
local LIME = Color3.fromRGB(190, 255, 90)
local FONT = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)

local player = Players.LocalPlayer
local K, S, Fx, Warn, net, shared
local getChest -- () -> his chest position (from the rig)

local combo, lastSwing = 0, 0
local lastDash, lastDrill = -99, -99
local tracks = {}
local hud, slots = nil, {}
local active = false -- the fight is on

local function cfgAttr(name, default)
	local v = shared:GetAttribute(name)
	return type(v) == "number" and v or default
end

--------------------------------------------------------------------------
-- the ability bar (bottom centre)
--------------------------------------------------------------------------
local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpiralBatHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -18)
	bar.Size = UDim2.fromOffset(300, 78)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local ll = Instance.new("UIListLayout")
	ll.FillDirection = Enum.FillDirection.Horizontal
	ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ll.Padding = UDim.new(0, 12)
	ll.Parent = bar
	local defs = {
		{ Key = "Swing", Glyph = UIS.TouchEnabled and not UIS.KeyboardEnabled and "TAP" or "M1", Name = "SWING / PARRY" },
		{ Key = "Dash", Glyph = "Q", Name = "SPIRAL DASH" },
		{ Key = "Drill", Glyph = "E", Name = "DRILL BREAK" },
	}
	for i, d in ipairs(defs) do
		local f = Instance.new("Frame")
		f.Size = UDim2.fromOffset(88, 78)
		f.BackgroundColor3 = Color3.fromRGB(8, 22, 14)
		f.BackgroundTransparency = 0.15
		f.LayoutOrder = i
		f.Parent = bar
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = f
		local st = Instance.new("UIStroke") st.Color = GREEN st.Thickness = 2 st.Parent = f
		local g = Instance.new("TextLabel")
		g.BackgroundTransparency = 1
		g.Size = UDim2.new(1, 0, 0.55, 0)
		g.FontFace = FONT
		g.TextScaled = true
		g.Text = d.Glyph
		g.TextColor3 = Color3.new(1, 1, 1)
		g.Parent = f
		local gs = Instance.new("UIStroke") gs.Thickness = 2 gs.Parent = g
		local n = Instance.new("TextLabel")
		n.BackgroundTransparency = 1
		n.Position = UDim2.fromScale(0.05, 0.58)
		n.Size = UDim2.new(0.9, 0, 0.32, 0)
		n.FontFace = FONT
		n.TextScaled = true
		n.Text = d.Name
		n.TextColor3 = LIME
		n.Parent = f
		local cd = Instance.new("Frame")
		cd.Name = "Cooldown"
		cd.AnchorPoint = Vector2.new(0, 1)
		cd.Position = UDim2.fromScale(0, 1)
		cd.Size = UDim2.fromScale(1, 0)
		cd.BackgroundColor3 = Color3.new(0, 0, 0)
		cd.BackgroundTransparency = 0.35
		cd.Parent = f
		local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 10) cc.Parent = cd
		slots[d.Key] = { Frame = f, Stroke = st, Cooldown = cd }
	end
	hud = gui
end

local function flashSlot(key)
	local s = slots[key]
	if not s then return end
	s.Stroke.Color = Color3.new(1, 1, 1)
	TweenService:Create(s.Stroke, TweenInfo.new(0.3), { Color = GREEN }):Play()
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
-- actions
--------------------------------------------------------------------------
local function swing()
	if not active then return end
	local _, hum, root = myChar()
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
	flashSlot("Swing")
	if #ids > 0 then
		-- (instant feedback; the server's verdict follows)
		Fx.parryBurst(root.Position + root.CFrame.LookVector * 3, false)
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
	local cam = workspace.CurrentCamera
	cam.FieldOfView += 8
	K.sfx(K.S.Whoosh, 0.9, 0.9)
	K.sfx(K.S.Electric, 0.35, 1.5)
	flashSlot("Dash")
end

local function drill()
	if not active then return end
	if not (myChar() and equipped()) then return end
	local now = os.clock()
	if now - lastDrill < cfgAttr("DrillCooldown", 7) then return end
	lastDrill = now
	net.Bat:FireServer("drill")
	flashSlot("Drill")
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
	Fx.emitAt(root.Position, {
		Texture = "11381556016", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = ColorSequence.new(GREEN, LIME), Size = K.ns(0, 3, 1, 0), Lifetime = NumberRange.new(0.25, 0.5),
		Speed = NumberRange.new(8, 25), SpreadAngle = Vector2.new(180, 180), Brightness = 3, Rotation = NumberRange.new(0, 360),
	}, 22, 1.5)
	-- a green afterimage: a ghost of each limb, fading where you were
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" then
			local g = K.part({ Name = "Ghost", Size = p.Size, CFrame = p.CFrame, Material = Enum.Material.Neon, Color = GREEN, Transparency = 0.45 }, Fx.Folder)
			K.tween(g, 0.35, { Transparency = 1 })
			Debris:AddItem(g, 0.4)
		end
	end
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
	d.Size = Vector3.new(4, 8, 4)
	d.Material = Enum.Material.Neon
	d.Color = LIME
	d.CFrame = CFrame.new(from)
	d.Parent = Fx.Folder
	local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, -3, 0) a0.Parent = d
	local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, 3, 0) a1.Parent = d
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.35
	trail.LightEmission = 1
	trail.Brightness = 4
	trail.Color = ColorSequence.new(LIME, GREEN)
	trail.Texture = "rbxassetid://10365550877"
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = d
	K.emitter(d, {
		Texture = "1851669703", Color = ColorSequence.new(Color3.new(1, 1, 1), GREEN), Size = K.ns(0, 3, 1, 0),
		Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(4, 12), SpreadAngle = Vector2.new(180, 180), Rate = 60, Brightness = 4,
	})
	Fx.sound(K.S.Cannon, from, 0.9, 1.2, 600)
	task.spawn(function()
		local spin = 0
		while d.Parent do
			local now = S.now()
			local u = math.clamp((now - t0) / math.max(t1 - t0, 0.05), 0, 1)
			local to = getChest()
			local p = from:Lerp(to, u) + Vector3.new(0, math.sin(math.pi * u) * 40, 0)
			local ahead = from:Lerp(to, math.min(u + 0.02, 1)) + Vector3.new(0, math.sin(math.pi * math.min(u + 0.02, 1)) * 40, 0)
			spin += 0.6
			if (ahead - p).Magnitude > 0.01 then
				-- (the cone's tip is its +Y: point it along the flight, spinning)
				d.CFrame = CFrame.lookAt(p, ahead) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, spin, 0)
			end
			if u >= 1 then
				Fx.bolt(from:Lerp(to, 0.97), to, true)
				Fx.emitAt(to, {
					Texture = "11381556016", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
					Color = ColorSequence.new(GREEN, LIME), Size = K.ns(0, 30, 1, 0), Lifetime = NumberRange.new(0.4, 0.8),
					Speed = NumberRange.new(40, 120), SpreadAngle = Vector2.new(180, 180), Brightness = 4, Rotation = NumberRange.new(0, 360),
				}, 30, 2)
				break
			end
			RunService.RenderStepped:Wait()
		end
		d:Destroy()
	end)
end

--------------------------------------------------------------------------
-- setup
--------------------------------------------------------------------------
function Bat.init(ctx)
	K, S, Fx, Warn, net = ctx.K, ctx.S, ctx.Fx, ctx.Warn, ctx.Net
	shared = ReplicatedStorage:WaitForChild("BossFight")
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
	if player.Character then hookChar(player.Character) end
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
			if userId ~= player.UserId and char then
				trailOn(char:FindFirstChild(TOOL), 0.3)
			end
		elseif kind == "dash" then
			dashFx(char)
		elseif kind == "drill" and type(data) == "table" then
			drillFx(data)
		end
	end)

	-- spin every drill tip; keep the ability bar current
	RunService.RenderStepped:Connect(function(dt)
		for _, p in ipairs(Players:GetPlayers()) do
			local tool = p.Character and p.Character:FindFirstChild(TOOL)
			local drillPart = tool and tool:FindFirstChild("Drill")
			local w = drillPart and drillPart:FindFirstChild("DrillWeld")
			if w then
				local fast = (p == player and os.clock() - lastSwing < 0.4) and 4 or 1
				w.C0 = w.C0 * CFrame.Angles(0, dt * 9 * fast, 0)
			end
		end
		if hud then
			hud.Enabled = active and equipped() ~= nil
			if hud.Enabled then
				local now = os.clock()
				local function cd(key, last, total)
					local u = math.clamp(1 - (now - last) / total, 0, 1)
					slots[key].Cooldown.Size = UDim2.fromScale(1, u)
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
