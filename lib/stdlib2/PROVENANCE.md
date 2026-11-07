# stdlib2 (trimmed derivatives)

- Source: https://github.com/rovmelek/stdlib2, version 2.1.0, commit `e39ed5a`.
- License: ISC, Copyright (c) 2016, Afforess. See `LICENSE` next to this file.

These modules are not copies. The upstream modules pull in about 15 other modules and write globals, so each file here
keeps stdlib2's logic for the part Nanobots2 uses and drops the rest. Each file has a header naming its sources.

| File | Stage | Derived from | Removed |
|---|---|---|---|
| `event.lua` | control | `stdlib/event/event.lua`, `core.lua` (`log_and_print`), `utils/is.lua` (`Object`) | filters and patterns, native event filters, nth_tick, `remove`, `stop_processing`, option objects, the `created_entity` copy and the `entity = destination` alias for build events, `event.options` and `event.define_name`, the mixed `script.on_event` guard, the on_load storage guard, `dump_data`, `register_*`, `raise_event` |
| `player.lua` | control | `stdlib/event/player.lua`, `event/modules/merge_data.lua`, `game.lua` (`get_player`) | `overwrite`, `pdata`, `add_data_all`, `dump_data`, print queue flushing, function valued defaults |
| `force.lua` | control | `stdlib/event/force.lua`, `game.lua` (`get_force`) | `overwrite`, `get`, `additional_data`, `add_data_all`, `dump_data` |
| `changes.lua` | control | `stdlib/event/changes.lua` | every change type except `mod_versions`, `dump_data`; migrations now run in version order |
| `recipe.lua` | data | `stdlib/data/recipe.lua`, `data/technology.lua` (`add_effect`) | the wrapper object API, everything except add or replace ingredient and add unlock |
| `sprites.lua` | data | `stdlib/data/modules/sprites.lua` | everything except the empty picture and animation helpers |
