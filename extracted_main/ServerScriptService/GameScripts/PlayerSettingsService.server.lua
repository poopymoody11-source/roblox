--==================================================
-- PLAYER SETTINGS  (server)
--
-- Powers the Settings buttons on each plot's stats
-- billboard. Each setting lives as an attribute on the
-- player (so the client can react and the billboard can
-- show it), is saved between sessions, and is shown as
-- a tick/cross on the owner's billboard.
--
--   music        Set_Music         background music on/off
--   Audio        Set_Audio         every sound on/off
--   LapisSound   Set_LapisSound    lapis pickup sounds
--   Low-Graphic-Mode Set_LowGraphics  cuts effects (also sets
--                LowGraphics, which PerformanceManager reads)
--   Allow-Players-Plot Set_AllowVisitors  others can walk
--                into your plot; off = they're pushed out
--   pvp          PvpEnabled        same toggle as the PvP button
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("PlayerSettings_v1")

local plotsFolder = workspace:WaitForChild("Islands"):WaitForChild("StarterIsland"):WaitForChild("IslandPlots")

-- button name on the billboard -> { attribute, default, label }
local SETTINGS = {
	["music"]              = { Attr = "Set_Music",         Default = true,  Label = "Music" },
	["Audio"]              = { Attr = "Set_Audio",         Default = true,  Label = "Audio" },
	["LapisSound"]         = { Attr = "Set_LapisSound",    Default = true,  Label = "Lapis Sound" },
	["Low-Graphic-Mode"]   = { Attr = "Set_LowGraphics",   Default = false, Label = "Low Graphic Mode" },
	["Allow-Players-Plot"] = { Attr = "Set_AllowVisitors", Default = true,  Label = "Allow Players Into Plot" },
	["pvp"]                = { Attr = "PvpEnabled",        Default = false, Label = "PVP", NoSave = true },
	-- not a billboard button: set once the first-join tutorial is finished/skipped
	["TutorialDone"]       = { Attr = "Set_TutorialDone",  Default = false, Label = "Tutorial", Hidden = true },
}

local remote = ReplicatedStorage:FindFirstChild("PlotSettings")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "PlotSettings"
	remote.Parent = ReplicatedStorage
end

--------------------------------------------------
-- billboard
--------------------------------------------------
local function plotOf(player)
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		local owner = plot:FindFirstChild("Owner")
		if owner and owner.Value == player.Name then return plot end
	end
end

local function statsGui(plot)
	local lb = plot and plot:FindFirstChild("Leaderboard")
	local stats = lb and lb:FindFirstChild("stats")
	if not stats then return nil end
	for _, c in ipairs(stats:GetChildren()) do
		if c:IsA("BasePart") then
			local g = c:FindFirstChildOfClass("SurfaceGui")
			if g then return g end
		end
	end
end

local function paint(plot, player)
	local gui = statsGui(plot)
	if not gui then return end
	for name, spec in pairs(SETTINGS) do
		local holder = gui:FindFirstChild(name, true)
		local label = holder and holder:FindFirstChildOfClass("TextLabel")
		if label then
			local on
			if player then
				on = player:GetAttribute(spec.Attr)
				if on == nil then on = spec.Default end
			else
				on = spec.Default
			end
			label.Text = spec.Label .. ": " .. (on and "\u{2705}" or "\u{274C}")
		end
	end
end

local function repaintFor(player)
	local plot = plotOf(player)
	if plot then paint(plot, player) end
end

-- repaint when a plot changes hands
local function watchPlot(plot)
	local owner = plot:WaitForChild("Owner", 10)
	if not owner then return end
	local function update()
		local p = owner.Value ~= "" and Players:FindFirstChild(owner.Value) or nil
		paint(plot, p)
	end
	owner:GetPropertyChangedSignal("Value"):Connect(update)
	update()
end
for _, plot in ipairs(plotsFolder:GetChildren()) do task.spawn(watchPlot, plot) end
plotsFolder.ChildAdded:Connect(watchPlot)

--------------------------------------------------
-- load / save
--------------------------------------------------
local function apply(player, saved)
	for _, spec in pairs(SETTINGS) do
		if not spec.NoSave then
			local v = saved and saved[spec.Attr]
			if type(v) ~= "boolean" then v = spec.Default end
			player:SetAttribute(spec.Attr, v)
		end
	end
	player:SetAttribute("LowGraphics", player:GetAttribute("Set_LowGraphics") == true)
end

local function save(player)
	local data = {}
	for _, spec in pairs(SETTINGS) do
		if not spec.NoSave then data[spec.Attr] = player:GetAttribute(spec.Attr) end
	end
	pcall(function() store:SetAsync("S_" .. player.UserId, data) end)
end

Players.PlayerAdded:Connect(function(player)
	apply(player, nil) -- defaults straight away
	local ok, saved = pcall(function() return store:GetAsync("S_" .. player.UserId) end)
	if ok and type(saved) == "table" and player.Parent then apply(player, saved) end
	player:SetAttribute("SettingsLoaded", true) -- the tutorial waits for this
	-- PvP changes come from the HUD button too; keep the billboard in sync
	for _, spec in pairs(SETTINGS) do
		player:GetAttributeChangedSignal(spec.Attr):Connect(function() repaintFor(player) end)
	end
	repaintFor(player)
end)
Players.PlayerRemoving:Connect(save)
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do save(p) end
end)

--------------------------------------------------
-- toggles from the billboard
--------------------------------------------------
local lastToggle = {}
remote.OnServerEvent:Connect(function(player, name)
	if name == "TutorialDone" then
		if player:GetAttribute("Set_TutorialDone") ~= true then
			player:SetAttribute("Set_TutorialDone", true)
			save(player)
		end
		return
	end
	local spec = type(name) == "string" and SETTINGS[name]
	if not spec or spec.Hidden then return end
	if lastToggle[player] and os.clock() - lastToggle[player] < 0.25 then return end
	lastToggle[player] = os.clock()

	local cur = player:GetAttribute(spec.Attr)
	if cur == nil then cur = spec.Default end
	player:SetAttribute(spec.Attr, not cur)
	if spec.Attr == "Set_LowGraphics" then
		player:SetAttribute("LowGraphics", not cur)
	end
end)
Players.PlayerRemoving:Connect(function(p) lastToggle[p] = nil end)

--------------------------------------------------
-- keep visitors out of plots whose owner turned it off
--------------------------------------------------
local function insidePart(part, pos)
	local lp = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	return math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z
end

task.spawn(function()
	while true do
		task.wait(0.5)
		for _, plot in ipairs(plotsFolder:GetChildren()) do
			local owner = plot:FindFirstChild("Owner")
			local hitbox = plot:FindFirstChild("Hitbox")
			local ownerPlayer = owner and owner.Value ~= "" and Players:FindFirstChild(owner.Value)
			if hitbox and ownerPlayer and ownerPlayer:GetAttribute("Set_AllowVisitors") == false then
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= ownerPlayer then
						local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
						if root and insidePart(hitbox, root.Position) then
							-- push them back out past the nearest side of the plot
							local lp = hitbox.CFrame:PointToObjectSpace(root.Position)
							local h = hitbox.Size / 2
							local out
							if h.X - math.abs(lp.X) < h.Z - math.abs(lp.Z) then
								out = Vector3.new(math.sign(lp.X) * (h.X + 6), lp.Y, lp.Z)
							else
								out = Vector3.new(lp.X, lp.Y, math.sign(lp.Z) * (h.Z + 6))
							end
							local world = hitbox.CFrame:PointToWorldSpace(out)
							p.Character:PivotTo(CFrame.new(world) * root.CFrame.Rotation)
						end
					end
				end
			end
		end
	end
end)
