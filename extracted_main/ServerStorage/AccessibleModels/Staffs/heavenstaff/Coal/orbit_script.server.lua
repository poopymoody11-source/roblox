local RunService = game:GetService("RunService")
local orbiter = script.Parent -- The Part that will orbit
local parent = orbiter.Parent:WaitForChild("Spin") -- Using WaitForChild prevents replication errors

-- PERFORMANCE FIX: Ensure the orbiter doesn't fight Roblox's physics engine
if orbiter:IsA("BasePart") then
	orbiter.Anchored = true
	orbiter.CanCollide = false
end

-- FIXED values (same for every copy)
local radius = 10
local speedTheta = 60
local speedPhi = 40
local spinSpeedX = 40
local spinSpeedY = 60
local spinSpeedZ = 25

-- Random generator, auto-seeded per instance
local rng = Random.new()

-- Randomized starting angles
local theta = rng:NextNumber(0, 360)
local phi = rng:NextNumber(0, 360)
local spinX = rng:NextNumber(0, 360)
local spinY = rng:NextNumber(0, 360)
local spinZ = rng:NextNumber(0, 360)

-- Randomized wobble
local wobbleAmplitude = rng:NextNumber(5, 30)
local wobbleSpeed = rng:NextNumber(0.5, 4)
local wobblePhaseX = rng:NextNumber(0, math.pi * 2)
local wobblePhaseY = rng:NextNumber(0, math.pi * 2)
local wobblePhaseZ = rng:NextNumber(0, math.pi * 2)
local wobbleMultY = rng:NextNumber(1.0, 1.6)
local wobbleMultZ = rng:NextNumber(0.4, 1.0)

local elapsedTime = 0 

-- JITTER FIX: Changed from Heartbeat to PreRender (or RenderStepped) to sync with screen refresh
local updateSignal = RunService:IsClient() and RunService.PreRender or RunService.Heartbeat

updateSignal:Connect(function(dt)
	-- Fallback check to prevent errors if the parent part is destroyed
	if not parent or not parent:IsA("BasePart") then return end

	elapsedTime += dt

	-- Orbit position
	theta = (theta + speedTheta * dt) % 360
	phi = (phi + speedPhi * dt) % 360

	local thetaRad = math.rad(theta)
	local phiRad = math.rad(phi)

	local offset = Vector3.new(
		radius * math.sin(phiRad) * math.cos(thetaRad),
		radius * math.cos(phiRad),
		radius * math.sin(phiRad) * math.sin(thetaRad)
	)

	local targetPosition = parent.Position + offset

	-- Spin + wobble rotation
	spinX = (spinX + spinSpeedX * dt) % 360
	spinY = (spinY + spinSpeedY * dt) % 360
	spinZ = (spinZ + spinSpeedZ * dt) % 360

	local wobbleX = math.sin(elapsedTime * wobbleSpeed + wobblePhaseX) * wobbleAmplitude
	local wobbleY = math.sin(elapsedTime * wobbleSpeed * wobbleMultY + wobblePhaseY) * wobbleAmplitude
	local wobbleZ = math.sin(elapsedTime * wobbleSpeed * wobbleMultZ + wobblePhaseZ) * wobbleAmplitude

	-- Order of multiplication matters for angles to prevent gimbal lock jitter
	local rotation = CFrame.Angles(0, math.rad(spinY + wobbleY), 0)
		* CFrame.Angles(math.rad(spinX + wobbleX), 0, 0)
		* CFrame.Angles(0, 0, math.rad(spinZ + wobbleZ))

	-- Move and rotate the Part directly
	orbiter.CFrame = CFrame.new(targetPosition) * rotation
end)
