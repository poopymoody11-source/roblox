--==================================================
-- THE DAZE (client)
-- Spent, he crashes forward over the rim - his head comes down on
-- the arena - and for a few seconds he's open: stars circle his
-- head, a green target marks it, and a bar counts down. Run up
-- and punch. Then he comes round with a roar and a shockwave.
--==================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local A = {}

local UP = Vector3.yAxis
local FONT = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)

local SLUMP = {
	Waist = { -22, 0, 0 }, Neck = { -18, 0, 0 },
	RightShoulder = { 55, 0, 18 }, LeftShoulder = { 55, 0, -18 },
	RightElbow = { 10, 0, 0 }, LeftElbow = { 10, 0, 0 },
}

local function tween(o, t, props)
	TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- the timer bar (bottom centre, over the QTE area)
local function timerBar(ctx, t0, t1)
	local root = ctx.Warn.Gui:FindFirstChild("Root")
	local holder = Instance.new("Frame")
	holder.Name = "DazeBar"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.2)
	holder.Size = UDim2.fromScale(0.34, 0.05)
	holder.BackgroundColor3 = Color3.new(1, 1, 1)
	holder.ZIndex = 58
	holder.Parent = root
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = holder
	local st = Instance.new("UIStroke") st.Thickness = 4 st.Parent = holder
	local g = Instance.new("UIGradient") g.Color = ColorSequence.new(Color3.fromRGB(10, 40, 20), Color3.fromRGB(20, 70, 35)) g.Rotation = -90 g.Parent = holder
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.ZIndex = 59
	fill.Parent = holder
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = fill
	local fg = Instance.new("UIGradient") fg.Color = ColorSequence.new(Color3.fromRGB(70, 255, 120), Color3.fromRGB(190, 255, 90)) fg.Parent = fill
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1.1)
	lbl.Position = UDim2.fromScale(0, -1.2)
	lbl.FontFace = FONT
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Text = "HE'S DAZED - PUNCH HIM!"
	lbl.ZIndex = 60
	lbl.Parent = holder
	local ls = Instance.new("UIStroke") ls.Thickness = 3 ls.Parent = lbl
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = ctx.S.now()
		local u = math.clamp((t1 - now) / (t1 - t0), 0, 1)
		fill.Size = UDim2.fromScale(u, 1)
		lbl.Text = (ctx.Moves.inReach() and "PUNCH HIM!  " or "HE'S DAZED - GET TO HIS HEAD!  ") .. string.format("%.1f", math.max(t1 - now, 0))
		if now >= t1 then
			conn:Disconnect()
			tween(holder, 0.3, { BackgroundTransparency = 1 })
			tween(fill, 0.3, { BackgroundTransparency = 1 })
			tween(lbl, 0.3, { TextTransparency = 1 })
			tween(st, 0.3, { Transparency = 1 })
			tween(ls, 0.3, { Transparency = 1 })
			task.delay(0.35, function() holder:Destroy() end)
		end
	end)
end

function A.start(ctx, d)
	local K, S, Fx, Rig, SK = ctx.K, ctx.S, ctx.Fx, ctx.Rig, ctx.SK
	local epoch = ctx.epoch()
	ctx.Moves.Weak = d.Weak
	local T0, T1 = d.T0, d.T1
	local fall = T0 + 0.7
	Fx.say(({ "IMPOSSIBLE... MY BODY...", "THIS... CANNOT BE...", "WHY... DO YOU NOT... DESPAIR..." })[math.random(1, 3)], 1.4, true)
	ctx.Warn.callout("DAZED!")
	ctx.Music.duck(0.5, 0.4)
	-- he crashes forward over the rim, head down on the arena
	-- (lowered and pitched about his root so his head lands just inside the rim)
	Rig:act({
		Until = T1 + 1.2,
		Root = function(t)
			local down = K.k(t, T0, fall, K.E.inQuad) * (1 - K.k(t, T1 - 0.1, T1 + 1.1, K.E.inOutQuad))
			local bob = math.sin(t * 2.2) * 3 * down
			return CFrame.new(0, -177 * down + bob, 0) * CFrame.Angles(-math.rad(27 * down), math.rad(math.sin(t * 1.3) * 3 * down), math.rad(math.sin(t * 1.7) * 2 * down))
		end,
		Upper = function(t)
			local down = K.k(t, T0, fall) * (1 - K.k(t, T1 - 0.1, T1 + 1.1))
			local sway = { Waist = { -22, math.sin(t * 1.4) * 6, 0 }, Neck = { -18 + math.sin(t * 2.6) * 6, math.sin(t * 1.9) * 12, 0 },
				RightShoulder = SLUMP.RightShoulder, LeftShoulder = SLUMP.LeftShoulder, RightElbow = SLUMP.RightElbow, LeftElbow = SLUMP.LeftElbow }
			Rig:pose(Rig.REST, sway, down)
			SK.hang(Rig.SB, "Right", 0.3, 0.3)
			SK.hang(Rig.SB, "Left", 0.3, 0.3)
			return true
		end,
	})
	-- the crash
	task.delay(math.max(fall - S.now(), 0), function()
		if ctx.epoch() ~= epoch then return end
		Fx.impact("WB", 0.05)
		Fx.blast(d.Weak, 40, Fx.VIOLET, { Sound = K.S.RockBoom, Shake = 3, Volume = 1.4, Column = false })
		ctx.Cam.punch(-10, 0.4)
		K.sfx(K.S.BodyFall, 1, 0.5)
	end)
	timerBar(ctx, T0, T1)
	-- the target on his head, and the stars going round it
	local host = K.part({ Name = "DazeHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(d.Weak) }, Fx.Folder)
	local ring = K.softRing(host, 32, 8, 10, { Brightness = 4, Alpha = 0 })
	for _, q in ipairs(ring.Q) do q.Color = ColorSequence.new(Color3.new(1, 1, 1), Fx.GREEN) end
	local ring2 = K.softRing(host, 32, 14, 15, { Brightness = 3, Alpha = 0 })
	for _, q in ipairs(ring2.Q) do q.Color = ColorSequence.new(Fx.LIME) end
	local spiral = K.quad(host, host.CFrame, 20, 20, "14426232568", { Color = Fx.GREEN, Brightness = 3, Transparency = 0.2 })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 50)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
	bb.AlwaysOnTop = true
	bb.Parent = host
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.FontFace = FONT
	tl.TextScaled = true
	tl.Text = "PUNCH HERE"
	tl.TextColor3 = Color3.fromRGB(190, 255, 170)
	tl.Parent = bb
	local ts = Instance.new("UIStroke") ts.Thickness = 3 ts.Parent = tl
	local stars = {}
	for i = 1, 6 do
		local p = K.part({ Name = "DizzyStar", Shape = Enum.PartType.Ball, Size = Vector3.one * 6, Material = Enum.Material.Neon, Color = i % 2 == 0 and Color3.fromRGB(255, 240, 150) or Color3.fromRGB(230, 200, 255), Transparency = 1 }, Fx.Folder)
		stars[i] = p
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = S.now()
		if ctx.epoch() ~= epoch or now > T1 + 0.4 then
			conn:Disconnect()
			host:Destroy()
			for _, p in ipairs(stars) do p:Destroy() end
			ctx.Moves.Weak = nil
			return
		end
		local on = K.k(now, fall, fall + 0.3) * (1 - K.k(now, T1 - 0.2, T1 + 0.2))
		local pulse = 0.5 + 0.5 * math.sin(now * 8)
		local c = d.Weak + UP * 0.4
		ring.update(CFrame.lookAt(c, c + UP), 8 + 2 * pulse, 10 + 3 * pulse, now)
		ring.setTransparency(1 - on * 0.9)
		ring2.update(CFrame.lookAt(c, c + UP), 14 + 4 * (now % 1), 15 + 4 * (now % 1), -now)
		ring2.setTransparency(1 - on * 0.9 * (1 - now % 1))
		K.moveQuad(spiral, CFrame.lookAt(c + UP * 0.2, c + UP * 2) * CFrame.Angles(0, 0, now * 2))
		spiral.Transparency = NumberSequence.new(1 - 0.7 * on)
		tl.TextTransparency = 1 - on
		ts.Transparency = 1 - on
		-- the stars: round his real head
		local head = ctx.part("Head")
		local hp = head and head.Position or (d.Weak + UP * 30)
		for i, p in ipairs(stars) do
			local a = now * 2.5 + i / #stars * math.pi * 2
			p.CFrame = CFrame.new(hp + Vector3.new(math.cos(a) * 55, 30 + math.sin(a * 2) * 6, math.sin(a) * 55))
			p.Transparency = 1 - on
		end
	end)
end

-- he comes round: a roar, and a shockwave off his head you have to jump
function A.finish(ctx, d)
	local K, S, Fx = ctx.K, ctx.S, ctx.Fx
	local epoch = ctx.epoch()
	ctx.Music.duck(1, 0.8)
	ctx.roar(d.T0, 1.4)
	Fx.say(({ "ENOUGH.", "I WILL ERASE YOU.", "KNEEL BEFORE THE VOID." })[math.random(1, 3)], 1, true)
	local sh = d.Shape
	local host = K.part({ Name = "RoarHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(d.Weak) }, Fx.Folder)
	local SEG = 48
	local wall = Fx.shockRing(host, SEG, sh.H, sh.W or 6, true)
	ctx.Warn.add({ Id = d.Id, Shape = sh, Name = "ROAR" })
	task.delay(math.max(d.RingT - S.now(), 0), function()
		if ctx.epoch() == epoch then Fx.blast(d.Weak, 25, Fx.VIOLET, { Shake = 2.5, Column = false, Sound = K.S.Boom }) end
	end)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = S.now()
		local r = S.ringRadius(sh, now)
		if ctx.epoch() ~= epoch or r > 2 * S.ARENA_R + 20 then
			conn:Disconnect()
			host:Destroy()
			return
		end
		wall.update(d.Weak, r, now >= sh.T0, now)
	end)
end

-- a punch landed on him (anyone's): his head snaps with it
function A.hit(ctx, d)
	local Fx = ctx.Fx
	local who = Players:GetPlayerByUserId(d.User)
	if who and who ~= ctx.player then
		ctx.Moves.punchFx(who.Character, d.At + UP * 4, math.random() < 0.5)
	end
	Fx.emitAt(d.At + UP * 6, {
		Texture = "1851669703", Color = ColorSequence.new(Color3.new(1, 1, 1), Fx.GREEN), Size = ctx.K.ns(0, 4, 1, 0),
		Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(30, 70), SpreadAngle = Vector2.new(70, 70), Brightness = 5,
	}, 12, 1)
	-- (every few punches, a proper impact frame)
	ctx.PunchCount = (ctx.PunchCount or 0) + 1
	if ctx.PunchCount % 5 == 0 then
		Fx.impact("G", 0.035)
		ctx.Cam.punch(-8, 0.25)
	end
end

return A
