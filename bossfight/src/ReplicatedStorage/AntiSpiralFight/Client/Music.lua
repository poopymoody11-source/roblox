--==================================================
-- BOSS MUSIC (client)
-- The fight's soundtrack, from the licensed tracks the cutscene
-- already uses (Kit.S): one theme per phase, a swell for his
-- set pieces, and a quiet after he falls. Tracks crossfade; the
-- whole mix can duck (under his lines, or while he's dazed).
-- Swap the IDs in TRACKS to change the music.
--==================================================
local M = {}

local K
local current, currentName
local level, duckTo = 1, 1
local BASE = 0.55

local TRACKS -- (filled from Kit.S in init)

function M.init(kit)
	K = kit
	TRACKS = {
		Intro = { Id = K.S.M_Determined, Vol = 0.45, Speed = 1 },
		Phase1 = { Id = K.S.M_EpicAnime, Vol = 0.6, Speed = 1 },
		Phase2 = { Id = K.S.M_Trailer, Vol = 0.62, Speed = 1.03 },
		SetPiece = { Id = K.S.M_Overture, Vol = 0.68, Speed = 1 },
		Victory = { Id = K.S.M_Wonder, Vol = 0.5, Speed = 1 },
	}
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		level += (duckTo - level) * math.min(1, dt * 3)
		if current and current.Parent then
			current.Volume = (current:GetAttribute("TargetVolume") or BASE) * level
		end
	end)
end

-- crossfade to a track by name (Intro / Phase1 / Phase2 / SetPiece / Victory)
function M.play(name, fade)
	if name == currentName then return end
	local tr = TRACKS[name]
	if not tr then return end
	fade = fade or 1.5
	if current then
		local old = current
		old:SetAttribute("TargetVolume", 0)
		K.fadeSound(old, 0, fade, true)
	end
	currentName = name
	current = K.sfx(tr.Id, 0, tr.Speed, { Looped = true })
	current:SetAttribute("Dry", true)
	current:SetAttribute("TargetVolume", 0)
	local s = current
	-- (a hand-rolled fade in, so the ducking still applies over it)
	task.spawn(function()
		local t0 = os.clock()
		while s.Parent and s == current do
			local u = math.min((os.clock() - t0) / fade, 1)
			s:SetAttribute("TargetVolume", tr.Vol * u)
			if u >= 1 then break end
			task.wait()
		end
	end)
end

-- duck the music to `to` (0..1) - 1 lets it back up
function M.duck(to, _time)
	duckTo = to
end

function M.stop(fade)
	if current then K.fadeSound(current, 0, fade or 2, true) end
	current, currentName = nil, nil
end

return M
