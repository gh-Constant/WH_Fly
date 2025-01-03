-- ClientFlyingScript in StarterPlayerScripts
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local camera = workspace.CurrentCamera

-- Get remotes
local FlyingRemotes = ReplicatedStorage:WaitForChild("FlyingRemotes")
local StartFlyingRemote = FlyingRemotes:WaitForChild("StartFlying")
local StopFlyingRemote = FlyingRemotes:WaitForChild("StopFlying")
local UpdateMovementRemote = FlyingRemotes:WaitForChild("UpdateMovement")

-- Flying state
local isFlying = false
local currentAnimation = nil
local currentCameraTween = nil
local targetCameraOffset = Vector3.new(0, 2, 10)
local currentSpeed = 0
local maxSpeed = 25
local acceleration = 1
local deceleration = 0.5
local turnResistance = 0.9
local currentRotation = CFrame.new()
local targetRotation = CFrame.new()
local currentCameraRotation = CFrame.new()
local targetCameraRotation = CFrame.new()
local cameraResistance = 0.92

-- Camera settings
local cameraConfig = {
    distance = 15,
    defaultHeight = 4,
    forwardHeight = 4,
    smoothness = 0.15,
    minY = -70,
    maxY = 70,
    currentX = 0,
    currentY = 0
}

-- Animation IDs
local FLYING_ANIMATION_ID = "84379061438490" -- Replace with your animation ID
local IDLE_ANIMATION_ID = "81979718118680" -- Replace with your animation ID

-- Near the top with other variables
local Animator = humanoid:WaitForChild("Animator")

-- Preloaded animation tracks
local flyingTrack
local idleTrack

-- Handle animations
local function loadAnimation(animationId)
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://" .. animationId
    return Animator:LoadAnimation(animation)
end

-- Preload animations
flyingTrack = loadAnimation(FLYING_ANIMATION_ID)
idleTrack = loadAnimation(IDLE_ANIMATION_ID)

local function playAnimation(animationId)
    -- Stop ALL animations, including walk animation
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if humanoid then
        local animator = humanoid:FindFirstChild("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                track:Stop(0) -- The 0 means stop immediately
            end
        end
    end
    
    if currentAnimation then
        currentAnimation:Stop(0)
    end
    
    -- Play the appropriate preloaded animation
    if animationId == FLYING_ANIMATION_ID then
        currentAnimation = flyingTrack
    else
        currentAnimation = idleTrack
    end
    
    currentAnimation:Play()
end

-- Simplify restore function to just stop flying animation
local function restoreDefaultAnimations()
    -- Stop flying animations immediately
    if currentAnimation then
        currentAnimation:Stop(0)
        currentAnimation = nil
    end
    
    -- Make sure Humanoid.PlatformStand is false to allow normal walking
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
    end
end

-- Add these camera variables near the top with other camera settings
local targetCameraY = cameraConfig.defaultHeight
local cameraTiltAmount = 8 -- Reduced from 15 to 8 degrees of tilt for sideways movement

-- Smooth camera movement
local function updateCamera(deltaTime)
    if not isFlying then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    -- Get movement direction from character's rotation
    local characterLook = humanoidRootPart.CFrame.LookVector
    local cameraLook = currentCameraRotation.LookVector
    
    -- Calculate dot products to determine movement direction
    local forwardDot = characterLook:Dot(cameraLook)
    local rightDot = characterLook:Dot(currentCameraRotation.RightVector)
    
    -- Determine movement type based on character's facing direction
    local isMovingForward = forwardDot > 0.7
    local isMovingLeft = rightDot < -0.25
    local isMovingRight = rightDot > 0.25
    
    -- Smoothly adjust camera height when moving forward
    if isMovingForward then
        targetCameraY = cameraConfig.forwardHeight
    else
        targetCameraY = cameraConfig.defaultHeight
    end
    
    cameraConfig.height = cameraConfig.height or cameraConfig.defaultHeight
    cameraConfig.height = cameraConfig.height + (targetCameraY - cameraConfig.height) * 0.1

    -- Update camera angles based on mouse movement with reduced sensitivity
    local delta = UserInputService:GetMouseDelta()
    local sensitivity = 0.25

    -- Update target angles
    cameraConfig.currentX = cameraConfig.currentX - delta.X * sensitivity
    cameraConfig.currentY = math.clamp(
        cameraConfig.currentY - delta.Y * sensitivity,
        cameraConfig.minY,
        cameraConfig.maxY
    )

    -- Add automatic camera tilt for sideways movement
    local sideTilt = 0
    if isMovingLeft then
        sideTilt = cameraTiltAmount
    elseif isMovingRight then
        sideTilt = -cameraTiltAmount
    end

    -- Calculate target camera position using spherical coordinates
    local angle = math.rad(cameraConfig.currentX)
    local height = math.rad(cameraConfig.currentY)
    
    local offset = Vector3.new(
        math.sin(angle) * math.cos(height),
        math.sin(height),
        math.cos(angle) * math.cos(height)
    ) * (isMovingForward and cameraConfig.distance * 0.7 or cameraConfig.distance)

    -- Calculate target camera CFrame with tilt
    local targetPosition = humanoidRootPart.Position - offset + Vector3.new(0, cameraConfig.height, 0)
    targetCameraRotation = CFrame.new(targetPosition, humanoidRootPart.Position) 
        * CFrame.Angles(0, 0, math.rad(sideTilt))
    
    -- Apply camera resistance
    currentCameraRotation = currentCameraRotation:Lerp(targetCameraRotation, 1 - cameraResistance)
    camera.CFrame = currentCameraRotation

    -- Update character rotation based on movement
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        -- Align with camera direction when moving forward
        local lookVector = camera.CFrame.LookVector
        targetRotation = CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + lookVector)
        
        -- Apply banking effect when turning
        local rightVector = humanoidRootPart.CFrame.RightVector
        local turnAmount = rightVector:Dot(lookVector * Vector3.new(1, 0, 1).Unit)
        local bankAngle = math.rad(turnAmount * 30) -- Max 30 degree bank
        targetRotation *= CFrame.Angles(0, 0, -bankAngle)
    else
        -- When not pressing W, maintain horizontal orientation but stay level
        local currentLook = humanoidRootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
        if currentLook.Magnitude > 0.1 then
            targetRotation = CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + currentLook)
        end
    end
    
    -- Apply smooth rotation transition
    currentRotation = currentRotation:Lerp(targetRotation, 1 - turnResistance)
    humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position) * currentRotation.Rotation
end

-- Smooth movement handling
local function updateMovement(deltaTime)
    if not isFlying then return end
    
    local moveDirection = Vector3.new(0, 0, 0)
    local isMoving = false
    
    -- Movement using camera direction
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveDirection = camera.CFrame.LookVector
        isMoving = true
    end
    
    -- Normalize the direction if we're moving
    if moveDirection.Magnitude > 0 then
        moveDirection = moveDirection.Unit
    end
    
    -- Smooth acceleration/deceleration
    if isMoving then
        currentSpeed = math.min(currentSpeed + acceleration * deltaTime, maxSpeed)
    else
        currentSpeed = math.max(currentSpeed - deceleration * deltaTime, 0)
    end
    
    -- Apply movement
    if currentSpeed > 0 then
        -- Use the full movement vector including vertical component
        moveDirection = moveDirection * currentSpeed
        
        -- Send movement data to server
        UpdateMovementRemote:FireServer({
            X = moveDirection.X,
            Y = moveDirection.Y,
            Z = moveDirection.Z
        })
    end
end

-- Connect mouse movement when flying starts
local function startMouseControl()
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

local function stopMouseControl()
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

-- Toggle flying
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F then
        if not isFlying then
            isFlying = true
            StartFlyingRemote:FireServer()
            startMouseControl()
            -- Play idle animation immediately when entering fly mode
            playAnimation(IDLE_ANIMATION_ID)
            RunService:BindToRenderStep("FlyingUpdate", Enum.RenderPriority.Character.Value, function(deltaTime)
                updateMovement(deltaTime)
                updateCamera(deltaTime)
            end)
        else
            isFlying = false
            StopFlyingRemote:FireServer()
            stopMouseControl()
            RunService:UnbindFromRenderStep("FlyingUpdate")
            restoreDefaultAnimations()
        end
    end
end)

-- Handle animation updates from server
UpdateMovementRemote.OnClientEvent:Connect(function(animationType)
    if animationType == "PlayFlyingAnimation" then
        playAnimation(FLYING_ANIMATION_ID)
    elseif animationType == "PlayIdleAnimation" then
        playAnimation(IDLE_ANIMATION_ID)
    end
end)

-- Cleanup
player.CharacterRemoving:Connect(function()
    if isFlying then
        isFlying = false
        StopFlyingRemote:FireServer()
        stopMouseControl()
        RunService:UnbindFromRenderStep("FlyingUpdate")
        restoreDefaultAnimations()
    end
end)