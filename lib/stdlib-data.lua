--- The one place the data stage reaches into stdlib2, see lib/stdlib.lua.
local PREFIX = '__stdlib2__/stdlib/'

local paths = {
    Data = 'data/data',
    Recipe = 'data/recipe'
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
