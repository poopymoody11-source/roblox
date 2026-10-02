--==================================================
-- DEVICE UI SCALE  (client)
--
-- A lot of the game's pop-ups / panels are built by scripts in fixed pixel
-- sizes (pass offers, tutorial, island lock banner, boss bars, admin panel,
-- Cruelty fight HUD, Verity recite...). Pixel sizes that look right on
-- a PC are huge on a phone and run off the screen.
--
-- This finds every "pixel-designed" window in those guis -- the topmost
-- element sized in offset -- and gives it a UIScale that shrinks it to fit the
-- screen. It never scales UP, so PC / tablet look exactly as before; only
-- smaller screens (phones, small windows) get scaled down.
--
-- If the element already has its own UIScale (pop-in animations), that one is
-- multiplied instead, so the animations keep working.
--
-- Works on guis created later too (pop-ups that are built on demand).
--==================================================

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- design reference: what the pixel UIs were built to look right on
local REF_W, REF_H = 960, 600
local MIN_SCALE = 0.5

-- guis that are already scale-based or size themselves to the screen
local SKIP = {
	Screen = true,              -- main HUD: scale-based + aspect lock (HudEdgePin)
	PromptUI = true,            -- billboards, sized in world space
	LapisZoneHighlightGui = true, -- zone border, sizes itself (BoxVisuals)
	LapisUnlockedGui = true,    -- LapisUnlockedPopup scales itself
	KeyHintToast = true,        -- VillagerKeyHints scales itself
	PortalWarp = true,          -- full-screen effect
	Freecam = true,
	PassOffer = true,           -- PromoPopups fits its own cards to the screen
	NowPlaying = true,          -- small music bar: shrinking it made the buttons too small to tap
	TutorialButton = true,
	-- the intro sizes its backdrop to the real screen in pixels every frame;
	-- scaling that shrank it into the top-left corner on phones
	IntroCutscene = true,
	SwingButtonGui = true,      -- Keybinds sizes the phone SWING button off the jump button
	-- Roblox's top bar is a fixed 44px on every device; these sit in it
	AdminTopbarButton = true,
	TitleTopbarButton = true,
}

local factor = 1
local function computeFactor()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(REF_W, REF_H)
	if vp.X < 2 or vp.Y < 2 then return 1 end
	return math.clamp(math.min(vp.X / REF_W, vp.Y / REF_H), MIN_SCALE, 1)
end

-- an element whose size is (mostly) fixed pixels on at least one axis
local function isPixelSized(o)
	if not o:IsA("GuiObject") then return false end
	local s = o.Size
	local pxX = s.X.Scale == 0 and s.X.Offset >= 24
	local pxY = s.Y.Scale == 0 and s.Y.Offset >= 24
	if not (pxX or pxY) then return false end
	-- huge backdrops (bigger than any screen) are meant to overflow; leave them
	if s.X.Offset >= 1000 or s.Y.Offset >= 1000 then return false end
	return true
end

local function insideLayout(o)
	local p = o.Parent
	return p and (p:FindFirstChildWhichIsA("UIListLayout") or p:FindFirstChildWhichIsA("UIGridLayout")
		or p:FindFirstChildWhichIsA("UITableLayout") or p:FindFirstChildWhichIsA("UIPageLayout")) ~= nil
end

-- a whole panel/window, not a small button: small things (~44px) are already
-- the right size for a finger, so they're left alone
local function isPanel(o)
	local s = o.Size
	local pxX = s.X.Scale == 0 and s.X.Offset or 0
	local pxY = s.Y.Scale == 0 and s.Y.Offset or 0
	if pxX > 0 and pxY > 0 then
		return math.max(pxX, pxY) >= 120 and math.min(pxX, pxY) >= 20
	end
	-- one axis follows the screen already; only a tall/wide fixed side matters
	return math.max(pxX, pxY) >= 160
end

-- topmost pixel-sized panel: no pixel-sized ancestor below the ScreenGui
local function isRoot(o, gui)
	if not isPixelSized(o) or not isPanel(o) or insideLayout(o) then return false end
	local a = o.Parent
	while a and a ~= gui do
		if isPixelSized(a) then return false end
		a = a.Parent
	end
	return true
end

-- [GuiObject] = { ui = UIScale, own = bool, base = number }
local scaled = {}
local writing = {}

local function applyTo(entry)
	local ui = entry.ui
	if not ui.Parent then return end
	writing[ui] = true
	ui.Scale = entry.base * factor
	writing[ui] = nil
end

local function piggyback(existing)
	-- an animation scale: keep whatever the animation sets, times our factor
	local entry = { ui = existing, own = false, base = existing.Scale }
	existing:GetPropertyChangedSignal("Scale"):Connect(function()
		if writing[existing] then return end
		entry.base = existing.Scale
		applyTo(entry)
	end)
	return entry
end

local function adopt(o)
	if scaled[o] then return end
	local existing
	for _, c in ipairs(o:GetChildren()) do
		if c:IsA("UIScale") then existing = c break end
	end
	local entry
	if existing then
		entry = piggyback(existing)
	else
		local ui = Instance.new("UIScale")
		ui.Name = "DeviceScale"
		ui.Parent = o
		entry = { ui = ui, own = true, base = 1 }
		-- the owning script added its own (animation) UIScale afterwards: only
		-- one UIScale per element works, so hand over to that one
		local conn
		conn = o.ChildAdded:Connect(function(c)
			if c:IsA("UIScale") and c ~= ui then
				conn:Disconnect()
				ui:Destroy()
				local e = piggyback(c)
				scaled[o] = e
				applyTo(e)
			end
		end)
	end
	scaled[o] = entry
	applyTo(entry)
	o.AncestryChanged:Connect(function()
		if not o:IsDescendantOf(game) then scaled[o] = nil end
	end)
end

local function consider(o, gui)
	if scaled[o] or not o.Parent then return end
	if isRoot(o, gui) then adopt(o) end
end

local function watchGui(gui)
	if not gui:IsA("ScreenGui") or SKIP[gui.Name] then return end
	for _, d in ipairs(gui:GetDescendants()) do consider(d, gui) end
	gui.DescendantAdded:Connect(function(d)
		if not d:IsA("GuiObject") then return end
		-- scripts usually set Size right after parenting; look once it settles,
		-- and again if the size is set a moment later (pop-in from 0)
		task.defer(consider, d, gui)
		local conn
		conn = d:GetPropertyChangedSignal("Size"):Connect(function()
			if scaled[d] then conn:Disconnect() return end
			consider(d, gui)
		end)
		task.delay(3, function() if conn then conn:Disconnect() end end)
	end)
end

factor = computeFactor()
for _, g in ipairs(playerGui:GetChildren()) do task.spawn(watchGui, g) end
playerGui.ChildAdded:Connect(function(g) task.defer(watchGui, g) end)

local function rescaleAll()
	local f = computeFactor()
	if math.abs(f - factor) < 0.001 then return end
	factor = f
	for _, entry in pairs(scaled) do applyTo(entry) end
end
local function hookCamera()
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescaleAll) end
	rescaleAll()
end
hookCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)
