package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

COL_TRIANGLE_POINT_EPSILON :: 0.001

Rectangle :: rl.Rectangle

Shape :: union {
	Rectangle,
	Polygon,
	Circle,
}

Circle :: struct {
	pos:    Vec2,
	radius: f32,
}

Polygon :: struct {
	pos:      Vec2,
	points:   []Vec2,
	rotation: f32, // in degrees
}

// Returns the normal of the collision. The normal is {0, 0} if there is no collision.
// The normal is relative to shape_a. Normal points from a to b.
// depth is the scalar value when that represents the minimum separation needed so that shape_a will not collide with shape_b.
// min_sep is 0 if the shapes are touching on edges, negative if shapes are not colliding at all, positive if colliding
resolve_collision_shapes :: proc(
	shape_a: Shape,
	a_pos: Vec2,
	shape_b: Shape,
	b_pos: Vec2,
) -> (
	collide: bool,
	normal: Vec2,
	depth: f32,
) {
	switch a in shape_a {
	case Circle:
		switch b in shape_b {
		case Circle:
			return resolve_collision_circles({a.pos + a_pos, a.radius}, {b.pos + b_pos, b.radius})
		case Polygon:
			collide, normal, depth = resolve_collision_polygon_circle(
				{b.pos + b_pos, b.points, b.rotation},
				{a.pos + a_pos, a.radius},
			)
			return collide, -normal, depth
		case Rectangle:
			rect_b := b
			rect_b.x += b_pos.x
			rect_b.y += b_pos.y
			collide, normal, depth = resolve_collision_polygon_circle(
				rect_to_polygon(rect_b),
				{a.pos + a_pos, a.radius},
			)
			return collide, -normal, depth
		}
	case Polygon:
		switch b in shape_b {
		case Circle:
			return resolve_collision_polygon_circle(
				{a.pos + a_pos, a.points, a.rotation},
				{b.pos + b_pos, b.radius},
			)
		case Polygon:
			return resolve_collision_polygons(
				{a.pos + a_pos, a.points, a.rotation},
				{b.pos + b_pos, b.points, b.rotation},
			)
		case Rectangle:
			rect_b := b
			rect_b.x += b_pos.x
			rect_b.y += b_pos.y
			return resolve_collision_polygons(
				{a.pos + a_pos, a.points, a.rotation},
				rect_to_polygon(rect_b),
			)
		}
	case Rectangle:
		switch b in shape_b {
		case Circle:
			rect_a := a
			rect_a.x += a_pos.x
			rect_a.y += a_pos.y
			return resolve_collision_polygon_circle(
				rect_to_polygon(rect_a),
				{b.pos + b_pos, b.radius},
			)
		case Polygon:
			rect_a := a
			rect_a.x += a_pos.x
			rect_a.y += a_pos.y
			return resolve_collision_polygons(
				rect_to_polygon(rect_a),
				{b.pos + b_pos, b.points, b.rotation},
			)
		case Rectangle:
			rect_a := a
			rect_a.x += a_pos.x
			rect_a.y += a_pos.y
			rect_b := b
			rect_b.x += b_pos.x
			rect_b.y += b_pos.y
			return resolve_collision_polygons(rect_to_polygon(rect_a), rect_to_polygon(rect_b))
		}
	}
	return false, {}, {}
}

// normal is relative to circle a
resolve_collision_circles :: proc(
	a: Circle,
	b: Circle,
) -> (
	collide: bool,
	normal: Vec2,
	depth: f32,
) {
	total_r := a.radius + b.radius
	center_dist := length(a.pos - b.pos)

	depth = total_r - center_dist
	if depth >= 0 {
		collide = true
	}
	normal = normalize(b.pos - a.pos)
	return
}

// Normal is relative to polygon
resolve_collision_polygon_circle :: proc(
	poly: Polygon,
	circle: Circle,
) -> (
	collide: bool,
	normal: Vec2,
	depth: f32,
) {
	if len(poly.points) < 2 {
		return false, {}, 0
	}
	depth = math.INF_F32
	points := polygon_to_points(poly)
	// _ = fmt.ctprintf("%v", poly)
	for index in 0 ..< len(points) {

		edge := points[index] - points[(index + 1) % len(points)]
		axis := normalize(edge.yx * {-1, 1})

		min_poly, max_poly := math.INF_F32, math.NEG_INF_F32
		for v in points {
			dot := dot(v, axis)
			min_poly = min(min_poly, dot)
			max_poly = max(max_poly, dot)
		}

		min_circle, max_circle := math.INF_F32, math.NEG_INF_F32
		{
			p1 := circle.pos + axis * circle.radius
			p2 := circle.pos - axis * circle.radius

			min_circle = dot(p1, axis)
			max_circle = dot(p2, axis)

			if (min_circle > max_circle) {
				min_circle, max_circle = max_circle, min_circle
			}
		}

		axis_depth := math.min(max_poly - min_circle, max_circle - min_poly)

		if axis_depth < 0 {
			// May not return the absolute least axis_depth. exits early
			return false, normal, axis_depth
		}

		if (axis_depth < depth) {
			depth = axis_depth
			normal = axis
		}
	}

	// Final axis test (closest point on polygon to circle center)
	cp_index := get_closest_polygon_point(poly, circle.pos)
	cp := points[cp_index]

	axis := normalize(cp - circle.pos)

	min_poly, max_poly := math.INF_F32, math.NEG_INF_F32
	for v in points {
		dot := dot(v, axis)
		min_poly = min(min_poly, dot)
		max_poly = max(max_poly, dot)
	}

	min_circle, max_circle := math.INF_F32, math.NEG_INF_F32
	{
		p1 := circle.pos + axis * circle.radius
		p2 := circle.pos - axis * circle.radius

		min_circle = dot(p1, axis)
		max_circle = dot(p2, axis)

		if (min_circle > max_circle) {
			min_circle, max_circle = max_circle, min_circle
		}
	}

	axis_depth := math.min(max_poly - min_circle, max_circle - min_poly)

	if axis_depth < 0 {
		// May not return the absolute least axis_depth. exits early
		return false, normal, axis_depth
	}

	if (axis_depth < depth) {
		depth = axis_depth
		normal = axis
	}

	// Flip normal if needed

	polygon_center := get_polygon_center(poly)

	direction := circle.pos - polygon_center

	if dot(direction, normal) < 0 {
		normal = -normal
	}

	return true, normal, depth
}

// normal is relative to polygon a
resolve_collision_polygons :: proc(
	a: Polygon,
	b: Polygon,
) -> (
	collide: bool,
	normal: Vec2,
	depth: f32,
) {
	if len(a.points) < 2 || len(b.points) < 2 {
		return false, {}, 0
	}
	depth = math.INF_F32
	p1 := polygon_to_points(a)
	p2 := polygon_to_points(b)
	_ = fmt.ctprintf("%v %v", a, b)
	for i in 0 ..< 2 {
		if i == 1 {
			p1, p2 = p2, p1
		}

		for index in 0 ..< len(p1) {
			edge := p1[index] - p1[(index + 1) % len(p1)]
			axis := normalize(edge.yx * {-1, 1})

			min_p1, max_p1 := math.INF_F32, math.NEG_INF_F32
			for v in p1 {
				dot := dot(v, axis)
				min_p1 = min(min_p1, dot)
				max_p1 = max(max_p1, dot)
			}

			min_p2, max_p2 := math.INF_F32, math.NEG_INF_F32
			for v in p2 {
				dot := dot(v, axis)
				min_p2 = min(min_p2, dot)
				max_p2 = max(max_p2, dot)
			}

			axis_depth := math.min(max_p1 - min_p2, max_p2 - min_p1)

			if axis_depth < 0 {
				// May not return the absolute least axis_depth. exits early
				return false, axis, axis_depth
			}

			if (axis_depth < depth) {
				depth = axis_depth
				normal = axis
			}
		}
	}

	center_a := get_polygon_center(a)
	center_b := get_polygon_center(b)

	direction := center_b - center_a

	if dot(direction, normal) < 0 {
		normal = -normal
	}

	return true, normal, depth
}

// Returns the distance of the ray intersection. Returns -1 if there is no collision. Dir must be normalized
cast_ray :: proc(start: Vec2, dir: Vec2, shape: Shape, shape_pos: Vec2) -> f32 {
	switch s in shape {
	case Circle:
		// The vector from start to center of circle
		vector_to := s.pos + shape_pos - start
		// Get the distance to the center from the closest point to the center on the axis dir.
		// This is calculated by projecting vector_to onto dir and then we get the distance between vector_to and this projection
		v_to_dir_dot := dot(vector_to, dir)
		v_to_proj := v_to_dir_dot * dir
		dist_to_center_sqrd := distance_squared(vector_to, v_to_proj)
		// Distance to center is larger than radius, meaning no collision
		if dist_to_center_sqrd > s.radius * s.radius {
			return -1
		}

		// edge_to_closest_point is the distance between a point on the edge of the circle and the closest point to the center both which are on the axis, dir
		edge_to_closest_point := math.sqrt(s.radius * s.radius - dist_to_center_sqrd)

		// distance from ray to edge = distance from ray to center (v_to_dir_dot, includes direction) - distance from edge to center
		p0 := v_to_dir_dot - edge_to_closest_point
		p1 := v_to_dir_dot + edge_to_closest_point
		if p0 < 0 {
			if p1 < 0 {
				return -1
			}
			return p1
		} else {
			return p0
		}
	case Polygon:
		min_t: f32 = -1

		points := polygon_to_points(s)
		for s_start, i in points {
			// Step 1: Get line segment

			// Segment delta. s_start + s_delta = end point of segment
			s_delta := points[(i + 1) % len(points)] - s_start

			// Step 2: Ray segment collision
			t := cast_ray_segment(start, dir, s_start + shape_pos, s_delta)
			// Continue if there is no collision
			if t == -1 {
				continue
			}

			// There is a collision!
			// Step 3: Check to see if collision is the earliest collision. Smallest t value
			if t < min_t || min_t == -1 {
				min_t = t
			}
		}
		return min_t
	case Rectangle:
		// Step 1: Collisions with all 4 sides
		t_values: [4]f32

		// Top left to right segment
		t_values[0] = cast_ray_segment(start, dir, {s.x, s.y} + shape_pos, {s.width, 0})
		// Top left to bottom segment
		t_values[1] = cast_ray_segment(start, dir, {s.x, s.y} + shape_pos, {0, s.height})
		// Bottom left to right segment
		t_values[2] = cast_ray_segment(start, dir, {s.x, s.y + s.height} + shape_pos, {s.width, 0})
		// Top right to bottom segment
		t_values[3] = cast_ray_segment(start, dir, {s.x + s.width, s.y} + shape_pos, {0, s.height})

		// Step 2: Get the smallest t value AKA where the ray first hits the rectangle
		min_t: f32 = -1

		for t in t_values {
			if t == -1 { 	// Skip if t is -1 AKA no collision for that side
				continue
			}

			if t < min_t || min_t == -1 {
				min_t = t
			}
		}


		return min_t
	}
	return -1
}

// Returns the length of the ray in order to collide with the segment defined by s_start + s_delta * t where t is an element of [0, 1]
// Returns -1 if no collision
cast_ray_segment :: proc(r_start: Vec2, r_dir: Vec2, s_start: Vec2, s_delta: Vec2) -> f32 {
	// Long hand version
	// t_ray :=
	// 	(s_dir.x * (start.y - s_start.y) - s_dir.y * (start.x - s_start.x)) /
	// 	(dir.x * s_dir.y - dir.y * s_dir.x)

	// Short hand written with cross products
	numerator := cross(r_start - s_start, s_delta)
	denominator := cross(s_delta, r_dir)
	if denominator == 0 {
		if numerator == 0 {
			// Colinear AKA parallel and on the same line
			// TODO: Provide a check here to see if lines are disjoint or overlapping
			return -1
		} else {
			// Parallel and not intersecting
			return -1
		}
	}

	// t_ray is the length of the ray where it hits the segment
	t_ray := numerator / denominator
	if t_ray < 0 { 	// No collision. Segment is behind ray
		return -1
	}
	t_seg := (r_start.x + t_ray * r_dir.x - s_start.x) / s_delta.x
	if s_delta.x == 0 {
		t_seg = (r_start.y + t_ray * r_dir.y - s_start.y) / s_delta.y
	}
	if t_seg < 0 || t_seg > 1 { 	// No collision. Ray is out of segment bounds
		return -1
	}

	return t_ray
}

// Circular concave polygon means that the polygon is constructed about a center point
// and a line can be drawn from each point in the polygon to that center
check_collsion_circular_concave_circle :: proc(
	points: []Vec2,
	center: Vec2,
	circle: Circle,
) -> bool {
	// Go through each point. Separate that point and the next point into a separate polygon and collide with circle
	for p, i in points {
		poly: Polygon = {
			points = {p, points[(i + 1) % len(points)], center},
		}

		if check_collision_polygon_circle(poly, circle) {
			return true
		}
	}
	return false
}

check_collision_shape_point :: proc(shape: Shape, pos: Vec2, point: Vec2) -> bool {
	return check_collision_shapes(shape, pos, Circle{}, point)
}

check_collision_shapes :: proc(shape_a: Shape, a_pos: Vec2, shape_b: Shape, b_pos: Vec2) -> bool {
	switch a in shape_a {
	case Circle:
		switch b in shape_b {
		case Circle:
			return rl.CheckCollisionCircles(a.pos + a_pos, a.radius, b.pos + b_pos, b.radius)
		case Polygon:
			return check_collision_polygon_circle(
				{b.pos + b_pos, b.points, b.rotation},
				{a.pos + a_pos, a.radius},
			)
		case Rectangle:
			rect_b := b
			rect_b.x += b_pos.x
			rect_b.y += b_pos.y
			return rl.CheckCollisionCircleRec(a.pos + a_pos, a.radius, rect_b)
		}
	case Polygon:
		switch b in shape_b {
		case Circle:
			return check_collision_polygon_circle(
				{a.pos + a_pos, a.points, a.rotation},
				{b.pos + b_pos, b.radius},
			)
		case Polygon:
			return check_collision_polygons(
				{a.pos + a_pos, a.points, a.rotation},
				{b.pos + b_pos, b.points, b.rotation},
			)
		case Rectangle:
			rect_b := b
			rect_b.x += b_pos.x
			rect_b.y += b_pos.y
			return check_collision_polygons(
				{a.pos + a_pos, a.points, a.rotation},
				rect_to_polygon(rect_b),
			)
		}
	case Rectangle:
		switch b in shape_b {
		case Circle:
			rect_a := a
			rect_a.x += a_pos.x
			rect_a.y += a_pos.y
			return rl.CheckCollisionCircleRec(b.pos + b_pos, b.radius, rect_a)
		case Polygon:
			rect_a := a
			rect_a.x += a_pos.x
			rect_a.y += a_pos.y
			return check_collision_polygons(
				rect_to_polygon(rect_a),
				{b.pos + b_pos, b.points, b.rotation},
			)
		case Rectangle:
			rect_a := a
			rect_a.x += a_pos.x
			rect_a.y += a_pos.y
			rect_b := b
			rect_b.x += b_pos.x
			rect_b.y += b_pos.y
			return rl.CheckCollisionRecs(rect_a, rect_b)
		}
	}
	return false
}

check_collision_polygon_circle :: proc(poly: Polygon, circle: Circle) -> bool {
	if len(poly.points) < 2 {
		return false
	}
	points := polygon_to_points(poly)
	// _ = fmt.ctprintf("%v", poly)
	for index in 0 ..< len(points) {

		edge := points[index] - points[(index + 1) % len(points)]
		axis := normalize(edge.yx * {-1, 1})

		min_poly, max_poly := math.INF_F32, math.NEG_INF_F32
		for v in points {
			dot := dot(v, axis)
			min_poly = min(min_poly, dot)
			max_poly = max(max_poly, dot)
		}

		min_circle, max_circle := math.INF_F32, math.NEG_INF_F32
		{
			p1 := circle.pos + axis * circle.radius
			p2 := circle.pos - axis * circle.radius

			min_circle = dot(p1, axis)
			max_circle = dot(p2, axis)

			if (min_circle > max_circle) {
				min_circle, max_circle = max_circle, min_circle
			}
		}

		axis_depth := math.min(max_poly - min_circle, max_circle - min_poly)

		if axis_depth < 0 {
			return false
		}
	}

	// Final axis test (closest point on polygon to circle center)
	cp_index := get_closest_polygon_point(poly, circle.pos)
	cp := points[cp_index]

	axis := normalize(cp - circle.pos)

	min_poly, max_poly := math.INF_F32, math.NEG_INF_F32
	for v in points {
		dot := dot(v, axis)
		min_poly = min(min_poly, dot)
		max_poly = max(max_poly, dot)
	}

	min_circle, max_circle := math.INF_F32, math.NEG_INF_F32
	{
		p1 := circle.pos + axis * circle.radius
		p2 := circle.pos - axis * circle.radius

		min_circle = dot(p1, axis)
		max_circle = dot(p2, axis)

		if (min_circle > max_circle) {
			min_circle, max_circle = max_circle, min_circle
		}
	}

	axis_depth := math.min(max_poly - min_circle, max_circle - min_poly)

	if axis_depth < 0 {
		return false
	}

	return true
}

check_collision_polygons :: proc(a: Polygon, b: Polygon) -> bool {
	if len(a.points) < 2 || len(b.points) < 2 {
		return false
	}
	p1 := polygon_to_points(a)
	p2 := polygon_to_points(b)
	for i in 0 ..< 2 {
		if i == 1 {
			p1, p2 = p1, p2
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

check_collision_triangle_point :: proc(tri: [3]Vec2, point: Vec2) -> bool {
	area_original := math.abs(triangle_area2(tri))

	area1 := math.abs(triangle_area2({tri[1], tri[2], point}))
	area2 := math.abs(triangle_area2({tri[0], tri[2], point}))
	area3 := math.abs(triangle_area2({tri[0], tri[1], point}))

	return area1 + area2 + area3 - area_original <= COL_TRIANGLE_POINT_EPSILON
}

// Gets the index of the closest point on the polygon to pos
get_closest_polygon_point :: proc(poly: Polygon, pos: Vec2) -> int {
	points := polygon_to_points(poly)
	closest_point_index := -1
	closest_distance := math.INF_F32
	for i in 0 ..< len(points) {
		dist := length(points[i] - pos)

		if (dist < closest_distance) {
			closest_distance = dist
			closest_point_index = i
		}
	}

	return closest_point_index
}

// Returns a slice of Vec2 points representing the polygon. Rotation and position are applied to each point
// Allocates the slice using temp allocator by default
polygon_to_points :: proc(polygon: Polygon, allocator := context.temp_allocator) -> []Vec2 {
	result := make([]Vec2, len(polygon.points), allocator)
	for i in 0 ..< len(polygon.points) {
		// Rotate point, then translate
		result[i] = rotate_vector(polygon.points[i], polygon.rotation) + polygon.pos
	}
	return result
}

// Allocates polygon.points using temp allocator by default
rotate_points :: proc(points: []Vec2, deg: f32, allocator := context.temp_allocator) -> []Vec2 {
	new_points := make([]Vec2, len(points), allocator)
	for i in 0 ..< len(points) {
		new_points[i] = rotate_vector(points[i], deg)
	}
	return new_points
}

// Allocates polygon.points using temp allocator by default
get_rotated_polygon :: proc(p: Polygon, allocator := context.temp_allocator) -> Polygon {
	points := rotate_points(p.points, p.rotation, allocator)
	return {p.pos, points, 0}
}

// Returns a positive area if the vertices are in clockwise order. Negative for counterclockwise
triangle_area2 :: proc(verts: [3]Vec2) -> f32 {
	x0 := verts[1].x - verts[0].x
	y0 := verts[1].y - verts[0].y
	x1 := verts[2].x - verts[0].x
	y1 := verts[2].y - verts[0].y
	return x0 * y1 - y0 * x1
}

// Polygon must be in clockwise order! 
draw_polygon :: proc(polygon: Polygon, color: rl.Color) {
	points := polygon_to_points(polygon)
	average_point: Vec2 = get_polygon_center(polygon)

	for i in 0 ..< len(points) {
		rl.DrawTriangle(points[i], average_point, points[(i + 1) % len(points)], color)
	}
}

draw_polygon_lines :: proc(polygon: Polygon, color: rl.Color) {
	points := polygon_to_points(polygon)
	for i in 0 ..< len(points) {
		rl.DrawLineEx(points[i], points[(i + 1) % len(points)], 1, color)
	}
}

draw_shape :: proc(shape: Shape, pos: Vec2, color: rl.Color) {
	switch s in shape {
	case Circle:
		rl.DrawCircleV(s.pos + pos, s.radius, color)
	case Polygon:
		draw_polygon({s.pos + pos, s.points, s.rotation}, color)
	case Rectangle:
		rl.DrawRectangle(i32(s.x + pos.x), i32(s.y + pos.y), i32(s.width), i32(s.height), color)
	}
}

draw_shape_lines :: proc(shape: Shape, pos: Vec2, color: rl.Color) {
	switch s in shape {
	case Circle:
		rl.DrawCircleLinesV(s.pos + pos, s.radius, color)
	case Polygon:
		draw_polygon_lines({s.pos + pos, s.points, s.rotation}, color)
	case Rectangle:
		rl.DrawRectangleLines(
			i32(s.x + pos.x),
			i32(s.y + pos.y),
			i32(s.width),
			i32(s.height),
			color,
		)
	}
}

get_centered_rect :: proc(center: Vec2, size: Vec2) -> Rectangle {
	return {center.x - size.x * 0.5, center.y - size.y * 0.5, size.x, size.y}
}

get_center :: proc {
	get_polygon_center,
	get_rect_center,
}

get_rect_center :: proc(rect: Rectangle) -> Vec2 {
	return {rect.x, rect.y} + {rect.width, rect.height} * 0.5
}

get_polygon_center :: proc(polygon: Polygon) -> Vec2 {
	points := polygon_to_points(polygon)
	summed_points: Vec2
	for p in points {
		summed_points += p
	}
	average_point: Vec2 = summed_points / f32(len(points))
	return average_point
}

rect_to_points :: proc(rect: Rectangle) -> [4]Vec2 {
	tl := Vec2{rect.x, rect.y}
	tr := tl + {rect.width, 0}
	br := tl + {rect.width, rect.height}
	bl := tl + {0, rect.height}
	return {tl, tr, br, bl}
}

// Allocates polygon.points using temp allocator by default
rect_to_polygon :: proc(rect: Rectangle, allocator := context.temp_allocator) -> Polygon {
	tl := Vec2{rect.width, rect.height} * -0.5
	tr := tl * {-1, 1}
	br := tl * {-1, -1}
	bl := tl * {1, -1}

	points := make([]Vec2, 4, allocator)
	points[0] = tl
	points[1] = tr
	points[2] = br
	points[3] = bl

	return {get_center(rect), points, 0}
}

// Sweep the current aabb to the other AABB with the given velocity and delta. The delta at which the collision occurred is returned.
// Will return null if aabbs are inside each other
// rect is the box that the velocity is being applied to
// sweep_rect :: proc(rect: , : Rectangle, vel: Vec2) -> (RectCollision, bool) {
// 	segment_start: Vec2 = {rect.x, rect.y} // So we don't accidentally change the position
// 	padded_rect: Rectangle = { 	// New rect with size of other and box combined.
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
