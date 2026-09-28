--==================================================
-- FINAL BOSS LOBBY  (SERVER)
--
-- The "CHALLENGE" prompt on a base's bossfight portal
-- (Upgrades > Purchases > bossfight > teleport) opens a
-- party lobby -- but only for that base's OWNER. The
-- owner invites people in the server (friends listed
-- first), invitees accept/decline, and START teleports
-- the whole party together into the FINAL BOSS game.
--
-- FINAL BOSS is a place INSIDE this experience (published
-- under [v1.0] BECOME LA PEACE), so each party gets its own
-- brand-new reserved (private) server there -- nobody else
-- can ever join it.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Only players who have bought the Bossfight base upgrade can be in a
-- party (BaseUpgradeService mirrors it as the BossfightUnlocked attribute).
local function isEligible(player)
	return player:GetAttribute("BossfightUnlocked") == true
end

local CONFIG = {
	FINAL_BOSS_PLACE_ID = 116187247764372, -- (the FINAL BOSS place in this experience; the old separate game was 108636690706753)
	MAX_PARTY = 8,
	COUNTDOWN = 3,
	INVITE_COOLDOWN = 2,
}

local remote = ReplicatedStorage:FindFirstChild("FinalBossLobby")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "FinalBossLobby"
	remote.Parent = ReplicatedStorage
end

-- lobbies[hostUserId] = { Host = Player, Members = {Player}, Invited = {[userId]=true}, Starting = bool }
local lobbies = {}
-- memberOf[userId] = hostUserId   (host included)
local memberOf = {}
local lastInvite = {}

--==================================================
-- HELPERS
--==================================================

local plotsFolder = workspace:WaitForChild("Islands"):WaitForChild("StarterIsland"):WaitForChild("IslandPlots")

local function plotOwnerName(plot)
	local owner = plot:FindFirstChild("Owner")
	return owner and owner.Value or nil
end

local function snapshot(lobby)
	local members = {}
	for _, p in ipairs(lobby.Members) do
		table.insert(members, { UserId = p.UserId, Name = p.Name, DisplayName = p.DisplayName })
	end
	local invited = {}
	for userId in pairs(lobby.Invited) do
		table.insert(invited, userId)
	end
	return {
		HostId = lobby.Host.UserId,
		HostName = lobby.Host.DisplayName,
		Members = members,
		Invited = invited,
		Max = CONFIG.MAX_PARTY,
		Starting = lobby.Starting,
	}
end

local function broadcast(lobby)
	local state = snapshot(lobby)
	for _, p in ipairs(lobby.Members) do
		remote:FireClient(p, "State", state)
	end
end

local function toast(player, text)
	remote:FireClient(player, "Toast", text)
end

local function removeMember(lobby, player)
	for i, p in ipairs(lobby.Members) do
		if p == player then
			table.remove(lobby.Members, i)
			break
		end
	end
	memberOf[player.UserId] = nil
end

local function closeLobby(hostUserId, reason)
	local lobby = lobbies[hostUserId]
	if not lobby then return end
	lobbies[hostUserId] = nil
	for _, p in ipairs(lobby.Members) do
		memberOf[p.UserId] = nil
		remote:FireClient(p, "Closed", reason)
	end
	-- withdraw pending invites
	for userId in pairs(lobby.Invited) do
		local p = Players:GetPlayerByUserId(userId)
		if p then remote:FireClient(p, "InviteRevoked", hostUserId) end
	end
end

local function leaveCurrent(player, reason)
	local hostId = memberOf[player.UserId]
	if not hostId then return end
	if hostId == player.UserId then
		closeLobby(hostId, reason or "The host closed the lobby.")
	else
		local lobby = lobbies[hostId]
		if lobby then
			removeMember(lobby, player)
			remote:FireClient(player, "Closed", reason or "You left the lobby.")
			broadcast(lobby)
		end
	end
end

--==================================================
-- OPEN FROM THE PORTAL PROMPT
--==================================================

local function openFor(player, plot)
	if plotOwnerName(plot) ~= player.Name then
		toast(player, "Only the owner of this base can start a Final Boss lobby.")
		return
	end
	if not isEligible(player) then
		toast(player, "Unlock the Final Boss base upgrade first.")
		return
	end

	local current = memberOf[player.UserId]
	if current and current ~= player.UserId then
		leaveCurrent(player)
	end

	local lobby = lobbies[player.UserId]
	if not lobby then
		lobby = { Host = player, Members = { player }, Invited = {}, Starting = false }
		lobbies[player.UserId] = lobby
		memberOf[player.UserId] = player.UserId
	end
	remote:FireClient(player, "Open")
	broadcast(lobby)
end

local hooked = {}
local function hookPrompt(prompt)
	if hooked[prompt] then return end
	hooked[prompt] = true
	local plot = prompt:FindFirstAncestorWhichIsA("Model")
	-- walk up to the plot (direct child of IslandPlots)
	local node = prompt
	while node and node.Parent ~= plotsFolder do
		node = node.Parent
	end
	plot = node
	if not plot then return end

	prompt.ActionText = "FINAL BOSS"
	prompt.ObjectText = "Create lobby"
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 1
	prompt.Triggered:Connect(function(player)
		openFor(player, plot)
	end)
end

local function scanPlot(plot)
	local purchases = plot:FindFirstChild("Upgrades") and plot.Upgrades:FindFirstChild("Purchases")
	local portal = purchases and purchases:FindFirstChild("bossfight")
	if not portal then return end
	for _, d in ipairs(portal:GetDescendants()) do
		if d:IsA("ProximityPrompt") then hookPrompt(d) end
	end
	portal.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then hookPrompt(d) end
	end)
end

for _, plot in ipairs(plotsFolder:GetChildren()) do scanPlot(plot) end
plotsFolder.ChildAdded:Connect(scanPlot)

--==================================================
-- TELEPORT
--==================================================

local function start(lobby)
	if lobby.Starting then return end
	lobby.Starting = true
	broadcast(lobby)

	for i = CONFIG.COUNTDOWN, 1, -1 do
		for _, p in ipairs(lobby.Members) do
			remote:FireClient(p, "Countdown", i)
		 end
		task.wait(1)
		if lobbies[lobby.Host.UserId] ~= lobby then return end -- closed mid-countdown
	end

	local party = {}
	for _, p in ipairs(lobby.Members) do
		if p.Parent == Players and isEligible(p) then table.insert(party, p) end
	end
	for _, p in ipairs(party) do
		remote:FireClient(p, "Teleporting")
	end

	if RunService:IsStudio() then
		for _, p in ipairs(party) do
			toast(p, "Teleports don't work in Studio -- this would send the party to FINAL BOSS.")
		end
		lobby.Starting = false
		broadcast(lobby)
		return
	end

	-- a brand-new reserved server of the FINAL BOSS place, just for this party
	local code
	for attempt = 1, 3 do
		local okR, res = pcall(function() return TeleportService:ReserveServer(CONFIG.FINAL_BOSS_PLACE_ID) end)
		if okR and res then code = res break end
		warn("[FinalBossLobby] ReserveServer failed (" .. attempt .. "): " .. tostring(res))
		task.wait(1.5)
	end
	local ok, err = false, "couldn't reserve a server"
	if code then
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData({
			PartyId = HttpService:GenerateGUID(false),
			PartySize = #party,
			FromLobbyHost = lobby.Host.UserId,
		})
		ok, err = pcall(function()
			return TeleportService:TeleportAsync(CONFIG.FINAL_BOSS_PLACE_ID, party, options)
		end)
	end
	if not ok then
		warn("[FinalBossLobby] teleport failed: " .. tostring(err))
		lobby.Starting = false
		for _, p in ipairs(party) do
			toast(p, "Teleport failed, try again in a moment.")
		end
		broadcast(lobby)
	end
end

TeleportService.TeleportInitFailed:Connect(function(player, result, message)
	local hostId = memberOf[player.UserId]
	local lobby = hostId and lobbies[hostId]
	toast(player, "Teleport failed (" .. tostring(result.Name) .. "). Try again.")
	if lobby then
		lobby.Starting = false
		broadcast(lobby)
	end
end)

--==================================================
-- CLIENT REQUESTS
--==================================================

remote.OnServerEvent:Connect(function(player, action, arg)
	local myHost = memberOf[player.UserId]
	local isHost = myHost == player.UserId
	local lobby = myHost and lobbies[myHost]

	if action == "Invite" then
		if not (isHost and lobby) or lobby.Starting then return end
		if type(arg) ~= "number" then return end
		local target = Players:GetPlayerByUserId(arg)
		if not target or target == player then return end
		if not isEligible(target) then
			toast(player, target.DisplayName .. " hasn't unlocked the Final Boss yet.")
			return
		end
		if memberOf[target.UserId] == player.UserId then return end
		if #lobby.Members >= CONFIG.MAX_PARTY then
			toast(player, "Lobby is full.")
			return
		end
		local key = player.UserId .. ":" .. target.UserId
		if lastInvite[key] and os.clock() - lastInvite[key] < CONFIG.INVITE_COOLDOWN then return end
		lastInvite[key] = os.clock()
		lobby.Invited[target.UserId] = true
		remote:FireClient(target, "Invite", player.UserId, player.DisplayName)
		broadcast(lobby)

	elseif action == "Accept" then
		if type(arg) ~= "number" then return end
		local target = lobbies[arg]
		if not (target and target.Invited[player.UserId]) then
			toast(player, "That invite has expired.")
			return
		end
		if target.Starting then return end
		if not isEligible(player) then
			toast(player, "Unlock the Final Boss base upgrade to join.")
			return
		end
		if #target.Members >= CONFIG.MAX_PARTY then
			toast(player, "That lobby is full.")
			return
		end
		if myHost then leaveCurrent(player) end
		target.Invited[player.UserId] = nil
		table.insert(target.Members, player)
		memberOf[player.UserId] = arg
		remote:FireClient(player, "Open")
		broadcast(target)

	elseif action == "Decline" then
		if type(arg) ~= "number" then return end
		local target = lobbies[arg]
		if target and target.Invited[player.UserId] then
			target.Invited[player.UserId] = nil
			toast(target.Host, player.DisplayName .. " declined your invite.")
			broadcast(target)
		end

	elseif action == "Kick" then
		if not (isHost and lobby) or lobby.Starting then return end
		local target = type(arg) == "number" and Players:GetPlayerByUserId(arg)
		if target and target ~= player and memberOf[target.UserId] == player.UserId then
			removeMember(lobby, target)
			remote:FireClient(target, "Closed", "You were removed from the lobby.")
			broadcast(lobby)
		end

	elseif action == "Leave" then
		if lobby and lobby.Starting and not isHost then return end
		leaveCurrent(player)

	elseif action == "Start" then
		if isHost and lobby then
			task.spawn(start, lobby)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	leaveCurrent(player, "The host left the server.")
	for _, lobby in pairs(lobbies) do
		if lobby.Invited[player.UserId] then
			lobby.Invited[player.UserId] = nil
			broadcast(lobby)
		end
	end
end)
