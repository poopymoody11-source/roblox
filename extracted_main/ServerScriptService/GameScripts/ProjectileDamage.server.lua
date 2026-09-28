-- Services
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Configuration
local DAMAGE_AMOUNT = 20
local ARROW_LIFETIME = 5 

local function setupArrow(arrow)
	local hasHit = false
	local touchPart = arrow:IsA("Model") and arrow.PrimaryPart or arrow
	if not touchPart then return end

	local connection
	connection = touchPart.Touched:Connect(function(hit)
		if hasHit then return end

		local character = hit.Parent
		local humanoid = character:FindFirstChildOfClass("Humanoid")

		if humanoid then
			-- Verify if the hit character is a Player OR an Iron Golem
			local isPlayer = Players:GetPlayerFromCharacter(character)
			local isIronGolem = string.find(character.Name, "IronGolem")

			if isPlayer or isIronGolem then
				hasHit = true
				connection:Disconnect()
				humanoid:TakeDamage(DAMAGE_AMOUNT)
				arrow:Destroy()
				return
			end
		end

		-- Destroy arrow if it hits walls/floors
		if hit.CanCollide and not hit:IsDescendantOf(character) then
			hasHit = true
			connection:Disconnect()
			task.wait(0.1)
			arrow:Destroy()
		end
	end)

	task.delay(ARROW_LIFETIME, function()
		if arrow and arrow.Parent then
			if connection then connection:Disconnect() end
			arrow:Destroy()
		end
	end)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Arrow" then
		setupArrow(child)
	end
end)
