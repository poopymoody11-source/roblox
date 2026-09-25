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
	Charge = 5.0,   -- rising + gathering the universe
	Fall = 2.2,     -- from his hands to the arena
	Damage = 75,
	Speed = 1,      -- (phase 2 hurls it faster)
}

function A.Run(F, P, token)
	local S = F.S
	local t0 = F.now() + 0.2
	local throwT = t0 + P.Charge / P.Speed
	local T = throwT + P.Fall / P.Speed
	local max = F.maxHealth()
	local hit = F.hit({
		T = T,
		Shape = { Kind = "circle", P = S.CENTER, R = S.ARENA_R + 40 },
		Damage = P.Damage,
		Name = "BIG BANG",
		Target = "all",
		Knock = 140,
		Big = true,
		-- five keys, one after another (the tightest windows in the fight)
		Qte = (function()
			local q = F.qte.sequence({ "CLICK", "Q", "E", "F", "CLICK" }, 0.42, "ultimate")
			q.Early, q.Late, q.Perfect = 0.24, 0.15, 0.07
			return q
		end)(),
		Counter = math.floor(max * 0.08),
		CounterPerfect = math.floor(max * 0.12),
	})
	F.fx("BigBang", { T0 = t0, ThrowT = throwT, T = T, Id = hit.Id })
	F.waitUntil(T + (F.Config.UltimateCounterDelay or 3.4) + 0.5)
end

return A
