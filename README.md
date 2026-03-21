# lubrigade: Luau in Luau

A full Luau C/C++ VM API and interpreter recreated entirely in Luau

## Features

TODO

## Installation

Just clone or download this repository
Refer to `examples` for usage examples (TODO)
Type defintions for the API can be found in `src/all.d.luau`

## Usage

Require the library in your Luau project:
```luau
-- require the lubrigade import manager
local lib = require("./lubrigade")

-- include the necessary modules
lib.include("string") -- lstate depends on lstring
lib.include("table") --                 and ltable
lib.include("state")

-- create a new lua_State
local L = lib.lua_newstate()

-- allocate a new string in the string table
print(lib.luaS_new(L, "Hello, World!"))
```

The API is nearly identical to Luau, so you can refer to Luau usage examples for more examples

**Currently only the [lune](https://github.com/lune-org/lune) runtime is supported**

## Contributing

Contributions are welcome
Follow my tarded coding style tho

## License

MIT License. See `LICENSE`
