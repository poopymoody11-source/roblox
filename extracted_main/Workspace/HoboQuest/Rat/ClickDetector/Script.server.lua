local clickDetector = script.Parent

clickDetector.MouseClick:Connect(function(player)
	-- Ensure the PlayerStats folder exists
	local playerStats = player:FindFirstChild("PlayerStats")
	if not playerStats then
		playerStats = Instance.new("Folder")
		playerStats.Name = "PlayerStats"
		playerStats.Parent = player
	end

	-- Check for "foundRat" BoolValue, create it if missing, and set to true
	local foundRat = playerStats:FindFirstChild("foundRat")
	if not foundRat then
		foundRat = Instance.new("BoolValue")
		foundRat.Name = "foundRat"
		foundRat.Parent = playerStats
	end

	foundRat.Value = true

	-- let them know it worked (only this player sees it)
	local rat = clickDetector.Parent
	local adornee = rat:IsA("Model") and (rat.PrimaryPart or rat:FindFirstChildWhichIsA("BasePart", true)) or rat
	local pg = player:FindFirstChild("PlayerGui")
	if pg and adornee and not pg:FindFirstChild("RatFoundTag") then
		local bb = Instance.new("BillboardGui")
		bb.Name = "RatFoundTag"
		bb.Adornee = adornee
		bb.AlwaysOnTop = true
		bb.Size = UDim2.fromOffset(260, 60)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = Color3.fromRGB(255, 220, 90)
		t.Text = "You found the rat!\nGo tell the Homeless Guy."
		local st = Instance.new("UIStroke") st.Thickness = 2.5 st.Parent = t
		t.Parent = bb
		bb.Parent = pg
		game:GetService("Debris"):AddItem(bb, 4)
	end
end)