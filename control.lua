local config = require('config')
-- Protected mode swallows handler errors. Set config.DEBUG = true in test builds so they crash loudly.
require('lib/stdlib').Event.set_protected_mode(not config.DEBUG)
local Interface = require('lib/stdlib').Interface.merge_interfaces(require('interface'))
local Commands = require('commands')

local Player = require('lib/stdlib').Player.register_events(true)
require('lib/stdlib').Force.register_events(true)
require('lib/stdlib').Changes.register_events('mod_versions', 'changes/versions')

Player.additional_data({ranges = {}})

require('scripts/nanobots')
require('scripts/roboport-interface')
require('scripts/armor-mods')

require('scripts/reprogram-gui')

remote.add_interface(script.mod_name, Interface)

commands.add_command(script.mod_name, 'Nanobot commands', Commands)
