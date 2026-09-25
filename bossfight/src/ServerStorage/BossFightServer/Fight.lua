--==================================================
-- BOSS FIGHT: SERVER CORE
-- The Anti-Spiral's state (health, phase, where he's walking),
-- the remotes, and every hit: attacks schedule hits with an
-- impact time and a shape; at impact the server checks who is
-- inside, waits a moment for parry claims, then resolves each
-- one as a hit, a parry (he takes the damage instead) or an
-- evade (Spiral Dash i-frames).
--
-- Attack modules (./Attacks) get this module and use:
--   F.now(), F.waitUntil(t), F.cancelled(token)
--   F.targets()                 -> { { Player, Root, Humanoid } } on the arena
--   F.rootAt(t)                 -> his root CFrame at t (from the walk plan)
--   F.fx(kind, data)            -> every client runs the matching visual
--   F.hit(hit)                  -> schedule a timed hit (circle / line shapes)
--   F.ringHit(hit, until)       -> a travelling shockwave ring (checked every frame)
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
F.FxRemote = remote("Fx")        -- server -> clients: attack visuals, hit results
F.BatRemote = remote("Bat")      -- client -> server: swings (with parry claims), dash, drill
F.BatFxRemote = remote("BatFx")  -- server -> clients: other players' bat visuals

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
		if F.Alive then F.setInvulnerable(false) end
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
function F.damageBoss(amount, player, source)
	if not F.Alive or model:GetAttribute("Invulnerable") then return false end
	humanoid.Health = math.max(humanoid.Health - amount, 0)
	F.fx("BossHurt", { Amount = amount, Source = source, User = player and player.UserId or 0 })
	if humanoid.Health <= 0 then
		onDeath()
		return true
	end
	if not transitioning then
		local pct = humanoid.Health / humanoid.MaxHealth
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
-- hits and parries
--------------------------------------------------------------------------
local live = {}   -- [id] = hit (while it can still be parried)
local claims = {} -- [player] = { [id] = client server-time of the swing }
local SLACK = 0.12

function F.isLive(id) return live[id] ~= nil end

function F.claim(player, id, clientT)
	if not live[id] then return end
	claims[player] = claims[player] or {}
	if not claims[player][id] then claims[player][id] = clientT end
end

local function resolve(hit, t, T)
	local player = t.Player
	local mine = claims[player] and claims[player][hit.Id]
	local result
	if hit.Parry ~= false and mine and mine >= T - S.PARRY_EARLY - SLACK and mine <= T + S.PARRY_LATE + SLACK then
		local perfect = math.abs(mine - T) <= S.PERFECT + 0.03
		result = perfect and "perfect" or "parry"
		F.damageBoss(perfect and Config.PerfectDamage or Config.ParryDamage, player, "parry")
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
	F.fx("Resolve", { Id = hit.Id, User = player.UserId, Result = result, Pos = t.Root.Position })
end

-- a timed hit: { Id, T, Shape, Damage, Name, Target (userId), Parry (default true), Knock }
function F.hit(hit)
	hit.Id = hit.Id or F.newId("H")
	live[hit.Id] = hit
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

-- a shockwave ring that runs until `untilT`; each player can be caught once
function F.ringHit(hit, untilT)
	hit.Id = hit.Id or F.newId("R")
	live[hit.Id] = hit
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
	humanoid.Died:Connect(onDeath)
	humanoid.HealthChanged:Connect(publish)
	model.AttributeChanged:Connect(publish)
	publish()
	print("[BossFight] server ready: " .. #script.Parent.Attacks:GetChildren() .. " attacks loaded")
end

-- a travelling hit checked every frame (rings, sweeping beams)
function F.continuousHit(hit, untilT)
	return F.ringHit(hit, untilT)
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

function F.run()
	setPhase(1)
	F.setInvulnerable(false)
	F.fx("Start", { T0 = S.now() })
	print("[BossFight] fight started")
	task.wait(1.5)
	local last
	local dir = F.rng:NextNumber() < 0.5 and 1 or -1
	while F.Alive do
		while transitioning and F.Alive do task.wait(0.1) end
		if not F.Alive then break end
		-- walk on round the arena (now and then turning back)
		if F.rng:NextNumber() < 0.3 then dir = -dir end
		local arc = F.rng:NextNumber(Config.WalkArc[1], Config.WalkArc[2])
		F.walk(arc * dir)
		if not F.Alive then break end
		while transitioning and F.Alive do task.wait(0.1) end
		local phase = F.phase()
		local entry = pick(phase, last)
		if entry and #F.targets() > 0 then
			last = entry.Module
			local mod = attacks[entry.Module]
			local params = table.clone(mod.Defaults or {})
			for k, v in pairs(entry.Params or {}) do params[k] = v end
			local token = F.Token
			print("[BossFight] attack: " .. entry.Module)
			local ok, err = pcall(mod.Run, F, params, token)
			if not ok then warn("[BossFight] " .. entry.Module .. " failed: " .. tostring(err)) end
			task.wait(phase.AttackDelay or 1)
		else
			task.wait(0.5)
		end
	end
end

return F
