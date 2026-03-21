--@meta

export type lightuserdata = { extra: number, v: any } -- :(
export type Value = GCObject | Proto | number | boolean | vector | nil | lightuserdata

export type TValue = {
	value: Value,
	tt: number
}

export type TString = {
	tt: number, marked: number, memcat: number,
	-- 1 byte padding

	atom: number,

	-- 2 byte padding

	next: TString?, -- next string in the hash table bucket

	hash: number,
	len: number,

	data: string
}

export type lua_Debug = {
	name: string,			-- (n)
	what: string,			-- (s) `Lua', `C'
	source: string,			-- (s)
	short_src: string,		-- (s)
	linedefined: number,	-- (s)
	currentline: number,	-- (l)
	nupvals: number,		-- (u)
	nparams: number,		-- (a)
	isvararg: boolean,		-- (a)

	userdata: any? -- only valid in luau_callhook
}

export type lua_Callbacks = {
	userdata: any?, -- arbitrary userdata value that is never overwritten by lubrigade
	
	interrupt: ((L: lua_State, gc: number) -> ())?, -- gets called at safepoints (loop back edges, call/ret, gc) if set
	panic: ((L: lua_State, errcode: number) -> ())?, -- gets called when an unprotected error is raised (if longjmp is used)

	userthread: ((LP: lua_State, L: lua_State) -> ())?, -- gets called when L is created (LP == parent) or destroyed (LP == NULL)

	useratom: ((L: lua_State, s: string, l: number) -> number)?, -- gets called when a string is created to assign an atom id

	debugbreak: ((L: lua_State, ar: lua_Debug) -> ())?, -- gets called when BREAK instruction is encountered
	debugstep: ((L: lua_State, ar: lua_Debug) -> ())?, -- gets called after each instruction in single step mode
	debuginterrupt: ((L: lua_State, ar: lua_Debug) -> ())?, -- gets called when thread execution is interrupted by break in another thread
	debugprotectederror: ((L: lua_State) -> ())?, -- gets called when protected call results in an error
}

export type lua_ExecutionCallbacks = {
	context: any?,

	close: ((L: lua_State) -> ())?,				-- called when global VM state is closed
	destroy: ((L: lua_State, p: Proto) -> ())?,	-- called when function is destroyed
	enter: ((L: lua_State, p: Proto) -> number)?,	-- called when function is about to start/resume (when execdata is present), return 0 to exit VM
	disable: ((L: lua_State, p: Proto) -> ())?,	-- called when function has to be switched from native to bytecode in the debugger
	getmemorysize: ((L: lua_State, p: Proto) -> number)?, -- called to request the size of memory associated with native part of the Proto
	gettypemapping: ((L: lua_State, str: string, len: number) -> number)?, -- called to get the userdata type index
	getcounterdata: ((L: lua_State, p: Proto, countCell: {number}) -> ())? -- called to get the execution counter data and count {uint32_t, uint32_t, uint64_t}
}

export type stringtable = {
	hash: { TString },
	nuse: number, -- number of elements
	size: number
}

-- export type GCStats = {
-- 	-- data for proportional-integral controller of heap trigger value
-- 	triggerterms: { number },
-- 	triggertermpos: number,
-- 	triggerintegral: number,

-- 	atomicstarttotalsizebytes: number,
-- 	endtotalsizebytes: number,
-- 	heapgoalsizebytes: number,

-- 	starttimestamp: number,
-- 	atomicstarttimestamp: number,
-- 	endtimestamp: number
-- }

export type global_State = {
	strt: stringtable,

	currentwhite: number,
	-- gcstate: number, -- state of garbage collector

	-- gray: { GCObject }, -- list of gray objects
	-- grayagain: { GCObject }, -- list of objects to be traversed atomically
	-- weak: { GCObject }, -- list of weak tables (to be cleared)

	-- GCthreshold: number, -- when totalbytes > GCthreshold, run GC step
	-- totalbytes: number, -- number of bytes currently allocated
	-- gcgoal: number,
	-- gcstepmul: number,
	-- gcstepsize: number,

	-- freepages: { lua_Page? }, -- free page linked list for each size class for non-collectable objects
	-- freegcopages: { lua_Page? }, -- free page linked list for each size class for collectable objects
	-- allpages: lua_Page?, -- page linked list with all pages for all non-collectable object classes (available with LUAU_ASSERTENABLED)
	-- allgcopages: lua_Page?, -- page linked list with all pages for all collectable object classes
	-- sweepgcopage: lua_Page?, -- position of the sweep in 'allgcopages'

	-- memcatbytes: { number }, -- total amount of memory used by each memory category

	mainthread: lua_State,
	uvhead: UpVal,                                    -- head of double-linked list of all open upvalues
	mt: { LuaTable },                   -- metatables for basic types
	ttname: { TString },       -- names for basic types
	tmname: { TString },             -- array with tag-method names

	pseudotemp: TValue, -- storage for temporary values used in pseudo2addr

	registry: TValue, -- registry table, used by lua_ref and LUA_REGISTRYINDEX
	registryfree: number, -- next free slot in registry

	errorjump: { () -> () },

	rngstate: number, -- PCG random number generator state
	ptrenckey: { number }, -- pointer encoding key for display

	cb: lua_Callbacks,
	ecb: lua_ExecutionCallbacks,

	ecbdata: { number },
	
	-- udatagc: { (L: lua_State, data: buffer) -> () },
	udatamt: { LuaTable }, -- metatables for tagged userdata

	lightuserdataname: { TString }, -- names for tagged lightuserdata

	-- gcstats: GCStats
}

-- export type lua_Page = {
-- 	prev: lua_Page?,
-- 	next: lua_Page?,

-- 	listprev: lua_Page?,
-- 	listnext: lua_Page?,

-- 	pageSize: number,
-- 	blockSize: number,

-- 	freeList: number,
-- 	freeNext: number,
-- 	busyBlocks: number,

-- 	data: { GCObject }, -- since we cant cast char* to GCObject*, we will have to use an array of GCObjects directly
-- }

export type CallInfo = {
	base: number,
	func: number,
	top: number,
	savedpc: { number },
	savedpcp: number, -- those who pointer ☠️☠️☠️

	nresults: number,
	flags: number
}

export type TKey = {
	value: Value,
	tt: number,
	next: number
}

export type LuaNode = {
	val: TValue,
	key: TKey
}

export type LuaTable = {
	tt: number, marked: number, memcat: number,

	tmcache: number,    -- 1<<p means tagmethod(p) is not present
	readonly: boolean,   -- sandboxing feature to prohibit writes to table
	safeenv: boolean,    -- environment doesn't share globals with other scripts
	lsizenode: number,  -- log2 of size of `node' array
	nodemask8: number, -- (1<<lsizenode)-1, truncated to 8 bits

	sizearray: number, -- size of `array' array
	union: number,

	metatable: LuaTable?,
	array: { TValue },  -- array part
	node: { LuaNode }, -- LuaNode*
	gclist: { GCObject }?
}

export type UpVal = {
	tt: number, marked: number, memcat: number,

	markedopen: boolean, -- uint8_t -- set if reachable from an alive thread (only valid during atomic)

	v: TValue | number, -- points to stack or to its own value
	union: TValue | {
		-- global double linked list (when open)
		prev: UpVal, -- UpVal*
		next: UpVal, -- UpVal*

		-- thread linked list (when open)
		threadnext: UpVal -- UpVal*
	}
}

export type GCHeader = {
	tt: number, marked: number, memcat: number,
}

export type Buffer = {
	tt: number, marked: number, memcat: number,

	len: number,

	data: buffer
}

export type Udata = {
	tt: number, marked: number, memcat: number,
	
	tag: number,

	len: number,

	metatable: LuaTable?,

	data: any
}

export type LocVar = {
	varname: TString,
	startpc: number,
	endpc: number,
	reg: number
}

export type Proto = {
	tt: number, marked: number, memcat: number,

	nups: number,
	numparams: number,
	is_vararg: boolean,
	maxstacksize: number,
	flags: number,

	k: { TValue },
	code: { number },
	p: { Proto },
	codeentry: { number },

	execdata: buffer,
	exectarget: number,

	lineinfo: { number },
	abslineinfo: number,
	locvars: { LocVar },
	upvalues: { TString },
	source: TString,

	debugname: TString,
	debuginsn: { number },

	typeinfo: { number },

	userdata: any?,

	gclist: { GCObject }?,

	sizecode: number,
	sizep: number,
	sizelocvars: number,
	sizeupvalues: number,
	sizek: number,
	sizelineinfo: number,
	linegaplog2: number,
	linedefined: number,
	bytecodeid: number,
	sizetypeinfo: number
}

export type lua_CFunction = (lua_State) -> number

export type Closure = {
	tt: number, marked: number, memcat: number,

	isC: boolean,
	nupvalues: number,
	stacksize: number,
	preload: boolean, -- uint8_t

	gclist: { GCObject }?,
	env: LuaTable,

	c: {
		f: lua_CFunction,
		--cont: lua_Continuation,
		debugname: string,
		upvals: { TValue }
	}?,
	l: {
		p: Proto,
		uprefs: { TValue }
	}?
}

export type GCObject = GCHeader & (TString | Udata | Closure | LuaTable | Proto | UpVal | lua_State | Buffer)

export type lua_State = {
	tt: number, marked: number, memcat: number,
	status: number,

	activememcat: number,

	isactive: boolean,
	singlestep: boolean,

	top: number,
	base: number,
	global: global_State,
	ci: { CallInfo },
	cip: number,
	stack_last: number,
	stack: { TValue },

	end_ci: number,
	base_ci: number,
	size_ci: number,

	stacksize: number,
	
	nCcalls: number,
	baseCcalls: number,
	cachedslot: number,
	gt: LuaTable,
	upval: { UpVal },
	gclist: { GCObject }?,

	namecall: TString?,

	userdata: any
}
