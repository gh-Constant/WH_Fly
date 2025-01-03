local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))

-- Set activation keys
Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
Cmdr:Toggle()
