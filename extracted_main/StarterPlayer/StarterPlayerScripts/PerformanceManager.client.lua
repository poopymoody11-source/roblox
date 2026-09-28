--==================================================
-- PERFORMANCE MANAGER  (CLIENT)
--
-- Two jobs, both purely local:
--
--  1. VFX culling -- only the nearest N lapis are allowed
--     to run their particles at once.
--  2. Distance fade -- past FADE_DISTANCE the lapis model
--     itself goes invisible, so you don't see a field of
--     plain untextured props with no effects on them.
--     Done with LocalTransparencyModifier, which is a
--     client-only override: the real Transparency the
--     server owns is never touched, so nothing desyncs
--     and pickups still work exactly the same.
--
-- Quality auto-tunes off the framerate you're actually
-- getting. Players who want it pinned low can set the
-- LowGraphics attribute on themselves.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG = {
	WATCH = {"SpawnedLapis", "Lapis", "LapisSpawnBox", "staffs"},
	UPDATE_INTERVAL = 0.3,

	QUALITY = {
		-- (raised: on the lower tiers so few lapis kept their particles, and
		-- the fade-out was so close, that it looked like effects/textures
		-- were simply missing)
		High = {Radius = 200, Groups = 70, Fade = 360},
		Med  = {Radius = 150, Groups = 45, Fade = 300},
		Low  = {Radius = 110, Groups = 28, Fade = 260},
		Pot  = {Radius = 80,  Groups = 14, Fade = 220},
	},
	ORDER = {"Pot", "Low", "Med", "High"},
	START_AT = "Med",

	FPS_DROP_BELOW = 32,
	FPS_RAISE_ABOVE = 55,
	SUSTAIN_SECONDS = 4,
}

--==================================================
-- REGISTRY
--==================================================

-- [model] = {root, fx = {}, parts = {}, shown = bool, visible = bool}
local groups = {}

-- Lapis textures are downloaded the first time they're drawn, so lapis on an
-- island you've never been near show up blank for a moment when you arrive.
-- Every decal/texture we register is queued here and preloaded in batches.
local preloadQueue = {}
local preloadSeen = {}
task.spawn(function()
	while true do
		task.wait(1)
		if #preloadQueue > 0 then
			local batch = preloadQueue
			preloadQueue = {}
			pcall(function() ContentProvider:PreloadAsync(batch) end)
		end
	end
end)

local function collect(model)
	if groups[model] then return end

	local fx, parts, root = {}, {}, nil

	if model:IsA("BasePart") then
		root = model
		table.insert(parts, model)
	end

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
			or d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			if d:GetAttribute("FXWasEnabled") == nil then
				d:SetAttribute("FXWasEnabled", d.Enabled)
			end
			if d:GetAttribute("FXWasEnabled") then
				table.insert(fx, d)
			end
		elseif d:IsA("BasePart") then
			table.insert(parts, d)
			if not root then root = d end
		elseif d:IsA("Decal") or d:IsA("Texture") then
			table.insert(parts, d)
			-- Remember the real transparency NOW, before anything hides it.
			-- (It used to be saved after hiding, i.e. saved as 1, so lapis
			-- came back from a distance with no texture at all.)
			local saved = d:GetAttribute("OrigDecalTrans")
			if saved == nil or saved >= 1 then
				d:SetAttribute("OrigDecalTrans", (d.Transparency < 1) and d.Transparency or 0)
			end
			if not preloadSeen[d.Texture] then
				preloadSeen[d.Texture] = true
				table.insert(preloadQueue, d)
			end
		end
	end

	-- Register even with zero emitters -- plain lapis still need fading.
	if not root or #parts == 0 then return end

	groups[model] = {root = root, fx = fx, parts = parts, shown = true, visible = true}
end

local function drop(model)
	groups[model] = nil
end

local function watchFolder(folder)
	for _, child in ipairs(folder:GetChildren()) do
		collect(child)
	end
	folder.ChildAdded:Connect(function(child)
		task.delay(0.15, function()
			if child.Parent then collect(child) end
		end)
	end)
	folder.ChildRemoved:Connect(drop)
end

for _, name in ipairs(CONFIG.WATCH) do
	local folder = workspace:FindFirstChild(name)
	if folder then
		watchFolder(folder)
	else
		task.spawn(function()
			local late = workspace:WaitForChild(name, 30)
			if late then watchFolder(late) end
		end)
	end
end

--==================================================
-- QUALITY
--==================================================

local qualityIndex = table.find(CONFIG.ORDER, CONFIG.START_AT) or 2

local function currentQuality()
	if player:GetAttribute("LowGraphics") then
		return CONFIG.QUALITY.Pot
	end
	return CONFIG.QUALITY[CONFIG.ORDER[qualityIndex]]
end

local frames, elapsed, goodFor, badFor = 0, 0, 0, 0

RunService.RenderStepped:Connect(function(dt)
	frames += 1
	elapsed += dt
	if elapsed < 1 then return end

	local fps = frames / elapsed
	frames, elapsed = 0, 0

	if fps < CONFIG.FPS_DROP_BELOW then
		badFor += 1
		goodFor = 0
	elseif fps > CONFIG.FPS_RAISE_ABOVE then
		goodFor += 1
		badFor = 0
	else
		goodFor, badFor = 0, 0
	end

	if badFor >= CONFIG.SUSTAIN_SECONDS and qualityIndex > 1 then
		qualityIndex -= 1
		badFor = 0
		print(("[PerformanceManager] %d fps -- dropping to %s"):format(math.floor(fps), CONFIG.ORDER[qualityIndex]))
	elseif goodFor >= CONFIG.SUSTAIN_SECONDS * 2 and qualityIndex < #CONFIG.ORDER then
		qualityIndex += 1
		goodFor = 0
		print(("[PerformanceManager] %d fps -- raising to %s"):format(math.floor(fps), CONFIG.ORDER[qualityIndex]))
	end
end)

--==================================================
-- APPLY
--==================================================

local function setShown(group, shown)
	if group.shown == shown then return end
	group.shown = shown
	for _, fx in ipairs(group.fx) do
		if fx.Parent then
			fx.Enabled = shown
		end
	end
end

local function setVisible(group, visible)
	if group.visible == visible then return end
	group.visible = visible
	local modifier = visible and 0 or 1
	for _, part in ipairs(group.parts) do
		if part.Parent then
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = modifier
			else
				-- Decals/Textures have no LocalTransparencyModifier, so they're
				-- hidden by hand. The original value was recorded in collect().
				if visible then
					part.Transparency = part:GetAttribute("OrigDecalTrans") or 0
				else
					part.Transparency = 1
				end
			end
		end
	end
end

local sortable = {}

task.spawn(function()
	while task.wait(CONFIG.UPDATE_INTERVAL) do
		camera = workspace.CurrentCamera
		if not camera then continue end

		local quality = currentQuality()
		local origin = camera.CFrame.Position
		local fxRangeSq = quality.Radius * quality.Radius
		local fadeSq = quality.Fade * quality.Fade

		table.clear(sortable)

		for model, group in pairs(groups) do
			if not model.Parent or not group.root.Parent then
				groups[model] = nil
			else
				local distSq = (group.root.Position - origin).Magnitude ^ 2

				-- fade the whole model out past the fade distance
				setVisible(group, distSq <= fadeSq)

				if distSq <= fxRangeSq then
					table.insert(sortable, {group = group, d = distSq})
				else
					setShown(group, false)
				end
			end
		end

		table.sort(sortable, function(a, b) return a.d < b.d end)

		for i, entry in ipairs(sortable) do
			setShown(entry.group, i <= quality.Groups)
		end
	end
end)
