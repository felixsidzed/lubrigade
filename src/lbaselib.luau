--!strict
--!optimize 2

local lib = getfenv().lubrigade
local const = getfenv().ldefine

function luaB_print(L: lua_State): number
	local result: string = ""
	local n: number = lib.lua_gettop(L) -- number of arguments
	for i=1,n do
		local s: string = lib.lua_tostring(L, i)
		if i > 1 then
			result ..= "\t"
		end
		result ..= s
		lib.lua_pop(L, 1) -- pop result
	end
	print(result)
	return 0
end

local base_funcs: luaL_Reg = {
	print = luaB_print,
}

function luaopen_base(L: lua_State)
	-- set global _G
	lib.lua_createtable(L, 0, 0)
	lib.lua_setglobal(L, "_G")

	-- open lib into global table
	lib.luaL_register(L, nil, base_funcs)
	lib.lua_pushstring(L, "Luau")
	lib.lua_setglobal(L, "_VERSION") -- set global _VERSION

	return 0
end

return {
	luaopen_base :: any
}
