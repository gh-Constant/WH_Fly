-- ClientFlyingScript in StarterPlayerScripts
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Get the FlyClient module
local FlyClient = require(ReplicatedStorage.WH_Fly.FlyClient)

-- Create a simple interface to start/stop flying
local function onFlyActivated()
    if FlyClient:IsFlying() then
        FlyClient:Stop()
    else
        FlyClient:Start()
    end
end

-- Bind to F key for flying
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F then
        onFlyActivated()
    end
end) 