--==================================================
-- QUEST GUIDE  ("🧭 FIND NEXT QUEST")
--
-- Pressing the button picks the next quest you can actually
-- do right now (story order, skipping anything on an island
-- you haven't unlocked yet) and guides you to its NPC:
--   * a glowing trail along the ground from you to them
--   * a gold outline on the NPC and a tag with the distance
--   * "teleport to X" if the quest is on another island
-- The guide clears itself when you get there. Once that quest
-- is finished it automatically moves on to the next one.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local frame = script.Parent                       -- the findquest pill
local button = frame:WaitForChild("Button")
local buttonLabel = frame:WaitForChild("TextLabel")
local BUTTON_TEXT = buttonLabel.Text

local modules = ReplicatedStorage:WaitForChild("AccessibleModules")
local ZoneData = require(modules:WaitForChild("ZoneData"))
local AscensionData = require(modules:WaitForChild("AscensionDataModule"))
local Monetization
pcall(function() Monetization = require(modules:WaitForChild("MonetizationData", 5)) end)

local stats = player:WaitForChild("PlayerStats", 30)
local claimed = stats and stats:WaitForChild("ClaimedQuests", 30)
local lapis = stats and stats:WaitForChild("Lapis", 30)

local GOLD = Color3.fromRGB(255, 200, 60)
local ARRIVE_DIST = 14

--------------------------------------------------
-- quest state helpers (same rules as the quest list)
--------------------------------------------------
local function isClaimed(name)
	local v = claimed and claimed:FindFirstChild(name)
	return v ~= nil and v.Value ~= false
end
local function statFlag(name)
	local v = stats and stats:FindFirstChild(name)
	if not v then return false end
	if v:IsA("BoolValue") then return v.Value end
	return true
end
local function lapisCount(name)
	local v = lapis and lapis:FindFirstChild(name)
	return v and v.Value or 0
end

local function find(path)
	local o = workspace
	for _, n in ipairs(path) do
		o = o and o:FindFirstChild(n)
	end
	return o
end

--------------------------------------------------
-- the quests, in story order
--   Target  -- where to guide you (path in Workspace)
--   Needs   -- extra islands the quest needs (where its lapis spawns)
--   Ready   -- prerequisites met?
--------------------------------------------------
local QUESTS = {
	{ Id = "HomelessQuest", Name = "Homeless Guy", Target = { "HoboQuest", "hoboquester" },
		Hint = "Find the hobo's lost pet rat",
		Done = function() return isClaimed("HomelessQuest") end },
	{ Id = "ToiletQuest", Name = "Hungry Guy", Target = { "ToiletQuest", "toiletquester" },
		Hint = "Bring the hungry guy some \"food\"",
		Ready = function() return isClaimed("HomelessQuest") end,
		Done = function() return isClaimed("ToiletQuest") end },
	{ Id = "TungQuest", Name = "Tung", Target = { "TungQuest", "TungQuester" },
		Hint = "Bring Tung 25 Gold Lapis",
		Done = function() return isClaimed("TungQuest") end },
	{ Id = "CarKeyQuest", Name = "Speed", Target = { "SpeedQuest", "speedquester" },
		Hint = "Find the keys dropped in the obby",
		Done = function() return isClaimed("CarKeyQuest") end },
	{ Id = "VillagerQuest", Name = "Mr Villager", Target = { "Villager", "mr villager quest" },
		Hint = "Bring Mr Villager 10 lapis from 67 Island", Needs = { "67 Island" },
		Done = function() return statFlag("cangoin") end },
	{ Id = "VerityQuest", Name = "Verity", Target = { "VerityQuest", "verityquester" },
		Hint = "Gather 20 Verity Lapis for Verity (bring a bat)",
		Ready = function() return isClaimed("TungQuest") end,
		Done = function() return isClaimed("VerityQuest") end },
	{ Id = "VerityQuest2", Name = "Verity's paper",
		Hint = "Equip Verity's paper and recite his words",
		Ready = function() return isClaimed("VerityQuest") end,
		Done = function() return isClaimed("VerityQuest2") end },
	{ Id = "VerityQuest3", Name = "Verity's Portal", Target = { "VerityQuest", "CrueltyPortal" },
		Hint = "Enter the portal and face whatever is inside",
		Ready = function() return isClaimed("VerityQuest2") end,
		Retarget = function(q)
			if statFlag("defeatedCruelty") then
				return { "VerityQuest", "verityquester" }, "Verity", nil
			end
		end,
		Done = function() return isClaimed("VerityQuest3") end },
	{ Id = "DungeonDoor", Name = "Dungeon Door", Target = { "Dungeon", "GoInDoor" },
		Hint = "Open the dungeon door on 67 Island",
		Ready = function() return statFlag("cangoin") end,
		Done = function() return isClaimed("DungeonDoor") end },
	{ Id = "DungeonReturn", Name = "The Dungeon", Target = { "Dungeon", "GoInDoor" },
		Hint = "Everything's done. Go back into the dungeon",
		Ready = function(list)
			if not isClaimed("DungeonDoor") then return false end
			for _, q in ipairs(list) do
				if q.Id ~= "DungeonDoor" and q.Id ~= "DungeonReturn" and not q.Done() then return false end
			end
			return true
		end,
		Done = function() return isClaimed("DungeonReturn") end },
}

--------------------------------------------------
-- islands
--------------------------------------------------
local function ascensions()
	local ls = player:FindFirstChild("leaderstats")
	local s = ls and (ls:FindFirstChild("Ascensions") or ls:FindFirstChild("Rebirths") or ls:FindFirstChild("Ascension"))
	return s and s.Value or 0
end

local function unlocked(island)
	if (AscensionData.Islands[island] or 0) <= ascensions() then return true end
	if Monetization then
		local ok, has = pcall(Monetization.HasIslandAccess, player, island)
		if ok and has then return true end
	end
	return false
end

local function positionOf(obj)
	if not obj then return nil end
	if obj:IsA("Model") then return obj:GetPivot().Position end
	if obj:IsA("BasePart") then return obj.Position end
	return nil
end

local function islandOf(pos)
	return pos and ZoneData.At(pos).Name or ZoneData.Default.Name
end

local function targetFor(q)
	local path, name, hint = q.Target, q.Name, q.Hint
	if q.Retarget then
		local p2, n2, h2 = q.Retarget(q)
		if p2 then path, name, hint = p2, n2, h2 end
	end
	return path, name, hint
end

-- the next quest you can do, and (if none) the first one you're locked out of
local function pickNext()
	local lockedOut
	for _, q in ipairs(QUESTS) do
		if not q.Done() and (not q.Ready or q.Ready(QUESTS)) then
			local path = targetFor(q)
			local obj = path and find(path)
			local islands = { islandOf(positionOf(obj)) }
			for _, n in ipairs(q.Needs or {}) do table.insert(islands, n) end
			local ok = true
			for _, isl in ipairs(islands) do
				if not unlocked(isl) then
					ok = false
					lockedOut = lockedOut or { Quest = q, Island = isl }
				end
			end
			if ok then return q end
		end
	end
	return nil, lockedOut
end

--------------------------------------------------
-- the guide card under the button, styled like the QUESTS panel:
-- purple gradient, chunky black outline, the pattern, a gold pill
-- title on the top edge and Inconsolata Bold with black strokes
--------------------------------------------------
local FONT = buttonLabel.FontFace
local BLACK = Color3.new(0, 0, 0)
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(0, 20) c.Parent = p return c end
local function uistroke(p, th, col) local s = Instance.new("UIStroke") s.Thickness = th or 5 s.Color = col or BLACK s.Parent = p return s end
local function gradient(p, a, b) local g = Instance.new("UIGradient") g.Color = ColorSequence.new(a, b) g.Rotation = -90 g.Parent = p return g end
local function shadow(p) pcall(function() Instance.new("UIShadow").Parent = p end) end
local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.TextScaled = true
	l.TextWrapped = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do if k ~= "StrokeColor" and k ~= "StrokeTh" then l[k] = v end end
	l.Parent = parent
	uistroke(l, props.StrokeTh or 2, props.StrokeColor or BLACK)
	return l
end
local function darker(c, f) return Color3.new(c.R * f, c.G * f, c.B * f) end
local GOLD_A, GOLD_B = Color3.fromRGB(255, 220, 90), Color3.fromRGB(240, 140, 40)

local card = Instance.new("Frame")
card.Name = "GuideToast"
card.Size = UDim2.new(0.186, 0, 0.13, 0)
local function cardPos()
	-- centred under the button, a little gap below it
	return frame.Position + UDim2.new(frame.Size.X.Scale / 2 - 0.093, 0, frame.Size.Y.Scale + 0.05, 0)
end
card.Position = cardPos()
card.BackgroundColor3 = Color3.new(1, 1, 1)
card.Visible = false
card.ZIndex = 5
card.Parent = frame.Parent
corner(card)
uistroke(card, 5)
gradient(card, Color3.fromRGB(148, 142, 153), Color3.fromRGB(46, 20, 55))
shadow(card)
local clip = Instance.new("Frame")
clip.BackgroundTransparency = 1
clip.Size = UDim2.fromScale(1, 1)
clip.ClipsDescendants = true
clip.ZIndex = 5
clip.Parent = card
corner(clip)
local pattern = Instance.new("ImageLabel")
pattern.BackgroundTransparency = 1
pattern.Image = "rbxassetid://83787990994298"
pattern.ImageTransparency = 0.75
pattern.Position = UDim2.fromScale(-1.2, -2.6)
pattern.Size = UDim2.fromScale(3.4, 6)
pattern.ZIndex = 5
pattern.Parent = clip

local titlePill = Instance.new("Frame")
titlePill.AnchorPoint = Vector2.new(0.5, 0.5)
titlePill.Position = UDim2.fromScale(0.5, 0)
titlePill.Size = UDim2.fromScale(0.66, 0.3)
titlePill.BackgroundColor3 = Color3.new(1, 1, 1)
titlePill.ZIndex = 7
titlePill.Parent = card
corner(titlePill, UDim.new(0, 60))
uistroke(titlePill, 5)
local titleGrad = gradient(titlePill, GOLD_A, GOLD_B)
shadow(titlePill)
local titleText = text(titlePill, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.7), Text = "NEXT QUEST", TextColor3 = BLACK, StrokeColor = Color3.new(1, 1, 1), StrokeTh = 3, ZIndex = 8 })

local bodyText = text(card, { Position = UDim2.fromScale(0.07, 0.2), Size = UDim2.fromScale(0.86, 0.44), Text = "", ZIndex = 7 })

local footPill = Instance.new("Frame")
footPill.AnchorPoint = Vector2.new(0.5, 0.5)
footPill.Position = UDim2.fromScale(0.5, 0.8)
footPill.Size = UDim2.fromScale(0.84, 0.24)
footPill.BackgroundColor3 = Color3.new(1, 1, 1)
footPill.ZIndex = 7
footPill.Parent = card
corner(footPill, UDim.new(0, 60))
uistroke(footPill, 3)
local footGrad = gradient(footPill, Color3.fromRGB(84, 98, 112), Color3.fromRGB(40, 44, 52))
local footText = text(footPill, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.68), Text = "", ZIndex = 8 })

local cardScale = Instance.new("UIScale")
cardScale.Parent = card
local cardOpen = false
local function openCard()
	if cardOpen then return end
	cardOpen = true
	card.Visible = true
	cardScale.Scale = 0.6
	TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
local function closeCard()
	if not cardOpen then return end
	cardOpen = false
	local t = TweenService:Create(cardScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
	t:Play()
	t.Completed:Connect(function() if not cardOpen then card.Visible = false end end)
end

-- title / body / footer; accent colours the title pill (gold by default)
local function render(title, body, foot, accent, footAccent)
	titleText.Text = string.upper(title or "QUEST GUIDE")
	local a = accent or GOLD_A
	titleGrad.Color = accent and ColorSequence.new(a, darker(a, 0.6)) or ColorSequence.new(GOLD_A, GOLD_B)
	bodyText.Text = body or ""
	footPill.Visible = foot ~= nil and foot ~= ""
	footText.Text = foot or ""
	local f = footAccent or Color3.fromRGB(84, 98, 112)
	footGrad.Color = ColorSequence.new(f, darker(f, 0.45))
end

local toastUntil = 0
local renderGuide -- (set below, once the guide exists)

-- a message that shows for a few seconds, then gives way to the guide (if any)
local function showToast(msg, color, seconds, title)
	seconds = seconds or 4
	toastUntil = os.clock() + seconds
	render(title or "QUEST GUIDE", msg, nil, color)
	openCard()
	task.delay(seconds, function()
		if os.clock() + 0.05 < toastUntil then return end -- (a newer message is up)
		if renderGuide and renderGuide() then return end
		closeCard()
	end)
end

-- the card rides along when the quest panel slides away
frame:GetPropertyChangedSignal("Position"):Connect(function()
	card.Position = cardPos()
end)

--------------------------------------------------
-- the guide visuals
--------------------------------------------------
local guide = {
	Quest = nil,        -- the quest being guided to
	Following = nil,    -- the quest we're waiting on (after arriving)
	Folder = nil,
	Beams = {},
	Highlight = nil,
	Tag = nil,
	TagText = nil,
	Target = nil,
	LastPath = 0,
	Points = nil,
}

local folder = Instance.new("Folder")
folder.Name = "QuestGuideFX"
folder.Parent = workspace

local anchor = Instance.new("Part")
anchor.Name = "GuideAnchor"
anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
anchor.Transparency = 1
anchor.Size = Vector3.one
anchor.Parent = folder

local MAX_SEGS = 40
local atts = {}
for i = 1, MAX_SEGS + 1 do
	local a = Instance.new("Attachment")
	a.Parent = anchor
	atts[i] = a
end
for i = 1, MAX_SEGS do
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = atts[i], atts[i + 1]
	b.Texture = "rbxassetid://14582794847" -- (soft glowing dots, flowing towards the NPC)
	b.TextureMode = Enum.TextureMode.Static
	b.TextureLength = 3
	b.TextureSpeed = -1.5
	b.Width0, b.Width1 = 2.4, 2.4
	b.FaceCamera = true
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Brightness = 5
	b.Segments = 1
	b.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), GOLD)
	b.Transparency = NumberSequence.new(0.1)
	b.Enabled = false
	b.Parent = anchor
	guide.Beams[i] = b
end

local function hideVisuals()
	for _, b in ipairs(guide.Beams) do b.Enabled = false end
	if guide.Highlight then guide.Highlight:Destroy() guide.Highlight = nil end
	if guide.Tag then guide.Tag:Destroy() guide.Tag = nil end
	guide.Target = nil
	guide.Points = nil
end

local function stopGuide()
	hideVisuals()
	guide.Quest = nil
	buttonLabel.Text = BUTTON_TEXT
	if os.clock() >= toastUntil then closeCard() end
end

-- the card while guiding: what to do, and where / how far
renderGuide = function()
	if not (guide.Quest and guide.Target) then return false end
	render(guide.Announce or "NEXT QUEST", guide.Hint, guide.Foot, guide.Announce and Color3.fromRGB(120, 230, 120) or nil, guide.FootAccent)
	openCard()
	return true
end

local function rootPart()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function makeTag(obj, name)
	local adornee = obj:IsA("Model") and (obj:FindFirstChild("Head") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or obj
	local bb = Instance.new("BillboardGui")
	bb.Name = "QuestGuideTag"
	bb.AlwaysOnTop = true
	-- small, and high enough to clear the NPC's own name tag / dialogue
	bb.Size = UDim2.fromOffset(132, 30) -- (resized to the screen by fitToScreen below)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	bb.LightInfluence = 0
	bb.Adornee = adornee
	-- (a gold pill like the HUD's titles: black outline, black text with a white edge)
	local pill = Instance.new("Frame")
	pill.Size = UDim2.new(1, -6, 1, -6)
	pill.Position = UDim2.fromOffset(3, 3)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Parent = bb
	corner(pill, UDim.new(0, 60))
	local st = uistroke(pill, 3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	gradient(pill, GOLD_A, GOLD_B)
	local t = text(pill, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -14, 0.72, 0), TextColor3 = BLACK, StrokeColor = Color3.new(1, 1, 1), StrokeTh = 1.5, Text = string.upper(name) })
	bb.Parent = folder
	guide.Tag, guide.TagText = bb, t
end

local function recomputePath(fromPos, toPos)
	local pts
	local ok = pcall(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 })
		path:ComputeAsync(fromPos, toPos)
		if path.Status == Enum.PathStatus.Success then
			pts = {}
			for _, w in ipairs(path:GetWaypoints()) do table.insert(pts, w.Position + Vector3.new(0, 0.6, 0)) end
		end
	end)
	if not ok or not pts or #pts < 2 then
		pts = { fromPos, toPos } -- (no walkable route found: a straight line)
	end
	-- thin it out to the beam budget
	if #pts > MAX_SEGS + 1 then
		local thin = {}
		for i = 1, MAX_SEGS + 1 do
			thin[i] = pts[math.floor((i - 1) / MAX_SEGS * (#pts - 1)) + 1]
		end
		pts = thin
	end
	guide.Points = pts
end

local function drawTrail(fromPos)
	local pts = guide.Points
	if not pts then return end
	-- the first point follows you; the rest is the route
	local n = math.min(#pts, MAX_SEGS + 1)
	local start = 1
	-- skip route points you've already passed
	local best, bestD = 1, math.huge
	for i = 1, n do
		local d = (pts[i] - fromPos).Magnitude
		if d < bestD then best, bestD = i, d end
	end
	start = math.min(best + 1, n)
	local chain = { fromPos - Vector3.new(0, 2.2, 0) }
	for i = start, n do table.insert(chain, pts[i]) end
	for i, b in ipairs(guide.Beams) do
		local p0, p1 = chain[i], chain[i + 1]
		if p0 and p1 then
			atts[i].WorldPosition = p0
			atts[i + 1].WorldPosition = p1
			b.Enabled = true
			-- fade the far end a little, pulse the whole trail
			local pulse = 0.15 + 0.1 * math.sin(os.clock() * 4 - i * 0.5)
			b.Transparency = NumberSequence.new(pulse)
		else
			b.Enabled = false
		end
	end
end

local function guideTo(q, announce)
	hideVisuals()
	guide.Quest = q
	guide.Following = q
	local path, name = targetFor(q)
	local hint = path and ("Go talk to " .. name .. ".") or nil
	if not path then
		-- nothing to walk to (e.g. recite Verity's paper): point at the quest list
		showToast("Check your quest list -- your next step is in there.", Color3.fromRGB(190, 140, 255), 6, "NEXT QUEST")
		guide.Quest = nil
		return
	end
	local obj = find(path)
	if not obj then
		showToast("Couldn't find " .. name .. " right now -- try again in a moment", Color3.fromRGB(255, 110, 90), 4, "HMM...")
		guide.Quest = nil
		return
	end
	guide.Target = obj
	guide.TargetName = name
	guide.Hint = hint
	guide.Island = islandOf(positionOf(obj))
	local hl = Instance.new("Highlight")
	hl.Name = "QuestGuideOutline"
	hl.FillTransparency = 1
	hl.OutlineColor = GOLD
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Adornee = obj
	hl.Parent = folder
	guide.Highlight = hl
	makeTag(obj, name)
	guide.LastPath = 0
	guide.Announce = announce == "next" and "NEW QUEST!" or nil
	guide.Foot = "📍 " .. string.upper(name)
	guide.FootAccent = nil
	toastUntil = 0
	renderGuide()
	if guide.Announce then
		task.delay(4, function() guide.Announce = nil end)
	end
end

--------------------------------------------------
-- the button
--------------------------------------------------
local function findNext(announce)
	local q, lockedOut = pickNext()
	if not q then
		stopGuide()
		guide.Following = nil
		if lockedOut then
			local need = AscensionData.Islands[lockedOut.Island] or 0
			showToast("Your next quest is on " .. lockedOut.Island .. ". Reach " .. need .. " ascensions to go there!", Color3.fromRGB(255, 150, 70), 5, "LOCKED")
		else
			showToast("Every quest is done -- nice work!", Color3.fromRGB(120, 230, 120), 5, "ALL DONE!")
		end
		return
	end
	guideTo(q, announce)
end

do
	local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = frame
	local function to(v, t)
		TweenService:Create(scale, TweenInfo.new(t or 0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = v }):Play()
	end
	button.MouseEnter:Connect(function() to(1.06) end)
	button.MouseLeave:Connect(function() to(1) end)
	button.MouseButton1Down:Connect(function() to(0.92, 0.06) end)
	button.MouseButton1Up:Connect(function() to(1.06) end)
end

button.Activated:Connect(function()
	-- pressing it again while it's guiding (or its card is up) turns it all off
	if guide.Quest or guide.Following or cardOpen then
		stopGuide()
		guide.Following = nil
		toastUntil = 0
		closeCard()
		return
	end
	findNext(true)
end)

--------------------------------------------------
-- every frame: trail, distance, arrival, island checks
--------------------------------------------------
RunService.Heartbeat:Connect(function()
	local q = guide.Quest
	if not q or not guide.Target then return end
	if not guide.Target.Parent then stopGuide() return end
	local root = rootPart()
	if not root then return end
	local here = root.Position
	local there = positionOf(guide.Target)
	local dist = (there - here).Magnitude
	local meters = math.floor(dist + 0.5)
	if guide.TagText then guide.TagText.Text = string.upper(guide.TargetName) .. " • " .. meters .. "m" end
	guide.Foot = "📍 " .. string.upper(guide.TargetName) .. " • " .. meters .. "m"
	guide.FootAccent = nil

	-- on another island: say where to teleport, no trail across the sea
	local myIsland = islandOf(here)
	if myIsland ~= guide.Island then
		for _, b in ipairs(guide.Beams) do b.Enabled = false end
		guide.Points = nil
		guide.Foot = "🌀 TELEPORT TO " .. string.upper(guide.Island)
		guide.FootAccent = Color3.fromRGB(40, 140, 220)
		if os.clock() >= toastUntil then renderGuide() end
		return
	end

	-- arrived
	if dist <= ARRIVE_DIST then
		hideVisuals()
		guide.Quest = nil
		buttonLabel.Text = BUTTON_TEXT
		showToast("Talk to them to see what they need.", Color3.fromRGB(120, 230, 120), 5, "YOU FOUND " .. string.upper(guide.TargetName) .. "!")
		return
	end

	-- keep the route fresh (every couple of seconds, or when you've wandered off it)
	local now = os.clock()
	if not guide.Points or now - guide.LastPath > 2.5 then
		guide.LastPath = now
		task.spawn(recomputePath, here, there)
	end
	drawTrail(here)
	if os.clock() >= toastUntil then renderGuide() end
end)

--------------------------------------------------
-- finished the quest you were following? straight on to the next one
--------------------------------------------------
local function onProgress()
	local f = guide.Following
	if f and f.Done() then
		guide.Following = nil
		task.delay(1.5, function() findNext("next") end)
	end
end
if claimed then
	claimed.ChildAdded:Connect(onProgress)
	claimed.DescendantAdded:Connect(onProgress)
	for _, v in ipairs(claimed:GetChildren()) do
		if v:IsA("ValueBase") then v.Changed:Connect(onProgress) end
	end
	claimed.ChildAdded:Connect(function(v) if v:IsA("ValueBase") then v.Changed:Connect(onProgress) end end)
end
if stats then
	for _, v in ipairs(stats:GetChildren()) do
		if v:IsA("ValueBase") then v.Changed:Connect(onProgress) end
	end
	stats.ChildAdded:Connect(function(v)
		if v:IsA("ValueBase") then v.Changed:Connect(onProgress) end
		onProgress()
	end)
end

script.Destroying:Connect(function() folder:Destroy() end)


--------------------------------------------------
-- keep it all in proportion on every screen: outlines and the NPC tag are
-- pixel sizes, so scale them with the HUD (phones, tablets, 4K, window resizes)
--------------------------------------------------
do
	local master = frame:FindFirstAncestor("master") or frame.Parent
	local BASE_H = 800 -- the screen height everything was designed at
	local function k()
		local h = master.AbsoluteSize.Y
		if h < 1 then return 1 end
		return math.clamp(h / BASE_H, 0.5, 2)
	end
	local function restroke(root)
		for _, st in ipairs(root:GetDescendants()) do
			if st:IsA("UIStroke") then
				local base = st:GetAttribute("_baseTh")
				if not base then base = st.Thickness st:SetAttribute("_baseTh", base) end
				st.Thickness = math.max(1, base * k())
			end
		end
		local own = root:FindFirstChildOfClass("UIStroke")
		if own then
			local base = own:GetAttribute("_baseTh") or own.Thickness
			own:SetAttribute("_baseTh", base)
			own.Thickness = math.max(1, base * k())
		end
	end
	local function fitToScreen()
		restroke(frame)
		if card then restroke(card) end
		local tag = guide.Tag
		if tag and tag.Parent then
			tag.Size = UDim2.fromOffset(math.round(132 * k()), math.round(30 * k()))
			restroke(tag)
		end
	end
	master:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
	folder.DescendantAdded:Connect(function(d)
		if d:IsA("BillboardGui") then task.defer(fitToScreen) end
	end)
	task.defer(fitToScreen)
end
