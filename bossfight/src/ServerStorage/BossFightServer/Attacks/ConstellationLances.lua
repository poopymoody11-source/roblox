--==================================================
-- ATTACK 4: CONSTELLATION LANCES
-- He points to the sky: stars ignite over the arena and join
-- into constellations, their lines burning red on the floor
-- below... then each line comes down as a blade of light.
--==================================================
local A = {}

A.Defaults = {
	Lines = 6,
	Windup = 1.4,
	Stagger = 0.22,
	W = 12,
	Damage = 30,
}

-- the chord of the arena through p along dir
local function chord(S, p, dir)
	local c = S.flat(S.CENTER)
	local o = S.flat(p) - c
	local d = S.flat(dir).Unit
	local b = o:Dot(d)
	local disc = b * b - (o:Dot(o) - (S.ARENA_R - 4) ^ 2)
	if disc < 0 then return nil end
	local s = math.sqrt(disc)
	local a0, a1 = o + d * (-b - s), o + d * (-b + s)
	return S.surface(c.X + a0.X, c.Z + a0.Z), S.surface(c.X + a1.X, c.Z + a1.Z)
end

function A.Run(F, P, token)
	local S = F.S
	local rng = F.rng
	local t0 = F.now() + 0.15
	local strikeT = t0 + P.Windup
	P.Lines += 2 * ((P.Players or 1) - 1)
	local lines = {}
	local function add(p, dir, target)
		local a, b = chord(S, p, dir)
		if a then table.insert(lines, { A = a, B = b, Target = target }) end
	end
	for _, t in ipairs(F.targets()) do
		local a = rng:NextNumber() * math.pi
		add(t.Root.Position, Vector3.new(math.cos(a), 0, math.sin(a)), t.Player.UserId)
	end
	while #lines < P.Lines do
		local a, r = rng:NextNumber() * math.pi * 2, rng:NextNumber() * S.ARENA_R * 0.7
		local p = S.CENTER + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local d = rng:NextNumber() * math.pi
		add(p, Vector3.new(math.cos(d), 0, math.sin(d)))
	end
	local list = {}
	for i, l in ipairs(lines) do
		local hit = F.hit({
			T = strikeT + (i - 1) * P.Stagger,
			Shape = { Kind = "line", A = l.A, B = l.B, W = P.W },
			Damage = P.Damage,
			Name = "LANCE",
			Target = l.Target,
			Knock = 45,
		})
		table.insert(list, { Id = hit.Id, A = l.A, B = l.B, W = P.W, T = hit.T, Target = l.Target })
	end
	F.fx("ConstellationLances", { T0 = t0, Lines = list })
	F.waitUntil(list[#list].T + 0.4)
	if F.cancelled(token) then return end
end

return A
