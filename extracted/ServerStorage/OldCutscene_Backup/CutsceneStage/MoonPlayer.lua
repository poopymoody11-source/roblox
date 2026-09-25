--==================================================
-- MOON ANIMATOR 2 RUNTIME PLAYER
--
-- Moon Animator saves are editor data. The plugin can
-- preview them and can export a rig to an uploadable
-- Animation, but there is no built-in way to PLAY a
-- whole multi-item scene -- camera, props, particles
-- and rigs together -- at runtime. This reads the save
-- format directly and does that.
--
-- THE FORMAT (reverse engineered from these two saves)
--
-- The StringValue holds JSON:
--   Information = { Length (frames), Looped, ... }
--   Items       = array of { Path = { InstanceNames,
--                                     InstanceTypes,
--                                     ItemType } }
--
-- The numbered Folder children line up INDEX-WISE with
-- that Items array: folder "3" is Items[3].
--
-- A non-rig item's folder holds one folder per animated
-- property (CFrame, Transparency, FieldOfView, ...),
-- each containing:
--     default            the value before any keyframe
--     <frameNumber>/Values/0   the keyed value
--
-- A rig item's folder holds a "Rig" folder of "_joint"
-- folders, each with:
--     _hier       "Torso.Head" -- Part0.Part1 of the Motor6D
--     default     base value
--     _keyframes/<frameNumber>/Values/0
--
-- Joints animate C1, NOT C0. That was confirmed by
-- comparing every saved `default` against the live
-- Motor6Ds on TemplateR6: all six matched C1 exactly
-- and none matched C0. Writing these to C0 would fold
-- the character inside out.
--
-- There is no easing data anywhere in the file, so
-- Moon Animator's default (linear) is what was authored
-- and what this reproduces. CONFIG.Smoothing can ease
-- the whole scene if you want it softer.
--==================================================

local RunService = game:GetService("RunService")

local MoonPlayer = {}
MoonPlayer.__index = MoonPlayer

-- Moon Animator authors at 60 frames per second.
local FPS = 60

local CONFIG = {
	-- "linear" reproduces the plugin preview exactly.
	-- "smooth" eases every segment; nicer on slow camera
	-- moves, but it will soften deliberate snaps.
	Smoothing = "linear",
}

--==================================================
-- INTERPOLATION
--==================================================

local function ease(alpha)
	if CONFIG.Smoothing == "smooth" then
		return alpha * alpha * (3 - 2 * alpha)
	end
	return alpha
end

local function lerpValue(a, b, alpha)
	local t = typeof(a)

	if t == "CFrame" then
		return a:Lerp(b, alpha)
	elseif t == "number" then
		return a + (b - a) * alpha
	elseif t == "Color3" then
		return a:Lerp(b, alpha)
	elseif t == "Vector3" then
		return a:Lerp(b, alpha)
	elseif t == "table" then
		-- a keypoint map from a sequence track: blend each keypoint
		-- the animation touches, independently
		local out = {}
		for index, from in pairs(a) do
			local to = b[index]
			if to == nil then
				out[index] = from
			else
				out[index] = lerpValue(from, to, alpha)
			end
		end
		for index, to in pairs(b) do
			if out[index] == nil then out[index] = to end
		end
		return out
	end

	-- booleans and anything else step rather than blend
	return a
end

--==================================================
-- READING THE SAVE
--==================================================

--==================================================
-- SEQUENCE TRACKS
--
-- ParticleEmitter.Transparency, .Size and .Color aren't
-- plain numbers -- they're NumberSequence / ColorSequence
-- curves. Moon Animator doesn't replace the whole curve;
-- it animates ONE KEYPOINT of it, and records which one:
--
--     Transparency/
--       default <NumberValue> = 1
--         NumberSequence <IntValue> = 0     <- keypoint index
--       577/Values/
--         NumberSequence <IntValue> = 0
--         0 <NumberValue> = 1               <- value for keypoint 0
--       578/Values/
--         NumberSequence <IntValue> = 0
--         0 <NumberValue> = 0
--
-- That example is the hand VFX turning on: keypoint 0's
-- transparency goes 1 -> 0 over a single frame, so the
-- particles snap from invisible to visible.
--
-- Assigning the raw number straight to the property (as
-- this did at first) throws "can't assign number to
-- NumberSequence", and because the assignment is wrapped
-- in pcall it fails silently -- the emitters simply never
-- appeared, with nothing in the output to say why.
--==================================================

local function sequenceKindOf(container)
	if container:FindFirstChild("NumberSequence") then return "NumberSequence" end
	if container:FindFirstChild("ColorSequence") then return "ColorSequence" end
	return nil
end

-- Returns { [keypointIndex] = value }.
local function readSequenceValues(container, kind)
	local map = {}

	if container:IsA("Folder") then
		-- a keyframe's Values folder: numbered children are keypoints
		for _, child in ipairs(container:GetChildren()) do
			local index = tonumber(child.Name)
			if index then
				local ok, value = pcall(function() return child.Value end)
				if ok then map[index] = value end
			end
		end
	else
		-- `default` carries the value itself; its marker child says
		-- which keypoint that value belongs to
		local marker = container:FindFirstChild(kind)
		local index = marker and marker.Value or 0
		local ok, value = pcall(function() return container.Value end)
		if ok then map[index] = value end
	end

	return map
end

-- A keyframe folder is named after its frame number and
-- wraps the real value two levels down.
local function readKeyframeValue(frameFolder, sequenceKind)
	local values = frameFolder:FindFirstChild("Values")
	if not values then return nil end

	if sequenceKind then
		return readSequenceValues(values, sequenceKind)
	end

	local holder = values:FindFirstChild("0") or values:GetChildren()[1]
	if not holder then return nil end

	local ok, value = pcall(function() return holder.Value end)
	if not ok then return nil end

	return value
end

-- Turns a track folder into a frame-sorted keyframe list.
local function readKeyframes(container, sequenceKind)
	local keyframes = {}

	for _, child in ipairs(container:GetChildren()) do
		local frame = tonumber(child.Name)
		if frame and child:IsA("Folder") then
			local value = readKeyframeValue(child, sequenceKind)
			if value ~= nil then
				table.insert(keyframes, { Frame = frame, Value = value })
			end
		end
	end

	table.sort(keyframes, function(a, b) return a.Frame < b.Frame end)
	return keyframes
end

local function readDefault(container, sequenceKind)
	local default = container:FindFirstChild("default")
	if not default then return nil end

	if sequenceKind then
		return readSequenceValues(default, sequenceKind)
	end

	local ok, value = pcall(function() return default.Value end)
	if not ok then return nil end

	return value
end

-- Works out whether a track drives a sequence, by looking for the
-- marker on the default or on any keyframe.
local function detectSequenceKind(trackFolder)
	local default = trackFolder:FindFirstChild("default")
	if default then
		local kind = sequenceKindOf(default)
		if kind then return kind end
	end

	for _, child in ipairs(trackFolder:GetChildren()) do
		if tonumber(child.Name) then
			local values = child:FindFirstChild("Values")
			if values then
				local kind = sequenceKindOf(values)
				if kind then return kind end
			end
		end
	end

	return nil
end

-- Writes a keypoint map onto a live sequence property, leaving every
-- keypoint the animation doesn't mention exactly as authored.
local function applySequence(target, property, kind, valueMap)
	local ok, current = pcall(function() return target[property] end)
	if not ok or current == nil then return end

	local points = current.Keypoints
	local rebuilt = {}

	for index, keypoint in ipairs(points) do
		-- Moon Animator counts keypoints from 0; Luau arrays from 1.
		local override = valueMap[index - 1]
		local value = override ~= nil and override or keypoint.Value

		if kind == "NumberSequence" then
			rebuilt[index] = NumberSequenceKeypoint.new(keypoint.Time, value, keypoint.Envelope)
		else
			rebuilt[index] = ColorSequenceKeypoint.new(keypoint.Time, value)
		end
	end

	pcall(function()
		if kind == "NumberSequence" then
			target[property] = NumberSequence.new(rebuilt)
		else
			target[property] = ColorSequence.new(rebuilt)
		end
	end)
end

--==================================================
-- RESOLVING WHAT A TRACK POINTS AT
--
-- Paths in the save are absolute (game.Workspace.X.Y),
-- but at runtime everything lives in a per-player clone.
-- So the FIRST meaningful name is looked up in the
-- caller's stage map and the rest of the path is walked
-- from there.
--==================================================

local function resolveInstance(path, stage)
	local names = path.InstanceNames
	if not names or #names == 0 then return nil end

	local last = names[#names]

	-- The camera is never cloned -- it's the real one.
	if last == "CurrentCamera" or path.ItemType == "Camera" then
		return workspace.CurrentCamera
	end

	-- names is like { "game", "Workspace", "Explosion023", "Hit", "2" }.
	-- Find the first segment the stage knows about, then walk down.
	for index = 1, #names do
		local root = stage[names[index]]
		if root then
			local current = root
			for deeper = index + 1, #names do
				current = current and current:FindFirstChild(names[deeper])
			end
			return current
		end
	end

	return nil
end

-- "Torso.Head" means the Motor6D joining Torso to Head.
-- The last segment is Part1's name, which is unique per rig,
-- so that alone identifies the joint -- and it survives the
-- joint itself being called something unrelated (the Torso
-- to Head joint is named "Neck").
local function resolveJoint(model, hier)
	local targetName = hier:match("([^%.]+)$")
	if not targetName then return nil end

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 and d.Part1.Name == targetName then
			return d
		end
	end

	return nil
end

--==================================================
-- BUILDING TRACKS
--==================================================

local function buildRigTracks(tracks, rigFolder, model)
	for _, joint in ipairs(rigFolder:GetChildren()) do
		if joint.Name == "_joint" then
			local hier = joint:FindFirstChild("_hier")
			local keyframeFolder = joint:FindFirstChild("_keyframes")

			if hier and keyframeFolder then
				local motor = resolveJoint(model, hier.Value)

				if motor then
					table.insert(tracks, {
						Kind = "Joint",
						Target = motor,
						Property = "C1",
						Default = readDefault(joint, nil),
						Keyframes = readKeyframes(keyframeFolder, nil),
						Label = hier.Value,
					})
				end
			end
		end
	end
end

-- Which instance property each Moon Animator track name maps to.
-- Emit is not a property at all -- it's a one-shot burst.
local PROPERTY_TRACKS = {
	CFrame = "CFrame",
	Transparency = "Transparency",
	Color = "Color",
	Size = "Size",
	Enabled = "Enabled",
	FieldOfView = "FieldOfView",
}

local function buildPropertyTracks(tracks, itemFolder, target, itemType)
	for _, trackFolder in ipairs(itemFolder:GetChildren()) do
		local name = trackFolder.Name

		if name == "Rig" or name == "MarkerTrack" then
			continue
		end

		local sequenceKind = detectSequenceKind(trackFolder)
		local keyframes = readKeyframes(trackFolder, sequenceKind)
		local default = readDefault(trackFolder, sequenceKind)

		if name == "Emit" then
			table.insert(tracks, {
				Kind = "Emit",
				Target = target,
				Keyframes = keyframes,
				Default = default,
				Label = "Emit",
			})
			continue
		end

		local property = PROPERTY_TRACKS[name]
		if not property then continue end

		if sequenceKind then
			table.insert(tracks, {
				Kind = "Sequence",
				SequenceKind = sequenceKind,
				Target = target,
				Property = property,
				Default = default,
				Keyframes = keyframes,
				Label = name,
			})
			continue
		end

		-- A Rig item with a CFrame track is the whole model moving,
		-- which has to go through PivotTo -- assigning .CFrame to a
		-- Model does nothing.
		local kind = "Property"
		if property == "CFrame" and target:IsA("Model") then
			kind = "Pivot"
		end

		table.insert(tracks, {
			Kind = kind,
			Target = target,
			Property = property,
			Default = default,
			Keyframes = keyframes,
			Label = name,
		})
	end
end

--==================================================
-- CONSTRUCTION
--
-- stage maps a name in the save's path to the live
-- instance standing in for it, e.g.
--     { ["TemplateR6"] = <the player's clone>, ... }
--==================================================

function MoonPlayer.new(saveValue, stage)
	local HttpService = game:GetService("HttpService")

	local ok, data = pcall(function()
		return HttpService:JSONDecode(saveValue.Value)
	end)

	if not ok or type(data) ~= "table" then
		return nil, "couldn't decode the save: " .. tostring(data)
	end

	local self = setmetatable({}, MoonPlayer)

	self.Name = saveValue.Name
	self.LengthFrames = (data.Information and data.Information.Length) or 0
	self.Looped = (data.Information and data.Information.Looped) == true
	self.Length = self.LengthFrames / FPS
	self.Tracks = {}
	self.Missing = {}

	for index, item in ipairs(data.Items or {}) do
		local itemFolder = saveValue:FindFirstChild(tostring(index))
		local path = item.Path

		if itemFolder and path then
			local target = resolveInstance(path, stage)

			if not target then
				table.insert(self.Missing, table.concat(path.InstanceNames or {}, "."))
			else
				local rigFolder = itemFolder:FindFirstChild("Rig")
				if rigFolder then
					buildRigTracks(self.Tracks, rigFolder, target)
				end
				buildPropertyTracks(self.Tracks, itemFolder, target, path.ItemType)
			end
		end
	end

	-- Real end of the scene. Both of these saves declare a Length
	-- well past their last keyframe (720 frames declared, 401 used),
	-- and playing out the difference is just dead air.
	local last = 0
	for _, track in ipairs(self.Tracks) do
		local keyframes = track.Keyframes
		if #keyframes > 0 then
			last = math.max(last, keyframes[#keyframes].Frame)
		end
	end
	self.LastKeyframe = last
	self.ContentLength = last / FPS

	return self
end

--==================================================
-- SAMPLING
--==================================================

local function sample(track, frame)
	local keyframes = track.Keyframes
	local count = #keyframes

	if count == 0 then
		return track.Default
	end

	if frame <= keyframes[1].Frame then
		-- Before the first key, hold the recorded base state rather
		-- than snapping to the first key -- that's what the plugin
		-- shows on frame 0.
		return track.Default ~= nil and track.Default or keyframes[1].Value
	end

	if frame >= keyframes[count].Frame then
		return keyframes[count].Value
	end

	for index = 1, count - 1 do
		local a = keyframes[index]
		local b = keyframes[index + 1]

		if frame >= a.Frame and frame <= b.Frame then
			local span = b.Frame - a.Frame
			if span <= 0 then return b.Value end

			return lerpValue(a.Value, b.Value, ease((frame - a.Frame) / span))
		end
	end

	return keyframes[count].Value
end

local function applyTrack(track, frame, previousFrame)
	if track.Kind == "Emit" then
		-- A burst fires once, as the playhead crosses its frame.
		for _, keyframe in ipairs(track.Keyframes) do
			if keyframe.Frame > previousFrame and keyframe.Frame <= frame then
				pcall(function()
					track.Target:Emit(math.floor(tonumber(keyframe.Value) or 0))
				end)
			end
		end
		return
	end

	local value = sample(track, frame)
	if value == nil then return end

	if track.Kind == "Joint" then
		track.Target.C1 = value
	elseif track.Kind == "Pivot" then
		track.Target:PivotTo(value)
	elseif track.Kind == "Sequence" then
		applySequence(track.Target, track.Property, track.SequenceKind, value)
	else
		pcall(function()
			track.Target[track.Property] = value
		end)
	end
end

-- Puts every track on a given frame. Used to prime the scene
-- before the first render so nothing pops.
function MoonPlayer:Seek(frame)
	for _, track in ipairs(self.Tracks) do
		applyTrack(track, frame, frame)
	end
end

--==================================================
-- PLAYBACK
--
-- onFrame(frame, seconds) fires every render step, which
-- is how the sound and polish layers stay in sync with
-- the animation rather than running off their own clock.
--==================================================

function MoonPlayer:Play(options)
	options = options or {}

	local stopAt = options.PlayToDeclaredLength
		and self.LengthFrames
		or self.LastKeyframe

	self:Seek(0)

	local previousFrame = -1
	local elapsed = 0
	local finished = false

	-- Optional time warp: { {From = frame, To = frame, Speed = 0.5}, ... }
	-- Inside a section the playhead advances at Speed x real time, so a
	-- stretch of the animation can be lengthened (slow, dreamy) without
	-- re-keying it in Moon Animator. Cues are frame-based, so they stay
	-- locked to the picture.
	local warp = options.TimeWarp
	local function speedAt(f)
		if warp then
			for _, section in ipairs(warp) do
				if f >= section.From and f < section.To then
					-- ease in/out of the section over 20 frames so it never lurches
					local edge = math.min(f - section.From, section.To - f)
					local k = math.clamp(edge / 20, 0, 1)
					return 1 + (section.Speed - 1) * k
				end
			end
		end
		return 1
	end
	local playhead = 0

	local connection
	connection = RunService.RenderStepped:Connect(function(delta)
		if self.Stopped then return end

		elapsed = elapsed + delta
		playhead = playhead + delta * FPS * speedAt(playhead)
		local frame = playhead

		if frame >= stopAt then
			frame = stopAt
		end

		for _, track in ipairs(self.Tracks) do
			applyTrack(track, frame, previousFrame)
		end

		if options.OnFrame then
			options.OnFrame(frame, elapsed)
		end

		previousFrame = frame

		if frame >= stopAt and not finished then
			finished = true
			connection:Disconnect()
			if options.OnFinished then
				task.spawn(options.OnFinished)
			end
		end
	end)

	self.Connection = connection
	return connection
end

function MoonPlayer:Stop()
	self.Stopped = true
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

--==================================================
-- WHERE THIS SCENE HAPPENS
--
-- Every world position the scene visits: camera
-- keyframes, prop moves, model pivots. The director
-- uses these to pull the map in around the shot before
-- rolling, because with StreamingEnabled the client
-- only loads terrain and parts near the PLAYER -- and
-- during a cutscene the player is stood still while the
-- camera is thousands of studs away.
--
-- Points closer together than `spacing` collapse into
-- one: there's no sense making eight streaming requests
-- for eight keyframes of the same slow push-in.
--==================================================

function MoonPlayer:GetFocusPoints(spacing)
	spacing = spacing or 120

	local points = {}

	local function add(position)
		for _, existing in ipairs(points) do
			if (existing - position).Magnitude < spacing then
				return
			end
		end
		table.insert(points, position)
	end

	for _, track in ipairs(self.Tracks) do
		local isPositional = track.Kind == "Pivot"
			or (track.Kind == "Property" and track.Property == "CFrame")

		if isPositional then
			if typeof(track.Default) == "CFrame" then
				add(track.Default.Position)
			end
			for _, keyframe in ipairs(track.Keyframes) do
				if typeof(keyframe.Value) == "CFrame" then
					add(keyframe.Value.Position)
				end
			end
		end
	end

	-- The rigs don't have CFrame tracks -- they animate in place --
	-- so their own positions have to go in separately or the shot
	-- they're standing in never streams.
	for _, track in ipairs(self.Tracks) do
		if track.Kind == "Joint" and track.Target and track.Target.Part0 then
			add(track.Target.Part0.Position)
			break
		end
	end

	return points
end

MoonPlayer.CONFIG = CONFIG
MoonPlayer.FPS = FPS

return MoonPlayer
