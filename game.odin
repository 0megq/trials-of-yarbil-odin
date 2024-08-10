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
FIRE_DASH_RADIUS :: 32
FIRE_DASH_FIRE_DURATION :: 0.5
FIRE_DASH_COOLDOWN :: 2
ITEM_HOLD_DIVISOR :: 1

// weapon/attack related constants
ATTACK_DURATION :: 0.2
ATTACK_INTERVAL :: 0.4
SWORD_DAMAGE :: 10
SWORD_KNOCKBACK :: 250
SWORD_HITBOX_OFFSET :: 4

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
	fire:                   Control,
	alt_fire:               Control,
	use_item:               Control,
	switch_selected_weapon: Control,
	drop:                   Control,
	pickup:                 Control,
	cancel:                 Control,
	movement_ability:       Control,
}

controls: Controls = {
	fire                   = rl.MouseButton.LEFT,
	alt_fire               = rl.MouseButton.RIGHT,
	use_item               = rl.MouseButton.MIDDLE,
	switch_selected_weapon = rl.KeyboardKey.X,
	drop                   = rl.KeyboardKey.Q,
	pickup                 = rl.KeyboardKey.E,
	cancel                 = rl.KeyboardKey.LEFT_CONTROL,
	movement_ability       = rl.KeyboardKey.SPACE,
}

// weapon-related variables
attack_duration_timer: f32
can_attack: bool
attack_interval_timer: f32
attack_damage: f32
attack_knockback: f32
attack_poly: Polygon

sword_hitbox_points: []Vec2

surfing: bool
current_ability: MovementAbility
editor_mode: EditorMode = .None
can_fire_dash: bool
fire_dash_timer: f32
player: Player
camera: rl.Camera2D
z_entities: [dynamic]ZEntity
bombs: [dynamic]Bomb
projectile_weapons: [dynamic]ProjectileWeapon
fires: [dynamic]Fire
enemies: [dynamic]Enemy
hit_enemies: [dynamic]bool

delta: f32
mouse_world_pos: Vec2
mouse_world_delta: Vec2

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
		pos          = {32, 32},
		shape        = Circle{{}, 8},
		pickup_range = 16,
		health       = 100,
		max_health   = 100,
	}

	// Attack hitbox points
	sword_hitbox_points = {
		{SWORD_HITBOX_OFFSET, -12},
		{SWORD_HITBOX_OFFSET + 10, -5},
		{SWORD_HITBOX_OFFSET + 12, 0},
		{SWORD_HITBOX_OFFSET + 10, 5},
		{SWORD_HITBOX_OFFSET, 12},
	}

	pickup_item({.Sword, 100, 100})
	pickup_item({.Bomb, 3, 16})

	current_ability = .FIRE
	can_fire_dash = true

	surf_poly := Polygon{player.pos, {{10, -30}, {20, -20}, {30, 0}, {20, 20}, {10, 30}}, 0}

	fires = make([dynamic]Fire, context.allocator)

	z_entities = make([dynamic]ZEntity, context.allocator)
	bombs = make([dynamic]Bomb, context.allocator)
	projectile_weapons = make([dynamic]ProjectileWeapon, context.allocator)

	timers := make([dynamic]Timer, context.allocator)

	append(&timers, Timer{0.5, toggle_text_cursor, 0.5})

	items := make([dynamic]Item, context.allocator)
	append(&items, Item{pos = {500, 300}, shape = Circle{{}, 4}, data = {.Sword, 10, 10}})
	append(&items, Item{pos = {200, 50}, shape = Circle{{}, 4}, data = {.Bomb, 1, 16}})
	append(&items, Item{pos = {100, 50}, shape = Circle{{}, 4}, data = {.Apple, 5, 16}})

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

	// punch_rect: Rectangle = {
	// 	8,
	// 	PLAYER_PUNCH_SIZE.y * -0.5,
	// 	PLAYER_PUNCH_SIZE.x,
	// 	PLAYER_PUNCH_SIZE.y,
	// }
	// punch_points := rect_to_points(punch_rect)

	// attack_poly.points = punch_points[:]

	hit_enemies = make([dynamic]bool, context.allocator)
	for i := 0; i < len(enemies); i += 1 {append(&hit_enemies, false)}

	camera = rl.Camera2D {
		target = player.pos - {f32(GAME_SIZE.x), f32(GAME_SIZE.y)} / 2,
		zoom   = WINDOW_TO_GAME,
	}

	for !rl.WindowShouldClose() {
		delta = rl.GetFrameTime()
		mouse_world_pos = rl.GetMousePosition() / camera.zoom + camera.target
		mouse_world_delta = rl.GetMouseDelta() / camera.zoom

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

		for &weapon, i in projectile_weapons {
			zentity_move(&weapon, delta)
			for wall in level.walls {
				_, normal, depth := resolve_collision_shapes(
					weapon.shape,
					weapon.pos,
					wall.shape,
					wall.pos,
				)
				// fmt.printfln("%v, %v, %v", collide, normal, depth)
				if depth > 0 {
					weapon.pos -= normal * depth
					weapon.vel = slide(weapon.vel, normal)
					weapon.data.count -= 1
					if weapon.data.count <= 0 {
						unordered_remove(&projectile_weapons, i)
					}
				}
			}
			for enemy, j in enemies {
				_, normal, depth := resolve_collision_shapes(
					weapon.shape,
					weapon.pos,
					enemy.shape,
					enemy.pos,
				)
				// fmt.printfln("%v, %v, %v", collide, normal, depth)
				if depth > 0 {
					weapon.pos -= normal * depth
					weapon.vel = slide(weapon.vel, normal)
					// 10 is a arbitrary number. TODO: make this use a weapon specific damage value
					if !hit_enemies[j] {
						damage_enemy(j, 10)
						hit_enemies[j] = true
						weapon.data.count -= 1
					}
				}
			}
			if weapon.z <= 0 {
				append(&items, Item{pos = weapon.pos, data = weapon.data, shape = Circle{{}, 4}})
				unordered_remove(&projectile_weapons, i)
			}
		}

		// Raycast test
		// ray_min_t: [18]f32
		// for &min_t, i in ray_min_t {
		// 	dir := vector_from_angle(f32(i) * 360 / f32(len(ray_min_t)))
		// 	min_t = cast_ray_through_level(level.walls[:], player.pos, dir)
		// }

		attack_poly.rotation = angle(mouse_world_pos - player.pos)

		if player.charging_weapon {
			if player.weapon_switched || is_control_pressed(controls.cancel) {
				player.charging_weapon = false
			} else if is_control_released(controls.alt_fire) {
				alt_fire_selected_weapon()
				player.charging_weapon = false
			}

			player.weapon_charge_time += delta
		}

		if is_control_pressed(controls.fire) {
			if player.weapons[player.selected_weapon_idx].id >= .Sword {
				fire_selected_weapon()
				player.holding_item = false // Cancel item hold
				player.charging_weapon = false // cancel charge
			}
		} else if is_control_pressed(controls.alt_fire) &&
		   player.weapons[player.selected_weapon_idx].id != .Empty { 	// Start charging
			player.attacking = false // Cancel attack if attacking
			player.holding_item = false // Cancel item hold
			player.charging_weapon = true
			player.weapon_charge_time = 0
		}

		if player.holding_item {
			if player.item_switched || is_control_pressed(controls.cancel) {
				player.holding_item = false
			} else if is_control_released(controls.use_item) {
				use_selected_item()
				player.holding_item = false
			}

			player.item_hold_time += delta
		}
		if is_control_pressed(controls.use_item) &&
		   player.items[player.selected_item_idx].id != .Empty {
			player.attacking = false // Cancel attack
			player.charging_weapon = false // Cancel charge
			player.holding_item = true
			player.item_hold_time = 0
		}

		// Item drop
		if is_control_pressed(controls.drop) {
			if item_data := drop_item(); item_data.id != .Empty {
				append(&items, Item{pos = player.pos, shape = Circle{{}, 4}, data = item_data})
			}
		}

		// Item switching
		player.item_switched = false
		if y := int(rl.GetMouseWheelMove()); y != 0 {
			if player.item_count > 1 {
				player.selected_item_idx = (player.selected_item_idx - y) %% player.item_count
			}
			player.item_switched = true
		}

		// Weapon switching
		player.weapon_switched = false
		if is_control_pressed(controls.switch_selected_weapon) {
			select_weapon(0 if player.selected_weapon_idx == 1 else 1)
			player.attacking = false // Cancel attack if attacking
			player.weapon_switched = true
			fmt.println("switched to weapon", player.selected_weapon_idx)
		}

		if player.attacking {
			if attack_duration_timer <= 0 {
				player.attacking = false
				attack_interval_timer = ATTACK_INTERVAL
			} else {
				attack_duration_timer -= delta
				for enemy, i in enemies {
					if !hit_enemies[i] &&
					   check_collision_shapes(enemy.shape, enemy.pos, attack_poly, player.pos) {
						enemies[i].vel +=
							normalize(mouse_world_pos - player.pos) * attack_knockback
						hit_enemies[i] = true
						damage_enemy(i, attack_damage)
						if enemy.health <= 0 {
							unordered_remove(&enemies, i)
						}
					}
				}
			}
		} else if !can_attack { 	// If right after punch finished then tick punch rate timer until done
			if attack_interval_timer <= 0 {
				can_attack = true
			}
			attack_interval_timer -= delta
		}

		// Item pickup
		if is_control_pressed(controls.pickup) {
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
			// fmt.printfln(
			// 	"weapons: %v, items: %v, selected_weapon: %v, selected_item: %v",
			// 	player.weapons,
			// 	player.items,
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

			for &entity in projectile_weapons {
				entity.sprite.scale = entity.z + 1
				draw_sprite(entity.sprite, entity.pos)
			}

			// Draw Player
			{
				// Player Sprite
				draw_sprite(player_sprite, player.pos)

				// Draw Item
				if player.items[player.selected_item_idx].id != .Empty {
					draw_item(player.items[player.selected_item_idx].id, mouse_world_pos)
				}

				// Draw Weapon
				if player.weapons[player.selected_weapon_idx].id != .Empty {
					draw_item(player.weapons[player.selected_weapon_idx].id, mouse_world_pos)
				}

				/* Item hold bar */
				if player.holding_item {
					hold_bar_length: f32 = 2
					hold_bar_height: f32 = 8
					hold_bar_base_rec := get_centered_rect(
						{player.pos.x, player.pos.y},
						{hold_bar_length, hold_bar_height},
					)
					rl.DrawRectangleRec(hold_bar_base_rec, rl.BLACK)
					hold_bar_filled_rec := hold_bar_base_rec

					hold_bar_filled_rec.height *= get_item_hold_multiplier()
					hold_bar_filled_rec.y =
						hold_bar_base_rec.y + hold_bar_base_rec.height - hold_bar_filled_rec.height
					rl.DrawRectangleRec(hold_bar_filled_rec, rl.GREEN)
				}
				/* End of Item hold bar */

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

				if !player.holding_item &&
				   player.weapons[player.selected_weapon_idx].id >= .Sword {
					attack_hitbox_color := rl.Color{255, 255, 255, 120}
					if player.attacking {
						attack_hitbox_color = rl.Color{255, 0, 0, 120}
					}
					draw_shape(attack_poly, player.pos, attack_hitbox_color)
				}

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

			draw_hud()


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

get_item_hold_multiplier :: proc() -> f32 {
	// https://en.wikipedia.org/wiki/Triangle_wave
	// 1/p * abs((x - p) % (2 * p) - p)
	// p = HOLD_DIVISOR
	// x = player.item_hold_time
	// Returns a value between 0 and 1
	return(
		math.abs(
			math.mod(player.item_hold_time + ITEM_HOLD_DIVISOR, 2 * ITEM_HOLD_DIVISOR) -
			ITEM_HOLD_DIVISOR,
		) /
		ITEM_HOLD_DIVISOR \
	)
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

use_selected_item :: proc() {
	// get selected item ItemId
	item_data := player.items[player.selected_item_idx]
	if item_data.id == .Empty || item_data.id >= .Sword {
		assert(false, "can't use item with empty or weapon id")
	}

	to_mouse := normalize(mouse_world_pos - player.pos)

	hold_multiplier := get_item_hold_multiplier()

	// use item
	#partial switch item_data.id {
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
		// 180 is an arbitrary multiplier. TODO: make a constant variable for it
		base_vel := hold_multiplier * 180
		append(
			&bombs,
			Bomb {
				pos = player.pos,
				shape = Rectangle{-1, 0, 3, 3},
				vel = to_mouse * base_vel,
				z = 0,
				vel_z = 20,
				sprite = sprite,
				time_left = 1,
			},
		)
		add_to_selected_item_count(-1)
	}
	// subtract from the count of item in the inventory. if no item is left then
}

// Adds to the count of selected item. If the count is less than then it removes the item from the player and deselects it
// Excess will be negative if count goes below 0
add_to_selected_item_count :: proc(to_add: int) -> (excess: int) {
	item_data := &player.items[player.selected_item_idx]
	if item_data.id == .Empty || item_data.id >= .Sword || item_data.count <= 0 {
		assert(false, "invalid item data")
	}
	item_data.count += to_add
	if item_data.count <= 0 {
		// Deselect item if count <= 0
		excess = item_data.count
		item_data.count = 0
		remove_selected_item()
	}
	return
}

fire_selected_weapon :: proc() -> int {
	// get selected weapon ItemId
	weapon_data := player.weapons[player.selected_weapon_idx]
	if weapon_data.id < .Sword {
		assert(false, "can't use weapon with empty or item id")
	}
	// to_mouse := normalize(mouse_world_pos - player.pos)

	// Fire weapon
	#partial switch weapon_data.id {
	case .Sword:
		// play sword attack animation
		if can_attack {
			// Attack
			attack_duration_timer = ATTACK_DURATION
			player.attacking = true
			attack_damage = SWORD_DAMAGE
			attack_knockback = SWORD_KNOCKBACK
			can_attack = false
			for i in 0 ..< len(hit_enemies) {
				hit_enemies[i] = false
			}
		}
	}
	return 0
}

// Returns the count of item used. If the item was not used then this is zero
alt_fire_selected_weapon :: proc() -> int {
	// get selected weapon ItemId
	weapon_data := player.weapons[player.selected_weapon_idx]
	if weapon_data.id < .Sword {
		assert(false, "can't use weapon with empty or item id")
	}
	to_mouse := normalize(mouse_world_pos - player.pos)

	// Alt fire weapon
	#partial switch weapon_data.id {
	case .Sword:
		// Throw sword here
		tex := loaded_textures[.Sword]
		sprite: Sprite = {
			.Sword,
			{0, 0, f32(tex.width), f32(tex.height)},
			{1, 1},
			{f32(tex.width) / 2, f32(tex.height) / 2},
			0,
			rl.WHITE,
		}
		append(
			&projectile_weapons,
			ProjectileWeapon {
				pos = player.pos,
				shape = Rectangle {
					-f32(tex.width) / 2,
					-f32(tex.height) / 2,
					f32(tex.width),
					f32(tex.height),
				},
				vel = to_mouse * 150,
				z = 0,
				vel_z = 12,
				sprite = sprite,
				data = weapon_data,
			},
		)
		for i in 0 ..< len(hit_enemies) {
			hit_enemies[i] = false
		}
		player.weapons[player.selected_weapon_idx].id = .Empty
	}
	return 0
}

draw_weapon :: proc(weapon: ItemId, mouse_pos: Vec2) {

}

draw_item :: proc(item: ItemId, mouse_pos: Vec2) {
	tex_id := item_to_texture[item]
	tex := loaded_textures[tex_id]
	sprite: Sprite = {tex_id, {0, 0, f32(tex.width), f32(tex.height)}, {1, 1}, {}, 0, rl.WHITE}
	draw_sprite(sprite, player.pos)
}

remove_selected_item :: proc() {
	player.item_count -= 1
	// If there is no empty in the next slot (last idx in items array or if next idx has Empty)
	if player.selected_item_idx == len(player.items) - 1 ||
	   player.items[player.selected_item_idx + 1].id == .Empty {
		player.items[player.selected_item_idx].id = .Empty
		player.selected_item_idx = 0
	} else {
		// This is not the most efficient way to do this, but it works fine
		for i := player.selected_item_idx + 1; i < len(player.items); i += 1 {
			// Copy value to prev index
			player.items[i - 1] = player.items[i]
		}
		// Set last item to empty
		player.items[len(player.items) - 1].id = .Empty
	}
}

// Returns true if the item was succesfully picked up
pickup_item :: proc(data: ItemData) -> bool {
	if data.id < ItemId(100) { 	// Not a weapon
		for &item in player.items {
			if item.id == .Empty {
				item = data
				player.item_count += 1
				return true
			} else if item.id == data.id {
				item.count += data.count
				return true
			}
		}
	} else { 	// Is a weapon
		for &weapon, i in player.weapons {
			if weapon.id == .Empty {
				weapon = data

				// Select weapon if currently selected nothing
				if player.weapons[player.selected_weapon_idx].id == .Empty ||
				   player.selected_weapon_idx == i {
					select_weapon(i)
				}

				return true
			}
		}
	}
	return false
}

select_weapon :: proc(idx: int) {
	player.selected_weapon_idx = idx
	#partial switch player.weapons[idx].id {
	case .Sword:
		attack_poly.points = sword_hitbox_points
	}
}

// Removes the currently selected and active item/weapon from player's inventory and returns its ItemData
drop_item :: proc() -> ItemData {
	if !player.holding_item {
		// If a weapon is selected and it is not empty
		if player.weapons[player.selected_weapon_idx].id != .Empty {
			weapon_data := player.weapons[player.selected_weapon_idx]
			// Set the weapon to empty and deselect it
			player.weapons[player.selected_weapon_idx].id = .Empty
			player.charging_weapon = false // Stop charging
			player.attacking = false // Cancel attack
			return weapon_data
		}
	} else {
		// If a item is selected and it is not empty
		if player.items[player.selected_item_idx].id != .Empty {
			item_data := player.items[player.selected_item_idx]
			remove_selected_item()
			player.holding_item = false
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
