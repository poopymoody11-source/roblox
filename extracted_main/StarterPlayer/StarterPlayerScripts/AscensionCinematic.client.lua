--==================================================
-- ASCENSION CINEMATIC  (CLIENT)
--
-- Watches the Ascensions stat and plays the heaven
-- sequence whenever it goes UP.
--
-- Watching the stat rather than listening for an
-- "ascended" remote on purpose: ascension is reachable
-- from the rebirth button, the shop remote, /ascend and
-- /reset, and the stat is the one thing all of them
-- move. Nothing has to remember to fire an event.
--
-- Only increases count. /reset and /resetpasses drive
-- the stat back to 0, and a wipe is not a celebration.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local modules = ReplicatedStorage:WaitForChild("AccessibleModules", 20)
if not modules then return end

local CinematicFx = require(modules:WaitForChild("CinematicFx"))
local AscensionData = require(modules:WaitForChild("AscensionDataModule"))

local leaderstats = player:WaitForChild("leaderstats", 30)
if not leaderstats then return end

local stat =
	leaderstats:WaitForChild("Ascensions", 20)
	or leaderstats:FindFirstChild("Rebirths")

if not stat then return end

-- Seeded from the value at join, so logging in with 26
-- ascensions doesn't fire the cinematic 26 times.
local lastSeen = stat.Value

stat.Changed:Connect(function(value)
	local previous = lastSeen
	lastSeen = value

	if value <= previous then
		return
	end

	-- The character is mid-teleport-and-reset for a beat after
	-- ascending; waiting lets the world VFX land on a root part
	-- that is actually where the player ended up.
	task.wait(0.35)

	local ok, err = pcall(function()
		CinematicFx.Ascension(value, AscensionData.GetMultiplier(value))
	end)

	if not ok then
		warn("[AscensionCinematic] " .. tostring(err))
	end
end)
