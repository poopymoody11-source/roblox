local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")

local BaseUpgradeService = {}

--==================================================
-- CONFIG
--==================================================

-- Slot and power tiers are deliberately STAGGERED onto different
-- ascension levels. They used to all unlock on 1 / 5 / 10 / 25, which
-- stacked an island unlock + more slots + a power tier onto the same
-- ascension and multiplied income ~30x in a single step, so the price
-- curve had to cliff to keep up. Spread out, income climbs in ~1.5-2.5x
-- steps and every few ascensions has something to look forward to.
local LAPIS_SLOT_TIERS = {
	-- (costs x0.3 for the ~25 minute run; were 3000 / 100000 / 2600000 / 9000000)
	-- (scaled so every tier is done by 12-14 ascensions: the final upgrade
	-- - the bossfight - comes at 16, so nothing may sit past it)
	{AscensionsRequired = 1,  Cost = 900,      SlotCount = 4,  Platforms = {"Platform9", "Platform4"}},
	{AscensionsRequired = 4,  Cost = 20000,    SlotCount = 6,  Platforms = {"Platform3", "Platform8"}},
	{AscensionsRequired = 8,  Cost = 250000,   SlotCount = 8,  Platforms = {"Platform2", "Platform7"}},
	{AscensionsRequired = 12, Cost = 780000,   SlotCount = 10, Platforms = {"Platform1", "Platform6"}},
}

local SLOT_POWER_TIERS = {
	-- (costs x0.3; were 49000 / 260000 / 5900000 / 17000000)
	{AscensionsRequired = 2,  Cost = 8000,      Multiplier = 2,  Color = Color3.fromRGB(120, 220, 255)},
	{AscensionsRequired = 6,  Cost = 60000,     Multiplier = 4,  Color = Color3.fromRGB(130, 255, 150)},
	{AscensionsRequired = 10, Cost = 400000,    Multiplier = 7,  Color = Color3.fromRGB(255, 200, 70)},
	{AscensionsRequired = 14, Cost = 1500000,   Multiplier = 12, Color = Color3.fromRGB(255, 70, 90)},
}

local TELEPORT_TIER = {AscensionsRequired = 1, Cost = 750} -- (was 2500)

-- "The ending". Priced at ~3-4 minutes of end-game income after reaching
-- ascension 25 (~16 min), for a ~20 minute economy + the quests = ~25 min
-- to the Final Boss. (Was 3B, for the old ~90 minute run.)
-- (now 16 ascensions, and priced for that point in the run)
local BOSSFIGHT_TIER = {AscensionsRequired = 16, Cost = 150000000}

local BASE_SLOT_PLATFORMS = {"Platform5", "Platform10"}

local DEFAULT_PLATFORM_COLOR = Color3.fromRGB(163, 162, 165)
local LOCKED_COLOR = Color3.new(0, 0, 0)
local FLASH_COLOR = Color3.new(1, 1, 1)
local COLLECTOR_ORIGINAL_COLOR_ATTRIBUTE = "OriginalCollectorColor"
local TELEPORT_ORIGINAL_TRANSPARENCY_ATTRIBUTE = "OriginalTeleportTransparency"

--==================================================
-- PERSISTENCE
--==================================================

local DATASTORE_NAME = "BaseUpgrades_v1"
local AUTO_SAVE_INTERVAL = 120

local store = DataStoreService:GetDataStore(DATASTORE_NAME)

local sessionData = {}
local dirty = {}
local isLoaded = {}
local activeUserIds = {}

local function keyFor(userId)
	return "Player_" .. userId
end

local function ensureEntry(userId)
	sessionData[userId] = sessionData[userId] or {
		LapisSlotTier = 0,
		SlotPowerTier = 0,
		TeleportUnlocked = false,
	}
	
	sessionData[userId] = sessionData[userId] or {
		LapisSlotTier = 0,
		SlotPowerTier = 0,
		TeleportUnlocked = false,
		BossfightUnlocked = false,
	}
	
	return sessionData[userId]
end

function BaseUpgradeService.Init(player)
	local userId = player.UserId

	local success, result = pcall(function()
		return store:GetAsync(keyFor(userId))
	end)

	if success and type(result) == "table" then
		sessionData[userId] = {
			LapisSlotTier = result.LapisSlotTier or 0,
			SlotPowerTier = result.SlotPowerTier or 0,
			TeleportUnlocked = result.TeleportUnlocked or false,
			-- was missing: the bossfight unlock was saved but never read
			-- back, so it silently vanished after rejoining
			BossfightUnlocked = result.BossfightUnlocked or false,
		}
	else
		sessionData[userId] = {LapisSlotTier = 0, SlotPowerTier = 0, TeleportUnlocked = false, BossfightUnlocked = false}
	end

	dirty[userId] = false
	isLoaded[userId] = true
	activeUserIds[userId] = true

	sessionData[userId].TeleportUnlocked = true
	player:SetAttribute("TeleportUnlocked", true)
	player:SetAttribute("BossfightUnlocked", sessionData[userId].BossfightUnlocked == true)
end

function BaseUpgradeService.IsLoaded(userId)
	return isLoaded[userId] == true
end

function BaseUpgradeService.FlushSave(userId)
	local data = sessionData[userId]
	if not data then return end

	local success, err = pcall(function()
		store:SetAsync(keyFor(userId), data)
	end)

	if success then
		dirty[userId] = false
	else
		warn("[BaseUpgradeService] Failed to save for userId " .. tostring(userId) .. ": " .. tostring(err))
	end
end

function BaseUpgradeService.Teardown(player)
	local userId = player.UserId
	BaseUpgradeService.FlushSave(userId)
	sessionData[userId] = nil
	dirty[userId] = nil
	isLoaded[userId] = nil
	activeUserIds[userId] = nil
end

function BaseUpgradeService.GetLapisSlotTier(userId)
	return ensureEntry(userId).LapisSlotTier
end

function BaseUpgradeService.SetLapisSlotTier(userId, tier)
	ensureEntry(userId).LapisSlotTier = tier
	dirty[userId] = true
end

function BaseUpgradeService.GetSlotPowerTier(userId)
	return ensureEntry(userId).SlotPowerTier
end

function BaseUpgradeService.SetSlotPowerTier(userId, tier)
	ensureEntry(userId).SlotPowerTier = tier
	dirty[userId] = true
end

-- (teleport isn't an upgrade any more: everyone just has it)
function BaseUpgradeService.GetTeleportUnlocked(userId)
	return true
end

function BaseUpgradeService.SetTeleportUnlocked(userId, unlocked)
	ensureEntry(userId).TeleportUnlocked = unlocked
	dirty[userId] = true
end

function BaseUpgradeService.GetBossfightUnlocked(userId)
	return ensureEntry(userId).BossfightUnlocked
end

function BaseUpgradeService.SetBossfightUnlocked(userId, unlocked)
	ensureEntry(userId).BossfightUnlocked = unlocked
	-- mirrored on the player so the Final Boss lobby can see who's eligible
	local p = Players:GetPlayerByUserId(userId)
	if p then p:SetAttribute("BossfightUnlocked", unlocked == true) end
	dirty[userId] = true
end

task.spawn(function()
	while true do
		task.wait(AUTO_SAVE_INTERVAL)
		for userId in pairs(activeUserIds) do
			if dirty[userId] then
				BaseUpgradeService.FlushSave(userId)
			end
		end
	end
end)

game:BindToClose(function()
	for userId in pairs(activeUserIds) do
		BaseUpgradeService.FlushSave(userId)
	end
end)

--==================================================
-- APPLYING VISUALS
--==================================================

local function colorAllParts(instance, color)
	if not instance then return end
	if instance:IsA("BasePart") then
		instance.Color = color
	end
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Color = color
		end
	end
end

local function setCollectorLocked(collector, locked)
	if not collector then return end

	local parts = {}
	if collector:IsA("BasePart") then table.insert(parts, collector) end
	for _, d in ipairs(collector:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end

	for _, part in ipairs(parts) do
		if locked then
			if not part:GetAttribute(COLLECTOR_ORIGINAL_COLOR_ATTRIBUTE) then
				local c = part.Color
				part:SetAttribute(COLLECTOR_ORIGINAL_COLOR_ATTRIBUTE, Color3.new(c.R, c.G, c.B))
			end
			part.Color = LOCKED_COLOR
		else
			local original = part:GetAttribute(COLLECTOR_ORIGINAL_COLOR_ATTRIBUTE)
			if original then
				part.Color = original
			end
		end
	end
end

local function isPlatformInSlotTierList(platformName)
	for i, tierData in ipairs(LAPIS_SLOT_TIERS) do
		for _, name in ipairs(tierData.Platforms) do
			if name == platformName then
				return i
			end
		end
	end
	return nil
end

local function getLapisValues()
	local ok, mods = pcall(function()
		return require(ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("LapisDataModule"))
	end)
	if not ok or not mods then return {} end

	local values = {}
	for _, lapis in ipairs(mods.Items) do
		values[lapis.Name] = lapis.PlotValue or lapis.Value -- plot PP/sec, not the sell price
	end
	return values
end

local function refreshMoneyTextImmediate(plot, lapisValues, multiplier)
	local platformsFolder = plot:FindFirstChild("Platform")
	if not platformsFolder then return end

	for _, platformModel in ipairs(platformsFolder:GetChildren()) do
		local platformLapis = platformModel:FindFirstChild("PlatformLapis")
		local collector = platformModel:FindFirstChild("Collector")
		if not platformLapis or not collector then continue end
		if platformLapis:GetAttribute("SlotLocked") then continue end

		local placedItem = platformLapis:GetAttribute("PlacedItem")
		local baseRate = (placedItem and lapisValues[placedItem]) or 0
		local currentRate = baseRate * multiplier

		local gui = collector:FindFirstChild("CollectorGui")
		if gui then
			local moneyText = gui:FindFirstChild("MoneyTextLabel")
			if moneyText then
				if multiplier > 1 then
					moneyText.Text = tostring(currentRate) .. " PP every second (x" .. tostring(multiplier) .. ")"
				else
					moneyText.Text = tostring(currentRate) .. " PP every second"
				end
			end
		end
	end
end

local function flashSlotPowerHighlight(plot, finalColor)
	local platformsFolder = plot:FindFirstChild("Platform")
	if not platformsFolder then return end

	for _, platformModel in ipairs(platformsFolder:GetChildren()) do
		local platformPart = platformModel:FindFirstChild("Platform")
		local platformLapis = platformModel:FindFirstChild("PlatformLapis")

		if platformLapis and platformLapis:GetAttribute("SlotLocked") then continue end

		for _, target in ipairs({platformPart, platformLapis}) do
			if target then
				local parts = {}
				if target:IsA("BasePart") then table.insert(parts, target) end
				for _, d in ipairs(target:GetDescendants()) do
					if d:IsA("BasePart") then table.insert(parts, d) end
				end

				for _, part in ipairs(parts) do
					part.Color = FLASH_COLOR
					TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Color = finalColor
					}):Play()
				end
			end
		end
	end
end

local function applyAllPlatformVisuals(plot, lapisSlotTier, slotPowerTier)
	local platformsFolder = plot:FindFirstChild("Platform")
	if not platformsFolder then return end

	local powerColor = DEFAULT_PLATFORM_COLOR
	local multiplier = 1
	if slotPowerTier > 0 then
		local tierData = SLOT_POWER_TIERS[slotPowerTier]
		powerColor = tierData.Color
		multiplier = tierData.Multiplier
	end

	plot:SetAttribute("SlotPowerMultiplier", multiplier)

	for _, platformModel in ipairs(platformsFolder:GetChildren()) do
		local platformName = platformModel.Name
		local platformPart = platformModel:FindFirstChild("Platform")
		local platformLapis = platformModel:FindFirstChild("PlatformLapis")
		local collector = platformModel:FindFirstChild("Collector")
		local prompt = collector and collector:FindFirstChild("ProximityPrompt")

		local requiredTierIndex = isPlatformInSlotTierList(platformName)
		local locked = requiredTierIndex ~= nil and requiredTierIndex > lapisSlotTier

		if platformLapis then
			platformLapis:SetAttribute("SlotLocked", locked)
		end

		local displayColor = locked and LOCKED_COLOR or powerColor
		if platformPart then colorAllParts(platformPart, displayColor) end
		if platformLapis then colorAllParts(platformLapis, displayColor) end
		setCollectorLocked(collector, locked)

		if collector then
			local gui = collector:FindFirstChild("CollectorGui")
			if gui then
				local collectorText = gui:FindFirstChild("CollectorTextLabel")
				local moneyText = gui:FindFirstChild("MoneyTextLabel")
				if locked then
					if collectorText then collectorText.Text = "🔒 LOCKED" end
					if moneyText then moneyText.Text = "🔒 LOCKED" end
				end
			end
		end

		if prompt then
			if locked then
				if not prompt:GetAttribute("UnlockedActionText") then
					prompt:SetAttribute("UnlockedActionText", prompt.ActionText)
				end
				prompt.ActionText = "LOCKED"
			else
				local hasLapis = prompt:GetAttribute("HasLapis")
				prompt.ActionText = hasLapis and "Retrieve" or (prompt:GetAttribute("UnlockedActionText") or "Select")
			end
		end
	end
end

function BaseUpgradeService.ApplyTeleportVisual(plot, unlocked)
	local upgrades = plot:FindFirstChild("Upgrades")
	local purchases = upgrades and upgrades:FindFirstChild("Purchases")
	local teleportModel = purchases and purchases:FindFirstChild("teleport")
	if not teleportModel then
		warn("[BaseUpgradeService] Could not find Purchases > teleport model")
		return
	end

	local parts = {}
	local decals = {}

	if teleportModel:IsA("BasePart") then table.insert(parts, teleportModel) end
	for _, d in ipairs(teleportModel:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("Decal") or d:IsA("Texture") then
			table.insert(decals, d)
		end
	end

	for _, part in ipairs(parts) do
		if unlocked then
			local original = part:GetAttribute(TELEPORT_ORIGINAL_TRANSPARENCY_ATTRIBUTE)
			part.Transparency = original or 0
			part.CanCollide = true
		else
			if not part:GetAttribute(TELEPORT_ORIGINAL_TRANSPARENCY_ATTRIBUTE) then
				part:SetAttribute(TELEPORT_ORIGINAL_TRANSPARENCY_ATTRIBUTE, part.Transparency)
			end
			part.Transparency = 1
			part.CanCollide = false
		end
	end

	for _, decal in ipairs(decals) do
		if unlocked then
			local original = decal:GetAttribute(TELEPORT_ORIGINAL_TRANSPARENCY_ATTRIBUTE)
			decal.Transparency = original or 0
		else
			if not decal:GetAttribute(TELEPORT_ORIGINAL_TRANSPARENCY_ATTRIBUTE) then
				decal:SetAttribute(TELEPORT_ORIGINAL_TRANSPARENCY_ATTRIBUTE, decal.Transparency)
			end
			decal.Transparency = 1
		end
	end

	local prompt = teleportModel:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = unlocked
	end
end

local BOSSFIGHT_ORIGINAL_TRANSPARENCY_ATTRIBUTE = "OriginalBossfightTransparency"

function BaseUpgradeService.ApplyBossfightPortalVisual(plot, unlocked)
	local upgrades = plot:FindFirstChild("Upgrades")
	local purchases = upgrades and upgrades:FindFirstChild("Purchases")
	local bossPortalModel = purchases and purchases:FindFirstChild("bossfight")

	if not bossPortalModel then
		warn("[BaseUpgradeService] Could not find Purchases > bossfight model")
		return
	end

	local parts = {}
	local decals = {}

	-- Sort through everything in the model
	if bossPortalModel:IsA("BasePart") then table.insert(parts, bossPortalModel) end
	for _, d in ipairs(bossPortalModel:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("Decal") or d:IsA("Texture") then
			table.insert(decals, d)
		end
	end

	-- Handle 3D Parts
	for _, part in ipairs(parts) do
		if unlocked then
			local original = part:GetAttribute(BOSSFIGHT_ORIGINAL_TRANSPARENCY_ATTRIBUTE)
			part.Transparency = original or 0
			-- Note: If your 'teleport' part is a trigger, you might want to keep CanCollide = false
			if part.Name ~= "teleport" then 
				part.CanCollide = true
			end
		else
			if not part:GetAttribute(BOSSFIGHT_ORIGINAL_TRANSPARENCY_ATTRIBUTE) then
				part:SetAttribute(BOSSFIGHT_ORIGINAL_TRANSPARENCY_ATTRIBUTE, part.Transparency)
			end
			part.Transparency = 1
			part.CanCollide = false
		end
	end

	-- Handle 2D Decals/Textures
	for _, decal in ipairs(decals) do
		if unlocked then
			local original = decal:GetAttribute(BOSSFIGHT_ORIGINAL_TRANSPARENCY_ATTRIBUTE)
			decal.Transparency = original or 0
		else
			if not decal:GetAttribute(BOSSFIGHT_ORIGINAL_TRANSPARENCY_ATTRIBUTE) then
				decal:SetAttribute(BOSSFIGHT_ORIGINAL_TRANSPARENCY_ATTRIBUTE, decal.Transparency)
			end
			decal.Transparency = 1
		end
	end

	-- Handle the ProximityPrompt
	local prompt = bossPortalModel:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = unlocked
	end
end

function BaseUpgradeService.ApplyOwnedUpgrades(plot, userId)
	applyAllPlatformVisuals(
		plot,
		BaseUpgradeService.GetLapisSlotTier(userId),
		BaseUpgradeService.GetSlotPowerTier(userId)
	)
	BaseUpgradeService.ApplyBossfightPortalVisual(plot, BaseUpgradeService.GetBossfightUnlocked(userId))
end

--==================================================
-- ADMIN RESET
--==================================================

function BaseUpgradeService.ResetUpgrades(player)
	local userId = player.UserId
	if not BaseUpgradeService.IsLoaded(userId) then return false end

	sessionData[userId] = {LapisSlotTier = 0, SlotPowerTier = 0, TeleportUnlocked = true, BossfightUnlocked = false}
	dirty[userId] = true
	player:SetAttribute("TeleportUnlocked", true)
	player:SetAttribute("BossfightUnlocked", false)

	local plot = BaseUpgradeService.FindPlotForPlayer(player)
	if plot then
		BaseUpgradeService.ApplyOwnedUpgrades(plot, userId)
	end

	BaseUpgradeService.FlushSave(userId)
	BaseUpgradeService.SendStateToClient(player)

	return true
end

--==================================================
-- FINDING A PLAYER'S PLOT
--==================================================

local islandsFolder = workspace:WaitForChild("Islands")
local starterIsland = islandsFolder:WaitForChild("StarterIsland")
local plotsFolder = starterIsland:WaitForChild("IslandPlots")

local function findPlotForPlayer(player)
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		local ownerValue = plot:FindFirstChild("Owner")
		if ownerValue and ownerValue.Value == player.Name then
			return plot
		end
	end
	return nil
end

BaseUpgradeService.FindPlotForPlayer = findPlotForPlayer

--==================================================
-- REMOTE / PURCHASE HANDLING
--==================================================

local accessibleEvents = ReplicatedStorage:FindFirstChild("AccessibleEvents")
if not accessibleEvents then
	accessibleEvents = Instance.new("Folder")
	accessibleEvents.Name = "AccessibleEvents"
	accessibleEvents.Parent = ReplicatedStorage
end

local baseUpgradeRemote = accessibleEvents:FindFirstChild("BaseUpgradeRemote")
if not baseUpgradeRemote then
	baseUpgradeRemote = Instance.new("RemoteEvent")
	baseUpgradeRemote.Name = "BaseUpgradeRemote"
	baseUpgradeRemote.Parent = accessibleEvents
end

local function getLeaderstatsPP(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("PeacePoints")
end

local function getAscensions(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local asc = leaderstats and (leaderstats:FindFirstChild("Ascensions") or leaderstats:FindFirstChild("Rebirths"))
	return asc and asc.Value or 0
end

local function tryPurchaseLinearTier(player, tiers, getCurrentTier, setCurrentTier)
	local currentTier = getCurrentTier(player.UserId)
	local nextIndex = currentTier + 1
	local tierData = tiers[nextIndex]

	if not tierData then
		return false, "ALREADY MAXED OUT!"
	end

	local ascensions = getAscensions(player)
	if ascensions < tierData.AscensionsRequired then
		return false, "NEED " .. tierData.AscensionsRequired .. " ASCENSIONS!"
	end

	local ppStat = getLeaderstatsPP(player)
	if not ppStat or ppStat.Value < tierData.Cost then
		return false, "NOT ENOUGH PEACEPOINTS!"
	end

	ppStat.Value -= tierData.Cost
	setCurrentTier(player.UserId, nextIndex)

	return true, nextIndex
end

local function buildConfigPayload()
	local lapisSlotPayload = {}
	for i, t in ipairs(LAPIS_SLOT_TIERS) do
		lapisSlotPayload[i] = {AscensionsRequired = t.AscensionsRequired, Cost = t.Cost, Value = tostring(t.SlotCount)}
	end
	
	local slotPowerPayload = {}
	for i, t in ipairs(SLOT_POWER_TIERS) do
		slotPowerPayload[i] = {AscensionsRequired = t.AscensionsRequired, Cost = t.Cost, Value = t.Multiplier .. "x"}
	end

	return {
		LapisSlotTiers = lapisSlotPayload,
		SlotPowerTiers = slotPowerPayload,
		TeleportTier = {AscensionsRequired = TELEPORT_TIER.AscensionsRequired, Cost = TELEPORT_TIER.Cost},
		BossfightTier = {AscensionsRequired = BOSSFIGHT_TIER.AscensionsRequired, Cost = BOSSFIGHT_TIER.Cost},
	}
end

function BaseUpgradeService.SendStateToClient(player)
	baseUpgradeRemote:FireClient(player, "State", {
		Config = buildConfigPayload(),
		LapisSlotTier = BaseUpgradeService.GetLapisSlotTier(player.UserId),
		SlotPowerTier = BaseUpgradeService.GetSlotPowerTier(player.UserId),
		TeleportUnlocked = BaseUpgradeService.GetTeleportUnlocked(player.UserId),
		BossfightUnlocked = BaseUpgradeService.GetBossfightUnlocked(player.UserId),
		QuestsDone = (function()
			local ok, qp = pcall(require, script.Parent:FindFirstChild("QuestProgress"))
			if not ok or not qp then return nil end
			local _, done = (qp.FinalDone or qp.AllDone)(player)
			return done
		end)(),
		QuestsTotal = 9,
	})
end

baseUpgradeRemote.OnServerEvent:Connect(function(player, action)
	if not BaseUpgradeService.IsLoaded(player.UserId) then
		baseUpgradeRemote:FireClient(player, "Error", "STILL LOADING -- TRY AGAIN IN A MOMENT!")
		return
	end

	if action == "GetState" then
		BaseUpgradeService.SendStateToClient(player)
		return
	end

	local plot = findPlotForPlayer(player)
	if not plot then
		baseUpgradeRemote:FireClient(player, "Error", "NO PLOT FOUND!")
		return
	end

	if action == "UpgradeLapisSlots" then
		local ok, result = tryPurchaseLinearTier(
			player, LAPIS_SLOT_TIERS,
			BaseUpgradeService.GetLapisSlotTier,
			BaseUpgradeService.SetLapisSlotTier
		)

		if ok then
			BaseUpgradeService.ApplyOwnedUpgrades(plot, player.UserId)
			BaseUpgradeService.FlushSave(player.UserId)
			baseUpgradeRemote:FireClient(player, "UpgradeSuccess", "LapisSlots", result)
		else
			baseUpgradeRemote:FireClient(player, "Error", result)
		end

	elseif action == "UpgradeSlotPower" then
		local ok, result = tryPurchaseLinearTier(
			player, SLOT_POWER_TIERS,
			BaseUpgradeService.GetSlotPowerTier,
			BaseUpgradeService.SetSlotPowerTier
		)

		if ok then
			BaseUpgradeService.ApplyOwnedUpgrades(plot, player.UserId)

			local tierData = SLOT_POWER_TIERS[result]
			flashSlotPowerHighlight(plot, tierData.Color)
			refreshMoneyTextImmediate(plot, getLapisValues(), tierData.Multiplier)

			BaseUpgradeService.FlushSave(player.UserId)
			baseUpgradeRemote:FireClient(player, "UpgradeSuccess", "SlotPower", result)
		else
			baseUpgradeRemote:FireClient(player, "Error", result)
		end

	elseif action == "UpgradeTeleport" then
		if BaseUpgradeService.GetTeleportUnlocked(player.UserId) then
			baseUpgradeRemote:FireClient(player, "Error", "ALREADY UNLOCKED!")
			return
		end

		local ascensions = getAscensions(player)
		if ascensions < TELEPORT_TIER.AscensionsRequired then
			baseUpgradeRemote:FireClient(player, "Error", "NEED " .. TELEPORT_TIER.AscensionsRequired .. " ASCENSIONS!")
			return
		end

		local ppStat = getLeaderstatsPP(player)
		if not ppStat or ppStat.Value < TELEPORT_TIER.Cost then
			baseUpgradeRemote:FireClient(player, "Error", "NOT ENOUGH PEACEPOINTS!")
			return
		end

		ppStat.Value -= TELEPORT_TIER.Cost
		BaseUpgradeService.SetTeleportUnlocked(player.UserId, true)
		player:SetAttribute("TeleportUnlocked", true)
		BaseUpgradeService.FlushSave(player.UserId)
		baseUpgradeRemote:FireClient(player, "UpgradeSuccess", "Teleport", true)

	elseif action == "UpgradeBossfight" then
		if BaseUpgradeService.GetBossfightUnlocked(player.UserId) then
			baseUpgradeRemote:FireClient(player, "Error", "ALREADY UNLOCKED!")
			return
		end

		local ascensions = getAscensions(player)
		if ascensions < BOSSFIGHT_TIER.AscensionsRequired then
			baseUpgradeRemote:FireClient(player, "Error", "NEED " .. BOSSFIGHT_TIER.AscensionsRequired .. " ASCENSIONS!")
			return
		end

		-- The final upgrade needs EVERY quest completed, and then going back
		-- into the dungeon (the true ending).
		local QuestProgress = require(script.Parent:WaitForChild("QuestProgress"))
		local questsDone, doneCount, total = QuestProgress.AllDone(player)
		if not questsDone then
			baseUpgradeRemote:FireClient(player, "Error", "COMPLETE EVERY QUEST FIRST! (" .. doneCount .. "/" .. total .. ")")
			return
		end
		local finalDone = QuestProgress.FinalDone(player)
		if not finalDone then
			baseUpgradeRemote:FireClient(player, "Error", "GO BACK INTO THE DUNGEON FIRST!")
			return
		end

		local ppStat = getLeaderstatsPP(player)
		if not ppStat or ppStat.Value < BOSSFIGHT_TIER.Cost then
			baseUpgradeRemote:FireClient(player, "Error", "NOT ENOUGH PEACEPOINTS!")
			return
		end

		ppStat.Value -= BOSSFIGHT_TIER.Cost
		BaseUpgradeService.SetBossfightUnlocked(player.UserId, true)
		BaseUpgradeService.ApplyBossfightPortalVisual(plot, true)
		BaseUpgradeService.FlushSave(player.UserId)
		baseUpgradeRemote:FireClient(player, "UpgradeSuccess", "Bossfight", true)
		-- the big reveal on their base (everyone nearby sees it; the buyer gets the camera)
		local reveal = game:GetService("ReplicatedStorage"):FindFirstChild("BossPortalReveal")
		local up = plot:FindFirstChild("Upgrades")
		local pur = up and up:FindFirstChild("Purchases")
		local portal = pur and pur:FindFirstChild("bossfight")
		if reveal and portal then reveal:FireAllClients(portal, player.UserId) end
	end
end)

return BaseUpgradeService