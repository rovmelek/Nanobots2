--- Event dispatcher: several handlers per event, optional protected mode, bootstrap events and custom event ids.
--- Derived from stdlib2 2.1.0 (https://github.com/rovmelek/stdlib2 @ e39ed5a): stdlib/event/event.lua, stdlib/core.lua
--- (log_and_print), stdlib/utils/is.lua (Object).
--- Copyright (c) 2016, Afforess. ISC license, see lib/stdlib2/LICENSE. Trimmed to what Nanobots2 uses.
---
--- Use `Event.register` for every event of the mod and never mix it with `script.on_event`, the dispatcher owns the
--- Factorio side of each event it registers.
local Event = {
    registry = {}, -- event id -> array of handlers, in registration order
    custom_events = {} -- custom event name -> generated event id
}

Event.core_events = {
    init = 'on_init',
    load = 'on_load',
    configuration_changed = 'on_configuration_changed',
    on_init = 'on_init',
    on_load = 'on_load',
    on_configuration_changed = 'on_configuration_changed'
}

local protected_mode = false

--- Print an error to the players and the log. Returns false when nobody was there to read it.
--- @param msg any
--- @return boolean
local function log_and_print(msg)
    msg = tostring(msg)
    if game and #game.connected_players > 0 then
        log(script.mod_name .. ':' .. msg)
        game.print(msg)
        return true
    end
    log(msg)
    return false
end

--- Is this value a Factorio object (LuaObjects are userdata in 2.x)?
local function is_object(value)
    return type(value) == 'userdata' or (type(value) == 'table' and value.__self ~= nil)
end

--- Call the handlers registered for an event, in order.
--- Stops when the event holds an object that became invalid, like Factorio does between handlers.
--- Handler errors are logged instead of raised when protected mode is on, bootstrap events are never protected.
--- @param event table must have `name`
function Event.dispatch(event)
    if type(event) ~= 'table' then
        error('missing event table')
    end
    local registry = Event.registry[event.name]
    if not registry then
        return
    end
    event.tick = event.tick or (game and game.tick) or 0
    local bootstrap = Event.core_events[event.name] ~= nil
    for _, handler in ipairs(registry) do
        for _, value in pairs(event) do
            if is_object(value) and not value.valid then
                return
            end
        end
        if protected_mode and not bootstrap then
            local ok, err = pcall(handler, event)
            if not ok and not log_and_print(err) then
                -- Nobody to tell, raise it so the error is not lost.
                error(err)
            end
        else
            handler(event)
        end
    end
end

--- The Factorio side of the three bootstrap events.
local bootstrap_hooks = {
    on_init = function()
        script.on_init(function()
            Event.dispatch({name = 'on_init'})
        end)
    end,
    on_load = function()
        script.on_load(function()
            Event.dispatch({name = 'on_load', tick = -1})
        end)
    end,
    on_configuration_changed = function()
        script.on_configuration_changed(function(event)
            event.name = 'on_configuration_changed'
            Event.dispatch(event)
        end)
    end
}

--- Add a handler to one or more events. Handlers run in registration order.
--- Registering a handler again for the same event moves it to the end.
--- @param event_id defines.events|string|(defines.events|string)[] an event, a generated custom id, a bootstrap name, or a list of them
--- @param handler fun(event: table)
--- @return table Event
function Event.register(event_id, handler)
    assert(event_id, 'missing event_id argument')
    assert(type(handler) == 'function', 'handler must be a function')

    if type(event_id) == 'table' then
        for _, id in pairs(event_id) do
            Event.register(id, handler)
        end
        return Event
    end

    local registry = Event.registry[event_id]
    if not registry then
        registry = {}
        Event.registry[event_id] = registry
        if type(event_id) == 'string' then
            local hook = bootstrap_hooks[event_id]
            assert(hook, 'unknown event name: ' .. event_id)
            hook()
        else
            script.on_event(event_id, Event.dispatch)
        end
    end

    for i, registered in ipairs(registry) do
        if registered == handler then
            table.remove(registry, i)
            log(('__%s__ Duplicate handler registered for event %s at position %d, moving it to the bottom.'):format(
                script.mod_name, tostring(event_id), i))
            break
        end
    end
    registry[#registry + 1] = handler
    return Event
end

--- Turn protected mode on or off. On, handler errors are logged and the game goes on. Off, they stop the game.
--- @param enabled boolean
--- @return table Event
function Event.set_protected_mode(enabled)
    protected_mode = enabled and true or false
    return Event
end

--- The id of a custom event, generated the first time it is asked for.
--- @param name string
--- @return defines.events
function Event.generate_event_name(name)
    assert(type(name) == 'string', 'event name must be a string')
    local id = Event.custom_events[name]
    if not id then
        id = script.generate_event_name()
        Event.custom_events[name] = id
    end
    return id
end

--- The id of a custom event, or nil when it was never generated.
--- @param name string
--- @return defines.events|nil
function Event.get_event_name(name)
    assert(type(name) == 'string', 'event name must be a string')
    return Event.custom_events[name]
end

return Event
