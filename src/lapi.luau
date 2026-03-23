--!strict
--!optimize 2

local lib = getfenv().lubrigade
local const = getfenv().ldefine

local function getcurrenv(L: lua_State): LuaTable
	if L.cip == L.base_ci then	-- no enclosing function?
		return L.gt				-- use global table as environment
	else
		return (L.ci[L.cip].func.value :: Closure).env
	end
end

local function pseudo2addr(L: lua_State, idx: number): TValue
	if idx == const.LUA_GLOBALSINDEX then
		L.global.pseudotemp.tt = L.gt.tt
		L.global.pseudotemp.value = L.gt
		return L.global.pseudotemp
	elseif idx == const.LUA_ENVIRONINDEX then
		local env: LuaTable = getcurrenv(L)
		L.global.pseudotemp.tt = env.tt
		L.global.pseudotemp.value = env
		return L.global.pseudotemp
	end
	return lib.luaO_nilobject
end

local function index2addr(L: lua_State, idx: number): TValue
	if idx > 0 then
		local o: number = L.base
		if o >= L.top then
			return lib.luaO_nilobject
		else
			return L.stack[o]
		end
	elseif idx > const.LUA_REGISTRYINDEX then
		return L.stack[L.top + idx]
	else
		return pseudo2addr(L, idx)
	end
end

function lua_gettop(L: lua_State): number
	return L.top - L.base
end

function lua_settop(L: lua_State, idx: number): ()
	if idx >= 0 then
		while L.top < L.base + idx do
			L.stack[L.top] = table.clone(lib.luaO_nilobject)
			L.top += 1
		end
	else
		L.top += idx + 1
	end
end

function lua_pop(L: lua_State, n: number): ()
	lua_settop(L, -(n)-1)
end

function lua_pushvalue(L: lua_State, idx: number): ()
	local o: TValue = index2addr(L, idx)
	L.stack[L.top] = table.clone(o)
	L.top += 1
end

function lua_type(L: lua_State, idx: number): number
	local o: TValue = index2addr(L, idx)
	return if o.tt == lib.luaO_nilobject then const.LUA_TNONE else o.tt
end

function lua_typename(L: lua_State, t: number): string
	return if t == const.LUA_TNONE then "no value" else lib.luaT_typenames[t + 1]
end

function lua_iscfunction(L: lua_State, idx: number): boolean
	local o: TValue = index2addr(L, idx)
	return o.tt == const.LUA_TCLOSURE and (o.value :: Closure).isC -- #expanded: iscfunction
end

function lua_isLfunction(L: lua_State, idx: number): boolean
	local o: TValue = index2addr(L, idx)
	return o.tt == const.LUA_TCLOSURE and not (o.value :: Closure).isC -- #expanded: isLfunction
end

function lua_isnumber(L: lua_State, idx: number): boolean
	-- #expanded: tonumber(o, &n)
	local o: TValue = index2addr(L, idx)
	if o.tt == const.LUA_TNUMBER then
		return true
	else
		local n: TValue = { tt = const.LUA_TNIL }
		return lib.luaV_tonumber(o, n) ~= nil
	end
end

function lua_isstring(L: lua_State, idx: number): boolean
	local t: number = lua_type(L, idx)
	return t == const.LUA_TSTRING or t == const.LUA_TNUMBER
end

function lua_isuserdata(L: lua_State, idx: number): boolean
	local o: TValue = index2addr(L, idx)
	return o.tt == const.LUA_TUSERDATA or o.tt == const.LUA_TLIGHTUSERDATA
end

-- Luau does not have an integer type
function lua_tonumber(L: lua_State, idx: number): number?
	local o: TValue = index2addr(L, idx)
	if o.tt == const.LUA_TNUMBER then
		return o.value :: number
	else
		return nil
	end
end

function lua_toboolean(L: lua_State, idx: number)
	local o: TValue = index2addr(L, idx)
	return not (o.tt == const.LUA_TNIL or (o.tt == const.LUA_TBOOLEAN and not o.value)) -- #expanded: l_isfalse(o)
end

-- TODO: should return true for tostring-able values
-- No point in returning string length since the length operator (#) exists
function lua_tostring(L: lua_State, idx: number): (string?, number?)
	local o: TValue = index2addr(L, idx)
	if o.tt == const.LUA_TSTRING then
		local ts = (o.value :: TString)
		return ts.data, ts.atom
	else
		return nil, nil
	end
end

function lua_namecallatom(L: lua_State): (string?, number?)
	local s: TString? = L.namecall
	if not s then
		return nil, nil
	end
	return s.data, s.atom
end

function lua_tovector(L: lua_State, idx: number): vector?
	local o: TValue = index2addr(L, idx)
	return if o.tt == const.LUA_TVECTOR then o.value :: vector else nil
end

function lua_objlen(L: lua_State, idx: number): number
	local o: TValue = index2addr(L, idx)
	
	if o.tt == const.LUA_TSTRING then
		return (o.value :: TString).len
	elseif o.tt == const.LUA_TUSERDATA then
		return (o.value :: Udata).len
	elseif o.tt == const.LUA_TBUFFER then
		return (o.value :: Buffer).len
	elseif o.tt == const.LUA_TTABLE then
		return lib.luaH_getn((o.value :: LuaTable))
	else
		return 0
	end
end

function lua_tocfunction(L: lua_State, idx: number): lua_CFunction?
	local o: TValue = index2addr(L, idx)
	return if o.tt == const.LUA_TCLOSURE and (o.value :: Closure).isC then ((o.value :: Closure).c :: any).f else nil
end

function lua_tolightuserdata(L: lua_State, idx: number): any?
	local o: TValue = index2addr(L, idx)
	return if o.tt == const.LUA_TLIGHTUSERDATA then (o.value :: lightuserdata).v else nil
end

function lua_tolightuserdatatagged(L: lua_State, idx: number, tag: number): any?
	local o: TValue = index2addr(L, idx)
	return if o.tt == const.LUA_TLIGHTUSERDATA and (o.value :: lightuserdata).extra == tag then (o.value :: lightuserdata).v else nil
end

function lua_touserdata(L: lua_State, idx: number): any
	local o: TValue = index2addr(L, idx)
	if o.tt == const.LUA_TUSERDATA then
		return (o.value :: Udata).data
	elseif o.tt == const.LUA_TLIGHTUSERDATA then
		return (o.value :: lightuserdata).v
	else
		return nil
	end
end

function lua_touserdatatagged(L: lua_State, idx: number, tag: number): any?
	local o: TValue = index2addr(L, idx)
	return if o.tt == const.LUA_TUSERDATA and (o.value :: Udata).tag == tag then (o.value :: Udata).data else nil
end

function lua_userdatatag(L: lua_State, idx: number): number
	local o: TValue = index2addr(L, idx)
	return if o.tt == const.LUA_TUSERDATA then (o.value :: Udata).tag else -1
end

function lua_lightuserdatatag(L: lua_State, idx: number): number
	local o: TValue = index2addr(L, idx)
	return if o.tt == const.LUA_TLIGHTUSERDATA then (o.value :: lightuserdata).extra else -1
end

function lua_tothread(L: lua_State, idx: number): lua_State?
	local o: TValue = index2addr(L, idx)
	return if o.tt == const.LUA_TTHREAD then o.value :: lua_State else nil
end

function lua_tobuffer(L: lua_State, idx: number): buffer?
	local o: TValue = index2addr(L, idx)
	if o.tt == const.LUA_TBUFFER then
		return (o.value :: Buffer).data
	else
		return nil
	end
end

function luaA_toobject(L: lua_State, idx: number)
	return index2addr(L, idx)
end

-- Raw pointers dont exist in Luau
function lua_topointer(L: lua_State, idx: number)
	local o: TValue = index2addr(L, idx)
	return if o.tt >= const.LUA_TSTRING then o.value else nil
end

function lua_pushstring(L: lua_State, str: string): ()
	L.stack[L.top].tt = const.LUA_TSTRING
	L.stack[L.top].value = lib.luaS_new(L, str)
	L.top += 1
end

function lua_pushfstring(L: lua_State, str: string, ...): ()
	lua_pushstring(L, string.format(str, ...))
end

function lua_pushnumber(L: lua_State, num: number): ()
	L.stack[L.top].tt = const.LUA_TNUMBER
	L.stack[L.top].value = num
	L.top += 1
end

function lua_pushvector(L: lua_State, v: vector): ()
	L.stack[L.top].tt = const.LUA_TVECTOR
	L.stack[L.top].value = v
	L.top += 1
end

function lua_pushboolean(L: lua_State, b: boolean): ()
	L.stack[L.top].tt = const.LUA_TBOOLEAN
	L.stack[L.top].value = b
	L.top += 1
end

function lua_pushnil(L: lua_State): ()
	L.stack[L.top].tt = const.LUA_TNIL
	L.top += 1
end

function lua_pushcclosurek(L: lua_State, fn: lua_CFunction, debugname: string, nup: number): ()
	-- #undone: luaC_checkGC(L);
    -- #undone: luaC_threadbarrier(L);
	local cl: Closure = {
		tt = const.LUA_TFUNCTION,
		marked = bit32.band(L.global.currentwhite, 3),
		memcat = L.activememcat,
		isC = true,
		nupvalues = nup,
		stacksize = const.LUA_MINSTACK,
		preload = false,
		env = getcurrenv(L),
		c = { f = fn, debugname = debugname, upvals = nup > 0 and table.create(nup) or nil }
	}
	L.top -= nup
	while nup > 0 do
		(cl.c :: any).upvals[nup] = table.clone(L.stack[L.top + nup])
		nup -= 1
	end
	L.stack[L.top].tt = const.LUA_TFUNCTION
	L.stack[L.top].value = cl
	L.top += 1
end

function lua_pushcfunction(L: lua_State, fn: lua_CFunction): ()
	lua_pushcclosurek(L, fn, debug.info(fn, "n") or "", 0)
end

function lua_gettable(L: lua_State, idx: number): number
	-- #undone: luaC_threadbarrier
	local t: TValue = index2addr(L, idx)
	lib.luaV_gettable(L, t, L.stack[L.top - 1], L.stack[L.top - 1])
	return L.stack[L.top - 1].tt
end

function lua_getfield(L: lua_State, idx: number, k: string): number
	-- #undone: luaC_threadbarrier(L);
	local t: TValue = index2addr(L, idx)
	local key: TValue = {
		tt = const.LUA_TSTRING,
		value = lib.luaS_new(L, k)
	}
	lib.luaV_gettable(L, t, key, L.stack[L.top])
	L.top += 1
	return L.stack[L.top - 1].tt
end

function lua_getglobal(L: lua_State, k: string)
	lua_getfield(L, const.LUA_GLOBALSINDEX, k)
end

function lua_createtable(L: lua_State, narray: number, nrec: number)
	-- #undone: luaC_checkGC(L)
	-- #undone: luaC_threadbarrier(L)
	L.stack[L.top].tt = const.LUA_TTABLE
	L.stack[L.top].value = lib.luaH_new(L, narray, nrec)
	L.top += 1
end

function lua_settable(L: lua_State, idx: number)
	local t: TValue = index2addr(L, idx)
	lib.luaV_settable(L, t, L.stack[L.top - 2], L.stack[L.top - 1])
	L.top -= 2
end

function lua_setfield(L: lua_State, idx: number, k: string)
	-- #undone: luaC_threadbarrier(L);
	local t: TValue = index2addr(L, idx)
	local key: TValue = {
		tt = const.LUA_TSTRING,
		value = lib.luaS_new(L, k)
	}
	lib.luaV_settable(L, t, key, L.stack[L.top - 1])
	L.top -= 1
end

function lua_setglobal(L: lua_State, k: string)
	lua_setfield(L, const.LUA_GLOBALSINDEX, k)
end

function lua_call(L: lua_State, nargs: number, nresults: number)
	lib.luaD_call(L, L.top - (nargs + 1), nresults)
	if  nresults == const.LUA_MULTRET and L.top >= L.ci[L.cip].top then
		L.ci[L.cip].top = L.top
	end
end

return {
	lua_gettop :: any, lua_settop, lua_pop,

	lua_pushvalue,

	lua_type, lua_typename,

	lua_iscfunction, lua_isLfunction, lua_isnumber, lua_isstring, lua_isuserdata,

	lua_tonumber, lua_toboolean, lua_tostring, lua_namecallatom, lua_tovector,
	lua_objlen, lua_tocfunction, lua_tolightuserdata, lua_tolightuserdatatagged,
	lua_touserdata, lua_touserdatatagged, lua_userdatatag, lua_lightuserdatatag,
	lua_tothread, lua_tobuffer, lua_topointer, luaA_toobject,

	lua_pushstring, lua_pushfstring, lua_pushnumber, lua_pushvector, lua_pushnil,
	lua_pushboolean, lua_pushcfunction, lua_pushcclosurek,

	lua_gettable, lua_getfield, lua_getglobal, lua_createtable,

	lua_settable, lua_setfield, lua_setglobal,

	lua_call,
}
