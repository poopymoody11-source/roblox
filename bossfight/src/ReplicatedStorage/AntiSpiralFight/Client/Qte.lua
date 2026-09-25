--==================================================
-- QTE: THE ESCAPE PROMPTS (client)
-- Only the black hole has one. It's the cutscene's dodge, step
-- for step: each key pops up as its own circle somewhere on the
-- screen, a ring closing in on it - press as the ring meets the
-- circle. They come one after another. Land them all and you tear
-- free (and hurt him); miss one and it has you.
-- Keys: CLICK (mouse / tap / R2), SPACE (A), Q (X), E (Y), F (B).
-- On touch the circles themselves are the buttons.
--==================================================
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Q = {}

local FONT = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)
local PURPLE = Color3.fromRGB(165, 85, 255)
local VIOLET = Color3.fromRGB(95, 35, 200)
local PINK = Color3.fromRGB(255, 150, 235)
local GOOD = Color3.fromRGB(120, 255, 170)
local BAD = Color3.fromRGB(255, 70, 90)
local LEAD = 0.95 -- a circle shows this long before its moment

-- where each circle pops up (screen fractions), in turn
local SPOTS = {
	Vector2.new(0.5, 0.42), Vector2.new(0.36, 0.52), Vector2.new(0.64, 0.5), Vector2.new(0.44, 0.64),
	Vector2.new(0.58, 0.36), Vector2.new(0.32, 0.38), Vector2.new(0.68, 0.64),
}

local player = Players.LocalPlayer
local K, S, Warn, remote
local root
local hits, order = {}, {}
Q.OnSuccess = nil -- function(hit, grade)
Q.OnFail = nil    -- function(hit, why)

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function corner(p) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = p return c end
local function stroke(p, color, th)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = th or 4
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end
local function grad(p, a, b) local g = Instance.new("UIGradient") g.Color = ColorSequence.new(a, b) g.Rotation = -90 g.Parent = p return g end
local function label(parent, props, th)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do t[k] = v end
	t.Parent = parent
	if (th or 3) > 0 then local s = Instance.new("UIStroke") s.Thickness = th or 3 s.Parent = t end
	return t
end

local function touchOnly() return UIS.TouchEnabled and not UIS.KeyboardEnabled end
local function padOnly() return UIS.GamepadEnabled and not UIS.KeyboardEnabled end
local GLYPH = {
	CLICK = function() return touchOnly() and "TAP" or padOnly() and "R2" or "CLICK" end,
	SPACE = function() return padOnly() and "A" or touchOnly() and "JUMP" or "SPACE" end,
	Q = function() return padOnly() and "X" or "Q" end,
	E = function() return padOnly() and "Y" or "E" end,
	F = function() return padOnly() and "B" or "F" end,
}

local function me()
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (r and hum and hum.Health > 0) then return nil end
	return r.Position
end

local function inPath(h, pos)
	if h.Qte.Kind == "ultimate" then return S.onArena(pos, -20) end
	return S.inside(h.Shape, pos, h.T, 0)
end

--------------------------------------------------------------------------
-- one circle (the cutscene's dodge prompt: key in a disc, ring closing on it)
--------------------------------------------------------------------------
local pressKey

local function makeCircle(key, spot)
	local holder = Instance.new("Frame")
	holder.Name = "QTE"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(spot.X, spot.Y)
	holder.Size = UDim2.fromScale(0.12, 0.12)
	holder.ZIndex = 61
	holder.Parent = root
	local ar = Instance.new("UIAspectRatioConstraint") ar.AspectRatio = 1 ar.DominantAxis = Enum.DominantAxis.Height ar.Parent = holder
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(3, 3)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 61
	ring.Parent = holder
	corner(ring)
	local rs = stroke(ring, Color3.new(1, 1, 1), 5)
	local rs2 = Instance.new("Frame")
	rs2.AnchorPoint = Vector2.new(0.5, 0.5)
	rs2.Position = UDim2.fromScale(0.5, 0.5)
	rs2.Size = UDim2.new(1, 8, 1, 8)
	rs2.BackgroundTransparency = 1
	rs2.ZIndex = 61
	rs2.Parent = ring
	corner(rs2)
	stroke(rs2, Color3.new(0, 0, 0), 2)
	local disc = Instance.new("TextButton")
	disc.Text = ""
	disc.AutoButtonColor = false
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = Color3.new(1, 1, 1)
	disc.ZIndex = 62
	disc.Active = touchOnly()
	disc.Parent = holder
	corner(disc)
	stroke(disc, Color3.new(0, 0, 0), 5)
	local dg = grad(disc, VIOLET, PURPLE)
	local txt = GLYPH[key]()
	label(disc, { Text = txt, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(#txt > 2 and 0.84 or 0.62, #txt > 2 and 0.36 or 0.62), ZIndex = 63 }, 4)
	if touchOnly() then disc.Activated:Connect(function() pressKey(key) end) end
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = holder
	tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	return { Holder = holder, Ring = ring, RingStroke = rs, DiscGrad = dg, Scale = sc, Key = key }
end

local function closeCircle(ui, good)
	if not ui or ui.Closed then return end
	ui.Closed = true
	local col = good and GOOD or BAD
	ui.RingStroke.Color = col
	ui.DiscGrad.Color = ColorSequence.new(col:Lerp(Color3.new(0, 0, 0), 0.25), col)
	tween(ui.Ring, 0.25, { Size = UDim2.fromScale(good and 1.9 or 1.2, good and 1.9 or 1.2) })
	tween(ui.RingStroke, 0.25, { Transparency = 1 })
	tween(ui.Scale, 0.3, { Scale = good and 1.25 or 0.6 }, good and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
	task.delay(0.12, function()
		for _, d in ipairs(ui.Holder:GetDescendants()) do
			if d:IsA("GuiObject") then tween(d, 0.25, { BackgroundTransparency = 1 }) end
			if d:IsA("TextLabel") then tween(d, 0.25, { TextTransparency = 1 }) end
			if d:IsA("UIStroke") then tween(d, 0.25, { Transparency = 1 }) end
		end
		task.delay(0.3, function() ui.Holder:Destroy() end)
	end)
end

local function popAt(spot, text, color)
	local t = label(root, { Text = text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(spot.X, spot.Y - 0.1), Size = UDim2.fromScale(0.16, 0.045), TextColor3 = color, ZIndex = 66 }, 3)
	tween(t, 0.6, { Position = UDim2.fromScale(spot.X, spot.Y - 0.15) })
	task.delay(0.4, function()
		tween(t, 0.25, { TextTransparency = 1 })
		task.delay(0.3, function() t:Destroy() end)
	end)
end

--------------------------------------------------------------------------
-- judging
--------------------------------------------------------------------------
local function fail(h, why)
	if h.Failed or h.Claimed then return end
	h.Failed = true
	for _, st in ipairs(h.Steps) do
		if st.UI then closeCircle(st.UI, st.Complete) end
	end
	Warn.pop(why == "early" and "TOO EARLY!" or why == "wrong" and "WRONG KEY!" or why == "late" and "TOO LATE!" or "MISSED!", BAD, false, Vector2.new(0.5, 0.74))
	K.sfx(K.S.TonalHit, 0.35, 1.6)
	if Q.OnFail then Q.OnFail(h, why) end
end

local function complete(h, now)
	h.Claimed = now
	local worst = 0
	for _, st in ipairs(h.Steps) do worst = math.max(worst, st.Err or 0) end
	local grade = worst <= h.Qte.Perfect and "perfect" or "good"
	remote:FireServer(h.Id, now, grade)
	K.sfx(K.S.Ring, 0.6, grade == "perfect" and 1.6 or 1.3)
	if Q.OnSuccess then Q.OnSuccess(h, grade) end
end

local function currentStep(h)
	for i, st in ipairs(h.Steps) do
		if not st.Complete then return i, st end
	end
	return nil
end

pressKey = function(key)
	local now = S.now()
	if not me() then return end
	-- the live circle due soonest
	local best, bestStep
	for _, id in ipairs(order) do
		local h = hits[id]
		if h and h.Shown and not h.Failed and not h.Claimed then
			local _, st = currentStep(h)
			if st and st.UI and (not bestStep or h.T + st.At < best.T + bestStep.At) then best, bestStep = h, st end
		end
	end
	if not best then return end
	local stepT = best.T + bestStep.At
	local err = now - stepT
	if key ~= bestStep.Keys[1] then
		-- (a wrong key near the moment costs you; well before it, it's ignored)
		if math.abs(err) <= 0.2 then fail(best, "wrong") end
		return
	end
	if err < -best.Qte.Early then fail(best, "early") return end
	if err > best.Qte.Late then fail(best, "late") return end
	bestStep.Complete = true
	bestStep.Err = math.abs(err)
	closeCircle(bestStep.UI, true)
	popAt(bestStep.Spot, math.abs(err) <= best.Qte.Perfect and "PERFECT!" or "GOOD!", math.abs(err) <= best.Qte.Perfect and PINK or GOOD)
	K.sfx(K.S.Whoosh, 0.5, 1.2 + bestStep.Index * 0.08)
	K.sfx(K.S.Ring, 0.3, 1.2 + bestStep.Index * 0.1)
	if not currentStep(best) then complete(best, now) end
end
Q.press = pressKey

--------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------
function Q.init(kit, shared, warn, qteRemote)
	K, S, Warn, remote = kit, shared, warn, qteRemote
	root = Warn.Gui:FindFirstChild("Root")
	local MAP = {
		[Enum.KeyCode.Space] = "SPACE", [Enum.KeyCode.Q] = "Q", [Enum.KeyCode.E] = "E", [Enum.KeyCode.F] = "F",
		[Enum.KeyCode.ButtonR2] = "CLICK", [Enum.KeyCode.ButtonA] = "SPACE", [Enum.KeyCode.ButtonX] = "Q",
		[Enum.KeyCode.ButtonY] = "E", [Enum.KeyCode.ButtonB] = "F",
	}
	UIS.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not processed then pressKey("CLICK") end
		elseif MAP[input.KeyCode] and not UIS:GetFocusedTextBox() then
			pressKey(MAP[input.KeyCode])
		end
	end)
end

-- a hit from the server: { Id, T, Shape, Name, Target, Qte }
function Q.add(d)
	if not d.Qte or hits[d.Id] or not d.T then return end
	local steps = {}
	local start = math.random(1, #SPOTS)
	for i, st in ipairs(d.Qte.Steps) do
		table.insert(steps, { At = st.At, Keys = st.Keys, Index = i, Spot = SPOTS[(start + i - 2) % #SPOTS + 1] })
	end
	hits[d.Id] = { Id = d.Id, T = d.T, Shape = d.Shape, Name = d.Name, Qte = d.Qte, Steps = steps }
	table.insert(order, d.Id)
end

function Q.claimed(id)
	local h = hits[id]
	return h ~= nil and h.Claimed ~= nil
end

function Q.get(id) return hits[id] end

function Q.cancelAll()
	for id, h in pairs(hits) do
		for _, st in ipairs(h.Steps) do if st.UI then closeCircle(st.UI, false) end end
		hits[id] = nil
	end
	table.clear(order)
end

function Q.update(now)
	local pos = me()
	for i = #order, 1, -1 do
		local id = order[i]
		local h = hits[id]
		if now > h.T + 2 then
			for _, st in ipairs(h.Steps) do if st.UI then closeCircle(st.UI, st.Complete) end end
			hits[id] = nil
			table.remove(order, i)
		elseif pos and not h.Failed and not h.Claimed then
			-- (in it: the circles come; out of it before they start: nothing to do)
			if not h.Shown and inPath(h, pos) and now >= h.T + h.Steps[1].At - LEAD then
				h.Shown = true
				Warn.pop("ESCAPE IT!", PINK, true, Vector2.new(0.5, 0.26))
			end
			if h.Shown then
				for _, st in ipairs(h.Steps) do
					local stepT = h.T + st.At
					if not st.Complete then
						if not st.UI and now >= stepT - LEAD then
							st.UI = makeCircle(st.Keys[1], st.Spot)
							K.sfx("rbxasset://sounds/electronicpingshort.wav", 0.35, 1 + st.Index * 0.1)
						end
						if st.UI and not st.UI.Closed then
							-- the ring closes from 3x to meet the circle at the step's moment
							local s = 1 + 2 * math.clamp((stepT - now) / LEAD, 0, 1)
							if now > stepT then s = 1 - 0.15 * math.min((now - stepT) / 0.15, 1) end
							st.UI.Ring.Size = UDim2.fromScale(s, s)
							local near = 1 - math.clamp(math.abs(now - stepT) / 0.3, 0, 1)
							st.UI.RingStroke.Thickness = 4 + near * 5
							st.UI.RingStroke.Color = Color3.new(1, 1, 1):Lerp(PINK, near)
						end
						if now > stepT + h.Qte.Late then fail(h, "late") break end
					end
				end
			end
		end
	end
end

return Q
