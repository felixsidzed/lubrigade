--!strict
--!optimize 2

local lib = require("./lubrigade")

lib.include("string")
lib.include("table")
lib.include("state")

local L = lib.lua_newstate()
print(lib.luaS_new(L, "Hello, World!"))
