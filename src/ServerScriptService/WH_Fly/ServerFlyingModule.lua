-- ServerFlyingModule in ServerScriptService
local ServerFlyingModule = {}
ServerFlyingModule.__index = ServerFlyingModule

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Store active flying players
local ActiveFlyers = {}

function ServerFlyingModule.new(player)
    local self = setmetatable({}, ServerFlyingModule)
    self.Player = player
    self.IsFlying = false
    self.IsMoving = false
    self.FlySpeed = 65
    self.MinGroundHeight = 5
    self.Character = player.Character or player.CharacterAdded:Wait()
    self.HumanoidRootPart = self.Character:WaitForChild("HumanoidRootPart")
    self.Humanoid = self.Character:WaitForChild("Humanoid")
    self.Trails = {}
    self.LastMovementTime = 0
    self.MovementThreshold = 0.1
    return self
end

local FlyingRemotes = ReplicatedStorage.WH_Fly:WaitForChild("FlyingRemotes")
local StartFlyingRemote = FlyingRemotes:WaitForChild("StartFlying")
local StopFlyingRemote = FlyingRemotes:WaitForChild("StopFlying")
local UpdateMovementRemote = FlyingRemotes:WaitForChild("UpdateMovement")

function ServerFlyingModule:SetupTrails()
    local limbAttachments = {
        -- Upper Arms instead of hands
        {limb = "LeftUpperArm", startOffset = Vector3.new(0, 0.5, 0), endOffset = Vector3.new(0, -0.5, 0)},
        {limb = "RightUpperArm", startOffset = Vector3.new(0, 0.5, 0), endOffset = Vector3.new(0, -0.5, 0)},
        -- Legs
        {limb = "LeftFoot", startOffset = Vector3.new(0, 0.5, 0), endOffset = Vector3.new(0, -0.2, 0)},
        {limb = "RightFoot", startOffset = Vector3.new(0, 0.5, 0), endOffset = Vector3.new(0, -0.2, 0)}
    }

    for _, attachmentData in ipairs(limbAttachments) do
        local limb = self.Character:FindFirstChild(attachmentData.limb)
        if limb then
            -- Create start attachment
            local startAttachment = Instance.new("Attachment")
            startAttachment.Position = attachmentData.startOffset
            startAttachment.Name = "TrailAttachment0"
            startAttachment.Parent = limb

            -- Create end attachment
            local endAttachment = Instance.new("Attachment")
            endAttachment.Position = attachmentData.endOffset
            endAttachment.Name = "TrailAttachment1"
            endAttachment.Parent = limb

            -- Create trail with updated properties
            local trail = Instance.new("Trail")
            trail.Attachment0 = startAttachment
            trail.Attachment1 = endAttachment
            trail.Lifetime = 0.8  -- Increased lifetime for longer trails
            trail.MinLength = 0.02  -- Smaller min length
            trail.MaxLength = 4   -- Increased max length
            trail.Enabled = false
            trail.FaceCamera = true
            
            -- Pure white color for cleaner look
            trail.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
            })
            
            -- More gradual fade out
            trail.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),    -- Fully visible at start
                NumberSequenceKeypoint.new(0.5, 0.2), -- Slight fade at middle
                NumberSequenceKeypoint.new(0.8, 0.5), -- More fade near end
                NumberSequenceKeypoint.new(1, 1)     -- Fully transparent at end
            })
            
            -- Thinner trails
            trail.WidthScale = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.3),   -- Start thinner
                NumberSequenceKeypoint.new(0.8, 0.1), -- Get even thinner
                NumberSequenceKeypoint.new(1, 0)      -- Fade to nothing
            })
            
            trail.Parent = limb
            table.insert(self.Trails, trail)
        end
    end
end

function ServerFlyingModule:StartFlying()
    if self.IsFlying then return end
    self.IsFlying = true

    -- Disable default animations
    self.Humanoid.AutoRotate = false
    -- Store original states to restore later
    self.OriginalJumpPower = self.Humanoid.JumpPower
    self.OriginalJumpHeight = self.Humanoid.JumpHeight
    -- Disable jumping
    self.Humanoid.JumpPower = 0
    self.Humanoid.JumpHeight = 0

    -- Setup physics
    self.BodyVelocity = Instance.new("BodyVelocity")
    self.BodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    self.BodyVelocity.Velocity = Vector3.new(0, 0, 0)
    self.BodyVelocity.Parent = self.HumanoidRootPart

    self.BodyGyro = Instance.new("BodyGyro")
    self.BodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    self.BodyGyro.P = 1000
    self.BodyGyro.D = 100
    self.BodyGyro.Parent = self.HumanoidRootPart

    -- Setup trails
    self:SetupTrails()

    -- Initial elevation
    self:EnsureMinimumHeight()
end

function ServerFlyingModule:StopFlying()
    if not self.IsFlying then return end
    self.IsFlying = false

    -- Restore default animation states
    self.Humanoid.AutoRotate = true
    -- Restore original jump values
    self.Humanoid.JumpPower = self.OriginalJumpPower
    self.Humanoid.JumpHeight = self.OriginalJumpHeight

    -- Cleanup physics
    if self.BodyVelocity then self.BodyVelocity:Destroy() end
    if self.BodyGyro then self.BodyGyro:Destroy() end

    -- Cleanup trails
    for _, trail in ipairs(self.Trails) do
        trail:Destroy()
    end
    self.Trails = {}

    -- Reset animations
    self:PlayIdleAnimation()
end

function ServerFlyingModule:EnsureMinimumHeight()
    local rayOrigin = self.HumanoidRootPart.Position
    local rayDirection = Vector3.new(0, -50, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {self.Character}

    local result = workspace:Raycast(rayOrigin, rayDirection, params)
    if result then
        local groundHeight = result.Position.Y
        local currentHeight = rayOrigin.Y
        local heightDifference = currentHeight - groundHeight

        if heightDifference < self.MinGroundHeight then
            local targetY = groundHeight + self.MinGroundHeight
            local targetPosition = Vector3.new(rayOrigin.X, targetY, rayOrigin.Z)
            self.HumanoidRootPart.Position = targetPosition
        end
    end
end

function ServerFlyingModule:UpdateMovement(moveData)
    if not self.IsFlying then return end

    local moveDirection = Vector3.new(moveData.X, moveData.Y, moveData.Z)
    local isMovingNow = moveDirection.Magnitude > self.MovementThreshold

    -- Update movement state
    if isMovingNow ~= self.IsMoving then
        self.IsMoving = isMovingNow
        if isMovingNow then
            self:EnableTrails()
            self:PlayFlyingAnimation()
        else
            self:DisableTrails()
            self:PlayIdleAnimation()
        end
    end

    -- Update physics
    if self.IsMoving then
        moveDirection = moveDirection.Unit * self.FlySpeed
        self.BodyVelocity.Velocity = moveDirection
        
        local lookAt = self.HumanoidRootPart.Position + moveDirection
        local targetCF = CFrame.lookAt(self.HumanoidRootPart.Position, lookAt) * CFrame.Angles(math.rad(-45), 0, 0)
        self.BodyGyro.CFrame = targetCF
    else
        self.BodyVelocity.Velocity = Vector3.new(0, 0, 0)
        self.BodyGyro.CFrame = CFrame.new(self.HumanoidRootPart.Position) * CFrame.Angles(0, 0, 0)
    end

    self:EnsureMinimumHeight()
end

function ServerFlyingModule:PlayFlyingAnimation()
    if not self.Player then return end
    UpdateMovementRemote:FireClient(self.Player, "PlayFlyingAnimation")
end

function ServerFlyingModule:PlayIdleAnimation()
    if not self.Player then return end
    UpdateMovementRemote:FireClient(self.Player, "PlayIdleAnimation")
end

function ServerFlyingModule:EnableTrails()
    for _, trail in ipairs(self.Trails) do
        trail.Enabled = true
    end
end

function ServerFlyingModule:DisableTrails()
    for _, trail in ipairs(self.Trails) do
        trail.Enabled = false
    end
end

-- Server-side remote handlers
StartFlyingRemote.OnServerEvent:Connect(function(player)
    if not ActiveFlyers[player] then
        local flyingModule = ServerFlyingModule.new(player)
        ActiveFlyers[player] = flyingModule
        flyingModule:StartFlying()
    end
end)

StopFlyingRemote.OnServerEvent:Connect(function(player)
    local flyingModule = ActiveFlyers[player]
    if flyingModule then
        flyingModule:StopFlying()
        ActiveFlyers[player] = nil
    end
end)

UpdateMovementRemote.OnServerEvent:Connect(function(player, moveData)
    local flyingModule = ActiveFlyers[player]
    if flyingModule then
        flyingModule:UpdateMovement(moveData)
    end
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
    local flyingModule = ActiveFlyers[player]
    if flyingModule then
        flyingModule:StopFlying()
        ActiveFlyers[player] = nil
    end
end)

return ServerFlyingModule