--==================================================
-- CRUELTY CHALLENGE LOBBY  (server)
--
-- The CHALLENGE prompt on Verity's portal opens a party
-- lobby, the same shape as the Final Boss one: invite
-- people in the server, they accept, the host hits START.
--
-- Differences from the Final Boss lobby:
--   * the arena is in THIS place, so there's no teleport --
--     the party drops into it through the portal
--   * there is only ONE Cruelty, so only one party can be
--     in the fight at a time; everyone else is told who
--     is currently down there
--   * nobody can deal or take damage until the intro is
--     over and the fight actually starts
--
-- The entry cinematic (fall -> dive -> plop -> get up) is
-- driven from here so the server owns the character
-- positions; the camera work is CrueltyEntryClient's.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local cutscene = workspace:WaitForChild("CrueltyCutscene")
local dummy = cutscene:WaitForChild("Cruelty")
local arenaSpawn = cutscene:WaitForChild("CharacterLocation")

local CONFIG = {
	MAX_PARTY = 6,
	COUNTDOWN = 3,
	INVITE_COOLDOWN = 2,
	DIVE_HEIGHT = 1100,  -- a proper skydive: through the clouds, down into the red
	DIVE_TIME = 11.5,   -- ~3.5s of calm drifting, then the plunge
	DIVE_ACROSS = 520,  -- the dive comes in at an angle, from this far out
	PLOP_TIME = 1.5,     -- how long you lie there before getting up
	GETUP_TIME = 1.9,
	SAFETY_UNLOCK = 45,  -- forcefields never outlive this, whatever happens
	PULL_TIME = 1.8,     -- dragged off your feet and into the portal
	TUNNEL_TIME = 1.25,  -- the wormhole, played on the client
	PORTAL_RISE = 10,    -- VerityRecite raises the portal this far on the client
	CHALLENGE_COOLDOWN = 60, -- after a fight, the whole party waits this long before going in again
}

local remote = ReplicatedStorage:FindFirstChild("CrueltyLobby")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "CrueltyLobby"
	remote.Parent = ReplicatedStorage
end

-- never boot up locked
workspace:SetAttribute("CrueltyFightLive", false)
workspace:SetAttribute("CrueltyChallenger", "")

local lobbies = {}    -- [hostUserId] = { Host, Members, Invited, Starting }
local memberOf = {}   -- [userId] = hostUserId
local lastInvite = {}
local activeHostId = nil  -- the one party currently in the arena
local activeParty = {}    -- userIds of the party currently down there
local cooldownUntil = {}  -- [userId] = os.clock() when they may challenge again

local function cooldownLeft(player)
	local t = cooldownUntil[player.UserId]
	if not t then return 0 end
	local left = math.ceil(t - os.clock())
	if left <= 0 then cooldownUntil[player.UserId] = nil return 0 end
	return left
end

--==================================================
-- ELIGIBILITY
--==================================================

-- You may only challenge Cruelty once you've recited Verity's words
-- (VerityQuest2). That's also what raises the portal in the first place.
local function hasRecited(player)
	local stats = player:FindFirstChild("PlayerStats")
	local claimed = stats and stats:FindFirstChild("ClaimedQuests")
	return claimed ~= nil and claimed:FindFirstChild("VerityQuest2") ~= nil
end

--==================================================
-- LOBBY PLUMBING
--==================================================

local function toast(player, text)
	remote:FireClient(player, "Toast", text)
end

local function snapshot(lobby)
	local members = {}
	for _, p in ipairs(lobby.Members) do
		table.insert(members, { UserId = p.UserId, Name = p.Name, DisplayName = p.DisplayName })
	end
	local invited = {}
	for userId in pairs(lobby.Invited) do table.insert(invited, userId) end
	local busyName = nil
	if activeHostId and activeHostId ~= lobby.Host.UserId then
		local host = Players:GetPlayerByUserId(activeHostId)
		busyName = host and host.DisplayName or "another party"
	end
	return {
		HostId = lobby.Host.UserId,
		HostName = lobby.Host.DisplayName,
		Members = members,
		Invited = invited,
		Max = CONFIG.MAX_PARTY,
		Starting = lobby.Starting,
		ArenaBusy = busyName,
	}
end

local function broadcast(lobby)
	local state = snapshot(lobby)
	for _, p in ipairs(lobby.Members) do
		remote:FireClient(p, "State", state)
	end
end

local function broadcastAll()
	for _, lobby in pairs(lobbies) do broadcast(lobby) end
end

local function removeMember(lobby, player)
	for i, p in ipairs(lobby.Members) do
		if p == player then table.remove(lobby.Members, i) break end
	end
	memberOf[player.UserId] = nil
end

local function closeLobby(hostUserId, reason)
	local lobby = lobbies[hostUserId]
	if not lobby then return end
	lobbies[hostUserId] = nil
	for _, p in ipairs(lobby.Members) do
		memberOf[p.UserId] = nil
		remote:FireClient(p, "Closed", reason)
	end
	for userId in pairs(lobby.Invited) do
		local p = Players:GetPlayerByUserId(userId)
		if p then remote:FireClient(p, "InviteRevoked", hostUserId) end
	end
end

local function leaveCurrent(player, reason)
	local hostId = memberOf[player.UserId]
	if not hostId then return end
	if hostId == player.UserId then
		closeLobby(hostId, reason or "The host closed the lobby.")
	else
		local lobby = lobbies[hostId]
		if lobby then
			removeMember(lobby, player)
			remote:FireClient(player, "Closed", reason or "You left the party.")
			broadcast(lobby)
		end
	end
end

--==================================================
-- THE PROMPT ON THE PORTAL
--==================================================

local function openFor(player)
	if not hasRecited(player) then
		toast(player, "Recite Verity's words first -- he won't open the way for you otherwise.")
		return
	end
	local left = cooldownLeft(player)
	if left > 0 then
		toast(player, ("The portal is still recovering. Try again in %ds."):format(left))
		return
	end

	local current = memberOf[player.UserId]
	if current and current ~= player.UserId then
		-- already in someone else's party: just show it
		local lobby = lobbies[current]
		if lobby then
			remote:FireClient(player, "Open")
			broadcast(lobby)
			return
		end
		memberOf[player.UserId] = nil
	end

	local lobby = lobbies[player.UserId]
	if not lobby then
		lobby = { Host = player, Members = { player }, Invited = {}, Starting = false }
		lobbies[player.UserId] = lobby
		memberOf[player.UserId] = player.UserId
	end
	remote:FireClient(player, "Open")
	broadcast(lobby)
end

task.spawn(function()
	local quest = workspace:WaitForChild("VerityQuest", 30)
	local portal = quest and quest:WaitForChild("CrueltyPortal", 30)
	if not portal then
		warn("[CrueltyLobby] CrueltyPortal missing -- nobody can challenge Cruelty")
		return
	end
	local prompt = portal:WaitForChild("ChallengePrompt", 30)
		or portal:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		warn("[CrueltyLobby] no ProximityPrompt on the portal")
		return
	end
	prompt.Triggered:Connect(openFor)
end)

--==================================================
-- THE ENTRY CINEMATIC
--
-- Portal -> long fall -> head-first dive -> hit the floor
-- and flop -> push yourself back up. The fall is driven
-- from the server with PivotTo on an anchored character so
-- it can't be desynced or skipped; the camera and the wind
-- are the client's job.
--==================================================

local RED = Color3.fromRGB(255, 60, 50)
local EMBER = Color3.fromRGB(255, 150, 40)

local function arenaCFrame()
	local bossRoot = dummy:FindFirstChild("HumanoidRootPart")
	local from = arenaSpawn.Position
	local to = bossRoot and bossRoot.Position or (from + arenaSpawn.CFrame.LookVector * 10)
	return CFrame.lookAt(from, Vector3.new(to.X, from.Y, to.Z))
end

local function shield(character, on)
	local existing = character:FindFirstChild("CrueltyIntroShield")
	if on then
		if existing then return end
		-- Humanoid:TakeDamage respects a ForceField, so an invisible one is
		-- the cleanest "nobody can hurt you yet" there is.
		local ff = Instance.new("ForceField")
		ff.Name = "CrueltyIntroShield"
		ff.Visible = false
		ff.Parent = character
	elseif existing then
		existing:Destroy()
	end
end

local function impactBurst(position)
	local holder = Instance.new("Folder")
	holder.Name = "DiveImpact"
	holder.Parent = workspace

	for i = 1, 2 do
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = (i == 1) and EMBER or RED
		ring.Size = Vector3.new(0.5, 4, 4)
		ring.CFrame = CFrame.new(position + Vector3.new(0, 0.8 + i * 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = holder
		TweenService:Create(ring, TweenInfo.new(0.6 + i * 0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.5, 34 + i * 16, 34 + i * 16),
			Transparency = 1,
		}):Play()
	end

	local burst = Instance.new("Part")
	burst.Anchored, burst.CanCollide, burst.CanQuery, burst.CanTouch = true, false, false, false
	burst.Transparency = 1
	burst.Size = Vector3.one
	burst.CFrame = CFrame.new(position)
	burst.Parent = holder

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(80, 50, 45), Color3.fromRGB(25, 12, 12))
	dust.Size = NumberSequence.new(5, 17)
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1, 1.7)
	dust.Speed = NumberRange.new(22, 44)
	dust.SpreadAngle = Vector2.new(78, 78)
	dust.Rate = 0
	dust.Drag = 3
	dust.Parent = burst
	dust:Emit(26)

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(EMBER, RED)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(1.1, 0)
	sparks.Lifetime = NumberRange.new(0.5, 1)
	sparks.Speed = NumberRange.new(40, 80)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 0
	sparks.Drag = 2
	sparks.Parent = burst
	sparks:Emit(34)

	Debris:AddItem(holder, 3.5)
end

local function portalCFrame()
	local quest = workspace:FindFirstChild("VerityQuest")
	local portal = quest and quest:FindFirstChild("CrueltyPortal")
	if not portal then return nil end
	return portal.CFrame * CFrame.new(0, CONFIG.PORTAL_RISE, 0)
end

-- Lifted off your feet and dragged into the portal: slow at first, then a
-- sudden whoosh, turning as you go. The client plays the vortex and camera.
local function pullIntoPortal(player, char, root)
	local portal = portalCFrame()
	if not portal then return end
	remote:FireClient(player, "Portal", portal, CONFIG.PULL_TIME, CONFIG.TUNNEL_TIME)
	root.Anchored = true
	local from = char:GetPivot()
	local rot = from - from.Position
	local elapsed = 0
	while elapsed < CONFIG.PULL_TIME do
		elapsed += task.wait()
		local a = math.min(elapsed / CONFIG.PULL_TIME, 1)
		-- hang in the air for a beat, then get yanked in
		local e = (a < 0.45) and (a / 0.45) * 0.08 or (0.08 + 0.92 * ((a - 0.45) / 0.55) ^ 2.4)
		local lift = math.sin(math.min(a / 0.45, 1) * math.pi / 2) * 3.5 * (1 - e)
		local pos = from.Position:Lerp(portal.Position, e) + Vector3.new(0, lift, 0)
		local spin = a * a * 16
		char:PivotTo(CFrame.new(pos) * rot * CFrame.Angles(0, spin, 0) * CFrame.Angles(-e * 1.2, 0, 0))
	end
end

-- One member's fall. Runs in its own thread; returns when they're upright.
local function diveIn(player, slot, total, partyIds, diveAngle)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and humanoid and root) or humanoid.Health <= 0 then return end

	shield(char, true)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	pullIntoPortal(player, char, root)

	-- spread the party out in a ring so nobody lands on anybody
	local angle = (slot - 1) / math.max(total, 1) * math.pi * 2
	local spread = (total > 1) and 7 or 0
	local landing = arenaCFrame() * CFrame.new(math.cos(angle) * spread, 0, math.sin(angle) * spread)
	-- stand ON the floor, not in it: find the ground under this spot and put
	-- the root at the height the Humanoid wants (legs were sinking into the arena)
	do
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = { arenaSpawn, dummy }
		for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ignore, p.Character) end end
		rp.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(landing.Position + Vector3.new(0, 30, 0), Vector3.new(0, -120, 0), rp)
		if hit then
			local standY = hit.Position.Y + humanoid.HipHeight + root.Size.Y * 0.5 + 0.35
			landing = landing - landing.Position + Vector3.new(landing.Position.X, standY, landing.Position.Z)
		end
	end
	-- everyone starts together, side by side, far out and high up
	local across = Vector3.new(math.cos(diveAngle or 0), 0, math.sin(diveAngle or 0))
	local sideways = across:Cross(Vector3.yAxis)
	local start = CFrame.new(landing.Position + across * CONFIG.DIVE_ACROSS + sideways * ((slot - (total + 1) / 2) * 9) + Vector3.new(0, CONFIG.DIVE_HEIGHT, 0))

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	char:PivotTo(start)
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	-- parked in the sky while the client flies through the wormhole
	task.wait(CONFIG.TUNNEL_TIME)

	remote:FireClient(player, "Dive", CONFIG.DIVE_TIME, landing.Position, partyIds, start.Position)

	-- the yaw the character should be facing when it lands
	local lv = landing.LookVector
	local landYaw = math.atan2(-lv.X, -lv.Z)

	-- THE SKYDIVE, on a curve: a few seconds of calm, belly-down drifting
	-- with the rest of the party, then it tips into a head-first plunge
	-- that steepens all the way down to the arena.
	local P0 = start.Position
	local P2 = landing.Position
	local P1 = P2 + across * CONFIG.DIVE_ACROSS * 0.12 + Vector3.new(0, CONFIG.DIVE_HEIGHT * 0.5, 0)
	local function bez(u)
		local v = 1 - u
		return P0 * (v * v) + P1 * (2 * v * u) + P2 * (u * u)
	end
	local CALM = 0.3
	local function progress(a)
		if a < CALM then return 0.05 * (a / CALM) end
		return 0.05 + 0.95 * ((a - CALM) / (1 - CALM)) ^ 1.7
	end
	local elapsed = 0
	local seed = slot * 1.7
	while elapsed < CONFIG.DIVE_TIME do
		elapsed += task.wait()
		local a = math.min(elapsed / CONFIG.DIVE_TIME, 1)
		local u = progress(a)
		local pos = bez(u)
		local calmBob = (a < CALM + 0.1) and Vector3.new(0, math.sin(elapsed * 1.6 + seed) * 1.2, 0) or Vector3.zero
		pos += calmBob
		local tangent = bez(math.min(u + 0.01, 1)) - bez(math.max(u - 0.01, 0))
		if tangent.Magnitude < 0.01 then tangent = P2 - P0 end
		tangent = tangent.Unit

		-- calm pose: flat, belly to the ground, drifting round slowly
		local calmCF = CFrame.new(pos) * CFrame.Angles(0, landYaw + math.sin(elapsed * 0.4 + seed) * 0.6, 0) * CFrame.Angles(math.rad(-88), 0, math.sin(elapsed * 0.9 + seed) * 0.12)
		-- dive pose: head leading along the curve, chest to the ground
		local right = tangent:Cross(Vector3.yAxis)
		right = right.Magnitude > 0.01 and right.Unit or Vector3.xAxis
		local diveCF = CFrame.fromMatrix(pos, right, tangent) * CFrame.Angles(0, math.sin(elapsed * 2 + seed) * 0.15, 0)

		local cf
		if a < CALM then
			cf = calmCF
		elseif a < CALM + 0.12 then
			local k = (a - CALM) / 0.12
			cf = calmCF:Lerp(diveCF, k * k * (3 - 2 * k))
		elseif a < 0.9 then
			cf = diveCF
		else
			-- swing the feet under you for the landing
			local k = (a - 0.9) / 0.1
			k = k * k * (3 - 2 * k)
			cf = diveCF:Lerp(CFrame.new(pos) * CFrame.Angles(0, landYaw, 0), k)
		end
		char:PivotTo(cf)
	end

	-- IMPACT
	char:PivotTo(landing)
	root.Anchored = false
	root.AssemblyLinearVelocity = Vector3.zero
	impactBurst(landing.Position)
	remote:FireClient(player, "DiveLanded")

	-- flop. FallingDown is the engine's own "sprawled on the floor" state,
	-- so this gets the stock animation and physics for free.
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	task.wait(CONFIG.PLOP_TIME)

	-- push yourself back up
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	task.wait(CONFIG.GETUP_TIME)
	-- if the flop physics wedged them into the floor, lift them back out
	if root.Parent and root.Position.Y < landing.Position.Y - 0.6 then
		char:PivotTo(landing)
		root.AssemblyLinearVelocity = Vector3.zero
	end

	humanoid.AutoRotate = true
end

--==================================================
-- STARTING A FIGHT
--==================================================

local function releaseParty(members)
	for _, p in ipairs(members) do
		local char = p.Character
		if char then shield(char, false) end
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed
			humanoid.JumpPower = 50
			humanoid.AutoRotate = true
		end
	end
end

local function endFight()
	-- the whole party that just went down waits a minute before the next go
	local untilT = os.clock() + CONFIG.CHALLENGE_COOLDOWN
	for userId in pairs(activeParty) do cooldownUntil[userId] = untilT end
	table.clear(activeParty)
	activeHostId = nil
	workspace:SetAttribute("CrueltyFightLive", false)
	workspace:SetAttribute("CrueltyChallenger", "")
	broadcastAll()
end

local function start(lobby)
	if lobby.Starting then return end
	if activeHostId then
		local host = Players:GetPlayerByUserId(activeHostId)
		toast(lobby.Host, (host and host.DisplayName or "Another party") .. " is inside the portal right now. Wait your turn.")
		return
	end
	if dummy:GetAttribute("FightActive") then
		toast(lobby.Host, "Someone is already inside the portal. Wait your turn.")
		return
	end
	for _, p in ipairs(lobby.Members) do
		local left = cooldownLeft(p)
		if left > 0 then
			toast(lobby.Host, ("%s just came back through the portal -- the party can go in again in %ds."):format(p.DisplayName, left))
			return
		end
	end

	lobby.Starting = true
	activeHostId = lobby.Host.UserId
	workspace:SetAttribute("CrueltyChallenger", lobby.Host.DisplayName)
	workspace:SetAttribute("CrueltyFightLive", false)
	broadcastAll()

	for i = CONFIG.COUNTDOWN, 1, -1 do
		for _, p in ipairs(lobby.Members) do
			remote:FireClient(p, "Countdown", i)
		end
		task.wait(1)
		if lobbies[lobby.Host.UserId] ~= lobby then
			endFight()
			return
		end
	end

	local party = {}
	for _, p in ipairs(lobby.Members) do
		if p.Parent == Players and p.Character then table.insert(party, p) end
	end
	if #party == 0 then
		lobby.Starting = false
		endFight()
		return
	end

	for _, p in ipairs(party) do
		remote:FireClient(p, "Closed", nil)
		activeParty[p.UserId] = true
	end

	-- everybody falls at once
	local done = 0
	local partyIds = {}
	for _, p in ipairs(party) do table.insert(partyIds, p.UserId) end
	local diveAngle = math.random() * math.pi * 2
	for i, p in ipairs(party) do
		task.spawn(function()
			local ok, err = pcall(diveIn, p, i, #party, partyIds, diveAngle)
			if not ok then warn("[CrueltyLobby] dive failed: " .. tostring(err)) end
			done += 1
		end)
	end

	-- wait for the landings (with a hard cap so a disconnect can't hang it)
	local waited = 0
	while done < #party and waited < 30 do
		waited += task.wait(0.1)
	end

	-- now Cruelty makes his entrance; CrueltyFightService takes it from here.
	-- PartySize is read there to scale his health to the group.
	dummy:SetAttribute("PartySize", #party)
	dummy:SetAttribute("FightActive", true)

	lobby.Starting = false

	-- Fight goes live once the boss has landed and said his piece.
	-- CrueltyFightService flips CrueltyFightLive; this is the backstop that
	-- makes sure nobody is left invincible if anything above went wrong.
	task.spawn(function()
		local t = 0
		while t < CONFIG.SAFETY_UNLOCK do
			t += task.wait(0.2)
			if workspace:GetAttribute("CrueltyFightLive") then break end
			if not dummy:GetAttribute("FightActive") then break end
		end
		workspace:SetAttribute("CrueltyFightLive", true)
		releaseParty(party)
	end)
end

-- when the fight ends for any reason, the arena frees up again
dummy:GetAttributeChangedSignal("FightActive"):Connect(function()
	if not dummy:GetAttribute("FightActive") then
		endFight()
	end
end)

--==================================================
-- CLIENT REQUESTS
--==================================================

remote.OnServerEvent:Connect(function(player, action, arg)
	local myHost = memberOf[player.UserId]
	local isHost = myHost == player.UserId
	local lobby = myHost and lobbies[myHost]

	if action == "Invite" then
		if not (isHost and lobby) or lobby.Starting then return end
		if type(arg) ~= "number" then return end
		local target = Players:GetPlayerByUserId(arg)
		if not target or target == player then return end
		if not hasRecited(target) then
			toast(player, target.DisplayName .. " hasn't recited Verity's words yet.")
			return
		end
		if memberOf[target.UserId] == player.UserId then return end
		if #lobby.Members >= CONFIG.MAX_PARTY then
			toast(player, "Party is full.")
			return
		end
		local key = player.UserId .. ":" .. target.UserId
		if lastInvite[key] and os.clock() - lastInvite[key] < CONFIG.INVITE_COOLDOWN then return end
		lastInvite[key] = os.clock()
		lobby.Invited[target.UserId] = true
		remote:FireClient(target, "Invite", player.UserId, player.DisplayName)
		broadcast(lobby)

	elseif action == "Accept" then
		if type(arg) ~= "number" then return end
		local target = lobbies[arg]
		if not (target and target.Invited[player.UserId]) then
			toast(player, "That invite has expired.")
			return
		end
		if target.Starting then return end
		if not hasRecited(player) then
			toast(player, "Recite Verity's words before you go down there.")
			return
		end
		local left = cooldownLeft(player)
		if left > 0 then
			toast(player, ("You just came back through the portal. You can go in again in %ds."):format(left))
			return
		end
		if #target.Members >= CONFIG.MAX_PARTY then
			toast(player, "That party is full.")
			return
		end
		if myHost then leaveCurrent(player) end
		target.Invited[player.UserId] = nil
		table.insert(target.Members, player)
		memberOf[player.UserId] = arg
		remote:FireClient(player, "Open")
		broadcast(target)

	elseif action == "Decline" then
		if type(arg) ~= "number" then return end
		local target = lobbies[arg]
		if target and target.Invited[player.UserId] then
			target.Invited[player.UserId] = nil
			toast(target.Host, player.DisplayName .. " declined.")
			broadcast(target)
		end

	elseif action == "Kick" then
		if not (isHost and lobby) or lobby.Starting then return end
		local target = type(arg) == "number" and Players:GetPlayerByUserId(arg)
		if target and target ~= player and memberOf[target.UserId] == player.UserId then
			removeMember(lobby, target)
			remote:FireClient(target, "Closed", "You were removed from the party.")
			broadcast(lobby)
		end

	elseif action == "Leave" then
		if lobby and lobby.Starting then return end
		leaveCurrent(player)

	elseif action == "Start" then
		if isHost and lobby then task.spawn(start, lobby) end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	leaveCurrent(player, "The host left the server.")
	for _, lobby in pairs(lobbies) do
		if lobby.Invited[player.UserId] then
			lobby.Invited[player.UserId] = nil
			broadcast(lobby)
		end
	end
	if activeHostId == player.UserId then
		-- the host bailed mid-fight; let the AI's own "nobody left" sweep
		-- close it out, but free the lobby lock immediately
		activeHostId = nil
		broadcastAll()
	end
end)

print("[CrueltyLobby] ready")
