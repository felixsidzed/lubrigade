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

-- table.clone performs a shallow clone which breaks dummynode
local function clonedummynode()
	local x: LuaNode = table.clone(dummynode)
	x.key = table.clone(x.key)
	x.val = table.clone(x.val)
	return x
end

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
		node = {[0]=dummynode},
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
		nhash = bit32.lshift(1, nhash)
		t.node = table.create(nhash)
		for i = 0, nhash do
			t.node[i] = clonedummynode()
		end
		t.lsizenode = lsize
		t.nodemask8 = bit32.lshift(1, lsize) - 1
		t.union = nhash
	end

	return t
end

local function hashnum(t: LuaTable, n: number)
	local h1, h2 = string.unpack("I4I4", string.pack("d", n))
	h2 = bit32.band(h2, 0x7fffffff)

	local m = 0x5bd1e995

	h1 = bit32.bxor(h1, bit32.rshift(h2, 18))
	h1 = bit32.band((h1 * m), 0xffffffff)

	h2 = bit32.bxor(h2, bit32.rshift(h1, 22))
	h2 = bit32.band((h2 * m), 0xffffffff)

	h1 = bit32.bxor(h1, bit32.rshift(h2, 17))
	h1 = bit32.band((h1 * m), 0xffffffff)

	h2 = bit32.bxor(h2, bit32.rshift(h1, 19))
	h2 = bit32.band((h2 * m), 0xffffffff)

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

local function getfreepos(t: LuaTable): number?
	while t.union > 0 do
		t.union -= 1

		if t.node[t.union].key.tt == const.LUA_TNIL then
			return t.union
		end
	end
	return nil -- could not find a free place
end

local function newkey(L: lua_State, t: LuaTable, key: TValue): TValue
	-- enforce boundary invariant
	if key.tt == const.LUA_TNUMBER and key.value == t.sizearray + 1 then
		-- TODO -- remove lib. after finishing i only put ts to quiet down luau-lsp
		lib.rehash(L, t, key) -- grow table
		
		-- after rehash, numeric keys might be located in the new array part, but won't be found in the node part
		return lib.arrayornewkey(L, t, key)
	end

	local mp: number = mainposition(t, key)
	if t.node[mp].val.tt ~= const.LUA_TNIL or t.node[mp] == dummynode then
		local np: number? = getfreepos(t) -- get a free place
		if np == nil then -- cannot find a free place?
			-- TODO -- remove lib. after finishing i only put ts to quiet down luau-lsp
			lib.rehash(L, t, key) -- grow table
		
			-- after rehash, numeric keys might be located in the new array part, but won't be found in the node part
			return lib.arrayornewkey(L, t, key)
		end

		local mk: TValue = {
			tt = t.node[mp].key.tt,
			value = t.node[mp].key.value
		}
		local othernp: number = mainposition(t, mk)
		if othernp ~= mp then -- is colliding node out of its main position?
			-- yes; move colliding node into free position
			local othern: LuaNode = t.node[othernp]
			while (othernp + othern.key.next) ~= mp do
				othernp += othern.key.next	-- find previous
				othern = t.node[othernp]
			end
			othern.key.next = np - othernp	-- redo the chain with `n' in place of `mp'
			-- copy colliding node into free pos. (mp->next also goes)

			local n: LuaNode = t.node[np]
			local mpn: LuaNode = t.node[mp]
			n.key.next = mpn.key.next -- TODO: not sure if we can set .key directly
			n.key.tt = mpn.key.tt
			n.key.value = mpn.key.value
			n.val = mpn.val

			if mpn.key.next ~= 0 then
				n.key.next += mp - np	-- correct 'next'
				mpn.key.next = 0		-- now 'mp' is free
			end
			mpn.val = const.LUA_TNIL
		else-- colliding node is in its own main position
			-- new node will go into free position

			local mpn: LuaNode = t.node[mp]
			if mpn.key.next ~= 0 then
				mpn.key.next = (mp + mpn.key.next) - np -- chain new position
			else
				assert(t.node[np].key.next == 0)
			end
			mpn.key.next = np - mp
			mp = np
		end
	end

	local mpn: LuaNode = t.node[mp]
	mpn.key.tt = key.tt
	mpn.key.value = key.value
	-- #undone: luaC_barriert(L, t, key);
	return mpn.val
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

local function luai_vecisnan(a: vector)
	return a.x ~= a.x or a.y ~= a.y or a.z ~= a.z
end

function luaH_newkey(L: lua_State, t: LuaTable, key: TValue)
	if key.tt == const.LUA_TNIL then
		lib.luaG_runerror(L, "table index is nil")
	elseif key.tt == const.LUA_TNUMBER and key.value ~= key.value then
		lib.luaG_runerror(L, "table index is NaN")
	elseif key.tt == const.LUA_TVECTOR and luai_vecisnan(key.value :: vector) then
		lib.luaG_runerror(L, "table index contains NaN")
	end
	return newkey(L, t, key)
end

function luaH_setslot(L: lua_State, t: LuaTable, slot: TValue, key: TValue)
	--t.tmcache = 0 -- #expanded: invalidateTMcache(t) -- TODO: uncomment this when u finish luaT_gettm
	if slot == lib.luaO_nilobject then
		return luaH_newkey(L, t, key)
	else
		return slot
	end
end

return {
	luaH_new :: any,

	luaH_get, luaH_getn,

	luaH_setslot, luaH_newkey,

	luaH_dummynode = dummynode
}
