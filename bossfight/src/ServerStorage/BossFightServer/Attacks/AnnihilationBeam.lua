--==================================================
-- ATTACK 5: ANNIHILATION BEAM
-- He thrusts out a palm; violet light gathers in it... then a
-- beam tears out of it and sweeps across the arena. It's too
-- tall to jump: parry it as it reaches you, or dash through.
--==================================================
local A = {}

A.Defaults = {
	Charge = 1.9,     -- the orb gathering
	Sweep = 2.3,      -- seconds to cross the arena
	Arc = 100,        -- degrees swept
	W = 16,           -- beam width on the floor
	Damage = 40,
	Sweeps = 1,       -- (phase 2 sends it back the other way)
}

function A.Run(F, P, token)
	local S = F.S
	local t0 = F.now() + 0.15
	local bossPos = F.rootAt(t0).Position
	local toBoss = S.flat(bossPos - S.CENTER).Unit
	local origin = S.CENTER + toBoss * (S.ARENA_R + 8)
	local centreA = math.atan2(-toBoss.Z, -toBoss.X) -- (from the rim, across the arena)
	local half = math.rad(P.Arc) / 2
	local dir = F.rng:NextNumber() < 0.5 and 1 or -1
	local hand = dir > 0 and "Right" or "Left"
	local fireT = t0 + P.Charge
	local sweeps = {}
	local t = fireT
	for i = 1, P.Sweeps do
		local d = (i % 2 == 1) and dir or -dir
		local shape = {
			Kind = "sweep", O = origin, A0 = centreA - half * d, A1 = centreA + half * d,
			T0 = t, T1 = t + P.Sweep, W = P.W, L = 2 * S.ARENA_R + 20,
		}
		local hit = { Id = F.newId("AB"), Shape = shape, Damage = P.Damage, Name = "ANNIHILATION BEAM", Knock = 50 }
		table.insert(sweeps, hit)
		t = shape.T1 + 0.35
	end
	local list = {}
	for _, h in ipairs(sweeps) do table.insert(list, { Id = h.Id, Shape = h.Shape }) end
	F.fx("AnnihilationBeam", { T0 = t0, FireT = fireT, Hand = hand, Origin = origin, Sweeps = list })
	for _, h in ipairs(sweeps) do
		F.waitUntil(h.Shape.T0 - 0.05)
		if F.cancelled(token) then return end
		F.continuousHit(h, h.Shape.T1 + 0.05)
	end
	F.waitUntil(sweeps[#sweeps].Shape.T1 + 0.6)
end

return A
