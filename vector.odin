package game

import "core:math"

Vec2i :: [2]i32
Vec2 :: [2]f32

get_length :: proc(v: Vec2) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

normalize :: proc(v: Vec2) -> Vec2 {
	length := get_length(v)
	if length == 0 {return {}}
	return v / length
}

get_angle :: proc(v: Vec2) -> f32 {
	return math.atan2(v.y, v.x) * math.DEG_PER_RAD
}
