local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Plots = Workspace:WaitForChild("Islands"):WaitForChild("StarterIsland"):WaitForChild("IslandPlots")

-- Function to handle setting up a plot's touch connection
local function setupPlot(plot)
	-- Look for the required items inside this specific plot
	local ownerValue = plot:FindFirstChild("Owner")
	local hitbox = plot:FindFirstChild("Hitbox")
	local claim = plot:FindFirstChild("Claim")

	-- Verify all required pieces exist before continuing
	if not (ownerValue and ownerValue:IsA("StringValue") and hitbox and claim) then
		warn("Plot " .. plot.Name .. " is missing Owner, Hitbox, or Claim!")
		return
	end

	-- Locate the UI elements inside Claim
	local surfaceGui = claim:FindFirstChildOfClass("SurfaceGui")
	if not surfaceGui then return end

	local textLabel = surfaceGui:FindFirstChildOfClass("TextLabel")
	local playerIcon = surfaceGui:FindFirstChild("PlayerIcon") -- Assuming this is an ImageLabel or similar UI element

	-- Handle player touching the Hitbox to claim
	hitbox.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)

		-- Check: Is it a valid player, and is the plot completely unclaimed?
		if player and ownerValue.Value == "" then

			-- Check if this player already owns a different plot
			for _, otherPlot in ipairs(Plots:GetChildren()) do
				local otherOwner = otherPlot:FindFirstChild("Owner")
				if otherOwner and otherOwner.Value == player.Name then
					return -- Player already owns a plot, don't let them claim another
				end
			end

			-- Claim the plot
			ownerValue.Value = player.Name

			-- Update the UI text
			if textLabel then
				textLabel.Text = player.Name .. "'s Plot"
			end

			-- Update the UI player profile icon
			if playerIcon and playerIcon:IsA("ImageLabel") then
				local userId = player.UserId
				-- Fetch the player's avatar headshot thumbnail
				playerIcon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
			end
		end
	end)
end

-- 1. Initialize and scan all current plots inside the folder
local allPlots = Plots:GetChildren()
print("Total plots found: " .. #allPlots)

for _, plot in ipairs(allPlots) do
	setupPlot(plot)
end

-- 2. Handle players leaving to reset their plot back to normal emptiness
Players.PlayerRemoving:Connect(function(player)
	for _, plot in ipairs(Plots:GetChildren()) do
		local ownerValue = plot:FindFirstChild("Owner")

		if ownerValue and ownerValue.Value == player.Name then
			-- Reset Owner string
			ownerValue.Value = ""

			-- Reset UI text and icon back to default values
			local claim = plot:FindFirstChild("Claim")
			if claim then
				local surfaceGui = claim:FindFirstChildOfClass("SurfaceGui")
				if surfaceGui then
					local textLabel = surfaceGui:FindFirstChildOfClass("TextLabel")
					local playerIcon = surfaceGui:FindFirstChild("PlayerIcon")

					if textLabel then
						textLabel.Text = "Unclaimed Plot"
					end
					if playerIcon and playerIcon:IsA("ImageLabel") then
						playerIcon.Image = "" -- Clears the image
					end
				end
			end

			-- (the Final Boss portal goes back into hiding for the next owner)
			pcall(function()
				require(script.Parent:WaitForChild("BaseUpgradeService")).ApplyBossfightPortalVisual(plot, false)
			end)

			print(player.Name .. "'s plot has been reset.")
			break -- Found and cleared, stop looking
		end
	end
end)
