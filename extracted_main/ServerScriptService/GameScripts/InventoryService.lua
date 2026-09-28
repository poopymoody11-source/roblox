--==================================================
-- INVENTORY SERVICE
--
-- Place in: ServerScriptService
-- Type: ModuleScript   <-- NOT a Script
--
-- This is the single source of truth for what every
-- player is carrying. Nothing else is allowed to
-- store counts. Other server scripts require this
-- and call Add / Remove / Set / Get.
--
-- Data lives in a plain table here on the server,
-- backed by a DataStore -- see PERSISTENCE below.
-- Never in the GUI. If the count lived in a
-- TextLabel, an exploiter could just set it to 999.
--
-- REQUIRES "Enable Studio Access to API Services"
-- turned on (Home tab > Game Settings > Security) --
-- DataStore calls silently fail without it, and
-- you'll see warnings in Output saying so.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")


local InventoryService = {}


--==================================================
-- STORAGE
--
-- [player] = { normal_lapis = 3, golden_lapis = 1 }
--
-- In-memory, backed by DataStore -- loaded on join,
-- saved on leave/shutdown/autosave. See PERSISTENCE
-- below for all of that.
--==================================================

local inventories = {}

-- [player] = true once loadInventory has finished for
-- them. Other scripts that also run on PlayerAdded
-- (e.g. LeaderstatsSetup) MUST call
-- InventoryService.WaitUntilLoaded(player) before
-- reading/writing this player's inventory, otherwise
-- they can race the DataStore load below and end up
-- double-counting or losing data.
local isLoaded = {}


--==================================================
-- PERSISTENCE CONFIG
--==================================================

local PERSISTENCE = {

	-- Versioned so you can bump this later (e.g. if
	-- you ever change the save format) without old
	-- and new data colliding.
	DATASTORE_NAME = "LapisInventory_v1",

	-- How often the safety-net autosave sweeps every
	-- connected player, in seconds. This is on top of
	-- the save-on-leave below, purely a crash/hard-
	-- disconnect backstop -- keep it infrequent so you
	-- don't burn your DataStore request budget with a
	-- lot of concurrent players.
	AUTO_SAVE_INTERVAL = 180,

}


local inventoryStore =
	DataStoreService:GetDataStore(
		PERSISTENCE.DATASTORE_NAME
	)


local function keyFor(player)
	return "Player_" .. player.UserId
end


--==================================================
-- REMOTE SETUP
--
-- Created here rather than placed by hand, so load
-- order never matters and you can't typo a name in
-- Explorer.
--==================================================

local function ensure(parent, name, className)

	local existing = parent:FindFirstChild(name)

	if existing then
		return existing
	end

	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent

	return created

end


local remotes =
	ensure(ReplicatedStorage, "Remotes", "Folder")

-- Server -> client push: "your inventory changed"
local inventoryUpdated =
	ensure(remotes, "InventoryUpdated", "RemoteEvent")

-- Client -> server ask: "what do I have?"
local getInventory =
	ensure(remotes, "GetInventory", "RemoteFunction")


--==================================================
-- SERVER-SIDE CHANGE SIGNAL
--
-- Separate from inventoryUpdated above. That one only
-- reaches the OWNING player's client (FireClient).
-- Other SERVER systems (PlayerStatsService, a future
-- sell system, anti-cheat, whatever) need their own
-- way to hear "this player's inventory changed" --
-- this is that. Fires with (player, inventoryCopy).
--==================================================

local changedEvent = Instance.new("BindableEvent")

InventoryService.Changed = changedEvent.Event


--==================================================
-- INTERNAL
--==================================================

local function getOrCreate(player)

	local inventory = inventories[player]

	if not inventory then

		inventory = {}
		inventories[player] = inventory

	end

	return inventory

end


-- Send the player their current inventory, and let
-- any server-side listeners know too.
local function push(player)

	if not player or not player.Parent then
		return
	end

	local inventory = InventoryService.Get(player)

	inventoryUpdated:FireClient(player, inventory)

	changedEvent:Fire(player, inventory)

end


--==================================================
-- PERSISTENCE
--==================================================

-- Loads saved data into inventories[player]. If
-- something (a pickup, most likely) already ran and
-- populated an entry for this player before the load
-- finished -- GetAsync yields, so that's possible --
-- this MERGES rather than overwrites, so nothing
-- earned during that brief window gets lost.
--
-- IMPORTANT: this merge assumes anything already in
-- inventories[player] at this point is a genuine NEW
-- gain (like a pickup) that happened during the yield,
-- not a duplicate of what's about to load. Other
-- scripts must not write a full snapshot into this
-- player's inventory before this finishes -- that's
-- why WaitUntilLoaded exists below. Violating that is
-- what causes double-counted values.
local function loadInventory(player)

	local success, result = pcall(function()
		return inventoryStore:GetAsync(keyFor(player))
	end)

	local loaded =
		(success and type(result) == "table")
		and result
		or {}

	if not success then

		warn(
			"[InventoryService] Failed to load "
				.. "inventory for "
				.. player.Name
				.. ": "
				.. tostring(result)
		)

	end


	local current = inventories[player]

	if current then

		for itemType, count in pairs(loaded) do

			current[itemType] =
				(current[itemType] or 0) + count

		end

	else

		inventories[player] = loaded

	end

end


local function saveInventory(player)

	local inventory = inventories[player]

	if not inventory then
		return
	end

	local success, err = pcall(function()

		inventoryStore:SetAsync(
			keyFor(player),
			inventory
		)

	end)

	if not success then

		warn(
			"[InventoryService] Failed to save "
				.. "inventory for "
				.. player.Name
				.. ": "
				.. tostring(err)
		)

	end

end


--==================================================
-- PUBLIC API
--==================================================

-- Returns a COPY, so callers can't mutate the real
-- table by accident.
function InventoryService.Get(player)

	local inventory = getOrCreate(player)

	local copy = {}

	for lapisType, count in pairs(inventory) do
		copy[lapisType] = count
	end

	return copy

end


function InventoryService.GetCount(player, lapisType)

	return getOrCreate(player)[lapisType] or 0

end


function InventoryService.Add(player, lapisType, amount)

	if not player or not lapisType then
		return 0
	end

	amount = amount or 1

	local inventory = getOrCreate(player)

	inventory[lapisType] =
		(inventory[lapisType] or 0) + amount

	push(player)

	return inventory[lapisType]

end


-- Returns true only if the player actually had
-- enough. You'll want this for selling lapis and
-- for rebirth costs later.
function InventoryService.Remove(player, lapisType, amount)

	amount = amount or 1

	local inventory = getOrCreate(player)

	local current = inventory[lapisType] or 0

	if current < amount then
		return false
	end

	local remaining = current - amount

	-- Drop the key entirely at zero so the GUI
	-- doesn't render "golden lapis x0" rows.
	if remaining <= 0 then
		inventory[lapisType] = nil
	else
		inventory[lapisType] = remaining
	end

	push(player)

	return true

end


-- Overwrite instead of add/remove. Two forms:
--
--   InventoryService.Set(player, { golden_lapis = 5, normal_lapis = 2 })
--       Replaces the player's ENTIRE inventory with the given table.
--       Zero/negative/nil counts are dropped. Use this for admin
--       "give all" style commands or restoring a full saved snapshot.
--
--   InventoryService.Set(player, "golden_lapis", 5)
--       Sets a single item's count directly (0 or less removes it).
--       Use this for admin "give one item" style commands.
--
-- Either form fires the same Changed/InventoryUpdated signals as
-- Add/Remove, so anything listening (like PlayerStats sync + saving)
-- reacts the same way.
--
-- CAUTION: calling this before InventoryService.WaitUntilLoaded(player)
-- has returned for a freshly-joined player can cause the player's
-- next-session load to double-count -- see loadInventory's comment
-- above. Always wait for load first.
function InventoryService.Set(player, itemTypeOrTable, amount)

	if not player then
		return
	end

	if type(itemTypeOrTable) == "table" then

		local newInventory = {}

		for itemType, count in pairs(itemTypeOrTable) do
			if count and count > 0 then
				newInventory[itemType] = count
			end
		end

		inventories[player] = newInventory

	elseif type(itemTypeOrTable) == "string" then

		local inventory = getOrCreate(player)
		amount = amount or 0

		if amount <= 0 then
			inventory[itemTypeOrTable] = nil
		else
			inventory[itemTypeOrTable] = amount
		end

	else
		return
	end

	push(player)

end


-- Convenience alias so quest/gamepass/reward code
-- reads clearly at the call site, e.g.:
--   InventoryService.GiveLapis(player, "golden_lapis", 1)
InventoryService.GiveLapis = InventoryService.Add


function InventoryService.Clear(player)

	inventories[player] = {}

	push(player)

end


-- Blocks the calling thread (cooperatively -- this is
-- just a task.wait() loop, it doesn't freeze the
-- server) until this player's saved inventory has
-- finished loading from the DataStore.
--
-- Any OTHER script that runs on Players.PlayerAdded
-- and needs to read or write this player's inventory
-- (via Get/Add/Remove/Set) MUST call this first.
-- Otherwise it can run before loadInventory's GetAsync
-- call below has returned, and whatever it writes will
-- get merged (added) with the real saved data once the
-- load finishes -- silently doubling values. This is
-- what caused lapis counts to grow by the same amount
-- on every join.
--
-- Returns immediately (no wait) if the player has
-- already finished loading, or has left the game.
function InventoryService.WaitUntilLoaded(player)

	while player and player.Parent and not isLoaded[player] do
		task.wait()
	end

end


--==================================================
-- REMOTE HANDLERS
--==================================================

-- The client calls this once on spawn. Covers
-- respawns and the case where the client's
-- LocalScript loads after PlayerAdded already fired.
getInventory.OnServerInvoke = function(player)

	InventoryService.WaitUntilLoaded(player)
	return InventoryService.Get(player)

end


Players.PlayerAdded:Connect(function(player)

	loadInventory(player)
	isLoaded[player] = true
	push(player)

end)


Players.PlayerRemoving:Connect(function(player)

	saveInventory(player)
	inventories[player] = nil
	isLoaded[player] = nil

end)


--==================================================
-- AUTOSAVE
--
-- Backstop against crashes, hard disconnects, or
-- anything else that skips PlayerRemoving. Costs one
-- SetAsync per connected player every
-- AUTO_SAVE_INTERVAL seconds -- keep that interval
-- generous if you expect a lot of concurrent players.
--==================================================

task.spawn(function()

	while true do

		task.wait(PERSISTENCE.AUTO_SAVE_INTERVAL)

		for _, player in ipairs(Players:GetPlayers()) do
			saveInventory(player)
		end

	end

end)


--==================================================
-- SERVER SHUTDOWN
--
-- PlayerRemoving isn't guaranteed to fire (or finish)
-- during a shutdown, so this saves everyone still
-- connected explicitly. Note: BindToClose does not
-- reliably fire when you just stop a Studio Play
-- Solo session -- test actual saving via a published
-- game or the "Stop" button after a real save/load
-- round trip, not just closing the Studio window.
--==================================================

game:BindToClose(function()

	for _, player in ipairs(Players:GetPlayers()) do
		saveInventory(player)
	end

end)


return InventoryService