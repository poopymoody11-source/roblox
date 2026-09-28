--==================================================
-- SPEED'S OBBY  (the car-key quest)
--   * red neon = reset to the start
--   * blue platform slides side to side
--   * a laser sweeps the round platform -- jump it
--   * pink tiles vanish a moment after you land on them
--   * falling off sends you back to the start (not the void)
--==================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local obby = script.Parent
local start = obby:WaitForChild("Start")

local function sendBack(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or character:GetAttribute("_ObbyReset") then return end
	character:SetAttribute("_ObbyReset", true)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(start.CFrame + Vector3.new(0, 4, 0))
	task.delay(0.5, function() character:SetAttribute("_ObbyReset", nil) end)
end

-- sliding platform (velocity set so you ride along with it)
local movers = {}
for _, p in ipairs(obby:GetChildren()) do
	if p:GetAttribute("SlideAxis") then
		table.insert(movers, { part = p, home = p.CFrame, axis = p:GetAttribute("SlideAxis"),
			dist = p:GetAttribute("SlideDist") or 6, period = (p:GetAttribute("SlideTime") or 1.6) * 2 })
	end
end
local spinners = {}
for _, p in ipairs(obby:GetChildren()) do
	if p:GetAttribute("SpinSpeed") then
		table.insert(spinners, { part = p, home = p.CFrame, speed = p:GetAttribute("SpinSpeed") })
	end
end

local t = 0
RunService.Heartbeat:Connect(function(dt)
	t += dt
	for _, m in ipairs(movers) do
		local w = 2 * math.pi / m.period
		local offset = math.sin(t * w) * m.dist
		m.part.CFrame = m.home + m.axis * offset
		m.part.AssemblyLinearVelocity = m.axis * (math.cos(t * w) * m.dist * w)
	end
	for _, s in ipairs(spinners) do
		s.part.CFrame = s.home * CFrame.Angles(0, t * s.speed, 0)
	end
end)

-- kill parts are polled (a part moved by CFrame doesn't fire Touched reliably)
local killers = {}
for _, p in ipairs(obby:GetChildren()) do
	if p:GetAttribute("ObbyKill") then table.insert(killers, p) end
end
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
task.spawn(function()
	while true do
		local chars = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character then table.insert(chars, plr.Character) end
		end
		params.FilterDescendantsInstances = chars
		if #chars > 0 then
			for _, k in ipairs(killers) do
				for _, hit in ipairs(workspace:GetPartsInPart(k, params)) do
					local ch = hit:FindFirstAncestorOfClass("Model")
					if ch and Players:GetPlayerFromCharacter(ch) then sendBack(ch) end
				end
			end
		end
		task.wait(0.08)
	end
end)

-- vanishing tiles
for _, p in ipairs(obby:GetChildren()) do
	if p:GetAttribute("FadeTile") then
		local busy = false
		p.Touched:Connect(function(hit)
			if busy or not Players:GetPlayerFromCharacter(hit.Parent) then return end
			busy = true
			task.wait(1.1) -- (easier: more time to step off)
			TweenService:Create(p, TweenInfo.new(0.15), { Transparency = 0.85 }):Play()
			p.CanCollide = false
			task.wait(1.6)
			p.CanCollide = true
			TweenService:Create(p, TweenInfo.new(0.2), { Transparency = 0 }):Play()
			busy = false
		end)
	end
end
