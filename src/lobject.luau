--!strict
--!optimize 2

local const = getfenv().ldefine

local log_2 =  {0, 1, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6,
				6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
				7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
				7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
				8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
				8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
				8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8}

function luaO_log2(x: number): number
	local l: number = -1
	while (x >= 256) do
		l += 8
		x = bit32.rshift(x, 8)
	end
	return l + log_2[x]
end

function luaO_ceillog2(x: number): number
	return luaO_log2(x-1) + 1
end

function luaO_rawequal(t1: TValue, t2: TValue): boolean
	if t1.tt ~= t2.tt then
		return false
	end
	
	if t1.tt == const.LUA_TNIL then
		return true
	elseif t1.tt == const.LUA_TLIGHTUSERDATA then
		local lu1: lightuserdata = t1.value :: lightuserdata
		local lu2: lightuserdata = t2.value :: lightuserdata
		return lu1.v == lu2.v and lu1.extra == lu2.extra
	else
		return t1 == t2
	end
end

return {
	luaO_log2 :: any, luaO_ceillog2,
	luaO_rawequal
}
