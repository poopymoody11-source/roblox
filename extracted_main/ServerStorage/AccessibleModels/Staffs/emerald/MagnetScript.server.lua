--==================================================
-- MAGNET TOOL (SERVER SCRIPT)
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local tool = script.Parent

local CONFIG = {
	MAGNET_RADIUS = 38,
	FLIGHT_DURATION = 1,
	CLAIM_INTERVAL = 0.1,
	LAPIS_FOLDER_NAME = "SpawnedLapis",
	SPAWN_BOX_FOLDER_NAME = "LapisSpawnBox",
	HEIGHT_PADDING = 60,
}

if not RunService:IsServer() then
	error("[Magnet] This must be a SERVER Script inside the Tool, not a LocalScript.")
end

local active = false
local heartbeatConnection = nil
local accumulator = 0
local claimed = {}
local ownerUserId = nil

local function getLapisFolder()
	return workspace:FindFirstChild(CONFIG.LAPIS_FOLDER_NAME)
end

local function isPlayerInSpawnBox(playerPosition)
	local spawnBoxFolder = workspace:FindFirstChild(CONFIG.SPAWN_BOX_FOLDER_NAME)
	if not spawnBoxFolder then return false end

	for _, desc in ipairs(spawnBoxFolder:GetDescendants()) do
		if desc:IsA("BasePart") then
			local localPos = desc.CFrame:PointToObjectSpace(playerPosition)
			local halfSize = desc.Size / 2

			if math.abs(localPos.X) <= halfSize.X
				and math.abs(localPos.Z) <= halfSize.Z
				and (localPos.Y >= -halfSize.Y - 2 and localPos.Y <= halfSize.Y + CONFIG.HEIGHT_PADDING) then
				return true
			end
		end
	end
	return false
end

local function release(lapis)
	claimed[lapis] = nil
	if not lapis.Parent then return end

	lapis:SetAttribute("MagnetTarget", nil)
	lapis:SetAttribute("MagnetStart", nil)
	lapis:SetAttribute("MagnetDuration", nil)
	lapis:SetAttribute("Magnetized", false)
	lapis:SetAttribute("CollectRequestedBy", nil)
end

local function releaseOwned()
	local lapisFolder = getLapisFolder()
	if not lapisFolder then
		for lapis in pairs(claimed) do release(lapis) end
		return
	end

	for _, lapis in ipairs(lapisFolder:GetChildren()) do
		if lapis:IsA("Model")
			and not lapis:GetAttribute("Collecting")
			and lapis:GetAttribute("MagnetTarget") == ownerUserId then
			release(lapis)
		end
	end

	for lapis in pairs(claimed) do release(lapis) end
	claimed = {}
end

local function scan()
	local character = tool.Parent
	if not character then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local playerPosition = humanoidRootPart.Position

	-- Jumping (or flying) lifts the root part clear of the
	-- spawn box volume. Leaving the box now only stops NEW
	-- claims -- anything already in flight finishes its trip,
	-- so a jump no longer dumps mid-air lapis back home.
	local inSpawnBox = isPlayerInSpawnBox(playerPosition)

	local lapisFolder = getLapisFolder()
	if not lapisFolder then return end

	local now = workspace:GetServerTimeNow()

	-- RESOLVE ALREADY-CLAIMED LAPIS
	for lapis in pairs(claimed) do
		if not lapis.Parent or lapis:GetAttribute("Collecting") then
			claimed[lapis] = nil
		elseif lapis:GetAttribute("MagnetTarget") ~= player.UserId then
			claimed[lapis] = nil
		else
			local startTime = lapis:GetAttribute("MagnetStart")
			if not startTime then
				release(lapis)
			elseif now - startTime >= CONFIG.FLIGHT_DURATION then
				claimed[lapis] = nil
				lapis:SetAttribute("CollectRequestedBy", nil)
				lapis:SetAttribute("CollectRequestedBy", player.UserId)
			end
		end
	end

	-- CLAIM NEW LAPIS
	if not inSpawnBox then return end

	for _, lapis in ipairs(lapisFolder:GetChildren()) do
		if not lapis:IsA("Model") or not lapis:GetAttribute("IsSpawnedLapis") then continue end
		if lapis:GetAttribute("Collecting") or lapis:GetAttribute("MagnetTarget") then continue end

		local distance = (lapis:GetPivot().Position - playerPosition).Magnitude
		if distance <= CONFIG.MAGNET_RADIUS then
			claimed[lapis] = true

			if not lapis:GetAttribute("OriginalPosition") then
				lapis:SetAttribute("OriginalPosition", lapis:GetPivot().Position)
			end

			lapis:SetAttribute("CollectRequestedBy", nil)
			lapis:SetAttribute("Magnetized", true)
			lapis:SetAttribute("MagnetDuration", CONFIG.FLIGHT_DURATION)
			lapis:SetAttribute("MagnetStart", now)
			lapis:SetAttribute("MagnetTarget", player.UserId)
		end
	end
end

local function startMagnet()
	local character = tool.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if player then ownerUserId = player.UserId end

	if active then return end
	active = true
	accumulator = 0

	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulator += deltaTime
		if accumulator < CONFIG.CLAIM_INTERVAL then return end
		accumulator = 0
		scan()
	end)
end

local function stopMagnet()
	if not active and next(claimed) == nil then return end
	active = false

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	releaseOwned()
end

tool.Equipped:Connect(startMagnet)
tool.Unequipped:Connect(stopMagnet)
tool.AncestryChanged:Connect(function()
	if not tool:IsDescendantOf(workspace) then stopMagnet() end
end)