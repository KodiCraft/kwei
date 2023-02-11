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
  -- download a file from a url to a destination
  printInfo("Downloading " .. url)
  local response = http.get(url)
  if response then
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
if not http.checkURL(pkgRoot .. "kwei.lua") then
  printError("Could not install kwei: no access to kwei repo")
  return
end

-- create a /tmp directory where we can download files
if not fs.exists("/tmp") then
  fs.makeDir("/tmp")
end

-- create the shallow file system layout
-- it should look like this:
-- / (root)
--   /tmp
--   /etc
--   /usr
--     /bin
--     /lib
--   /var
--     /log
--     /run
--     /kwei
--       /containers
--       /images
--       /volumes

-- create the root directories
local rootDirs = {"/etc", "/usr", "/var"}
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
local varDirs = {"/var/log", "/var/run", "/var/kwei"}
for _, dir in ipairs(varDirs) do
  if not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

-- create the /var/kwei subdirectories
local kweiDirs = {"/var/kwei/containers", "/var/kwei/images", "/var/kwei/volumes"}
for _, dir in ipairs(kweiDirs) do
  if not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

local files = {"/usr/bin/kwei.lua"}

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