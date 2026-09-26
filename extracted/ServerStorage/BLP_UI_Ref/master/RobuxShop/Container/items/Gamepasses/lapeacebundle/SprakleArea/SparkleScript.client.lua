--Variables

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ParentGui = script.Parent

--Config
local Texture = "rbxassetid://7112395588"
local LifeTime = 3
local Rate = 1
local MinSize = UDim2.new(0,0,0,0)
local MaxSize = UDim2.new(0.4,0,0.4,0)
local Easing = Enum.EasingStyle.Quad
local Rotation = false
local MaxPerGui = 6
local MaxDistance = 80

--State
local SparklePool = {}
local SparkleCount = 0
local LastSpawnTime = 0
local UsedPositions = {}

--Functions

local function GetSparkle()
	local Sparkle = table.remove(SparklePool)
	if Sparkle then
		Sparkle.Visible = true
	else
		Sparkle = Instance.new("ImageLabel")
		Sparkle.BackgroundTransparency = 1
		Sparkle.AnchorPoint = Vector2.new(0.5,0.5)
		Sparkle.ScaleType = Enum.ScaleType.Fit
	end
	return Sparkle
end

local function CleanUpSparkle(Sparkle)
	Sparkle.Visible = false
	Sparkle.Parent = nil
	table.insert(SparklePool, Sparkle)
	table.remove(UsedPositions, 1)
end

local function GetSafePositions()
	local absSize = ParentGui.AbsoluteSize
	
	for _ = 1, 25 do
		local x = math.random() * absSize.X
		local y = math.random() * absSize.Y
		
		local ok = true
		for _, pos in ipairs(UsedPositions) do
			if (Vector2.new(x,y) - pos).Magnitude < MaxDistance then
				ok = false
				break
			end
		end
		
		if ok then
			table.insert(UsedPositions, Vector2.new(x, y))
			if #UsedPositions > 20 then table.remove(UsedPositions, 1) end
			return x,y
		end
		
	end
	
	local x = math.random() * absSize.X
	local y = math.random() * absSize.Y
	table.insert(UsedPositions, Vector2.new(x, y))
	return x,y
	
end

local function CreateSparkle()
	
	if SparkleCount >= MaxPerGui then return end
	
	local sparkle = GetSparkle()
	sparkle.Size = MinSize
	sparkle.Image = Texture
	sparkle.ImageTransparency = 1
	sparkle.Rotation = Rotation and math.random(0, 360) or 0
	
	local x, y = GetSafePositions()
	sparkle.Position = UDim2.new(0, x, 0, y)
	sparkle.Parent = ParentGui
	
	SparkleCount += 1
	
	local tweenIn = TweenService:Create(sparkle, TweenInfo.new(LifeTime / 2, Easing, Enum.EasingDirection.Out), {
		Size = MaxSize,
		ImageTransparency = 0
	})
	
	local tweenOut = TweenService:Create(sparkle, TweenInfo.new(LifeTime / 2, Easing, Enum.EasingDirection.In), {
		Size = MinSize,
		ImageTransparency = 1
	})
	
	tweenIn:Play()
	tweenIn.Completed:Once(function()
		tweenOut:Play()
	end)
	
	tweenOut.Completed:Once(function()
		CleanUpSparkle(sparkle)
		SparkleCount -= 1
	end)
end

RunService.PreRender:Connect(function()
	local currentTime = time()
	if currentTime - LastSpawnTime >= 1 / Rate then
		CreateSparkle()
		LastSpawnTime = currentTime
	end
end)