local RunService = game:GetService("RunService")
local lapis = script.Parent -- Monk_lapis MODEL

local rayRig = Instance.new("Part")
rayRig.Anchored = true
rayRig.CanCollide = false
rayRig.Transparency = 0.95
rayRig.Size = Vector3.new(0.2, 0.2, 0.2)
rayRig.CFrame = lapis:GetPivot()
rayRig.Parent = lapis

local center = Instance.new("Attachment")
center.Parent = rayRig

local RAY_COUNT = 60
local MIN_RADIUS = 60
local MAX_RADIUS = 100
local goldenAngle = math.pi * (3 - math.sqrt(5))

local rays = {}

for i = 0, RAY_COUNT - 1 do
	local y = 1 - (i / (RAY_COUNT - 1)) * 2
	local radiusAtY = math.sqrt(1 - y * y)
	local theta = goldenAngle * i
	local dir = Vector3.new(math.cos(theta) * radiusAtY, y, math.sin(theta) * radiusAtY)

	local outerAttach = Instance.new("Attachment")
	outerAttach.Position = dir * MAX_RADIUS
	outerAttach.Parent = rayRig

	local beam = Instance.new("Beam")
	beam.Attachment0 = center
	beam.Attachment1 = outerAttach
	beam.Width0 = 2
	beam.Width1 = 3
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 245, 210))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1)
	})
	beam.LightEmission = 0.3
	beam.FaceCamera = true
	beam.Parent = rayRig

	table.insert(rays, {
		dir = dir,
		attachment = outerAttach,
		phase = i * 0.7
	})
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	rayRig.CFrame = rayRig.CFrame * CFrame.Angles(0, math.rad(15) * dt, 0)

	for _, ray in ipairs(rays) do
		local wave = (math.sin(elapsed * 2 + ray.phase) + 1) / 2
		local length = MIN_RADIUS + wave * (MAX_RADIUS - MIN_RADIUS)
		ray.attachment.Position = ray.dir * length
	end
end)