--==================================================
-- FINAL CUTSCENE DIRECTOR (client)
--
-- Waits with the party on the Become La Peace island, then
-- plays the whole opening in lock-step with every other
-- client off the server clock, chapter by chapter, and hands
-- over to the Anti-Spiral fight at the end.
--
-- Chapters live in ReplicatedStorage.FinalCutscene.Client.
-- Studio testing:
--   workspace:SetAttribute("FC_DebugFrom", "Reveal")  (server, before start)
--   workspace:SetAttribute("FC_ForceStart", true)     (server)
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local FC = ReplicatedStorage:WaitForChild("FinalCutscene")
local ClientFolder = FC:WaitForChild("Client")
local K = require(ClientFolder:WaitForChild("Kit"))
local TL = K.TL

--------------------------------------------------------------------------
-- a party passing through the public server on the way to its private one
--------------------------------------------------------------------------
do
	local TeleportService = game:GetService("TeleportService")
	local ok, td = pcall(function() return TeleportService:GetLocalPlayerTeleportData() end)
	if ok and type(td) == "table" and td.PrivateParty and not RunService:IsStudio() then
		task.wait(0.5)
		if workspace:GetAttribute("IsReservedServer") ~= true then
			player:SetAttribute("FC_CoverOff", true)
			local hold = Instance.new("ScreenGui")
			hold.Name = "PartyTransit"
			hold.IgnoreGuiInset = true
			hold.DisplayOrder = 1000
			hold.ResetOnSpawn = false
			local bg = Instance.new("Frame")
			bg.Size = UDim2.fromScale(1, 1)
			bg.BackgroundColor3 = Color3.new(0, 0, 0)
			bg.Parent = hold
			local text = Instance.new("TextLabel")
			text.BackgroundTransparency = 1
			text.AnchorPoint = Vector2.new(0.5, 0.5)
			text.Position = UDim2.fromScale(0.5, 0.5)
			text.Size = UDim2.fromScale(0.7, 0.06)
			text.FontFace = K.Fonts.Title
			text.TextScaled = true
			text.TextColor3 = Color3.fromRGB(200, 190, 255)
			text.Text = "OPENING A PRIVATE SERVER FOR YOUR PARTY..."
			text.Parent = bg
			hold.Parent = player:WaitForChild("PlayerGui")
			while hold.Parent do
				text.TextTransparency = 0.25 + math.sin(os.clock() * 3) * 0.25
				task.wait()
			end
			return
		end
	end
end

--------------------------------------------------------------------------
-- chapters
--------------------------------------------------------------------------
local chapterFns = {}
local builders = {}
for _, name in ipairs({ "ChGrass", "ChSpace", "ChSolar", "ChHole", "ChAnti", "ChArena", "ChRise", "ChEntry", "ChHand", "ChAwaken" }) do
	local ok, mod = pcall(require, ClientFolder:WaitForChild(name))
	if ok then
		for k, v in pairs(mod) do
			if k == "build" then table.insert(builders, { Name = name, Fn = v })
			elseif type(v) == "function" and TL.ByName[k] then chapterFns[k] = v end
		end
	else
		warn("[FinalCutscene] " .. name .. " failed to load: " .. tostring(mod))
	end
end

--------------------------------------------------------------------------
-- context shared by every chapter
--------------------------------------------------------------------------
local ctx = { kit = K, TL = TL, sets = {}, rigs = {}, roster = {}, n = 1 }

function ctx.setMusic(id, vol, fade, timePos)
	if ctx.music and ctx.music.Parent then K.fadeSound(ctx.music, 0, (fade and fade > 0) and fade or 0.4, true) end
	local s = K.sfx(id, 0, 1, { Looped = true, TimePosition = timePos })
	ctx.music = s
	if fade and fade > 0 then
		TweenService:Create(s, TweenInfo.new(fade, Enum.EasingStyle.Sine), { Volume = vol }):Play()
	else
		s.Volume = vol
	end
end

function ctx.fadeMusic(vol, time)
	if ctx.music and ctx.music.Parent then K.fadeSound(ctx.music, vol, time or 0.5) end
end

-- the fight arena (and its ring of galaxies) is far away but still drawn: it showed up
-- as a flat cluster of galaxies behind the space shots, so it's parked until the fall
function ctx.stashArena()
	local bf = workspace:FindFirstChild("BossFight")
	if bf then ctx.StashedArena = bf bf.Parent = nil end
	ctx.hideBase()
end
function ctx.restoreArena()
	if ctx.StashedArena then ctx.StashedArena.Parent = workspace ctx.StashedArena = nil end
	-- (the realm's galaxies come back; the arena itself stays out of sight until the landing)
	if not ctx.ArenaShown then ctx.arenaMap(false) end
	ctx.hideBase()
end

-- the arena itself (floor, rim, dressing, its veil) - kept completely out of view
-- from spiral space until the party and the Anti-Spiral land on it together
local ARENA_BITS = { { "BossFightMap" }, { "ArenaDressing" }, { "GalaxyRealm", "GoldFloor" }, { "GalaxyRealm", "Veil" } }
ctx.ArenaShown = false
ctx.ArenaBits = {}
function ctx.arenaBit(name)
	local e = ctx.ArenaBits[name]
	if e then return e[1] end
	local bf = workspace:FindFirstChild("BossFight") or ctx.StashedArena
	return bf and bf:FindFirstChild(name, true)
end
function ctx.arenaMap(on)
	ctx.ArenaShown = on
	local bf = workspace:FindFirstChild("BossFight") or ctx.StashedArena
	if on then
		for _, e in pairs(ctx.ArenaBits) do pcall(function() e[1].Parent = e[2] end) end
		ctx.ArenaBits = {}
		return
	end
	if not bf then return end
	for _, path in ipairs(ARENA_BITS) do
		local inst = bf
		for _, n in ipairs(path) do inst = inst and inst:FindFirstChild(n) end
		if inst and inst.Parent then
			local key = path[#path]
			ctx.ArenaBits[key] = { inst, inst.Parent }
			inst.Parent = nil
		end
	end
end

-- the Become La Peace island: once the party has left it, it's gone for good on
-- this screen (and stays gone even if streaming tries to put it back)
function ctx.hideBase()
	ctx.BaseHidden = true
	local map = workspace:FindFirstChild("LaPeaceMap")
	if map then map.Parent = nil end
	if not ctx.BaseGuard then
		ctx.BaseGuard = workspace.ChildAdded:Connect(function(c)
			if ctx.BaseHidden and c.Name == "LaPeaceMap" then task.defer(function() c.Parent = nil end) end
		end)
	end
end

-- the real Anti-Spiral (server model) is swapped for a stand-in while the cutscene runs
local bossHidden = {}
function ctx.hideBoss(on)
	local bf = workspace:FindFirstChild("BossFight")
	local boss = bf and bf:FindFirstChild("Anti-Spiral")
	if not boss then return end
	if on then
		if bossHidden.On then return end
		bossHidden = { On = true, Items = {} }
		for _, d in ipairs(boss:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			elseif d:IsA("ParticleEmitter") or d:IsA("Highlight") or d:IsA("BillboardGui") or d:IsA("Decal") then
				local prop = d:IsA("Decal") and "Transparency" or "Enabled"
				table.insert(bossHidden.Items, { d, prop, d[prop] })
				if prop == "Enabled" then d.Enabled = false else d.Transparency = 1 end
			end
		end
		local h = boss:FindFirstChildOfClass("Highlight")
		if h then h.Enabled = false end
		-- the golden particle floor is tuned for the fight camera; seen from the low
		-- cinematic angles its ~10k additive puffs pile up into a flat white glare,
		-- so it's calmed down (locally) until the fight starts
		local map = ctx.arenaBit("BossFightMap")
		bossHidden.Floor = {}
		for name, how in pairs({ MainMap = "bright", MainMapVFX = "alpha" }) do
			local part = map and map:FindFirstChild(name)
			for _, e in ipairs(part and part:GetChildren() or {}) do
				if e:IsA("ParticleEmitter") then
					table.insert(bossHidden.Floor, { e, e.Brightness, e.Transparency })
					if how == "bright" then
						e.Brightness = math.min(e.Brightness, 4)
					else
						local ks = {}
						for _, k in ipairs(e.Transparency.Keypoints) do table.insert(ks, NumberSequenceKeypoint.new(k.Time, 1 - (1 - k.Value) * 0.08)) end
						e.Transparency = NumberSequence.new(ks)
					end
				end
			end
		end
	else
		if not bossHidden.On then return end
		for _, f in ipairs(bossHidden.Floor or {}) do
			pcall(function() f[1].Brightness = f[2] f[1].Transparency = f[3] end)
		end
		for _, d in ipairs(boss:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
		end
		for _, it in ipairs(bossHidden.Items) do pcall(function() it[1][it[2]] = it[3] end) end
		bossHidden = {}
	end
end

--------------------------------------------------------------------------
-- waiting UI
--------------------------------------------------------------------------
local waitGui = Instance.new("ScreenGui")
waitGui.Name = "FinalCutsceneWait"
waitGui.IgnoreGuiInset = true
waitGui.ResetOnSpawn = false
waitGui.DisplayOrder = 550
waitGui.Parent = player:WaitForChild("PlayerGui")

-- styled like the Become La Peace HUD: chunky black outlines, rounded
-- gradient panels, a pill title and Inconsolata Bold with black strokes
local UI_FONT = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold)
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(0, 20) c.Parent = p return c end
local function stroke(p, color, th) local s = Instance.new("UIStroke") s.Color = color or Color3.new(0, 0, 0) s.Thickness = th or 5 s.Parent = p return s end
local function grad(p, a, b) local g = Instance.new("UIGradient") g.Color = ColorSequence.new(a, b) g.Rotation = -90 g.Parent = p return g end
local function shadow(p) pcall(function() local sh = Instance.new("UIShadow") sh.Parent = p end) end
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = UI_FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do if k ~= "StrokeColor" and k ~= "StrokeTh" then l[k] = v end end
	l.Parent = parent
	stroke(l, props.StrokeColor or Color3.new(0, 0, 0), props.StrokeTh or 2)
	return l
end

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.AnchorPoint = Vector2.new(0.5, 1)
root.Position = UDim2.new(0.5, 0, 1, -26)
root.Size = UDim2.fromOffset(540, 190)
root.Parent = waitGui
local uiScale = Instance.new("UIScale")
uiScale.Parent = root
local function rescale()
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	uiScale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720) * 1.05, 0.55, 1.4)
end
rescale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
panel.Position = UDim2.fromOffset(0, 26)
panel.Size = UDim2.new(1, 0, 1, -26)
panel.ClipsDescendants = true
panel.Parent = root
corner(panel)
local panelStroke = stroke(panel, Color3.new(0, 0, 0), 5)
local panelGrad = grad(panel, Color3.fromRGB(148, 142, 153), Color3.fromRGB(46, 20, 55))
shadow(panel)
local pattern = Instance.new("ImageLabel")
pattern.BackgroundTransparency = 1
pattern.Image = "rbxassetid://83787990994298"
pattern.ImageTransparency = 0.75
pattern.Position = UDim2.fromScale(-1.2, -2.6)
pattern.Size = UDim2.fromScale(3.4, 6)
pattern.ZIndex = 0
pattern.Parent = panel

-- pill title sitting on the panel's top edge
local pill = Instance.new("Frame")
pill.Name = "Title"
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.Position = UDim2.new(0.5, 0, 0, 0)
pill.Size = UDim2.fromOffset(330, 50)
pill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
pill.ZIndex = 5
pill.Parent = root
corner(pill, UDim.new(0, 60))
stroke(pill, Color3.new(0, 0, 0), 5)
local pillGrad = grad(pill, Color3.fromRGB(66, 205, 161), Color3.fromRGB(23, 89, 156))
shadow(pill)
local bTitle = label(pill, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.72), TextColor3 = Color3.new(0, 0, 0), Text = "WAITING FOR PARTY", ZIndex = 6, StrokeColor = Color3.new(1, 1, 1), StrokeTh = 3 })

local bSub = label(panel, { Position = UDim2.new(0, 20, 0, 34), Size = UDim2.new(1, -40, 0, 26), Text = "", ZIndex = 3 })

-- one bubble per party member
local slots = Instance.new("Frame")
slots.Name = "Slots"
slots.BackgroundTransparency = 1
slots.Position = UDim2.new(0, 20, 0, 68)
slots.Size = UDim2.new(1, -40, 0, 46)
slots.ZIndex = 3
slots.Parent = panel
local lay = Instance.new("UIListLayout")
lay.FillDirection = Enum.FillDirection.Horizontal
lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
lay.VerticalAlignment = Enum.VerticalAlignment.Center
lay.Padding = UDim.new(0, 10)
lay.Parent = slots
local bubbles = {}
for i = 1, 8 do
	local b = Instance.new("Frame")
	b.Name = "Slot" .. i
	b.Size = UDim2.fromOffset(44, 44)
	b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	b.LayoutOrder = i
	b.Visible = false
	b.ZIndex = 3
	b.Parent = slots
	corner(b, UDim.new(1, 0))
	local st = stroke(b, Color3.new(0, 0, 0), 3)
	local g = grad(b, Color3.fromRGB(84, 98, 112), Color3.fromRGB(40, 44, 52))
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.ZIndex = 4
	img.Parent = b
	corner(img, UDim.new(1, 0))
	local q = label(b, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6), Text = "?", ZIndex = 5 })
	bubbles[i] = { Frame = b, Img = img, Grad = g, Stroke = st, Q = q, User = nil }
end

-- loading bar
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
bar.Position = UDim2.new(0, 24, 1, -40)
bar.Size = UDim2.new(1, -48, 0, 20)
bar.ZIndex = 3
bar.Parent = panel
corner(bar, UDim.new(0, 60))
stroke(bar, Color3.new(0, 0, 0), 3)
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
fill.Size = UDim2.fromScale(0, 1)
fill.ZIndex = 4
fill.Parent = bar
corner(fill, UDim.new(0, 60))
local fillGrad = Instance.new("UIGradient")
fillGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(29, 149, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 242, 0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)) })
fillGrad.Parent = fill
local hint = label(bar, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -16, 1, -4), Text = "EXPLORE THE ISLAND WHILE EVERYONE LOADS IN", ZIndex = 6 })

-- big countdown number
local big = label(waitGui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.fromOffset(120, 100), Text = "", TextTransparency = 1, ZIndex = 10, StrokeTh = 4 })
grad(big, Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 230, 100))
local bigRatio = Instance.new("UIAspectRatioConstraint")
bigRatio.AspectRatio = 1.2
bigRatio.Parent = big
-- TextScaled tops out at 100px, so the number is blown up with a UIScale instead
local bigStroke = big:FindFirstChildOfClass("UIStroke")
local bigScale = Instance.new("UIScale")
bigScale.Parent = big

local thumbCache = {}
local function headshot(uid)
	if thumbCache[uid] ~= nil then return thumbCache[uid] end
	thumbCache[uid] = false
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		thumbCache[uid] = ok and img or false
	end)
	return false
end

local function presentCount()
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if not p:GetAttribute("FC_Transit") then n += 1 end
	end
	return n
end

local waitAmb
local waiting = true
local lastLeft
task.spawn(function()
	local shown = 0
	while waiting do
		local st = workspace:GetAttribute("FC_State")
		local exp = workspace:GetAttribute("FC_Expected") or 0
		local present = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if not p:GetAttribute("FC_Transit") then table.insert(present, p) end
		end
		table.sort(present, function(a, b) return a.UserId < b.UserId end)
		local n = #present
		local total = math.max(exp, n, 1)
		for i, bub in ipairs(bubbles) do
			local p = present[i]
			bub.Frame.Visible = i <= math.min(total, 8)
			if p then
				local img = headshot(p.UserId)
				bub.Img.Image = img or ""
				bub.Q.Text = img and "" or "..."
				bub.Grad.Color = ColorSequence.new(Color3.fromRGB(86, 170, 47), Color3.fromRGB(168, 223, 98))
				bub.Stroke.Color = Color3.new(0, 0, 0)
			else
				bub.Img.Image = ""
				bub.Q.Text = "?"
				bub.Grad.Color = ColorSequence.new(Color3.fromRGB(84, 98, 112), Color3.fromRGB(40, 44, 52))
			end
		end
		local frac = math.clamp(n / total, 0, 1)
		shown += (frac - shown) * 0.25
		fill.Size = UDim2.fromScale(math.max(shown, 0.04), 1)
		if st == "Countdown" then
			local left = math.max(0, math.ceil((workspace:GetAttribute("FC_Start") or 0) - K.now()))
			bTitle.Text = "EVERYONE'S HERE!"
			bSub.Text = "THE FINAL BATTLE BEGINS IN " .. left .. "..."
			pillGrad.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(230, 75, 59))
			hint.Text = "GET READY"
			if left ~= lastLeft and left > 0 then
				lastLeft = left
				big.Text = tostring(left)
				big.TextTransparency = 0
				bigStroke.Transparency = 0
				local base = uiScale.Scale * 2.4
				bigScale.Scale = base * 1.6
				TweenService:Create(bigScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = base }):Play()
				task.delay(0.6, function()
					TweenService:Create(big, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
					TweenService:Create(bigStroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
				end)
			end
		else
			bTitle.Text = "WAITING FOR PARTY"
			pillGrad.Color = ColorSequence.new(Color3.fromRGB(66, 205, 161), Color3.fromRGB(23, 89, 156))
			if exp > 0 then
				bSub.Text = string.format("%d / %d PLAYERS ARRIVED", n, exp)
			else
				bSub.Text = string.format("%d PLAYER%s HERE", n, n == 1 and "" or "S")
			end
			hint.Text = "EXPLORE THE ISLAND WHILE EVERYONE LOADS IN"
		end
		pill.Rotation = math.sin(os.clock() * 2) * 1.2
		task.wait(0.05)
	end
end)

--------------------------------------------------------------------------
-- prebuild every chapter's set while people are still loading in
--------------------------------------------------------------------------
local built = false
task.spawn(function()
	local list = {}
	for _, d in ipairs(K.Assets:GetDescendants()) do
		if d:IsA("Decal") or d:IsA("ParticleEmitter") or d:IsA("MeshPart") then table.insert(list, d) end
	end
	for _, b in ipairs(builders) do
		local ok, err = pcall(b.Fn, ctx)
		if not ok then warn("[FinalCutscene] build " .. b.Name .. ": " .. tostring(err)) end
		task.wait()
	end
	-- preload the textures/sounds the sets use
	local preload = {}
	for _, set in pairs(ctx.sets) do table.insert(preload, set) end
	local sounds = Instance.new("Folder")
	for _, id in pairs(K.S) do
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. id
		s.Parent = sounds
	end
	table.insert(preload, sounds)
	pcall(function() ContentProvider:PreloadAsync(preload) end)
	sounds:Destroy()
	built = true
end)

--------------------------------------------------------------------------
-- hiding / restoring the game around the cutscene
--------------------------------------------------------------------------
local hudState = {}
local hudConn
local controls
task.spawn(function()
	local pm = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
	if pm then pcall(function() controls = require(pm):GetControls() end) end
end)

local function hideHud(on)
	local pg = player:WaitForChild("PlayerGui")
	if on then
		for _, g in ipairs(pg:GetChildren()) do
			if g:IsA("ScreenGui") and g ~= K.Gui and g ~= waitGui then
				hudState[g] = g.Enabled
				g.Enabled = false
			end
		end
		hudConn = pg.ChildAdded:Connect(function(g)
			if g:IsA("ScreenGui") and g ~= K.Gui and g ~= waitGui then
				hudState[g] = hudState[g] == nil and g.Enabled or hudState[g]
				g.Enabled = false
			end
		end)
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
		-- (the cutscene streams the world around the camera, far from where your character
		-- stands; Roblox would pop its "gameplay paused / waiting for server" overlay over
		-- the cutscene - and its QTEs - whenever the character's own area streams out)
		pcall(function() game:GetService("GuiService"):SetGameplayPausedNotificationEnabled(false) end)
		pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
		if controls then pcall(function() controls:Disable() end) end
	else
		if hudConn then hudConn:Disconnect() hudConn = nil end
		for g, was in pairs(hudState) do
			if g.Parent then g.Enabled = was end
		end
		hudState = {}
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
		pcall(function() game:GetService("GuiService"):SetGameplayPausedNotificationEnabled(true) end)
		pcall(function() StarterGui:SetCore("ResetButtonCallback", true) end)
		if controls then pcall(function() controls:Enable() end) end
	end
end

--------------------------------------------------------------------------
-- run / finish
--------------------------------------------------------------------------
local running = false
local finished = false
local skipped = false   -- the party voted to skip (see the skip vote below)
local skipGui
local skipLabel

local function toFight()
	-- the hand-off: world and camera back to the player, fight lighting on
	K.stopCamera()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
	cam.FieldOfView = 70
	K.hideCharacters(false)
	ctx.restoreArena()
	ctx.arenaMap(true)
	ctx.hideBoss(false)
	-- (the Anti-Spiral keeps the stone he took in the Reveal)
	if ctx.onFight then pcall(ctx.onFight) end
	hideHud(false)
	K.lighting("Arena", 0)
	-- (the cutscene's arena grade is darker for its close shots; the fight keeps its own)
	game:GetService("Lighting").ExposureCompensation = 0
	K.Grade.Enabled = false
	K.Bloom.Enabled = false
	K.releasePost()
	K.streamStop()
	player:SetAttribute("CutsceneDone", true)
	player:SetAttribute("FC_CoverOff", true)
end

local function finish()
	if finished then return end
	finished = true
	if ctx.stage then ctx.stage:Destroy() ctx.stage = nil end
	for _, set in pairs(ctx.sets) do pcall(function() set:Destroy() end) end
	for _, rig in pairs(ctx.rigs) do pcall(function() rig:destroy() end) end
	ctx.rigs = {}
	K.stopAllSounds(1)
	toFight()
	K.letterbox(false, 0.8)
	K.vignette(0, nil, 0.5)
	K.fade(0, 1)
	if skipGui then skipGui:Destroy() skipGui = nil end
	task.delay(1.2, function()
		for _, c in ipairs(K.Layer:GetChildren()) do c:Destroy() end
	end)
end

-- the vote passed: black out, stop whatever chapter is playing, go to the fight
workspace:GetAttributeChangedSignal("FC_Skipped"):Connect(function()
	if not workspace:GetAttribute("FC_Skipped") or skipped or finished or not running then return end
	skipped = true
	if skipLabel then skipLabel.Text = "SKIPPING..." end
	K.fade(1, 0.35)
	task.wait(0.4)
	K.Aborted = true           -- every chapter's clock loop returns
	for _ = 1, 3 do RunService.RenderStepped:Wait() end
	finish()
end)

--------------------------------------------------------------------------
-- skip vote: a button for the party; when a majority says yes (the server
-- counts, see FinalCutsceneServer) everyone cuts straight to the fight
--------------------------------------------------------------------------
local function buildSkipButton()
	if skipGui then return end
	local remote = FC:WaitForChild("SkipVote", 5)
	if not remote then return end
	local voted = false
	-- (in the same style as the waiting panel: chunky black outlines, gradient pill, Inconsolata)
	local holder = Instance.new("Frame")
	holder.Name = "SkipVote"
	holder.BackgroundTransparency = 1
	-- (inside the bottom letterbox bar, centred in it)
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Position = UDim2.new(1, -22, 0.95, 0)
	holder.Size = UDim2.fromOffset(300, 64)
	holder.ZIndex = 99
	local sc = Instance.new("UIScale")
	sc.Parent = holder
	local function fit()
		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		sc.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720) * 0.9, 0.5, 1.2)
	end
	fit()
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
	-- the vote count, in a round panel-coloured badge
	local badge = Instance.new("Frame")
	badge.Name = "Votes"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 0, 0.5, 0)
	badge.Size = UDim2.fromOffset(64, 64)
	badge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	badge.ZIndex = 101
	badge.Parent = holder
	corner(badge, UDim.new(1, 0))
	stroke(badge, Color3.new(0, 0, 0), 5)
	grad(badge, Color3.fromRGB(148, 142, 153), Color3.fromRGB(46, 20, 55))
	shadow(badge)
	local count = label(badge, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.5), Text = "0/1", ZIndex = 102 })
	-- the button itself: the title pill
	local b = Instance.new("TextButton")
	b.Name = "Button"
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, 0, 0.5, 0)
	b.Size = UDim2.fromOffset(222, 50)
	b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	b.AutoButtonColor = false
	b.Text = ""
	b.ZIndex = 100
	b.Parent = holder
	corner(b, UDim.new(0, 60))
	stroke(b, Color3.new(0, 0, 0), 5)
	local g = grad(b, Color3.fromRGB(66, 205, 161), Color3.fromRGB(23, 89, 156))
	shadow(b)
	local txt = label(b, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.84, 0.62), TextColor3 = Color3.new(0, 0, 0), Text = "SKIP CUTSCENE", ZIndex = 101, StrokeColor = Color3.new(1, 1, 1), StrokeTh = 3 })
	skipLabel = txt
	local bs = Instance.new("UIScale")
	bs.Parent = b
	local TS = game:GetService("TweenService")
	local function pop(s) TS:Create(bs, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = s }):Play() end
	b.MouseEnter:Connect(function() pop(1.06) end)
	b.MouseLeave:Connect(function() pop(1) end)
	b.MouseButton1Down:Connect(function() pop(0.94) end)
	b.MouseButton1Up:Connect(function() pop(1.06) end)
	local function refresh()
		local v = workspace:GetAttribute("FC_SkipVotes") or 0
		local need = workspace:GetAttribute("FC_SkipNeeded") or 1
		count.Text = string.format("%d/%d", v, need)
		if workspace:GetAttribute("FC_Skipped") then
			txt.Text = "SKIPPING..."
		elseif voted then
			txt.Text = "VOTED TO SKIP"
			g.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(230, 75, 59))
		else
			txt.Text = "SKIP CUTSCENE"
			g.Color = ColorSequence.new(Color3.fromRGB(66, 205, 161), Color3.fromRGB(23, 89, 156))
		end
	end
	b.Activated:Connect(function()
		if workspace:GetAttribute("FC_Skipped") then return end
		voted = not voted
		remote:FireServer(voted)
		refresh()
	end)
	workspace:GetAttributeChangedSignal("FC_SkipVotes"):Connect(refresh)
	workspace:GetAttributeChangedSignal("FC_SkipNeeded"):Connect(refresh)
	refresh()
	holder.Parent = K.Gui
	skipGui = holder
end

local function run()
	if running then return end
	running = true
	waiting = false
	waitGui.Enabled = false
	player:SetAttribute("FC_CoverOff", true)
	if waitAmb then K.fadeSound(waitAmb, 0, 1, true) end

	local roster = string.split(workspace:GetAttribute("FC_Roster") or "", ",")
	local mySlot
	for i, id in ipairs(roster) do
		if id == tostring(player.UserId) then mySlot = i end
	end
	ctx.roster = roster
	ctx.n = #roster
	ctx.me = mySlot
	ctx.start = workspace:GetAttribute("FC_Start") or K.now()

	hideHud(true)
	K.hideCharacters(true)
	K.captureLighting()
	K.fade(1, 0.15)

	if not mySlot then
		-- joined after the cutscene began: wait it out
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, 0.5)
		t.Size = UDim2.fromScale(0.7, 0.06)
		t.FontFace = K.Fonts.Title
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(210, 200, 255)
		t.Text = "YOUR PARTY IS FACING THE ANTI-SPIRAL... GET READY"
		t.ZIndex = 95
		t.Parent = K.Gui
		while workspace:GetAttribute("FC_State") ~= "Fight" do task.wait(0.2) end
		t:Destroy()
		finish()
		return
	end

	-- wait for the sets (they're normally long done by now)
	local w0 = os.clock()
	while not built and os.clock() - w0 < 8 do task.wait() end

	local stage = Instance.new("Folder")
	stage.Name = "FC_Stage"
	stage.Parent = workspace
	ctx.stage = stage
	for i, uid in ipairs(roster) do
		local ok, rig = pcall(K.rig, uid, stage)
		if ok and rig then ctx.rigs[i] = rig else warn("[FinalCutscene] rig " .. tostring(uid) .. ": " .. tostring(rig)) end
	end
	ctx.myRig = ctx.rigs[mySlot]
	K.startCamera()
	task.delay(2, function()
		if not finished and not skipped then pcall(buildSkipButton) end
	end)

	for _, c in ipairs(TL.Chapters) do
		if finished or skipped then break end
		local t0 = ctx.start + c.Start
		if K.now() < t0 + c.Dur - 0.05 then
			while K.now() < t0 and not skipped do RunService.RenderStepped:Wait() end
			if skipped then break end
			local fn = chapterFns[c.Name]
			if fn then
				local ok, err = pcall(fn, ctx, t0, c.Dur)
				if not ok then warn("[FinalCutscene] chapter " .. c.Name .. ": " .. tostring(err)) end
			end
		end
	end
	finish()
end

--------------------------------------------------------------------------
-- state machine
--------------------------------------------------------------------------
local function onState()
	local st = workspace:GetAttribute("FC_State")
	if st == "Cutscene" then
		task.spawn(run)
	elseif st == "Fight" then
		if not running then
			running = true
			waiting = false
			waitGui.Enabled = false
			finished = true
			toFight()
			K.fade(0, 0.6)
		end
	elseif st == "Countdown" then
		-- fade to black just before it starts
		task.spawn(function()
			local start = workspace:GetAttribute("FC_Start") or K.now()
			while K.now() < start - 0.9 do task.wait() end
			if not running then K.fade(1, 0.8) end
		end)
	end
end

workspace:GetAttributeChangedSignal("FC_State"):Connect(onState)

-- first frame: island daylight, cover off, walk around
if (workspace:GetAttribute("FC_State") or "Waiting") ~= "Fight" then
	K.lighting("Day", 0)
	K.Grade.Enabled = true
	waitAmb = K.loop(K.S.Meadow, 0.25, 3)
end
task.delay(0.6, function()
	if (workspace:GetAttribute("FC_State") or "Waiting") == "Waiting" or workspace:GetAttribute("FC_State") == "Countdown" then
		player:SetAttribute("FC_CoverOff", true)
	end
end)
onState()
