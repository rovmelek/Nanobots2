local Event = require('lib/stdlib').Event
local Queue = require('scripts/hash_queue')
local interface = {}

function interface.reset_mod(are_you_sure)
    local player_name = game.player and game.player.name or 'script'
    if are_you_sure then
        -- Hand back the items that are in flight before the queues are thrown away.
        interface.reset_queue('nano_queue')
        storage = {}
        Event.dispatch({name = Event.core_events.init})
        game.print('Full Reset Completed by ' .. player_name)
    else
        game.print('Full reset attempted but ' .. player_name .. ' was not sure')
    end
end

function interface.reset_queue(queue)
    queue = queue or 'nano_queue'
    local name = 'reset_' .. queue
    local id = Event.get_event_name(name)
    if storage[queue] and id then
        game.print('Resetting ' .. queue)
        Event.dispatch({name = id})
    end
end

function interface.count_queue(queue)
    queue = queue or 'nano_queue'
    if storage[queue] then
        game.print('Queued:' .. Queue.count(storage[queue]) .. ' Hashed:' .. Queue.hash_count(storage[queue]))
    end
end

return interface
