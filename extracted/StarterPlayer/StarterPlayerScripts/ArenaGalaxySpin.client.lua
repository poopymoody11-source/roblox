-- turns the gold arena's layered galaxies (GoldFloor.GoldDepth), each at its own speed,
-- so looking down into the floor you see depth moving against depth
local RunService = game:GetService("RunService")
local depth = workspace:WaitForChild("BossFight", math.huge):WaitForChild("GalaxyRealm", math.huge):WaitForChild("GoldFloor", math.huge):WaitForChild("GoldDepth", 30)
-- (math.huge: the cutscene holds the arena off-stage until the landing, so this waits quietly)
if not depth then return end
local layers = {}
for _, p in ipairs(depth:GetChildren()) do
	local s = p:GetAttribute("Spin")
	if p:IsA("BasePart") and s and s ~= 0 then
		table.insert(layers, { P = p, Home = p.CFrame, Spin = s })
	end
end
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for _, L in ipairs(layers) do
		L.P.CFrame = L.Home * CFrame.Angles(0, t * L.Spin, 0)
	end
end)
