--!strict
--!optimize 2

local lib = require("./lubrigade")

lib.include("*")

local L = lib.lua_newstate()

lib.luaG_pusherrhandler(L, function()
	error((lib.lua_tostring(L, -1)), 0)
end)

local function test(L: lua_State)
	lib.lua_pushstring(L, "the power of netanyahu compels you!")
	return 1
end

lib.lua_pushcfunction(L, test)
lib.lua_call(L, 0, 1)
print((lib.lua_tostring(L, -1)))
