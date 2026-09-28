-- DialogModule.lua
local DialogModule = {}
DialogModule.__index = DialogModule

local tweenService = game:GetService("TweenService")
local runService = game:GetService('RunService')
local userInputService = game:GetService('UserInputService')
local collectionService = game:GetService("CollectionService")

local TICK_SOUND = script.sounds.tick
local END_TICK_SOUND = script.sounds.tick2
local DIALOG_RESPONSES_UI = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Screen"):WaitForChild("master"):WaitForChild("dialog"):WaitForChild("dialogResponses")

--==================================================
-- ONE SHARED SET OF RESPONSE BUTTONS
--
-- Every NPC reuses the same nine buttons, so a dialog that
-- was never answered (you walked away, you died, you opened
-- another NPC) used to leave its click/keypress connections
-- attached to them forever. Those stale handlers swallowed
-- the next NPC's clicks and hid its buttons again -- which is
-- why a panel "sometimes" didn't open when you talked to
-- someone.
--
-- Now every triggerDialog gets a session id. Only the newest
-- session may answer, and opening a dialog disconnects
-- everything the previous one left behind.
--==================================================

local sessionCounter = 0
local liveConnections = {}

-- WATCHDOG: a conversation whose script stopped half-way (an error, a
-- server call that never came back, a quest step that ended it early)
-- used to leave every NPC prompt switched off and the NPC's name tag
-- hidden until you rejoined. If nothing has happened in any dialog for a
-- few seconds and none is waiting on you, everything is switched back on.
local lastActivity = os.clock()
local instances = setmetatable({}, { __mode = "k" })
local disabledByUs = {}
local function touch() lastActivity = os.clock() end

local function clearLiveConnections()
	for _, connection in ipairs(liveConnections) do
		pcall(function() connection:Disconnect() end)
	end
	table.clear(liveConnections)
end

-- Dying mid-conversation used to leave every NPC prompt switched off for
-- good (the dialog's exit never ran). A fresh body always gets them back.
do
	local lp = game.Players.LocalPlayer
	local function restorePrompts()
		clearLiveConnections()
		pcall(function() lp:SetAttribute("InDialog", nil) end)
		for _, prompt in collectionService:GetTagged("NPCprompt") do
			if prompt:IsA("ProximityPrompt") then prompt.Enabled = true end
		end
	end
	lp.CharacterAdded:Connect(function() task.defer(restorePrompts) end)
	local function hookDeath(ch)
		local hum = ch:WaitForChild("Humanoid", 10)
		if hum then hum.Died:Connect(restorePrompts) end
	end
	if lp.Character then task.spawn(hookDeath, lp.Character) end
	lp.CharacterAdded:Connect(hookDeath)
	task.defer(restorePrompts)
end

-- Constructor
function DialogModule.new(npcName, npc, prompt, animation)
	local self = setmetatable({}, DialogModule)
	self.npcName = npcName
	self.npc = npc
	self.dialogs = {} -- Array to store dialog options
	self.responses = {} -- Array to store response options
	self.dialogOption = 1
	self.npcGui = self.npc:WaitForChild("Head"):WaitForChild("gui")
	self.npcGui.AlwaysOnTop = true
	self.active = false
	self.talking = false
	self.prompt = prompt
	instances[self] = true
	
	DIALOG_RESPONSES_UI = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Screen"):WaitForChild("master"):WaitForChild("dialog"):WaitForChild("dialogResponses")

	
	local template = DIALOG_RESPONSES_UI:FindFirstChild("template")
	if template then
		for i = 1,9 do
			local newResponseButton = template:Clone()
			newResponseButton.Parent = DIALOG_RESPONSES_UI
			newResponseButton.Name = i
		end
		template:Destroy()
	end
	
	local eventSignal = Instance.new("BindableEvent")
	self.responded = eventSignal.Event -- Expose the event to connect to
	self.fireResponded = eventSignal -- Keep a reference to the BindableEvent
		
	-- tween variables
	self.animNameText = tweenService:Create(self.npcGui.name, TweenInfo.new(.3),{TextTransparency = 1})
	self.animNameStroke = tweenService:Create(self.npcGui.name.UIStroke, TweenInfo.new(.3),{Transparency = 1})
	self.animArrowText = tweenService:Create(self.npcGui.arrow, TweenInfo.new(.3),{TextTransparency = 1})
	self.animArrowStroke = tweenService:Create(self.npcGui.arrow.UIStroke, TweenInfo.new(.3),{Transparency = 1})
	self.animDialogText = tweenService:Create(self.npcGui.dialog, TweenInfo.new(.3),{TextTransparency = 1})
	self.animDialogStroke = tweenService:Create(self.npcGui.dialog.UIStroke, TweenInfo.new(.3),{Transparency = 1})
	
	-- animate
	if animation ~= nil then
		local newAnimation = Instance.new("Animation")
		newAnimation.AnimationId = animation
		local newAnimLoaded = npc:WaitForChild("Humanoid"):LoadAnimation(newAnimation)
		newAnimLoaded:Play()
	end
	
	-- Connections
	local frameCount = 0
	local heartbeatConnection = runService.Heartbeat:Connect(function()
		frameCount += 1
		if self.talking then
			self.npcGui.StudsOffset = Vector3.new(0,1.6,0)
		else
			self.npcGui.StudsOffset = Vector3.new(0,math.sin(frameCount/25)/6 + 1.55,0)
		end
	end)
	local shownConnection = prompt.PromptShown:Connect(function()
		self.npcGui.AlwaysOnTop = true
	end)
	local hiddenConnection = prompt.PromptHidden:Connect(function()
		-- (dialogue always draws through walls and the NPC's own mesh now)
		self.npcGui.AlwaysOnTop = true
	end)
	self.connections = {heartbeatConnection}--,shownConnection,hiddenConnection}
	
	return self
end

-- Add dialog to the NPC
function DialogModule:addDialog(dialogText, responseOptions)
	table.insert(self.dialogs, {text = dialogText, responses = responseOptions})
end

-- Sort dialogs alphabetically or by custom function
function DialogModule:sortDialogs(sortFunc)
	table.sort(self.dialogs, sortFunc or function(a, b) return a.text < b.text end)
end

-- Display the dialog when proximity prompt is triggered
function DialogModule:triggerDialog(player, questionNumber)
	self:showGui()

	-- take over the shared response buttons from whatever ran before
	sessionCounter += 1
	local sessionId = sessionCounter
	clearLiveConnections()

	if #self.dialogs == 0 then
		warn("No dialogs available for NPC: " .. self.npcName)
		return
	end

	local dialogNum = questionNumber or self.dialogOption
	local dialog = self.dialogs[dialogNum] -- Show the first dialog (can be updated for other logic)
	
	tweenService:Create(game.Workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 65}):Play()
	
	task.spawn(function()
		self.talking = true
		local dialogObject = self.npcGui.dialog
		dialogObject.Visible = true
		dialogObject.Text = ""
		local currenttext = ""
		local skip = false
		local arrow = 0
		for i, letter in string.split(dialog.text,"") do
			currenttext = currenttext .. letter
			if letter == "<" then skip = true end
			if letter == ">" then skip = false arrow += 1 continue end
			if arrow == 2 then arrow = 0 end
			if skip then continue end
			dialogObject.Text = currenttext .. if arrow == 1 then "</font>" else ""
			TICK_SOUND:Play()
			touch()
			task.wait(0.02)
		end
		dialogObject.Text = dialog.text
		self.talking = false

		-- inputs
		local keyboardInputs = {
			Enum.KeyCode.One,
			Enum.KeyCode.Two,
			Enum.KeyCode.Three,
			Enum.KeyCode.Four,
			Enum.KeyCode.Five,
			Enum.KeyCode.Six,
			Enum.KeyCode.Seven,
			Enum.KeyCode.Eight,
			Enum.KeyCode.Nine,
		}

		-- Show responses
		local currentScreen = player:WaitForChild("PlayerGui"):WaitForChild("Screen")
		DIALOG_RESPONSES_UI = currentScreen:WaitForChild("master"):WaitForChild("dialog"):WaitForChild("dialogResponses")
		local uiResponses = DIALOG_RESPONSES_UI

		-- NEW: Rebuild the response buttons if the player died and the UI reset
		if not uiResponses:FindFirstChild("1") then
			local template = uiResponses:FindFirstChild("template")
			if template then
				for j = 1, 9 do
					local newResponseButton = template:Clone()
					newResponseButton.Parent = uiResponses
					newResponseButton.Name = tostring(j)
				end
				template.Visible = false -- Hide the template instead of destroying it
			end
		end

		local responseNum = nil
		-- Live BEFORE the buttons appear: the old code only allowed answers
		-- after every button had finished its 0.2s reveal, so a quick click
		-- on the first option did nothing at all.
		self.active = true

		local function answer(i)
			if sessionId ~= sessionCounter then return end
			if not self.active then return end
			self.active = false
			responseNum = i
			self.fireResponded:Fire(i, dialogNum)
			TICK_SOUND:Play()
		end

		for i, response in ipairs(dialog.responses) do
			-- Safely find the option by its string name
			local option = uiResponses:FindFirstChild(tostring(i))
			if not option then continue end 

			option.text.Text = "<font color='rgb(255,220,127)'>" .. i .. ".)</font> [''" .. response .. "'']"

			-- calculate x size
			local plaintext = i..".) [''"..response:gsub("%b<>", "").."'']"
			
			option.Size = UDim2.fromScale(option.Size.X.Scale,.4)
			
			option.text.Position = UDim2.new(0.02,0,0.5,0)
			option.Visible = true
			tweenService:Create(option,TweenInfo.new(0.1,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size = UDim2.new(option.Size.X.Scale,0,0.35,0)}):Play()

			local enterCon = option.MouseEnter:Connect(function()
				tweenService:Create(option,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size = UDim2.new(option.Size.X.Scale + (option.Size.X.Scale * .05), 0,0.4,0)}):Play()
				tweenService:Create(option.text,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position = UDim2.new(0.06,0,0.5,0)}):Play()
				END_TICK_SOUND:Play()
			end)

			local leaveCon = option.MouseLeave:Connect(function()
				tweenService:Create(option,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size = UDim2.new(option.Size.X.Scale, 0,0.35,0)}):Play()
				tweenService:Create(option.text,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position = UDim2.new(0.02,0,0.5,0)}):Play()
			end)

			local chooseCon = option.MouseButton1Down:Connect(function() -- Return response
				answer(i)
			end)

			local numberpressCon = userInputService.InputBegan:Connect(function(input, gameprocessed)
				if gameprocessed then return end
				if input.UserInputType == Enum.UserInputType.Keyboard then
					local numberinput = table.find(keyboardInputs, input.KeyCode)
					if numberinput ~= nil and numberinput == i then
						answer(i)
					end
				end
			end)

			table.insert(liveConnections, enterCon)
			table.insert(liveConnections, leaveCon)
			table.insert(liveConnections, chooseCon)
			table.insert(liveConnections, numberpressCon)

			coroutine.wrap(function()
				-- also gives up if another dialog took over the buttons
				repeat task.wait() until responseNum ~= nil or sessionId ~= sessionCounter
				enterCon:Disconnect()
				leaveCon:Disconnect()
				chooseCon:Disconnect()
				numberpressCon:Disconnect()
				if sessionId == sessionCounter then
					option.Visible = false
				end
			end)()

			END_TICK_SOUND:Play()

			task.wait(0.2)
		end

		-- Walk-away distance. It used to be a flat 10 studs to the NPC's
		-- torso, the same as the prompt's reach -- so for an NPC you talk to
		-- from a bit further off (the Homeless Guy sits inside a dumpster)
		-- the dialogue opened and closed on the same frame.
		local range = math.max(16, (self.prompt and self.prompt.MaxActivationDistance or 10) + 8)
		while self.active and sessionId == sessionCounter do
			local character = player.Character
			local primaryPart = character and character.PrimaryPart
			local torso = self.npc.PrimaryPart or self.npc:FindFirstChild("Torso") or self.npc:FindFirstChild("HumanoidRootPart")

			-- If the player died or NPC is missing parts, safely close the dialog
			if not primaryPart or not torso then
				self:hideGui()
				responseNum = 0
				break
			end

			touch()
			local distance = (primaryPart.Position - torso.Position).Magnitude
			if distance > range then
				self:hideGui()
				responseNum = 0
				break
			end
			task.wait()
		end
	end)
end

-- your own overhead title/name tag sits between the camera and the NPC
-- and covers what they're saying -- hide it while a conversation is open
local function setOwnTagsHidden(hidden)
	-- PromptUI hides your own nameplate while this is set (so it can't cover
	-- the NPC's words), and brings it back afterwards
	pcall(function() game.Players.LocalPlayer:SetAttribute("InDialog", hidden and true or nil) end)
end

function DialogModule:showGui()
	touch()
	turnProximityPromptsOn(false)
	setOwnTagsHidden(true)
	--self.npcGui.AlwaysOnTop = true
	
	self.animNameText:Play()
	self.animNameStroke:Play()
	self.animArrowText:Play()
	self.animArrowStroke:Play()

	self.animDialogText:Cancel()
	self.animDialogStroke:Cancel()
	
	self.npcGui.dialog.TextTransparency = 0
	self.npcGui.dialog.UIStroke.Transparency = 0
	
	coroutine.wrap(function()
		task.wait(0.3)
		
		if self.npcGui.name.TextTransparency ~= 1 then return end -- check if already chose an opiton
		self.npcGui.name.Visible = false
		self.npcGui.arrow.Visible = false
	end)()
end

function DialogModule:hideGui(exitQuip, notActuallyAnExitQuip)
	touch()
	self.active = false
	self.talking = true
	notActuallyAnExitQuip = notActuallyAnExitQuip or false
	turnProximityPromptsOn(not notActuallyAnExitQuip)
	
	self.talking = false
	
	if notActuallyAnExitQuip then
		tweenService:Create(game.Workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 65}):Play()
	else
		tweenService:Create(game.Workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 70}):Play()
	end
	
	-- hide player response options
	local playerReponseOptions = DIALOG_RESPONSES_UI
	for i, option in playerReponseOptions:GetChildren() do
		if not option:IsA("GuiButton") then continue end
		option.Visible = false
	end
	
	local dialogObject = self.npcGui.dialog
	if exitQuip then
		dialogObject.TextTransparency = 0
		dialogObject.UIStroke.Transparency = 0
		self.npcGui.name.TextTransparency = 1
		self.npcGui.name.UIStroke.Transparency = 1
		self.npcGui.arrow.TextTransparency = 1
		self.npcGui.arrow.UIStroke.Transparency = 1
		local currenttext = ""
		dialogObject.Text = ""
		dialogObject.Visible = true
		local skip = false
		local arrow = 0
		for i, letter in string.split(exitQuip,"") do
			if dialogObject.Text ~= currenttext and skip == 0 then warn("other dialog happening") break end
			currenttext = currenttext .. letter
			if letter == "<" then skip = true end
			if letter == ">" then skip = false arrow += 1 continue end
			if arrow == 2 then arrow = 0 end
			if skip then continue end
			dialogObject.Text = currenttext .. if arrow == 1 then "</font>" else ""
			TICK_SOUND:Play()
			touch()
			task.wait(0.02)
		end
			
		dialogObject.Text = exitQuip
		if notActuallyAnExitQuip then return end
	end
	
	task.spawn(function()
		if exitQuip then
			wait(2)
			if dialogObject.Text ~= exitQuip then return end
		end

		if self.npcGui.name.TextTransparency ~= 1 then
			self.animNameText:Cancel()
			self.animNameStroke:Cancel()
			self.animArrowText:Cancel()
			self.animArrowStroke:Cancel()
		end
		self.npcGui.name.TextTransparency = 0
		self.npcGui.name.UIStroke.Transparency = 0
		self.npcGui.arrow.TextTransparency = 0
		self.npcGui.arrow.UIStroke.Transparency = 0
		self.npcGui.name.Visible = true
		self.npcGui.arrow.Visible = true

		self.animDialogText:Play()
		self.animDialogStroke:Play()
		--self.npcGui.AlwaysOnTop = false
		turnProximityPromptsOn(true)
		setOwnTagsHidden(false)
	end)
end

function DialogModule:nextOption()
	self.dialogOption += 1
	if #self.dialogs < self.dialogOption then warn("No next dialog option for, " .. self.npcName) self.dialogOption -= 1 end
	return self.dialogOption
end

function turnProximityPromptsOn(yes)
	for i, prompt in collectionService:GetTagged("NPCprompt") do
		if prompt:IsA("ProximityPrompt") then
			if yes then
				prompt.Enabled = true
				disabledByUs[prompt] = nil
			else
				if prompt.Enabled then disabledByUs[prompt] = true end
				prompt.Enabled = false
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		if os.clock() - lastActivity > 6 then
			local busy = false
			for inst in pairs(instances) do
				if inst.active or inst.talking then busy = true break end
			end
			if not busy then
				if next(disabledByUs) then
					for prompt in pairs(disabledByUs) do
						if prompt.Parent then prompt.Enabled = true end
					end
					table.clear(disabledByUs)
				end
				pcall(function()
					if game.Players.LocalPlayer:GetAttribute("InDialog") then game.Players.LocalPlayer:SetAttribute("InDialog", nil) end
				end)
				-- the NPC's name tag and arrow back on
				for inst in pairs(instances) do
					pcall(function()
						local g = inst.npcGui
						if g and g.Parent and (not g.name.Visible or g.name.TextTransparency > 0.5) and g.dialog.TextTransparency > 0.5 then
							g.name.Visible = true
							g.arrow.Visible = true
							g.name.TextTransparency = 0
							g.name.UIStroke.Transparency = 0
							g.arrow.TextTransparency = 0
							g.arrow.UIStroke.Transparency = 0
						end
					end)
				end
			end
		end
	end
end)

return DialogModule