--==================================================
-- TELEPORT SERVICE
--
-- Place in: ServerScriptService > GameScripts
-- Type:     Script (server)
--
-- Backs the teleport GUI (Screen > master > teleport).
--
-- THE GATE IS HERE, NOT ON THE CLIENT.
-- TeleportClient greys out locked buttons, but that is
-- cosmetic only -- a client can fire the remote with
-- any island name it likes. This script re-reads the
-- player's rebirth count from leaderstats on every
-- request and is the only thing that actually decides.
--
-- Requirements come from AscensionData.Islands so the
-- GUI, the rebirth panel and this gate can never
-- disagree about a number.
--
-- Destinations come from Workspace > TeleportPoints,
-- one anchored invisible Part per island. Drag those
-- around in Studio to retune landing spots -- no code
-- change needed.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- AscensionDataModule is optional. When it is missing the server used
-- to yield here forever, which silently killed every teleport. Fall back
-- to the same numbers TeleportClient hardcodes.
local FALLBACK_ISLANDS = {
	["67 Island"]      = 1,
	["Verity Island"]  = 5,
	["LaPeace Island"] = 15,
}

local AscensionData
do
	local modules = ReplicatedStorage:FindFirstChild("AccessibleModules")
	local moduleScript = modules and modules:FindFirstChild("AscensionDataModule")

	if moduleScript and moduleScript:IsA("ModuleScript") then
		local ok, result = pcall(require, moduleScript)
		if ok and typeof(result) == "table" and typeof(result.Islands) == "table" then
			AscensionData = result
		end
	end

	if not AscensionData then
		warn("[TeleportService] AscensionDataModule missing -- using hardcoded island requirements")
		AscensionData = { Islands = FALLBACK_ISLANDS }
	end
end


--==================================================
-- CONFIGURATION
--==================================================

local CONFIG = {

	POINTS_FOLDER = "TeleportPoints",

	-- Seconds between accepted teleports, per player.
	-- Stops a held-down button firing every frame.
	COOLDOWN = 1.5,

	-- Random horizontal offset, so a group teleporting
	-- together doesn't all land inside each other.
	SCATTER = 8,

	-- HOME goes to the player's claimed plot when they
	-- have one. Set false to always use the Home marker.
	-- (the button is SHOP/SELL now: it always goes to the shop & sell stands)
	HOME_PREFERS_PLOT = false,

}


--==================================================
-- DESTINATIONS
--
-- Keyed by the GUI frame name (Container > home, 67,
-- verity, lapeace). Island is the key into
-- AscensionData.Islands; nil means always unlocked.
--==================================================

local DESTINATIONS = {

	["home"]    = { Point = "Home",           Island = nil },
	["base"]    = { Point = "Home",           Island = nil, Plot = true }, -- (your own plot)
	["67"]      = { Point = "67 Island",      Island = "67 Island" },
	["verity"]  = { Point = "Verity Island",  Island = "Verity Island" },
	["lapeace"] = { Point = "LaPeace Island", Island = "LaPeace Island" },

}


--==================================================
-- REMOTE
--
-- Lives next to ShopEvent in AccessibleEvents so all
-- the game's remotes sit in one place.
--
-- Client -> server: fire with the frame name.
-- Server -> client: fire back (ok, message) purely so
-- the GUI can show why a teleport was refused.
--==================================================

local events = ReplicatedStorage:WaitForChild("AccessibleEvents")

local remote = events:FindFirstChild("TeleportRequest")

if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "TeleportRequest"
	remote.Parent = events
end


--==================================================
-- REBIRTH COUNT
--
-- LeaderboardStats creates this as "Ascensions". The
-- other two names are checked because AscensionService
-- accepts them as aliases -- keeping the same fallback
-- order here means a rename can't silently make every
-- island free.
--==================================================

--==================================================
-- GAMEPASS ISLAND ACCESS
--
-- Optional require: a place file without
-- MonetizationData still gates purely on rebirths.
--==================================================

local Monetization do
	local modules = ReplicatedStorage:FindFirstChild("AccessibleModules")
	local moduleScript = modules and modules:FindFirstChild("MonetizationData")
	if moduleScript then
		local ok, result = pcall(require, moduleScript)
		if ok and type(result) == "table" then
			Monetization = result
		end
	end
end


local function getRebirths(player)

	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		return 0
	end

	local stat =
		leaderstats:FindFirstChild("Ascensions")
		or leaderstats:FindFirstChild("Rebirths")
		or leaderstats:FindFirstChild("Ascension")

	return stat and stat.Value or 0

end


--==================================================
-- MARKER LOOKUP
--==================================================

local function getPoint(pointName)

	local folder =
		Workspace:FindFirstChild(CONFIG.POINTS_FOLDER)

	if not folder then
		return nil
	end

	local part = folder:FindFirstChild(pointName)

	if part and part:IsA("BasePart") then
		return part
	end

	return nil

end


--==================================================
-- PLOT LOOKUP (for HOME)
--
-- Raycasts down from above the plot rather than using
-- the hitbox centre directly -- the hitbox is a tall
-- trigger volume, so its centre can sit well above the
-- actual floor.
--==================================================

local plotRayParams = RaycastParams.new()
plotRayParams.FilterType = Enum.RaycastFilterType.Exclude
plotRayParams.IgnoreWater = true


local function getOwnedPlotCFrame(player)

	local islands = Workspace:FindFirstChild("Islands")
	local starter = islands and islands:FindFirstChild("StarterIsland")
	local plots = starter and starter:FindFirstChild("IslandPlots")

	if not plots then
		return nil
	end

	for _, plot in ipairs(plots:GetChildren()) do

		local owner = plot:FindFirstChild("Owner")

		if owner
			and owner:IsA("StringValue")
			and owner.Value == player.Name then

			local hitbox = plot:FindFirstChild("Hitbox")

			if hitbox and hitbox:IsA("BasePart") then

				local ignore = { plots }

				if player.Character then
					table.insert(ignore, player.Character)
				end

				plotRayParams.FilterDescendantsInstances = ignore

				local origin =
					hitbox.Position + Vector3.new(0, 60, 0)

				local result =
					Workspace:Raycast(
						origin,
						Vector3.new(0, -300, 0),
						plotRayParams
					)

				local landing =
					result
					and (result.Position + Vector3.new(0, 3, 0))
					or (hitbox.Position + Vector3.new(0, 5, 0))

				return CFrame.new(landing)

			end

		end

	end

	return nil

end


--==================================================
-- TELEPORT
--
-- Velocity is zeroed after the move. Without this a
-- player who was mid-fall keeps their downward speed
-- and punches straight through the island they just
-- arrived on.
--==================================================

local function moveCharacter(player, destinationCFrame)

	local character = player.Character

	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local scatter = CONFIG.SCATTER

	local offset =
		Vector3.new(
			(math.random() * 2 - 1) * scatter,
			0,
			(math.random() * 2 - 1) * scatter
		)

	character:PivotTo(destinationCFrame + offset)

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	return true

end


--==================================================
-- REQUEST HANDLER
--==================================================

local lastTeleport = {}


local function onRequest(player, destinationKey)

	-- Remotes are player input. Anything can arrive here.
	if typeof(destinationKey) ~= "string" then
		return
	end

	local destination = DESTINATIONS[destinationKey]

	if not destination then
		return
	end


	local now = os.clock()
	local previous = lastTeleport[player]

	if previous and (now - previous) < CONFIG.COOLDOWN then
		return
	end


	--==================================================
	-- THE GATE
	--==================================================

	if destination.Island then

		local required =
			AscensionData.Islands[destination.Island] or 0

		local owned = getRebirths(player)

		-- Unlock All Islands opens every gate; the Verity and
		-- La Peace bundles open their own island only. Checked
		-- here rather than by zeroing `required` above so the
		-- refusal message still reports the real requirement to
		-- players who don't own a pass.
		local passAccess =
			Monetization ~= nil
			and Monetization.HasIslandAccess(player, destination.Island)

		if owned < required and not passAccess then

			remote:FireClient(
				player,
				false,
				string.format(
					"%s needs %d rebirth%s. You have %d.",
					destination.Island,
					required,
					required == 1 and "" or "s",
					owned
				)
			)

			return

		end

	end


	--==================================================
	-- RESOLVE THE LANDING SPOT
	--==================================================

	local targetCFrame = nil

	if destinationKey == "home" and CONFIG.HOME_PREFERS_PLOT then
		targetCFrame = getOwnedPlotCFrame(player)
	end
	if destination.Plot then
		targetCFrame = getOwnedPlotCFrame(player)
		if not targetCFrame then
			remote:FireClient(player, false, "You don't have a base yet - claim a plot first!")
			return
		end
	end

	if not targetCFrame then

		local point = getPoint(destination.Point)

		if not point then

			warn(
				"[TeleportService] No Part named '"
					.. destination.Point
					.. "' inside Workspace."
					.. CONFIG.POINTS_FOLDER
					.. " -- nowhere to send "
					.. player.Name
			)

			remote:FireClient(
				player,
				false,
				"That destination isn't set up yet."
			)

			return

		end

		targetCFrame = point.CFrame

	end


	if not moveCharacter(player, targetCFrame) then
		return
	end

	lastTeleport[player] = now

	remote:FireClient(player, true, destination.Point)

end


remote.OnServerEvent:Connect(onRequest)


Players.PlayerRemoving:Connect(function(player)
	lastTeleport[player] = nil
end)
