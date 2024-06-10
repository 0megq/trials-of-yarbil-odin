package game

// import "core:fmt"
import "core:math"
import rl "vendor:raylib"

WINDOW_SIZE :: Vec2i{1280, 720}
CANVAS_SIZE :: Vec2i{640, 360}
WINDOW_TO_CANVAS :: f32(WINDOW_SIZE.x) / f32(CANVAS_SIZE.x)
PLAYER_BASE_MAX_SPEED :: 150
PLAYER_BASE_ACCELERATION :: 1200
PLAYER_PUNCH_SIZE :: Vec2{20, 32}
PUNCH_TIME :: 0.2
TIME_BETWEEN_PUNCH :: 0.4

Entity :: struct {
	pos: Vec2,
}

PhysicsEntity :: struct {
	using entity: Entity,
	vel:          Vec2,
	size:         Vec2,
}

Enemy :: struct {
	using physics_entity: PhysicsEntity,
	detection_range:      f32,
}

player: PhysicsEntity = {
	pos  = {300, 300},
	size = {32, 32},
}

punching: bool
punch_timer: f32
can_punch: bool
punch_rate_timer: f32

move :: proc(e: ^PhysicsEntity, input: Vec2, acceleration: f32, max_speed: f32, delta: f32) {
	e.vel += normalize(input) * acceleration * delta

	friction_vector: Vec2
	if input.x == 0 {
		friction_vector.x = -math.sign(e.vel.x)
	}
	if input.y == 0 {
		friction_vector.y = -math.sign(e.vel.y)
	}

	e.vel += normalize(friction_vector) * acceleration * 0.5 * delta
	// Prevent friction overshooting
	if math.sign(e.vel.x) == friction_vector.x {e.vel.x = 0}
	if math.sign(e.vel.y) == friction_vector.y {e.vel.y = 0}

	speed := get_length(e.vel)
	if speed > max_speed {
		e.vel = normalize(e.vel) * max_speed
	}

	e.pos += e.vel * delta
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE.x, WINDOW_SIZE.y, "Trials of Yarbil")

	load_textures()

	enemies: [dynamic]Enemy = make([dynamic]Enemy, context.allocator)

	append(&enemies, Enemy{pos = {20, 80}, size = {10, 10}, detection_range = 200})
	append(&enemies, Enemy{pos = {400, 300}, size = {100, 100}, detection_range = 100})

	// p1: Polygon = {{200, 200}, {{30, 0}, {0, -30}, {-30, 0}, {0, 30}}}
	// mouse_poly: Polygon = {rl.GetMousePosition(), {{30, 0}, {0, -30}, {-30, 0}, {0, 30}}}

	punch_rect: rl.Rectangle = {
		player.size.x * 0.5,
		PLAYER_PUNCH_SIZE.y * -0.5,
		PLAYER_PUNCH_SIZE.x,
		PLAYER_PUNCH_SIZE.y,
	}
	punch_points := rect_to_points(punch_rect)
	punch_poly: Polygon
	punch_poly.pos = player.pos
	punch_poly.points = punch_points[:]

	for !rl.WindowShouldClose() {
		delta := rl.GetFrameTime()
		mouse_canvas_pos := rl.GetMousePosition() / WINDOW_TO_CANVAS

		// copy(p1.points, rotate_points(p1.points, 10 * delta))

		// mouse_poly.pos = mouse

		move(
			&player,
			get_directional_input(),
			PLAYER_BASE_ACCELERATION,
			PLAYER_BASE_MAX_SPEED,
			delta,
		)

		player_rect := get_centered_rect(player.pos, player.size)

		// Move enemies and track player if in range
		for &enemy in enemies {
			input: Vec2
			if rl.CheckCollisionCircleRec(enemy.pos, enemy.detection_range, player_rect) {
				input = normalize(player.pos - enemy.pos)
			}
			move(&enemy, input, 80, 120, delta)
		}

		punch_poly.pos = player.pos
		rotated_punch_poly := rotate_polygon(punch_poly, get_angle(mouse_canvas_pos - player.pos))

		if rl.IsMouseButtonPressed(.LEFT) && can_punch {
			punching = true
			punch_timer = PUNCH_TIME
			can_punch = false
		} else if punching {
			if punch_timer <= 0 {
				punching = false
				punch_rate_timer = TIME_BETWEEN_PUNCH
			} else {
				punch_timer -= delta
				for enemy, i in enemies {
					if check_collision_polygons(
						rect_to_polygon(get_centered_rect(enemy.pos, enemy.size)),
						rotated_punch_poly,
					) {
						unordered_remove(&enemies, i)
					}
				}
			}
		} else if !can_punch { 	// If right after punch finished then tick punch rate timer until done
			if punch_rate_timer <= 0 {
				can_punch = true
			}
			punch_rate_timer -= delta
		}


		// rl.TraceLog(
		// 	.INFO,
		// 	fmt.ctprintf("Pos: %v, Vel: %v, Speed: %v", player.pos, player.vel, speed),
		// )

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLUE)

		camera := rl.Camera2D {
			zoom = WINDOW_TO_CANVAS,
		}

		rl.BeginMode2D(camera)

		rl.DrawRectangleRec(player_rect, rl.RED)
		rl.DrawTextureV(textures[.Player], player.pos, rl.WHITE)
		//rl.DrawRectanglePro() sword drawing
		for enemy in enemies {
			rl.DrawRectangleRec(get_centered_rect(enemy.pos, enemy.size), rl.GREEN)
			draw_polygon_lines(rect_to_polygon(get_centered_rect(enemy.pos, enemy.size)), rl.GREEN)
			rl.DrawCircleLinesV(enemy.pos, enemy.detection_range, rl.YELLOW)
		}

		// rl.DrawText(
		// 	fmt.ctprintf("Colliding: %v", check_collision_polygons(p1, mouse_poly)),
		// 	200,
		// 	20,
		// 	24,
		// 	rl.BLACK,
		// )


		// draw_polygon_lines(p1, rl.ORANGE)
		// draw_polygon_lines(mouse_poly, rl.ORANGE)
		// draw_polygon_lines(offset_polygon(p2, rl.GetMousePosition()), rl.RED)

		punch_area_color := rl.Color{255, 255, 255, 120}
		if punching {
			punch_area_color = rl.Color{255, 0, 0, 120}
		}
		// rl.DrawRectanglePro(
		// 	{player.pos.x, player.pos.y, PLAYER_PUNCH_SIZE.x, PLAYER_PUNCH_SIZE.y},
		// 	{-player.size.x, PLAYER_PUNCH_SIZE.y * 0.5},
		// 	get_angle(rl.GetMousePosition() - player.pos),
		// 	punch_area_color,
		// )
		// draw_polygon_lines(rotated_punch_poly, punch_area_color)
		draw_polygon(rotated_punch_poly, punch_area_color)

		rl.EndMode2D()

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	free_all(context.allocator)
	unload_textures()
	rl.CloseWindow()
}

get_directional_input :: proc() -> Vec2 {
	dir: Vec2
	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		dir += {0, -1}
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		dir += {0, 1}
	}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		dir += {-1, 0}
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		dir += {1, 0}
	}

	return dir
}
