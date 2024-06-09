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

polygon_to_points :: proc(polygon: Polygon) -> []Vec2 {
	result := make([]Vec2, len(polygon.points), context.temp_allocator)
	for i in 0 ..< len(polygon.points) {
		result[i] = polygon.points[i] + polygon.pos
	}
	return result
}

rotate_points :: proc(points: []Vec2, deg: f32) -> []Vec2 {
	new_points := make([]Vec2, len(points), context.temp_allocator)
	for i in 0 ..< len(points) {
		new_points[i] = rotate_vector(points[i], deg)
	}
	return new_points
}

draw_polygon_lines :: proc(polygon: Polygon, color: rl.Color) {
	points := polygon_to_points(polygon)
	for i in 0 ..< len(points) {
		rl.DrawLineV(points[i], points[(i + 1) % len(points)], color)
	}
}
