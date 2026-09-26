--==================================================
-- BOSS FIGHT: SERVER CORE
-- The Anti-Spiral's state (health, phase, where he's walking),
-- the remotes, and every hit: attacks schedule hits with an
-- impact time and a shape; at impact the server checks who is
-- inside, waits a moment for parry claims, then resolves each
-- one as a hit or a parry (a completed QTE: he takes the
-- damage instead).
--
-- Attack modules (./Attacks) get this module and use:
--   F.now(), F.waitUntil(t), F.cancelled(token)
--   F.targets()                 -> { { Player, Root, Humanoid } } on the arena
--   F.rootAt(t)                 -> his root CFrame at t (from the walk plan)
--   F.fx(kind, data)            -> every client runs the matching visual
--   F.hit(hit)                  -> schedule a timed hit (circle / line shapes)
--   F.continuousHit(hit, until) -> a travelling hit (rings, sweeps: checked every frame)
--   F.qte.single/chord(...)     -> QTE specs for a hit (hit.Qte; default: one click)
--   F.newId(prefix), F.rng
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local S = require(ReplicatedStorage:WaitForChild("AntiSpiralFight"):WaitForChild("Shared"))
local Config = require(script.Parent:WaitForChild("Config"))

local F = {}
F.S = S
F.Config = Config
F.rng = Random.new()

--------------------------------------------------------------------------
-- remotes
--------------------------------------------------------------------------
local shared = ReplicatedStorage:WaitForChild("AntiSpiralFight")
local net = shared:FindFirstChild(S.NET) or Instance.new("Folder")
net.Name = S.NET
net.Parent = shared
local function remote(name)
	local r = net:FindFirstChild(name) or Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = net
	return r
end
F.FxRemote = remote("Fx")        -- server -> clients: attack visuals, hits, results
F.QteRemote = remote("Qte")      -- client -> server: "I completed this hit's QTE" (id, time, grade)
F.ActionRemote = remote("Action") -- client -> server: "roll", "punch"

function F.fx(kind, data)
	F.FxRemote:FireAllClients(kind, data)
end

--------------------------------------------------------------------------
-- clock
--------------------------------------------------------------------------
function F.now() return S.now() end

function F.waitUntil(t)
	while S.now() < t do
		task.wait(math.min(t - S.now(), 0.05))
	end
end

local idSeq = 0
function F.newId(prefix)
	idSeq += 1
	return (prefix or "H") .. idSeq
end

--------------------------------------------------------------------------
-- the boss
--------------------------------------------------------------------------
local model, humanoid, root
F.Token = 0 -- bumped on phase change / death: running attacks bail out
F.Dazed = false
F.SetPiecesUsed = {}
F.Forced = {} -- set pieces waiting to go next
F.Alive = true
F.PhaseIndex = 0

function F.cancelled(token)
	return not F.Alive or F.Token ~= token
end

function F.phase() return Config.Phases[F.PhaseIndex] or Config.Phases[1] end

local plan
local function setPlan(p)
	plan = p
	model:SetAttribute("Motion", S.encodePlan(p))
	shared:SetAttribute("BossMotion", model:GetAttribute("Motion"))
end

function F.rootAt(t)
	return (S.rootAt(plan, t or S.now()))
end

-- his chest (drills are thrown at it), from where it sits on his root in Studio
local chestOffset = CFrame.new(0, 80, 0)
function F.chestAt(t)
	return (F.rootAt(t) * chestOffset).Position
end

function F.angleAt(t)
	local u = plan.T1 > plan.T0 and math.clamp(((t or S.now()) - plan.T0) / (plan.T1 - plan.T0), 0, 1) or 1
	return plan.A0 + (plan.A1 - plan.A0) * S.ease(u)
end

-- walk `degrees` round the ring (sign = direction); returns when he's there
function F.walk(degrees)
	local a0 = F.angleAt()
	local a1 = a0 + math.rad(degrees)
	local arc = math.abs(a1 - a0) * S.WALK_R
	-- (eased: the average speed of an ease-in-out is 2/pi of its peak)
	local dur = math.max(arc / Config.WalkSpeed * (math.pi / 2), 1.5)
	local t0 = S.now() + 0.15
	setPlan({ T0 = t0, T1 = t0 + dur, A0 = a0, A1 = a1, F0 = 0, F1 = 0, FM = 0.8, Y = plan.Y })
	F.waitUntil(t0 + dur)
end

-- stand where he is (square to the arena)
local function hold()
	local a = F.angleAt()
	local t = S.now()
	setPlan({ T0 = t, T1 = t, A0 = a, A1 = a, F0 = 0, F1 = 0, FM = 0, Y = plan.Y })
end

-- his state, copied onto the shared folder (every client always has that;
-- the model itself may not have streamed in to them)
local function publish()
	for _, k in ipairs({ "DisplayName", "Phase", "Invulnerable", "Defeated", "Motion" }) do
		shared:SetAttribute("Boss" .. k, model:GetAttribute(k))
	end
	shared:SetAttribute("BossHealth", humanoid.Health)
	shared:SetAttribute("BossMaxHealth", humanoid.MaxHealth)
end

function F.maxHealth() return humanoid.MaxHealth end

function F.setInvulnerable(on)
	model:SetAttribute("Invulnerable", on)
end

--------------------------------------------------------------------------
-- targets
--------------------------------------------------------------------------
function F.targets()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if hum and r and hum.Health > 0 and S.onArena(r.Position, -20) then
			table.insert(list, { Player = p, Root = r, Humanoid = hum })
		end
	end
	return list
end

local function feetHeight(t)
	local hum = t.Humanoid
	local feet = t.Root.Position.Y - hum.HipHeight - t.Root.Size.Y / 2
	return feet - S.CENTER.Y
end

--------------------------------------------------------------------------
-- damage to him
--------------------------------------------------------------------------
local transitioning = false

local function setPhase(index)
	transitioning = true
	F.Token += 1
	F.PhaseIndex = index
	model:SetAttribute("Phase", index)
	local ph = Config.Phases[index]
	if index > 1 then
		F.setInvulnerable(true)
		hold()
		F.fx("Phase", { Index = index, T0 = S.now(), Dur = ph.TransitionTime or 3 })
		task.wait(ph.TransitionTime or 3)
		-- (back to normal: only hurt while dazed)
		if F.Alive then F.setInvulnerable(not F.Dazed) end
	end
	transitioning = false
end

local function onDeath()
	if not F.Alive then return end
	F.Alive = false
	F.Token += 1
	hold()
	model:SetAttribute("Defeated", true)
	F.fx("Defeated", { T0 = S.now() })
	workspace:SetAttribute("FC_BossDefeated", true)
end

-- returns true if it landed
-- (a QTE counter lands whether he's dazed or not; everything else only while he's open)
function F.damageBoss(amount, player, source)
	if not F.Alive or transitioning then return false end
	local counter = source == "parry" or source == "ultimate"
	if model:GetAttribute("Invulnerable") and not counter then return false end
	humanoid.Health = math.max(humanoid.Health - amount, 0)
	F.fx("BossHurt", { Amount = amount, Source = source, User = player and player.UserId or 0 })
	if humanoid.Health <= 0 then
		onDeath()
		return true
	end
	-- (set pieces - his ultimate, the galaxy corruption - come out as he crosses their thresholds)
	local pct = humanoid.Health / humanoid.MaxHealth
	for i, fp in ipairs(Config.SetPieces or {}) do
		if pct <= fp.At and not F.SetPiecesUsed[i] then
			F.SetPiecesUsed[i] = true
			table.insert(F.Forced, fp)
		end
	end
	if not transitioning then
		for i = #Config.Phases, 1, -1 do
			if i > F.PhaseIndex and pct <= Config.Phases[i].StartsAtHealthPct then
				task.spawn(setPhase, i)
				break
			end
		end
	end
	return true
end

--------------------------------------------------------------------------
-- hits and QTEs
-- Every hit carries a QTE spec that the clients turn into prompts:
--   { Kind = "single" | "chord" | "ultimate",
--     Steps = { { At = seconds relative to impact, Keys = { "CLICK", "Q", ... } }, ... },
--     Early = s, Late = s,  -- the window round each step
--     Perfect = s }         -- |error| within this is perfect
-- Keys: CLICK, SPACE, Q, E, F. A chord's keys all have to go down inside the
-- window. A client that completes every step claims the hit; if the claim's
-- time is in the window, it's a parry and he takes the counter damage.
--------------------------------------------------------------------------
local live = {}   -- [id] = hit (while it can still be parried)
local claims = {} -- [player] = { [id] = { T = client server-time, Grade = "good" | "perfect" } }
local SLACK = 0.14

local QTE = {}
F.qte = QTE
function QTE.single(key)
	return { Kind = "single", Steps = { { At = 0, Keys = { key or "CLICK" } } }, Early = S.PARRY_EARLY, Late = S.PARRY_LATE, Perfect = S.PERFECT }
end
function QTE.chord(keys)
	return { Kind = "chord", Steps = { { At = 0, Keys = keys } }, Early = 0.34, Late = 0.1, Perfect = 0.1 }
end
-- a random chord of n keys (always with CLICK)
local POOL = { "Q", "E", "F", "SPACE" }
function QTE.randomChord(n)
	local keys = { "CLICK" }
	local pool = table.clone(POOL)
	for _ = 2, n do
		table.insert(keys, table.remove(pool, F.rng:NextInteger(1, #pool)))
	end
	return QTE.chord(keys)
end
function QTE.ultimate(steps)
	return { Kind = "ultimate", Steps = steps, Early = 0.24, Late = 0.18, Perfect = 0.08 }
end
-- keys one after another, `gap` apart, the last on the impact
function QTE.sequence(keys, gap, kind)
	local steps = {}
	for i, k in ipairs(keys) do
		table.insert(steps, { At = -(#keys - i) * (gap or 0.45), Keys = { k } })
	end
	return { Kind = kind or "sequence", Steps = steps, Early = 0.3, Late = 0.18, Perfect = 0.09 }
end

function F.isLive(id) return live[id] ~= nil end

F.QteRemote.OnServerEvent:Connect(function(player, id, clientT, grade)
	if type(id) ~= "string" or type(clientT) ~= "number" or not live[id] then return end
	if math.abs(clientT - S.now()) > 1.5 then return end
	claims[player] = claims[player] or {}
	if not claims[player][id] then
		claims[player][id] = { T = clientT, Grade = grade == "perfect" and "perfect" or "good" }
	end
end)

local function resolve(hit, t, T)
	local player = t.Player
	local mine = claims[player] and claims[player][hit.Id]
	local q = hit.Qte
	local result
	if q and mine and mine.T >= T - q.Early - SLACK and mine.T <= T + q.Late + SLACK then
		local perfect = mine.Grade == "perfect"
		result = perfect and "perfect" or "parry"
		local base = hit.Counter or Config.ParryDamage
		local dmg = perfect and (hit.CounterPerfect or base * 1.6) or base
		if q.Kind == "ultimate" then
			-- (the counter lands at the end of their cinematic)
			task.delay(Config.UltimateCounterDelay or 3.2, function() F.damageBoss(dmg, player, "ultimate") end)
		else
			F.damageBoss(dmg, player, "parry")
		end
	elseif (player:GetAttribute("IFrameUntil") or 0) >= T - 0.05 then
		result = "evade"
	else
		result = "hit"
		local mult = F.phase().DamageMultiplier or 1
		t.Humanoid:TakeDamage((hit.Damage or 20) * mult)
		if hit.Knock and t.Root.Parent then
			local away = S.flat(t.Root.Position - S.shapeCentre(hit.Shape, T))
			away = away.Magnitude > 0.1 and away.Unit or Vector3.xAxis
			t.Root.AssemblyLinearVelocity = away * hit.Knock + Vector3.new(0, hit.Knock * 0.5, 0)
		end
	end
	F.fx("Resolve", { Id = hit.Id, User = player.UserId, Result = result, Pos = t.Root.Position, Kind = q and q.Kind or "none",
		Knock = hit.Knock or 0, From = S.shapeCentre(hit.Shape, T) })
end

-- every hit is announced (its QTE, shape and timing) so each client can prompt it
-- (QTEs are only for the big wind-ups: a hit has one only if its attack gives it one.
-- Big = true marks those: they get the lock-on; everything else just gets the red icon)
local function announce(hit)
	if hit.Qte == false then hit.Qte = nil end
	F.fx("Hit", { Id = hit.Id, T = hit.T, Shape = hit.Shape, Name = hit.Name, Target = hit.Target, Qte = hit.Qte, Big = hit.Big })
end

-- a timed hit: { Id, T, Shape, Damage, Name, Target (userId | "all"), Qte (spec | false), Counter, CounterPerfect, Knock }
function F.hit(hit)
	hit.Id = hit.Id or F.newId("H")
	live[hit.Id] = hit
	announce(hit)
	local token = F.Token
	task.spawn(function()
		-- (sample a beat after impact: the server sees each player ~half a ping late)
		F.waitUntil(hit.T + 0.1)
		if F.cancelled(token) then live[hit.Id] = nil return end
		local inside = {}
		for _, t in ipairs(F.targets()) do
			if S.inside(hit.Shape, t.Root.Position, hit.T) then table.insert(inside, t) end
		end
		F.waitUntil(hit.T + S.GRACE)
		for _, t in ipairs(inside) do resolve(hit, t, hit.T) end
		task.delay(1, function() live[hit.Id] = nil end)
	end)
	return hit
end

-- a travelling hit (shockwave rings, sweeping beams) checked every frame until
-- `untilT`; each player can be caught once
function F.continuousHit(hit, untilT)
	hit.Id = hit.Id or F.newId("R")
	live[hit.Id] = hit
	announce(hit)
	local token = F.Token
	local caught = {}
	task.spawn(function()
		while S.now() < untilT and not F.cancelled(token) do
			local now = S.now()
			for _, t in ipairs(F.targets()) do
				if not caught[t.Player] and S.inside(hit.Shape, t.Root.Position, now, feetHeight(t)) then
					caught[t.Player] = true
					task.delay(S.GRACE, function()
						if not F.cancelled(token) then resolve(hit, t, now) end
					end)
				end
			end
			RunService.Heartbeat:Wait()
		end
		task.delay(1, function() live[hit.Id] = nil end)
	end)
	return hit
end
F.ringHit = F.continuousHit

Players.PlayerRemoving:Connect(function(p) claims[p] = nil end)
-- (old claims are dropped as their hits expire)
task.spawn(function()
	while true do
		task.wait(5)
		for _, list in pairs(claims) do
			for id in pairs(list) do
				if not live[id] then list[id] = nil end
			end
		end
	end
end)

--------------------------------------------------------------------------
-- setup + the loop
--------------------------------------------------------------------------
local attacks = {}

function F.init(bossModel)
	model = bossModel
	humanoid = model:WaitForChild("Humanoid")
	root = model:WaitForChild("HumanoidRootPart")
	F.Model = model
	humanoid.MaxHealth = Config.MaxHealth
	humanoid.Health = Config.MaxHealth
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	model:SetAttribute("DisplayName", Config.DisplayName)
	model:SetAttribute("Phase", 0)
	model:SetAttribute("Defeated", false)
	CollectionService:AddTag(model, "Boss") -- (the boss HUD finds him by this tag)
	F.setInvulnerable(true)
	-- where he starts: his angle round the arena, from where he stands in Studio
	local home = root.Position
	local a = math.atan2(home.Z - S.CENTER.Z, home.X - S.CENTER.X)
	local t = S.now()
	setPlan({ T0 = t, T1 = t, A0 = a, A1 = a, F0 = 0, F1 = 0, FM = 0, Y = home.Y })
	local ut = model:FindFirstChild("UpperTorso")
	if ut then chestOffset = root.CFrame:ToObjectSpace(ut.CFrame) end
	for _, m in ipairs(script.Parent:WaitForChild("Attacks"):GetChildren()) do
		if m:IsA("ModuleScript") then attacks[m.Name] = require(m) end
	end
	for i, ph in ipairs(Config.Phases) do
		for _, e in ipairs(ph.Attacks) do
			if not attacks[e.Module] then warn(("[BossFight] phase %d lists %s, but Attacks has no such module"):format(i, e.Module)) end
		end
	end
	-- (the clients read these for their moves)
	for _, k in ipairs({ "RollCooldown", "RollIFrames", "PunchRange", "PunchCooldown" }) do
		shared:SetAttribute(k, Config[k])
	end
	shared:SetAttribute("BossDazed", false)
	humanoid.Died:Connect(onDeath)
	humanoid.HealthChanged:Connect(publish)
	model.AttributeChanged:Connect(publish)
	publish()
	print("[BossFight] server ready: " .. #script.Parent.Attacks:GetChildren() .. " attacks loaded")
end

local function pick(phase, last)
	local pool, total = {}, 0
	for _, e in ipairs(phase.Attacks) do
		if attacks[e.Module] and (e.Module ~= last or #phase.Attacks == 1) then
			table.insert(pool, e)
			total += e.Weight
		end
	end
	local roll = F.rng:NextNumber() * total
	for _, e in ipairs(pool) do
		roll -= e.Weight
		if roll <= 0 then return e end
	end
	return pool[#pool]
end

-- his health, scaled to the party: base + a share per extra player
local function scaledHealth(n)
	return math.floor(Config.MaxHealth * (1 + (Config.HealthPerExtraPlayer or 0.7) * math.max(n - 1, 0)))
end

--------------------------------------------------------------------------
-- THE DAZE: after a few attacks he's spent - he slumps over the rim, his head
-- down on the arena, and for a few seconds he can be punched
--------------------------------------------------------------------------
local dazeEnds = 0
function F.weakPoint(t)
	local p = F.rootAt(t).Position
	local toBoss = S.flat(p - S.CENTER).Unit
	return S.CENTER + toBoss * (S.ARENA_R - 10) + Vector3.new(0, 5, 0)
end

local function daze()
	local t0 = S.now()
	local extra = math.max(#Players:GetPlayers() - 1, 0)
	local dur = math.max((Config.DazeTime or 8) - extra * (Config.DazeShortenPerPlayer or 0), 8)
	local weak = F.weakPoint(t0)
	F.Dazed = true
	dazeEnds = t0 + dur
	model:SetAttribute("Dazed", true)
	shared:SetAttribute("BossDazed", true)
	F.setInvulnerable(false)
	F.fx("Daze", { T0 = t0, T1 = t0 + dur, Weak = weak })
	print("[BossFight] dazed")
	while S.now() < dazeEnds and F.Alive and not transitioning do task.wait(0.1) end
	F.Dazed = false
	model:SetAttribute("Dazed", false)
	shared:SetAttribute("BossDazed", false)
	F.setInvulnerable(true)
	if not F.Alive then return end
	-- he comes round with a roar that throws everyone off him
	local rt = S.now() + 0.9
	local ring = { Kind = "ring", O = weak, R0 = 0, Speed = 95, W = 8, H = 5, T0 = rt }
	local hit = { Id = F.newId("DZ"), Shape = ring, Damage = 20, Name = "ROAR", Knock = 60, Qte = false }
	F.fx("DazeEnd", { T0 = S.now(), RingT = rt, Weak = weak, Id = hit.Id, Shape = ring })
	F.continuousHit(hit, rt + (2 * S.ARENA_R + 20) / ring.Speed)
	task.wait(1.6)
end

-- the players' own moves: a roll (i-frames) and, while he's dazed, the punch
local lastAct = {}
F.ActionRemote.OnServerEvent:Connect(function(player, action)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then return end
	local now = S.now()
	lastAct[player] = lastAct[player] or { roll = 0, punch = 0 }
	local L = lastAct[player]
	if action == "roll" then
		if now - L.roll < (Config.RollCooldown or 1.1) * 0.85 then return end
		L.roll = now
		player:SetAttribute("IFrameUntil", now + (Config.RollIFrames or 0.4))
		F.fx("Roll", { User = player.UserId })
	elseif action == "punch" then
		if not F.Dazed or now - L.punch < (Config.PunchCooldown or 0.4) * 0.8 then return end
		local weak = F.weakPoint(now)
		if (S.flat(root.Position) - S.flat(weak)).Magnitude > (Config.PunchRange or 30) + 6 then return end
		L.punch = now
		F.damageBoss(Config.PunchDamage or 55, player, "punch")
		F.fx("Punch", { User = player.UserId, At = weak })
	end
end)
Players.PlayerRemoving:Connect(function(p) lastAct[p] = nil end)

function F.run()
	local n = math.max(#Players:GetPlayers(), 1)
	humanoid.MaxHealth = scaledHealth(n)
	humanoid.Health = humanoid.MaxHealth
	print(("[BossFight] %d player(s): %d health"):format(n, humanoid.MaxHealth))
	-- (someone joining mid-fight adds their share)
	Players.PlayerAdded:Connect(function()
		if not F.Alive then return end
		local add = Config.MaxHealth * (Config.HealthPerExtraPlayer or 0.7)
		humanoid.MaxHealth += add
		humanoid.Health += add
	end)
	setPhase(1)
	-- (only ever hurt while he's dazed)
	F.setInvulnerable(true)
	-- the how-to-play cards first, then he comes for you
	local intro = Config.IntroTime or 10
	F.fx("Intro", { T0 = S.now(), Dur = intro })
	task.wait(intro)
	F.fx("Start", { T0 = S.now() })
	print("[BossFight] fight started")
	task.wait(1.5)
	local sinceDaze = 0
	local last
	local dir = F.rng:NextNumber() < 0.5 and 1 or -1
	while F.Alive do
		while transitioning and F.Alive do task.wait(0.1) end
		if not F.Alive then break end
		-- walk on round the arena (now and then turning back)
		if F.rng:NextNumber() < (Config.WalkChance or 1) then
			if F.rng:NextNumber() < 0.3 then dir = -dir end
			local arc = F.rng:NextNumber(Config.WalkArc[1], Config.WalkArc[2])
			F.walk(arc * dir)
		end
		if not F.Alive then break end
		while transitioning and F.Alive do task.wait(0.1) end
		local phase = F.phase()
		local entry = pick(phase, last)
		local forced = table.remove(F.Forced, 1)
		if forced and attacks[forced.Module] then
			entry = { Module = forced.Module, Weight = 0, Params = forced.Params or (forced.Module == "BigBang" and phase.UltimateParams) or nil }
		end
		if entry and #F.targets() > 0 then
			last = entry.Module
			local mod = attacks[entry.Module]
			local params = table.clone(mod.Defaults or {})
			for k, v in pairs(entry.Params or {}) do params[k] = v end
			params.Players = math.max(#F.targets(), 1)
			local token = F.Token
			print("[BossFight] attack: " .. entry.Module)
			local ok, err = pcall(mod.Run, F, params, token)
			if not ok then warn("[BossFight] " .. entry.Module .. " failed: " .. tostring(err)) end
			task.wait(phase.AttackDelay or 1)
			-- (after a run of attacks - or a set piece - he's spent)
			sinceDaze += 1
			if F.Alive and not transitioning and (sinceDaze >= (Config.AttacksBeforeDaze or 3) or forced) then
				sinceDaze = 0
				daze()
			end
		else
			task.wait(0.5)
		end
	end
end

return F
