--- Area helpers shared by the scripts, built on flib's bounding-box module.
local flib_bounding_box = require('__Nanobots2__.lib.flib.bounding-box')

local Area = {}

--- The square area within radius of pos. radius defaults to 1, as stdlib2's Position.expand_to_area did
--- (get_mining_drill_radius and mining_drill_radius are optional in the API).
--- @param pos MapPosition
--- @param radius number?
--- @return BoundingBox
function Area.around(pos, radius)
    radius = radius or 1
    return flib_bounding_box.from_dimensions(pos, 2 * radius, 2 * radius)
end

--- The box, or the box grown by 0.01 when it has no area, as stdlib2's Area:non_zero() did.
--- @param box BoundingBox
--- @return BoundingBox
function Area.non_zero(box)
    if flib_bounding_box.width(box) * flib_bounding_box.height(box) == 0 then
        return flib_bounding_box.resize(box, 0.01)
    end
    return box
end

return Area
