local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AccessibleModules = ReplicatedStorage:WaitForChild("AccessibleModules")
local LapisDataModule = require(AccessibleModules:WaitForChild("LapisDataModule"))
local AscensionData = require(AccessibleModules:WaitForChild("AscensionDataModule"))
local Monetization = require(AccessibleModules:WaitForChild("MonetizationData"))
local lapisRemote = ReplicatedStorage:WaitForChild("LapisRemote")

local GameScripts = ServerScriptService:WaitForChild("GameScripts")
local PlotSaveService = require(GameScripts:WaitForChild("PlotSaveService"))

local lapisValues = {}
for _, lapis in ipairs(LapisDataModule.Items) do
	lapisValues[lapis.Name] = lapis.PlotValue or lapis.Value
end

local islandsFolder = workspace:WaitForChild("Islands")
local starterIsland = islandsFolder:WaitForChild("StarterIsland")
local plotsFolder = starterIsland:WaitForChild("IslandPlots")

local debounce = {}

local function getOwnerPlayer(plot)
	local ownerValue = plot:FindFirstChild("Owner")
	if not ownerValue or ownerValue.Value == "" then return nil end
	return Players:FindFirstChild(ownerValue.Value)
end

local function setupCollector(collector, plot, platformModel)
	local platformName = platformModel.Name

	collector.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)

		if player then
			if debounce[player] and tick() - debounce[player] < 0.5 then return end
			debounce[player] = tick()

			local ownerValue = plot:FindFirstChild("Owner")

			if ownerValue and ownerValue.Value == player.Name then
				if not PlotSaveService.IsLoaded(player.UserId) then return end

				local platformLapis = platformModel:FindFirstChild("PlatformLapis")
				if platformLapis and platformLapis:GetAttribute("SlotLocked") then return end

				local amount = PlotSaveService.GetMoney(player.UserId, platformName)
				if amount > 0 then
					PlotSaveService.ResetMoney(player.UserId, platformName)

					local gui = collector:FindFirstChild("CollectorGui")
					if gui and gui:FindFirstChild("CollectorTextLabel") then
						gui.CollectorTextLabel.Text = "0 PP"
					end

					local leaderstats = player:FindFirstChild("leaderstats")
					if leaderstats then
						local ppStat = leaderstats:FindFirstChild("Peace Points") or leaderstats:FindFirstChild("PeacePoints") or leaderstats:FindFirstChild("PP")
						if ppStat then
							ppStat.Value += amount
						end
					end

					lapisRemote:FireClient(player, "Claim", "+" .. tostring(amount) .. " PP COLLECTED!", false)
				end
			end
		end
	end)
end

for _, plot in ipairs(plotsFolder:GetChildren()) do
	local platformsFolder = plot:FindFirstChild("Platform")
	if platformsFolder then
		for _, platformModel in ipairs(platformsFolder:GetChildren()) do
			local collector = platformModel:FindFirstChild("Collector")
			if collector then
				setupCollector(collector, plot, platformModel)
			end
		end
	end
end

task.spawn(function()
	while task.wait(1) do
		for _, plot in ipairs(plotsFolder:GetChildren()) do
			local platformsFolder = plot:FindFirstChild("Platform")
			if not platformsFolder then continue end

			local ownerPlayer = getOwnerPlayer(plot)
			if not ownerPlayer or not PlotSaveService.IsLoaded(ownerPlayer.UserId) then continue end

			for _, platformModel in ipairs(platformsFolder:GetChildren()) do
				local platformLapis = platformModel:FindFirstChild("PlatformLapis")
				local collector = platformModel:FindFirstChild("Collector")

				if platformLapis and collector then
					if platformLapis:GetAttribute("SlotLocked") then continue end

					local platformName = platformModel.Name
					local currentRate = 0
					local placedItem = platformLapis:GetAttribute("PlacedItem")
					local multiplier = plot:GetAttribute("SlotPowerMultiplier") or 1

					-- Ascensions now scale passive plot income as well as
					-- selling. Previously only the slot-power tier mattered,
					-- so income was completely flat between tiers while
					-- ascension costs kept climbing.
					local ascStat = ownerPlayer:FindFirstChild("leaderstats")
					ascStat = ascStat and (ascStat:FindFirstChild("Ascensions") or ascStat:FindFirstChild("Rebirths"))
					local ascMultiplier = AscensionData.GetMultiplier(ascStat and ascStat.Value or 0)

					-- Passive plot income respects 2x Money too. Without
					-- this the pass would only pay out on manual selling,
					-- which is most of the point of owning a plot.
					local passMultiplier = Monetization.GetMoneyMultiplier(ownerPlayer)
					ascMultiplier = ascMultiplier * passMultiplier

					if placedItem and lapisValues[placedItem] then
						currentRate = math.floor(lapisValues[placedItem] * multiplier * ascMultiplier)
					end

					local currentMoney
					if currentRate > 0 then
						currentMoney = PlotSaveService.AddMoney(ownerPlayer.UserId, platformName, currentRate)
					else
						currentMoney = PlotSaveService.GetMoney(ownerPlayer.UserId, platformName)
					end

					local gui = collector:FindFirstChild("CollectorGui")
					if gui then
						local collectorText = gui:FindFirstChild("CollectorTextLabel")
						local moneyText = gui:FindFirstChild("MoneyTextLabel")

						if collectorText then
							collectorText.Text = tostring(currentMoney) .. " PP"
						end
						if moneyText then
							local totalMultiplier = multiplier * ascMultiplier
							if totalMultiplier > 1 then
								moneyText.Text = tostring(currentRate) .. " PP every second (x" .. string.format("%.1f", totalMultiplier) .. ")"
							else
								moneyText.Text = tostring(currentRate) .. " PP every second"
							end
						end
					end
				end
			end
		end
	end
end)