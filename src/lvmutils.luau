--!strict
--!optimize 2

local lib = getfenv().lubrigade
local const = getfenv().ldefine

local function callTMres(L: lua_State, res: TValue, f: TValue, p1: TValue, p2: TValue)
	-- #undone: ptrdiff_t result = savestack(L, res);
	
	L.stack[L.top].tt = f.tt; L.stack[L.top].value = f.value			-- push function
	L.stack[L.top + 1].tt = p1.tt; L.stack[L.top + 1].value = p1.value	-- 1st argument
	L.stack[L.top + 2].tt = p2.tt; L.stack[L.top + 2].value = p2.value	-- 2nd argument
	L.top += 3
	lib.luaD_call(L, L.top - 3, 1)
	-- #undone: res = restorestack(L, result);
	L.top -= 1
	res.tt = L.stack[L.top].tt
	res.value = L.stack[L.top].value
	return res
end

function luaV_gettable(L: lua_State, t: TValue, key: TValue, val: TValue)
	for loop = 1, const.MAXTAGLOOP do
		local tm: TValue = lib.luaO_nilobject
		if t.tt == const.LUA_TTABLE  then -- `t' is a table?
			local h: LuaTable = t.value :: LuaTable

			local res: TValue = lib.luaH_get(h, key) -- do a primitive get

			-- if res ~= lib.luaO_nilobject then
			-- 	L.cachedslot = nil -- ?? TODO: int(cast_to(LuaNode*, static_cast<const TValue*>(v)) - t->node)
			-- end

			--(et == NULL ? NULL : (et->tmcache & (1u << e)) ? NULL : luaT_gettm(et, e, l->global->tmname[e]))

			if res.tt ~= const.LUA_TNIL or bit32.band(h.tmcache, 1) == 1 then
				val.tt = res.tt
				val.value = res.value
				return
			end
		else
			-- TODO: tag method resolution
			lib.luaG_indexerror(L, t, key)
		end

        if tm.tt == const.LUA_TFUNCTION then
            callTMres(L, val, tm, t, key)
            return
		end
        t = tm -- else repeat with `tm'
	end
	lib.luaG_runerror(L, "'__index' chain too long; possible loop");
end

return {
	luaV_gettable :: any
}
