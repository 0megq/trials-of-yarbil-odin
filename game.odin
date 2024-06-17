package game

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

WINDOW_SIZE :: Vec2i{1280, 720}
GAME_SIZE :: Vec2i{640, 360}
WINDOW_TO_GAME :: f32(WINDOW_SIZE.x) / f32(GAME_SIZE.x)
PLAYER_BASE_MAX_SPEED :: 150
PLAYER_BASE_ACCELERATION :: 1200
PLAYER_PUNCH_SIZE :: Vec2{12, 16}
PUNCH_TIME :: 0.2
TIME_BETWEEN_PUNCH :: 0.2
PUNCH_POWER :: 150
SWORD_POWER :: 250
FIRE_DASH_RADIUS :: 32

Timer :: struct {
	time_left: f32,
	callable:  proc(),
}

MovementAbility :: enum {
	FIRE,
	WATER,
	ELECTRIC,
	GROUND,
	AIR,
}

Level :: struct {
	walls: [dynamic]PhysicsEntity,
}

punching: bool
punch_timer: f32
can_punch: bool
punch_rate_timer: f32
holding_sword: bool
surfing: bool
current_ability: MovementAbility

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		for _, entry in track.allocation_map {
			fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		}
		for entry in track.bad_free_array {
			fmt.eprintf("%v bad free\n", entry.location)
		}
		mem.tracking_allocator_destroy(&track)
	}

	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE.x, WINDOW_SIZE.y, "Trials of Yarbil")

	load_textures()

	player: Player = {
		pos          = {300, 300},
		shape        = Circle{{}, 8},
		pickup_range = 16,
	}

	current_ability = .WATER

	surf_poly := Polygon{player.pos, {{10, -30}, {20, -20}, {30, 0}, {20, 20}, {10, 30}}, 0}

	fires := make([dynamic]Circle, context.allocator)

	timers := make([dynamic]Timer, context.allocator)

	items := make([dynamic]Item, context.allocator)
	append(&items, Item{pos = {500, 300}, shape = Circle{{}, 4}, item_id = .Sword})

	level: Level

	wall1 := PhysicsEntity {
		pos   = {200, 100},
		shape = Polygon{{}, {{-16, -16}, {16, -16}, {0, 16}}, 0},
	}
	level.walls = make([dynamic]PhysicsEntity, context.allocator)


	if level_data, ok := os.read_entire_file("level.json", context.allocator); ok {
		if json.unmarshal(level_data, &level) != nil {
			append(&level.walls, wall1)
		}
	} else {
		append(&level.walls, wall1)
	}

	enemies := make([dynamic]Enemy, context.allocator)
	append(
		&enemies,
		Enemy{pos = {20, 80}, shape = get_centered_rect({}, {16, 16}), detection_range = 160},
	)
	append(
		&enemies,
		Enemy{pos = {100, 80}, shape = get_centered_rect({}, {16, 16}), detection_range = 160},
	)
	append(
		&enemies,
		Enemy{pos = {600, 300}, shape = get_centered_rect({}, {16, 16}), detection_range = 160},
	)
	append(
		&enemies,
		Enemy{pos = {80, 300}, shape = get_centered_rect({}, {16, 16}), detection_range = 160},
	)

	player_sprite := Sprite{.Player, {0, 0, 12, 16}, {1, 1}, {5.5, 7.5}, 0, rl.WHITE}

	player_radius: f32 = 8
	punch_rect: Rectangle = {
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
		mouse_world_pos := rl.GetMousePosition() / WINDOW_TO_GAME
		mouse_world_delta := rl.GetMouseDelta() / WINDOW_TO_GAME

		for &timer, i in timers {
			timer.time_left -= delta
			if timer.time_left <= 0 {
				timer.callable()
				unordered_remove(&timers, i)
			}
		}

		update_editor(
			&level.walls,
			rl.GetMousePosition(),
			rl.GetMouseDelta(),
			mouse_world_pos,
			mouse_world_delta,
		)

		if rl.IsKeyPressed(.SPACE) {
			switch current_ability {
			case .FIRE:
				player.vel = normalize(get_directional_input()) * 250
				fire := Circle{player.pos, FIRE_DASH_RADIUS}
				append(&fires, fire)
				for &enemy in enemies {
					if check_collision_shapes(fire, {}, enemy.shape, enemy.pos) {
						power_scale :=
							(FIRE_DASH_RADIUS - length(enemy.pos - fire.pos)) / FIRE_DASH_RADIUS
						power_scale = max(power_scale, 0.6) // TODO use a map function
						enemy.vel -= normalize(get_directional_input()) * 600 * power_scale
					}
				}
			case .WATER:
				surfing = true
				append(&timers, Timer{1, turn_off_surf})
			// for &enemy in enemies {
			// 	if check_collision_shapes(fire, {}, enemy.shape, enemy.pos) {
			// 		enemy.vel -= normalize(get_directional_input()) * 200
			// 	}
			// }
			case .ELECTRIC:

			case .GROUND:

			case .AIR:
			}
		}

		if surfing {
			player.vel = normalize(get_directional_input()) * 200
			surf_poly.rotation = angle(get_directional_input())
			surf_poly.pos = player.pos
			for &enemy in enemies {
				if check_collision_shapes(surf_poly, {}, enemy.shape, enemy.pos) {
					enemy.vel = normalize(enemy.pos - (surf_poly.pos + {10, 0})) * 250
				}
			}
		}

		{
			player_move(&player, delta)

			for wall in level.walls {
				_, normal, depth := resolve_collision_shapes(
					player.shape,
					player.pos,
					wall.shape,
					wall.pos,
				)
				// fmt.printfln("%v, %v, %v", collide, normal, depth)
				if depth > 0 {
					player.pos -= normal * depth
					player.vel = slide(player.vel, normal)
				}
			}
		}

		// Move enemies and track player if in range
		for &enemy in enemies {
			enemy_move(&enemy, delta, player)
			for wall in level.walls {
				_, normal, depth := resolve_collision_shapes(
					enemy.shape,
					enemy.pos,
					wall.shape,
					wall.pos,
				)
				// fmt.printfln("%v, %v, %v", collide, normal, depth)
				if depth > 0 {
					enemy.pos -= normal * depth
					enemy.vel = slide(enemy.vel, normal)
				}
			}
		}

		attack_poly.rotation = angle(mouse_world_pos - player.pos)

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
							normalize(mouse_world_pos - player.pos) *
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
			zoom = WINDOW_TO_GAME,
		}

		rl.BeginMode2D(camera)

		draw_polygon(surf_poly, rl.DARKGREEN)

		for fire in fires {
			rl.DrawCircleV(fire.pos, fire.radius, rl.ORANGE)
		}

		for item in items {
			draw_shape(item.shape, item.pos, rl.PURPLE)
		}

		for wall in level.walls {
			draw_shape(wall.shape, wall.pos, rl.GRAY)
		}

		for enemy in enemies {
			draw_shape(enemy.shape, enemy.pos, rl.GREEN)
			rl.DrawCircleLinesV(enemy.pos, enemy.detection_range, rl.YELLOW)
		}

		punch_area_color := rl.Color{255, 255, 255, 120}
		if punching {
			punch_area_color = rl.Color{255, 0, 0, 120}
		}

		draw_shape(player.shape, player.pos, rl.RED)
		draw_sprite(player_sprite, player.pos)
		draw_shape_lines(Circle{{}, player.pickup_range}, player.pos, rl.DARKBLUE)

		draw_shape(attack_poly, player.pos, punch_area_color)

		draw_editor_world()
		rl.EndMode2D()

		draw_editor_ui()
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	if level_data, err := json.marshal(level, allocator = context.allocator); err == nil {
		os.write_entire_file("level.json", level_data)
	}

	mem.tracking_allocator_clear(&track)
	free_all(context.temp_allocator)
	free_all(context.allocator)

	unload_textures()
	rl.CloseWindow()
}

player_move :: proc(e: ^Player, delta: f32) {
	max_speed: f32 = 160.0
	acceleration: f32 = 960.0
	friction: f32 = 320.0
	harsh_friction: f32 = 1040.0

	input := get_directional_input()
	acceleration_v := normalize(input) * acceleration * delta

	friction_dir: Vec2 = -normalize(e.vel)
	if length(e.vel) > max_speed {
		friction = harsh_friction
	}
	friction_v := normalize(friction_dir) * friction * delta

	// Prevent friction overshooting when deaccelerating
	// if math.sign(e.vel.x) == sign(friction_dir.x) {e.vel.x = 0}
	// if math.sign(e.vel.y) == sign(friction_dir.y) {e.vel.y = 0}

	if length(e.vel + acceleration_v + friction_v) > max_speed && length(e.vel) <= max_speed { 	// If overshooting above max speed
		e.vel = normalize(e.vel + acceleration_v + friction_v) * max_speed
	} else if length(e.vel + acceleration_v + friction_v) < max_speed &&
	   length(e.vel) > max_speed &&
	   angle_between(e.vel, acceleration_v) <= 90 { 	// If overshooting below max speed
		e.vel = normalize(e.vel + acceleration_v + friction_v) * max_speed
	} else {
		e.vel += acceleration_v
		e.vel += friction_v
		// Account for friction overshooting when slowing down
		if acceleration_v.x == 0 && math.sign(e.vel.x) == math.sign(friction_v.x) {
			e.vel.x = 0
		}
		if acceleration_v.y == 0 && math.sign(e.vel.y) == math.sign(friction_v.y) {
			e.vel.y = 0
		}
	}

	// fmt.printfln(
	// 	"speed: %v, vel: %v fric vector: %v, acc vector: %v, acc length: %v",
	// 	length(e.vel),
	// 	e.vel,
	// 	friction_v,
	// 	acceleration_v,
	// )

	e.pos += e.vel * delta
}

enemy_move :: proc(e: ^Enemy, delta: f32, player: Player) {
	max_speed: f32 = 120.0
	acceleration: f32 = 720.0
	friction: f32 = 240.0
	harsh_friction: f32 = 960.0

	input: Vec2
	if check_collision_shapes(Circle{{}, e.detection_range}, e.pos, player.shape, player.pos) {
		input = normalize(player.pos - e.pos)
	}
	acceleration_v := normalize(input) * acceleration * delta

	friction_dir: Vec2 = -normalize(e.vel)
	if length(e.vel) > max_speed {
		friction = harsh_friction
	}
	friction_v := normalize(friction_dir) * friction * delta

	// Prevent friction overshooting when deaccelerating
	// if math.sign(e.vel.x) == sign(friction_dir.x) {e.vel.x = 0}
	// if math.sign(e.vel.y) == sign(friction_dir.y) {e.vel.y = 0}

	if length(e.vel + acceleration_v + friction_v) > max_speed && length(e.vel) <= max_speed { 	// If overshooting above max speed
		e.vel = normalize(e.vel + acceleration_v + friction_v) * max_speed
	} else if length(e.vel + acceleration_v + friction_v) < max_speed &&
	   length(e.vel) > max_speed &&
	   angle_between(e.vel, acceleration_v) <= 90 { 	// If overshooting below max speed
		e.vel = normalize(e.vel + acceleration_v + friction_v) * max_speed
	} else {
		e.vel += acceleration_v
		e.vel += friction_v
		// Account for friction overshooting when slowing down
		if acceleration_v.x == 0 && math.sign(e.vel.x) == math.sign(friction_v.x) {
			e.vel.x = 0
		}
		if acceleration_v.y == 0 && math.sign(e.vel.y) == math.sign(friction_v.y) {
			e.vel.y = 0
		}
	}

	// fmt.printfln(
	// 	"speed: %v, vel: %v fric vector: %v, acc vector: %v, acc length: %v",
	// 	length(e.vel),
	// 	e.vel,
	// 	friction_v,
	// 	acceleration_v,
	// )

	e.pos += e.vel * delta
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
	dst_rec := Rectangle {
		pos.x,
		pos.y,
		f32(tex.width) * math.abs(sprite.scale.x), // scale the sprite. a negative would mess this up
		f32(tex.height) * math.abs(sprite.scale.y),
	}

	src_rec := Rectangle {
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

turn_off_surf :: proc() {
	surfing = false
}
