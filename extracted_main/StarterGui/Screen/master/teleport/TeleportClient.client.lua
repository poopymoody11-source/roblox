--==================================================
-- TELEPORT CLIENT (REWRITTEN)
--
-- Place in: StarterGui > Screen > master > teleport
-- Type:     LocalScript
--
-- Fully client-side: reads the player's Ascensions stat, checks it
-- against the required amount for each island, and teleports the
-- character directly to the matching part under
-- Workspace.TeleportPoints. No server round-trip.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

print("[TeleportClient] Script starting...")

-- IMPORTANT: WaitForChild with no timeout yields FOREVER if the path
-- is wrong, silently freezing this script before it ever reaches the
-- code that binds the buttons -- no error, nothing in Output, and
-- every teleport button just does nothing forever. Every lookup below
-- now has an explicit timeout and a safe fallback so a missing/renamed
-- instance can never hang the whole script again.

local accessibleModules = ReplicatedStorage:WaitForChild("AccessibleModules", 10)
local ascensionDataModule = accessibleModules and accessibleModules:WaitForChild("AscensionDataModule", 10)

-- Island requirements now come from AscensionDataModule so this GUI,
-- TeleportService's server-side gate and the rebirth panel can't drift
-- apart. The hardcoded table below is only a fallback for when the
-- module is missing or slow to replicate.
local ISLAND_REQUIREMENTS = {
	["67 Island"] = 2,
	["Verity Island"] = 8,
	["LaPeace Island"] = 15,
}

if ascensionDataModule then
	local ok, data = pcall(require, ascensionDataModule)
	if ok and typeof(data) == "table" and typeof(data.Islands) == "table" then
		ISLAND_REQUIREMENTS = data.Islands
		print("[TeleportClient] Island requirements loaded from AscensionDataModule")
	else
		warn("[TeleportClient] AscensionDataModule did not return Islands -- using fallback requirements")
	end
else
	print("[TeleportClient] AscensionDataModule not found -- using fallback island requirements")
end

local teleportPoints = Workspace:WaitForChild("TeleportPoints", 10)
if not teleportPoints then
	warn("[TeleportClient] Could not find Workspace.TeleportPoints within 10s -- teleporting will not work")
end

local gui = script.Parent
local container = gui:WaitForChild("Container", 10)
if not container then
	warn("[TeleportClient] Could not find 'Container' under " .. gui:GetFullName() .. " within 10s -- aborting setup")
	return
end

print("[TeleportClient] Core references loaded, setting up cards...")

--==================================================
-- CARD DEFINITIONS
-- Frame     = name of the card Frame under Container
-- PointName = name of the matching instance under Workspace.TeleportPoints
-- Required  = ascensions needed to unlock (hardcoded -- matches the
--             numbers already shown in the card UI: 0 / 1 / 5 / 25)
--==================================================

local CARDS = {
	{ Frame = "home",    PointName = "Home",           Required = 0 },
	{ Frame = "67",      PointName = "67 Island",      Required = ISLAND_REQUIREMENTS["67 Island"] or 2 },
	{ Frame = "verity",  PointName = "Verity Island",  Required = ISLAND_REQUIREMENTS["Verity Island"] or 8 },
	{ Frame = "lapeace", PointName = "LaPeace Island", Required = ISLAND_REQUIREMENTS["LaPeace Island"] or 15 },
}

--==================================================
-- SOUNDS
-- Same two sounds/volumes used by the shop GUI.
--==================================================

local successSound = Instance.new("Sound")
successSound.SoundId = "rbxassetid://10066947742"
successSound.Volume = 0.15
successSound.Parent = SoundService

local errorSound = Instance.new("Sound")
errorSound.SoundId = "rbxassetid://132281440773764"
errorSound.Volume = 0.08
errorSound.Parent = SoundService

--==================================================
-- FONT AUTO-DETECTION
-- Same approach as the shop: pull whatever font the existing card
-- labels actually use, so the popup always matches the current UI
-- instead of a hardcoded guess.
--==================================================

local notifFont = Enum.Font.FredokaOne
for _, entry in ipairs(container:GetChildren()) do
	local teleportFrame = entry:FindFirstChild("teleport")
	local label = teleportFrame and teleportFrame:FindFirstChildWhichIsA("TextLabel")
	if label then
		notifFont = label.Font
		break
	end
end

--==================================================
-- NOTIFICATION POPUP
-- Same component/animation/stroke as the shop & sell GUIs, just its
-- own instance living under this GUI instead of the shop's.
--==================================================

local notifLabel = gui:FindFirstChild("TeleportNotification")
if not notifLabel then
	notifLabel = Instance.new("TextLabel")
	notifLabel.Name = "TeleportNotification"
	notifLabel.Size = UDim2.new(0.6, 0, 0.06, 0)
	notifLabel.Position = UDim2.new(0.2, 0, 0.03, 0)
	notifLabel.BackgroundTransparency = 1
	notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	notifLabel.TextStrokeTransparency = 1
	notifLabel.RichText = false
	notifLabel.TextScaled = true
	notifLabel.Font = notifFont
	notifLabel.Text = ""
	notifLabel.Visible = false
	notifLabel.ZIndex = 100
	notifLabel.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Parent = notifLabel
end

local activeAnim = nil

local function showNotification(message, isError)
	notifLabel.Text = message
	notifLabel.Font = notifFont

	local stroke = notifLabel:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = Color3.fromRGB(0, 0, 0) end

	if isError then
		notifLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		SoundService:PlayLocalSound(errorSound)
	else
		notifLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
		SoundService:PlayLocalSound(successSound)
	end

	if activeAnim then activeAnim:Cancel() end

	notifLabel.Position = UDim2.new(0.2, 0, 0.01, 0)
	notifLabel.TextTransparency = 1
	if stroke then stroke.Transparency = 1 end
	notifLabel.Visible = true

	local popTween = TweenService:Create(notifLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.2, 0, 0.03, 0),
		TextTransparency = 0
	})

	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	end

	popTween:Play()
	activeAnim = popTween

	task.delay(2, function()
		if notifLabel.Text == message then
			local exitTween = TweenService:Create(notifLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.2, 0, 0.01, 0),
				TextTransparency = 1
			})
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
			exitTween:Play()
			exitTween.Completed:Connect(function()
				if notifLabel.TextTransparency == 1 then
					notifLabel.Visible = false
				end
			end)
		end
	end)
end

--==================================================
-- STAT / TELEPORT HELPERS
--==================================================

local function getAscensions()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return 0 end

	local stat =
		leaderstats:FindFirstChild("Ascensions")
		or leaderstats:FindFirstChild("Rebirths")
		or leaderstats:FindFirstChild("Ascension")

	return stat and stat.Value or 0
end

-- Pulls a usable CFrame out of whatever kind of instance sits under
-- TeleportPoints (BasePart, Attachment, or Model all work).
local function getTeleportCFrame(instance)
	if not instance then return nil end
	if instance:IsA("BasePart") then
		return instance.CFrame
	elseif instance:IsA("Attachment") then
		return instance.WorldCFrame
	elseif instance:IsA("Model") then
		return instance:GetPivot()
	end
	return nil
end

local function teleportPlayerTo(destinationCFrame)
	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not rootPart then return false end

	-- Lift slightly so the character doesn't spawn clipped into the ground.
	rootPart.CFrame = destinationCFrame + Vector3.new(0, 3, 0)
	return true
end

--==================================================
-- CARD SETUP
--==================================================

local cards = {}

--==================================================
-- GAMEPASS ISLAND ACCESS
--
-- This was the actual reason Unlock All Islands and the
-- bundles "didn't save on rebirth": the SERVER gate in
-- TeleportService honoured the pass fine, but this panel
-- only ever looked at the ascension count. It painted the
-- card LOCKED and refused to fire the remote, so the
-- server never got asked. Ascending resets Ascensions to
-- 0, so every rebirth re-locked the islands the player had
-- paid to keep.
--
-- Ownership comes from a replicated attribute, so the
-- answer here is the same one the server will give.
--==================================================

local Monetization do
	local moduleScript = accessibleModules and accessibleModules:FindFirstChild("MonetizationData")
	if moduleScript then
		local ok, result = pcall(require, moduleScript)
		if ok and type(result) == "table" then
			Monetization = result
		end
	end
end

local function hasPassAccess(pointName)
	if not Monetization then return false end
	return Monetization.HasIslandAccess(player, pointName)
end

local function isUnlocked(card)
	return getAscensions() >= card.Required or hasPassAccess(card.PointName)
end

-- islands that opened up while you were playing: always NEW, even if an
-- old save once saw them (a wiped / reset save used to never show it again)
local sessionNew = {}
local statsReady = false

local function refreshCard(card)
	local unlocked = isUnlocked(card)
	if statsReady and card.Unlocked == false and unlocked and card.Key ~= "home" then
		sessionNew[card.Key] = true
	end
	card.Unlocked = unlocked

	if card.Label then
		card.Label.Text = unlocked and "TELEPORT" or "LOCKED"
	end
end

local function refreshAll()
	for _, card in ipairs(cards) do
		refreshCard(card)
	end
end

for _, entry in ipairs(CARDS) do
	local frame = container:FindFirstChild(entry.Frame)
	if not frame then
		warn("[TeleportClient] No card frame named '" .. entry.Frame .. "' under teleport.Container")
		continue
	end

	local teleportFrame = frame:FindFirstChild("teleport")
	if not teleportFrame then
		warn("[TeleportClient] Card '" .. entry.Frame .. "' has no 'teleport' subframe")
		continue
	end

	local imageButton = teleportFrame:FindFirstChildOfClass("ImageButton")
	local label = teleportFrame:FindFirstChildWhichIsA("TextLabel")

	if not imageButton then
		warn("[TeleportClient] Card '" .. entry.Frame .. "' has no ImageButton under its 'teleport' frame")
		continue
	end

	-- Force this button above anything else stacked in the same spot
	-- (highlight overlay, UIStroke, etc.) so clicks can't be silently
	-- swallowed by a sibling with a higher ZIndex sitting on top of it.
	imageButton.ZIndex = math.max(imageButton.ZIndex, 10)

	print("[TeleportClient] Bound button for card:", entry.Frame)

	local card = {
		Key = entry.Frame,
		PointName = entry.PointName,
		Required = entry.Required,
		Label = label,
	}

	imageButton.Activated:Connect(function()
		print("[TeleportClient] Activated fired for card:", card.Key)

		-- Re-check live, not a cached flag, in case the stat changed
		-- since the last refresh.
		local currentAscensions = getAscensions()
		print("[TeleportClient] Ascensions:", currentAscensions, "/ required:", card.Required)

		if not isUnlocked(card) then
			showNotification(string.format("NEED %d ASCENSIONS", card.Required), true)
			return
		end

		-- Ask the SERVER to move you. It knows which plot is yours, so HOME
		-- takes you to your own base (the old client-only teleport always
		-- dropped you at the spawn's Home point), and it applies the same
		-- island gate the island guard uses, so you never get yanked back.
		local tpRemote = ReplicatedStorage:FindFirstChild("AccessibleEvents")
		tpRemote = tpRemote and tpRemote:FindFirstChild("TeleportRequest")
		if tpRemote then
			tpRemote:FireServer(card.Key)
			return
		end

		-- (fallback if the server remote is missing: the old local teleport)
		local destination = teleportPoints and teleportPoints:FindFirstChild(card.PointName)
		local destCFrame = getTeleportCFrame(destination)

		if not destCFrame then
			warn("[TeleportClient] Could not find a usable teleport location for '" .. card.PointName .. "'")
			return
		end

		local success = teleportPlayerTo(destCFrame)
		print("[TeleportClient] Teleport result:", success)

		if success then
			showNotification("TELEPORTED!", false)
		end
		-- Deliberately NOT hiding the panel here -- it stays visible
		-- after a successful teleport, per request.
	end)

	table.insert(cards, card)
end

--==================================================
-- CLOSE BUTTON
--==================================================

local closeButton = gui:FindFirstChild("close")
if closeButton then
	local function attachCloseListener(obj)
		if obj:IsA("GuiButton") then
			obj.Activated:Connect(function()
				container.Visible = false
			end)
		end
	end
	attachCloseListener(closeButton)
	for _, child in ipairs(closeButton:GetDescendants()) do
		attachCloseListener(child)
	end
end

--==================================================
-- STAT WATCHING
--==================================================

local function watchStats()
	local leaderstats = player:WaitForChild("leaderstats", 15)
	if not leaderstats then return end

	local stat =
		leaderstats:FindFirstChild("Ascensions")
		or leaderstats:FindFirstChild("Rebirths")
		or leaderstats:FindFirstChild("Ascension")

	if stat then
		stat.Changed:Connect(refreshAll)
	end

	leaderstats.ChildAdded:Connect(function(child)
		if child.Name == "Ascensions"
			or child.Name == "Rebirths"
			or child.Name == "Ascension" then
			child.Changed:Connect(refreshAll)
			refreshAll()
		end
	end)

	-- Pass ownership lands a second or two after join (the server
	-- has to ask Roblox), and again the instant one is bought, so
	-- the cards have to repaint on that too -- otherwise a player
	-- who buys Unlock All Islands stares at a LOCKED button.
	if Monetization then
		for _, pass in ipairs(Monetization.Passes) do
			local attribute = Monetization.AttributeFor(pass.Key)
			player:GetAttributeChangedSignal(attribute):Connect(refreshAll)
		end
	end

	refreshAll()
	-- (from here on, an island that unlocks is a NEW one - pass ownership
	-- landing a moment after join doesn't count)
	task.delay(4, function()
		refreshAll()
		statsReady = true
	end)
end

refreshAll()
task.spawn(watchStats)

--==================================================
-- MY BASE: straight back to your own plot
--==================================================
do
	local baseBtn = gui:FindFirstChild("MyBaseButton")
	if baseBtn then baseBtn:Destroy() end
	-- styled exactly like the cards' TELEPORT buttons (a copy of one)
	local template = container:FindFirstChild("home") and container.home:FindFirstChild("teleport")
	if template then
		baseBtn = template:Clone()
	else
		baseBtn = Instance.new("Frame")
		baseBtn.BackgroundColor3 = Color3.new(0, 0, 0)
	end
	baseBtn.Name = "MyBaseButton"
	baseBtn.AnchorPoint = Vector2.new(0.5, 0)
	baseBtn.Position = UDim2.fromScale(0.48, 0.825)
	baseBtn.Size = UDim2.fromScale(0.13, 0.06)
	baseBtn.Visible = container.Visible
	baseBtn.ZIndex = 12
	baseBtn.Parent = gui
	local lbl = baseBtn:FindFirstChildWhichIsA("TextLabel")
	if lbl then lbl.Text = "MY BASE" end
	local click = baseBtn:FindFirstChildWhichIsA("GuiButton")
	if not click then
		click = Instance.new("TextButton")
		click.BackgroundTransparency = 1
		click.Text = ""
		click.Size = UDim2.fromScale(1, 1)
		click.Parent = baseBtn
	end
	click.ZIndex = math.max(click.ZIndex, 10)
	container:GetPropertyChangedSignal("Visible"):Connect(function() baseBtn.Visible = container.Visible end)
	click.Activated:Connect(function()
		local ev = ReplicatedStorage:FindFirstChild("AccessibleEvents")
		local r = ev and ev:FindFirstChild("TeleportRequest")
		if r then r:FireServer("base") end
	end)
end

--==================================================
-- SERVER REPLIES  (TeleportService / island guard)
--==================================================
task.spawn(function()
	local events = ReplicatedStorage:WaitForChild("AccessibleEvents", 20)
	local tpRemote = events and events:WaitForChild("TeleportRequest", 20)
	if not tpRemote then return end
	tpRemote.OnClientEvent:Connect(function(ok, msg)
		if ok then
			showNotification("TELEPORTED!", false)
		elseif type(msg) == "string" then
			showNotification(string.upper(msg), true)
		end
	end)
end)

--==================================================
-- "NEW ISLAND!" PILL
-- Same idea as the ASCEND READY pill next to [R]: while an island is
-- open to you that you haven't looked at yet, a pulsing pill sits next
-- to the [T] button. Tapping it (or opening the menu) marks them seen -
-- remembered by the server, so it only ever pops for genuinely new ones.
--==================================================
do
	local icon = gui:FindFirstChild("icon")
	local old = gui:FindFirstChild("IslandReady")
	if old then old:Destroy() end
	local seenRemote = ReplicatedStorage:WaitForChild("IslandSeen", 10)

	local pill = Instance.new("TextButton")
	pill.Name = "IslandReady"
	pill.AnchorPoint = Vector2.new(1, 0.5)
	pill.Size = UDim2.fromScale(0.1, 0.042)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Text = ""
	pill.AutoButtonColor = true
	pill.Visible = false
	pill.ZIndex = 20
	pill.Parent = gui
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0.5, 0)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(120, 210, 255), Color3.fromRGB(40, 120, 230))
	grad.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(10, 30, 70)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = pill
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 3.6
	ar.Parent = pill
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.9)
	label.Position = UDim2.fromScale(0.03, 0.05)
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	label.TextScaled = true
	label.Text = "NEW\u{00A0}ISLAND!"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.ZIndex = 21
	label.Parent = pill
	local ls = Instance.new("UIStroke")
	ls.Thickness = 2
	ls.Color = Color3.fromRGB(10, 30, 70)
	ls.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = pill

	local function place()
		if not icon then
			pill.Position = UDim2.fromScale(0.915, 0.69)
			return
		end
		pill.Position = UDim2.new(
			icon.Position.X.Scale - 0.006, icon.Position.X.Offset,
			icon.Position.Y.Scale + icon.Size.Y.Scale / 2, icon.Position.Y.Offset + icon.Size.Y.Offset / 2)
	end
	place()
	if icon then
		icon:GetPropertyChangedSignal("Position"):Connect(place)
		icon:GetPropertyChangedSignal("Size"):Connect(place)
	end

	local ding = Instance.new("Sound")
	ding.SoundId = "rbxassetid://10066947742"
	ding.Volume = 0.2
	ding.Parent = SoundService

	local pulse = TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 })

	local function seenSet()
		local set = {}
		for k in string.gmatch(player:GetAttribute("SeenIslands") or "", "[^,]+") do set[k] = true end
		return set
	end
	local function unseen()
		local list = {}
		if not player:GetAttribute("SeenIslandsLoaded") then return list end
		local set = seenSet()
		for _, card in ipairs(cards) do
			if card.Key ~= "home" and isUnlocked(card) and (not set[card.Key] or sessionNew[card.Key]) then table.insert(list, card.Key) end
		end
		return list
	end
	local function markSeen()
		local list = unseen()
		if #list > 0 and seenRemote then seenRemote:FireServer(list) end
		for _, k in ipairs(list) do sessionNew[k] = nil end
	end

	local wasShowing = false
	local function update()
		if container.Visible then markSeen() end
		local show = #unseen() > 0 and not container.Visible
		if show and not pill.Visible then
			pill.Visible = true
			scale.Scale = 0
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			task.delay(0.36, function() if pill.Visible then pulse:Play() end end)
			if not wasShowing then SoundService:PlayLocalSound(ding) end
		elseif not show and pill.Visible then
			pulse:Cancel()
			pill.Visible = false
		end
		wasShowing = show
	end

	pill.Activated:Connect(function()
		for _, child in ipairs(gui:GetChildren()) do
			if child:IsA("GuiObject") and child ~= pill and child.Name ~= "icon" and child.Name ~= "keybind"
				and not child.Name:lower():find("notification") then
				child.Visible = true
			end
		end
		markSeen()
		update()
	end)
	container:GetPropertyChangedSignal("Visible"):Connect(update)
	player:GetAttributeChangedSignal("SeenIslands"):Connect(update)
	task.spawn(function()
		while pill.Parent do
			task.wait(0.5)
			pcall(update)
		end
	end)
end
