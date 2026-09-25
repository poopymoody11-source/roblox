--==================================================
-- BOSS FIGHT: CONFIG
-- Tune the fight here. Attack modules live in ./Attacks and
-- are listed per phase by name; Params override each
-- module's own Defaults.
--==================================================
return {
	DisplayName = "Anti-Spiral",
	MaxHealth = 6000,

	WalkSpeed = 70,          -- studs/s round the ring at full stride
	WalkArc = { 35, 80 },    -- degrees he walks between attacks (random in range)

	-- what a parry does to him (perfect = within Shared.PERFECT of impact)
	ParryDamage = 45,
	PerfectDamage = 80,

	-- the Spiral Bat
	Bat = {
		SwingCooldown = 0.28,
		ComboReset = 0.9,     -- seconds before the combo starts over
		MeleeDamage = 20,     -- on anything with a Humanoid in reach (minions, his body if you get close)
		MeleeRange = 11,
		DrillDamage = 60,     -- E: Drill Break, thrown at his core
		DrillCooldown = 7,
		DrillSpeed = 260,     -- studs/s
		DashCooldown = 2.2,   -- Q: Spiral Dash
		DashIFrames = 0.35,
	},

	Phases = {
		{
			Name = "THE END OF ALL SPIRALS",
			StartsAtHealthPct = 1,
			AttackDelay = 1.2,  -- rest after an attack, before he walks on
			Attacks = {
				{ Module = "GalaxyBarrage", Weight = 3 },
				{ Module = "FistSlam", Weight = 3 },
				{ Module = "StompQuake", Weight = 2 },
				{ Module = "ConstellationLances", Weight = 2 },
			},
		},
		{
			-- (placeholder until phase 2 gets its own design: the same attacks, harder)
			Name = "DESPAIR OF THE UNIVERSE",
			StartsAtHealthPct = 0.5,
			AttackDelay = 0.7,
			TransitionTime = 3.5,
			DamageMultiplier = 1.25,
			Attacks = {
				{ Module = "GalaxyBarrage", Weight = 3, Params = { Shots = 22, Interval = 0.26, Portals = 3 } },
				{ Module = "FistSlam", Weight = 3, Params = { Waves = 3, ExtraZones = 4 } },
				{ Module = "StompQuake", Weight = 2, Params = { Rings = 5, Speed = 85 } },
				{ Module = "ConstellationLances", Weight = 2, Params = { Lines = 9 } },
			},
		},
	},
}
