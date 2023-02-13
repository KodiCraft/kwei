-- kwei.lua
-- by KodiCraft

package.path = package.path .. ";/usr/lib/?.lua"

local logger = require("k-log")
local crypto = require("k-crypto")

local args = {...}

log = logger.Logger:new()

local function printError(text)
  term.setTextColor(colors.red)
  print(text)
  term.setTextColor(colors.white)
end

local function printSuccess(text)
  term.setTextColor(colors.green)
  print(text)
  term.setTextColor(colors.white)
end

local function printInfo(text)
  term.setTextColor(colors.yellow)
  print(text)
  term.setTextColor(colors.white)
end

local function printWarning(text)
  term.setTextColor(colors.orange)
  print(text)
  term.setTextColor(colors.white)
end

local function usage()
  print("Usage: kwei <command> [options]")
  print("Commands:")
  print("  help - show this help message")
  print("  passwd - set the admin password")
  print("  create <name> [image] - create a new container from an image")
  print("  run <container> <executable> [args] - run an executable in a container")
  print("  shell <container> - open a shell in a container")
  print("  list - list all containers")
  print("  delete <container> - delete a container")
  print("  overlay <container> <targetContainer> - overlay the file system of a container on top of another")
  print("  cd <container> - change the current directory to the container's root")
end

HOME = settings.get("kwei.path.home")
if HOME == nil then
  HOME = "/var/kwei"
  settings.set("kwei.path.home", HOME)
end

local passwdhandle = fs.open(HOME .. "/passwd", "r")
if passwdhandle == nil then
  printError("No password set, setting it to empty string ('')")
  PASSWORD_HASH = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" -- sha256 of empty string
else
  PASSWORD_HASH = passwdhandle.readLine()
  passwdhandle.close()
end

local function verify_password(input)
    local inputhash = crypto.sha256(input)
    if inputhash == PASSWORD_HASH then
        return true
    else
        return false
    end
end

local function passwd()
  log:info("Attempting password change")

  print("Enter current password: ")
  local input = read("*")
  if not verify_password(input) then
    print("Authentication failed")
    log:warn("Authentication failed")
    return
  end

  print("Enter new password: ")
  local newpass = read("*")
  print("Confirm new password: ")
  local newpass2 = read("*")

  if newpass ~= newpass2 then
        print("Passwords do not match")
        log:warn("Password change aborted: passwords do not match")
        return
  end

  local passhash = crypto.sha256(newpass)
  local passhandle = fs.open(HOME .. "/passwd", "w")
  passhandle.writeLine(passhash)
  passhandle.close()
  print("Password updated.")
  log:info("Password changed, sha256 hash: " .. passhash)
  return
end

local function create(name, image)

  log:info("Attempting to create container " .. name)
  if image ~= nil then
    printError("Image support is not yet implemented! This feature will be added in a future release.")
  end

  if name == nil then
    printError("No container name specified")
    log:warn("No container name specified")
    return
  end

  -- check if the container already exists
  if fs.exists(HOME .. "/containers/" .. name) then
    printError("Container " .. name .. " already exists")
    log:warn("Container " .. name .. " already exists")
    return
  end

  -- create folder for container
  local containerhome = HOME .. "/containers/" .. name
  fs.makeDir(containerhome)
  fs.makeDir(containerhome .. "/fs")

  -- create container basic configuration
  local config = {}
  config.name = name
  config.image = "std@kwei"
  config.overlays = {}
  config.permissions = {}
  config.peripherals = {}
  config.mounts = {}

  -- write config to file
  local confighandle = fs.open(containerhome .. "/config", "w")
  confighandle.write(textutils.serialize(config))
  confighandle.close()

  -- create container filesystem
  local fsdir = containerhome .. "/fs"
  fs.makeDir(fsdir .. "/rom")
  -- copy rom files from either the system rom or the kwei patched rom
  -- get a recursive file list of the rom directory
  local romfiles = {}
  local list = fs.list("/rom")
  for i = 1, #list do
    local file = list[i]
    if fs.isDir("/rom/" .. file) then
      local subfiles = fs.list("/rom/" .. file)
      for j = 1, #subfiles do
        table.insert(romfiles, file .. "/" .. subfiles[j])
      end
    else
      table.insert(romfiles, file)
    end
  end

  for i = 1, #romfiles do
    local file = romfiles[i]
    -- check if the file exists in the /usr/lib/kwei-patched-rom directory
    if fs.exists("/usr/lib/kwei-patched-rom/" .. file) then
      -- copy the patched rom file
      fs.copy("/usr/lib/kwei-patched-rom/" .. file, fsdir .. "/rom/" .. file)
    else
      -- copy the original rom file
      fs.copy("/rom/" .. file, fsdir .. "/rom/" .. file)
    end
  end

  -- copy the patched bios to the container's filesystem
  fs.copy("/usr/lib/kwei-patched-bios.lua", fsdir .. "/rom/bios.lua")

  printSuccess("Container " .. name .. " created")
  log:info("Container " .. name .. " created")
end

local function shellInContainer(name)
  if name == nil then
    printError("No container name specified")
    log:warn("No container name specified")
    return
  end

  log:info("Attempting to open shell in container " .. name)
  -- check if the container exists
  if not fs.exists(HOME .. "/containers/" .. name) then
    printError("Container " .. name .. " does not exist")
    log:warn("Container " .. name .. " does not exist")
    return
  end

  -- load the container's config
  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "r")
  local config = textutils.unserialize(confighandle.readAll())
  confighandle.close()

  -- TODO: Handle configuration and permissions

  -- create the container's required global:
  _CC_CONTAINER_HOME = HOME .. "/containers/" .. name

  -- Create a new global table for the container, it should be almost the same as the current global table, except for all the kwei functions
  local globals = {}
  for k, v in pairs(_G) do
    globals[k] = v
  end
  globals._G = globals
  globals._CC_CONTAINER_HOME = HOME .. "/containers/" .. name


  -- start the container's bios
  local bios = fs.open(HOME .. "/containers/" .. name .. "/fs/rom/bios.lua", "r")
  local bioscode = bios.readAll()
  bios.close()
  local biosfunc = load(bioscode, "bios.lua", "t", globals)
  biosfunc()

  -- when we return here, the container has exited
  -- destroy the container's global
  globals = nil
  _CC_CONTAINER_HOME = nil

  log:info("Container " .. name .. " exited")
  return
end

local cmds = {
    {name = "help", func = usage},
    {name = "passwd", func = passwd},
    {name = "create", func = create},
    {name = "shell", func = shellInContainer}
}

if #args == 0 then
  usage()
  return
end

local cmd = args[1]
local cmdargs = {}
for i = 2, #args do
  cmdargs[i - 1] = args[i]
end

for i = 1, #cmds do
  if cmds[i].name == cmd then
    cmds[i].func(unpack(cmdargs))
    return
  end
end

printError("Unknown command " .. cmd)
usage()
return