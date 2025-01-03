--[[
    Flying Client Module
    Author: Your Name
    Version: 1.0.0

    A client-side flying module that provides smooth flying mechanics with camera controls.

    API:
    - FlyingClient:Start() -> nil
        Starts flying mode for the local player
        Example: FlyingClient:Start()

    - FlyingClient:Stop() -> nil
        Stops flying mode for the local player
        Example: FlyingClient:Stop()

    - FlyingClient:IsFlying() -> boolean
        Returns whether the player is currently flying
        Example: local isFlying = FlyingClient:IsFlying()

    Configuration:
    - You can modify the following properties in the Config table:
        * MaxSpeed: number - Maximum flying speed
        * Acceleration: number - How fast to reach max speed
        * Deceleration: number - How fast to slow down
        * TurnResistance: number - How smooth turning is (0-1)
        * CameraConfig: table - Camera behavior settings
        * AnimationIds: table - Custom animation IDs

    Example Usage:
    local FlyingClient = require(game.ReplicatedStorage.Modules.FlyingClient)
    
    -- Start flying
    FlyingClient:Start()
    
    -- Stop flying
    FlyingClient:Stop()
]]

local FlyingClient = {}
FlyingClient.__index = FlyingClient

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Get player and character
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local camera = workspace.CurrentCamera

-- Configuration
local Config = {
    MaxSpeed = 25,
    Acceleration = 1,
    Deceleration = 0.5,
    TurnResistance = 0.9,
    CameraResistance = 0.92,
    CameraConfig = {
        Distance = 15,
        DefaultHeight = 4,
        ForwardHeight = 4,
        Smoothness = 0.15,
        MinY = -70,
        MaxY = 70,
        TiltAmount = 8,
        Sensitivity = 0.25
    },
    AnimationIds = {
        Flying = "84379061438490", -- Replace with your animation ID
        Idle = "81979718118680"    -- Replace with your animation ID
    }
}

-- Get remotes
local FlyingRemotes = ReplicatedStorage:WaitForChild("FlyingRemotes")
local StartFlyingRemote = FlyingRemotes:WaitForChild("StartFlying")
local StopFlyingRemote = FlyingRemotes:WaitForChild("StopFlying")
local UpdateMovementRemote = FlyingRemotes:WaitForChild("UpdateMovement")

-- State variables
local state = {
    isFlying = false,
    currentSpeed = 0,
    currentAnimation = nil,
    currentRotation = CFrame.new(),
    targetRotation = CFrame.new(),
    currentCameraRotation = CFrame.new(),
    targetCameraRotation = CFrame.new(),
    cameraConfig = {
        currentX = 0,
        currentY = 0,
        height = Config.CameraConfig.DefaultHeight
    }
}

-- Animation handling
local function loadAnimation(animationId)
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://" .. animationId
    return humanoid:WaitForChild("Animator"):LoadAnimation(animation)
end

local animations = {
    flying = loadAnimation(Config.AnimationIds.Flying),
    idle = loadAnimation(Config.AnimationIds.Idle)
}

local function playAnimation(animationType)
    if state.currentAnimation then
        state.currentAnimation:Stop(0)
    end
    
    -- Stop all current animations
    local animator = humanoid:FindFirstChild("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            track:Stop(0)
        end
    end
    
    state.currentAnimation = animations[animationType]
    if state.currentAnimation then
        state.currentAnimation:Play()
    end
end

-- Camera movement
local function updateCamera(deltaTime)
    if not state.isFlying then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    -- Update camera angles based on mouse movement
    local delta = UserInputService:GetMouseDelta()
    
    state.cameraConfig.currentX = state.cameraConfig.currentX - delta.X * Config.CameraConfig.Sensitivity
    state.cameraConfig.currentY = math.clamp(
        state.cameraConfig.currentY - delta.Y * Config.CameraConfig.Sensitivity,
        Config.CameraConfig.MinY,
        Config.CameraConfig.MaxY
    )

    -- Calculate camera position
    local angle = math.rad(state.cameraConfig.currentX)
    local height = math.rad(state.cameraConfig.currentY)
    
    local offset = Vector3.new(
        math.sin(angle) * math.cos(height),
        math.sin(height),
        math.cos(angle) * math.cos(height)
    ) * Config.CameraConfig.Distance

    -- Update camera CFrame
    local targetPosition = humanoidRootPart.Position - offset + Vector3.new(0, state.cameraConfig.height, 0)
    state.targetCameraRotation = CFrame.new(targetPosition, humanoidRootPart.Position)
    
    -- Apply camera smoothing
    state.currentCameraRotation = state.currentCameraRotation:Lerp(state.targetCameraRotation, 1 - Config.CameraResistance)
    camera.CFrame = state.currentCameraRotation

    -- Update character rotation when moving
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        local lookVector = camera.CFrame.LookVector
        state.targetRotation = CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + lookVector)
        state.currentRotation = state.currentRotation:Lerp(state.targetRotation, 1 - Config.TurnResistance)
        humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position) * state.currentRotation.Rotation
    end
end

-- Movement handling
local function updateMovement(deltaTime)
    if not state.isFlying then return end
    
    local moveDirection = Vector3.new(0, 0, 0)
    local isMoving = false
    
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveDirection = camera.CFrame.LookVector
        isMoving = true
        playAnimation("flying")
    else
        playAnimation("idle")
    end
    
    -- Update speed
    if isMoving then
        state.currentSpeed = math.min(state.currentSpeed + Config.Acceleration * deltaTime, Config.MaxSpeed)
    else
        state.currentSpeed = math.max(state.currentSpeed - Config.Deceleration * deltaTime, 0)
    end
    
    -- Apply movement
    if state.currentSpeed > 0 then
        moveDirection = moveDirection.Unit * state.currentSpeed
        UpdateMovementRemote:FireServer({
            X = moveDirection.X,
            Y = moveDirection.Y,
            Z = moveDirection.Z
        })
    end
end

-- Mouse control
local function startMouseControl()
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

local function stopMouseControl()
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

-- Public API
function FlyingClient:Start()
    if state.isFlying then return end
    
    state.isFlying = true
    StartFlyingRemote:FireServer()
    startMouseControl()
    playAnimation("idle")
    
    RunService:BindToRenderStep("FlyingUpdate", Enum.RenderPriority.Character.Value, function(deltaTime)
        updateMovement(deltaTime)
        updateCamera(deltaTime)
    end)
end

function FlyingClient:Stop()
    if not state.isFlying then return end
    
    state.isFlying = false
    StopFlyingRemote:FireServer()
    stopMouseControl()
    
    if state.currentAnimation then
        state.currentAnimation:Stop(0)
        state.currentAnimation = nil
    end
    
    RunService:UnbindFromRenderStep("FlyingUpdate")
end

function FlyingClient:IsFlying()
    return state.isFlying
end

-- Cleanup
player.CharacterRemoving:Connect(function()
    if state.isFlying then
        FlyingClient:Stop()
    end
end)

return FlyingClient