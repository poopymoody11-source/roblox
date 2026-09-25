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
local Debris = game:GetService("Debris")

local M = {}

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
function M.rollFx(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	CharAnim.play(char, CharAnim.Roll, 0.04)
	local p = root.Position - Vector3.new(0, 2.5, 0)
	Fx.emitAt(p, {
		Texture = "10180479311", Color = ColorSequence.new(Color3.fromRGB(200, 190, 220)), Size = K.ns(0, 2, 1, 6),
		Transparency = K.ns(0, 0.4, 1, 1), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(4, 10),
		SpreadAngle = Vector2.new(80, 10), LightEmission = 0.2, Rotation = NumberRange.new(0, 360),
	}, 10, 1.2)
	-- a green afterimage streak behind you
	for k = 0, 2 do
		task.delay(k * 0.06, function()
			for _, part in ipairs(char:GetChildren()) do
				if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "HumanoidRootPart" then
					local g = K.part({ Name = "Ghost", Size = part.Size, CFrame = part.CFrame, Material = Enum.Material.Neon, Color = k == 1 and LIME or GREEN, Transparency = 0.5 + k * 0.12 }, Fx.Folder)
					K.tween(g, 0.3, { Transparency = 1 })
					Debris:AddItem(g, 0.35)
				end
			end
		end)
	end
	Fx.sound(K.S.Whoosh, root.Position, 0.7, 1.4, 150)
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
local function roll()
	if not active then return end
	local char, hum, root = me()
	if not char then return end
	local now = os.clock()
	if now - lastRoll < attr("RollCooldown", 1.1) then return end
	lastRoll = now
	net.Action:FireServer("roll")
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then dir = root.CFrame.LookVector end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * 62
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	Debris:AddItem(lv, 0.34)
	Debris:AddItem(att, 0.34)
	M.rollFx(char)
	ctx.Cam.punch(6, 0.25)
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
