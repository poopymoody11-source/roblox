local prompt = script.Parent
-- Find the part we want to teleport to
local destinationPart = workspace:WaitForChild("Dungeon"):WaitForChild("ExitPart")

prompt.Triggered:Connect(function(player)
	local character = player.Character

	-- Check if the character exists and is spawned in
	if character and character.PrimaryPart then
		-- Teleport the character to the destination part's location
		-- We add + Vector3.new(0, 3, 0) so the player spawns slightly above the part and doesn't get stuck
		character:PivotTo(destinationPart.CFrame + Vector3.new(0, 3, 0))
	end
end)