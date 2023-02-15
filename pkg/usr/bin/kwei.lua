-- kwei.lua
-- by KodiCraft

package.path = package.path .. ";/usr/lib/?.lua"

local logger = require("k-log")
local crypto = require("k-crypto")

local valid_permissions = {
  "http", -- In computercraft pre-1.102 this one needs to be handled differently
  "debug",
  -- wow there really isn't much here
  -- consider this a stub to make sure the system works
}

local args = {...}

log = logger.Logger:new()

-- Save copied tables in `copies`, indexed by original table.
function deepcopy(orig, copies)
  copies = copies or {}
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
      if copies[orig] then
          copy = copies[orig]
      else
          copy = {}
          copies[orig] = copy
          for orig_key, orig_value in next, orig, nil do
              copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
          end
          setmetatable(copy, deepcopy(getmetatable(orig), copies))
      end
  else -- number, string, boolean, etc
      copy = orig
  end
  return copy
end

function table.contains(table, element)
  for _, value in pairs(table) do
      if value == element then
          return true
      end
  end
  return false
end

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
  print("  shell <container> - open a shell in a container")
  print("  addperm <container> <permission> - add a permission to a container")
  print("  rmperm <container> <permission> - remove a permission from a container")
  print("  listperms [container] - list permissions of a container or all possible permissions")
  print("  mount <container> <host_path> <container_path> - mount a path from the host filesystem into a container (container path is absolute)")
  print("  umount <container> <host_path> - unmount a path from the host filesystem")
  print("  listmounts <container> - list all mounts of a container")
  print("  addperi <container> <peripheral> [innername] - add a peripheral to a container")
  print("  rmperi <container> <peripheral> - remove a peripheral from a container")
  print("  listperis <container> - list all peripherals of a container")
  print("  list - list all containers")
  print("  delete <container> - delete a container")
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
  config.mounts = {{native = "rom", container = "rom"}}

  -- write config to file
  local confighandle = fs.open(containerhome .. "/config", "w")
  confighandle.write(textutils.serialize(config))
  confighandle.close()

  -- create container filesystem
  local fsdir = containerhome .. "/fs"
  
  -- create rom directory for rom mount
  fs.makeDir(fsdir .. "/rom")

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
  _CC_CONTAINER_HOME = HOME .. "/containers/" .. name .. "/fs"
  log:info("Container home set to " .. _CC_CONTAINER_HOME)
  -- Create a new global table for the container, we will give it globals only if it has the permission to use them
  -- TODO: Handle permissions for /rom APIs
  local copies = {}
  local oldglobals = deepcopy(_G, copies)
  copies = {}
  local globals = deepcopy(_G, copies)

  -- nuke globals for fs from the container
  globals.fs = nil

  -- nuke globals for peripherals from the container
  globals.peripheral = nil

  -- nuke os.shutdown and os.reboot from the container
  globals.os.shutdown = function() error("Tried to shutdown from the container") end
  globals.os.reboot = function () error("Tried to reboot from the container") end

  -- nuke http from the container if it does not have the permission
  if not table.contains(config.permissions, "http") then
    globals.http = nil
  end

  -- nuke debug from the container if it does not have the permission
  if not table.contains(config.permissions, "debug") then
    globals.debug = {}
    -- Add some fake debug functions to prevent errors that return placeholders
    globals.debug.getregistry = function() return "debug.getregistry is not available in this container" end
    globals.debug.getinfo = function() return "debug.getinfo is not available in this container" end
    globals.debug.getlocal = function() return "debug.getlocal is not available in this container" end
    globals.debug.getupvalue = function() return "debug.getupvalue is not available in this container" end
    globals.debug.setlocal = function() return "debug.setlocal is not available in this container" end
    globals.debug.setupvalue = function() return "debug.setupvalue is not available in this container" end
    globals.debug.traceback = function() return "debug.traceback is not available in this container" end
    globals.debug.upvalueid = function() return "debug.upvalueid is not available in this container" end
    globals.debug.upvaluejoin = function() return "debug.upvaluejoin is not available in this container" end
  end

  -- crete a new fs API that redirects to the container's fs
  local newfs = {}
  function genContainerPath(path)
    -- resolve the path to remove any relative paths
    local resolved = fs.combine("", path)
    -- check we are not starting with ".." verifies that the path is not outside the container's fs
    if string.sub(resolved, 1, 2) == ".." then
      error("Path " .. path .. " is outside the container's filesystem")
    end
    -- check if the path is in rom/api/{a-valid-permission-api}
    if string.sub(resolved, 1, 8) == "rom/api/" then
      -- check if the path is in any of the container's permissions
      for _, permission in pairs(config.permissions) do
        -- if the path starts with the permission's container path, redirect it to the permission's native path
        if string.sub(resolved, 9, string.len(permission)) == permission then
          log:info("Redirecting " .. path .. " to " .. fs.combine(permission, string.sub(resolved, string.len(permission) + 1)) .. " (permission)")
          return fs.combine(permission, string.sub(resolved, string.len(permission) + 1))
        end
      end
    end
    -- check if the path is in any of the container's mounts
    for _, mount in pairs(config.mounts) do
      -- if the path starts with the mount's container path, redirect it to the mount's native path
      if string.sub(resolved, 1, string.len(mount.container)) == mount.container then
        log:info("Redirecting " .. path .. " to " .. fs.combine(mount.native, string.sub(resolved, string.len(mount.container) + 1)) .. " (mount)")
        return fs.combine(mount.native, string.sub(resolved, string.len(mount.container) + 1))
      end
    end

    -- if we get here, the path is not in any of the container's mounts
    -- redirect it to the container's fs
    log:info("Redirecting " .. path .. " to " .. fs.combine(_CC_CONTAINER_HOME, resolved))
    return fs.combine(_CC_CONTAINER_HOME, resolved)
  end

  function genContainerPaths(...)
    local paths = {...}
    for i = 1, #paths do
      -- check if the path is a string, if it is not, we can just ignore it
      if type(paths[i]) == "string" then
        paths[i] = genContainerPath(paths[i])
      else
        log:warn("Path " .. paths[i] .. " is not a string, ignoring")
        paths[i] = paths[i]
      end
    end
    return unpack(paths)
  end

  -- Use some metatable magic to make the fs API redirect to the container's fs
  local fsmt = {
    __index = function(t, k)
      if type(fs[k]) == "function" then
        log:info("Calling fs." .. k .. " from container")
        -- if we are calling 'open' we need to maintain the input mode
        if k == "open" then
          return function(path, mode)
            return fs[k](genContainerPath(path), mode)
          end
        end
        -- if we are calling 'complete' or 'combine' we need to maintain the input path
        if k == "complete" or k == "combine" then
          return fs[k]
        end
        return function(...)
          return fs[k](genContainerPaths(...))
        end
      else
        return fs[k]
      end
    end
  }

  -- create a new peripheral API that redirects peripherals according to the container's config
  local newperipheral = {}
  function genContainerPeripheral(name)
    -- check if the container has a peripheral matching the name
    for _, peripheral in pairs(config.peripherals) do
      if peripheral.container == name then
        log:info("Redirecting peripheral " .. name .. " to " .. peripheral.native)
        return peripheral.native
      end
    end
    -- if we get here, the container does not have a peripheral matching the name
    error("Access peripheral " .. name .. ", unauthorized")
  end

  function newperipheral.getNames()
    local names = {}
    for _, peripheral in pairs(config.peripherals) do
      table.insert(names, peripheral.container)
    end
    return names
  end

  function newperipheral.isPresent(name)
    for _, peripheral in ipairs(config.peripherals) do
      if peripheral.container == name then
        return true
      end
    end
    return false
  end

  function newperipheral.getType(name)
    for _, peri in ipairs(config.peripherals) do
      if peri.container == name then
        return peripheral.getType(peri.native)
      end
    end
    return nil
  end

  function newperipheral.getMethods(name)
    for _, peri in ipairs(config.peripherals) do
      if peri.container == name then
        return peripheral.getMethods(peri.native)
      end
    end
    return nil
  end

  function newperipheral.call(name, method, ...)
    for _, peri in ipairs(config.peripherals) do
      if peri.container == name then
        return peripheral.call(peri.native, method, ...)
      end
    end
    return nil
  end

  function newperipheral.wrap(name)
    for _, peri in ipairs(config.peripherals) do
      if peri.container == name then
        return peripheral.wrap(peri.native)
      end
    end
    return nil
  end

  setmetatable(newfs, fsmt)

  globals.fs = newfs
  globals.peripheral = newperipheral
  globals._G = globals
  globals._CC_CONTAINER_HOME = _CC_CONTAINER_HOME
  globals._PARENT_LOGGER = log
  

  local bioshandle = fs.open("/usr/lib/bios.lua", "r")
  if bioshandle == nil then
    printError("Failed to open bios.lua")
    log:error("Failed to open bios.lua")
    return
  end
  local bios = bioshandle.readAll()
  bioshandle.close()

  -- load the bios into a function
  local biosfunc, err = load(bios, "bios", "t", globals)

  local result, err = pcall(biosfunc)
  if not result then
    printError("Container " .. name .. " exited with error: " .. err)
    log:error("Container " .. name .. " exited with error: " .. err)
    for k, v in pairs(oldglobals) do
      _G[k] = v
    end
    return
  end
  -- when we return here, the container has exited
  -- rebuild the global table
  for k, v in pairs(oldglobals) do
    _G[k] = v
  end
  term.clear()
  printSuccess("Container " .. name .. " exited")
  log:info("Container " .. name .. " exited")
  return
end

local function list()
  print("Containers:")
  local list = fs.list(HOME .. "/containers")
  for i = 1, #list do
    print("  " .. list[i])
  end
end

local function delete(name)
  if name == nil then
    printError("No container name specified")
    log:warn("No container name specified")
    return
  end
  if not fs.exists(HOME .. "/containers/" .. name) then
    printError("Container " .. name .. " does not exist")
    log:warn("Container " .. name .. " does not exist")
    return
  end
  fs.delete(HOME .. "/containers/" .. name)
  printSuccess("Container " .. name .. " deleted")
  log:info("Container " .. name .. " deleted")
end

local function mount(name, native, container)
  -- args check
  if name == nil then
    printError("No mount name specified")
    log:warn("No mount name specified")
    return
  end
  if native == nil then
    printError("No native path specified")
    log:warn("No native path specified")
    return
  end
  if container == nil then
    printError("No container path specified")
    log:warn("No container path specified")
    return
  end

  -- check if the container exists
  if not fs.exists(HOME .. "/containers/" .. name) then
    printError("Container " .. name .. " does not exist")
    log:warn("Container " .. name .. " does not exist")
    return
  end

  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "r")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  local config = textutils.unserialize(confighandle.readAll())
  confighandle.close()
  -- preprocess mount path to remove prefix slashes
  container = fs.combine("", container)

  -- check if the mount already exists
  for i = 1, #config.mounts do
    if config.mounts[i].name == name then
      printError("Mount " .. name .. " already exists")
      log:warn("Mount " .. name .. " already exists")
      return
    end
  end

  -- if the native path is relative, make it absolute
  if string.sub(native, 1, 1) ~= "/" then
    native = fs.combine(shell.dir(), native)
  end

  -- check if the native path exists
  if not fs.exists(native) then
    printError("Native path " .. native .. " does not exist")
    log:warn("Native path " .. native .. " does not exist")
    return
  end

  -- make the directory in the container's file system
  local containerpath = fs.combine(HOME .. "/containers/" .. name .. "/fs/", container)
  if not fs.exists(containerpath) then
    fs.makeDir(containerpath)
  end

  -- add the mount to the config
  table.insert(config.mounts, {native = native, container = container})

  -- write the config back
  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "w")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  confighandle.write(textutils.serialize(config))
  confighandle.close()

  printSuccess("Mount " .. container .. " added")
  log:info("Mount " .. container .. " added")

  return
end

local function unmount(name, path)
  -- args check
  if name == nil then
    printError("No container name specified")
    log:warn("No container name specified")
    return
  end
  if path == nil then
    printError("No container path specified")
    log:warn("No container path specified")
    return
  end

  -- check if the container exists
  if not fs.exists(HOME .. "/containers/" .. name) then
    printError("Container " .. name .. " does not exist")
    log:warn("Container " .. name .. " does not exist")
    return
  end

  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "r")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  local config = textutils.unserialize(confighandle.readAll())

  -- preprocess the path to make sure it's absolute
  path = fs.combine("", path)

  -- check if the mount exists
  local found = false
  for i = 1, #config.mounts do
    if config.mounts[i].container == path then
      found = true
      table.remove(config.mounts, i)
      break
    end
  end

  if not found then
    printError("Mount " .. path .. " does not exist")
    log:warn("Mount " .. path .. " does not exist")
    return
  end

  -- write the config back
  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "w")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  confighandle.write(textutils.serialize(config))
  confighandle.close()

  printSuccess("Mount " .. path .. " removed")
  log:info("Mount " .. path .. " removed")
  return
end

local function listmounts(name)
  -- args check
  if name == nil then
    printError("No container name specified")
    log:warn("No container name specified")
    return
  end

  -- check if the container exists
  if not fs.exists(HOME .. "/containers/" .. name) then
    printError("Container " .. name .. " does not exist")
    log:warn("Container " .. name .. " does not exist")
    return
  end

  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "r")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  local config = textutils.unserialize(confighandle.readAll())
  confighandle.close()

  printInfo("Mounts for container " .. name .. ":")
  for i = 1, #config.mounts do
    printInfo("  " .. config.mounts[i].container .. " -> " .. config.mounts[i].native)
  end
  return
end

local function addPermission(name, perm)
  -- arg check
  if name == nil then
    printError("No container name specified")
    log:warn("No container name specified")
    return
  end
  if not table.contains(valid_permissions, perm) then
    printError("Invalid permission " .. perm)
    printInfo("Valid permissions are: " .. table.concat(valid_permissions, ", "))
    log:warn("Invalid permission " .. perm)
    return
  end

  -- check if the container exists
  if not fs.exists(HOME .. "/containers/" .. name) then
    printError("Container " .. name .. " does not exist")
    log:warn("Container " .. name .. " does not exist")
    return
  end

  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "r")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  local config = textutils.unserialize(confighandle.readAll())

  -- check if the permission already exists
  for i = 1, #config.permissions do
    if config.permissions[i] == perm then
      printError("Permission " .. perm .. " already granted to " .. name)
      log:warn("Permission " .. perm .. " already granted to " .. name)
      return
    end
  end

  -- add the permission
  table.insert(config.permissions, perm)

  -- write the config back
  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "w")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  confighandle.write(textutils.serialize(config))
  confighandle.close()
end

local function listPermissions(name)
  -- if no name is specified, list all possible permissions
  if name == nil then
    printInfo("Valid permissions are: " .. table.concat(valid_permissions, ", "))
    return
  end

  -- check if the container exists
  if not fs.exists(HOME .. "/containers/" .. name) then
    printError("Container " .. name .. " does not exist")
    log:warn("Container " .. name .. " does not exist")
    return
  end

  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "r")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  local config = textutils.unserialize(confighandle.readAll())

  printInfo("Permissions for " .. name .. ":")
  for i = 1, #config.permissions do
    printInfo("  " .. config.permissions[i])
  end
end

local function removePermission(name, perm)
  -- arg check
  if name == nil then
    printError("No container name specified")
    log:warn("No container name specified")
    return
  end
  if not table.contains(valid_permissions, perm) then
    printError("Invalid permission " .. perm)
    printInfo("Valid permissions are: " .. table.concat(valid_permissions, ", "))
    log:warn("Invalid permission " .. perm)
    return
  end

  -- check if the container exists
  if not fs.exists(HOME .. "/containers/" .. name) then
    printError("Container " .. name .. " does not exist")
    log:warn("Container " .. name .. " does not exist")
    return
  end

  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "r")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  local config = textutils.unserialize(confighandle.readAll())
  confighandle.close()

  -- check if the permission exists
  local found = false
  for i = 1, #config.permissions do
    if config.permissions[i] == perm then
      found = true
      table.remove(config.permissions, i)
      break
    end
  end

  if not found then
    printError("Permission " .. perm .. " not granted to " .. name)
    log:warn("Permission " .. perm .. " not granted to " .. name)
    return
  end

  -- write the config back
  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "w")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  confighandle.write(textutils.serialize(config))
  confighandle.close()
end

local function addPeripheral(name, peri, inner)
  -- arg check
  if name == nil then
    printError("No container name specified")
    log:warn("No container name specified")
    return
  end
  if peri == nil then
    printError("No peripheral name specified")
    log:warn("No peripheral name specified")
    return
  end
  if inner == nil then
    inner = peri
  end

  -- check if the container exists
  if not fs.exists(HOME .. "/containers/" .. name) then
    printError("Container " .. name .. " does not exist")
    log:warn("Container " .. name .. " does not exist")
    return
  end

  -- load the config
  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "r")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  local config = textutils.unserialize(confighandle.readAll())
  confighandle.close()


  -- check if the peripheral exists
  if not peripheral.isPresent(peri) then
    printError("Peripheral " .. peri .. " not found")
    log:warn("Peripheral " .. peri .. " not found")
    return
  end

  -- check if the peripheral is already added
  for i = 1, #config.peripherals do
    if config.peripherals[i].native == peri then
      printError("Peripheral " .. peri .. " already added to " .. name)
      log:warn("Peripheral " .. peri .. " already added to " .. name)
      return
    end
  end

  -- add the peripheral
  table.insert(config.peripherals, {native = peri, container = inner})

  -- write the config back
  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "w")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  confighandle.write(textutils.serialize(config))
  confighandle.close()

  printInfo("Added peripheral " .. peri .. " to " .. name)
end

local function rmPeripheral(name, peri)
  -- arg check
  if name == nil then
    printError("No container name specified")
    log:warn("No container name specified")
    return
  end
  if peri == nil then
    printError("No peripheral name specified")
    log:warn("No peripheral name specified")
    return
  end

  -- check if the container exists
  if not fs.exists(HOME .. "/containers/" .. name) then
    printError("Container " .. name .. " does not exist")
    log:warn("Container " .. name .. " does not exist")
    return
  end

  -- load the config
  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "r")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  local config = textutils.unserialize(confighandle.readAll())
  confighandle.close()

  -- check if the peripheral exists
  local found = false
  for i = 1, #config.peripherals do
    if config.peripherals[i].native == peri then
      found = true
      table.remove(config.peripherals, i)
      break
    end
  end

  if not found then
    printError("Peripheral " .. peri .. " not found in " .. name)
    log:warn("Peripheral " .. peri .. " not found in " .. name)
    return
  end

  -- write the config back
  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "w")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  confighandle.write(textutils.serialize(config))
  confighandle.close()

  printInfo("Removed peripheral " .. peri .. " from " .. name)
end

local function listPeripherals(name)
  -- arg check
  if name == nil then
    printError("No container name specified")
    log:warn("No container name specified")
    return
  end

  -- check if the container exists
  if not fs.exists(HOME .. "/containers/" .. name) then
    printError("Container " .. name .. " does not exist")
    log:warn("Container " .. name .. " does not exist")
    return
  end

  -- load the config
  local confighandle = fs.open(HOME .. "/containers/" .. name .. "/config", "r")
  if confighandle == nil then
    printError("Failed to open container config")
    log:error("Failed to open container config")
    return
  end
  local config = textutils.unserialize(confighandle.readAll())
  confighandle.close()

  -- print the peripherals
  printInfo("Peripherals for " .. name)
  for i = 1, #config.peripherals do
    print(config.peripherals[i].native .. " -> " .. config.peripherals[i].container)
  end
end

local cmds = {
    {name = "help", func = usage},
    {name = "passwd", func = passwd},
    {name = "create", func = create},
    {name = "shell", func = shellInContainer},
    {name = "list", func = list},
    {name = "delete", func = delete},
    {name = "mount", func = mount},
    {name = "unmount", func = unmount},
    {name = "addperm", func = addPermission},
    {name = "listperms", func = listPermissions},
    {name = "rmperm", func = removePermission},
    {name = "addperi", func = addPeripheral},
    {name = "listperis", func = listPeripherals},
    {name = "rmperi", func = rmPeripheral},
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