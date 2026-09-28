local RunService = game:GetService("RunService")
local orbiter = script.Parent -- the Part that will orbit
local parent = orbiter.Parent.Parent -- the object to orbit around

-- FIXED values (same for every copy)
local radius = 60
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

local time = 0

RunService.Heartbeat:Connect(function(dt)
	time += dt

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
	local wobbleX = math.sin(time * wobbleSpeed + wobblePhaseX) * wobbleAmplitude
	local wobbleY = math.sin(time * wobbleSpeed * wobbleMultY + wobblePhaseY) * wobbleAmplitude
	local wobbleZ = math.sin(time * wobbleSpeed * wobbleMultZ + wobblePhaseZ) * wobbleAmplitude
	local rotation = CFrame.Angles(
		math.rad(spinX + wobbleX),
		math.rad(spinY + wobbleY),
		math.rad(spinZ + wobbleZ)
	)

	-- Move and rotate the Part directly
	orbiter.CFrame = CFrame.new(targetPosition) * rotation
end)