--==================================================
-- BOSS MINIONS -- bee flight animation (client)
-- Minions are welded models (no Motor6Ds), so an uploaded
-- Animation can't bend them. This fakes the bee anim on each
-- client: wings flutter fast and the body bobs + tilts forward
-- while moving, slower hover when idle. Only for minions within
-- 250 studs. Server side: Summon tags them "BossMinion".
--==================================================

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local rigs = {} -- [minion] = { wing = Weld, wingC0, body = Weld, bodyC0, root, humanoid, phase }

local function setup(minion)
	local root = minion:FindFirstChild("HumanoidRootPart")
	local hum = minion:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	local wingWeld, bodyWeld
	for _, d in ipairs(minion:GetDescendants()) do
		if d:IsA("Weld") then
			if d.Parent and d.Parent.Name == "Wings" and d.Part1 and d.Part1 ~= d.Parent then wingWeld = d end
			if d.Part1 == root and d.Part0 and d.Part0.Name == "Thorn" then bodyWeld = d end
		end
	end
	rigs[minion] = {
		wing = wingWeld, wingC0 = wingWeld and wingWeld.C0,
		body = bodyWeld, bodyC0 = bodyWeld and bodyWeld.C0,
		root = root, humanoid = hum, phase = math.random() * 10,
	}
end

CollectionService:GetInstanceAddedSignal("BossMinion"):Connect(setup)
CollectionService:GetInstanceRemovedSignal("BossMinion"):Connect(function(m) rigs[m] = nil end)
for _, m in ipairs(CollectionService:GetTagged("BossMinion")) do setup(m) end

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	local t = os.clock()
	for minion, r in pairs(rigs) do
		if not minion.Parent or not r.root.Parent then
			rigs[minion] = nil
		elseif r.humanoid.Health > 0 and (not camPos or (camPos - r.root.Position).Magnitude < 250) then
			local moving = r.humanoid.MoveDirection.Magnitude > 0.1 or r.root.AssemblyLinearVelocity.Magnitude > 2
			local tt = t + r.phase
			if r.wing and r.wingC0 then
				local flap = math.sin(tt * (moving and 60 or 30)) * (moving and 0.35 or 0.2)
				r.wing.C0 = r.wingC0 * CFrame.Angles(0, 0, flap)
			end
			if r.body and r.bodyC0 then
				local bob = math.sin(tt * (moving and 8 or 3)) * (moving and 0.45 or 0.3)
				local lean = moving and math.rad(12) or 0
				r.body.C0 = r.bodyC0 * CFrame.new(0, bob, 0) * CFrame.Angles(lean, 0, math.sin(tt * 4) * 0.08)
			end
		end
	end
end)
