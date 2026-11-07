--- The one place the control stage reaches into stdlib2. Every other file asks this module for what it needs, so
--- renaming the library (the fork still shares its name with the portal mod) is a change to PREFIX and info.json.
---
--- Modules are loaded on first use, so the order they load in stays the same as when each file required them itself.
local PREFIX = '__stdlib2__/stdlib/'

local paths = {
    Event = 'event/event',
    Player = 'event/player',
    Force = 'event/force',
    Changes = 'event/changes',
    Interface = 'scripts/interface',
    Area = 'area/area',
    Position = 'area/position',
    table = 'utils/table',
    time = 'utils/defines/time',
    string = 'utils/string' -- adds string:split and friends, loaded for that
}

return setmetatable({}, {
    __index = function(self, name)
        local path = paths[name]
        if path then
            local module = require(PREFIX .. path)
            rawset(self, name, module)
            return module
        end
    end
})
