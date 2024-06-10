package game

import "core:math"
import rl "vendor:raylib"

Shape :: union {
	rl.Rectangle,
	Polygon,
}

Polygon :: struct {
	pos:    Vec2,
	points: []Vec2,
}

RectCollision :: struct {
	delta:  f32, // the delta at which the collision occurred. 
	// if delta is negative then the recs are already inside each other
	normal: Vec2,
}

check_collision_polygons :: proc(a: Polygon, b: Polygon) -> bool {
	p1 := polygon_to_points(a)
	p2 := polygon_to_points(b)
	for i in 0 ..< 2 {
		if i == 1 {
			p1, p2 = swap(p1, p2)
		}

		for index in 0 ..< len(p1) {
			edge := p1[index] - p1[(index + 1) % len(p1)]
			normal := edge.yx * {-1, 1}

			min_p1, max_p1 := math.INF_F32, math.NEG_INF_F32
			for v in p1 {
				dot := dot(v, normal)
				min_p1 = min(min_p1, dot)
				max_p1 = max(max_p1, dot)
			}

			min_p2, max_p2 := math.INF_F32, math.NEG_INF_F32
			for v in p2 {
				dot := dot(v, normal)
				min_p2 = min(min_p2, dot)
				max_p2 = max(max_p2, dot)
			}

			if max_p1 < min_p2 || max_p2 < min_p1 {
				return false
			}
		}
	}
	return true
}

// Copy the result of this proc if you want to save it past the current frame. Allocates using context.temp_allocator
polygon_to_points :: proc(polygon: Polygon) -> []Vec2 {
	result := make([]Vec2, len(polygon.points), context.temp_allocator)
	for i in 0 ..< len(polygon.points) {
		result[i] = polygon.points[i] + polygon.pos
	}
	return result
}

// Copy the result of this proc if you want to save it past the current frame. Allocates using context.temp_allocator
rotate_points :: proc(points: []Vec2, deg: f32) -> []Vec2 {
	new_points := make([]Vec2, len(points), context.temp_allocator)
	for i in 0 ..< len(points) {
		new_points[i] = rotate_vector(points[i], deg)
	}
	return new_points
}

// Copy the result of this proc if you want to save it past the current frame. Allocates using context.temp_allocator
rotate_polygon :: proc(p: Polygon, deg: f32) -> Polygon {
	points := rotate_points(p.points, deg)
	return {p.pos, points}
}

// Polygon must be in clockwise order! 
draw_polygon :: proc(polygon: Polygon, color: rl.Color) {
	points := polygon_to_points(polygon)
	summed_points: Vec2
	for p in points {
		summed_points += p
	}

	average_point: Vec2 = summed_points / f32(len(points))
	for i in 0 ..< len(points) {
		rl.DrawTriangle(points[i], average_point, points[(i + 1) % len(points)], color)
	}
}

draw_polygon_lines :: proc(polygon: Polygon, color: rl.Color) {
	points := polygon_to_points(polygon)
	for i in 0 ..< len(points) {
		rl.DrawLineV(points[i], points[(i + 1) % len(points)], color)
	}
}

get_centered_rect :: proc(center: Vec2, size: Vec2) -> rl.Rectangle {
	return {center.x - size.x * 0.5, center.y - size.y * 0.5, size.x, size.y}
}

get_center :: proc(rect: rl.Rectangle) -> Vec2 {
	return {rect.x, rect.y} + {rect.width, rect.height} * 0.5
}

rect_to_points :: proc(rect: rl.Rectangle) -> [4]Vec2 {
	tl := Vec2{rect.x, rect.y}
	tr := tl + {rect.width, 0}
	br := tl + {rect.width, rect.height}
	bl := tl + {0, rect.height}
	return {tl, tr, br, bl}
}

rect_to_polygon :: proc(rect: rl.Rectangle) -> Polygon {
	tl := Vec2{rect.width, rect.height} * -0.5
	tr := tl * {-1, 1}
	br := tl * {-1, -1}
	bl := tl * {1, -1}

	return {get_center(rect), {tl, tr, br, bl}}
}

// Sweep the current aabb to the other AABB with the given velocity and delta. The delta at which the collision occurred is returned.
// Will return null if aabbs are inside each other
// rect is the box that the velocity is being applied to
// sweep_rect :: proc(rect: , : rl.Rectangle, vel: Vec2) -> (RectCollision, bool) {
// 	segment_start: Vec2 = {rect.x, rect.y} // So we don't accidentally change the position
// 	padded_rect: rl.Rectangle = { 	// New rect with size of other and box combined.
// 		other.x - rect.width,
// 		other.y - rect.height,
// 		rect.width + rect.width,
// 		rect.height + rect.height,
// 	}

// 	// Variables to see which side the segment could potentially collide on
// 	top := segment_start.y <= padded_rect.y && vel.y > 0
// 	bottom := segment_start.y >= padded_rect.y + padded_rect.height && vel.y < 0
// 	left := segment_start.x <= padded_rect.x && vel.x > 0
// 	right := segment_start.x >= padded_rect.x + padded_rect.width && vel.x < 0

// 	col_set: bool
// 	col: RectCollision

// 	if top {
// 		// Get y position. See where the ray is at that y position
// 		delta_to := (padded_rect.y - segment_start.y) / vel.y
// 		x_at_delta := segment_start.x + vel.x * delta_to
// 		// Check if the x position after being integrated by delta_to * vel is within the bounds of the padded AABB
// 		if (x_at_delta > padded_rect.x && x_at_delta < padded_rect.x + padded_rect.width) {
// 			// Potential collision
// 			// delta_to is the delta at which the collision occurred. This will be returned
// 			// The smaller delta_to indicates collision happened earlier so we will get minimum between the current col delta and delta to
// 			// so that the smallest delta to is returned
// 			if (!col_set || delta_to < col.delta) {
// 				col = {delta_to, {0, -1}}
// 				col_set = true
// 			}

// 		}
// 	}
// 	if (bottom) {
// 		delta_to := (padded_rect.y + padded_rect.height - segment_start.y) / vel.y
// 		x_at_delta := segment_start.x + vel.x * delta_to
// 		if (x_at_delta > padded_rect.x && x_at_delta < padded_rect.x + padded_rect.width) {
// 			if (!col_set || delta_to < col.delta) {
// 				col = {delta_to, {0, 1}}
// 				col_set = true
// 			}

// 		}
// 	}
// 	if (left) {
// 		delta_to := (padded_rect.x - segment_start.x) / vel.x
// 		y_at_delta := segment_start.y + vel.x * delta_to
// 		if (y_at_delta > padded_rect.y && y_at_delta < padded_rect.y + padded_rect.height) {
// 			if (!col_set || delta_to < col.delta) {
// 				col = {delta_to, {-1, 0}}
// 				col_set = true
// 			}
// 		}
// 	}
// 	if (right) {
// 		delta_to := (padded_rect.x + padded_rect.width - segment_start.x) / vel.x
// 		y_at_delta := segment_start.y + vel.y * delta_to
// 		if (y_at_delta > padded_rect.y && y_at_delta < padded_rect.y + padded_rect.height) {
// 			if (!col_set || delta_to < col.delta) {
// 				col = {delta_to, {1, 0}}
// 				col_set = true
// 			}

// 		}
// 	}
// 	return col, col_set
// }
