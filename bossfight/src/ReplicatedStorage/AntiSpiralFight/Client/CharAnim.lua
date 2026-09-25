--==================================================
-- CHARACTER ANIMATION (client)
-- Keyframed poses on a real R6 character, played on every client
-- (the server announces each parry, so everyone sees everyone's).
-- Poses use the cutscene's convention (Kit.Poses): rotations for
-- Root / Neck / RS / LS / RH / LH, in the joint's parent space.
-- They're written into Motor6D.Transform after the Animator runs,
-- blended in and out over the default animations.
--==================================================
local RunService = game:GetService("RunService")

local CA = {}

local JOINTS = {
	Root = { "HumanoidRootPart", "RootJoint" },
	Neck = { "Torso", "Neck" },
	RS = { "Torso", "Right Shoulder" },
	LS = { "Torso", "Left Shoulder" },
	RH = { "Torso", "Right Hip" },
	LH = { "Torso", "Left Hip" },
}

local playing = {} -- [character] = { Keys, T0, Dur, Motors }
local K

local function motors(char)
	local out = {}
	for key, path in pairs(JOINTS) do
		local p = char:FindFirstChild(path[1])
		local m = p and p:FindFirstChild(path[2])
		if m and m:IsA("Motor6D") then out[key] = m end
	end
	return out
end

-- keys: { { t, pose }, ... } (t in seconds from the start); fade: blend in/out time
function CA.play(char, keys, fade)
	if not char then return end
	local ms = motors(char)
	if not ms.Root then return end
	playing[char] = { Keys = keys, T0 = os.clock(), Dur = keys[#keys][1], Motors = ms, Fade = fade or 0.08 }
end

local IDENT = CFrame.new()
local function sample(keys, t)
	if t <= keys[1][1] then return keys[1][2], keys[1][2], 0 end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b[1] then
			local u = (t - a[1]) / math.max(b[1] - a[1], 1e-3)
			return a[2], b[2], K.E.inOutSine(u)
		end
	end
	return keys[#keys][2], keys[#keys][2], 0
end

function CA.init(kit)
	K = kit
	-- (after the Animator has written this frame's Transforms)
	RunService.Stepped:Connect(function()
		local now = os.clock()
		for char, P in pairs(playing) do
			local t = now - P.T0
			if t > P.Dur or not char.Parent then
				playing[char] = nil
			else
				local w = math.min(1, t / P.Fade, (P.Dur - t) / P.Fade)
				local a, b, u = sample(P.Keys, t)
				for key, m in pairs(P.Motors) do
					local ra, rb = a[key] or IDENT, b[key] or IDENT
					local rot = ra:Lerp(rb, u)
					-- (the pose is C0-relative, as Kit applies it: conjugate into Transform)
					local base = m.C0.Rotation
					local want = base:Inverse() * rot * base
					m.Transform = m.Transform:Lerp(want, w)
				end
			end
		end
	end)
end

--------------------------------------------------------------------------
-- the moves
--------------------------------------------------------------------------
local A = function(x, y, z) return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0)) end

-- a one-handed parry: palm thrust out, body turned into it
CA.Deflect = {
	{ 0, { Root = A(0, 20, 0), RS = A(30, 0, 40), LS = A(-10, 0, -20), RH = A(-10, 0, 0), LH = A(12, 0, 0) } },
	{ 0.07, { Root = A(-8, -35, 0), Neck = A(0, 25, 0), RS = A(95, 0, -15), LS = A(-35, 0, -30), RH = A(-25, 0, 6), LH = A(20, 0, -6) } },
	{ 0.3, { Root = A(-6, -30, 0), Neck = A(0, 22, 0), RS = A(92, 0, -10), LS = A(-30, 0, -28), RH = A(-22, 0, 6), LH = A(18, 0, -6) } },
	{ 0.5, {} },
}

-- a chord: arms crossed to take it... then thrown open, blasting it back
CA.Guard = {
	{ 0, { Root = A(10, 0, 0), RS = A(100, 0, -45), LS = A(100, 0, 45), RH = A(25, 0, 8), LH = A(-20, 0, -8) } },
	{ 0.12, { Root = A(14, 0, 0), Neck = A(-10, 0, 0), RS = A(95, 0, -55), LS = A(95, 0, 55), RH = A(35, 0, 10), LH = A(-25, 0, -10) } },
	{ 0.22, { Root = A(-12, 0, 0), Neck = A(12, 0, 0), RS = A(90, 0, 70), LS = A(90, 0, -70), RH = A(-20, 0, 14), LH = A(20, 0, -14) } },
	{ 0.55, { Root = A(-8, 0, 0), Neck = A(8, 0, 0), RS = A(85, 0, 60), LS = A(85, 0, -60), RH = A(-15, 0, 12), LH = A(15, 0, -12) } },
	{ 0.8, {} },
}

-- a perfect one: a spinning backhand
CA.Spin = {
	{ 0, { Root = A(0, 60, 0), RS = A(20, 0, 60), LS = A(20, 0, -40) } },
	{ 0.1, { Root = A(-5, -80, 0), RS = A(90, 0, 90), LS = A(30, 0, -80), RH = A(-15, 0, 10), LH = A(15, 0, -10) } },
	{ 0.2, { Root = A(-5, -170, 0), RS = A(90, 0, 60), LS = A(40, 0, -90), RH = A(-10, 0, 10), LH = A(10, 0, -10) } },
	{ 0.45, { Root = A(-3, -180, 0), Neck = A(0, 20, 0), RS = A(80, 0, 40), LS = A(20, 0, -60) } },
	{ 0.65, {} },
}

-- hit: knocked reeling
CA.Reel = {
	{ 0, {} },
	{ 0.06, { Root = A(28, 0, 8), Neck = A(-30, 0, 0), RS = A(60, 0, 70), LS = A(50, 0, -80), RH = A(-30, 0, 10), LH = A(25, 0, -10) } },
	{ 0.35, { Root = A(15, 0, 4), Neck = A(-12, 0, 0), RS = A(30, 0, 40), LS = A(30, 0, -40), RH = A(-10, 0, 6), LH = A(10, 0, -6) } },
	{ 0.6, {} },
}

-- the roll: tucked up, heels over head (a quarter turn per key, so it turns all the way round)
CA.Roll = {
	{ 0, { Root = A(0, 0, 0), RS = A(60, 0, 20), LS = A(60, 0, -20), RH = A(40, 0, 0), LH = A(40, 0, 0) } },
	{ 0.09, { Root = A(-90, 0, 0), Neck = A(-30, 0, 0), RS = A(120, 0, 10), LS = A(120, 0, -10), RH = A(95, 0, 0), LH = A(95, 0, 0) } },
	{ 0.18, { Root = A(-180, 0, 0), Neck = A(-30, 0, 0), RS = A(120, 0, 10), LS = A(120, 0, -10), RH = A(100, 0, 0), LH = A(100, 0, 0) } },
	{ 0.27, { Root = A(-270, 0, 0), Neck = A(-30, 0, 0), RS = A(120, 0, 10), LS = A(120, 0, -10), RH = A(95, 0, 0), LH = A(95, 0, 0) } },
	{ 0.36, { Root = A(-355, 0, 0), RS = A(70, 0, 20), LS = A(70, 0, -20), RH = A(40, 0, 0), LH = A(20, 0, 0) } },
	{ 0.48, {} },
}

-- the spiral punch: a wind-up, then a lunging straight right that twists through
CA.Punch = {
	{ 0, { Root = A(0, 25, 0), RS = A(-35, 0, 25), LS = A(40, 0, -30), RH = A(-10, 0, 0), LH = A(15, 0, 0) } },
	{ 0.07, { Root = A(-6, 35, 0), Neck = A(0, -20, 0), RS = A(-45, 0, 30), LS = A(55, 0, -35), RH = A(-15, 0, 4), LH = A(20, 0, -4) } },
	{ 0.13, { Root = A(-14, -40, 0), Neck = A(0, 30, 0), RS = A(95, 0, -8), LS = A(-30, 0, -40), RH = A(-30, 0, 6), LH = A(25, 0, -6) } },
	{ 0.3, { Root = A(-10, -35, 0), Neck = A(0, 26, 0), RS = A(92, 0, -6), LS = A(-25, 0, -35), RH = A(-25, 0, 6), LH = A(20, 0, -6) } },
	{ 0.42, {} },
}
-- (and its mirror, for the combo)
CA.Punch2 = {
	{ 0, { Root = A(0, -25, 0), LS = A(-35, 0, -25), RS = A(40, 0, 30), LH = A(-10, 0, 0), RH = A(15, 0, 0) } },
	{ 0.07, { Root = A(-6, -35, 0), Neck = A(0, 20, 0), LS = A(-45, 0, -30), RS = A(55, 0, 35), LH = A(-15, 0, -4), RH = A(20, 0, 4) } },
	{ 0.13, { Root = A(-14, 40, 0), Neck = A(0, -30, 0), LS = A(95, 0, 8), RS = A(-30, 0, 40), LH = A(-30, 0, -6), RH = A(25, 0, 6) } },
	{ 0.3, { Root = A(-10, 35, 0), Neck = A(0, -26, 0), LS = A(92, 0, 6), RS = A(-25, 0, 35), LH = A(-25, 0, -6), RH = A(20, 0, 6) } },
	{ 0.42, {} },
}

-- knocked flat by something big
CA.Blasted = {
	{ 0, {} },
	{ 0.06, { Root = A(55, 0, 12), Neck = A(-40, 0, 0), RS = A(150, 0, 70), LS = A(140, 0, -80), RH = A(-40, 0, 20), LH = A(30, 0, -20) } },
	{ 0.6, { Root = A(40, 0, 8), Neck = A(-25, 0, 0), RS = A(120, 0, 60), LS = A(110, 0, -60), RH = A(-20, 0, 12), LH = A(20, 0, -12) } },
	{ 0.95, {} },
}

return CA
