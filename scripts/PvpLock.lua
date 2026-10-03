--==================================================
-- PVP LOCK  (server)
-- Once you get the bat from Tung you're a fighter: PvP turns ON
-- for good and the toggle can't switch it off. The only break is
-- 30 seconds of spawn protection every time you respawn (a
-- visible forcefield - nobody can hit you, you can't be flung).
--
-- Attributes on the player:
--   PvpLocked            true once you own a bat
--   SpawnProtectedUntil  os-time-ish (workspace:GetServerTimeNow())
--==================================================
local Players = game:GetService("Players")
local SPAWN_PROTECTION = 30

local function ownsBat(player)
	for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character, player:FindFirstChild("StarterGear") }) do
		if holder and (holder:FindFirstChild("Bat") or holder:FindFirstChild("VerityBat")) then return true end
	end
	return false
end

local function lock(player)
	if not player:GetAttribute("PvpLocked") then
		player:SetAttribute("PvpLocked", true)
	end
	-- (PvP stays off inside Cruelty's arena; CrueltyFightService turns it back on after)
	if player:GetAttribute("PvpEnabled") ~= true and not player:GetAttribute("InCrueltyArena") then
		player:SetAttribute("PvpEnabled", true)
	end
end

local function protect(player, char)
	local untilT = workspace:GetServerTimeNow() + SPAWN_PROTECTION
	player:SetAttribute("SpawnProtectedUntil", untilT)
	local ff = Instance.new("ForceField")
	ff.Name = "SpawnProtection"
	ff.Visible = true
	ff.Parent = char
	task.delay(SPAWN_PROTECTION, function()
		if ff.Parent then ff:Destroy() end
	end)
end

local function hook(player)
	-- nobody (settings menu, the button, an admin) can switch a locked PvP back off
	player:GetAttributeChangedSignal("PvpEnabled"):Connect(function()
		if player:GetAttribute("PvpLocked") and player:GetAttribute("PvpEnabled") ~= true
			and not player:GetAttribute("InCrueltyArena") then -- (off during the Cruelty fight)
			task.defer(function()
				if not player:GetAttribute("InCrueltyArena") then player:SetAttribute("PvpEnabled", true) end
			end)
		end
	end)
	local first = true
	local function onChar(char)
		local isFirst = first
		first = false
		task.wait(1) -- (the backpack refills first)
		if ownsBat(player) then lock(player) end
		-- respawning (not the first spawn of the session) as a fighter
		if player:GetAttribute("PvpLocked") and not isFirst then protect(player, char) end
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then task.spawn(onChar, player.Character) end
	-- picking the bat up mid-life
	task.spawn(function()
		while player.Parent == Players do
			if not player:GetAttribute("PvpLocked") and ownsBat(player) then lock(player) end
			task.wait(1)
		end
	end)
end

Players.PlayerAdded:Connect(hook)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(hook, p) end

-- shared check for the damage scripts
_G.IsSpawnProtected = function(player)
	return (player:GetAttribute("SpawnProtectedUntil") or 0) > workspace:GetServerTimeNow()
end
