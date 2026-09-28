--==================================================
-- PRIVATE PARTY ROUTER
--
-- BECOME LA PEACE is a different experience, and Roblox
-- only lets a game reserve private servers for its OWN
-- places. So a party from the Final Boss lobby arrives
-- here in an ordinary server first, tagged in its
-- TeleportData:
--   { PrivateParty = true, PartyId = "<guid>", PartySize = n }
-- This script gathers the party (up to WAIT_FOR seconds)
-- and immediately moves them together into a brand-new
-- RESERVED server of this place -- nobody else can ever
-- join it. Their client shows a short "entering" screen
-- instead of the cutscene while this happens; the
-- cutscene plays once they're in the private server.
--==================================================

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local WAIT_FOR = 12
local MAX_ATTEMPTS = 3

local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
-- clients can't read PrivateServerId, so publish the answer
workspace:SetAttribute("IsReservedServer", isReserved)

if isReserved or RunService:IsStudio() then
	return
end

-- parties[partyId] = { Players = {}, Size = n, Started = os.clock(), Sent = false }
local parties = {}
-- one reserved server per party, remembered so a member who loads in late
-- (after the rest were already sent) joins THEIR server, not a new empty one
-- codes[partyId] = { Code = accessCode, At = os.clock() }
local codes = {}
local CODE_TTL = 15 * 60

local function codeFor(partyId)
	local entry = codes[partyId]
	if entry and os.clock() - entry.At < CODE_TTL then return entry.Code end
	for attempt = 1, MAX_ATTEMPTS do
		local ok, code = pcall(function() return TeleportService:ReserveServer(game.PlaceId) end)
		if ok and code then
			codes[partyId] = { Code = code, At = os.clock() }
			return code
		end
		warn("[PrivatePartyRouter] ReserveServer failed (" .. attempt .. "): " .. tostring(code))
		task.wait(2)
	end
	return nil
end

local function sendList(partyId, list)
	local code = codeFor(partyId)
	if not code then return false end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({ FromPrivateParty = partyId, PartySize = #list })
	for attempt = 1, MAX_ATTEMPTS do
		local ok, err = pcall(function()
			return TeleportService:TeleportAsync(game.PlaceId, list, options)
		end)
		if ok then return true end
		warn("[PrivatePartyRouter] reserved teleport failed (" .. attempt .. "): " .. tostring(err))
		task.wait(2)
	end
	return false
end

local function send(partyId)
	local party = parties[partyId]
	if not party or party.Sent then return end
	party.Sent = true

	local list = {}
	for _, p in ipairs(party.Players) do
		if p.Parent == Players then table.insert(list, p) end
	end
	if #list > 0 then sendList(partyId, list) end
	parties[partyId] = nil
end

-- forget old codes
task.spawn(function()
	while true do
		task.wait(60)
		for id, entry in pairs(codes) do
			if os.clock() - entry.At > CODE_TTL then codes[id] = nil end
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	local data = player:GetJoinData()
	local td = data and data.TeleportData
	if type(td) ~= "table" or not td.PrivateParty or type(td.PartyId) ~= "string" then
		return
	end

	player:SetAttribute("PartyTransit", true)

	-- the rest of the party already left: follow them into their server
	if codes[td.PartyId] and not parties[td.PartyId] then
		task.delay(1.5, function()
			if player.Parent == Players then sendList(td.PartyId, { player }) end
		end)
		return
	end

	local party = parties[td.PartyId]
	if not party then
		party = { Players = {}, Size = math.clamp(tonumber(td.PartySize) or 1, 1, 50), Started = os.clock(), Sent = false }
		parties[td.PartyId] = party
		task.delay(WAIT_FOR, function() send(td.PartyId) end)
	end
	table.insert(party.Players, player)

	if #party.Players >= party.Size then
		-- a beat so everyone's client has loaded the transit screen
		task.delay(1.5, function() send(td.PartyId) end)
	end
end)

-- if a reserve teleport fails for someone, try them again on their own
TeleportService.TeleportInitFailed:Connect(function(player, result, message)
	warn("[PrivatePartyRouter] " .. player.Name .. ": " .. tostring(result) .. " " .. tostring(message))
	task.wait(2)
	if player.Parent ~= Players then return end
	-- retry into the SAME reserved server as their party
	local data = player:GetJoinData()
	local td = data and data.TeleportData
	if type(td) == "table" and type(td.PartyId) == "string" then
		sendList(td.PartyId, { player })
	end
end)
