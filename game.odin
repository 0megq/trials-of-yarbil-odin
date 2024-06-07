package game

// import "core:fmt"
import "core:math"
import rl "vendor:raylib"

SCREEN_SIZE :: Vec2i{1280, 720}
PLAYER_BASE_MAX_SPEED :: 150
PLAYER_BASE_ACCELERATION :: 1200
PLAYER_PUNCH_SIZE :: Vec2{20, 32}
PUNCH_TIME :: 0.2

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

	speed := get_length(e.vel)
	if speed > max_speed {
		e.vel = normalize(e.vel) * max_speed
	}

	e.pos += e.vel * delta
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_SIZE.x, SCREEN_SIZE.y, "Trials of Yarbil")

	enemies: [dynamic]Enemy = make([dynamic]Enemy, context.allocator)

	append(&enemies, Enemy{pos = {20, 80}, size = {10, 10}, detection_range = 200})
	append(&enemies, Enemy{pos = {120, 200}, size = {30, 20}, detection_range = 100})

	for !rl.WindowShouldClose() {
		delta := rl.GetFrameTime()

		move(
			&player,
			get_directional_input(),
			PLAYER_BASE_ACCELERATION,
			PLAYER_BASE_MAX_SPEED,
			delta,
		)

		player_rect: rl.Rectangle = {
			player.pos.x - player.size.x * 0.5,
			player.pos.y - player.size.y * 0.5,
			player.size.x,
			player.size.y,
		}

		// Move enemies and track player if in range
		for &enemy in enemies {
			input: Vec2
			if rl.CheckCollisionCircleRec(enemy.pos, enemy.detection_range, player_rect) {
				input = normalize(player.pos - enemy.pos)
			}
			move(&enemy, input, 240, 80, delta)
		}

		if rl.IsMouseButtonPressed(.LEFT) {
			punching = true
			punch_timer = PUNCH_TIME
		} else {
			if punch_timer <= 0 {
				punching = false
			}
			if punching {
				punch_timer -= delta
			}
		}

		// rl.TraceLog(
		// 	.INFO,
		// 	fmt.ctprintf("Pos: %v, Vel: %v, Speed: %v", player.pos, player.vel, speed),
		// )

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLUE)
		rl.DrawRectangleRec(player_rect, rl.RED)
		//rl.DrawRectanglePro() sword drawing
		for enemy in enemies {
			rl.DrawRectangleV(enemy.pos - enemy.size / 2, enemy.size.y, rl.GREEN)
			rl.DrawCircleLinesV(enemy.pos, enemy.detection_range, rl.YELLOW)
		}

		punch_area_color := rl.Color{255, 255, 255, 120}
		if punching {
			punch_area_color = rl.Color{255, 0, 0, 120}
		}
		rl.DrawRectanglePro(
			{player.pos.x, player.pos.y, PLAYER_PUNCH_SIZE.x, PLAYER_PUNCH_SIZE.y},
			{-16, PLAYER_PUNCH_SIZE.y * 0.5},
			get_angle(rl.GetMousePosition() - player.pos),
			punch_area_color,
		)

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	free_all(context.allocator)

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
