local constants = {}
constants.projectile_animation = {
    layers = {
        {
            filename = '__base__/graphics/entity/defender-robot/defender-robot.png',
            priority = 'high',
            line_length = 16,
            width = 56,
            height = 59,
            frame_count = 16,
            direction_count = 1,
            shift = {0, 0.015625},
            scale = 0.25
        },
        {
            filename = '__base__/graphics/entity/defender-robot/defender-robot-mask.png',
            priority = 'high',
            line_length = 16,
            width = 28,
            height = 21,
            frame_count = 16,
            direction_count = 1,
            shift = {0, -0.125},
            apply_runtime_tint = true,
            scale = 0.25
        },
        {
            filename = '__base__/graphics/entity/defender-robot/defender-robot-shadow.png',
            priority = 'high',
            line_length = 16,
            width = 88,
            height = 50,
            frame_count = 16,
            direction_count = 1,
            shift = {0.859375, 0.609375},
            scale = 0.25
        }
    }
}

function constants.cloud_animation(scale)
    scale = scale or .4
    return {
        filename = '__Nanobots2__/graphics/entity/cloud/cloud-45-frames.png',
        --flags = {'compressed'},
        priority = 'low',
        width = 256,
        height = 256,
        frame_count = 45,
        animation_speed = 0.5,
        line_length = 7,
        scale = scale,
        shift = {0.0, 0.75}
    }
end

return constants
