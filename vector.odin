package game

import "core:math"

Vec2i :: [2]i32
Vec2 :: [2]f32

length :: proc(v: Vec2) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

length_squared :: proc(v: Vec2) -> f32 {
	return v.x * v.x + v.y * v.y
}

distance :: proc(v1: Vec2, v2: Vec2) -> f32 {
	return length(v1 - v2)
}

distance_squared :: proc(v1: Vec2, v2: Vec2) -> f32 {
	return length_squared(v1 - v2)
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

// Projects v onto axis
proj :: proc(axis: Vec2, v: Vec2) -> Vec2 {
	return dot(axis, v) * axis / length_squared(axis)
}

// Returns positive if rotating from v1 to v2 moves in a clockwise direction (right). Returns negative for counter-clockwise (left)
// Defined as v1.x * -v2.y + v1.y * v2.x
cross :: proc(v1: Vec2, v2: Vec2) -> f32 {
	return v1.x * -v2.y + v1.y * v2.x
}

// Rotates vector by +90 degrees (CCW)
perpindicular :: proc(v: Vec2) -> Vec2 {
	return v.yx * {-1, 1}
}

// Returns the component of the vector along the given axis, specificed by its normal vector
slide :: proc(v: Vec2, normal: Vec2) -> Vec2 {
	return v - normal * dot(v, normal)
}

rotate_vector :: proc(v: Vec2, deg: f32) -> Vec2 {
	rad := deg * math.RAD_PER_DEG
	return {v.x * math.cos(rad) - v.y * math.sin(rad), v.x * math.sin(rad) + v.y * math.cos(rad)}
}

rotate_about_origin :: proc(p: Vec2, origin: Vec2, deg: f32) -> Vec2 {
	return rotate_vector(p - origin, deg) + origin
}

// In degrees
angle :: proc(v: Vec2) -> f32 {
	return math.atan2(v.y, v.x) * math.DEG_PER_RAD
}

angle_between :: proc(v1: Vec2, v2: Vec2) -> f32 {
	if length(v1) == 0 || length(v2) == 0 { 	// avoid division by zero
		return 0
	}
	return math.acos(dot(v1, v2) / (length(v1) * length(v2))) * math.DEG_PER_RAD
}

vector_from_angle :: proc(deg: f32) -> Vec2 {
	return {math.cos(deg * math.RAD_PER_DEG), math.sin(deg * math.RAD_PER_DEG)}
}
