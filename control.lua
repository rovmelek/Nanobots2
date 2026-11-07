local config = require('config')
local Event = require('__Nanobots2__.lib.stdlib2.event')
-- Protected mode swallows handler errors. Set config.DEBUG = true in test builds so they crash loudly.
Event.set_protected_mode(not config.DEBUG)

local Player = require('__Nanobots2__.lib.stdlib2.player').register_events(true)
require('__Nanobots2__.lib.stdlib2.force').register_events(true)
require('__Nanobots2__.lib.stdlib2.changes').register_versions('changes/versions')

Player.additional_data({ranges = {}})

require('scripts/nanobots')
require('scripts/roboport-interface')
require('scripts/armor-mods')

require('scripts/reprogram-gui')

remote.add_interface(script.mod_name, require('interface'))

commands.add_command(script.mod_name, 'Nanobot commands', require('commands'))
