local flib_data_util = require('__Nanobots2__.lib.flib.data-util')

local function make_shortcut(chip)
    if mods['PickerInventoryTools'] then
        local disabled = flib_data_util.copy_prototype(chip, 'picker-disabled-' .. chip.name)
        disabled.localised_name = {'nano-disabled-equipment.disabled', chip.localised_name or {'equipment-name.' .. chip.name}}

        data:extend {disabled, {
            type = 'shortcut',
            name = 'toggle-' .. chip.name,
            order = 'c[toggles]-z[' .. chip.name .. ']',
            action = 'lua',
            toggleable = true,
            localised_name = {'shortcut.toggle-' .. chip.name},
            associated_control_input = nil,
            technology_to_unlock = 'personal-roboport-equipment',
            -- 2.x shortcuts take file names and sizes, not sprite tables
            icon = chip.sprite.filename,
            icon_size = 64,
            small_icon = chip.sprite.filename,
            small_icon_size = 64
        }}
    end
end

return make_shortcut
