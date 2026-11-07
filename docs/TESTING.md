# Manual test checklist

Nothing in the 2.x port has automated coverage yet, so run this list in game before a release.

## Setup

1. Set `NANO.DEBUG = true` in `config.lua`. This turns off stdlib protected mode, so any script error stops the game with a stack trace instead of being hidden. Set it back to `false` before releasing.
2. Start a new game with Space Age enabled (quality needs it). Enable the console and cheats (`/c game.player.cheat_mode = false` keeps the normal item flow, which is what you want for most cases).
3. Research Nanobots and the three range and speed techs. Craft the nano emitter and constructor ammo, equip them.
4. Run `luacheck .` and confirm it is clean.

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
- [ ] Feeder chip feeds the nano emitter and the player (food from the allowed list).
- [ ] Launcher chip launches combat robots.
- [ ] Nano interface chip lets nanobots work inside a roboport network.
- [ ] The reprogram GUI changes the radius for each ammo type and respects the maximum from research.

## Roboport interface

Build the interface inside a roboport network that has construction bots. Set one signal at a time in its constant combinator.

- [ ] `nano-signal-chop-trees` marks trees in each cell.
- [ ] `nano-signal-item-on-ground` marks items on the ground.
- [ ] `nano-signal-deconstruct-finished-miners` marks drills with no resources left.
- [ ] `nano-signal-catch-fish` marks fish.
- [ ] `nano-signal-closest-roboport` limits the work to the attached cell.
- [ ] A negative signal value only acts while the network holds more than that amount of the item.
- [ ] The interface can be blueprinted and rebuilt, and its parts die and are removed with it.

## Commands and saves

- [ ] `/Nanobots2 count nano_queue` and `cell_queue` print the queue sizes.
- [ ] `/Nanobots2 reset nano_queue` and `cell_queue` work with items queued.
- [ ] Save, quit, load: queued work resumes with no error.
- [ ] Load a save from the previous release and confirm the migration runs.

## Later: automated tests

The FactorioTest mod can run these cases in a headless game. The manual list above is the spec to port.
