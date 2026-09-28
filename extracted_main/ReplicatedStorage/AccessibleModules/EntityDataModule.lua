local EntityDataModule = {}
-- Config settings for each mob type
EntityDataModule.Mobs = {
	-- SMALL MOB: High spawn chance, drops common lapis, very low caps
	["Zombie"] = {
		SpawnChance = 0.70,       -- 70% chance to spawn during the night
		MaxAmount = 15,           -- Can have many on the map at once
		SpawnCooldown = 5,        -- Min seconds between two Zombie spawns
		DropLoot = true,          
		SpawnableLoot = {         
			"normal_lapis",       -- Common drop
			"golden_lapis"        -- Slightly better drop
		}
	},
	-- MEDIUM MOB: Moderate spawn chance, slightly better item selection
	["Skeleton"] = {
		SpawnChance = 0.25,       -- 25% chance to spawn
		MaxAmount = 8,
		SpawnCooldown = 15,       -- Min seconds between two Skeleton spawns
		DropLoot = true,
		SpawnableLoot = {
			"normal_lapis",
			"golden_lapis",
			"rgb_lapis"           -- Higher tier drop
		}
	},
	-- BOSS MOB: Extremely rare spawn, very restrictive cap, drops high-end rewards
	["LapisTitanBoss"] = {
		SpawnChance = 0.05,       -- 5% chance to spawn (Very Rare!)
		MaxAmount = 1,            -- Only 1 can exist at a time
		SpawnCooldown = 900,      -- Min seconds between two boss spawns (15 min)
		DropLoot = true,
		SpawnableLoot = {         
			"lapeace_lapis",      -- Boss exclusive tier
			"verity_lapis",       -- Boss exclusive tier
			"hell_lapis",         -- Boss exclusive tier
			"malevolent_lapis",   -- Ultra rare boss drop
			"interstellar_lapis"  -- Ultra rare boss drop
		}
	}
}
-- Helper function to fetch data safely
function EntityDataModule.GetMobData(mobName)
	return EntityDataModule.Mobs[mobName]
end
return EntityDataModule