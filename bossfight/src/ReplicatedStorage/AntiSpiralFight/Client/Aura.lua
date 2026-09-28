--==================================================
-- SPIRAL AURA (client)
-- Everyone fights wearing the power the cutscene gave them: the
-- same SpiralKit power-up (green veins, glowing eyes, the green
-- glow, the aura and its whirling dotted rings), put on every
-- player's real character on every client. It flares when they
-- parry and gutters when they're hit.
--==================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Aura = {}

local K, SK
local worn = {}   -- [character] = { Rig, Flare, Dim }
local active = false

-- the cutscene's rigs, as SpiralKit expects them, over a real R6 character
local function adapter(char)
	local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
	if not torso then return nil end
	return {
		Model = char,
		Torso = torso,
		part = function(_, name) return char:FindFirstChild(name) end,
		head = function() return char:FindFirstChild("Head") end,
	}
end

local function wear(char)
	if worn[char] or not char.Parent then return end
	local rig = adapter(char)
	if not rig then return end
	local ok = pcall(SK.powerUp, K, rig)
	if not ok then return end
	worn[char] = { Rig = rig, Flare = 0, Dim = 0 }
	char.AncestryChanged:Connect(function()
		if not char.Parent then worn[char] = nil end
	end)
end

local function strip(char)
	local w = worn[char]
	if not w then return end
	worn[char] = nil
	local SP = w.Rig.SP
	if not SP then return end
	for _, v in ipairs(SP.Veins) do v.Beam:Destroy() end
	for _, e in ipairs(SP.Eyes) do e:Destroy() end
	if SP.Rings then for _, R in ipairs(SP.Rings) do for _, b in ipairs(R.B) do b:Destroy() end for _, a in ipairs(R.A) do a:Destroy() end end end
	for _, x in ipairs({ SP.Glow, SP.Aura, SP.Sparks, SP.Light }) do if x then x:Destroy() end end
end

-- a burst of power (a parry) / a stagger (a hit)
function Aura.flare(char, amount)
	local w = char and worn[char]
	if w then w.Flare = math.max(w.Flare, amount or 1) end
end
function Aura.dim(char)
	local w = char and worn[char]
	if w then w.Dim = 1 end
end

function Aura.setActive(on)
	active = on
	if not on then
		for char in pairs(worn) do strip(char) end
	end
end

function Aura.init(kit, spiralKit)
	K, SK = kit, spiralKit
	local last = os.clock()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local dt = now - last
		last = now
		if not active then return end
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			if c and hum and hum.Health > 0 and not worn[c] then wear(c) end
		end
		for char, w in pairs(worn) do
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				strip(char)
			else
				w.Flare = math.max(w.Flare - dt * 1.4, 0)
				w.Dim = math.max(w.Dim - dt * 1.2, 0)
				local amount = math.clamp(0.8 + 0.2 * w.Flare - 0.5 * w.Dim, 0, 1)
				SK.powerLevel(w.Rig, now, amount)
				local SP = w.Rig.SP
				if SP then
					SP.Aura.Rate = 12 + 45 * w.Flare
					SP.Sparks.Rate = 16 + 50 * w.Flare
					SP.Light.Brightness = 2 + 4 * w.Flare
				end
			end
		end
	end)
end

return Aura
