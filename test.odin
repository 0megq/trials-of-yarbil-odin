package game


import "core:testing"
import rl "vendor:raylib"

test_contact_point := Vec2{}
test_sweep_point := Vec2{}

// @(test)
testr :: proc(t: ^testing.T) {
	rl.InitWindow(1280, 720, "My First Game")

	polygon := Polygon{{}, {{30, 0}, {20, 40}, {0, 60}, {-20, 50}, {0, -60}}, 0}

	shape_1: Shape = polygon
	shape_2: Shape = get_centered_rect({}, 10)

	shape_1_pos: Vec2 = rl.GetMousePosition()
	shape_2_pos: Vec2 = {300, 100}

	velocity: Vec2
	vel_start: Vec2


	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)


		if rl.IsMouseButtonPressed(.RIGHT) {
			velocity = {}
		} else if rl.IsMouseButtonDown(.RIGHT) {
			velocity -= rl.GetMouseDelta()
			shape_1_pos = rl.GetMousePosition()
		} else {
			shape_1_pos = rl.GetMousePosition()
		}

		vel_start = shape_1_pos

		delta, normal := sweep_collision_shapes(
			shape_1,
			shape_1_pos,
			shape_2,
			shape_2_pos,
			velocity,
		)


		draw_shape_lines(shape_2, shape_2_pos, rl.BLUE)

		draw_shape_lines(shape_1, shape_1_pos + velocity, rl.ORANGE)
		if delta > 0 {
			draw_shape_lines(shape_1, shape_1_pos + velocity * delta, rl.RED)
		}
		draw_shape_lines(shape_1, shape_1_pos, rl.GREEN)

		rl.DrawLineV({40, 400}, {40, 400} + normal * 40, rl.DARKBLUE)
		rl.DrawCircleV({40, 400} + normal * 40, 5, rl.BLUE)

		// rl.DrawLineV(test_sweep_point, test_contact_point, rl.BLACK)
		// rl.DrawCircleV(test_contact_point, 4, rl.RED)
		// rl.DrawCircleV(test_sweep_point, 4, rl.ORANGE)

		rl.DrawLineV(vel_start, vel_start + velocity, rl.RED)

		rl.EndDrawing()
	}

	rl.CloseWindow()

}
