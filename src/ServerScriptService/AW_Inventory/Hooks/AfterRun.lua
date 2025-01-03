return function(registry)
    registry:RegisterHook("AfterRun", function(context)
        -- Log command execution
        print(string.format(
            "[Command Log] Player: %s (%d) | Command: %s | Response: %s",
            context.Executor.Name,
            context.Executor.UserId,
            context.RawText,
            context.Response or "No response"
        ))
        
        -- Return nil to show the original response
        return nil
    end)
end 