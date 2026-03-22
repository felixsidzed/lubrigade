--!strict
--!optimize 2

local lib = require("./lubrigade")

lib.include("string", "table", "state", "api", "define", "vmutils", "object", "debug")

local L = lib.lua_newstate()

lib.luaG_pusherrhandler(L, function()
	error((lib.lua_tostring(L, -1)), 0)
end)

lib.lua_pushnil(L)
print(lib.lua_gettable(L, -1, -1))
