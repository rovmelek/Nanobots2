local Recipe = require('__Nanobots2__.lib.stdlib2.recipe')

require('prototypes/technology/shortcuts')

-- bobmods recipe changes
if mods['boblibrary'] then

    local key = 'bobmods-logistics-disableroboports'
    if settings["startup"][key] and settings["startup"][key].value then
        Recipe.replace_ingredient('roboport-interface', 'roboport', 'bob-logistic-zone-expander')
    end
    Recipe.replace_ingredient('gun-nano-emitter', 'electronic-circuit', 'bob-basic-circuit-board')
    Recipe.replace_ingredient('ammo-nano-constructors', 'electronic-circuit', 'bob-basic-circuit-board')
    Recipe.replace_ingredient('ammo-nano-termites', 'electronic-circuit', 'bob-basic-circuit-board')

    Recipe.add_ingredient('equipment-bot-chip-items', 'bob-robot-brain')
    Recipe.add_ingredient('equipment-bot-chip-trees', 'bob-robot-brain')
    Recipe.add_ingredient('equipment-bot-chip-nanointerface', 'bob-robot-brain')
    Recipe.add_ingredient('equipment-bot-chip-nanointerface', 'gun-nano-emitter')
    Recipe.add_ingredient('equipment-bot-chip-launcher', 'bob-robot-brain-combat')
    Recipe.add_ingredient('equipment-bot-chip-feeder', 'bob-robot-brain-combat')
end
