--==================================================
-- BOSS FIGHT: SHARED
-- Everything the server and every client must agree on:
-- the arena, the Anti-Spiral's walk around it (a plan both
-- sides evaluate on the synced server clock), the shapes an
-- attack can hit, and the parry timing.
--==================================================
local HttpService = game:GetService("HttpService")

local S = {}

S.CENTER = Vector3.new(0, 0.5, 20000) -- arena centre, on its surface
S.ARENA_R = 225                       -- the disc players stand on
S.WALK_R = 300                        -- the ring he walks round, outside the rim
S.UP = Vector3.yAxis

-- parry timing (seconds, relative to a hit's impact time T)
S.PARRY_EARLY = 0.32   -- a swing this long before impact still parries
S.PARRY_LATE = 0.08    -- ...or this long after
S.PERFECT = 0.1        -- |swing - T| within this is a perfect parry
S.GRACE = 0.2          -- the server waits this long after T for late parry claims
S.WARN_LOCK = 2.4      -- the red lock-on shows this long before impact
S.PROMPT_LEAD = 0.9    -- the click prompt shows this long before impact

-- remotes (made by the server in ReplicatedStorage.AntiSpiralFight.Net)
S.NET = "Net"

function S.now()
	return workspace:GetServerTimeNow()
end

function S.flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

function S.onArena(p, margin)
	return (S.flat(p) - S.flat(S.CENTER)).Magnitude <= S.ARENA_R - (margin or 0)
end

-- a point on the arena surface
function S.surface(x, z)
	return Vector3.new(x, S.CENTER.Y, z)
end

function S.ease(u)
	u = math.clamp(u, 0, 1)
	return -(math.cos(math.pi * u) - 1) / 2
end

--------------------------------------------------------------------------
-- MOTION PLAN
-- { T0, T1, A0, A1, F0, F1, FM, Y }: between T0 and T1 his angle round
-- the ring eases from A0 to A1 (radians), and his facing from F0 to F1
-- (0 = square to the arena centre, 1 = along the way he's walking), plus
-- FM * sin(pi * u): a walk that turns into its stride and squares back up
-- to the arena as it stops. Y is his root height. Outside T0..T1 he holds.
--------------------------------------------------------------------------
function S.encodePlan(plan)
	return HttpService:JSONEncode(plan)
end

function S.decodePlan(str)
	if type(str) ~= "string" or str == "" then return nil end
	local ok, plan = pcall(HttpService.JSONDecode, HttpService, str)
	return ok and plan or nil
end

local function ringPos(a, y)
	return Vector3.new(S.CENTER.X + math.cos(a) * S.WALK_R, y, S.CENTER.Z + math.sin(a) * S.WALK_R)
end
S.ringPos = ringPos

-- his root CFrame at time t, plus his speed (studs/s) and the plan's travel sign
function S.rootAt(plan, t)
	local u = plan.T1 > plan.T0 and math.clamp((t - plan.T0) / (plan.T1 - plan.T0), 0, 1) or 1
	local e = S.ease(u)
	local a = plan.A0 + (plan.A1 - plan.A0) * e
	local f = plan.F0 + (plan.F1 - plan.F0) * e + (plan.FM or 0) * math.sin(math.pi * u)
	local pos = ringPos(a, plan.Y)
	local toCentre = S.flat(S.CENTER - pos).Unit
	local dir = (plan.A1 >= plan.A0) and 1 or -1
	local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) * dir
	local face = toCentre:Lerp(tangent, f)
	if face.Magnitude < 1e-3 then face = toCentre end
	-- (angular speed of the eased move, times the radius)
	local dur = math.max(plan.T1 - plan.T0, 1e-3)
	local speed = 0
	if u > 0 and u < 1 then
		speed = math.abs(plan.A1 - plan.A0) * (math.pi / 2) * math.sin(math.pi * u) / dur * S.WALK_R
	end
	return CFrame.lookAt(pos, pos + face.Unit), speed
end

--------------------------------------------------------------------------
-- HIT SHAPES
-- circle: { Kind = "circle", P = Vector3, R = number }
-- line:   { Kind = "line", A = Vector3, B = Vector3, W = number }
-- ring:   { Kind = "ring", O = Vector3, R0 = number, Speed = number, W = number, H = number, T0 = number }
--         (a shockwave: radius R0 + Speed * (t - T0), W thick, H tall; jump it)
-- Positions are compared flat (XZ), against a character's root.
--------------------------------------------------------------------------
function S.ringRadius(shape, t)
	return shape.R0 + shape.Speed * (t - shape.T0)
end

function S.inside(shape, pos, t, feetHeight)
	local p = S.flat(pos)
	if shape.Kind == "circle" then
		return (p - S.flat(shape.P)).Magnitude <= shape.R + 1.5
	elseif shape.Kind == "line" then
		local a, b = S.flat(shape.A), S.flat(shape.B)
		local ab = b - a
		local u = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		return (p - (a + ab * u)).Magnitude <= shape.W / 2 + 1.5
	elseif shape.Kind == "ring" then
		local r = S.ringRadius(shape, t)
		local d = (p - S.flat(shape.O)).Magnitude
		if math.abs(d - r) > shape.W / 2 + 1.5 then return false end
		-- (jump it: feet clear of the wall's top)
		return (feetHeight or 0) < shape.H
	end
	return false
end

-- when a ring shockwave reaches a point (for prompts)
function S.ringArrival(shape, pos)
	local d = (S.flat(pos) - S.flat(shape.O)).Magnitude
	return shape.T0 + (d - shape.R0) / shape.Speed
end

-- a point to hang a warning on
function S.shapeCentre(shape, t)
	if shape.Kind == "circle" then return shape.P end
	if shape.Kind == "line" then return shape.A:Lerp(shape.B, 0.5) end
	return shape.O
end

return S
