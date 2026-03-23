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
	return l + log_2[x + 1]
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

function luaO_str2d(s: string): (boolean, number?)
	local x: number? = tonumber(s)
	return x ~= nil, x
end

-- Possible chunkname prefixes:
--
-- '=' prefix: meant to represent custom chunknames. When truncation is needed,
-- the beginning of the chunkname is kept.
--
-- '@' prefix: meant to represent filepaths. When truncation is needed, the end
-- of the filepath is kept, as this is more useful for identifying the file.
function luaO_chunkid(source: string): string
	local srclen: number = #source
	if source:sub(1, 1) == "=" then
		if srclen <= const.LUA_IDSIZE then
			return source:sub(2)
		end
		-- truncate the part after =
		return source:sub(1, const.LUA_IDSIZE)
	elseif source:sub(1, 1) == "@" then
		if srclen <= const.LUA_IDSIZE then
			return source:sub(2)
		end
		-- truncate the part after @
		return `...{source:sub(srclen, const.LUA_IDSIZE - 4)}`
	else-- buf = [string "string"]
		-- stop at first newline
		local len: number = source:find("[\n\r]") :: number
		if len then
			len -= 1
		else
			len = #source
		end

		local buflen: number = const.LUA_IDSIZE - 14 -- #expanded: sizeof("[string \"...\"]")
		if len > buflen then
			len = buflen
		end

		if source:sub(len + 1, len + 1) ~= "" then
			return `[string \"{source:sub(1, len)}...`
		else
			return `[string \"{source}\"]`
		end
	end
end
return {
	luaO_log2 :: any, luaO_ceillog2,
	luaO_rawequal,
	luaO_str2d,
	luaO_chunkid
}
