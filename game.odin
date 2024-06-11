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
	shape        = Circle{{}, 8},
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
	append(&items, Item{pos = {500, 300}, shape = Circle{{}, 4}, item_id = .Sword})

	obstacles := make([dynamic]PhysicsEntity, context.allocator)
	append(&obstacles, PhysicsEntity{pos = {200, 100}, shape = get_centered_rect({}, {16, 32})})

	enemies := make([dynamic]Enemy, context.allocator)
	append(
		&enemies,
		Enemy{pos = {20, 80}, shape = get_centered_rect({}, {16, 16}), detection_range = 160},
	)

	player_sprite := Sprite{.Player, {0, 0, 12, 16}, {1, 1}, {5.5, 7.5}, 0, rl.WHITE}

	player_radius := player.shape.(Circle).radius
	punch_rect: rl.Rectangle = {
		player_radius,
		PLAYER_PUNCH_SIZE.y * -0.5,
		PLAYER_PUNCH_SIZE.x,
		PLAYER_PUNCH_SIZE.y,
	}
	punch_points := rect_to_points(punch_rect)
	sword_points: []Vec2 = {
		{player_radius, -12},
		{player_radius + 10, -5},
		{player_radius + 12, 0},
		{player_radius + 10, 5},
		{player_radius, 12},
	}
	attack_poly: Polygon
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

		move(
			&player,
			get_directional_input(),
			PLAYER_BASE_ACCELERATION,
			PLAYER_BASE_MAX_SPEED,
			delta,
		)

		// Move enemies and track player if in range
		for &enemy in enemies {
			input: Vec2
			if check_collision_shapes(
				Circle{{}, enemy.detection_range},
				enemy.pos,
				player.shape,
				player.pos,
			) {
				input = normalize(player.pos - enemy.pos)
			}
			move(&enemy, input, 400, 120, delta)
		}

		attack_poly.rotation = angle(mouse_canvas_pos - player.pos)

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
					   check_collision_shapes(enemy.shape, enemy.pos, attack_poly, player.pos) {
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
				append(&items, Item{pos = player.pos, shape = Circle{{}, 4}, item_id = .Sword})
				holding_sword = false
				attack_poly.points = punch_points[:]
			} else {
				for item, i in items {
					if check_collision_shapes(
						Circle{{}, player.pickup_range},
						player.pos,
						item.shape,
						item.pos,
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

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLUE)

		camera := rl.Camera2D {
			zoom = WINDOW_TO_CANVAS,
		}

		rl.BeginMode2D(camera)

		draw_shape(player.shape, player.pos, rl.RED)
		draw_sprite(player_sprite, player.pos)
		draw_shape_lines(Circle{{}, player.pickup_range}, player.pos, rl.DARKBLUE)

		for item in items {
			draw_shape(item.shape, item.pos, rl.PURPLE)
		}

		for obstacle in obstacles {
			draw_shape(obstacle.shape, obstacle.pos, rl.GRAY)
		}

		for enemy in enemies {
			draw_shape(enemy.shape, enemy.pos, rl.GREEN)
			rl.DrawCircleLinesV(enemy.pos, enemy.detection_range, rl.YELLOW)
		}

		punch_area_color := rl.Color{255, 255, 255, 120}
		if punching {
			punch_area_color = rl.Color{255, 0, 0, 120}
		}

		draw_shape(attack_poly, player.pos, punch_area_color)

		rl.EndMode2D()

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	free_all(context.allocator)
	unload_textures()
	rl.CloseWindow()
}

move :: proc(e: ^MovingEntity, input: Vec2, acceleration: f32, max_speed: f32, delta: f32) {
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

	speed := length(e.vel)
	if speed > max_speed {
		e.vel = normalize(e.vel) * max_speed
	}

	e.pos += e.vel * delta
}

draw_sprite :: proc(sprite: Sprite, pos: Vec2) {
	tex := loaded_textures[sprite.tex_id]
	dst_rec := rl.Rectangle {
		pos.x,
		pos.y,
		f32(tex.width) * math.abs(sprite.scale.x), // scale the sprite. a negative would mess this up
		f32(tex.height) * math.abs(sprite.scale.y),
	}

	src_rec := rl.Rectangle {
		sprite.tex_region.x,
		sprite.tex_region.y,
		sprite.tex_region.width * math.sign(sprite.scale.x), // Flip the texture, based off sprite scale
		sprite.tex_region.height * math.sign(sprite.scale.y),
	}

	rl.DrawTexturePro(
		tex,
		src_rec,
		dst_rec,
		sprite.tex_origin * abs(sprite.scale),
		sprite.rotation,
		sprite.tint,
	)
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
