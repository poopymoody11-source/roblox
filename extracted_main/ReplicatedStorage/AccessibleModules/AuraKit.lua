--==================================================
-- AURA KIT  (client)
--
-- Shared plumbing for the code-built auras (Tide, Prism, Inferno,
-- Ascendant). Each aura builds its parts once, then every frame it
-- queues a CFrame for each part and the kit moves them all in ONE
-- workspace:BulkMoveTo call -- far cheaper than setting CFrame part by
-- part when eight players nearby are all wearing one.
--
--   local kit = AuraKit.new(character, "TideAura", updateFn)
--   kit:part{...}            anchored, non-colliding neon part
--   kit:emitter(parent, {})  particle emitter
--   kit:place(part, cframe)  queue a move for this frame
--   kit.groundY              floor height under the player (raycast)
--   kit:Destroy()
--==================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local AuraKit = {}
AuraKit.__index = AuraKit

AuraKit.SPARK = "rbxasset://textures/particles/sparkles_main.dds"
AuraKit.SMOKE = "rbxasset://textures/particles/smoke_main.dds"
AuraKit.FIRE = "rbxasset://textures/particles/fire_main.dds"
AuraKit.EMBERS = "rbxasset://textures/particles/fire_sparks_main.dds"

local container = workspace:FindFirstChild("ClientAuras")
if not container then
	container = Instance.new("Folder")
	container.Name = "ClientAuras"
	container.Parent = workspace
end
AuraKit.Container = container

function AuraKit.lowGraphics()
	return Players.LocalPlayer and Players.LocalPlayer:GetAttribute("Set_LowGraphics") == true
end

-- scale a count by the graphics budget, never below `min`
function AuraKit.count(n, min)
	if AuraKit.lowGraphics() then
		return math.max(min or 1, math.floor(n * 0.5))
	end
	return n
end

function AuraKit.new(character, name, update)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local self = setmetatable({}, AuraKit)
	self.character = character
	self.root = root
	self.humanoid = character:FindFirstChildOfClass("Humanoid")
	self.t0 = os.clock()
	self.connections = {}
	self.moveParts = {}
	self.moveCFrames = {}
	self.groundY = root.Position.Y - 3
	self.nextGround = 0
	self.flare = 0 -- 1 on jump / landing, decays; auras use it for bursts

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = container
	self.folder = folder

	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.rayParams.FilterDescendantsInstances = { character, container }

	-- invisible part that carries the particle emitters and light
	self.core = self:part({ Name = "Core", Size = Vector3.one * 0.2, Transparency = 1 })

	if self.humanoid then
		table.insert(self.connections, self.humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				self.flare = 1
				if self.onJump then self:onJump() end
			elseif new == Enum.HumanoidStateType.Landed then
				if self.onLand then self:onLand() end
			end
		end))
	end

	self.update = update
	table.insert(self.connections, RunService.RenderStepped:Connect(function(dt)
		if not root.Parent or not character.Parent then
			self:Destroy()
			return
		end
		local now = os.clock()
		if now >= self.nextGround then
			self.nextGround = now + 0.2
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), self.rayParams)
			self.groundY = hit and hit.Position.Y or (root.Position.Y - 3)
		end
		self.flare = math.max(0, self.flare - dt * 1.5)
		table.clear(self.moveParts)
		table.clear(self.moveCFrames)
		local ok, err = pcall(self.update, self, dt, now - self.t0)
		if not ok then
			warn("[" .. name .. "] " .. tostring(err))
			self:Destroy()
			return
		end
		if #self.moveParts > 0 then
			workspace:BulkMoveTo(self.moveParts, self.moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end))

	return self
end

function AuraKit:part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Locked = true
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = self.root and self.root.CFrame or CFrame.identity
	for k, v in pairs(props) do p[k] = v end
	p.Parent = self.folder
	return p
end

function AuraKit:emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.Rotation = NumberRange.new(0, 360)
	for k, v in pairs(props) do e[k] = v end
	e.Parent = parent
	return e
end

function AuraKit:attachment(parent, pos)
	local a = Instance.new("Attachment")
	a.Position = pos or Vector3.zero
	a.Parent = parent
	return a
end

function AuraKit:trail(p, colour, life, width)
	local a0 = self:attachment(p, Vector3.new(0, width or 0.25, 0))
	local a1 = self:attachment(p, Vector3.new(0, -(width or 0.25), 0))
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = life or 0.4
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.Color = typeof(colour) == "ColorSequence" and colour or ColorSequence.new(colour)
	tr.Transparency = NumberSequence.new(0.1, 1)
	tr.WidthScale = NumberSequence.new(1, 0)
	tr.Parent = p
	return tr
end

function AuraKit:place(p, cf)
	local n = #self.moveParts + 1
	self.moveParts[n] = p
	self.moveCFrames[n] = cf
end

-- CFrame for a flat ring segment: centre `c`, angle `a`, radius `r`
function AuraKit.ringCF(c, a, r)
	local pos = c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	return CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
end

function AuraKit:Destroy()
	for _, c in ipairs(self.connections) do
		pcall(function() c:Disconnect() end)
	end
	self.connections = {}
	if self.folder then self.folder:Destroy() end
	self.folder = nil
end

return AuraKit
