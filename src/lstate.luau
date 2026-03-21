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
	L1.stack_last = L1.stack

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
	lib.luaS_resize(L, const.LUA_MINSTRTABSIZE)
	local i_o: TValue = g.registry
	i_o.value = lib.luaH_new(L, 0, 2)
	i_o.tt = const.LUA_TTABLE
	-- #undone: checkliveness(L->global, i_o)
	-- #undone: luaS_resize(L, 32)
	for i = 1, #luaT_typenames do
		L.global.ttname[i] = nocollect(lib.luaS_new(L, luaT_typenames[i]))
	end
	for i = 1, #luaT_eventname do
		L.global.tmname = nocollect(lib.luaS_new(L, luaT_eventname[i]))
	end
	g.GCthreshold = 4 * g.totalbytes
end

function lua_newstate(ud: any): lua_State
	local L: lua_State = {
		tt = const.LUA_TTHREAD,
		marked = 7, -- #expanded: bit2mask(WHITE0BIT, FIXEDBIT)
		memcat = 1,
		stack = table.create(const.BASIC_STACK_SIZE + const.EXTRA_STACK),
		stacksize = const.BASIC_STACK_SIZE + const.EXTRA_STACK,
		openupval = {},
		size_ci = 0,
		nCcalls = 0,
		baseCcalls = 0,
		status = const.LUA_OK,
		base_ci = 1,
		end_ci = 1,
		ci = table.create(const.BASIC_CI_SIZE),
		cip = 1,
		singlestep = false,
		isactive = false,
		activememcat = 1,
		userdata = ud,
		base = 1,
		gclist = {}
	} :: any
	local g: global_State = {
		currentwhite = L.marked,
		mainthread = L,
		GCthreshold = 0,
		registryfree = 0,
		rngstate = 0,
		ptrenckey = {1, 0, 0, 0},
		strt = {
			hash = {},
			size = 0,
			nuse = 0
		},
		pseudotemp = table.clone(luaO_nilobject),
		registry = table.clone(luaO_nilobject),
		gcstate = const.GCSpause,
		gray = {},
		grayagain = {},
		weak = {},
		totalbytes = 6816, -- sizeof(LG)
		gcgoal = const.LUAI_GCGOAL,
		gcstepmul = const.LUAI_GCSTEPMUL,
		gcstepsize = const.LUAI_GCSTEPSIZE,
		udatamt = table.create(const.LUA_T_COUNT),
		lightuserdataname = table.create(const.LUA_LUTAG_LIMIT),
		memcatbytes = table.create(const.LUA_MEMORY_CATEGORIES, 0),
		cb = {},
		ecb = {},
		ttname = table.create(const.LUA_T_COUNT),
		tmname = #luaT_eventname,
	} :: any

	L.global = g
	g.memcatbytes[L.activememcat] = g.totalbytes
	L.ci[1] = {} :: any

	f_luaopen(L, ud)
	return L
end

return {
	lua_newstate,
	luaO_nilobject = luaO_nilobject :: any
}
