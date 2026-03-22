--!strict
--!optimize 2

local lib = require("./lubrigade")

lib.include("string", "table", "state", "api", "define", "vmutils", "object", "debug")

local L = lib.lua_newstate()

lib.lua_getfield(L, lib.LUA_GLOBALSINDEX, "nonexistent")
print(lib.lua_typename(L, lib.lua_type(L, -1)))
