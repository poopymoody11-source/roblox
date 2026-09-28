--==================================================
-- QUEST UI TOGGLE
--
-- Place in: QuestUI > questtoggle
-- Type:     LocalScript
--==================================================

local TweenService = game:GetService("TweenService")

local gui = script.Parent
local frame = gui:WaitForChild("Frame")
local openCloseFrame = gui:WaitForChild("open/close")
local titleFrame = gui:WaitForChild("title")

local arrowButton = openCloseFrame:WaitForChild("ImageButton")
local staffsLabel = openCloseFrame:WaitForChild("Staffs")

local TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- Ensure QuestUI ScreenGui and all its internal frames are visible on startup
gui.Enabled = true
for _, child in ipairs(gui:GetChildren()) do
	if child:IsA("GuiObject") then
		child.Visible = true
	end
end

-- Save default positions from Studio (Open layout)
local openPositions = {
	Frame = frame.Position,
	Title = titleFrame.Position,
	Button = openCloseFrame.Position,
}

local isOpen = false

local function getSlideOffset()
	local slideDistance = frame.AbsoluteSize.X + frame.AbsolutePosition.X + 5
	return UDim2.fromOffset(-slideDistance, 0)
end

-- Set initial closed position instantly on start
task.defer(function()
	local offset = getSlideOffset()
	frame.Position = openPositions.Frame + offset
	titleFrame.Position = openPositions.Title + offset
	openCloseFrame.Position = openPositions.Button + offset
	staffsLabel.Text = ">"
end)

local function toggleUI()
	isOpen = not isOpen

	local targetFramePos
	local targetTitlePos
	local targetButtonPos

	if isOpen then
		targetFramePos = openPositions.Frame
		targetTitlePos = openPositions.Title
		targetButtonPos = openPositions.Button
		staffsLabel.Text = "<"
	else
		local offset = getSlideOffset()
		targetFramePos = openPositions.Frame + offset
		targetTitlePos = openPositions.Title + offset
		targetButtonPos = openPositions.Button + offset
		staffsLabel.Text = ">"
	end

	TweenService:Create(frame, TWEEN_INFO, { Position = targetFramePos }):Play()
	TweenService:Create(titleFrame, TWEEN_INFO, { Position = targetTitlePos }):Play()
	TweenService:Create(openCloseFrame, TWEEN_INFO, { Position = targetButtonPos }):Play()
end

arrowButton.Activated:Connect(toggleUI)