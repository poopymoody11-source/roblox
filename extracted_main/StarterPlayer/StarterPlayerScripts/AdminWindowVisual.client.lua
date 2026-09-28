--==================================================
-- ADMIN WINDOW  (client, everyone sees it)
--
-- While a developer has the admin panel open, a floating
-- holographic "ADMINISTRATOR" console appears in the world
-- in front of them: a glowing frame, scrolling code, a
-- rotating ring and a beam down to their hands. Everyone in
-- the server can see it, so it reads as the admin doing
-- something rather than just staring at their screen.
--
-- Driven by the AdminPanelOpen player attribute, which
-- AdminPanelClient sets on itself and replicates.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PURPLE = Color3.fromRGB(190, 110, 255)
local CYAN = Color3.fromRGB(120, 220, 255)
local DARK = Color3.fromRGB(12, 6, 24)

local CODE = {
	"> admin.authenticate(root)", "> access granted", "> loading player registry...",
	"> peacepoints.grant(1e12)", "> titles.unlock(*)", "> plots.rebuild()",
	"> lapis.spawn_rate = MAX", "> passes.refresh()", "> quests.complete(all)",
	"> ascension.set(25)", "> world.integrity = 100%", "> awaiting input_",
}

local holder = workspace:FindFirstChild("ClientAuras")
if not holder then
	holder = Instance.new("Folder")
	holder.Name = "ClientAuras"
	holder.Parent = workspace
end

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	return p
end

--==================================================
-- BUILD ONE CONSOLE
--==================================================

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "AdminWindow"
	folder.Parent = holder
	local b = { folder = folder, t0 = os.clock(), bars = {} }

	-- the screen: a thin dark pane with a glowing edge
	local screen = part({ Size = Vector3.new(8.6, 5.2, 0.12), Color = DARK, Material = Enum.Material.SmoothPlastic, Transparency = 0.12, Parent = folder })
	b.screen = screen
	local edge = part({ Size = Vector3.new(9.1, 5.7, 0.06), Color = PURPLE, Transparency = 0.35, Parent = folder })
	b.edge = edge

	-- corner brackets
	b.corners = {}
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			local h = part({ Size = Vector3.new(1.3, 0.14, 0.14), Color = CYAN, Parent = folder })
			local v = part({ Size = Vector3.new(0.14, 1.1, 0.14), Color = CYAN, Parent = folder })
			table.insert(b.corners, { h = h, v = v, sx = sx, sy = sy })
		end
	end

	-- rotating ring behind the screen
	b.rings = {}
	for i = 1, 2 do
		local r = part({
			Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 6.4 - i * 1.4, 6.4 - i * 1.4),
			Color = (i == 1) and PURPLE or CYAN, Material = Enum.Material.ForceField, Parent = folder,
		})
		table.insert(b.rings, r)
	end

	-- The screen contents, drawn on BOTH faces: the admin reads it from
	-- behind, everyone else sees it from the front.
	b.lines = {}
	b.titles = {}
	for _, face in ipairs({ Enum.NormalId.Back, Enum.NormalId.Front }) do
		local surface = new("SurfaceGui", {
			Name = "Console", Face = face, CanvasSize = Vector2.new(560, 340),
			LightInfluence = 0, AlwaysOnTop = false, Adornee = screen, Parent = screen,
		})
		new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = DARK, BackgroundTransparency = 0.2, Parent = surface })
		local title = new("TextLabel", {
			Position = UDim2.fromScale(0.04, 0.04), Size = UDim2.fromScale(0.92, 0.17), BackgroundTransparency = 1,
			Font = Enum.Font.Code, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(225, 170, 255), Text = "ADMINISTRATOR", Parent = surface,
		})
		table.insert(b.titles, title)
		new("Frame", {
			Position = UDim2.fromScale(0.04, 0.23), Size = UDim2.fromScale(0.92, 0.012),
			BackgroundColor3 = PURPLE, BorderSizePixel = 0, Parent = surface,
		})
		local list = new("Frame", {
			Position = UDim2.fromScale(0.04, 0.27), Size = UDim2.fromScale(0.92, 0.68),
			BackgroundTransparency = 1, ClipsDescendants = true, Parent = surface,
		}, { new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local set = {}
		for i = 1, 7 do
			set[i] = new("TextLabel", {
				LayoutOrder = i, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
				Font = Enum.Font.Code, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = CYAN, Text = "", Parent = list,
			})
		end
		table.insert(b.lines, set)
	end
	b.feed = 0
	b.nextFeed = 0

	-- No floating nameplate here on purpose: the admin's own aura already
	-- carries a DEVELOPER plate over their head, and two stacked titles on
	-- one player read as clutter.

	-- beams from the admin's hands up to the screen
	local anchor = part({ Size = Vector3.one * 0.1, Transparency = 1, Parent = folder })
	b.anchor = anchor
	local a0 = Instance.new("Attachment") a0.Parent = anchor
	local a1 = Instance.new("Attachment") a1.Parent = screen
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1 = 1.6, 0.2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 1.2
	beam.TextureSpeed = -2
	beam.Color = ColorSequence.new(CYAN, PURPLE)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.9),
	})
	beam.Parent = anchor

	local glow = Instance.new("PointLight")
	glow.Color = PURPLE
	glow.Range = 16
	glow.Brightness = 2.5
	glow.Shadows = false
	glow.Parent = screen
	b.glow = glow

	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(PURPLE, CYAN)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = 12
	pe.Parent = screen

	return b
end

--==================================================
-- DRIVE
--==================================================

local windows = {} -- [player] = built

local function drop(player)
	local w = windows[player]
	if w then w.folder:Destroy() end
	windows[player] = nil
end

local function animate(w, root, dt)
	local t = os.clock() - w.t0
	local base = root.CFrame * CFrame.new(0, 2.2, -5.4)
	local cf = base * CFrame.Angles(math.rad(-8), 0, math.rad(math.sin(t * 0.7) * 1.5))
		* CFrame.new(0, math.sin(t * 1.3) * 0.12, 0)

	w.screen.CFrame = cf
	w.edge.CFrame = cf * CFrame.new(0, 0, 0.05)
	w.anchor.CFrame = root.CFrame * CFrame.new(0, 0.2, -0.8)

	for _, c in ipairs(w.corners) do
		local x, y = c.sx * 3.85, c.sy * 2.3
		c.h.CFrame = cf * CFrame.new(x - c.sx * 0.55, y, -0.06)
		c.v.CFrame = cf * CFrame.new(x, y - c.sy * 0.45, -0.06)
	end

	for i, r in ipairs(w.rings) do
		local dir = (i == 1) and 1 or -1
		r.CFrame = cf * CFrame.new(0, 0, 0.6) * CFrame.Angles(0, 0, t * 0.9 * dir) * CFrame.Angles(0, math.rad(90), 0)
	end

	local pulse = (math.sin(t * 3) + 1) / 2
	w.glow.Brightness = 1.8 + pulse * 1.8
	w.edge.Transparency = 0.45 - pulse * 0.2
	for _, title in ipairs(w.titles) do
		title.Text = "ADMINISTRATOR" .. ((math.floor(t * 2) % 2 == 0) and " \u{2588}" or "")
	end

	-- scrolling console feed (mirrored on both faces)
	if t > w.nextFeed then
		w.nextFeed = t + 0.45
		w.feed += 1
		for _, set in ipairs(w.lines) do
			for i = 1, #set - 1 do
				set[i].Text = set[i + 1].Text
				set[i].TextTransparency = 0.45
			end
			local last = set[#set]
			last.Text = CODE[(w.feed % #CODE) + 1]
			last.TextTransparency = 0
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local open = player:GetAttribute("AdminPanelOpen") == true
		local near = root and (not camPos or (camPos - root.Position).Magnitude < 220)

		if open and root and near then
			if not windows[player] then windows[player] = build() end
			animate(windows[player], root, dt)
		elseif windows[player] then
			drop(player)
		end
	end

	for player in pairs(windows) do
		if not player.Parent then drop(player) end
	end
end)

Players.PlayerRemoving:Connect(drop)
