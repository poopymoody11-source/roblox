--==================================================
-- SPIRAL PICKUPS  (server)
--
-- ServerStorage.BossAbilities.SpiralEnergy dropped on the
-- arena floor (GalaxyProjectile explosions call Drop). Walk
-- into one to gain +1 Spiral Energy. Clients spin/bob them
-- and play the pickup effects (SpiralClient).
--
-- One Heartbeat loop handles every pickup; they expire after
-- LIFETIME seconds and there are never more than MAX_LIVE.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Spiral = require(ServerStorage:WaitForChild("SpiralEnergy"))

local Pickups = {}

local LIFETIME = 25
local MAX_LIVE = 12
local RADIUS = 7
local FLOAT = 3.5

local fx = ReplicatedStorage:FindFirstChild("SpiralFX")
if not fx then
	fx = Instance.new("RemoteEvent")
	fx.Name = "SpiralFX"
	fx.Parent = ReplicatedStorage
end

local live = {} -- { model, pos, born }

local function remove(i)
	local entry = table.remove(live, i)
	if entry and entry.model.Parent then entry.model:Destroy() end
end

function Pickups.Drop(boss, position)
	local template = ServerStorage.BossAbilities:FindFirstChild("SpiralEnergy")
	if not template then return end
	if #live >= MAX_LIVE then remove(1) end -- oldest makes room

	local ground = position
	if boss and boss.Arena then
		local a = boss.Arena
		local flat = Vector3.new(position.X - a.Center.X, 0, position.Z - a.Center.Z)
		if flat.Magnitude > a.Radius - 6 then flat = flat.Unit * (a.Radius - 6) end
		ground = Vector3.new(a.Center.X + flat.X, a.SurfaceY, a.Center.Z + flat.Z)
	end
	local pos = ground + Vector3.new(0, FLOAT, 0)

	local model = template:Clone()
	model:PivotTo(CFrame.new(pos))
	model:SetAttribute("BaseY", pos.Y)
	CollectionService:AddTag(model, "SpiralPickup")
	model.Parent = (boss and boss.Effects) or workspace
	table.insert(live, { model = model, pos = pos, born = os.clock() })
end

RunService.Heartbeat:Connect(function()
	if #live == 0 then return end
	local now = os.clock()
	local i = 1
	while i <= #live do
		local entry = live[i]
		local taken = false
		if not entry.model.Parent or now - entry.born > LIFETIME then
			remove(i)
			continue
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and (root.Position - entry.pos).Magnitude <= RADIUS then
				Spiral.Add(player, 1)
				fx:FireAllClients("Pickup", entry.pos, player)
				taken = true
				break
			end
		end
		if taken then
			remove(i)
		else
			i += 1
		end
	end
end)

return Pickups
