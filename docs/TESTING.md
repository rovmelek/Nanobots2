# Manual test checklist

The offline harness (`lua5.2 tools/harness/run.lua`) checks that the mod loads and that storage and prototypes keep their shape. It cannot run any gameplay, so run this list in game before a release.

## Setup

1. Set `NANO.DEBUG = true` in `config.lua`. This turns off protected mode, so any script error stops the game with a stack trace instead of being hidden. Build the test zip with `tools/package.sh --dirty` so the uncommitted setting is included. Set it back to `false` before releasing.
2. Start a new game with Space Age enabled (quality needs it). Leave `cheat_mode` off for the main pass, because the code takes different paths with it on (items are not consumed or refunded). Optionally run one short pass with it on.
3. Research `nanobots`, `nano-range-1` to `4`, `nano-speed-1` to `4` and `nanobots-cliff`. Craft the nano emitter and constructor ammo, equip them.
4. Run `luacheck .` and `lua5.2 tools/harness/run.lua` and confirm both are clean.

## Nanobot gun

For each case: place the ghost or marker, stand within range, and watch that the right thing happens and that no error appears.

- [ ] Entity ghost from a blueprint builds and uses the item from the inventory.
- [ ] Quality ghost (for example a rare assembler) consumes an item of that quality and builds at that quality. With only a normal item, it does not build.
- [ ] Tile ghost builds when the `Nanobots Build Tiles` setting is on, and is ignored when off.
- [ ] Entity upgrade (belt to fast belt) works.
- [ ] Quality-only upgrade (same entity, higher quality) works.
- [ ] Upgrade planner direction-only change (rotate) works.
- [ ] Deconstruction of an entity returns the item to the player.
- [ ] Deconstruction of a marked tile works.
- [ ] Cliff deconstruction works with cliff explosives and is ignored without the cliff tech.
- [ ] Damaged entities get repaired.
- [ ] Module request (item request proxy) is fulfilled from the inventory, including a partial amount.
- [ ] Damaged item: a built entity gets the health of the item it was built from.
- [ ] Running out of ammo or items stops the gun cleanly. Items already queued are returned if the target disappears.
- [ ] Termite ammo kills trees in range.
- [ ] `Network limits` setting: nanobots hold back when a roboport network with construction bots covers the target.

## Equipment chips

- [ ] Bot chip for items on the ground reprograms personal bots to pick up items.
- [ ] Bot chip for trees reprograms personal bots to chop trees.
- [ ] Feeder chip heals the energy shield, or the player when below 75% health, using healing capsules from the inventory (a flat 10 if there are none).
- [ ] Launcher chip launches combat robots.
- [ ] Nano interface chip lets nanobots work inside a roboport network.

## Roboport interface

Build the interface inside a roboport network that has construction bots. Set one signal at a time in its constant combinator.

- [ ] `nano-signal-chop-trees` marks trees in each cell.
- [ ] `nano-signal-item-on-ground` marks items on the ground.
- [ ] `nano-signal-deconstruct-finished-miners` marks drills with no resources left.
- [ ] `nano-signal-catch-fish` marks fish.
- [ ] `nano-signal-closest-roboport` limits the work to the attached cell.
- [ ] A negative value on chop-trees or catch-fish only acts while the network holds fewer than that many wood or raw fish.
- [ ] The interface can be blueprinted and rebuilt, and its parts die and are removed with it.

## Dependencies and load

- [ ] A new game with only Nanobots2 and the base game (no stdlib2 mod) starts without errors.
- [ ] With Space Age, and with Bob's mods, the roboport interface, chips and recipes look as in 3.5.3 (the load order can change now that the stdlib2 dependency is gone).
- [ ] A tile ghost under an entity ghost waits for the entity ghost to be built first.
- [ ] A mining drill with its resources used up is marked by the `nano-signal-deconstruct-finished-miners` signal, and one with resources left is not.
- [ ] A 3.5.3 or 3.6.2 save loads; 'Resetting nano_queue' is printed once, queued items come back to the character (or lie at the job positions), and the ghosts are queued again. The cell queue is intact. Saving and loading again does not reset the queue a second time.

## Commands and saves

- [ ] `/Nanobots2 count nano_queue` and `cell_queue` print the queue sizes.
- [ ] `/Nanobots2 reset nano_queue` and `cell_queue` work with items queued. `/Nanobots2 reset mod` fully resets (admin only).
- [ ] Save, quit, load: queued work resumes with no error.
- [ ] Load a save from the previous release and confirm the migration runs.

## Remote view

Cheat mode off for all of these. First set the "Afk Timer" map setting (`nanobots-afk-time`, default 4 seconds) to 0, otherwise nanobots stop polling a player who gives no input while in the map or on a platform.

Ghost-based checks only reach the fixed code if remote-view planning finds the items (unknown, see the spec). If the ammo charge does not drop during a ghost-based check, record it as that planning limitation, not a failure. The checks marked "deciding" avoid that: they drain ammo without any item lookup, or queue the job before entering remote view. For every map-view check: equip the emitter and ammo (and chips) first, make sure nothing in range needs work, open the map, and only then run the setup command from the console while in map view. Nanobots poll a player about once a second, so setup done before opening the map would be handled in normal view and prove nothing. The "Modules" and "Map view refund spill" checks are the exception: they queue jobs in normal view on purpose (with a slow queue) and open the map before the jobs run. For all emitter checks, have no construction robots in the personal roboport, or turn the "Network limits" map setting off, otherwise scanning stops and the checks pass without running anything. The chip checks need a personal roboport with construction radius above 0, not robots.

Console setup (setup only, leave `cheat_mode` off):

- Another surface: `/c game.player.force.unlock_space_location('vulcanus'); game.planets.vulcanus.create_surface()`.
- A platform to ride: `/c local p = game.player.force.create_space_platform{name = 'test', planet = 'nauvis', starter_pack = 'space-platform-starter-pack'}; p.apply_starter_pack(); game.player.enter_space_platform(p)`. If entering fails because the platform is still being created, run `/c game.player.enter_space_platform(game.player.force.platforms[1])` a few seconds later. Carry the emitter, ammo and items in the character's inventory before entering.
- Damage your entities near the character (place at least 10 walls or other entities there first): `/c for _, e in pairs(game.player.surface.find_entities_filtered{force = game.player.force, position = game.player.character.position, radius = 6}) do if e.health and e.type ~= 'character' then e.health = 1 end end`
- Lower the character's health: `/c game.player.character.health = 50`
- Trees around the character: `/c local c = game.player.character; for i = 1, 25 do local a = i * 2 * math.pi / 25; c.surface.create_entity{name = 'tree-01', position = {c.position.x + 5 * math.cos(a), c.position.y + 5 * math.sin(a)}} end`
- Walls on a platform (run while riding it): `/c local s, c = game.player.character.surface, game.player.character.position; local n = 0; for i = -5, 5 do local e = s.create_entity{name = 'stone-wall', position = {c.x + i, c.y + 5}, force = game.player.force}; if e then e.health = 1; n = n + 1 end end; game.print(n)`. Adjust the offset so the walls land on the starter foundation; at least 10 must be created.
- An enemy nearby: `/c local c = game.player.character; c.surface.create_entity{name = 'small-biter', position = {c.position.x + 10, c.position.y}, force = 'enemy'}`

- [ ] Map view refill (repair, deciding): exactly one constructor ammo item in the emitter's ammo slot (10 charges), more constructor ammo in the main inventory, no ghosts, at least 10 damaged entities at 1 health in range. Open the map and wait (repair scans run every 3rd poll). Expect: no crash; when the slot runs out it refills from the main inventory.
- [ ] Map view empty (repair, deciding): same, with no spare ammo. Expect: no crash; the slot empties and nanobots stop.
- [ ] Map view termites (deciding): exactly one termite ammo item in the slot (20 charges), more termite ammo in the main inventory, no trees in range; open the map, then create the trees. Expect: no crash; the slot refills.
- [ ] Modules (deciding): set the "nanobots-nano-queue-rate" map setting to 600. In normal view, place a blueprint whose entities request modules, in range, with the items and modules in the inventory. Open the map before the queued jobs run and stay in it while they build. Expect: no crash (3.6.2 crashes at the module insert); modules are taken from the character's inventory. Restore the setting afterwards.
- [ ] Map view ghosts (record): one constructor ammo item in the slot, spare ammo, more than 10 buildable ghosts in range, in map view. Expect: no crash. Record whether ghosts get built and the slot refills.
- [ ] Space platform (deciding part: repair): ride a platform (setup above) with the emitter, one constructor ammo item and spare ammo; then create the damaged walls (platform command above). Expect: no crash; the slot empties and refills. Record also: with ghosts near the hub of an item only the character holds (not the hub), whether nanobots build them.
- [ ] Other surface (deciding: repair): on the other surface (setup above), at the character's coordinates, create a damaged entity of your force: `/c local s = game.surfaces.vulcanus; local p = game.player.character.position; s.request_to_generate_chunks(p, 1); s.force_generate_chunk_requests(); local e = s.create_entity{name = 'stone-wall', position = p, force = game.player.force}; if e then e.health = 1; game.print('wall ok') end` (it must print "wall ok"). Remote view that surface with constructor ammo equipped: `/c game.player.set_controller{type = defines.controllers.remote, surface = 'vulcanus', position = game.player.character.position}`, and confirm with `/c game.print(game.player.controller_type == defines.controllers.remote and game.player.surface.name)` that it prints `vulcanus`. Then, as a positive control, damage an entity of your force next to the character on its own surface (place a wall there beforehand): `/c local c = game.player.character; for _, e in pairs(c.surface.find_entities_filtered{force = game.player.force, position = c.position, radius = 6}) do if e.health and e.type ~= 'character' then e.health = 1 end end`. Wait about 10 seconds. Expect: the entity next to the character is repaired and ammo drains (proves nanobots are running). Expect: no repair projectile on vulcanus and no ammo drained for it (3.6.2 repairs it). Then confirm the wall still exists at 1 health: `/c for _, e in pairs(game.surfaces.vulcanus.find_entities_filtered{name = 'stone-wall', position = game.player.character.position, radius = 1}) do game.print(e.health) end`.
- [ ] Map view feeder chip: personal roboport with construction radius above 0, feeder chip charged, character health set to 50, fish in the inventory, in map view. Expect: no crash, a fish is used and the character's health rises. Secondary: zoomed in on the character in map view, the heal text appears at the character.
- [ ] Map view launcher chip: personal roboport with construction radius above 0, launcher chip charged, combat robot capsules in the inventory, an enemy spawned nearby, in map view. Expect: no freeze, no error; robots launch next to the character.
- [ ] Map view refund spill: set "nanobots-nano-queue-rate" to 600. Queue several ghosts, then fill the inventory completely, including topping up any partial stack of the ghosts' item. Open the map and remove a still-queued ghost, then, before its job runs (about 10 s), pan the map camera far away from the character. Expect: its items drop next to the character, not at the camera (3.6.2 drops them at the camera centre). Restore the setting afterwards.
- [ ] Record for follow-ups (unchanged from 3.6.2, not a 3.6.3 pass/fail): in map view, and on a platform where possible, (a) mark an entity, a chest holding items and a tile for deconstruction; (b) mark an entity for upgrade with the new item in the inventory; (c) place a concrete ghost over stone path (not on a platform); (d) sit in a car or train whose trunk or wagons hold the only items for a ghost; (e) ride a platform, remote view a planet, and mark an entity near the hub for deconstruction and another for upgrade. For each, note whether it happens, where the items go, and whether ammo keeps draining on something that stays marked.
- [ ] Queue reset without a character: set "nanobots-nano-queue-rate" to 600, queue several ghosts, then `/c game.player.character.die()` and, before respawning, `/Nanobots2 reset nano_queue`. Expect: no error; the queued items lie on the ground at the ghost positions. Restore the setting afterwards.
- [ ] Release build: rebuild with `NANO.DEBUG = false` in `config.lua`, repeat the "Map view refill", "Map view termites", "Modules" and "Space platform" checks. Confirm no error in chat, no line in factorio-current.log that contains `Nanobots2:` together with `failed` or an error message (covers both `Nanobots2: polling player ... failed` and the per-job `Nanobots2: <action> failed`), and for Modules that the modules are actually in the built entities.

## Later: automated tests

The FactorioTest mod can run these cases in a headless game. The manual list above is the spec to port.
