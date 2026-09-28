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

if ascensionDataModule then
	print("[TeleportClient] Found AscensionDataModule, but ignoring it -- required amounts are hardcoded in CARDS below now (module path was unreliable / took >10s to resolve).")
else
	print("[TeleportClient] AscensionDataModule not found -- fine, not used anymore. Required amounts are hardcoded in CARDS below.")
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
	{ Frame = "67",      PointName = "67 Island",      Required = 1 },
	{ Frame = "verity",  PointName = "Verity Island",  Required = 5 },
	{ Frame = "lapeace", PointName = "LaPeace Island", Required = 25 },
}

--==================================================
-- SOUNDS
-- Same two sounds/volumes used by the shop GUI.
--==================================================

local successSound = Instance.new("Sound")
successSound.SoundId = "rbxassetid://10066947742"
successSound.Volume = 0.25
successSound.Parent = SoundService

local errorSound = Instance.new("Sound")
errorSound.SoundId = "rbxassetid://132281440773764"
errorSound.Volume = 0.12
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

local function refreshCard(card)
	local unlocked = getAscensions() >= card.Required
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

		if currentAscensions < card.Required then
			showNotification(string.format("NEED %d ASCENSIONS", card.Required), true)
			return
		end

		local destination = teleportPoints and teleportPoints:FindFirstChild(card.PointName)
		print("[TeleportClient] Looking for destination:", card.PointName, "-> found:", destination)
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

	refreshAll()
end

refreshAll()
task.spawn(watchStats)