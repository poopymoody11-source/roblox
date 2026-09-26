-- ModuleScript | ServerStorage.BossController
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local BossController = {}
BossController.__index = BossController

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function BossController.new(model, config, arena)
	local self = setmetatable({}, BossController)
	self.Model = model
	self.Config = config
	self.Arena = arena
	self.Humanoid = model:WaitForChild("Humanoid")
	self.Root = model:WaitForChild("HumanoidRootPart")

	self.PhaseIndex = 0
	self.Token = 0 -- bumped on every phase change and on death; running attacks check it and bail out
	self.Started = false
	self.Alive = true
	self.Transitioning = false
	self.Minions = {}
	self.Spikes = nil -- the BossSpikes manager; the Summon attack creates it the first time it's needed
	self.GasterBlasters = nil -- the BossGasterBlasters manager; created the first time a Gaster attack runs-- the BossSpikes manager; the Summon attack creates it the first time it's needed

	local defeated = Instance.new("BindableEvent")
	self._defeated = defeated
	self.Defeated = defeated.Event

	-- Telegraphs, projectiles, blasts and minions all live here and get wiped when the boss dies
	self.Effects = Instance.new("Folder")
	self.Effects.Name = "BossEffects"
	self.Effects.Parent = workspace

	-- Load every attack module by name
	self.Attacks = {}
	for _, module in ServerStorage:WaitForChild("BossAttacks"):GetChildren() do
		if module:IsA("ModuleScript") then
			self.Attacks[module.Name] = require(module)
		end
	end

	for i, phase in config.Phases do
		for _, entry in phase.Attacks do
			if not self.Attacks[entry.Module] then
				warn(("BossConfig phase %d lists '%s' but there is no module with that name in ServerStorage.BossAttacks"):format(i, entry.Module))
			end
		end
	end

	self.Humanoid.MaxHealth = config.MaxHealth
	self.Humanoid.Health = config.MaxHealth
	self.Humanoid.WalkSpeed = config.WalkSpeed or 16
	pcall(function()
		self.Root:SetNetworkOwner(nil) -- the server simulates the boss (errors harmlessly if anchored)
	end)

	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:SetAttribute("DisplayName", config.DisplayName)
	model:SetAttribute("Phase", 0)
	CollectionService:AddTag(model, "Boss") -- the health bar LocalScript finds the boss by this tag

	self:SetInvulnerable(true) -- stays invulnerable until the fight starts
	return self
end

-- Invulnerable while dormant and during phase transitions.
-- ForceField blocks Humanoid:TakeDamage. If your weapon scripts set Health directly,
-- check the boss's "Invulnerable" attribute in them.
function BossController:SetInvulnerable(state)
	self.Model:SetAttribute("Invulnerable", state)
	local field = self.Model:FindFirstChildOfClass("ForceField")
	if state and not field then
		field = Instance.new("ForceField")
		field.Visible = false
		field.Parent = self.Model
	elseif not state and field then
		field:Destroy()
	end
end

-- Living players' root parts that are on (or near) the arena
function BossController:GetTargets()
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			if flatDistance(root.Position, self.Arena.Center) <= self.Arena.Radius + 10 then
				table.insert(list, root)
			end
		end
	end
	return list
end

function BossController:PickTarget()
	local best, bestDist = nil, math.huge
	for _, root in self:GetTargets() do
		local dist = flatDistance(root.Position, self.Root.Position)
		if dist < bestDist then
			best, bestDist = root, dist
		end
	end
	return best
end

function BossController:FaceTowards(position)
	if self.Root.Anchored then return end -- a fixed background boss doesn't turn
	local here = self.Root.Position
	self.Root.CFrame = CFrame.lookAt(here, Vector3.new(position.X, here.Y, position.Z))
end

function BossController:CountMinions()
	local alive = {}
	for _, minion in self.Minions do
		local humanoid = minion:FindFirstChildOfClass("Humanoid")
		if minion.Parent and humanoid and humanoid.Health > 0 then
			table.insert(alive, minion)
		end
	end
	self.Minions = alive
	return #alive
end

-- Cached AnimationTrack for an Animation instance, played through the boss's Animator
function BossController:GetTrack(animation)
	self._tracks = self._tracks or {}
	local track = self._tracks[animation]
	if not track then
		local animator = self.Humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = self.Humanoid
		end
		track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		self._tracks[animation] = track
	end
	return track
end

function BossController:PhaseForHealth()
	local pct = self.Humanoid.Health / self.Humanoid.MaxHealth
	for i = #self.Config.Phases, 1, -1 do
		if pct <= self.Config.Phases[i].StartsAtHealthPct then
			return i
		end
	end
	return 1
end

local function runHook(hook, ...)
	if not hook then return end
	local ok, err = pcall(hook, ...)
	if not ok then
		warn("Boss phase hook error:", err)
	end
end

function BossController:SetPhase(index)
	self.Transitioning = true
	self.Token += 1 -- cancels whatever attack is mid-flight
	self:SetInvulnerable(true)

	local old = self.Config.Phases[self.PhaseIndex]
	if old then runHook(old.OnExit, self) end

	self.PhaseIndex = index
	self.Model:SetAttribute("Phase", index) -- replicates to clients (health bar color, music, etc.)

	local new = self.Config.Phases[index]
	runHook(new.OnEnter, self)
	task.wait(new.TransitionTime or 0)

	if self.Alive then
		self:SetInvulnerable(false)
	end
	self.Transitioning = false
end

-- Weighted random pick among the attacks that are usable right now.
-- An attack is usable if its CanUse(boss, dist, params) returns true, or, without CanUse,
-- if the target's distance is inside its MinRange/MaxRange.
-- Returns the attack module and its params (module Defaults overridden by the phase's Params).
function BossController:PickAttack(phase, dist)
	local pool, total = {}, 0
	for _, entry in phase.Attacks do
		local attack = self.Attacks[entry.Module]
		if attack then
			local params = table.clone(attack.Defaults or {})
			for key, value in entry.Params or {} do
				params[key] = value
			end

			local usable
			if attack.CanUse then
				usable = attack.CanUse(self, dist, params)
			else
				usable = dist >= (attack.MinRange or 0) and dist <= (attack.MaxRange or math.huge)
			end

			if usable then
				-- We add 'AttackName = entry.Module' here to save the string from your config
				table.insert(pool, { 
					attack = attack, 
					AttackName = entry.Module, 
					params = params, 
					weight = entry.Weight 
				})
				total += entry.Weight
			end
		end
	end

	if total == 0 then return nil end

	local roll = math.random() * total
	local chosen = pool[#pool]
	for _, item in pool do
		roll -= item.weight
		if roll <= 0 then
			chosen = item
			break
		end
	end

	-- Now we print the AttackName we saved earlier!
	print("Chosen attack:", chosen.AttackName)
	return chosen.attack, chosen.params
end

function BossController:RunAttack(attack, target, params)
	local token = self.Token
	local function isCancelled()
		return not self.Alive or self.Token ~= token
	end

	self.Humanoid:MoveTo(self.Root.Position) -- stand still during the attack
	local ok, err = pcall(attack.Execute, self, target, isCancelled, params)
	if not ok then
		warn("Boss attack error:", err)
	end
end

function BossController:Loop()
	self:SetPhase(1)

	while self.Alive do
		while self.Transitioning and self.Alive do
			task.wait(0.1)
		end

		local phase = self.Config.Phases[self.PhaseIndex]
		local delay = 0.25

		local target = self:PickTarget()
		if target then
			local dist = flatDistance(target.Position, self.Root.Position)
			local attack, params = self:PickAttack(phase, dist)
			if attack then
				self:RunAttack(attack, target, params)
				delay = phase.AttackDelay
			elseif not self.Root.Anchored then
				self.Humanoid:MoveTo(target.Position) -- nothing in range: close the gap (a fixed boss can't)
			end
		end

		task.wait(delay)
	end
end

-- Called once by BossService when the cutscene signal arrives
function BossController:Start()
	if self.Started or not self.Alive then return end
	self.Started = true

	self.Humanoid.Died:Connect(function()
		self:OnDeath()
	end)

	self.Humanoid.HealthChanged:Connect(function()
		if not self.Alive or self.Humanoid.Health <= 0 or self.Transitioning then return end
		local want = self:PhaseForHealth()
		if want > self.PhaseIndex then
			self:SetPhase(want)
		end
	end)

	task.spawn(function()
		self:Loop()
	end)
end

function BossController:OnDeath()
	if not self.Alive then return end
	self.Alive = false
	self.Token += 1
	self.Model:SetAttribute("Defeated", true)

	if self.Spikes then
		self.Spikes:Destroy()
	end
	if self.GasterBlasters then
		self.GasterBlasters:Destroy()
	end
	self.Effects:ClearAllChildren() -- telegraphs, projectiles, spikes and minions
	self.Minions = {}
	self._defeated:Fire()
end

return BossController