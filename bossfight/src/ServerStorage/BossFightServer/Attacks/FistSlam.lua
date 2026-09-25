--==================================================
-- ATTACK 2: FIST SLAM
-- He rears back and brings his fists down: red zones open on
-- the arena (one under every player, plus a few more), fill up,
-- and violet fists of his power crash into each one. Get out -
-- or parry the fist as it lands.
--==================================================
local A = {}

A.Defaults = {
	Waves = 2,
	ExtraZones = 2,
	ZoneR = 22,
	Windup = 1.7,     -- first wave's warning
	WaveWarn = 1.25,  -- later waves' warning
	WaveGap = 0.55,   -- rest between one wave's last slam and the next wave's warning
	Stagger = 0.16,   -- between slams in a wave
	Damage = 35,
	Hammer = true,     -- the finale: both fists, one huge zone over the crowd
	HammerR = 50,
	HammerWarn = 1.9,
	HammerDamage = 50,
}

function A.Run(F, P, token)
	local S = F.S
	local rng = F.rng
	local now = F.now()
	local waveT = now + 0.2
	for w = 1, P.Waves do
		if F.cancelled(token) then return end
		local warn = w == 1 and P.Windup or P.WaveWarn
		local impact = waveT + warn
		local zones = {}
		local function clear(p)
			for _, z in ipairs(zones) do
				if (S.flat(z.P) - S.flat(p)).Magnitude < P.ZoneR * 1.6 then return false end
			end
			return true
		end
		local function add(p, target)
			local off = S.flat(p - S.CENTER)
			if off.Magnitude > S.ARENA_R - P.ZoneR * 0.6 then p = S.CENTER + off.Unit * (S.ARENA_R - P.ZoneR * 0.6) end
			table.insert(zones, { P = S.surface(p.X, p.Z), Target = target })
		end
		for _, t in ipairs(F.targets()) do
			local p = t.Root.Position + S.flat(t.Root.AssemblyLinearVelocity) * 0.3
			if clear(p) then add(p, t.Player.UserId) end
		end
		for _ = 1, P.ExtraZones + (w - 1) do
			for _ = 1, 12 do
				local a, r = rng:NextNumber() * math.pi * 2, math.sqrt(rng:NextNumber()) * (S.ARENA_R - P.ZoneR)
				local p = S.CENTER + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				if clear(p) then add(p) break end
			end
		end
		-- (slam order: nearest to him first, so the fists walk across the arena)
		local bossPos = F.rootAt(impact).Position
		table.sort(zones, function(a, b) return (a.P - bossPos).Magnitude < (b.P - bossPos).Magnitude end)
		local list = {}
		for i, z in ipairs(zones) do
			local hit = F.hit({
				T = impact + (i - 1) * P.Stagger,
				Shape = { Kind = "circle", P = z.P, R = P.ZoneR },
				Damage = P.Damage,
				Name = "FIST",
				Target = z.Target,
				Knock = 70,
				Counter = 25, CounterPerfect = 40,
			})
			table.insert(list, { Id = hit.Id, P = z.P, R = P.ZoneR, T = hit.T, Target = z.Target })
		end
		F.fx("FistSlam", { T0 = waveT, Wave = w, Hand = (w % 2 == 1) and "Right" or "Left", Zones = list })
		local last = list[#list] and list[#list].T or impact
		F.waitUntil(last + 0.2)
		waveT = last + P.WaveGap
	end
	if P.Hammer and not F.cancelled(token) then
		-- over the middle of everyone (kept on the arena)
		local sum, n = Vector3.zero, 0
		for _, t in ipairs(F.targets()) do sum += t.Root.Position n += 1 end
		local c = n > 0 and sum / n or S.CENTER
		local off = S.flat(c - S.CENTER)
		if off.Magnitude > S.ARENA_R - P.HammerR * 0.5 then c = S.CENTER + off.Unit * (S.ARENA_R - P.HammerR * 0.5) end
		local p = S.surface(c.X, c.Z)
		local hit = F.hit({
			T = waveT + P.HammerWarn,
			Shape = { Kind = "circle", P = p, R = P.HammerR },
			Damage = P.HammerDamage,
			Name = "HAMMER OF DESPAIR",
			Target = "all",
			Knock = 110,
			Qte = F.qte.randomChord(3),
			Counter = 100, CounterPerfect = 160,
		})
		F.fx("FistHammer", { T0 = waveT, T = hit.T, Id = hit.Id, P = p, R = P.HammerR })
		waveT = hit.T + 0.6
	end
	F.waitUntil(waveT)
end

return A
