--!strict
--!optimize 2

local lib = getfenv().lubrigade
local const = getfenv().ldefine

function luaV_tonumber(obj: TValue, n: TValue): TValue?
	if obj.tt == const.LUA_TNUMBER then
		return obj
	end
	
	local succ, num = lib.luaO_str2d((obj.value :: TString).data)
	if obj.tt == const.LUA_TSTRING and succ then
		n.tt = const.LUA_TNUMBER
		n.value = num
		return n
	else
		return nil
	end
end

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

local function callTM(L: lua_State, f: TValue, p1: TValue, p2: TValue, p3: TValue): ()
	L.stack[L.top].tt = f.tt; L.stack[L.top].value = f.value			-- push function
	L.stack[L.top + 1].tt = p1.tt; L.stack[L.top + 1].value = p1.value	-- 1st argument
	L.stack[L.top + 2].tt = p2.tt; L.stack[L.top + 2].value = p2.value	-- 2nd argument
	L.stack[L.top + 3].tt = p3.tt; L.stack[L.top + 3].value = p3.value	-- 3rd argument
	
	L.top += 4;
	lib.luaD_call(L, L.top - 4, 0);
end

function luaV_gettable(L: lua_State, t: TValue, key: TValue, val: TValue)
	for loop = 1, const.MAXTAGLOOP do
		local tm: TValue = lib.luaO_nilobject
		if t.tt == const.LUA_TTABLE  then -- `t' is a table?
			local h: LuaTable = t.value :: LuaTable

			local res: TValue = lib.luaH_get(h, key) -- do a primitive get

			-- TODO
			-- if res ~= lib.luaO_nilobject then
			-- 	 L.cachedslot = gval2slot(h, res)
			-- end

			if res.tt ~= const.LUA_TNIL or bit32.band(h.tmcache, 1) ~= 0 then
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

function luaV_settable(L: lua_State, t: TValue, key: TValue, val: TValue)
	local temp: TValue = { tt = 0 }
	for loop=1,const.MAXTAGLOOP do
		local tm: TValue = { tt = 0 }
		if t.tt == const.LUA_TTABLE then -- `t' is a table?
			local h: LuaTable = t.value :: LuaTable

			local oldval: TValue = lib.luaH_get(h, key)
			
			-- should we assign the key? (if key is valid or __newindex is not set)
			if oldval.tt ~= const.LUA_TNIL or bit32.band(h.tmcache, 2) ~= 0 then
				if h.readonly then
					lib.luaG_readonlyerror(L)
				end

				-- luaH_set would work but would repeat the lookup so we use luaH_setslot that can reuse oldval if it's safe
				local newval: TValue = lib.luaH_setslot(L, h, oldval, key)

				-- TODO: L.cachedslot = gval2slot(h, newval) -- remember slot to accelerate future lookups

				newval.tt = val.tt
				newval.value = val.value
				--#undone luaC_barriert(L, h, val);
				return
			end

			-- fallthrough to metamethod
		else
			-- TODO: tag method resolution
			lib.luaG_indexerror(L, t, key)
		end

		if tm.tt == const.LUA_TFUNCTION then
			callTM(L, tm, t, key, val)
			return
		end
		-- else repeat with `tm'
		-- avoid pointing inside table (may rehash)
		temp.tt = tm.tt
		temp.value = tm.value
		t = temp
	end
	lib.luaG_runerror(L, "'__newindex' chain too long; possible loop")
end

return {
	luaV_tonumber :: any,

	luaV_gettable, luaV_settable,
}
