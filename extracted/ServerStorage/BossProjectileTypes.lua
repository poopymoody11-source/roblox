-- ModuleScript | ServerStorage.BossProjectileTypes   (directly in ServerStorage, NOT in BossAttacks)
-- One entry per kind of projectile the boss can fire. The assets live in ServerStorage.BossAbilities.
--
-- To add a new projectile: put its asset in BossAbilities, add an entry here, then give it a
-- share in the BossProjectile attack's `Types` param (defaults, or per phase in BossConfig).
--
--   Template        name of the asset in BossAbilities that gets cloned and fired (Model or Part)
--   Explosion       name of the explosion asset in BossAbilities, cloned where it detonates.
--                   nil = Roblox's built-in explosion as a placeholder, false = no visual at all
--   ExplosionScale  optional: size multiplier for the explosion asset, emitters included
--   Speed           studs per second
--   HitRadius       optional: how close to a player counts as a hit. Defaults to the asset's size
--   HitHeight       optional: with it, the hitbox is a disc (HitRadius wide, this thick) oriented
--                   like the projectile, instead of a sphere
--   RotationOffset  optional Vector3 of degrees (X, Y, Z) that rotates the asset relative to its
--                   flight direction, applied from the moment it spawns
--   RandomScale     optional: each shot is scaled by a random factor between 1 and this value
--                   (e.g. 3 = randomly anywhere from original size to 3x original size)
--   BlastRadius     everyone within this distance of the explosion takes Damage
--   Damage          damage to each player caught in the blast
--   Deflectable     optional: the Verity Bat can hit it back at the boss
--   DeflectDamage   optional: damage to the boss when a batted-back one lands (default 60)
--   OnExplode       optional hook, called after the explosion with one table:
--                   { Boss, Def, Position, Victims, Damage }
local SpiralPickups = require(game:GetService("ServerStorage"):WaitForChild("SpiralPickups"))

return {
	EnergyOrb = {
		Template = "EnergyOrb",
		Explosion = "EnergyExplosion",
		Speed = 80,
		BlastRadius = 12,
		Damage = 25,
		RandomScale = 3,
		Deflectable = true,
		DeflectDamage = 60,
	},

	GalaxyProjectile = {
		Template = "GalaxyProjectile",
		Explosion = "GalaxyExplosion",
		ExplosionScale = 3,
		RotationOffset = Vector3.new(0, 0, 90),
		Speed = 45,
		HitRadius = 90, -- flat radius of the galaxy disc
		HitHeight = 12, -- vertical thickness of the galaxy disc
		BlastRadius = 120,
		Damage = 15,
		-- every galaxy that goes off leaves a Spiral Energy pickup behind
		OnExplode = function(ctx)
			SpiralPickups.Drop(ctx.Boss, ctx.Position)
		end,
	},
}