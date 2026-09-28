local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local LapisPlacementCore = {}

local accessibleModels = ServerStorage:FindFirstChild("AccessibleModels")
LapisPlacementCore.LapisModelsFolder = accessibleModels and accessibleModels:FindFirstChild("BaseLapis")

LapisPlacementCore.ModelNameMap = {
	["golden_lapis"] = "gold",
	["malevolent_lapis"] = "sukuna",
}

LapisPlacementCore.RotationCorrections = {
	interstellar_lapis = CFrame.new(),
	totem_lapis = CFrame.new(),
}

LapisPlacementCore.HeightOverrides = {
	["67_lapis"] = 15,
}

function LapisPlacementCore.GetRotationCorrection(itemName)
	return LapisPlacementCore.RotationCorrections[itemName] or CFrame.new()
end

function LapisPlacementCore.GetPromptForPlatform(platform)
	local platformRoot = platform and platform.Parent
	local collector = platformRoot and platformRoot:FindFirstChild("Collector")
	local prompt = collector and collector:FindFirstChild("ProximityPrompt")
	return prompt
end

function LapisPlacementCore.ClearPlatformChildren(platform)
	for _, child in ipairs(platform:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			child:Destroy()
		end
	end
end

function LapisPlacementCore.SpawnLapisModel(platform, itemName)
	local lapisModelsFolder = LapisPlacementCore.LapisModelsFolder
	if not lapisModelsFolder then return nil end

	local targetName = LapisPlacementCore.ModelNameMap[itemName] or itemName:gsub("_lapis$", "")
	local modelTemplate = lapisModelsFolder:FindFirstChild(targetName)

	if not modelTemplate then
		warn("[LapisPlacementCore] BaseLapis model template not found for: " .. tostring(targetName))
		return nil
	end

	LapisPlacementCore.ClearPlatformChildren(platform)

	local lapisClone = modelTemplate:Clone()

	local modelHeight = 0
	if lapisClone:IsA("Model") then
		local _, size = lapisClone:GetBoundingBox()
		modelHeight = size.Y
	elseif lapisClone:IsA("BasePart") then
		modelHeight = lapisClone.Size.Y
	end

	if LapisPlacementCore.HeightOverrides[itemName] then
		modelHeight = LapisPlacementCore.HeightOverrides[itemName]
	end

	local templatePivot = modelTemplate:GetPivot()
	local templateRotation = templatePivot - templatePivot.Position
	local correction = LapisPlacementCore.GetRotationCorrection(itemName)

	local heightOffset = 1.5

	local restPosition = platform.Position + Vector3.new(0, (platform.Size.Y / 2) + (modelHeight / 2) + heightOffset, 0)
	local restCFrame = CFrame.new(restPosition) * templateRotation * correction

	lapisClone:PivotTo(restCFrame)
	lapisClone.Parent = platform

	CollectionService:AddTag(lapisClone, "PlacedLapis")

	return lapisClone
end

return LapisPlacementCore