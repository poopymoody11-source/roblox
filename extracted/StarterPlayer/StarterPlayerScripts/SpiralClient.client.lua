-- ModuleScript | ServerStorage.BossGasterBlasters   (directly in ServerStorage, NOT in BossAttacks)
-- Manages a fixed ring of Gaster Blaster models spaced evenly around the arena. Created once per
-- boss fight and reused for every blast: nothing is cloned or destroyed per-shot, only faded in
-- and back out, so firing bursts of them costs very little.
--
-- Every blaster fires along the same fixed line it rests on -- straight across the map, through
-- the arena center, to the opposite side of the ring -- rather than aiming at a player. Because a
-- fixed line can't track anyone, its hit width is HitWidthMultiplier times Config.BeamWidth, so it
-- still has a real chance to catch someone. Both the warning line and the beam are drawn at that
-- same real hit width, so what you see is what can hurt you.
--
-- A blaster sits invisible until fired. Firing it (see :Fire) runs through, in order:
--   1. fades in and starts charging: plays Anims.GasterPrep      (FadeIn seconds)
--   2. shows a thin, non-damaging telegraph line along its fixed
--      path; GasterPrep keeps playing                            (Warning seconds)
--   3. becomes a damaging beam: plays Anims.GasterFire            (BeamHold seconds)
--   4. fades back out to invisible                                (FadeOut seconds)
-- Anyone caught in the live beam takes damage once, the same "distance check, not a script"
-- approach BossSpikes uses.
--
-- Needs:
--   ServerStorage.BossAbilities.GasterBlaster    the Gaster Blaster Model. Its front should point
--     along local -Z; if it doesn't, set Config.RotationOffset below. It doesn't need its own
--     AnimationController/Animator -- one is added automatically if it's missing.
--   ServerStorage.BossAttacks.Anims.GasterPrep   Animation, played while a blaster charges up
--   ServerStorage.BossAttacks.Anims.GasterFire   Animation, played while its beam is live
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")
local Util = require(ServerStorage:WaitForChild("BossUtil"))

local PLAYER_SLOP = 2.5 -- roughly the size of a character around its root part

local animsFolder = ServerStorage:WaitForChild("BossAttacks"):WaitForChild("Anims")
local prepAnimation = animsFolder:WaitForChild("GasterPrep")
local fireAnimation = animsFolder:WaitForChild("GasterFire")

-- Catches the single most common reason a custom rig's animation "does nothing": the Animation
-- instance itself was never given a real AnimationId. LoadAnimation/Play won't error on a blank
-- or placeholder id -- they just silently produce no motion -- so check for it up front instead.
local function checkAnimationId(animation)
	local id = animation.AnimationId
	if id == "" or id == "rbxassetid://0" or id == "rbxasset://0" then
		warn(("BossGasterBlasters: %s has no AnimationId set (ServerStorage.BossAttacks.Anims.%s)")
			:format(animation:GetFullName(), animation.Name))
	end
end
checkAnimationId(prepAnimation)
checkAnimationId(fireAnimation)

local Config = {
	Count = 24,
	HeightAboveFloor = 10,   -- studs above the arena floor the ring sits at
	RotationOffset = Vector3.new(0, -90, 0),    -- Vector3 of degrees, e.g. Vector3.new(90, 0, 0), if the model's
	-- "front" isn't -Z. Leave nil if the model already faces -Z.
	FadeIn = 0.25,
	Warning = 0.6,
	BeamHold = 0.4,
	FadeOut = 0.35,
	Damage = 35,
	BeamWidth = 3,           -- studs; the "base" width used below
	HitWidthMultiplier = 10, -- both the beam AND its warning line are drawn at BeamWidth * this,
	-- since a fixed line can't track anyone and needs the extra reach --
	-- widening only the hitbox and not the visual would hide it from players
	Color = Color3.fromRGB(140, 225, 255),
}

local GasterBlasters = {}
GasterBlasters.__index = GasterBlasters

-- A thin Neon block, `length` studs long, running from `origin` to `origin + direction * length`
local function newLinePart(self, width, length)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Config.Color
	part.Size = Vector3.new(width, width, length)
	part.Parent = self.Folder
	return part
end

local function placeLine(part, origin, direction, length)
	part.CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -length / 2)
end

-- Tweens every part of `model` toward its recorded base transparency (visible) or fully
-- transparent (hidden). Doesn't yield -- callers task.wait the duration themselves so the rest
-- of the sequence (warning, beam) stays a simple linear read.
local function fadeModel(model, baseTransparency, duration, visible)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for part, base in pairs(baseTransparency) do
		local target = if visible then base else 1
		TweenService:Create(part, info, { Transparency = target }):Play()
	end
end

-- Finds or creates an AnimationController + Animator on `model`, so a non-Humanoid model (like a
-- floating Gaster Blaster) can still play animations.
local function getAnimator(model)
	local controller = model:FindFirstChildOfClass("AnimationController")
		or model:FindFirstChildOfClass("Humanoid")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end

	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end
	return animator
end

-- Runs one full fire sequence for `entry`. Spawned as its own thread by :Fire so several
-- blasters can be mid-sequence at once without blocking each other.
local function runFire(self, entry, opts)
	local boss = self.Boss
	entry.Busy = true

	local origin = entry.RestCFrame.Position
	local direction = entry.RestCFrame.LookVector -- fixed: straight across the map, not aimed at anyone

	-- 1. fade in + start the charge-up animation
	fadeModel(entry.Model, entry.PartTransparency, opts.FadeIn, true)
	entry.PrepTrack:Play(0.1)
	task.wait(opts.FadeIn)
	if self.Destroyed or not boss.Alive then
		entry.PrepTrack:Stop(0.1)
		entry.Busy = false
		return
	end

	local range = boss.Arena.Radius * 2.5 -- comfortably crosses the whole disc from any ring position
	local hitWidth = opts.BeamWidth * opts.HitWidthMultiplier -- the real, wider hit width -- see Config above

	-- 2. warning: a line telegraphing exactly where the beam is about to go, drawn at the real hit
	-- width so the danger zone you see is the one that can actually hurt you. No damage yet.
	-- GasterPrep keeps playing through this.
	local warningPart = newLinePart(self, hitWidth, range)
	warningPart.Transparency = 0.75
	placeLine(warningPart, origin, direction, range)

	local elapsed = 0
	while elapsed < opts.Warning do
		elapsed += RunService.Heartbeat:Wait()
		if self.Destroyed or not boss.Alive then
			warningPart:Destroy()
			entry.PrepTrack:Stop(0.1)
			entry.Busy = false
			return
		end
	end
	warningPart:Destroy()
	entry.PrepTrack:Stop(0.15)

	-- 3. beam: bright and damaging for BeamHold seconds, plays GasterFire, same hitWidth as the
	-- warning that preceded it. `hit` makes sure each character is only damaged once even though
	-- the check runs every frame the beam is live.
	local beamPart = newLinePart(self, hitWidth, range)
	beamPart.Transparency = 0.1
	placeLine(beamPart, origin, direction, range)
	entry.FireTrack:Play(0.05)

	local beamRadius = hitWidth / 2
	local hit = {}
	elapsed = 0
	while elapsed < opts.BeamHold do
		elapsed += RunService.Heartbeat:Wait()
		if self.Destroyed or not boss.Alive then
			beamPart:Destroy()
			entry.FireTrack:Stop(0.1)
			entry.Busy = false
			return
		end

		for _, root in boss:GetTargets() do
			local character = root.Parent
			if not hit[character] then
				local toRoot = root.Position - origin
				local along = toRoot:Dot(direction)
				if along >= -PLAYER_SLOP and along <= range then
					local perp = (toRoot - direction * along).Magnitude
					if perp <= beamRadius + PLAYER_SLOP then
						hit[character] = true
						local humanoid = character:FindFirstChildOfClass("Humanoid")
						if humanoid then
							humanoid:TakeDamage(opts.Damage)
						end
					end
				end
			end
		end
	end
	beamPart:Destroy()
	entry.FireTrack:Stop(0.2)

	-- 4. fade out
	fadeModel(entry.Model, entry.PartTransparency, opts.FadeOut, false)
	task.wait(opts.FadeOut)
	entry.Busy = false
end

function GasterBlasters.new(boss, template)
	local self = setmetatable({}, GasterBlasters)
	self.Boss = boss
	self.Destroyed = false
	self.Blasters = {}

	local rotationOffset = CFrame.identity
	if Config.RotationOffset then 
		rotationOffset = CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
	end

	self.Folder = Instance.new("Folder")
	self.Folder.Name = "GasterBlasters"
	self.Folder.Parent = boss.Effects

	local arena = boss.Arena
	for i = 1, Config.Count do
		local angle = ((i - 1) / Config.Count) * math.pi * 2
		local pos = Vector3.new(
			arena.Center.X + math.cos(angle) * arena.Radius,
			arena.SurfaceY + Config.HeightAboveFloor,
			arena.Center.Z + math.sin(angle) * arena.Radius
		)
		-- the direction every shot from this blaster travels: straight through the arena center
		-- to the opposite side of the ring. Fixed at creation, since the aim never changes shot to shot.
		local restCFrame = CFrame.lookAt(pos, Vector3.new(arena.Center.X, pos.Y, arena.Center.Z))

		local model = template:Clone()
		for _, item in model:GetDescendants() do
			if item:IsA("BaseScript") then
				item:Destroy()
			end
		end
		Util.MakeInert(model)
		-- rotationOffset only corrects the model's visual facing; the beam always travels along
		-- restCFrame's direction regardless of this
		model:PivotTo(restCFrame * rotationOffset)
		model.Parent = self.Folder

		local partTransparency = {}
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				partTransparency[part] = part.Transparency
				part.Transparency = 1
			end
		end

		local animator = getAnimator(model)
		local prepTrack = animator:LoadAnimation(prepAnimation)
		prepTrack.Priority = Enum.AnimationPriority.Action
		local fireTrack = animator:LoadAnimation(fireAnimation)
		fireTrack.Priority = Enum.AnimationPriority.Action

		-- one-time check: Length reads 0 immediately after LoadAnimation even for a fine
		-- animation, so wait a beat first. If it's still 0/near-0 after that, the keyframe data
		-- itself never loaded server-side (commonly: published very recently and still going
		-- through Roblox's processing, even though the Animation Editor already previews it).
		if i == 1 then
			task.spawn(function()
				task.wait(1)
				print(("BossGasterBlasters: GasterPrep Length=%.2f, GasterFire Length=%.2f")
					:format(prepTrack.Length, fireTrack.Length))
			end)
		end

		table.insert(self.Blasters, {
			Model = model,
			RestCFrame = restCFrame,
			PartTransparency = partTransparency,
			PrepTrack = prepTrack,
			FireTrack = fireTrack,
			Busy = false,
		})
	end

	return self
end

-- Fires blaster `index` (1..#self.Blasters) along its fixed line. No-ops if that index is
-- already mid-sequence, or the manager has been destroyed. opts (all optional, fall back to
-- Config): FadeIn, Warning, BeamHold, FadeOut, Damage, BeamWidth, HitWidthMultiplier.
-- Doesn't yield.
function GasterBlasters:Fire(index, opts)
	if self.Destroyed then return end
	local entry = self.Blasters[index]
	if not entry or entry.Busy then return end

	opts = opts or {}
	task.spawn(runFire, self, entry, {
		FadeIn = opts.FadeIn or Config.FadeIn,
		Warning = opts.Warning or Config.Warning,
		BeamHold = opts.BeamHold or Config.BeamHold,
		FadeOut = opts.FadeOut or Config.FadeOut,
		Damage = opts.Damage or Config.Damage,
		BeamWidth = opts.BeamWidth or Config.BeamWidth,
		HitWidthMultiplier = opts.HitWidthMultiplier or Config.HitWidthMultiplier,
	})
end

function GasterBlasters:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	self.Folder:Destroy()
end

return GasterBlasters