package game

import "core:fmt"
import rl "vendor:raylib"

Polygon :: struct {
	pos:    Vec2,
	points: []Vec2,
}

check_collision_polygons :: proc(p1: Polygon, p2: Polygon) -> bool {
	points1 := polygon_to_points(p1)
	points2 := polygon_to_points(p2)
	for i in 0 ..< 2 {
		if i == 1 {
			points1, points2 = swap(points1, points2)
		}
		fmt.printfln("%v and %v", points1, points2)
	}
	return false
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
