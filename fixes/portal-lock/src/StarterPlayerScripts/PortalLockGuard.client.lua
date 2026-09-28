--==================================================
-- FINAL BOSS PORTAL GUARD (client)
-- Keeps a locked Final Boss portal's prompt off on this client, even
-- if something local switches it on (DialogModule used to). The
-- server's PortalLockFix says which portals are unlocked through the
-- bossfight model's "Unlocked" attribute. FinalPortalFX builds its
-- effects only while the prompt is on, so they stay hidden too.
--==================================================
local plotsFolder = workspace:WaitForChild("Islands"):WaitForChild("StarterIsland"):WaitForChild("IslandPlots")

local function guard(model, prompt)
	local function unlocked() return model:GetAttribute("Unlocked") == true end
	if not unlocked() then prompt.Enabled = false end
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if prompt.Enabled and not unlocked() then
			prompt.Enabled = false
			-- (when he buys it, the server's Enabled can land a moment before
			-- its Unlocked attribute: look again once that's had time to arrive)
			task.delay(0.5, function()
				if unlocked() and prompt.Parent then prompt.Enabled = true end
			end)
		end
	end)
	-- the attribute is the truth: follow it
	model:GetAttributeChangedSignal("Unlocked"):Connect(function()
		prompt.Enabled = unlocked()
	end)
end

local function watch(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then guard(model, d) end
	end
	model.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then guard(model, d) end
	end)
end

local function scanPlot(plot)
	local upgrades = plot:WaitForChild("Upgrades", 30)
	local purchases = upgrades and upgrades:WaitForChild("Purchases", 30)
	if not purchases then return end
	local model = purchases:FindFirstChild("bossfight")
	if model then watch(model) end
	-- (with streaming, the portal can arrive later)
	purchases.ChildAdded:Connect(function(c)
		if c.Name == "bossfight" then watch(c) end
	end)
end

for _, plot in ipairs(plotsFolder:GetChildren()) do task.spawn(scanPlot, plot) end
plotsFolder.ChildAdded:Connect(function(plot) task.spawn(scanPlot, plot) end)
