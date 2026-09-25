--==================================================
-- SPIRAL ENERGY SERVICE
-- Sets every player up with an empty gauge and, while
-- the boss fight is running, fills it slowly over time
-- (one bar every CHARGE_TIME seconds). Hook your own
-- rewards in with ServerStorage.SpiralEnergy.Add().
--==================================================

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spiral = require(ServerStorage:WaitForChild("SpiralEnergy"))
require(ServerStorage:WaitForChild("SpiralPickups")) -- starts the pickup loop

--==================================================
-- SPIRAL POWER  (press F)
-- Spends ALL stored energy (need at least 1). Lasts
-- BASE + PER_ENERGY seconds per bar spent, so a full 10
-- is a 23 second super mode:
--   * walk speed x SPEED_MULT
--   * heals REGEN_PCT of max health every second
--   * ReplicatedStorage.SpiralAura's particle emitters are
--     copied onto the matching body parts
--==================================================

local BASE_TIME = 3
local PER_ENERGY = 2
local SPEED_MULT = 1.6
local REGEN_PCT = 0.04
local ACTIVATE_SOUND = "rbxassetid://101311815784759"

local activateRemote = ReplicatedStorage:FindFirstChild("SpiralActivate")
if not activateRemote then
	activateRemote = Instance.new("RemoteEvent")
	activateRemote.Name = "SpiralActivate"
	activateRemote.Parent = ReplicatedStorage
end

-- SpiralAura is an R6 rig; map its parts onto R15 bodies too
local R15_MAP = {
	Torso = { "UpperTorso", "LowerTorso" },
	["Left Arm"] = { "LeftUpperArm", "LeftLowerArm" },
	["Right Arm"] = { "RightUpperArm", "RightLowerArm" },
	["Left Leg"] = { "LeftUpperLeg", "LeftLowerLeg" },
	["Right Leg"] = { "RightUpperLeg", "RightLowerLeg" },
}

local function applyAura(character)
	local rig = ReplicatedStorage:FindFirstChild("SpiralAura")
	if not rig then return end
	for _, src in ipairs(rig:GetChildren()) do
		if src:IsA("BasePart") then
			local targets = {}
			local direct = character:FindFirstChild(src.Name)
			if direct and direct:IsA("BasePart") then
				table.insert(targets, direct)
			else
				for _, n in ipairs(R15_MAP[src.Name] or {}) do
					local p = character:FindFirstChild(n)
					if p then table.insert(targets, p) end
				end
			end
			for _, target in ipairs(targets) do
				for _, d in ipairs(src:GetDescendants()) do
					if d:IsA("ParticleEmitter") then
						local holder = target
						if d.Parent:IsA("Attachment") then
							local att = Instance.new("Attachment")
							att.Name = "SpiralAuraFX"
							att.CFrame = d.Parent.CFrame
							att.Parent = target
							holder = att
						end
						local copy = d:Clone()
						copy.Name = "SpiralAuraFX"
						copy.Enabled = true
						copy.Parent = holder
					end
				end
			end
		end
	end
end

local function removeAura(character)
	if not character then return end
	for _, d in ipairs(character:GetDescendants()) do
		if d.Name == "SpiralAuraFX" then d:Destroy() end
	end
end

local active = {} -- [player] = token

-- Everything that has to be undone when a run ends, in one place. This used
-- to be a tail of statements after the loop: if ANY line above it threw --
-- applyAura touching a part that had just despawned, say -- the thread died
-- with SpiralActive still true and active[player] still set, and F was dead
-- for that player for the rest of the round. That was the "sometimes you
-- can't use spiral energy" bug.
local function endRun(player, token, char, hum, baseSpeed)
	if token and active[player] ~= token then return end
	active[player] = nil
	if hum and hum.Parent and baseSpeed then
		pcall(function() hum.WalkSpeed = baseSpeed end)
	end
	pcall(removeAura, char)
	if player and player.Parent then
		player:SetAttribute("SpiralActive", false)
		player:SetAttribute("SpiralEndsAt", 0)
	end
end

local function activate(player)
	if active[player] then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local energy = Spiral.Get(player)
	if energy < 1 or not Spiral.Spend(player, energy) then return end

	local duration = BASE_TIME + PER_ENERGY * energy
	local token = {}
	active[player] = token
	player:SetAttribute("SpiralActive", true)
	player:SetAttribute("SpiralEndsAt", workspace:GetServerTimeNow() + duration)

	local baseSpeed = hum.WalkSpeed

	local ok, err = pcall(function()
		hum.WalkSpeed = baseSpeed * SPEED_MULT
		applyAura(char)

		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			local s = Instance.new("Sound")
			s.SoundId = ACTIVATE_SOUND
			s.Volume = 1.4
			s.Parent = root
			s:Play()
			game:GetService("Debris"):AddItem(s, 5)
		end

		local ends = os.clock() + duration
		while os.clock() < ends and active[player] == token and hum.Parent and hum.Health > 0 do
			hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * REGEN_PCT * 0.25)
			task.wait(0.25)
		end
	end)

	if not ok then
		warn("[SpiralEnergy] run failed, releasing the player anyway: " .. tostring(err))
	end
	endRun(player, token, char, hum, baseSpeed)
end

activateRemote.OnServerEvent:Connect(function(player)
	task.spawn(activate, player)
end)

-- Respawning always clears the flag. This has to cover players who were
-- ALREADY here when the script started, not just later joiners -- in a
-- Studio test that is every player, which is why it kept getting missed.
local function watchRespawns(p)
	p.CharacterAdded:Connect(function()
		active[p] = nil
		p:SetAttribute("SpiralActive", false)
		p:SetAttribute("SpiralEndsAt", 0)
	end)
end
Players.PlayerAdded:Connect(watchRespawns)
for _, p in ipairs(Players:GetPlayers()) do watchRespawns(p) end

Players.PlayerRemoving:Connect(function(p) active[p] = nil end)

-- Last line of defence: if the flag is somehow still set well past the run's
-- own end time, let the player go. Nothing should ever reach this, but a
-- stuck flag is a silently unusable ability, so it is worth the sweep.
task.spawn(function()
	while true do
		task.wait(2)
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("SpiralActive") == true and not active[p] then
				local endsAt = p:GetAttribute("SpiralEndsAt") or 0
				if workspace:GetServerTimeNow() > endsAt + 1 then
					warn("[SpiralEnergy] clearing a stuck SpiralActive on " .. p.Name)
					p:SetAttribute("SpiralActive", false)
					p:SetAttribute("SpiralEndsAt", 0)
					pcall(removeAura, p.Character)
				end
			end
		end
	end
end)

local CHARGE_TIME = 12

Players.PlayerAdded:Connect(function(p) Spiral.Set(p, 0) end)
for _, p in ipairs(Players:GetPlayers()) do Spiral.Set(p, 0) end

local function fightRunning()
	local boss = CollectionService:GetTagged("Boss")[1]
	if not boss then return false end
	return (boss:GetAttribute("Phase") or 0) >= 1 and not boss:GetAttribute("Defeated")
end

local timers = {}
while true do
	task.wait(1)
	if fightRunning() then
		for _, p in ipairs(Players:GetPlayers()) do
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not Spiral.IsFull(p) then
				timers[p] = (timers[p] or 0) + 1
				if timers[p] >= CHARGE_TIME then
					timers[p] = 0
					Spiral.Add(p, 1)
				end
			end
		end
	end
end
