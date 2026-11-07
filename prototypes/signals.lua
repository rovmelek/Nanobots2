local group = {
    type = 'item-subgroup',
    name = 'nanobot-signals',
    group = 'signals',
    order = 'zzzzzz'
}

local signal1 = {
    type = 'virtual-signal',
    name = 'nano-signal-chop-trees',
    icon = '__Nanobots2__/graphics/icons/signals/chop-trees.png',
    icon_size = 64,
    subgroup = 'nanobot-signals',
    order = '[nano-signal]-a'
}
local signal2 = {
    type = 'virtual-signal',
    name = 'nano-signal-item-on-ground',
    icon = '__Nanobots2__/graphics/icons/signals/item-on-ground.png',
    icon_size = 64,
    subgroup = 'nanobot-signals',
    order = '[nano-signal]-b'
}
local signal5 = {
    type = 'virtual-signal',
    name = 'nano-signal-deconstruct-finished-miners',
    icon = '__Nanobots2__/graphics/icons/signals/deconstruct-miners.png',
    icon_size = 64,
    subgroup = 'nanobot-signals',
    order = '[nano-signal]-e'
}
local signal6 = {
    type = 'virtual-signal',
    name = 'nano-signal-catch-fish',
    icon = '__Nanobots2__/graphics/icons/signals/remove-fish.png',
    icon_size = 64,
    subgroup = 'nanobot-signals',
    order = '[nano-signal]-f'
}
local signal99 = {
    type = 'virtual-signal',
    name = 'nano-signal-closest-roboport',
    icon = '__Nanobots2__/graphics/icons/signals/closest-roboport.png',
    icon_size = 64,
    subgroup = 'nanobot-signals',
    order = '[nano-signal]-z'
}

data:extend {group, signal1, signal2, signal5, signal6, signal99}
