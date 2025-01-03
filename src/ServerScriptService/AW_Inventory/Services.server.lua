local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Package = ReplicatedStorage.Packages
local Cmdr = require(Package.cmdr)

Cmdr:RegisterDefaultCommands() -- This loads the default set of commands that Cmdr comes with. (Optional)
Cmdr:RegisterCommandsIn(script.Parent.Commands) -- Register commands from your own folder. (Optional)
Cmdr:RegisterHooksIn(script.Parent.Hooks)
