local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local GameScripts = ServerScriptService:WaitForChild("GameScripts")
local Core = require(GameScripts:WaitForChild("LapisPlacementCore"))
local PlotSaveService = require(GameScripts:WaitForChild("PlotSaveService"))
local BaseUpgradeService = require(GameScripts:WaitForChild("BaseUpgradeService"))

local islandsFolder = workspace:WaitForChild("Islands")
local starterIsland = islandsFolder:WaitForChild("StarterIsland")
local plotsFolder = starterIsland:WaitForChild("IslandPlots")

local loadedOwner = {}

local function restorePlot(plot, player)
	PlotSaveService.Init(player)
	BaseUpgradeService.Init(player)
	loadedOwner[plot] = player.UserId

	BaseUpgradeService.ApplyOwnedUpgrades(plot, player.UserId)

	local platformsFolder = plot:FindFirstChild("Platform")
	if not platformsFolder then return end

	for _, platformModel in ipairs(platformsFolder:GetChildren()) do
		local platformLapis = platformModel:FindFirstChild("PlatformLapis")
		local collector = platformModel:FindFirstChild("Collector")
		if not platformLapis then continue end

		local platformName = platformModel.Name
		local savedItem = PlotSaveService.GetPlacedItem(player.UserId, platformName)

		if savedItem then
			local lapisClone = Core.SpawnLapisModel(platformLapis, savedItem)
			platformLapis:SetAttribute("PlacedItem", savedItem)

			local prompt = collector and collector:FindFirstChild("ProximityPrompt")
			if prompt then
				if not prompt:GetAttribute("OriginalActionText") then
					prompt:SetAttribute("OriginalActionText", prompt.ActionText)
				end
				prompt.ActionText = "Retrieve"
				prompt:SetAttribute("HasLapis", true)
			end

			if not lapisClone then
				warn("[PlotDataRestore] Saved item '" .. tostring(savedItem) .. "' for " .. player.Name .. " on " .. platformName .. " has no model template.")
			end
		end

		local savedMoney = PlotSaveService.GetMoney(player.UserId, platformName)
		if collector and not platformLapis:GetAttribute("SlotLocked") then
			local gui = collector:FindFirstChild("CollectorGui")
			if gui and gui:FindFirstChild("CollectorTextLabel") then
				gui.CollectorTextLabel.Text = tostring(savedMoney) .. " PP"
			end
		end
	end
end

local function teardownPlot(plot)
	local userId = loadedOwner[plot]
	if not userId then return end

	local player = Players:GetPlayerByUserId(userId)
	if player then
		PlotSaveService.Teardown(player)
		BaseUpgradeService.Teardown(player)
	end

	loadedOwner[plot] = nil
end

local function watchPlot(plot)
	local ownerValue = plot:FindFirstChild("Owner")
	if not ownerValue then return end

	local function handleOwnerChanged()
		local ownerName = ownerValue.Value

		if ownerName == "" or ownerName == nil then
			teardownPlot(plot)
			return
		end

		local player = Players:FindFirstChild(ownerName)
		if not player then return end

		if loadedOwner[plot] == player.UserId then return end

		if loadedOwner[plot] then
			teardownPlot(plot)
		end

		restorePlot(plot, player)
	end

	ownerValue:GetPropertyChangedSignal("Value"):Connect(handleOwnerChanged)

	if ownerValue.Value ~= "" then
		handleOwnerChanged()
	end
end

for _, plot in ipairs(plotsFolder:GetChildren()) do
	watchPlot(plot)
end

plotsFolder.ChildAdded:Connect(watchPlot)

Players.PlayerRemoving:Connect(function(player)
	for plot, userId in pairs(loadedOwner) do
		if userId == player.UserId then
			teardownPlot(plot)
		end
	end
end)