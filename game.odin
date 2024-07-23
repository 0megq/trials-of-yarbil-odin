package game

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

WINDOW_SIZE :: Vec2i{1440, 810}
GAME_SIZE :: Vec2i{480, 270}
WINDOW_TO_GAME :: f32(WINDOW_SIZE.x) / f32(GAME_SIZE.x)
PLAYER_BASE_MAX_SPEED :: 80
PLAYER_BASE_ACCELERATION :: 1500
PLAYER_BASE_FRICTION :: 750
PLAYER_BASE_HARSH_FRICTION :: 2000
PLAYER_PUNCH_SIZE :: Vec2{12, 16}
ENEMY_PATHFINDING_TIME :: 0.5
PUNCH_TIME :: 0.2
TIME_BETWEEN_PUNCH :: 0.4
PUNCH_POWER :: 150
SWORD_POWER :: 250
FIRE_DASH_RADIUS :: 32
FIRE_DASH_FIRE_DURATION :: 0.5
FIRE_DASH_COOLDOWN :: 2

EditorMode :: enum {
	None,
	Level,
	NavMesh,
}

Timer :: struct {
	time_left:  f32,
	callable:   proc(),
	start_time: f32, // Set to 0 or less if want to not one shot
}

MovementAbility :: enum {
	FIRE,
	WATER,
	ELECTRIC,
	GROUND,
	AIR,
}

Level :: struct {
	walls:    [dynamic]PhysicsEntity,
	nav_mesh: NavMesh,
}

Control :: union {
	rl.KeyboardKey,
	rl.MouseButton,
}

Controls :: struct {
	fire:             Control,
	alt_fire:         Control,
	drop_item:        Control,
	// switch between sword and item being active
	switch_active:    Control,
	pickup_item:      Control,
	movement_ability: Control,
}

controls: Controls = {
	fire             = rl.MouseButton.LEFT,
	alt_fire         = rl.MouseButton.RIGHT,
	drop_item        = rl.KeyboardKey.Q,
	switch_active    = rl.KeyboardKey.X,
	pickup_item      = rl.KeyboardKey.E,
	movement_ability = rl.KeyboardKey.SPACE,
}

punching: bool
punch_timer: f32
can_punch: bool
punch_rate_timer: f32
surfing: bool
current_ability: MovementAbility
editor_mode: EditorMode = .None
can_fire_dash: bool
fire_dash_timer: f32
player: Player
camera: rl.Camera2D
z_entities: [dynamic]ZEntity
bombs: [dynamic]Bomb
fires: [dynamic]Fire
enemies: [dynamic]Enemy

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
	load_navmesh()

	player = {
		pos                 = {32, 32},
		shape               = Circle{{}, 8},
		pickup_range        = 16,
		health              = 100,
		max_health          = 100,
		weapon_active       = true,
		selected_weapon_idx = -1,
		selected_item_idx   = -1,
	}
	player.weapons[0] = {
		id = .Sword,
	}
	player.selected_weapon_idx = 0

	player.items[0] = {
		id = .Bomb,
	}
	player.selected_item_idx = 0

	current_ability = .FIRE
	can_fire_dash = true

	surf_poly := Polygon{player.pos, {{10, -30}, {20, -20}, {30, 0}, {20, 20}, {10, 30}}, 0}

	fires = make([dynamic]Fire, context.allocator)

	z_entities = make([dynamic]ZEntity, context.allocator)
	bombs = make([dynamic]Bomb, context.allocator)

	timers := make([dynamic]Timer, context.allocator)

	append(&timers, Timer{0.5, toggle_text_cursor, 0.5})

	items := make([dynamic]Item, context.allocator)
	append(&items, Item{pos = {500, 300}, shape = Circle{{}, 4}, data = {.Sword, 10, 10}})

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
		delete(level_data)
	} else {
		append(&level.walls, wall1)
	}

	enemies = make([dynamic]Enemy, context.allocator)
	enemy_attack_poly := Polygon{{}, {{10, -10}, {16, -8}, {20, 0}, {16, 8}, {10, 10}}, 0}
	append(&enemies, new_enemy({300, 80}, enemy_attack_poly))
	append(&enemies, new_enemy({200, 200}, enemy_attack_poly))
	append(&enemies, new_enemy({130, 200}, enemy_attack_poly))
	append(&enemies, new_enemy({220, 180}, enemy_attack_poly))
	append(&enemies, new_enemy({80, 300}, enemy_attack_poly))

	player_sprite := Sprite{.Player, {0, 0, 12, 16}, {1, 1}, {5.5, 7.5}, 0, rl.WHITE}

	player_radius: f32 = 8
	punch_rect: Rectangle = {
		player_radius,
		PLAYER_PUNCH_SIZE.y * -0.5,
		PLAYER_PUNCH_SIZE.x,
		PLAYER_PUNCH_SIZE.y,
	}
	punch_points := rect_to_points(punch_rect)
	// sword_points: []Vec2 = {
	// 	{player_radius, -12},
	// 	{player_radius + 10, -5},
	// 	{player_radius + 12, 0},
	// 	{player_radius + 10, 5},
	// 	{player_radius, 12},
	// }
	attack_poly: Polygon
	attack_poly.points = punch_points[:]

	hit_enemies: [dynamic]bool = make([dynamic]bool, context.allocator)
	for i := 0; i < len(enemies); i += 1 {append(&hit_enemies, false)}

	camera = rl.Camera2D {
		target = player.pos - {f32(GAME_SIZE.x), f32(GAME_SIZE.y)} / 2,
		zoom   = WINDOW_TO_GAME,
	}

	for !rl.WindowShouldClose() {
		delta := rl.GetFrameTime()
		mouse_world_pos := rl.GetMousePosition() / camera.zoom + camera.target
		mouse_world_delta := rl.GetMouseDelta() / camera.zoom

		for &timer, i in timers {
			timer.time_left -= delta
			if timer.time_left <= 0 {
				timer.callable()
				if timer.start_time > 0 {
					timer.time_left += timer.start_time
				} else {
					unordered_remove(&timers, i)
				}
			}
		}

		if rl.IsKeyPressed(.H) {
			editor_mode = EditorMode((int(editor_mode) + 1) % 3)
		}

		#partial switch editor_mode {
		case .Level:
			update_editor(
				&level.walls,
				rl.GetMousePosition(),
				rl.GetMouseDelta(),
				mouse_world_pos,
				mouse_world_delta,
				camera.target,
			)
		case .NavMesh:
			update_navmesh_editor(mouse_world_pos, mouse_world_delta)
		}

		if !can_fire_dash {
			fire_dash_timer -= delta
			if fire_dash_timer <= 0 {
				can_fire_dash = true
			}
		}

		if is_control_pressed(controls.movement_ability) {
			switch current_ability {
			case .FIRE:
				if can_fire_dash {
					can_fire_dash = false
					fire_dash_timer = FIRE_DASH_COOLDOWN

					player.vel = normalize(get_directional_input()) * 250
					fire := Fire{{player.pos, FIRE_DASH_RADIUS}, FIRE_DASH_FIRE_DURATION}
					append(&fires, fire)
					for &enemy, i in enemies {
						if check_collision_shapes(fire.circle, {}, enemy.shape, enemy.pos) {
							power_scale :=
								(FIRE_DASH_RADIUS - length(enemy.pos - fire.pos)) /
								FIRE_DASH_RADIUS
							power_scale = max(power_scale, 0.6) // TODO use a map function
							enemy.vel -= normalize(fire.pos - enemy.pos) * 400 * power_scale
							damage_enemy(i, 20)
						}
					}
				}
			case .WATER:
				surfing = true
				append(&timers, Timer{0.5, turn_off_surf, 0})
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
			for &enemy, i in enemies {
				if check_collision_shapes(surf_poly, {}, enemy.shape, enemy.pos) {
					enemy.vel = normalize(enemy.pos - (surf_poly.pos + {10, 0})) * 250
					damage_enemy(i, 5)
				}
			}
		}

		if editor_mode == .None {
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

		for &fire, i in fires {
			fire.time_left -= delta
			if fire.time_left <= 0 {
				unordered_remove(&fires, i)
			}
		}

		// Move enemies and track player if in range
		for &enemy in enemies {

			// Update detection points
			for &p, i in enemy.detection_points {
				dir := vector_from_angle(f32(i) * 360 / f32(len(enemy.detection_points)))
				t := cast_ray_through_level(level.walls[:], enemy.pos, dir)
				if t < enemy.detection_range {
					p = enemy.pos + t * dir
				} else {
					p = enemy.pos + enemy.detection_range * dir
				}
			}

			if enemy.player_in_range &&
			   !check_collsion_circular_concave_circle(
					   enemy.detection_points[:],
					   enemy.pos,
					   {player.shape.(Circle).pos + player.pos, player.shape.(Circle).radius},
				   ) {
				enemy.player_in_range = false
			} else if !enemy.player_in_range &&
			   check_collsion_circular_concave_circle(
				   enemy.detection_points[:],
				   enemy.pos,
				   {player.shape.(Circle).pos + player.pos, player.shape.(Circle).radius},
			   ) {
				enemy.player_in_range = true
				if enemy.current_path != nil {
					delete(enemy.current_path)
				}
				enemy.current_path = find_path(enemy.pos, player.pos, game_nav_mesh)
				enemy.current_path_point = 1
				enemy.pathfinding_timer = ENEMY_PATHFINDING_TIME
			}

			// Recalculate path based on timer or if the enemy is at the end of the path already
			if enemy.player_in_range {
				enemy.pathfinding_timer -= delta
				if enemy.pathfinding_timer < 0 {
					// Reset timer
					enemy.pathfinding_timer = ENEMY_PATHFINDING_TIME
					// Find new path
					delete(enemy.current_path)
					enemy.current_path = find_path(enemy.pos, player.pos, game_nav_mesh)
					enemy.current_path_point = 1
				}
				if enemy.current_path_point >= len(enemy.current_path) {
					delete(enemy.current_path)
					enemy.current_path = find_path(enemy.pos, player.pos, game_nav_mesh)
					enemy.current_path_point = 1
				}
			}
			// Follow path if there exists one and the enemy is not already at the end of it
			target := enemy.pos
			if enemy.current_path != nil && enemy.current_path_point < len(enemy.current_path) {
				target = enemy.current_path[enemy.current_path_point]
				if distance_squared(enemy.pos, enemy.current_path[enemy.current_path_point]) <
				   10 { 	// Enemy is at the point
					enemy.current_path_point += 1
				}
			}

			enemy_move(&enemy, delta, target)

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

			if enemy.flinching {
				enemy.current_flinch_time -= delta
				if enemy.current_flinch_time <= 0 {
					enemy.flinching = false
				}
			}

			enemy.just_attacked = false
			if enemy.charging {
				enemy.current_charge_time -= delta
				if enemy.current_charge_time <= 0 {
					enemy.just_attacked = true
					enemy.charging = false
					if check_collision_shapes(
						enemy.attack_poly,
						enemy.pos,
						player.shape,
						player.pos,
					) {
						fmt.println("damaged")
						player.health -= 5
						if player.health <= 0 {
							fmt.println("player is dead")
						}
					}
				}
			}

			// If player in attack trigger range
			if !enemy.flinching &&
			   !enemy.charging &&
			   check_collision_shapes(
				   Circle{{}, enemy.attack_charge_range},
				   enemy.pos,
				   player.shape,
				   player.pos,
			   ) {
				enemy.attack_poly.rotation = angle(player.pos - enemy.pos)
				enemy.charging = true
				enemy.current_charge_time = enemy.start_charge_time
			}
		}

		for &entity in z_entities {
			zentity_move(&entity, delta)
			for wall in level.walls {
				_, normal, depth := resolve_collision_shapes(
					entity.shape,
					entity.pos,
					wall.shape,
					wall.pos,
				)
				// fmt.printfln("%v, %v, %v", collide, normal, depth)
				if depth > 0 {
					entity.pos -= normal * depth
					entity.vel = slide(entity.vel, normal)
				}
			}
		}

		for &bomb, i in bombs {
			zentity_move(&bomb, delta)
			for wall in level.walls {
				_, normal, depth := resolve_collision_shapes(
					bomb.shape,
					bomb.pos,
					wall.shape,
					wall.pos,
				)
				// fmt.printfln("%v, %v, %v", collide, normal, depth)
				if depth > 0 {
					bomb.pos -= normal * depth
					bomb.vel = slide(bomb.vel, normal)
				}
			}
			for enemy in enemies {
				_, normal, depth := resolve_collision_shapes(
					bomb.shape,
					bomb.pos,
					enemy.shape,
					enemy.pos,
				)
				// fmt.printfln("%v, %v, %v", collide, normal, depth)
				if depth > 0 {
					bomb.pos -= normal * depth
					bomb.vel = slide(bomb.vel, normal)
				}
			}
			if bomb.z <= 0 {
				bomb.time_left -= delta
				if bomb.time_left <= 0 {
					bomb_explosion(bomb.pos, 8)
					for &enemy, j in enemies {
						if check_collision_shapes(
							Circle{{}, 8},
							bomb.pos,
							enemy.shape,
							enemy.pos,
						) {
							damage_enemy(j, 6)
						}
					}
					unordered_remove(&bombs, i)
				}
			}
		}

		// Raycast test
		// ray_min_t: [18]f32
		// for &min_t, i in ray_min_t {
		// 	dir := vector_from_angle(f32(i) * 360 / f32(len(ray_min_t)))
		// 	min_t = cast_ray_through_level(level.walls[:], player.pos, dir)
		// }

		attack_poly.rotation = angle(mouse_world_pos - player.pos)

		if is_control_pressed(controls.switch_active) {
			player.weapon_active = !player.weapon_active
			fmt.printfln("weapon active: %v", player.weapon_active)
		}

		if is_control_pressed(controls.fire) {
			if player.weapon_active && player.selected_weapon_idx != -1 {
				fire(player.weapons[player.selected_weapon_idx].id, mouse_world_pos)
			} else if player.selected_item_idx != -1 {
				fire(player.items[player.selected_item_idx].id, mouse_world_pos)
			}
		} else if is_control_pressed(controls.alt_fire) {

		}

		// Item pickup
		if is_control_pressed(controls.pickup_item) {
			closest_item_idx := -1
			closest_item_dist_sqrd := math.INF_F32
			for item, i in items {
				if check_collision_shapes(
					Circle{{}, player.pickup_range},
					player.pos,
					item.shape,
					item.pos,
				) {
					dist_sqrd := distance_squared(item.pos, player.pos)
					if closest_item_idx == -1 || dist_sqrd < closest_item_dist_sqrd {
						closest_item_idx = i
						closest_item_dist_sqrd = dist_sqrd
					}
				}
			}
			if closest_item_idx != -1 {
				item := items[closest_item_idx]
				if pickup_item(item.data) {
					unordered_remove(&items, closest_item_idx)
				}
			}
			fmt.printfln(
				"weapons: %v, items: %v, weapon_active: %v, selected_weapon: %v, selected_item: %v",
				player.weapons,
				player.items,
				player.weapon_active,
				player.selected_weapon_idx,
				player.selected_item_idx,
			)
		}

		// Item drop
		if is_control_pressed(controls.drop_item) {
			if item_data := drop_item(); item_data.id != .Empty {
				append(&items, Item{pos = player.pos, shape = Circle{{}, 4}, data = item_data})
			}
			// fmt.printfln(
			// 	"weapons: %v, items: %v, weapon_active: %v, selected_weapon: %v, selected_item: %v",
			// 	player.weapons,
			// 	player.items,
			// 	player.weapon_active,
			// 	player.selected_weapon_idx,
			// 	player.selected_item_idx,
			// )
		}

		// Drawing
		{
			rl.BeginDrawing()
			rl.ClearBackground(rl.DARKGRAY)

			// Zooming
			{
				if editor_mode == .None {
					camera.target = player.pos - {f32(GAME_SIZE.x), f32(GAME_SIZE.y)} / 2
					camera.zoom = WINDOW_TO_GAME
				} else {
					if rl.IsMouseButtonDown(.MIDDLE) {
						camera.target -= mouse_world_delta
					}
					world_center :=
						camera.target + {f32(WINDOW_SIZE.x), f32(WINDOW_SIZE.y)} / camera.zoom / 2
					camera.zoom += rl.GetMouseWheelMove() * 0.2 * camera.zoom
					camera.zoom = max(0.1, camera.zoom)
					camera.target =
						world_center - {f32(WINDOW_SIZE.x), f32(WINDOW_SIZE.y)} / camera.zoom / 2
				}
			}

			rl.BeginMode2D(camera)

			if surfing {
				draw_polygon(surf_poly, rl.DARKGREEN)
			}

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
				health_bar_length: f32 = 20
				health_bar_height: f32 = 5
				health_bar_base_rec := get_centered_rect(
					{enemy.pos.x, enemy.pos.y - 20},
					{health_bar_length, health_bar_height},
				)
				rl.DrawRectangleRec(health_bar_base_rec, rl.BLACK)
				health_bar_filled_rec := health_bar_base_rec
				health_bar_filled_rec.width *= enemy.health / enemy.max_health
				rl.DrawRectangleRec(health_bar_filled_rec, rl.RED)

				attack_area_color := rl.Color{255, 255, 255, 120}
				if enemy.just_attacked {
					attack_area_color = rl.Color{255, 0, 0, 120}
				}
				if enemy.charging || enemy.just_attacked {
					draw_shape(enemy.attack_poly, enemy.pos, attack_area_color)
				}

				// Draw detection area
				// rl.DrawCircleLinesV(enemy.pos, enemy.detection_range, rl.YELLOW)
				// for p, i in enemy.detection_points {
				// 	rl.DrawLineV(
				// 		p,
				// 		enemy.detection_points[(i + 1) % len(enemy.detection_points)],
				// 		rl.YELLOW,
				// 	)
				// }

				if enemy.current_path != nil {
					for point in enemy.current_path {
						rl.DrawCircleV(point, 2, rl.RED)
					}
				}
			}

			// Draw Z Entities
			for &entity in z_entities {
				entity.sprite.scale = entity.z + 1
				draw_sprite(entity.sprite, entity.pos)
			}

			for &entity in bombs {
				entity.sprite.scale = entity.z + 1
				draw_sprite(entity.sprite, entity.pos)
			}

			// Draw Player
			{
				// Player Sprite
				draw_sprite(player_sprite, player.pos)

				// Draw Item
				if player.selected_item_idx != -1 &&
				   player.items[player.selected_item_idx].id != .Empty {
					draw_item(player.items[player.selected_item_idx].id, mouse_world_pos)
				}

				// Draw Weapon
				if player.selected_weapon_idx != -1 &&
				   player.weapons[player.selected_weapon_idx].id != .Empty {
					draw_item(player.weapons[player.selected_weapon_idx].id, mouse_world_pos)
				}


				/* Health Bar */
				health_bar_length: f32 = 20
				health_bar_height: f32 = 5
				health_bar_base_rec := get_centered_rect(
					{player.pos.x, player.pos.y - 20},
					{health_bar_length, health_bar_height},
				)
				rl.DrawRectangleRec(health_bar_base_rec, rl.BLACK)
				health_bar_filled_rec := health_bar_base_rec
				health_bar_filled_rec.width *= player.health / player.max_health
				rl.DrawRectangleRec(health_bar_filled_rec, rl.RED)
				/* End of Health Bar */

				punch_area_color := rl.Color{255, 255, 255, 120}
				if punching {
					punch_area_color = rl.Color{255, 0, 0, 120}
				}
				draw_shape(attack_poly, player.pos, punch_area_color)

				// Player pickup range
				// draw_shape_lines(Circle{{}, player.pickup_range}, player.pos, rl.DARKBLUE)
				// Collision shape
				// draw_shape(player.shape, player.pos, rl.RED)
			}

			#partial switch editor_mode {
			case .Level:
				draw_editor_world()
			case .NavMesh:
				draw_navmesh_editor_world(mouse_world_pos)
			}

			rl.EndMode2D()

			// Display Fire Dash Status
			if current_ability == .FIRE {
				if can_fire_dash {
					rl.DrawText("Fire Dash Ready", 1000, 16, 20, rl.ORANGE)
				} else {
					rl.DrawText(
						fmt.ctprintf("On Cooldown: %f", fire_dash_timer),
						1000,
						16,
						20,
						rl.WHITE,
					)
				}
			}

			#partial switch editor_mode {
			case .Level:
				draw_editor_ui()
			case .NavMesh:
				draw_navmesh_editor_ui(mouse_world_pos, camera)
			}

			rl.EndDrawing()
		}
		free_all(context.temp_allocator)
	}

	if level_data, err := json.marshal(level, allocator = context.allocator); err == nil {
		os.write_entire_file("level.json", level_data)
		delete(level_data)
	}
	delete(level.walls)

	save_navmesh()
	unload_navmesh()
	mem.tracking_allocator_clear(&track)
	free_all(context.temp_allocator)
	free_all(context.allocator)

	unload_textures()
	rl.CloseWindow()
}

bomb_explosion :: proc(pos: Vec2, radius: f32) {
	append(&fires, Fire{Circle{pos, radius}, 0.5})
}

zentity_move :: proc(e: ^ZEntity, delta: f32) {
	friction: f32 = 300
	gravity: f32 = 50

	// Z movement
	{
		// Apply gravity
		if e.vel_z > 0 || e.z > 0 {
			e.vel_z -= gravity * delta
			e.z += e.vel_z * delta
		}
		// Snap to ground
		if e.z < 0 {
			e.z = 0
			if e.vel_z < 0 {
				e.vel_z = 0
			}
		}
	}

	// 2D Movement
	{
		// Apply friction if on ground
		if e.z <= 0 {
			friction_dir: Vec2 = -normalize(e.vel)
			friction_v := friction_dir * friction * delta

			e.vel += friction_v
			// Account for friction overshooting when slowing down
			if math.sign(e.vel.x) == math.sign(friction_v.x) {
				e.vel.x = 0
			}
			if math.sign(e.vel.y) == math.sign(friction_v.y) {
				e.vel.y = 0
			}
		}

		e.pos += e.vel * delta
	}
}

player_move :: proc(e: ^Player, delta: f32) {
	max_speed: f32 = PLAYER_BASE_MAX_SPEED
	acceleration: f32 = PLAYER_BASE_ACCELERATION
	friction: f32 = PLAYER_BASE_FRICTION
	harsh_friction: f32 = PLAYER_BASE_HARSH_FRICTION

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
	// 	length(acceleration_v),
	// )

	e.pos += e.vel * delta
}

enemy_move :: proc(e: ^Enemy, delta: f32, target: Vec2) {
	max_speed: f32 = 80.0
	acceleration: f32 = 400.0
	friction: f32 = 240.0
	harsh_friction: f32 = 500.0

	input: Vec2
	if !e.charging && !e.flinching && target != e.pos {
		input = normalize(target - e.pos)
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

cast_ray_through_level :: proc(walls: []PhysicsEntity, start: Vec2, dir: Vec2) -> f32 {
	min_t := math.INF_F32
	for wall in walls {
		t := cast_ray(start, dir, wall.shape, wall.pos)
		if t == -1 {
			continue
		}

		if t < min_t {
			min_t = t
		}
	}
	return min_t
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

damage_enemy :: proc(enemy_idx: int, amount: f32) {
	enemy := &enemies[enemy_idx]
	enemy.charging = false
	enemy.health -= amount
	enemy.flinching = true
	enemy.current_flinch_time = enemy.start_flinch_time
	if enemy.health <= 0 {
		unordered_remove(&enemies, enemy_idx)
	}
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

world_to_screen :: proc(point: Vec2, camera: rl.Camera2D) -> Vec2 {
	return (point - camera.target) * camera.zoom
}

// Returns the count of item used. If the item was not used then this is zero
fire_pressed :: proc(item: ItemId, mouse_pos: Vec2) -> int {
	to_mouse := normalize(mouse_pos - player.pos)
	#partial switch item {
	case .Bomb:
		tex := loaded_textures[.Bomb]
		sprite: Sprite = {
			.Bomb,
			{0, 0, f32(tex.width), f32(tex.height)},
			{1, 1},
			{1, 2},
			0,
			rl.WHITE,
		}
		append(
			&bombs,
			Bomb {
				pos = player.pos,
				shape = Rectangle{-1, 0, 3, 3},
				vel = to_mouse * 64,
				z = 0,
				vel_z = 15,
				sprite = sprite,
				time_left = 1,
			},
		)
	case .Sword:

	}
}

// Returns the count of item used. If the item was not used then this is zero
fire_released :: proc(item: ItemId, mouse_pos: Vec2) -> int {
	to_mouse := normalize(mouse_pos - player.pos)
	#partial switch item {
	case .Bomb:

	case .Sword:

	}
}

// Returns the count of item used. If the item was not used then this is zero
alt_fire :: proc(item: ItemId, mouse_pos: Vec2) -> int {

}

// Returns the count of item used. If the item was not used then this is zero
alt_fire_released :: proc(item: ItemId, mouse_pos: Vec2) -> int {

}

draw_weapon :: proc(weapon: ItemId, mouse_pos: Vec2) {

}

draw_item :: proc(item: ItemId, mouse_pos: Vec2) {
	tex_id := item_to_texture[item]
	tex := loaded_textures[tex_id]
	sprite: Sprite = {tex_id, {0, 0, f32(tex.width), f32(tex.height)}, {1, 1}, {}, 0, rl.WHITE}
	draw_sprite(sprite, player.pos)
}

// Returns true if the item was succesfully picked up
pickup_item :: proc(data: ItemData) -> bool {
	if data.id < ItemId(100) { 	// Not a weapon
		for &item, i in player.items {
			if item.id == .Empty {
				item = data
				// Select item if currently selected nothing
				if player.selected_item_idx == -1 {
					player.selected_item_idx = i
					// If no weapon selected then make item active
					if player.selected_weapon_idx == -1 {
						player.weapon_active = false
					}
				}
				return true
			}
		}
	} else { 	// Is a weapon
		for &weapon, i in player.weapons {
			if weapon.id == .Empty {
				// Select weapon if currently selected nothing
				if player.selected_weapon_idx == -1 {
					player.selected_weapon_idx = i
					// If no item selected then make weapon active
					if player.selected_item_idx == -1 {
						player.weapon_active = true
					}
				}
				weapon = data
				return true
			}
		}
	}
	return false
}

// Removes the currently selective and active item/weapon from player's inventory and returns its ItemData
drop_item :: proc() -> ItemData {
	if player.weapon_active {
		// If a weapon is selected and it is not empty
		if player.selected_weapon_idx != -1 &&
		   player.weapons[player.selected_weapon_idx].id != .Empty {
			weapon_data := player.weapons[player.selected_weapon_idx]
			// Set the weapon to empty and deselect it
			player.weapons[player.selected_weapon_idx].id = .Empty
			player.selected_weapon_idx = -1 // TODO: make the weapons inLook for ontory tor select
			return weapon_data
		}
	} else {
		// If a item is selected and it is not empty
		if player.selected_item_idx != -1 && player.items[player.selected_item_idx].id != .Empty {
			item_data := player.items[player.selected_item_idx]
			// Set the item to empty and deselect it
			player.items[player.selected_item_idx].id = .Empty // TODO: Look for other items in inventory to select
			player.selected_item_idx = -1
			return item_data
		}
	}
	return {}
}

is_control_pressed :: proc(c: Control) -> bool {
	switch v in c {
	case rl.KeyboardKey:
		return rl.IsKeyPressed(v)
	case rl.MouseButton:
		return rl.IsMouseButtonPressed(v)
	}
	return false
}

is_control_released :: proc(c: Control) -> bool {
	switch v in c {
	case rl.KeyboardKey:
		return rl.IsKeyReleased(v)
	case rl.MouseButton:
		return rl.IsMouseButtonReleased(v)
	}
	return false
}
