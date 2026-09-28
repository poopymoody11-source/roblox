--==================================================
-- TITLES CLIENT
--
-- Drives the ★ button and the titles panel. The title
-- itself shows as a chat tag (TitleChatTag) and an aura
-- (TitleAura); this is just the picker.
--
-- Server contract (AccessibleEvents.TitleRemote):
--   -> "GetState" / "Equip", id / "AutoBest" / "ToggleAura"
--   <- "State", {Unlocked, Equipped, ManualPick, AuraEnabled}
--   <- "Unlocked", id
--   <- "Error", message
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

local TitleData = require(
	ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("TitleDataModule")
)

local events = ReplicatedStorage:WaitForChild("AccessibleEvents")
local titleRemote = events:WaitForChild("TitleRemote")

local root = script.Parent
local button = root:WaitForChild("Frame")
local clickTarget = button:WaitForChild("Click")
local container = root:WaitForChild("Container")
local list = container:WaitForChild("list")
local template = container:WaitForChild("template")
local closeButton = container:WaitForChild("close")
local autoButton = container:WaitForChild("auto")
local auraButton = container:WaitForChild("aura")

local FONT_BOLD = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local state = {
	Unlocked = {},
	Equipped = TitleData.DefaultTitle,
	ManualPick = false,
	AuraEnabled = true,
}
local rows = {}

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://6895079853"
clickSound.Volume = 0.12
clickSound.Parent = SoundService

local successSound = Instance.new("Sound")
successSound.SoundId = "rbxassetid://10066947742"
successSound.Volume = 0.15
successSound.Parent = SoundService

--==================================================
-- TOAST
--==================================================

local CinematicFx do
	local modules = game:GetService("ReplicatedStorage"):FindFirstChild("AccessibleModules")
	local moduleScript = modules and modules:FindFirstChild("CinematicFx")
	if moduleScript then
		local ok, result = pcall(require, moduleScript)
		if ok then CinematicFx = result end
	end
end

local function toast(text, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.3, 0, 0.055, 0)
	label.Position = UDim2.new(0.35, 0, 0.14, 0)
	label.BackgroundColor3 = Color3.fromRGB(25, 22, 30)
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.FontFace = FONT_BOLD
	label.Text = text
	label.TextScaled = true
	label.ZIndex = 200
	label.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label

	task.delay(2.5, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.4), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

--==================================================
-- LIST
--==================================================

local function sortedTitles()
	local sorted = table.clone(TitleData.Titles)
	table.sort(sorted, function(a, b)
		if a.Rank ~= b.Rank then return a.Rank > b.Rank end
		return a.Order < b.Order
	end)
	return sorted
end

local function build()
	for _, row in pairs(rows) do
		row:Destroy()
	end
	table.clear(rows)

	for index, title in ipairs(sortedTitles()) do
		if title.Hidden and state.Unlocked[title.Id] ~= true then continue end
		local row = template:Clone()
		row.Name = title.Id
		row.LayoutOrder = index
		row.Visible = true
		row.Parent = list

		local unlocked = state.Unlocked[title.Id] == true
		local equipped = state.Equipped == title.Id
		local color = TitleData.GetColor(title.Id)
		local auraKey = TitleData.GetAura(title.Id)

		row.titleName.Text = unlocked and title.Name or "???"
		row.titleName.TextColor3 = unlocked and color or Color3.fromRGB(120, 120, 130)

		local desc = title.Description
		if auraKey then
			desc = desc .. "   [" .. string.upper(tostring(auraKey)) .. " AURA]"
		end
		row.desc.Text = desc
		row.Accent.Color = unlocked and color or Color3.new(0, 0, 0)

		local equipButton = row.equip
		if not unlocked then
			equipButton.Text = "LOCKED"
			equipButton.BackgroundColor3 = Color3.fromRGB(70, 65, 80)
		elseif equipped then
			equipButton.Text = "EQUIPPED"
			equipButton.BackgroundColor3 = Color3.fromRGB(150, 115, 40)
		else
			equipButton.Text = "EQUIP"
			equipButton.BackgroundColor3 = Color3.fromRGB(70, 110, 70)
		end

		equipButton.Activated:Connect(function()
			if not unlocked then
				toast("YOU HAVEN'T UNLOCKED THAT YET", Color3.fromRGB(255, 120, 120))
				return
			end
			if equipped then return end
			SoundService:PlayLocalSound(clickSound)
			titleRemote:FireServer("Equip", title.Id)
		end)

		rows[title.Id] = row
	end

	autoButton.Text = state.ManualPick and "AUTO: OFF" or "AUTO: BEST"
	autoButton.BackgroundColor3 = state.ManualPick
		and Color3.fromRGB(90, 85, 100)
		or Color3.fromRGB(70, 110, 70)

	auraButton.Text = state.AuraEnabled and "AURA: ON" or "AURA: OFF"
	auraButton.BackgroundColor3 = state.AuraEnabled
		and Color3.fromRGB(110, 80, 150)
		or Color3.fromRGB(90, 85, 100)
end

--==================================================
-- OPEN / CLOSE
--==================================================

local function setOpen(open)
	container.Visible = open
	if open then
		titleRemote:FireServer("GetState")
		build()
	end
end

clickTarget.Activated:Connect(function()
	SoundService:PlayLocalSound(clickSound)
	setOpen(not container.Visible)
end)

--==================================================
-- TOPBAR BUTTON
-- The old ★ button in the top-right was sized in screen
-- percentages on both axes, so it stretched and squashed on
-- every screen shape. It's now a fixed-size round button in
-- Roblox's topbar, right after the chat button (the admin
-- panel's ⚙ moves one slot over for people who have it).
-- Sized off TopbarInset, so it fits PC, phone, tablet and
-- console alike.
--==================================================
button.Visible = false
local keybindHint = root:FindFirstChild("keybind")
if keybindHint then keybindHint.Visible = false end

do
	local GuiService = game:GetService("GuiService")
	local playerGui = player:WaitForChild("PlayerGui")
	-- (this script re-runs on respawn; the topbar gui doesn't reset)
	local old = playerGui:FindFirstChild("TitleTopbarButton")
	if old then old:Destroy() end
	local topGui = Instance.new("ScreenGui")
	topGui.Name = "TitleTopbarButton"
	topGui.IgnoreGuiInset = true
	topGui.ResetOnSpawn = false
	topGui.DisplayOrder = 90
	topGui.Parent = playerGui

	local b = Instance.new("TextButton")
	b.Name = "TitlesButton"
	b.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	b.BackgroundTransparency = 0.3
	b.Text = "\u{2605}"
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.fromRGB(255, 205, 60)
	b.AutoButtonColor = true
	b.Parent = topGui
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	local pad = Instance.new("UIPadding", b)
	pad.PaddingTop = UDim.new(0.2, 0)
	pad.PaddingBottom = UDim.new(0.2, 0)
	pad.PaddingLeft = UDim.new(0.2, 0)
	pad.PaddingRight = UDim.new(0.2, 0)
	local st = Instance.new("UIStroke", b)
	st.Color = Color3.fromRGB(255, 205, 60)
	st.Thickness = 1.5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local function place()
		local inset = GuiService.TopbarInset
		local h = inset.Height > 0 and inset.Height or 58
		local size = math.clamp(h - 14, 32, 44)
		b.Size = UDim2.fromOffset(size, size)
		b.Position = UDim2.fromOffset((inset.Min.X > 0 and inset.Min.X or 164) + 4, math.floor((h - size) / 2))
	end
	place()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)

	local tip = Instance.new("TextLabel")
	tip.BackgroundTransparency = 1
	tip.Position = UDim2.new(0.5, 0, 1, 2)
	tip.AnchorPoint = Vector2.new(0.5, 0)
	tip.Size = UDim2.fromOffset(90, 16)
	tip.Font = Enum.Font.GothamBold
	tip.TextSize = 12
	tip.TextColor3 = Color3.new(1, 1, 1)
	tip.TextStrokeTransparency = 0.4
	tip.Text = UserInputService.KeyboardEnabled and "TITLES [Y]" or "TITLES"
	tip.Visible = false
	tip.Parent = b
	b.MouseEnter:Connect(function() tip.Visible = true end)
	b.MouseLeave:Connect(function() tip.Visible = false end)
	b.Activated:Connect(function()
		SoundService:PlayLocalSound(clickSound)
		setOpen(not container.Visible)
	end)

	-- (hidden during cutscenes by CinematicHud, like the rest of the HUD.
	-- This script used to ALSO toggle it; the two raced, and CinematicHud
	-- could "restore" it to hidden after a cutscene.)
end

closeButton.Activated:Connect(function()
	SoundService:PlayLocalSound(clickSound)
	setOpen(false)
end)

autoButton.Activated:Connect(function()
	SoundService:PlayLocalSound(clickSound)
	titleRemote:FireServer("AutoBest")
end)

auraButton.Activated:Connect(function()
	SoundService:PlayLocalSound(clickSound)
	titleRemote:FireServer("ToggleAura")
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Y then
		setOpen(not container.Visible)
	end
end)

--==================================================
-- SERVER MESSAGES
--==================================================

titleRemote.OnClientEvent:Connect(function(action, payload)
	if action == "State" then
		state.Unlocked = {}
		for _, id in ipairs(payload.Unlocked or {}) do
			state.Unlocked[id] = true
		end
		state.Equipped = payload.Equipped or TitleData.DefaultTitle
		state.ManualPick = payload.ManualPick == true
		state.AuraEnabled = payload.AuraEnabled ~= false
		if container.Visible then
			build()
		end

	elseif action == "Unlocked" then
		local title = TitleData.ById[payload]
		if title then
			SoundService:PlayLocalSound(successSound)

			-- The grey toast this used to be was the same notice a
			-- failed equip got. Unlocking a title is a moment, so it
			-- gets the full card: rarity-tinted rays, a flare and the
			-- name. Falls back to the toast if the module is missing.
			if CinematicFx then
				CinematicFx.TitleUnlock(title.Name, title.Rarity, TitleData.GetColor(payload))
			else
				toast("TITLE UNLOCKED: " .. string.upper(title.Name), TitleData.GetColor(payload))
			end
		end

	elseif action == "Error" then
		toast(tostring(payload), Color3.fromRGB(255, 120, 120))
	end
end)

container.Visible = false
titleRemote:FireServer("GetState")
