local RunService = game:GetService("RunService")
-- (the old swirl galaxies were replaced by the GalaxyRealm, which spins client-side;
-- the originals are kept in ServerStorage.OldArenaFX_Backup)
local galaxiesModel = workspace.BossFight.BossFightMap:FindFirstChild("Galaxies")
if not galaxiesModel then return end

local SPIN_SPEED = 3 -- Degrees per second

RunService.Heartbeat:Connect(function(deltaTime)
	if galaxiesModel:IsA("Model") then
		local currentPivot = galaxiesModel:GetPivot()
		local rotation = CFrame.Angles(math.rad(SPIN_SPEED * deltaTime), 0, 0)

		-- Rotates all parts together around the Model's pivot point
		galaxiesModel:PivotTo(currentPivot * rotation)
	end
end)