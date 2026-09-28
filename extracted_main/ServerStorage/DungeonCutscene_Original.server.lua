local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local Debris = game:GetService("Debris") -- NEW: Added Debris service

local Lighting = game:GetService("Lighting")
local white = Lighting:WaitForChild("whiteframe")
local purple = Lighting:WaitForChild("purpleframe")
local black = Lighting:WaitForChild("blackframe")

local Dungeon = workspace:WaitForChild("Dungeon")
local Cutscene = Dungeon:WaitForChild("Cutscene")
local speedy = Cutscene:WaitForChild("IShowSpeed")
local torso = speedy:WaitForChild("LowerTorso")
local humanoid = speedy:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

local npcs = Cutscene:WaitForChild("NPCs")
local BEAM = Cutscene:WaitForChild("UltimateBeam")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local projectileAsset = ReplicatedStorage:WaitForChild("Purple")

local triggerPart = script.Parent
local cutsceneCamPart = Cutscene:WaitForChild("CutsceneCameraPart")
local cutsceneCamPart2 = Cutscene:WaitForChild("CutsceneCameraPart2")
local goodcutsceneCamPart = Cutscene:WaitForChild("GoodCutscenePart")
local goodCutsceneCamPart2 = Cutscene:WaitForChild("GoodCutscenePart2")
local goodCutsceneCamPart3 = Cutscene:WaitForChild("GoodCutscenePart3")
local camera = workspace.CurrentCamera

local characterLocation = Cutscene:WaitForChild("CharacterLocation")
--local character = localPlayer:WaitForChild("Character")
--local characterRoot = character:WaitForChild("HumanoidRootPart")

local hasPlayed = false

local holdAnim = Instance.new("Animation")
holdAnim.AnimationId = "rbxassetid://139209711419916"
local holdTrack = animator:LoadAnimation(holdAnim)
local gettinghitAnim = Instance.new("Animation")
gettinghitAnim.AnimationId = "rbxassetid://97968542662768"
local gettinghitTrack = animator:LoadAnimation(gettinghitAnim)

local playerStats = localPlayer:WaitForChild("PlayerStats")
local claimedQuests = playerStats:WaitForChild("ClaimedQuests")


local LETTER_DELAY = 0.05
local function typeOut(label, fullText, delay)
	label.Text = ""
	for i = 1, #fullText do
		label.Text = string.sub(fullText, 1, i)
		task.wait(delay)
	end
end



triggerPart.Touched:Connect(function(hit)
	if hasPlayed then return end
	print("triggerede")
	local character = hit.Parent
	
	local hitPlayer = Players:GetPlayerFromCharacter(character)
	local characterRoot = character:WaitForChild("HumanoidRootPart")
	
	local GUI = hitPlayer.PlayerGui
	local Screen = GUI:WaitForChild("ScreenGui")
	local SpeakFrame = Screen:WaitForChild("BossSpeakFrame")
	local speakText = SpeakFrame:WaitForChild("BossSpeak")
	
	print("triggered")
	if hitPlayer == localPlayer then
		if claimedQuests:FindFirstChild("TungQuest") and claimedQuests:FindFirstChild("HomelessQuest") and claimedQuests:FindFirstChild("VerityQuest3") and claimedQuests:FindFirstChild("ToiletQuest") and claimedQuests:FindFirstChild("CarKeyQuest") and playerStats:FindFirstChild("cangoin") and playerStats.cangoin.Value == true then 
			print("All quests completed")
			hasPlayed = true 

			camera.CameraType = Enum.CameraType.Scriptable

			local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
			local tween = TweenService:Create(camera, tweenInfo, {CFrame = cutsceneCamPart.CFrame})
			tween:Play()
			
			characterRoot.CFrame = characterLocation.CFrame
			characterRoot.Anchored = true
			tween.Completed:Wait()
			speakText.Parent.Visible = true
			typeOut(speakText, "EVIL SPEED: You shouldn't be here.", LETTER_DELAY)
			task.wait(3)
			typeOut(speakText, "", LETTER_DELAY)
			speakText.Parent.Visible = false
			
			
			holdTrack:Play()
			task.wait(0.5)
			local hand = speedy.RightHand

			for i, item in pairs(hand:GetDescendants()) do
				if item:IsA("ParticleEmitter") then
					item.Enabled = true
					item:Emit(5)
				end
			end

			task.wait(3)

			local rootPart = speedy:WaitForChild("HumanoidRootPart")

			local projectile = projectileAsset:Clone()
			projectile:PivotTo(hand.CFrame) 
			projectile.Parent = workspace

			local aimCFrame = rootPart.CFrame * CFrame.Angles(math.rad(-15), 0, 0)
			local shootDirection = aimCFrame.LookVector
			local shootVelocity = shootDirection * 50 

			-- Find a part in the model to attach the engine to
			local mainPart = projectile.PrimaryPart or projectile:FindFirstChildWhichIsA("BasePart", true)

			if mainPart then
				-- Create an attachment point
				local attachment = Instance.new("Attachment")
				attachment.Parent = mainPart

				-- Apply LinearVelocity to constantly push it forward, ignoring gravity
				local linearVel = Instance.new("LinearVelocity")
				linearVel.Attachment0 = attachment
				linearVel.MaxForce = math.huge -- Infinite strength to fight gravity
				linearVel.VectorVelocity = shootVelocity
				linearVel.Parent = mainPart
			end

			-- Unanchor everything so it can fly
			for _, part in projectile:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = false
				end
			end





			white.Enabled = true
			task.wait(0.1)
			purple.Enabled = true
			white.Enabled = false

			for i, item in pairs(hand:GetDescendants()) do
				if item:IsA("ParticleEmitter") then
					item.Enabled = false
				end
				if item:IsA("Sound") then
					item:Play()
				end
			end

			task.wait(0.03)
			purple.Enabled = false
			black.Enabled = true

			task.wait(0.05)
			black.Enabled = false





			


			
			

			
			-- ==========================================

			tween = TweenService:Create(camera, tweenInfo, {CFrame = goodcutsceneCamPart.CFrame})
			tween:Play()
			task.delay(0.4, function()
				for _, part in projectile:GetDescendants() do
					if part:IsA("BasePart") then
						part.Anchored = true
					end
				end
			end)

			
			tween.Completed:Wait()
			

			
			
			-- 1. Set up the drop positions
			local startCFrame = npcs:GetPivot()
			local endCFrame = startCFrame * CFrame.new(0, -38, 0)

			-- 2. Create a temporary CFrameValue to tween
			local cframeValue = Instance.new("CFrameValue")
			cframeValue.Value = startCFrame

			-- Constantly update the model's position as the tween plays
			cframeValue.Changed:Connect(function(newValue)
				if npcs.Parent then
					npcs:PivotTo(newValue)
				end
			end)

			-- 3. Create the fast, smooth drop tween (0.4 seconds, Cubic Out)
			local dropInfo = TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
			local dropTween = TweenService:Create(cframeValue, dropInfo, {Value = endCFrame})

			LETTER_DELAY = 0.025
			speakText.Parent.Visible = true
			speakText.TextColor3 = Color3.fromRGB(255, 255, 0)
			speakText.Font = Enum.Font.FredokaOne
			typeOut(speakText, "Not on my watch.", LETTER_DELAY)


			local soundtrack = Instance.new("Sound")
			soundtrack.Name = "Land"
			soundtrack.SoundId = "rbxassetid://72728975467251"
			soundtrack.Volume = 1
			soundtrack.Looped = false
			soundtrack.Parent = Screen
			soundtrack:Play()
			
			dropTween:Play()
			

			
			dropTween.Completed:Wait() -- Wait for the model to land
			local soundtrack = Instance.new("Sound")
			soundtrack.Name = "Arrival"
			soundtrack.SoundId = "rbxassetid://125367748123159"
			soundtrack.Volume = 1
			soundtrack.Looped = false
			soundtrack.Parent = Screen
			soundtrack:Play()
			
			
			typeOut(speakText, "", LETTER_DELAY)
			speakText.Parent.Visible = false
			cframeValue:Destroy() -- Clean up the temporary value

			-- ==========================================
			-- 4. MINOR SCREEN SHAKE
			-- ==========================================
			local shakeDuration = 0.3 -- How long the shake lasts
			local shakeIntensity = 0.5 -- How aggressive the shake is
			local originalCamCFrame = camera.CFrame

			local startTime = tick()
			while tick() - startTime < shakeDuration do
				-- Generate small random offsets
				local offsetX = (math.random() - 0.5) * shakeIntensity
				local offsetY = (math.random() - 0.5) * shakeIntensity

				-- Apply the offset to the camera
				camera.CFrame = originalCamCFrame * CFrame.new(offsetX, offsetY, 0)
				task.wait()
			end


			tween = TweenService:Create(camera, tweenInfo, {CFrame = goodCutsceneCamPart2.CFrame})
			tween:Play()
			tween.Completed:Wait()



			-- MAKE BEAM MODEL APPEAR HERE AND DOUBLE THE SIZE
			for _, item in ipairs(BEAM:GetDescendants()) do
				if item:IsA("Beam") then
					item.Enabled = true

					-- Only double it if we haven't tagged it as doubled yet
					if not item:GetAttribute("HasDoubled") then
						item.Width0 = item.Width0 * 5
						item.Width1 = item.Width1 * 5
						item:SetAttribute("HasDoubled", true)
					end

				elseif item:IsA("ParticleEmitter") then
					item.Enabled = true
				elseif item:IsA("PointLight") then
					item.Enabled = true
				end
			end
			local soundtrack = Instance.new("Sound")
			soundtrack.Name = "Beam"
			soundtrack.SoundId = "rbxassetid://86261914368076"
			soundtrack.Volume = 1
			soundtrack.Looped = false
			soundtrack.Parent = Screen
			soundtrack:Play()
			projectile:Destroy()
			
			gettinghitTrack:Play()
			task.wait(0.5)
			LETTER_DELAY = 0.05
			speakText.Parent.Visible = true
			speakText.TextColor3 = Color3.fromRGB(255, 0, 0)
			speakText.Font = Enum.Font.Creepster
			typeOut(speakText, "NOOOOOOOOOOOOO!", LETTER_DELAY)
			task.wait(1)
			typeOut(speakText, "", LETTER_DELAY)
			speakText.Parent.Visible = false
			task.wait(1)
			
			camera.CFrame = goodCutsceneCamPart3.CFrame
			
			task.wait(1)
			-- kill speedy

			humanoid.Health = 0
			humanoid:ChangeState(Enum.HumanoidStateType.Dead)
			

			for _, descendant in ipairs(speedy:GetDescendants()) do
				if descendant:IsA("Motor6D") or descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
					descendant:Destroy()
				end
			end
			for _, part in ipairs(speedy:GetDescendants()) do
				if part.Name == "FullBodyOutlineAura" then
					part:Destroy()
				elseif part:IsA("BasePart") then -- Covers MeshParts, BaseParts, and Unions
					part.Anchored = false
					part.CanCollide = true -- Ensures pieces land on the floor

					-- Remove HumanoidRootPart so it doesn't interfere with physics
					if part.Name == "HumanoidRootPart" then
						part:Destroy()
						--part.Anchored = false
					else
						-- Add a physics force to pop the mesh pieces apart
						local scatterForce = Vector3.new(
							math.random(-25, 25),
							math.random(10, 35),
							math.random(-25, 25)
						)
						part:ApplyImpulse(scatterForce * part:GetMass())
					end
				end
			end
			
			gettinghitTrack:Stop()
			local soundtrack = Instance.new("Sound")
			soundtrack.Name = "Boom"
			soundtrack.SoundId = "rbxassetid://139557908315922"
			soundtrack.Volume = 1
			soundtrack.Looped = false
			soundtrack.Parent = Screen
			soundtrack:Play()
	
			-- Break all joints so limbs become unanchored physics objects
			task.wait(0.3)

			for _, item in ipairs(BEAM:GetDescendants()) do
				if item:IsA("Beam") then
					item.Enabled = false
				elseif item:IsA("PointLight") then
					item.Enabled = false

				elseif item:IsA("ParticleEmitter") then
					item.Enabled = false
				end
			end

			-- Snap the camera perfectly back into place when finished
			task.wait(1.5)
			camera.CFrame = originalCamCFrame
			
			-- Give camera control back to the player
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = character:WaitForChild("Humanoid")
			
			
			
			
			characterRoot.Anchored = false
			task.wait(1)
			-- MAKE END UI HERE
			local playerGui = localPlayer:WaitForChild("PlayerGui")

			local endGui = Instance.new("ScreenGui")
			endGui.Name = "EndCutsceneUI"
			endGui.IgnoreGuiInset = true -- cover the whole screen, including the top bar
			endGui.ResetOnSpawn = false
			endGui.DisplayOrder = 100
			endGui.Parent = playerGui

			local blackScreen = Instance.new("Frame")
			blackScreen.Size = UDim2.fromScale(1, 1)
			blackScreen.BackgroundColor3 = Color3.new(0, 0, 0)
			blackScreen.BackgroundTransparency = 1
			blackScreen.BorderSizePixel = 0
			blackScreen.Parent = endGui

			local helloLabel = Instance.new("TextLabel")
			helloLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			helloLabel.Position = UDim2.fromScale(0.5, 0.5)
			helloLabel.Size = UDim2.fromScale(0.8, 0.3)
			helloLabel.BackgroundTransparency = 1
			helloLabel.Text = "The Real Lapeace is the Friends We Made Along The Way"
			helloLabel.TextColor3 = Color3.new(1, 1, 1)
			helloLabel.Font = Enum.Font.GothamBlack
			helloLabel.TextScaled = true
			helloLabel.TextTransparency = 1
			helloLabel.Parent = blackScreen

			-- Fade the black screen in, then the text
			local fadeInInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			local bgTween = TweenService:Create(blackScreen, fadeInInfo, {BackgroundTransparency = 0})
			bgTween:Play()
			local soundtrack = Instance.new("Sound")
			soundtrack.Name = "EndSoundtrack"
			soundtrack.SoundId = "rbxassetid://1846088038"
			soundtrack.Volume = 0.5
			soundtrack.Looped = false
			soundtrack.Parent = endGui
			soundtrack:Play()
			bgTween.Completed:Wait()

			local textTween = TweenService:Create(helloLabel, fadeInInfo, {TextTransparency = 0})
			textTween:Play()
			textTween.Completed:Wait()

			-- Hold for 5 seconds
			task.wait(10)

			-- Fade everything out, then remove it
			local fadeOutInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(blackScreen, fadeOutInfo, {BackgroundTransparency = 1}):Play()
			local textOut = TweenService:Create(helloLabel, fadeOutInfo, {TextTransparency = 1})
			textOut:Play()
			textOut.Completed:Wait()


			local musicOut = TweenService:Create(soundtrack, fadeOutInfo, {Volume = 0})
			musicOut:Play()
			
			endGui:Destroy()
			
			
			--hasPlayed = false
		else

			hasPlayed = true 
			
			camera.CameraType = Enum.CameraType.Scriptable
			
			local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
			local tween = TweenService:Create(camera, tweenInfo, {CFrame = cutsceneCamPart.CFrame})
			tween:Play()
			character.Humanoid.WalkSpeed = 0
			characterRoot.CFrame = characterLocation.CFrame
			tween.Completed:Wait()
			speakText.Parent.Visible = true
			typeOut(speakText, "EVIL SPEED: You shouldn't be here.", LETTER_DELAY)
			task.wait(3)
			typeOut(speakText, "", LETTER_DELAY)
			speakText.Parent.Visible = false
			
			
			holdTrack:Play()
			task.wait(0.5)
			local hand = speedy.RightHand

			for i, item in pairs(hand:GetDescendants()) do
				if item:IsA("ParticleEmitter") then
					item.Enabled = true
					item:Emit(5)
				end
			end

			task.wait(3)

			local rootPart = speedy:WaitForChild("HumanoidRootPart")

			local projectile = projectileAsset:Clone()
			projectile:PivotTo(hand.CFrame) 
			projectile.Parent = workspace

			local aimCFrame = rootPart.CFrame * CFrame.Angles(math.rad(-15), 0, 0)
			local shootDirection = aimCFrame.LookVector
			local shootVelocity = shootDirection * 50 

			-- Find a part in the model to attach the engine to
			local mainPart = projectile.PrimaryPart or projectile:FindFirstChildWhichIsA("BasePart", true)

			if mainPart then
				-- Create an attachment point
				local attachment = Instance.new("Attachment")
				attachment.Parent = mainPart

				-- Apply LinearVelocity to constantly push it forward, ignoring gravity
				local linearVel = Instance.new("LinearVelocity")
				linearVel.Attachment0 = attachment
				linearVel.MaxForce = math.huge -- Infinite strength to fight gravity
				linearVel.VectorVelocity = shootVelocity
				linearVel.Parent = mainPart
			end

			-- Unanchor everything so it can fly
			for _, part in projectile:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = false
				end
			end
			
			
			
			
			
			white.Enabled = true
			task.wait(0.1)
			purple.Enabled = true
			white.Enabled = false

			for i, item in pairs(hand:GetDescendants()) do
				if item:IsA("ParticleEmitter") then
					item.Enabled = false
				end
				if item:IsA("Sound") then
					item:Play()
				end
			end

			task.wait(0.03)
			purple.Enabled = false
			black.Enabled = true

			task.wait(0.05)
			black.Enabled = false
			
			
			
			
			
			
			
			Debris:AddItem(projectile, 3)
			-- ==========================================

			tween = TweenService:Create(camera, tweenInfo, {CFrame = cutsceneCamPart2.CFrame})
			tween:Play()
			tween.Completed:Wait()

			-- Give camera control back to the player
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = character:WaitForChild("Humanoid")
			task.wait(2)
			hasPlayed = false
		end
	end
end)