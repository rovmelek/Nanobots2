local config = require('config')
-- Protected mode swallows handler errors. Set config.DEBUG = true in test builds so they crash loudly.
require('__stdlib2__/stdlib/event/event').set_protected_mode(not config.DEBUG)
local Interface = require('__stdlib2__/stdlib/scripts/interface').merge_interfaces(require('interface'))
local Commands = require('commands')

local Player = require('__stdlib2__/stdlib/event/player').register_events(true)
require('__stdlib2__/stdlib/event/force').register_events(true)
require('__stdlib2__/stdlib/event/changes').register_events('mod_versions', 'changes/versions')

Player.additional_data({ranges = {}})

require('scripts/nanobots')
require('scripts/roboport-interface')
require('scripts/armor-mods')

require('scripts/reprogram-gui')

remote.add_interface(script.mod_name, Interface)

commands.add_command(script.mod_name, 'Nanobot commands', Commands)
