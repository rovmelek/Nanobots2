local changes = {}

local interface = require('interface')
local Queue = require('scripts/hash_queue')

changes['1.8.2'] = function()
    interface.reset_queue('nano_queue')
end

changes['1.8.7'] = function()
    interface.reset_queue('cell_queue')
end

changes['3.5.0'] = function()
    -- Queues now keep a running count of their queued ticks.
    for _, name in pairs {'nano_queue', 'cell_queue'} do
        local saved = storage[name]
        if saved and saved._hash then
            Queue.rebuild_count(saved)
        end
    end
end

changes['3.6.3'] = function()
    -- 3.6.2 could strand nano jobs on a polling error (their tick was never executed and their hashes stayed set).
    -- Reset the queue once: queued items go back to their character, or are dropped where the job was.
    interface.reset_queue('nano_queue')
end

return changes
