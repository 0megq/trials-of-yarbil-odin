package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

WINDOW_SIZE :: Vec2i{1280, 720}
CANVAS_SIZE :: Vec2i{640, 360}
WINDOW_TO_CANVAS :: f32(WINDOW_SIZE.x) / f32(CANVAS_SIZE.x)
PLAYER_BASE_MAX_SPEED :: 150
PLAYER_BASE_ACCELERATION :: 1200
PLAYER_PUNCH_SIZE :: Vec2{12, 16}
PUNCH_TIME :: 0.2
TIME_BETWEEN_PUNCH :: 0.2
PUNCH_POWER :: 150
SWORD_POWER :: 250

Timer :: struct {
	time_left: f32,
	callable:  proc(),
}

player: Player = {
	pos          = {300, 300},
	size         = {12, 12},
	pickup_range = 16,
}

punching: bool
punch_timer: f32
can_punch: bool
punch_rate_timer: f32
holding_sword: bool

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE.x, WINDOW_SIZE.y, "Trials of Yarbil")

	load_textures()

	timers := make([dynamic]Timer, context.allocator)

	items := make([dynamic]Item, context.allocator)
	append(&items, Item{pos = {500, 300}, size = {8, 8}, item_id = .Sword})

	obstacles := make([dynamic]StaticEntity, context.allocator)
	append(&obstacles, StaticEntity{pos = {200, 100}, size = {16, 32}})

	enemies := make([dynamic]Enemy, context.allocator)
	append(&enemies, Enemy{pos = {20, 80}, size = {16, 16}, detection_range = 160})

	// p1: Polygon = {{200, 200}, {{30, 0}, {0, -30}, {-30, 0}, {0, 30}}}
	// mouse_poly: Polygon = {rl.GetMousePosition(), {{30, 0}, {0, -30}, {-30, 0}, {0, 30}}}

	punch_rect: rl.Rectangle = {
		player.size.x * 0.5,
		PLAYER_PUNCH_SIZE.y * -0.5,
		PLAYER_PUNCH_SIZE.x,
		PLAYER_PUNCH_SIZE.y,
	}
	punch_points := rect_to_points(punch_rect)
	sword_points: []Vec2 = {
		{player.size.x * 0.5, -12},
		{player.size.x * 0.5 + 10, -5},
		{player.size.x * 0.5 + 12, 0},
		{player.size.x * 0.5 + 10, 5},
		{player.size.x * 0.5, 12},
	}
	attack_poly: Polygon
	attack_poly.pos = player.pos
	attack_poly.points = punch_points[:]

	hit_enemies: [dynamic]bool = make([dynamic]bool, context.allocator)
	for i := 0; i < len(enemies); i += 1 {append(&hit_enemies, false)}

	for !rl.WindowShouldClose() {
		delta := rl.GetFrameTime()
		mouse_canvas_pos := rl.GetMousePosition() / WINDOW_TO_CANVAS

		for &timer, i in timers {
			timer.time_left -= delta
			if timer.time_left <= 0 {
				timer.callable()
				unordered_remove(&timers, i)
			}
		}

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
			move(&enemy, input, 400, 140, delta)
		}

		attack_poly.pos = player.pos
		rotated_attack_poly := rotate_polygon(
			attack_poly,
			get_angle(mouse_canvas_pos - player.pos),
		)

		if rl.IsMouseButtonPressed(.LEFT) && can_punch {
			punching = true
			punch_timer = PUNCH_TIME
			can_punch = false
			for i in 0 ..< len(hit_enemies) {
				hit_enemies[i] = false
			}
		} else if punching {
			if punch_timer <= 0 {
				punching = false
				punch_rate_timer = TIME_BETWEEN_PUNCH
			} else {
				punch_timer -= delta
				for enemy, i in enemies {
					if !hit_enemies[i] &&
					   check_collision_polygons(
						   rect_to_polygon(get_centered_rect(enemy.pos, enemy.size)),
						   rotated_attack_poly,
					   ) {
						enemies[i].vel +=
							normalize(mouse_canvas_pos - player.pos) *
							(SWORD_POWER if holding_sword else PUNCH_POWER)
						hit_enemies[i] = true
					}
				}
			}
		} else if !can_punch { 	// If right after punch finished then tick punch rate timer until done
			if punch_rate_timer <= 0 {
				can_punch = true
			}
			punch_rate_timer -= delta
		}

		if rl.IsKeyPressed(.LEFT_SHIFT) {
			if holding_sword {
				append(&items, Item{pos = player.pos, size = {8, 8}, item_id = .Sword})
				holding_sword = false
				attack_poly.points = punch_points[:]
			} else {
				for item, i in items {
					if rl.CheckCollisionCircleRec(
						player.pos,
						player.pickup_range,
						get_centered_rect(item.pos, item.size),
					) {
						fmt.printfln("picked up %v", item.item_id)
						if item.item_id == .Sword {
							holding_sword = true
							attack_poly.points = sword_points
						}
						unordered_remove(&items, i)
					}
				}
			}
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
		rl.DrawCircleLinesV(player.pos, player.pickup_range, rl.DARKBLUE)

		for item in items {
			rl.DrawRectangleRec(get_centered_rect(item.pos, item.size), rl.PURPLE)
		}

		for obstacle in obstacles {
			rl.DrawRectangleRec(get_centered_rect(obstacle.pos, obstacle.size), rl.GRAY)
			// draw_polygon_lines(rect_to_polygon(get_centered_rect(enemy.pos, enemy.size)), rl.GREEN)
		}

		// rl.DrawTextureV(textures[.Player], player.pos, rl.WHITE)
		//rl.DrawRectanglePro() sword drawing
		for enemy in enemies {
			rl.DrawRectangleRec(get_centered_rect(enemy.pos, enemy.size), rl.GREEN)
			// draw_polygon_lines(rect_to_polygon(get_centered_rect(enemy.pos, enemy.size)), rl.GREEN)
			rl.DrawCircleLinesV(enemy.pos, enemy.detection_range, rl.YELLOW)
		}

		// rl.DrawText(
		// 	fmt.ctprintf("Colliding: %v", check_collision_polygons(p1, mouse_poly)),
		// 	200,
		// 	20,
		// 	24,
		// 	rl.BLACK,
		// )

		// fmt.println(
		// 	sweep_rect(
		// 		e.pos,
		// 		e.size,
		// 		get_centered_rect(obstacles[0].pos, obstacles[0].size),
		// 		e.vel,
		// 	),
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
		draw_polygon(rotated_attack_poly, punch_area_color)

		rl.EndMode2D()

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	free_all(context.allocator)
	unload_textures()
	rl.CloseWindow()
}

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
