--==================================================
-- BOSS SCREEN SHAKE  (client)
-- ServerStorage.BossUtil.Shake(point, intensity, duration, range)
-- fires ReplicatedStorage.BossScreenShake. Strength falls off with
-- distance from the impact, decays over the duration, and is
-- applied on top of whatever the camera is doing (so cutscenes
-- and the normal follow camera both keep working).
-- Several shakes at once just add up, capped so it never gets silly.
--==================================================

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("BossScreenShake", 60)
if not remote then return end

local shakes = {}

remote.OnClientEvent:Connect(function(point, intensity, duration, range)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local dist = (cam.CFrame.Position - point).Magnitude
	local falloff = math.clamp(1 - dist / math.max(range, 1), 0, 1)
	if falloff <= 0 then return end
	if #shakes > 6 then table.remove(shakes, 1) end
	table.insert(shakes, { amp = intensity * falloff, dur = duration, t0 = os.clock(), seed = math.random() * 100 })
end)

RunService:BindToRenderStep("BossScreenShake", Enum.RenderPriority.Camera.Value + 1, function()
	if #shakes == 0 then return end
	local now = os.clock()
	local x, y, roll = 0, 0, 0
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local age = now - s.t0
		if age >= s.dur then
			table.remove(shakes, i)
		else
			local k = s.amp * (1 - age / s.dur) ^ 2
			local t = age * 28 + s.seed
			x += math.noise(t, 0, s.seed) * k
			y += math.noise(0, t, s.seed) * k
			roll += math.noise(t, t, s.seed) * k
		end
	end
	x, y, roll = math.clamp(x, -3, 3), math.clamp(y, -3, 3), math.clamp(roll, -3, 3)
	local cam = workspace.CurrentCamera
	cam.CFrame = cam.CFrame * CFrame.new(x * 0.6, y * 0.6, 0) * CFrame.Angles(math.rad(y * 1.5), math.rad(x * 1.5), math.rad(roll * 2))
end)
