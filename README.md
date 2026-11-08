# Nanobots2

## About this fork

Nanobots2 is a fork of [**Nanobots**](https://github.com/Nexela/Nanobots) ([mod portal](https://mods.factorio.com/mod/Nanobots)) by Nicholas "Nexela" Dunn, the original author of this mod and of nearly all of its design and code. Thank you, Nexela.

- Factorio 2.0 port and the rename to Nanobots2: Jackie Mueller ([jackiepmueller/Nanobots2](https://github.com/jackiepmueller/Nanobots2), the upstream of this fork).
- 2.0 gameplay fixes (iron stick unlock, repair pack prerequisite, cliff deconstruction with Nano Explosives): Ricardo Gonçalves.
- Fix for Factorio 2.0.33+ (bundles a graphic the game removed): artanin.
- This fork ports the mod to Factorio 2.1 and removes its dependencies on other mods: it needs only the base game. flib v0.17.2 (MIT) and a trimmed stdlib2 (ISC) are included in `lib/`, and the dead PickerAtheneum dependency is gone. See [Third-party code](#third-party-code) and [changelog.txt](changelog.txt).
- All contributors: <https://github.com/rovmelek/Nanobots2/graphs/contributors>

## Robot enhancements from the start of the game

Learn how to create powerful but consumable robots after learning automation. Get up and running fast by using these robots to help you build your way up to Roboports and even smarter robots. Add modules to your power armor to reprogram your personal roboport to complete mundane tasks automatically. Place roboport interfaces to have your logistic networks perform tasks while you are away.

### Nanobots

- Pre bot version of ghost building construction bots. Allows researching automated construction earlier (for blueprints etc).
- Equip the Nano Emitter and some Nano ammo, make it your selected gun and any ghosts/blueprints within 7.5 tiles of you will be automatically built if you have the items in your inventory.
- Technologies exist to slightly increase the range and speed of your nanobots.
- These earlier version bots are capable of building, deconstructing and healing. They do not replenish (each Ammo magazine will build 10 items)
- Nanobots do not work inside logistic networks that contain construction robots, or personal roboport zones without an interface module installed in your power armor.
- Manually shooting nanobots releases a pretty cloud of nanobots and nothing else. This is a good way to waste nanobots.

### Ammo Details

- Nano Constructors - These nanobots will revive ghosts in their range, heal damaged structures, and deconstruct marked items.
- Nano Termites - These nanobots will kill off trees. This process causes the tree to topple over and may damage nearby structures.

--------------------------------------------------------------------------------

#### Modular Armor Equipment

Reprogram your personal roboport to do a lot of the mundane tasks for you. Most modules require an active personal roboport and construction bots to fully work.

- Adds new equipment pieces for your power armor that will enhance your late game experience.
- The item retriever module will mark all items on the ground (artifacts, etc) in your personal roboport construction range for deconstruction as long as no enemies are around.
- The tree cutter module will mark all trees within your personal roboport range for deconstruction.
- The unit launcher module will launch Destroys/Defenders/Distractors when enemies get inside your roboport range.
- The feeder will automatically heal you when you are low on health. For a bigger healing bonus keep a stack of healing capsules in your inventory.
- The Belt Immunity chip stops belts from moving you around.
- The Nano interface will allow your nanobots to work even while you are inside logistic networks.

--------------------------------------------------------------------------------

#### Roboport Interface

The roboport interface allows you to program your logistic networks to do mundane tasks for you. Place a Roboport interface and set virtual signals on the built in combinator. If there are enemies in the construction zone your robots will not execute these tasks. Only up to half of your available construction bots will be uses for these tasks.

- Find items: Will scan for any items on the ground in your network and order your construction robots to pick them up.
- Chop trees: Scan for any trees in range and chop them up. Setting this to a negative symbol will only chop trees if you have less than that amount of raw wood in the network.
- Gather fish: Sends your construction robots on a fishing expedition. Set to a negative amount to only fish if there is less then that amount in the network.
- Roboport only: Set this signal to only run this scanner in the nearest roboports zone and not the whole network.
- (Not implemented yet): Unit launcher: Launch units to defend against biter attacks. Attach a chest to the scanner combinator and any robots inside this chest will be used for defensive purposes.

--------------------------------------------------------------------------------

#### Future Plans and Known issues

- Better graphics for the roboport interface
- More power armor equipment modules
- More roboport interface logic
- Even more script optimization's
- Found a bug? Report it here: <https://github.com/rovmelek/Nanobots2/issues>

#### Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for style and tooling and [docs/TESTING.md](docs/TESTING.md) for the manual test checklist. `tools/package.sh` builds the release zip.

#### Third-party code

Nanobots2 needs only the base game. It includes, with their licenses:

- [flib](https://codeberg.org/raiguard/flib) by raiguard (MIT), unchanged, in `lib/flib`, see [lib/flib/LICENSE](lib/flib/LICENSE).
- Parts of [stdlib2](https://github.com/rovmelek/stdlib2) (ISC, Copyright (c) 2016, Afforess), trimmed, in `lib/stdlib2`, see [lib/stdlib2/LICENSE](lib/stdlib2/LICENSE).

#### Many thanks to

- Articulating for his help and Ideas
- TokMor for a lot of extensive bug testing
- M16 for breaking things
- Wube and The Factorio development team
- KatherineOfSky, Arumba, Momentary Flux (and All other youtubers Showing off the Nanobots.)
- Xterminator and his Nanobots spotlight. <https://www.youtube.com/watch?v=sh_oIgUMfV4>
- And you as an everyday user of Nanobots.

#### License

MIT, Copyright (c) 2017 Nicholas "Nexela" Dunn. See [LICENSE](LICENSE). The code in `lib/` keeps its own licenses.
