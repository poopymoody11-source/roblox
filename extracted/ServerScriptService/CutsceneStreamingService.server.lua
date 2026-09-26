--==================================================
-- CUTSCENE STREAMING SERVICE  (SERVER)
--
-- This place has StreamingEnabled, which loads the map
-- around each player's REPLICATION FOCUS. By default
-- that focus is their character -- so during a cutscene,
-- where the character stands frozen at spawn and the
-- camera flies up to 2,700 studs away, the client never
-- receives the clouds, the Earth, the black hole or the
-- VFX rigs standing beside the characters. They render
-- as empty space.
--
-- RequestStreamAroundAsync from the client isn't enough
-- on its own: it pulls a region in, but the engine
-- streams it straight back out again because the focus
-- is still hundreds of studs away. Watching it happen,
-- the clouds appeared and vanished twice in one run.
--
-- Player.ReplicationFocus is the actual fix, and it can
-- only be set from the server. The client tells us where
-- its cutscene camera is; we point the focus at a marker
-- part there, and the map loads around the shot instead
-- of around the body.
--
-- Place as a Script in ServerScriptService.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- A client that never sends "stop" (crash, disconnect mid-scene,
-- someone poking the remote) must not keep a focus pinned forever.
-- (the final cutscene runs ~3 minutes: at 90 the focus was yanked back to the
-- far-away body right at the portal, and the game paused to stream it in)
local MAX_FOCUS_TIME = 420

-- Ignore updates closer together than this. The client sends on a
-- timer, and there's no value in moving the focus every frame.
local MIN_UPDATE_INTERVAL = 0.15

local remote = ReplicatedStorage:FindFirstChild("CutsceneFocus")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "CutsceneFocus"
	remote.Parent = ReplicatedStorage
end

local markers = {}    -- [player] = Part
local started = {}    -- [player] = os.clock() when focus was taken
local lastUpdate = {} -- [player] = os.clock()

local function releaseFocus(player)
	if not markers[player] then return end

	-- Hand the focus back to the character before destroying the
	-- marker; leaving it pointed at a destroyed part would stop the
	-- player streaming anything at all.
	pcall(function()
		player.ReplicationFocus = nil
	end)

	markers[player]:Destroy()
	markers[player] = nil
	started[player] = nil
	lastUpdate[player] = nil
end

local function takeFocus(player, position)
	local marker = markers[player]

	if not marker then
		marker = Instance.new("Part")
		marker.Name = "CutsceneFocus_" .. player.Name
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Transparency = 1
		marker.Size = Vector3.new(1, 1, 1)
		marker.Parent = workspace

		markers[player] = marker
		started[player] = os.clock()
	end

	marker.CFrame = CFrame.new(position)

	pcall(function()
		player.ReplicationFocus = marker
	end)
end

remote.OnServerEvent:Connect(function(player, action, position)
	if action == "stop" then
		releaseFocus(player)
		return
	end

	if action ~= "focus" then return end
	if typeof(position) ~= "Vector3" then return end

	-- Remotes are player input; a NaN or infinite position here would
	-- put the streaming system into a bad state.
	if position.Magnitude ~= position.Magnitude then return end
	if position.Magnitude == math.huge then return end

	local now = os.clock()
	if lastUpdate[player] and (now - lastUpdate[player]) < MIN_UPDATE_INTERVAL then
		return
	end
	lastUpdate[player] = now

	if started[player] and (now - started[player]) > MAX_FOCUS_TIME then
		releaseFocus(player)
		return
	end

	takeFocus(player, position)
end)

Players.PlayerRemoving:Connect(releaseFocus)

-- Safety net for a client that stops sending without saying stop.
task.spawn(function()
	while true do
		task.wait(5)
		local now = os.clock()
		for player, last in pairs(lastUpdate) do
			if now - last > 10 then
				releaseFocus(player)
			end
		end
	end
end)
