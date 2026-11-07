# Contributing

## Tooling

- **Luacheck** is the CI check. Run `luacheck .` before pushing. The config is `.luacheckrc`, with the Factorio 2.x globals (`storage`, `prototypes`, `helpers`).
- **StyLua** formats the code, config in `stylua.toml`. The existing files are not fully formatted yet, so format only the files you are changing, to keep diffs small.
- **LuaLS** gives type checking in the editor. Install the Factorio Modding Toolkit (FMTK) in VS Code and run its `Factorio: Set Mod Version` command for 2.1, it fills in the API definitions the `.luarc.json` here relies on. Annotate new functions with `---@param` and `---@return`, the queue job class is `Nanobots.data`.

## Code layout

- `control.lua` wires up the runtime scripts in `scripts/`. `data.lua`, `data-updates.lua` and `prototypes/` are the data stage.
- Reach stdlib2 through `lib/stdlib.lua` (runtime) or `lib/stdlib-data.lua` (data stage), never with a direct `require('__stdlib2__/...')`.
- Queues (`scripts/hash_queue.lua`) keep their data in `storage` and their handler functions in a local `handlers` table that is passed to `Queue(...)`. Never put functions in `storage`, and never write to `storage` in `on_load`.
- Settings read at runtime are cached in a local `cfg` and refreshed on `on_runtime_mod_setting_changed`.
- Storage shape changes need an entry in `changes/versions.lua`.

## Style

- 4 spaces, single quotes, no trailing whitespace.
- Prefer early returns over deep nesting, and small functions that do one job.
- Remove commented-out code instead of keeping it, git has the history.

## Testing

See `docs/TESTING.md`. Set `NANO.DEBUG = true` in `config.lua` for test builds so errors stop the game, and set it back before release.

## Releasing

1. Bump `version` in `info.json` and add the entry on top of `changelog.txt`.
2. Run `tools/package.sh` to build `Nanobots2_<version>.zip`, or push a `v*` tag and take the zip from the Package workflow.
