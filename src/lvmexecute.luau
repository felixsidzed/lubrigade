--!strict
--!optimize 2

local lib = getfenv().lubrigade
local const = getfenv().ldefine

function luau_precall(L: lua_State, pfunc: number, nresults: number)
	local func: TValue = L.stack[pfunc]
	if func.tt ~= const.LUA_TFUNCTION then
		error("TODO") -- luaV_tryfuncTM(L, func);
		-- L->top is incremented by tryfuncTM
	end

	local ccl: Closure = func.value :: Closure

	-- #expanded: incr_ci(L)
	local ci: CallInfo
	if #L.ci == L.end_ci then
		ci = lib.luaD_growCI(L)
	else
		L.cip += 1
		ci = L.ci[L.cip]
	end
	ci.func = func
	ci.base = pfunc + 1
	ci.top = L.top + ccl.stacksize
	ci.savedpc = 0
	ci.flags = 0
	ci.nresults = nresults

	L.base = ci.base
	-- Note: L->top is assigned externally

	if not ccl.isC then
		local p: Proto = (ccl.l :: any).p

		-- fill unused parameters with nil
		local argi: number = L.top
		local argend: number = L.base + p.numparams
		while argi < argend do
			L.stack[argi].tt = const.LUA_TNIL -- complete missing arguments
		end
		L.top = if p.is_vararg then argi else ci.top

		ci.savedpc = 1

		return const.PCRLUA
	else
		local n: number = (ccl.c :: any).f(L)

		-- yield
		if n < 0 then
			return const.PCRYIELD
		end

		-- pci is our callinfo, pcip is our parent
		local pci: number = L.cip
		local pcip: number = pci - 1

		-- copy return values into parent stack (but only up to nresults!), fill the rest with nil
		-- TODO: it might be worthwhile to handle the case when nresults==b explicitly?
		local res: number = table.find(L.stack, ci.func) :: number -- oh my god bruh
		assert(res)
		local vali: number = L.top - n
		local valend: number = L.top

		local i: number = nresults
		while i ~= 0 and vali < valend do
			L.stack[res].tt = L.stack[vali].tt
			L.stack[res].value = L.stack[vali].value
			res += 1
			vali += 1
			i -= 1
		end

		-- pop the stack frame
		L.cip = pcip
		L.base = L.ci[pcip].base
		L.top = res

		return const.PCRC
	end
end

return {
	luau_precall :: any
}
