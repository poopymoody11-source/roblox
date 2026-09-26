--==================================================
-- ULTIMATE: BIG BANG
-- He rises out of the galaxy floor, draws every star in the
-- realm into a universe between his hands, and hurls it at
-- the arena. It covers everything: there's no running from it.
-- The only way out is its QTE - five steps, on a knife-edge -
-- and anyone who lands all five drives it back into him.
--==================================================
local A = {}

A.Defaults = {
	Charge = 4.2,   -- rising + gathering the universe
	R = 160,        -- where it lands (the outer ring of the arena is safe - or roll through it)
	Fall = 2.2,     -- from his hands to the arena
	Damage = 75,
	Speed = 1,      -- (phase 2 hurls it faster)
}

function A.Run(F, P, token)
	local S = F.S
	local t0 = F.now() + 0.2
	local throwT = t0 + P.Charge / P.Speed
	local T = throwT + P.Fall / P.Speed
	local hit = F.hit({
		T = T,
		Shape = { Kind = "circle", P = S.CENTER, R = P.R },
		Damage = P.Damage,
		Name = "BIG BANG",
		Target = "all",
		Knock = 140,
		Big = true,
	})
	F.fx("BigBang", { T0 = t0, ThrowT = throwT, T = T, Id = hit.Id, R = P.R })
	F.waitUntil(T + 2.5)
end

return A
