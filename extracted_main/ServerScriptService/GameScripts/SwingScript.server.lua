local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris") 

local pvpEvent = ReplicatedStorage:WaitForChild("AccessibleEvents"):WaitForChild("pvptoggle")

pvpEvent.OnServerEvent:Connect(function(player)
	-- (own a bat = PvP is on for good)
	if player:GetAttribute("PvpLocked") then player:SetAttribute("PvpEnabled", true) return end
	player:SetAttribute("PvpEnabled", not (player:GetAttribute("PvpEnabled") == true))
	print("pvp toggled for", player.Name, "to", player:GetAttribute("PvpEnabled"))
end)


local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players") -- PVP CHANGE: needed to look up the target's player

local Swing = ReplicatedStorage:WaitForChild("Swing")
local SwingVisuals = ReplicatedStorage:WaitForChild("SwingVisuals")
local SwingVfx = ReplicatedStorage:WaitForChild("AccessibleModels").RegularSwingVFX

local SwingBeam = ReplicatedStorage.AccessibleModels.SwingBeam

-- PVP CHANGE: true if this model is a player's character and that player has PvP OFF.
-- NPCs aren't players, so they are never protected.
-- Assumes the pvptoggle server handler sets the "PvpEnabled" attribute on the player.
-- PvP only happens when BOTH players have it on. Before, only the target
-- was checked, so someone with PvP OFF could still hit players who had it
-- on while being untouchable themselves.
local function isProtected(model, attacker)
	local targetPlayer = Players:GetPlayerFromCharacter(model)
	if targetPlayer == nil then return false end -- NPCs/mobs are always fair game
	if targetPlayer:GetAttribute("PvpEnabled") ~= true then return true end
	-- no PvP inside Cruelty's arena
	if targetPlayer:GetAttribute("InCrueltyArena") or (attacker and attacker:GetAttribute("InCrueltyArena")) then return true end
	-- 30s of spawn protection after respawning
	if (targetPlayer:GetAttribute("SpawnProtectedUntil") or 0) > workspace:GetServerTimeNow() then return true end
	if attacker and attacker:GetAttribute("PvpEnabled") ~= true then return true end
	return false
end

-- 1. Handle the Swing Visuals (Happens whether you hit someone or not)
SwingVisuals.OnServerEvent:Connect(function(player, currentM1, BatType)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local offset = CFrame.new(0, 0, -1)

	-- 3. Apply the tilts entirely in 3D space
	if currentM1 == 1 then
		-- FIX 2: Replaced the 2D particle rotation with a true 3D tilt
		if BatType == "VerityBat" then
			offset = offset * CFrame.Angles(0, math.rad(90), math.rad(-190)) 
		end
		offset = offset * CFrame.Angles(0, 0, math.rad(-10)) 

	elseif currentM1 == 2 then
		if BatType == "VerityBat" then
			offset = offset * CFrame.Angles(math.rad(0), math.rad(90), math.rad(0)) 
		else
			offset = offset * CFrame.Angles(0, 0, math.rad(-160)) 
		end
	elseif currentM1 == 3 then
		if BatType == "VerityBat" then
			offset = offset * CFrame.Angles(math.rad(0), math.rad(0), math.rad(-90)) 
		else
			offset = offset * CFrame.Angles(0, math.rad(180), math.rad(-90)) 
		end
	end

	if BatType == "VerityBat" then
		SwingVfx = ReplicatedStorage.AccessibleModels.UpgradedSlash
	else
		SwingVfx = ReplicatedStorage.AccessibleModels.RegularSwingVFX
	end

	if SwingVfx then
		local activeVfx = SwingVfx:Clone()

		-- FIX 1: Turn off physics so the VFX doesn't bump the player and twist the weld
		activeVfx.CanCollide = false
		activeVfx.Massless = true

		-- 1. Put it in the workspace temporarily to set it up
		activeVfx.Parent = workspace

		local weld = Instance.new("Weld")
		weld.Part0 = rootPart
		weld.Part1 = activeVfx
		weld.C1 = CFrame.new() -- Safely zero out the C1 offset
		weld.Parent = activeVfx

		-- 2. Move it 1 stud forward from that flat position


		-- 4. Apply the calculated CFrame
		weld.C0 = offset

		-- 5. Give the client a fraction of a second to load the part
		task.wait(0.05)

		-- 6. Emit the particles
		for _, child in ipairs(activeVfx:GetDescendants()) do
			if child:IsA("ParticleEmitter") then



				-- Reset the 2D texture rotation back to 0 so it stays perfectly aligned with the 3D Part
				if currentM1 == 2 and BatType == "VerityBat" then
					child.Rotation = NumberRange.new(-90)
				end


				if currentM1 == 3 then
					child.Rotation = NumberRange.new(180)
				end


				child:Emit(5) 
				print("vfx")
			end
		end

		-- 7. Clean it up
		Debris:AddItem(activeVfx, 1)
	end

	-- 2. Beam VFX — new
	if BatType == "VerityBat" then
		local beamclone = SwingBeam:Clone()

		-- Same reasoning as FIX 1 on the particle VFX: don't let the rig physically bump the player
		for _, part in ipairs(beamclone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Massless = true
			end
		end

		local primary = beamclone:WaitForChild("primary")
		local weld = Instance.new("Weld")
		weld.Part0 = rootPart
		weld.Part1 = primary
		weld.C0 = offset -- FIX: this was never set, so the beam had no offset at all
		weld.C1 = CFrame.new()
		weld.Parent = primary

		beamclone.Parent = workspace

		-- Capture each beam's Studio-authored width/transparency as the "fully visible" target,
		-- then start it at zero width / fully transparent so it can fade in
		local beams = {}
		for _, descendant in ipairs(beamclone:GetDescendants()) do
			if descendant:IsA("Beam") then
				table.insert(beams, {
					beam = descendant,
					targetWidth0 = descendant.Width0,
					targetWidth1 = descendant.Width1,
					targetTransparency = descendant.Transparency,
				})
				descendant.Width0 = 0
				descendant.Width1 = 0
				descendant.Transparency = NumberSequence.new(1)
				descendant.Enabled = true
			end
		end

		local LIFETIME = 0.5
		local FADE_IN = 0.15
		local FADE_OUT = 0.2
		local ROTATION_SPEED = 720 -- degrees/second, spins around the beam's own forward axis

		local elapsed = 0
		local connection
		connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt

			-- Spin by updating the weld's offset, not the model's CFrame directly —
			-- that way it doesn't fight the weld constraint every physics step
			local spinAngle = math.rad(ROTATION_SPEED * elapsed)
			if currentM1 == 1 then
				weld.C0 = offset * CFrame.Angles(math.rad(180), spinAngle, 0)
			else
				weld.C0 = offset * CFrame.Angles(math.rad(180), spinAngle, 0)
			end
			-- Ease in over FADE_IN, hold at full, ease out over the final FADE_OUT
			local alpha
			if elapsed < FADE_IN then
				alpha = TweenService:GetValue(elapsed / FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			elseif elapsed > LIFETIME - FADE_OUT then
				local t = (elapsed - (LIFETIME - FADE_OUT)) / FADE_OUT
				alpha = 1 - TweenService:GetValue(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			else
				alpha = 1
			end

			for _, data in ipairs(beams) do
				data.beam.Width0 = data.targetWidth0 * alpha
				data.beam.Width1 = data.targetWidth1 * alpha

				-- Rebuild the NumberSequence by hand each frame, pushing every keypoint
				-- toward fully transparent as alpha shrinks
				local newKeypoints = {}
				for i, keypoint in ipairs(data.targetTransparency.Keypoints) do
					newKeypoints[i] = NumberSequenceKeypoint.new(keypoint.Time, 1 - (1 - keypoint.Value) * alpha)
				end
				data.beam.Transparency = NumberSequence.new(newKeypoints)
			end

			if elapsed >= LIFETIME or not beamclone.Parent then
				connection:Disconnect()
			end
		end)

		Debris:AddItem(beamclone, LIFETIME)
	end
end)

-- 2. Handle the Damage (Only happens when you hit an enemy)
Swing.OnServerEvent:Connect(function(player, enemyRoot, currentM1, BatType)
	-- PVP CHANGE: return at the very start if the target is a player with PvP off
	if typeof(enemyRoot) ~= "Instance" or not enemyRoot.Parent or isProtected(enemyRoot.Parent, player) then return end

	local character = player.Character
	if not character or not (character:FindFirstChild("Bat") or character:FindFirstChild("VerityBat")) then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not enemyRoot then return end

	local isBoss = enemyRoot.Parent.Name == "Cruelty_Active"
	if isBoss then
		-- Cruelty is huge: measure to the edge of his body, flat, with a generous reach
		local ok, size = pcall(function() return enemyRoot.Parent:GetExtentsSize() end)
		local bodyR = ok and math.min(math.max(size.X, size.Z) * 0.5, 12) or 4
		local off = enemyRoot.Position - rootPart.Position
		local flatDist = Vector3.new(off.X, 0, off.Z).Magnitude - bodyR
		local reach = (BatType == "VerityBat") and 28 or 23
		if flatDist > reach or math.abs(off.Y) > 45 then return end
	else
		if BatType == "Bat" and (rootPart.Position - enemyRoot.Position).Magnitude > 10 then
			return 
		end
		if BatType == "VerityBat" and (rootPart.Position - enemyRoot.Position).Magnitude > 18 then
			return
		end
	end


	local enemyModel = enemyRoot.Parent
	local enemyHumanoid = enemyModel and enemyModel:FindFirstChildOfClass("Humanoid")

	if enemyHumanoid and enemyHumanoid.Health > 0 then
		-- Deal Damage
		if BatType == "Bat" then
			enemyHumanoid:TakeDamage(15)
		else
			enemyHumanoid:TakeDamage(25)
		end

		-- === KNOCKBACK LOGIC ===
		-- 1. Get the direction from the player to the enemy
		local knockbackDirection = (enemyRoot.Position - rootPart.Position).Unit

		-- 2. Define the strength of the knockback
		local horizontalPower = 45 -- How far back they are pushed
		local verticalPower = 20   


		if currentM1 == 3 or isBoss then
			horizontalPower = 0 -- How far back they are pushed
			verticalPower = 0   -- How high they are popped into the air
		end
		if isBoss then return end -- don't shove the boss around (made his hitbox jumpy)


		-- 3. Apply the velocity
		enemyRoot.AssemblyLinearVelocity = Vector3.new(
			knockbackDirection.X * horizontalPower, 
			verticalPower, 
			knockbackDirection.Z * horizontalPower
		)
	end
end)




local GroundSlam = ReplicatedStorage:WaitForChild("GroundSlam")
local GroundSlamVisual = ReplicatedStorage:WaitForChild("GroundSlamVisual")
local SlamVFX = ReplicatedStorage.AccessibleModels.SlamVFX

local FORWARD_OFFSET = 6.5     -- how far in front of the player the slam lands
local SLAM_RADIUS = 5
local SLAM_DAMAGE = 25
local SLAM_KNOCKBACK = 125
local SLAM_UP_POWER = 100

local RING_CUBE_COUNT = 14
local RING_RADIUS = 4.5
local MAX_HEIGHT_DIFF = 2     -- studs of tolerance before a ring spot counts as "no room"

-- Raycasts straight down from just above worldPos to find the ground there
local function raycastGround(worldPos, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return workspace:Raycast(worldPos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), params)
end


local function applyKnockback(rootPart, velocity, duration)
	duration = duration or 0.15

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Velocity = velocity
	bodyVelocity.Parent = rootPart

	Debris:AddItem(bodyVelocity, duration)
end

GroundSlam.OnServerEvent:Connect(function(player, BatType)
	local character = player.Character
	if not character or not (character:FindFirstChild("Bat") or character:FindFirstChild("VerityBat")) then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local exclude = { character }

	-- VerityBat's ground slam is twice the size and twice the stats
	local sizeMultiplier = (BatType == "VerityBat") and 2 or 1
	local slamRadius = SLAM_RADIUS * sizeMultiplier
	local slamDamage = SLAM_DAMAGE * sizeMultiplier
	local slamKnockback = SLAM_KNOCKBACK * sizeMultiplier
	local slamUpPower = SLAM_UP_POWER * sizeMultiplier
	local ringRadius = RING_RADIUS * sizeMultiplier
	local ringCubeCount = math.floor(RING_CUBE_COUNT * sizeMultiplier)

	-- 1. Find where the weapon actually lands: in front of the player, on the ground
	local forwardPoint = rootPart.Position + rootPart.CFrame.LookVector * FORWARD_OFFSET
	local mainHit = raycastGround(forwardPoint, exclude)

	if not mainHit then
		-- nothing in front of them (ledge, gap) — slam at their feet instead
		mainHit = raycastGround(rootPart.Position, exclude)
	end

	if not mainHit then return end -- no ground anywhere reasonable; nothing to slam

	local slamPosition = mainHit.Position
	local groundY = slamPosition.Y

	-- 2. Sample the ground's material and color
	local hitInstance = mainHit.Instance
	local material = mainHit.Material
	local color
	if hitInstance:IsA("Terrain") then
		color = workspace.Terrain:GetMaterialColor(material)
	else
		color = hitInstance.Color
	end

	-- 3. AOE damage + knockback, centered on the actual slam point
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = exclude

	local nearbyParts = workspace:GetPartBoundsInRadius(slamPosition, slamRadius, overlapParams)
	local hitHumanoids = {}

	for _, part in ipairs(nearbyParts) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local enemyRoot = model and model:FindFirstChild("HumanoidRootPart")

		-- PVP CHANGE: skip players whose PvP is off (no damage, no knockback)
		if humanoid and enemyRoot and not hitHumanoids[humanoid] and not isProtected(model, player) then
			hitHumanoids[humanoid] = true

			local offset = enemyRoot.Position - slamPosition
			local distance = offset.Magnitude
			local falloff = math.clamp(1 - (distance / slamRadius), 0.25, 1)

			humanoid:TakeDamage(slamDamage * falloff)

			local flatDir = Vector3.new(offset.X, 0, offset.Z)
			flatDir = flatDir.Magnitude > 0 and flatDir.Unit or Vector3.new(1, 0, 0)

			if model.Name ~= "Cruelty_Active" then applyKnockback(enemyRoot, Vector3.new(
				flatDir.X * slamKnockback * falloff,
				slamUpPower * falloff,
				flatDir.Z * slamKnockback * falloff
				)) end
		end
	end

	-- 4. Check the ring has room, sized to match this slam
	local ringPositions = {}
	for i = 1, ringCubeCount do
		local angle = (i / ringCubeCount) * math.pi * 2
		local spotOffset = Vector3.new(math.cos(angle) * ringRadius, 0, math.sin(angle) * ringRadius)
		local spotHit = raycastGround(slamPosition + spotOffset, exclude)

		if spotHit and math.abs(spotHit.Position.Y - groundY) <= MAX_HEIGHT_DIFF then
			table.insert(ringPositions, spotHit.Position)
		end
	end

	-- 5. Tell every client where, what material/color, and which spots are valid
	GroundSlamVisual:FireAllClients(slamPosition, material, color, ringPositions)

	-- 6. VerityBat only: clone the impact VFX part at the slam spot
	if BatType == "VerityBat" and SlamVFX then
		local slamVfxClone = SlamVFX:Clone()
		slamVfxClone.CanCollide = false
		slamVfxClone.Massless = true
		slamVfxClone.CFrame = CFrame.new(slamPosition.X, slamPosition.Y + 0.2, slamPosition.Z)
		slamVfxClone.Parent = workspace
		task.wait(0.05)
		for _, v in ipairs(slamVfxClone:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount") or 1)
			end
		end

		Debris:AddItem(slamVfxClone, 3) -- tune to however long SlamVFX's own effect runs
	end
end)