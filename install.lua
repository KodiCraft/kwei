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

function progress(percent)
  term.setTextColor(colors.yellow)
  write("[" .. string.rep("=", math.floor(percent / 10)) .. string.rep(" ", 10 - math.floor(percent / 10)) .. "] " .. percent .. "%")
  term.setTextColor(colors.white)
end

function download(url, dest)
  -- download a file from a url to a destination
  -- print out a progress bar as the download is happening
  -- print any errors that occur
  request = http.get(url)
  printInfo("Downloading " .. url)
  function downloadProgress()
    local percent = math.floor(request.getResponseCode() / request.getResponseHeaders()["Content-Length"] * 100)
    progress(percent)
  end
  local timer = os.startTimer(0.1)
  while true do
    local event, param = os.pullEvent()
    if event == "timer" and param == timer then
      downloadProgress()
      timer = os.startTimer(0.1)
    elseif event == "http_success" and param == request then
      break
    elseif event == "http_failure" and param == request then
      printError("Could not download " .. url .. ": " .. request.getResponseCode())
      return false
    end
  end
end

-- constants
local pkgRoot = "https://raw.githubusercontent.com/KodiCraft/kwei/main/pkg/"


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

local files = {"kwei.lua"}

-- download files
for _, file in ipairs(files) do
  printInfo("Downloading " .. file)
  download(pkgRoot .. file, "/tmp/" .. file)
  printSuccess("Downloaded " .. file)
end