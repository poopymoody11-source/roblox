--==================================================
-- CINEMATIC FX  (client only)
--
-- The two big "something just happened" moments:
-- unlocking a title, and ascending.
--
-- Both are built from the textures in Workspace.effects
-- rather than invented from scratch, so they sit in the
-- same visual family as the auras and the staff VFX.
--
-- Everything is drawn into its own ScreenGui at a high
-- DisplayOrder and destroyed when the sequence ends, so
-- nothing here can leave residue on the HUD if a player
-- ascends twice in quick succession.
--==================================================

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local CinematicFx = {}

-- Straight out of Workspace.effects -- these are the
-- decals on the "light rays" / "light ray" / "flare" /
-- "light ring" reference parts in the pack.
local TEX = {
	Sunburst = "rbxassetid://1084975295",
	Ray      = "rbxassetid://1053548563",
	Flare    = "rbxassetid://14684195806",
	Ring     = "rbxassetid://8271495905",
}

local GOLD      = Color3.fromRGB(255, 214, 110)
local GOLD_DEEP = Color3.fromRGB(255, 160, 40)
local WHITE     = Color3.fromRGB(255, 255, 255)

--==================================================
-- SMALL HELPERS
--==================================================

local function tween(instance, time, props, style, direction)
	local info = TweenInfo.new(
		time,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)
	local t = TweenService:Create(instance, info, props)
	t:Play()
	return t
end

local function newGui(name, order)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return nil end

	-- Replace rather than stack: ascending twice inside the
	-- sequence length should restart it, not double-expose it.
	local existing = playerGui:FindFirstChild(name)
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order or 100
	gui.Parent = playerGui
	return gui
end

local function image(parent, texture, size, color, zindex)
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = size
	label.Image = texture
	label.ImageColor3 = color or WHITE
	label.ZIndex = zindex or 1
	label.Parent = parent
	return label
end

local function text(parent, str, scaleSize, position, color, zindex)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = scaleSize
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = str
	label.TextColor3 = color or WHITE
	label.ZIndex = zindex or 2
	label.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label

	return label, stroke
end

-- Spins forever until the parent is destroyed. Cheaper and
-- smoother than tweening Rotation in fixed chunks.
local function spin(label, degreesPerSecond)
	task.spawn(function()
		local last = os.clock()
		while label.Parent do
			local now = os.clock()
			label.Rotation = (label.Rotation + (now - last) * degreesPerSecond) % 360
			last = now
			task.wait()
		end
	end)
end

--==================================================
-- WORLD EFFECTS
--
-- Clones one of the 1x1x1 effect parts out of
-- Workspace.effects, drops it on the player and fires
-- it once. The source parts are emitters-on-an-attachment,
-- so Emit() is the right way to play them as a one-shot.
--==================================================

local function findEffect(folderName, effectName)
	local effects = workspace:FindFirstChild("effects")
	if not effects then return nil end

	local folder = folderName and effects:FindFirstChild(folderName) or effects
	return folder and folder:FindFirstChild(effectName)
end

function CinematicFx.WorldBurst(folderName, effectName, cframe, emitCount, lifetime)
	local source = findEffect(folderName, effectName)
	if not source or not source:IsA("BasePart") then return nil end

	local clone = source:Clone()
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.Transparency = 1
	clone.CFrame = cframe
	clone.Parent = workspace

	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			-- Emit a burst rather than leaving Rate running, so the
			-- effect ends on its own even if cleanup is late.
			d.Enabled = false
			d:Emit(emitCount or 25)
		end
	end

	Debris:AddItem(clone, lifetime or 4)
	return clone
end

--==================================================
-- TITLE UNLOCKED
--
-- Replaces the old toast, which was a grey rectangle
-- with the title's name in it.
--==================================================

function CinematicFx.TitleUnlock(titleName, rarityName, color)
	local gui = newGui("TitleUnlockFx", 120)
	if not gui then return end

	color = color or GOLD

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui

	-- rays behind everything, tinted to the title's rarity
	local burst = image(holder, TEX.Sunburst, UDim2.fromScale(0, 0), color, 1)
	burst.ImageTransparency = 0.45
	burst.Position = UDim2.fromScale(0.5, 0.42)
	spin(burst, 14)

	local ring = image(holder, TEX.Ring, UDim2.fromScale(0, 0), color, 2)
	ring.Position = UDim2.fromScale(0.5, 0.42)
	ring.ImageTransparency = 0.2

	local flare = image(holder, TEX.Flare, UDim2.fromScale(0.5, 0.5), WHITE, 3)
	flare.Position = UDim2.fromScale(0.5, 0.42)
	flare.ImageTransparency = 1

	local headline = text(holder, "TITLE UNLOCKED",
		UDim2.fromScale(0.34, 0.045), UDim2.fromScale(0.5, 0.35), WHITE, 5)
	headline.Font = Enum.Font.GothamBold
	headline.TextTransparency = 1

	local nameLabel, nameStroke = text(holder, string.upper(titleName),
		UDim2.fromScale(0.62, 0.105), UDim2.fromScale(0.5, 0.43), color, 5)
	nameLabel.TextTransparency = 1
	nameStroke.Thickness = 4

	local rarityLabel = text(holder, string.upper(rarityName or ""),
		UDim2.fromScale(0.26, 0.034), UDim2.fromScale(0.5, 0.505), color, 5)
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextTransparency = 1

	-- in
	tween(burst, 0.55, { Size = UDim2.fromScale(0.85, 1.5) }, Enum.EasingStyle.Back)
	tween(ring, 0.7, { Size = UDim2.fromScale(0.62, 1.1), ImageTransparency = 1 })

	flare.ImageTransparency = 0.1
	tween(flare, 0.45, { Size = UDim2.fromScale(1.1, 1.1), ImageTransparency = 1 })

	tween(headline, 0.3, { TextTransparency = 0 })
	task.delay(0.12, function()
		if nameLabel.Parent then
			tween(nameLabel, 0.35, { TextTransparency = 0 })
			tween(rarityLabel, 0.35, { TextTransparency = 0.15 })
		end
	end)

	-- out
	task.delay(2.6, function()
		if not gui.Parent then return end
		tween(burst, 0.5, { ImageTransparency = 1, Size = UDim2.fromScale(1.1, 1.9) })
		tween(headline, 0.4, { TextTransparency = 1 })
		tween(nameLabel, 0.4, { TextTransparency = 1 })
		tween(rarityLabel, 0.4, { TextTransparency = 1 })
		for _, d in ipairs(holder:GetDescendants()) do
			if d:IsA("UIStroke") then
				tween(d, 0.4, { Transparency = 1 })
			end
		end
		task.wait(0.55)
		gui:Destroy()
	end)
end

--==================================================
-- ASCENSION
--
-- Runs about 3.4 seconds: light gathers, the screen
-- goes white, and the player comes out the other side
-- with the new number on screen.
--==================================================

local ROMAN = {
	{1000, "M"}, {900, "CM"}, {500, "D"}, {400, "CD"},
	{100, "C"}, {90, "XC"}, {50, "L"}, {40, "XL"},
	{10, "X"}, {9, "IX"}, {5, "V"}, {4, "IV"}, {1, "I"},
}

function CinematicFx.Roman(number)
	number = math.floor(tonumber(number) or 0)
	if number <= 0 then return "0" end

	local out = {}
	for _, pair in ipairs(ROMAN) do
		while number >= pair[1] do
			table.insert(out, pair[2])
			number = number - pair[1]
		end
	end
	return table.concat(out)
end

function CinematicFx.Ascension(level, multiplier)
	local gui = newGui("AscensionFx", 130)
	if not gui then return end

	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui

	--------------------------------------------------
	-- 1. GATHER  (0.0 - 0.9)
	--------------------------------------------------

	local sunburst = image(holder, TEX.Sunburst, UDim2.fromScale(0, 0), GOLD, 1)
	sunburst.ImageTransparency = 0.35
	spin(sunburst, 20)
	tween(sunburst, 1.2, { Size = UDim2.fromScale(1.4, 2.4) }, Enum.EasingStyle.Sine)

	-- two columns of light either side of centre
	for _, offset in ipairs({ 0.34, 0.66 }) do
		local column = image(holder, TEX.Ray, UDim2.fromScale(0.12, 0), GOLD, 2)
		column.Position = UDim2.fromScale(offset, 0.5)
		column.ImageTransparency = 0.55
		tween(column, 1.0, { Size = UDim2.fromScale(0.2, 1.3) }, Enum.EasingStyle.Sine)
		task.delay(1.4, function()
			if column.Parent then tween(column, 0.6, { ImageTransparency = 1 }) end
		end)
	end

	if root then
		CinematicFx.WorldBurst("Anime", "Charge-01", root.CFrame, 60, 3)
	end

	--------------------------------------------------
	-- 2. FLASH  (0.9 - 1.3)
	--------------------------------------------------

	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 8
	flash.Parent = holder

	local camera = workspace.CurrentCamera
	local baseFov = camera and camera.FieldOfView or 70

	task.delay(0.9, function()
		if not gui.Parent then return end

		tween(flash, 0.12, { BackgroundTransparency = 0.05 })

		if root then
			CinematicFx.WorldBurst("Anime", "Shiny-01", root.CFrame, 40, 4)
			CinematicFx.WorldBurst("Big", "Lighting-01", root.CFrame + Vector3.new(0, 3, 0), 30, 4)
			CinematicFx.WorldBurst("Anime", "Stars-01", root.CFrame, 35, 5)
		end

		if camera then
			tween(camera, 0.18, { FieldOfView = baseFov + 16 }, Enum.EasingStyle.Back)
			task.delay(0.25, function()
				if camera then
					tween(camera, 0.7, { FieldOfView = baseFov }, Enum.EasingStyle.Quart)
				end
			end)
		end

		task.wait(0.15)
		if flash.Parent then
			tween(flash, 0.55, { BackgroundTransparency = 1 })
		end
	end)

	--------------------------------------------------
	-- 3. THE NUMBER  (1.2 - 3.4)
	--------------------------------------------------

	task.delay(1.15, function()
		if not gui.Parent then return end

		local ring = image(holder, TEX.Ring, UDim2.fromScale(0, 0), GOLD, 3)
		ring.ImageTransparency = 0.1
		tween(ring, 0.9, { Size = UDim2.fromScale(1.3, 2.3), ImageTransparency = 1 })

		local headline, headlineStroke = text(holder, "ASCENDED",
			UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.5, 0.4), WHITE, 10)
		headline.TextTransparency = 1
		headlineStroke.Thickness = 5

		-- gold gradient on the headline, top light / bottom deep
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(0.55, GOLD),
			ColorSequenceKeypoint.new(1, GOLD_DEEP),
		})
		gradient.Parent = headline

		local levelLabel = text(holder, "ASCENSION " .. CinematicFx.Roman(level),
			UDim2.fromScale(0.42, 0.05), UDim2.fromScale(0.5, 0.505), GOLD, 10)
		levelLabel.Font = Enum.Font.GothamBold
		levelLabel.TextTransparency = 1

		local multLabel = text(holder,
			string.format("x%.1f PEACEPOINTS", multiplier or 1),
			UDim2.fromScale(0.34, 0.04), UDim2.fromScale(0.5, 0.56), WHITE, 10)
		multLabel.Font = Enum.Font.GothamBold
		multLabel.TextTransparency = 1

		-- drop in from slightly above
		headline.Position = UDim2.fromScale(0.5, 0.33)
		tween(headline, 0.45, {
			TextTransparency = 0,
			Position = UDim2.fromScale(0.5, 0.4),
		}, Enum.EasingStyle.Back)

		task.delay(0.2, function()
			if levelLabel.Parent then
				tween(levelLabel, 0.4, { TextTransparency = 0 })
				tween(multLabel, 0.4, { TextTransparency = 0.1 })
			end
		end)

		task.delay(1.7, function()
			if not gui.Parent then return end
			tween(headline, 0.45, { TextTransparency = 1 })
			tween(levelLabel, 0.45, { TextTransparency = 1 })
			tween(multLabel, 0.45, { TextTransparency = 1 })
			tween(sunburst, 0.6, { ImageTransparency = 1 })
			for _, d in ipairs(holder:GetDescendants()) do
				if d:IsA("UIStroke") then
					tween(d, 0.45, { Transparency = 1 })
				end
			end
			task.wait(0.7)
			gui:Destroy()
		end)
	end)
end

return CinematicFx
