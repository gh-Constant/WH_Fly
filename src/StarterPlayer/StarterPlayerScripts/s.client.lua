-- Example usage in a LocalScript
local FlyingClient = require(game.ReplicatedStorage.Modules.FlyingClient)

-- You can bind it to any event or input you want
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F then
        if not FlyingClient:IsFlying() then
            FlyingClient:Start()
        else
            FlyingClient:Stop()
        end
    end
end)