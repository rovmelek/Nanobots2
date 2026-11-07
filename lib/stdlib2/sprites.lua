--- Empty sprites for prototype fields that need a picture but should draw nothing.
--- Derived from stdlib2 2.1.0 (https://github.com/rovmelek/stdlib2 @ e39ed5a): stdlib/data/modules/sprites.lua.
--- Copyright (c) 2016, Afforess. ISC license, see lib/stdlib2/LICENSE. Trimmed to what Nanobots2 uses.
---
--- Every call returns new tables, prototypes must not share them.
local Sprites = {}

local EMPTY = '__core__/graphics/empty.png'

--- An empty sprite.
--- @return table
function Sprites.empty_picture()
    return {filename = EMPTY, priority = 'extra-high', width = 1, height = 1}
end
Sprites.empty_sprite = Sprites.empty_picture

--- An empty animation (also usable as a rotated picture set).
--- @return table
function Sprites.empty_pictures()
    return {
        filename = EMPTY,
        width = 1,
        height = 1,
        line_length = 1,
        frame_count = 1,
        shift = {0, 0},
        animation_speed = 1,
        direction_count = 1
    }
end
Sprites.empty_animation = Sprites.empty_pictures

return Sprites
