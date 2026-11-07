--- Per force data in `storage.forces`, created when a force is created and removed when it is merged away.
--- Derived from stdlib2 2.1.0 (https://github.com/rovmelek/stdlib2 @ e39ed5a): stdlib/event/force.lua,
--- stdlib/game.lua (get_force).
--- Copyright (c) 2016, Afforess. ISC license, see lib/stdlib2/LICENSE. Trimmed to what Nanobots2 uses.
local Event = require('__Nanobots2__.lib.stdlib2.event')

local Force = {}

--- The force a LuaForce, force name or event refers to.
--- @param source LuaForce|string|table
--- @return LuaForce|nil
local function resolve(source)
    local source_type = type(source)
    if source_type == 'userdata' then
        return source.valid and source or nil
    elseif source_type == 'string' then
        return game.forces[source]
    elseif source_type == 'table' and source.force then
        return resolve(source.force)
    end
end

--- Create the data of a force, or of every force when nothing is given. Existing data is kept.
--- Used as an event handler, so it takes an event as well as a force or its name.
--- @param source LuaForce|string|table|nil
function Force.init(source)
    storage.forces = storage.forces or {}
    local force = resolve(source)
    if force then
        if not storage.forces[force.name] then
            storage.forces[force.name] = {index = force.name, name = force.name}
        end
    else
        for name in pairs(game.forces) do
            if not storage.forces[name] then
                storage.forces[name] = {index = name, name = name}
            end
        end
    end
end

--- @param event table on_forces_merged
function Force.merged(event)
    if storage.forces then
        storage.forces[event.source_name] = nil
    end
end

--- Keep `storage.forces` up to date.
--- @param do_on_init boolean also create the data of the existing forces when the mod is added to a game
--- @return table Force
function Force.register_events(do_on_init)
    Event.register(defines.events.on_force_created, Force.init)
    Event.register(defines.events.on_forces_merged, Force.merged)
    if do_on_init then
        Event.register(Event.core_events.init, Force.init)
    end
    return Force
end

return Force
