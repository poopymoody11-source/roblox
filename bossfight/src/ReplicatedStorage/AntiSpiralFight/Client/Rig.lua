--==================================================
-- THE ANTI-SPIRAL, ANIMATED (client)
-- The server never moves him: it publishes a walk plan (the
-- "Motion" attribute) and every client places his root from it
-- on the synced clock, then poses him procedurally - the same
-- two-bone leg solve as the cutscene's charge, so every planted
-- foot stays planted. Feet step on their own whenever his body
-- has moved (or turned) too far from them, so walking, turning
-- on the spot and settling all come out of one rule. Each
-- footfall is a stomp (Fx builds the galaxy floor under it).
--
-- Attacks take over parts of him with rig:act({ ... }):
--   Until = t                    - when the action lets go
--   Root = function(t) -> CFrame - an offset applied to his root (lean, crouch, recoil)
--   Upper = function(t, rootCF)  - pose waist/neck/arms/hands (SB.body / SB.hand / SK.hang)
--   Foot = { Right = function(t, plant) -> groundPos, pitch }  - drive a foot yourself
--==================================================
local Rig = {}
Rig.__index = Rig

local UP = Vector3.yAxis
local rad = math.rad

local function aimRot(localA, localRef, worldA, worldRef)
	local la = localA.Unit
	local lr = localRef - la * localRef:Dot(la)
	lr = lr.Magnitude > 1e-3 and lr.Unit or la:Cross(Vector3.xAxis).Unit
	local lc = la:Cross(lr)
	local wa = worldA.Unit
	local wr = worldRef - wa * worldRef:Dot(wa)
	wr = wr.Magnitude > 1e-3 and wr.Unit or wa:Cross(Vector3.yAxis).Unit
	local wc = wa:Cross(wr)
	return CFrame.fromMatrix(Vector3.zero, wa, wr, wc) * CFrame.fromMatrix(Vector3.zero, la, lr, lc):Inverse()
end

-- (the cutscene's leg solve: hip -> knee -> ankle onto `target`, knee toward `pole`)
local function solveLeg(g, lt, target, pole, footRot)
	local sW = (lt * CFrame.new(g.HB.C0.Position)).Position
	local toT = target - sW
	local d = math.clamp(toT.Magnitude, math.abs(g.Lu - g.Ll) + 1, g.Lu + g.Ll - 0.5)
	local dir = toT.Magnitude > 1e-3 and toT.Unit or -Vector3.yAxis
	local a = (g.Lu * g.Lu - g.Ll * g.Ll + d * d) / (2 * d)
	local h = math.sqrt(math.max(g.Lu * g.Lu - a * a, 0))
	local bend = pole - dir * pole:Dot(dir)
	bend = bend.Magnitude > 1e-3 and bend.Unit or dir:Cross(Vector3.xAxis).Unit
	local eW = sW + dir * a + bend * h
	local wW = sW + dir * d
	local Rul = aimRot(g.eJ - g.sJ, g.FwdU, eW - sW, bend)
	local ulCF = CFrame.new(sW - Rul * g.sJ) * Rul
	local Rll = aimRot(g.wL - g.eL, g.FwdL, wW - eW, bend)
	local llCF = CFrame.new(eW - Rll * g.eL) * Rll
	g.Hip.C0 = CFrame.new(g.HB.C0.Position) * (lt:Inverse() * ulCF * g.HB.C1).Rotation
	g.Knee.C0 = CFrame.new(g.KB.C0.Position) * (ulCF:Inverse() * llCF * g.KB.C1).Rotation
	g.Ankle.C0 = CFrame.new(g.AB.C0.Position) * (llCF.Rotation:Inverse() * footRot * g.AB.C1.Rotation)
	return wW
end

local function flatYaw(cf)
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude < 1e-3 then look = Vector3.zAxis end
	return CFrame.lookAt(Vector3.zero, look.Unit)
end

local function yawBetween(a, b)
	local la, lb = a.LookVector, b.LookVector
	return math.acos(math.clamp(la:Dot(lb), -1, 1))
end

function Rig.new(K, SK, S, model)
	local self = setmetatable({}, Rig)
	local root = model:WaitForChild("HumanoidRootPart")
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	self.K, self.SK, self.S = K, SK, S
	self.Model, self.Root = model, root
	self.Home = root.CFrame
	local ctx = { Boss = model, BossRoot = root, BossHome = self.Home, kit = K }
	self.Ctx = ctx
	self.SB = SK.boss(ctx, K) -- (his giant jointed hands, as in the cutscene)
	self.R = self.SB.R
	self:_calibrate()
	self.Feet = {}
	for _, side in ipairs({ "Right", "Left" }) do
		self.Feet[side] = { Plant = self:_ground(side, self.Home), Yaw = flatYaw(self.Home), LandT = 0, Pitch = 0 }
	end
	self.Action = nil
	self.LastStep = "Left"
	self.OnStep = nil -- function(side, pos, power)
	self.Focus = nil  -- world point he looks at
	return self
end

function Rig:_calibrate()
	local R, SB, home = self.R, self.SB, self.Home
	SB.reset()
	local lt = R.cf("LowerTorso", home)
	local L = {}
	local floor = math.huge
	for _, side in ipairs({ "Right", "Left" }) do
		local hip = R.joint(side .. "Hip", side .. "UpperLeg")
		local knee = R.joint(side .. "Knee", side .. "LowerLeg")
		local ankle = R.joint(side .. "Ankle", side .. "Foot")
		assert(hip and knee and ankle, "[BossFight] the Anti-Spiral's " .. side .. " leg joints are missing")
		local hb, kb, ab = R.B[hip], R.B[knee], R.B[ankle]
		local g = { Hip = hip, Knee = knee, Ankle = ankle, HB = hb, KB = kb, AB = ab }
		g.sJ, g.eJ, g.eL, g.wL = hb.C1.Position, kb.C0.Position, kb.C1.Position, ab.C0.Position
		g.Lu, g.Ll = (g.eJ - g.sJ).Magnitude, (g.wL - g.eL).Magnitude
		local ul = lt * hb.C0 * hb.C1:Inverse()
		local ll = ul * kb.C0 * kb.C1:Inverse()
		local ft = ll * ab.C0 * ab.C1:Inverse()
		local hipW = (lt * CFrame.new(hb.C0.Position)).Position
		local ankW = ll:PointToWorldSpace(g.wL)
		local foot = self.Model:FindFirstChild(side .. "Foot")
		local sole = ft.Position.Y - (foot and foot.Size.Y or 40) / 2
		floor = math.min(floor, sole)
		g.AnkleUp = ankW.Y - sole
		g.HipRel = home:PointToObjectSpace(hipW)
		g.AnkRel = home:PointToObjectSpace(ankW)
		g.FootRel = home.Rotation:Inverse() * ft.Rotation
		g.ToeRel = home:VectorToObjectSpace(ft.Position - ankW)
		g.FwdU = ul:VectorToObjectSpace(home.LookVector)
		g.FwdL = ll:VectorToObjectSpace(home.LookVector)
		g.Reach = g.Lu + g.Ll
		g.Rest = hipW.Y - ankW.Y
		L[side] = g
	end
	self.L = L
	self.Floor = floor
	self.LegLen = math.min(L.Right.Reach, L.Left.Reach)
end

-- the floor point under a foot's ankle for a root at `cf`
function Rig:_ground(side, cf)
	local g = self.L[side]
	local p = cf:PointToWorldSpace(Vector3.new(g.AnkRel.X, 0, g.AnkRel.Z))
	return Vector3.new(p.X, self.Floor, p.Z)
end

-- the middle of a footprint (for the stomp effects)
function Rig:printAt(side, ground, yaw)
	local g = self.L[side]
	-- (ToeRel is in his home frame; a foot turned to `yaw` carries it round)
	return ground + (yaw or flatYaw(self.Home)) * Vector3.new(g.ToeRel.X, 0, g.ToeRel.Z)
end

-- where a foot is now (floor point) - for effects
function Rig:footGround(side)
	return self.Feet[side].Now or self.Feet[side].Plant
end

function Rig:act(action)
	self.Action = action
end

function Rig:setPlan(plan)
	self.Plan = plan
end

function Rig:rootAt(t)
	if not self.Plan then return self.Home, 0 end
	return self.S.rootAt(self.Plan, t)
end

-- where his chest / head / hands are right now (after update)
function Rig:partCF(name)
	local p = self.Model:FindFirstChild(name)
	return p and p.CFrame
end

--------------------------------------------------------------------------
-- posing: poses are tables { Joint = { x, y, z } } (degrees) for the joints
-- SB.body knows (Waist, Neck, RightShoulder, RightElbow, LeftShoulder, LeftElbow)
--------------------------------------------------------------------------
Rig.REST = {
	Waist = { -3, 0, 0 }, RightShoulder = { 8, 0, 12 }, LeftShoulder = { 8, 0, -12 },
	RightElbow = { 22, 0, 0 }, LeftElbow = { 22, 0, 0 },
}

-- apply the blend of pose a -> b at u (0..1)
function Rig:pose(a, b, u)
	local K = self.K
	u = u or 0
	local out = {}
	for k, va in pairs(a) do
		local vb = (b and b[k]) or va
		out[k] = K.A(va[1] + (vb[1] - va[1]) * u, va[2] + (vb[2] - va[2]) * u, va[3] + (vb[3] - va[3]) * u)
	end
	if b then
		for k, vb in pairs(b) do
			if not a[k] then out[k] = K.A(vb[1] * u, vb[2] * u, vb[3] * u) end
		end
	end
	self.SB.body(out)
end

-- blend through a list of { t, pose } keys at time t
function Rig:posePath(keys, t, ease)
	ease = ease or self.K.E.inOutSine
	if t <= keys[1][1] then return self:pose(keys[1][2]) end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b[1] then
			return self:pose(a[2], b[2], ease((t - a[1]) / math.max(b[1] - a[1], 1e-3)))
		end
	end
	return self:pose(keys[#keys][2])
end

--------------------------------------------------------------------------
-- stepping
--------------------------------------------------------------------------
local WALK_REF = 70 -- (the config walk speed: how "moving" he looks)

function Rig:_steps(t, baseCF, speed)
	local K = self.K
	local move = math.clamp(speed / WALK_REF, 0, 1)
	local dur = speed > 3 and math.clamp(1.05 - speed / 220, 0.62, 1.0) or 0.7
	local vel = (self:rootAt(t + 0.1).Position - baseCF.Position) / 0.1
	local action = self.Action
	for _, side in ipairs({ "Right", "Left" }) do
		local f = self.Feet[side]
		local over = action and action.Foot and action.Foot[side]
		if over then
			f.Step = nil
		elseif f.Step then
			local st = f.Step
			local w = (t - st.T0) / st.Dur
			if w >= 1 then
				f.Plant, f.Yaw, f.Step, f.LandT = st.To, st.YawTo, nil, t
				f.LandPower = st.Power
				self.LastStep = side
				if self.OnStep then self.OnStep(side, self:printAt(side, st.To, st.YawTo), st.Power) end
			end
		end
	end
	-- start a step? (one foot at a time; the one that's furthest behind)
	local stepping = false
	for _, side in ipairs({ "Right", "Left" }) do
		if self.Feet[side].Step then stepping = true end
	end
	if not stepping then
		local best, bestErr = nil, 0
		for _, side in ipairs({ "Right", "Left" }) do
			local f = self.Feet[side]
			if not (action and action.Foot and action.Foot[side]) and t - f.LandT > 0.08 then
				local want = self:_ground(side, baseCF)
				local err = (want - f.Plant).Magnitude
				local turn = math.deg(yawBetween(f.Yaw, flatYaw(baseCF)))
				local need = speed > 3 and (speed * dur * 0.45 + 12) or 16
				local score = err / need + turn / (speed > 3 and 22 or 14)
				-- (alternate feet while walking)
				if side == self.LastStep and speed > 3 then score *= 0.6 end
				if score > 1 and score > bestErr then best, bestErr = side, score end
			end
		end
		if best then
			local f = self.Feet[best]
			local landCF = self:rootAt(t + dur)
			local to = self:_ground(best, landCF) + Vector3.new(vel.X, 0, vel.Z) * dur * 0.35 * move
			local dist = (to - f.Plant).Magnitude
			f.Step = {
				From = f.Plant, To = to, YawFrom = f.Yaw, YawTo = flatYaw(landCF), T0 = t, Dur = dur,
				Lift = math.clamp(dist * 0.5, 28, 150), Power = math.clamp(0.3 + dist / 160, 0.35, 1.2),
			}
		end
	end
	-- each foot's ground point + pitch right now
	for _, side in ipairs({ "Right", "Left" }) do
		local f = self.Feet[side]
		local over = action and action.Foot and action.Foot[side]
		if over then
			local pos, pitch, yaw = over(t, f.Plant)
			f.Now, f.Pitch, f.NowYaw = pos, pitch or 0, yaw or f.Yaw
		elseif f.Step then
			local st = f.Step
			local w = math.clamp((t - st.T0) / st.Dur, 0, 1)
			local e = K.E.inOutSine(w)
			f.Now = st.From:Lerp(st.To, e) + UP * st.Lift * math.sin(math.pi * w ^ 0.85)
			f.Pitch = -26 * math.sin(math.pi * math.min(w * 1.3, 1)) + 14 * K.k(w, 0.55, 1)
			f.NowYaw = st.YawFrom:Lerp(st.YawTo, e)
		else
			f.Now = f.Plant
			f.Pitch = 14 * (1 - K.k(t - f.LandT, 0, 0.14))
			f.NowYaw = f.Yaw
		end
	end
	return move
end

--------------------------------------------------------------------------
-- the frame
--------------------------------------------------------------------------
function Rig:update(t)
	local K, SB, SK = self.K, self.SB, self.SK
	local baseCF, speed = self:rootAt(t)
	local action = self.Action
	if action and action.Until and t > action.Until then
		self.Action = nil
		action = nil
	end
	local move = self:_steps(t, baseCF, speed)

	-- the body: a slight crouch (more at a stride), a dip as each foot lands,
	-- a rise through the swing, and sway over the planted foot
	local crouch = self.LegLen * (0.035 + 0.05 * move)
	local dip, rise, sway = 0, 0, 0
	for _, side in ipairs({ "Right", "Left" }) do
		local f = self.Feet[side]
		local since = t - f.LandT
		if since < 0.4 then dip += 16 * (f.LandPower or 0.5) * (1 - since / 0.4) ^ 2 end
		if f.Step then
			local w = math.clamp((t - f.Step.T0) / f.Step.Dur, 0, 1)
			rise += 6 * math.sin(math.pi * w) * move
			-- (lean away from the lifted foot, over the planted one)
			sway += (side == "Right" and -1 or 1) * 9 * math.sin(math.pi * w) * move
		end
	end
	local lean = 7 * move
	local rootCF = CFrame.new(baseCF.Position + UP * (rise - crouch - dip) + baseCF.RightVector * sway)
		* baseCF.Rotation * CFrame.Angles(-rad(lean), 0, rad(sway * 0.25))
	if action and action.Root then rootCF = rootCF * action.Root(t) end
	self.RootCF = rootCF
	self.Root.CFrame = rootCF

	SB.reset()
	-- upper body
	local handled = action and action.Upper and action.Upper(t, rootCF)
	if not handled then
		-- arms swinging against the legs; he turns his head to whoever he's hunting
		local g = 0
		local fr, fl = self.Feet.Right, self.Feet.Left
		if fr.Step then g += math.sin(math.pi * math.clamp((t - fr.Step.T0) / fr.Step.Dur, 0, 1)) end
		if fl.Step then g -= math.sin(math.pi * math.clamp((t - fl.Step.T0) / fl.Step.Dur, 0, 1)) end
		local sw = 26 * move
		local breathe = math.sin(t * 1.3) * 2
		SB.body({
			Waist = K.A(-3 + breathe * 0.5, g * 6 * move, 0),
			RightShoulder = K.A(8 - g * sw, 0, 12 + breathe),
			LeftShoulder = K.A(8 + g * sw, 0, -12 - breathe),
			RightElbow = K.A(22 + 10 * move, 0, 0),
			LeftElbow = K.A(22 + 10 * move, 0, 0),
		})
		SK.hang(SB, "Right", 0.55, 0.1)
		SK.hang(SB, "Left", 0.55, 0.1)
		if self.Focus then SB.lookAt(self.Focus, 0.8, rootCF) end
	end

	-- legs
	local lt = SB.R.cf("LowerTorso", rootCF)
	for _, side in ipairs({ "Right", "Left" }) do
		local g = self.L[side]
		local f = self.Feet[side]
		local yaw = f.NowYaw or f.Yaw
		local target = f.Now + UP * g.AnkleUp
		local footRot = yaw * CFrame.Angles(rad(f.Pitch or 0), 0, 0) * g.FootRel
		local look = rootCF.LookVector
		local outward = rootCF.RightVector * (side == "Right" and 0.15 or -0.15)
		solveLeg(g, lt, target, look + outward, footRot)
	end
end

return Rig
