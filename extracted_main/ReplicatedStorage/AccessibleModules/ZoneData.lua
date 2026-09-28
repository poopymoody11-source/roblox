--==================================================
-- ZONES  (shared: server + client)
--
-- One entry per island. A zone is the matching box in
-- Workspace.Walkboxes (the big invisible parts named "1"-"4"),
-- so resizing a box in Studio resizes the zone.
--
--   WalkSpeed  -- your speed while standing in that zone
--   Pad        -- which LapisSpawnBox pad spawns lapis there;
--                 the spawner uses players-per-zone to decide
--                 how much lapis each island gets
--
-- Anywhere outside every box counts as the Starter island.
--==================================================

local ZoneData = {}

ZoneData.Zones = {
	-- (everyone's a lot faster now - the starter speed is also what you get anywhere
	-- outside the island boxes)
	{ Name = "Starter Island",  Box = "1", Pad = "A", WalkSpeed = 32 },
	{ Name = "67 Island",       Box = "3", Pad = "C", WalkSpeed = 36 },
	{ Name = "Verity Island",   Box = "2", Pad = "B", WalkSpeed = 40 },
	{ Name = "LaPeace Island",  Box = "4", Pad = "D", WalkSpeed = 46 },
}

ZoneData.Default = ZoneData.Zones[1]

local byPad = {}
for _, z in ipairs(ZoneData.Zones) do byPad[z.Pad] = z end

function ZoneData.ForPad(padName)
	return byPad[padName]
end

local function box(zone)
	local folder = workspace:FindFirstChild("Walkboxes")
	return folder and folder:FindFirstChild(zone.Box)
end

local function inside(part, pos)
	local rel = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z
end

-- Which zone is this world position in? (never nil)
-- Islands are checked before the starter box so an island floating
-- above the starter area still wins.
function ZoneData.At(pos)
	for i = #ZoneData.Zones, 2, -1 do
		local z = ZoneData.Zones[i]
		local b = box(z)
		if b and b:IsA("BasePart") and inside(b, pos) then return z end
	end
	return ZoneData.Default
end

return ZoneData
