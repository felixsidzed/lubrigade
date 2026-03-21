--!strict
--!optimize 2

local lib = require("./lubrigade")

lib.include("string")
lib.include("table")
lib.include("state")
lib.include("api")

local L = lib.lua_newstate()
lib.lua_pushstring(L, "Hello, World!")
print(lib.lua_tostring(L, -1))
