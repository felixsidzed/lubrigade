--!strict
--!optimize 2

local LUAI_MAXCSTACK = 8000

return {
	-- luaconf
	LUA_MINSTACK = 20,
	LUA_UTAG_LIMIT = 128,
	LUA_LUTAG_LIMIT = 128,
	LUA_MINSTRTABSIZE = 32,
	LUA_MEMORY_CATEGORIES = 256,
	LUA_EXECUTION_CALLBACK_STORAGE = 512,
	LUA_SIZECLASSES = 40,
	LUAI_MAXCSTACK = LUAI_MAXCSTACK,
	LUA_VECTOR_SIZE = 3,
	LUA_IDSIZE = 256,
	LUAI_MAXCCALLS = 200,
	LUAI_MAXCALLS = 20000,

	-- lstate
	BASIC_CI_SIZE = 8,
	BASIC_STACK_SIZE = 40,
	EXTRA_STACK = 5,

	-- lua
	LUA_MULTRET = -1,
	LUA_REGISTRYINDEX = -LUAI_MAXCSTACK - 2000,
	LUA_ENVIRONINDEX = -LUAI_MAXCSTACK - 2001,
	LUA_GLOBALSINDEX = -LUAI_MAXCSTACK - 2002,

	-- lua_Status
	LUA_OK = 0,
	LUA_YIELD = 1,
    LUA_ERRRUN = 2,
    LUA_ERRSYNTAX = 3,
    LUA_ERRMEM = 4,
    LUA_ERRERR = 5,
    LUA_BREAK = 6,

	-- lua_Type
	LUA_TNONE = -1,
	LUA_TNIL = 0,
	LUA_TBOOLEAN = 1,
	LUA_TLIGHTUSERDATA = 2,
	LUA_TNUMBER = 3,
	LUA_TVECTOR = 4,

	LUA_TSTRING = 5,
	LUA_TTABLE = 6,
	LUA_TFUNCTION = 7,
	LUA_TUSERDATA = 8,
	LUA_TTHREAD = 9,
	LUA_TBUFFER = 10,
	LUA_TPROTO = 11,
	LUA_TUPVAL = 12,
	LUA_TDEADKEY = 13,
	LUA_T_COUNT = 11,

	-- TMS
	TM_INDEX = 0,
    TM_NEWINDEX = 1,
    TM_MODE = 2,
    TM_NAMECALL = 3,
    TM_CALL = 4,
    TM_ITER = 5,
    TM_LEN = 6,

    TM_EQ = 7, -- last tag method with `fast' access

    TM_ADD = 8,
    TM_SUB = 9,
    TM_MUL = 10,
    TM_DIV = 11,
    TM_IDIV = 12,
    TM_MOD = 13,
    TM_POW = 14,
    TM_UNM = 15,

    TM_LT = 16,
    TM_LE = 17,
    TM_CONCAT = 18,
    TM_TYPE = 19,
    TM_METATABLE = 20,

    TM_N = 20, -- number of elements in the enum

	-- lgc
	LUAI_GCGOAL = 200,
	LUAI_GCSTEPMUL = 200,
	LUAI_GCSTEPSIZE = 1,

	GCspause = 0,
	GCSpropagate = 1,
	GCSpropagateagain = 2,
	GCSatomic = 3,
	GCSsweep = 4,

	-- lstring
	ATOM_UNDEF = -32768,
	MAXSSIZE = 1073741823,

	-- lvmutils
	MAXTAGLOOP = 100,

	-- ldo
	PCRLUA = 0,		-- initiated a call to a Lua function
	PCRC = 1,		-- did a call to a C function
	PCRYIELD = 2,	-- C function yielded
}
