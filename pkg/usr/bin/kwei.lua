-- kwei.lua
-- by KodiCraft

package.path = package.path .. ";/usr/lib/?.lua"

local logger = require("k-log")
local crypto = require("k-crypto")

local args = {...}

log = logger.Logger:new()

function usage()
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

function verify_password(input)
    local inputhash = crypto.sha256(input)
    if inputhash == PASSWORD_HASH then
        return true
    else
        return false
    end
end

function passwd()
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

function create(name, image)

  if image ~= nil then
    printError("Image support is not yet implemented! This feature will be added in a future release.")
  end

  -- check if the container already exists
  log:info("Attempting to create container " .. name)
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
  config.
end

local cmds = {
    {name = "help", func = usage},
    {name = "passwd", func = passwd},

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