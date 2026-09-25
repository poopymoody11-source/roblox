--==================================================
-- QTE: THE PARRY PROMPTS (client)
-- Every hit you're standing in gets a prompt, in the dodge
-- prompt's style (a key in a disc, a ring closing on it):
--   single   - one key as it lands
--   chord    - several keys, all down inside the window
--   ultimate - a sequence of steps (some of them chords), each on
--              a knife-edge; the whole track shows along the top
-- Complete every step and the hit is claimed (the server has the
-- last word). Early, late or wrong keys lose it.
-- Keys: CLICK (mouse / tap / R2), SPACE (A), Q (X), E (Y), F (B).
-- On touch the discs themselves are the buttons.
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
local GOLD = Color3.fromRGB(255, 220, 110)
local EMBER = Color3.fromRGB(255, 90, 40)

local player = Players.LocalPlayer
local K, S, Warn, remote
local root
local hits, order = {}, {}
Q.OnSuccess = nil -- function(hit, grade) (the local parry animation)
Q.OnFail = nil    -- function(hit, why)

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(1, 0) c.Parent = p return c end
local function stroke(p, color, th)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = th or 4
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end
local function grad(p, a, b) local g = Instance.new("UIGradient") g.Color = ColorSequence.new(a, b) g.Rotation = -90 g.Parent = p return g end
local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end
local function label(parent, props, th)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do t[k] = v end
	t.Parent = parent
	if (th or 3) > 0 then
		local s = Instance.new("UIStroke") s.Thickness = th or 3 s.Parent = t
	end
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

--------------------------------------------------------------------------
-- geometry
--------------------------------------------------------------------------
local function me()
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (r and hum and hum.Health > 0) then return nil end
	return r.Position
end

local function impactT(h, pos)
	local sh = h.Shape
	if sh.Kind == "ring" then return S.ringArrival(sh, pos) end
	if sh.Kind == "sweep" then return S.sweepArrival(sh, pos) end
	return h.T
end

local function inPath(h, pos, T)
	local sh = h.Shape
	if h.Qte.Kind == "ultimate" then return S.onArena(pos, -20) end
	if sh.Kind == "ring" then return S.onArena(pos, -5) end
	if sh.Kind == "sweep" then return T >= sh.T0 - 0.05 and T <= sh.T1 + 0.05 and S.onArena(pos, -5) end
	return S.inside(sh, pos, T, 0)
end

--------------------------------------------------------------------------
-- the prompt UI
--------------------------------------------------------------------------
local pressKey -- (forward)

local function buildUI(h)
	local ult = h.Qte.Kind == "ultimate"
	local holder = frame(root, { Name = "QTE", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromScale(0.34, 0.11), BackgroundTransparency = 1, ZIndex = 61 })
	local ui = { Holder = holder, Pos = Vector2.new(0.5, 0.66), Discs = {}, StepShown = 0 }
	-- the ring that closes (round the whole group)
	local ringBox = frame(holder, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 61 })
	local ar = Instance.new("UIAspectRatioConstraint") ar.AspectRatio = 1 ar.DominantAxis = Enum.DominantAxis.Height ar.Parent = ringBox
	local ring = frame(ringBox, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(3, 3), BackgroundTransparency = 1, ZIndex = 61 })
	corner(ring)
	ui.Ring = ring
	ui.RingStroke = stroke(ring, Color3.new(1, 1, 1), 5)
	-- the keys, in a row
	local row = frame(holder, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 62 })
	local ll = Instance.new("UIListLayout")
	ll.FillDirection = Enum.FillDirection.Horizontal
	ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ll.VerticalAlignment = Enum.VerticalAlignment.Center
	ll.Padding = UDim.new(0.02, 0)
	ll.Parent = row
	ui.Row = row
	-- its name (chords and the ultimate say what's coming)
	if h.Qte.Kind ~= "single" then
		ui.Title = label(holder, { Text = ult and "!! BIG BANG !! - PERFECT TIMING" or "PARRY - ALL AT ONCE", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromScale(1.2, 0.34), TextColor3 = ult and GOLD or PINK, ZIndex = 63 }, 3)
	end
	-- the ultimate's track: every step as a pip
	if ult then
		local track = frame(root, { Name = "QTETrack", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.42, 0.05), BackgroundTransparency = 1, ZIndex = 61 })
		local tl = Instance.new("UIListLayout")
		tl.FillDirection = Enum.FillDirection.Horizontal
		tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		tl.VerticalAlignment = Enum.VerticalAlignment.Center
		tl.Padding = UDim.new(0.02, 0)
		tl.Parent = track
		ui.Pips = {}
		for i, st in ipairs(h.Steps) do
			local names = {}
			for _, k in ipairs(st.Keys) do table.insert(names, GLYPH[k]()) end
			local pip = frame(track, { Size = UDim2.fromScale(0.18, 1), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, ZIndex = 62 })
			corner(pip, UDim.new(0.3, 0))
			stroke(pip, Color3.new(0, 0, 0), 3)
			ui.PipGrad = ui.PipGrad or {}
			ui.PipGrad[i] = grad(pip, Color3.fromRGB(90, 20, 20), EMBER)
			label(pip, { Text = table.concat(names, "+"), Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), ZIndex = 63 }, 2)
			ui.Pips[i] = pip
		end
		ui.Track = track
	end
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = holder
	tween(sc, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
	ui.Scale = sc
	return ui
end

-- lay out the current step's keys
local function showStep(h, i)
	local ui = h.UI
	for _, d in ipairs(ui.Discs) do d.Box:Destroy() end
	ui.Discs = {}
	ui.StepShown = i
	local st = h.Steps[i]
	local ult = h.Qte.Kind == "ultimate"
	for _, key in ipairs(st.Keys) do
		local box = Instance.new("TextButton")
		box.Text = ""
		box.AutoButtonColor = false
		box.BackgroundColor3 = Color3.new(1, 1, 1)
		box.Size = UDim2.fromScale(1, 1)
		box.ZIndex = 62
		local a = Instance.new("UIAspectRatioConstraint") a.AspectRatio = 1 a.DominantAxis = Enum.DominantAxis.Height a.Parent = box
		corner(box)
		stroke(box, Color3.new(0, 0, 0), 5)
		local g = grad(box, ult and Color3.fromRGB(120, 20, 20) or VIOLET, ult and EMBER or PURPLE)
		local txt = GLYPH[key]()
		label(box, { Text = txt, Size = UDim2.fromScale(#txt > 2 and 0.84 or 0.6, #txt > 2 and 0.34 or 0.6), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 63 }, 3)
		box.Parent = ui.Row
		-- (on touch the discs are the buttons; with a mouse a click is a click, wherever it lands)
		box.Active = touchOnly()
		if touchOnly() then box.Activated:Connect(function() pressKey(key) end) end
		table.insert(ui.Discs, { Box = box, Key = key, Grad = g })
	end
	if ui.Pips then
		for j, _ in ipairs(ui.Pips) do
			if j < i then ui.PipGrad[j].Color = ColorSequence.new(Color3.fromRGB(20, 110, 55), GOOD) end
			if j == i then ui.PipGrad[j].Color = ColorSequence.new(Color3.fromRGB(150, 100, 20), GOLD) end
		end
	end
end

local function closeUI(h, good)
	local ui = h.UI
	if not ui then return end
	h.UI = nil
	local col = good and GOOD or BAD
	ui.RingStroke.Color = col
	for _, d in ipairs(ui.Discs) do d.Grad.Color = ColorSequence.new(col:Lerp(Color3.new(0, 0, 0), 0.25), col) end
	tween(ui.Ring, 0.25, { Size = UDim2.fromScale(good and 1.9 or 1.2, good and 1.9 or 1.2) })
	tween(ui.RingStroke, 0.25, { Transparency = 1 })
	tween(ui.Scale, 0.3, { Scale = good and 1.25 or 0.6 }, good and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
	task.delay(0.12, function()
		for _, g in ipairs({ ui.Holder, ui.Track }) do
			if g then
				for _, d in ipairs(g:GetDescendants()) do
					if d:IsA("GuiObject") then tween(d, 0.25, { BackgroundTransparency = 1 }) end
					if d:IsA("TextLabel") then tween(d, 0.25, { TextTransparency = 1 }) end
					if d:IsA("UIStroke") then tween(d, 0.25, { Transparency = 1 }) end
				end
			end
		end
		task.delay(0.3, function()
			ui.Holder:Destroy()
			if ui.Track then ui.Track:Destroy() end
		end)
	end)
end

--------------------------------------------------------------------------
-- judging
--------------------------------------------------------------------------
local function fail(h, why)
	if h.Failed or h.Claimed then return end
	h.Failed = true
	closeUI(h, false)
	Warn.pop(why == "early" and "TOO EARLY!" or why == "wrong" and "WRONG KEY!" or why == "late" and "TOO LATE!" or "MISSED!", BAD, false, Vector2.new(0.5, 0.74))
	K.sfx(K.S.TonalHit, 0.35, 1.6)
	if Q.OnFail then Q.OnFail(h, why) end
end

local function complete(h, now)
	h.Claimed = now
	local worst = 0
	for _, st in ipairs(h.Steps) do
		for _, e in pairs(st.Done) do worst = math.max(worst, e) end
	end
	local grade = worst <= h.Qte.Perfect and "perfect" or "good"
	remote:FireServer(h.Id, now, grade)
	closeUI(h, true)
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
	local pos = me()
	if not pos then return end
	-- the displayed hit, due soonest, whose current step wants this key
	local best, bestT, bestStep
	local anyUlt
	for _, id in ipairs(order) do
		local h = hits[id]
		if h and h.UI and not h.Failed and not h.Claimed then
			local _, st = currentStep(h)
			if st then
				local T = impactT(h, pos) + st.At
				if h.Qte.Kind == "ultimate" then anyUlt = { H = h, T = T, St = st } end
				local wants = false
				for _, k in ipairs(st.Keys) do if k == key and not st.Done[k] then wants = true end end
				if wants and (not bestT or T < bestT) then best, bestT, bestStep = h, T, st end
			end
		end
	end
	K.sfx(K.S.Ring, 0.2, 2)
	if not best then
		-- (on the ultimate, a stray key inside its window costs you)
		if anyUlt and math.abs(now - anyUlt.T) <= 0.3 then fail(anyUlt.H, "wrong") end
		return
	end
	local err = now - bestT
	if err < -best.Qte.Early then
		fail(best, "early")
		return
	end
	if err > best.Qte.Late then
		fail(best, "late")
		return
	end
	bestStep.Done[key] = math.abs(err)
	-- (the disc lights up)
	for _, d in ipairs(best.UI.Discs) do
		if d.Key == key then
			d.Grad.Color = ColorSequence.new(Color3.fromRGB(20, 110, 55), GOOD)
			local sc = Instance.new("UIScale") sc.Scale = 1.25 sc.Parent = d.Box
			tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
	local all = true
	for _, k in ipairs(bestStep.Keys) do if not bestStep.Done[k] then all = false end end
	if all then
		bestStep.Complete = true
		if not currentStep(best) then complete(best, now) end
	end
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
	if not d.Qte or hits[d.Id] then return end
	local steps = {}
	for _, st in ipairs(d.Qte.Steps) do
		table.insert(steps, { At = st.At, Keys = st.Keys, Done = {}, Complete = false })
	end
	hits[d.Id] = { Id = d.Id, T = d.T, Shape = d.Shape, Name = d.Name, Target = d.Target, Qte = d.Qte, Steps = steps }
	table.insert(order, d.Id)
end

function Q.claimed(id)
	local h = hits[id]
	return h ~= nil and h.Claimed ~= nil
end

function Q.get(id) return hits[id] end

function Q.cancelAll()
	for id, h in pairs(hits) do
		if h.UI then closeUI(h, false) end
		hits[id] = nil
	end
	table.clear(order)
end

function Q.update(now)
	local cam = workspace.CurrentCamera
	local vs = cam.ViewportSize
	local pos = me()
	local shown = 0
	for i = #order, 1, -1 do
		local id = order[i]
		local h = hits[id]
		local T = (pos and impactT(h, pos)) or h.T or now
		local sh = h.Shape
		local over = (sh.Kind == "ring" and now > sh.T0 + 12) or (sh.Kind == "sweep" and now > sh.T1 + 2) or (h.T and now > h.T + 2)
		if over then
			if h.UI then closeUI(h, h.Claimed ~= nil) end
			hits[id] = nil
			table.remove(order, i)
		elseif pos and not h.Failed and not h.Claimed then
			local si, st = currentStep(h)
			local stepT = st and (T + st.At)
			local lead = h.Qte.Kind == "ultimate" and 1.0 or S.PROMPT_LEAD
			local want = st and inPath(h, pos, T) and now >= (T + h.Steps[1].At) - lead
			if st and now > stepT + h.Qte.Late then
				if h.UI or inPath(h, pos, T) then fail(h, "late") end
			elseif want and shown < 3 then
				shown += 1
				if not h.UI then h.UI = buildUI(h) end
				if h.UI.StepShown ~= si then showStep(h, si) end
				local ui = h.UI
				-- the ring closes from 3x to meet the discs at the step's moment
				local stepLead = si == 1 and lead or math.max(stepT - (T + h.Steps[si - 1].At), 0.2)
				local s = 1 + 2 * math.clamp((stepT - now) / stepLead, 0, 1)
				if now > stepT then s = 1 - 0.15 * math.min((now - stepT) / 0.15, 1) end
				ui.Ring.Size = UDim2.fromScale(s, s)
				local near = 1 - math.clamp(math.abs(now - stepT) / 0.3, 0, 1)
				ui.RingStroke.Thickness = 4 + near * 5
				ui.RingStroke.Color = Color3.new(1, 1, 1):Lerp(h.Qte.Kind == "ultimate" and GOLD or PINK, near)
				-- (the single ones hang over what's coming; the big ones sit centre screen)
				local wantPos = Vector2.new(0.5, h.Qte.Kind == "ultimate" and 0.62 or 0.66)
				if h.Qte.Kind == "single" and h.WorldPos then
					local v = cam:WorldToViewportPoint(h.WorldPos(now))
					if v.Z > 0 then wantPos = Vector2.new(math.clamp(v.X / vs.X, 0.3, 0.7), math.clamp(v.Y / vs.Y, 0.3, 0.72)) end
				end
				ui.Pos = ui.Pos:Lerp(wantPos, 0.2)
				ui.Holder.Position = UDim2.fromScale(ui.Pos.X, ui.Pos.Y)
			elseif h.UI and not want then
				closeUI(h, false)
			end
		end
	end
end

-- (attack visuals can tell a single prompt where its threat is)
function Q.track(id, worldPosFn)
	local h = hits[id]
	if h then h.WorldPos = worldPosFn end
end

return Q
