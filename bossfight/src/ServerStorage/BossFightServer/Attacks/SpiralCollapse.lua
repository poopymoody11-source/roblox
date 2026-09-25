--==================================================
-- ATTACK 6: SPIRAL COLLAPSE
-- He claps his hands together over his head and a black hole
-- opens above the arena, dragging everyone toward it (the pull
-- is applied on each client). Fight your way out of the red
-- before it collapses - or stand your ground and parry the blast.
--==================================================
local A = {}

A.Defaults = {
	Windup = 1.4,     -- the clap
	Pull = 4.2,       -- seconds of pull before it collapses
	Strength = 10,    -- studs/s toward the centre (walk speed is 16)
	R = 75,           -- the blast radius
	Damage = 45,
}

function A.Run(F, P, token)
	local S = F.S
	local t0 = F.now() + 0.15
	local openT = t0 + P.Windup
	local blastT = openT + P.Pull
	local hit = F.hit({
		T = blastT,
		Shape = { Kind = "circle", P = S.CENTER, R = P.R },
		Damage = P.Damage,
		Name = "SPIRAL COLLAPSE",
		Knock = 90,
		Target = "all",
		Big = true,
		Qte = F.qte.sequence({ "Q", "E", "CLICK" }, 0.45),
		Counter = 70, CounterPerfect = 110,
	})
	F.fx("SpiralCollapse", { T0 = t0, OpenT = openT, BlastT = blastT, Id = hit.Id, R = P.R, Strength = P.Strength, Centre = S.CENTER })
	F.waitUntil(blastT + 0.8)
	if F.cancelled(token) then return end
end

return A
