local M = {}

-- logger class
local Logger = {}
Logger.__index = Logger

function Logger:new()
  local self = setmetatable({}, Logger)
  self.logFile = fs.open(settings.get("kwei.log.file"), "a")
  self.logFormat = "[%s] %s: %s" -- date, level, message
  self.logLevel = settings.get("kwei.log.level")
  return self
end

-- generic log function
function Logger:log(level, message)
  if level == "info" and self.logLevel == "info" then
    self.logFile.writeLine(string.format(self.logFormat, os.date(), level, message))
  elseif level == "warn" and (self.logLevel == "info" or self.logLevel == "warn") then
    self.logFile.writeLine(string.format(self.logFormat, os.date(), level, message))
  elseif level == "error" then
    self.logFile.writeLine(string.format(self.logFormat, os.date(), level, message))
  end
end

-- wrappers that are more convenient
function Logger:info(message)
  self:log("info", message)
end

function Logger:warn(message)
  self:log("warn", message)
end

function Logger:error(message)
  self:log("error", message)
end

function Logger:close()
  self.logFile.close()
end

-- return the logger class
M.Logger = Logger

return M