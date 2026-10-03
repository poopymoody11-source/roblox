--==================================================
-- HUD EDGE PIN  (client)
--
-- The whole HUD lives inside Screen > master, which has an aspect-ratio
-- lock (1.745). On any screen that isn't exactly that shape -- ultrawide,
-- most phones, tablets -- master shrinks and centres itself, so the side
-- buttons, the PP counter and the quest panel float in from the real
-- screen edges.
--
-- This slides each edge group back out by exactly the gap between master
-- and the screen, keeping its size (so nothing stretches) and leaving the
-- centred menus alone. Re-runs whenever the screen or master changes size.
--==================================================

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- what to move, and which way: x = -1 left edge / +1 right edge / 0 stay,
-- y = -1 top / +1 bottom / 0 stay. `children` = move only those children
-- (for wrappers that also hold a centred panel).
local PINS = {
	{ path = "OpenInventory", x = 1, y = 0 },
	-- the [F] [R] [T] buttons live inside their menus' wrappers, next to the
	-- centred panels, so only the icon + key badge are moved
	{ path = "RobuxShop", x = 1, y = 0, children = { "icon", "keybind" }, group = true },
	{ path = "rebirth", x = 1, y = 0, children = { "icon", "keybind" }, group = true },
	{ path = "teleport", x = 1, y = 0, children = { "icon", "keybind" }, group = true },
	-- PVP sits centred under the [T] button's icon, not flush with the edge
	{ path = "pvptoggle", x = 1, y = 0, alignTo = { "teleport", "icon" } },
	{ path = "Money", x = -1, y = 1 },
	{ path = "QuestUI", x = -1, y = 0 },
	-- the titles star goes right up into the (empty) top-right corner of the
	-- Roblox top bar, level with the top-bar icons
	{ path = "Titles", x = 1, y = -1, children = { "Frame", "keybind" }, group = true, topbar = true },
}

local function bind(screen)
	local master = screen:WaitForChild("master", 20)
	if not master then return end

	local targets = {}
	for _, pin in ipairs(PINS) do
		local wrapper = master:WaitForChild(pin.path, 10)
		if wrapper then
			if pin.children and pin.group then
				-- move the listed children together, measured as one block
				local members = {}
				for _, name in ipairs(pin.children) do
					local c = wrapper:FindFirstChild(name)
					if c then table.insert(members, { gui = c, base = c.Position }) end
				end
				if #members > 0 then table.insert(targets, { members = members, x = pin.x, y = pin.y, topbar = pin.topbar }) end
			elseif pin.children then
				for _, name in ipairs(pin.children) do
					local c = wrapper:FindFirstChild(name)
					if c then table.insert(targets, { gui = c, x = pin.x, y = pin.y, base = c.Position }) end
				end
			else
				local ref
				if pin.alignTo then
					local w = master:FindFirstChild(pin.alignTo[1])
					ref = w and w:FindFirstChild(pin.alignTo[2])
				end
				table.insert(targets, { gui = wrapper, x = pin.x, y = pin.y, base = wrapper.Position, ref = ref })
			end
		end
	end

	-- the on-screen box a group actually occupies: its own children, whether
	-- or not they're showing yet (the quest panel is hidden until it loads)
	local function bounds(gui)
		local items = {}
		if gui:IsA("GuiObject") and gui.BackgroundTransparency < 1 then table.insert(items, gui) end
		for _, c in ipairs(gui:GetChildren()) do
			if c:IsA("GuiObject") then table.insert(items, c) end
		end
		if #items == 0 then items = { gui } end
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, g in ipairs(items) do
			local p, s = g.AbsolutePosition, g.AbsoluteSize
			minX, minY = math.min(minX, p.X), math.min(minY, p.Y)
			maxX, maxY = math.max(maxX, p.X + s.X), math.max(maxY, p.Y + s.Y)
		end
		return minX, minY, maxX, maxY
	end

	-- PHONES: the right-edge column ([G] [F] [R] [T], PVP - and the ASCEND pill,
	-- which follows the [R] icon) ran down behind Roblox's jump button. Slide
	-- the whole column up until it clears it, but never up into the music
	-- player / ? in the top-right corner.
	local UIS = game:GetService("UserInputService")
	local pg = player:WaitForChild("PlayerGui")
	-- (Roblox reports every gui's AbsolutePosition in the same space, whatever its
	-- IgnoreGuiInset - adding the top-bar inset here put the column ~a top bar
	-- lower than it really was, so it was shoved up into the ? and squashed)
	local function screenRect(g)
		return g.AbsolutePosition, g.AbsoluteSize
	end
	local function avoidJump(targets, margin)
		if not UIS.TouchEnabled then return end
		local touchGui = pg:FindFirstChild("TouchGui")
		local jump = touchGui and touchGui.Enabled and touchGui:FindFirstChild("JumpButton", true)
		if not (jump and jump.Visible and jump.AbsoluteSize.X > 0) then return end
		local jp = screenRect(jump)
		local limitBottom = jp.Y - margin
		-- the top of the room we have: under the ? (or the music player) in the corner
		local limitTop = margin
		for _, name in ipairs({ "TutorialButton", "NowPlaying" }) do
			local g = pg:FindFirstChild(name)
			if g and g.Enabled then
				for _, d in ipairs(g:GetChildren()) do
					if d:IsA("GuiObject") and d.Visible then
						local p, s = screenRect(d)
						limitTop = math.max(limitTop, p.Y + s.Y + margin)
					end
				end
			end
		end
		-- (a clear gap under the ? - it was sitting right on top of the icons)
		limitTop += 10
		-- everything on the right edge, measured as one column (and each piece of it)
		local items = {}
		local minY, maxY = math.huge, -math.huge
		local function add(g)
			if not (g and g.Parent) then return end
			local list = { g }
			for _, c in ipairs(g:GetChildren()) do if c:IsA("GuiObject") and c.Visible then table.insert(list, c) end end
			local top, bottom = math.huge, -math.huge
			for _, x in ipairs(list) do
				if x:IsA("GuiObject") and x.AbsoluteSize.Y > 0 and (x ~= g or g.BackgroundTransparency < 1 or #list == 1) then
					local p, s = screenRect(x)
					top, bottom = math.min(top, p.Y), math.max(bottom, p.Y + s.Y)
				end
			end
			if top == math.huge then return end
			table.insert(items, { G = g, Top = top, Bottom = bottom })
			minY, maxY = math.min(minY, top), math.max(maxY, bottom)
		end
		for _, t in ipairs(targets) do
			if t.x > 0 and not t.topbar then
				if t.members then
					for _, m in ipairs(t.members) do add(m.gui) end
				else
					add(t.gui)
				end
			end
		end
		if #items == 0 then return end
		-- already clear of both the jump button and the ?: leave it be
		if maxY <= limitBottom and minY >= limitTop then return end
		-- fit the column between the ? and the jump button: slide it, and if it's
		-- still too tall, close up the gaps between the icons (sizes stay the same)
		local room = limitBottom - limitTop
		local height = maxY - minY
		local newTop
		if height <= room then
			-- fits: as low as it was, but inside the room
			newTop = math.clamp(minY, limitTop, limitBottom - height)
		else
			newTop = limitTop
		end
		-- squeeze: spread each piece's top over the room (the last piece ends at the jump button)
		local lastTop, lastH = minY, 0
		for _, it in ipairs(items) do
			if it.Top >= lastTop then lastTop, lastH = it.Top, it.Bottom - it.Top end
		end
		local span = lastTop - minY
		local k = 1
		if height > room and span > 0 then
			k = math.clamp((room - lastH) / span, 0.72, 1)
		end
		for _, it in ipairs(items) do
			local want = newTop + (it.Top - minY) * k
			it.G.Position += UDim2.fromOffset(0, math.round(want - it.Top))
		end
	end

	-- Snap each group so its outermost edge sits MARGIN from the real screen
	-- edge -- the same small gap on every device, whatever its shape.
	-- onlyRight: re-place just the right-edge column (the once-a-second phone
	-- check). The left side is left alone - re-measuring the quest panel while
	-- it's slid away dragged it back into the middle of the screen.
	local function apply(onlyRight)
		local screenPos, screenSize = screen.AbsolutePosition, screen.AbsoluteSize
		if master.AbsoluteSize.X < 1 or screenSize.Y < 1 then return end
		local margin = math.clamp(math.floor(screenSize.Y * 0.015), 6, 18)
		for _, t in ipairs(targets) do
			if onlyRight and not (t.x > 0 and not t.topbar) then continue end
			if t.members then
				local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
				for _, m in ipairs(t.members) do
					m.gui.Position = m.base
					local p, s = m.gui.AbsolutePosition, m.gui.AbsoluteSize
					minX, minY = math.min(minX, p.X), math.min(minY, p.Y)
					maxX, maxY = math.max(maxX, p.X + s.X), math.max(maxY, p.Y + s.Y)
				end
				local dx = (t.x > 0) and ((screenPos.X + screenSize.X - margin) - maxX) or ((t.x < 0) and ((screenPos.X + margin) - minX) or 0)
				local dy = 0
				if t.topbar then
					-- centre the block on the top-bar row (the inset area above the GUI)
					local inset = GuiService:GetGuiInset().Y
					local rowCentre = screenPos.Y - inset / 2
					dy = rowCentre - (minY + maxY) / 2
					if inset < 8 then dy = (screenPos.Y + margin) - minY end
				elseif t.y < 0 then
					dy = (screenPos.Y + margin) - minY
				elseif t.y > 0 then
					dy = (screenPos.Y + screenSize.Y - margin) - maxY
				end
				for _, m in ipairs(t.members) do
					m.gui.Position = m.base + UDim2.fromOffset(math.round(dx), math.round(dy))
				end
			end
			local g = t.gui
			if g and g.Parent then
				g.Position = t.base -- measure from the designed spot
				local minX, minY, maxX, maxY = bounds(g)
				local dx, dy = 0, 0
				if t.ref and t.ref.Parent then
					local rp, rs = t.ref.AbsolutePosition, t.ref.AbsoluteSize
					dx = (rp.X + rs.X / 2) - (minX + maxX) / 2
					-- never let it poke past the edge margin
					local over = (maxX + dx) - (screenPos.X + screenSize.X - margin)
					if over > 0 then dx -= over end
				elseif t.x < 0 then
					dx = (screenPos.X + margin) - minX
				elseif t.x > 0 then
					dx = (screenPos.X + screenSize.X - margin) - maxX
				end
				if t.y < 0 then
					dy = (screenPos.Y + margin) - minY
				elseif t.y > 0 then
					dy = (screenPos.Y + screenSize.Y - margin) - maxY
				end
				g.Position = t.base + UDim2.fromOffset(math.round(dx), math.round(dy))
			end
		end
		avoidJump(targets, margin)
	end

	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	master:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	apply()
	task.delay(1, apply)
	-- (phones: the jump button / music player can appear or move after load)
	if UIS.TouchEnabled then
		task.spawn(function()
			while screen.Parent do
				task.wait(1)
				apply(true)
			end
		end)
	end
end

-- Screen has ResetOnSpawn on some setups; rebind whenever a fresh copy appears
local current
local function watch(child)
	if child.Name == "Screen" and child:IsA("ScreenGui") and child ~= current then
		current = child
		task.spawn(bind, child)
	end
end
for _, c in ipairs(playerGui:GetChildren()) do watch(c) end
playerGui.ChildAdded:Connect(watch)
