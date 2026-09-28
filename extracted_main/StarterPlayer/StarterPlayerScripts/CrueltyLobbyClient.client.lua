--==================================================
-- CRUELTY CHALLENGE LOBBY  (client)
--
-- Same shape as the Final Boss lobby so it reads as the
-- same feature, but in Cruelty's colours and with the
-- "someone else is down there right now" banner, since
-- there's only one arena to go round.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SocialService = game:GetService("SocialService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("CrueltyLobby")

local RED = Color3.fromRGB(235, 62, 54)
local EMBER = Color3.fromRGB(255, 160, 60)
local PURPLE = Color3.fromRGB(168, 70, 255)
local BG = Color3.fromRGB(20, 10, 12)
local CARD = Color3.fromRGB(42, 20, 24)
local GREEN = Color3.fromRGB(85, 220, 120)
local GREY = Color3.fromRGB(90, 78, 82)
local WHITE = Color3.fromRGB(255, 248, 240)

local state = nil
local pendingInvites = {}

--------------------------------------------------
-- helpers
--------------------------------------------------
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(r or 0.18, 0) c.Parent = p return c end
local function stroke(p, col, th)
	local s = Instance.new("UIStroke") s.Color = col s.Thickness = th or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = p return s
end
local function textStroke(p)
	local s = Instance.new("UIStroke") s.Thickness = 1.8 s.Color = Color3.new(0, 0, 0)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual s.Parent = p
end

local function label(parent, text, size, pos, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size l.Position = pos
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = color or WHITE
	l.Text = text
	l.Parent = parent
	textStroke(l)
	return l
end

local function button(parent, text, size, pos, color)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.Size = size b.Position = pos
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = WHITE
	b.Text = text
	b.Parent = parent
	corner(b, 0.25)
	textStroke(b)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0) pad.PaddingBottom = UDim.new(0.18, 0)
	pad.PaddingLeft = UDim.new(0.06, 0) pad.PaddingRight = UDim.new(0.06, 0)
	pad.Parent = b
	return b
end

--------------------------------------------------
-- build
--------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CrueltyLobby"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 61
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.62, 0.66)
panel.BackgroundColor3 = BG
panel.BackgroundTransparency = 0.04
panel.Visible = false
panel.Parent = gui
corner(panel, 0.04)
stroke(panel, RED, 3)
local ar = Instance.new("UIAspectRatioConstraint") ar.AspectRatio = 1.55 ar.Parent = panel
local sizeCap = Instance.new("UISizeConstraint") sizeCap.MaxSize = Vector2.new(900, 600) sizeCap.Parent = panel
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 60, 70))
grad.Rotation = 90
grad.Parent = panel
local panelScale = Instance.new("UIScale") panelScale.Parent = panel

local title = label(panel, "ENTER THE PORTAL", UDim2.fromScale(0.7, 0.1), UDim2.fromScale(0.15, 0.03), EMBER)
title.Font = Enum.Font.GothamBlack
local subtitle = label(panel, "", UDim2.fromScale(0.7, 0.05), UDim2.fromScale(0.15, 0.13), Color3.fromRGB(255, 200, 190))

local closeBtn = button(panel, "X", UDim2.fromScale(0.07, 0.1), UDim2.fromScale(0.91, 0.02), RED)
local cAr = Instance.new("UIAspectRatioConstraint") cAr.Parent = closeBtn

local partyHeader = label(panel, "PARTY", UDim2.fromScale(0.42, 0.06), UDim2.fromScale(0.04, 0.2), WHITE)
partyHeader.TextXAlignment = Enum.TextXAlignment.Left
local partyList = Instance.new("ScrollingFrame")
partyList.Size = UDim2.fromScale(0.44, 0.52)
partyList.Position = UDim2.fromScale(0.04, 0.27)
partyList.BackgroundColor3 = CARD
partyList.BackgroundTransparency = 0.2
partyList.ScrollBarThickness = 6
partyList.AutomaticCanvasSize = Enum.AutomaticSize.Y
partyList.CanvasSize = UDim2.new()
partyList.BorderSizePixel = 0
partyList.Parent = panel
corner(partyList, 0.04)
local pl = Instance.new("UIListLayout") pl.Padding = UDim.new(0, 6) pl.SortOrder = Enum.SortOrder.LayoutOrder pl.Parent = partyList
local pp = Instance.new("UIPadding") pp.PaddingTop = UDim.new(0.02, 0) pp.PaddingLeft = UDim.new(0.03, 0) pp.PaddingRight = UDim.new(0.05, 0) pp.Parent = partyList

local inviteHeader = label(panel, "INVITE (RECITED THE WORDS)", UDim2.fromScale(0.44, 0.06), UDim2.fromScale(0.52, 0.2), WHITE)
inviteHeader.TextXAlignment = Enum.TextXAlignment.Left
local inviteList = partyList:Clone()
inviteList.Position = UDim2.fromScale(0.52, 0.27)
inviteList.Parent = panel
for _, c in ipairs(inviteList:GetChildren()) do
	if not (c:IsA("UIListLayout") or c:IsA("UIPadding") or c:IsA("UICorner")) then c:Destroy() end
end

local bringFriends = button(panel, "+ INVITE FRIENDS TO THIS SERVER", UDim2.fromScale(0.44, 0.08), UDim2.fromScale(0.52, 0.82), PURPLE)
local startBtn = button(panel, "ENTER THE PORTAL", UDim2.fromScale(0.3, 0.1), UDim2.fromScale(0.04, 0.84), GREEN)
local leaveBtn = button(panel, "LEAVE", UDim2.fromScale(0.12, 0.1), UDim2.fromScale(0.36, 0.84), RED)

local banner = label(panel, "", UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.4), EMBER)
banner.Font = Enum.Font.GothamBlack
banner.ZIndex = 10
banner.Visible = false

-- "someone else is in there" strip under the title
local busyStrip = Instance.new("Frame")
busyStrip.Size = UDim2.fromScale(0.92, 0.07)
busyStrip.Position = UDim2.fromScale(0.04, 0.905)
busyStrip.BackgroundColor3 = Color3.fromRGB(70, 22, 22)
busyStrip.Visible = false
busyStrip.BorderSizePixel = 0
busyStrip.Parent = panel
corner(busyStrip, 0.3)
local busyText = label(busyStrip, "", UDim2.fromScale(0.96, 0.7), UDim2.fromScale(0.02, 0.15), Color3.fromRGB(255, 170, 160))

-- invite popup
local popup = Instance.new("Frame")
popup.AnchorPoint = Vector2.new(0.5, 0)
popup.Position = UDim2.fromScale(0.5, -0.3)
popup.Size = UDim2.fromScale(0.34, 0.14)
popup.BackgroundColor3 = BG
popup.Parent = gui
corner(popup, 0.12)
stroke(popup, RED, 3)
local pAr = Instance.new("UIAspectRatioConstraint") pAr.AspectRatio = 3.4 pAr.Parent = popup
local popupText = label(popup, "", UDim2.fromScale(0.92, 0.42), UDim2.fromScale(0.04, 0.08))
local acceptBtn = button(popup, "JOIN", UDim2.fromScale(0.42, 0.36), UDim2.fromScale(0.05, 0.56), GREEN)
local declineBtn = button(popup, "DECLINE", UDim2.fromScale(0.42, 0.36), UDim2.fromScale(0.53, 0.56), RED)
local popupHost = nil

local toastLabel = label(gui, "", UDim2.fromScale(0.5, 0.05), UDim2.fromScale(0.25, 0.12), EMBER)
toastLabel.Visible = false
local toastToken = 0
local function showToast(text)
	toastToken += 1
	local my = toastToken
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(4, function() if toastToken == my then toastLabel.Visible = false end end)
end

--------------------------------------------------
-- render
--------------------------------------------------
local friendCache = {}
local function isFriend(userId)
	if friendCache[userId] == nil then
		local ok, res = pcall(function() return player:IsFriendsWith(userId) end)
		friendCache[userId] = ok and res or false
	end
	return friendCache[userId]
end

local function clearRows(list)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
end

local function row(list, order)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 0)
	f.BackgroundColor3 = Color3.fromRGB(58, 30, 34)
	f.BorderSizePixel = 0
	f.LayoutOrder = order
	f.Parent = list
	corner(f, 0.2)
	local r = Instance.new("UIAspectRatioConstraint")
	r.AspectRatio = 6.5
	r.AspectType = Enum.AspectType.ScaleWithParentSize
	r.DominantAxis = Enum.DominantAxis.Width
	r.Parent = f
	return f
end

local function avatar(parent, userId)
	local img = Instance.new("ImageLabel")
	img.BackgroundColor3 = CARD
	img.Size = UDim2.fromScale(0.15, 0.85)
	img.Position = UDim2.fromScale(0.02, 0.075)
	img.BorderSizePixel = 0
	img.Parent = parent
	corner(img, 0.5)
	local a = Instance.new("UIAspectRatioConstraint") a.Parent = img
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then img.Image = url end
	end)
end

local function recited(p)
	local stats = p:FindFirstChild("PlayerStats")
	local claimed = stats and stats:FindFirstChild("ClaimedQuests")
	return claimed ~= nil and claimed:FindFirstChild("VerityQuest2") ~= nil
end

local function render()
	if not state then return end
	local amHost = state.HostId == player.UserId
	subtitle.Text = (amHost and "YOUR PARTY" or (string.upper(state.HostName) .. "'S PARTY"))
		.. "   " .. #state.Members .. "/" .. state.Max
	startBtn.Visible = amHost
	leaveBtn.Text = amHost and "DISBAND" or "LEAVE"
	inviteHeader.Visible = amHost
	inviteList.Visible = amHost
	bringFriends.Visible = amHost

	if state.ArenaBusy then
		busyStrip.Visible = true
		busyText.Text = "\u{1F512} " .. string.upper(state.ArenaBusy) .. "'S PARTY IS INSIDE THE PORTAL RIGHT NOW"
		startBtn.Text = "ARENA BUSY"
		startBtn.BackgroundColor3 = GREY
	else
		busyStrip.Visible = false
		startBtn.Text = state.Starting and "..." or "ENTER THE PORTAL"
		startBtn.BackgroundColor3 = state.Starting and GREY or GREEN
	end

	clearRows(partyList)
	local inParty = {}
	for i, m in ipairs(state.Members) do
		inParty[m.UserId] = true
		local f = row(partyList, i)
		avatar(f, m.UserId)
		local n = label(f, (m.UserId == state.HostId and "\u{1F451} " or "") .. m.DisplayName,
			UDim2.fromScale(amHost and 0.52 or 0.78, 0.6), UDim2.fromScale(0.2, 0.2))
		n.TextXAlignment = Enum.TextXAlignment.Left
		if amHost and m.UserId ~= player.UserId then
			local kick = button(f, "KICK", UDim2.fromScale(0.22, 0.7), UDim2.fromScale(0.75, 0.15), RED)
			kick.Activated:Connect(function() remote:FireServer("Kick", m.UserId) end)
		end
	end

	if not amHost then return end
	clearRows(inviteList)
	local invited = {}
	for _, id in ipairs(state.Invited) do invited[id] = true end

	local others = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and not inParty[p.UserId] and recited(p) then
			table.insert(others, p)
		end
	end
	table.sort(others, function(a, b)
		local fa, fb = isFriend(a.UserId), isFriend(b.UserId)
		if fa ~= fb then return fa end
		return a.DisplayName:lower() < b.DisplayName:lower()
	end)

	if #others == 0 then
		local f = row(inviteList, 1)
		f.BackgroundTransparency = 1
		label(f, "Nobody else here has recited the words yet.", UDim2.fromScale(0.95, 0.6), UDim2.fromScale(0.025, 0.2), Color3.fromRGB(220, 180, 175))
	end

	for i, p in ipairs(others) do
		local f = row(inviteList, i)
		avatar(f, p.UserId)
		local n = label(f, (isFriend(p.UserId) and "\u{2B50} " or "") .. p.DisplayName, UDim2.fromScale(0.52, 0.6), UDim2.fromScale(0.2, 0.2))
		n.TextXAlignment = Enum.TextXAlignment.Left
		local pending = invited[p.UserId]
		local b = button(f, pending and "SENT" or "INVITE", UDim2.fromScale(0.22, 0.7), UDim2.fromScale(0.75, 0.15), pending and GREY or PURPLE)
		b.Activated:Connect(function()
			remote:FireServer("Invite", p.UserId)
			b.Text = "SENT"
			b.BackgroundColor3 = GREY
		end)
	end
end

local function setPanel(visible)
	if visible == panel.Visible then return end
	panel.Visible = visible
	if visible then
		panelScale.Scale = 0.85
		TweenService:Create(panelScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

local function showNextInvite()
	popupHost = nil
	for hostId, hostName in pairs(pendingInvites) do
		popupHost = hostId
		popupText.Text = string.upper(hostName) .. " WANTS YOU TO ENTER THE PORTAL!"
		TweenService:Create(popup, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.03) }):Play()
		return
	end
	TweenService:Create(popup, TweenInfo.new(0.25), { Position = UDim2.fromScale(0.5, -0.3) }):Play()
end

--------------------------------------------------
-- wiring
--------------------------------------------------
closeBtn.Activated:Connect(function() setPanel(false) end)
leaveBtn.Activated:Connect(function() remote:FireServer("Leave") end)
startBtn.Activated:Connect(function() remote:FireServer("Start") end)
bringFriends.Activated:Connect(function()
	local ok, can = pcall(function() return SocialService:CanSendGameInviteAsync(player) end)
	if ok and can then
		pcall(function() SocialService:PromptGameInvite(player) end)
	else
		showToast("Game invites aren't available right now.")
	end
end)
acceptBtn.Activated:Connect(function()
	if popupHost then
		remote:FireServer("Accept", popupHost)
		pendingInvites[popupHost] = nil
		showNextInvite()
	end
end)
declineBtn.Activated:Connect(function()
	if popupHost then
		remote:FireServer("Decline", popupHost)
		pendingInvites[popupHost] = nil
		showNextInvite()
	end
end)

remote.OnClientEvent:Connect(function(action, a, b)
	if action == "Open" then
		setPanel(true)
	elseif action == "State" then
		state = a
		banner.Visible = false
		render()
	elseif action == "Closed" then
		state = nil
		setPanel(false)
		if a then showToast(a) end
	elseif action == "Invite" then
		pendingInvites[a] = b
		showNextInvite()
	elseif action == "InviteRevoked" then
		pendingInvites[a] = nil
		if popupHost == a then showNextInvite() end
	elseif action == "Countdown" then
		setPanel(true)
		banner.Visible = true
		banner.Text = "THE PORTAL OPENS IN " .. tostring(a) .. "..."
	elseif action == "Toast" then
		showToast(a)
	end
end)

Players.PlayerAdded:Connect(function() if panel.Visible then render() end end)
Players.PlayerRemoving:Connect(function() task.defer(function() if panel.Visible then render() end end) end)
