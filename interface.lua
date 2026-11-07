local Event = require('__Nanobots2__.lib.stdlib2.event')
local Queue = require('scripts/hash_queue')
local interface = {}

function interface.reset_mod(are_you_sure)
    local player_name = game.player and game.player.name or 'script'
    if are_you_sure then
        -- Hand back the items that are in flight before the queues are thrown away.
        interface.reset_queue('nano_queue')
        -- Clear in place, the storage global itself must not be reassigned.
        for key in pairs(storage) do
            storage[key] = nil
        end
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

--- Write the storage table to script-output/<mod name>/storage.lua, for debugging.
function interface.write_storage()
    helpers.remove_path(script.mod_name)
    helpers.write_file(script.mod_name .. '/storage.lua', serpent.block(storage, {comment = false, nocode = true, name = 'storage'}))
end

-- Kept for callers of the 1.x name.
interface.write_global = interface.write_storage

return interface
