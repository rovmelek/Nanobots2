-------------------------------------------------------------------------------
--[[roboport-interface]]
-------------------------------------------------------------------------------
local Event = require('__Nanobots2__.lib.stdlib2.event')
local flib_array = require('__Nanobots2__.lib.flib.array')
local Area = require('scripts/area')
local Queue = require('scripts/hash_queue')
local events = require('events')
local queue
--- Handlers for the cell queue, by action name.
local handlers = {}

local floor = math.floor

-- Cached copies of the runtime settings this file reads.
local cfg
local function update_settings()
    local setting = settings['global']
    cfg = {
        free_bots_per = setting['nanobots-free-bots-per'].value,
        cell_queue_rate = setting['nanobots-cell-queue-rate'].value
    }
end
Event.register(defines.events.on_runtime_mod_setting_changed, update_settings)
update_settings()

local params_to_check = {
    ['nano-signal-chop-trees'] = {
        action = 'mark_items_or_trees',
        find_type = 'tree',
        item_name = 'wood'
    },
    ['nano-signal-item-on-ground'] = {
        action = 'mark_items_or_trees',
        find_type = 'item-entity'
    },
    ['nano-signal-deconstruct-finished-miners'] = {
        action = 'deconstruct_finished_miners',
        find_type = 'mining-drill'
    },
    ['nano-signal-catch-fish'] = {
        action = 'mark_items_or_trees',
        find_type = 'fish',
        item_name = 'raw-fish'
    }
}

--[[
Signals read from the interface's constant combinator, see params_to_check above:
nano-signal-chop-trees: mark trees for deconstruction. A negative value only does it while the network holds fewer
    than that many wood.
nano-signal-catch-fish: the same for fish and raw fish.
nano-signal-item-on-ground: mark items on the ground, if there are no enemies in range.
nano-signal-deconstruct-finished-miners: mark mining drills that have nothing left to mine.
nano-signal-closest-roboport: with a value above 0, only work in the cell next to the interface.
--]]
-- Read the signals set in the constant combinator. Factorio 2.x stores them in logistic sections.
local function get_parameters(behaviour)
    local parameters = {}
    for _, section in pairs(behaviour.sections) do
        if section.active then
            for _, filter in pairs(section.filters) do
                local signal = filter.value
                if signal and signal.name then
                    parameters[signal.name] = (parameters[signal.name] or 0) + (filter.min or 0)
                end
            end
        end
    end
    return parameters
end

local function get_entity_info(entity)
    return entity.surface, entity.force, entity.position
end

handlers.mark_items_or_trees =
    function(data)
    if data.logistic_cell.valid and data.logistic_cell.construction_radius > 0 and data.logistic_cell.logistic_network then
        local surface, force, position = get_entity_info(data.logistic_cell.owner)
        if not (data.find_type or data.find_name) then
            data.find_type = 'NIL'
        end
        if not surface.find_nearest_enemy {position = position, max_distance = data.logistic_cell.construction_radius * 1.5 + 40, force = force} then
            local filter = {
                area = Area.around(position, data.logistic_cell.construction_radius),
                name = data.find_name,
                type = data.find_type,
                limit = 300
            }
            local available_bots = floor(data.logistic_cell.logistic_network.available_construction_robots - (data.logistic_cell.logistic_network.all_construction_robots * (cfg.free_bots_per / 100)))
            local limit = -99999999999
            if data.value < 0 and data.item_name then
                limit = data.logistic_cell.logistic_network.get_item_count(data.item_name) + data.value
            end

            for _, item in pairs(surface.find_entities_filtered(filter)) do
                if available_bots > 0 and (limit < 0) then
                    if not item.to_be_deconstructed() then
                        item.order_deconstruction(force)
                        available_bots = available_bots - 1
                        limit = limit + 1
                    end
                else
                    break
                end
            end
        end
    end
end

local function has_resources(miner)
    local _find = function(v, _)
        return v.prototype.resource_category == 'basic-solid' and (v.amount > 0 or v.prototype.infinite_resource)
    end
    -- Quality can change the mining radius; use the quality aware getter when this game version has it.
    local has_getter, radius = pcall(function() return miner.prototype.get_mining_drill_radius(miner.quality) end)
    if not (has_getter and radius) then
        radius = miner.prototype.mining_drill_radius
    end
    local filter = {area = Area.around(miner.position, radius), type = 'resource'}
    if miner.mining_target then
        return (miner.mining_target.amount or 0) > 0
    else
        return flib_array.find_if(miner.surface.find_entities_filtered(filter), _find)
    end
end

handlers.deconstruct_finished_miners = function(data)
    if not script.active_mods['AutoDeconstruct'] then
        if data.logistic_cell.valid and data.logistic_cell.construction_radius > 0 and data.logistic_cell.logistic_network then
            local surface, force, position = get_entity_info(data.logistic_cell.owner)
            local filter = {area = Area.around(position, data.logistic_cell.construction_radius), type = data.find_type or 'error', force = force}
            for _, miner in pairs(surface.find_entities_filtered(filter)) do
                if not miner.to_be_deconstructed() and miner.minable and not miner.has_flag('not-deconstructable') and not has_resources(miner) then
                    miner.order_deconstruction(force)
                end
            end
        end
    end
end

local function find_network_and_cell(interface)
    local port = interface.surface.find_entities_filtered {name = 'roboport-interface-main', position = interface.position}[1]
    if port and port.valid then
        local network = port.logistic_network
        local cell =
            flib_array.find_if(
            port.logistic_cell.neighbours,
            function(v)
                return v.construction_radius > 0
            end
        ) or port.logistic_cell
        return network, cell
    end
end

local function run_interface(interface)
    local behaviour = interface.get_control_behavior()
    if behaviour and behaviour.enabled then
        local logistic_network, logistic_cell = find_network_and_cell(interface)
        if logistic_network and logistic_network.available_construction_robots > logistic_network.all_construction_robots * (cfg.free_bots_per / 100) then
            local tick_spacing = cfg.cell_queue_rate
            local parameters = get_parameters(behaviour)
            -- If the closest roboport signal is present and > 0 then just run on the attached cell
            local just_cell = (parameters['nano-signal-closest-roboport'] or 0) > 0 and logistic_cell and {logistic_cell} or nil
            local fdata = storage.forces[logistic_cell.owner.force.name]
            local next_tick = queue:next(fdata._next_cell_tick or game.tick, tick_spacing, true)
            for param_name, param_table in pairs(params_to_check) do
                if (parameters[param_name] or 0) ~= 0 then
                    for _, cell in pairs(just_cell or logistic_network.cells) do
                        local hash = queue:get_hash(cell.owner)
                        if not cell.mobile and cell.construction_radius > 0 and queue:count() < 5000 and not (hash and hash[param_table.action]) then
                            local data = {
                                position = cell.owner.position,
                                logistic_cell = cell,
                                entity = cell.owner,
                                name = param_name,
                                action = param_table.action,
                                find_type = param_table.find_type,
                                find_name = param_table.find_name,
                                item_name = param_table.item_name,
                                value = parameters[param_name],
                                unit_number = cell.owner.unit_number
                            }
                            queue:insert(data, next_tick())
                        end
                    end
                end
            end
            fdata._next_cell_tick = queue:count() > 0 and next_tick() or game.tick
        end
    end
end

local function execute_interface_queue(event)
    queue:execute(event)
end
Event.register(defines.events.on_tick, execute_interface_queue)

--[Roboport Interface Scanner]--
 local function kill_or_remove_interface_parts(event, destroy)
    if event.entity.name == 'roboport-interface-main' then
        destroy = destroy or event.mod == 'creative-mode'
        local interface = event.entity
        for _, entity in pairs(interface.surface.find_entities_filtered {position = interface.position, force = interface.force}) do
            if entity ~= interface and entity.name:find('^roboport%-interface') then
                _ = (destroy and entity.destroy()) or entity.die()
            end
        end
    end
end
Event.register(defines.events.on_entity_died, kill_or_remove_interface_parts)
Event.register(
    events.mined,
    function(event)
        kill_or_remove_interface_parts(event, true)
    end
)

--Build the interface, after built check the area around it for interface components to revive or create.
local function build_roboport_interface(event)
    local interface = event.entity or event.destination
    if interface and interface.name == 'roboport-interface-main' then
        local pos, force = interface.position, interface.force
        local cc, ra
        for _, entity in pairs(interface.surface.find_entities_filtered {position = pos, force = force}) do
            if entity ~= interface then
                --If we have ghosts either via blueprint or something killed them
                if entity.name == 'entity-ghost' then
                    if entity.ghost_name == 'roboport-interface-cc' then
                        _, cc = entity.revive()
                    elseif entity.ghost_name == 'roboport-interface-scanner' then
                        _, ra = entity.revive()
                    end
                elseif entity.name == 'roboport-interface-cc' then
                    cc = entity
                elseif entity.name == 'roboport-interface-scanner' then
                    ra = entity
                end
            end
        end
        --If neither CC or RA are valid at this point then let us create them.
        if not (cc and cc.valid) then
            cc = interface.surface.create_entity {name = 'roboport-interface-cc', position = pos, force = force}
        end
        if not (ra and ra.valid) then
            ra = interface.surface.create_entity {name = 'roboport-interface-scanner', position = pos, force = force}
        end

        if not (cc and ra) then
            return
        end

        --roboports start with a buffer of energy. Lets take that away!
        interface.energy = 0
        --Use the same backer name for the interface and radar
        ra.backer_name = interface.backer_name
        cc.direction = defines.direction.north
        cc.destructible = false
        ra.destructible = false
    end
end
Event.register(events.build, build_roboport_interface)

local function on_sector_scanned(event)
    if event.radar.name == 'roboport-interface-scanner' then
        local entity = event.radar
        local interface = entity.surface.find_entities_filtered {name = 'roboport-interface-cc', position = entity.position, limit = 1}[1]
        if interface and interface.valid then
            run_interface(interface)
        end
    end
end
Event.register(defines.events.on_sector_scanned, on_sector_scanned)

local function on_init()
    storage.cell_queue = Queue(nil, handlers)
    queue = storage.cell_queue
end
Event.register(Event.core_events.init, on_init)

local function on_load()
    queue = Queue(storage.cell_queue, handlers)
end
Event.register(Event.core_events.load, on_load)

local function reset_cell_queue()
    storage.cell_queue = nil
    queue = nil
    storage.cell_queue = Queue(nil, handlers)
    queue = storage.cell_queue
    for _, fdata in pairs(storage.forces) do
        fdata._next_cell_tick = game and game.tick or 0
    end
end
Event.register(Event.generate_event_name('reset_cell_queue'), reset_cell_queue)
