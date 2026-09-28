-- Services
local PathfindingService = game:GetService("PathfindingService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- Configuration
local DETECT_RADIUS = 50
local ATTACK_RADIUS = 12
local FIRE_RATE = 3
local ARROW_SPEED = 100
local ARROW_LIFETIME = 8
local ANIM_ID = "rbxassetid://124700726189599"

local TURN_SPEED = 6            -- higher = snaps to face target faster, lower = smoother/slower turn
local PATH_RECOMPUTE_INTERVAL = 1 -- seconds between pathfinding recalculations (prevents jitter from recomputing every 0.1s)

local WANDER_RADIUS = 25        -- how far from spawn point the skeleton wanders
local WANDER_WAIT_MIN = 2       -- seconds to pause between wander destinations
local WANDER_WAIT_MAX = 5

-- References
local skeleton = script.Parent
local rootPart = skeleton:WaitForChild("HumanoidRootPart") -- always use HRP, never Torso
local humanoid = skeleton:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local arrowSpawn = skeleton:WaitForChild("ArrowSpawn")
local arrowPrefab = ServerStorage:WaitForChild("AccessibleModels"):WaitForChild("Arrow")

local spawnPosition = rootPart.Position

-- Let us drive rotation manually and smoothly instead of letting Humanoid snap it
humanoid.AutoRotate = false

-- State Machine setup
local States = { Idle = "Idle", Attack = "Attack" }
local currentState = States.Idle

-- Force server to handle movement physics smoothly
for _, part in ipairs(skeleton:GetDescendants()) do
	if part:IsA("BasePart") then
		pcall(function()
			part:SetNetworkOwner(nil)
		end)
	end
end

-- Load Animation Track
local detectAnim = Instance.new("Animation")
detectAnim.AnimationId = ANIM_ID
local animTrack = animator:LoadAnimation(detectAnim)

local lastShot = 0

-- Desired facing direction, updated by the AI loop and smoothly applied every frame
local desiredLookDir = rootPart.CFrame.LookVector

-- Cached pathfinding state so we don't recompute a path every 0.1s (that recompute
-- was the main cause of the movement "snapping")
local pathState = { waypoints = nil, index = 2, lastComputeTime = 0, goal = nil }

local function isValidTarget(character)
	if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Humanoid") then
		return false
	end
	if character.Humanoid.Health <= 0 then
		return false
	end
	if Players:GetPlayerFromCharacter(character) then
		return true
	end
	-- Name-based check restored: matches "IronGolem" or close variants (case-insensitive,
	-- partial match), e.g. "IronGolem_1", "iron golem", "IronGolemBoss"
	local lowerName = string.lower(character.Name)
	if string.find(lowerName, "irongolem") or string.find(lowerName, "iron golem") then
		return true
	end
	return false
end

local function getClosestTarget()
	local closestTarget = nil
	local shortestDistance = DETECT_RADIUS

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if isValidTarget(character) then
			local distance = (rootPart.Position - character.HumanoidRootPart.Position).Magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				closestTarget = character
			end
		end
	end

	-- Scan all descendants (not just direct children) so golems nested in a folder
	-- still get found
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) and isValidTarget(obj) then
			local distance = (rootPart.Position - obj.HumanoidRootPart.Position).Magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				closestTarget = obj
			end
		end
	end

	return closestTarget
end

local function getTargetPositionAtRadius(targetRoot)
	local direction = (rootPart.Position - targetRoot.Position).Unit
	if direction.Magnitude == 0 then direction = Vector3.new(1, 0, 0) end
	return targetRoot.Position + (direction * ATTACK_RADIUS)
end

-- Smooth, cached pathfinding: only recompute periodically or when we've run out
-- of waypoints, and advance through waypoints via MoveToFinished instead of
-- reissuing MoveTo every tick.
local function pathfindTo(targetPosition)
	local now = tick()
	local goalMoved = not pathState.goal or (pathState.goal - targetPosition).Magnitude > 4

	if not pathState.waypoints or goalMoved or (now - pathState.lastComputeTime) > PATH_RECOMPUTE_INTERVAL then
		local path = PathfindingService:CreatePath({
			AgentRadius = 3,
			AgentHeight = 5,
			AgentCanJump = true
		})

		local success = pcall(function()
			path:ComputeAsync(rootPart.Position, targetPosition)
		end)

		pathState.lastComputeTime = now
		pathState.goal = targetPosition

		if success and path.Status == Enum.PathStatus.Success then
			pathState.waypoints = path:GetWaypoints()
			pathState.index = 2
		else
			pathState.waypoints = nil
			humanoid:MoveTo(targetPosition)
			return
		end
	end

	local waypoints = pathState.waypoints
	if waypoints and waypoints[pathState.index] then
		local wp = waypoints[pathState.index]
		humanoid:MoveTo(wp.Position)
		if wp.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
	end
end

humanoid.MoveToFinished:Connect(function(reached)
	if reached and pathState.waypoints and pathState.index < #pathState.waypoints then
		pathState.index += 1
	end
end)

-- Smoothly rotate rootPart toward desiredLookDir every frame instead of snapping
-- it instantly once per 0.1s AI tick (this was the cause of the visible "snap left")
RunService.Heartbeat:Connect(function(dt)
	if desiredLookDir and desiredLookDir.Magnitude > 0 then
		local currentPos = rootPart.Position
		local flatDir = Vector3.new(desiredLookDir.X, 0, desiredLookDir.Z)
		if flatDir.Magnitude > 0.01 then
			local goalCFrame = CFrame.new(currentPos, currentPos + flatDir)
			rootPart.CFrame = rootPart.CFrame:Lerp(goalCFrame, math.clamp(dt * TURN_SPEED, 0, 1))
		end
	end
end)

-- Wander state
local wanderTarget = nil
local nextWanderTime = 0

local function pickWanderPoint()
	local angle = math.random() * math.pi * 2
	local radius = math.random() * WANDER_RADIUS
	local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	return spawnPosition + offset
end

-- Main AI Loop
task.spawn(function()
	while task.wait(0.1) do
		local target = getClosestTarget()

		if target and currentState == States.Idle then
			currentState = States.Attack
			pathState.waypoints = nil -- clear stale wander path
			if not animTrack.IsPlaying then
				animTrack:Play()
			end
		elseif not target and currentState == States.Attack then
			currentState = States.Idle
			pathState.waypoints = nil -- clear stale attack path
			animTrack:Stop()
		end

		if currentState == States.Attack and target then
			local targetRoot = target.HumanoidRootPart -- always HRP, never Torso
			local directDistance = (rootPart.Position - targetRoot.Position).Magnitude

			-- Face the target (applied smoothly in the Heartbeat loop above)
			desiredLookDir = (targetRoot.Position - rootPart.Position)

			if directDistance > (ATTACK_RADIUS + 3) or directDistance < (ATTACK_RADIUS - 3) then
				local goalPos = getTargetPositionAtRadius(targetRoot)
				pathfindTo(goalPos)
			else
				humanoid:MoveTo(rootPart.Position)
			end

			-- Shoot Arrow Sequence
			if tick() - lastShot >= FIRE_RATE then
				lastShot = tick()

				local arrowClone = arrowPrefab:Clone()
				arrowClone.Name = "Arrow"

				local arrowPart = arrowClone:IsA("Model") and arrowClone.PrimaryPart or arrowClone
				if not arrowPart then
					arrowClone:Destroy()
					continue
				end

				for _, part in ipairs(arrowClone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = false
						part.CanCollide = false
						if part ~= arrowPart then
							local alreadyRigid = false
							for _, joint in ipairs(part:GetJoints()) do
								if joint:IsA("WeldConstraint") or joint:IsA("Weld") or joint:IsA("Motor6D") then
									alreadyRigid = true
									break
								end
							end
							if not alreadyRigid then
								local weld = Instance.new("WeldConstraint")
								weld.Part0 = arrowPart
								weld.Part1 = part
								weld.Parent = arrowPart
							end
						end
					end
				end

				local spawnPos = arrowSpawn.Position
				local direction = (targetRoot.Position - spawnPos).Unit

				if arrowClone:IsA("Model") then
					arrowClone:PivotTo(CFrame.lookAt(spawnPos, spawnPos + direction))
				else
					arrowClone.CFrame = CFrame.lookAt(spawnPos, spawnPos + direction)
				end

				arrowClone.Parent = Workspace
				arrowPart.AssemblyLinearVelocity = direction * ARROW_SPEED

				Debris:AddItem(arrowClone, ARROW_LIFETIME)
			end

		elseif currentState == States.Idle then
			-- Wander instead of standing still
			local now = tick()
			if not wanderTarget or now >= nextWanderTime then
				wanderTarget = pickWanderPoint()
				nextWanderTime = now + math.random(WANDER_WAIT_MIN, WANDER_WAIT_MAX)
				pathState.waypoints = nil -- force fresh path to new wander point
			end

			local distToWander = (rootPart.Position - wanderTarget).Magnitude
			if distToWander > 2 then
				desiredLookDir = (wanderTarget - rootPart.Position)
				pathfindTo(wanderTarget)
			else
				humanoid:MoveTo(rootPart.Position)
			end
		end
	end
end)