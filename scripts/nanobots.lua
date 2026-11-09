local Event = require('__Nanobots2__.lib.stdlib2.event') -- protected mode is set in control.lua
local flib_array = require('__Nanobots2__.lib.flib.array')
local flib_bounding_box = require('__Nanobots2__.lib.flib.bounding-box')
local flib_position = require('__Nanobots2__.lib.flib.position')
local flib_table = require('__Nanobots2__.lib.flib.table')
local Area = require('scripts/area')
local Queue = require('scripts/hash_queue')
local queue
local cfg
--- Handlers for the nano queue, by action name.
local handlers = {}

local max, floor, table_size = math.max, math.floor, table_size
local TICKS_PER_SECOND = 60

local config = require('config')
local armormods = require('scripts/armor-mods')
local bot_radius = config.BOT_RADIUS
local queue_speed = config.QUEUE_SPEED_BONUS

--- The distinct values of tbl, in the order pairs() gives the inverted table.
local function unique(tbl)
    local values = {}
    for value in pairs(flib_table.inverted(tbl)) do
        values[#values + 1] = value
    end
    return values
end
local inv_list = unique {
    defines.inventory.character_trash, defines.inventory.character_main, defines.inventory.god_main, defines.inventory.chest,
    defines.inventory.character_vehicle, defines.inventory.car_trunk, defines.inventory.cargo_wagon
}

local moveable_types = {
    car = true, ['spider-vehicle'] = true,
    locomotive = true, ['cargo-wagon'] = true, ['fluid-wagon'] = true, ['artillery-wagon'] = true
} ---@type { [string]: true }
local blockable_types = {
    ['straight-rail'] = true, ['half-diagonal-rail'] = true, ['curved-rail-a'] = true, ['curved-rail-b'] = true,
    ['elevated-straight-rail'] = true, ['elevated-half-diagonal-rail'] = true,
    ['elevated-curved-rail-a'] = true, ['elevated-curved-rail-b'] = true,
    ['legacy-straight-rail'] = true, ['legacy-curved-rail'] = true
} ---@type { [string]: true }

---@type ItemStackDefinition[]
local explosives = {
    { name = 'cliff-explosives', count = 1 }, { name = 'explosives', count = 10 }, { name = 'explosive-rocket', count = 4 },
    { name = 'explosive-cannon-shell', count = 4 }, { name = 'cluster-grenade', count = 2 }, { name = 'grenade', count = 14 },
    { name = 'land-mine', count = 5 }, { name = 'artillery-shell', count = 1 }
}


local function update_settings()
    local setting = settings['global']
    cfg = {
        poll_rate = setting['nanobots-nano-poll-rate'].value,
        queue_rate = setting['nanobots-nano-queue-rate'].value,
        queue_cycle = setting['nanobots-nano-queue-per-cycle'].value,
        build_tiles = setting['nanobots-nano-build-tiles'].value,
        network_limits = setting['nanobots-network-limits'].value,
        nanobots_auto = setting['nanobots-nanobots-auto'].value,
        equipment_auto = setting['nanobots-equipment-auto'].value,
        afk_time = setting['nanobots-afk-time'].value * TICKS_PER_SECOND,
        do_proxies = setting['nanobots-nano-fullfill-requests'].value
    }
end
Event.register(defines.events.on_runtime_mod_setting_changed, update_settings)
update_settings()

--- Is the item in the player's inventory (or vehicle) in the amount needed, or is cheat_mode on?
--- Doesnt return items with inventory
--- @param simple_stack SimpleItemStack
--- @param player LuaPlayer
--- @param at_least_one boolean
--- @param quality string?
--- @return boolean
local _find_item = function(simple_stack, player, at_least_one, quality)
    local count = at_least_one and 1 or simple_stack.count
    local prototype = prototypes.item[simple_stack.name]
    if prototype.type ~= 'item-with-inventory' then
        local item = { name = simple_stack.name, quality = quality or simple_stack.quality or 'normal' }
        if player.cheat_mode or player.get_item_count(item) >= count then
            return true
        else
            local vehicle = player.vehicle
            local train = vehicle and vehicle.train --- @type LuaTrain
            return vehicle and ((vehicle.get_item_count(item) >= count) or (train and train.get_item_count(item) >= count))
        end
    end
end

--- The first of the items that the player has (see _find_item), or nil.
--- A plain loop, this runs for every scanned entity.
--- @param items SimpleItemStack[]
--- @param player LuaPlayer
--- @param at_least_one boolean?
--- @param quality string?
--- @return SimpleItemStack|nil
local function find_available_item(items, player, at_least_one, quality)
    for _, item in ipairs(items) do
        if _find_item(item, player, at_least_one, quality) then
            return item
        end
    end
end

--- The name of a quality, from a QualityID string or a LuaQualityPrototype.
--- @param quality string|LuaQualityPrototype|nil
--- @return string
local function quality_name(quality)
    if type(quality) == 'string' then
        return quality
    end
    return quality and quality.name or 'normal'
end

--- Copy an item to place, adding the quality it is needed in.
--- @param simple_stack ItemStackDefinition
--- @param quality string
--- @return ItemStackDefinition
local function with_quality(simple_stack, quality)
    return { name = simple_stack.name, count = simple_stack.count, quality = quality }
end

--- Is the player connected, not afk, and have an attached character
--- @param player LuaPlayer
--- @return boolean
local function is_connected_player_ready(player)
    return (cfg.afk_time <= 0 or player.afk_time < cfg.afk_time) and player.character
end

local function has_powered_equipment(character, eq_name)
    local grid = character.grid
    if grid then
        local eq = grid.find(eq_name)
        return eq and eq.energy > 0
    end
end

--- Is the player character not in a logistic network or has a working nano-interface
--- @param character LuaEntity
--- @param target LuaEntity
--- @return boolean
local function nano_network_check(character, target)
    if has_powered_equipment(character, 'equipment-bot-chip-nanointerface') then
        return true
    else
        local c = character
        local networks = target and target.surface.find_logistic_networks_by_construction_area(target.position, target.force) or
                             c.surface.find_logistic_networks_by_construction_area(c.position, c.force)
        -- Con bots in network
        local pnetwork = c.logistic_cell and c.logistic_cell and c.logistic_cell.mobile and c.logistic_cell.logistic_network
        local has_pbots = c.logistic_cell and c.logistic_cell.construction_radius > 0 and c.logistic_cell.logistic_network and
                              c.logistic_cell.logistic_network.all_construction_robots > 0
        local has_nbots = flib_array.any_of(networks, function(network)
            return network ~= pnetwork and network.all_construction_robots > 0
        end)
        return not (has_pbots or has_nbots)
    end
end

--- Can nanobots repair this entity?
--- @param entity LuaEntity
--- @return boolean
local function nano_repairable_entity(entity)
    if entity.has_flag('not-repairable') or entity.type:find('robot') then
        return false
    end
    if blockable_types[entity.type] and entity.minable == false then
        return false
    end
    if (entity.get_health_ratio() or 1) >= 1 then
        return false
    end
    if moveable_types[entity.type] and entity.speed > 0 then
        return false
    end
    -- 2.x collision masks are {layers = {...}, ...}
    local mask = entity.prototype.collision_mask
    return mask ~= nil and table_size(mask.layers or {}) > 0
end

--- Get the gun, ammo and ammo name for the named gun: will return nil for all returns if there is no ammo for the gun.
--- @param player LuaPlayer
--- @param gun_name string
--- @return LuaItemStack|nil
--- @return LuaItemStack|nil
--- @return string|nil
local function get_gun_ammo_name(player, gun_name)
    local gun_inv = player.character.get_inventory(defines.inventory.character_guns)
    local ammo_inv = player.character.get_inventory(defines.inventory.character_ammo)

    local gun --- @type LuaItemStack
    local ammo --- @type LuaItemStack

    if not player.mod_settings['nanobots-active-emitter-mode'].value then
        local index
        gun, index = gun_inv.find_item_stack(gun_name)
        ammo = gun and ammo_inv[index]
    else
        local index = player.character.selected_gun_index
        gun, ammo = gun_inv[index], ammo_inv[index]
    end

    if gun and gun.valid_for_read and ammo.valid_for_read then
        return gun, ammo, ammo.name
    end
    return nil, nil, nil
end

--- Attempt to insert an ItemStackDefinition or array of ItemStackDefinition into the entity
--- Spill to the ground at the entity anything that doesn't get inserted
--- @param entity LuaEntity
--- @param item_stacks ItemStackDefinition|ItemStackDefinition[]
--- @param is_return_cheat boolean
--- @return boolean #there was some items inserted or spilled
local function insert_or_spill_items(entity, item_stacks, is_return_cheat)
    if is_return_cheat then
        return
    end

    local new_stacks = {}
    if item_stacks then
        if item_stacks[1] and item_stacks[1].name then
            new_stacks = item_stacks
        elseif item_stacks and item_stacks.name then
            new_stacks = { item_stacks }
        end
        for _, stack in pairs(new_stacks) do
            local name, count, health, quality = stack.name, stack.count, stack.health or 1, quality_name(stack.quality)
            if prototypes.item[name] and not prototypes.item[name].hidden then
                local inserted = entity.insert({ name = name, count = count, health = health, quality = quality })
                if inserted ~= count then
                    entity.surface.spill_item_stack {
                        position = entity.position,
                        stack = { name = name, count = count - inserted, health = health, quality = quality },
                        enable_looted = true
                    }
                end
            end
        end
        return new_stacks[1] and new_stacks[1].name and true
    end
end

--- Give a job's items back to its player's character (the player controller has no inventory in remote view). Nothing was taken in cheat mode, so nothing is returned.
--- The cheat mode of the moment the items were taken is stored in the job, the player can change it while jobs wait.
--- @param player LuaPlayer
--- @param item_stack ItemStackDefinition|nil
--- @param cheat boolean|nil cheat mode when the job was queued
local function refund(player, item_stack, cheat)
    if item_stack then
        return insert_or_spill_items(player.character or player, { item_stack }, cheat)
    end
end

--- Drop a job's items on the ground where the job was, for a player that has no character to insert into.
--- @param data Nanobots.data
local function spill_job_items(data)
    local stack = data.item_stack
    local surface = data.surface
    if stack and not data.cheat and surface and surface.valid then
        surface.spill_item_stack {
            position = data.position,
            stack = { name = stack.name, count = stack.count, health = stack.health or 1, quality = quality_name(stack.quality) },
            enable_looted = true
        }
    end
end

--- Attempt to insert an arrary of items stacks into an entity
--- @param entity LuaEntity
--- @param item_stacks ItemStackDefinition|ItemStackDefinition[]
--- @return ItemStackDefinition[] #Items not inserted
local function insert_into_entity(entity, item_stacks)
    item_stacks = item_stacks or {}
    if item_stacks and item_stacks.name then
        item_stacks = { item_stacks }
    end
    local new_stacks = {}
    for _, stack in pairs(item_stacks) do
        local name, count, health, quality = stack.name, stack.count, stack.health or 1, quality_name(stack.quality)
        local inserted = entity.insert({ name = name, count = count, health = health, quality = quality })
        if inserted ~= count then
            new_stacks[#new_stacks + 1] = { name = name, count = count - inserted, health = health, quality = quality }
        end
    end
    return new_stacks
end

--- Set the health of a freshly built entity from the health of the item it was built from.
--- Entities without health (nil) or that start dead are left alone.
--- @param entity LuaEntity
--- @param item_stack ItemStackDefinition|nil
local function restore_health(entity, item_stack)
    local health = entity.health
    if health and health > 0 then
        entity.health = (item_stack and item_stack.health or 1) * entity.max_health
    end
end

--- Scan the ground under a ghost entities collision box for items and return an array of SimpleItemStack.
--- @param entity LuaEntity the entity object to scan under
--- @return ItemStackDefinition[] #array of ItemStackDefinition
local function get_all_items_on_ground(entity, existing_stacks)
    local item_stacks = existing_stacks or {}
    local surface, position, bouding_box = entity.surface, entity.position, entity.ghost_prototype.selection_box
    local area = flib_bounding_box.move(bouding_box, position)
    for _, item_on_ground in pairs(surface.find_entities_filtered { name = 'item-on-ground', area = area }) do
        local ground_stack = item_on_ground.stack
        item_stacks[#item_stacks + 1] = { name = ground_stack.name, count = ground_stack.count, health = ground_stack.health or 1, quality = ground_stack.quality.name }
        item_on_ground.destroy()
    end
    local inserter_area = flib_bounding_box.resize(area, 3)
    for _, inserter in pairs(surface.find_entities_filtered { area = inserter_area, type = 'inserter' }) do
        local stack = inserter.held_stack
        if stack.valid_for_read and flib_bounding_box.contains_position(area, inserter.held_stack_position) then
            item_stacks[#item_stacks + 1] = { name = stack.name, count = stack.count, health = stack.health or 1, quality = stack.quality.name }
            stack.clear()
        end
    end
    return (item_stacks[1] and item_stacks) or {}
end

--- Get an item with health data from the inventory
--- @param entity LuaEntity the entity object to search
--- @param item_stack ItemStackDefinition the item to look for
--- @param cheat boolean cheat the item
--- @param at_least_one boolean #return as long as count > 0
--- @return ItemStackDefinition|nil
local function get_items_from_inv(entity, item_stack, cheat, at_least_one)
    local quality = quality_name(item_stack.quality)
    local item = { name = item_stack.name, quality = quality }
    if cheat then
        return { name = item_stack.name, count = item_stack.count, health = 1, quality = quality }
    else
        local sources
        if entity.vehicle and entity.vehicle.train then
            sources = entity.vehicle.train.cargo_wagons
            sources[#sources + 1] = entity.character
        elseif entity.vehicle then
            sources = { entity.vehicle, entity.character }
        else
            sources = { entity.character }
        end

        local new_item_stack = { name = item_stack.name, count = 0, health = 1, quality = quality }
        -- Health is averaged over the items taken, each stack weighted by how many items came from it.
        local health_total = 0

        local function finish()
            if new_item_stack.count > 0 then
                new_item_stack.health = health_total / new_item_stack.count
            end
            return new_item_stack
        end

        local count = item_stack.count

        for _, source in pairs(sources) do
            for _, inv in pairs(inv_list) do
                local inventory = source.get_inventory(inv)
                if inventory and inventory.valid and inventory.get_item_count(item) > 0 then
                    local stack = inventory.find_item_stack(item)
                    while stack do
                        local removed = math.min(stack.count, count)
                        new_item_stack.count = new_item_stack.count + removed
                        health_total = health_total + removed * stack.health
                        stack.count = stack.count - removed
                        count = count - removed

                        if new_item_stack.count == item_stack.count then
                            return finish()
                        end
                        stack = inventory.find_item_stack(item)
                    end
                end
            end
        end
        -- If we havn't returned here check the hand!
        if entity.is_player() then
            local stack = entity.cursor_stack
            if stack and stack.valid_for_read and stack.name == item_stack.name and stack.quality.name == quality then
                local removed = math.min(stack.count, count)
                new_item_stack.count = new_item_stack.count + removed
                health_total = health_total + removed * stack.health
                if removed >= stack.count then
                    stack.clear()
                else
                    stack.count = stack.count - removed
                end
            end
        end
        if new_item_stack.count == item_stack.count or (new_item_stack.count > 0 and at_least_one) then
            return finish()
        else
            -- Not enough items, put back what was already taken.
            if new_item_stack.count > 0 then
                local taken = finish()
                insert_or_spill_items(entity.character or entity, { taken })
            end
            return nil
        end
    end
end

--- Manually drain ammo, if it is the last bit of ammo in the stack pull in more ammo from inventory if available
--- @param player LuaPlayer the player object
--- @param ammo LuaItemStack the ammo itemstack
--- @param amount number?
--- @return boolean #Ammo was drained
local function ammo_drain(player, ammo, amount)
    if player.cheat_mode then
        return true
    end

    amount = amount or 1
    local name = ammo.name
    ammo.drain_ammo(amount)
    if not ammo.valid_for_read then
        -- Use the character's inventory: the player's main inventory is nil in remote view.
        local character = player.character
        local inventory = character and character.get_main_inventory()
        local new = inventory and inventory.find_item_stack(name)
        if new then
            ammo.set_stack(new)
            new.clear()
        end
        return true
    end
end

--- Get the radius to use based on tehnology and player defined radius
--- @param player LuaPlayer
--- @param nano_ammo LuaItemStack
local function get_ammo_radius(player, nano_ammo)
    local data = storage.players[player.index]
    local modifier = player.force.get_ammo_damage_modifier(nano_ammo.prototype.ammo_category.name)
    local max_radius = bot_radius[modifier] or 7
    local custom_radius = data.ranges[nano_ammo.name] or max_radius
    return custom_radius <= max_radius and custom_radius or max_radius
end

--- Remove delivered items from an item request proxy's insert plan, destroy the proxy when nothing is left.
--- In Factorio 2.x `item_requests` is read only, the requests are stored in `insert_plan`.
--- @param proxy LuaEntity the item request proxy
--- @param name string the item that was delivered
--- @param amount number how many were delivered
local function reduce_insert_plan(proxy, name, quality, amount)
    if not (proxy and proxy.valid) then
        return
    end
    local new_plan = {}
    for _, entry in pairs(proxy.insert_plan) do
        local items = entry.items or {}
        if amount > 0 and entry.id.name == name and quality_name(entry.id.quality) == quality then
            local kept = {}
            for _, pos in pairs(items.in_inventory or {}) do
                local count = pos.count or 1
                if amount >= count then
                    amount = amount - count
                elseif amount > 0 then
                    pos.count = count - amount
                    amount = 0
                    kept[#kept + 1] = pos
                else
                    kept[#kept + 1] = pos
                end
            end
            items.in_inventory = kept[1] and kept or nil
            if amount > 0 and (items.grid_count or 0) > 0 then
                local used = math.min(amount, items.grid_count)
                items.grid_count = items.grid_count - used
                amount = amount - used
            end
            entry.items = items
            if items.in_inventory or (items.grid_count or 0) > 0 then
                new_plan[#new_plan + 1] = entry
            end
        else
            new_plan[#new_plan + 1] = entry
        end
    end
    if new_plan[1] then
        proxy.insert_plan = new_plan
    else
        proxy.destroy()
    end
end

--- Attempt to satisfy module requests from player inventory
--- @param proxy LuaEntity the item request proxy to get requests from
--- @param entity LuaEntity the entity to satisfy requests for
--- @param player LuaPlayer the player to get modules from
local function satisfy_requests(proxy, entity, player)
    -- Use the character's inventory: the player's main inventory is nil in remote view.
    local character = player.character
    local pinv = character and character.get_main_inventory()
    if not (pinv or player.cheat_mode) then
        return
    end
    for _, request in pairs(proxy.item_requests) do
        if not proxy.valid then
            return
        end
        local name, count, quality = request.name, request.count, quality_name(request.quality)
        if count > 0 and entity.can_insert({ name = name, quality = quality }) then
            local removed = player.cheat_mode and count or pinv.remove({ name = name, count = count, quality = quality })
            local inserted = removed > 0 and entity.insert({ name = name, count = removed, quality = quality }) or 0
            if removed > inserted and not player.cheat_mode then
                pinv.insert({ name = name, count = removed - inserted, quality = quality })
            end
            if inserted > 0 then
                reduce_insert_plan(proxy, name, quality, inserted)
            end
        end
    end
end

--- Create a projectile from source to target
--- @param name string the name of the projecticle
--- @param surface LuaSurface the surface to create the projectile on
--- @param force LuaForce the force this projectile belongs too
--- @param source MapPosition|LuaEntity position table to start at
--- @param target MapPosition|LuaEntity position table to end at
local function create_projectile(name, surface, force, source, target, speed)
    speed = speed or 1
    force = force or 'player'
    surface.create_entity { name = name, force = force, position = source, target = target, speed = speed }
end

--[[Nano Emitter Queue Handler --]]
-- Queued items are handled one at a time, --check validity of all stored objects at this point, They could have become
-- invalidated between the time they were entered into the queue and now.


--- @class Nanobots.data
--- @field player_index number
--- @field entity LuaEntity
--- @field surface LuaSurface
--- @field position MapPosition
--- @field unit_number number|nil
--- @field cheat boolean cheat mode of the player when the items were taken
--- @field action string
--- @field hash number set by the queue on insert
--- @field item_stack ItemStackDefinition|nil
--- @field entity_name string|nil
--- @field quality string|nil
--- @field deconstructors boolean|nil

--- @param data Nanobots.data
function handlers.cliff_deconstruction(data)
    local entity, player = data.entity, game.get_player(data.player_index)
    if not (player and player.valid) then
        return
    end
    if not player.character then
        -- The player died or disconnected while the job waited, there is no inventory to hand the items back to.
        return spill_job_items(data)
    end

    if not (entity and entity.valid and entity.to_be_deconstructed()) then
        return refund(player, data.item_stack, data.cheat)
    end

    create_projectile('nano-projectile-deconstructors', entity.surface, entity.force, player.character.position, entity.position)
    local exp_name = data.item_stack.name == 'artillery-shell' and 'big-artillery-explosion' or 'big-explosion'
    entity.surface.create_entity { name = exp_name, position = entity.position }
    entity.destroy({ do_cliff_correction = true, raise_destroy = true })
end

-- Handles all of the deconstruction and scrapper related tasks.
--- @param data Nanobots.data
function handlers.deconstruction(data)
    local entity = data.entity
    local player = game.get_player(data.player_index)
    if not (player and player.valid) then
        return
    end
    if not player.character then
        -- The player died or disconnected while the job waited, there is no inventory to hand the items back to.
        return spill_job_items(data)
    end

    if not (entity and entity.valid and entity.to_be_deconstructed()) then
        return
    end

    local surface = data.surface or entity.surface
    local force =  entity.force
    local ppos = player.character.position
    local epos = entity.position

    create_projectile('nano-projectile-deconstructors', surface, force, ppos, epos)
    create_projectile('nano-projectile-return', surface, force, epos, ppos)

    if entity.name == 'deconstructible-tile-proxy' then
        local tile = surface.get_tile(epos)
        if tile then
            player.mine_tile(tile)
            entity.destroy()
        end
    else
        player.mine_entity(entity)
    end
end

--- @param data Nanobots.data
function handlers.build_entity_ghost(data)
    local ghost = data.entity
    local player = game.get_player(data.player_index)
    local surface = data.surface
    local position = data.position
    if not (player and player.valid) then
        return
    end
    if not player.character then
        -- The player died or disconnected while the job waited, there is no inventory to hand the items back to.
        return spill_job_items(data)
    end

    if not (ghost.valid and data.entity.ghost_name == data.entity_name) then
        return refund(player, data.item_stack, data.cheat)
    end

    local item_stacks = get_all_items_on_ground(ghost)
    if not ghost.surface.can_place_entity { name = ghost.ghost_name, position = ghost.position, direction = ghost.direction, force = ghost.force } then
        return refund(player, data.item_stack, data.cheat)
    end

    local revived, entity, requests = ghost.revive { raise_revive = true }

    if not revived then
        return refund(player, data.item_stack, data.cheat)
    end

    if not entity then
        -- These are real items from the ground, so they are returned in cheat mode too.
        if insert_or_spill_items(player.character, item_stacks) then
            create_projectile('nano-projectile-return', surface, player.force, position, player.character.position)
        end
        return
    end

    create_projectile('nano-projectile-constructors', entity.surface, entity.force, player.character.position, entity.position)
    restore_health(entity, data.item_stack)
    if insert_or_spill_items(player.character, insert_into_entity(entity, item_stacks)) then
        create_projectile('nano-projectile-return', surface, player.force, position, player.character.position)
    end
    if requests then
        satisfy_requests(requests, entity, player)
    end
end

--- @param data Nanobots.data
function handlers.build_tile_ghost(data)
    local ghost = data.entity
    local player = game.get_player(data.player_index)
    local surface = data.surface
    local position = data.position
    if not (player and player.valid) then
        return
    end
    if not player.character then
        -- The player died or disconnected while the job waited, there is no inventory to hand the items back to.
        return spill_job_items(data)
    end

    if not ghost.valid then
        return refund(player, data.item_stack, data.cheat)
    end

    local tile, hidden_tile = surface.get_tile(position), surface.get_hidden_tile(position)
    local force = ghost.force
    local tile_was_mined = hidden_tile and tile.prototype.can_be_part_of_blueprint and player.mine_tile(tile)
    local ghost_was_revived = ghost.valid and ghost.revive({ raise_revive = true }) -- Mining tiles invalidates ghosts
    if not (tile_was_mined or ghost_was_revived) then
        return refund(player, data.item_stack, data.cheat)
    end

    local item_ptype = data.item_stack and prototypes.item[data.item_stack.name]
    local tile_ptype = item_ptype and item_ptype.place_as_tile_result.result
    create_projectile('nano-projectile-constructors', surface, force, player.character.position, position)
    position = flib_position.floor(position)
    -- if the tile was mined, we need to manually place the tile.
    -- checking if the ghost was revived is likely unnecessary but felt safer.
    if tile_was_mined and not ghost_was_revived then
        create_projectile('nano-projectile-return', surface, force, position, player.character.position)
        surface.set_tiles({ { name = tile_ptype.name, position = position } }, true, true, false, true)
    end

    surface.play_sound { path = 'nano-sound-build-tiles', position = position }
end

--- @param data Nanobots.data
function handlers.upgrade_ghost(data)
    local ghost = data.entity
    local player = game.get_player(data.player_index)
    local surface = data.surface
    local position = data.position
    if not (player and player.valid) then
        return
    end
    if not player.character then
        -- The player died or disconnected while the job waited, there is no inventory to hand the items back to.
        return spill_job_items(data)
    end

    if not ghost.valid then
        return refund(player, data.item_stack, data.cheat)
    end

    local entity = surface.create_entity {
        name = data.entity_name or data.item_stack.name,
        direction = ghost.direction,
        force = ghost.force,
        position = position,
        fast_replace = true,
        player = player,
        type = ghost.type == 'underground-belt' and ghost.belt_to_ground_type or nil,
        quality = data.quality or quality_name(data.item_stack.quality),
        raise_built = true
    }
    if not entity then
        return refund(player, data.item_stack, data.cheat)
    end

    create_projectile('nano-projectile-constructors', entity.surface, entity.force, player.character.position, entity.position)
    surface.play_sound { path = 'utility/build_small', position = entity.position }
    restore_health(entity, data.item_stack)
end

--- @param data Nanobots.data
function handlers.item_requests(data)
    local proxy = data.entity
    local player = game.get_player(data.player_index)
    local target = proxy.valid and proxy.proxy_target ---@type LuaEntity
    if not (player and player.valid) then
        return
    end
    if not player.character then
        -- The player died or disconnected while the job waited, there is no inventory to hand the items back to.
        return spill_job_items(data)
    end

    if not (proxy.valid and target and target.valid) then
        return refund(player, data.item_stack, data.cheat)
    end

    if not target.can_insert(data.item_stack) then
        return refund(player, data.item_stack, data.cheat)
    end

    create_projectile('nano-projectile-constructors', proxy.surface, proxy.force, player.character.position, proxy.position)
    local item_stack = data.item_stack
    local inserted = target.insert(item_stack)
    item_stack.count = item_stack.count - inserted

    if item_stack.count > 0 then
        refund(player, item_stack, data.cheat)
    end

    if inserted > 0 then
        reduce_insert_plan(proxy, item_stack.name, quality_name(item_stack.quality), inserted)
    end
end

--[[ Nano Emmitter --]]
-- Extension of the tick handler. Each poll runs a few narrow, engine-filtered scans (marked for deconstruction,
-- marked for upgrade, ghosts, item request proxies) instead of walking every entity in range, and each scan hands
-- the entities to a small planner that queues at most one job for that entity.
-- Only repair has to look at every entity of the force, so it runs on a slower cadence.

--- Run the repair scan once every this many polls of a player.
local REPAIR_SCAN_EVERY = 3

--- @class Nanobots.scan_context
--- @field player LuaPlayer
--- @field force LuaForce
--- @field ammo LuaItemStack
--- @field next_tick fun(): number
--- @field queue_count fun(num?: number): number

--- Start the queue entry for an entity.
--- @param ctx Nanobots.scan_context
--- @param entity LuaEntity
--- @return Nanobots.data
local function new_job(ctx, entity)
    --- @type Nanobots.data
    return {
        player_index = ctx.player.index,
        position = entity.position,
        surface = entity.surface,
        unit_number = entity.unit_number,
        cheat = ctx.player.cheat_mode,
        entity = entity
    }
end

--- Queue the job and pay for it with ammo.
--- @param ctx Nanobots.scan_context
--- @param job Nanobots.data
local function enqueue(ctx, job)
    queue:insert(job, ctx.next_tick())
    ammo_drain(ctx.player, ctx.ammo, 1)
end

--- Entities marked for deconstruction, including cliffs.
local function plan_deconstruct(ctx, entity)
    if not entity.to_be_deconstructed() then
        return
    end
    -- The search is not limited by force, so skip what other players' forces marked.
    local player = ctx.player
    if entity.force ~= player.force and entity.force.name ~= 'neutral' then
        return
    end
    if entity.type == 'cliff' then
        if not player.force.technologies['nanobots-cliff'].researched then
            return
        end
        local item_stack = find_available_item(explosives, player)
        local explosive = item_stack and get_items_from_inv(player, item_stack, player.cheat_mode)
        if explosive then
            local job = new_job(ctx, entity)
            job.item_stack = explosive
            job.action = 'cliff_deconstruction'
            enqueue(ctx, job)
        end
    elseif entity.minable then
        local job = new_job(ctx, entity)
        job.action = 'deconstruction'
        job.deconstructors = true
        enqueue(ctx, job)
    end
end

--- Entities marked for upgrade. In 2.x the target can change the entity, its quality or both.
local function plan_upgrade(ctx, entity)
    if entity.to_be_deconstructed() then
        return
    end
    local player = ctx.player
    local prototype, target_quality = entity.get_upgrade_target()
    local quality = target_quality and target_quality.name or entity.quality.name
    if not (prototype and (prototype.name ~= entity.name or quality ~= entity.quality.name)) then
        return
    end
    local item_stack = find_available_item(prototype.items_to_place_this or {}, player, false, quality)
    local place_item = item_stack and get_items_from_inv(player, with_quality(item_stack, quality), player.cheat_mode)
    if place_item then
        local job = new_job(ctx, entity)
        job.action = 'upgrade_ghost'
        job.entity_name = prototype.name
        job.quality = quality
        job.item_stack = place_item
        enqueue(ctx, job)
    end
end

--- Entity ghosts and tile ghosts.
local function plan_ghost(ctx, ghost)
    local is_entity_ghost = ghost.name == 'entity-ghost'
    if not (is_entity_ghost or cfg.build_tiles) then
        return
    end
    local player = ctx.player
    local proto = ghost.ghost_prototype
    -- Ghosts are revived at their own quality, so use an item of that quality. Tiles have no quality.
    local quality = is_entity_ghost and ghost.quality.name or 'normal'
    local item_stack = find_available_item(proto.items_to_place_this or {}, player, false, quality)
    if not item_stack then
        return
    end
    item_stack = with_quality(item_stack, quality)

    if is_entity_ghost then
        local place_item = get_items_from_inv(player, item_stack, player.cheat_mode)
        if place_item then
            local job = new_job(ctx, ghost)
            job.action = 'build_entity_ghost'
            job.entity_name = proto.name
            job.item_stack = place_item
            enqueue(ctx, job)
        end
        return
    end

    -- Don't queue tile ghosts if an entity ghost is on top of them.
    local blocked = ghost.surface.count_entities_filtered {name = 'entity-ghost', area = Area.non_zero(ghost.bounding_box), limit = 1}
    if blocked > 0 or not ghost.surface.get_tile(ghost.position) then
        return
    end
    local place_item = get_items_from_inv(player, item_stack, player.cheat_mode)
    if place_item then
        local job = new_job(ctx, ghost)
        job.item_stack = place_item
        job.action = 'build_tile_ghost'
        enqueue(ctx, job)
    end
end

--- Damaged entities of the player's force.
local function plan_repair(ctx, entity)
    if not nano_repairable_entity(entity) then
        return
    end
    -- Skip if a repair cloud is already working on it.
    if entity.surface.count_entities_filtered {name = 'nano-cloud-small-repair', position = entity.position} > 0 then
        return
    end
    entity.surface.create_entity {
        name = 'nano-projectile-repair',
        position = ctx.player.character.position,
        force = ctx.force,
        target = entity.position,
        speed = 0.5
    }
    ctx.queue_count(1)
    ammo_drain(ctx.player, ctx.ammo, 1)
end

--- Module and item requests, satisfied from the player's inventory.
local function plan_proxy(ctx, proxy)
    local player = ctx.player
    local items = {}
    for _, request in pairs(proxy.item_requests) do
        items[#items + 1] = {name = request.name, count = request.count, quality = quality_name(request.quality)}
    end
    local item_stack = find_available_item(items, player, true)
    local place_item = item_stack and get_items_from_inv(player, item_stack, player.cheat_mode, true)
    if place_item and place_item.count > 0 then
        local job = new_job(ctx, proxy)
        job.action = 'item_requests'
        job.item_stack = place_item
        enqueue(ctx, job)
    end
end

--- Plan one entity, after the checks every job needs.
--- @param ctx Nanobots.scan_context
--- @param entity LuaEntity
--- @param scan table
--- @return boolean #false when scanning should stop, the ammo ran out or the queue is full
local function plan_entity(ctx, entity, scan)
    if not (ctx.ammo.valid and ctx.ammo.valid_for_read) then
        return false
    end
    if ctx.queue_count() >= cfg.queue_cycle then
        return false
    end
    if queue:get_hash(entity) then
        return true
    end
    -- Marked entities are handled by the deconstruct and upgrade scans only.
    if scan.skip_marked and (entity.to_be_deconstructed() or entity.to_be_upgraded()) then
        return true
    end
    if cfg.network_limits and not nano_network_check(ctx.player.character, entity) then
        return true
    end
    scan.planner(ctx, entity)
    return true
end

--- The scans, in priority order. `filter` is merged with the area, `force` is added when `same_force` is set.
local scans = {
    {filter = {to_be_deconstructed = true}, planner = plan_deconstruct},
    {filter = {to_be_upgraded = true}, same_force = true, planner = plan_upgrade},
    {filter = {type = {'entity-ghost', 'tile-ghost'}}, same_force = true, skip_marked = true, planner = plan_ghost},
    {filter = {type = 'item-request-proxy'}, same_force = true, skip_marked = true, planner = plan_proxy, enabled = function() return cfg.do_proxies end},
    {filter = {}, same_force = true, skip_marked = true, planner = plan_repair, every = REPAIR_SCAN_EVERY}
}

--- Queue the ghosts in range for building, heal stuff needing healed
--- @param player LuaPlayer
--- @param pos MapPosition
--- @param nano_ammo LuaItemStack
local function queue_ghosts_in_range(player, pos, nano_ammo)
    local pdata = storage.players[player.index]
    local force = player.force
    local _next_nano_tick = (pdata._next_nano_tick and pdata._next_nano_tick < (game.tick + 2000) and pdata._next_nano_tick) or game.tick
    local tick_spacing = max(1, cfg.queue_rate - (queue_speed[force.get_gun_speed_modifier('nano-ammo')] or queue_speed[4]))
    local next_tick, queue_count = queue:next(_next_nano_tick, tick_spacing)
    local area = Area.around(pos, get_ammo_radius(player, nano_ammo))
    local surface = player.character.surface

    ---@type Nanobots.scan_context
    local ctx = {player = player, force = force, ammo = nano_ammo, next_tick = next_tick, queue_count = queue_count}

    pdata._poll_count = (pdata._poll_count or 0) + 1
    for _, scan in ipairs(scans) do
        local due = not scan.every or pdata._poll_count % scan.every == 0
        if due and (not scan.enabled or scan.enabled()) then
            local filter = {area = area, force = scan.same_force and force or nil}
            for key, value in pairs(scan.filter) do
                filter[key] = value
            end
            local keep_going = true
            for _, entity in pairs(surface.find_entities_filtered(filter)) do
                if not plan_entity(ctx, entity, scan) then
                    keep_going = false
                    break
                end
            end
            if not keep_going then
                break
            end
        end
    end
    pdata._next_nano_tick = next_tick() or game.tick
end

-- Nano Termites
-- Kill the trees! Kill them dead
--- @param player LuaPlayer
--- @param pos MapPosition
--- @param nano_ammo LuaItemStack
local function everyone_hates_trees(player, pos, nano_ammo)
    local radius = get_ammo_radius(player, nano_ammo)
    local force = player.force
    local surface = player.character.surface
    for _, stupid_tree in pairs(surface.find_entities_filtered { position = pos, radius = radius, type = 'tree', limit = 200 }) do
        if nano_ammo.valid and nano_ammo.valid_for_read then
            if not stupid_tree.to_be_deconstructed() then
                local tree_area = flib_bounding_box.resize(stupid_tree.bounding_box, .5)
                if surface.count_entities_filtered { area = tree_area, name = 'nano-cloud-small-termites' } == 0 then
                    surface
                        .create_entity { name = 'nano-projectile-termites', position = player.character.position, force = force, target = stupid_tree, speed = .5 }
                    ammo_drain(player, nano_ammo, 1)
                end
            end
        else
            break
        end
    end
end

--[[ EVENTS --]]
-- The Tick Handler
--- @param player LuaPlayer a connected player that passed is_connected_player_ready
local function poll_player(player)
    if cfg.nanobots_auto and (not cfg.network_limits or nano_network_check(player.character)) then
        local gun, nano_ammo, ammo_name = get_gun_ammo_name(player, 'gun-nano-emitter')
        if gun then
            if ammo_name == 'ammo-nano-constructors' then
                queue_ghosts_in_range(player, player.character.position, nano_ammo)
            elseif ammo_name == 'ammo-nano-termites' then
                everyone_hates_trees(player, player.character.position, nano_ammo)
            end
        end -- Gun and Ammo check
    end
    if cfg.equipment_auto then
        armormods.prepare_chips(player)
    end -- Auto Equipment
end

--- @param event on_tick
local function poll_players(event)
    -- Run logic for nanobots and power armor modules
    -- if event.tick % math.ceil(#game.connected_players/cfg.poll_rate) == 0 then
    if event.tick % max(1, floor(cfg.poll_rate / #game.connected_players)) == 0 then
        local last_player, player = next(game.connected_players, storage._last_player)
        -- Advance first, so a failing player does not block the others.
        storage._last_player = last_player
        -- Establish connected, non afk, player character
        if player and is_connected_player_ready(player) then
            if config.DEBUG then
                poll_player(player)
            else
                local ok, err = pcall(poll_player, player)
                if not ok then
                    log('Nanobots2: polling player ' .. player.index .. ' failed: ' .. tostring(err))
                end
            end
        end -- Player Ready
    end -- NANO Automatic scripts
    queue:execute(event)
end
Event.register(defines.events.on_tick, poll_players)

-- Reset last player when players join or leave
local function players_changed()
    storage._last_player = nil
end
Event.register({ defines.events.on_player_joined_game, defines.events.on_player_left_game }, players_changed)

local function on_nano_init()
    storage.nano_queue = Queue(nil, handlers)
    queue = storage.nano_queue
    game.print('Nanobots are now ready to serve')
end
Event.register(Event.core_events.init, on_nano_init)

local function on_nano_load()
    queue = Queue(storage.nano_queue, handlers)
end
Event.register(Event.core_events.load, on_nano_load)

local function reset_nano_queue()
    -- Swap in the new queue first, so a failing refund cannot leave jobs in the live queue to be refunded twice.
    local old = queue
    storage.nano_queue = Queue(nil, handlers)
    queue = storage.nano_queue
    -- Jobs already took their items from the player, give them back before the old jobs are dropped.
    if old then
        for tick, jobs in pairs(old) do
            if type(tick) == 'number' then
                for _, job in pairs(jobs) do
                    local player = game.get_player(job.player_index)
                    if job.item_stack then
                        if player and player.valid and player.character then
                            pcall(refund, player, job.item_stack, job.cheat)
                        else
                            pcall(spill_job_items, job)
                        end
                    end
                end
            end
        end
    end
    for _, player in pairs(storage.players) do
        player._next_nano_tick = 0
    end
end
Event.register(Event.generate_event_name('reset_nano_queue'), reset_nano_queue)
