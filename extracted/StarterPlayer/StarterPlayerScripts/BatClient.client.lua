--==================================================
-- VERITY BAT  (client)  -- ported from BECOME LA PEACE's Keybinds swing
-- Click to swing (3-hit combo, the 3rd is a ground slam). Hits the
-- boss/minions; players are ignored. Server also bats back any energy
-- orbs in front of you when the swing lands.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BatRemotes")
local Swing = remotes:WaitForChild("Swing")
local SwingVisuals = remotes:WaitForChild("SwingVisuals")
local GroundSlam = remotes:WaitForChild("GroundSlam")
local GroundSlamVisual = remotes:WaitForChild("GroundSlamVisual")
local SwingAnims = ReplicatedStorage:WaitForChild("SwingAnims")
local assets = ReplicatedStorage:WaitForChild("BatAssets")
local regularHitbox = assets:WaitForChild("RegularHitbox")
local upgradedHitbox = assets:WaitForChild("UpgradedHitbox")

local m1sPerformed, currentM1 = 0, 0
local m1Debounce = false
local COMBO_END_COOLDOWN = 0.5
local WAIT_BEFORE_RESET = 0.5

local function swing()
	if m1Debounce then return end
	m1Debounce = true

	local character = player.Character
	local batTool = character and (character:FindFirstChild("VerityBat") or character:FindFirstChild("Bat"))
	if not batTool then m1Debounce = false return end
	local batType = batTool.Name

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or humanoid.Health <= 0 or not animator or not rootPart then m1Debounce = false return end

	m1sPerformed += 1
	currentM1 += 1
	local anim = SwingAnims:FindFirstChild("Swing" .. currentM1)
	if not anim then currentM1 = 0 m1Debounce = false return end

	local track = animator:LoadAnimation(anim)
	track.Looped = false
	local thisM1 = currentM1

	local hitConn = track:GetMarkerReachedSignal("Hit"):Connect(function()
		SwingVisuals:FireServer(thisM1, batType)
		if thisM1 == 3 then GroundSlam:FireServer(batType) end

		local box = (batType == "VerityBat" and upgradedHitbox or regularHitbox):Clone()
		box.CFrame = rootPart.CFrame * CFrame.new(0, 0, -3)
		box.Parent = workspace

		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hitModels = {}
		for _, part in ipairs(workspace:GetPartsInPart(box, params)) do
			local model = part:FindFirstAncestorOfClass("Model")
			while model and not model:FindFirstChildOfClass("Humanoid") do model = model:FindFirstAncestorOfClass("Model") end
			if model and not hitModels[model] and not Players:GetPlayerFromCharacter(model) then
				local hum = model:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hitModels[model] = true
					Swing:FireServer(part, thisM1)
				end
			end
		end
		Debris:AddItem(box, 0.2)
	end)

	track:Play()
	track.Stopped:Wait()
	hitConn:Disconnect()

	task.spawn(function()
		local old = m1sPerformed
		task.wait(WAIT_BEFORE_RESET)
		if old == m1sPerformed then currentM1 = 0 end
	end)
	if currentM1 >= 3 then
		task.wait(COMBO_END_COOLDOWN)
		currentM1 = 0
	end
	m1Debounce = false
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		task.spawn(swing)
	end
end)

--------------------------------------------------
-- ground slam rubble
--------------------------------------------------
local function spawnRingCube(position, material, color)
	local cube = Instance.new("Part")
	cube.Anchored = true
	cube.CanCollide = false
	cube.CanQuery = false
	cube.Material = material
	cube.Color = color
	cube.Size = Vector3.new(math.random(8, 16) / 10, math.random(8, 16) / 10, math.random(8, 16) / 10)
	local rest = CFrame.new(position) * CFrame.Angles(math.rad(math.random(0, 360)), math.rad(math.random(0, 360)), math.rad(math.random(0, 360)))
	cube.CFrame = rest
	cube.Parent = workspace
	local pop = TweenService:Create(cube, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = rest + Vector3.new(0, math.random(3, 10) / 10, 0) })
	pop:Play()
	pop.Completed:Connect(function()
		task.wait(math.random(2, 4) / 10)
		TweenService:Create(cube, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = rest - Vector3.new(0, cube.Size.Y, 0), Transparency = 1 }):Play()
	end)
	Debris:AddItem(cube, 1.2)
end

GroundSlamVisual.OnClientEvent:Connect(function(_, material, color, ring)
	for _, pos in ipairs(ring) do spawnRingCube(pos, material, color) end
end)
