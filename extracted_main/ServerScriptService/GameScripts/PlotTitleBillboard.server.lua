--==================================================
-- PLOT TITLE BILLBOARD
--
-- Fills in the "Title:" line on each plot's PLAYER STATS
-- board. Kept separate from PlotStatBillboard so that
-- script keeps owning name / icon / ascensions and this
-- one only ever touches the title row.
--
-- NOTE: that label used to be a SECOND child called
-- "name" (same as the player-name label), so
-- FindFirstChild("name") could return either one. It has
-- been renamed to "titlestat".
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TitleData = require(
	ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("TitleDataModule")
)

local plots = workspace:WaitForChild("Islands"):WaitForChild("StarterIsland"):WaitForChild("IslandPlots")

local function getLabel(plot)
	local lb = plot:FindFirstChild("Leaderboard")
	local stats = lb and lb:FindFirstChild("stats")
	if not stats then return nil end
	return stats:FindFirstChild("titlestat", true)
end

local function render(plot)
	local label = getLabel(plot)
	if not label then return end

	local ownerValue = plot:FindFirstChild("Owner")
	local ownerName = ownerValue and ownerValue.Value or ""
	local player = ownerName ~= "" and Players:FindFirstChild(ownerName) or nil

	if not player then
		label.Text = "Title: [N/A]"
		label.TextColor3 = Color3.fromRGB(120, 120, 120)
		return
	end

	local titleId = player:GetAttribute("EquippedTitle")
	local title = titleId and TitleData.ById[titleId]

	if not title then
		label.Text = "Title: [N/A]"
		label.TextColor3 = Color3.fromRGB(120, 120, 120)
		return
	end

	label.Text = "Title: " .. title.Name
	label.TextColor3 = TitleData.GetColor(title.Id)
end

local connections = {}

local function watch(plot)
	render(plot)

	local ownerValue = plot:FindFirstChild("Owner")
	if ownerValue then
		ownerValue.Changed:Connect(function()
			render(plot)
		end)
	end
end

for _, plot in ipairs(plots:GetChildren()) do
	watch(plot)
end
plots.ChildAdded:Connect(watch)

-- Re-render every plot when anyone's title changes.
local function hook(player)
	player:GetAttributeChangedSignal("EquippedTitle"):Connect(function()
		for _, plot in ipairs(plots:GetChildren()) do
			render(plot)
		end
	end)
end

Players.PlayerAdded:Connect(hook)
for _, player in ipairs(Players:GetPlayers()) do hook(player) end

Players.PlayerRemoving:Connect(function()
	task.defer(function()
		for _, plot in ipairs(plots:GetChildren()) do
			render(plot)
		end
	end)
end)

-- Cheap safety net in case an Owner value is set without firing Changed.
task.spawn(function()
	while task.wait(5) do
		for _, plot in ipairs(plots:GetChildren()) do
			pcall(render, plot)
		end
	end
end)
