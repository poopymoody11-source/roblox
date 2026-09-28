local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local function findInventoryModule()
	local nested = ServerScriptService:FindFirstChild("InventoryService", true)
	if nested then return nested end
	return ServerStorage:FindFirstChild("InventoryService", true)
end

local invModule = findInventoryModule()
local InventoryService = invModule and require(invModule) or nil

local GameScripts = ServerScriptService:WaitForChild("GameScripts")
local Core = require(GameScripts:WaitForChild("LapisPlacementCore"))
local PlotSaveService = require(GameScripts:WaitForChild("PlotSaveService"))

local lapisRemote = ReplicatedStorage:FindFirstChild("LapisRemote")
if not lapisRemote then
	lapisRemote = Instance.new("RemoteEvent")
	lapisRemote.Name = "LapisRemote"
	lapisRemote.Parent = ReplicatedStorage
end

local RETRIEVE_ACTION_TEXT = "Retrieve"

local function getPlatformName(platform)
	return platform.Parent.Name
end

lapisRemote.OnServerEvent:Connect(function(player, action, arg1, arg2)
	if not InventoryService then return end

	if action == "Place" then
		local itemName = arg1
		local platform = arg2

		if type(itemName) ~= "string" then return end
		if not platform or not platform:IsA("BasePart") then return end

		local plot = platform.Parent.Parent.Parent
		local ownerValue = plot:FindFirstChild("Owner")

		if ownerValue and ownerValue.Value ~= player.Name then
			lapisRemote:FireClient(player, action, "YOU DON'T OWN THIS PLOT!", true)
			return
		end

		local prompt = Core.GetPromptForPlatform(platform)

		if prompt and prompt:GetAttribute("HasLapis") then
			lapisRemote:FireClient(player, action, "SLOT ALREADY OCCUPIED -- RETRIEVE FIRST!", true)
			return
		end

		if platform:GetAttribute("SlotLocked") then
			lapisRemote:FireClient(player, action, "THIS SLOT IS LOCKED!", true)
			return
		end

		local owned = InventoryService.GetCount(player, itemName)
		if owned < 1 then
			lapisRemote:FireClient(player, action, "YOU DO NOT HAVE THIS LAPIS!", true)
			return
		end

		local removed = InventoryService.Remove(player, itemName, 1)
		if not removed then
			lapisRemote:FireClient(player, action, "FAILED TO REMOVE LAPIS!", true)
			return
		end

		Core.SpawnLapisModel(platform, itemName)
		platform:SetAttribute("PlacedItem", itemName)

		PlotSaveService.SetPlacedItem(player.UserId, getPlatformName(platform), itemName)

		if prompt then
			if not prompt:GetAttribute("OriginalActionText") then
				prompt:SetAttribute("OriginalActionText", prompt.ActionText)
			end
			prompt.ActionText = RETRIEVE_ACTION_TEXT
			prompt:SetAttribute("HasLapis", true)
		end

		lapisRemote:FireClient(player, action, "LAPIS PLACED!", false)

	elseif action == "Retrieve" then
		local platform = arg1

		if not platform or not platform:IsA("BasePart") then return end

		local plot = platform.Parent.Parent.Parent
		local ownerValue = plot:FindFirstChild("Owner")

		if ownerValue and ownerValue.Value ~= player.Name then
			lapisRemote:FireClient(player, action, "YOU DON'T OWN THIS PLOT!", true)
			return
		end

		local prompt = Core.GetPromptForPlatform(platform)
		if not prompt or not prompt:GetAttribute("HasLapis") then
			lapisRemote:FireClient(player, "Retrieve", "NOTHING TO RETRIEVE!", true)
			return
		end

		local itemName = platform:GetAttribute("PlacedItem")
		if not itemName then
			lapisRemote:FireClient(player, "Retrieve", "NOTHING TO RETRIEVE!", true)
			return
		end

		Core.ClearPlatformChildren(platform)
		platform:SetAttribute("PlacedItem", nil)

		PlotSaveService.ClearPlacedItem(player.UserId, getPlatformName(platform))

		prompt.ActionText = prompt:GetAttribute("OriginalActionText") or "Select"
		prompt:SetAttribute("HasLapis", false)

		InventoryService.Add(player, itemName, 1)

		lapisRemote:FireClient(player, "Retrieve", "LAPIS RETRIEVED!", false)
	end
end)