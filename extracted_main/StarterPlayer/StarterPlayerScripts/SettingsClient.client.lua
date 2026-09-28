--==================================================
-- SETTINGS  (client)
--
-- 1. Makes the Settings buttons on YOUR plot's stats
--    billboard clickable (the server flips the setting).
-- 2. Applies your settings locally: music, all audio,
--    lapis pickup sounds, low graphics.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("PlotSettings")
local plotsFolder = workspace:WaitForChild("Islands"):WaitForChild("StarterIsland"):WaitForChild("IslandPlots")

local BUTTONS = { "music", "Audio", "LapisSound", "Low-Graphic-Mode", "Allow-Players-Plot", "pvp" }

--------------------------------------------------
-- billboard buttons
--------------------------------------------------
local function isMyPlot(plot)
	local owner = plot:FindFirstChild("Owner")
	return owner ~= nil and owner.Value == player.Name
end

local hooked = {}
local function hookPlot(plot)
	local lb = plot:WaitForChild("Leaderboard", 10)
	local stats = lb and lb:WaitForChild("stats", 10)
	if not stats then return end
	for _, part in ipairs(stats:GetChildren()) do
		local gui = part:IsA("BasePart") and part:FindFirstChildOfClass("SurfaceGui")
		if gui then
			gui.Active = true
			for _, name in ipairs(BUTTONS) do
				local holder = gui:FindFirstChild(name, true)
				local btn = holder and holder:FindFirstChildOfClass("ImageButton")
				if btn and not hooked[btn] then
					hooked[btn] = true
					btn.Active = true
					btn.Activated:Connect(function()
						if not isMyPlot(plot) then return end -- only the owner changes their settings
						if name == "pvp" then
							-- same remote the HUD PvP button uses
							local ev = ReplicatedStorage:FindFirstChild("AccessibleEvents")
							ev = ev and ev:FindFirstChild("pvptoggle")
							if ev then ev:FireServer() end
						else
							remote:FireServer(name)
						end
						-- click feedback
						local label = holder:FindFirstChildOfClass("TextLabel")
						if label then
							local size = label.TextSize
							label.TextTransparency = 0.4
							task.delay(0.12, function() label.TextTransparency = 0 end)
						end
					end)
				end
			end
		end
	end
end
for _, plot in ipairs(plotsFolder:GetChildren()) do task.spawn(hookPlot, plot) end
plotsFolder.ChildAdded:Connect(function(p) task.spawn(hookPlot, p) end)

--------------------------------------------------
-- audio
--------------------------------------------------
local musicFolder = SoundService:WaitForChild("Music", 10)

local function setting(attr, default)
	local v = player:GetAttribute(attr)
	if v == nil then return default end
	return v
end

local function isMusic(sound)
	return musicFolder ~= nil and sound:IsDescendantOf(musicFolder)
end

-- Remember a sound's real volume the first time we touch it, then drive
-- it between that and 0.
local function applyTo(sound)
	if not sound:IsA("Sound") then return end
	if sound:GetAttribute("SetOrigVolume") == nil then
		sound:SetAttribute("SetOrigVolume", sound.Volume)
	end
	local audioOn = setting("Set_Audio", true)
	local on = audioOn and (not isMusic(sound) or setting("Set_Music", true))
	sound.Volume = on and sound:GetAttribute("SetOrigVolume") or 0
end

local function applyAudio()
	for _, d in ipairs(game:GetDescendants()) do
		local ok, isSound = pcall(function() return d:IsA("Sound") end)
		if ok and isSound then pcall(applyTo, d) end
	end
end

-- new sounds (pickups, effects) follow the current setting
game.DescendantAdded:Connect(function(d)
	local ok, isSound = pcall(function() return d:IsA("Sound") end)
	if ok and isSound then
		task.defer(function()
			if setting("Set_Audio", true) and (not isMusic(d) or setting("Set_Music", true)) then
				return -- nothing muted; leave its volume alone
			end
			pcall(applyTo, d)
		end)
	end
end)

player:GetAttributeChangedSignal("Set_Audio"):Connect(applyAudio)
player:GetAttributeChangedSignal("Set_Music"):Connect(applyAudio)

--------------------------------------------------
-- low graphics (PerformanceManager also reads LowGraphics)
--------------------------------------------------
local savedFx = nil
local function applyGraphics()
	local low = setting("Set_LowGraphics", false)
	if low and not savedFx then
		savedFx = { Shadows = Lighting.GlobalShadows, Effects = {} }
		Lighting.GlobalShadows = false
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:IsA("PostEffect") then
				savedFx.Effects[e] = e.Enabled
				e.Enabled = false
			end
		end
	elseif not low and savedFx then
		Lighting.GlobalShadows = savedFx.Shadows
		for e, was in pairs(savedFx.Effects) do
			if e.Parent then e.Enabled = was end
		end
		savedFx = nil
	end
end
player:GetAttributeChangedSignal("Set_LowGraphics"):Connect(applyGraphics)

task.delay(2, function()
	applyAudio()
	applyGraphics()
end)
