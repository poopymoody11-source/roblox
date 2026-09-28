-- Place in: ServerScriptService

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local startBossFightEvent = ReplicatedStorage:FindFirstChild("StartBossFight")
if not startBossFightEvent then
	startBossFightEvent = Instance.new("RemoteEvent")
	startBossFightEvent.Name = "StartBossFight"
	startBossFightEvent.Parent = ReplicatedStorage
end

local crueltycutscene = workspace:WaitForChild("CrueltyCutscene")
local cruelty = crueltycutscene:WaitForChild("Cruelty")
cruelty:WaitForChild("Humanoid") -- make sure the boss model is fully loaded

-- Assumes one shared boss instance that everyone fights together.
-- If you actually want a separate fight per player/party, this needs to key
-- the state (and probably the boss itself) per player/group instead.

-- IMPORTANT: the FightActive attribute on the boss is the single source of
-- truth for "is a fight running". CrueltyAIScript clears it when the fight
-- ends or is cancelled. We deliberately do NOT keep a separate boolean here:
-- the old `fightStarted` flag was set to true on the first trigger and never
-- reset, so every later trigger returned early, FightActive never changed,
-- and the boss clone never spawned again.

local RETRIGGER_COOLDOWN = 1 -- seconds; Touched can fire many times per second
local lastStartAttempt = 0

-- Never boot up stuck "in a fight" (e.g. the place was saved mid-fight).
cruelty:SetAttribute("FightActive", false)

-- The fight is now started only by CrueltyLobbyService (party menu -> portal ->
-- dive). Nothing fires this remote any more; it stays so old clients don't
-- error, but it no longer starts anything -- otherwise any client could skip
-- the lobby, the one-party lock and the recital gate.
local LEGACY_REMOTE_ENABLED = false

startBossFightEvent.OnServerEvent:Connect(function(player)
	if not LEGACY_REMOTE_ENABLED then return end
	-- Already fighting -- ignore repeat/duplicate triggers.
	if cruelty:GetAttribute("FightActive") then
		return
	end

	local now = os.clock()
	if now - lastStartAttempt < RETRIGGER_COOLDOWN then
		return
	end
	lastStartAttempt = now

	-- The "go" signal. CrueltyAIScript watches this attribute and spawns the
	-- active boss clone; the boss health bar GUI can watch it too.
	cruelty:SetAttribute("FightActive", true)
end)