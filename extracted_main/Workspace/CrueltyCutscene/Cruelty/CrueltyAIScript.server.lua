local boss = script.Parent
local humanoid = boss:WaitForChild("Humanoid")
local rootPart = boss:WaitForChild("HumanoidRootPart")
local Players = game:GetService("Players")

local shootingAnim = boss.Parent.CrueltyAnims.Shoot
local walkAnim = boss.Parent.CrueltyAnims.Walk
local swingAnim = boss.Parent.CrueltyAnims.Swing

-- Check if this specific instance is the active fighting clone
local isClone = boss:GetAttribute("IsClone")

if isClone then
	-- ===================================================
	-- CLONE / ACTIVE BOSS BEHAVIOR
	-- ===================================================

	humanoid.BreakJointsOnDeath = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)

	local head = boss:WaitForChild("Head")
	local crueltyCameraPart = boss:WaitForChild("CrueltyCamera")
	local fireSource = crueltyCameraPart:WaitForChild("Fire")

	-- Load animation tracks on the clone's animator
	local animator = humanoid:WaitForChild("Animator")
	local shootTrack = animator:LoadAnimation(shootingAnim)
	local walkTrack = animator:LoadAnimation(walkAnim)
	local swingTrack = animator:LoadAnimation(swingAnim)

	-- Configuration Settings
	local MELEE_RANGE = 20
	local MELEE_DAMAGE = 10
	local MELEE_COOLDOWN = 2.2
	local PROJECTILE_SPEED = 40
	local PROJECTILE_DAMAGE = 6

	local DEFAULT_WALKSPEED = 16
	local STOP_DISTANCE = MELEE_RANGE - 5
	local RESUME_MOVE_BUFFER = 5
	local SCATTER_ANGLE = 25

	local SPIN_SPEED_MIN = 5
	local SPIN_SPEED_MAX = 10

	-- Phase 2 settings
	local PHASE_TWO_HEALTH_FRACTION = 0.5
	local PHASE_TWO_CAMERA_RADIUS = 60
	local PHASE_TWO_CAMERA_DURATION = 2

	local GIANT_PROJECTILE_INTERVAL = 14
	local GIANT_PROJECTILE_SCALE = 3
	local GIANT_PROJECTILE_SPEED = 25
	local GIANT_PROJECTILE_DAMAGE = 18
	local GIANT_PROJECTILE_LIFETIME = 6

	local FRAGMENT_COUNT = 6
	local FRAGMENT_SPEED = 45
	local FRAGMENT_DAMAGE = 5
	local FRAGMENT_LIFETIME = 3

	local Debris = game:GetService("Debris")
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local lastMeleeTime = 0
	local lastRangedTime = tick()
	local isFiring = false
	local isStopped = false
	local aiStarted = false

	-- CrueltyFightService drops the boss in from above and smashes it into
	-- the floor first. Hold the AI until that's finished, or it would walk
	-- off mid-air during the entrance.
	local function entering()
		return boss:GetAttribute("Entering") == true
	end

	-- The party falls in through the portal and Cruelty makes his entrance
	-- and says his piece before anyone can throw a punch. CrueltyFightService
	-- flips this once the intro is over; until then he holds still.
	local function fightLive()
		return workspace:GetAttribute("CrueltyFightLive") == true
	end

	local phaseTwoTriggered = false
	local isPhaseTwo = false
	local lastGiantProjectileTime = 0

	-- Play/Stop Walk Animation automatically on movement
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 and not isFiring then
			if not walkTrack.IsPlaying then
				walkTrack:Play()
			end
		else
			if walkTrack.IsPlaying then
				walkTrack:Stop()
			end
		end
	end)

	local projectileFolder = workspace:FindFirstChild("BossActiveProjectiles") or Instance.new("Folder")
	projectileFolder.Name = "BossActiveProjectiles"
	if not projectileFolder.Parent then
		projectileFolder.Parent = workspace
	end

	local projectileTemplate = workspace:WaitForChild("CrueltyCutscene"):WaitForChild("CrueltyBall")

	local fireTemplates = {}
	if fireSource:IsA("ParticleEmitter") then
		table.insert(fireTemplates, fireSource)
	else
		for _, child in ipairs(fireSource:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				table.insert(fireTemplates, child)
			end
		end
	end

	local phaseTwoCameraEvent = ReplicatedStorage:FindFirstChild("CrueltyPhaseTwoCamera")
	local fightFx = ReplicatedStorage:FindFirstChild("CrueltyFightFX")
	local TweenService = game:GetService("TweenService")

	-- where a projectile lands: a flash of embers and a small shock ring
	local impactFolder = workspace:FindFirstChild("CrueltyImpacts") or Instance.new("Folder")
	impactFolder.Name = "CrueltyImpacts"
	impactFolder.Parent = workspace
	local function impactBurst(position, big)
		local holder = Instance.new("Part")
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
		holder.Transparency = 1
		holder.Size = Vector3.one * 0.2
		holder.CFrame = CFrame.new(position)
		holder.Parent = impactFolder
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(220, 30, 20))
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new(big and 1.6 or 0.8, 0)
		sparks.Lifetime = NumberRange.new(0.3, 0.6)
		sparks.Speed = NumberRange.new(big and 30 or 14, big and 60 or 28)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Drag = 3
		sparks.Rate = 0
		sparks.Parent = holder
		sparks:Emit(big and 40 or 10)
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 120, 60)
		ring.Size = Vector3.new(0.2, 1, 1)
		ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = holder
		local r = big and 26 or 7
		TweenService:Create(ring, TweenInfo.new(big and 0.6 or 0.35, Enum.EasingStyle.Quint), { Size = Vector3.new(0.2, r, r), Transparency = 1 }):Play()
		Debris:AddItem(holder, 1.2)
	end

	local function randomUnitVector()
		local v = Vector3.new(
			math.random(-100, 100),
			math.random(-100, 100),
			math.random(-100, 100)
		)
		if v.Magnitude < 0.001 then
			v = Vector3.new(0, 1, 0)
		end
		return v.Unit
	end

	local function getClosestPlayer()
		local closestChar = nil
		local shortestDistance = math.huge

		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
				local targetRoot = char:FindFirstChild("HumanoidRootPart")
				if targetRoot and rootPart and rootPart.Parent then
					local distance = (targetRoot.Position - rootPart.Position).Magnitude
					if distance < shortestDistance then
						shortestDistance = distance
						closestChar = char
					end
				end
			end
		end
		return closestChar, shortestDistance
	end

	local function fireProjectiles(targetChar)
		if entering() or not fightLive() then return end
		isFiring = true

		-- Stop walking animation while shooting
		if walkTrack and walkTrack.IsPlaying then
			walkTrack:Stop()
		end

		if humanoid and humanoid.Parent then humanoid.WalkSpeed = 0 end

		-- Start playing shooting animation
		if shootTrack then
			shootTrack:Play()
		end

		for i = 1, 24 do
			if not boss or not boss.Parent then break end

			local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
			local targetHumanoid = targetChar and targetChar:FindFirstChild("Humanoid")

			if not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
				break
			end

			local lookTarget = Vector3.new(targetRoot.Position.X, rootPart.Position.Y, targetRoot.Position.Z)
			rootPart.CFrame = CFrame.lookAt(rootPart.Position, lookTarget)

			local startPos = head.Position + (rootPart.CFrame.LookVector * 5)
			local baseAimCFrame = CFrame.lookAt(startPos, targetRoot.Position)

			local projectile = projectileTemplate:Clone()
			projectile.Anchored = false
			projectile.CanCollide = false

			local scatterX = math.rad(math.random(-SCATTER_ANGLE, SCATTER_ANGLE))
			local scatterY = math.rad(math.random(-SCATTER_ANGLE, SCATTER_ANGLE))

			local spreadCFrame = baseAimCFrame * CFrame.Angles(scatterX, scatterY, 0)
			local spreadDirection = spreadCFrame.LookVector

			projectile.CFrame = spreadCFrame
			projectile.Parent = projectileFolder

			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.Velocity = spreadDirection * PROJECTILE_SPEED
			bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			bodyVelocity.Parent = projectile

			local spinAxis = Vector3.new(
				math.random(-100, 100),
				math.random(-100, 100),
				math.random(-100, 100)
			).Unit
			local spinSpeed = SPIN_SPEED_MIN + math.random() * (SPIN_SPEED_MAX - SPIN_SPEED_MIN)

			local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
			bodyAngularVelocity.AngularVelocity = spinAxis * spinSpeed
			bodyAngularVelocity.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			bodyAngularVelocity.Parent = projectile

			local lastPos = projectile.Position
			local connection
			local hitDetected = false

			connection = RunService.Heartbeat:Connect(function()
				if hitDetected or not projectile or not projectile.Parent then
					if connection then connection:Disconnect() end
					return
				end

				local currentPos = projectile.Position
				local rayDirection = currentPos - lastPos

				if rayDirection.Magnitude > 0.01 then
					local raycastParams = RaycastParams.new()
					raycastParams.FilterDescendantsInstances = {boss, projectileFolder}
					raycastParams.FilterType = Enum.RaycastFilterType.Exclude

					local result = workspace:Raycast(lastPos, rayDirection, raycastParams)
					if result then
						hitDetected = true
						connection:Disconnect()

						local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
						if hitChar then
							local hitHumanoid = hitChar:FindFirstChildOfClass("Humanoid")
							if hitHumanoid then
								hitHumanoid:TakeDamage(PROJECTILE_DAMAGE)
							end
						end
						impactBurst(result.Position, false)
						projectile:Destroy()
					end
				end
				lastPos = currentPos
			end)

			Debris:AddItem(projectile, 5)
			task.wait(0.05)
		end

		-- Stop shooting animation
		if shootTrack and shootTrack.IsPlaying then
			shootTrack:Stop()
		end

		task.wait(0.2)
		isFiring = false
	end

	local function spawnTrackingProjectile(startCFrame, direction, speed, damage, lifetime, sizeScale, onHit)
		local projectile = projectileTemplate:Clone()
		projectile.Anchored = false
		projectile.CanCollide = false
		projectile.CFrame = startCFrame
		if sizeScale and sizeScale ~= 1 then
			projectile.Size = projectile.Size * sizeScale
		end
		projectile.Parent = projectileFolder

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Velocity = direction * speed
		bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bodyVelocity.Parent = projectile

		local spinAxis = randomUnitVector()
		local spinSpeed = SPIN_SPEED_MIN + math.random() * (SPIN_SPEED_MAX - SPIN_SPEED_MIN)
		local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
		bodyAngularVelocity.AngularVelocity = spinAxis * spinSpeed
		bodyAngularVelocity.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		bodyAngularVelocity.Parent = projectile

		local lastPos = projectile.Position
		local connection
		local hitDetected = false

		connection = RunService.Heartbeat:Connect(function()
			if hitDetected or not projectile or not projectile.Parent then
				if connection then connection:Disconnect() end
				return
			end

			local currentPos = projectile.Position
			local rayDirection = currentPos - lastPos

			if rayDirection.Magnitude > 0.01 then
				local raycastParams = RaycastParams.new()
				raycastParams.FilterDescendantsInstances = {boss, projectileFolder}
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude

				local result = workspace:Raycast(lastPos, rayDirection, raycastParams)
				if result then
					hitDetected = true
					connection:Disconnect()

					local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
					if hitChar then
						local hitHumanoid = hitChar:FindFirstChildOfClass("Humanoid")
						if hitHumanoid then
							hitHumanoid:TakeDamage(damage)
						end
					end

					local hitPosition = currentPos
					impactBurst(result.Position, sizeScale and sizeScale > 1)
					projectile:Destroy()

					if onHit then
						onHit(hitPosition)
					end
				end
			end
			lastPos = currentPos
		end)

		Debris:AddItem(projectile, lifetime)
	end

	local function explodeIntoFragments(position)
		for i = 1, FRAGMENT_COUNT do
			local direction = randomUnitVector()
			spawnTrackingProjectile(CFrame.new(position), direction, FRAGMENT_SPEED, FRAGMENT_DAMAGE, FRAGMENT_LIFETIME, 1, nil)
		end
	end

	local function fireGiantProjectile(targetChar)
		local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
		if not targetRoot then return end

		local lookTarget = Vector3.new(targetRoot.Position.X, rootPart.Position.Y, targetRoot.Position.Z)
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, lookTarget)

		-- wind-up: an orb of fire gathers in front of him first, so the big
		-- one is telegraphed rather than appearing out of nowhere
		if fightFx then fightFx:FireAllClients("Charge", head.Position + rootPart.CFrame.LookVector * 5, 0.8) end
		task.wait(0.8)
		if not targetRoot.Parent or not rootPart.Parent then return end
		lookTarget = Vector3.new(targetRoot.Position.X, rootPart.Position.Y, targetRoot.Position.Z)
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, lookTarget)

		local startPos = head.Position + (rootPart.CFrame.LookVector * 5)
		local direction = (targetRoot.Position - startPos).Unit
		local startCFrame = CFrame.lookAt(startPos, targetRoot.Position)

		spawnTrackingProjectile(startCFrame, direction, GIANT_PROJECTILE_SPEED, GIANT_PROJECTILE_DAMAGE, GIANT_PROJECTILE_LIFETIME, GIANT_PROJECTILE_SCALE, explodeIntoFragments)
	end

	local function igniteBoss()
		for _, part in ipairs(boss:GetDescendants()) do
			if part:IsA("MeshPart") and part ~= crueltyCameraPart then
				for _, template in ipairs(fireTemplates) do
					local fireClone = template:Clone()
					fireClone.Enabled = true
					fireClone.Parent = part
				end
			end
		end
	end

	local function fireNearbyCameraEvent()
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local distance = (targetRoot.Position - rootPart.Position).Magnitude
				if distance <= PHASE_TWO_CAMERA_RADIUS then
					if phaseTwoCameraEvent then
						phaseTwoCameraEvent:FireClient(player, crueltyCameraPart.CFrame, PHASE_TWO_CAMERA_DURATION)
					end
				end
			end
		end
	end

	local function triggerPhaseTwo()
		if phaseTwoTriggered then return end
		phaseTwoTriggered = true
		isPhaseTwo = true

		igniteBoss()
		-- (the old nearby-camera event is gone: CrueltyFightService runs the
		-- phase-two cinematic now)

		lastGiantProjectileTime = tick()
	end

	humanoid.HealthChanged:Connect(function(health)
		if not phaseTwoTriggered and health <= humanoid.MaxHealth * PHASE_TWO_HEALTH_FRACTION then
			triggerPhaseTwo()
		end
	end)

	local function startAI()
		if aiStarted then return end
		aiStarted = true

		task.spawn(function()
			while task.wait(0.1) do
				if not boss or not boss.Parent then break end
				if not humanoid or humanoid.Health <= 0 then break end
				if entering() then continue end
				if not fightLive() then
					-- truce: stand there and look at them
					humanoid.WalkSpeed = 0
					continue
				end

				local targetChar, distance = getClosestPlayer()

				if targetChar and not isFiring then
					local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")

					if distance <= STOP_DISTANCE then
						isStopped = true
					elseif distance > STOP_DISTANCE + RESUME_MOVE_BUFFER then
						isStopped = false
					end

					if isStopped then
						humanoid.WalkSpeed = 0
						local lookTarget = Vector3.new(targetRoot.Position.X, rootPart.Position.Y, targetRoot.Position.Z)
						rootPart.CFrame = CFrame.lookAt(rootPart.Position, lookTarget)
					else
						humanoid.WalkSpeed = DEFAULT_WALKSPEED
						humanoid:MoveTo(targetRoot.Position)
					end

					-- Play swing animation and deal melee damage
					if distance <= MELEE_RANGE and (tick() - lastMeleeTime) >= MELEE_COOLDOWN then
						lastMeleeTime = tick()

						if swingTrack then
							swingTrack:Play()
						end
						if fightFx then fightFx:FireAllClients("Slash", rootPart.CFrame, targetRoot.Position) end

						targetChar.Humanoid:TakeDamage(MELEE_DAMAGE)
					end

					if (tick() - lastRangedTime) >= 10 then
						lastRangedTime = tick()
						fireProjectiles(targetChar)
					end

					if isPhaseTwo and (tick() - lastGiantProjectileTime) >= GIANT_PROJECTILE_INTERVAL then
						lastGiantProjectileTime = tick()
						fireGiantProjectile(targetChar)
					end
				end
			end
			aiStarted = false
		end)
	end

	startAI()

else
	-- ===================================================
	-- ORIGINAL / DUMMY BOSS BEHAVIOR (MANAGER)
	-- ===================================================
	local activeClone = nil

	boss.Archivable = true
	local pristineTemplate = boss:Clone()
	pristineTemplate.Name = boss.Name .. "_Active"
	pristineTemplate:SetAttribute("IsClone", true)
	pristineTemplate:SetAttribute("FightActive", nil)

	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	task.spawn(function()
		while task.wait(1) do
			if boss:GetAttribute("FightActive") and activeClone then
				local playersAlive = false

				for _, player in ipairs(Players:GetPlayers()) do
					local char = player.Character
					if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
						local targetRoot = char:FindFirstChild("HumanoidRootPart")
						if targetRoot and rootPart and rootPart.Parent then
							local dist = (targetRoot.Position - rootPart.Position).Magnitude
							if dist < 500 then
								playersAlive = true
								break
							end
						end
					end
				end

				if not playersAlive then
					boss:SetAttribute("FightActive", false)
				end
			end
		end
	end)

	local function setDummyGhost(isGhost)
		for _, desc in ipairs(boss:GetDescendants()) do
			if desc:IsA("BasePart") then
				if isGhost then
					if desc:GetAttribute("OrigTrans") == nil then
						desc:SetAttribute("OrigTrans", desc.Transparency)
						desc:SetAttribute("OrigCollide", desc.CanCollide)
						desc:SetAttribute("OrigQuery", desc.CanQuery)
						desc:SetAttribute("OrigTouch", desc.CanTouch)
					end
					desc.Transparency = 1
					desc.CanCollide = false
					desc.CanQuery = false
					desc.CanTouch = false
				else
					if desc:GetAttribute("OrigTrans") ~= nil then
						desc.Transparency = desc:GetAttribute("OrigTrans")
						desc.CanCollide = desc:GetAttribute("OrigCollide")
						desc.CanQuery = desc:GetAttribute("OrigQuery")
						desc.CanTouch = desc:GetAttribute("OrigTouch")
					end
				end
			elseif desc:IsA("Decal") or desc:IsA("Texture") then
				if isGhost then
					if desc:GetAttribute("OrigTrans") == nil then
						desc:SetAttribute("OrigTrans", desc.Transparency)
					end
					desc.Transparency = 1
				else
					if desc:GetAttribute("OrigTrans") ~= nil then
						desc.Transparency = desc:GetAttribute("OrigTrans")
					end
				end
			elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("PointLight") or desc:IsA("SurfaceLight") or desc:IsA("SpotLight") then
				if isGhost then
					if desc:GetAttribute("OrigEnabled") == nil then
						desc:SetAttribute("OrigEnabled", desc.Enabled)
					end
					desc.Enabled = false
				else
					if desc:GetAttribute("OrigEnabled") ~= nil then
						desc.Enabled = desc:GetAttribute("OrigEnabled")
					end
				end
			end
		end

		if rootPart then
			if isGhost then
				if rootPart:GetAttribute("OrigAnchored") == nil then
					rootPart:SetAttribute("OrigAnchored", rootPart.Anchored)
				end
				rootPart.Anchored = true
			else
				if rootPart:GetAttribute("OrigAnchored") ~= nil then
					rootPart.Anchored = rootPart:GetAttribute("OrigAnchored")
				end
			end
		end
	end

	local function clearActiveClone()
		if activeClone then
			activeClone:Destroy()
			activeClone = nil
		end

		local parent = boss.Parent
		if parent then
			for _, child in ipairs(parent:GetChildren()) do
				if child ~= boss and child.Name == pristineTemplate.Name then
					child:Destroy()
				end
			end
		end
	end

	-- never visible standing about in the arena -- it spoils the drop-in reveal
	setDummyGhost(true)

	boss:GetAttributeChangedSignal("FightActive"):Connect(function()
		local isActive = boss:GetAttribute("FightActive")

		if isActive then
			if activeClone and not activeClone.Parent then
				activeClone = nil
			end

			if activeClone then return end

			activeClone = pristineTemplate:Clone()
			setDummyGhost(true)
			-- Keep him out of sight until he drops in: remember where he should
			-- land, then park the clone far overhead (anchored) before it ever
			-- appears in the arena. CrueltyFightService drops him from there.
			local cloneRoot = activeClone:FindFirstChild("HumanoidRootPart")
			if cloneRoot then
				activeClone:SetAttribute("LandRootCF", cloneRoot.CFrame)
				cloneRoot.Anchored = true
			end
			activeClone:PivotTo(activeClone:GetPivot() + Vector3.new(0, 1500, 0))
			activeClone.Parent = boss.Parent

			local cloneHumanoid = activeClone:WaitForChild("Humanoid")

			cloneHumanoid.HealthChanged:Connect(function(health)
				humanoid.Health = math.max(health, 0.1)
			end)

			cloneHumanoid.Died:Connect(function()
				local winners = {}

				for _, player in ipairs(Players:GetPlayers()) do
					local char = player.Character
					local playerRoot = char and char:FindFirstChild("HumanoidRootPart")

					if playerRoot and rootPart and rootPart.Parent then
						local distance = (playerRoot.Position - rootPart.Position).Magnitude
						-- The arena is ~160 studs end to end, so 150 meant anyone
						-- fighting from the entrance was not counted as a winner.
						-- (the title/flag is handed out by CrueltyFightService, which
						-- also leaves out anyone who died during the fight)
						local hum = char:FindFirstChildOfClass("Humanoid")
						if distance <= 400 and hum and hum.Health > 0 then
							table.insert(winners, char)
						end
					end
				end

				-- long enough for the client's VICTORY sequence to play out; it
				-- fades to black just before this so the move is hidden
				task.delay(7.2, function()
					local victoryPart = workspace:FindFirstChild("CrueltyCutscene") and workspace.CrueltyCutscene:FindFirstChild("VictoryPart")

					if victoryPart then
						for _, char in ipairs(winners) do
							if char and char:FindFirstChild("HumanoidRootPart") then
								char:PivotTo(victoryPart.CFrame * CFrame.new(0, 3, 0))
							end
						end
					end

					if boss:GetAttribute("FightActive") then
						boss:SetAttribute("FightActive", false)
					end
				end)
			end)

		else
			clearActiveClone()
			-- the stand-in stays hidden: he only ever appears by dropping in
			setDummyGhost(true)
			humanoid.Health = humanoid.MaxHealth
		end
	end)
end