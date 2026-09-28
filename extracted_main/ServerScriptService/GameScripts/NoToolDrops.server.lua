--==================================================
-- NO TOOL DROPS
-- Dropping a tool (Backspace) threw it on the ground and could leave the
-- camera stuck on it. Nothing in this game is meant to be dropped, so every
-- tool -- ones already in the place and ones handed out later (staffs, bats,
-- quest items, pass rewards) -- has CanBeDropped turned off.
--==================================================
local function fix(d)
	if d:IsA("Tool") then d.CanBeDropped = false end
end
for _, d in ipairs(game:GetDescendants()) do pcall(fix, d) end
game.DescendantAdded:Connect(function(d) pcall(fix, d) end)
