--==================================================
-- LAPIS VISUALS & COLLECTION CLIENT SCRIPT (Custom Themes)
-- Place as a LocalScript in StarterPlayerScripts
--==================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local spawnedLapis = Workspace:WaitForChild("SpawnedLapis", 10)

-- A signature pickup sound per lapis type (rarer = more dramatic).
-- Anything not listed falls back to the three coin sounds below.
local LAPIS_SOUNDS = {
	golden_lapis       = { Id = "rbxassetid://4612374807",   Volume = 0.6 },  -- coin
	diamond_lapis      = { Id = "rbxassetid://4612374036",   Volume = 0.6 },  -- bling
	emerald_lapis      = { Id = "rbxassetid://128010120465897", Volume = 0.6 }, -- gem sparkle
	rgb_lapis          = { Id = "rbxassetid://121240128098228", Volume = 0.6 }, -- sparkles
	totem_lapis        = { Id = "rbxassetid://125318004836003", Volume = 0.6 }, -- drum bounce
	hell_lapis         = { Id = "rbxassetid://9114446852",   Volume = 0.5 },  -- fire whoosh
	["67_lapis"]       = { Id = "rbxassetid://2772396665",   Volume = 0.5 },  -- boing
	malevolent_lapis   = { Id = "rbxassetid://71223034565178", Volume = 0.5 }, -- void
	interstellar_lapis = { Id = "rbxassetid://124047596872022", Volume = 0.55 }, -- cosmic pull
}

-- Everything here was far too loud when you're vacuuming up hundreds of
-- lapis; every pickup sound is scaled by this.
local PICKUP_VOLUME_SCALE = 0.14
-- the special per-lapis sounds are rarer and several are quiet recordings,
-- so they get more headroom than the everyday coin clinks
local SPECIAL_VOLUME_SCALE = 0.32
-- Magnet staffs pull in a dozen lapis in the same frame; without a gap
-- the sounds stack into one loud blast.
local MIN_SOUND_GAP = 0.08
local lastSoundAt = 0

-- One reusable Sound per id instead of a new instance every pickup
-- (less garbage + less lag when vacuuming hundreds of lapis).
local soundCache = {}
local function getSound(id, volume, special)
	local key = id .. "@" .. volume
	local s = soundCache[key]
	if not s then
		s = Instance.new("Sound")
		s.Name = "PickupSfx"
		s.SoundId = id
		s.Volume = volume * (special and SPECIAL_VOLUME_SCALE or PICKUP_VOLUME_SCALE)
		s.Parent = SoundService
		soundCache[key] = s
	end
	return s
end

local function formatPP(n)
	n = math.floor(n or 0)
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in ipairs(units) do
		if n >= u[1] then
			return (("%.1f"):format(n / u[1]):gsub("%.0$", "")) .. u[2]
		end
	end
	return tostring(n)
end

local lastSpecialAt = {} -- [id] = os.clock()
local function playPickupSound(lapisName)
	-- Settings billboard: "Lapis Sound" off mutes pickups
	if player:GetAttribute("Set_LapisSound") == false then return end

	local now = os.clock()
	local special = lapisName == "verity_lapis" or lapisName == "lapeace_lapis" or LAPIS_SOUNDS[lapisName] ~= nil
	-- The anti-spam gap used to be shared by EVERY pickup, so a rare lapis
	-- grabbed a split second after a normal one (magnets!) never made its
	-- sound. Now only the coin clinks share the gap; each special sound
	-- just can't restart itself more than a few times a second.
	if not special then
		if now - lastSoundAt < MIN_SOUND_GAP then return end
		lastSoundAt = now
	else
		if now - (lastSpecialAt[lapisName] or 0) < 0.15 then return end
		lastSpecialAt[lapisName] = now
	end

	local coins = {
		"rbxassetid://135483737426662",
		"rbxassetid://72764897006138",
		"rbxassetid://135478009117226",
	}
	local id, volume = coins[math.random(1, 3)], 0.6
	if lapisName == "verity_lapis" then
		id = "rbxassetid://71231208892767"
	elseif lapisName == "lapeace_lapis" then
		id = "rbxassetid://97886203052070"
	elseif LAPIS_SOUNDS[lapisName] then
		id = LAPIS_SOUNDS[lapisName].Id
		volume = LAPIS_SOUNDS[lapisName].Volume
	end
	SoundService:PlayLocalSound(getSound(id, volume, special))
end

-- load every pickup sound up front, so the first pickup of a rare lapis
-- isn't silent while its audio is still downloading
task.spawn(function()
	local list = {}
	for _, info in pairs(LAPIS_SOUNDS) do table.insert(list, getSound(info.Id, info.Volume, true)) end
	table.insert(list, getSound("rbxassetid://71231208892767", 0.6, true))
	table.insert(list, getSound("rbxassetid://97886203052070", 0.6, true))
	for _, id in ipairs({ "rbxassetid://135483737426662", "rbxassetid://72764897006138", "rbxassetid://135478009117226" }) do
		table.insert(list, getSound(id, 0.6, false))
	end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
end)

-- Maps each specific lapis type from your list to its unique color theme
local function getLapisColors(lapisName)
	local lowerName = lapisName:lower()
	if lowerName:find("gold") then
		return Color3.fromRGB(255, 215, 0), Color3.fromRGB(120, 70, 0)
	elseif lowerName:find("diamond") or lowerName:find("???") then
		-- Diamond Lapis (locked / icy bluish theme)
		return Color3.fromRGB(100, 200, 255), Color3.fromRGB(20, 50, 80)
	elseif lowerName:find("emerald") then
		return Color3.fromRGB(50, 255, 100), Color3.fromRGB(0, 60, 20)
	elseif lowerName:find("rgb") then
		return Color3.fromRGB(255, 50, 200), Color3.fromRGB(50, 0, 80)
	elseif lowerName:find("totem") then
		return Color3.fromRGB(150, 255, 100), Color3.fromRGB(40, 50, 10)
	elseif lowerName:find("verity") then
		return Color3.fromRGB(255, 255, 50), Color3.fromRGB(90, 80, 0)
	elseif lowerName:find("hell") then
		return Color3.fromRGB(255, 50, 50), Color3.fromRGB(80, 0, 0)
	elseif lowerName:find("67") then
		return Color3.fromRGB(0, 255, 200), Color3.fromRGB(0, 60, 60)
	elseif lowerName:find("peace") then
		return Color3.fromRGB(255, 180, 50), Color3.fromRGB(80, 40, 0)
	elseif lowerName:find("malevolent") then
		return Color3.fromRGB(200, 50, 50), Color3.fromRGB(50, 0, 0)
	elseif lowerName:find("interstellar") then
		return Color3.fromRGB(200, 220, 255), Color3.fromRGB(20, 20, 50)
	else
		-- Normal Lapis / Default Blue
		return Color3.fromRGB(0, 150, 255), Color3.fromRGB(0, 30, 80)
	end
end

local function showPickupPopup(lapisModel, lapisName)
	playPickupSound(lapisName)

	local rootPart = lapisModel.PrimaryPart or lapisModel:FindFirstChildWhichIsA("BasePart")
	if not rootPart then return end

	local textColor, strokeColor = getLapisColors(lapisName)

	-- Create floating BillboardGui above the lapis
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 140, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1

	-- Format name nicely (e.g., "normal_lapis" -> "Normal Lapis")
	local cleanName = lapisName:gsub("_", " "):gsub("^%l", string.upper)
	local soldFor = lapisModel:GetAttribute("AutoSoldFor")
	if soldFor then
		-- auto-sold: show what it actually sold for (ascension + pass multipliers included)
		textLabel.Text = "SOLD +" .. formatPP(soldFor) .. " PP"
		textColor, strokeColor = Color3.fromRGB(120, 255, 120), Color3.fromRGB(0, 70, 20)
	else
		textLabel.Text = "+1 " .. cleanName
	end
	textLabel.TextColor3 = textColor
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextTransparency = 0

	-- Cool random tilt/rotation every time (-15 to 15 degrees)
	textLabel.Rotation = math.random(-15, 15)

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = strokeColor
	uiStroke.Thickness = 3
	uiStroke.Parent = textLabel

	textLabel.Parent = billboard
	billboard.Adornee = rootPart
	billboard.Parent = player:WaitForChild("PlayerGui")

	-- Initial bouncy pop scale animation
	billboard.Size = UDim2.new(0, 60, 0, 20)
	TweenService:Create(
		billboard, 
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
		{Size = UDim2.new(0, 160, 0, 55)}
	):Play()

	-- Smooth upward floating drift and fade out sequence
	task.spawn(function()
		local driftInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(billboard, driftInfo, {StudsOffset = Vector3.new(math.random(-1, 1), 5.5, 0)}):Play()

		task.wait(0.3)
		local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(textLabel, fadeInfo, {TextTransparency = 1}):Play()
		TweenService:Create(uiStroke, fadeInfo, {Transparency = 1}):Play()

		task.wait(0.3)
		billboard:Destroy()
	end)
end

local function animateCollection(lapis)
	local primaryPart = lapis.PrimaryPart or lapis:FindFirstChildWhichIsA("BasePart")
	if not primaryPart then return end

	-- Rise and fade client-side collection animation
	local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local targetCFrame = primaryPart.CFrame + Vector3.new(0, 5, 0)

	TweenService:Create(primaryPart, tweenInfo, {CFrame = targetCFrame}):Play()

	for _, part in ipairs(lapis:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			TweenService:Create(part, tweenInfo, {Transparency = 1}):Play()
		end
	end
end

local function watchLapis(lapis)
	if not lapis:IsA("Model") then return end

	lapis:GetAttributeChangedSignal("Collecting"):Connect(function()
		if lapis:GetAttribute("Collecting") == true then
			-- only YOUR pickups get a popup + sound; other players' lapis
			-- just fades (less noise, less lag in a full server)
			local by = lapis:GetAttribute("CollectedBy")
			if by == nil or by == player.UserId then
				showPickupPopup(lapis, lapis.Name)
			end
			animateCollection(lapis)
		end
	end)
end

if spawnedLapis then
	spawnedLapis.ChildAdded:Connect(watchLapis)
	for _, child in ipairs(spawnedLapis:GetChildren()) do
		watchLapis(child)
	end
end