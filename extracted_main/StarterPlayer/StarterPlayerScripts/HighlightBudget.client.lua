--==================================================
-- HIGHLIGHT BUDGET  (client)
--
-- Roblox only draws 31 Highlights at once; past that, random
-- ones just don't render. The map had ~65 switched on at a
-- time (tutorial stage, shop staffs, base lapis, the lapis
-- field...), so lapis outlines and staff outlines flickered
-- in and out or never showed.
--
-- This keeps the ones that matter on: whatever you're
-- holding first, then the NEAREST ones to the camera, up to
-- the limit. Everything else waits its turn. Purely local -
-- nothing on the server changes.
--==================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local BUDGET = 29          -- (a couple spare for anything Roblox itself shows)
local INTERVAL = 0.35

local tracked = {}   -- [highlight] = true

local function track(h)
	if not h:IsA("Highlight") or tracked[h] then return end
	-- remember whether it was meant to be on at all (switched-off ones stay off)
	if h:GetAttribute("HBWanted") == nil then h:SetAttribute("HBWanted", h.Enabled) end
	tracked[h] = true
	-- another script switching it later is respected
	h:GetPropertyChangedSignal("Enabled"):Connect(function()
		if h:GetAttribute("HBSetting") then return end
		h:SetAttribute("HBWanted", h.Enabled)
	end)
end

for _, d in ipairs(workspace:GetDescendants()) do track(d) end
workspace.DescendantAdded:Connect(track)

local function set(h, on)
	if h.Enabled == on then return end
	h:SetAttribute("HBSetting", true)
	h.Enabled = on
	h:SetAttribute("HBSetting", nil)
end

local function positionOf(h)
	local a = h.Adornee or h.Parent
	if not a then return nil end
	if a:IsA("BasePart") then return a.Position end
	if a:IsA("Model") then
		local ok, cf = pcall(a.GetPivot, a)
		if ok then return cf.Position end
	end
	local p = a:FindFirstAncestorWhichIsA("BasePart") or a:FindFirstChildWhichIsA("BasePart", true)
	return p and p.Position
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < INTERVAL then return end
	acc = 0
	local cam = workspace.CurrentCamera
	if not cam then return end
	local cp = cam.CFrame.Position
	local char = player.Character
	local list = {}
	for h in pairs(tracked) do
		if not h.Parent or not h:IsDescendantOf(workspace) then
			tracked[h] = nil
		elseif h:GetAttribute("HBWanted") then
			local pos = positionOf(h)
			local d = pos and (pos - cp).Magnitude or math.huge
			-- your own character / held staff always first
			if char and h:IsDescendantOf(char) then d = -1 end
			table.insert(list, { h, d })
		else
			set(h, false)
		end
	end
	table.sort(list, function(a, b) return a[2] < b[2] end)
	for i, e in ipairs(list) do
		set(e[1], i <= BUDGET)
	end
end)
