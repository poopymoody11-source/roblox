--==================================================
-- PLACED LAPIS SPINNER
-- Place as a LocalScript in StarterPlayerScripts
--
-- Purely cosmetic: continuously spins any lapis model placed on a
-- platform (tagged "PlacedLapis" by the server, right after it sets
-- the model's initial upright CFrame) around a fixed WORLD vertical
-- axis. Client-only -- no need to keep the exact rotation angle in
-- sync between players, same as the game's existing pickup-sparkle
-- effects.
--==================================================

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SPIN_SPEED = math.rad(45) -- radians/second -- same for every lapis

local spinning = {} -- [instance] = base CFrame captured when tagged

local function startSpinning(instance)
	if spinning[instance] then return end

	local ok, baseCFrame = pcall(function()
		return instance:GetPivot()
	end)
	if ok then
		spinning[instance] = baseCFrame
	end
end

local function stopSpinning(instance)
	spinning[instance] = nil
end

for _, instance in ipairs(CollectionService:GetTagged("PlacedLapis")) do
	startSpinning(instance)
end

CollectionService:GetInstanceAddedSignal("PlacedLapis"):Connect(startSpinning)
CollectionService:GetInstanceRemovedSignal("PlacedLapis"):Connect(stopSpinning)

RunService.Heartbeat:Connect(function()
	for instance, baseCFrame in pairs(spinning) do
		if not instance.Parent then
			spinning[instance] = nil
		else
			local angle = SPIN_SPEED * os.clock()
			local pivotPos = baseCFrame.Position

			-- Rotate the model's ENTIRE base orientation around a fixed
			-- world-space vertical (Y) axis, anchored at its own pivot
			-- position. This spins any model in place like a turntable,
			-- regardless of whatever rotation is baked into that
			-- specific model's own pivot -- unlike rotating around local
			-- X, which only happened to look right for interstellar.
			local spin = CFrame.new(pivotPos) * CFrame.Angles(0, angle, 0) * CFrame.new(-pivotPos)

			local ok = pcall(function()
				instance:PivotTo(spin * baseCFrame)
			end)
			if not ok then
				spinning[instance] = nil
			end
		end
	end
end)