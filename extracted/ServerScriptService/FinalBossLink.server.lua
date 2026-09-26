--==================================================
-- FINAL BOSS LINK  (SERVER)
--
-- Keeps FINAL BOSS connected to BECOME LA PEACE:
--
-- 1. PORTAL-ONLY ENTRY. The fight only happens in the
--    private (reserved) servers PrivatePartyRouter makes
--    for parties that came through the portal in BLP.
--    Anyone who lands in a PUBLIC server without portal
--    teleport data (joined from the game page, a friend
--    join, etc.) is sent back to BECOME LA PEACE.
--    Developers are exempt so you can still test.
--
-- 2. RETURN TRIP. When the Anti-Spiral is defeated
--    (BossService sets FC_BossDefeated), everyone in the
--    server is teleported home with BeatFinalBoss = true,
--    which BLP's FinalBossReturn turns into the
--    SPIRAL KING title.
--
-- 3. FAILING THE DIVE. Take too many hits in the dodge
--    during the dive and you're sent home early
--    (TeleportData FailedFinalBoss = true).
--
-- REQUIRED: Game Settings > Security > "Allow Third Party
-- Teleports" ON in BOTH experiences.
--==================================================

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local BLP_PLACE_ID = 117079564433820
local RETURN_DELAY = 12 -- seconds to enjoy the victory before going home

local DEVELOPERS = {
	["MrMajou"] = true,
	["SpedcialEd_Kid"] = true,
	["ncncbnc"] = true,
}

local function isDeveloper(player)
	return DEVELOPERS[player.Name] == true or player.UserId == game.CreatorId
end

local function isReserved()
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

local function sendHome(list, data)
	if #list == 0 then return end
	if RunService:IsStudio() then
		print("[FinalBossLink] (Studio) would send " .. #list .. " player(s) to BECOME LA PEACE")
		return
	end
	local options = Instance.new("TeleportOptions")
	if data then options:SetTeleportData(data) end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			return TeleportService:TeleportAsync(BLP_PLACE_ID, list, options)
		end)
		if ok then return end
		warn("[FinalBossLink] teleport home failed (" .. attempt .. "): " .. tostring(err))
		task.wait(2)
	end
end

--------------------------------------------------------
-- 1. portal-only entry
--------------------------------------------------------
local function cameThroughPortal(player)
	local data = player:GetJoinData()
	local td = data and data.TeleportData
	return type(td) == "table" and (td.PrivateParty == true or td.FromPrivateParty ~= nil)
end

local function gate(player)
	if RunService:IsStudio() or isReserved() then return end
	if isDeveloper(player) or cameThroughPortal(player) then return end
	player:SetAttribute("FC_Transit", true) -- keep them out of any cutscene roster
	task.wait(2)
	if player.Parent ~= Players then return end
	sendHome({ player })
	task.wait(15)
	if player.Parent == Players then
		player:Kick("The Final Boss can only be reached through the portal in BECOME LA PEACE.")
	end
end

Players.PlayerAdded:Connect(function(p) task.spawn(gate, p) end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(gate, p) end

--------------------------------------------------------
-- 2. return trip after the win
--------------------------------------------------------
local sent = false
local function onDefeated()
	if sent or workspace:GetAttribute("FC_BossDefeated") ~= true then return end
	sent = true
	task.wait(RETURN_DELAY)
	sendHome(Players:GetPlayers(), { BeatFinalBoss = true })
end
workspace:GetAttributeChangedSignal("FC_BossDefeated"):Connect(onDefeated)
onDefeated()

--------------------------------------------------------
-- 3. failing the dive: a player who takes too many hits in
--    the DRAG dodge (client Dodge module) is sent home
--------------------------------------------------------
local FC = game:GetService("ReplicatedStorage"):WaitForChild("FinalCutscene")
local failEvent = FC:FindFirstChild("DodgeFailed")
if not failEvent then
	failEvent = Instance.new("RemoteEvent")
	failEvent.Name = "DodgeFailed"
	failEvent.Parent = FC
end
local failed = {}
failEvent.OnServerEvent:Connect(function(player)
	if failed[player] then return end
	-- (only while the cutscene is actually running)
	if workspace:GetAttribute("FC_State") ~= "Cutscene" then return end
	failed[player] = true
	sendHome({ player }, { FailedFinalBoss = true })
end)
Players.PlayerRemoving:Connect(function(p) failed[p] = nil end)
