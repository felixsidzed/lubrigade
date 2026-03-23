--!strict
--!optimize 2

local lib = require("./lubrigade")

lib.include("*")

local L = lib.lua_newstate()
lib.luaopen_base(L)

lib.lua_getglobal(L, "print")
lib.lua_pushfstring(L, "Hello, %s!", "World")
lib.lua_call(L, 1, 0)
