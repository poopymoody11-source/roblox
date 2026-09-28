--==================================================
-- LAPIS REWARD FX  (client)
--
-- When an NPC pays you in lapis (car keys, the toilet...), it doesn't just
-- appear in your inventory: the NPC spits a spray of lapis out in front of
-- it, they bounce and settle for a beat, then get sucked into you one after
-- another -- each with the normal pickup sound -- ending on a big
-- "+1000 Diamond Lapis" popup, the same look as a normal pickup.
-- Purely visual: the server already added the lapis.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local templates = ReplicatedStorage:WaitForChild("LapisVisuals")
local remote = ReplicatedStorage:WaitForChild("AccessibleEvents"):WaitForChild("LapisReward")

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local SPIT_SOUND = "rbxassetid://2772396665"
local PICK_SOUNDS = { "rbxassetid://135483737426662", "rbxassetid://72764897006138", "rbxassetid://135478009117226" }

local COLOURS = {
	normal = { Color3.fromRGB(0, 150, 255), Color3.fromRGB(0, 30, 80) },
	golden = { Color3.fromRGB(255, 215, 0), Color3.fromRGB(120, 70, 0) },
	diamond = { Color3.fromRGB(100, 200, 255), Color3.fromRGB(20, 50, 80) },
	emerald = { Color3.fromRGB(50, 255, 100), Color3.fromRGB(0, 60, 20) },
}
local function coloursFor(name)
	for key, c in pairs(COLOURS) do
		if name:find(key) then return c[1], c[2] end
	end
	return COLOURS.normal[1], COLOURS.normal[2]
end

local function prettyName(name)
	return (name:gsub("_", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end

local function playSound(id, volume, speed)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.3
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	SoundService:PlayLocalSound(s)
	task.delay(3, function() s:Destroy() end)
end

local function mouthOf(npc)
	if not npc then return nil end
	local head = npc:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.CFrame * CFrame.new(0, -0.2, -0.6)
	end
	local ok, pivot = pcall(function() return npc:GetPivot() end)
	return ok and (pivot * CFrame.new(0, 1.5, -0.8)) or nil
end

local function bigPopup(root, text, colour, stroke)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(80, 30)
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = root
	bb.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = colour
	label.Rotation = math.random(-6, 6)
	label.Parent = bb
	local st = Instance.new("UIStroke")
	st.Color = stroke
	st.Thickness = 4
	st.Parent = label
	TweenService:Create(bb, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(300, 80) }):Play()
	TweenService:Create(bb, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 7, 0) }):Play()
	task.delay(1.1, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(st, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
	task.delay(1.7, function() bb:Destroy() end)
end

local function smallPopup(pos, text, colour, stroke)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(pos)
	anchor.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(110, 36)
	bb.AlwaysOnTop = true
	bb.Adornee = anchor
	bb.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = colour
	label.Rotation = math.random(-15, 15)
	label.Parent = bb
	local st = Instance.new("UIStroke")
	st.Color = stroke
	st.Thickness = 3
	st.Parent = label
	TweenService:Create(bb, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	task.delay(0.3, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end)
	task.delay(0.7, function() anchor:Destroy() end)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundBelow(pos, ignore)
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), rayParams)
	return hit and hit.Position or (pos - Vector3.new(0, 3, 0))
end

local function play(npc, lapisName, amount)
	local template = templates:FindFirstChild(lapisName) or templates:FindFirstChild("normal_lapis")
	local mouth = mouthOf(npc)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not template or not mouth or not root then return end

	local folder = Instance.new("Folder")
	folder.Name = "LapisRewardFX"
	folder.Parent = workspace
	local colour, stroke = coloursFor(lapisName)
	local count = math.clamp(math.floor(amount / 80), 6, 14)
	local perPiece = math.floor(amount / count)

	playSound(SPIT_SOUND, 0.5, 0.8)

	-- toward the player, fanned out
	local toward = (root.Position - mouth.Position) * Vector3.new(1, 0, 1)
	toward = toward.Magnitude > 0.1 and toward.Unit or mouth.LookVector
	local ignore = { folder, char, npc }

	local pieces = {}
	for i = 1, count do
		local m = template:Clone()
		local size = m:GetExtentsSize()
		local s = 1.6 / math.max(size.X, size.Y, size.Z, 0.1)
		if math.abs(s - 1) > 0.05 then pcall(function() m:ScaleTo(s) end) end
		m:PivotTo(mouth)
		m.Parent = folder
		local spread = CFrame.Angles(0, (math.random() - 0.5) * 1.8, 0):VectorToWorldSpace(toward)
		local dist = 3.5 + math.random() * 5
		local landing = groundBelow(mouth.Position + spread * dist, ignore) + Vector3.new(0, 0.9, 0)
		table.insert(pieces, {
			m = m, from = mouth.Position, to = landing,
			delay = (i - 1) * 0.045, flight = 0.45 + math.random() * 0.2,
			spin = (math.random() - 0.5) * 20, arc = 3 + math.random() * 3,
		})
	end

	-- spit + bounce
	local t0 = os.clock()
	local conn
	local phase = "spit"
	local collectStart
	conn = RunService.RenderStepped:Connect(function()
		local now = os.clock() - t0
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local target = r and (r.Position + Vector3.new(0, 0.5, 0))
		local allDone = true
		for i, p in ipairs(pieces) do
			if p.m.Parent then
				local local_t = now - p.delay
				if phase == "spit" then
					if local_t < 0 then
						p.m:PivotTo(mouth)
						allDone = false
					else
						local u = math.min(local_t / p.flight, 1)
						local pos = p.from:Lerp(p.to, u) + Vector3.new(0, math.sin(u * math.pi) * p.arc, 0)
						-- a little bounce after landing
						if u >= 1 then
							local after = local_t - p.flight
							pos = p.to + Vector3.new(0, math.abs(math.sin(after * 9)) * math.max(0, 0.9 - after * 1.4), 0)
						end
						p.m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, local_t * p.spin, u < 1 and local_t * 8 or 0))
						if local_t < p.flight + 0.6 then allDone = false end
					end
				elseif phase == "collect" and target then
					local ct = now - collectStart - i * 0.06
					if ct < 0 then
						allDone = false
						p.m:PivotTo(CFrame.new(p.to + Vector3.new(0, math.sin(now * 3 + i) * 0.2, 0)) * CFrame.Angles(0, now * 2 + i, 0))
					else
						local u = math.min(ct / 0.35, 1)
						local e = u * u
						local pos = p.to:Lerp(target, e) + Vector3.new(0, math.sin(u * math.pi) * 1.5, 0)
						p.m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, ct * 20, 0) * CFrame.new())
						pcall(function() p.m:ScaleTo(math.max(0.05, p.m:GetScale() * (1 - dt_guard()))) end)
						if u >= 1 then
							smallPopup(target + Vector3.new((math.random() - 0.5) * 2, 1.5, 0), "+" .. perPiece, colour, stroke)
							playSound(PICK_SOUNDS[math.random(#PICK_SOUNDS)], 0.12, 0.9 + i * 0.03)
							p.m:Destroy()
						else
							allDone = false
						end
					end
				end
			end
		end
		if allDone then
			if phase == "spit" then
				phase = "collect"
				collectStart = now + 0.25
			else
				conn:Disconnect()
				local r2 = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if r2 then
					bigPopup(r2, ("+%d %s"):format(amount, prettyName(lapisName)), colour, stroke)
				end
				playSound("rbxassetid://4612374036", 0.35, 1)
				folder:Destroy()
			end
		end
	end)
	-- safety net
	task.delay(8, function()
		if conn.Connected then conn:Disconnect() end
		if folder.Parent then folder:Destroy() end
	end)
end

-- shrink pieces a touch while they fly in
function dt_guard() return 0.04 end

remote.OnClientEvent:Connect(function(npc, lapisName, amount)
	if typeof(lapisName) ~= "string" or typeof(amount) ~= "number" then return end
	task.spawn(play, npc, lapisName, amount)
end)
