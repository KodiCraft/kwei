-- kwei installation script
-- by kodicraft4

-- utilities that need to be embedded in the installer
function printError(text)
  term.setTextColor(colors.red)
  print(text)
  term.setTextColor(colors.white)
end

function printSuccess(text)
  term.setTextColor(colors.green)
  print(text)
  term.setTextColor(colors.white)
end

function printInfo(text)
  term.setTextColor(colors.yellow)
  print(text)
  term.setTextColor(colors.white)
end

function printWarning(text)
  term.setTextColor(colors.orange)
  print(text)
  term.setTextColor(colors.white)
end

function download(url, dest)
  -- append '?' and some random characters to the url to prevent caching
  url = url .. "?" .. math.random(1000000000, 9999999999)
  -- download a file from a url to a destination
  printInfo("Downloading " .. url)
  local response = http.get(url)
  if response then
    printInfo("Got response: " .. response.getResponseCode())
    local file = fs.open(dest, "w")
    file.write(response.readAll())
    file.close()
    response.close()
    printSuccess("Downloaded " .. url)
    return true
  else
    printError("Could not download " .. url)
    return false
  end
end

-- constants
local pkgRoot = "https://raw.githubusercontent.com/KodiCraft/kwei/main/pkg"


-- check if we have access to github
if not http.checkURL("https://github.com") then
  printError("Could not install kwei: no internet access")
  return
end

-- check if we have access to the kwei repo
if not http.checkURL(pkgRoot .. "/kwei.lua") then
  printError("Could not install kwei: no access to kwei repo")
  return
end

-- create a /tmp directory where we can download files
if not fs.exists("/tmp") then
  fs.makeDir("/tmp")
end

-- create the shallow file system layout
-- create the root directories
local rootDirs = {"/usr", "/var"}
for _, dir in ipairs(rootDirs) do
  if not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

-- create the /usr subdirectories
local usrDirs = {"/usr/bin", "/usr/lib"}
for _, dir in ipairs(usrDirs) do
  if not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

-- create the /var subdirectories
local varDirs = {"/var/log", "/var/kwei"}
for _, dir in ipairs(varDirs) do
  if not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

-- find the list of files at the root of the package
local files = {}
local response = http.get(pkgRoot .. "/filelist.txt")
if response then
  for line in response.readLine do
    table.insert(files, line)
  end
  response.close()
else
  printError("Could not install kwei: could not get file list")
  return
end

-- check if any of the files already exist
for _, file in ipairs(files) do
  if fs.exists(file) then
    printWarning("File " .. file .. " already exists, deleting")
    fs.delete(file)
  end
end

-- download the files
for _, file in ipairs(files) do
  local url = pkgRoot .. file
  local dest = "/tmp" .. file
  if not download(url, dest) then
    printError("Could not install kwei: could not download " .. url)
    return
  end
end

-- move the files to their final destination
for _, file in ipairs(files) do
  local dest = file
  local src = "/tmp" .. file

  fs.copy(src, dest)
  fs.delete(src)
  printSuccess("Installed " .. file)
end

-- check the minor version of ComputerCraft
local minorVersion = tonumber(_HOST:sub(17, 19))

-- check if the file pkg/usr/lib/{version}-bios.lua can be found on the repo
local response = http.get(pkgRoot .. "/usr/lib/" .. minorVersion .. "-bios.lua")
if response == nil or response.getResponseCode() ~= 200 then
  printInfo("Could not find a bios.lua for ComputerCraft " .. minorVersion .. ", using the bios from CC-Tweaked/master")
  -- we'll download the upstream bios.lua from the ComputerCraft: Tweaked repo
  local url = "https://raw.githubusercontent.com/SquidDev-CC/CC-Tweaked/master/src/main/resources/assets/computercraft/lua/bios.lua"
  -- download the file as /usr/lib/bios.lua
  local dest = "/usr/lib/bios.lua"
  if not download(url, dest) then
    printError("Could not install kwei: could not download " .. url)
    return
  end
else
  printInfo("Found a bios.lua for ComputerCraft " .. minorVersion .. ", using it")
  -- we'll download the kwei bios.lua from the kwei repo
  local url = pkgRoot .. "/usr/lib/" .. minorVersion .. "-bios.lua"
  -- download the file as /usr/lib/bios.lua
  local dest = "/usr/lib/bios.lua"
  if not download(url, dest) then
    printError("Could not install kwei: could not download " .. url)
    return
  end
end

-- add /usr/bin to the PATH
local path = shell.path()
if not path:find("/usr/bin") then
  shell.setPath(path .. ":/usr/bin")
end

printSuccess("Added /usr/bin to PATH")

-- add that previous segment to the startup script
local startup = "/startup"
if fs.exists(startup) then
  local file = fs.open(startup, "r")
  local contents = file.readAll()
  file.close()

  if not contents:find("shell.setPath") then
    file = fs.open(startup, "a")
    file.writeLine("shell.setPath(shell.path() .. \":/usr/bin\")")
    file.close()
  end
end

-- define default settings
local kweisettings = {
  {key = "kwei.log.level", description = "Log level for kwei, either 'info', 'warn' or 'error'", type = "string", default = "warn"},
  {key = "kwei.log.file", description = "Log file for kwei", type = "string", default = "/var/log/kwei.log"},
  {key = "kwei.path.home", description = "Home directory for kwei and its files", type = "string", default = "/var/kwei"},
  {key = "kwei.path.dl", description = "Temporary directory for downloads", type = "string", default = "/tmp"},
}

for _, setting in ipairs(kweisettings) do
  -- check if the setting already exists
  if settings.get(setting.key) then
    printWarning("Setting " .. setting.key .. " already exists, skipping")
  else
    settings.define(setting.key, {description = setting.description, type = setting.type, default = setting.default})
  end
end

-- add defining the settings to the startup script
if fs.exists(startup) then
  local file = fs.open(startup, "r")
  local contents = file.readAll()
  file.close()

  if not contents:find("settings.define") then
    file = fs.open(startup, "a")
    for _, setting in ipairs(kweisettings) do
      file.writeLine("settings.define(\"" .. setting.key .. "\", {description = \"" .. setting.description .. "\", type = \"" .. setting.type .. "\", default = \"" .. setting.default .. "\"})")
    end
    file.close()
  end
end

printSuccess("Setup initial settings for kwei")

printSuccess("Installed kwei")

settings.save()