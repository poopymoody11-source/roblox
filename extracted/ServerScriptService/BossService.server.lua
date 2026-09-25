-- Script | ServerScriptService.BossService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BossController = require(ServerStorage:WaitForChild("BossController"))
local BossConfig = require(ServerStorage:WaitForChild("BossConfig"))

-- "Anti-Spiral" has a hyphen, so workspace.BossFight.Anti-Spiral would parse as a subtraction.
-- Index it by string instead.
local bossFight = workspace:WaitForChild("BossFight")
local model = bossFight:WaitForChild("Anti-Spiral")

-- BossFightMap may sit inside BossFight or directly in Workspace; find it either way
local function findMapFolder()
	return bossFight:FindFirstChild("BossFightMap", true) or workspace:FindFirstChild("BossFightMap", true)
end

local mapFolder = findMapFolder()
while not mapFolder do
	task.wait(0.5)
	mapFolder = findMapFolder()
end
local map = mapFolder:WaitForChild("MainMap")

-- Arena info from the disc. Assumes a flat, horizontal disc: the smallest Size axis is the
-- thickness and the largest is the diameter, whichever way the part is oriented.
local sizes = { map.Size.X, map.Size.Y, map.Size.Z }
table.sort(sizes)
local arena = {
	Center = map.Position,
	Radius = sizes[3] / 2,
	SurfaceY = map.Position.Y + sizes[1] / 2,
}

local function getOrCreate(parent, className, name)
	local instance = parent:FindFirstChild(name)
	if not instance then
		instance = Instance.new(className)
		instance.Name = name
		instance.Parent = parent
	end
	return instance
end

-- Remote the cutscene's LocalScript fires when the cutscene ends
local remotes = getOrCreate(ReplicatedStorage, "Folder", "BossRemotes")
local cutsceneFinished = getOrCreate(remotes, "RemoteEvent", "CutsceneFinished")

local boss = BossController.new(model, BossConfig, arena)

-- The fight starts when FinalCutsceneServer flips the place to "Fight"
-- at the end of the opening cutscene (the old client remote is ignored,
-- so nobody can start the boss early from their own client).
-- (testing switch: set workspace attribute FC_FightDisabled = true to keep the
-- boss idle after the cutscene; clear it to turn the fight back on)
local function checkFight()
	if workspace:GetAttribute("FC_FightDisabled") then return end
	if workspace:GetAttribute("FC_State") == "Fight" then
		boss:Start() -- safe to call repeatedly; only the first call does anything
	end
end
workspace:GetAttributeChangedSignal("FC_State"):Connect(checkFight)
checkFight()

boss.Defeated:Connect(function()
	print("Anti-Spiral defeated")
	-- FinalBossLink sees this and sends everyone home to BECOME LA PEACE
	-- with the SPIRAL KING reward flag
	workspace:SetAttribute("FC_BossDefeated", true)
end)

-- boss:Start() -- uncomment to test the fight without the cutscene