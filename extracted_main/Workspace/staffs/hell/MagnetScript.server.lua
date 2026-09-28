--==================================================
-- MAGNET TOOL (server authority only)
--
-- Place in: Tool > Script  (SERVER Script)
--
-- This script no longer moves anything. It only
-- decides:
--
--   * which lapis are claimed by this player
--   * when a claimed lapis has "arrived" and should
--     be collected
--
-- The visual flight is drawn by LapisVisuals on each
-- client, at full framerate, with zero replication.
-- That split is what fixed the team-test lag: server
-- PivotTo every frame meant every lapis position had
-- to cross the network at ~20Hz.
--
-- Runs at CLAIM_INTERVAL rather than every frame,
-- because claiming is a cheap decision that does not
-- need 60Hz.
--
-- OWNERSHIP INVARIANT
--
-- MagnetTarget is the claim flag: while it's set, no
-- other magnet will touch that lapis. So EVERY path
-- that gives up on a lapis has to clear it. A lapis
-- left with a stale MagnetTarget is invisible to
-- every magnet in the game, permanently -- that's
-- what made spam-equipping eventually kill lapis one
-- by one. LapisPickupService also runs a reaper for
-- this as a backstop.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local tool = script.Parent


--==================================================
-- CONFIGURATION
--==================================================

local CONFIG = {

	MAGNET_RADIUS = 98,      -- studs, how far the pull reaches

	FLIGHT_DURATION = 1,   -- seconds from claim to collect.
	-- The client's flight animation
	-- reads this, so visual and
	-- collection stay in sync.

	CLAIM_INTERVAL = 0.1,    -- seconds between scans

	LAPIS_FOLDER_NAME = "SpawnedLapis",

}


--==================================================
-- SANITY CHECK
--==================================================

if not RunService:IsServer() then

	error(
		"[Magnet] This must be a SERVER Script inside "
			.. "the Tool, not a LocalScript."
	)

end


--==================================================
-- STATE
--==================================================

local active = false
local heartbeatConnection = nil
local accumulator = 0

-- Lapis this tool has claimed but not yet collected.
local claimed = {}

-- Cached at equip time. On UNEQUIP the tool has
-- already left the character, so
-- GetPlayerFromCharacter returns nil and we'd have no
-- way to identify which lapis are ours to release.
local ownerUserId = nil


local function getLapisFolder()

	return workspace:FindFirstChild(
		CONFIG.LAPIS_FOLDER_NAME
	)

end


--==================================================
-- RELEASE
--
-- Clearing MagnetTarget hands the lapis back to the
-- client, which coasts it to a stop and resumes the
-- idle bob.
--
-- CollectRequestedBy is cleared too. That attribute
-- is read via GetAttributeChangedSignal, which only
-- fires on an actual CHANGE -- so leaving a stale
-- UserId here means the next time this same player
-- collects this same lapis, the write is a no-op, the
-- signal never fires, and the lapis silently never
-- gets collected.
--==================================================

local function release(lapis)

	claimed[lapis] = nil

	if not lapis.Parent then
		return
	end

	lapis:SetAttribute("MagnetTarget", nil)
	lapis:SetAttribute("MagnetStart", nil)
	lapis:SetAttribute("MagnetDuration", nil)
	lapis:SetAttribute("Magnetized", false)
	lapis:SetAttribute("CollectRequestedBy", nil)

end


--==================================================
-- RELEASE EVERYTHING WE OWN
--
-- Sweeps the folder by MagnetTarget rather than
-- walking the `claimed` table, because `claimed` is
-- not a complete record of what we own. A lapis that
-- has been sent for collection is removed from
-- `claimed` while its MagnetTarget stays set (the
-- client needs it to keep flying). If the collect
-- then doesn't land -- unequip lands in the same tick,
-- the player dies, whatever -- walking `claimed`
-- would skip it and strand it forever.
--==================================================

local function releaseOwned()

	local lapisFolder = getLapisFolder()

	if not lapisFolder then

		-- Fall back to whatever we still have tracked.
		for lapis in pairs(claimed) do
			release(lapis)
		end

		return

	end


	for _, lapis in ipairs(lapisFolder:GetChildren()) do

		if lapis:IsA("Model")
			and not lapis:GetAttribute("Collecting")
			and lapis:GetAttribute("MagnetTarget")
			== ownerUserId then

			release(lapis)

		end

	end


	-- Anything still tracked that the sweep missed
	-- (already reparented, mid-destroy, etc).
	for lapis in pairs(claimed) do
		release(lapis)
	end

	claimed = {}

end


--==================================================
-- SCAN
--==================================================

local function scan()

	local character = tool.Parent

	if not character then
		return
	end


	local player =
		Players:GetPlayerFromCharacter(character)

	if not player then
		return
	end


	local humanoidRootPart =
		character:FindFirstChild("HumanoidRootPart")

	if not humanoidRootPart then
		return
	end


	local playerPosition = humanoidRootPart.Position

	local lapisFolder = getLapisFolder()

	if not lapisFolder then
		return
	end


	local now = workspace:GetServerTimeNow()


	--==================================================
	-- RESOLVE ALREADY-CLAIMED LAPIS
	--==================================================

	for lapis in pairs(claimed) do

		if not lapis.Parent
			or lapis:GetAttribute("Collecting") then

			-- Gone or already being collected. Just drop
			-- our tracking -- no attributes to clean up,
			-- the pickup service owns it now.
			claimed[lapis] = nil

		elseif lapis:GetAttribute("MagnetTarget")
			~= player.UserId then

			-- Someone else's now, or it was reaped out
			-- from under us. Not ours to clear.
			claimed[lapis] = nil

		else

			local startTime =
				lapis:GetAttribute("MagnetStart")

			if not startTime then

				-- Claimed but untimed -- shouldn't happen,
				-- but if it does, RELEASE it rather than
				-- just forgetting it. Dropping it from
				-- `claimed` alone would leave MagnetTarget
				-- set and make the lapis permanently
				-- unclaimable by anyone.
				release(lapis)

			elseif now - startTime
				>= CONFIG.FLIGHT_DURATION then

				-- Arrived. Ask the pickup service to
				-- collect it.
				--
				-- An attribute, not a BindableEvent: a
				-- Tool held by a player lives in the
				-- Workspace, so this script runs in a
				-- sandboxed thread, and Roblox forbids
				-- those from firing a non-sandboxed
				-- BindableEvent.
				--
				-- MagnetTarget deliberately stays set so
				-- the client keeps drawing the flight
				-- until Collecting flips. The pickup
				-- service's reaper will clear it if the
				-- collect never lands.
				claimed[lapis] = nil

				-- Cleared first so the write below is
				-- always a real change and always fires
				-- GetAttributeChangedSignal, even if this
				-- exact UserId was the last value.
				lapis:SetAttribute(
					"CollectRequestedBy",
					nil
				)

				lapis:SetAttribute(
					"CollectRequestedBy",
					player.UserId
				)

			end

		end

	end


	--==================================================
	-- CLAIM NEW LAPIS
	--==================================================

	for _, lapis in ipairs(lapisFolder:GetChildren()) do

		if not lapis:IsA("Model") then
			continue
		end

		if not lapis:GetAttribute("IsSpawnedLapis") then
			continue
		end

		if lapis:GetAttribute("Collecting") then
			continue
		end

		-- Already claimed, by us or by someone else.
		if lapis:GetAttribute("MagnetTarget") then
			continue
		end


		local distance =
			(lapis:GetPivot().Position - playerPosition)
			.Magnitude

		if distance <= CONFIG.MAGNET_RADIUS then

			claimed[lapis] = true

			-- Wipe any leftover request from a previous
			-- flight before this one starts.
			lapis:SetAttribute("CollectRequestedBy", nil)

			lapis:SetAttribute("Magnetized", true)

			lapis:SetAttribute(
				"MagnetDuration",
				CONFIG.FLIGHT_DURATION
			)

			-- Set the target LAST. The client starts
			-- animating the moment it sees this, so the
			-- timing attributes must already be there.
			lapis:SetAttribute("MagnetStart", now)

			lapis:SetAttribute(
				"MagnetTarget",
				player.UserId
			)

		end

	end

end


--==================================================
-- START / STOP
--
-- Both are idempotent. Equipped, Unequipped and
-- AncestryChanged can all fire in quick succession
-- when a tool is spam-toggled, sometimes out of the
-- order you'd expect.
--==================================================

local function startMagnet()

	local character = tool.Parent

	local player =
		character
		and Players:GetPlayerFromCharacter(character)

	if player then
		ownerUserId = player.UserId
	end


	if active then
		return
	end

	active = true
	accumulator = 0

	heartbeatConnection =
		RunService.Heartbeat:Connect(
			function(deltaTime)

				accumulator += deltaTime

				if accumulator
					< CONFIG.CLAIM_INTERVAL then

					return

				end

				accumulator = 0

				scan()

			end
		)

end


local function stopMagnet()

	if not active and next(claimed) == nil then
		return
	end

	active = false

	if heartbeatConnection then

		heartbeatConnection:Disconnect()
		heartbeatConnection = nil

	end

	releaseOwned()

end


tool.Equipped:Connect(startMagnet)
tool.Unequipped:Connect(stopMagnet)

tool.AncestryChanged:Connect(function()

	if not tool:IsDescendantOf(workspace) then
		stopMagnet()
	end

end)