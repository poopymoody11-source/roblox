local prompt = script.Parent
local keyTemplate = prompt.Parent.Parent -- The model or template of the key

prompt.Triggered:Connect(function(player)
	local toolName = keyTemplate.Name

	-- Check if the player already has the tool in their inventory or currently equipped
	local hasInBackpack = player.Backpack:FindFirstChild(toolName)
	local hasInCharacter = player.Character and player.Character:FindFirstChild(toolName)

	if not hasInBackpack and not hasInCharacter then
		-- Give the tool since they don't have it
		local tool = keyTemplate:Clone()
		local keypart = tool:WaitForChild("MeshPart")
		keypart.Anchored = false
		keypart:WaitForChild("ProximityPrompt"):Destroy()
		tool.Parent = player.Backpack
		-- keep it after dying / respawning
		local gear = player:FindFirstChild("StarterGear")
		if gear and not gear:FindFirstChild(toolName) then tool:Clone().Parent = gear end
	else
		-- Optional: Let them know they already have it
		print(player.Name .. " already has the key!")
	end
end)