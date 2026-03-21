--!strict
--!optimize 2

local lib = getfenv().lubrigade
local const = getfenv().ldefine

local luaO_nilobject: TValue = {
	value = nil,
	tt = 0
}

local luaT_typenames = {
	"nil",
	"boolean",

	"userdata",
	"number",
	"vector",

	"string",
	
	"table",
	"function",
	"userdata",
	"thread",
	"buffer",
}

local luaT_eventname = {
	"__index",
	"__newindex",
	"__mode",
	"__namecall",
	"__call",
	"__iter",
	"__len",

	"__eq",
	
	"__add",
	"__sub",
	"__mul",
	"__div",
	"__idiv",
	"__mod",
	"__pow",
	"__unm",
	
	"__lt",
	"__le",
	"__concat",
	"__type",
	"__metatable",
}

local function nocollect(x)
	x.marked = bit32.bor(x.marked, bit32.lshift(1, 3))
	return x
end

local function stack_init(L1: lua_State)
	L1.end_ci = L1.base_ci + L1.size_ci - 1

	for i = 1, L1.stacksize do
		L1.stack[i] = table.clone(luaO_nilobject)
	end
	L1.top = 1
	L1.stack_last = #L1.stack

	local cip = L1.ci[L1.cip]
	cip.func = L1.top
	L1.base = cip.base
	cip.base = L1.top
	cip.top = L1.top + const.LUA_MINSTACK - 1
end

local function f_luaopen(L: lua_State, userdata: any)
	local g: global_State = L.global
	stack_init(L)
	L.gt = lib.luaH_new(L, 0, 2)
	local i_o: TValue = g.registry
	i_o.value = lib.luaH_new(L, 0, 2)
	i_o.tt = const.LUA_TTABLE
	-- #undone: checkliveness(L->global, i_o)
	lib.luaS_resize(L, const.LUA_MINSTRTABSIZE)
	for i = 1, #luaT_typenames do
		L.global.ttname[i] = nocollect(lib.luaS_new(L, luaT_typenames[i]))
	end
	for i = 1, #luaT_eventname do
		L.global.tmname[i] = nocollect(lib.luaS_new(L, luaT_eventname[i]))
	end
end

function lua_newstate(ud: any): lua_State
	local L: lua_State = {
		tt = const.LUA_TTHREAD,
		marked = 9, -- #expanded: bit2mask(WHITE0BIT, FIXEDBIT)
		memcat = 1,
		status = const.LUA_OK,

		activememcat = 1,

		isactive = true,
		singlestep = false,

		top = 1,
		base = 1,
		global = nil :: any,
		ci = table.create(const.BASIC_CI_SIZE),
		cip = 1,
		stack_last = 0,
		stack = table.create(const.BASIC_STACK_SIZE + const.EXTRA_STACK),

		end_ci = 1,
		base_ci = 1,
		size_ci = 1,

		stacksize = const.BASIC_STACK_SIZE + const.EXTRA_STACK,
		
		nCcalls = 0,
		baseCcalls = 0,
		cachedslot = 0,
		gt = nil :: any,
		upval = {},
		userdata = ud
	}
	
	local g: global_State = {
		strt = { hash = {}, size = 0, nuse = 0 },

		currentwhite = L.marked,
		-- gcstate = const.GCSpause,

		-- gray = {},
		-- grayagain = {},
		-- weak = {},

		-- GCthreshold = 0,
		-- totalbytes = 0,
		-- gcgoal = 0,
		-- gcstepmul = 0,
		-- gcstepsize = 0,

		-- freepages = table.create(const.LUA_SIZECLASSES),
		-- freegcopages = table.create(const.LUA_SIZECLASSES),

		-- memcatbytes = table.create(const.LUA_MEMORY_CATEGORIES),

		mainthread = L,
		uvhead = {
			tt = 0, marked = 0, memcat = 0,
			markedopen = false, v = 0,
			union = luaO_nilobject
		},
		mt = table.create(const.LUA_T_COUNT),
		ttname = table.create(const.LUA_T_COUNT),
		tmname = table.create(#luaT_eventname),

		pseudotemp = table.clone(luaO_nilobject),

		registry = table.clone(luaO_nilobject),
		registryfree = 1,

		errorjump = {},

		rngstate = 0,
		ptrenckey = { 1, 0, 0, 0 },

		cb = {},
		ecb = {},

		ecbdata = table.create(const.LUA_EXECUTION_CALLBACK_STORAGE),
		
		--udatagc = table.create(const.LUA_UTAG_LIMIT),
		udatamt = table.create(const.LUA_UTAG_LIMIT),

		lightuserdataname = table.create(const.LUA_UTAG_LIMIT),

		-- gcstats = {
		-- 	triggerterms = table.create(32, 0),
		-- 	triggertermpos = 0,
		-- 	triggerintegral = 0,

		-- 	atomicstarttotalsizebytes = 0,
		-- 	endtotalsizebytes = 0,
		-- 	heapgoalsizebytes = 0,
			
		-- 	starttimestamp = 0,
		-- 	atomicstarttimestamp = 0,
		-- 	endtimestamp = 0
		-- }
	}

	L.global = g

	f_luaopen(L, ud)
	return L
end

return {
	lua_newstate,
	luaO_nilobject = luaO_nilobject :: any
}
