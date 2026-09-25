--==================================================
-- ATTACK 1: GALAXY BARRAGE
-- He raises his arms and tears violet galaxies open in the sky
-- over the arena; planets, moons and stars pour out of them at
-- the players. Every one locks on (the cutscene's red warning)
-- and can be dodged or parried straight back at him.
--==================================================
local A = {}

A.Defaults = {
	Portals = 2,
	Shots = 14,
	Interval = 0.34,   -- seconds between shots
	Windup = 1.5,      -- the galaxies opening
	Travel = { 1.6, 2.1 },
	Finale = true,     -- a planet the size of a house, at everyone
}

-- what can come out: name (the lock-on label), size, damage, speed factor
local KINDS = {
	{ Kind = "planet", Name = "JUPITER", Model = "jupiter", Size = 22, R = 11, Damage = 30, Weight = 1 },
	{ Kind = "planet", Name = "SATURN", Model = "saturn", Size = 20, R = 10, Damage = 30, Weight = 1 },
	{ Kind = "planet", Name = "NEPTUNE", Model = "neptune", Size = 16, R = 9, Damage = 25, Weight = 1 },
	{ Kind = "planet", Name = "MARS", Model = "mars", Size = 12, R = 8, Damage = 22, Weight = 1.2 },
	{ Kind = "planet", Name = "EARTH", Model = "earth", Size = 13, R = 8, Damage = 22, Weight = 1 },
	{ Kind = "planet", Name = "MOON", Model = "moon", Size = 9, R = 7, Damage = 18, Weight = 1.5 },
	{ Kind = "star", Name = "STAR", Size = 6, R = 6, Damage = 15, Weight = 3, Fast = true },
}

local function pickKind(rng)
	local total = 0
	for _, k in ipairs(KINDS) do total += k.Weight end
	local roll = rng:NextNumber() * total
	for _, k in ipairs(KINDS) do
		roll -= k.Weight
		if roll <= 0 then return k end
	end
	return KINDS[#KINDS]
end

function A.Run(F, P, token)
	local S = F.S
	local rng = F.rng
	local t0 = F.now() + 0.2
	local bossPos = F.rootAt(t0).Position
	local toBoss = S.flat(bossPos - S.CENTER).Unit
	local side = toBoss:Cross(S.UP).Unit
	-- the galaxies: high over the rim on his side, fanned left and right
	local portals = {}
	for i = 1, P.Portals do
		local k = P.Portals == 1 and 0 or ((i - 1) / (P.Portals - 1) - 0.5) * 2
		local pos = S.CENTER + toBoss * 150 + side * k * 150 + S.UP * (175 + rng:NextNumber(-15, 25))
		table.insert(portals, pos)
	end
	local openT = t0 + P.Windup
	local lastT = openT + (P.Shots - 1) * P.Interval
	local id = F.newId("GB")
	F.fx("GalaxyBarrage", { Id = id, T0 = t0, OpenT = openT, CloseT = lastT + P.Travel[2] + (P.Finale and 4.3 or 0.8), Portals = portals })

	local targets = F.targets()
	for i = 1, P.Shots do
		local tl = openT + (i - 1) * P.Interval
		F.waitUntil(tl)
		if F.cancelled(token) then return end
		targets = F.targets()
		if #targets == 0 then break end
		local tgt = targets[(i - 1) % #targets + 1]
		if rng:NextNumber() < 0.35 then tgt = targets[rng:NextInteger(1, #targets)] end
		local k = pickKind(rng)
		-- aim where they're heading (a little lead), kept on the arena
		local vel = S.flat(tgt.Root.AssemblyLinearVelocity)
		local travel = rng:NextNumber(P.Travel[1], P.Travel[2]) * (k.Fast and 0.75 or 1)
		local aim = tgt.Root.Position + vel * math.min(travel * 0.35, 0.6)
		local off = S.flat(aim - S.CENTER)
		if off.Magnitude > S.ARENA_R - 6 then aim = S.CENTER + off.Unit * (S.ARENA_R - 6) end
		local land = S.surface(aim.X, aim.Z)
		local from = portals[rng:NextInteger(1, #portals)]
		local hit = F.hit({
			T = tl + travel,
			Shape = { Kind = "circle", P = land, R = k.R },
			Damage = k.Damage,
			Name = k.Name,
			Target = tgt.Player.UserId,
			Knock = 40,
		})
		F.fx("Shot", {
			Attack = id, Id = hit.Id, Kind = k.Kind, Model = k.Model, Name = k.Name, Size = k.Size, R = k.R,
			From = from, To = land, T0 = tl, T = hit.T, Target = tgt.Player.UserId, Spin = rng:NextNumber(-3, 3),
		})
	end
	if P.Finale and not F.cancelled(token) then
		F.waitUntil(lastT + 0.6)
		local tg = F.targets()
		if #tg > 0 then
			local sum = Vector3.zero
			for _, t in ipairs(tg) do sum += t.Root.Position end
			local c = sum / #tg
			local off = S.flat(c - S.CENTER)
			if off.Magnitude > S.ARENA_R - 30 then c = S.CENTER + off.Unit * (S.ARENA_R - 30) end
			local land = S.surface(c.X, c.Z)
			local tl = F.now()
			local hit = F.hit({
				T = tl + 2.9,
				Shape = { Kind = "circle", P = land, R = 32 },
				Damage = 45,
				Name = "JUPITER",
				Target = "all",
				Knock = 100,
				Big = true,
			})
			F.fx("Shot", {
				Attack = id, Id = hit.Id, Kind = "giant", Model = "jupiter", Name = "JUPITER", Size = 64, R = 32,
				From = portals[math.ceil(#portals / 2)] + S.UP * 60, To = land, T0 = tl, T = hit.T, Target = "all", Spin = 0.6,
			})
			lastT = hit.T - P.Travel[2]
		end
	end
	F.waitUntil(lastT + P.Travel[2] + 0.3)
end

return A
