local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local character = script.Parent
local rootPart = character:WaitForChild("HumanoidRootPart")

local Plots = Workspace:WaitForChild("Islands"):WaitForChild("StarterIsland"):WaitForChild("IslandPlots")
local ARROW_DECAL_ID = "rbxassetid://10249261576" 

-- ==========================================
-- 1. SETUP THE BEAM ON THE PLAYER
-- ==========================================
local bodyAttachment = Instance.new("Attachment")
bodyAttachment.Name = "BodyAttachment"
bodyAttachment.Parent = rootPart

local beam = Instance.new("Beam")
beam.Name = "PlotPointerBeam"
beam.Texture = ARROW_DECAL_ID
beam.TextureMode = Enum.TextureMode.Wrap
beam.TextureLength = 4 
beam.TextureSpeed = 1.5 -- Moves arrows from your body to the plot
beam.FaceCamera = true
beam.Width0 = 3
beam.Width1 = 3
beam.LightEmission = 1
beam.Enabled = false
beam.Attachment1 = bodyAttachment
beam.Parent = character

-- ==========================================
-- 2. HELPER FUNCTIONS
-- ==========================================
local function doesPlayerOwnAPlot()
	for _, plot in ipairs(Plots:GetChildren()) do
		local ownerValue = plot:FindFirstChild("Owner")
		if ownerValue and ownerValue.Value == localPlayer.Name then
			return true
		end
	end
	return false
end

local function getNearestUnclaimedPlot()
	local nearestPlot = nil
	local shortestDistance = math.huge

	for _, plot in ipairs(Plots:GetChildren()) do
		local ownerValue = plot:FindFirstChild("Owner")
		local claim = plot:FindFirstChild("Claim")

		if ownerValue and ownerValue.Value == "" and claim then
			local distance = (claim.Position - rootPart.Position).Magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				nearestPlot = plot
			end
		end
	end

	return nearestPlot
end

-- ==========================================
-- 3. CONSTANTLY UPDATE THE POINTER
-- ==========================================
RunService.RenderStepped:Connect(function()
	-- If the player claimed a plot, turn the beam off entirely
	if doesPlayerOwnAPlot() then
		beam.Enabled = false
		return
	end

	-- Find the closest open plot to the player
	local targetPlot = getNearestUnclaimedPlot()

	if targetPlot then
		local claimPart = targetPlot.Claim

		-- Ensure the claim part has an attachment for the beam to connect to
		local targetAttachment = claimPart:FindFirstChild("TargetAttachment")
		if not targetAttachment then
			targetAttachment = Instance.new("Attachment")
			targetAttachment.Name = "TargetAttachment"
			targetAttachment.Parent = claimPart
		end

		-- Connect the beam from the player to the nearest plot
		beam.Attachment0 = targetAttachment
		beam.Enabled = true
	else
		-- No empty plots left in the game
		beam.Enabled = false
	end
end)