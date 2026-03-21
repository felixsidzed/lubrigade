--!strict
--!optimize 2

local const = getfenv().ldefine

function luaS_hash(str: string, len: number): number
	local a, b = 0, 0
	local h = len

	local function rol(x, s)
		return bit32.bor(bit32.lshift(x, s), bit32.rshift(x, 32 - s))
	end

	local function mix(u, v, w)
		a = bit32.bxor(a, h)
		a -= rol(h, u)
		b = bit32.bxor(b, a)
		b -= rol(a, v)
		h = bit32.bxor(h, b)
		h -= rol(b, w)
	end

	local index = 1
	while len >= 32 do
		local block0, block1, block2 = string.unpack("<I4I4I4", str, index)

		a += block0
		b += block1
		h += block2
		mix(14, 11, 25)

		index += 12
		len -= 12
	end

	for i = len, 1, -1 do
		h = bit32.bxor(h, bit32.lshift(h, 5) + bit32.rshift(h, 2) + str:byte(index + i - 1))
	end

	return h
end

function luaS_resize(L: lua_State, newsize: number): ()
	local newhash: { TString } = table.create(newsize)
	local tb: stringtable = L.global.strt
	
	-- rehash
	for i=1, tb.size do
		local p: TString? = tb.hash[i]
		while p do
			local next: TString? = p.next
			local h1: number = bit32.band(p.hash, newsize - 1)

			p.next = newhash[h1]
			newhash[h1] = p

			p = next
		end
	end

	for i=1,tb.size do
		tb.hash[i] = nil
	end
	tb.size = newsize
	tb.hash = newhash
end

local function newlstr(L: lua_State, str: string, l: number, h: number): TString
	local ts: TString = {
		atom = const.ATOM_UNDEF,
		hash = h,
		len = l,
		data = str,
		marked = 0,
		tt = const.LUA_TSTRING,
		memcat = L.activememcat,
		next = nil
	}

	local tb = L.global.strt
	h = bit32.band(h, tb.size - 1)
	ts.next = tb.hash[h] -- chain new entry
	tb.hash[h] = ts

	tb.nuse += 1
	if tb.nuse > tb.size and tb.size <= const.MAXSSIZE then
		luaS_resize(L, tb.size * 2) -- too crowded
	end

	return ts
end

function luaS_newlstr(L: lua_State, str: string, l: number): TString
	local h = luaS_hash(str, l)
	local g = L.global
	local bucket = g.strt.hash[bit32.band(h, g.strt.size - 1)]

	local el: TString? = bucket
	while el do
		if el.len == l and el.data == str then
			if bit32.band(el.marked, 11) == bit32.band(bit32.bxor(g.currentwhite, 3), 3) then -- #expanded: isdead(L->global, obj2gco(el))
				el.marked = bit32.bxor(el.marked, 3) -- #expanded: changewhite(obj2gco(el))
			end
			return el
		end
		el = el.next
	end

	return newlstr(L, str, l, h)
end

function luaS_new(L, str): TString
	return luaS_newlstr(L, str, #str)
end

return {
	luaS_newlstr :: any,
	luaS_new,
	luaS_hash,
	luaS_resize
}
