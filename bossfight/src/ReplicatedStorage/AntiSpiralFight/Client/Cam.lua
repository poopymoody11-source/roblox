--==================================================
-- BOSS FIGHT: THE LOCK-ON CAMERA (client)
-- Sits behind you on the line from the Anti-Spiral through you,
-- and frames the two of you together: you low in the shot, him
-- towering over the rim behind. It follows him as he walks the
-- ring. Hold right mouse (or the right stick / drag on touch) to
-- swing it round; it eases back when you let go. C toggles it.
--==================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local C = {}

local player = Players.LocalPlayer
-- (far back and high, wide: he's hundreds of studs tall and the shot has to hold him and you)
local DIST = 42
local HEIGHT = 22
local FOV = 80

local enabled = false
local nowFn = os.clock
local function nowFnRef() return nowFn() end
-- (your own camera most of the time: the follow shot only for his big moments,
-- or always if you press C)
local wanted = false
local followUntil = 0
local function following()
	return wanted or nowFnRef() < followUntil
end
local focusFn -- () -> Vector3: the point on him to frame
local camPos, aimDir
local yawOff, pitchOff = 0, 0
local dragging = false
local shakes = {}

function C.shake(amp, dur)
	table.insert(shakes, { A = amp, D = dur, T0 = os.clock() })
end

-- a camera cut-in: from t0 to t1 (server time) the shot is fn(now) -> CFrame, fov,
-- whipping in and back out over `blend` seconds. The big attacks use these to show
-- the whole of what's coming.
local cuts = {}
function C.cut(fn, t0, t1, blend)
	table.insert(cuts, { Fn = fn, T0 = t0, T1 = t1, B = blend or 0.25 })
end
function C.clearCuts() table.clear(cuts) end

-- a kick of the camera's roll (degrees), easing back
local rolls = {}
function C.roll(deg, dur)
	table.insert(rolls, { A = math.rad(deg), D = dur or 0.4, T0 = os.clock() })
end
local function rollOffset()
	local now = os.clock()
	local off = 0
	for i = #rolls, 1, -1 do
		local r = rolls[i]
		local u = (now - r.T0) / r.D
		if u >= 1 then table.remove(rolls, i) else off += r.A * (1 - u) ^ 2 * math.cos(u * 9) end
	end
	return off
end

-- a punch of the field of view (negative = zoom in)
local punches = {}
function C.punch(amount, dur)
	table.insert(punches, { A = amount, D = dur or 0.3, T0 = os.clock() })
end
local function punchOffset()
	local now = os.clock()
	local off = 0
	for i = #punches, 1, -1 do
		local p = punches[i]
		local u = (now - p.T0) / p.D
		if u >= 1 then table.remove(punches, i) else off += p.A * (1 - u) ^ 2 end
	end
	return off
end

local function activeCut()
	local now = nowFn()
	for i = #cuts, 1, -1 do
		local c = cuts[i]
		if now > c.T1 then
			table.remove(cuts, i)
		elseif now >= c.T0 then
			local b = math.min((now - c.T0) / c.B, (c.T1 - now) / c.B, 1)
			b = b * b * (3 - 2 * b)
			return c, b, now
		end
	end
	return nil
end

local function shakeOffset()
	local now = os.clock()
	local off = Vector3.zero
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local u = (now - s.T0) / s.D
		if u >= 1 then
			table.remove(shakes, i)
		else
			local a = s.A * (1 - u) ^ 2 * 0.35
			off += Vector3.new(math.noise(now * 22, i, 0.3) * a, math.noise(now * 22, i, 1.7) * a, math.noise(now * 22, i, 3.1) * a)
		end
	end
	return off
end

-- where your own camera should be when it gets you back: behind you, level,
-- facing the way you were last looking (not wherever a cut-in left it)
local homeLook = Vector3.new(0, 0, -1)
local HOME_BACK, HOME_UP = 15, 5
local function homeCF(root)
	local head = root.Position + Vector3.new(0, 2, 0)
	return CFrame.lookAt(head - homeLook * HOME_BACK + Vector3.new(0, HOME_UP, 0), head)
end
local function setHomeLook(v)
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude > 0.05 then homeLook = flat.Unit end
end

-- the handback: a short blend from the last scripted shot to homeCF, then your camera
local HANDBACK = 0.35
local handFrom, handT0

local function giveBack(cam, hum, root)
	if root then cam.CFrame = homeCF(root) end
	cam.CameraType = Enum.CameraType.Custom
	if hum then cam.CameraSubject = hum end
	cam.FieldOfView = 70
	handFrom, handT0 = nil, nil
end

local function step(dt)
	local cam = workspace.CurrentCamera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local ours = cam.CameraType == Enum.CameraType.Scriptable
	-- (while it's yours, remember where you're looking)
	if not ours then setHomeLook(cam.CFrame.LookVector) end
	local cut, cb, cnow = activeCut()
	if cut and enabled then
		-- (a cut-in plays whatever the player's own camera setting)
		cam.CameraType = Enum.CameraType.Scriptable
		handFrom, handT0 = nil, nil
		local ok, cf, fov = pcall(cut.Fn, cnow)
		if ok and cf then
			-- (blend from, and back to, the follow shot, or where your own camera belongs)
			local base
			if following() and camPos then
				base = CFrame.lookAt(camPos, camPos + (aimDir or cf.LookVector))
			elseif root then
				base = homeCF(root)
			else
				base = cam.CFrame
			end
			local mixed = base:Lerp(cf, cb)
			cam.CFrame = mixed * CFrame.new(shakeOffset())
			cam.FieldOfView = FOV + ((fov or FOV) - FOV) * cb + punchOffset()
			return
		end
	end
	if not (enabled and following() and root and hum and hum.Health > 0 and focusFn) then
		if ours and enabled then
			if not root then
				giveBack(cam, hum, nil)
			else
				-- ease from the scripted shot to behind you, then let go
				if not handT0 then
					handFrom, handT0 = cam.CFrame, os.clock()
					setHomeLook(cam.CFrame.LookVector)
				end
				local k = (os.clock() - handT0) / HANDBACK
				if k >= 1 then
					giveBack(cam, hum, root)
				else
					local e = k * k * (3 - 2 * k)
					cam.CFrame = handFrom:Lerp(homeCF(root), e)
					cam.FieldOfView = cam.FieldOfView + (70 - cam.FieldOfView) * e
				end
			end
		end
		camPos = nil
		return
	end
	handFrom, handT0 = nil, nil
	cam.CameraType = Enum.CameraType.Scriptable
	local me = root.Position + Vector3.new(0, 1.5, 0)
	local boss = focusFn()
	local away = Vector3.new(me.X - boss.X, 0, me.Z - boss.Z)
	away = away.Magnitude > 1 and away.Unit or Vector3.xAxis
	-- (your own swing of the camera, easing home when you let go)
	if not dragging then
		yawOff *= math.exp(-dt * 2.2)
		pitchOff *= math.exp(-dt * 2.2)
	end
	local turned = CFrame.Angles(0, yawOff, 0):VectorToWorldSpace(away)
	local want = me + turned * DIST + Vector3.new(0, HEIGHT + pitchOff, 0)
	camPos = camPos and camPos:Lerp(want, 1 - math.exp(-dt * 9)) or want
	-- aim between you and him, leaning to him (you low in the frame, him filling the top)
	local toMe = (me - camPos).Unit
	local toBoss = (boss - camPos).Unit
	local aim = (toMe * 0.55 + toBoss).Unit
	aimDir = aimDir and aimDir:Lerp(aim, 1 - math.exp(-dt * 7)).Unit or aim
	local pos = camPos + shakeOffset()
	cam.CFrame = CFrame.lookAt(pos, pos + aimDir) * CFrame.Angles(0, 0, rollOffset())
	cam.FieldOfView = cam.FieldOfView + (FOV - cam.FieldOfView) * (1 - math.exp(-dt * 4)) + punchOffset() * 0.25
end

function C.start(fn, now)
	focusFn = fn
	nowFn = now or nowFn
	if enabled then return end
	enabled = true
	RunService:BindToRenderStep("BossFightCamera", Enum.RenderPriority.Camera.Value + 2, step)
	ContextActionService:BindAction("BossFightCamToggle", function(_, state)
		if state == Enum.UserInputState.Begin then
			-- (turning it off hands the camera back smoothly, in step)
			wanted = not wanted
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonR3)
end

function C.stop()
	if not enabled then return end
	enabled = false
	RunService:UnbindFromRenderStep("BossFightCamera")
	ContextActionService:UnbindAction("BossFightCamToggle")
	local cam = workspace.CurrentCamera
	if cam.CameraType == Enum.CameraType.Scriptable then
		local char = player.Character
		giveBack(cam, char and char:FindFirstChildOfClass("Humanoid"), char and char:FindFirstChild("HumanoidRootPart"))
	end
end

function C.active() return enabled and following() end

-- the follow shot until `untilT` (server time): pulled back, framing him and you
function C.follow(untilT)
	followUntil = math.max(followUntil, untilT)
end

-- swinging it round
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		dragging = true
		UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		dragging = false
		UIS.MouseBehavior = Enum.MouseBehavior.Default
	end
end)
UIS.InputChanged:Connect(function(input, processed)
	if not (enabled and following()) then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
		yawOff = math.clamp(yawOff - input.Delta.X * 0.006, -1.3, 1.3)
		pitchOff = math.clamp(pitchOff - input.Delta.Y * 0.05, -6, 14)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local v = input.Position
		dragging = v.Magnitude > 0.2
		if dragging then
			yawOff = math.clamp(yawOff - v.X * 0.05, -1.3, 1.3)
			pitchOff = math.clamp(pitchOff + v.Y * 0.4, -6, 14)
		end
	elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
		-- (a drag on the right half of the screen, away from the thumbstick)
		if input.Position.X > workspace.CurrentCamera.ViewportSize.X * 0.5 then
			dragging = true
			yawOff = math.clamp(yawOff - input.Delta.X * 0.008, -1.3, 1.3)
			pitchOff = math.clamp(pitchOff - input.Delta.Y * 0.06, -6, 14)
			task.delay(0.15, function() dragging = false end)
		end
	end
end)

return C
