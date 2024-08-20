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
WEAPON_CHARGE_DIVISOR :: 1

// weapon/attack related constants
ATTACK_DURATION :: 0.15
ATTACK_INTERVAL :: 0.4
SWORD_DAMAGE :: 10
SWORD_KNOCKBACK :: 150
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
	alt_fire               = rl.MouseButton.MIDDLE,
	use_item               = rl.MouseButton.RIGHT,
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

WeaponAnimation :: struct {
	// Constants
	cpos_top_rotation:    f32,
	csprite_top_rotation: f32,
	cpos_bot_rotation:    f32,
	csprite_bot_rotation: f32,

	// For animation purposes
	pos_rotation_vel:     f32, // Simulates the rotation of the arc of the swing
	sprite_rotation_vel:  f32, // Simulates the rotation of the sprite

	// Weapon rotations
	pos_cur_rotation:     f32,
	sprite_cur_rotation:  f32,
}
sword_animation := WeaponAnimation{-70, -160, 70, 160, 0, 0, -70, -160}


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
items: [dynamic]Item
exploding_barrels: [dynamic]ExplodingBarrel

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

	current_ability = .WATER
	can_fire_dash = true

	surf_poly := Polygon{player.pos, {{10, -30}, {20, -20}, {30, 0}, {20, 20}, {10, 30}}, 0}

	fires = make([dynamic]Fire, context.allocator)

	z_entities = make([dynamic]ZEntity, context.allocator)
	bombs = make([dynamic]Bomb, context.allocator)
	exploding_barrels = make([dynamic]ExplodingBarrel, context.allocator)
	append(&exploding_barrels, ExplodingBarrel{pos = {24, 64}, shape = Circle{{}, 6}, health = 50})

	projectile_weapons = make([dynamic]ProjectileWeapon, context.allocator)

	timers := make([dynamic]Timer, context.allocator)

	append(&timers, Timer{0.5, toggle_text_cursor, 0.5})

	items = make([dynamic]Item, context.allocator)
	add_item_to_world({.Sword, 10, 10}, {500, 300})
	add_item_to_world({.Bomb, 1, 16}, {200, 50})
	add_item_to_world({.Apple, 5, 16}, {100, 50})

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
			move_successful := false
			switch current_ability {
			case .FIRE:
				if can_fire_dash {
					move_successful = true
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
					for &barrel, i in exploding_barrels {
						if check_collision_shapes(fire.circle, {}, barrel.shape, barrel.pos) {
							power_scale :=
								(FIRE_DASH_RADIUS - length(barrel.pos - fire.pos)) /
								FIRE_DASH_RADIUS
							power_scale = max(power_scale, 0.6) // TODO use a map function
							barrel.vel -= normalize(fire.pos - barrel.pos) * 400 * power_scale
							damage_exploding_barrel(i, 20)
						}
					}
					for &bomb in bombs {
						if check_collision_shapes(fire.circle, {}, bomb.shape, bomb.pos) {
							power_scale :=
								(FIRE_DASH_RADIUS - length(bomb.pos - fire.pos)) / FIRE_DASH_RADIUS
							power_scale = max(power_scale, 0.6) // TODO use a map function
							bomb.vel -= normalize(fire.pos - bomb.pos) * 400 * power_scale
						}
					}
				}
			case .WATER:
				move_successful = true
				surfing = true
				append(&timers, Timer{1, turn_off_surf, 0})
			// for &enemy in enemies {
			// 	if check_collision_shapes(fire, {}, enemy.shape, enemy.pos) {
			// 		enemy.vel -= normalize(get_directional_input()) * 200
			// 	}
			// }
			case .ELECTRIC:

			case .GROUND:

			case .AIR:
			}
			if move_successful {
				player.attacking = false
				player.charging_weapon = false
				player.holding_item = false
			}
		}

		if surfing {
			player.vel = normalize(get_directional_input()) * 200
			surf_poly.rotation = angle(get_directional_input())
			surf_poly.pos = player.pos
			for &enemy, i in enemies {
				if check_collision_shapes(surf_poly, {}, enemy.shape, enemy.pos) {
					enemy.vel = normalize(enemy.pos - (surf_poly.pos + {10, 0})) * 250
					damage_enemy(i, 40 * delta)
				}
			}
			for &barrel, i in exploding_barrels {
				if check_collision_shapes(surf_poly, {}, barrel.shape, barrel.pos) {
					barrel.vel = normalize(barrel.pos - (surf_poly.pos + {10, 0})) * 250
					damage_exploding_barrel(i, 40 * delta)
				}
			}
			for &bomb in bombs {
				if check_collision_shapes(surf_poly, {}, bomb.shape, bomb.pos) {
					bomb.vel = normalize(bomb.pos - (surf_poly.pos + {10, 0})) * 250
				}
			}
		}

		if editor_mode == .None {
			player_update_velocity(&player, delta)
			fmt.println("bef: ", player.vel)
			remaining_delta := delta
			for sweeps := 0; remaining_delta > 0 && sweeps < 10; sweeps += 1 {
				min_col_delta: f32 = -1
				min_normal: Vec2 = {}
				for wall in level.walls {
					col_delta, normal := sweep_collision_shapes(
						player.shape,
						player.pos,
						wall.shape,
						wall.pos,
						player.vel,
					)
					if col_delta >= 0 {
						if col_delta < min_col_delta || min_col_delta == -1 {
							min_col_delta = col_delta
							min_normal = -normal
						} else if col_delta == min_col_delta {
							min_normal -= normal
							min_normal /= 2
						}
					}
				}
				if min_col_delta < 0 || min_col_delta > remaining_delta {
					player.pos += player.vel * remaining_delta
					remaining_delta = 0
				} else {
					speed := length(player.vel)
					vel_dir := player.vel / speed
					// Separate speed and direction so we can substract 0.001 from speed and then apply vel_dir
					// Prevents player going through wall
					player.pos += max(speed * min_col_delta - 0.001, 0) * vel_dir
					remaining_delta -= min_col_delta
					player.vel = slide(player.vel, min_normal)
					he := player.pos.x >= 81.7
					fmt.println("aft: ", player.vel, he)
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
		// if false {
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
	}


	for &entity in exploding_barrels {
		generic_move(&entity, 1000, delta)
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
				for enemy, j in enemies {
					if check_collision_shapes(Circle{{}, 8}, bomb.pos, enemy.shape, enemy.pos) {
						damage_enemy(j, 6)
					}
				}
				// Bomb damaging exploding barrel
				for barrel, j in exploding_barrels {
					if check_collision_shapes(Circle{{}, 8}, bomb.pos, barrel.shape, barrel.pos) {
						damage_exploding_barrel(j, 100)
					}
				}
				unordered_remove(&bombs, i)
			}
		}
		// }

		for &weapon, i in projectile_weapons {
			zentity_move(&weapon, delta)
			if !weapon.just_hit {
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
						// TODO: Scale the damge done on durability (count) to the velocity of the impact
						// Higher velocity hit wall should take more durability
						weapon.data.count -= 5
						if weapon.data.count <= 0 {
							delete(weapon.shape.(Polygon).points)
							unordered_remove(&projectile_weapons, i)
						}
						weapon.just_hit = true
						break
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
					if !enemy.just_hit {
						enemies[j].just_hit = true
						damage_enemy(j, 10)
						weapon.data.count -= 1
						if weapon.data.count <= 0 {
							delete(weapon.shape.(Polygon).points)
							unordered_remove(&projectile_weapons, i)
						}
					}
				}
			}
			for barrel, j in exploding_barrels {
				_, normal, depth := resolve_collision_shapes(
					weapon.shape,
					weapon.pos,
					barrel.shape,
					barrel.pos,
				)
				// fmt.printfln("%v, %v, %v", collide, normal, depth)
				if depth > 0 {
					weapon.pos -= normal * depth
					weapon.vel = slide(weapon.vel, normal)
					// 10 is a arbitrary number. TODO: make this use a weapon specific damage value
					if !barrel.just_hit {
						exploding_barrels[j].just_hit = true
						damage_exploding_barrel(j, 10)
						weapon.data.count -= 1
						if weapon.data.count <= 0 {
							delete(weapon.shape.(Polygon).points)
							unordered_remove(&projectile_weapons, i)
						}
					}
				}
			}
			if weapon.z <= 0 {
				add_item_to_world(weapon.data, weapon.pos)
				delete(weapon.shape.(Polygon).points)
				unordered_remove(&projectile_weapons, i)
			}
		}

		// Raycast test
		// ray_min_t: [18]f32
		// for &min_t, i in ray_min_t {
		// 	dir := vector_from_angle(f32(i) * 360 / f32(len(ray_min_t)))
		// 	min_t = cast_ray_through_level(level.walls[:], player.pos, dir)
		// }


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
				add_item_to_world(item_data, player.pos)
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

		// Weapon animation
		if sword_animation.pos_rotation_vel == 0 {
			// Do nothing. when vel is 0 that means we are not animating
		} else {
			// Animate
			sword_animation.pos_cur_rotation += sword_animation.pos_rotation_vel * delta
			sword_animation.sprite_cur_rotation += sword_animation.sprite_rotation_vel * delta
		}
		// Stop Weapon animation
		if sword_animation.pos_rotation_vel < 0 &&
		   (sword_animation.pos_cur_rotation <= sword_animation.cpos_top_rotation ||
				   !player.attacking) {
			// Animating to top finished
			sword_animation.pos_cur_rotation = sword_animation.cpos_top_rotation
			sword_animation.sprite_cur_rotation = sword_animation.csprite_top_rotation
			sword_animation.pos_rotation_vel = 0
		} else if sword_animation.pos_rotation_vel > 0 &&
		   (sword_animation.pos_cur_rotation >= sword_animation.cpos_bot_rotation ||
				   !player.attacking) {
			// Animating to bottom finished
			sword_animation.pos_cur_rotation = sword_animation.cpos_bot_rotation
			sword_animation.sprite_cur_rotation = sword_animation.csprite_bot_rotation
			sword_animation.pos_rotation_vel = 0
		}

		if player.attacking {
			if attack_duration_timer <= 0 {
				player.attacking = false
			} else {
				attack_duration_timer -= delta
				for &enemy, i in enemies {
					if !enemy.just_hit &&
					   check_collision_shapes(enemy.shape, enemy.pos, attack_poly, player.pos) {
						enemy.vel += normalize(mouse_world_pos - player.pos) * attack_knockback
						enemy.just_hit = true
						damage_enemy(i, attack_damage)
						player.weapons[player.selected_weapon_idx].count -= 1
						if player.weapons[player.selected_weapon_idx].count <= 0 {
							player.weapons[player.selected_item_idx].id = .Empty
						}
					}
				}
				// Other sword interactions go here
				for &barrel, i in exploding_barrels {
					if !barrel.just_hit &&
					   check_collision_shapes(barrel.shape, barrel.pos, attack_poly, player.pos) {
						barrel.vel += normalize(mouse_world_pos - player.pos) * attack_knockback
						barrel.just_hit = true
						damage_exploding_barrel(i, attack_damage)
						player.weapons[player.selected_weapon_idx].count -= 1
						if player.weapons[player.selected_weapon_idx].count <= 0 {
							player.weapons[player.selected_item_idx].id = .Empty
						}
					}
				}
				for &bomb in bombs {
					if !bomb.just_hit &&
					   check_collision_shapes(bomb.shape, bomb.pos, attack_poly, player.pos) {
						bomb.vel += normalize(mouse_world_pos - player.pos) * attack_knockback
						bomb.just_hit = true
						player.weapons[player.selected_weapon_idx].count -= 1
						if player.weapons[player.selected_weapon_idx].count <= 0 {
							player.weapons[player.selected_item_idx].id = .Empty
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

			// Draw items with slight gray tint
			for item in items {
				tex_id := item_to_texture[item.data.id]
				tex := loaded_textures[tex_id]
				sprite: Sprite = {
					tex_id,
					{0, 0, f32(tex.width), f32(tex.height)},
					{1, 1},
					{f32(tex.width) / 2, f32(tex.height) / 2},
					0,
					rl.LIGHTGRAY, // Slight darker tint
				}


				draw_sprite(sprite, item.pos)
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

			for &barrel in exploding_barrels {
				draw_shape(barrel.shape, barrel.pos, rl.RED)
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
				if player.holding_item && player.items[player.selected_item_idx].id != .Empty {
					draw_item(player.items[player.selected_item_idx].id)
				}

				// Draw Weapon
				if !player.holding_item &&
				   player.weapons[player.selected_weapon_idx].id != .Empty {
					draw_weapon(player.weapons[player.selected_weapon_idx].id)
				}

				/* Item hold bar */
				if player.holding_item {
					bar_length: f32 = 2
					bar_height: f32 = 8
					bar_base_rec := get_centered_rect(
						{player.pos.x, player.pos.y},
						{bar_length, bar_height},
					)
					rl.DrawRectangleRec(bar_base_rec, rl.BLACK)
					bar_filled_rec := bar_base_rec

					bar_filled_rec.height *= get_item_hold_multiplier()
					bar_filled_rec.y = bar_base_rec.y + bar_base_rec.height - bar_filled_rec.height
					rl.DrawRectangleRec(bar_filled_rec, rl.GREEN)
				}
				/* End of Item hold bar */

				/* Weapon charge bar */
				if player.charging_weapon {
					bar_length: f32 = 2
					bar_height: f32 = 8
					bar_base_rec := get_centered_rect(
						{player.pos.x, player.pos.y},
						{bar_length, bar_height},
					)
					rl.DrawRectangleRec(bar_base_rec, rl.BLACK)
					bar_filled_rec := bar_base_rec

					bar_filled_rec.height *= get_weapon_charge_multiplier()
					bar_filled_rec.y = bar_base_rec.y + bar_base_rec.height - bar_filled_rec.height
					rl.DrawRectangleRec(bar_filled_rec, rl.GREEN)
				}
				/* End of Weapon charge bar */


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

				// if !player.holding_item &&
				//    player.weapons[player.selected_weapon_idx].id >= .Sword {
				// 	attack_hitbox_color := rl.Color{255, 255, 255, 120}
				// 	if player.attacking {
				// 		attack_hitbox_color = rl.Color{255, 0, 0, 120}
				// 	}
				// 	draw_shape(attack_poly, player.pos, attack_hitbox_color)
				// }

				// Player pickup range
				// draw_shape_lines(Circle{{}, player.pickup_range}, player.pos, rl.DARKBLUE)
				// Collision shape
				draw_shape(player.shape, player.pos, rl.RED)
			}

			#partial switch editor_mode {
			case .Level:
				draw_editor_world()
			case .NavMesh:
				draw_navmesh_editor_world(mouse_world_pos)
			}

			rl.EndMode2D()

			rl.DrawText(fmt.ctprintf("%v", player.pos), 30, 30, 20, rl.BLACK)
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

// Moves entity with current velocity and slows down with friction. no max speed
generic_move :: proc(e: ^MovingEntity, friction: f32, delta: f32) {
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
	e.pos += e.vel * delta
}

zentity_move :: proc(e: ^ZEntity, delta: f32) {
	friction :: 300
	gravity :: 50

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
		e.rot += e.rot_vel * delta
	}
	// Update collision shape and sprite to match new rotation
	#partial switch &s in e.shape {
	case Polygon:
		s.rotation = e.rot
	}
	e.sprite.rotation = e.rot
}

player_update_velocity :: proc(e: ^Player, delta: f32) {
	max_speed: f32 = PLAYER_BASE_MAX_SPEED
	// Slow down player
	if player.holding_item || player.charging_weapon || player.attacking {
		max_speed = PLAYER_BASE_MAX_SPEED / 2
	}
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
	if player.items[player.selected_item_idx].id == .Apple {
		// 1.0 are supposed to be same number. it requires 1.0 seconds to eat an apple
		return min(player.item_hold_time / 1.0, 1.0)
	}
	return(
		math.abs(
			math.mod(player.item_hold_time + ITEM_HOLD_DIVISOR, 2 * ITEM_HOLD_DIVISOR) -
			ITEM_HOLD_DIVISOR,
		) /
		ITEM_HOLD_DIVISOR \
	)
}

get_weapon_charge_multiplier :: proc() -> f32 {
	return(
		math.abs(
			math.mod(
				player.weapon_charge_time + WEAPON_CHARGE_DIVISOR,
				2 * WEAPON_CHARGE_DIVISOR,
			) -
			WEAPON_CHARGE_DIVISOR,
		) /
		WEAPON_CHARGE_DIVISOR \
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

damage_exploding_barrel :: proc(barrel_idx: int, amount: f32) {
	barrel := &exploding_barrels[barrel_idx]
	barrel.health -= amount
	if barrel.health <= 0 {
		// KABOOM!!!
		// Visual
		fire := Fire{Circle{barrel.pos, 24}, 2}
		append(&fires, fire)
		for enemy, i in enemies {
			if check_collision_shapes(enemy.shape, enemy.pos, fire.circle, barrel.pos) {
				// Knockback
				power_scale := (fire.radius - length(enemy.pos - fire.pos)) / fire.radius
				power_scale = max(power_scale, 0.6) // TODO use a map function
				enemies[i].vel -= normalize(fire.pos - enemy.pos) * 400 * power_scale
				// Damge
				damage_enemy(i, 20)
			}
		}
		unordered_remove(&exploding_barrels, barrel_idx)
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

		sprite.rotation += angle(to_mouse)
		// 180 is an arbitrary multiplier. TODO: make a constant variable for it
		base_vel := hold_multiplier * 180
		append(
			&bombs,
			Bomb {
				pos = player.pos + rotate_vector({-hold_multiplier * 5, 3}, angle(to_mouse)),
				shape = Rectangle{-1, 0, 3, 3},
				vel = to_mouse * base_vel,
				z = 0,
				vel_z = 20,
				sprite = sprite,
				time_left = 1,
			},
		)
		add_to_selected_item_count(-1)
	case .Apple:
		// Restore 5 health
		if player.item_hold_time >= 1 {
			player.health += 5
			add_to_selected_item_count(-1)
		}
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
		if can_attack {
			// Attack
			attack_poly.rotation = angle(mouse_world_pos - player.pos)
			attack_duration_timer = ATTACK_DURATION
			attack_interval_timer = ATTACK_INTERVAL
			player.attacking = true
			attack_damage = SWORD_DAMAGE
			attack_knockback = SWORD_KNOCKBACK
			can_attack = false
			reset_hit_states()

			// Animation
			if sword_animation.pos_cur_rotation == sword_animation.cpos_top_rotation { 	// Animate down
				sword_animation.pos_rotation_vel =
					(sword_animation.cpos_bot_rotation - sword_animation.cpos_top_rotation) /
					ATTACK_DURATION
				sword_animation.sprite_rotation_vel =
					(sword_animation.csprite_bot_rotation - sword_animation.csprite_top_rotation) /
					ATTACK_DURATION
			} else { 	// Animate up
				sword_animation.pos_rotation_vel =
					(sword_animation.cpos_top_rotation - sword_animation.cpos_bot_rotation) /
					ATTACK_DURATION
				sword_animation.sprite_rotation_vel =
					(sword_animation.csprite_top_rotation - sword_animation.csprite_bot_rotation) /
					ATTACK_DURATION
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
				pos = player.pos +
				rotate_vector(
					{-2, 5} + 10 * vector_from_angle(-50 - get_weapon_charge_multiplier() * 50),
					angle(to_mouse),
				),
				shape = rect_to_polygon(
					Rectangle {
						-f32(tex.width) / 2,
						-f32(tex.height) / 2,
						f32(tex.width),
						f32(tex.height),
					},
					allocator = context.allocator,
				),
				vel = to_mouse * get_weapon_charge_multiplier() * 300,
				z = 0,
				vel_z = 12,
				rot = -140 - get_weapon_charge_multiplier() * 110 + angle(to_mouse),
				rot_vel = 1200 * get_weapon_charge_multiplier(),
				sprite = sprite,
				data = weapon_data,
			},
		)
		reset_hit_states()
		player.weapons[player.selected_weapon_idx].id = .Empty
	}
	return 0
}

draw_item :: proc(item: ItemId) {
	to_mouse := normalize(mouse_world_pos - player.pos)
	tex_id := item_to_texture[item]
	tex := loaded_textures[tex_id]
	sprite: Sprite = {
		tex_id,
		{0, 0, f32(tex.width), f32(tex.height)},
		{1, 1},
		{f32(tex.width) / 2, f32(tex.height) / 2},
		0,
		rl.WHITE,
	}

	sprite_pos := player.pos + {-get_item_hold_multiplier() * 5, 3}
	sprite.scale = 1 + get_item_hold_multiplier() / 2


	sprite.rotation += angle(to_mouse)
	sprite_pos = rotate_about_origin(sprite_pos, player.pos, angle(to_mouse))
	draw_sprite(sprite, sprite_pos)
}

draw_weapon :: proc(weapon: ItemId) {
	to_mouse := normalize(mouse_world_pos - player.pos)
	tex_id := item_to_texture[weapon]
	tex := loaded_textures[tex_id]
	sprite: Sprite = {tex_id, {0, 0, f32(tex.width), f32(tex.height)}, {1, 1}, {}, 0, rl.WHITE}
	#partial switch weapon {
	case .Sword:
		sprite.tex_origin = {0, 1}
	}

	sprite_pos := player.pos
	if player.charging_weapon {
		sprite.rotation = -140 - get_weapon_charge_multiplier() * 110
		sprite_pos += {-2, 5} + 10 * vector_from_angle(-50 - get_weapon_charge_multiplier() * 50)
	} else {
		// Set rotation and position based on if sword is on top or not
		sprite.rotation = sword_animation.sprite_cur_rotation
		sprite_pos += {2, 0} + 4 * vector_from_angle(sword_animation.pos_cur_rotation)
	}

	// Rotate sprite and rotate its position to face mouse
	sprite.rotation += angle(to_mouse)
	sprite_pos = rotate_about_origin(sprite_pos, player.pos, angle(to_mouse))
	draw_sprite(sprite, sprite_pos)
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

reset_hit_states :: proc() {
	for &enemy in enemies {
		enemy.just_hit = false
	}
	for &barrel in exploding_barrels {
		barrel.just_hit = false
	}
	for &bomb in bombs {
		bomb.just_hit = false
	}
}

add_item_to_world :: proc(data: ItemData, pos: Vec2) {
	append(&items, Item{pos = pos, shape = Circle{{}, 4}, data = data})
}
