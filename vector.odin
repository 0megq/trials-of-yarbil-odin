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

dot :: proc(v1: Vec2, v2: Vec2) -> f32 {
	return v1.x * v2.x + v1.y * v2.y
}

rotate_vector :: proc(v: Vec2, deg: f32) -> Vec2 {
	rad := deg * math.RAD_PER_DEG
	return {v.x * math.cos(rad) - v.y * math.sin(rad), v.x * math.sin(rad) + v.y * math.cos(rad)}
}

get_angle :: proc(v: Vec2) -> f32 {
	return math.atan2(v.y, v.x) * math.DEG_PER_RAD
}
