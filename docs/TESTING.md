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
- [ ] A 3.5.3 save loads, and its queues are intact.

## Commands and saves

- [ ] `/Nanobots2 count nano_queue` and `cell_queue` print the queue sizes.
- [ ] `/Nanobots2 reset nano_queue` and `cell_queue` work with items queued. `/Nanobots2 reset mod` fully resets (admin only).
- [ ] Save, quit, load: queued work resumes with no error.
- [ ] Load a save from the previous release and confirm the migration runs.

## Later: automated tests

The FactorioTest mod can run these cases in a headless game. The manual list above is the spec to port.
