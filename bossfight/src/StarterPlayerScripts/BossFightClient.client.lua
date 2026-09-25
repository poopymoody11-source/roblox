--==================================================
-- BOSS FIGHT (client entry)
-- Once the cutscene hands over (player attribute CutsceneDone),
-- brings the Anti-Spiral to life (walk plan -> procedural rig),
-- lays the galaxy road under him, takes the lock-on camera, and
-- runs every attack's visuals as the server announces them.
-- Code: ReplicatedStorage.AntiSpiralFight
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local shared = ReplicatedStorage:WaitForChild("AntiSpiralFight")
local S = require(shared:WaitForChild("Shared"))
local client = shared:WaitForChild("Client")
local net = shared:WaitForChild(S.NET)
local Net = { Fx = net:WaitForChild("Fx"), Bat = net:WaitForChild("Bat"), BatFx = net:WaitForChild("BatFx") }

local FC = ReplicatedStorage:WaitForChild("FinalCutscene")
local K = require(FC:WaitForChild("Client"):WaitForChild("Kit"))
local SK = require(FC.Client:WaitForChild("SpiralKit"))

local Rig = require(client:WaitForChild("Rig"))
local Fx = require(client:WaitForChild("Fx"))
local Warn = require(client:WaitForChild("Warn"))
local Cam = require(client:WaitForChild("Cam"))
local Bat = require(client:WaitForChild("Bat"))
local attacks = {}
for _, m in ipairs(client:WaitForChild("Attacks"):GetChildren()) do
	if m:IsA("ModuleScript") then attacks[m.Name] = require(m) end
end

Fx.init(K, SK, S)
Warn.init(K, S)
Fx.onShake(Cam.shake)

--------------------------------------------------------------------------
-- HIM: the fight is drawn on our own copy of the Anti-Spiral (the cutscene's,
-- which every client always has). The real one in workspace may not have
-- streamed in to us at all - and when it does, it's hidden.
--------------------------------------------------------------------------
local src = FC:WaitForChild("Assets"):WaitForChild("AntiSpiral")
local model = src:Clone()
model.Name = "AntiSpiral_Fight"
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
		d.Anchored = d.Name == "HumanoidRootPart"
	elseif d:IsA("Script") or d:IsA("LocalScript") then
		d:Destroy()
	end
end
local hb = model:FindFirstChild("Hitbox")
if hb then hb:Destroy() end
local hum = model:FindFirstChildOfClass("Humanoid")
if hum then
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.PlatformStand = true
end

local hidden = {}
local function hideReal(inst)
	if inst:IsA("BasePart") then
		inst.LocalTransparencyModifier = 1
		hidden[inst] = true
	elseif inst:IsA("Highlight") or inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Light") then
		inst.Enabled = false
	end
end
local function watchReal()
	local bf = workspace:WaitForChild("BossFight")
	local function hook(real)
		if real.Name ~= "Anti-Spiral" or not real:IsA("Model") then return end
		local hh = real:FindFirstChildOfClass("Humanoid")
		if hh then hh.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
		for _, d in ipairs(real:GetDescendants()) do hideReal(d) end
		real.DescendantAdded:Connect(hideReal)
		-- (the stone he took in the cutscene is welded to his chest: bring it across)
		task.spawn(function()
			local gem = real:WaitForChild("StolenLapeace", 30)
			local torso = model:FindFirstChild("UpperTorso")
			local realTorso = real:FindFirstChild("UpperTorso")
			if gem and torso and realTorso and gem:IsA("Model") then
				local rel = realTorso.CFrame:ToObjectSpace(gem:GetPivot())
				local copy = gem:Clone()
				for _, d in ipairs(copy:GetDescendants()) do
					if d:IsA("WeldConstraint") or d:IsA("Weld") then d:Destroy() end
				end
				copy:PivotTo(torso.CFrame * rel)
				for _, d in ipairs(copy:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored, d.Massless, d.LocalTransparencyModifier = false, true, 0
						local w = Instance.new("WeldConstraint")
						w.Part0, w.Part1 = d, torso
						w.Parent = d
					end
				end
				copy.Parent = model
				for _, d in ipairs(gem:GetDescendants()) do hideReal(d) end
			end
		end)
	end
	for _, c in ipairs(bf:GetChildren()) do hook(c) end
	bf.ChildAdded:Connect(hook)
end
task.spawn(watchReal)
-- (the cutscene un-hides the real one as it hands over: keep it hidden)
RunService.Heartbeat:Connect(function()
	for p in pairs(hidden) do
		if p.Parent then p.LocalTransparencyModifier = 1 else hidden[p] = nil end
	end
end)

--------------------------------------------------------------------------
-- a stand-in for the boss HUD: a local Humanoid that mirrors his health
--------------------------------------------------------------------------
do
	local proxy = Instance.new("Model")
	proxy.Name = "AntiSpiralHUDProxy"
	local ph = Instance.new("Humanoid")
	ph.Parent = proxy
	proxy.Parent = ReplicatedStorage
	local function sync()
		local max = shared:GetAttribute("BossMaxHealth")
		if type(max) == "number" and max > 0 then
			ph.MaxHealth = max
			ph.Health = shared:GetAttribute("BossHealth") or max
		end
		for _, k in ipairs({ "DisplayName", "Phase", "Invulnerable", "Defeated" }) do
			proxy:SetAttribute(k, shared:GetAttribute("Boss" .. k))
		end
	end
	shared.AttributeChanged:Connect(sync)
	sync()
	game:GetService("CollectionService"):AddTag(proxy, "Boss")
end

--------------------------------------------------------------------------
-- context handed to every attack
--------------------------------------------------------------------------
local epoch = 0 -- (bumped on a phase change / his death: running visuals stop)
local rig, road

local ctx = { K = K, SK = SK, S = S, Fx = Fx, Warn = Warn, Cam = Cam, Net = Net, player = player }
function ctx.epoch() return epoch end
function ctx.chest()
	local ut = model:FindFirstChild("UpperTorso")
	return ut and ut.Position or model:GetPivot().Position
end

Bat.init(ctx)

--------------------------------------------------------------------------
-- feedback on him
--------------------------------------------------------------------------
local function damageNumber(amount, source)
	local at = ctx.chest() + Vector3.new(math.random(-40, 40), math.random(-20, 40), 0)
	local host = K.part({ Name = "Dmg", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(at) }, Fx.Folder)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 60)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = host
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)
	t.TextScaled = true
	t.Text = tostring(math.floor(amount + 0.5))
	t.TextColor3 = source == "parry" and Color3.fromRGB(140, 255, 170) or source == "drill" and Color3.fromRGB(200, 255, 110) or Color3.new(1, 1, 1)
	t.Parent = bb
	local st = Instance.new("UIStroke") st.Thickness = 3 st.Parent = t
	K.tween(host, 0.9, { CFrame = host.CFrame + Vector3.new(0, 30, 0) })
	task.delay(0.5, function()
		K.tween(t, 0.4, { TextTransparency = 1 })
		K.tween(st, 0.4, { Transparency = 1 })
	end)
	Debris:AddItem(host, 1)
end

local function hurtFlash()
	local hl = model:FindFirstChildOfClass("Highlight")
	if not hl then return end
	hl.FillColor = Color3.fromRGB(140, 255, 170)
	hl.FillTransparency = 0.55
	K.tween(hl, 0.25, { FillTransparency = 0.99 })
end

local ROAR = {
	Waist = { 16, 0, 0 }, RightShoulder = { 35, 0, 65 }, LeftShoulder = { 35, 0, -65 },
	RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 },
}

local function roar(t0, dur)
	if not rig then return end
	rig:act({
		Until = t0 + dur,
		Root = function(t)
			local u = K.k(t, t0, t0 + 0.6) * (1 - K.k(t, t0 + dur - 0.6, t0 + dur))
			return CFrame.Angles(math.rad(6 * u), 0, 0)
		end,
		Upper = function(t)
			local u = K.k(t, t0, t0 + 0.6, K.E.outBack) * (1 - K.k(t, t0 + dur - 0.6, t0 + dur))
			rig:pose(Rig.REST, ROAR, u)
			SK.hang(rig.SB, "Right", 0.95, 0.3)
			SK.hang(rig.SB, "Left", 0.95, 0.3)
			rig.SB.lookAt(rig.RootCF.Position + Vector3.new(0, 900, 0) + rig.RootCF.LookVector * 300, 0.9 * u, rig.RootCF)
			return true
		end,
	})
	K.sfx(K.S.Hell, 1, 0.7)
	K.sfx(K.S.DarkDrone, 0.9, 0.8)
	Cam.shake(3, dur * 0.7)
	K.flash(0.5, Color3.fromRGB(170, 90, 255), 0.5)
end

local function collapse(t0)
	if not rig then return end
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end
	rig:act({
		Root = function(t)
			local u = K.k(t, t0, t0 + 3.5, K.E.inCubic)
			return CFrame.new(0, -420 * u, 0) * CFrame.Angles(math.rad(-25 * K.k(t, t0, t0 + 1.2)), 0, math.rad(8 * u))
		end,
		Upper = function(t)
			local u = K.k(t, t0, t0 + 1.2)
			rig:pose(ROAR, { Waist = { -35, 0, 0 }, RightShoulder = { 10, 0, 5 }, LeftShoulder = { 10, 0, -5 }, RightElbow = { 5, 0, 0 }, LeftElbow = { 5, 0, 0 } }, u)
			SK.hang(rig.SB, "Right", 0.3, 0.2)
			SK.hang(rig.SB, "Left", 0.3, 0.2)
			local fade = K.k(t, t0 + 1.5, t0 + 4)
			for _, p in ipairs(parts) do p.LocalTransparencyModifier = fade end
			return true
		end,
	})
	K.sfx(K.S.Hell, 1, 0.55)
	K.sfx(K.S.Boom, 1, 0.5)
	K.flash(1.2, Color3.new(1, 1, 1), 0.8)
	Cam.shake(4, 2.5)
	task.spawn(function()
		for _ = 1, 10 do
			Fx.emitAt(ctx.chest() + Vector3.new(math.random(-120, 120), math.random(-150, 150), math.random(-80, 80)), {
				Texture = "1851669703", Color = ColorSequence.new(Color3.new(1, 1, 1), Fx.VIOLET), Size = K.ns(0, 40, 1, 0),
				Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(60, 200), SpreadAngle = Vector2.new(180, 180), Brightness = 5,
			}, 25, 2)
			task.wait(0.3)
		end
	end)
end

--------------------------------------------------------------------------
-- server events
--------------------------------------------------------------------------
local handlers = {}

handlers.Start = function(d)
	roar(d.T0, 2.2)
end

handlers.GalaxyBarrage = function(d) attacks.GalaxyBarrage.start(ctx, d) end
handlers.Shot = function(d) attacks.GalaxyBarrage.shot(ctx, d) end
handlers.FistSlam = function(d) attacks.FistSlam.start(ctx, d) end
handlers.StompQuake = function(d) attacks.StompQuake.start(ctx, d) end
handlers.ConstellationLances = function(d) attacks.ConstellationLances.start(ctx, d) end
handlers.FistHammer = function(d) attacks.FistSlam.hammer(ctx, d) end
handlers.AnnihilationBeam = function(d) attacks.AnnihilationBeam.start(ctx, d) end
handlers.SpiralCollapse = function(d) attacks.SpiralCollapse.start(ctx, d) end

handlers.Resolve = function(d)
	if d.User == player.UserId then Warn.result(d.Id, d.Result) end
	if d.Result == "parry" or d.Result == "perfect" then
		local perfect = d.Result == "perfect"
		if d.User ~= player.UserId then Fx.parryBurst(d.Pos, perfect) end
		Fx.bolt(d.Pos + Vector3.new(0, 2, 0), ctx.chest(), perfect)
		if perfect and d.User == player.UserId then
			K.flash(0.25, Color3.fromRGB(255, 255, 190), 0.35)
			Bat.impactFrame(true)
		end
	end
end

handlers.BossHurt = function(d)
	hurtFlash()
	damageNumber(d.Amount, d.Source)
end

handlers.Phase = function(d)
	epoch += 1
	Warn.cancelAll()
	roar(d.T0, d.Dur)
end

handlers.Defeated = function(d)
	epoch += 1
	Warn.cancelAll()
	Bat.setActive(false)
	collapse(d.T0)
end

-- (events that arrive before the fight is set up on this client wait for it)
local ready = false
local queue = {}
Net.Fx.OnClientEvent:Connect(function(kind, data)
	if not ready then
		table.insert(queue, { kind, data })
		return
	end
	local h = handlers[kind]
	if h then
		local ok, err = pcall(h, data)
		if not ok then warn("[BossFight] " .. tostring(kind) .. ": " .. tostring(err)) end
	end
end)

--------------------------------------------------------------------------
-- start
--------------------------------------------------------------------------
local function plan()
	return S.decodePlan(shared:GetAttribute("BossMotion"))
end

local function begin()
	if ready then return end
	print("[BossFight] client: the fight is on")
	model.Parent = workspace
	rig = Rig.new(K, SK, S, model)
	ctx.Rig = rig
	rig:setPlan(plan())
	shared:GetAttributeChangedSignal("BossMotion"):Connect(function()
		local p = plan()
		if p then rig:setPlan(p) end
	end)
	road = Fx.road(rig.Floor)
	rig.OnStep = function(_, pos, power) Fx.stomp(pos, power) end
	RunService:BindToRenderStep("BossFightRig", Enum.RenderPriority.Camera.Value, function()
		local now = S.now()
		local c = player.Character
		local head = c and c:FindFirstChild("Head")
		rig.Focus = head and head.Position or S.CENTER
		local ok, err = pcall(rig.update, rig, now)
		if not ok then warn("[BossFight] rig: " .. tostring(err)) end
		Fx.updateStomps()
		road.update(now)
		Warn.update(now)
	end)
	Cam.start(ctx.chest)
	Bat.setActive(not shared:GetAttribute("BossDefeated"))
	ready = true
	-- (late: anything announced while we were getting ready)
	for _, q in ipairs(queue) do
		local h = handlers[q[1]]
		if h and q[1] ~= "Start" then pcall(h, q[2]) end
	end
	table.clear(queue)
end

local function check()
	if workspace:GetAttribute("FC_State") == "Fight" and player:GetAttribute("CutsceneDone") == true then
		begin()
	end
end
player:GetAttributeChangedSignal("CutsceneDone"):Connect(check)
workspace:GetAttributeChangedSignal("FC_State"):Connect(check)
check()
