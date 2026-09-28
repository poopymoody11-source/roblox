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

	-- Snap each group so its outermost edge sits MARGIN from the real screen
	-- edge -- the same small gap on every device, whatever its shape.
	local function apply()
		local screenPos, screenSize = screen.AbsolutePosition, screen.AbsoluteSize
		if master.AbsoluteSize.X < 1 or screenSize.Y < 1 then return end
		local margin = math.clamp(math.floor(screenSize.Y * 0.015), 6, 18)
		for _, t in ipairs(targets) do
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
	end

	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	master:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	apply()
	task.delay(1, apply)
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
