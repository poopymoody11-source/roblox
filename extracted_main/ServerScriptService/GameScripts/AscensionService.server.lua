--==================================================
-- ASCENSION SERVER HANDLER
-- Place as a Script in ServerScriptService
--
-- Costs come from AccessibleModules.AscensionDataModule
-- so the rebirth UI, the teleport gate, adminScript and
-- this handler can never disagree about a number. The
-- old "BASE_COST * (level + 1)" curve was linear while
-- income grew geometrically, which made ascension 1 a
-- ~25 minute wall and every later one nearly instant.
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AscensionData = require(
	ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("AscensionDataModule")
)

-- Setup Remote and Bindable Events
local eventsFolder = ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage
local ascendEvent = eventsFolder:FindFirstChild("AscendRequest")
if not ascendEvent then
	ascendEvent = Instance.new("RemoteEvent")
	ascendEvent.Name = "AscendRequest"
	ascendEvent.Parent = eventsFolder
end

local resetShopEvent = eventsFolder:FindFirstChild("ResetPlayerShop")
if not resetShopEvent then
	resetShopEvent = Instance.new("BindableEvent")
	resetShopEvent.Name = "ResetPlayerShop"
	resetShopEvent.Parent = eventsFolder
end

ascendEvent.OnServerEvent:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local ppStat = leaderstats:FindFirstChild("PeacePoints")
		or leaderstats:FindFirstChild("peacepoints")
		or leaderstats:FindFirstChild("Money")
		or leaderstats:FindFirstChild("PP")

	local ascensionStat = leaderstats:FindFirstChild("Ascensions")
		or leaderstats:FindFirstChild("Rebirths")
		or leaderstats:FindFirstChild("Ascension")

	if not ppStat or not ascensionStat then return end

	local currentPP = ppStat.Value
	local currentLevel = ascensionStat.Value
	-- GetCostFor, not GetCost: the 2x Ascensions pass halves
	-- this, and the rebirth UI shows the halved number.
	local requiredPP = AscensionData.GetCostFor(player, currentLevel)

	if currentPP >= requiredPP then
		ppStat.Value = 0
		ascensionStat.Value = currentLevel + 1

		-- Trigger the Shop Server Script to wipe inventory & data
		resetShopEvent:Fire(player)
	end
end)
