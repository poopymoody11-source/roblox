--==================================================
-- CUTSCENE CONFIG
--
-- The beat sheet. Every cue time below was read off
-- the actual keyframes in the Moon Animator saves
-- rather than guessed, so the audio and the polish
-- land exactly on the cuts you authored.
--
-- Frames are 60 per second. If you re-time the
-- animation in Moon Animator, update the Frame numbers
-- here and everything follows.
--==================================================

local Config = {}

--==================================================
-- AUDIO
--
-- All from Roblox's licensed partner libraries (APM,
-- Distrokid, Pro Sound Effects), so they're cleared
-- for use in any experience -- unlike most user
-- uploads, which are locked to their uploader's games.
-- Every one was load-tested before being put here.
--==================================================

Config.Sounds = {
	Music     = { Id = 75226952728672,  Volume = 0.55, Name = "Epic Trailer Astral Stormfront" },
	Ambience  = { Id = 9119392620,      Volume = 0.35, Name = "Space Presence 2",  Looped = true },
	Drone     = { Id = 9043359885,      Volume = 0.40, Name = "Dark Drone 13" },
	Boom      = { Id = 1837830314,      Volume = 0.85, Name = "Boom Ambient Thump 04" },
	Whoosh    = { Id = 9042305931,      Volume = 0.50, Name = "Heist Spliced Sting 2" },
	Sting     = { Id = 9044902278,      Volume = 0.55, Name = "Graveyard Mystery Sting 2" },
	Roar      = { Id = 105926319962443, Volume = 0.80, Name = "Short Growl" },
	Impact    = { Id = 6555423202,      Volume = 0.70, Name = "Impact" },
	Rumble    = { Id = 9112775414,      Volume = 0.30, Name = "Eerie Rumble" },
	Riser     = { Id = 1837831381,      Volume = 0.45, Name = "Toms Roll 11" },

	-- Footsteps for the walk up to the Anti-Spiral. Two samples
	-- alternating reads as a gait; one repeated sounds like a
	-- machine.
	StepLeft  = { Id = 106672010112184, Volume = 0.42, Name = "walk_grass_left" },
	StepRight = { Id = 82667401006591,  Volume = 0.42, Name = "walk_grass_right" },
}

--==================================================
-- BACKDROPS
--
-- The camera travels from the grass, up through the
-- cloud deck, out of the atmosphere and across to the
-- black hole -- so the sky has to travel with it.
--
-- Done with atmosphere and fog rather than by swapping
-- skyboxes. The skybox here is already a starfield; at
-- ground level a thick blue atmosphere drowns it out and
-- reads as daylight, and thinning that atmosphere on the
-- way up reveals the stars underneath. It costs no new
-- assets and it's the way the real thing works.
--
-- These are applied by a LocalScript, so they only ever
-- affect the player watching -- someone already in the
-- game doesn't see the sky change.
--==================================================

Config.Backdrops = {
	grassland = {
		Sky = "Sky",
		Ambient = Color3.fromRGB(88, 92, 84),
		OutdoorAmbient = Color3.fromRGB(120, 128, 116),
		Brightness = 3,
		ClockTime = 14.5,
		FogColor = Color3.fromRGB(176, 200, 222),
		FogEnd = 2600,
		Atmosphere = {
			Density = 0.46,
			Color = Color3.fromRGB(202, 216, 232),
			Decay = Color3.fromRGB(106, 142, 190),
			-- Haze and glare kept low on purpose. The Anti-Spiral's
			-- own head emitters are already very bright, and pushing
			-- these up blew the whole left of the reveal shot to white
			-- and flattened him into a silhouette.
			Haze = 1.4,
			Glare = 0.08,
		},
		Bloom = 0.7,
	},

	-- leaving the ground, thinner air, cooler light
	upper = {
		Sky = "Sky",
		Ambient = Color3.fromRGB(64, 70, 84),
		OutdoorAmbient = Color3.fromRGB(92, 104, 126),
		Brightness = 2.6,
		ClockTime = 15.5,
		FogColor = Color3.fromRGB(120, 150, 190),
		FogEnd = 12000,
		Atmosphere = {
			Density = 0.2,
			Color = Color3.fromRGB(168, 194, 224),
			Decay = Color3.fromRGB(64, 96, 150),
			Haze = 0.7,
			Glare = 0.1,
		},
		Bloom = 1.1,
	},

	-- above the atmosphere: the starfield comes through
	space = {
		Sky = "Space",
		Ambient = Color3.fromRGB(26, 30, 46),
		OutdoorAmbient = Color3.fromRGB(32, 38, 56),
		Brightness = 2,
		ClockTime = 0,
		FogColor = Color3.fromRGB(6, 8, 18),
		FogEnd = 100000,
		Atmosphere = {
			Density = 0.02,
			Color = Color3.fromRGB(140, 160, 200),
			Decay = Color3.fromRGB(20, 26, 48),
			Haze = 0,
			Glare = 0,
		},
		Bloom = 1.5,
	},

	-- the black hole: violet, heavy, and lit from one side
	galaxy = {
		Sky = "Space",
		Ambient = Color3.fromRGB(38, 22, 58),
		OutdoorAmbient = Color3.fromRGB(44, 26, 68),
		Brightness = 1.7,
		ClockTime = 0,
		FogColor = Color3.fromRGB(18, 8, 32),
		FogEnd = 60000,
		Atmosphere = {
			Density = 0.06,
			Color = Color3.fromRGB(186, 140, 255),
			Decay = Color3.fromRGB(58, 24, 96),
			Haze = 0.4,
			Glare = 0.35,
		},
		Bloom = 2.1,
		Tint = Color3.fromRGB(226, 206, 255),
	},

	-- Where the player ends up: the boss arena, which already has a
	-- Galaxies folder of nebula billboards around it. This is also
	-- set as the place's own Lighting, so a player who skips the
	-- cutscene still arrives into the right sky.
	arena = {
		Sky = "Space",
		Ambient = Color3.fromRGB(42, 30, 66),
		OutdoorAmbient = Color3.fromRGB(50, 36, 78),
		Brightness = 1.9,
		ClockTime = 0,
		FogColor = Color3.fromRGB(14, 8, 28),
		FogEnd = 45000,
		Atmosphere = {
			Density = 0.08,
			Color = Color3.fromRGB(170, 130, 240),
			Decay = Color3.fromRGB(48, 20, 84),
			Haze = 0.3,
			Glare = 0,
		},
		-- Kept at the map's original 1.0. The arena floor gets its look
		-- from glow emitters on MainMap / MainMapVFX, and any bloom above
		-- this blooms them into a white sheet up close.
		Bloom = 1.0,
		Tint = Color3.fromRGB(232, 216, 255),
	},
}

--==================================================
-- THE DESCENT
--
-- Not a Moon Animator scene -- this one is generated,
-- because it has to end with the player's real body
-- standing in the boss arena, and the landing point is
-- a property of the map rather than of an animation.
--
-- The arena floor is the MainMap part: a 469 x 450 plane
-- whose top surface a downward raycast lands on at
-- y = -277.
--==================================================

Config.Descent = {
	Enabled = true,

	-- where the body lands, and where the player is left standing
	Landing = Vector3.new(-2603, -274, 541),

	-- how far above that the fall starts
	StartHeight = 1600,

	-- held on black after scene 2 before the fall begins
	PreDelay = 2.4,

	FallTime = 7.5,
	ImpactHold = 0.45,
	BlackHold = 0.9,
	WakeTime = 5.4,

	-- the fire builds from BurnStart to BurnPeak (fractions of the fall)
	EntryColor = Color3.fromRGB(255, 140, 60),
	BurnStart = 0.12,
	BurnPeak = 0.55,

	-- Atmosphere layers punched through on the way down, top to bottom.
	-- At = fraction of the fall (0 = start, 1 = ground). Each one is a
	-- huge local sheet the camera tears through, plus a screen tint.
	Layers = {
		{ At = 0.10, Color = Color3.fromRGB(70, 110, 255),  Transparency = 0.55, Name = "Ionosphere" },
		{ At = 0.24, Color = Color3.fromRGB(120, 170, 255), Transparency = 0.50, Name = "Mesosphere" },
		{ At = 0.38, Color = Color3.fromRGB(255, 150, 70),  Transparency = 0.45, Name = "Burn" },
		{ At = 0.52, Color = Color3.fromRGB(255, 110, 40),  Transparency = 0.40, Name = "Burn2" },
		{ At = 0.66, Color = Color3.fromRGB(235, 235, 255), Transparency = 0.25, Name = "Cloud" },
		{ At = 0.76, Color = Color3.fromRGB(210, 215, 240), Transparency = 0.20, Name = "Cloud2" },
		{ At = 0.87, Color = Color3.fromRGB(150, 110, 230), Transparency = 0.45, Name = "ArenaHaze" },
	},
}

--==================================================
-- SCENES
--
-- Cue kinds:
--   Sound  -- plays Config.Sounds[Key]
--   Shake  -- camera shake, Power studs, decaying over Time
--   Flash  -- full screen white, fading over Time
--   Punch  -- field-of-view kick of Amount degrees
--   Burst  -- fires every ParticleEmitter under Target
--   Title  -- on-screen text card
--   Backdrop -- eases the sky to a Config.Backdrops preset
--   Grade  -- a one-off push on contrast/brightness
--==================================================

Config.Scenes = {
	{
		Save = "animstart01",

		-- Which prop stands in for the player, and which of
		-- the save's item names it answers to.
		AvatarProp = "TemplateR6",

		-- Props this scene needs cloned. Cloning all of them
		-- for both scenes would put scene 2's set inside
		-- scene 1's shot.
		Props = { "TemplateR6", "Anti-Spiral guy", "Wind-01", "Explosion023" },

		Cues = {
			{ Frame = 0,   Kind = "Backdrop", Preset = "grassland", Time = 0 },
			{ Frame = 0,   Kind = "Sound", Key = "Ambience", FadeIn = 1.5 },
			{ Frame = 0,   Kind = "Sound", Key = "Music",    FadeIn = 2.0 },
			{ Frame = 0,   Kind = "Title", Text = "BECOME LA PEACE", Sub = "FINAL BOSS", Time = 3.2 },

			-- THE WALK.
			-- The leg joints key on a repeating 63-frame cycle --
			-- 0, 10, 40, 50 then again at 63, 73, 103, 113 and so on --
			-- and the two contact poses in each cycle are the +10 and
			-- +40 keys. One footstep on each of those lands the sound
			-- on the actual foot plants instead of a guessed tempo.
			{ Frame = 10,  Kind = "Sound", Key = "StepLeft" },
			{ Frame = 40,  Kind = "Sound", Key = "StepRight" },
			{ Frame = 73,  Kind = "Sound", Key = "StepLeft" },
			{ Frame = 103, Kind = "Sound", Key = "StepRight" },
			{ Frame = 136, Kind = "Sound", Key = "StepLeft" },
			{ Frame = 166, Kind = "Sound", Key = "StepRight" },
			{ Frame = 200, Kind = "Sound", Key = "StepLeft" },
			{ Frame = 230, Kind = "Sound", Key = "StepRight" },
			{ Frame = 262, Kind = "Sound", Key = "StepLeft" },
			{ Frame = 292, Kind = "Sound", Key = "StepRight" },

			-- camera cut at 321 -> 322 (5.35s)
			{ Frame = 321, Kind = "Sound", Key = "Whoosh" },
			{ Frame = 322, Kind = "Punch", Amount = 10, Time = 0.5 },
			{ Frame = 322, Kind = "Grade", Contrast = 0.3, Time = 0.35 },

			-- the Anti-Spiral guy drops in at 376 and moves on 451 / 545
			{ Frame = 360, Kind = "Sound", Key = "Rumble", FadeIn = 1.2 },
			{ Frame = 376, Kind = "Sound", Key = "Drone" },
			{ Frame = 376, Kind = "Sound", Key = "Roar" },
			{ Frame = 376, Kind = "Shake", Power = 1.2, Time = 1.4 },
			{ Frame = 376, Kind = "Punch", Amount = -8, Time = 0.9 },
			{ Frame = 376, Kind = "Grade", Contrast = 0.35, Brightness = -0.06, Time = 1.1 },
			{ Frame = 376, Kind = "Backdrop", Preset = "upper", Time = 2.6 },
			{ Frame = 451, Kind = "Shake", Power = 0.7, Time = 0.8 },
			{ Frame = 545, Kind = "Shake", Power = 0.9, Time = 0.9 },

			-- camera cut at 400 -> 401 (6.68s)
			{ Frame = 400, Kind = "Sound", Key = "Whoosh" },
			{ Frame = 401, Kind = "Punch", Amount = 12, Time = 0.5 },
			{ Frame = 401, Kind = "Grade", Contrast = 0.3, Time = 0.35 },

			-- the hand VFX come on at 577 (keypoint 0 of their
			-- Transparency curve goes 1 -> 0)
			{ Frame = 560, Kind = "Sound", Key = "Sting" },
			{ Frame = 577, Kind = "Sound", Key = "Riser" },
			{ Frame = 578, Kind = "Burst", Target = "Explosion023", Count = 18 },

			-- Wind-01 slams 179 studs down between 584 and 600
			{ Frame = 596, Kind = "Sound", Key = "Boom" },
			{ Frame = 596, Kind = "Sound", Key = "Impact" },
			{ Frame = 596, Kind = "Flash", Time = 0.45 },
			{ Frame = 596, Kind = "Shake", Power = 3.5, Time = 1.2 },
			{ Frame = 596, Kind = "Punch", Amount = 18, Time = 0.7 },
			{ Frame = 596, Kind = "Burst", Target = "Explosion023", Count = 40 },
			{ Frame = 596, Kind = "Grade", Contrast = 0.5, Brightness = 0.08, Time = 0.9 },
		},
	},

	{
		Save = "animpart2",
		AvatarProp = "TemplateR6-0.1",

		-- blackhole is staged rather than left to streaming. It sits
		-- 650 studs from the shot that looks at it, which is past what
		-- the streaming radius will deliver even with the replication
		-- focus on the camera -- and marking it Persistent didn't get
		-- it to the client either. A client-side clone is always
		-- present, so the shot is never empty. The original stays in
		-- Workspace for gameplay.
		Props = { "TemplateR6-0.1", "Wind-03", "blackhole" },

		-- Stretch the big moments: the climb off Earth (440-600) plays at
		-- 45% speed, the space shot a touch slower, and the final push on
		-- the black hole at half speed. Cues are frame based, so they
		-- stay locked to the picture.
		TimeWarp = {
			{ From = 430, To = 600, Speed = 0.45 },
			{ From = 601, To = 666, Speed = 0.7 },
			{ From = 667, To = 735, Speed = 0.5 },
		},

		-- Real cloud decks for the camera to climb through on the way up
		-- (the camera rises straight up the column at X 1343, Z 2406).
		Clouds = {
			Centre = Vector3.new(1343, 0, 2406),
			Decks = {
				{ Y = 120, Color = Color3.fromRGB(245, 247, 255), Transparency = 0.12, Clusters = 38, Radius = 520 },
				{ Y = 215, Color = Color3.fromRGB(236, 240, 252), Transparency = 0.18, Clusters = 34, Radius = 600 },
				{ Y = 320, Color = Color3.fromRGB(210, 222, 245), Transparency = 0.35, Clusters = 26, Radius = 700 },
				{ Y = 410, Color = Color3.fromRGB(170, 190, 235), Transparency = 0.6,  Clusters = 18, Radius = 800 },
			},
		},

		-- After the last frame: get pulled into the black hole.
		EndTransition = "BlackHole",

		Cues = {
			-- still stood on the ground under the cloud deck
			{ Frame = 0,   Kind = "Backdrop", Preset = "grassland", Time = 0 },
			{ Frame = 0,   Kind = "Sound", Key = "Ambience", FadeIn = 1.0 },

			-- camera climbs 393 studs between 440 and 582: leaving Earth
			{ Frame = 430, Kind = "Sound", Key = "Drone" },
			{ Frame = 435, Kind = "Sound", Key = "Riser" },
			{ Frame = 440, Kind = "Shake", Power = 0.5, Time = 2.4 },
			{ Frame = 440, Kind = "Backdrop", Preset = "upper", Time = 2.2 },

			-- through the cloud deck and out of the atmosphere
			{ Frame = 530, Kind = "Backdrop", Preset = "space", Time = 2.0 },
			{ Frame = 560, Kind = "Sound", Key = "Sting" },

			-- hard cut at 600 -> 601, straight down to y = -35
			{ Frame = 600, Kind = "Sound", Key = "Whoosh" },
			{ Frame = 601, Kind = "Punch", Amount = 14, Time = 0.5 },
			{ Frame = 601, Kind = "Shake", Power = 1.0, Time = 0.8 },
			{ Frame = 601, Kind = "Grade", Contrast = 0.3, Time = 0.4 },

			-- hard cut at 666 -> 667, 1,439 studs across to the black hole
			{ Frame = 660, Kind = "Sound", Key = "Rumble", FadeIn = 0.6 },
			{ Frame = 666, Kind = "Sound", Key = "Whoosh" },
			{ Frame = 667, Kind = "Backdrop", Preset = "galaxy", Time = 0.9 },
			{ Frame = 667, Kind = "Sound", Key = "Boom" },
			{ Frame = 667, Kind = "Flash", Time = 0.35 },
			{ Frame = 667, Kind = "Punch", Amount = 16, Time = 0.6 },
			{ Frame = 667, Kind = "Shake", Power = 2.0, Time = 1.0 },
			{ Frame = 667, Kind = "Burst", Target = "blackhole", Count = 30 },
			{ Frame = 700, Kind = "Shake", Power = 0.6, Time = 1.4 },
		},
	},
}

--==================================================
-- PRESENTATION
--==================================================

Config.Presentation = {
	LetterboxHeight = 0.11,   -- fraction of screen, per bar
	LetterboxTime   = 0.6,
	FadeTime        = 0.8,
	GapBetweenScenes = 0.35,  -- held on black

	SkipHoldTime    = 0.8,
	SkipPromptAfter = 2.5,    -- seconds before the prompt appears

	BaseFieldOfView = 70,

	-- Slight grade for the whole cutscene: a touch more contrast
	-- and bloom than gameplay, dropped on exit.
	GradeContrast   = 0.12,
	GradeSaturation = 0.08,
	BloomIntensity  = 0.9,
}

--==================================================
-- WHEN IT PLAYS
--==================================================

Config.Playback = {
	-- Every join. Set false while you're iterating on the map
	-- so you aren't sat through 22 seconds on every test.
	PlayOnJoin = true,

	-- The sky the player is left in once it's all over. Restoring
	-- whatever Lighting happened to be before would undo the arrival
	-- and drop them back into the old grey default.
	EndBackdrop = "arena",

	-- Studio only: skip straight to gameplay. Flip this on when
	-- you're building and don't want the cutscene each playtest.
	SkipInStudio = false,
}

return Config
