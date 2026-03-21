--!strict
--!optimize 2

local lib = getfenv().lubrigade
local const = getfenv().ldefine

local dummynode: LuaNode = {
	key = {
		next = 0,
		tt = 0,
		value = lib.luaO_nilobject
	},
	val = lib.luaO_nilobject
}

function luaH_new(L: lua_State, narray: number, nhash: number): LuaTable
	local t: LuaTable = {
		metatable = nil,
		tmcache = 255, -- #expanded: cast_byte(~0)
		array = table.create(narray),
		sizearray = narray,
		union = 0,
		lsizenode = 0,
		readonly = false,
		safeenv = false,
		nodemask8 = 0,
		node = {},
		memcat = L.activememcat,
		tt = const.LUA_TTABLE,
		marked = 0,
		gclist = {}
	}

	if narray > 0 then
		local array = t.array
		for i=1,narray do
			array[i].tt = const.LUA_TNIL
		end
	end
	if nhash > 0 then
		local lsize = math.ceil(math.log(nhash, 2))
		nhash = bit32.rshift(1, nhash)
		t.node = table.create(nhash)
		for i = 0, nhash do
			t.node[i] = table.clone(dummynode)
		end
		t.lsizenode = lsize
		t.nodemask8 = bit32.rshift(1, lsize) - 1
		t.union = nhash
	end

	return t
end

return {
	luaH_new :: any,
	luaH_dummynode = dummynode
}
