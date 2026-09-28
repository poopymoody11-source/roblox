--==================================================
-- MONETIZATION SERVICE
--
-- Owns every gamepass question in the game:
--
--   1. On join, ask Roblox which passes the player owns
--      and publish the answer as player attributes
--      (Pass_DoubleMoney = true, and so on).
--   2. Re-check the instant a purchase completes in-game,
--      so the benefit lands without a rejoin.
--   3. Apply the benefits that are one-shot grants
--      (bundle lapis, staff unlocks, accessories, titles).
--
-- Everything else in the codebase reads the ATTRIBUTE
-- rather than calling MarketplaceService itself. That
-- matters for two reasons: UserOwnsGamePassAsync is a
-- web call that throttles and can fail, and attributes
-- replicate to the client for free, so the shop UI and
-- the rebirth UI can show the right thing with no extra
-- remotes.
--
-- Place as a Script in ServerScriptService > GameScripts.
--==================================================

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local AccessibleModules = ReplicatedStorage:WaitForChild("AccessibleModules")
local MonetizationData = require(AccessibleModules:WaitForChild("MonetizationData"))

local GRANT_STORE_NAME = "PassGrants_v1"
local grantStore = DataStoreService:GetDataStore(GRANT_STORE_NAME)

-- How long to keep retrying a failed ownership check before
-- giving up for this session. A player who paid and then hit
-- a Roblox outage should still get their pass a few seconds
-- later rather than being told to rejoin.
local RunService = game:GetService("RunService")

local OWNERSHIP_RETRIES = 3
local RETRY_DELAY = 2

--==================================================
-- STUDIO TESTING
--
-- Gamepasses cannot be BOUGHT in Studio -- the Robux
-- prompt is a no-op in a playtest -- and you don't own
-- your own passes, so UserOwnsGamePassAsync answers
-- false for every one of them. The result is that in
-- Team Test nothing appears to work at all, which is
-- exactly what it looks like when the code is broken.
--
-- So in Studio, every pass is granted by default. This
-- NEVER applies in a live server: RunService:IsStudio()
-- is false there, and the flag below is checked on top
-- of it, so there is no way for this to leak to players.
--
-- Set STUDIO_GRANT_ALL = false to test the no-pass
-- experience instead, or use /resetpasses in-game to
-- drop them for the current session.
--==================================================

local STUDIO_GRANT_ALL = true

-- Team Test: the server and every client run inside Studio, but only the
-- HOST counted as a developer, so everyone else got no passes -- that's why
-- "gamepasses don't work when multiple people are in the team test".
--
-- JobId is an empty string in Studio and Team Test and a real GUID on a live
-- Roblox server, so this is the reliable "this is not a live game" test.
-- It can never be true for a real player in a real server.
-- Team Test servers are NOT "Studio" to the server: IsStudio() is false
-- there and JobId is a real id, so the old check only ever worked in solo
-- Play. What a Team Test server does look like is a reserved server
-- (PrivateServerId set, no owner). This place never reserves servers of
-- ITSELF (only the separate Final Boss place is reserved), so here that
-- combination can only mean Team Test.
local function isTeamTest()
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

local function isTestSession()
	return RunService:IsStudio() or game.JobId == "" or isTeamTest()
end

local DEV_USER_IDS = {
	-- [123456789] = true,
}

local function isDeveloper(player)
	if not player then return false end
	if DEV_USER_IDS[player.UserId] then return true end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	elseif game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		return ok and rank >= 254
	end
	return false
end

-- Test sessions only. (It used to ALSO grant everything to the developer in
-- live servers, which is how the owner's account ended up with bundles,
-- staffs and thousands of lapis it never bought.)
local function studioGrantsEverything(player)
	if not STUDIO_GRANT_ALL then return false end
	return isTestSession()
end

-- Roblox counts an experience's OWNER as owning every gamepass of it, so the
-- web check says "yes" to all of them for the creator. Ignore that in live
-- servers: the owner only gets what COMPLIMENTARY lists. Set false if you
-- want your own account to have everything live.
local IGNORE_OWNER_PASSES = true
local function isOwnerAccount(player)
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- Staff tools a pass hands out in a TEST session: put in the backpack for
-- the session only, never saved (a test grant used to save the staff, the
-- title and the bundle lapis to the real account data).
local TEST_STAFF_TOOLS = {
	op_lapis = "opstaff",
	verity_lapis = "verity",
	lapeace_lapis = "heavenstaff",
}

-- Freebies. The old ElytraService whitelisted this name for
-- the Elytra; kept here so nothing is taken away from anyone
-- who already had it.
local COMPLIMENTARY = {
	["munkyusik"] = { Elytra = true },
}

-- OP Robe has no Accessory model in ServerStorage, so it is
-- built in code instead: a coloured body glow, a trail off
-- the torso, and a jump boost. JumpPower is deliberately the
-- stat it touches -- WalkSpeed is owned by the speed-zone
-- parts in GameScripts > Walkspeed, and anything that writes
-- WalkSpeed here would be overwritten the next time the
-- player stepped on one.
local ROBE = {
	JumpPower = 1.4,
	ColorA = Color3.fromRGB(150, 60, 255),
	ColorB = Color3.fromRGB(80, 200, 255),
}

--==================================================
-- ONE-TIME GRANT LEDGER
--
-- Consumables (the 99x lapis in a bundle) must fire
-- exactly once ever, not on every rejoin, or the bundle
-- becomes an infinite lapis tap. Permanent effects
-- (island access, money multiplier) are read live from
-- the attribute and need no ledger at all.
--==================================================

local grantedCache = {}   -- [userId] = { [passKey] = true }
local grantsDirty = {}    -- [userId] = true

local function grantKey(userId)
	return "grants_" .. tostring(userId)
end

local function loadGrants(userId)
	local ok, result = pcall(function()
		return grantStore:GetAsync(grantKey(userId))
	end)

	if ok and type(result) == "table" then
		grantedCache[userId] = result
	else
		if not ok then
			warn("[Monetization] couldn't load grant ledger for " .. userId .. ": " .. tostring(result))
		end
		-- An empty table here would re-grant the bundle on a
		-- DataStore outage. Mark the session as unsafe instead
		-- so one-time grants are skipped until the store works.
		grantedCache[userId] = ok and {} or false
	end

	return grantedCache[userId]
end

local function hasGranted(userId, passKey)
	local ledger = grantedCache[userId]
	if ledger == false then
		-- Ledger unavailable (DataStore down or throttled). On a live server
		-- we refuse rather than risk duping a bundle. In Studio / Team Test
		-- DataStores throttle constantly with several people joining at once,
		-- and there's nothing real to dupe, so testing isn't blocked by it.
		return not isTestSession()
	end
	return ledger ~= nil and ledger[passKey] == true
end

local function markGranted(userId, passKey)
	local ledger = grantedCache[userId]
	if type(ledger) ~= "table" then return end
	ledger[passKey] = true
	grantsDirty[userId] = true
end

local function saveGrants(userId)
	if not grantsDirty[userId] then return end
	local ledger = grantedCache[userId]
	if type(ledger) ~= "table" then return end

	local ok, err = pcall(function()
		grantStore:SetAsync(grantKey(userId), ledger)
	end)

	if ok then
		grantsDirty[userId] = nil
	else
		warn("[Monetization] couldn't save grant ledger for " .. userId .. ": " .. tostring(err))
	end
end

--==================================================
-- BENEFIT APPLICATION
--==================================================

local function adminBindable()
	return ServerStorage:FindFirstChild("AdminActionBindable")
end

-- Lapis and staff unlocks both live in LeaderboardStats'
-- session table, which is private to that script. Its
-- existing "GiveLapis" action already does both things
-- (adds the lapis AND unlocks the matching staff), so
-- reuse it rather than duplicating the save logic here.
-- Amount 0 unlocks the staff without handing over lapis.
local function giveLapis(player, itemName, amount)
	local bindable = adminBindable()
	if not bindable then
		warn("[Monetization] AdminActionBindable missing -- can't grant " .. itemName)
		return
	end
	bindable:Fire(player, "GiveLapis", itemName, amount)
end

--==================================================
-- OP ROBE
--
-- Rebuilt on every spawn. Everything it creates is
-- named with the ROBE_TAG prefix so a respawn or a
-- second call replaces rather than stacks.
--==================================================

local ROBE_TAG = "OPRobe_"

local function clearRobe(character)
	for _, d in ipairs(character:GetDescendants()) do
		if d.Name:sub(1, #ROBE_TAG) == ROBE_TAG then
			d:Destroy()
		end
	end
end

local function applyRobe(player)
	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root then return end

	clearRobe(character)

	local glow = Instance.new("Highlight")
	glow.Name = ROBE_TAG .. "Glow"
	glow.FillColor = ROBE.ColorA
	glow.FillTransparency = 0.78
	glow.OutlineColor = ROBE.ColorB
	glow.OutlineTransparency = 0.25
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = character

	local top = Instance.new("Attachment")
	top.Name = ROBE_TAG .. "Top"
	top.Position = Vector3.new(0, 1, 0)
	top.Parent = root

	local bottom = Instance.new("Attachment")
	bottom.Name = ROBE_TAG .. "Bottom"
	bottom.Position = Vector3.new(0, -1.6, 0)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = ROBE_TAG .. "Trail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.7
	trail.MinLength = 0.1
	trail.LightEmission = 0.6
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = ColorSequence.new(ROBE.ColorA, ROBE.ColorB)
	trail.Parent = root

	if humanoid then
		-- Multiply rather than set, so it stacks correctly with
		-- whatever the default rig uses.
		if humanoid.UseJumpPower then
			humanoid.JumpPower = humanoid.JumpPower * ROBE.JumpPower
		else
			humanoid.JumpHeight = humanoid.JumpHeight * ROBE.JumpPower
		end
	end
end

-- An accessory only counts as "on" if its handle is actually welded to
-- the body. A failed AddAccessory (character not ready yet) used to leave
-- an unwelded copy that fell off into the void -- the name was still in
-- the character, so it was never given again. That's the "I bought the
-- Elytra and never got it" bug.
local function accessoryWorks(acc)
	local handle = acc:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then return false end
	for _, j in ipairs(handle:GetChildren()) do
		if j:IsA("JointInstance") or j:IsA("WeldConstraint") or j:IsA("RigidConstraint") then
			return true
		end
	end
	return false
end

local accessoryRetry = {} -- [player] = true while a retry is queued

local function giveAccessory(player, accessoryName, attempt)
	local character = player.Character
	if not character then return end
	local existing = character:FindFirstChild(accessoryName)
	if existing then
		if accessoryWorks(existing) then return end
		-- give AddAccessory a beat to weld a fresh one before calling it broken
		if (attempt or 0) == 0 and existing:GetAttribute("GivenAt") and os.clock() - existing:GetAttribute("GivenAt") < 1 then return end
		existing:Destroy()
	end

	local models = ServerStorage:FindFirstChild("AccessibleModels")
	local folder = models and models:FindFirstChild("Accessories")
	local template = folder and folder:FindFirstChild(accessoryName)

	if not template then
		-- Not an error worth spamming about: OPRobe has no model yet.
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local ready = humanoid and humanoid.Health > 0 and character:IsDescendantOf(workspace)
		and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	local ok = false
	local clone
	if ready then
		clone = template:Clone()
		clone:SetAttribute("GivenAt", os.clock())
		if clone:IsA("Accessory") then
			ok = pcall(function() humanoid:AddAccessory(clone) end)
		else
			clone.Parent = character
			ok = true
		end
		if ok and clone:IsA("Accessory") then
			-- make sure it really welded
			task.wait()
			ok = clone.Parent == character and accessoryWorks(clone)
		end
	end
	if not ok then
		if clone then clone:Destroy() end
		-- not ready yet: try again shortly instead of leaving it loose
		attempt = (attempt or 0) + 1
		if attempt <= 10 and not accessoryRetry[player] then
			accessoryRetry[player] = true
			task.delay(1, function()
				accessoryRetry[player] = nil
				if player.Parent and player.Character == character then
					giveAccessory(player, accessoryName, attempt)
				end
			end)
		elseif attempt > 10 then
			warn(("[Monetization] couldn't attach %s to %s"):format(accessoryName, player.Name))
		end
	end
end

--==================================================
-- BUNDLE STAFF UPGRADE
--
-- A bundle owner's staff (verity / heavenstaff) is upgraded
-- every time it lands in their Backpack or hands: much bigger
-- and faster magnet (the MagnetRadius / MagnetFlight
-- attributes LocalLapisClient and LocalLapisService read),
-- the island's own effects shrunk onto the tip (BundleStaffFX in
-- ServerStorage), an island aura at your feet while held, one
-- outline over the whole staff, a light and a swing trail. The
-- hotbar tooltip says it's the upgraded, permanent bundle version.
-- Being re-applied on every spawn/ascension is what makes it
-- permanent; the base staff model in ServerStorage is never
-- touched, so non-owners keep the normal one.
--==================================================
local UPGRADE_TAG = "BundleUpgrade_"

local function upgradeTool(tool, up)
	if not tool:IsA("Tool") or tool:GetAttribute("BundleUpgraded") then return end
	local handle = tool:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then return end
	tool:SetAttribute("BundleUpgraded", true)

	local baseRadius = tool:GetAttribute("MagnetRadius") or 60
	tool:SetAttribute("BaseMagnetRadius", baseRadius)
	tool:SetAttribute("MagnetRadius", math.floor(baseRadius * (up.RadiusMult or 2)))
	tool:SetAttribute("MagnetFlight", up.Flight or 0.6)
	tool:SetAttribute("BundleLabel", up.Label)
	tool.ToolTip = "\u{2726} " .. up.Label .. " \u{2022} UPGRADED \u{2022} PERMANENT"

	local a, b = up.ColorA, up.ColorB

	local center = Instance.new("Attachment")
	center.Name = UPGRADE_TAG .. "Center"
	center.Parent = handle

	-- orbiting sparkles
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = UPGRADE_TAG .. "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(a, b)
	sparks.LightEmission = up.LightBrightness and 0.3 or 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparks.Lifetime = NumberRange.new(0.8, 1.4)
	sparks.Rate = up.SparkleRate or 40
	sparks.Speed = NumberRange.new(1, 3)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.RotSpeed = NumberRange.new(-180, 180)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.Acceleration = Vector3.new(0, 2, 0)
	sparks.Parent = center

	-- the upgraded model: gold collars, prongs cradling the lapis, a sun
	-- halo with rays and a glowing pommel (BundleStaffFX.<tool>.Decor,
	-- each part stores its offset from the handle in LocalCF)
	local fxRoot = ServerStorage:FindFirstChild("BundleStaffFX")
	local decor = fxRoot and fxRoot:FindFirstChild(up.Tool) and fxRoot[up.Tool]:FindFirstChild("Decor")
	if decor then
		local holder = Instance.new("Model")
		holder.Name = UPGRADE_TAG .. "Decor"
		for _, p in ipairs(decor:GetChildren()) do
			local cf = p:GetAttribute("LocalCF")
			if p:IsA("BasePart") and typeof(cf) == "CFrame" then
				local c = p:Clone()
				c.Anchored = false
				c.CFrame = handle.CFrame * cf
				local w = Instance.new("WeldConstraint")
				w.Part0 = handle
				w.Part1 = c
				w.Parent = c
				c.Parent = holder
			end
		end
		holder.Parent = tool
	end

	local light = Instance.new("PointLight")
	light.Name = UPGRADE_TAG .. "Light"
	light.Color = a
	light.Brightness = up.LightBrightness or 2.5
	light.Range = 14
	light.Parent = handle

	-- swing trail
	local t0 = Instance.new("Attachment")
	t0.Name = UPGRADE_TAG .. "TrailA"
	t0.Position = Vector3.new(0, handle.Size.Y * 0.45, 0)
	t0.Parent = handle
	local t1 = Instance.new("Attachment")
	t1.Name = UPGRADE_TAG .. "TrailB"
	t1.Position = Vector3.new(0, -handle.Size.Y * 0.45, 0)
	t1.Parent = handle
	local trail = Instance.new("Trail")
	trail.Name = UPGRADE_TAG .. "Trail"
	trail.Attachment0 = t0
	trail.Attachment1 = t1
	trail.Color = ColorSequence.new(a, b)
	trail.LightEmission = up.LightBrightness and 0.2 or 1
	trail.Lifetime = 0.35
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = handle

	-- ONE outline over the whole staff. The staff came with three separate
	-- Highlights (handle, butt, and the lapis on top); Roblox only draws
	-- 31 Highlights at once, so with a field of lapis around, the top one
	-- was the first to drop out. One instance = one slot, and it covers
	-- every part including the top.
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("Highlight") then d.Enabled = false end
	end
	local hl = Instance.new("Highlight")
	hl.Name = UPGRADE_TAG .. "Outline"
	hl.Adornee = tool
	hl.FillColor = b
	hl.FillTransparency = 1 -- outline only; a fill washed out the gold
	hl.OutlineColor = a
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = tool

	-- the island's own effects, shrunk down: a mini version of the
	-- island's tornado + the lapis' stars/lightning swirling round the tip
	local fx = ServerStorage:FindFirstChild("BundleStaffFX")
	fx = fx and fx:FindFirstChild(up.Tool)
	local tipTemplate = fx and fx:FindFirstChild("Tip")
	if tipTemplate then
		local tip = tipTemplate:Clone()
		tip.Name = UPGRADE_TAG .. "Tip"
		tip.Parent = handle
	end

	-- while it's in your hands, the island's aura spins round your feet
	local groundTemplate = fx and fx:FindFirstChild("Ground")
	local aura
	local function clearAura()
		if aura then aura:Destroy() aura = nil end
	end
	tool.Equipped:Connect(function()
		clearAura()
		local c = tool.Parent
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not (r and groundTemplate) then return end
		aura = groundTemplate:Clone()
		aura.Name = UPGRADE_TAG .. "Aura_" .. up.Tool
		aura.Parent = r
		local glow = Instance.new("PointLight")
		glow.Color = a
		glow.Brightness = (up.LightBrightness or 2.5) * 1.2
		glow.Range = 18
		glow.Parent = aura
	end)
	tool.Unequipped:Connect(clearAura)
	tool.Destroying:Connect(clearAura)
end

local staffWatch = {} -- [player] = { connections }

local function upgradesFor(player)
	local list = {}
	for _, pass in ipairs(MonetizationData.Passes) do
		local benefit = MonetizationData.Benefits[pass.Key]
		if benefit and benefit.StaffUpgrade and MonetizationData.Owns(player, pass.Key) then
			list[benefit.StaffUpgrade.Tool] = benefit.StaffUpgrade
		end
	end
	return list
end

local function checkTool(player, tool)
	if not tool:IsA("Tool") then return end
	local up = upgradesFor(player)[tool.Name]
	if up then upgradeTool(tool, up) end
end

local function watchContainer(player, container)
	if not container then return end
	for _, c in ipairs(container:GetChildren()) do checkTool(player, c) end
	local conn = container.ChildAdded:Connect(function(c) checkTool(player, c) end)
	staffWatch[player] = staffWatch[player] or {}
	table.insert(staffWatch[player], conn)
end

local function applyStaffUpgrades(player)
	if not next(upgradesFor(player)) then return end
	if staffWatch[player] then
		for _, c in ipairs(staffWatch[player]) do c:Disconnect() end
	end
	staffWatch[player] = {}
	watchContainer(player, player:FindFirstChildOfClass("Backpack"))
	watchContainer(player, player.Character)
	table.insert(staffWatch[player], player.ChildAdded:Connect(function(c)
		if c:IsA("Backpack") then watchContainer(player, c) end
	end))
end

Players.PlayerRemoving:Connect(function(player)
	if staffWatch[player] then
		for _, c in ipairs(staffWatch[player]) do c:Disconnect() end
		staffWatch[player] = nil
	end
end)

local function giveTitle(player, titleId)
	if type(_G.GrantTitle) ~= "function" then return end
	pcall(_G.GrantTitle, player, titleId)
end

--==================================================
-- ELYTRA CONTROLS HINT
--
-- Flight is bound to a double-tap of jump, which is not
-- something anyone guesses. So the first time a player
-- has the Elytra, a prompt appears telling them -- and
-- once they've actually flown, it never comes back.
--
-- "Has flown" rides in the same ledger as the one-time
-- grants, so it survives rejoining. The client reads the
-- ElytraHint attribute; it replicates, so no extra
-- remote is needed to show or hide the prompt.
--==================================================

local FLOWN_KEY = "ElytraFlown"

local elytraFlownRemote = ReplicatedStorage:FindFirstChild("ElytraFlown")
if not elytraFlownRemote then
	elytraFlownRemote = Instance.new("RemoteEvent")
	elytraFlownRemote.Name = "ElytraFlown"
	elytraFlownRemote.Parent = ReplicatedStorage
end

-- Same idea for the OP (Command) Staff's click-to-fling:
-- "CLICK TO FLING" shows until they've used it once.
local FLUNG_KEY = "StaffFlung"

local staffFlungRemote = ReplicatedStorage:FindFirstChild("StaffFlung")
if not staffFlungRemote then
	staffFlungRemote = Instance.new("RemoteEvent")
	staffFlungRemote.Name = "StaffFlung"
	staffFlungRemote.Parent = ReplicatedStorage
end

-- The "how to use it" prompts come back EVERY time you join, and go away
-- once you've used the item in that session.
local usedThisSession = {} -- [player] = { Elytra = true, Staff = true }

local function refreshElytraHint(player)
	local used = usedThisSession[player] or {}
	local owns = MonetizationData.Owns(player, "Elytra")
	player:SetAttribute("ElytraHint", owns and not used.Elytra)

	-- Not gated on the pass: the staff can also be bought with PP.
	-- The prompt itself only appears while the staff is held.
	player:SetAttribute("StaffHint", not used.Staff)
end

Players.PlayerRemoving:Connect(function(player) usedThisSession[player] = nil end)

staffFlungRemote.OnServerEvent:Connect(function(player)
	usedThisSession[player] = usedThisSession[player] or {}
	usedThisSession[player].Staff = true
	player:SetAttribute("StaffHint", false)
end)

elytraFlownRemote.OnServerEvent:Connect(function(player)
	usedThisSession[player] = usedThisSession[player] or {}
	usedThisSession[player].Elytra = true
	player:SetAttribute("ElytraHint", false)
end)

-- Everything that has to be re-applied on spawn, on join,
-- and after every ascension.
--
-- Staff unlocks belong here rather than in the one-time
-- ledger. Ascending resets OwnedItems to just the starter
-- staff, so a bundle staff granted once at purchase would
-- vanish on the player's first rebirth and the ledger
-- would then refuse to hand it back -- which is exactly
-- what "the bundle staffs don't save on rebirth" was.
local function applyPersistentBenefits(player)
	for _, pass in ipairs(MonetizationData.Passes) do
		if MonetizationData.Owns(player, pass.Key) then
			local benefit = MonetizationData.Benefits[pass.Key]
			if benefit then
				if benefit.Accessory then
					giveAccessory(player, benefit.Accessory)
				end
				-- (not in test sessions: the title would be SAVED to the real account)
				if benefit.Title and not isTestSession() then
					giveTitle(player, benefit.Title)
				end
				if benefit.RobeEffect then
					applyRobe(player)
				end
				if benefit.Staffs then
					for _, itemName in ipairs(benefit.Staffs) do
						if isTestSession() then
							-- session-only tool, nothing saved
							local toolName = TEST_STAFF_TOOLS[itemName]
							local models = ServerStorage:FindFirstChild("AccessibleModels")
							local staffs = models and models:FindFirstChild("Staffs")
							local template = toolName and staffs and staffs:FindFirstChild(toolName)
							local bp = player:FindFirstChildOfClass("Backpack")
							local has = bp and bp:FindFirstChild(toolName) or (player.Character and player.Character:FindFirstChild(toolName))
							if template and bp and not has then
								-- Tagged so LeaderboardStats' clearTools (ascension,
								-- equipping another staff) leaves it alone. Without the
								-- tag it was destroyed on every ascension and only came
								-- back if the 1s re-grant won the race.
								local tool = template:Clone()
								tool:SetAttribute("PassSessionTool", true)
								tool.Parent = bp
							end
						else
							giveLapis(player, itemName, 0)
						end
					end
				end
			end
		end
	end
	applyStaffUpgrades(player)
end

--==================================================
-- REBIRTH
--
-- Watching the Ascensions stat rather than hooking the
-- ascend event: performAscension is reachable from the
-- rebirth button, the shop remote, /ascend and /reset,
-- and only the stat changes on all of them.
--==================================================

local function watchAscensions(player)
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 20)
		if not leaderstats then return end

		local stat = leaderstats:WaitForChild("Ascensions", 20)
			or leaderstats:FindFirstChild("Rebirths")
		if not stat then return end

		stat.Changed:Connect(function()
			-- LeaderboardStats wipes OwnedItems as part of the
			-- ascension; re-granting in the same frame would race
			-- it and lose.
			-- Re-applied twice as a backstop: once after the wipe, and
			-- again after any client re-equip that follows the cinematic.
			for _, delaySec in ipairs({ 1, 3 }) do
				task.delay(delaySec, function()
					if player.Parent then
						applyPersistentBenefits(player)
					end
				end)
			end
		end)
	end)
end

-- Consumables. Guarded by the DataStore ledger.
local function applyOneTimeGrants(player)
	local userId = player.UserId
	-- Test sessions (Studio / Team Test) hand out every pass for free, and
	-- they use the REAL DataStores - so a test grant of bundle lapis landed
	-- in the real inventory (and marked the bundle as already granted).
	-- Consumables are never given in a test session.
	if isTestSession() then return end

	for _, pass in ipairs(MonetizationData.Passes) do
		local benefit = MonetizationData.Benefits[pass.Key]
		local grant = benefit and benefit.OneTimeGrant

		if grant
			and MonetizationData.Owns(player, pass.Key)
			and not hasGranted(userId, pass.Key)
		then
			if grant.Lapis then
				for itemName, amount in pairs(grant.Lapis) do
					giveLapis(player, itemName, amount)
				end
			end

			markGranted(userId, pass.Key)
			print(("[Monetization] granted %s to %s"):format(pass.Name, player.Name))
		end

		-- the buffed bundle amount: own ledger key, so pre-buff buyers get it too.
		-- Added straight to the inventory (not GiveLapis) so the bonus lapis
		-- don't also unlock every matching staff for free.
		local bonus = benefit and benefit.BonusGrant
		if bonus and bonus.Key
			and MonetizationData.Owns(player, pass.Key)
			and not hasGranted(userId, bonus.Key)
		then
			local ok, InventoryService = pcall(require, script.Parent:WaitForChild("InventoryService"))
			if ok and InventoryService and InventoryService.WaitUntilLoaded then
				pcall(InventoryService.WaitUntilLoaded, player)
			end
			if ok and InventoryService and player.Parent and not hasGranted(userId, bonus.Key) then
				for itemName, amount in pairs(bonus.Lapis or {}) do
					InventoryService.Add(player, itemName, amount)
				end
				markGranted(userId, bonus.Key)
				print(("[Monetization] granted %s bonus to %s"):format(pass.Name, player.Name))
			end
		end
	end

	saveGrants(userId)
end

--==================================================
-- OWNERSHIP
--==================================================

local function checkPass(player, pass)
	for attempt = 1, OWNERSHIP_RETRIES do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
		end)

		if ok then
			return owns == true
		end

		if attempt < OWNERSHIP_RETRIES then
			task.wait(RETRY_DELAY)
		end
	end

	warn(("[Monetization] ownership check failed for %s / %s"):format(player.Name, pass.Name))
	return nil   -- unknown, not "no"
end

local function refreshOwnership(player)
	if IGNORE_OWNER_PASSES and isOwnerAccount(player) and not isTestSession() then
		-- (see IGNORE_OWNER_PASSES: only the complimentary ones)
		local free = COMPLIMENTARY[player.Name] or {}
		for _, pass in ipairs(MonetizationData.Passes) do
			player:SetAttribute(MonetizationData.AttributeFor(pass.Key), free[pass.Key] == true)
		end
		return
	end
	if studioGrantsEverything(player) then
		for _, pass in ipairs(MonetizationData.Passes) do
			player:SetAttribute(MonetizationData.AttributeFor(pass.Key), true)
		end
		if not player:GetAttribute("_PassGrantLogged") then
			player:SetAttribute("_PassGrantLogged", true)
			print("[Monetization] test session: granted all passes to " .. player.Name
				.. "  (/resetpasses to clear, STUDIO_GRANT_ALL=false to disable)")
		end
		return
	end

	-- Checked in PARALLEL. One at a time meant 10 passes x up to 3 retries x a
	-- 2s wait each: with several people joining together the web calls throttle
	-- and the last passes could take most of a minute to resolve.
	local threads = 0
	for _, pass in ipairs(MonetizationData.Passes) do
		local attribute = MonetizationData.AttributeFor(pass.Key)

		-- Never overwrite a true we already know about with an
		-- unknown. A failed web call should not strip a pass
		-- the player has already been given this session.
		if player:GetAttribute(attribute) ~= true then
			threads += 1
			task.spawn(function()
				local owns = checkPass(player, pass)
				if owns ~= nil and player.Parent then
					player:SetAttribute(attribute, owns)
				end
				threads -= 1
			end)
		end
	end

	-- give the checks a moment to land, but never block the join for long
	local waited = 0
	while threads > 0 and waited < 8 do
		task.wait(0.25)
		waited += 0.25
	end
end

--==================================================
-- PLAYER LIFECYCLE
--==================================================

local function onPlayerAdded(player)
	-- Default every attribute to false first so client code
	-- can read them immediately instead of waiting on nil.
	for _, pass in ipairs(MonetizationData.Passes) do
		player:SetAttribute(MonetizationData.AttributeFor(pass.Key), false)
	end

	-- Freebies are set before the web check so they are never
	-- clobbered by a "you don't own this" answer.
	local free = COMPLIMENTARY[player.Name]
	if free then
		for key in pairs(free) do
			player:SetAttribute(MonetizationData.AttributeFor(key), true)
		end
	end

	loadGrants(player.UserId)
	refreshOwnership(player)

	-- LeaderboardStats needs its session table built before
	-- GiveLapis will land, and TitleService needs its own data
	-- loaded before a title can be granted. Both happen on
	-- PlayerAdded too, so give them a moment rather than
	-- racing them.
	task.delay(4, function()
		if not player.Parent then return end
		applyOneTimeGrants(player)
		applyPersistentBenefits(player)
		refreshElytraHint(player)
	end)

	watchAscensions(player)

	-- A purchase made while the ownership web call was failing (or by someone
	-- whose Robux prompt closed after they'd already left and rejoined) is
	-- picked up by this sweep instead of needing another rejoin.
	task.spawn(function()
		-- every 20s for the first two minutes, then every 90s for the rest of
		-- the session (only passes not already owned are re-checked)
		for i = 1, 200 do
			task.wait(i <= 6 and 20 or 90)
			if not player.Parent then return end
			refreshOwnership(player)
			applyOneTimeGrants(player)
			applyPersistentBenefits(player)
		end
	end)

	local function onCharacter(character)
		-- Accessories are parented to the character, so they die
		-- with it and have to be re-applied on every respawn.
		task.wait(0.5)
		applyPersistentBenefits(player)
		refreshElytraHint(player)

		-- Avatar loading can finish AFTER we've added the wings, and applying
		-- the avatar strips accessories that aren't part of it -- which is why
		-- some players (slow-loading / big avatars) "never got" the Elytra.
		-- So: re-apply once the appearance has loaded, a couple of times
		-- after that as a backstop, and put it straight back if it's removed
		-- while they still own it.
		for _, delaySec in ipairs({ 2.5, 6, 12 }) do
			task.delay(delaySec, function()
				if player.Parent and player.Character == character then
					applyPersistentBenefits(player)
				end
			end)
		end
		local pending = false
		character.ChildRemoved:Connect(function(child)
			if pending or not child:IsA("Accessory") then return end
			for _, pass in ipairs(MonetizationData.Passes) do
				local benefit = MonetizationData.Benefits[pass.Key]
				if benefit and benefit.Accessory == child.Name and MonetizationData.Owns(player, pass.Key) then
					pending = true
					task.delay(0.3, function()
						pending = false
						local hum = character:FindFirstChildOfClass("Humanoid")
						if character.Parent and player.Character == character and hum and hum.Health > 0 then
							giveAccessory(player, benefit.Accessory)
						end
					end)
					return
				end
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	player.CharacterAppearanceLoaded:Connect(function(character)
		if player.Character == character then
			applyPersistentBenefits(player)
		end
	end)
	if player.Character then task.spawn(onCharacter, player.Character) end
end

local function onPlayerRemoving(player)
	saveGrants(player.UserId)
	grantedCache[player.UserId] = nil
	grantsDirty[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

--==================================================
-- LIVE PURCHASES
--
-- Fires the moment the Robux prompt closes. Without
-- this the player pays and then sits there wondering
-- why nothing happened until they rejoin.
--==================================================

local function grantPurchased(player, pass, source)
	if MonetizationData.Owns(player, pass.Key) then
		applyPersistentBenefits(player)
		return
	end
	player:SetAttribute(MonetizationData.AttributeFor(pass.Key), true)
	applyOneTimeGrants(player)
	applyPersistentBenefits(player)
	refreshElytraHint(player)
	task.delay(2, function()
		if player.Parent then applyPersistentBenefits(player) refreshElytraHint(player) end
	end)
	print(("[Monetization] %s purchased %s (%s)"):format(player.Name, pass.Name, source))
end

-- Backup path: the buyer's own client also reports the finished prompt.
-- It is never trusted on a live server -- ownership is re-checked with
-- Roblox (retrying for ~30s while the purchase propagates) -- but in
-- Studio / Team Test, where test purchases never show up as owned, the
-- client's word is enough. This covers the case where the server-side
-- event didn't reach us ("it doesn't work for other people").
local purchaseReport = ReplicatedStorage:FindFirstChild("PassPurchaseReport")
if not purchaseReport then
	purchaseReport = Instance.new("RemoteEvent")
	purchaseReport.Name = "PassPurchaseReport"
	purchaseReport.Parent = ReplicatedStorage
end
local reportBusy = {}
purchaseReport.OnServerEvent:Connect(function(player, gamePassId)
	local pass = type(gamePassId) == "number" and MonetizationData.GetById(gamePassId)
	if not pass or MonetizationData.Owns(player, pass.Key) then return end
	local key = player.UserId .. ":" .. pass.Id
	if reportBusy[key] then return end
	reportBusy[key] = true
	if isTestSession() then
		grantPurchased(player, pass, "test purchase")
		reportBusy[key] = nil
		return
	end
	for _ = 1, 10 do
		if not player.Parent or MonetizationData.Owns(player, pass.Key) then break end
		if checkPass(player, pass) == true then
			grantPurchased(player, pass, "verified")
			break
		end
		task.wait(3)
	end
	reportBusy[key] = nil
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	local pass = MonetizationData.GetById(tonumber(gamePassId))
	if not pass then return end
	if not wasPurchased then
		-- closed the prompt: maybe because they already own it (bought on the
		-- website). Re-check just this pass.
		task.spawn(function()
			if not MonetizationData.Owns(player, pass.Key) and checkPass(player, pass) == true then
				grantPurchased(player, pass, "already owned")
			end
		end)
		return
	end

	player:SetAttribute(MonetizationData.AttributeFor(pass.Key), true)

	applyOneTimeGrants(player)
	applyPersistentBenefits(player)
	refreshElytraHint(player)
	task.delay(2, function()
		if player.Parent then applyPersistentBenefits(player) refreshElytraHint(player) end
	end)

	print(("[Monetization] %s purchased %s"):format(player.Name, pass.Name))
end)

--==================================================
-- DEVELOPER PRODUCTS  (PeacePoints packs)
--
-- ProcessReceipt is the ONLY safe place to grant a
-- product. Roblox re-delivers a receipt until the
-- callback returns PurchaseGranted, so the rules are:
--
--   * return NotProcessedYet on ANY failure, so the
--     player gets another chance instead of losing
--     their Robux;
--   * record the PurchaseId before granting, so a
--     re-delivered receipt can't pay out twice.
--
-- MarketplaceService allows exactly one ProcessReceipt
-- callback per game. Nothing else in this place sets
-- one -- if you add a second, it silently replaces
-- this one and every purchase starts failing.
--==================================================

local receiptStore = DataStoreService:GetDataStore("PurchaseReceipts_v1")

-- tells the client its paid skip landed (plays the ascension fanfare)
if not ReplicatedStorage:FindFirstChild("SkipAscensionDone") then
	local ev = Instance.new("RemoteEvent")
	ev.Name = "SkipAscensionDone"
	ev.Parent = ReplicatedStorage
end
local sessionReceipts = {}

local function alreadyHandled(purchaseId)
	local ok, seen = pcall(function()
		return receiptStore:GetAsync(purchaseId)
	end)

	if not ok then
		-- Can't tell. Treat as unhandled but let the caller
		-- decide; the write below is what actually guards.
		return nil
	end

	return seen == true
end

local function markHandled(purchaseId)
	local ok = pcall(function()
		receiptStore:SetAsync(purchaseId, true)
	end)
	return ok
end

local function creditPeacePoints(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	local pp = leaderstats and leaderstats:FindFirstChild("PeacePoints")

	if not pp then
		return false
	end

	pp.Value = pp.Value + amount
	return true
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)

	if not player then
		-- They left mid-purchase. Roblox will redeliver the
		-- receipt next time they join.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = MonetizationData.GetProductById(receiptInfo.ProductId)

	local skipTier = MonetizationData.SkipTierById(receiptInfo.ProductId)
	local isSkip = skipTier ~= nil
	if isSkip then
		product = { Key = "SkipAscension", Label = "Skip Ascension", Price = skipTier.Price }
	end

	if not product then
		warn("[Monetization] unknown product id " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)

	if alreadyHandled(purchaseId) == true then
		-- Redelivery of something already paid out.
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Claim the receipt BEFORE granting. If the write fails we
	-- have no duplicate protection, so refuse and let Roblox
	-- try again rather than risk paying out twice.
	if sessionReceipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if not markHandled(purchaseId) then
		-- Team Test / Studio sessions sometimes can't write to
		-- DataStores. Test purchases cost nothing, so grant
		-- anyway there (guarded by the in-memory set). On a live
		-- server we still defer so a real purchase can't pay twice.
		if not (isTestSession() or isDeveloper(player)) then
			warn("[Monetization] couldn't record receipt " .. purchaseId .. " -- deferring")
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		warn("[Monetization] receipt store unavailable, granting test purchase anyway")
	end
	sessionReceipts[purchaseId] = true

	if isSkip then
		-- Same path the admin panel uses: LeaderboardStats.performAscension
		-- (wipes PP/inventory, +1 ascension, keeps pass staffs).
		local ls = player:FindFirstChild("leaderstats")
		local asc = ls and (ls:FindFirstChild("Ascensions") or ls:FindFirstChild("Rebirths"))
		local bindable = adminBindable()
		if not asc or not bindable then
			sessionReceipts[purchaseId] = nil
			pcall(function() receiptStore:RemoveAsync(purchaseId) end)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local before = asc.Value
		for _ = 1, 3 do
			bindable:Fire(player, "Ascend")
			local t = 0
			while asc.Value == before and t < 1.5 do
				task.wait(0.1)
				t += 0.1
			end
			if asc.Value > before then break end
		end
		if asc.Value <= before then
			warn("[Monetization] skip-ascension for " .. player.Name .. " didn't land -- will retry")
			sessionReceipts[purchaseId] = nil
			pcall(function() receiptStore:RemoveAsync(purchaseId) end)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local fx = ReplicatedStorage:FindFirstChild("SkipAscensionDone")
		if fx then fx:FireClient(player, asc.Value) end
		print(("[Monetization] %s skipped to ascension %d"):format(player.Name, asc.Value))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local granted = creditPeacePoints(player, product.Amount)

	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	print(("[Monetization] %s bought %s (+%d PP)"):format(
		player.Name, product.Label, product.Amount))

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--==================================================
-- PUBLIC HELPERS
--
-- Exposed on _G so the older scripts in this game can
-- use them without being converted to modules.
--==================================================

_G.HasPass = function(player, key)
	return MonetizationData.Owns(player, key)
end

_G.GetMoneyMultiplier = function(player)
	return MonetizationData.GetMoneyMultiplier(player)
end

_G.RefreshPasses = function(player)
	refreshOwnership(player)
	applyPersistentBenefits(player)
end

--==================================================
-- /resetpasses
--
-- Drops every pass for this player: the attributes go
-- false, the one-time grant ledger is wiped so bundles
-- can be tested again from scratch, and the Elytra hint
-- comes back.
--
-- In Studio the passes are re-granted on the next join
-- (see STUDIO_GRANT_ALL), which is what you want when
-- testing. On a live server the next ownership check
-- puts back whatever the player genuinely owns, so this
-- cannot be used to permanently strip a paying player.
--==================================================

_G.ResetPasses = function(player)
	if not player then return false end

	for _, pass in ipairs(MonetizationData.Passes) do
		player:SetAttribute(MonetizationData.AttributeFor(pass.Key), false)
	end

	local userId = player.UserId
	grantedCache[userId] = {}
	grantsDirty[userId] = true
	saveGrants(userId)

	player:SetAttribute("ElytraHint", false)

	-- Strip the things that are applied to the character rather
	-- than read live, so the reset is visible immediately.
	local character = player.Character
	if character then
		clearRobe(character)
		local elytra = character:FindFirstChild("Elytra")
		if elytra then elytra:Destroy() end
	end

	print("[Monetization] reset all passes for " .. player.Name)
	return true
end

_G.GivePass = function(player, key)
	local pass = MonetizationData.GetByKey(key)
	if not player or not pass then return false end

	player:SetAttribute(MonetizationData.AttributeFor(pass.Key), true)
	applyOneTimeGrants(player)
	applyPersistentBenefits(player)
	refreshElytraHint(player)

	print(("[Monetization] granted %s to %s by command"):format(pass.Name, player.Name))
	return true
end

_G.ListPasses = function(player)
	local owned = {}
	for _, pass in ipairs(MonetizationData.Passes) do
		table.insert(owned, ("  %-18s %s"):format(
			pass.Key, MonetizationData.Owns(player, pass.Key) and "OWNED" or "-"))
	end
	return table.concat(owned, "\n")
end

print("[Monetization] ready -- " .. #MonetizationData.Passes .. " passes registered")
