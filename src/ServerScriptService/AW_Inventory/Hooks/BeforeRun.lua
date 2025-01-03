return function(registry)
	registry:RegisterHook("BeforeRun", function(context)
		return nil
		-- -- Allow specific developer by UserId
		-- if context.Executor.UserId == 1564972967 then
		--     return nil -- Allow command execution
		-- end

		-- -- Block admin commands for non-authorized users
		-- if context.Group == "Admin" then
		--     return "You don't have permission to run this command"
		-- end
	end)
end
