--- Version migrations: runs the functions of a version file once for each version a save has not seen yet.
--- Derived from stdlib2 2.1.0 (https://github.com/rovmelek/stdlib2 @ e39ed5a): stdlib/event/changes.lua.
--- Copyright (c) 2016, Afforess. ISC license, see lib/stdlib2/LICENSE. Trimmed to what Nanobots2 uses.
---
--- The version file returns a table of version string to function. `storage._changes` remembers which versions ran.
local Event = require('__Nanobots2__.lib.stdlib2.event')

local Changes = {}

--- Version file tables, by require path.
local version_files = {}

--- A new game has nothing to migrate, mark every version as done.
local function on_init()
    local current = script.active_mods[script.mod_name]
    storage._changes = {}
    for _, versions in pairs(version_files) do
        for version in pairs(versions) do
            storage._changes[version] = current
        end
    end
end

--- Run the migrations this save has not run yet, oldest version first.
--- @param event table on_configuration_changed
local function on_configuration_changed(event)
    local change = event.mod_changes and event.mod_changes[script.mod_name]
    if not change then
        return
    end
    storage._changes = storage._changes or {}

    if change.old_version then
        local pending = {}
        for _, versions in pairs(version_files) do
            for version, migrate in pairs(versions) do
                if not storage._changes[version] then
                    pending[#pending + 1] = {version = version, migrate = migrate}
                end
            end
        end
        table.sort(pending, function(a, b)
            return helpers.compare_versions(a.version, b.version) < 0
        end)
        for _, entry in ipairs(pending) do
            entry.migrate()
            storage._changes[entry.version] = change.new_version
            log('Migration completed for version ' .. entry.version)
        end
    end

    log(script.mod_name .. ': version changed from ' .. tostring(change.old_version) .. ' to ' .. tostring(change.new_version))
end

--- Register a version file. Call it once, while control.lua loads.
--- @param path string require path of the version file
--- @return table Changes
function Changes.register_versions(path)
    if next(version_files) == nil then
        Event.register(Event.core_events.init, on_init)
        Event.register(Event.core_events.configuration_changed, on_configuration_changed)
    end
    version_files[path] = require(path)
    return Changes
end

return Changes
