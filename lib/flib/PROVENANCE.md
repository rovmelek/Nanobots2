# flib (vendored)

- Source: https://codeberg.org/raiguard/flib, tag `v0.17.2`, commit `c7bfe5a` (the Lua code is identical at 0.17.3-dev `88a5e3b`).
- License: MIT, Copyright (c) 2020 raiguard. See `LICENSE` next to this file.
- Files: `array.lua`, `bounding-box.lua`, `data-util.lua`, `direction.lua`, `math.lua`, `position.lua`, `prototypes.lua`, `table.lua`.

## Verbatim rule

These files are copies of upstream. The only change is mechanical: every `"__flib__.` require prefix was rewritten to
`"__Nanobots2__.lib.flib.` (code and doc comments). Do not edit them by hand. Formatting is upstream's, so StyLua
skips this folder (`.styluaignore`) and luacheck has a relaxed entry for it (`.luacheckrc`).

## Caveat

`data-util.lua` exports `empty_image`, `black_image`, `planner_base_image` and `dark_red_button_tileset` as
`__flib__/graphics/...` paths. flib's graphics are not vendored, so those four fields point at nothing. Nanobots2 does not
use them; use `lib/stdlib2/sprites.lua` for empty sprites.

## Re-sync

1. Copy the 8 files from the new upstream tag.
2. Run `sed -i 's/"__flib__\./"__Nanobots2__.lib.flib./g'` on them.
3. Check that reversing the rewrite gives back the upstream file byte for byte.
4. Update the tag and commit above.
