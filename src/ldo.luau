--!strict
--!optimize 2

local lib = getfenv().lubrigade
local const = getfenv().ldefine

function luaD_checkCstack(L: lua_State)
	-- allow extra stack space to handle stack overflow in xpcall
	local hardlimit: number = const.LUAI_MAXCCALLS + bit32.rshift(const.LUAI_MAXCCALLS, 3)

	if L.nCcalls == const.LUAI_MAXCCALLS then
		lib.luaG_runerror(L, "C stack overflow")
	elseif L.nCcalls >= hardlimit then
		lib.luaD_throw(L, const.LUA_ERRERR) -- error while handling stack error
	end
end

function luaD_growCI(L: lua_State)
	-- allow extra stack space to handle stack overflow in xpcall
	local hardlimit: number = const.LUAI_MAXCALLS + bit32.rshift(const.LUAI_MAXCALLS, 3)

	if L.size_ci >= hardlimit then
		lib.luaD_throw(L, const.LUA_ERRERR); -- error while handling stack error
	end

	local request: number = L.size_ci * 2
	local newsize: number = if L.size_ci >= const.LUAI_MAXCALLS then hardlimit else (if request < const.LUAI_MAXCALLS then request else const.LUAI_MAXCALLS)
	
	-- TODO: MAYBE properly realloc ci
	L.size_ci = newsize
	L.end_ci = L.base_ci + L.size_ci - 1

	if L.size_ci > const.LUAI_MAXCALLS then
		lib.luaG_runerror(L, "stack overflow")
	end

	L.cip += 1
	L.ci[L.cip] = {} :: any
	return L.ci[L.cip]
end

local function performcall(L: lua_State, func: number, nresults: number, preparereentry: boolean)
	if lib.luau_precall(L, func, nresults) == const.PCRLUA then	-- is a Lua function?
		L.ci[L.cip].flags = const.LUA_CALLINFO_RETURN		-- luau_execute will stop after returning from the stack frame

		local oldactive: boolean = L.isactive
		L.isactive = true
		-- #undone: luaC_threadbarrier(L);

		lib.luau_execute(L) -- call it

		if not oldactive then
			L.isactive = false
		end
	end
end

function luaD_callint(L: lua_State, func: number, nresults: number, preparereentry: boolean)
	L.nCcalls += 1
	if L.nCcalls >= const.LUAI_MAXCCALLS then
		luaD_checkCstack(L)
	end

	-- when called from a yieldable C function, maintain yieldable invariant (baseCcalls <= nCcalls)
	local fromyieldableccall: boolean = false

	if L.cip ~= L.base_ci then
		local ccl: Closure = L.ci[L.cip].func.value :: Closure

		-- TODO: cont
		if ccl.isC and (ccl.c :: any).cont then
			fromyieldableccall = true
			L.baseCcalls += 1
		end
	end

	local funcoffset: number = func
	local cioffset: number = L.cip

	performcall(L, func, nresults, preparereentry)

	local yielded: boolean = L.status == const.LUA_YIELD or L.status == const.LUA_BREAK

	if fromyieldableccall then
		-- restore original yieldable invariant
		-- in case of an error, this would either be restored by luaD_pcall or the thread would no longer be resumable
		L.baseCcalls -= 1

		-- on yield, we have to set the CallInfo top of the C function including slots for expected results, to restore later
		if yielded then
			L.ci[cioffset].top = funcoffset + (if nresults ~= const.LUA_MULTRET then nresults else 0)
		end
	end

	if nresults ~= const.LUA_MULTRET and not yielded then
		L.top = funcoffset + nresults
	end

	L.nCcalls -= 1
	-- #undone: luaC_checkGC(L);
end

function luaD_call(L: lua_State, func: number, nresults: number)
	luaD_callint(L, func, nresults, false)
end

return {
	luaD_checkCstack :: any,
	luaD_growCI,
	
	luaD_call, luaD_callint,
}
