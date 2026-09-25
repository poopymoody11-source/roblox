--==================================================
-- FINAL CUTSCENE TIMELINE (shared by server + client)
-- Every chapter starts at a fixed number of seconds after
-- the shared start time, so all clients stay in sync with
-- each other and with the server (which moves the real
-- bodies into the arena and starts the fight on schedule).
--==================================================
local T = {}

T.MaxPlayers = 8

-- how long the server waits for the rest of the party
T.WaitForParty = 60     -- hard cap after the first player arrives
T.GatherMin = 6         -- never start sooner than this after the first join
T.SettleAfterJoin = 3   -- ...or sooner than this after the latest join
T.Countdown = 4         -- "everyone's here" banner before the start

T.Chapters = {
	{ Name = "Grass",     Dur = 26 },
	{ Name = "Launch",    Dur = 16.2 },
	{ Name = "Space",     Dur = 22 },
	{ Name = "Drag",      Dur = 13 },
	{ Name = "Vortex",    Dur = 5 },   -- (replaces the old black hole: the fall into the Anti-Spiral's portal)
	{ Name = "Portal",    Dur = 6 },
	-- the Spiral Galaxy (ChEntry, ChHand, ChAwaken)
	{ Name = "Ejected",   Dur = 6 },    -- blown out of the vortex, spinning
	{ Name = "Layers",    Dur = 13 },   -- down through the panes of 4-D space
	{ Name = "Float",     Dur = 11 },   -- broken out of 4-D space: drift free and take in the Galaxy Realm
	{ Name = "Descent",   Dur = 12 },   -- he charges across a floor of his power, leaps... and is gone
	{ Name = "Catch",     Dur = 11 },   -- caught in his hand
	-- ("Absorb" - him taking the True Lapeace - is out for now; ChHand.Absorb is kept for later)
	{ Name = "Crush",     Dur = 8 },
	{ Name = "Funnel",    Dur = 9 },    -- every galaxy's spiral energy
	{ Name = "Veins",     Dur = 11 },   -- inside you
	{ Name = "Transform", Dur = 11 },   -- the Spiral Bat
	{ Name = "Shout",     Dur = 7 },    -- JUST WHO THE HELL DO YOU THINK WE ARE
	{ Name = "IAm",       Dur = 9.5 },  -- JUST WHO THE HELL DO YOU THINK I AM - then you both land, and the arena is there
}

local t = 0
T.ByName = {}
for i, c in ipairs(T.Chapters) do
	c.Index = i
	c.Start = t
	t += c.Dur
	T.ByName[c.Name] = c
end
T.Total = t

-- the server moves the real bodies to the arena at the start of this chapter
T.ArenaChapter = "Descent"

--==================================================
-- PLACES
--==================================================
-- the open field in the middle of the Become La Peace island (south of the shop),
-- facing north toward the shop and where the portal opens
T.Meadow = CFrame.new(143, 134, -18380)

-- slots around the meadow, in the meadow's frame (x right, z back)
T.MeadowSlots = {
	Vector3.new(-3, 0, 12), Vector3.new(7, 0, 10), Vector3.new(-11, 0, 15), Vector3.new(14, 0, 15),
	Vector3.new(-17, 0, 20), Vector3.new(2, 0, 20), Vector3.new(20, 0, 22), Vector3.new(-7, 0, 24),
}

-- the new arena (workspace.BossFight, MainMap top at y = 0.5)
T.ArenaCenter = Vector3.new(0, 0.5, 20000)
T.ArenaRadius = 225
T.LapisPos = Vector3.new(0, 35.5, 20000)
T.ShrinePos = Vector3.new(0, 0.5, 20000)

-- where each slot ends up standing when the fight starts (after the knockback)
function T.ArenaStand(slot)
	local row = (slot - 1) % 4
	local col = math.floor((slot - 1) / 4)
	local z = (row - 1.5) * 11
	local x = -95 - col * 12 + ((row % 2) * 4)
	return T.ArenaCenter + Vector3.new(x, 3, z)
end

-- client-built sets (all far apart, all within +-30k)
T.SpaceOrigin = Vector3.new(-20000, 0, 0)
T.HoleOrigin = Vector3.new(20000, 0, 0)

function T.Chapter(name) return T.ByName[name] end

--==================================================
-- THE LIFT-OFF (shared by the Grass and Launch chapters)
-- Height above the ground (studs) lt seconds after the beam
-- fires. A slow, eerie float off the grass first (feet leave
-- the ground, ~5 studs in 1.6s), then a cubic build-up into
-- a violent, uncontrollable rise (~390 studs/s by the time
-- the Grass chapter hands over at lt = 5.75).
--==================================================
T.LiftFloat = 0.7        -- seconds of float before the rise takes over (short: they go up WITH the beam)
T.LiftHandOver = 5.75    -- launch clock when the Launch chapter starts
function T.LaunchY(lt)
	if lt <= 0 then return 3 end
	if lt <= T.LiftFloat then
		local s = lt / T.LiftFloat
		return 3 + 14 * s * s
	end
	local tau = lt - T.LiftFloat
	return 3 + 14 + 40 * tau + 4.57 * tau * tau * tau
end
-- vertical speed (studs/s) at lt (~390 at the hand-over, matching the Launch climb)
function T.LaunchV(lt)
	if lt <= 0 then return 0 end
	if lt <= T.LiftFloat then return 28 * lt / (T.LiftFloat * T.LiftFloat) end
	local tau = lt - T.LiftFloat
	return 40 + 13.71 * tau * tau
end

return T
