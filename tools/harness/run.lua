-- Offline harness: loads the mod under stubs of the Factorio API and checks that it loads, that storage keeps its
-- shape across init, load and configuration changes, and that the data stage extends what it should.
-- It cannot replace the in game checks of docs/TESTING.md.
--
-- Usage, from the repository root: lua5.2 tools/harness/run.lua
local ROOT = (arg and arg[0] or 'tools/harness/run.lua'):gsub('tools/harness/run%.lua$', '')
ROOT = (ROOT == '' and '.' or ROOT:gsub('/$', ''))

local failures = 0

local function check(condition, message)
    if not condition then
        failures = failures + 1
        io.stderr:write('FAIL: ' .. message .. '\n')
    end
end

local function check_equal(actual, expected, message)
    check(actual == expected, ('%s (expected %s, got %s)'):format(message, tostring(expected), tostring(actual)))
end

local function deep_equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= 'table' then
        return a == b
    end
    for k, v in pairs(a) do
        if not deep_equal(v, b[k]) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

--- A copy without metatables that keeps shared references, like a save/load cycle.
local function strip(value, seen)
    if type(value) ~= 'table' then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[strip(k, seen)] = strip(v, seen)
    end
    return copy
end

---------------------------------------------------------------------------------------------------
-- Module loading: resolve require like Factorio does.
---------------------------------------------------------------------------------------------------

local preloaded = {}
for name in pairs(package.loaded) do
    preloaded[name] = true
end

local function read_file(path)
    local file = io.open(path, 'r')
    if file then
        file:close()
        return path
    end
end

table.insert(package.searchers, 2, function(name)
    local prefix = '__Nanobots2__'
    if name:sub(1, prefix:len() + 1):match('^__Nanobots2__[./]$') then
        local path = read_file(ROOT .. '/' .. name:sub(prefix:len() + 2):gsub('%.', '/') .. '.lua')
        return path and loadfile(path) or ('\n\tno file for ' .. name)
    elseif name:match('^__.-__') then
        return '\n\tmod not installed: ' .. name
    end
    local caller = debug.getinfo(3, 'S').source:gsub('^@', '')
    local caller_dir = caller:match('^(.*)/[^/]*$') or '.'
    local path = read_file(caller_dir .. '/' .. name .. '.lua') or read_file(ROOT .. '/' .. name .. '.lua')
    return path and loadfile(path) or ('\n\tno file for ' .. name)
end)

local function unload_mod()
    for name in pairs(package.loaded) do
        if not preloaded[name] then
            package.loaded[name] = nil
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Stubs of the Factorio API.
---------------------------------------------------------------------------------------------------

--- Tables that hand out a unique number for every key, for defines.events and friends.
local function numbering()
    local numbers, count = {}, 0
    return setmetatable({}, {
        __index = function(_, key)
            if not numbers[key] then
                count = count + 1
                numbers[key] = count
            end
            return numbers[key]
        end
    })
end

local function install_defines()
    local categories = {}
    defines = setmetatable({}, {
        __index = function(_, category)
            categories[category] = categories[category] or numbering()
            return categories[category]
        end
    })
    -- Only the data stage reads this one.
    rawset(defines, 'prototypes', {
        item = {item = 0, gun = 0, ammo = 0, capsule = 0, ['item-with-entity-data'] = 0},
        fluid = {fluid = 0}
    })
end

local messages, logs

local function compare_versions(first, second)
    local a, b = {}, {}
    first:gsub('%d+', function(n) a[#a + 1] = tonumber(n) end)
    second:gsub('%d+', function(n) b[#b + 1] = tonumber(n) end)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then
            return x < y and -1 or 1
        end
    end
    return 0
end

--- The Factorio globals of the control stage. Returns the table the stubs record into.
local function install_control_stubs()
    messages, logs = {}, {}
    local rec = {events = {}, interfaces = {}, commands = {}, files = {}, removed = {}}
    local counter = 1000

    script = {
        mod_name = 'Nanobots2',
        active_mods = {Nanobots2 = '3.6.0'},
        on_init = function(fn) rec.on_init = fn end,
        on_load = function(fn) rec.on_load = fn end,
        on_configuration_changed = function(fn) rec.on_configuration_changed = fn end,
        on_event = function(id, fn) rec.events[id] = fn end,
        generate_event_name = function()
            counter = counter + 1
            return counter
        end
    }
    settings = {
        global = setmetatable({}, {__index = function() return {value = 1} end}),
        startup = setmetatable({}, {__index = function() return {value = false} end})
    }
    remote = {
        interfaces = rec.interfaces,
        add_interface = function(name, interface) rec.interfaces[name] = interface end
    }
    commands = {add_command = function(name, _, handler) rec.commands[name] = handler end}
    log = function(message) logs[#logs + 1] = tostring(message) end
    serpent = {block = function() return 'serpent' end}
    table_size = function(t)
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end
    helpers = {
        compare_versions = compare_versions,
        write_file = function(name) rec.files[#rec.files + 1] = name end,
        remove_path = function(name) rec.removed[#rec.removed + 1] = name end
    }
    prototypes = {}
    storage = storage or {}
    game = nil
    return rec
end

local function make_player(index)
    return {index = index, name = 'player' .. index, force = {name = 'player'}, afk_time = 0, valid = true}
end

--- The `game` global, installed only around calls that run with a game, like Factorio does.
local function install_game(players)
    local connected = {}
    for _, player in pairs(players) do
        connected[#connected + 1] = player
    end
    game = {
        tick = 0,
        players = players,
        connected_players = connected,
        forces = {player = {name = 'player', valid = true}},
        get_player = function(index) return players[index] end,
        print = function(message) messages[#messages + 1] = tostring(message) end
    }
end

local function expect_messages(patterns, context)
    local remaining = {}
    for _, message in ipairs(messages) do
        local matched = false
        for _, pattern in ipairs(patterns) do
            if message:find(pattern, 1, true) then
                matched = true
            end
        end
        if not matched then
            remaining[#remaining + 1] = message
        end
    end
    check(#remaining == 0, context .. ': unexpected game.print messages: ' .. table.concat(remaining, ' | '))
    messages = {}
end

local function load_control()
    unload_mod()
    local rec = install_control_stubs()
    require('config').DEBUG = true
    dofile(ROOT .. '/control.lua')
    return rec
end

local function log_index(text)
    for i, entry in ipairs(logs) do
        if entry:find(text, 1, true) then
            return i
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Control stage.
---------------------------------------------------------------------------------------------------

local function run_control_stage()
    install_defines()
    storage = {}
    local players = {[1] = make_player(1)}
    local rec = load_control()
    check(rec.on_init and rec.on_load and rec.on_configuration_changed, 'control: bootstrap events are hooked')
    check(rec.interfaces.Nanobots2 ~= nil, 'control: remote interface registered')
    check(rec.commands.Nanobots2 ~= nil, 'control: command registered')
    check(rec.interfaces.Nanobots2.dump_all == nil, 'control: stdlib debug functions are gone from the interface')

    -- on_init: every storage key is created.
    install_game(players)
    rec.on_init()
    check(deep_equal(storage.players[1], {index = 1, name = 'player1', force = 'player', ranges = {}}), 'init: player data shape')
    check(deep_equal(storage.forces.player, {index = 'player', name = 'player'}), 'init: force data shape')
    check_equal(storage._changes['1.8.2'], '3.6.0', 'init: 1.8.2 marked as done')
    check_equal(storage._changes['1.8.7'], '3.6.0', 'init: 1.8.7 marked as done')
    check_equal(storage._changes['3.5.0'], '3.6.0', 'init: 3.5.0 marked as done')
    check(storage.nano_queue and storage.nano_queue._hash and storage.nano_queue._count == 0, 'init: nano queue shape')
    check(storage.cell_queue and storage.cell_queue._hash and storage.cell_queue._count == 0, 'init: cell queue shape')
    expect_messages({'Nanobots are now ready to serve'}, 'init')

    -- Player and force events.
    local events = defines.events
    players[2] = make_player(2)
    rec.events[events.on_player_created]({name = events.on_player_created, player_index = 2})
    check(storage.players[2] and storage.players[2].name == 'player2', 'player created: data added')
    check(storage.players[2].ranges ~= storage.players[1].ranges, 'player created: defaults are deep copies')
    players[2].force = {name = 'enemy'}
    rec.events[events.on_player_changed_force]({name = events.on_player_changed_force, player_index = 2})
    check_equal(storage.players[2].force, 'enemy', 'player changed force: force updated')
    rec.events[events.on_player_removed]({name = events.on_player_removed, player_index = 2})
    check_equal(storage.players[2], nil, 'player removed: data removed')
    players[2] = nil
    local new_force = {name = 'rebels', valid = true}
    game.forces.rebels = new_force
    rec.events[events.on_force_created]({name = events.on_force_created, force = new_force})
    check(deep_equal(storage.forces.rebels, {index = 'rebels', name = 'rebels'}), 'force created: data added')
    rec.events[events.on_forces_merged]({name = events.on_forces_merged, source_name = 'rebels'})
    check_equal(storage.forces.rebels, nil, 'forces merged: data removed')

    -- Commands and the remote interface.
    local command = rec.commands.Nanobots2
    command({parameter = 'count  nano_queue'})
    command({parameter = 'reset nano_queue'})
    command({parameter = 'reset cell_queue'})
    expect_messages({'Queued:', 'Resetting nano_queue', 'Resetting cell_queue'}, 'commands')
    local before = storage
    command({parameter = 'reset mod'})
    check(storage == before, 'reset mod: the storage table is cleared in place')
    check(storage.players and storage.players[1] and storage.nano_queue and storage.cell_queue, 'reset mod: init ran again')
    expect_messages({'Resetting nano_queue', 'Full Reset Completed', 'Nanobots are now ready to serve'}, 'reset mod')
    rec.interfaces.Nanobots2.write_storage()
    check_equal(rec.files[1], 'Nanobots2/storage.lua', 'write_storage writes the storage file')

    -- Save and load: metatables are lost, on_load must restore the queues and write nothing.
    local Queue = require('scripts/hash_queue')
    local ran = 0
    Queue.insert(storage.nano_queue, {entity = {unit_number = 5}, action = 'harness_job'}, 10)
    storage = strip(storage)
    local snapshot = strip(storage)
    game = nil
    rec = load_control()
    rec.on_load()
    check(deep_equal(storage, snapshot), 'on_load: storage was not written')
    for _, name in ipairs({'nano_queue', 'cell_queue'}) do
        local meta = getmetatable(storage[name])
        check(meta and meta.__index == package.loaded['scripts/hash_queue'], 'on_load: ' .. name .. ' metatable restored')
        check(meta and next(meta.handlers) ~= nil, 'on_load: ' .. name .. ' has handlers')
    end
    install_game(players)
    getmetatable(storage.nano_queue).handlers.harness_job = function() ran = ran + 1 end
    rec.events[events.on_tick]({name = events.on_tick, tick = 10})
    check_equal(ran, 1, 'on_tick after on_load: a job queued before the save ran')
    expect_messages({}, 'on_tick')

    -- Configuration change from an old save: pending migrations run in version order.
    storage._changes = {['1.8.2'] = '3.5.3'}
    storage.nano_queue._count = nil
    logs = {}
    rec.on_configuration_changed({mod_changes = {Nanobots2 = {old_version = '3.5.3', new_version = '3.6.0'}}})
    local first, second = log_index('Migration completed for version 1.8.7'), log_index('Migration completed for version 3.5.0')
    check(first and second and first < second, 'configuration changed: 1.8.7 then 3.5.0 ran in order')
    check_equal(log_index('Migration completed for version 1.8.2'), nil, 'configuration changed: 1.8.2 did not run again')
    check_equal(storage._changes['1.8.7'], '3.6.0', 'configuration changed: 1.8.7 marked')
    check_equal(storage._changes['3.5.0'], '3.6.0', 'configuration changed: 3.5.0 marked')
    check(type(storage.nano_queue._count) == 'number' and storage.nano_queue._hash, 'configuration changed: queue shape rebuilt')
    expect_messages({'Resetting cell_queue'}, 'configuration changed')

    -- A mod change that is not ours does nothing.
    storage._changes = {}
    rec.on_configuration_changed({mod_changes = {SomeOtherMod = {old_version = '1.0.0', new_version = '1.0.1'}}})
    check(next(storage._changes) == nil, 'configuration changed: other mods are ignored')
    expect_messages({}, 'configuration changed (other mod)')
end

--- Migrations must run in version order, which neither pairs() order nor string order gives for these versions.
local function run_changes_checks()
    install_defines()
    storage = {}
    install_control_stubs()
    unload_mod()
    local ran = {}
    local function migration(version)
        return function() ran[#ran + 1] = version end
    end
    package.loaded['harness/versions'] = {
        ['10.0.0'] = migration('10.0.0'),
        ['9.0.0'] = migration('9.0.0'),
        ['1.10.0'] = migration('1.10.0'),
        ['1.9.0'] = migration('1.9.0')
    }
    local rec = install_control_stubs()
    local Changes = require('__Nanobots2__.lib.stdlib2.changes')
    Changes.register_versions('harness/versions')
    install_game({[1] = make_player(1)})
    storage._changes = {}
    rec.on_configuration_changed({mod_changes = {Nanobots2 = {old_version = '0.1.0', new_version = '11.0.0'}}})
    check_equal(table.concat(ran, ','), '1.9.0,1.10.0,9.0.0,10.0.0', 'changes: migrations run in version order')
    check_equal(storage._changes['10.0.0'], '11.0.0', 'changes: the last migration is marked')
    ran = {}
    rec.on_configuration_changed({mod_changes = {Nanobots2 = {old_version = '11.0.0', new_version = '11.0.1'}}})
    check_equal(#ran, 0, 'changes: migrations that ran are not run again')
    expect_messages({}, 'changes')
end

local function run_event_checks()
    install_defines()
    storage = {}
    install_control_stubs()
    unload_mod()
    local Event = require('__Nanobots2__.lib.stdlib2.event')
    install_game({[1] = make_player(1)})

    local id = Event.generate_event_name('harness')
    check_equal(Event.get_event_name('harness'), id, 'event: custom id is remembered')
    check_equal(Event.generate_event_name('harness'), id, 'event: custom id is generated once')

    local order = {}
    local function first() order[#order + 1] = 'first' end
    local function second() order[#order + 1] = 'second' end
    Event.register(id, first)
    Event.register(id, second)
    Event.register(id, first) -- moves to the end
    Event.dispatch({name = id})
    check_equal(table.concat(order, ','), 'second,first', 'event: handlers run in order, a repeated handler moves to the end')

    local ran = false
    Event.register(id, function() ran = true end)
    Event.dispatch({name = id, entity = {__self = true, valid = false}})
    check(not ran, 'event: an invalid object stops the handlers')

    Event.set_protected_mode(true)
    Event.register(id, function() error({}) end)
    messages = {}
    Event.dispatch({name = id})
    check_equal(#messages, 1, 'event: protected mode prints the error, even a non string one')
    messages = {}
    game.connected_players = {}
    check(not pcall(Event.dispatch, {name = id}), 'event: protected mode raises when nobody can read the error')
    Event.set_protected_mode(false)
    game.connected_players = {make_player(1)}
    check(not pcall(Event.dispatch, {name = id}), 'event: unprotected errors are raised')
    check(not pcall(Event.register, 'not_an_event', first), 'event: unknown string ids are rejected')
    messages = {}
end

---------------------------------------------------------------------------------------------------
-- Data stage.
---------------------------------------------------------------------------------------------------

local function deep_copy(value)
    if type(value) ~= 'table' then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deep_copy(v)
    end
    return copy
end

local function new_data(raw)
    local data = {raw = raw}
    function data:extend(prototypes)
        for _, prototype in ipairs(prototypes) do
            assert(prototype.type and prototype.name, 'prototype needs type and name')
            self.raw[prototype.type] = self.raw[prototype.type] or {}
            self.raw[prototype.type][prototype.name] = prototype
        end
    end
    return data
end

local function base_raw()
    local raw = {
        technology = {
            ['personal-roboport-equipment'] = {type = 'technology', name = 'personal-roboport-equipment', effects = {}}
        },
        ['constant-combinator'] = {
            ['constant-combinator'] = {
                type = 'constant-combinator',
                name = 'constant-combinator',
                minable = {mining_time = 0.1, result = 'constant-combinator'},
                sprites = {},
                activity_led_sprites = {},
                activity_led_light_offsets = {},
                circuit_wire_connection_points = {}
            }
        },
        radar = {
            radar = {type = 'radar', name = 'radar', minable = {mining_time = 0.1, result = 'radar'}, next_upgrade = 'x'}
        },
        shortcut = {
            ['toggle-personal-roboport'] = {type = 'shortcut', name = 'toggle-personal-roboport', technology_to_unlock = 'construction-robotics'}
        },
        item = {
            ['electronic-circuit'] = {type = 'item', name = 'electronic-circuit'},
            roboport = {type = 'item', name = 'roboport'}
        },
        fluid = {}
    }
    return raw
end

local function run_data_stage(options)
    unload_mod()
    install_defines()
    -- The data stage has none of the control stage globals.
    script, game, storage, remote, commands, helpers, prototypes, serpent, table_size = nil, nil, nil, nil, nil, nil, nil, nil, nil
    local raw = base_raw()
    for name in pairs(options.items or {}) do
        raw.item[name] = {type = 'item', name = name}
    end
    data = new_data(raw)
    table.deepcopy = deep_copy
    mods = options.mods
    logs = {}
    log = function(message) logs[#logs + 1] = tostring(message) end
    settings = {startup = {}}
    for key, value in pairs(options.settings or {}) do
        settings.startup[key] = {value = value}
    end
    dofile(ROOT .. '/data.lua')
    dofile(ROOT .. '/data-updates.lua')
    return raw
end

local function ingredient(raw, recipe, name)
    for _, entry in ipairs(raw.recipe[recipe].ingredients) do
        if entry.name == name then
            return entry
        end
    end
end

local function run_data_stage_checks()
    -- Plain game.
    local raw = run_data_stage({mods = {}})
    local cc, scanner = raw['constant-combinator']['roboport-interface-cc'], raw.radar['roboport-interface-scanner']
    check(cc and scanner, 'data: roboport interface parts exist')
    check(cc and cc.minable == nil and cc.placeable_by == nil, 'data: the combinator copy has no minable or placeable_by')
    check(scanner and scanner.minable == nil and scanner.placeable_by == nil, 'data: the scanner copy has no minable or placeable_by')
    check(scanner and scanner.next_upgrade == nil and scanner.hidden == true, 'data: scanner edits applied')
    check(raw['constant-combinator']['constant-combinator'].sprites.north == nil, 'data: the base combinator is untouched')
    check(cc and cc.sprites.north and cc.sprites.north.filename == '__core__/graphics/empty.png', 'data: empty sprites used')
    check(raw.roboport and raw.roboport['roboport-interface-main'], 'data: roboport interface entity exists')
    check(raw.recipe['roboport-interface'].enabled == false, 'data: the interface recipe starts disabled')
    local unlocked = false
    for _, effect in ipairs(raw.technology['roboport-interface'].effects) do
        unlocked = unlocked or (effect.type == 'unlock-recipe' and effect.recipe == 'roboport-interface')
    end
    check(unlocked, 'data: the interface technology unlocks the recipe')
    check_equal(raw.shortcut['toggle-personal-roboport'].technology_to_unlock, 'nanobots', 'data: shortcuts need the nanobots technology')
    for _, chip in ipairs({'items', 'trees', 'launcher', 'nanointerface', 'feeder'}) do
        local name = 'equipment-bot-chip-' .. chip
        check(raw['active-defense-equipment'][name] and raw.item[name] and raw.recipe[name], 'data: ' .. name .. ' exists')
        check(raw['active-defense-equipment']['picker-disabled-' .. name] == nil, 'data: no disabled copy without PickerInventoryTools')
    end
    check(raw.sound['nano-sound-build-tiles'] ~= nil, 'data: sound exists')

    -- Bob's mods and PickerInventoryTools.
    raw = run_data_stage({
        mods = {boblibrary = true, PickerInventoryTools = true},
        settings = {['bobmods-logistics-disableroboports'] = true},
        items = {
            ['bob-basic-circuit-board'] = true,
            ['bob-robot-brain'] = true,
            ['bob-logistic-zone-expander'] = true
            -- bob-robot-brain-combat is missing on purpose: that ingredient has to be skipped
        }
    })
    local entry = ingredient(raw, 'gun-nano-emitter', 'bob-basic-circuit-board')
    check(entry and entry.type == 'item' and entry.amount == 2, "bob: the circuit board replaces the circuit and keeps the amount")
    check(ingredient(raw, 'gun-nano-emitter', 'electronic-circuit') == nil, 'bob: the old ingredient is gone')
    entry = ingredient(raw, 'roboport-interface', 'bob-logistic-zone-expander')
    check(entry and entry.amount == 1, 'bob: the roboport is replaced when the startup setting is on')
    check(ingredient(raw, 'equipment-bot-chip-items', 'bob-robot-brain') ~= nil, 'bob: robot brain added')
    check(ingredient(raw, 'equipment-bot-chip-nanointerface', 'gun-nano-emitter') ~= nil, 'bob: the nano gun is an ingredient of the interface chip')
    check_equal(#raw.recipe['equipment-bot-chip-launcher'].ingredients, 2, 'bob: a missing item is skipped')
    check(log_index('Ingredient not found: bob-robot-brain-combat') ~= nil, 'bob: the skip is logged')
    local disabled = raw['active-defense-equipment']['picker-disabled-equipment-bot-chip-items']
    check(disabled and disabled.name == 'picker-disabled-equipment-bot-chip-items' and disabled.localised_name, 'picker: disabled copy exists')
    check(raw.shortcut['toggle-equipment-bot-chip-items'] ~= nil, 'picker: shortcut exists')

    -- Without the setting the roboport stays.
    raw = run_data_stage({mods = {boblibrary = true}, items = {['bob-basic-circuit-board'] = true, ['bob-logistic-zone-expander'] = true}})
    check(ingredient(raw, 'roboport-interface', 'roboport') ~= nil, 'bob: the roboport stays without the startup setting')
end

run_control_stage()
run_event_checks()
run_changes_checks()
run_data_stage_checks()

if failures > 0 then
    io.stderr:write(('%d check(s) failed\n'):format(failures))
    os.exit(1)
end
print('harness: all checks passed')
