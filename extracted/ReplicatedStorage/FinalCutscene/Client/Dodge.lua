--==================================================
-- DODGE: the WASD quick-time dodge in the DRAG dive
--
-- Every obstacle in the dive (ChSolar's CRASH list: the Moon, meteors, a
-- comet, Mars, Jupiter, Saturn's rings) gets a prompt over it: a key in a
-- circle, and a ring closing in on it. Press the key as the ring meets the
-- circle and you dodge: the diver swerves and the obstacle is thrown aside.
-- Miss, and you smash straight through it. Take MAX_HITS hits and you're
-- sent back to BECOME LA PEACE.
--
-- Keyboard WASD / arrows, gamepad D-pad, and on-screen arrows on touch.
-- Everything here is local to the player: each player dodges for themselves.
--==================================================
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local D = {}
D.MAX_HITS = 3
D.LEAD = 1.25      -- the prompt appears this long before impact
D.JUDGE = 0.3      -- the ring meets the circle this long before impact
D.WINDOW = 0.22    -- +/- seconds that still count as a dodge
D.PERFECT = 0.08

local DIRS = { W = Vector2.new(0, 1), A = Vector2.new(-1, 0), S = Vector2.new(0, -1), D = Vector2.new(1, 0) }
local ARROWS = { W = "▲", A = "◀", S = "▼", D = "▶" }
local ORDER = { "W", "A", "S", "D" }
local KEYMAP = {
	[Enum.KeyCode.W] = "W", [Enum.KeyCode.Up] = "W", [Enum.KeyCode.DPadUp] = "W",
	[Enum.KeyCode.A] = "A", [Enum.KeyCode.Left] = "A", [Enum.KeyCode.DPadLeft] = "A",
	[Enum.KeyCode.S] = "S", [Enum.KeyCode.Down] = "S", [Enum.KeyCode.DPadDown] = "S",
	[Enum.KeyCode.D] = "D", [Enum.KeyCode.Right] = "D", [Enum.KeyCode.DPadRight] = "D",
}

-- (the Become La Peace look: chunky black outlines, rounded gradient panels,
-- Inconsolata Bold with black strokes)
local FONT = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)
local PURPLE = Color3.fromRGB(165, 85, 255)
local VIOLET = Color3.fromRGB(95, 35, 200)
local PINK = Color3.fromRGB(255, 150, 235)
local GOOD = Color3.fromRGB(120, 255, 170)
local BAD = Color3.fromRGB(255, 70, 90)
local RED = Color3.fromRGB(255, 40, 55)
D.LOCK = 2.4       -- the red lock-on appears this long before impact
local BEEP = "rbxasset://sounds/electronicpingshort.wav"
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(1, 0) c.Parent = p return c end
local function stroke(p, color, th, mode)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = th or 4
	if mode then s.ApplyStrokeMode = mode end
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
	stroke(t, Color3.new(0, 0, 0), props.StrokeTh or 3)
	return t
end
local function square(f) local a = Instance.new("UIAspectRatioConstraint") a.AspectRatio = 1 a.Parent = f return a end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local S -- the running session

local function root(K)
	local r = K.Gui:FindFirstChild("Dodge")
	if r then return r end
	r = frame(K.Gui, { Name = "Dodge", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60 })
	return r
end

local function touchOnly() return UIS.TouchEnabled and not UIS.KeyboardEnabled end
local function padOnly() return UIS.GamepadEnabled and not UIS.KeyboardEnabled end

--------------------------------------------------------------------------
-- the intro card (shown during the pull, before the dive)
--------------------------------------------------------------------------
function D.intro(ctx)
	local K = ctx.kit
	local r = root(K)
	local card = frame(r, {
		Name = "Intro", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.36, 0.2),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.05, ZIndex = 70,
	})
	corner(card, UDim.new(0.18, 0))
	stroke(card, Color3.new(0, 0, 0), 5)
	grad(card, Color3.fromRGB(70, 25, 140), Color3.fromRGB(150, 70, 255))
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = card
	label(card, { Text = "DODGE!", Size = UDim2.fromScale(0.9, 0.32), Position = UDim2.fromScale(0.05, 0.06), ZIndex = 71, StrokeTh = 4 })
	local keys = frame(card, { BackgroundTransparency = 1, Size = UDim2.fromScale(0.9, 0.32), Position = UDim2.fromScale(0.05, 0.4), ZIndex = 71 })
	local ll = Instance.new("UIListLayout")
	ll.FillDirection = Enum.FillDirection.Horizontal
	ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ll.VerticalAlignment = Enum.VerticalAlignment.Center
	ll.Padding = UDim.new(0.03, 0)
	ll.Parent = keys
	for _, k in ipairs(ORDER) do
		local cap = frame(keys, { Size = UDim2.fromScale(0.2, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 72 })
		square(cap)
		corner(cap, UDim.new(0.25, 0))
		stroke(cap, Color3.new(0, 0, 0), 4)
		grad(cap, Color3.fromRGB(215, 205, 235), Color3.new(1, 1, 1))
		local txt = touchOnly() and ARROWS[k] or padOnly() and ARROWS[k] or k
		local l = label(cap, { Text = txt, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), TextColor3 = Color3.fromRGB(60, 20, 120), ZIndex = 73, StrokeTh = 0 })
		l:FindFirstChildOfClass("UIStroke"):Destroy()
	end
	local how = touchOnly() and "TAP THE ARROW WHEN THE RINGS MEET" or padOnly() and "D-PAD WHEN THE RINGS MEET" or "PRESS THE KEY WHEN THE RINGS MEET"
	label(card, { Text = how .. "  -  " .. D.MAX_HITS .. " HITS AND YOU'RE OUT", Size = UDim2.fromScale(0.9, 0.14), Position = UDim2.fromScale(0.05, 0.8), ZIndex = 71, TextColor3 = Color3.fromRGB(235, 220, 255) })
	tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.3, function()
		tween(sc, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.35, function() card:Destroy() end)
	end)
end

--------------------------------------------------------------------------
-- the hull pips
--------------------------------------------------------------------------
local function buildPips(r)
	local bar = frame(r, { Name = "Hull", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.125), Size = UDim2.fromScale(0.2, 0.05), BackgroundTransparency = 1, ZIndex = 64 })
	local ll = Instance.new("UIListLayout")
	ll.FillDirection = Enum.FillDirection.Horizontal
	ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ll.VerticalAlignment = Enum.VerticalAlignment.Center
	ll.Padding = UDim.new(0.02, 0)
	ll.Parent = bar
	local pips = {}
	for i = 1, D.MAX_HITS do
		local p = frame(bar, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 65, LayoutOrder = i })
		square(p)
		corner(p)
		stroke(p, Color3.new(0, 0, 0), 3)
		grad(p, VIOLET, PINK)
		pips[i] = p
	end
	return bar, pips
end

--------------------------------------------------------------------------
-- a prompt: the key in its circle, and the ring closing on it
--------------------------------------------------------------------------
local function makePrompt(r, key)
	local holder = frame(r, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.12, 0.12), BackgroundTransparency = 1, ZIndex = 61 })
	square(holder).DominantAxis = Enum.DominantAxis.Height
	local ring = frame(holder, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(3, 3), BackgroundTransparency = 1, ZIndex = 61 })
	corner(ring)
	local rs = stroke(ring, Color3.new(1, 1, 1), 5)
	local rs2 = frame(ring, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 8, 1, 8), BackgroundTransparency = 1, ZIndex = 61 })
	corner(rs2)
	stroke(rs2, Color3.new(0, 0, 0), 2)
	local disc = frame(holder, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 62 })
	corner(disc)
	local ds = stroke(disc, Color3.new(0, 0, 0), 5)
	local dg = grad(disc, VIOLET, PURPLE)
	local glyph = (touchOnly() or padOnly()) and ARROWS[key] or key
	local l = label(disc, { Text = glyph, Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.17), ZIndex = 63, StrokeTh = 4 })
	local sub = label(disc, { Text = ARROWS[key], Size = UDim2.fromScale(0.3, 0.2), Position = UDim2.fromScale(0.35, 0.74), ZIndex = 63, TextColor3 = Color3.fromRGB(230, 210, 255), StrokeTh = 2 })
	if glyph == ARROWS[key] then sub.Visible = false end
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = holder
	tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	return { Holder = holder, Ring = ring, RingStroke = rs, Disc = disc, DiscGrad = dg, Scale = sc, Label = l, Sub = sub, Pos = Vector2.new(0.5, 0.5) }
end

local function popText(r, pos, text, color, big)
	local t = label(r, {
		Text = text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(pos.X, pos.Y - 0.1), Size = UDim2.fromScale(big and 0.32 or 0.2, big and 0.08 or 0.055),
		TextColor3 = color, ZIndex = 66, StrokeTh = 4,
	})
	local sc = Instance.new("UIScale")
	sc.Scale = 0.4
	sc.Parent = t
	tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(t, 0.8, { Position = UDim2.fromScale(pos.X, pos.Y - 0.16) }, Enum.EasingStyle.Quad)
	task.delay(0.55, function()
		tween(t, 0.3, { TextTransparency = 1 })
		local s = t:FindFirstChildOfClass("UIStroke")
		if s then tween(s, 0.3, { Transparency = 1 }) end
		task.delay(0.35, function() t:Destroy() end)
	end)
end

local function closePrompt(q, good)
	local ui = q.UI
	if not ui then return end
	q.UI = nil
	local col = good and GOOD or BAD
	ui.RingStroke.Color = col
	ui.DiscGrad.Color = ColorSequence.new(col:Lerp(Color3.new(0, 0, 0), 0.25), col)
	tween(ui.Ring, 0.25, { Size = UDim2.fromScale(good and 1.9 or 1.2, good and 1.9 or 1.2) })
	tween(ui.RingStroke, 0.25, { Transparency = 1 })
	tween(ui.Scale, 0.3, { Scale = good and 1.25 or 0.6 }, good and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
	task.delay(0.12, function()
		for _, d in ipairs(ui.Holder:GetDescendants()) do
			if d:IsA("Frame") then tween(d, 0.25, { BackgroundTransparency = 1 })
			elseif d:IsA("TextLabel") then tween(d, 0.25, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then tween(d, 0.25, { Transparency = 1 }) end
		end
		task.delay(0.3, function() ui.Holder:Destroy() end)
	end)
end

--------------------------------------------------------------------------
-- judging a press
--------------------------------------------------------------------------
local function resolve(c, ok, how)
	local q = c.Q
	if not q or q.Done then return end
	q.Done = true
	local K = S.ctx.kit
	local pos = q.UI and q.UI.Pos or Vector2.new(0.5, 0.5)
	if ok then
		local T = S.clock()
		local cam = workspace.CurrentCamera.CFrame
		local d = DIRS[q.Key]
		local world = (cam.RightVector * d.X + cam.UpVector * d.Y).Unit
		c.Dodged = true
		c.DodgeT = T
		c.DodgeVec = -world        -- the obstacle is thrown the other way
		S.ctx.SOL.DodgeT = T
		S.ctx.SOL.DodgeWorld = world
		S.ctx.SOL.DodgeSign = (d.X ~= 0 and d.X or d.Y)
		S.dodged += 1
		closePrompt(q, true)
		popText(S.root, pos, how == "perfect" and "PERFECT!" or "DODGED!", how == "perfect" and PINK or GOOD, how == "perfect")
		K.sfx(K.S.Whoosh, 0.9, how == "perfect" and 1.25 or 1.1)
		K.sfx(K.S.Ring, 0.35, how == "perfect" and 1.5 or 1.2)
	else
		c.QFail = true
		closePrompt(q, false)
		popText(S.root, pos, how == "early" and "TOO EARLY!" or how == "wrong" and "WRONG KEY!" or "MISS!", BAD)
		K.sfx(K.S.TonalHit, 0.35, 1.6)
	end
end

local function press(key)
	if not S or S.dead then return end
	local T = S.clock()
	-- the open prompt nearest its moment takes the press
	local best
	for _, c in ipairs(S.list) do
		local q = c.Q
		if q and not q.Done then
			if not best or c.T < best.T then best = c end
		end
	end
	if not best then return end
	local q = best.Q
	local J = best.T - D.JUDGE
	local dt = T - J
	if key ~= q.Key then
		resolve(best, false, "wrong")
	elseif dt < -D.WINDOW then
		resolve(best, false, "early")
	elseif math.abs(dt) <= D.WINDOW then
		resolve(best, true, math.abs(dt) <= D.PERFECT and "perfect" or "good")
	end
end

--------------------------------------------------------------------------
-- the lock-on: red target brackets clamped round whatever's about to hit you,
-- its name, and a countdown to impact (and it beeps faster as it closes)
--------------------------------------------------------------------------
local function makeLock(r, name)
	local h = frame(r, { Name = "Lock", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(200, 200), BackgroundTransparency = 1, ZIndex = 57 })
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
	-- a crosshair tick on each side, and a diamond at the heart of it
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

local function endLock(c, good)
	local L = c.Lock
	if not L or L.Ending then return end
	L.Ending = true
	local col = good and GOOD or RED
	for _, b in ipairs(L.Bits) do b.BackgroundColor3 = col end
	L.Tag.TextColor3 = col
	L.Eta.Text = good and "EVADED" or "IMPACT"
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

local function lockUpdate(c, T, cam, vs, wp, rad)
	local L = c.Lock
	if L.Ending then return end
	if not wp then L.H.Visible = false return end
	local v = cam:WorldToViewportPoint(wp)
	if v.Z <= 0 then L.H.Visible = false return end
	L.H.Visible = true
	local tanh = math.tan(math.rad(cam.FieldOfView) / 2)
	local sr = ((rad or 200) / (v.Z * tanh)) * vs.Y / 2
	local want = math.clamp(sr * 2.3, 80, vs.Y * 0.8)
	-- (it slams in from wide as it locks on)
	local k = 1 + 1.6 * (1 - smooth((T - c.LockT) / 0.35))
	L.H.Size = UDim2.fromOffset(want * k, want * k)
	L.H.Position = UDim2.fromOffset(math.clamp(v.X, 60, vs.X - 60), math.clamp(v.Y, 70, vs.Y - 70))
	local rem = math.max(c.T - T, 0)
	L.Eta.Text = string.format("IMPACT  %.1f", rem)
	local blink = rem < 0.9 and math.floor(os.clock() * (rem < 0.45 and 16 or 9)) % 2 == 0
	local col = blink and Color3.new(1, 1, 1) or RED
	if col ~= L.Col then
		L.Col = col
		for _, b in ipairs(L.Bits) do b.BackgroundColor3 = col end
	end
end

--------------------------------------------------------------------------
-- session
--------------------------------------------------------------------------
-- list: the obstacles (tables with T, and Key); clock(): the solar clock now
function D.start(ctx, list, clock)
	if S then D.stop() end
	local K = ctx.kit
	local r = root(K)
	S = { ctx = ctx, list = list, clock = clock, root = r, hits = 0, dodged = 0, conns = {}, dead = false }
	S.bar, S.pips = buildPips(r)
	local rng = Random.new()
	for _, c in ipairs(list) do
		c.Q = nil c.Dodged = nil c.QFail = nil c.Lock = nil
		c.NeedKey = ORDER[rng:NextInteger(1, 4)]
	end
	table.insert(S.conns, UIS.InputBegan:Connect(function(input)
		local key = KEYMAP[input.KeyCode]
		if key then press(key) end
	end))
	if touchOnly() then
		-- on-screen arrows (bottom right)
		local pad = frame(r, { Name = "Pad", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(0.97, 0.86), Size = UDim2.fromScale(0.3, 0.3), BackgroundTransparency = 1, ZIndex = 64 })
		square(pad).DominantAxis = Enum.DominantAxis.Height
		local spots = { W = UDim2.fromScale(0.5, 0.17), A = UDim2.fromScale(0.17, 0.5), S = UDim2.fromScale(0.5, 0.83), D = UDim2.fromScale(0.83, 0.5) }
		for k, at in pairs(spots) do
			local b = Instance.new("TextButton")
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.Position = at
			b.Size = UDim2.fromScale(0.32, 0.32)
			b.BackgroundColor3 = Color3.new(1, 1, 1)
			b.Text = ARROWS[k]
			b.FontFace = FONT
			b.TextScaled = true
			b.TextColor3 = Color3.new(1, 1, 1)
			b.AutoButtonColor = true
			b.ZIndex = 65
			corner(b)
			stroke(b, Color3.new(0, 0, 0), 4, Enum.ApplyStrokeMode.Border)
			grad(b, VIOLET, PURPLE)
			b.Parent = pad
			table.insert(S.conns, b.Activated:Connect(function() press(k) end))
		end
		S.pad = pad
	end
end

-- posOf(c) -> the obstacle's world position, radius and name (or nil)
function D.update(T, posOf)
	if not S or S.dead then return end
	local cam = workspace.CurrentCamera
	local vs = cam.ViewportSize
	local soonest
	for _, c in ipairs(S.list) do
		local J = c.T - D.JUDGE
		local wp, rad, name
		if not c.Done and T >= c.T - D.LOCK - 0.1 then wp, rad, name = posOf(c) end
		-- the red lock-on
		if not c.Lock and not c.Done and not c.Dodged and T >= c.T - D.LOCK and T < c.T then
			c.Lock = makeLock(S.root, name or "INCOMING")
			c.LockT = T
			local K = S.ctx.kit
			K.sfx(BEEP, 0.4, 0.8)
		end
		if c.Lock and not c.Lock.Ending then
			if c.Dodged then
				endLock(c, true)
			elseif T >= c.T or c.Done then
				endLock(c, false)
			else
				lockUpdate(c, T, cam, vs, wp, rad)
				if not soonest or c.T < soonest.T then soonest = c end
			end
		end
		-- the dodge prompt
		if not c.Q and not c.Done and T >= c.T - D.LEAD and T < J + D.WINDOW then
			c.Q = { Key = c.NeedKey, UI = makePrompt(S.root, c.NeedKey) }
		end
		local q = c.Q
		if q and not q.Done then
			if T > J + D.WINDOW then
				resolve(c, false, "miss")
			elseif q.UI then
				local ui = q.UI
				-- the ring closes from 3x to meet the circle at the judging moment
				local s = 1 + 2 * math.max(0, (J - T) / (D.LEAD - D.JUDGE))
				if T > J then s = 1 - 0.15 * (T - J) / D.WINDOW end
				ui.Ring.Size = UDim2.fromScale(s, s)
				local near = 1 - math.clamp(math.abs(T - J) / 0.35, 0, 1)
				ui.RingStroke.Thickness = 4 + near * 4
				ui.RingStroke.Color = Color3.new(1, 1, 1):Lerp(PINK, near)
				-- hang it over the obstacle (kept well on screen, clear of the diver)
				local want = Vector2.new(0.5, 0.36)
				if wp then
					local v = cam:WorldToViewportPoint(wp)
					if v.Z > 0 then want = Vector2.new(math.clamp(v.X / vs.X, 0.28, 0.72), math.clamp(v.Y / vs.Y, 0.24, 0.44)) end
				end
				ui.Pos = ui.Pos:Lerp(want, 0.25)
				ui.Holder.Position = UDim2.fromScale(ui.Pos.X, ui.Pos.Y)
			end
		end
	end
	-- the warning beep: faster and higher the closer the nearest threat gets
	if soonest then
		local rem = math.max(soonest.T - T, 0)
		local u = math.clamp(rem / D.LOCK, 0, 1)
		local gap = 0.07 + 0.43 * u
		if os.clock() - (S.lastBeep or 0) >= gap then
			S.lastBeep = os.clock()
			local K = S.ctx.kit
			K.sfx(BEEP, 0.28 + 0.2 * (1 - u), 1.35 + 0.8 * (1 - u))
		end
	end
end

-- you smashed into something: lose a pip (true = that was the last)
function D.hit()
	if not S or S.dead then return false end
	local K = S.ctx.kit
	S.hits += 1
	local p = S.pips[D.MAX_HITS - S.hits + 1]
	if p then
		local g = p:FindFirstChildOfClass("UIGradient")
		if g then g.Color = ColorSequence.new(Color3.fromRGB(60, 50, 70), Color3.fromRGB(110, 100, 120)) end
		local sc = Instance.new("UIScale")
		sc.Scale = 1.6
		sc.Parent = p
		tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	K.vignette(0.55, Color3.fromRGB(180, 0, 30), 0.08)
	task.delay(0.25, function() K.vignette(0, nil, 0.6) end)
	if S.hits >= D.MAX_HITS then
		D.fail()
		return true
	end
	return false
end

-- too many hits: you're done. Sent back to BECOME LA PEACE.
function D.fail()
	if not S or S.dead then return end
	S.dead = true
	local ctx, K = S.ctx, S.ctx.kit
	if S.bar then S.bar.Visible = false end
	if S.pad then S.pad.Visible = false end
	for _, c in ipairs(S.list) do
		if c.Q and not c.Q.Done then c.Q.Done = true closePrompt(c.Q, false) end
		if c.Lock then endLock(c, false) end
	end
	local over = frame(K.Gui, { Name = "DodgeFail", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 200 })
	K.flash(0.6, Color3.fromRGB(255, 60, 80), 0.8)
	K.sfx(K.S.Boom, 1, 0.6)
	K.sfx(K.S.Hell, 0.7, 0.8)
	K.shake(5, 1)
	tween(over, 1.2, { BackgroundTransparency = 0 })
	local big = label(over, { Text = "TORN APART", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(0.6, 0.11), TextColor3 = BAD, TextTransparency = 1, ZIndex = 201, StrokeTh = 5 })
	local small = label(over, { Text = "RETURNING TO BECOME LA PEACE...", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.5, 0.045), TextColor3 = Color3.fromRGB(230, 215, 255), TextTransparency = 1, ZIndex = 201 })
	task.delay(0.5, function()
		tween(big, 0.6, { TextTransparency = 0 })
		tween(small, 0.6, { TextTransparency = 0 })
	end)
	task.delay(2.2, function()
		local ev = ReplicatedStorage:FindFirstChild("FinalCutscene") and ReplicatedStorage.FinalCutscene:FindFirstChild("DodgeFailed")
		if ev then ev:FireServer() end
	end)
	-- (in Studio there's no teleport: after a moment the cutscene just carries on)
	local wait = RunService:IsStudio() and 5 or 25
	task.delay(wait, function()
		if not over.Parent then return end
		if RunService:IsStudio() then small.Text = "(STUDIO: NO TELEPORT, CARRYING ON)" end
		task.wait(RunService:IsStudio() and 1.2 or 0)
		tween(over, 0.8, { BackgroundTransparency = 1 })
		tween(big, 0.5, { TextTransparency = 1 })
		tween(small, 0.5, { TextTransparency = 1 })
		task.delay(0.9, function() over:Destroy() end)
	end)
end

function D.stop()
	if not S then return end
	for _, cn in ipairs(S.conns) do cn:Disconnect() end
	for _, c in ipairs(S.list) do
		if c.Q and not c.Q.Done then c.Q.Done = true closePrompt(c.Q, false) end
		if c.Lock then endLock(c, false) end
	end
	local bar, pad = S.bar, S.pad
	for _, g in ipairs({ bar, pad }) do
		if g then
			for _, d in ipairs(g:GetDescendants()) do
				if d:IsA("GuiObject") then tween(d, 0.4, { BackgroundTransparency = 1 }) end
				if d:IsA("UIStroke") then tween(d, 0.4, { Transparency = 1 }) end
				if d:IsA("TextButton") then tween(d, 0.4, { TextTransparency = 1 }) end
			end
			task.delay(0.5, function() g:Destroy() end)
		end
	end
	S = nil
end

function D.active() return S ~= nil and not S.dead end

return D
