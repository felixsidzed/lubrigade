--!strict
--!optimize 2

-- You should probably inline this wherever it's used instead of using require()

local lubrigade = {}

local fs = (require)("@lune/fs")
local luau = (require)("@lune/luau")
local const = require("./src/ldefine")

table.freeze(const)

-- TODO: automatically include dependencies
local loaded = {}
function lubrigade.include(...)
	for _, moduleName in {...} do
		if loaded[moduleName] then
			continue
		end

		local mod = luau.load(luau.compile(fs.readFile(`src/l{moduleName}.luau`), {
			optimizationLevel = 2,
			coverageLevel = 0,
			debugLevel = 1
		}))


		getfenv().lubrigade = lubrigade
		getfenv().ldefine = const

		mod = mod()
		for k, v in mod do
			local name = if type(k) == "string" then k else nil
			if not name and type(v) == "function" then
				name = debug.info(v, "n")
			end

			if name then
				lubrigade[name] = v
			end
		end

		loaded[moduleName] = true
	end
end

return lubrigade
