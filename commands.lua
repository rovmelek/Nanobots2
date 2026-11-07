local Interface = require('interface')

--- Split on spaces, empty pieces are dropped.
local function split(text)
    local words = {}
    for word in text:gmatch('[^ ]+') do
        words[#words + 1] = word
    end
    return words
end

local function commands(event)
    -- player_index is nil for the server console and RCON, which are always allowed.
    local player = event.player_index and game.get_player(event.player_index)
    if not event.player_index or (player and player.admin) then
        local params = event.parameter and split(event.parameter) or {}
        if params[1] == 'reset' then
            if params[2] == 'mod' then
                Interface.reset_mod(true)
            elseif params[2] == 'cell_queue' then
                Interface.reset_queue('cell_queue')
            elseif params[2] == 'nano_queue' then
                Interface.reset_queue('nano_queue')
            end
        elseif params[1] == 'count' then
            Interface.count_queue(params[2])
        end
    end
end

return commands
