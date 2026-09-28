--==================================================
-- PASS PURCHASE REPORTER (client)
--
-- Backup for gamepass purchases: when YOUR Robux prompt
-- closes with a purchase, tell the server so it can
-- double-check and hand the pass over even if its own
-- PromptGamePassPurchaseFinished never arrived.
-- (MonetizationService verifies with Roblox on live servers.)
--==================================================

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local report = ReplicatedStorage:WaitForChild("PassPurchaseReport", 30)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, gamePassId, wasPurchased)
	if who ~= player or not wasPurchased or not report then return end
	report:FireServer(tonumber(gamePassId))
end)
