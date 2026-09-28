--==================================================
-- ADMIN PANEL  (server)
--
-- Replaces the old chat commands. Type /cmds in chat to open it.
-- Only the developers get the panel GUI at all, and every action is
-- re-checked here, so nobody else can fire it even with exploits.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local GameScripts = script.Parent
local QuestDataService = require(GameScripts:WaitForChild("QuestDataService"))
local BaseUpgradeService = require(GameScripts:WaitForChild("BaseUpgradeService"))
local MonetizationData = require(ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("MonetizationData"))
local TitleData = require(ReplicatedStorage.AccessibleModules:WaitForChild("TitleDataModule"))

-- Admins = the developers listed in TitleDataModule.DeveloperIds
-- (MrMajou, ncncncbnc). Checked by UserId.
local function isAdmin(player)
	return TitleData.IsDeveloper(player)
end

local LAPIS = {
	"all", "normal_lapis", "golden_lapis", "diamond_lapis", "emerald_lapis", "rgb_lapis",
	"totem_lapis", "verity_lapis", "hell_lapis", "67_lapis", "lapeace_lapis",
	"malevolent_lapis", "interstellar_lapis", "op_lapis",
}

local function adminBindable()
	return ServerStorage:FindFirstChild("AdminActionBindable")
end

local function ascensionCost(player, level)
	local mod = ReplicatedStorage.AccessibleModules:FindFirstChild("AscensionDataModule")
	local ok, data = pcall(require, mod)
	if ok and type(data) == "table" then
		if data.GetCostFor then return data.GetCostFor(player, level) end
		if data.GetCost then return data.GetCost(level) end
	end
	return 100000 * (level + 1)
end

-- remotes
local remote = ReplicatedStorage:FindFirstChild("AdminPanelRemote") or Instance.new("RemoteFunction")
remote.Name = "AdminPanelRemote"
remote.Parent = ReplicatedStorage

local openEvent = ReplicatedStorage:FindFirstChild("AdminPanelOpen") or Instance.new("RemoteEvent")
openEvent.Name = "AdminPanelOpen"
openEvent.Parent = ReplicatedStorage

-- /cmds as a real chat command so it doesn't get posted in chat
local command = TextChatService:FindFirstChild("AdminCmdsCommand")
if not command then
	command = Instance.new("TextChatCommand")
	command.Name = "AdminCmdsCommand"
	command.PrimaryAlias = "/cmds"
	command.SecondaryAlias = "/admin"
	command.Parent = TextChatService
end

--==================================================
-- ACTIONS
--==================================================

local function stats(target)
	local ls = target:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("PeacePoints"), ls and (ls:FindFirstChild("Ascensions") or ls:FindFirstChild("Rebirths"))
end

local function regrantQuestTools(target)
	local accessible = ReplicatedStorage:FindFirstChild("AccessibleModels")
	local backpack = target:FindFirstChild("Backpack")
	if not accessible or not backpack then return end
	for _, name in ipairs({ "Bat", "VerityBat" }) do
		local src = accessible:FindFirstChild(name)
		local has = backpack:FindFirstChild(name) or (target.Character and target.Character:FindFirstChild(name))
		if src and not has then src:Clone().Parent = backpack end
	end
end

local function removeQuestTools(target)
	for _, holder in ipairs({ target:FindFirstChild("Backpack"), target.Character }) do
		if holder then
			for _, name in ipairs({ "Bat", "VerityBat", "Poop", "VillagerKey" }) do
				local t = holder:FindFirstChild(name)
				if t and t:IsA("Tool") then t:Destroy() end
			end
		end
	end
end

local ACTIONS = {}

ACTIONS.AddPP = function(target, amount)
	local pp = stats(target)
	amount = tonumber(amount) or 10000000
	if not pp then return false, "no PeacePoints stat" end
	pp.Value += amount
	return true, ("+%s PP"):format(amount)
end

ACTIONS.SetPP = function(target, amount)
	local pp = stats(target)
	amount = tonumber(amount)
	if not pp or not amount then return false, "enter an amount" end
	pp.Value = amount
	return true, "PP set to " .. amount
end

ACTIONS.MaxPP = function(target)
	local pp = stats(target)
	if not pp then return false, "no PeacePoints stat" end
	pp.Value += 1000000000000
	return true, "+1T PP"
end

ACTIONS.Ascend = function(target)
	local pp, asc = stats(target)
	if not pp or not asc then return false, "no stats" end
	pp.Value = ascensionCost(target, asc.Value)
	local b = adminBindable()
	if b then b:Fire(target, "Ascend") end
	return true, "ascended"
end

ACTIONS.SetAscension = function(target, amount)
	local _, asc = stats(target)
	amount = tonumber(amount)
	if not asc or not amount then return false, "enter an amount" end
	asc.Value = math.max(0, math.floor(amount))
	return true, "ascensions set to " .. asc.Value
end

ACTIONS.GiveLapis = function(target, amount, id)
	id = id and id:lower()
	if not id or not table.find(LAPIS, id) then return false, "pick a lapis" end
	local b = adminBindable()
	if not b then return false, "AdminActionBindable missing" end
	b:Fire(target, "GiveLapis", id, tonumber(amount) or 1)
	return true, ("gave %s x%s"):format(id, tonumber(amount) or 1)
end

ACTIONS.GiveEverything = function(target)
	local pp, asc = stats(target)
	if pp then pp.Value = 1000000000000 end
	if asc then asc.Value = 25 end
	local b = adminBindable()
	if b then b:Fire(target, "GiveAllMax", 999) end
	return true, "1T PP, 25 ascensions, 999 of every lapis"
end

ACTIONS.GiveAllQuests = function(target)
	if not QuestDataService.GiveAllQuests(target) then return false, "quest data not loaded" end
	regrantQuestTools(target)
	target:SetAttribute("QuestsRefresh", os.clock())
	return true, "all quests completed"
end

ACTIONS.ResetQuests = function(target)
	if not QuestDataService.ResetQuests(target) then return false, "quest data not loaded" end
	removeQuestTools(target)
	target:SetAttribute("QuestsRefresh", os.clock())
	return true, "quests reset"
end

ACTIONS.RefreshPasses = function(target)
	if _G.RefreshPasses then _G.RefreshPasses(target) end
	return true, _G.ListPasses and _G.ListPasses(target) or "refreshed"
end

ACTIONS.GivePass = function(target, _, id)
	if not id or not _G.GivePass then return false, "pick a pass" end
	if not _G.GivePass(target, id) then return false, "no pass " .. tostring(id) end
	return true, "gave pass " .. id
end

ACTIONS.ResetPasses = function(target)
	if not _G.ResetPasses then return false, "MonetizationService not running" end
	_G.ResetPasses(target)
	return true, "passes reset"
end

ACTIONS.GiveTitle = function(target, _, id)
	if not id or not _G.GrantTitle then return false, "pick a title" end
	return _G.GrantTitle(target, id) and true or false, "title " .. id
end

ACTIONS.ResetTitles = function(target)
	if not _G.ResetTitles then return false, "TitleService not running" end
	_G.ResetTitles(target)
	return true, "titles reset"
end

ACTIONS.ResetUpgrades = function(target)
	local ok = BaseUpgradeService.ResetUpgrades(target)
	return ok and true or false, "base upgrades reset"
end

ACTIONS.WipeData = function(target)
	local pp, asc = stats(target)
	if pp then pp.Value = 0 end
	if asc then asc.Value = 0 end
	local b = adminBindable()
	if b then b:Fire(target, "WipeData") end
	if _G.ResetTitles then _G.ResetTitles(target) end
	return true, "data wiped (PP, ascensions, inventory, titles)"
end

--==================================================
-- GIVE ME EVERYTHING
-- One button for testing: max PP + ascensions, every lapis
-- and staff (OP included), every gamepass, every base
-- upgrade, every quest (so the Verity Bat comes too), every
-- title, and the Elytra. Basically a fully finished save.
--==================================================

ACTIONS.GiveEverythingPlus = function(target)
	local pp, asc = stats(target)
	if pp then pp.Value = 1000000000000 end
	if asc then asc.Value = 25 end

	local b = adminBindable()
	if b then b:Fire(target, "GiveAllMax", 999) end

	-- every gamepass (OP staff, Elytra, bundles, auto sell...)
	if _G.GivePass then
		for _, pass in ipairs(MonetizationData.Passes) do
			pcall(_G.GivePass, target, pass.Key)
		end
	end

	-- every quest, plus the tools they hand out
	QuestDataService.GiveAllQuests(target)
	regrantQuestTools(target)
	target:SetAttribute("QuestsRefresh", os.clock())

	-- beat Cruelty (unlocks the Verity Bat + its title)
	local playerStats = target:FindFirstChild("PlayerStats")
	if playerStats and not playerStats:FindFirstChild("defeatedCruelty") then
		local tag = Instance.new("BoolValue")
		tag.Name = "defeatedCruelty"
		tag.Value = true
		tag.Parent = playerStats
	end

	-- every base upgrade, including the final one
	pcall(function()
		BaseUpgradeService.SetLapisSlotTier(target.UserId, 4)
		BaseUpgradeService.SetSlotPowerTier(target.UserId, 4)
		BaseUpgradeService.SetTeleportUnlocked(target.UserId, true)
		BaseUpgradeService.SetBossfightUnlocked(target.UserId, true)
		BaseUpgradeService.SendStateToClient(target)
		local plots = workspace.Islands.StarterIsland:FindFirstChild("IslandPlots")
		for _, plot in ipairs(plots and plots:GetChildren() or {}) do
			local owner = plot:FindFirstChild("Owner")
			if owner and owner.Value == target.Name then
				BaseUpgradeService.ApplyOwnedUpgrades(plot, target.UserId)
			end
		end
	end)

	-- every title
	if _G.ListTitles and _G.GrantTitle then
		for _, id in ipairs(_G.ListTitles()) do
			pcall(_G.GrantTitle, target, id)
		end
	end

	-- the upgrade replaces the plain bat rather than sitting next to it
	for _, holder in ipairs({ target:FindFirstChild("Backpack"), target.Character }) do
		local old = holder and holder:FindFirstChild("Bat")
		if old and old:IsA("Tool") then old:Destroy() end
	end

	task.delay(1, function()
		if _G.RefreshPasses then pcall(_G.RefreshPasses, target) end
	end)

	return true, "gave EVERYTHING: 1T PP, 25 asc, all lapis/staffs, all passes, all quests, all upgrades, all titles"
end

ACTIONS.Heal = function(target)
	local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.Health = hum.MaxHealth end
	return true, "healed"
end

ACTIONS.BringHere = function(target, _, _, caller)
	local a = caller.Character and caller.Character:FindFirstChild("HumanoidRootPart")
	if not a or not target.Character then return false, "no character" end
	target.Character:PivotTo(a.CFrame * CFrame.new(0, 0, -4))
	return true, "brought " .. target.Name
end

ACTIONS.GoTo = function(target, _, _, caller)
	local a = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not a or not caller.Character then return false, "no character" end
	caller.Character:PivotTo(a.CFrame * CFrame.new(0, 0, -4))
	return true, "teleported to " .. target.Name
end

--==================================================

remote.OnServerInvoke = function(player, action, targetName, amount, id)
	if not isAdmin(player) then return false, "not allowed" end

	-- The floating ADMINISTRATOR console everyone can see needs a
	-- replicated flag; attributes set on the client stay on that client.
	if action == "SetPanelOpen" then
		player:SetAttribute("AdminPanelOpen", targetName == true)
		return true, "ok"
	end

	if action == "Meta" then
		local passes = {}
		for _, p in ipairs(MonetizationData.Passes) do table.insert(passes, p.Key) end
		local titles = {}
		for _, t in ipairs(TitleData.Titles or TitleData) do
			if type(t) == "table" and t.Id then table.insert(titles, t.Id) end
		end
		return true, { Lapis = LAPIS, Passes = passes, Titles = titles }
	end

	local fn = ACTIONS[action]
	if not fn then return false, "unknown action" end

	local target = Players:FindFirstChild(tostring(targetName)) or player
	local ok, result, msg = pcall(fn, target, amount, id, player)
	if not ok then
		warn("[AdminPanel] " .. action .. " failed: " .. tostring(result))
		return false, tostring(result)
	end
	print(("[AdminPanel] %s -> %s on %s: %s"):format(player.Name, action, target.Name, tostring(msg)))
	return result, msg
end

--==================================================
-- give the panel to the admin only
--==================================================

local function givePanel(player)
	if not isAdmin(player) then return end
	local template = ServerStorage:FindFirstChild("AdminPanelGui")
	if not template then return warn("[AdminPanel] ServerStorage.AdminPanelGui missing") end
	local pg = player:WaitForChild("PlayerGui", 20)
	if pg and not pg:FindFirstChild("AdminPanelGui") then
		template:Clone().Parent = pg
	end
end

Players.PlayerAdded:Connect(function(player)
	givePanel(player)
	player:SetAttribute("AdminPanelOpen", false)
	player.Chatted:Connect(function(msg)
		local m = msg:lower()
		if isAdmin(player) and (m == "/cmds" or m == "/admin") then
			openEvent:FireClient(player)
		end
	end)
end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(givePanel, p) end
