local Data = require('lib/stdlib-data').Data

local function make_shortcut(chip)
    if mods['PickerInventoryTools'] then
        chip:copy('picker-disabled-' .. chip.name):set_fields {
            localised_name = {'nano-disabled-equipment.disabled', chip.localised_name or {'equipment-name.' .. chip.name}}
        }

        Data {
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
        }
    end
end

return make_shortcut
