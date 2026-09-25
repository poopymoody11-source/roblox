-- shared helpers for the GalaxyRealm generator (a build-time tool; not used at runtime)
local C = Vector3.new(0, 0, 20000)          -- arena centre
local BF = workspace.BossFight
local realm = BF:FindFirstChild("GalaxyRealm")
if not realm then
	realm = Instance.new("Model")
	realm.Name = "GalaxyRealm"
	realm.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	realm.Parent = BF
end
local function stage(name)
	local old = realm:FindFirstChild(name)
	if old then old:Destroy() end
	local f = Instance.new("Model")
	f.Name = name
	f.Parent = realm
	return f
end
local function host(parent, name, pos)
	local p = Instance.new("Part")
	p.Name = name or "Host"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(pos or C)
	p.Parent = parent
	return p
end
local function ns(...)
	local a = { ... }
	if #a == 1 then return NumberSequence.new(a[1]) end
	local k = {}
	for i = 1, #a, 2 do table.insert(k, NumberSequenceKeypoint.new(a[i], a[i + 1])) end
	return NumberSequence.new(k)
end
local function cs(...)
	local a = { ... }
	if #a == 1 then return ColorSequence.new(a[1]) end
	if typeof(a[1]) == "Color3" and #a == 2 then return ColorSequence.new(a[1], a[2]) end
	local k = {}
	for i = 1, #a, 2 do table.insert(k, ColorSequenceKeypoint.new(a[i], a[i + 1])) end
	return ColorSequence.new(k)
end
-- a flat textured quad (Beam) centred on cf, spanning cf.X (w) and cf.Y (h), facing cf.Look
local function quad(h, cf, w, hh, tex, o)
	o = o or {}
	local rel = h.CFrame:ToObjectSpace(cf)
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	a0.CFrame = rel * CFrame.new(-w / 2, 0, 0)
	a1.CFrame = rel * CFrame.new(w / 2, 0, 0)
	a0.Parent = h
	a1.Parent = h
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = hh
	b.Width1 = hh
	b.FaceCamera = false
	b.Segments = 1
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.TextureSpeed = 0
	b.Texture = tex or ""
	b.LightEmission = o.Emission or 1
	b.LightInfluence = 0
	b.Brightness = o.Brightness or 1
	b.ZOffset = o.ZOffset or 0
	local tr = o.Transparency or 0
	b.Transparency = typeof(tr) == "NumberSequence" and tr or NumberSequence.new(tr)
	b.Color = typeof(o.Color) == "ColorSequence" and o.Color or ColorSequence.new(o.Color or Color3.new(1, 1, 1))
	if o.Name then b.Name = o.Name end
	b.Parent = h
	return b
end
-- a camera-facing ribbon between two world points (a star, a column of gas, a line)
local function ribbon(h, p0, p1, w0, w1, tex, o)
	o = o or {}
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	a0.Parent = h
	a1.Parent = h
	a0.WorldPosition = p0
	a1.WorldPosition = p1
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = w0
	b.Width1 = w1 or w0
	b.FaceCamera = true
	b.Segments = o.Segments or 1
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.TextureSpeed = o.Speed or 0
	b.Texture = tex or ""
	b.LightEmission = o.Emission or 1
	b.LightInfluence = 0
	b.Brightness = o.Brightness or 1
	b.ZOffset = o.ZOffset or 0
	local tr = o.Transparency or 0
	b.Transparency = typeof(tr) == "NumberSequence" and tr or NumberSequence.new(tr)
	b.Color = typeof(o.Color) == "ColorSequence" and o.Color or ColorSequence.new(o.Color or Color3.new(1, 1, 1))
	if o.Name then b.Name = o.Name end
	b.Parent = h
	return b
end
-- a camera-facing sprite (star, glow) of size s at p: a tiny ribbon along a fixed axis
local function sprite(h, p, s, tex, o)
	o = o or {}
	local ax = o.Axis or Vector3.yAxis
	return ribbon(h, p - ax * (s / 2), p + ax * (s / 2), s, s, tex, o)
end
local T = {
	Cloud = "rbxassetid://10180479311",
	Smoke = "rbxassetid://15058059008",
	Aura = "rbxassetid://15912352592",
	Burst = "rbxassetid://122142232022083",
	Glow = "rbxasset://sky/sun.jpg",
	SoftDot = "rbxassetid://14582794847",
	StarLong = "rbxassetid://122000198974865",
	Star4 = "rbxassetid://131679330853412",
	Star4b = "rbxassetid://133922680220478",
	StarBig = "rbxassetid://15211281419",
	Star8 = "rbxasset://textures/particles/sparkles_main.dds",
	StarSmall = "rbxassetid://14960943986",
	Ring = "rbxassetid://15098067965",
	Disk = "rbxassetid://1084982817",
	Galaxy = { "rbxassetid://12383337533", "rbxassetid://12383662183", "rbxassetid://15057851037", "rbxassetid://383165544", "rbxassetid://11723866809", "rbxassetid://16823444551", "rbxassetid://15058513927" },
}
local PAL = {
	Violet = Color3.fromRGB(140, 70, 255), Deep = Color3.fromRGB(46, 12, 96), Magenta = Color3.fromRGB(255, 80, 210),
	Lav = Color3.fromRGB(205, 180, 255), Gold = Color3.fromRGB(255, 196, 120), Teal = Color3.fromRGB(90, 220, 255),
	Pink = Color3.fromRGB(255, 70, 140), White = Color3.fromRGB(245, 240, 255), Blue = Color3.fromRGB(120, 150, 255),
}
return { C = C, realm = realm, stage = stage, host = host, ns = ns, cs = cs, quad = quad, ribbon = ribbon, sprite = sprite, T = T, PAL = PAL }
