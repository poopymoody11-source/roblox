--==================================================
-- CRUELTY FIGHT DIRECTOR  (server)
--
-- Everything about the fight that isn't the boss's AI:
--
--   * ENTRANCE -- Cruelty drops out of the sky and SMASHES
--     into the arena floor (shockwave, crater ring, camera
--     shake) before the fight starts
--   * DIALOGUE -- taunts at the start, at phase 2 and on
--     defeat, shown by the client's boss UI
--   * PHASE 2 banner + music change
--   * DEFEATED prompt, the Cruelty Slayer title, and the
--     "YOU DIED -- RETRY" prompt for players who go down
--
-- CrueltyAIScript still owns the boss's attacks. This script
-- only talks to it through the FightActive attribute and the
-- clone it spawns.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local cutscene = workspace:WaitForChild("CrueltyCutscene")
local dummy = cutscene:WaitForChild("Cruelty")
local arenaSpawn = cutscene:WaitForChild("CharacterLocation")

local fx = ReplicatedStorage:WaitForChild("CrueltyFightFX")
local retryRemote = ReplicatedStorage:WaitForChild("CrueltyRetry")

-- quick-time-event answers from the clients during his final attack
local qteRemote = ReplicatedStorage:FindFirstChild("CrueltyQTE")
if not qteRemote then
	qteRemote = Instance.new("RemoteEvent")
	qteRemote.Name = "CrueltyQTE"
	qteRemote.Parent = ReplicatedStorage
end

-- Everyone who has died in the CURRENT fight. They never get the title,
-- even if the rest of the party goes on to win.
local fallenThisFight = {}

-- Health scaling: a solo player fights BASE_HEALTH; every extra party member
-- adds EXTRA_PER_PLAYER of that on top (capped at MAX_SCALED_PLAYERS).
local BASE_HEALTH = 200
local EXTRA_PER_PLAYER = 0.5
local MAX_SCALED_PLAYERS = 8

local RED = Color3.fromRGB(255, 60, 50)
local EMBER = Color3.fromRGB(255, 150, 40)

-- Verity is a HE. Every line that refers to him says so.
local LINES = {
	Intro = {
		"Another one falls out of the sky. How many is that now?",
		"Verity keeps sending them down here to die. He never comes himself.",
		"Get up. I want you standing when I bury you.",
	},
	PhaseTwo = {
		"ENOUGH.",
		"You want to see death? LOOK AT ME.",
	},
	-- said mid-fight, every so often
	Taunt = {
		"Everything down here dies. You're just late.",
		"I can hear your heart. It's slowing down.",
		"Every step you take is one step closer to your grave.",
		"Do you know what it feels like to die? You will.",
		"They all fight at first. Then they rot.",
		"I've buried better than you in this floor.",
		"Your name will be the next one I forget.",
		"Death isn't the end. It's just me, waiting.",
		"Breathe while you still can.",
		"Scream. It helps. It doesn't.",
	},
	TauntRage = {
		"I AM what's waiting at the end.",
		"THERE IS NO LIGHT DOWN HERE.",
		"You'll die screaming his name.",
		"I will wear your death like a crown.",
		"FALL. DOWN. AND. STAY. DEAD.",
	},
	Kill = {
		"Dead. Like the rest of them.",
		"Stay down. Forever.",
		"Another grave. Another name forgotten.",
		"Is that the best he could find?",
		"Death was always coming. I just brought it early.",
	},
	Final = {
		"Enough games.",
		"I am the end of everything.",
		"EVERYTHING. DIES. NOW.",
	},
	FinalWin = {
		"...what...?!",
	},
	FinalLose = {
		"Told you. Everything dies.",
	},
	Defeat = {
		"...no... death doesn't... die...",
		"Verity... he finally found one...",
	},
}

-- The client types dialogue out a character at a time (BossHealthVisual.say),
-- so this is how long a set of lines takes to deliver.
local function speakDuration(lines)
	local total = 0
	for _, line in ipairs(lines) do
		total += #line * 0.022 + 1.5
	end
	return total
end

local function broadcast(...)
	fx:FireAllClients(...)
end

-- NO PVP IN CRUELTY'S ARENA: everyone in it is flagged, and the bat / staff
-- damage code (SwingScript, StaffFlingService) leaves flagged players alone.
-- Their PvP is also switched OFF for real while they're in there (the PVP
-- button shows it), nothing can turn it back on, and whatever it was before
-- comes back when they leave. (PvpLock leaves flagged players alone.)
local function enterArena(p)
	p:SetAttribute("PvpBeforeArena", p:GetAttribute("PvpEnabled") == true)
	p:SetAttribute("InCrueltyArena", true)
	p:SetAttribute("PvpEnabled", false)
end
local function leaveArena(p)
	p:SetAttribute("InCrueltyArena", nil)
	p:SetAttribute("PvpEnabled", p:GetAttribute("PvpBeforeArena") == true or p:GetAttribute("PvpLocked") == true)
	p:SetAttribute("PvpBeforeArena", nil)
end
local function hookArenaPvp(p)
	p:GetAttributeChangedSignal("PvpEnabled"):Connect(function()
		if p:GetAttribute("InCrueltyArena") and p:GetAttribute("PvpEnabled") == true then
			task.defer(function()
				if p:GetAttribute("InCrueltyArena") then p:SetAttribute("PvpEnabled", false) end
			end)
		end
	end)
end
Players.PlayerAdded:Connect(hookArenaPvp)
for _, p in ipairs(Players:GetPlayers()) do hookArenaPvp(p) end
task.spawn(function()
	while true do
		task.wait(0.5)
		local centre = arenaSpawn and arenaSpawn.Parent and arenaSpawn.Position
		for _, p in ipairs(Players:GetPlayers()) do
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local inside = centre ~= nil and r ~= nil and (r.Position - centre).Magnitude <= 600
			if (p:GetAttribute("InCrueltyArena") == true) ~= inside then
				if inside then enterArena(p) else leaveArena(p) end
			end
		end
	end
end)

local function nearbyPlayers(position, radius)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude <= radius then
			table.insert(list, player)
		end
	end
	return list
end

--==================================================
-- ENTRANCE: the smash
--==================================================

local function smashInto(clone)
	local root = clone:FindFirstChild("HumanoidRootPart")
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end

	local landing = clone:GetAttribute("LandRootCF") or root.CFrame
	-- strip any tilt: only keep which way he faces
	local lx, ly, lz = landing:ToOrientation()
	landing = CFrame.new(landing.Position) * CFrame.fromOrientation(0, ly, 0)
	local ground = landing.Position
	-- the model's pivot isn't the root, so place him BY the root
	local rootToPivot = root.CFrame:ToObjectSpace(clone:GetPivot())
	local function placeRoot(cf) clone:PivotTo(cf * rootToPivot) end

	-- freeze the boss while it falls
	humanoid.WalkSpeed = 0
	clone:SetAttribute("Entering", true)
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end

	broadcast("Entrance", ground)

	-- fall from high above, spinning
	local start = landing + Vector3.new(0, 260, 0)
	placeRoot(start)
	-- a beat of empty sky first, so the camera is already looking up when
	-- he appears
	task.wait(0.7)
	local elapsed, FALL = 0, 1.05
	while elapsed < FALL do
		elapsed += task.wait()
		local a = math.min(elapsed / FALL, 1)
		placeRoot(start:Lerp(landing, a * a) * CFrame.Angles(0, a * 8, 0))
	end
	placeRoot(landing)

	-- impact: shockwave ring, dust, crater glow
	local holder = Instance.new("Folder")
	holder.Name = "CrueltyImpact"
	holder.Parent = workspace

	for i = 1, 3 do
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = (i % 2 == 0) and EMBER or RED
		ring.Size = Vector3.new(0.6, 6, 6)
		ring.CFrame = CFrame.new(ground + Vector3.new(0, 1 + i * 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = holder
		TweenService:Create(ring, TweenInfo.new(0.7 + i * 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.6, 90 + i * 35, 90 + i * 35),
			Transparency = 1,
		}):Play()
	end

	local burst = Instance.new("Part")
	burst.Anchored, burst.CanCollide, burst.CanQuery, burst.CanTouch = true, false, false, false
	burst.Transparency = 1
	burst.Size = Vector3.one
	burst.CFrame = CFrame.new(ground)
	burst.Parent = holder
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(70, 40, 35), Color3.fromRGB(20, 10, 10))
	dust.Size = NumberSequence.new(8, 26)
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.2, 2)
	dust.Speed = NumberRange.new(30, 60)
	dust.SpreadAngle = Vector2.new(75, 75)
	dust.Rate = 0
	dust.Drag = 3
	dust.Parent = burst
	dust:Emit(45)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(EMBER, RED)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(1.6, 0)
	sparks.Lifetime = NumberRange.new(0.7, 1.4)
	sparks.Speed = NumberRange.new(60, 120)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 0
	sparks.Drag = 2
	sparks.Parent = burst
	sparks:Emit(70)
	local light = Instance.new("PointLight")
	light.Color = EMBER
	light.Range = 70
	light.Brightness = 6
	light.Shadows = false
	light.Parent = burst
	TweenService:Create(light, TweenInfo.new(1.2), { Brightness = 0 }):Play()

	Debris:AddItem(holder, 4)
	broadcast("Smash", ground)

	-- knock everyone nearby off their feet
	for _, player in ipairs(nearbyPlayers(ground, 90)) do
		local char = player.Character
		local proot = char and char:FindFirstChild("HumanoidRootPart")
		local phum = char and char:FindFirstChildOfClass("Humanoid")
		if proot and phum and phum.Health > 0 then
			local away = (proot.Position - ground)
			away = Vector3.new(away.X, 0, away.Z)
			if away.Magnitude < 1 then away = Vector3.new(1, 0, 0) end
			proot.AssemblyLinearVelocity = away.Unit * 45 + Vector3.new(0, 45, 0)
			phum:TakeDamage(5)
		end
	end

	task.wait(0.9)
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = false end
	end
	if root then root.Anchored = false end
	-- The server simulates him. Left to the default, physics ownership hops to
	-- whichever player is nearest, and each hop replicated that client's view
	-- of his state -- one of the ways the health bar flickered between players.
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then pcall(function() d:SetNetworkOwner(nil) end) end
	end
	clone:SetAttribute("Entering", nil)
	humanoid.WalkSpeed = 20
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	-- a proper forward hunch from the waist (not a sideways tilt), head
	-- tipped back up so he's still staring at you
	local waist = clone:FindFirstChild("Waist", true)
	local neck = clone:FindFirstChild("Neck", true)
	if waist and waist:IsA("Motor6D") then
		local c0 = waist.C0
		waist:SetAttribute("BaseC0", c0)
		TweenService:Create(waist, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { C0 = c0 * CFrame.Angles(math.rad(-32), 0, 0) }):Play()
	end
	if neck and neck:IsA("Motor6D") then
		local c0 = neck.C0
		TweenService:Create(neck, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { C0 = c0 * CFrame.Angles(math.rad(22), 0, 0) }):Play()
	end
end

--==================================================
-- FIGHT LIFECYCLE
--==================================================

local function awardTitle(player)
	-- the flag the Verity quest and the Cruelty Slayer title both read
	local okQ, QDS = pcall(function() return require(game:GetService("ServerScriptService"):WaitForChild("GameScripts"):WaitForChild("QuestDataService")) end)
	if okQ and QDS and QDS.SetDefeatedCruelty then pcall(QDS.SetDefeatedCruelty, player) end
	local stats = player:FindFirstChild("PlayerStats")
	if stats then
		local tag = stats:FindFirstChild("defeatedCruelty")
		if not tag then
			tag = Instance.new("BoolValue")
			tag.Name = "defeatedCruelty"
			tag.Parent = stats
		end
		tag.Value = true
	end
	if type(_G.GrantTitle) == "function" then
		pcall(_G.GrantTitle, player, "cruelty_slayer")
	end
end

local watching = nil

local function watchClone(clone)
	if watching == clone then return end
	watching = clone

	local humanoid = clone:WaitForChild("Humanoid", 10)
	local root = clone:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then return end

	-- more fighters, more health
	local partySize = dummy:GetAttribute("PartySize")
	if type(partySize) ~= "number" or partySize < 1 then
		partySize = math.max(#nearbyPlayers(arenaSpawn.Position, 600), 1)
	end
	partySize = math.clamp(partySize, 1, MAX_SCALED_PLAYERS)
	local scaled = math.floor(BASE_HEALTH * (1 + EXTRA_PER_PLAYER * (partySize - 1)))
	humanoid.MaxHealth = scaled
	humanoid.Health = scaled
	clone:SetAttribute("PartySize", partySize)
	broadcast("Health", scaled, scaled)

	task.spawn(function()
		smashInto(clone)
		broadcast("Start", LINES.Intro)

		-- Nobody can hurt anybody until he's finished talking. The lobby
		-- shields the party; this is the boss's half of the truce.
		task.wait(speakDuration(LINES.Intro))
		if not dummy:GetAttribute("FightActive") then return end
		workspace:SetAttribute("CrueltyFightLive", true)
		broadcast("FightGo")
	end)

	local phaseTwo = false
	local shiftLock = nil -- health is frozen here while the phase-two cinematic plays

	-- THE TRANSFORMATION. Time stops: he rises off the floor, the arena
	-- darkens, the aura tears out of him, and he slams back down. Nobody
	-- takes or deals damage while it plays; the clients do the spectacle.
	local SHIFT_TIME = 6.2
	local function phaseShift()
		shiftLock = humanoid.Health
		clone:SetAttribute("Entering", true)
		clone:SetAttribute("PhaseTwo", true)
		humanoid.WalkSpeed = 0
		root.Anchored = true
		local shields = {}
		for _, player in ipairs(nearbyPlayers(root.Position, 500)) do
			local char = player.Character
			if char then
				local ff = Instance.new("ForceField")
				ff.Name = "CrueltyShiftShield"
				ff.Visible = false
				ff.Parent = char
				table.insert(shields, ff)
			end
		end
		broadcast("PhaseTwo", LINES.PhaseTwo, SHIFT_TIME)

		local base = root.CFrame
		local flat = CFrame.new(base.Position) * (base - base.Position)
		-- rise and turn slowly, trembling
		local elapsed = 0
		while elapsed < 4.3 and clone.Parent do
			elapsed += task.wait()
			local a = math.min(elapsed / 3.2, 1)
			local lift = (1 - (1 - a) ^ 3) * 9
			local tremble = (elapsed > 1.2) and (math.random() - 0.5) * 0.35 * math.min((elapsed - 1.2) / 2, 1) or 0
			root.CFrame = flat * CFrame.new(tremble, lift, tremble) * CFrame.Angles(0, math.sin(elapsed * 0.9) * 0.25, 0)
		end
		-- slam back down
		local top = root.CFrame
		local slamT = 0
		while slamT < 0.22 and clone.Parent do
			slamT += task.wait()
			local a = math.min(slamT / 0.22, 1)
			root.CFrame = top:Lerp(flat, a * a)
		end
		root.CFrame = flat
		broadcast("PhaseSlam", flat.Position)
		-- from here on he burns: a blood-red outline everyone can see, black
		-- smoke pouring up off him and embers whipping round his body
		local hl = Instance.new("Highlight")
		hl.Name = "RageOutline"
		hl.FillColor = Color3.fromRGB(110, 0, 12)
		hl.FillTransparency = 0.72
		hl.OutlineColor = RED
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = clone
		local att = Instance.new("Attachment")
		att.Name = "RageAura"
		att.Parent = root
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(60, 0, 6), Color3.fromRGB(5, 0, 0))
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 12) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		smoke.Lifetime = NumberRange.new(1.2, 2)
		smoke.Speed = NumberRange.new(6, 12)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.SpreadAngle = Vector2.new(25, 25)
		smoke.Rate = 18
		smoke.Parent = att
		local embers = Instance.new("ParticleEmitter")
		embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 120, 90), RED)
		embers.LightEmission = 1
		embers.Size = NumberSequence.new(0.9, 0)
		embers.Lifetime = NumberRange.new(0.8, 1.4)
		embers.Speed = NumberRange.new(8, 16)
		embers.SpreadAngle = Vector2.new(180, 180)
		embers.RotSpeed = NumberRange.new(-200, 200)
		embers.Acceleration = Vector3.new(0, 10, 0)
		embers.Rate = 40
		embers.Parent = att
		local glow = Instance.new("PointLight")
		glow.Color = RED
		glow.Range = 30
		glow.Brightness = 3
		glow.Shadows = false
		glow.Parent = root
		for _, player in ipairs(nearbyPlayers(flat.Position, 70)) do
			local char = player.Character
			local proot = char and char:FindFirstChild("HumanoidRootPart")
			if proot then
				local away = (proot.Position - flat.Position) * Vector3.new(1, 0, 1)
				if away.Magnitude < 1 then away = Vector3.new(1, 0, 0) end
				proot.AssemblyLinearVelocity = away.Unit * 70 + Vector3.new(0, 55, 0)
			end
		end
		task.wait(SHIFT_TIME - 4.3 - 0.22)
		for _, ff in ipairs(shields) do ff:Destroy() end
		if clone.Parent then
			root.Anchored = false
			pcall(function() root:SetNetworkOwner(nil) end)
			clone:SetAttribute("Entering", nil)
			humanoid.WalkSpeed = 20
		end
		shiftLock = nil
		broadcast("Health", humanoid.Health, humanoid.MaxHealth)
	end

	--==================================================
	-- FINAL ATTACK: at 20% he goes up into the air and drops a sphere of
	-- death on the arena. Every player gets their OWN five quick-time
	-- prompts (server-generated, answers checked here against the shared
	-- server clock). Miss two or more and it kills you. Anyone who holds
	-- on throws it back into him.
	--==================================================
	local finalDone = false
	-- 8 rings per player, one every 0.62s; each is judged against the moment
	-- its approach ring closes (hit time). Up to 2 misses and you live.
	-- hard: 12 rings, fast, tight timing, one mistake allowed
	-- (nerfed: fewer notes, more time between them, a wider window, a longer lead, one more miss allowed)
	local QTE_COUNT, QTE_GAP, QTE_WINDOW, QTE_GRACE, QTE_LEAD = 8, 0.72, 0.26, 0.3, 1.0
	-- a ring can stay up this much longer if a lag spike brought it in late
	-- (phones); keep in step with LAG_GRACE in CrueltyFightClient
	local LAG_GRACE = 0.5
	local MAX_MISSES = 2
	local qteState = nil
	local qteConn = qteRemote.OnServerEvent:Connect(function(player, index, symbol)
		if not qteState then return end
		local st = qteState.players[player.UserId]
		if not st or type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > QTE_COUNT then return end
		if st.answered[index] ~= nil then return end
		local now = workspace:GetServerTimeNow()
		local hitAt = qteState.start + (index - 1) * QTE_GAP
		-- the client judges the timing (a key pressed too early sends 0); taps on
		-- the circle count from the moment it shows up. Late side allows for
		-- ping and lag spikes.
		local ok = symbol == st.seq[index] and now >= hitAt - QTE_LEAD - 0.3 and now <= hitAt + QTE_WINDOW + QTE_GRACE + LAG_GRACE
		st.answered[index] = ok
		if ok then st.hits += 1 else st.misses += 1 end
		fx:FireClient(player, "QTEResult", index, ok)
	end)
	clone.Destroying:Connect(function() qteConn:Disconnect() end)

	local function finalAttack()
		finalDone = true
		while shiftLock do task.wait(0.1) end
		if not clone.Parent or humanoid.Health <= 0 then return end
		shiftLock = humanoid.Health
		clone:SetAttribute("Entering", true)
		humanoid.WalkSpeed = 0
		root.Anchored = true

		local participants, shields = {}, {}
		for _, player in ipairs(nearbyPlayers(root.Position, 500)) do
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not fallenThisFight[player.UserId] then
				table.insert(participants, player)
				local ff = Instance.new("ForceField")
				ff.Name = "CrueltyFinalShield"
				ff.Visible = false
				ff.Parent = char
				shields[player] = ff
				hum.WalkSpeed = 0
				hum.JumpPower = 0
			end
		end

		local INTRO = 6.5
		local start = workspace:GetServerTimeNow() + INTRO
		local resolveAt = start + (QTE_COUNT - 1) * QTE_GAP + QTE_WINDOW + QTE_GRACE + LAG_GRACE + 0.15
		qteState = { start = start, players = {} }
		local ids = {}
		for _, player in ipairs(participants) do
			local seq, spots = {}, {}
			for i = 1, QTE_COUNT do
				local sym
				repeat sym = math.random(1, 4) until i == 1 or sym ~= seq[i - 1]
				seq[i] = sym
				-- where the ring shows up on screen (0..1), never too close to the last one
				local x, y
				repeat
					x, y = 0.18 + math.random() * 0.64, 0.2 + math.random() * 0.52
				until i == 1 or (Vector2.new(x, y) - spots[i - 1]).Magnitude > 0.22
				spots[i] = Vector2.new(x, y)
			end
			qteState.players[player.UserId] = { seq = seq, answered = {}, hits = 0, misses = 0 }
			table.insert(ids, player.UserId)
			local spotList = {}
			for i, v in ipairs(spots) do spotList[i] = { v.X, v.Y } end
			fx:FireClient(player, "FinalQTE", { seq = seq, spots = spotList, start = start, gap = QTE_GAP, window = QTE_WINDOW, lead = QTE_LEAD, count = QTE_COUNT, maxMisses = MAX_MISSES })
		end
		broadcast("FinalAttack", LINES.Final, { start = start, resolveAt = resolveAt, count = QTE_COUNT, gap = QTE_GAP, participants = ids })

		-- he rises into the air, shaking, while the sphere gathers
		local base = root.CFrame
		local flat = CFrame.new(base.Position) * (base - base.Position)
		local riseT = 0
		while workspace:GetServerTimeNow() < resolveAt and clone.Parent do
			riseT += task.wait()
			local a = math.min(riseT / 3, 1)
			local shakeAmt = (riseT > 1.5) and 0.25 or 0
			root.CFrame = flat * CFrame.new((math.random() - 0.5) * shakeAmt, (1 - (1 - a) ^ 3) * 26, (math.random() - 0.5) * shakeAmt) * CFrame.Angles(0, math.sin(riseT * 0.7) * 0.2, 0)
		end
		if not clone.Parent then return end

		-- verdict per player; unanswered rings are misses
		local survivors, fallen = {}, {}
		for _, player in ipairs(participants) do
			local st = qteState.players[player.UserId]
			local misses = st.misses
			for i = 1, QTE_COUNT do if st.answered[i] == nil then misses += 1 end end
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if player.Parent and hum and hum.Health > 0 and misses <= MAX_MISSES then
				table.insert(survivors, player.UserId)
			else
				table.insert(fallen, player.UserId)
				-- no title for anyone the sphere takes, even if their party wins
				fallenThisFight[player.UserId] = true
			end
		end
		qteState = nil
		broadcast("FinalResolve", survivors, fallen, (#survivors > 0) and LINES.FinalWin or LINES.FinalLose)

		task.wait(0.55)
		for _, player in ipairs(participants) do
			if shields[player] then shields[player]:Destroy() end
			if table.find(fallen, player.UserId) then
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum then hum.Health = 0 end
			end
		end

		if #survivors > 0 then
			-- thrown back into him. He comes apart.
			task.wait(1.4)
			for _, player in ipairs(participants) do
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then hum.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed hum.JumpPower = 50 end
			end
			shiftLock = nil
			clone:SetAttribute("Entering", nil)
			root.Anchored = false
			-- the killing blow: Died awards the title to the living, unfallen only
			humanoid.Health = 0
			return
		end

		-- nobody held on: the dead are gone, he settles back down
		root.CFrame = flat
		if clone.Parent then
			root.Anchored = false
			pcall(function() root:SetNetworkOwner(nil) end)
			clone:SetAttribute("Entering", nil)
			humanoid.WalkSpeed = 20
		end
		shiftLock = nil
		broadcast("FinalEnd")
	end

	humanoid.HealthChanged:Connect(function(health)
		-- Invulnerable during the entrance and the intro: anything that got
		-- through (a stray projectile, an eager bat swing) is simply undone.
		if workspace:GetAttribute("CrueltyFightLive") ~= true then
			if health < humanoid.MaxHealth then
				humanoid.Health = humanoid.MaxHealth
			end
			broadcast("Health", humanoid.MaxHealth, humanoid.MaxHealth)
			return
		end
		if shiftLock then
			if health < shiftLock and health > 0 then humanoid.Health = shiftLock end
			return
		end
		broadcast("Health", health, humanoid.MaxHealth)
		if not phaseTwo and health > 0 and health <= humanoid.MaxHealth * 0.5 then
			phaseTwo = true
			task.spawn(phaseShift)
		elseif phaseTwo and not finalDone and health > 0 and health <= humanoid.MaxHealth * 0.2 then
			finalDone = true
			task.spawn(finalAttack)
		end
	end)

	-- he never shuts up about death
	task.spawn(function()
		local lastLine
		while clone.Parent and humanoid.Health > 0 and dummy:GetAttribute("FightActive") do
			task.wait(math.random(9, 14))
			if not clone.Parent or humanoid.Health <= 0 then break end
			if workspace:GetAttribute("CrueltyFightLive") == true and not shiftLock then
				local pool = phaseTwo and LINES.TauntRage or LINES.Taunt
				local line
				repeat line = pool[math.random(#pool)] until line ~= lastLine or #pool < 2
				lastLine = line
				broadcast("Taunt", line, phaseTwo)
			end
		end
	end)

	humanoid.Died:Connect(function()
		workspace:SetAttribute("CrueltyFightLive", false)
		-- Only the ones still standing when he falls. Anybody who died at any
		-- point in this fight gets nothing, even if their party finished it.
		local winnerIds = {}
		for _, player in ipairs(nearbyPlayers(root.Position, 400)) do
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not fallenThisFight[player.UserId] then
				awardTitle(player)
				table.insert(winnerIds, player.UserId)
			end
		end
		broadcast("Defeated", LINES.Defeat, winnerIds)
		watching = nil
	end)
end

dummy:GetAttributeChangedSignal("FightActive"):Connect(function()
	if not dummy:GetAttribute("FightActive") then
		watching = nil
		workspace:SetAttribute("CrueltyFightLive", false)
		broadcast("End")
		return
	end
	workspace:SetAttribute("CrueltyFightLive", false)
	table.clear(fallenThisFight)
	-- CrueltyAIScript spawns the clone on this same signal
	task.spawn(function()
		for _ = 1, 40 do
			for _, child in ipairs(dummy.Parent:GetChildren()) do
				if child ~= dummy and child:GetAttribute("IsClone") and child:FindFirstChildOfClass("Humanoid") then
					watchClone(child)
					return
				end
			end
			task.wait(0.1)
		end
	end)
end)

--==================================================
-- DEATH -> BACK TO THE LOBBY
-- No retries. Die down there and the client plays the
-- YOU FAILED sequence over the respawn, and you come back
-- up at Verity's portal instead of the island spawn.
--==================================================

local pendingReturn = {}

local function lobbyCFrame()
	local victory = cutscene:FindFirstChild("VictoryPart")
	if victory then
		return victory.CFrame * CFrame.new(math.random(-4, 4), 3, math.random(-4, 4))
	end
	return nil
end

local function watchDeaths(player)
	local function hook(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then return end

		if pendingReturn[player] then
			pendingReturn[player] = nil
			local root = character:WaitForChild("HumanoidRootPart", 10)
			local cf = lobbyCFrame()
			if root and cf then
				task.wait(0.1)
				character:PivotTo(cf)
				root.AssemblyLinearVelocity = Vector3.zero
			end
			fx:FireClient(player, "Returned")
		end

		humanoid.Died:Connect(function()
			if not dummy:GetAttribute("FightActive") then return end
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then return end
			if (root.Position - arenaSpawn.Position).Magnitude > 600 then return end
			pendingReturn[player] = true
			fallenThisFight[player.UserId] = true
			fx:FireClient(player, "YouDied", LINES.Kill[math.random(#LINES.Kill)])
		end)
	end
	if player.Character then task.spawn(hook, player.Character) end
	player.CharacterAdded:Connect(hook)
end

Players.PlayerRemoving:Connect(function(player) pendingReturn[player] = nil end)

Players.PlayerAdded:Connect(watchDeaths)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(watchDeaths, p) end

-- Retrying was removed on purpose: a death sends you back to the lobby.
-- The remote stays so an old client firing it doesn't error, but it does
-- nothing.
retryRemote.OnServerEvent:Connect(function() end)

print("[CrueltyFight] director ready")
