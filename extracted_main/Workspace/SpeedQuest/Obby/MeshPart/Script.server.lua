local triggerPart = script.Parent

-- Prevent multiple triggers at once
local debounce = false

triggerPart.Touched:Connect(function(hit)
	local character = hit.Parent
	local player = game.Players:GetPlayerFromCharacter(character)

	if player and not debounce then
		debounce = true

		local playerStats = player:FindFirstChild("PlayerStats")
		if playerStats then
			-- Check if the value already exists
			local carKey = playerStats:FindFirstChild("hasCarKey")

			if not carKey then
				-- Create new BoolValue if it doesn't exist yet
				carKey = Instance.new("BoolValue")
				carKey.Name = "hasCarKey"
				carKey.Value = true
				carKey.Parent = playerStats
			else
				-- If it already exists, just make sure it's set to true
				carKey.Value = true
			end

			print(player.Name .. " picked up the car key!")
		else
			warn("PlayerStats folder not found on player: " .. player.Name)
		end

		task.wait(1) -- Cooldown before it can touch-trigger again
		debounce = false
	end
end)