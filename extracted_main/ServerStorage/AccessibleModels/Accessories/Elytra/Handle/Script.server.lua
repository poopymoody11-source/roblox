--==================================================
-- ELYTRA FLIGHT  (SERVER)
--
-- One copy of this runs per equipped Elytra, with its
-- own ToggleFlightEvent and UpdateMovementEvent, so the
-- remotes are already scoped to a single player.
--==================================================

local Players = game:GetService("Players")

local flightSystem = script.Parent
local toggleEvent = flightSystem:WaitForChild("ToggleFlightEvent")
local movementEvent = flightSystem:WaitForChild("UpdateMovementEvent")

local FLY_SPEED = 60 
local DIVE_TILT = math.rad(-78) -- how flat the body lies while moving (superman)
local flyingPlayers = {}

-- Wind streaks off both hands while flying (server-side so
-- everyone sees them).
local function addTrails(character)
	local made = {}
	for _, limbName in ipairs({ "Left Arm", "Right Arm", "LeftHand", "RightHand" }) do
		local limb = character:FindFirstChild(limbName)
		if limb and limb:IsA("BasePart") then
			local a0 = Instance.new("Attachment")
			a0.Name = "ElytraTrailA"
			a0.Position = Vector3.new(0, -limb.Size.Y / 2, 0.25)
			a0.Parent = limb
			local a1 = Instance.new("Attachment")
			a1.Name = "ElytraTrailB"
			a1.Position = Vector3.new(0, -limb.Size.Y / 2, -0.25)
			a1.Parent = limb
			local trail = Instance.new("Trail")
			trail.Name = "ElytraTrail"
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.45
			trail.MinLength = 0.1
			trail.FaceCamera = true
			trail.LightEmission = 0.8
			trail.Color = ColorSequence.new(Color3.fromRGB(255, 250, 220), Color3.fromRGB(240, 232, 103))
			trail.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
			trail.WidthScale = NumberSequence.new(1, 0)
			trail.Parent = limb
			table.insert(made, a0)
			table.insert(made, a1)
			table.insert(made, trail)
		end
	end
	return made
end

--==================================================
-- FLIGHT POSE (superman)
-- Posed on the server by rotating the R6 joints' C0, so
-- every player sees it (client-side poses don't replicate).
-- Angles are degrees in torso space: +X swings a limb
-- forward (an arm at +180 points straight past the head),
-- +Z swings a right limb outward.
--==================================================

local TweenService = game:GetService("TweenService")

local POSES = {
	-- moving: body is laid flat along the flight path, so this reads
	-- as one fist punched forward, the other arm swept back, legs
	-- together with one knee slightly bent, head up to look ahead
	Dive = {
		["Right Shoulder"] = { 172, 0, -8 },
		["Left Shoulder"]  = { -12, 0, -18 },
		["Right Hip"]      = { -4, 0, -3 },
		["Left Hip"]       = { 14, 0, 3 },
		["Neck"]           = { 50, 0, 0 },
	},
	-- hovering upright: arms loose and out for balance, legs dangling
	Hover = {
		["Right Shoulder"] = { 18, 0, 28 },
		["Left Shoulder"]  = { 12, 0, -28 },
		["Right Hip"]      = { 12, 0, 6 },
		["Left Hip"]       = { -6, 0, -6 },
		["Neck"]           = { -8, 0, 0 },
	},
}

local poseState = {} -- [player] = { Originals = {[joint]=C0}, Current = "Dive"/"Hover" }

local function getJoints(character)
	local torso = character:FindFirstChild("Torso")
	local joints = {}
	if not torso then return joints end
	for name in pairs(POSES.Dive) do
		local j = torso:FindFirstChild(name)
		if j and j:IsA("Motor6D") then joints[name] = j end
	end
	return joints
end

local function applyPose(player, poseName, time)
	local state = poseState[player]
	if not state or state.Current == poseName then return end
	state.Current = poseName
	local pose = POSES[poseName]
	for name, joint in pairs(state.Joints) do
		local c0 = state.Originals[joint]
		local a = pose and pose[name]
		local target = c0
		if a then
			target = CFrame.new(c0.Position)
				* CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3]))
				* (c0 - c0.Position)
		end
		TweenService:Create(joint, TweenInfo.new(time or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = target }):Play()
	end
end

-- The joint's REAL resting C0 is remembered on the joint itself the
-- first time we ever touch it. Reading j.C0 fresh each take-off meant
-- that taking off again while the landing tween was still running
-- saved a half-posed arm as "normal" -- and the pose never went away.
local function restC0(j)
	local saved = j:GetAttribute("ElytraRestC0")
	if typeof(saved) ~= "CFrame" then
		saved = j.C0
		j:SetAttribute("ElytraRestC0", saved)
	end
	return saved
end

local function startPose(player, character)
	local joints = getJoints(character)
	local originals = {}
	for _, j in pairs(joints) do originals[j] = restC0(j) end
	poseState[player] = { Joints = joints, Originals = originals, Current = nil }
	applyPose(player, "Hover", 0.25)
end

local function endPose(player, character)
	local state = poseState[player]
	poseState[player] = nil
	-- put every joint we might have posed back, even without state
	local joints = state and state.Joints or (character and getJoints(character)) or {}
	for _, joint in pairs(joints) do
		if joint.Parent then
			local rest = joint:GetAttribute("ElytraRestC0")
			if typeof(rest) == "CFrame" then
				TweenService:Create(joint, TweenInfo.new(0.25), { C0 = rest }):Play()
			end
		end
	end
end

local trailsFor = {}
local function clearTrails(player)
	for _, inst in ipairs(trailsFor[player] or {}) do
		inst:Destroy()
	end
	trailsFor[player] = nil
end

-- REMOVED: a PlayerAdded hook that cloned FlightLocal into
-- every character.
--
-- FlightLocal already sits inside this accessory, and a
-- LocalScript under the character runs on its own -- so the
-- clone meant TWO copies of the input handler were live at
-- once. Every toggle fired twice and cancelled itself out,
-- which is why flight looked like it simply didn't work.
--
-- Worse, this script runs once per equipped Elytra, and the
-- hook listened for ALL players joining -- so one player's
-- wings pushed a flight handler into everyone else's
-- character too.

local function setupFlightMovers(character)
	local hrp = character:WaitForChild("HumanoidRootPart")

	local attachment = hrp:FindFirstChild("FlightAttachment") or Instance.new("Attachment")
	attachment.Name = "FlightAttachment"
	attachment.Parent = hrp

	local lv = hrp:FindFirstChild("FlightVelocity") or Instance.new("LinearVelocity")
	lv.Name = "FlightVelocity"
	lv.MaxForce = 999999
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = Vector3.new(0, 0, 0)
	lv.Attachment0 = attachment
	lv.Parent = hrp

	local ao = hrp:FindFirstChild("FlightRotation") or Instance.new("AlignOrientation")
	ao.Name = "FlightRotation"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = attachment
	ao.MaxTorque = 999999
	ao.Responsiveness = 25 
	ao.Parent = hrp
end

local function land(player, character)
	flyingPlayers[player] = nil
	clearTrails(player)
	endPose(player, character)
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		if hrp:FindFirstChild("FlightVelocity") then hrp.FlightVelocity:Destroy() end
		if hrp:FindFirstChild("FlightRotation") then hrp.FlightRotation:Destroy() end
		if hrp:FindFirstChild("FlightAttachment") then hrp.FlightAttachment:Destroy() end
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

-- The client now says which state it WANTS (true = fly, false = land)
-- instead of "toggle". A plain toggle could drift out of sync with the
-- client (a dropped or doubled event) and then landing actually took
-- off again, leaving you stuck in the flight pose.
toggleEvent.OnServerEvent:Connect(function(player, want)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end
	if type(want) ~= "boolean" then want = not flyingPlayers[player] end

	if want and not flyingPlayers[player] then
		flyingPlayers[player] = true
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		setupFlightMovers(character)
		clearTrails(player)
		trailsFor[player] = addTrails(character)
		startPose(player, character)
	elseif not want then
		land(player, character)
	end
end)

-- Wings taken off / re-given mid-flight (the pass re-applies the
-- accessory): this copy of the script is going away, so land first or
-- the pose and the flight movers would be left behind forever.
script.Destroying:Connect(function()
	for player in pairs(flyingPlayers) do
		pcall(land, player, player.Character)
	end
end)
flightSystem.AncestryChanged:Connect(function()
	local model = flightSystem:FindFirstAncestorOfClass("Model")
	for player in pairs(flyingPlayers) do
		if player.Character ~= model then pcall(land, player, player.Character) end
	end
end)

movementEvent.OnServerEvent:Connect(function(player, cameraCFrame, moveDirection)
	if not flyingPlayers[player] then return end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local lv = hrp:FindFirstChild("FlightVelocity")
	local ao = hrp:FindFirstChild("FlightRotation")

	if lv and ao then
		if moveDirection.Magnitude > 0 then
			-- FIX: Calculate absolute vector velocity cleanly matching directional inputs
			local finalVelocity = cameraCFrame:VectorToWorldSpace(moveDirection) * FLY_SPEED
			lv.VectorVelocity = finalVelocity

			-- Lay the body flat along the flight path (head first).
			-- The camera's up vector is always perpendicular to any
			-- camera-relative move direction, so lookAt never degenerates
			-- (the old version went NaN flying straight up).
			ao.CFrame = CFrame.lookAt(Vector3.zero, finalVelocity, cameraCFrame.UpVector)
				* CFrame.Angles(DIVE_TILT, 0, 0)
			applyPose(player, "Dive", 0.35)
		else
			lv.VectorVelocity = Vector3.new(0, 0, 0)
			-- Hover upright, facing where the camera looks (flattened so
			-- looking down doesn't tip you over).
			local look = cameraCFrame.LookVector * Vector3.new(1, 0, 1)
			if look.Magnitude > 0.01 then
				ao.CFrame = CFrame.lookAt(Vector3.zero, look)
			end
			applyPose(player, "Hover", 0.35)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	flyingPlayers[player] = nil
	trailsFor[player] = nil
	poseState[player] = nil
end)
