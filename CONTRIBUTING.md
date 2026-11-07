# Contributing

## Tooling

- **Luacheck** is the CI check. Run `luacheck .` before pushing. The config is `.luacheckrc`, with the Factorio 2.x globals (`storage`, `prototypes`, `helpers`).
- **StyLua** formats the code, config in `stylua.toml`. The existing files are not fully formatted yet, so format only the files you are changing, to keep diffs small.
- **LuaLS** gives type checking in the editor. Install the Factorio Modding Toolkit (FMTK) in VS Code and select Factorio 2.1 in its version picker. FMTK supplies the API definitions, `.luarc.json` only holds the project settings. Annotate new functions with `---@param` and `---@return`, the queue job class is `Nanobots.data`.

## Code layout

- `control.lua` wires up the runtime scripts in `scripts/`. `data.lua`, `data-updates.lua` and `prototypes/` are the data stage.
- Nanobots2 depends only on the base game. Library code is vendored under `lib/`, see `lib/flib/PROVENANCE.md` and `lib/stdlib2/PROVENANCE.md`.
  - `lib/flib/` holds upstream flib files, verbatim. Never edit them by hand, re-sync them as described in the PROVENANCE file.
  - `lib/stdlib2/` holds trimmed derivatives of stdlib2, each with a header naming its sources. Keep the license files with the code.
  - Require vendored modules by their dotted absolute path, for example `require('__Nanobots2__.lib.flib.bounding-box')`, so each is loaded under one name only.
  - `scripts/area.lua` is Nanobots2's own helper module built on flib's bounding box.
- Queues (`scripts/hash_queue.lua`) keep their data in `storage` and their handler functions in a local `handlers` table that is passed to `Queue(...)`. Never put functions in `storage`, and never write to `storage` in `on_load`.
- Settings read at runtime are cached in a local `cfg` and refreshed on `on_runtime_mod_setting_changed`.
- Storage shape changes need an entry in `changes/versions.lua`.

## Style

- 4 spaces, single quotes, no trailing whitespace.
- Prefer early returns over deep nesting, and small functions that do one job.
- Remove commented-out code instead of keeping it, git has the history.

## Testing

Run `lua5.2 tools/harness/run.lua` from the repository root. It loads the control and data stages under stubs of the Factorio API and checks storage shapes, on_init, on_load, migrations and the prototypes. CI runs it too. Gameplay still needs the manual list, see `docs/TESTING.md`. Set `NANO.DEBUG = true` in `config.lua` for test builds so errors stop the game, and set it back before release.

## Releasing

1. Bump `version` in `info.json` and add the entry on top of `changelog.txt`.
2. Run `tools/package.sh` to build `Nanobots2_<version>.zip`, or push a `v*` tag and take the zip from the Package workflow.
