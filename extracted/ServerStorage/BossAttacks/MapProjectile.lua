-- ModuleScript | ServerStorage.BossAttacks.MapProjectile
-- One meteor from the map per attack. A warning disc marks the landing spot, the meteor
-- (ServerStorage.BossAbilities.Meteor, a Model) falls onto it, and ServerStorage.BossAbilities.MeteorExplosion
-- (a Part) plays where it lands. Both are scaled up, particle emitters included.
local ServerStorage = game:GetService("ServerStorage")
local Util = require(ServerStorage:WaitForChild("BossUtil"))

local MapProjectile = {}

MapProjectile.MinRange = 0
MapProjectile.MaxRange = math.huge -- usable from anywhere

-- The Meteor model's main mesh at its ORIGINAL size (before Scale is applied)
local MESH_SIZE = Vector3.new(17.872, 18.431, 17.89)
local MESH_RADIUS = math.max(MESH_SIZE.X, MESH_SIZE.Y, MESH_SIZE.Z) / 2 -- ~9.2 studs

MapProjectile.Defaults = {
	Template = "Meteor",           -- Model in ServerStorage.BossAbilities
	Explosion = "MeteorExplosion", -- Part in ServerStorage.BossAbilities
	Scale = 2,                     -- size multiplier for the meteor AND its explosion (emitters included)
	-- Radius = 18,                -- optional override. Left out, the warning disc and hitbox are the
	--                                meteor's scaled radius: MESH_RADIUS * Scale (~18.4 studs at 2x)
	Damage = 30,
	TargetedPct = 1,               -- chance it lands on a player; otherwise a random spot on the disc
	Warning = 1.6,                 -- telegraph time = the player's dodge window (also the fall time)
	FallHeight = 120,              -- studs above the landing height it starts falling from
	Recovery = 0.5,                -- pause after impact
}

function MapProjectile.Execute(boss, target, isCancelled, p)
	if isCancelled() then return end

	-- the boss calls it down (BossAttacks.Anims.Meteor)
	local anim = script.Parent:FindFirstChild("Anims") and script.Parent.Anims:FindFirstChild("Meteor")
	if anim and anim.AnimationId ~= "" then
		pcall(function() boss:GetTrack(anim):Play(0.15) end)
	end

	-- the warning disc and the damage zone share this one number, so what you see is what hurts
	local radius = p.Radius or MESH_RADIUS * p.Scale

	local point
	local targets = boss:GetTargets()
	if #targets > 0 and math.random() < p.TargetedPct then
		local root = targets[math.random(#targets)]
		point = Util.GroundPoint(boss.Arena, root.Position, radius / 2)
	else
		point = Util.RandomPointInArena(boss.Arena, radius)
	end

	Util.Meteor(boss, point, { -- yields until the meteor has landed
		Template = p.Template,
		Explosion = p.Explosion,
		Scale = p.Scale,
		Radius = radius,
		Damage = p.Damage,
		Warning = p.Warning,
		FallHeight = p.FallHeight,
	})

	task.wait(p.Recovery)
end

return MapProjectile