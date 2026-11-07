--- Per player data in `storage.players`, created when a player is created and removed with the player.
--- Derived from stdlib2 2.1.0 (https://github.com/rovmelek/stdlib2 @ e39ed5a): stdlib/event/player.lua,
--- stdlib/event/modules/merge_data.lua, stdlib/game.lua (get_player).
--- Copyright (c) 2016, Afforess. ISC license, see lib/stdlib2/LICENSE. Trimmed to what Nanobots2 uses.
local Event = require('__Nanobots2__.lib.stdlib2.event')
local flib_table = require('__Nanobots2__.lib.flib.table')

local Player = {}

--- Tables merged (as deep copies) into the data of every new player.
local new_player_data = {}

--- Add default fields for new players.
--- @param defaults table
--- @return table Player
function Player.additional_data(defaults)
    assert(type(defaults) == 'table', 'additional player data must be a table')
    new_player_data[#new_player_data + 1] = defaults
    return Player
end

--- @param player LuaPlayer
--- @return table
local function new(player)
    local pdata = {index = player.index, name = player.name, force = player.force.name}
    for _, defaults in ipairs(new_player_data) do
        for key, value in pairs(defaults) do
            pdata[key] = flib_table.deep_copy(value)
        end
    end
    return pdata
end

--- The player a player index, name or event refers to.
--- @param source number|string|table
--- @return LuaPlayer|nil
local function resolve(source)
    local source_type = type(source)
    if source_type == 'number' or source_type == 'string' then
        return game.get_player(source)
    elseif source_type == 'table' and source.player_index then
        return game.get_player(source.player_index)
    end
end

--- Create the data of a player, or of every player when nothing is given. Existing data is kept.
--- Used as an event handler, so it takes an event as well as an index or name.
--- @param source number|string|table|nil
--- @return table #the new data when a single player was created, else Player
function Player.init(source)
    storage.players = storage.players or {}
    local player = resolve(source)
    if player then
        if not storage.players[player.index] then
            storage.players[player.index] = new(player)
            return storage.players[player.index]
        end
    else
        for _, each in pairs(game.players) do
            if not storage.players[each.index] then
                storage.players[each.index] = new(each)
            end
        end
    end
    return Player
end

--- The player and their data, the data is created when it is missing.
--- @param index number
--- @return LuaPlayer, table
function Player.get(index)
    return game.get_player(index), storage.players and storage.players[index] or Player.init(index)
end

--- @param event table on_player_changed_force
function Player.update_force(event)
    local player, pdata = Player.get(event.player_index)
    pdata.force = player.force.name
end

--- @param event table on_player_removed
function Player.remove(event)
    if storage.players then
        storage.players[event.player_index] = nil
    end
end

--- Keep `storage.players` up to date.
--- @param do_on_init boolean also create the data of the existing players when the mod is added to a game
--- @return table Player
function Player.register_events(do_on_init)
    Event.register(defines.events.on_player_created, Player.init)
    Event.register(defines.events.on_player_changed_force, Player.update_force)
    Event.register(defines.events.on_player_removed, Player.remove)
    if do_on_init then
        Event.register(Event.core_events.init, Player.init)
    end
    return Player
end

return Player
