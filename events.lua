--- The events that mean an entity was built or is about to be removed, shared by the scripts.
local ev = defines.events

return {
    build = {ev.on_built_entity, ev.on_robot_built_entity, ev.script_raised_built, ev.script_raised_revive, ev.on_entity_cloned},
    mined = {ev.on_pre_player_mined_item, ev.on_robot_pre_mined, ev.script_raised_destroy}
}
