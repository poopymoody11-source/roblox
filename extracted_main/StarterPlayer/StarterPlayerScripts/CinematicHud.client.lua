-- CinematicHud: hides the gameplay HUD while any cinematic is playing.
-- Any script sets player:SetAttribute("HideHud_<Name>", true) to request hiding, nil to release.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HIDE = { "Screen", "ScreenGui", "TutorialButton", "PromptUI", "PassOffer", "AdminTopbarButton", "TitleTopbarButton", "IslandLock", "LapisZoneHighlightGui", "CrueltyLobby", "FinalBossLobby" }
local saved = {}
local hidden = false

local function wanted()
	for k, v in pairs(player:GetAttributes()) do
		if v and k:sub(1, 8) == "HideHud_" then return true end
	end
	return false
end

local function apply()
	local want = wanted()
	if want == hidden then return end
	hidden = want
	local SG = game:GetService("StarterGui")
	if want then
		saved = {}
		for _, n in ipairs(HIDE) do
			local g = playerGui:FindFirstChild(n)
			if g and g:IsA("ScreenGui") then
				saved[g] = g.Enabled
				g.Enabled = false
			end
		end
		for _, t in ipairs({ Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList }) do
			local ok, was = pcall(function() return SG:GetCoreGuiEnabled(t) end)
			saved[t] = ok and was
			pcall(function() SG:SetCoreGuiEnabled(t, false) end)
		end
	else
		for k, was in pairs(saved) do
			if typeof(k) == "EnumItem" then
				if was then pcall(function() SG:SetCoreGuiEnabled(k, true) end) end
			elseif k.Parent then
				k.Enabled = was
			end
		end
		saved = {}
	end
end

-- a respawn recreates the HUD guis (ResetOnSpawn); hide the fresh copies too
playerGui.ChildAdded:Connect(function(g)
	if not hidden or not g:IsA("ScreenGui") or not table.find(HIDE, g.Name) then return end
	task.defer(function()
		if hidden and g.Parent then
			saved[g] = true
			g.Enabled = false
		end
	end)
end)

player.AttributeChanged:Connect(function(name)
	if name:sub(1, 8) == "HideHud_" then apply() end
end)
apply()
