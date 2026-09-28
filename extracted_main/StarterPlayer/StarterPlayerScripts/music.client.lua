--==================================================
-- BACKGROUND MUSIC  (client)
--
-- Shuffles the calm tycoon playlist in SoundService.Music (Roblox-licensed
-- APM / DistroKid catalogue, free to use in experiences; the old phonk
-- tracks are kept in ServerStorage.PhonkMusicBackup), crossfades between
-- songs and respects the Music / Audio settings on the plot billboard.
--
-- Bottom-right controller: play/pause, skip, volume. The song name
-- slides out only when a new song starts, then tucks away again.
--==================================================

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local musicFolder = SoundService:WaitForChild("Music")

local BASE_VOLUME = 0.25
local FADE = 2.5
local userVolume = 1      -- 0..1 from the slider
local paused = false
local inCutscene = false  -- any cutscene has the screen: the music sits it out

local function musicOn()
	return player:GetAttribute("Set_Audio") ~= false and player:GetAttribute("Set_Music") ~= false
end
local function target()
	if paused or inCutscene or not musicOn() then return 0 end
	return BASE_VOLUME * userVolume
end

repeat task.wait(0.5) until not playerGui:FindFirstChild("IntroCutscene")

local songs = {}
for _, s in ipairs(musicFolder:GetChildren()) do
	if s:IsA("Sound") then
		s.Looped = false
		s.Volume = 0
		s:SetAttribute("SetOrigVolume", BASE_VOLUME)
		table.insert(songs, s)
	end
end
if #songs == 0 then return end

local ok = {}
pcall(function()
	ContentProvider:PreloadAsync(songs, function(id, status)
		if status == Enum.AssetFetchStatus.Success then ok[id] = true end
	end)
end)
local playable = {}
for _, s in ipairs(songs) do
	if ok[s.SoundId] then table.insert(playable, s) else s:Stop() end
end
if #playable == 0 then return end

--------------------------------------------------
-- controller UI
--------------------------------------------------
local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end
local ACCENT = Color3.fromRGB(120, 90, 255)

local old = playerGui:FindFirstChild("NowPlaying") if old then old:Destroy() end
local gui = new("ScreenGui", { Name = "NowPlaying", ResetOnSpawn = false, DisplayOrder = 5, Parent = playerGui })
local bar = new("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(150, 40),
	BackgroundColor3 = Color3.fromRGB(15, 15, 25), BackgroundTransparency = 0.15, ClipsDescendants = true, Parent = gui,
}, { new("UICorner", { CornerRadius = UDim.new(0, 12) }), new("UIStroke", { Color = ACCENT, Thickness = 1.5 }) })

local function btn(text, x)
	return new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Color3.fromRGB(40, 40, 60), Text = text, Font = Enum.Font.GothamBold, TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1), Parent = bar,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end
local skipBtn = btn("⏭", -6)
local playBtn = btn("⏸", -40)
local volBtn = btn("🔊", -74)
local noteLabel = new("TextLabel", {
	Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -120, 1, 0), BackgroundTransparency = 1,
	Text = "♪", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = bar,
})

-- volume popup (slider)
local volPop = new("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -102), Size = UDim2.fromOffset(170, 36),
	BackgroundColor3 = Color3.fromRGB(15, 15, 25), BackgroundTransparency = 0.1, Visible = false, Parent = gui,
}, { new("UICorner", { CornerRadius = UDim.new(0, 10) }), new("UIStroke", { Color = ACCENT, Thickness = 1.5 }) })
local track = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.new(1, -28, 0, 6),
	BackgroundColor3 = Color3.fromRGB(50, 50, 70), Parent = volPop,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local fill = new("Frame", { Size = UDim2.fromScale(userVolume, 1), BackgroundColor3 = ACCENT, Parent = track }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local knob = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(userVolume, 0.5), Size = UDim2.fromOffset(14, 14),
	BackgroundColor3 = Color3.new(1, 1, 1), Parent = track,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

local current
local function fadeTo(sound, vol, time)
	TweenService:Create(sound, TweenInfo.new(time or FADE), { Volume = vol }):Play()
end
local function refreshVolume(time)
	if current then fadeTo(current, target(), time or 0.3) end
	volBtn.Text = (userVolume <= 0.01) and "🔇" or "🔊"
end

local dragging = false
local function setFromX(x)
	local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
	userVolume = rel
	fill.Size = UDim2.fromScale(rel, 1)
	knob.Position = UDim2.fromScale(rel, 0.5)
	refreshVolume(0.1)
end
track.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		setFromX(i.Position.X)
	end
end)
UserInputService.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		setFromX(i.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
volBtn.MouseButton1Click:Connect(function() volPop.Visible = not volPop.Visible end)

-- song name only when a song starts
local collapsed = UDim2.fromOffset(150, 40)
local expanded = UDim2.fromOffset(360, 40)
local showToken = 0
local function showName(name)
	showToken += 1
	local my = showToken
	noteLabel.Text = "♪  " .. name
	TweenService:Create(bar, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = expanded }):Play()
	task.delay(5, function()
		if showToken ~= my then return end
		noteLabel.Text = "♪"
		TweenService:Create(bar, TweenInfo.new(0.3), { Size = collapsed }):Play()
	end)
end

player:GetAttributeChangedSignal("Set_Music"):Connect(function() refreshVolume(0.5) end)
player:GetAttributeChangedSignal("Set_Audio"):Connect(function() refreshVolume(0.5) end)

--------------------------------------------------
-- playlist
--------------------------------------------------
local queue, last = {}, nil
local function nextSong()
	if #queue == 0 then
		for _, s in ipairs(playable) do table.insert(queue, s) end
		for i = #queue, 2, -1 do local j = math.random(i) queue[i], queue[j] = queue[j], queue[i] end
		if queue[1] == last and #queue > 1 then queue[1], queue[#queue] = queue[#queue], queue[1] end
	end
	last = table.remove(queue, 1)
	return last
end

--------------------------------------------------
-- cutscenes: fade out and hold the song while ANY cutscene is on
-- (a HideHud_* attribute, a scripted camera, or the intro), then pick
-- up exactly where it left off
--------------------------------------------------
local function cutsceneActive()
	for k, v in pairs(player:GetAttributes()) do
		if v and k:sub(1, 8) == "HideHud_" then return true end
	end
	local cam = workspace.CurrentCamera
	if cam and cam.CameraType == Enum.CameraType.Scriptable then return true end
	if playerGui:FindFirstChild("IntroCutscene") ~= nil then return true end
	-- a boss track is up (Cruelty fight etc.): the playlist sits it out
	local boss = SoundService:FindFirstChild("BossMusic")
	if boss then
		for _, s in ipairs(boss:GetChildren()) do
			if s:IsA("Sound") and s.IsPlaying then return true end
		end
	end
	if player:GetAttribute("InBossFight") then
		local cc = workspace:FindFirstChild("CrueltyCutscene")
		local dummy = cc and cc:FindFirstChild("Cruelty")
		if dummy and dummy:GetAttribute("FightActive") then return true end
	end
	return false
end
local function syncCutscene()
	local now = cutsceneActive()
	if now == inCutscene then return end
	inCutscene = now
	local song = current
	if not song then return end
	if inCutscene then
		fadeTo(song, 0, 0.4)
		task.delay(0.45, function() if inCutscene and current == song then song:Pause() end end)
	elseif not paused then
		if not song.IsPlaying then song:Resume() end
		refreshVolume(1.5)
	end
end
player.AttributeChanged:Connect(function(k) if k:sub(1, 8) == "HideHud_" then syncCutscene() end end)
task.spawn(function()
	while true do
		task.wait(0.3)
		syncCutscene()
	end
end)

local skipRequested = false
skipBtn.MouseButton1Click:Connect(function() skipRequested = true end)
playBtn.MouseButton1Click:Connect(function()
	paused = not paused
	playBtn.Text = paused and "▶" or "⏸"
	if current then
		if paused then
			fadeTo(current, 0, 0.3)
			task.delay(0.3, function() if paused and current then current:Pause() end end)
		elseif not inCutscene then
			current:Resume()
			refreshVolume(0.4)
		end
	end
end)

while true do
	local song = nextSong()
	local prev = current
	current = song
	song.TimePosition = 0
	song.Volume = 0
	song:Play()
	if paused or inCutscene then song:Pause() end
	fadeTo(song, target())
	if prev then
		fadeTo(prev, 0, 1.2)
		task.delay(1.3, function() if prev ~= current then prev:Stop() end end)
	end
	if musicOn() then showName(song.Name) end

	local length = song.TimeLength
	if length <= 0 then length = 120 end
	skipRequested = false
	while not skipRequested do
		task.wait(0.25)
		-- (a paused song during a cutscene is NOT a finished song)
		if not paused and not inCutscene and (not song.IsPlaying or song.TimePosition >= length - FADE) then break end
	end
end
