-- ModuleScript | ServerStorage.BossSpikes   (directly in ServerStorage, NOT in BossAttacks)
-- Runs every spike hazard from one place, so hundreds of them cost very little:
--   * spikes and warning discs are pooled: created once, then reused (no clone/destroy per spike)
--   * one Heartbeat loop drives every warning, rise and hit check (no thread or tween per spike)
--   * damage is a distance check here, not a script inside each spike. Any Script inside the
--     Spike asset is removed from the pooled copies, so no spike runs code of its own.
local RunService = game:GetService("RunService")

local PLAYER_SLOP = 2.5      -- roughly the size of a character around its root part
local BURIED_DEPTH = 8       -- spikes rise from this far below the floor
local PARK_DEPTH = 60        -- idle pooled parts wait this far below the floor
local BELOW_FLOOR = 5        -- a player this far below the floor can no longer be hit
local FILL_INTERVAL = 1 / 20 -- how often a growing warning disc updates its size (seconds)

local Spikes = {}
Spikes.__index = Spikes

local function alwaysAlive()
	return true
end

-- Horizontal radius and height of the Spike asset, used as its hitbox unless overridden
local function measure(template)
	local size = if template:IsA("Model") then template:GetExtentsSize() else template.Size
	return (math.max(size.X, size.Z) / 2) * 0.6, size.Y
end

function Spikes.new(boss, template)
	local self = setmetatable({}, Spikes)
	self.Boss = boss
	self.Template = template
	self.HitRadius, self.HitHeight = measure(template)
	self.Active = {}       -- every strike in flight (warning or up)
	self.FreeSpikes = {}   -- pooled spikes waiting to be reused
	self.FreeWarnings = {} -- pooled warning discs waiting to be reused
	self.Destroyed = false

	-- Idle pooled parts wait below the map (but above the height where Roblox deletes fallen parts)
	local arena = boss.Arena
	local parkY = math.max(arena.SurfaceY - PARK_DEPTH, workspace.FallenPartsDestroyHeight + 20)
	self.ParkCFrame = CFrame.new(arena.Center.X, parkY, arena.Center.Z)

	self.Folder = Instance.new("Folder")
	self.Folder.Name = "Spikes"
	self.Folder.Parent = boss.Effects

	self.Connection = RunService.Heartbeat:Connect(function()
		self:_step()
	end)
	return self
end

function Spikes:_newSpike()
	local spike = self.Template:Clone()

	-- damage is handled centrally, so the asset's own scripts aren't needed
	for _, item in spike:GetDescendants() do
		if item:IsA("BaseScript") then
			item:Destroy()
		end
	end

	local function prepare(part)
		part.Anchored = true
		part.CanTouch = false
		part.CanQuery = false
	end
	if spike:IsA("BasePart") then
		prepare(spike)
	end
	for _, item in spike:GetDescendants() do
		if item:IsA("BasePart") then
			prepare(item)
		end
	end

	spike:PivotTo(self.ParkCFrame)
	spike.Parent = self.Folder
	return spike
end

function Spikes:_newWarning()
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.2, 0.05, 0.05)
	part.CFrame = self.ParkCFrame
	part.Color = Color3.fromRGB(255, 40, 40)
	part.Material = Enum.Material.Neon
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = self.Folder
	return part
end

-- Warning disc grows over `Warning` seconds, then the spike rises out of the floor over `Rise`
-- seconds and stays up for `Hold` seconds. Anyone inside its hitbox while it's up takes `Damage`
-- once. Doesn't yield.
-- opts: Warning, WarnRadius, Rise, Hold, Damage,
--       HitRadius / HitHeight (optional; default to the Spike asset's size),
--       Alive (optional function; if it returns false when the warning ends, the spike never erupts)
function Spikes:Strike(point, opts)
	if self.Destroyed then return end
	-- 8 minions x 5 spikes/sec used to be able to stack hundreds of live spikes;
	-- past this many in flight new strikes are simply skipped
	if #self.Active >= 90 then return end

	local warning = table.remove(self.FreeWarnings) or self:_newWarning()
	-- cylinders point along X, so roll it 90 degrees to lie flat
	warning.CFrame = CFrame.new(point + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	warning.Size = Vector3.new(0.2, 0.05, 0.05)
	warning.Transparency = 0.5

	table.insert(self.Active, {
		state = "warning",
		point = point,
		start = os.clock(),
		lastFill = 0,
		warning = opts.Warning,
		warnRadius = opts.WarnRadius,
		rise = opts.Rise,
		hold = opts.Hold,
		damage = opts.Damage,
		hitRadius = opts.HitRadius or self.HitRadius,
		hitHeight = opts.HitHeight or self.HitHeight,
		alive = opts.Alive or alwaysAlive,
		warningPart = warning,
		hit = {}, -- characters this spike already damaged
	})
end

function Spikes:_releaseWarning(event)
	local part = event.warningPart
	part.Transparency = 1
	part.CFrame = self.ParkCFrame
	table.insert(self.FreeWarnings, part)
	event.warningPart = nil
end

function Spikes:_erupt(event)
	local spike = table.remove(self.FreeSpikes) or self:_newSpike()
	event.spike = spike
	event.startCFrame = CFrame.new(event.point - Vector3.new(0, BURIED_DEPTH, 0))
	event.endCFrame = CFrame.new(event.point)
	spike:PivotTo(event.startCFrame)
	event.state = "up"
end

function Spikes:_releaseSpike(event)
	event.spike:PivotTo(self.ParkCFrame)
	table.insert(self.FreeSpikes, event.spike)
	event.spike = nil
end

function Spikes:_damage(event, targets)
	for _, root in targets do
		local character = root.Parent
		if not event.hit[character] then
			local offset = root.Position - event.point
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flat <= event.hitRadius + PLAYER_SLOP
				and offset.Y >= -BELOW_FLOOR
				and offset.Y <= event.hitHeight + PLAYER_SLOP then
				event.hit[character] = true
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:TakeDamage(event.damage)
				end
			end
		end
	end
end

function Spikes:_step()
	local boss = self.Boss
	if not boss.Alive then
		self:Destroy()
		return
	end

	local now = os.clock()
	local targets -- fetched once per frame, and only if some spike is up

	local i = 1
	while i <= #self.Active do
		local event = self.Active[i]
		local age = now - event.start

		if event.state == "warning" then
			if age < event.warning then
				-- grow the disc, but only ~20 times a second to keep network traffic down
				if now - event.lastFill >= FILL_INTERVAL then
					event.lastFill = now
					local alpha = age / event.warning
					local diameter = math.max(event.warnRadius * 2 * alpha, 0.05)
					event.warningPart.Size = Vector3.new(0.2, diameter, diameter)
					event.warningPart.Transparency = 0.5 - 0.2 * alpha
				end
			else
				self:_releaseWarning(event)
				if event.alive() then
					self:_erupt(event)
				else
					event.state = "done"
				end
			end
		end

		if event.state == "up" then
			local upAge = age - event.warning
			if upAge >= event.rise + event.hold then
				self:_releaseSpike(event)
				event.state = "done"
			else
				if upAge < event.rise then
					event.spike:PivotTo(event.startCFrame:Lerp(event.endCFrame, upAge / event.rise))
				elseif not event.risen then
					event.risen = true
					event.spike:PivotTo(event.endCFrame)
				end

				targets = targets or boss:GetTargets()
				self:_damage(event, targets)
			end
		end

		if event.state == "done" then
			-- swap-remove; don't advance, the swapped-in event needs its turn
			self.Active[i] = self.Active[#self.Active]
			self.Active[#self.Active] = nil
		else
			i += 1
		end
	end
end

function Spikes:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	self.Connection:Disconnect()
	self.Active = {}
	self.FreeSpikes = {}
	self.FreeWarnings = {}
	self.Folder:Destroy()
end

return Spikes