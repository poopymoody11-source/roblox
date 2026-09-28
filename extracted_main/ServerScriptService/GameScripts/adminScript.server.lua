--==================================================
-- ADMIN SERVER SCRIPT (unchanged - no fixes needed here)
-- Place as a Script in ServerScriptService > AdminScript
--==================================================

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- The chat commands were replaced by the /cmds admin panel
-- (GameScripts.AdminPanelService). Flip this to true to bring the
-- old chat commands back.
local LEGACY_CHAT_COMMANDS = false

-- Admins are the developers in TitleDataModule.DeveloperIds (MrMajou and
-- ncncncbnc, checked by UserId) - the same list the admin panel uses.
local TitleDataForAdmins = require(game:GetService("ReplicatedStorage"):WaitForChild("AccessibleModules"):WaitForChild("TitleDataModule"))

local DEFAULT_BASE_COST = 100000
local ASCENSION_COSTS = {
	[0]  = 100000,
	[1]  = 250000,
	[2]  = 500000,
	[3]  = 1000000,
	[4]  = 2500000,
	[5]  = 5000000,
	[6]  = 10000000,
	[7]  = 25000000,
	[8]  = 50000000,
	[9]  = 100000000,
	[10] = 250000000,
	[11] = 500000000,
	[12] = 1000000000,
	[13] = 2500000000,
	[14] = 5000000000,
	[15] = 10000000000,
	[16] = 18000000000,
	[17] = 28000000000,
	[18] = 40000000000,
	[19] = 52000000000,
	[20] = 65000000000,
	[21] = 75000000000,
	[22] = 84000000000,
	[23] = 90000000000,
	[24] = 95000000000,
	[25] = 100000000000,
}

local function getRequiredPP(level, player)
	-- Prefer the shared table so /setascension and the real ascension
	-- handler always agree on what a level costs.
	local mods = game:GetService("ReplicatedStorage"):FindFirstChild("AccessibleModules")
	local admod = mods and mods:FindFirstChild("AscensionDataModule")
	if admod then
		local ok, data = pcall(require, admod)
		if ok and type(data) == "table" then
			-- GetCostFor applies the 2x Ascensions discount, so
			-- /ascend tops the player up to what they will actually
			-- be charged rather than full price.
			if type(data.GetCostFor) == "function" and player then
				return data.GetCostFor(player, level)
			end
			if type(data.GetCost) == "function" then
				return data.GetCost(level)
			end
		end
	end
	return ASCENSION_COSTS[level] or (DEFAULT_BASE_COST * (level + 1))
end

local adminBindable = ServerStorage:FindFirstChild("AdminActionBindable")
if not adminBindable then
	adminBindable = Instance.new("BindableEvent")
	adminBindable.Name = "AdminActionBindable"
	adminBindable.Parent = ServerStorage
end

--==================================================
-- WHO COUNTS AS AN ADMIN
--
-- The hardcoded list only. The OP Admin gamepass
-- deliberately grants NOTHING for now and is off sale --
-- to switch it on, uncomment the Pass_Admin line below,
-- set GrantsAdmin = true in MonetizationData.Benefits,
-- and re-enable the pass in the Creator Dashboard.
--
-- Checked per COMMAND rather than once on join, so a
-- pass that lands a second after PlayerAdded still works
-- without a rejoin.
--==================================================

local function isAdmin(player)
	if TitleDataForAdmins.IsDeveloper(player) then
		return true
	end

	-- return player:GetAttribute("Pass_Admin") == true
	return false
end

-- Partial-name match, same rule the /title command already
-- used locally. Returns nil when nothing matches so callers
-- can fall back to the caller themselves.
local function findPlayer(nameArg)
	if not nameArg then return nil end

	local lowered = nameArg:lower()
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Name:lower():sub(1, #lowered) == lowered then
			return other
		end
	end

	return nil
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if not LEGACY_CHAT_COMMANDS then return end
		if not isAdmin(player) then return end

		local args = {}
		for word in message:gmatch("%S+") do
			table.insert(args, word)
		end

		local command = args[1] and args[1]:lower()
		local leaderstats = player:FindFirstChild("leaderstats")
		local ppStat = leaderstats and leaderstats:FindFirstChild("PeacePoints")
		local ascStat = leaderstats and leaderstats:FindFirstChild("Ascensions")

		if command == "!addpp" or command == "/addpp" then
			local amount = tonumber(args[2]) or 10000000
			if ppStat then
				ppStat.Value += amount
			end

		elseif command == "!max" or command == "/max" then
			if ppStat then
				ppStat.Value += 1000000000000
			end

		elseif command == "!passes" or command == "/passes" then
			-- Re-runs the gamepass ownership check. Useful right
			-- after buying one on the website rather than in-game,
			-- which fires no PromptGamePassPurchaseFinished event.
			if type(_G.RefreshPasses) == "function" then
				_G.RefreshPasses(player)
				print("[/passes] refreshed for " .. player.Name)
			end
			if type(_G.ListPasses) == "function" then
				print("[/passes] " .. player.Name .. ":\n" .. _G.ListPasses(player))
			end

		elseif command == "!resetpasses" or command == "/resetpasses" then
			-- /resetpasses            -- yourself
			-- /resetpasses <player>   -- someone else
			--
			-- Clears every owned pass AND the one-time grant ledger,
			-- so bundles hand out their lapis again next time. In
			-- Studio the passes come back on the next join because
			-- STUDIO_GRANT_ALL re-grants them; on a live server the
			-- next ownership check restores whatever is genuinely
			-- owned, so this can't strip a paying player for good.
			local target = player
			if args[2] then
				local found = findPlayer(args[2])
				if found then target = found end
			end

			if type(_G.ResetPasses) == "function" then
				_G.ResetPasses(target)
				print("[/resetpasses] cleared for " .. target.Name)
			else
				warn("[/resetpasses] MonetizationService isn't running")
			end

		elseif command == "!givepass" or command == "/givepass" then
			-- /givepass <key> [player]   keys: see /passes
			local key = args[2]
			local target = player
			if args[3] then
				local found = findPlayer(args[3])
				if found then target = found end
			end

			if key and type(_G.GivePass) == "function" then
				if not _G.GivePass(target, key) then
					warn("[/givepass] no pass with key '" .. tostring(key) .. "'")
				end
			end

		elseif command == "!ascend" or command == "/ascend" then
			if ppStat and ascStat then
				local requiredPP = getRequiredPP(ascStat.Value, player)
				ppStat.Value = requiredPP
				if adminBindable then
					adminBindable:Fire(player, "Ascend")
				end
			end

		elseif command == "!setascension" or command == "/setascension" then
			local targetLevel = tonumber(args[2])
			if targetLevel and ascStat then
				ascStat.Value = targetLevel
			end

		elseif command == "!givelapis" or command == "/givelapis" then
			local targetItem = args[2] and args[2]:lower()
			local amount = tonumber(args[3]) or 1
			if adminBindable then
				adminBindable:Fire(player, "GiveLapis", targetItem, amount)
			end

		elseif command == "!all" or command == "/all" then
			if ppStat then
				-- Was 999,999,999,999,999. Two problems: it overflowed
				-- the old IntValue outright, and 15 digits is past the
				-- precision Luau prints cleanly, so it rendered in
				-- scientific notation. A trillion is plenty for testing.
				ppStat.Value = 1000000000000
			end
			if ascStat then
				ascStat.Value = 25
			end
			if adminBindable then
				adminBindable:Fire(player, "GiveAllMax", 999)
			end

		elseif command == "!reset" or command == "/reset" or command == "!resetdata" then
			if ppStat then ppStat.Value = 0 end
			if ascStat then ascStat.Value = 0 end
			if adminBindable then
				adminBindable:Fire(player, "WipeData")
			end
			-- Titles are their own save, so a data wipe has to clear
			-- them too or you keep La Peace on a fresh account.
			if _G.ResetTitles then
				_G.ResetTitles(player)
			end

		--==================================================
		-- /title give <id> [player]
		-- /title take <id> [player]   (take = reset + re-earn)
		-- /title list
		-- /title reset [player]
		--==================================================
		elseif command == "!title" or command == "/title" then
			local sub = args[2] and args[2]:lower()

			local function resolveTarget(nameArg)
				if not nameArg then return player end
				local lowered = nameArg:lower()
				for _, other in ipairs(Players:GetPlayers()) do
					if other.Name:lower():sub(1, #lowered) == lowered then
						return other
					end
				end
				return nil
			end

			if sub == "list" then
				if _G.ListTitles then
					print("[/title] available: " .. table.concat(_G.ListTitles(), ", "))
				end

			elseif sub == "give" then
				local titleId = args[3]
				local target = resolveTarget(args[4])
				if not titleId then
					print("[/title] usage: /title give <id> [player]")
				elseif not target then
					print("[/title] no player matching '" .. tostring(args[4]) .. "'")
				elseif _G.GrantTitle then
					local granted = _G.GrantTitle(target, titleId)
					print(("[/title] give %s -> %s : %s"):format(tostring(titleId), target.Name, tostring(granted)))
				end

			elseif sub == "reset" or sub == "take" then
				local target = resolveTarget(args[3])
				if target and _G.ResetTitles then
					_G.ResetTitles(target)
					print("[/title] reset titles for " .. target.Name)
				end

			else
				print("[/title] usage: give <id> [player] | reset [player] | list")
			end
		end
	end)
end)

--==================================================
-- ADMIN COMMANDS
-- Place in: ServerScriptService
--==================================================

--==================================================
-- ADMIN COMMANDS
-- Place in: ServerScriptService
--==================================================

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameScripts = ServerScriptService:WaitForChild("GameScripts")
local BaseUpgradeService = require(GameScripts:WaitForChild("BaseUpgradeService"))

local ADMIN_NAME = "MrMajou"
local RESET_COMMAND = "/resetupgrades"

local function handleCommand(player, message)

	if not LEGACY_CHAT_COMMANDS then return end
	if not isAdmin(player) then return end
	if message:lower() ~= RESET_COMMAND then return end

	local success = BaseUpgradeService.ResetUpgrades(player)
	print("[AdminCommands] ResetUpgrades result:", success, "TeleportUnlocked now:", player:GetAttribute("TeleportUnlocked"))
end

-- Legacy chat path (works if legacy chat/Chatted bridging is active)
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		handleCommand(player, message)
	end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.Chatted:Connect(function(message)
		handleCommand(player, message)
	end)
end

-- TextChatService path (modern chat) -- fires regardless of legacy bridging
TextChatService.MessageReceived:Connect(function(textChatMessage)
	local player = Players:GetPlayerByUserId(textChatMessage.TextSource and textChatMessage.TextSource.UserId or -1)
	if player then
		handleCommand(player, textChatMessage.Text)
	end
end)