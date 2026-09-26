--==================================================
-- YOUR MOVES (client)
--   CTRL / B / the ROLL button - a roll: a burst along the way
--                                you're moving, untouchable for
--                                a moment (the server's i-frames)
--   CLICK / R2 / the PUNCH button - while he's dazed and you're at
--                                his head: a spiral punch (left,
--                                right, left...) that hurts him
-- Everyone's rolls and punches play on every client.
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local M = {}

-- the roll: a burst that eases off (studs/s over ROLL_TIME)
local ROLL_TIME = 0.36
local ROLL_FAST, ROLL_SLOW = 105, 38

local player = Players.LocalPlayer
local K, S, Fx, CharAnim, Aura, net, shared, ctx
local lastRoll, lastPunch = -99, -99
local side = 1
local active = false
M.Weak = nil -- where his head is while he's dazed (the server's weak point)

local GREEN = Color3.fromRGB(70, 255, 120)
local LIME = Color3.fromRGB(190, 255, 90)

local function attr(name, default)
	local v = shared:GetAttribute(name)
	return type(v) == "number" and v or default
end

local function me()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then return nil end
	return c, hum, root
end

--------------------------------------------------------------------------
-- effects (for anyone's)
--------------------------------------------------------------------------
-- my own roll: white speed lines streak in from the edges of the screen
local linesGui
function M.speedLines()
	if not linesGui or not linesGui.Parent then
		linesGui = Instance.new("ScreenGui")
		linesGui.Name = "BF_SpeedLines"
		linesGui.IgnoreGuiInset = true
		linesGui.ResetOnSpawn = false
		linesGui.DisplayOrder = 5
		linesGui.Parent = player:WaitForChild("PlayerGui")
	end
	for _ = 1, 18 do
		local a = math.random() * 2 * math.pi
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = math.random() < 0.3 and GREEN or Color3.new(1, 1, 1)
		line.BackgroundTransparency = 0.35
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Rotation = math.deg(a)
		local r0 = 0.62 + math.random() * 0.15
		line.Position = UDim2.fromScale(0.5 + math.cos(a) * r0 * 0.6, 0.5 + math.sin(a) * r0)
		line.Size = UDim2.new(0, 60 + math.random() * 120, 0, 2 + math.random() * 2)
		line.Parent = linesGui
		local r1 = r0 + 0.25
		K.tween(line, 0.22 + math.random() * 0.1, {
			Position = UDim2.fromScale(0.5 + math.cos(a) * r1 * 0.6, 0.5 + math.sin(a) * r1), BackgroundTransparency = 1,
		})
		Debris:AddItem(line, 0.4)
	end
end

-- mine: the local player's own roll (its sound already played, 2D, on the press)
function M.rollFx(char, mine)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	CharAnim.play(char, CharAnim.Roll, 0.03)
	Aura.flare(char, 0.7)
	local dir = root.CFrame.LookVector
	local p = root.Position - Vector3.new(0, 2.5, 0)
	-- a sonic ring as you break away: two thin halos across your path, bursting open
	local ringHost = K.part({ Name = "RollRing", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(root.Position) }, Fx.Folder)
	for i, col in ipairs({ Color3.new(1, 1, 1), GREEN }) do
		local ring = K.softRing(ringHost, 24, 1, 1.6, { Brightness = 4, Alpha = 0 })
		for _, q in ipairs(ring.Q) do q.Color = ColorSequence.new(col) end
		local at = root.Position + dir * (1 + i)
		local t0 = os.clock() + (i - 1) * 0.05
		local c
		c = RunService.RenderStepped:Connect(function()
			local k = (os.clock() - t0) / 0.32
			if k < 0 then ring.setEnabled(false) return end
			if k >= 1 or not ringHost.Parent then c:Disconnect() ring.setEnabled(false) return end
			ring.setEnabled(true)
			local e = 1 - (1 - k) ^ 3
			local r = 1.5 + 8 * e
			ring.update(CFrame.lookAt(at - dir * 3 * e, at - dir * 3 * e + dir), r, r + 1.4 * (1 - k) + 0.2, 0)
			ring.setTransparency(0.1 + 0.9 * k)
		end)
	end
	Debris:AddItem(ringHost, 0.6)
	-- a kick of dust off the floor, and a flat shockwave where you pushed off
	Fx.emitAt(p, {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(210, 200, 230)), Size = K.ns(0, 2, 1, 7),
		Transparency = K.ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(6, 16),
		SpreadAngle = Vector2.new(90, 8), LightEmission = 0.2, Rotation = NumberRange.new(0, 360),
	}, 14, 1.2)
	Fx.emitAt(p + Vector3.new(0, 0.3, 0), {
		Texture = "1851669703", Color = ColorSequence.new(Color3.new(1, 1, 1), GREEN), Size = K.ns(0, 1, 1, 0),
		Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(25, 45), SpreadAngle = Vector2.new(90, 5), Brightness = 4,
	}, 10, 1)
	-- a green streak off your body while you roll
	local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or root
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.9, 0)
	a0.Parent = torso
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.9, 0)
	a1.Parent = torso
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.22
	tr.LightEmission = 1
	tr.Brightness = 3
	tr.FaceCamera = true
	tr.Color = ColorSequence.new(Color3.new(1, 1, 1), GREEN)
	tr.Transparency = K.ns(0, 0.2, 1, 1)
	tr.WidthScale = K.ns(0, 1, 1, 0.2)
	tr.Parent = torso
	task.delay(ROLL_TIME, function() tr.Enabled = false end)
	Debris:AddItem(tr, ROLL_TIME + 0.3)
	-- a ribbon of light along the floor where you rolled
	local f0 = Instance.new("Attachment")
	f0.Position = Vector3.new(-1.1, -2.9, 0)
	f0.Parent = root
	local f1 = Instance.new("Attachment")
	f1.Position = Vector3.new(1.1, -2.9, 0)
	f1.Parent = root
	local rib = Instance.new("Trail")
	rib.Attachment0, rib.Attachment1 = f0, f1
	rib.Lifetime = 0.45
	rib.LightEmission = 1
	rib.Brightness = 2
	rib.Color = ColorSequence.new(LIME, GREEN)
	rib.Transparency = K.ns(0, 0.35, 1, 1)
	rib.Texture = "rbxassetid://14582794847"
	rib.Parent = root
	task.delay(ROLL_TIME, function() rib.Enabled = false end)
	Debris:AddItem(rib, ROLL_TIME + 0.5)
	Debris:AddItem(f0, ROLL_TIME + 0.5)
	Debris:AddItem(f1, ROLL_TIME + 0.5)
	-- green sparks and spiral wisps shed off you mid-roll
	local sparks = K.emitter(torso, {
		Texture = "1851669703", Color = ColorSequence.new(Color3.new(1, 1, 1), GREEN), Size = K.ns(0, 0.9, 1, 0),
		Lifetime = NumberRange.new(0.25, 0.5), Speed = NumberRange.new(4, 12), SpreadAngle = Vector2.new(180, 180),
		Rate = 90, Brightness = 5, LightEmission = 1, Drag = 4,
	})
	local wisps = K.emitter(torso, {
		Texture = "14426232568", Color = ColorSequence.new(LIME, GREEN), Size = K.ns(0, 1.5, 1, 4),
		Transparency = K.ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(0, 2),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-600, 600), Rate = 40, LightEmission = 1,
	})
	task.delay(ROLL_TIME, function()
		sparks.Enabled = false
		wisps.Enabled = false
	end)
	Debris:AddItem(sparks, ROLL_TIME + 0.6)
	Debris:AddItem(wisps, ROLL_TIME + 0.6)
	Debris:AddItem(a0, ROLL_TIME + 0.3)
	Debris:AddItem(a1, ROLL_TIME + 0.3)
	-- afterimages strung out behind you
	for k = 0, 3 do
		task.delay(k * 0.055, function()
			for _, part in ipairs(char:GetChildren()) do
				if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "HumanoidRootPart" then
					local g = K.part({ Name = "Ghost", Size = part.Size, CFrame = part.CFrame, Material = Enum.Material.Neon, Color = k % 2 == 1 and LIME or GREEN, Transparency = 0.45 + k * 0.1 }, Fx.Folder)
					K.tween(g, 0.28, { Transparency = 1, Size = part.Size * 0.85 })
					Debris:AddItem(g, 0.32)
				end
			end
		end)
	end
	-- (a scuff as you come out of it)
	task.delay(ROLL_TIME - 0.05, function()
		if not root.Parent then return end
		Fx.sound(K.S.StepL, root.Position, 0.6, 1.2, 120)
		-- a puff of dust as you land out of it
		Fx.emitAt(root.Position - Vector3.new(0, 2.6, 0), {
			Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(215, 205, 235)), Size = K.ns(0, 1.5, 1, 5),
			Transparency = K.ns(0, 0.45, 1, 1), Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(5, 11),
			SpreadAngle = Vector2.new(90, 5), Rotation = NumberRange.new(0, 360), LightEmission = 0.2,
		}, 8, 1)
	end)
	if mine then M.speedLines() end
	if not mine then Fx.sound(K.S.Whoosh, root.Position, 0.7, 1.4, 150) end
end

function M.punchFx(char, at, left)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	CharAnim.play(char, left and CharAnim.Punch2 or CharAnim.Punch, 0.04)
	Aura.flare(char, 0.8)
	task.delay(0.12, function()
		local arm = char:FindFirstChild(left and "Left Arm" or "Right Arm")
		local fist = arm and (arm.CFrame * CFrame.new(0, -1.2, 0)).Position or root.Position
		-- a spiral drill of light off the fist, into him
		local hit = at or (fist + root.CFrame.LookVector * 6)
		Fx.emitAt(fist, {
			Texture = "11381556016", FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Color = ColorSequence.new(GREEN, LIME), Size = K.ns(0, 3, 1, 0), Lifetime = NumberRange.new(0.2, 0.4),
			Speed = NumberRange.new(20, 50), SpreadAngle = Vector2.new(25, 25), Brightness = 4, Rotation = NumberRange.new(0, 360),
		}, 14, 1)
		Fx.vfx("Punch-0" .. math.random(1, 3), hit, 1.6, nil, 2)
		Fx.vfx("Blood-Punch-01", hit, 0.6, 3, 2)
		local host = K.part({ Name = "PunchHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(fist) }, Fx.Folder)
		for i = 1, 2 do
			local b = K.ray(host, fist, hit, 1.6, 0.4, "10365550877", { Color = i == 1 and GREEN or LIME, Brightness = 5, Segments = 12, Mode = Enum.TextureMode.Wrap, Length = 4, Speed = 8 })
			b.CurveSize0, b.CurveSize1 = (i == 1 and 2 or -2), (i == 1 and -2 or 2)
		end
		Debris:AddItem(host, 0.18)
		Fx.sound(math.random() < 0.5 and K.S.Punch or K.S.Punch2, hit, 1, 0.9 + math.random() * 0.2, 400)
	end)
end

--------------------------------------------------------------------------
-- actions (mine)
--------------------------------------------------------------------------
-- the roll's sound, loaded up front: played 2D the moment you press
local rollSound
local function playRollSound()
	if not rollSound then return end
	local snd = rollSound:Clone()
	snd.Parent = SoundService
	snd:Play()
	Debris:AddItem(snd, 3)
end

local rolling
local function roll()
	if not active then return end
	local char, hum, root = me()
	if not char then return end
	local now = os.clock()
	if now - lastRoll < attr("RollCooldown", 1.1) then return end
	lastRoll = now
	-- (the sound and the server's i-frames first: nothing ahead of them)
	playRollSound()
	net.Action:FireServer("roll")
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then dir = root.CFrame.LookVector end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	if rolling then rolling() end
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * ROLL_FAST
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	hum.AutoRotate = false
	-- untouchable: a green flash for as long as the i-frames last
	local hl = Instance.new("Highlight")
	hl.FillColor = GREEN
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.FillTransparency = 0.55
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
	K.tween(hl, attr("RollIFrames", 0.4), { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(hl, attr("RollIFrames", 0.4) + 0.1)
	local t0 = os.clock()
	local conn
	local function stop()
		if conn then conn:Disconnect() conn = nil end
		lv:Destroy()
		att:Destroy()
		hum.AutoRotate = true
		if rolling == stop then rolling = nil end
	end
	rolling = stop
	conn = RunService.Heartbeat:Connect(function()
		local k = (os.clock() - t0) / ROLL_TIME
		if k >= 1 or not lv.Parent then stop() return end
		-- fast off the mark, easing out
		local v = ROLL_FAST + (ROLL_SLOW - ROLL_FAST) * (1 - (1 - k) ^ 2)
		lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * v
	end)
	M.rollFx(char, true)
	ctx.Cam.punch(10, 0.3)
	ctx.Cam.roll(dir:Dot(workspace.CurrentCamera.CFrame.RightVector) * -4, 0.3)
end

local function inReach()
	if not M.Weak then return false end
	local _, _, root = me()
	return root ~= nil and (S.flat(root.Position) - S.flat(M.Weak)).Magnitude <= attr("PunchRange", 30)
end

local function punch()
	if not active or not shared:GetAttribute("BossDazed") then return end
	local char, _, root = me()
	if not char then return end
	if not inReach() then
		ctx.Warn.pop("GET TO HIS HEAD!", Color3.fromRGB(255, 220, 120), false, Vector2.new(0.5, 0.74))
		return
	end
	local now = os.clock()
	if now - lastPunch < attr("PunchCooldown", 0.4) then return end
	lastPunch = now
	side = -side
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(M.Weak.X, root.Position.Y, M.Weak.Z))
	net.Action:FireServer("punch")
	M.punchFx(char, M.Weak + Vector3.new(0, 4, 0), side < 0)
	M.LastMine = os.clock()
	ctx.Cam.shake(0.8, 0.15)
	ctx.Cam.punch(-4, 0.15)
end

--------------------------------------------------------------------------
-- setup
--------------------------------------------------------------------------
function M.init(c)
	ctx = c
	K, S, Fx, CharAnim, Aura = c.K, c.S, c.Fx, c.CharAnim, c.Aura
	net = c.Net
	shared = ReplicatedStorage:WaitForChild("AntiSpiralFight")
	rollSound = Instance.new("Sound")
	rollSound.Name = "BF_RollWhoosh"
	rollSound.SoundId = "rbxassetid://" .. K.S.Whoosh
	rollSound.Volume = 0.8
	rollSound.PlaybackSpeed = 1.45
	rollSound.Parent = SoundService
	task.spawn(function() pcall(function() ContentProvider:PreloadAsync({ rollSound }) end) end)
	ContextActionService:BindAction("BF_Roll", function(_, state)
		if state == Enum.UserInputState.Begin then roll() end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.ButtonB)
	pcall(function()
		ContextActionService:SetTitle("BF_Roll", "ROLL")
		ContextActionService:SetPosition("BF_Roll", UDim2.new(1, -175, 1, -135))
	end)
	-- the punch: a click (anywhere) / R2 while he's dazed; a button on touch
	UIS.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			punch()
		end
	end)
	local punchBound = false
	RunService.Heartbeat:Connect(function()
		local want = active and UIS.TouchEnabled and shared:GetAttribute("BossDazed") == true
		if want and not punchBound then
			punchBound = true
			ContextActionService:BindAction("BF_Punch", function(_, state)
				if state == Enum.UserInputState.Begin then punch() end
				return Enum.ContextActionResult.Sink
			end, true)
			pcall(function()
				ContextActionService:SetTitle("BF_Punch", "PUNCH")
				ContextActionService:SetPosition("BF_Punch", UDim2.new(1, -100, 1, -205))
			end)
		elseif not want and punchBound then
			punchBound = false
			ContextActionService:UnbindAction("BF_Punch")
		end
	end)
end

function M.setActive(on) active = on end
function M.inReach() return inReach() end

return M
