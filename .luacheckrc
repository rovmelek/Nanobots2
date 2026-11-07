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

exclude_files = {".git", ".pdn", "graphics", "sounds", "locale"}

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
    -- Added by stdlib2
    "prequire",
    -- Data stage
    "util", "mods", "feature_flags",
}
