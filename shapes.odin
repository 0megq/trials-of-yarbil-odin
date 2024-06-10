package game

import "core:math"
import rl "vendor:raylib"

Polygon :: struct {
	pos:    Vec2,
	points: []Vec2,
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
