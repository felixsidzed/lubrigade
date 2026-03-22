--!strict
--!optimize 2

local lib = getfenv().lubrigade
local const = getfenv().ldefine

local dummynode: LuaNode = {
	key = {
		next = 0,
		tt = 0,
		value = nil
	},
	val = { tt = const.LUA_TNIL, value = nil }
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
		local lsize = lib.luaO_ceillog2(nhash)
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

local function hashnum(t: LuaTable, n: number)
	local h1, h2 = string.unpack("I4I4", string.pack("d", n))
	h2 = bit32.band(h2, 0x7fffffff)

	local m = 0x5bd1e995

	h1 = bit32.bxor(h1, bit32.rshift(h2, 18))
	h1 = (h1 * m) % 2^32

	h2 = bit32.bxor(h2, bit32.rshift(h1, 22))
	h2 = (h2 * m) % 2^32

	h1 = bit32.bxor(h1, bit32.rshift(h2, 17))
	h1 = (h1 * m) % 2^32

	h2 = bit32.bxor(h2, bit32.rshift(h1, 19))
	h2 = (h2 * m) % 2^32

	return bit32.band(h2, bit32.lshift(1, t.lsizenode) - 1)
end

function mainposition(t: LuaTable, key: TValue): number
	if key.tt == const.LUA_TNUMBER then
		return hashnum(t, key.value :: number)
	elseif key.tt == const.LUA_TSTRING then
		return bit32.band((key.value :: TString).hash, bit32.lshift(1, t.lsizenode) - 1) -- #expanded: hashstr(t, key)
	else
		error("TODO")
	end
end

function luaH_getstr(t: LuaTable, key: TString): TValue
	local np: number = bit32.band(key.hash, bit32.lshift(1, t.lsizenode) - 1) -- #expanded: hashstr(t, key)
	while true do -- check whether `key' is somewhere in the chain
		local n: LuaNode = t.node[np]
		if n.key.tt == const.LUA_TSTRING and n.key.value == key then
			return n.val -- that's it
		end
		if n.key.next == 0 then
			break
		end
		np += n.key.next
	end
	return lib.luaO_nilobject
end

function luaH_getnum(t: LuaTable, key: number): TValue
	-- (1 <= key && key <= t->sizearray)
	if key <= t.sizearray then
		return t.array[key]
	elseif t.node ~= dummynode then
		local np: number = hashnum(t, key)
		while true do -- check whether `key' is somewhere in the chain
			local n: LuaNode = t.node[np]
			if n.key.tt == const.LUA_TNUMBER and n.key.value :: number == key then
				return n.val -- that's it
			end
			if n.key.next == 0 then
				break
			end
			np += n.key.next
		end
	end
	return lib.luaO_nilobject
end

function luaH_get(t: LuaTable, key: TValue): TValue
	if key.tt == const.LUA_TNIL then
		return lib.luaO_nilobject
	elseif key.tt == const.LUA_TSTRING then
		return luaH_getstr(t, key.value :: TString)
	elseif key.tt == const.LUA_TNUMBER then
		local k: number = key.value :: number
		if k % 1 == 0 then -- index is int?
			return luaH_getnum(t, k) -- use specialized version
		end
	end

	local np: number = mainposition(t, key)
	while true do -- check whether `key' is somewhere in the chain
		local n: LuaNode = t.node[np]
		if lib.luaO_rawequalKey(n.key.value, key) then
			return n.val -- that's it
		end

		if n.key.next == 0 then
			break
		end
		np += n.key.next
	end
	return lib.luaO_nilobject
end

local function updateaboundary(t: LuaTable, boundary: number): number
	if boundary < t.sizearray and t.array[boundary].tt == const.LUA_TNIL then
		if boundary >= 2 and t.array[boundary - 1].tt ~= const.LUA_TNIL then
			if t.union <= 0 then
				t.union = -boundary
			end
			return boundary - 1
		end
	elseif boundary + 1 < t.sizearray and t.array[boundary + 1].tt ~= const.LUA_TNIL and t.array[boundary + 2].tt == const.LUA_TNIL then
		if t.union <= 0 then
			t.union = -boundary
		end
		return boundary + 1
	end

	return 0
end

function luaH_getn(t: LuaTable)
	local boundary: number = if t.union < 0 then -t.union else t.sizearray

	if boundary > 0 then
		if t.array[t.sizearray].tt ~= const.LUA_TNIL and t.node == dummynode then
			return t.sizearray -- fast-path: the end of the array in `t' already refers to a boundary
		elseif boundary < t.sizearray and t.array[boundary].tt ~= const.LUA_TNIL and t.array[boundary + 1].tt == const.LUA_TNIL then
			return boundary -- fast-path: boundary already refers to a boundary in `t'
		end

		local foundboundary = updateaboundary(t, boundary)
		if foundboundary > 0 then
			return foundboundary
		end
	end

	local j: number = t.sizearray

	if j > 0 and t.array[j - 1].tt == const.LUA_TNIL then
		local base: number = 1
		local rest: number = j
		while true do
			local half: number = bit32.rshift(rest, 1)
			if half == 0 then
				break
			end
			base = if t.array[base + half].tt == const.LUA_TNIL then base else base + half
			rest -= half
		end
		boundary = (if t.array[base].tt == const.LUA_TNIL then 1 else 0) + base
		if t.union <= 0 then
			t.union = -boundary
		end
		return boundary
	else
		return j
	end
end

return {
	luaH_new :: any,
	luaH_get, luaH_getn,

	luaH_dummynode = dummynode
}
