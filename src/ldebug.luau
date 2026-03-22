--!strict
--!optimize 2

local lib = getfenv().lubrigade
local const = getfenv().ldefine

function luaG_getline(p: Proto, pc: number)
	if not p.lineinfo then
		return 0
	end

	return p.lineinfo[p.abslineinfo + bit32.rshift(pc, p.linegaplog2)] + p.lineinfo[pc]
end

local function currentline(L: lua_State, ci: CallInfo)
	local p = ((ci.func.value :: Closure).l :: any).p
	return luaG_getline(p, ci.savedpc)
end

local function pusherror(L: lua_State, msg: string)
	local ci: CallInfo = L.ci[L.cip]
	if ci.func.tt == const.LUA_TFUNCTION and not (ci.func.value :: Closure).isC then -- #expanded: isLua(ci)
		lib.lua_pushfstring(L, "%s:%d: %s", lib.luaO_chunkid(((ci.func.value :: Closure).l :: any).p.source), currentline(L, ci), msg)
	else
		lib.lua_pushstring(L, msg)
	end
end

function luaD_throw(L: lua_State, errcode: number)
	local jb: lua_jmpbuf? = L.global.errorjmp
	if jb then
		jb.status = errcode
		jb.buf() -- must always stop execution (i.e. error)
		return
	end

	if L.global.cb.panic then
		L.global.cb.panic(L, errcode)
	end

	error("unexpected error! aborting")
end

function luaG_runerror(L: lua_State, fmt: string, ...): ()
	local result: string = fmt:format(...)

	pusherror(L, result)
	luaD_throw(L, const.LUA_ERRRUN)
end

function luaG_indexerror(L: lua_State, p1: TValue, p2: TValue)
	local t1: string = L.global.ttname[p1.tt].data -- oh my god bruh -- TODO: luaT_objtypename
	local t2: string = L.global.ttname[p2.tt].data
	local key: TString? = if p2.tt == const.LUA_TSTRING then p2.value :: TString else nil

	if key and key.len <= 64 then -- limit length to make sure we don't generate very long error messages for very long keys
		luaG_runerror(L, "attempt to index %s with '%s'", t1, key.data)
	else
		luaG_runerror(L, "attempt to index %s with %s", t1, t2)
	end 
end

-- custom func :P
function luaG_pusherrhandler(L: lua_State, handler: () -> ()): ()
	L.global.errorjmp = {
		prev = L.global.errorjmp,
		status = 0,
		buf = handler
	}
end

return {
	luaD_throw :: any,
	luaG_runerror,
	luaG_indexerror,
	luaG_pusherrhandler,

	luaG_getline,
}
