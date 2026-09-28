--==================================================
-- LOCAL LAPIS  (client)
--
-- Your own lapis: the server (GameScripts > LocalLapisService)
-- tells us where each one is; we build it here, on your
-- screen only, inside workspace.SpawnedLapis so the existing
-- LapisVisuals (bob, magnet flight, pickup) and LapisPopup
-- treat it exactly like the old shared lapis.
--
-- Walking over one, or pulling it in with your staff's magnet,
-- asks the server for it; the server checks you're really
-- there before paying out.
--
-- Works the same on PC, mobile, console and VR: nothing here
-- depends on the input device.
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("LocalLapis")
local templates = ReplicatedStorage:WaitForChild("LocalLapisTemplates")
local folder = workspace:WaitForChild("SpawnedLapis")
local spawnBox = workspace:WaitForChild("LapisSpawnBox")
local LapisConfig = require(ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("LapisDataModule"))

local WALKOVER_RADIUS = 5
local SCAN_INTERVAL = 0.1
local HEIGHT_PADDING = 60      -- (same spawn-box check the server magnet used)
local LOD_RADIUS = 170         -- scripted extras (orbits, rays, rgb) only run this close
local LOD_RADIUS_LOW = 80

local values, doAnim = {}, {}
for _, item in ipairs(LapisConfig.Items) do
	values[item.Name] = item.Value
	doAnim[item.Name] = item.DoAnim ~= false
end

local live = {}     -- [id] = model
local pending = {}  -- [id] = true while a collect request is out

--==================================================
-- BUILD ONE
--==================================================
local function isDecalHolder(o)
	if not o:IsA("BasePart") then return false end
	for _, c in ipairs(o:GetChildren()) do if c:IsA("Decal") then return true end end
	return false
end

local function restingCFrame(model, surface, yaw)
	local inner = model:FindFirstChild("model")
	local floorModel = (inner and inner:IsA("Model")) and inner or model
	local cf, size = floorModel:GetBoundingBox()
	local lowest = cf.Position.Y - size.Y / 2
	local offsetY = model:GetPivot().Position.Y - lowest
	return CFrame.new(surface.X, surface.Y + offsetY, surface.Z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

local function build(id, name, surface, yaw)
	if live[id] then return end
	local template = templates:FindFirstChild(name)
	if not template then return end
	local m = template:Clone()
	m.Name = name
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			if isDecalHolder(d) then d.Transparency = 1 end
		-- (Highlights are left as authored: HighlightBudget decides which
		-- of ALL the map's outlines get one of Roblox's 31 slots)
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") then
			-- Remember how the model was AUTHORED, before anything toggles it.
			-- PerformanceManager reads this. (It used to record whatever state
			-- it found - and if it or the old LOD pass had already switched an
			-- effect off, that lapis lost its particles for good.)
			d:SetAttribute("FXWasEnabled", d.Enabled)
		end
	end
	m:PivotTo(restingCFrame(m, surface, yaw))
	m:SetAttribute("IsSpawnedLapis", true)
	m:SetAttribute("LocalLapisId", id)
	m:SetAttribute("Value", values[name] or 0)
	m:SetAttribute("Collecting", false)
	m:SetAttribute("Magnetized", false)
	m:SetAttribute("DoAnim", doAnim[name] ~= false)
	m.Parent = folder
	live[id] = m
end

local function drop(id)
	local m = live[id]
	live[id] = nil
	pending[id] = nil
	if m and m.Parent and not m:GetAttribute("Collecting") then m:Destroy() end
end

local function release(m)
	m:SetAttribute("MagnetTarget", nil)
	m:SetAttribute("MagnetStart", nil)
	m:SetAttribute("MagnetDuration", nil)
	m:SetAttribute("Magnetized", false)
end

--==================================================
-- SERVER MESSAGES
--==================================================
local idleNote
local clearGen = 0
remote.OnClientEvent:Connect(function(action, a, b, c, d)
	if action == "Spawn" then
		build(a, b, c, d)
	elseif action == "SpawnMany" then
		-- coming back to an island: redraw what's still lying there,
		-- a few per frame so it doesn't hitch
		local gen = clearGen
		task.spawn(function()
			for i, e in ipairs(a) do
				if gen ~= clearGen then return end
				build(e[1], e[2], e[3], e[4])
				if i % 40 == 0 then task.wait() end
			end
		end)
	elseif action == "Collected" then
		local m = live[a]
		live[a] = nil
		pending[a] = nil
		if m and m.Parent then
			m:SetAttribute("CollectedBy", player.UserId)
			if b then m:SetAttribute("AutoSoldFor", b) end
			m:SetAttribute("Collecting", true)
			m:SetAttribute("Magnetized", false)
			task.delay(0.7, function() if m.Parent then m:Destroy() end end)
		end
	elseif action == "Reject" then
		pending[a] = nil
		local m = live[a]
		if m then release(m) end
	elseif action == "Clear" then
		clearGen += 1
		for id in pairs(live) do drop(id) end
	elseif action == "Idle" then
		-- a nudge so a player who's just standing around knows why it stopped
		if a and not idleNote then
			idleNote = Instance.new("ScreenGui")
			idleNote.Name = "LapisIdleNote"
			idleNote.ResetOnSpawn = false
			idleNote.DisplayOrder = 30
			local t = Instance.new("TextLabel")
			t.AnchorPoint = Vector2.new(0.5, 0)
			t.Position = UDim2.fromScale(0.5, 0.16)
			t.Size = UDim2.fromScale(0.6, 0.045)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextColor3 = Color3.fromRGB(255, 220, 90)
			t.Text = "LAPIS STOPPED SPAWNING - MOVE AROUND TO KEEP IT COMING!"
			t.Active = false
			t.Parent = idleNote
			local st = Instance.new("UIStroke") st.Thickness = 2 st.Parent = t
			idleNote.Parent = player:WaitForChild("PlayerGui")
		elseif not a and idleNote then
			idleNote:Destroy()
			idleNote = nil
		end
	end
end)
remote:FireServer("Ready")

--==================================================
-- PICKUP + MAGNET
--==================================================
local function inSpawnBox(pos)
	for _, d in ipairs(spawnBox:GetDescendants()) do
		if d:IsA("BasePart") then
			local rel = d.CFrame:PointToObjectSpace(pos)
			local h = d.Size / 2
			if math.abs(rel.X) <= h.X and math.abs(rel.Z) <= h.Z and rel.Y >= -h.Y - 2 and rel.Y <= h.Y + HEIGHT_PADDING then
				return true
			end
		end
	end
	return false
end

local function request(id)
	if pending[id] then return end
	pending[id] = true
	remote:FireServer("Collect", id)
	-- (no answer - a dropped packet - lets it be tried again; the
	-- server may queue a big magnet haul for a few seconds)
	task.delay(12, function()
		if pending[id] and live[id] then
			pending[id] = nil
			release(live[id])
		end
	end)
end

local acc = 0
local boxCache, boxCacheT = false, 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < SCAN_INTERVAL then return end
	acc = 0
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0) then return end
	local pos = root.Position
	local tool = char:FindFirstChildOfClass("Tool")
	local radius = tool and tool:GetAttribute("MagnetRadius")
	local flight = tool and tool:GetAttribute("MagnetFlight") or 1
	if radius and os.clock() - boxCacheT > 0.3 then
		boxCache, boxCacheT = inSpawnBox(pos), os.clock()
	end
	local now = workspace:GetServerTimeNow()
	for id, m in pairs(live) do
		if not m.Parent then
			live[id] = nil
		elseif not m:GetAttribute("Collecting") and not pending[id] then
			local start = m:GetAttribute("MagnetStart")
			if start then
				-- mid-flight: it reaches you -> ask for it
				if now - start >= (m:GetAttribute("MagnetDuration") or flight) then request(id) end
			else
				local p = m:GetPivot().Position
				local dist = (p - pos).Magnitude
				if dist <= WALKOVER_RADIUS then
					request(id)
				elseif radius and boxCache and dist <= radius then
					if not m:GetAttribute("OriginalPosition") then m:SetAttribute("OriginalPosition", p) end
					m:SetAttribute("Magnetized", true)
					m:SetAttribute("MagnetDuration", flight)
					m:SetAttribute("MagnetStart", now)
					m:SetAttribute("MagnetTarget", player.UserId)
				end
			end
		end
	end
	-- (unequipped mid-flight: whatever was flying goes back)
	if not radius then
		for id, m in pairs(live) do
			if m.Parent and m:GetAttribute("MagnetStart") and not pending[id] and not m:GetAttribute("Collecting") then release(m) end
		end
	end
end)

--==================================================
-- LEVEL OF DETAIL: the scripted extras (67 lapis' orbiting ores,
-- La Peace lapis' rays, RGB colour cycling) and particles only
-- run near you
--==================================================
-- Only the SCRIPTS are switched here. Particles/lights belong to
-- PerformanceManager alone: two systems toggling the same emitters
-- fought each other, and one would save the other's "off" as the
-- original state - the missing lapis particles.
local lodState = {} -- [model] = true when its scripts are on
local function setExtras(m, on)
	if lodState[m] ~= nil and lodState[m] == on then return end
	lodState[m] = on
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Script") then
			d.Enabled = on
		end
	end
end
-- Roblox only draws 31 Highlights at a time. A field of lapis each
-- carrying one ate the whole budget, so staffs (and anything else with
-- an outline) randomly lost theirs. Only the nearest few lapis keep one.
local MAX_LAPIS_HIGHLIGHTS = 8
local hlOn = {} -- [model] = bool
local function setHighlight(m, on)
	if hlOn[m] == on then return end
	hlOn[m] = on
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Highlight") then d.Enabled = on end
	end
end

task.spawn(function()
	while true do
		task.wait(0.5)
		local cam = workspace.CurrentCamera
		if cam then
			local r = player:GetAttribute("LowGraphics") and LOD_RADIUS_LOW or LOD_RADIUS
			local cp = cam.CFrame.Position
			local near = {}
			for _, m in pairs(live) do
				if m.Parent then
					local d = (m:GetPivot().Position - cp).Magnitude
					setExtras(m, d <= r)
					table.insert(near, { m, d })
				end
			end
		end
		for m in pairs(lodState) do if not m.Parent then lodState[m] = nil end end
	end
end)
