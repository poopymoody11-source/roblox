local TweenService = game:GetService("TweenService")

local button = script.Parent -- ImageButton
local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Set up grey overlay tint on the ImageButton
button.BackgroundColor3 = Color3.fromRGB(200, 200, 200) -- Grey highlight tint
button.BackgroundTransparency = 1                        -- Default invisible

local hoverTween = TweenService:Create(button, tweenInfo, {
	BackgroundTransparency = 0.75 -- Shows subtle grey overlay on hover
})

local leaveTween = TweenService:Create(button, tweenInfo, {
	BackgroundTransparency = 1    -- Fades back to invisible
})

button.MouseEnter:Connect(function()
	leaveTween:Cancel()
	hoverTween:Play()
end)

button.MouseLeave:Connect(function()
	hoverTween:Cancel()
	leaveTween:Play()
end)