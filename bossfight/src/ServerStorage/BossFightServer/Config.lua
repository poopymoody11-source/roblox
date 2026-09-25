--==================================================
-- BOSS FIGHT: CONFIG
-- Tune the fight here. Attack modules live in ./Attacks and
-- are listed per phase by name; Params override each
-- module's own Defaults.
--==================================================
return {
	DisplayName = "Anti-Spiral",

	-- his health: MaxHealth for one player, plus this share of it per extra player
	-- (2 players = 1.7x, 4 players = 3.1x ...)
	MaxHealth = 4000,
	HealthPerExtraPlayer = 0.7,

	WalkSpeed = 70,          -- studs/s round the ring at full stride
	WalkArc = { 35, 80 },    -- degrees he walks between attacks (random in range)

	-- a parried hit's damage to him, if the attack doesn't set its own Counter
	ParryDamage = 40,

	-- set pieces: each comes out once, next, as his health crosses At
	SetPieces = {
		{ At = 0.72, Module = "BigBang" },            -- his ultimate
		{ At = 0.58, Module = "GalaxyCorruption" },   -- the end of phase 1
		{ At = 0.3, Module = "BigBang" },
	},
	UltimateCounterDelay = 3.4, -- (the Big Bang counter cinematic's length: its damage lands at the end)

	Phases = {
		{
			Name = "THE END OF ALL SPIRALS",
			StartsAtHealthPct = 1,
			AttackDelay = 1.1,  -- rest after an attack, before he walks on
			Attacks = {
				{ Module = "GalaxyBarrage", Weight = 3 },
				{ Module = "FistSlam", Weight = 3 },
				{ Module = "StompQuake", Weight = 2 },
				{ Module = "ConstellationLances", Weight = 2 },
				{ Module = "AnnihilationBeam", Weight = 2 },
				{ Module = "SpiralCollapse", Weight = 1.5 },
			},
		},
		{
			-- (placeholder until phase 2 gets its own design: the same attacks, harder)
			Name = "DESPAIR OF THE UNIVERSE",
			StartsAtHealthPct = 0.5,
			AttackDelay = 0.7,
			TransitionTime = 3.5,
			DamageMultiplier = 1.25,
			UltimateParams = { Speed = 1.2 },
			Attacks = {
				{ Module = "GalaxyBarrage", Weight = 3, Params = { Shots = 22, Interval = 0.26, Portals = 3 } },
				{ Module = "FistSlam", Weight = 3, Params = { Waves = 3, ExtraZones = 4 } },
				{ Module = "StompQuake", Weight = 2, Params = { Rings = 5, Speed = 85 } },
				{ Module = "ConstellationLances", Weight = 2, Params = { Lines = 9 } },
				{ Module = "AnnihilationBeam", Weight = 2, Params = { Sweeps = 2, Sweep = 1.9 } },
				{ Module = "SpiralCollapse", Weight = 1.5, Params = { Strength = 13, R = 85 } },
			},
		},
	},
}
