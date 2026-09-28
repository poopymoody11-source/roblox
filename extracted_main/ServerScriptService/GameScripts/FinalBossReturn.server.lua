--==================================================
-- FINAL BOSS RETURN
--
-- FINAL BOSS is a separate place (a sub-place of this experience), so this can't
-- see the fight. Instead, when a winner is sent home the
-- other place puts BeatFinalBoss = true in the teleport
-- data, and this hands out the SPIRAL KING title (and its
-- Gurren Lagann spiral aura) the moment they land.
--
-- In FINAL BOSS, teleport them back with:
--     local options = Instance.new("TeleportOptions")
--     options:SetTeleportData({ BeatFinalBoss = true })
--     TeleportService:TeleportAsync(117079564433820, {player}, options)
--==================================================

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local function grantSpiralKing(player, justWon)
	-- TitleService loads the player's titles on join; keep trying until it
	-- has actually stuck. (GrantTitle returns false both for "already had
	-- it" and "titles not loaded yet" -- the old loop gave up on the first
	-- false, so a winner landing before their titles loaded got nothing.)
	for _ = 1, 120 do -- up to a minute
		if not player.Parent then return end
		if type(_G.GrantTitle) == "function" then
			local ok, granted = pcall(_G.GrantTitle, player, "spiral_king")
			local has = type(_G.HasTitle) == "function" and _G.HasTitle(player, "spiral_king")
			if ok and (granted == true or has == true) then
				print("[FinalBossReturn] SPIRAL KING -> " .. player.Name)
				-- straight off the win: put it on, aura and all
				if justWon and type(_G.EquipTitle) == "function" then pcall(_G.EquipTitle, player, "spiral_king") end
				return
			end
		end
		task.wait(0.5)
	end
	warn("[FinalBossReturn] couldn't give SPIRAL KING to " .. player.Name .. " (titles never loaded)")
end

-- the "Spiral King" badge is awarded by FINAL BOSS the moment the boss
-- falls, so even a winner who comes back later (or whose return teleport
-- failed) still gets the aura here
local SPIRAL_KING_BADGE = 2998582809220098
local BadgeService = game:GetService("BadgeService")

local function hasBadge(player)
	for _ = 1, 3 do
		local ok, owns = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, SPIRAL_KING_BADGE)
		if ok then return owns end
		task.wait(2)
	end
	return false
end

local function onJoin(player)
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	local teleportData = ok and data and data.TeleportData
	local justWon = type(teleportData) == "table" and teleportData.BeatFinalBoss == true
	if justWon then
		-- make sure the badge is theirs too (FINAL BOSS awards it at the credits;
		-- this catches a failed award there)
		task.spawn(function()
			if not hasBadge(player) then
				local okB, errB = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, SPIRAL_KING_BADGE)
				if not okB then warn("[FinalBossReturn] badge award failed for " .. player.Name .. ": " .. tostring(errB)) end
			end
		end)
		grantSpiralKing(player, true)
	elseif hasBadge(player) then
		grantSpiralKing(player, false)
	end
end

Players.PlayerAdded:Connect(function(p) task.spawn(onJoin, p) end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onJoin, p) end

print("[FinalBossReturn] watching for returning Final Boss winners")
