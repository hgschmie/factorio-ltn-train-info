--- Tools for working with `<x,y>` coordinates.
-- @module Area.Position
-- @usage local Position = require('stdlib.area/position')
-- @see Area.Area
-- @see Position
-- @see defines.direction
---@class PositionLibrary
local Position = { __class = 'Position', __index = require('stdlib.core') }
setmetatable(Position, Position)

package.loaded['__' .. script.mod_name .. '__/' .. (...):gsub('%.', '/') .. '.lua'] = Position

local Area = require('stdlib.area.area')
local Direction = require('stdlib.area.direction')
local Orientation = require('stdlib.area.orientation')

local string = require('stdlib.utils.string')
local math = require('stdlib.utils.math')

local floor, abs, atan2, round_to, round = math.floor, math.abs, math.atan2, math.round_to, math.round
local cos, sin, ceil, sqrt, pi, random = math.cos, math.sin, math.ceil, math.sqrt, math.pi, math.random
local deg, acos, max, min, is_number = math.deg, math.acos, math.max, math.min, math.is_number
local split = string.split
local directions = defines.direction

local EPSILON = 1.19e-07
local ORIGIN = { x = 0, y = 0 }

local metatable
--- Constructor Methods
-- @section Constructors

Position.__call = function(_, ...)
    local type = type((...))
    if type == 'table' then
        local t = (...)
        if t.x and t.y then
            return Position.load(...)
        else
            return Position.new(...)
        end
    elseif type == 'string' then
        return Position.from_string(...)
    else
        return Position.construct(...)
    end
end

local function new(x, y)
    return setmetatable({ x = x, y = y }, metatable)
end

--- Returns a correctly formated position object.
-- @usage Position.new({0, 0}) -- returns {x = 0, y = 0}
---@param pos MapPosition the position table or array to convert
---@return MapPosition
function Position.new(pos)
    return new(pos.x or pos[1] or 0, pos.y or pos[2] or 0)
end

--- Creates a table representing the position from x and y.
---@param ... number x and y coordinates
---@return MapPosition
function Position.construct(...)
    -- was self was passed as first argument?
    local args = type((...)) == 'table' and { select(2, ...) } or { select(1, ...) }
    return new(args[1] or 0, args[2] or args[1] or 0)
end

function Position.construct_xy(x, y)
    return new(x, y)
end

--- Update a position in place without returning a new position.
---@param pos MapPosition
---@param x number
---@param y number
---@return MapPosition position the passed position updated.
function Position.update(pos, x, y)
    pos.x, pos.y = x, y
    return pos
end

--- Load the metatable into the passed position without creating a new one.
-- Always assumes a valid position is passed
---@param pos MapPosition the position to set the metatable onto
---@return MapPosition position the position with metatable attached
function Position.load(pos)
    return setmetatable(pos, metatable)
end

--- Converts a position string to a position.
---@param pos_string string the position to convert
---@return MapPosition
function Position.from_string(pos_string)
    return Position(load('return ' .. pos_string)())
end

--- Converts a string key position to a position.
---@param pos_string string the position to convert
---@return MapPosition
function Position.from_key(pos_string)
    local tab = split(pos_string, ',', false, tonumber)
    return new(tab[1], tab[2])
end

--- Gets the left top tile position of a chunk from the chunk position.
---@param pos MapPosition
---@return MapPosition
function Position.from_chunk_position(pos)
    local x, y = (floor(pos.x) * 32), (floor(pos.y) * 32)
    return new(x, y)
end

--- Convert position from pixels
---@param pos MapPosition
---@return MapPosition position
function Position.from_pixels(pos)
    local x = pos.x / 32
    local y = pos.y / 32
    return new(x, y)
end

--- Position Methods
-- @section Methods

--- Addition of two positions.
---@param pos1 MapPosition
---@param ... MapPosition|number position or x, y values.
---@return MapPosition position pos1 with pos2 added
function Position.add(pos1, ...)
    pos1 = Position(pos1)
    local pos2 = Position(...)
    return new(pos1.x + pos2.x, pos1.y + pos2.y)
end

--- Subtraction of two positions..
---@param pos1 MapPosition
---@param ... MapPosition|number position or x, y values
---@return MapPosition position pos1 with pos2 subtracted
function Position.subtract(pos1, ...)
    pos1 = Position(pos1)
    local pos2 = Position(...)
    return new(pos1.x - pos2.x, pos1.y - pos2.y)
end

--- Multiplication of two positions.
---@param pos1 MapPosition
---@param ... MapPosition|number position or x, y values
---@return MapPosition position pos1 multiplied by pos2
function Position.multiply(pos1, ...)
    pos1 = Position(pos1)
    local pos2 = Position(...)
    return new(pos1.x * pos2.x, pos1.y * pos2.y)
end

--- Division of two positions.
---@param pos1 MapPosition
---@param ... MapPosition|number position or x, y values
---@return MapPosition position pos1 divided by pos2
function Position.divide(pos1, ...)
    pos1 = Position(pos1)
    local pos2 = Position(...)
    return new(pos1.x / pos2.x, pos1.y / pos2.y)
end

--- Modulo of two positions.
---@param pos1 MapPosition
---@param ... MapPosition|number position or x, y values
---@return MapPosition position pos1 modulo pos2
function Position.mod(pos1, ...)
    pos1 = Position(pos1)
    local pos2 = Position(...)
    return new(pos1.x % pos2.x, pos1.y % pos2.y)
end

--- Return the closest position to the first position.
---@param pos1 MapPosition The position to find the closest too
---@param positions MapPosition[] array of MapPosition
---@return MapPosition
function Position.closest(pos1, positions)
    local x, y = pos1.x, pos1.y
    local closest = math.MAXINT32
    for _, pos in pairs(positions) do
        local distance = Position.distance(pos1, pos)
        if distance < closest then
            x, y = pos.x, pos.y
            closest = distance
        end
    end
    return new(x, y)
end

--- Return the farthest position from the first position.
---@param pos1 MapPosition The position to find the farthest from
---@param positions MapPosition[] array of MapPosition
---@return MapPosition
function Position.farthest(pos1, positions)
    local x, y = pos1.x, pos1.y
    local closest = 0
    for _, pos in pairs(positions) do
        local distance = Position.distance(pos1, pos)
        if distance > closest then
            x, y = pos.x, pos.y
            closest = distance
        end
    end
    return new(x, y)
end

--- The middle of two positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return MapPosition position the middle of two positions
function Position.between(pos1, pos2)
    return new((pos1.x + pos2.x) / 2, (pos1.y + pos2.y) / 2)
end

--- The projection point of two positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return MapPosition position the projected position
function Position.projection(pos1, pos2)
    local s = (pos1.x * pos2.x + pos1.y * pos2.y) / (pos2.x * pos2.x + pos2.y * pos2.y)
    return new(s * pos2.x, s * pos2.y)
end

--- The reflection point or two positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return MapPosition position the reflected position
function Position.reflection(pos1, pos2)
    local s = 2 * (pos1.x * pos2.x + pos1.y * pos2.y) / (pos2.x * pos2.x + pos2.y * pos2.y)
    return new(s * pos2.x - pos1.x, s * pos2.y - pos1.y)
end

--- Stores the position for recall later, not deterministic.
-- Only the last position stored is saved.
---@param pos MapPosition
function Position.store(pos)
    rawset(getmetatable(pos), '_saved', pos)
    return pos
end

--- Recalls the stored position.
---@param pos MapPosition
---@return MapPosition position the stored position
function Position.recall(pos)
    return rawget(getmetatable(pos), '_saved')
end

--- Normalizes a position by rounding it to 2 decimal places.
---@param pos MapPosition
---@return MapPosition position a new normalized position
function Position.normalize(pos)
    return new(round_to(pos.x, 2), round_to(pos.y, 2))
end

--- Abs x, y values
---@param pos MapPosition
---@return MapPosition
function Position.abs(pos)
    return new(abs(pos.x), abs(pos.y))
end

--- Ceil x, y values.
---@param pos MapPosition
---@return MapPosition
function Position.ceil(pos)
    return new(ceil(pos.x), ceil(pos.y))
end

--- Floor x, y values.
---@param pos MapPosition
---@return MapPosition
function Position.floor(pos)
    return new(floor(pos.x), floor(pos.y))
end

local function pos_center(pos)
    local x, y
    local ceil_x = ceil(pos.x)
    local ceil_y = ceil(pos.y)
    x = pos.x >= 0 and floor(pos.x) + 0.5 or (ceil_x == pos.x and ceil_x + 0.5 or ceil_x - 0.5)
    y = pos.y >= 0 and floor(pos.y) + 0.5 or (ceil_y == pos.y and ceil_y + 0.5 or ceil_y - 0.5)
    return x, y
end

--- The center position of the tile where the given position resides.
---@param pos MapPosition
---@return MapPosition position a new position at the center of the tile
function Position.center(pos)
    return new(pos_center(pos))
end

--- Rounds a positions points to the closest integer.
---@param pos MapPosition
---@return MapPosition position a new rounded position
function Position.round(pos)
    return new(round(pos.x), round(pos.y))
end

--- Perpendicular position.
---@param pos MapPosition
---@return MapPosition position
function Position.perpendicular(pos)
    return new(-pos.y, pos.x)
end

--- Swap the x and y coordinates.
---@param pos MapPosition
---@return MapPosition position a new position with x and y swapped
function Position.swap(pos)
    return new(pos.y, pos.x)
end

--- Flip the signs of the position.
---@param pos MapPosition
---@return MapPosition position a new position with flipped signs
function Position.flip(pos)
    return new(-pos.x, -pos.y)
end
Position.unary = Position.flip

--- Flip the x sign.
---@param pos MapPosition
---@return MapPosition position a new position with the sign of x flipped
function Position.flip_x(pos)
    return new(-pos.x, pos.y)
end

--- Flip the y sign.
---@param pos MapPosition
---@return MapPosition position a new position with the sign of y flipped
function Position.flip_y(pos)
    return new(pos.x, -pos.y)
end

--- Lerp position of pos1 and pos2.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@param alpha number 0-1 how close to get to position 2
---@return MapPosition position the interpolated position
function Position.lerp(pos1, pos2, alpha)
    local x = pos1.x + (pos2.x - pos1.x) * alpha
    local y = pos1.y + (pos2.y - pos1.y) * alpha
    return new(x, y)
end

---  Trim the position to a length.
---@param pos MapPosition
---@param max_len number
function Position.trim(pos, max_len)
    local s = max_len * max_len / (pos.x * pos.x + pos.y * pos.y)
    s = (s > 1 and 1) or sqrt(s)
    return new(pos.x * s, pos.y * s)
end

--- Returns the position along line between source and target, at the distance from target.
---@param pos1 MapPosition where the line starts and extends from.
---@param pos2 MapPosition where the line ends and is offset back from.
---@param distance_from_pos2 number backwards from pos1 for the new position.
---@return MapPosition position a point along the line between source and target, offset back from the target
function Position.offset_along_line(pos1, pos2, distance_from_pos2)
    distance_from_pos2 = distance_from_pos2 or 0

    local angle = Position.atan2(pos1, pos2)
    local veclength = Position.distance(pos1, pos2) - distance_from_pos2

    -- From source_position, project the point along the vector at angle, and veclength
    local x = pos1.x + round_to(sin(angle) * veclength, 2)
    local y = pos1.y + round_to(cos(angle) * veclength, 2)

    return new(x, y)
end

--- Translates a position in the given direction.
---@param pos MapPosition the position to translate
---@param direction defines.direction the direction of translation
---@param distance number distance of the translation
---@return MapPosition position a new translated position
function Position.translate(pos, direction, distance)
    direction = direction or 0
    distance = distance or 1
    return Position.add(pos, Direction.to_vector(direction, distance))
end

--- Return a random offset of a position.
---@param pos MapPosition the position to randomize
---@param minimum? number the minimum amount to offset
---@param maximum? number the maximum amount to offset
---@param random_tile? boolean randomize the location on the tile
---@return MapPosition position a new randomly offset position
function Position.random(pos, minimum, maximum, random_tile)
    local rand_x = random(minimum or 0, maximum or 1)
    local rand_y = random(minimum or 0, maximum or 1)
    local x = pos.x + (random() >= .5 and -rand_x or rand_x) + (random_tile and random() or 0)
    local y = pos.y + (random() >= .5 and -rand_y or rand_y) + (random_tile and random() or 0)
    return new(x, y)
end

local function get_array(...)
    local array = select(2, ...)
    if array then
        table.insert(array, (...))
    else
        array = (...)
    end
    return array
end

--- Return the average position of the passed positions.
---@param ... MapPosition|MapPosition[] positions to average
---@return MapPosition position a new position
function Position.average(...)
    local positions = get_array(...)
    local avg = new(0, 0)
    for _, pos in ipairs(positions) do Position.add(avg, pos) end
    return Position.divide(avg, #positions)
end

--- Return the minimum position of the passed positions.
---@param ... MapPosition|MapPosition[] positions to compare
---@return MapPosition position a new position
function Position.min(...)
    local positions = get_array(...)
    local x, y
    local len = math.MAXINT32
    for _, pos in pairs(positions) do
        local cur_len = Position.len(pos)
        if cur_len < len then
            len = cur_len
            x, y = pos.x, pos.y
        end
    end
    return new(x, y)
end

--- Return the maximum position of the passed positions.
---@param ... MapPosition|MapPosition[] positions to compare
---@return MapPosition position a new position
function Position.max(...)
    local positions = get_array(...)
    local x, y
    local len = -math.MAXINT32
    for _, pos in pairs(positions) do
        local cur_len = Position.len(pos)
        if cur_len > len then
            len = cur_len
            x, y = pos.x, pos.y
        end
    end
    return new(x, y)
end

--- Return a position created from the smallest x, y values in the passed positions.
---@param ... MapPosition|MapPosition[] positions to compare
---@return MapPosition position a new position
function Position.min_xy(...)
    local positions = get_array(...)
    local x, y = positions[1].x, positions[1].y
    for _, pos in pairs(positions) do
        x = min(x, pos.x)
        y = min(y, pos.y)
    end
    return new(x, y)
end

--- Return a position created from the largest x, y values in the passed positions.
---@param ... MapPosition|MapPosition[] positions to compare
---@return MapPosition position a new position
function Position.max_xy(...)
    local positions = get_array(...)
    local x, y = positions[1].x, positions[1].y
    for _, pos in pairs(positions) do
        x = max(x, pos.x)
        y = max(y, pos.y)
    end
    return new(x, y)
end

--- The intersection of 4 positions.
---@return MapPosition position a new position
function Position.intersection(pos1_start, pos1_end, pos2_start, pos2_end)
    local d = (pos1_start.x - pos1_end.x) * (pos2_start.y - pos2_end.y) - (pos1_start.y - pos1_end.y) *
        (pos2_start.x - pos2_end.x)
    local a = pos1_start.x * pos1_end.y - pos1_start.y * pos1_end.x
    local b = pos2_start.x * pos2_end.y - pos2_start.y * pos2_end.x
    local x = (a * (pos2_start.x - pos2_end.x) - (pos1_start.x - pos1_end.x) * b) / d
    local y = (a * (pos2_start.y - pos2_end.y) - (pos1_start.y - pos1_end.y) * b) / d
    return is_number(x) and is_number(y) and new(x, y) or pos1_start
end

--- Position Mutate Methods
-- @section Mutate Methods

--- Normalizes a position by rounding it to 2 decimal places.
---@param pos MapPosition
---@return MapPosition position the normalized position, mutated in place
function Position.normalized(pos)
    pos.x, pos.y = round_to(pos.x, 2), round_to(pos.y, 2)
    return pos
end

--- Abs x, y values
---@param pos MapPosition
---@return MapPosition position the absolute position, mutated in place
function Position.absed(pos)
    pos.x, pos.y = abs(pos.x), abs(pos.y)
    return pos
end

--- Ceil x, y values in place.
---@param pos MapPosition
---@return MapPosition position the ceiled position, mutated in place
function Position.ceiled(pos)
    pos.x, pos.y = ceil(pos.x), ceil(pos.y)
    return pos
end

--- Floor x, y values.
---@param pos MapPosition
---@return MapPosition position the floored position, mutated in place
function Position.floored(pos)
    pos.x, pos.y = floor(pos.x), floor(pos.y)
    return pos
end

--- The center position of the tile where the given position resides.
---@param pos MapPosition
---@return MapPosition position the centered position, mutated in place
function Position.centered(pos)
    pos.x, pos.y = pos_center(pos)
    return pos
end

--- Rounds a positions points to the closest integer.
---@param pos MapPosition
---@return MapPosition position the rounded position, mutated in place
function Position.rounded(pos)
    pos.x, pos.y = round(pos.x), round(pos.y)
    return pos
end

--- Swap the x and y coordinates.
---@param pos MapPosition
---@return MapPosition position the swapped position, mutated in place
function Position.swapped(pos)
    pos.x, pos.y = pos.y, pos.x
    return pos
end

--- Flip the signs of the position.
---@param pos MapPosition
---@return MapPosition position the flipped position, mutated in place
function Position.flipped(pos)
    pos.x, pos.y = -pos.x, -pos.y
    return pos
end

--- Position Conversion Methods
-- @section Position Conversion Methods
-- Test Comment

--- Convert to pixels from position
---@param pos MapPosition
---@return MapPosition position
function Position.to_pixels(pos)
    local x = pos.x * 32
    local y = pos.y * 32
    return new(x, y)
end

--- Gets the chunk position of a chunk where the specified position resides.
---@param pos MapPosition a position residing somewhere in a chunk
---@return ChunkPosition chunk_position a new chunk position
-- @usage local chunk_x = Position.chunk_position(pos).x
function Position.to_chunk_position(pos)
    local x, y = floor(pos.x / 32), floor(pos.y / 32)
    return new(x, y)
end

--- Area Conversion Methods
-- @section Area Conversion Methods

--- Expands a position to a square area.
---@param pos MapPosition the position to expand into an area
---@param radius number half of the side length of the area
---@return BoundingBox area the area
function Position.expand_to_area(pos, radius)
    radius = radius or 1

    local left_top = { x = pos.x - radius, y = pos.y - radius }
    local right_bottom = { x = pos.x + radius, y = pos.y + radius }

    return Area { left_top = left_top, right_bottom = right_bottom }
end

--- Expands a position into an area by setting pos to left_top.
---@param pos MapPosition
---@param width number
---@param height number
---@return BoundingBox
function Position.to_area(pos, width, height)
    width = width or 0
    height = height or width

    local left_top = { x = pos.x, y = pos.y }
    local right_bottom = { x = pos.x + width, y = pos.y + height }

    return Area { left_top = left_top, right_bottom = right_bottom }
end

--- Converts a tile position to the @{BoundingBox|area} of the tile it is in.
---@param pos TilePosition the tile position
---@return BoundingBox area the area of the tile
function Position.to_tile_area(pos)
    local x, y = floor(pos.x), floor(pos.y)
    local left_top = { x = x, y = y }
    local right_bottom = { x = x + 1, y = y + 1 }

    return Area { left_top = left_top, right_bottom = right_bottom }
end

--- Get the chunk area the specified position is in.
---@param pos MapPosition
---@return BoundingBox
function Position.to_chunk_area(pos)
    local left_top = { x = floor(pos.x / 32) * 32, y = floor(pos.y / 32) * 32 }
    local right_bottom = { x = left_top.x + 32, y = left_top.y + 32 }

    return Area { left_top = left_top, right_bottom = right_bottom }
end

--- Get the chunk area for the specified chunk position.
---@param pos ChunkPosition
---@return BoundingBox area the chunk position's area
function Position.chunk_position_to_chunk_area(pos)
    local left_top = { x = pos.x * 32, y = pos.y * 32 }
    local right_bottom = { left_top.x + 32, left_top.y + 32 }
    return Area { left_top = left_top, right_bottom = right_bottom }
end

--- Position Functions
-- @section Functions

--- Gets the squared length of a position
---@param pos MapPosition
---@return number
function Position.len_squared(pos)
    return pos.x * pos.x + pos.y * pos.y
end

--- Gets the length of a position
---@param pos MapPosition
---@return number
function Position.len(pos)
    return (pos.x * pos.x + pos.y * pos.y) ^ 0.5
end

--- Converts a position to a string.
---@param pos MapPosition the position to convert
---@return string position_string string representation of the position
function Position.to_string(pos)
    return '{x = ' .. pos.x .. ', y = ' .. pos.y .. '}'
end

--- Converts a position to an x, y string.
---@param pos MapPosition the position to convert
---@return string
function Position.to_string_xy(pos)
    return pos.x .. ', ' .. pos.y
end

--- Converts a position to a string suitable for using as a table index.
---@param pos MapPosition the position to convert
---@return string
function Position.to_key(pos)
    return pos.x .. ',' .. pos.y
end

--- Unpack a position into a tuple.
---@param pos MapPosition the position to unpack
---@return number x
---@return number y
function Position.unpack(pos)
    return pos.x, pos.y
end

--- Packs a position into an array.
---@param pos MapPosition the position to pack
---@return number[]
function Position.pack(pos)
    return { pos.x, pos.y }
end

--- Is this position {0, 0}.
---@param pos MapPosition
---@return boolean
function Position.is_zero(pos)
    return pos.x == 0 and pos.y == 0
end

--- Is a position inside of an area.
---@param pos MapPosition The pos to check
---@param area BoundingBox The area to check.
---@return boolean inside true if the position is inside the area
function Position.inside(pos, area)
    local lt = area.left_top
    local rb = area.right_bottom

    return pos.x >= lt.x and pos.y >= lt.y and pos.x <= rb.x and pos.y <= rb.y
end

--- Is this a simple position. {num, num}
---@param pos MapPosition
---@return boolean
function Position.is_simple_position(pos)
    return type(pos) == 'table' and type(pos[1]) == 'number' and type(pos[2]) == 'number'
end

--- Is this a complex position. {x = number, y = number}
---@param pos MapPosition
---@return boolean
function Position.is_complex_position(pos)
    return type(pos) == 'table' and type(pos.x) == 'number' and type(pos.y) == 'number'
end

--- Does the position have the class attached
---@param pos MapPosition
---@return boolean
function Position.is_Position(pos)
    return getmetatable(pos) == metatable
end

--- Is this any position
---@param pos MapPosition
---@return boolean
function Position.is_position(pos)
    return Position.is_Position(pos) or Position.is_complex_position(pos) or Position.is_simple_position(pos)
end

--- Return the atan2 of 2 positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return number
function Position.atan2(pos1, pos2)
    return atan2(pos2.x - pos1.x, pos2.y - pos1.y)
end

--- The angle between two positions
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return number
function Position.angle(pos1, pos2)
    local dist = Position.distance(pos1, pos2)
    if dist ~= 0 then
        return deg(acos((pos1.x * pos2.x + pos1.y * pos2.y) / dist))
    else
        return 0
    end
end

--- Return the cross product of two positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return number
function Position.cross(pos1, pos2)
    return pos1.x * pos2.y - pos1.y * pos2.x
end

-- Return the dot product of two positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return number
function Position.dot(pos1, pos2)
    return pos1.x * pos2.x + pos1.y * pos2.y
end

--- Tests whether or not the two given positions are equal.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return boolean equal true if the positions are equal
function Position.equals(pos1, pos2)
    if not (pos1 and pos2) then return false end

    return abs(pos1.x - pos2.x) < EPSILON and abs(pos1.y - pos2.y) < EPSILON
end

--- Is pos1 less than pos2.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return boolean
function Position.less_than(pos1, pos2)
    return Position.len(pos1) < Position.len(pos2)
end

--- Is pos1 less than or equal to pos2.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return boolean
function Position.less_than_eq(pos1, pos2)
    return Position.len(pos1) <= Position.len(pos2)
end

--- Calculates the Euclidean distance squared between two positions, useful when sqrt is not needed.
---@param pos1 MapPosition
---@param pos2? MapPosition
---@return number distance_squared the square of the Euclidean distance
function Position.distance_squared(pos1, pos2)
    pos2 = pos2 or ORIGIN
    local ax_bx = pos1.x - pos2.x
    local ay_by = pos1.y - pos2.y
    return ax_bx * ax_bx + ay_by * ay_by
end

--- Calculates the Euclidean distance between two positions.
---@param pos1 MapPosition
---@param pos2? MapPosition
---@return number distance the Euclidean distance
function Position.distance(pos1, pos2)
    pos2 = pos2 or ORIGIN
    local ax_bx = pos1.x - pos2.x
    local ay_by = pos1.y - pos2.y
    return (ax_bx * ax_bx + ay_by * ay_by) ^ 0.5
end

--- Calculates the Manhattan distance between two positions.
---@param pos1 MapPosition
---@param pos2? MapPosition the second position
---@return number distance the Manhattan distance
-- @see https://en.wikipedia.org/wiki/Taxicab_geometry Taxicab geometry (Manhattan distance)
function Position.manhattan_distance(pos1, pos2)
    pos2 = pos2 or ORIGIN
    return abs(pos2.x - pos1.x) + abs(pos2.y - pos1.y)
end

--- Returms the direction to a position using simple delta comparisons.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return defines.direction
function Position.direction_to(pos1, pos2)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    if dx ~= 0 then
        if dy == 0 then
            return dx > 0 and directions.west or directions.east
        else
            local adx, ady = abs(dx), abs(dy)
            if adx > ady then
                return dx > 0 and directions.north or directions.south
            else
                return dy > 0 and directions.west or directions.east
            end
        end
    else
        return dy > 0 and directions.north or directions.south
    end
end

--- Returns the direction to a position.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@param eight_way boolean return the eight way direction
---@return defines.direction
function Position.complex_direction_to(pos1, pos2, eight_way)
    return Orientation.to_direction(Position.orientation_to(pos1, pos2), eight_way)
end

function Position.orientation_to(pos1, pos2)
    return (1 - (Position.atan2(pos1, pos2) / pi)) / 2
end

--- Increment a position each time it is called.
-- This can be used to increment or even decrement a position quickly.
-- <p>Do not store function closures in the global object; use them in the current tick.
-- @usage
-- local next_pos = Position.increment({0,0})
-- for i = 1, 5 do next_pos(0,1) -- returns {x = 0, y = 1} {x = 0, y = 2} {x = 0, y = 3} {x = 0, y = 4} {x = 0, y = 5}
-- @usage
-- local next_pos = Position.increment({0, 0}, 1)
-- next_pos() -- returns {1, 0}
-- next_pos(0, 5) -- returns {1, 5}
-- next_pos(nil, 5) -- returns {2, 10}
-- @usage
-- local next_pos = Position.increment({0, 0}, 0, 1)
-- surface.create_entity{name = 'flying-text', text = 'text', position = next_pos()}
-- surface.create_entity{name = 'flying-text', text = 'text', position = next_pos()} -- creates two flying text entities 1 tile apart
---@param pos MapPosition the position to start with
---@param inc_x? number optional increment x by this amount
---@param inc_y? number optional increment y by this amount
---@param increment_initial? boolean Whether the first use should be incremented
---@return function iterator a function closure that returns a new incremented position
function Position.increment(pos, inc_x, inc_y, increment_initial)
    local x, y = pos.x, pos.y
    inc_x, inc_y = inc_x or 0, inc_y or 0

    --- A closure which the @{increment} function returns.
    -- @function increment_closure
    -- > Do not call this directly and do not store this in the global object.
    -- @see increment
    ---@param new_inc_x? number
    ---@param new_inc_y? number
    ---@return MapPosition position the incremented position
    return function(new_inc_x, new_inc_y)
        if increment_initial then
            x = x + (new_inc_x or inc_x)
            y = y + (new_inc_y or inc_y)
        else
            x = x
            y = y
            increment_initial = true
        end
        return new(x, y)
    end
end

--- Metamethods
-- @section Metamethods

--- Position tables are returned with these metamethods attached.
-- Methods that return a position will return a NEW position without modifying the passed positions.
-- @table Metamethods
metatable = {
    __class = 'position',
    __index = Position, -- If key is not found, see if there is one availble in the Position module.
    __add = Position.add, -- Adds two position together. Returns a new position.
    __sub = Position.subtract, -- Subtracts one position from another. Returns a new position.
    __mul = Position.multiply, -- Multiply 2 positions. Returns a new position.
    __div = Position.divide, -- Divide 2 positions. Returns a new position.
    __mod = Position.mod, -- Modulo of 2 positions. Returns a new position.
    __unm = Position.flip, -- Unary Minus of a position. Returns a new position.
    __len = Position.len, -- Length of a single position.
    __eq = Position.equals, -- Are two positions at the same spot.
    __lt = Position.less_than, -- Is position1 less than position2.
    __le = Position.less_than_eq, -- Is position1 less than or equal to position2.
    __tostring = Position.to_string, -- Returns a string representation of the position
    __concat = _ENV.concat, -- calls tostring on both sides of concact.
    __call = Position.new, -- copy the position.
    __debugline = [[<Position>{[}x={x},y={y}{]}]]
}

return Position
