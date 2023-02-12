-- kwei.lua
-- by KodiCraft

package.path = package.path .. ";/usr/lib/?.lua"

local logger = require("k-log")

local args = {...}

log = logger.Logger:new()

log:info("kwei is starting")