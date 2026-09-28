--==================================================
-- ISLAND GUARD  (server)
--
-- Islands are only reachable by teleport, and TeleportService gates that.
-- The Elytra (and anything else that moves you) could simply fly in. This
-- is the server half of the lock: anyone found inside the dome of an island
-- they haven't unlocked is put back outside it. The client half
-- (IslandBarrier) makes the dome solid for them so it rarely comes to this.
--
-- Same rule as TeleportService: enough ascensions, or a pass that opens the
-- island (Unlock All Islands, or the Verity / La Peace bundles).
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modules = ReplicatedStorage:WaitForChild("AccessibleModules")
local AscensionData = require(modules:WaitForChild("AscensionDataModule"))
local Monetization = require(modules:WaitForChild("MonetizationData"))

local ISLANDS = {
	["67Island"] = "67 Island",
	["VerityIsland"] = "Verity Island",
	["LaPeaceIsland"] = "LaPeace Island",
}

local events = ReplicatedStorage:WaitForChild("AccessibleEvents")
local notice = events:FindFirstChild("IslandLocked") or Instance.new("RemoteEvent")
notice.Name = "IslandLocked"
notice.Parent = events

local function ascensions(player)
	local ls = player:FindFirstChild("leaderstats")
	local stat = ls and (ls:FindFirstChild("Ascensions") or ls:FindFirstChild("Rebirths") or ls:FindFirstChild("Ascension"))
	return stat and stat.Value or 0
end

local function allowed(player, islandName)
	local need = AscensionData.Islands[islandName] or 0
	return ascensions(player) >= need or Monetization.HasIslandAccess(player, islandName)
end

local domes = {}
local islands = workspace:WaitForChild("Islands")
for folderName, islandName in pairs(ISLANDS) do
	local isl = islands:WaitForChild(folderName, 20)
	local ff = isl and isl:FindFirstChild("ForceField")
	if ff then
		table.insert(domes, { part = ff, name = islandName, radius = ff.Size.X / 2 })
	end
end

local lastWarn = {}

while true do
	task.wait(0.4)
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			for _, dome in ipairs(domes) do
				local centre = dome.part.Position
				local offset = root.Position - centre
				if offset.Magnitude < dome.radius - 2 and not allowed(player, dome.name) then
					local dir = offset.Magnitude > 1 and offset.Unit or Vector3.new(0, 1, 0)
					-- keep them outside and a little above, facing away from the dome
					local out = centre + dir * (dome.radius + 14)
					out = Vector3.new(out.X, math.max(out.Y, centre.Y + 20), out.Z)
					char:PivotTo(CFrame.lookAt(out, out + Vector3.new(dir.X, 0, dir.Z) + Vector3.new(0, 0, 0.001)))
					root.AssemblyLinearVelocity = Vector3.new(dir.X, 0.4, dir.Z) * 60
					local now = os.clock()
					if not lastWarn[player] or now - lastWarn[player] > 2 then
						lastWarn[player] = now
						notice:FireClient(player, dome.name, AscensionData.Islands[dome.name] or 0, true)
					end
				end
			end
		end
	end
end
