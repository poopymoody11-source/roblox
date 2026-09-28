--==================================================
-- SPIRAL ENERGY  (server API)
--
-- Each player stores up to MAX spiral energy (shown in
-- the bottom-left gauge). Use this from any server code:
--
--   local Spiral = require(game.ServerStorage.SpiralEnergy)
--   Spiral.Add(player, 1)          -- gain (clamped to max)
--   if Spiral.Spend(player, 5) then -- returns true if they had enough
--       -- fire a spiral super attack
--   end
--   Spiral.Get(player) / Spiral.IsFull(player)
--==================================================

local SpiralEnergy = {}

SpiralEnergy.MAX = 10

function SpiralEnergy.Get(player)
	return player:GetAttribute("SpiralEnergy") or 0
end

function SpiralEnergy.Set(player, value)
	player:SetAttribute("SpiralEnergyMax", SpiralEnergy.MAX)
	player:SetAttribute("SpiralEnergy", math.clamp(math.floor(value), 0, SpiralEnergy.MAX))
end

function SpiralEnergy.Add(player, amount)
	SpiralEnergy.Set(player, SpiralEnergy.Get(player) + (amount or 1))
end

function SpiralEnergy.Spend(player, amount)
	amount = amount or 1
	if SpiralEnergy.Get(player) < amount then return false end
	SpiralEnergy.Set(player, SpiralEnergy.Get(player) - amount)
	return true
end

function SpiralEnergy.IsFull(player)
	return SpiralEnergy.Get(player) >= SpiralEnergy.MAX
end

return SpiralEnergy
