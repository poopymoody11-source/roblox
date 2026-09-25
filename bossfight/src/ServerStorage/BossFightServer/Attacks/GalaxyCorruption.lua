--==================================================
-- SET PIECE: GALAXY CORRUPTION (the end of phase 1)
-- He reaches out to the sky and every galaxy in the realm turns
-- to his violet. Then they open fire: a storm of rapid strikes
-- raining down on the arena, lances of light across it, faster
-- and faster... and to finish, every galaxy converges on you.
--==================================================
local A = {}

A.Defaults = {
	Corrupt = 3.2,     -- the galaxies turning
	Storm = 9,         -- seconds of bombardment
	Galaxies = 7,      -- (the realm's hero galaxies, indexed on the client)
	BoltGap = { 0.22, 0.09 }, -- seconds between bolts, start -> end of the storm
	BoltWarn = 0.95,
	BoltR = 10,
	LanceEvery = 1.8,
	Damage = 18,
	FinaleR = 16,
	FinaleDamage = 45,
}

local KEYS = { "CLICK", "CLICK", "Q", "E", "F" }

function A.Run(F, P, token)
	local S = F.S
	local rng = F.rng
	local t0 = F.now() + 0.2
	local stormT = t0 + P.Corrupt
	local endT = stormT + P.Storm
	F.fx("GalaxyCorruption", { T0 = t0, StormT = stormT, EndT = endT, Galaxies = P.Galaxies })
	F.waitUntil(stormT - P.BoltWarn)
	local nextLance = stormT + 0.8
	local t = stormT
	while t < endT do
		if F.cancelled(token) then return end
		local u = (t - stormT) / P.Storm
		local gap = P.BoltGap[1] + (P.BoltGap[2] - P.BoltGap[1]) * u
		local targets = F.targets()
		if #targets == 0 then break end
		-- a bolt: at someone (with a little scatter), from one of the galaxies
		local tg = targets[rng:NextInteger(1, #targets)]
		local p = tg.Root.Position + S.flat(tg.Root.AssemblyLinearVelocity) * 0.4
			+ Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14))
		local off = S.flat(p - S.CENTER)
		if off.Magnitude > S.ARENA_R - 6 then p = S.CENTER + off.Unit * (S.ARENA_R - 6) end
		local land = S.surface(p.X, p.Z)
		local hit = F.hit({
			T = t + P.BoltWarn,
			Shape = { Kind = "circle", P = land, R = P.BoltR },
			Damage = P.Damage, Name = "CORRUPTED STAR", Target = tg.Player.UserId, Knock = 30,
			Qte = F.qte.single(KEYS[rng:NextInteger(1, #KEYS)]),
			Counter = 12, CounterPerfect = 20,
		})
		F.fx("CorruptBolt", { Id = hit.Id, From = rng:NextInteger(1, P.Galaxies), To = land, R = P.BoltR, T0 = t, T = hit.T })
		-- now and then a lance of light across the arena, through someone
		if t >= nextLance then
			nextLance = t + P.LanceEvery * (1 - 0.4 * u)
			local a = rng:NextNumber() * math.pi
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			local c = S.flat(tg.Root.Position - S.CENTER)
			local b = c:Dot(d)
			local disc = b * b - (c:Dot(c) - (S.ARENA_R - 4) ^ 2)
			if disc > 0 then
				local sq = math.sqrt(disc)
				local A0 = S.CENTER + d * (-b - sq)
				local B0 = S.CENTER + d * (-b + sq)
				local lh = F.hit({
					T = t + 1.2,
					Shape = { Kind = "line", A = S.surface(A0.X, A0.Z), B = S.surface(B0.X, B0.Z), W = 12 },
					Damage = P.Damage + 8, Name = "GALACTIC LANCE", Target = tg.Player.UserId, Knock = 45,
					Qte = F.qte.randomChord(2), Counter = 35, CounterPerfect = 55,
				})
				F.fx("CorruptLance", { Id = lh.Id, From = rng:NextInteger(1, P.Galaxies), A = lh.Shape.A, B = lh.Shape.B, W = 12, T0 = t, T = lh.T })
			end
		end
		F.waitUntil(t + gap)
		t += gap
	end
	if F.cancelled(token) then return end
	-- the finale: every galaxy at once, on each of you
	local finT = endT + 2.2
	for _, tg in ipairs(F.targets()) do
		local p = tg.Root.Position
		local hit = F.hit({
			T = finT,
			Shape = { Kind = "circle", P = S.surface(p.X, p.Z), R = P.FinaleR },
			Damage = P.FinaleDamage, Name = "EVERY GALAXY", Target = tg.Player.UserId, Knock = 90,
			Qte = F.qte.randomChord(3), Counter = 80, CounterPerfect = 130,
		})
		F.fx("CorruptFinale", { Id = hit.Id, P = hit.Shape.P, R = P.FinaleR, T0 = endT, T = finT, User = tg.Player.UserId })
	end
	F.waitUntil(finT + 1.5)
end

return A
