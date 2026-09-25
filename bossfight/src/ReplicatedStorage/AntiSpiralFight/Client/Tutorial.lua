--==================================================
-- HOW TO FIGHT HIM (client)
-- The cards between the cutscene and his first attack, in the
-- dodge intro's style (a purple gradient card, chunky black
-- outline, Inconsolata, a row of keycaps). The keys shown match
-- the device: keyboard, gamepad or touch.
--==================================================
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local T = {}

local FONT = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)

local function touch() return UIS.TouchEnabled and not UIS.KeyboardEnabled end
local function pad() return UIS.GamepadEnabled and not UIS.KeyboardEnabled end

local function tween(o, t, props, style, dir)
	TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
end
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
	if (th or 3) > 0 then local s = Instance.new("UIStroke") s.Thickness = th or 3 s.Parent = t end
	return t
end
local function style(p, a, b, r)
	local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(0.18, 0) c.Parent = p
	local s = Instance.new("UIStroke") s.Thickness = 5 s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = p
	local g = Instance.new("UIGradient") g.Color = ColorSequence.new(a, b) g.Rotation = -90 g.Parent = p
end

local function cards()
	local click = touch() and "TAP" or pad() and "R2" or "CLICK"
	local rollKey = touch() and "ROLL" or pad() and "B" or "CTRL"
	return {
		{ Title = "SURVIVE HIM", Keys = { "!" }, Text = "WHEN THE RED ! FLASHES, SOMETHING IS ABOUT TO LAND ON YOU - GET OUT OF THE RED", Color = Color3.fromRGB(255, 60, 80) },
		{ Title = "ROLL", Keys = { rollKey }, Text = "ROLL THROUGH ANYTHING - YOU CAN'T BE HIT MID-ROLL. JUMP HIS SHOCKWAVES", Color = Color3.fromRGB(120, 200, 255) },
		{ Title = "STRIKE HIM WHEN HE FALLS", Keys = { click }, Text = "AFTER A FEW ATTACKS HE COLLAPSES OVER THE EDGE - RUN TO HIS HEAD AND " .. click .. " TO PUNCH", Color = Color3.fromRGB(90, 255, 140) },
		{ Title = "THE BLACK HOLE", Keys = { pad() and "X" or "Q", pad() and "Y" or "E", click }, Text = "CAUGHT IN HIS BLACK HOLE? CIRCLES APPEAR ONE BY ONE - PRESS EACH KEY AS ITS RING CLOSES", Color = Color3.fromRGB(255, 200, 80) },
	}
end

-- dur: seconds to fill (the server holds his first attack for it)
function T.play(K, gui, dur)
	local list = cards()
	local each = math.max((dur - 0.6) / #list, 1.6)
	task.spawn(function()
		for i, c in ipairs(list) do
			local card = frame(gui, {
				Name = "HowTo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromScale(0.42, 0.22),
				BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 70,
			})
			style(card, Color3.fromRGB(70, 25, 140), Color3.fromRGB(150, 70, 255))
			local sc = Instance.new("UIScale") sc.Scale = 0 sc.Parent = card
			label(card, { Text = c.Title, Size = UDim2.fromScale(0.9, 0.24), Position = UDim2.fromScale(0.05, 0.05), ZIndex = 71, TextColor3 = c.Color }, 4)
			local row = frame(card, { BackgroundTransparency = 1, Size = UDim2.fromScale(0.9, 0.3), Position = UDim2.fromScale(0.05, 0.32), ZIndex = 71 })
			local ll = Instance.new("UIListLayout")
			ll.FillDirection = Enum.FillDirection.Horizontal
			ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
			ll.VerticalAlignment = Enum.VerticalAlignment.Center
			ll.Padding = UDim.new(0.03, 0)
			ll.Parent = row
			for _, k in ipairs(c.Keys) do
				local cap = frame(row, { Size = UDim2.fromScale(#k > 2 and 0.24 or 0.14, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 72 })
				style(cap, Color3.fromRGB(215, 205, 235), Color3.new(1, 1, 1), UDim.new(0.25, 0))
				label(cap, { Text = k, Size = UDim2.fromScale(0.8, 0.7), Position = UDim2.fromScale(0.1, 0.15), TextColor3 = k == "!" and Color3.fromRGB(200, 20, 40) or Color3.fromRGB(60, 20, 120), ZIndex = 73 }, 0)
			end
			label(card, { Text = c.Text, Size = UDim2.fromScale(0.92, 0.26), Position = UDim2.fromScale(0.04, 0.68), ZIndex = 71, TextColor3 = Color3.fromRGB(235, 220, 255) }, 2)
			-- a step counter
			label(card, { Text = i .. " / " .. #list, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromScale(0.12, 0.12), Position = UDim2.fromScale(0.97, 0.04), ZIndex = 71, TextColor3 = Color3.fromRGB(200, 180, 255) }, 2)
			tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			K.sfx(K.S.CutIn, 0.45, 1.1 + i * 0.05)
			task.wait(each - 0.35)
			tween(sc, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.delay(0.35, function() card:Destroy() end)
			task.wait(0.35)
		end
	end)
end

return T
