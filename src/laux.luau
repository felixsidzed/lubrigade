--!strict
--!optimize 2

local lib = getfenv().lubrigade

function luaL_register(L: lua_State, libname: string?, l: luaL_Reg)
	if libname then
		error("TODO")
	else
		for name, func in l do
			lib.lua_pushcfunction(L, func, name)
			lib.lua_setglobal(L, name)
		end
	end
end

return {
	luaL_register :: any
}
