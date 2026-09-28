--==================================================
-- QUEST UI  (tracker + slide toggle)
--
-- Lists every quest on the left of the screen with live
-- progress (lapis counts, key found, etc.). Finished
-- quests drop to the bottom with a tick. Starts OPEN;
-- the arrow tab slides it off screen and back.
--==================================================

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = script.Parent
local frame = gui:WaitForChild("Frame")
local openCloseFrame = gui:WaitForChild("open/close")
local titleFrame = gui:WaitForChild("title")
local list = frame:WaitForChild("ScrollingFrame")
local findQuest = gui:WaitForChild("findquest", 10) -- (the 🧭 FIND NEXT QUEST pill slides with the panel)

local arrowButton = openCloseFrame:WaitForChild("ImageButton")
local staffsLabel = openCloseFrame:WaitForChild("Staffs")

local TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

if gui:IsA("LayerCollector") then gui.Enabled = true else gui.Visible = true end
for _, child in ipairs(gui:GetChildren()) do
	if child:IsA("GuiObject") and child.Name ~= "GuideToast" then child.Visible = true end
end

--------------------------------------------------
-- quests
--------------------------------------------------
local stats = player:WaitForChild("PlayerStats", 30)
local claimed = stats and stats:WaitForChild("ClaimedQuests", 30)
local started = stats and stats:WaitForChild("StartedQuests", 30)
local lapis = stats and stats:WaitForChild("Lapis", 30)

local function lapisCount(name)
	local v = lapis and lapis:FindFirstChild(name)
	return v and v.Value or 0
end
local function isClaimed(name)
	local v = claimed and claimed:FindFirstChild(name)
	return v ~= nil and v.Value ~= false
end
local function isStarted(name)
	return started ~= nil and started:FindFirstChild(name) ~= nil
end
local function statFlag(name)
	local v = stats and stats:FindFirstChild(name)
	if not v then return false end
	if v:IsA("BoolValue") then return v.Value end
	return true
end
local function hasTool(name)
	local bp = player:FindFirstChild("Backpack")
	return (bp and bp:FindFirstChild(name)) or (player.Character and player.Character:FindFirstChild(name))
end

-- Text / done / progress for each quest, in story order.
-- (declared first: DungeonReturn's text walks this same list)
local QUESTS
QUESTS = {
	{
		Id = "HomelessQuest",
		Text = function() return "Find the hobo's lost pet rat" end,
		Done = function() return isClaimed("HomelessQuest") end,
	},
	{
		Id = "ToiletQuest",
		Text = function()
			return "Bring the hungry guy some \"food\" [" .. (hasTool("Poop") and 1 or 0) .. "/1]"
		end,
		Done = function() return isClaimed("ToiletQuest") end,
	},
	{
		Id = "TungQuest",
		Text = function() return "Bring Tung 25 Gold Lapis [" .. math.min(lapisCount("golden_lapis"), 25) .. "/25]" end,
		Done = function() return isClaimed("TungQuest") end,
	},
	{
		Id = "CarKeyQuest",
		Text = function()
			return "Find the keys dropped in the obby [" .. (statFlag("hasCarKey") and 1 or 0) .. "/1]"
		end,
		Done = function() return isClaimed("CarKeyQuest") end,
	},
	{
		Id = "VillagerQuest",
		Text = function() return "Bring Mr Villager 10 lapis from 67 Island [" .. math.min(lapisCount("67_lapis") + lapisCount("hell_lapis") + lapisCount("totem_lapis"), 10) .. "/10]" end,
		Done = function() return statFlag("cangoin") end,
	},
	{
		Id = "VerityQuest",
		Text = function() return "Gather 20 Verity Lapis for Verity [" .. math.min(lapisCount("verity_lapis"), 20) .. "/20]" end,
		Done = function() return isClaimed("VerityQuest") end,
	},
	{
		Id = "VerityQuest2",
		After = "VerityQuest",
		Text = function() return "Equip Verity's paper and recite his words" end,
		Done = function() return isClaimed("VerityQuest2") end,
	},
	{
		Id = "VerityQuest3",
		After = "VerityQuest2",
		Text = function()
			if statFlag("defeatedCruelty") then return "Go back to Verity for your reward" end
			return "Enter the portal and face whatever is inside"
		end,
		Done = function() return isClaimed("VerityQuest3") end,
	},
	-- The dungeon behind Mr Villager's house. These two are the finale, so
	-- they don't count towards "finish every quest".
	{
		Id = "DungeonDoor",
		Finale = true,
		Visible = function() return statFlag("cangoin") end,
		Text = function() return "Open the dungeon door on 67 Island (grab the Villager Key from his house)" end,
		Done = function() return isClaimed("DungeonDoor") end,
	},
	{
		Id = "DungeonReturn",
		Finale = true,
		Visible = function() return isClaimed("DungeonDoor") end,
		Text = function()
			local n, total = 0, 0
			for _, q in ipairs(QUESTS) do
				if not q.Finale then
					total += 1
					if q.Done() then n += 1 end
				end
			end
			if n >= total then return "Everything's done. Go back into the dungeon on 67 Island" end
			return "Finish every quest, then come back to the dungeon on 67 Island [" .. n .. "/" .. total .. "]"
		end,
		Done = function() return isClaimed("DungeonReturn") end,
	},
}

-- Only quests you've talked to the giver about (or finished) are listed.
-- Follow-up quests appear once the previous step is done.
local function isVisible(q)
	if q.Visible then return q.Visible() or q.Done() end
	if q.Done() or isStarted(q.Id) or isClaimed(q.Id) then return true end
	return q.After ~= nil and isClaimed(q.After)
end

-- the label already in the list is the style template
local template = list:FindFirstChildWhichIsA("TextLabel")
if template then template.Parent = nil end

local rows = {}
local function makeRow(q)
	local row
	if template then
		row = template:Clone()
	else
		row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.TextScaled = true
		row.Font = Enum.Font.FredokaOne
		row.TextColor3 = Color3.new(1, 1, 1)
	end
	row.Name = "Quest_" .. q.Id
	row.Size = UDim2.new(0.94, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.None
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextWrapped = true
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 4.2
	ar.AspectType = Enum.AspectType.ScaleWithParentSize
	ar.DominantAxis = Enum.DominantAxis.Width
	ar.Parent = row
	row.Parent = list
	rows[q.Id] = row
	return row
end

local function refresh()
	-- drop labels other scripts dropped into the list (the old Verity one)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("TextLabel") and not c.Name:match("^Quest_") then c:Destroy() end
	end
	local order = 0
	local shownCount = 0
	for _, q in ipairs(QUESTS) do
		local row = rows[q.Id]
		local vis = isVisible(q)
		if vis then shownCount += 1 end
		if row then row.Visible = vis end
	end
	-- unfinished first, then finished
	for pass = 1, 2 do
		for _, q in ipairs(QUESTS) do
			local done = q.Done()
			if isVisible(q) and ((pass == 1 and not done) or (pass == 2 and done)) then
				order += 1
				local row = rows[q.Id] or makeRow(q)
				row.LayoutOrder = order
				if done then
					row.Text = "✅ - " .. q.Text():gsub("%s*%[.-%]$", "")
					row.TextColor3 = Color3.fromRGB(140, 230, 140)
					row.TextTransparency = 0.35
				else
					row.Text = "☐ - " .. q.Text()
					row.TextColor3 = Color3.fromRGB(255, 255, 255)
					row.TextTransparency = 0
				end
			end
		end
	end
	-- banner row: all quests unlock the final (Bossfight) base upgrade
	local doneCount, mainCount = 0, 0
	for _, q in ipairs(QUESTS) do
		if not q.Finale then
			mainCount += 1
			if q.Done() then doneCount += 1 end
		end
	end
	local banner = rows.__banner or makeRow({ Id = "FinalGate" })
	rows.__banner = banner
	banner.LayoutOrder = 0
	if doneCount >= mainCount and isClaimed("DungeonReturn") then
		banner.Text = "🔓 Final upgrade unlocked -- buy it at your base!"
		banner.TextColor3 = Color3.fromRGB(255, 220, 90)
	elseif doneCount >= mainCount then
		banner.Text = "🔒 Go back into the dungeon to unlock the final upgrade"
		banner.TextColor3 = Color3.fromRGB(200, 150, 255)
	elseif shownCount == 0 then
		banner.Text = "💬 Talk to people around the island to find quests!"
		banner.TextColor3 = Color3.fromRGB(180, 220, 255)
	else
		banner.Text = "🔒 Finish every quest (and the dungeon) to unlock the final upgrade (" .. doneCount .. "/" .. mainCount .. ")"
		banner.TextColor3 = Color3.fromRGB(255, 200, 120)
	end
	banner.TextTransparency = 0

	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then layout.SortOrder = Enum.SortOrder.LayoutOrder end
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
end

local queued = false
local function queueRefresh()
	if queued then return end
	queued = true
	task.delay(0.1, function()
		queued = false
		refresh()
	end)
end

refresh()
if lapis then
	for _, v in ipairs(lapis:GetChildren()) do v.Changed:Connect(queueRefresh) end
	lapis.ChildAdded:Connect(function(v) v.Changed:Connect(queueRefresh) queueRefresh() end)
end
if started then
	started.ChildAdded:Connect(queueRefresh)
	started.ChildRemoved:Connect(queueRefresh)
end
if claimed then
	claimed.ChildAdded:Connect(queueRefresh)
	claimed.DescendantAdded:Connect(queueRefresh)
	claimed.ChildRemoved:Connect(queueRefresh)
end
if stats then
	stats.ChildAdded:Connect(function(v)
		if v:IsA("ValueBase") then v.Changed:Connect(queueRefresh) end
		queueRefresh()
	end)
	for _, v in ipairs(stats:GetChildren()) do
		if v:IsA("ValueBase") then v.Changed:Connect(queueRefresh) end
	end
end
list.ChildAdded:Connect(function(c)
	if c:IsA("TextLabel") and not c.Name:match("^Quest_") then queueRefresh() end
end)
local function watchBag(bag)
	if not bag then return end
	bag.ChildAdded:Connect(queueRefresh)
	bag.ChildRemoved:Connect(queueRefresh)
end
watchBag(player:FindFirstChild("Backpack"))
player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then watchBag(c) end end)
player.CharacterAdded:Connect(function(ch) watchBag(ch) queueRefresh() end)
if player.Character then watchBag(player.Character) end

--------------------------------------------------
-- slide toggle (starts OPEN, on screen)
--------------------------------------------------
local openPositions = {
	Frame = frame.Position,
	Title = titleFrame.Position,
	Button = openCloseFrame.Position,
	Find = findQuest and findQuest.Position,
}

local isOpen = true
staffsLabel.Text = "<"

local function getSlideOffset()
	local slideDistance = frame.AbsoluteSize.X + frame.AbsolutePosition.X + 5
	return UDim2.fromOffset(-slideDistance, 0)
end

local function toggleUI()
	isOpen = not isOpen
	local offset = isOpen and UDim2.new() or getSlideOffset()
	staffsLabel.Text = isOpen and "<" or ">"
	TweenService:Create(frame, TWEEN_INFO, { Position = openPositions.Frame + offset }):Play()
	TweenService:Create(titleFrame, TWEEN_INFO, { Position = openPositions.Title + offset }):Play()
	TweenService:Create(openCloseFrame, TWEEN_INFO, { Position = openPositions.Button + offset }):Play()
	if findQuest then TweenService:Create(findQuest, TWEEN_INFO, { Position = openPositions.Find + offset }):Play() end
end

arrowButton.Activated:Connect(toggleUI)

player:GetAttributeChangedSignal("QuestsRefresh"):Connect(queueRefresh)

--------------------------------------------------
-- ON JOIN: the list is open, and FIND NEXT QUEST glows red until you use it
--------------------------------------------------
task.defer(function()
	if not isOpen then toggleUI() end
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "GuideToast" then child.Visible = true end
	end
end)
if findQuest and not player:GetAttribute("SawFindQuest") then
	local st = Instance.new("UIStroke")
	st.Name = "RedHint"
	st.Color = Color3.fromRGB(255, 40, 40)
	st.Thickness = 3
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = findQuest
	local pulse = TweenService:Create(st, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 6, Transparency = 0.25 })
	pulse:Play()
	local function clear()
		player:SetAttribute("SawFindQuest", true)
		pulse:Cancel()
		if st.Parent then st:Destroy() end
	end
	if findQuest:IsA("GuiButton") then findQuest.Activated:Connect(clear) end
	for _, b in ipairs(findQuest:GetDescendants()) do
		if b:IsA("GuiButton") then b.Activated:Connect(clear) end
	end
end
