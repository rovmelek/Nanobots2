-- Luacheck config for Factorio 2.x. Based on the community Factorio luacheckrc,
-- kept in the repo so CI does not depend on a 1.1-era file fetched from the internet.
std = "lua52c"
max_line_length = false
cache = true
codes = true
ignore = {
    "212/_.*", -- unused argument, for vars with "_" prefix
    "211/_.*", -- unused local, for vars with "_" prefix
    "11./_",   -- setting or accessing the "_" global
    "631",     -- line is too long
}

-- .lua, .luarocks and .install are created in the workspace by the CI Lua setup actions.
exclude_files = {".git", ".pdn", ".lua", ".luarocks", ".install", "graphics", "sounds", "locale"}

-- Globals the mod writes to.
globals = {
    "storage", -- 2.x replacement for `global`
    "data",    -- data stage
}

-- Globals the mod only reads.
read_globals = {
    -- Factorio runtime
    "game", "script", "remote", "commands", "settings", "rcon", "rendering",
    "helpers", "prototypes", "defines", "log", "localised_print", "table_size",
    "serpent", "bit32",
    -- Data stage
    "util", "mods", "feature_flags",
}

-- lib/flib holds upstream flib files kept verbatim (see lib/flib/PROVENANCE.md): ignore its argument shadowing
-- (W412, W432), and table.deepcopy, which core's util adds to table in the data stage.
files["lib/flib/"] = {
    ignore = {"412", "432"},
    read_globals = {table = {fields = {"deepcopy"}}},
}

-- The offline harness (tools/harness) defines stubs of the Factorio API.
files["tools/harness/"] = {
    globals = {
        "script", "game", "defines", "settings", "prototypes", "helpers", "remote", "commands", "log", "serpent",
        "table_size", "mods", "data", "storage", "rendering", "rcon", "localised_print",
        table = {fields = {"deepcopy"}},
    },
}
