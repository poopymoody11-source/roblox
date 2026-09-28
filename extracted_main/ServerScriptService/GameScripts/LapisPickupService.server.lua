--==================================================
-- LAPIS PICKUP SERVICE
--
-- Place in: ServerScriptService (as a Script)
--
-- This is the shared middle layer between the
-- spawner and the magnet tool. Neither of them
-- talks to the other directly. They both talk
-- to this.
--
-- It owns:
--   * the SpawnedLapis folder
--   * the shared attributes (Value, Collecting,
--     Magnetized, IsSpawnedLapis)
--   * ALL collection (walk-over and magnet)
--   * reaping stale magnet claims
--
-- It does NOT own the pickup animation. That's
-- entirely client-side now (LapisVisuals.client.lua) --
-- see the note above cleanupForPickup for why.
--==================================================

local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


--==================================================
-- INVENTORY
--
-- Looked up by search rather than a fixed path,
-- because scripts are commonly nested in folders
-- (e.g. ServerScriptService > GameScripts > Game).
-- A direct-children-only lookup breaks the moment
-- you organise things into folders.
--
-- Order: sibling first (most likely), then anywhere
-- under ServerScriptService, then ServerStorage.
--==================================================

local function findInventoryModule()

	local sibling =
		script.Parent:FindFirstChild("InventoryService")

	if sibling then
		return sibling
	end

	-- 'true' = search all descendants, not just
	-- direct children.
	local nested =
		ServerScriptService:FindFirstChild(
			"InventoryService",
			true
		)

	if nested then
		return nested
	end

	return ServerStorage:FindFirstChild(
		"InventoryService",
		true
	)

end


local inventoryModule = findInventoryModule()


-- Instances all exist before scripts run, but retry
-- briefly just in case something creates it late.
if not inventoryModule then

	local deadline = os.clock() + 5

	repeat
		task.wait(0.1)
		inventoryModule = findInventoryModule()
	until inventoryModule or os.clock() > deadline

end


if not inventoryModule then

	error(
		"[LapisPickupService] Could not find a "
			.. "ModuleScript named 'InventoryService' "
			.. "anywhere in ServerScriptService or "
			.. "ServerStorage. Create it: right-click a "
			.. "folder in ServerScriptService > Insert "
			.. "Object > ModuleScript, name it exactly "
			.. "'InventoryService', paste the code in."
	)

end


if not inventoryModule:IsA("ModuleScript") then

	error(
		"[LapisPickupService] Found 'InventoryService' "
			.. "at "
			.. inventoryModule:GetFullName()
			.. " but it is a "
			.. inventoryModule.ClassName
			.. ", not a ModuleScript. Delete it and "
			.. "re-insert it as a ModuleScript, then "
			.. "paste the code back in."
	)

end


local InventoryService = require(inventoryModule)

-- AutoSell: if the player has flagged this lapis type, it is converted
-- straight to PeacePoints on pickup instead of entering the inventory.
local AutoSellService = require(
	game:GetService("ServerScriptService")
		:WaitForChild("GameScripts")
		:WaitForChild("AutoSellService")
)


--==================================================
-- CONFIGURATION
--==================================================

local CONFIG = {

	FOLDER_NAME = "SpawnedLapis",

	-- How close a player has to get to sweep one up
	-- on foot. This also catches magnet-delivered
	-- lapis, since the magnet parks them on the
	-- player's root part.
	WALKOVER_RADIUS = 5,

	-- How long the CLIENT's pickup animation (rise,
	-- spin, fade -- see LapisVisuals.client.lua) takes.
	-- Kept here too because the server uses it to time
	-- the destroy. If you change the animation length
	-- on the client, change it here as well.
	PICKUP_DURATION = 0.45,

	-- Extra buffer added on top of PICKUP_DURATION
	-- before the server destroys the instance. Covers
	-- the gap between "server sets Collecting" and
	-- "client notices Collecting and starts its local
	-- tween", so the lapis is never destroyed
	-- mid-animation.
	PICKUP_DESTROY_GRACE = 0.2,

	-- How long past its flight duration a claimed lapis
	-- is allowed to sit before the reaper frees it. See
	-- the MAGNET CLAIM REAPER section.
	MAGNET_CLAIM_GRACE = 1,

	-- Fallback values, only used if the lapis has no
	-- Value attribute and the config module has no
	-- Value field for it.
	DEFAULT_VALUES = {
		normal_lapis = 10,
		golden_lapis = 100,
		verity_lapis = 250,
	},
}


--==================================================
-- FOLDER
--==================================================

local spawnedLapis =
	workspace:FindFirstChild(
		CONFIG.FOLDER_NAME
	)

if not spawnedLapis then

	spawnedLapis = Instance.new("Folder")
	spawnedLapis.Name = CONFIG.FOLDER_NAME
	spawnedLapis.Parent = workspace

end


--==================================================
-- COLLECT EVENT
--
-- Kept for other server scripts to use. The magnet
-- no longer relies on it -- see COLLECT REQUESTS
-- below -- because a script running inside a Tool
-- held by a character lives in the Workspace and
-- therefore runs in a SANDBOXED thread, which
-- Roblox forbids from firing a non-sandboxed
-- BindableEvent.
--==================================================

local collectEvent =
	ServerStorage:FindFirstChild(
		"CollectLapis"
	)

if not collectEvent then

	collectEvent = Instance.new("BindableEvent")
	collectEvent.Name = "CollectLapis"
	collectEvent.Parent = ServerStorage

end

-- pcall'd because Sandboxed doesn't exist on older
-- Roblox builds and would hard-error there.
pcall(function()
	collectEvent.Sandboxed = true
end)


--==================================================
-- VALUE LOOKUP
--
-- Pulled from LapisDataModule if it defines a
-- Value per item. Falls back to DEFAULT_VALUES.
--==================================================

local lapisValues = {}

do
	local modules =
		ReplicatedStorage:FindFirstChild(
			"AccessibleModules"
		)

	local moduleScript =
		modules
		and modules:FindFirstChild(
			"LapisDataModule"
		)

	if moduleScript then

		local success, data =
			pcall(require, moduleScript)

		if success
			and type(data) == "table"
			and type(data.Items) == "table" then

			for _, item in ipairs(data.Items) do

				if item.Name and item.Value then

					lapisValues[item.Name] =
						item.Value

				end

			end

		end

	end
end


local function getLapisValue(lapisName)

	return lapisValues[lapisName]
		or CONFIG.DEFAULT_VALUES[lapisName]
		or 0

end


--==================================================
-- DECAL HOLDER
--
-- A Part whose only job is to hold a Decal should
-- always be invisible -- the decal still renders.
-- Used by registerLapis to hide decal-holder parts
-- the moment a lapis spawns in.
--==================================================

local function isDecalHolder(object)

	if not object:IsA("BasePart") then
		return false
	end

	for _, child in ipairs(
		object:GetChildren()
		) do

		if child:IsA("Decal") then
			return true
		end

	end

	return false

end


--==================================================
-- CLEAR MAGNET CLAIM
--
-- One place that knows every attribute a claim
-- consists of. Any code that gives up on a claim
-- calls this, so no path can clear three of the four
-- and leave the lapis in a half-claimed state.
--==================================================

local function clearMagnetClaim(lapis)

	lapis:SetAttribute("MagnetTarget", nil)
	lapis:SetAttribute("MagnetStart", nil)
	lapis:SetAttribute("MagnetDuration", nil)
	lapis:SetAttribute("Magnetized", false)
	lapis:SetAttribute("CollectRequestedBy", nil)

end


--==================================================
-- PICKUP CLEANUP
--
-- Visuals (rise, spin, fade) are entirely client-side
-- now -- see LapisVisuals.client.lua. The server's only
-- job once a lapis is collected is to stop it being
-- interacted with again and remove it once every
-- client has had time to finish the local animation.
--
-- NEVER call PivotTo here. The server doesn't know
-- where the lapis visually is once it starts flying --
-- only the client does, per-client. Reasserting any
-- CFrame from the server would replicate the lapis's
-- STALE spawn-time position to every client, snapping
-- it away from wherever it actually flew to.
--==================================================

local function cleanupForPickup(lapis)

	for _, object in ipairs(
		lapis:GetDescendants()
		) do

		if object:IsA("BasePart") then

			object.CanCollide = false
			object.CanTouch = false

		end

	end

end


local function scheduleDestroy(lapis)

	task.delay(
		CONFIG.PICKUP_DURATION
			+ CONFIG.PICKUP_DESTROY_GRACE,
		function()

			if lapis.Parent then
				lapis:Destroy()
			end

		end
	)

end


--==================================================
-- COLLECT
--
-- Single entry point. Walk-over, touch, and the
-- magnet tool all funnel through here, so double
-- collection is impossible.
--==================================================

local function collectLapis(lapis, player)

	if not lapis
		or not lapis.Parent
		or not lapis:IsA("Model") then

		return

	end


	-- Claim it before anything else. This is the
	-- lock that stops two systems awarding the same
	-- lapis on the same frame.
	if lapis:GetAttribute("Collecting") then
		return
	end


	if not player or not player.Parent then
		return
	end


	-- Who picked it up, and (if auto-sold) what it actually sold for,
	-- set BEFORE "Collecting" so the client popup can read them.
	lapis:SetAttribute("CollectedBy", player.UserId)
	local soldOnPickup, soldFor = AutoSellService.TrySellOnPickup(player, lapis.Name, 1)
	if soldOnPickup then
		lapis:SetAttribute("AutoSoldFor", soldFor or 0)
	end

	lapis:SetAttribute("Collecting", true)
	lapis:SetAttribute("Magnetized", false)


	--==================================================
	-- DEPOSIT
	--
	-- The lapis Model's Name IS the item type
	-- ("normal_lapis", "golden_lapis", ...), which is
	-- what the spawner stamps on the clone.
	--
	-- The Value attribute is still set on every lapis
	-- and deliberately unused here. Keep it -- that's
	-- what a future "sell lapis for PeacePoints" shop
	-- will read.
	--==================================================

	if not soldOnPickup then
		InventoryService.Add(player, lapis.Name, 1)
	end


	cleanupForPickup(lapis)
	scheduleDestroy(lapis)

end


collectEvent.Event:Connect(collectLapis)


--==================================================
-- COLLECT REQUESTS VIA ATTRIBUTE
--
-- This is how the magnet asks for a collect.
--
-- Attributes are plain data and cross sandbox
-- boundaries freely, unlike BindableEvent:Fire,
-- which Roblox blocks from a sandboxed thread. A
-- Tool held by a player lives in the Workspace, so
-- its script IS sandboxed -- that's the whole
-- reason this path exists.
--==================================================

local function onCollectRequested(lapis)

	local userId =
		lapis:GetAttribute("CollectRequestedBy")

	if not userId then
		return
	end


	local player = Players:GetPlayerByUserId(userId)

	if not player then

		-- Requester left mid-flight. Free the lapis
		-- completely instead of leaving it claimed by a
		-- player who no longer exists -- a half-cleared
		-- claim is invisible to every other magnet.
		clearMagnetClaim(lapis)

		return

	end


	collectLapis(lapis, player)


	-- Always clear the request, whether or not the
	-- collect went through. A leftover UserId here
	-- means the next identical write is a no-op, so
	-- GetAttributeChangedSignal never fires and that
	-- lapis silently stops being collectable.
	--
	-- (This re-enters this function once with a nil
	-- userId, which returns immediately.)
	lapis:SetAttribute("CollectRequestedBy", nil)

end


--==================================================
-- REGISTER A SPAWNED LAPIS
--
-- Backstop: if the spawner already stamped these
-- attributes we leave them alone. If something
-- spawns a lapis without them, this fills the gaps
-- so the magnet still understands it.
--==================================================

-- Spawned lapis are anchored and never move on the server until a
-- magnet claims them (and the sweep skips magnetized ones), so their
-- position is cached once instead of GetPivot() on every lapis 10x/sec.
local restPositions = {}

local function registerLapis(lapis)

	if not lapis:IsA("Model") then
		return
	end

	restPositions[lapis] = lapis:GetPivot().Position


	if lapis:GetAttribute("Registered") then
		return
	end

	lapis:SetAttribute("Registered", true)


	if lapis:GetAttribute("IsSpawnedLapis") == nil then
		lapis:SetAttribute("IsSpawnedLapis", true)
	end

	if lapis:GetAttribute("Value") == nil then

		lapis:SetAttribute(
			"Value",
			getLapisValue(lapis.Name)
		)

	end

	if lapis:GetAttribute("Collecting") == nil then
		lapis:SetAttribute("Collecting", false)
	end

	if lapis:GetAttribute("Magnetized") == nil then
		lapis:SetAttribute("Magnetized", false)
	end


	--==================================================
	-- COLLECT REQUEST LISTENER
	--==================================================

	lapis:GetAttributeChangedSignal(
		"CollectRequestedBy"
	):Connect(function()

		onCollectRequested(lapis)

	end)


	-- In case the magnet set it before this ran.
	if lapis:GetAttribute("CollectRequestedBy") then
		task.spawn(onCollectRequested, lapis)
	end


	for _, object in ipairs(
		lapis:GetDescendants()
		) do

		if object:IsA("BasePart") then

			-- Every part anchored, so PivotTo moves
			-- the whole model as one rigid piece
			-- instead of dragging one part away from
			-- the others.
			object.Anchored = true
			object.CanCollide = false

			if isDecalHolder(object) then
				object.Transparency = 1
			end


			object.Touched:Connect(function(hit)

				local character = hit.Parent

				if not character then
					return
				end

				local humanoid =
					character:FindFirstChildOfClass(
						"Humanoid"
					)

				if not humanoid
					or humanoid.Health <= 0 then

					return

				end

				local player =
					Players:GetPlayerFromCharacter(
						character
					)

				if player then
					collectLapis(lapis, player)
				end

			end)

		end

	end

end


spawnedLapis.ChildAdded:Connect(registerLapis)
spawnedLapis.ChildRemoved:Connect(function(lapis)
	restPositions[lapis] = nil
end)

for _, lapis in ipairs(
	spawnedLapis:GetChildren()
	) do

	registerLapis(lapis)

end


--==================================================
-- MAGNET CLAIM REAPER
--
-- MagnetTarget is what makes a lapis "taken" -- every
-- magnet skips a lapis that has one. So a lapis left
-- with a stale MagnetTarget is unclaimable by anyone,
-- forever, and looks to the player like that specific
-- lapis just stopped responding to the magnet.
--
-- The magnet tool clears its own claims on unequip,
-- but it can't cover every case: the player can die,
-- the tool can be destroyed outright, the script can
-- error mid-scan, the owner can leave. Rather than
-- trying to enumerate those, this just frees any claim
-- that has outlived its flight.
--
-- A claim is stale if any of these hold:
--   * no MagnetStart (claimed but never timed)
--   * the claiming player is no longer in the server
--   * it's been longer than the flight duration plus
--     MAGNET_CLAIM_GRACE
--
-- A healthy claim is collected at exactly its flight
-- duration, so the grace window means this never
-- reaps a flight that's still legitimately running.
--==================================================

local function reapStaleClaims(now)

	for _, lapis in ipairs(
		spawnedLapis:GetChildren()
		) do

		if not lapis:IsA("Model") then
			continue
		end

		if lapis:GetAttribute("Collecting") then
			continue
		end


		local target = lapis:GetAttribute("MagnetTarget")

		if not target then
			continue
		end


		local startTime =
			lapis:GetAttribute("MagnetStart")

		local duration =
			lapis:GetAttribute("MagnetDuration") or 0.6


		local expired =
			not startTime
			or (now - startTime)
			> (duration + CONFIG.MAGNET_CLAIM_GRACE)

		local ownerGone =
			Players:GetPlayerByUserId(target) == nil


		if expired or ownerGone then
			clearMagnetClaim(lapis)
		end

	end

end


--==================================================
-- WALK-OVER SWEEP
--
-- Touched is unreliable for anchored parts that get
-- moved by CFrame, which is exactly what both the
-- bob animation and the magnet do. This proximity
-- pass is the actual guarantee that a lapis sitting
-- on a player gets collected.
--
-- Note: this reads lapis:GetPivot() on the SERVER,
-- which for a currently-flying lapis is stale (still
-- its spawn spot) -- fine here, because the
-- "not Magnetized" guard below already excludes any
-- lapis mid-magnet-flight from this sweep entirely.
--==================================================

local sweepAccumulator = 0
local SWEEP_INTERVAL = 0.1


RunService.Heartbeat:Connect(function(deltaTime)

	-- Throttled. Walking over a lapis does not need a
	-- 60Hz check, and this loop is O(players * lapis)
	-- every time it runs.
	sweepAccumulator += deltaTime

	if sweepAccumulator < SWEEP_INTERVAL then
		return
	end

	sweepAccumulator = 0


	reapStaleClaims(workspace:GetServerTimeNow())


	local targets = {}

	for _, player in ipairs(
		Players:GetPlayers()
		) do

		local character = player.Character

		local humanoidRootPart =
			character
			and character:FindFirstChild(
				"HumanoidRootPart"
			)

		local humanoid =
			character
			and character:FindFirstChildOfClass(
				"Humanoid"
			)

		if humanoidRootPart
			and humanoid
			and humanoid.Health > 0 then

			table.insert(targets, {
				Player = player,
				Position = humanoidRootPart.Position,
			})

		end

	end


	if #targets == 0 then
		return
	end


	for _, lapis in ipairs(
		spawnedLapis:GetChildren()
		) do

		if lapis:IsA("Model")
			and not lapis:GetAttribute("Collecting")
			and not lapis:GetAttribute("Magnetized") then

			local position = restPositions[lapis]
			if not position then
				position = lapis:GetPivot().Position
				restPositions[lapis] = position
			end

			for _, target in ipairs(targets) do

				if (position - target.Position).Magnitude
					<= CONFIG.WALKOVER_RADIUS then

					collectLapis(
						lapis,
						target.Player
					)

					break

				end

			end

		end

	end

end)


--==================================================
-- FREE CLAIMS WHEN A PLAYER LEAVES
--
-- The reaper would catch these within a second or so
-- anyway, but doing it immediately means a lapis
-- never sits frozen mid-flight while someone else is
-- standing right next to it wondering why their
-- magnet won't take it.
--==================================================

Players.PlayerRemoving:Connect(function(player)

	for _, lapis in ipairs(
		spawnedLapis:GetChildren()
		) do

		if lapis:IsA("Model")
			and not lapis:GetAttribute("Collecting")
			and lapis:GetAttribute("MagnetTarget")
			== player.UserId then

			clearMagnetClaim(lapis)

		end

	end

end)


--==================================================
-- NOTE ON PEACEPOINTS
--
-- Collection no longer touches leaderstats at all.
-- Lapis go straight into InventoryService.
--
-- When you build the shop, PeacePoints comes back
-- as the currency you get for SELLING lapis out of
-- the inventory -- InventoryService.Remove() plus
-- the Value attribute that's still stamped on every
-- spawned lapis.
--==================================================