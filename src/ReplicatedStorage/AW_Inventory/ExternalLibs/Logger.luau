local RunService = game:GetService("RunService")

export type LogLevel = "Error" | "Warning" | "Info" | "Debug" | "Verbose"

local Logger = {}
Logger.__index = Logger

-- Color codes for different log levels
local LOG_COLORS = {
    Error = "❌",
    Warning = "⚠️",
    Info = "ℹ️",
    Debug = "🔧",
    Verbose = "📝"
}

local DEFAULT_CONFIG = {
    MinimumLogLevel = "Info",
    IncludeTimestamp = true,
    LogToOutput = true,
}

function Logger.new(scriptName: string, config: {[string]: any}?)
    local self = setmetatable({}, Logger)
    
    self.scriptName = scriptName
    self.config = if config then table.clone(DEFAULT_CONFIG) else DEFAULT_CONFIG
    
    -- Override default config with provided config
    if config then
        for key, value in pairs(config) do
            self.config[key] = value
        end
    end
    
    return self
end

function Logger:shouldLog(level: LogLevel): boolean
    local logLevels: {LogLevel} = {"Error", "Warning", "Info", "Debug", "Verbose"}
    local minimumLevel = self.config.MinimumLogLevel
    
    local minimumIndex = table.find(logLevels, minimumLevel)
    local currentIndex = table.find(logLevels, level)
    
    return currentIndex <= minimumIndex
end

function Logger:formatMessage(level: LogLevel, message: string, ...: any): string
    local timestamp = if self.config.IncludeTimestamp 
        then string.format("[%.3f] ", workspace:GetServerTimeNow())
        else ""
    
    local args = {...}
    
    -- Format any additional arguments into the message
    if #args > 0 then
        message = string.format(message, table.unpack(args))
    end
    
    -- Simplified format without font tags
    return string.format("%s %s[%s] [%s]: %s",
        LOG_COLORS[level],
        timestamp,
        self.scriptName,
        level,
        message
    )
end

function Logger:log(level: LogLevel, message: string, ...: any)
    if not self:shouldLog(level) then return end
    
    local formattedMessage = self:formatMessage(level, message, ...)
    
    if self.config.LogToOutput then
        if level == "Error" then
            error(formattedMessage, 2)
        elseif level == "Warning" then
            warn(formattedMessage)
        else
            print(formattedMessage)
        end
    end
end

function Logger:error(message: string, ...: any)
    self:log("Error", message, ...)
end

function Logger:warn(message: string, ...: any)
    self:log("Warning", message, ...)
end

function Logger:info(message: string, ...: any)
    self:log("Info", message, ...)
end

function Logger:debug(message: string, ...: any)
    self:log("Debug", message, ...)
end

function Logger:verbose(message: string, ...: any)
    self:log("Verbose", message, ...)
end

return Logger 