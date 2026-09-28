--==================================================
-- STAFF VISUALS (CLIENT)
--
-- Place in: StarterPlayer > StarterPlayerScripts
-- Type: LocalScript
--
-- Floats and wobbles the lapis above every equipped
-- staff, for every player in the server.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


--==================================================
-- CONFIGURATION
--==================================================

local CONFIG = {

	WOBBLE_ANGLE = 8,        -- degrees of tilt

	WOBBLE_SPEED = 2,        -- wobble cycles/sec-ish

	HOVER_GAP = 0.1,         -- studs of clearance above Spin

	ANCHOR_NAME = "Spin",

	LAPIS_NAME_PATTERN = "lapis",

}


--==================================================
-- TRACKED STAFFS
--
-- [tool] = { Anchor = BasePart, LapisContainer = Instance }
--==================================================

local tracked = {}


--==================================================
-- FIND THE LAPIS CONTAINER
--==================================================

local function findLapisContainer(tool)

	for _, child in ipairs(tool:GetChildren()) do

		if child.Name:lower():find(
			CONFIG.LAPIS_NAME_PATTERN,
			1,
			true
			) then

			return child

		end

	end

	return nil

end


--==================================================
-- TRACK
--==================================================

local function track(tool)

	if not tool:IsA("Tool") then
		return
	end

	if tracked[tool] then
		return
	end


	local anchor = tool:FindFirstChild(CONFIG.ANCHOR_NAME)

	if not anchor or not anchor:IsA("BasePart") then
		return
	end


	local container = findLapisContainer(tool)

	if not container then
		return
	end


	--==================================================
	-- TAKE ALL PARTS OUT OF PHYSICS
	--
	-- Anchor every part inside the container so no sub-parts
	-- drop off or fall through the map while pivoting.
	--==================================================

	if container:IsA("BasePart") then
		container.Anchored = true
		container.CanCollide = false
		container.CanTouch = false
	else
		for _, desc in ipairs(container:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
				desc.CanTouch = false
			end
		end
	end


	-- the OP staff's command block levitates higher, bobs and slowly
	-- turns (its aura lives in OpStaffAura)
	local isCommandBlock = container.Name:lower():find("commandblock", 1, true) ~= nil

	tracked[tool] = {
		Anchor = anchor,
		LapisContainer = container,
		Levitate = isCommandBlock,
	}


	tool.AncestryChanged:Connect(function()

		if not tool:IsDescendantOf(workspace) then
			tracked[tool] = nil
		end

	end)

end


--==================================================
-- DISCOVERY
--==================================================

local function watchCharacter(character)

	for _, child in ipairs(character:GetChildren()) do
		track(child)
	end

	character.ChildAdded:Connect(track)

end


local function watchPlayer(player)

	if player.Character then
		watchCharacter(player.Character)
	end

	player.CharacterAdded:Connect(watchCharacter)

end


for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

Players.PlayerAdded:Connect(watchPlayer)


--==================================================
-- ANIMATE
--==================================================

RunService.RenderStepped:Connect(function()

	local now = workspace:GetServerTimeNow()


	local x =
		math.sin(now * CONFIG.WOBBLE_SPEED)
		* math.rad(CONFIG.WOBBLE_ANGLE)

	local z =
		math.cos(now * CONFIG.WOBBLE_SPEED)
		* math.rad(CONFIG.WOBBLE_ANGLE)


	for tool, parts in pairs(tracked) do

		local anchor = parts.Anchor
		local lapisContainer = parts.LapisContainer


		if not tool.Parent
			or not anchor.Parent
			or not lapisContainer.Parent then

			tracked[tool] = nil
			continue

		end


		-- measured once: GetExtentsSize every frame for every staff
		-- in the server was a noticeable chunk of client frame time
		local lapisHeight = parts.Height
		if not lapisHeight then
			lapisHeight = 1
			if lapisContainer:IsA("Model") then
				lapisHeight = lapisContainer:GetExtentsSize().Y
			elseif lapisContainer:IsA("BasePart") then
				lapisHeight = lapisContainer.Size.Y
			end
			parts.Height = lapisHeight
		end


		local targetPosition =
			anchor.Position
			+ Vector3.new(
				0,
				CONFIG.HOVER_GAP
				+ (anchor.Size.Y / 2)
				+ (lapisHeight / 2),
				0
			)


		local targetCFrame
		if parts.Levitate then
			local bob = 1.2 + math.sin(now * 1.7) * 0.35
			targetCFrame =
				CFrame.new(targetPosition + Vector3.new(0, bob, 0))
				* CFrame.Angles(0, now * 0.9, 0)
				* CFrame.Angles(x * 0.6, 0, z * 0.6)
		else
			targetCFrame =
				CFrame.new(targetPosition)
				* CFrame.Angles(x, 0, z)
		end


		if lapisContainer:IsA("Model") then
			lapisContainer:PivotTo(targetCFrame)
		elseif lapisContainer:IsA("BasePart") then
			lapisContainer.CFrame = targetCFrame
		end

	end

end)