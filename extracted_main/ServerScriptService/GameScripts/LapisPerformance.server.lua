--==================================================
-- LAPIS PERFORMANCE  (SERVER)  --  distance LOD
--
-- v1 of this script just switched the decorative
-- scripts off permanently, which killed the lag but
-- also killed the orbiting bits. This version brings
-- them back and gates them on distance instead: close
-- up you get the full effect, far away the lapis is a
-- static prop costing nothing.
--
-- WHY the orbit scripts are so expensive: each one is a
-- SERVER script running RunService.Heartbeat and calling
-- model:PivotTo() every single frame. 67_lapis contains
-- TWELVE of them, at MaxCap 22 that is 264 per-frame
-- PivotTo calls -- and every one of those replicates a
-- CFrame change to every client, every frame. The cost
-- is as much network as CPU.
--
--   67_lapis            orbit_script x12   (243 emitters)
--   interstellar_lapis  orbit_script x8
--   rgb_lapis           rbg_effect x4 + rbg_highlight
--   lapeace_lapis       wobble_script + ray_script
--
-- So: only ever animate the handful nearest an actual
-- player, and never more than ANIMATED_SCRIPT_BUDGET of
-- them at once no matter how many players there are.
--
-- Templates in ServerStorage are never modified.
--==================================================

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local CONFIG = {
	--------------------------------------------------
	-- PARTICLES (trimmed once, on spawn)
	--------------------------------------------------
	-- Emitters kept per spawned lapis, highest-Rate first. 24 leaves
	-- every lapis except 67_lapis completely untouched, and cuts that
	-- one from 243 -> 24. The client PerformanceManager then culls
	-- what's left by distance.
	MAX_EMITTERS_PER_LAPIS = 24,
	PER_TYPE_EMITTER_OVERRIDE = {
		-- ["67_lapis"] = 40,   -- raise if it looks too bare up close
		["normal_lapis"] = 4,   -- cap 100 of these, keep them cheap
		["golden_lapis"] = 6,
	},
	MAX_LIGHTS_PER_LAPIS = 2,
	MAX_BEAMS_PER_LAPIS = 2,
	MAX_TRAILS_PER_LAPIS = 2,
	GLOBAL_EMITTER_BUDGET = 900,

	DISABLE_SHADOWS = true,

	--------------------------------------------------
	-- ANIMATION LOD (orbit / wobble / rgb scripts)
	--------------------------------------------------
	ANIMATED_SCRIPT_NAMES = {
		orbit_script = true,
		wobble_script = true,
		ray_script = true,
		rbg_effect = true,
		rbg_highlight = true,
	},
	-- Anything not in the list above: true = also LOD it.
	LOD_UNKNOWN_SCRIPTS = true,

	ENABLE_RADIUS = 140,    -- start animating inside this
	DISABLE_RADIUS = 190,   -- stop animating outside this (hysteresis
	                        -- so a lapis on the boundary doesn't flicker)
	ANIMATED_SCRIPT_BUDGET = 60,  -- hard ceiling, server-wide
	UPDATE_INTERVAL = 0.4,
}

local spawnedFolder = workspace:FindFirstChild("SpawnedLapis")
	or workspace:WaitForChild("SpawnedLapis", 30)

if not spawnedFolder then
	warn("[LapisPerformance] No SpawnedLapis folder -- nothing to optimise")
	return
end

--==================================================
-- SPAWN-TIME TRIM
--==================================================

local liveEmitters = 0
local tracked = {}   -- [model] = {scripts = {...}, animating = bool, root = BasePart}

local function trim(list, keep)
	local kept = 0
	for _, item in ipairs(list) do
		if kept < keep then
			kept += 1
		else
			item:Destroy()
		end
	end
	return kept
end

local function onSpawned(lapis)
	if not lapis:IsA("Model") and not lapis:IsA("BasePart") then return end
	if tracked[lapis] then return end
	if CollectionService:HasTag(lapis, "PlacedLapis") then return end

	local emitters, lights, beams, trails, scripts, parts = {}, {}, {}, {}, {}, {}
	local root = lapis:IsA("BasePart") and lapis or nil

	for _, d in ipairs(lapis:GetDescendants()) do
		if d:IsA("ParticleEmitter") then table.insert(emitters, d)
		elseif d:IsA("Light") then table.insert(lights, d)
		elseif d:IsA("Beam") then table.insert(beams, d)
		elseif d:IsA("Trail") then table.insert(trails, d)
		elseif d:IsA("BasePart") then
			table.insert(parts, d)
			if not root then root = d end
		elseif d:IsA("Script") then
			if CONFIG.ANIMATED_SCRIPT_NAMES[d.Name] or CONFIG.LOD_UNKNOWN_SCRIPTS then
				table.insert(scripts, d)
			end
		end
	end

	table.sort(emitters, function(a, b)
		local ra = (typeof(a.Rate) == "number") and a.Rate or 0
		local rb = (typeof(b.Rate) == "number") and b.Rate or 0
		return ra > rb
	end)

	local allowance = CONFIG.PER_TYPE_EMITTER_OVERRIDE[lapis.Name]
		or CONFIG.MAX_EMITTERS_PER_LAPIS
	if liveEmitters >= CONFIG.GLOBAL_EMITTER_BUDGET then
		allowance = 0
	end

	local kept = trim(emitters, allowance)
	trim(lights, CONFIG.MAX_LIGHTS_PER_LAPIS)
	trim(beams, CONFIG.MAX_BEAMS_PER_LAPIS)
	trim(trails, CONFIG.MAX_TRAILS_PER_LAPIS)

	if CONFIG.DISABLE_SHADOWS then
		for _, part in ipairs(parts) do
			part.CastShadow = false
		end
	end

	-- Start dormant. The LOD pass below switches them on when a player
	-- actually gets close enough to see them.
	for _, s in ipairs(scripts) do
		s.Disabled = true
	end

	liveEmitters += kept
	lapis:SetAttribute("PerfEmitters", kept)

	if root and #scripts > 0 then
		tracked[lapis] = {scripts = scripts, animating = false, root = root}
	end
end

local function onRemoved(lapis)
	local n = lapis:GetAttribute("PerfEmitters")
	if n then
		liveEmitters -= n
		if liveEmitters < 0 then liveEmitters = 0 end
	end
	tracked[lapis] = nil
end

for _, child in ipairs(spawnedFolder:GetChildren()) do
	onSpawned(child)
end
spawnedFolder.ChildAdded:Connect(onSpawned)
spawnedFolder.ChildRemoved:Connect(onRemoved)

--==================================================
-- DISTANCE LOD
--==================================================

local function setAnimating(entry, on)
	if entry.animating == on then return 0 end
	entry.animating = on
	for _, s in ipairs(entry.scripts) do
		if s.Parent then
			s.Disabled = not on
		end
	end
	return #entry.scripts
end

local function playerPositions()
	local positions = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			table.insert(positions, rootPart.Position)
		end
	end
	return positions
end

local candidates = {}

task.spawn(function()
	while task.wait(CONFIG.UPDATE_INTERVAL) do
		local positions = playerPositions()

		if #positions == 0 then
			for model, entry in pairs(tracked) do
				if model.Parent then setAnimating(entry, false) else tracked[model] = nil end
			end
			continue
		end

		table.clear(candidates)
		local enableSq = CONFIG.ENABLE_RADIUS ^ 2
		local disableSq = CONFIG.DISABLE_RADIUS ^ 2

		for model, entry in pairs(tracked) do
			if not model.Parent or not entry.root.Parent then
				tracked[model] = nil
			else
				local pos = entry.root.Position
				local best = math.huge
				for _, p in ipairs(positions) do
					local d = (p - pos).Magnitude ^ 2
					if d < best then best = d end
				end

				if best > disableSq then
					setAnimating(entry, false)
				elseif best <= enableSq or entry.animating then
					-- inside the enable ring, or already running and still
					-- within the (larger) disable ring
					table.insert(candidates, {entry = entry, d = best})
				end
			end
		end

		table.sort(candidates, function(a, b) return a.d < b.d end)

		local budget = CONFIG.ANIMATED_SCRIPT_BUDGET
		for _, c in ipairs(candidates) do
			local cost = #c.entry.scripts
			if cost <= budget then
				setAnimating(c.entry, true)
				budget -= cost
			else
				setAnimating(c.entry, false)
			end
		end
	end
end)

--==================================================
-- COUNTER RESYNC
--==================================================

task.spawn(function()
	while task.wait(15) do
		local total = 0
		for _, child in ipairs(spawnedFolder:GetChildren()) do
			total += child:GetAttribute("PerfEmitters") or 0
		end
		liveEmitters = total
	end
end)
