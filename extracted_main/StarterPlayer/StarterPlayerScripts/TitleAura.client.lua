--==================================================
-- TITLE AURA  (CLIENT)
--
-- Rarer title = tougher aura. The auras themselves are
-- the authored rigs in Workspace.effects.Auras, cloned
-- onto the player:
--     Rare      tide       Water-Aura-01
--     Epic      prism      RNG-Aura-03
--     Legendary inferno    Fire-Aura-01
--     Mythic    ascendant  RNG-Aura-02
--
-- The source rigs are R6 dummies and players here are
-- R15, so limb emitters are remapped by name. The RNG
-- auras hang everything off the HumanoidRootPart, which
-- ports across rigs untouched -- their beams just need
-- rewiring to the cloned attachments.
--
-- Entirely client-side and budgeted: only players within
-- AURA_RADIUS get one, and never more than MAX_AURAS at
-- once (nearest first), so a busy lobby can't tank you.
--
-- Reads two attributes TitleService publishes on each
-- player: EquippedTitle and AuraEnabled. Toggling the
-- aura off in the titles panel clears it for everybody.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local TitleData = require(
	ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("TitleDataModule")
)

local CONFIG = {
	AURA_RADIUS = 130,
	MAX_AURAS = 8,
	UPDATE_INTERVAL = 0.5,
}

local active = {}   -- [player] = {folder = Instance, key = string}

--==================================================
-- BUILDING AN AURA
--==================================================

-- Where the source rigs live.
local function auraFolder()
	local effects = workspace:FindFirstChild("effects")
	return effects and effects:FindFirstChild("Auras")
end

-- The source rigs are R6. Players are R15. Each R6 limb maps
-- to ONE R15 part rather than all of them -- mapping "Left Arm"
-- onto LeftUpperArm + LeftLowerArm + LeftHand would triple the
-- particle count for no visual gain.
local R6_TO_R15 = {
	["Head"] = "Head",
	["Torso"] = "UpperTorso",
	["Left Arm"] = "LeftLowerArm",
	["Right Arm"] = "RightLowerArm",
	["Left Leg"] = "LeftLowerLeg",
	["Right Leg"] = "RightLowerLeg",
	["HumanoidRootPart"] = "HumanoidRootPart",
}

local function targetPartFor(character, sourceName)
	-- An R6 player would have the part under its own name.
	local direct = character:FindFirstChild(sourceName)
	if direct and direct:IsA("BasePart") then
		return direct
	end

	local mapped = R6_TO_R15[sourceName]
	if not mapped then return nil end

	local part = character:FindFirstChild(mapped)
	return (part and part:IsA("BasePart")) and part or nil
end

local function isEffect(instance)
	return instance:IsA("ParticleEmitter")
		or instance:IsA("Trail")
		or instance:IsA("PointLight")
		or instance:IsA("SpotLight")
		or instance:IsA("Beam")
		or instance:IsA("Sparkles")
		or instance:IsA("Fire")
		or instance:IsA("Smoke")
end

--==================================================
-- BUILDING AN AURA
--
-- Returns a flat list of everything it created so
-- cleanup doesn't have to go looking.
--==================================================

local function buildAura(character, rootPart, spec)
	-- Code-built auras (the DEVELOPER one) live in their own module.
	if spec.Code then
		local mod = ReplicatedStorage.AccessibleModules:FindFirstChild(spec.Code)
		local ok, lib = pcall(require, mod)
		if not ok or not lib then
			warn("[TitleAura] couldn't load " .. tostring(spec.Code) .. ": " .. tostring(lib))
			return nil
		end
		local handle = lib.new(character)
		return handle and { handle } or nil
	end

	local folder = auraFolder()
	local source = folder and spec.Model and folder:FindFirstChild(spec.Model)

	if not source then
		warn("[TitleAura] missing effect rig: " .. tostring(spec.Model))
		return nil
	end

	local created = {}
	local attachmentMap = {}   -- [source attachment] = clone
	local beams = {}           -- clones still needing rewiring

	-- A beam's two endpoints are often attachments that hold no
	-- effect of their own -- they exist purely to anchor the line.
	-- Without this pre-pass those never get cloned, the rewiring
	-- finds nothing to point at, and the beams get dropped: the
	-- halo aura came through with its particles but no beams at all.
	local endpointsNeeded = {}
	for _, d in ipairs(source:GetDescendants()) do
		if d:IsA("Beam") then
			if d.Attachment0 then endpointsNeeded[d.Attachment0] = true end
			if d.Attachment1 then endpointsNeeded[d.Attachment1] = true end
		end
	end

	for _, sourcePart in ipairs(source:GetChildren()) do
		if sourcePart:IsA("BasePart") then
			local target = targetPartFor(character, sourcePart.Name)

			if target then
				for _, child in ipairs(sourcePart:GetChildren()) do
					if child:IsA("Attachment") then
						-- Only attachments that actually carry effects.
						-- The rig is full of stock ones (HatAttachment,
						-- RootAttachment...) and cloning those onto a
						-- player would collide with the real ones.
						local carries = endpointsNeeded[child] == true
						if not carries then
							for _, sub in ipairs(child:GetDescendants()) do
								if isEffect(sub) then carries = true break end
							end
						end

						if carries then
							local clone = child:Clone()
							attachmentMap[child] = clone
							clone.Parent = target
							table.insert(created, clone)

							for _, sub in ipairs(clone:GetDescendants()) do
								if sub:IsA("Beam") then table.insert(beams, sub) end
							end
						end

					elseif isEffect(child) then
						local clone = child:Clone()
						clone.Parent = target
						table.insert(created, clone)
						if clone:IsA("Beam") then table.insert(beams, clone) end
					end
				end
			end
		end
	end

	-- A cloned Beam still points at the SOURCE rig's attachments,
	-- so until this runs the aura renders stretched across the map
	-- between the player and wherever the effects folder sits.
	for _, beam in ipairs(beams) do
		if beam.Attachment0 and attachmentMap[beam.Attachment0] then
			beam.Attachment0 = attachmentMap[beam.Attachment0]
		end
		if beam.Attachment1 and attachmentMap[beam.Attachment1] then
			beam.Attachment1 = attachmentMap[beam.Attachment1]
		end

		-- Anything still pointing outside the character is a beam
		-- whose far end lives on a limb we didn't map. Drop it
		-- rather than leave a line across the world.
		local a0 = beam.Attachment0
		local a1 = beam.Attachment1
		if (a0 and not a0:IsDescendantOf(character))
			or (a1 and not a1:IsDescendantOf(character)) then
			beam.Enabled = false
		end
	end

	if #created == 0 then
		return nil
	end

	return created
end

local function clearAura(player)
	local entry = active[player]
	if not entry then return end

	for _, instance in ipairs(entry.instances or {}) do
		if type(instance) == "table" then
			instance:Destroy()
		elseif instance and instance.Parent then
			instance:Destroy()
		end
	end

	active[player] = nil
end

-- While this client is watching a cutscene (anything that sets a
-- HideHud_* attribute on the local player) every aura is taken down, so
-- nothing glowing gets in the way of the shot.
local function inCinematic()
	local me = Players.LocalPlayer
	if not me then return false end
	-- any scripted camera (opening, tutorial, portals, bosses) counts too
	local cam = workspace.CurrentCamera
	if cam and cam.CameraType == Enum.CameraType.Scriptable then return true end
	for k, v in pairs(me:GetAttributes()) do
		if v and (k:sub(1, 8) == "HideHud_" or k:sub(1, 9) == "HideAura_") then return true end
	end
	return false
end

local function wantedAuraFor(player)
	if inCinematic() then return nil end
	if player:GetAttribute("AuraEnabled") == false then return nil end

	local titleId = player:GetAttribute("EquippedTitle")
	if not titleId then return nil end

	local key, spec = TitleData.GetAura(titleId)
	if not key or not spec then return nil end

	return key, spec
end

local function applyAura(player)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		clearAura(player)
		return
	end

	local key, spec = wantedAuraFor(player)
	local entry = active[player]

	if not key then
		clearAura(player)
		return
	end

	-- already correct, and still on the live character
	if entry and entry.key == key and entry.character == character then
		return
	end

	clearAura(player)

	local instances = buildAura(character, rootPart, spec)
	if instances then
		active[player] = {instances = instances, key = key, character = character}
	end
end

--==================================================
-- BUDGETED UPDATE LOOP
--==================================================

local candidates = {}

task.spawn(function()
	while task.wait(CONFIG.UPDATE_INTERVAL) do
		local camera = workspace.CurrentCamera
		if not camera then continue end
		local origin = camera.CFrame.Position

		table.clear(candidates)

		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local distance = (rootPart.Position - origin).Magnitude
				if distance <= CONFIG.AURA_RADIUS and wantedAuraFor(player) then
					table.insert(candidates, {player = player, d = distance})
				else
					clearAura(player)
				end
			else
				clearAura(player)
			end
		end

		table.sort(candidates, function(a, b) return a.d < b.d end)

		for index, entry in ipairs(candidates) do
			if index <= CONFIG.MAX_AURAS then
				applyAura(entry.player)
			else
				clearAura(entry.player)
			end
		end
	end
end)

--==================================================
-- REACT IMMEDIATELY TO CHANGES
--==================================================

local function hook(player)
	player:GetAttributeChangedSignal("EquippedTitle"):Connect(function()
		applyAura(player)
	end)
	player:GetAttributeChangedSignal("AuraEnabled"):Connect(function()
		applyAura(player)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.6)
		applyAura(player)
	end)
end

Players.LocalPlayer.AttributeChanged:Connect(function(name)
	if name:sub(1, 8) ~= "HideHud_" and name:sub(1, 9) ~= "HideAura_" then return end
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(applyAura, player)
	end
end)

-- scripted camera on/off (cutscenes that don't set a HideHud_ attribute)
local camConn
local function watchCamera(cam)
	if camConn then camConn:Disconnect() end
	if not cam then return end
	camConn = cam:GetPropertyChangedSignal("CameraType"):Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(applyAura, player)
		end
	end)
end
watchCamera(workspace.CurrentCamera)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() watchCamera(workspace.CurrentCamera) end)

Players.PlayerAdded:Connect(hook)
for _, player in ipairs(Players:GetPlayers()) do hook(player) end
Players.PlayerRemoving:Connect(clearAura)
