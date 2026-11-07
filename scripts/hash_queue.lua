local table = require('__stdlib2__/stdlib/utils/table')

local function NtoZ_c(x, y)
    return (x >= 0 and x or (-0.5 - x)), (y >= 0 and y or (-0.5 - y))
end

local function cantorPair_v7(pos)
    local x, y = NtoZ_c(math.floor(pos.x), math.floor(pos.y))
    local s = x + y
    local h = s * (s + 0.5) + x
    return h + h
end

local Queue = {}

--- Count the ticks that have work queued, by walking the queue.
local function count_ticks(t)
    local count = 0
    for index in pairs(t) do
        if type(index) == 'number' then
            count = count + 1
        end
    end
    return count
end

--- Create a queue, or re-attach the metatable to a queue loaded from storage.
--- The handlers (action name to function) are code, so they live in the metatable and not in storage.
--- @param t table|nil the queue table from storage
--- @param handlers table<string, fun(data: table)>|nil
function Queue.new(t, handlers)
    local mt = {__index = Queue, handlers = handlers or {}}
    if t and t._hash then
        -- Never write to the table here, Queue.new runs in on_load where storage is read only.
        return setmetatable(t, mt)
    else
        return setmetatable({_hash = {}, _count = 0}, mt)
    end
end

function Queue.set_hash(t, data)
    local index = data.entity.unit_number or cantorPair_v7(data.entity.position)
    local hash = t._hash
    hash[index] = hash[index] or {}
    hash[index][data.action] = data.action
    return index
end

--- The number of ticks that have work queued, kept as a running counter so this is O(1).
function Queue.count(t)
    return t._count or count_ticks(t)
end

--- Store the running counter. Queues saved before it existed get it from the 3.5.0 migration, the first insert
--- also does it. Must not be called from on_load.
function Queue.rebuild_count(t)
    t._count = count_ticks(t)
    return t._count
end

--- The number of distinct entities with work queued. Walks the hash, meant for diagnostics only.
function Queue.hash_count(t)
    return table.size(t._hash)
end

function Queue.get_hash(t, entity)
    local index = entity.unit_number or cantorPair_v7(entity.position)
    return t._hash[index]
end

function Queue.insert(t, data, tick, count)
    data.hash = Queue.set_hash(t, data)

    if not t._count then
        Queue.rebuild_count(t)
    end
    if not t[tick] then
        t[tick] = {}
        t._count = t._count + 1
    end
    t[tick][#t[tick] + 1] = data

    return t, count
end

function Queue.next(t, next_tick_hint, tick_spacing, dont_combine)
    tick_spacing = tick_spacing or 1
    local count = 0
    local tick = (next_tick_hint and next_tick_hint >= game.tick and next_tick_hint) or game.tick
    local next_tick = function(really_dont_combine)
        tick = tick + tick_spacing
        while (dont_combine or really_dont_combine) and t[tick] do
            tick = tick + 1
        end
        count = count + 1
        return tick, count
    end
    local queue_count = function(num)
        count = count + (num or 0)
        return count
    end
    return next_tick, queue_count
end

--Tick handler, handles executing multiple data tables in a queue
function Queue.execute(t, event)
    local jobs = t[event.tick]
    if jobs then
        -- Take the jobs off the queue before running them. Handlers raise events, and a reset from one of those
        -- must not find jobs that already ran.
        t[event.tick] = nil
        t._count = t._count and (t._count - 1) or count_ticks(t)
        local handlers = getmetatable(t).handlers
        for _, data in ipairs(jobs) do
            local index = data.hash
            local handler = handlers[data.action]
            if handler then
                handler(data)
            else
                log('Nanobots2: queued action has no handler and was skipped: ' .. tostring(data.action))
            end
            local hashed = t._hash[index]
            if hashed then
                hashed[data.action] = nil
                if next(hashed) == nil then
                    t._hash[index] = nil
                end
            end
        end
    end
    return t
end

local mt = {
    __call = function(_, ...)
        return Queue.new(...)
    end
}

return setmetatable(Queue, mt)
