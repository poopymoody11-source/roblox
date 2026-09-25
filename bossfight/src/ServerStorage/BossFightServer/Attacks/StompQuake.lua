--==================================================
-- ATTACK 3: STOMP QUAKE
-- He lifts a foot high over the galaxy floor and brings it down
-- at the rim: shockwave rings roll out across the whole arena.
-- Jump each wall of light as it reaches you - or parry it.
--==================================================
local A = {}

A.Defaults = {
	Rings = 3,
	Speed = 72,     -- studs/s
	Gap = 0.85,     -- seconds between rings
	Windup = 1.6,   -- the foot coming up
	W = 6,          -- ring thickness
	H = 4.5,        -- ring height (clear it with a jump)
	Damage = 22,
}

function A.Run(F, P, token)
	local S = F.S
	local t0 = F.now() + 0.15
	local stompT = t0 + P.Windup
	local bossPos = F.rootAt(stompT).Position
	local toBoss = S.flat(bossPos - S.CENTER).Unit
	local origin = S.CENTER + toBoss * (S.ARENA_R + 4)
	local foot = F.rng:NextNumber() < 0.5 and "Right" or "Left"
	local reach = 2 * S.ARENA_R + 20
	local rings = {}
	for i = 1, P.Rings do
		local rt = stompT + 0.1 + (i - 1) * P.Gap
		local shape = { Kind = "ring", O = origin, R0 = 0, Speed = P.Speed, W = P.W, H = P.H, T0 = rt }
		table.insert(rings, { Shape = shape, Until = rt + reach / P.Speed })
	end
	local list = {}
	for _, r in ipairs(rings) do
		-- (SPACE: jump it, and a jump on the beat parries it)
		local hit = { Id = F.newId("SQ"), Shape = r.Shape, Damage = P.Damage, Name = "SHOCKWAVE", Knock = 30, Qte = F.qte.single("SPACE"), Counter = 20, CounterPerfect = 32 }
		r.Hit = hit
		table.insert(list, { Id = hit.Id, Shape = r.Shape })
	end
	-- (announced now, so the prompts can lead them; a ring can't catch anyone before its start)
	for _, r in ipairs(rings) do
		F.continuousHit(r.Hit, r.Until)
	end
	F.fx("StompQuake", { T0 = t0, StompT = stompT, Foot = foot, Origin = origin, Rings = list })
	F.waitUntil(rings[#rings].Until - (S.ARENA_R / P.Speed) * 0.6)
end

return A
