-- ModuleScript | ServerStorage.BossConfig
-- Phases are data. Each attack entry can override that attack's defaults with Params,
-- so phase 2 can hit harder without touching any attack code.
local Util = require(game:GetService("ServerStorage"):WaitForChild("BossUtil"))

return {
	DisplayName = "Anti-Spiral",
	MaxHealth = 5000,

	Phases = {
		{
			Name = "Phase 1",
			StartsAtHealthPct = 1,
			AttackDelay = 2.5, -- pause between attacks
			-- entrance: the boss flares, a shockwave sweeps the arena and light bursts from the floor
			OnEnter = function(boss)
				task.spawn(function()
					local arena = boss.Arena
					Util.FlashBoss(boss, Util.GOLD, 1.2)
					Util.Shake(arena.Center, 1.8, 1, 800)
					Util.Sound(boss, arena.Center, Util.METEOR_SOUND, 2, 0.5)
					Util.Ring(boss, arena.Center, { From = 10, To = arena.Radius + 20, Time = 0.9, Color = Util.GOLD, Thickness = 8, Height = 5, Segments = 48 })
					task.wait(0.15)
					Util.Ring(boss, arena.Center, { From = 5, To = arena.Radius, Time = 1.0, Color = Util.WHITE, Thickness = 3, Height = 2, Segments = 48 })
					for i = 1, 10 do
						local spot = Util.RandomPointInArena(arena, 20)
						Util.Pillar(boss, spot, { Height = math.random(80, 160), Radius = math.random(5, 10), Color = if i % 2 == 0 then Util.GOLD else Util.VIOLET, Time = 0.8 })
						task.wait(0.05)
					end
				end)
			end,
			Attacks = {
				{ Module = "Melee",          Weight = 3 },
				{ Module = "BossProjectile", Weight = 2 },
				{ Module = "MapProjectile",  Weight = 2 },
				{ Module = "Summon",         Weight = 1 },	
				{ Module = "GasterRandom",   Weight = 2 },
				{ Module = "GasterCircle",   Weight = 1 },
				--{ Module = "SpiralLance",    Weight = 2 },
				--{ Module = "SpiralPinwheel", Weight = 2 },
			},
		},
		{
			Name = "Phase 2",
			StartsAtHealthPct = 0.5,
			AttackDelay = 1.6,
			TransitionTime = 3, -- boss is invulnerable and idle while the phase change plays
			OnEnter = function(boss)
				-- roar animation / color change / arena effect goes here
			end,
			Attacks = {
				{ Module = "Melee",          Weight = 3, Params = { Damage = 55, KnockbackSpeed = 170 } },
				{ Module = "BossProjectile", Weight = 3, Params = { DamageMultiplier = 1.25 } },
				-- To make the meteor harder in phase 2, try Params = { Damage = 45, Warning = 1.3 }
				{ Module = "MapProjectile",  Weight = 3 },
				{ Module = "Summon",         Weight = 2, Params = { Count = 4, MaxAlive = 8 } },
			},
		},
	},
}