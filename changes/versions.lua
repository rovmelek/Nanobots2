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

return changes
