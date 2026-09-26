--==================================================
-- CHAPTER 6: PORTAL
-- Through the Anti-Spiral's portal (the solar system, the drag and
-- the fall into the portal live in ChSolar): a tunnel of bent
-- starlight wrapping into a violet vortex that carries the party
-- into the Anti-Spiral's domain.
--==================================================
local Ch = {}

------------------------------------------------------------------------
-- BUILD
------------------------------------------------------------------------
function Ch.build(ctx)
	local K = ctx.kit
	local rng = Random.new(5)
	local C = ctx.TL.HoleOrigin

	--------------------------------------------------------------------
	-- the portal: a tunnel of bent starlight
	--------------------------------------------------------------------
	local portal = Instance.new("Folder")
	portal.Name = "PortalSet"
	ctx.sets.Portal = portal
	local ph = K.part({ Name = "PortalHost", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(C + Vector3.new(0, 4000, 0)) }, portal)
	ctx.PortalHost = ph
	ctx.PortalRings = {}
	for i = 1, 14 do
		local ring = K.softRing(ph, 30, 22, 70, { Brightness = 2.4, Alpha = 0.7, Texture = i % 2 == 0 and "10180479311" or nil })
		table.insert(ctx.PortalRings, { Ring = ring, Z = (i - 1) / 14, Spin = (i % 2 == 0 and 1 or -1) * rng:NextNumber(0.6, 1.4) })
	end
	ctx.PortalStreaks = {}
	for _ = 1, 110 do
		local b = K.ray(ph, Vector3.zero, Vector3.new(0, 0, 1), 0.5, 0.05, nil, { Color = Color3.fromRGB(255, 240, 220), Transparency = K.ns(0, 1, 0.4, 0.15, 1, 1), Brightness = 4, Segments = 2 })
		table.insert(ctx.PortalStreaks, { Beam = b, Ang = rng:NextNumber(0, 6.28), R = rng:NextNumber(8, 60), Z = rng:NextNumber(), Speed = rng:NextNumber(0.7, 1.4), Hue = rng:NextNumber() })
	end
	ctx.PortalCore = K.quad(ph, CFrame.new(), 200, 200, "rbxasset://sky/sun.jpg", { Color = Color3.fromRGB(255, 255, 255), Brightness = 2, Transparency = 0.35 })
end

------------------------------------------------------------------------
-- PORTAL: through the portal, bent starlight wraps into a vortex
------------------------------------------------------------------------
function Ch.Portal(ctx, t0, dur)
	local K = ctx.kit
	local E = K.E
	local set = ctx.sets.Portal
	set.Parent = ctx.stage
	K.lighting("Anti", 0)
	K.Blur.Enabled = false
	local ph = ctx.PortalHost
	local P = ph.Position
	local tunnel = K.loop(K.S.Tunnel, 0.9, 0.2, 0.8)
	K.sfx(K.S.Portal2, 1, 0.6)
	K.sfx(K.S.Whoosh, 1, 0.4, { Reverb = 3 })
	local cue = K.once()
	local me = ctx.myRig
	local fwd = Vector3.new(0, 0, -1)
	for _, rig in pairs(ctx.rigs) do rig.Smooth = 10 end

	K.run(t0, dur, function(t, dt)
		local e = K.k(t, 0, dur)
		local speed = K.lerp(1, 3.2, E.inQuad(e))
		-- colour: the portal's violet, deepening into the Anti-Spiral's purple and cyan
		local cA = Color3.fromRGB(205, 140, 255):Lerp(Color3.fromRGB(150, 90, 255), K.k(t, 0.5, 3))
		local cB = Color3.fromRGB(235, 215, 255):Lerp(Color3.fromRGB(80, 220, 255), K.k(t, 1, 3.5))
		local camCF = CFrame.lookAt(P, P + fwd) * CFrame.Angles(0, 0, t * K.lerp(0.8, 3, e))
		for i, pr in ipairs(ctx.PortalRings) do
			local z = (pr.Z + t * 0.35 * speed) % 1
			local depth = z * 600
			local cf = camCF * CFrame.new(0, 0, -600 + depth) * CFrame.Angles(0, 0, t * pr.Spin)
			local r0 = K.lerp(40, 14, z) * (1 + math.sin(t * 3 + i) * 0.1)
			-- three arms per ring, each ring's arms turned a little further than the
			-- last, so the whole tunnel reads as one twisting vortex
			pr.Ring.update(cf, r0, r0 + K.lerp(110, 36, z), t * pr.Spin, function(ang)
				return 0.3 + 0.7 * (0.5 + 0.5 * math.cos(3 * (ang - t * pr.Spin) + z * 9 - t * 4))
			end)
			local a = math.clamp(math.min(z / 0.2, (1 - z) / 0.15), 0, 1) * 0.8
			pr.Ring.setTransparency(K.ns(math.min(0.99, 1 - a)))
			for _, q in ipairs(pr.Ring.Q) do q.Color = ColorSequence.new(i % 2 == 0 and cA or cB, cA) end
		end
		for _, st in ipairs(ctx.PortalStreaks) do
			local z = (st.Z + t * st.Speed * 0.5 * speed) % 1
			local ang = st.Ang + z * 3 + t * 1.2
			local b = camCF * CFrame.new(math.cos(ang) * st.R, math.sin(ang) * st.R, -600 + z * 640)
			st.Beam.Attachment0.WorldPosition = b.Position
			st.Beam.Attachment1.WorldPosition = (b * CFrame.new(math.cos(ang + 0.4) * 6, math.sin(ang + 0.4) * 6, 30 + speed * 40)).Position
			st.Beam.Color = ColorSequence.new(st.Hue > 0.5 and cA or cB)
		end
		K.moveQuad(ctx.PortalCore, camCF * CFrame.new(0, 0, -620) * CFrame.Angles(0, 0, t))
		ctx.PortalCore.Color = ColorSequence.new(cB)
		K.setQuadSize(ctx.PortalCore, K.lerp(70, 560, E.inQuad(e)), K.lerp(70, 560, E.inQuad(e)))
		-- the party tumbling down the tunnel ahead of you
		local center
		for slot, rig in pairs(ctx.rigs) do
			local a = slot * 2.2 + t * 0.9
			local r = ctx.n > 1 and (4 + (slot % 3) * 2.5) or 0
			local p = (camCF * CFrame.new(math.cos(a) * r, math.sin(a) * r - 1.5, -16 - (slot % 3) * 5 - e * 6)).Position
			rig:setCF(CFrame.new(p) * K.zeroGRot(t * 4, slot, 1.6, slot % 2 == 0 and 1 or -1))
			rig:setPose(K.mixPose(K.zeroGPose(t * 4, slot, 1.5), K.Poses.Blown, 0.4))
			rig:apply()
			if rig == me then center = p end
		end
		K.setCam(camCF, K.lerp(80, 115, E.inQuad(e)))
		K.shake(0.8 + e * 1.5, 0.1, 22, true)
		K.Grade.TintColor = Color3.new(1, 1, 1):Lerp(cB, 0.25)
		cue("out", t >= dur - 0.6, function()
			K.flash(0.4, Color3.fromRGB(220, 200, 255), 1)
			K.fade(1, 0.5)
			K.stopAllSounds(0.6)
			ctx.fadeMusic(0, 0.5)
		end)
		K.stream(P)
	end)
	K.fadeSound(tunnel, 0, 0.3, true)
	K.Grade.TintColor = Color3.new(1, 1, 1)
	set.Parent = nil
end

return Ch
