--==================================================
-- BOSS FIGHT: WARNINGS + PARRY (client)
-- Every hit the server schedules is registered here. For the
-- ones aimed at you it draws the cutscene's lock-on: red target
-- brackets clamped round what's coming, its name, IMPACT 1.2
-- counting down, and a beep that quickens as it closes. Also the
-- attack callouts and the result pops. (The parry prompts are Qte's.)
--==================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local W = {}

local FONT = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)
local RED = Color3.fromRGB(255, 40, 55)
local GOOD = Color3.fromRGB(120, 255, 170)
local GOLD = Color3.fromRGB(255, 230, 120)
local BEEP = "rbxasset://sounds/electronicpingshort.wav"

local K, S
local player = Players.LocalPlayer
local gui, root
local hits = {}   -- [id] = hit
local order = {}  -- ids, oldest first
local lastBeep = 0

local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function stroke(p, color, th)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = th or 4
	s.Parent = p
	return s
end
local function grad(p, a, b, rot) local g = Instance.new("UIGradient") g.Color = ColorSequence.new(a, b) g.Rotation = rot or -90 g.Parent = p return g end
local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end
local function label(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do if k ~= "StrokeTh" then t[k] = v end end
	t.Parent = parent
	if (props.StrokeTh or 3) > 0 then stroke(t, Color3.new(0, 0, 0), props.StrokeTh or 3) end
	return t
end


function W.init(kit, shared)
	K, S = kit, shared
	gui = Instance.new("ScreenGui")
	gui.Name = "BossFightWarnings"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 520
	gui.Parent = player:WaitForChild("PlayerGui")
	root = frame(gui, { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	W.Gui = gui
end

--------------------------------------------------------------------------
-- pop text ("PARRY!", "PERFECT!", ...)
--------------------------------------------------------------------------
function W.pop(text, color, big, pos)
	pos = pos or Vector2.new(0.5, 0.6)
	local t = label(root, {
		Text = text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(pos.X, pos.Y), Size = UDim2.fromScale(big and 0.34 or 0.22, big and 0.085 or 0.058),
		TextColor3 = color, ZIndex = 66, StrokeTh = 4,
	})
	local sc = Instance.new("UIScale")
	sc.Scale = 0.4
	sc.Parent = t
	tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(t, 0.8, { Position = UDim2.fromScale(pos.X, pos.Y - 0.06) })
	task.delay(0.6, function()
		tween(t, 0.3, { TextTransparency = 1 })
		local s = t:FindFirstChildOfClass("UIStroke")
		if s then tween(s, 0.3, { Transparency = 1 }) end
		task.delay(0.35, function() t:Destroy() end)
	end)
end

--------------------------------------------------------------------------
-- the danger icon: a red warning that pulses in the middle of the screen
-- while something is about to land where you stand (MOVE! / JUMP! / ROLL!)
--------------------------------------------------------------------------
local danger
local function buildDanger()
	local f = frame(root, { Name = "Danger", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromScale(0.09, 0.09), BackgroundColor3 = Color3.new(1, 1, 1), Rotation = 45, Visible = false, ZIndex = 55 })
	local ar = Instance.new("UIAspectRatioConstraint") ar.AspectRatio = 1 ar.DominantAxis = Enum.DominantAxis.Height ar.Parent = f
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.18, 0) c.Parent = f
	stroke(f, Color3.new(0, 0, 0), 5)
	grad(f, Color3.fromRGB(140, 0, 20), RED)
	local bang = label(f, { Text = "!", Rotation = -45, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), ZIndex = 56, StrokeTh = 4 })
	local word = label(root, { Name = "DangerWord", Text = "MOVE!", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(0.18, 0.05), TextColor3 = Color3.fromRGB(255, 90, 100), Visible = false, ZIndex = 56, StrokeTh = 4 })
	local sc = Instance.new("UIScale") sc.Parent = f
	return { F = f, Bang = bang, Word = word, Scale = sc }
end

--------------------------------------------------------------------------
-- an attack's name, slammed in under the boss bar (glitching in, like his name)
--------------------------------------------------------------------------
function W.callout(text)
	local holder = frame(root, { Name = "Callout", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.21), Size = UDim2.fromScale(0.5, 0.06), BackgroundTransparency = 1, ZIndex = 70 })
	local t = label(holder, { Text = "", Size = UDim2.fromScale(1, 1), TextColor3 = Color3.new(1, 1, 1), ZIndex = 71, StrokeTh = 4 })
	grad(t, Color3.fromRGB(255, 150, 235), Color3.fromRGB(165, 85, 255), 0)
	local sc = Instance.new("UIScale")
	sc.Scale = 1.6
	sc.Parent = holder
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	local chars = "!<>-_/[]{}=+*^?#%01XZ"
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.35 do
			local k = math.floor(#text * (os.clock() - t0) / 0.35)
			local out = text:sub(1, k)
			for i = k + 1, #text do
				local r = math.random(1, #chars)
				out ..= text:sub(i, i) == " " and " " or chars:sub(r, r)
			end
			t.Text = out
			task.wait()
		end
		t.Text = text
		task.wait(1.3)
		tween(t, 0.35, { TextTransparency = 1 })
		local st = t:FindFirstChildOfClass("UIStroke")
		if st then tween(st, 0.35, { Transparency = 1 }) end
		task.wait(0.4)
		holder:Destroy()
	end)
	K.sfx(K.S.CutIn, 0.5, 1.2)
end

--------------------------------------------------------------------------
-- the lock-on (the cutscene's dodge warning)
--------------------------------------------------------------------------
local function makeLock(name)
	local h = frame(root, { Name = "Lock", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(200, 200), BackgroundTransparency = 1, ZIndex = 57 })
	local bits = {}
	for i = 0, 3 do
		local cx, cy = i % 2, math.floor(i / 2)
		local cf = frame(h, { AnchorPoint = Vector2.new(cx, cy), Position = UDim2.fromScale(cx, cy), Size = UDim2.fromScale(0.28, 0.28), BackgroundTransparency = 1, ZIndex = 57 })
		local hb = frame(cf, { AnchorPoint = Vector2.new(cx, cy), Position = UDim2.fromScale(cx, cy), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = RED, ZIndex = 57 })
		local vb = frame(cf, { AnchorPoint = Vector2.new(cx, cy), Position = UDim2.fromScale(cx, cy), Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = RED, ZIndex = 57 })
		stroke(hb, Color3.new(0, 0, 0), 1.5)
		stroke(vb, Color3.new(0, 0, 0), 1.5)
		table.insert(bits, hb)
		table.insert(bits, vb)
	end
	for i = 0, 3 do
		local horiz = i < 2
		local at = ({ UDim2.fromScale(0, 0.5), UDim2.fromScale(1, 0.5), UDim2.fromScale(0.5, 0), UDim2.fromScale(0.5, 1) })[i + 1]
		local tk = frame(h, { AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = horiz and UDim2.fromOffset(16, 3) or UDim2.fromOffset(3, 16), BackgroundColor3 = RED, ZIndex = 57 })
		stroke(tk, Color3.new(0, 0, 0), 1)
		table.insert(bits, tk)
	end
	local dot = frame(h, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(11, 11), Rotation = 45, BackgroundColor3 = RED, ZIndex = 57 })
	stroke(dot, Color3.new(0, 0, 0), 1.5)
	table.insert(bits, dot)
	local tag = label(h, { Text = "! " .. name .. " !", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.fromOffset(260, 26), TextColor3 = RED, ZIndex = 58, StrokeTh = 2.5 })
	local eta = label(h, { Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8), Size = UDim2.fromOffset(170, 22), TextColor3 = Color3.fromRGB(255, 205, 205), ZIndex = 58, StrokeTh = 2 })
	return { H = h, Bits = bits, Tag = tag, Eta = eta }
end

local function endLock(h, good, text)
	local L = h.Lock
	if not L or L.Ending then return end
	L.Ending = true
	local col = good and GOOD or RED
	for _, b in ipairs(L.Bits) do b.BackgroundColor3 = col end
	L.Tag.TextColor3 = col
	L.Eta.Text = text or (good and "EVADED" or "IMPACT")
	L.Eta.TextColor3 = col
	local sz = L.H.Size
	tween(L.H, 0.35, { Size = UDim2.fromOffset(sz.X.Offset * (good and 1.5 or 0.7), sz.Y.Offset * (good and 1.5 or 0.7)) })
	task.delay(0.15, function()
		for _, d in ipairs(L.H:GetDescendants()) do
			if d:IsA("Frame") then tween(d, 0.3, { BackgroundTransparency = 1 })
			elseif d:IsA("TextLabel") then tween(d, 0.3, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then tween(d, 0.3, { Transparency = 1 }) end
		end
		task.delay(0.35, function() L.H:Destroy() end)
	end)
end

local function lockUpdate(h, now, T, cam, vs, wp, rad)
	local L = h.Lock
	if L.Ending then return end
	if not wp then L.H.Visible = false return end
	local v = cam:WorldToViewportPoint(wp)
	if v.Z <= 0 then L.H.Visible = false return end
	L.H.Visible = true
	local tanh = math.tan(math.rad(cam.FieldOfView) / 2)
	local sr = ((rad or 10) / (v.Z * tanh)) * vs.Y / 2
	local want = math.clamp(sr * 2.3, 80, vs.Y * 0.6)
	local k = 1 + 1.6 * (1 - smooth((now - h.LockT) / 0.35))
	L.H.Size = UDim2.fromOffset(want * k, want * k)
	L.H.Position = UDim2.fromOffset(math.clamp(v.X, 60, vs.X - 60), math.clamp(v.Y, 70, vs.Y - 70))
	local rem = math.max(T - now, 0)
	L.Eta.Text = string.format("IMPACT  %.1f", rem)
	local blink = rem < 0.9 and math.floor(os.clock() * (rem < 0.45 and 16 or 9)) % 2 == 0
	local col = blink and Color3.new(1, 1, 1) or RED
	if col ~= L.Col then
		L.Col = col
		for _, b in ipairs(L.Bits) do b.BackgroundColor3 = col end
	end
end

--------------------------------------------------------------------------
-- hits
--------------------------------------------------------------------------
local function me()
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (r and hum and hum.Health > 0) then return nil end
	return r.Position
end

local function impactT(h, pos)
	if h.Shape.Kind == "ring" then return S.ringArrival(h.Shape, pos) end
	if h.Shape.Kind == "sweep" then return S.sweepArrival(h.Shape, pos) end
	return h.T
end

-- would it catch me where I stand? (rings: if I don't jump)
local function inPath(h, pos, T)
	if h.Shape.Kind == "ring" then return S.onArena(pos, -5) end
	if h.Shape.Kind == "sweep" then
		return T >= h.Shape.T0 - 0.05 and T <= h.Shape.T1 + 0.05 and S.onArena(pos, -5)
	end
	return S.inside(h.Shape, pos, T, 0)
end

-- h: { Id, T, Shape, Name, Target (userId), Pos = function(now) -> Vector3 (optional), Rad (optional), Parry (default true) }
function W.add(h)
	local old = hits[h.Id]
	if old then
		-- (the attack's visuals add where its threat is drawn)
		old.Pos = old.Pos or h.Pos
		old.Rad = old.Rad or h.Rad
		return
	end
	hits[h.Id] = h
	table.insert(order, h.Id)
end

function W.cancelAll()
	for id, h in pairs(hits) do
		if h.Lock then endLock(h, true, "") end
		hits[id] = nil
	end
	table.clear(order)
end

-- the server's verdict on a hit that caught (or would have caught) you
function W.result(id, result)
	local h = hits[id]
	if h then
		h.Result = result
		if h.Lock then endLock(h, result ~= "hit", result == "hit" and "IMPACT" or (result == "evade" and "EVADED" or "PARRIED")) end
	end
	if result == "perfect" then
		W.pop("PERFECT PARRY!", GOLD, true)
	elseif result == "parry" then
		W.pop("PARRY!", GOOD, true)
	elseif result == "evade" then
		W.pop("EVADED", Color3.fromRGB(170, 220, 255), false)
	elseif result == "hit" then
		K.vignette(0.5, Color3.fromRGB(180, 0, 30), 0.08)
		task.delay(0.25, function() K.vignette(0, nil, 0.6) end)
	end
end

function W.update(now)
	local cam = workspace.CurrentCamera
	local vs = cam.ViewportSize
	local pos = me()
	local soonest, soonestT
	local myId = player.UserId
	local dangerT, dangerWord
	for i = #order, 1, -1 do
		local id = order[i]
		local h = hits[id]
		local T = pos and impactT(h, pos) or h.T or now
		local over = (h.Shape.Kind == "ring" and now > h.Shape.T0 + 12) or (h.Shape.Kind == "sweep" and now > h.Shape.T1 + 2)
		if over or (h.T and now > h.T + 2.5) then
			if h.Lock then endLock(h, true, "") end
			hits[id] = nil
			table.remove(order, i)
		else
			-- the red icon: anything about to land where I stand (the QTE ones prompt instead)
			if pos and not h.Result and not h.Qte and inPath(h, pos, T) and T - now <= 1.3 and T - now >= -0.05 then
				if not dangerT or T < dangerT then
					dangerT = T
					dangerWord = h.Shape.Kind == "ring" and "JUMP!" or h.Shape.Kind == "sweep" and "ROLL!" or "MOVE!"
				end
			end
			-- the lock-on: the big ones, aimed at me
			if h.Big and (h.Target == myId or h.Target == "all") and pos then
				if not h.Lock and not h.Result and now >= T - S.WARN_LOCK and now < T then
					h.Lock = makeLock(h.Name or "INCOMING")
					h.LockT = now
					K.sfx(BEEP, 0.4, 0.8)
				end
				if h.Lock and not h.Lock.Ending then
					if h.Result or now >= T then
						endLock(h, h.Result ~= nil and h.Result ~= "hit" or not inPath(h, pos, T))
					else
						local wp = h.Pos and h.Pos(now) or S.shapeCentre(h.Shape, now)
						lockUpdate(h, now, T, cam, vs, wp, h.Rad or 12)
						if not soonestT or T < soonestT then soonest, soonestT = h, T end
					end
				end
			end
		end
	end
	danger = danger or buildDanger()
	local on = dangerT ~= nil
	danger.F.Visible = on
	danger.Word.Visible = on
	if on then
		local rem = math.max(dangerT - now, 0)
		local beat = 0.5 + 0.5 * math.sin(os.clock() * (10 + 20 * (1 - rem / 1.3)))
		danger.Scale.Scale = 1 + 0.18 * beat
		danger.Word.Text = dangerWord
		danger.Word.TextColor3 = Color3.fromRGB(255, 90, 100):Lerp(Color3.new(1, 1, 1), beat * 0.5)
		if os.clock() - lastBeep >= 0.12 + 0.3 * (rem / 1.3) then
			lastBeep = os.clock()
			K.sfx(BEEP, 0.3, 1.9)
		end
	end
	-- the beep: faster and higher as the nearest lock closes
	if soonest then
		local rem = math.max(soonestT - now, 0)
		local u = math.clamp(rem / S.WARN_LOCK, 0, 1)
		local gap = 0.07 + 0.43 * u
		if os.clock() - lastBeep >= gap then
			lastBeep = os.clock()
			K.sfx(BEEP, 0.26 + 0.2 * (1 - u), 1.35 + 0.8 * (1 - u))
		end
	end
end

return W
