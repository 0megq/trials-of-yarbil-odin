package game

import "core:math"

Vec2i :: [2]i32
Vec2 :: [2]f32

length :: proc(v: Vec2) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

abs :: proc(v: Vec2) -> Vec2 {
	return {math.abs(v.x), math.abs(v.y)}
}

sign :: proc(v: Vec2) -> Vec2 {
	return {math.sign(v.x), math.sign(v.y)}
}

normalize :: proc(v: Vec2) -> Vec2 {
	length := length(v)
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

angle :: proc(v: Vec2) -> f32 {
	return math.atan2(v.y, v.x) * math.DEG_PER_RAD
}

angle_between :: proc(v1: Vec2, v2: Vec2) -> f32 {
	if length(v1) == 0 || length(v2) == 0 { 	// avoid division by zero
		return 0
	}
	return math.acos(dot(v1, v2) / (length(v1) * length(v2))) * math.DEG_PER_RAD
}
