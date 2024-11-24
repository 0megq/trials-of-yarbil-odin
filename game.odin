package game

import "core:crypto"
import "core:encoding/uuid"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:slice"
import rl "vendor:raylib"

GAME_SIZE :: Vec2i{480, 270}
ASPECT_RATIO_X_Y: f32 : f32(GAME_SIZE.x) / f32(GAME_SIZE.y)
PLAYER_BASE_MAX_SPEED :: 80
PLAYER_BASE_ACCELERATION :: 1500
PLAYER_BASE_FRICTION :: 750
PLAYER_BASE_HARSH_FRICTION :: 2000
ENEMY_PATHFINDING_TIME :: 0.2
FIRE_DASH_RADIUS :: 32
FIRE_DASH_FIRE_DURATION :: 0.5
FIRE_DASH_COOLDOWN :: 2
FIRE_TILE_DAMAGE :: 1
ITEM_HOLD_DIVISOR :: 1 // Max time
WEAPON_CHARGE_DIVISOR :: 1 // Max time
PORTAL_RADIUS :: 16

// weapon/attack related constants
ATTACK_DURATION :: 0.15
ATTACK_INTERVAL :: 0.4
SWORD_DAMAGE :: 20
SWORD_KNOCKBACK :: 150
SWORD_HITBOX_OFFSET :: 4
STICK_DAMAGE :: 10
STICK_KNOCKBACK :: 70
STICK_HITBOX_OFFSET :: 2

EditorMode :: enum {
	None,
	Level,
	Entity,
	// NavMesh,
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
	use_portal:             Control,
}

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

controls: Controls = {
	fire                   = rl.MouseButton.LEFT,
	alt_fire               = rl.MouseButton.MIDDLE,
	use_item               = rl.MouseButton.RIGHT,
	switch_selected_weapon = rl.KeyboardKey.X,
	drop                   = rl.KeyboardKey.Q,
	pickup                 = rl.KeyboardKey.E,
	cancel                 = rl.KeyboardKey.LEFT_CONTROL,
	movement_ability       = rl.KeyboardKey.SPACE,
	use_portal             = rl.KeyboardKey.E,
}

SWORD_HITBOX_POINTS := []Vec2 {
	{SWORD_HITBOX_OFFSET, -12},
	{SWORD_HITBOX_OFFSET + 10, -5},
	{SWORD_HITBOX_OFFSET + 12, 0},
	{SWORD_HITBOX_OFFSET + 10, 5},
	{SWORD_HITBOX_OFFSET, 12},
}

STICK_HITBOX_POINTS := []Vec2 {
	{STICK_HITBOX_OFFSET, -10},
	{STICK_HITBOX_OFFSET + 8, -4},
	{STICK_HITBOX_OFFSET + 10, 0},
	{STICK_HITBOX_OFFSET + 8, 4},
	{STICK_HITBOX_OFFSET, 10},
}

ENEMY_ATTACK_HITBOX_POINTS := []Vec2{{10, -10}, {16, -8}, {20, 0}, {16, 8}, {10, 10}}

SWORD_ANIMATION_DEFAULT :: WeaponAnimation{-70, -160, 70, 160, 0, 0, -70, -160}
STICK_ANIMATION_DEFAULT :: WeaponAnimation{-70, -115, 70, 205, 0, 0, -70, -115}

PLAYER_SPRITE :: Sprite{.Player, {0, 0, 12, 16}, {1, 1}, {5.5, 7.5}, 0, rl.WHITE}
ENEMY_SPRITE :: Sprite{.Enemy, {0, 0, 16, 16}, {1, 1}, {7.5, 7.5}, 0, rl.WHITE}
BARREL_SPRITE :: Sprite{.ExplodingBarrel, {0, 0, 12, 12}, {1, 1}, {6, 6}, 0, rl.WHITE}

window_size := Vec2i{1440, 810}
window_over_game: f32
game_over_window: f32

game_data: GameData

// world data
player: Player
enemies: [dynamic]Enemy
items: [dynamic]Item
exploding_barrels: [dynamic]ExplodingBarrel
tilemap: Tilemap
// nav_mesh: NavMesh
nav_graph: NavGraph
walls: [dynamic]Wall

bombs: [dynamic]Bomb
projectile_weapons: [dynamic]ProjectileWeapon
arrows: [dynamic]Arrow
rocks: [dynamic]Rock
fires: [dynamic]Fire

player_at_portal: bool
display_win_screen: bool
play_again_button: Button = Button {
	rect          = {700, 300, 200, 24},
	text          = "Play Again",
	hover_color   = rl.DARKGRAY,
	normal_color  = rl.GRAY,
	pressed_color = Color{80, 80, 80, 255},
	status        = .Normal,
}
queue_play_again: bool

// misc
camera: rl.Camera2D

delta: f32
mouse_pos: Vec2
mouse_delta: Vec2
mouse_world_pos: Vec2
mouse_world_delta: Vec2


main :: proc() {
	context.random_generator = crypto.random_generator()

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

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.SetWindowMaxSize(1920, 1057)
	rl.InitWindow(window_size.x, window_size.y, "Trials of Yarbil")
	window_over_game = f32(window_size.x) / f32(GAME_SIZE.x)
	game_over_window = f32(GAME_SIZE.x) / f32(window_size.x)

	load_textures()
	load_game_data()
	load_level()

	init_editor_state(&editor_state)


	surf_poly := Polygon{player.pos, {{10, -30}, {20, -20}, {30, 0}, {20, 20}, {10, 30}}, 0}

	fires = make([dynamic]Fire, context.allocator)

	bombs = make([dynamic]Bomb, context.allocator)


	projectile_weapons = make([dynamic]ProjectileWeapon, context.allocator)
	arrows = make([dynamic]Arrow, context.allocator)
	rocks = make([dynamic]Rock, context.allocator)

	timers := make([dynamic]Timer, context.allocator)

	append(&timers, Timer{0.5, toggle_text_cursor, 0.5})

	// Generate new ids for the walls. Potential source of bugs
	// for &wall in level.walls {
	// 	wall.id = uuid.generate_v4()
	// }

	// punch_rect: Rectangle = {
	// 	8,
	// 	PLAYER_PUNCH_SIZE.y * -0.5,
	// 	PLAYER_PUNCH_SIZE.x,
	// 	PLAYER_PUNCH_SIZE.y,
	// }
	// punch_points := rect_to_points(punch_rect)

	// attack_poly.points = punch_points[:]

	camera = rl.Camera2D {
		target = player.pos,
		zoom   = window_over_game,
		offset = ({f32(GAME_SIZE.x), f32(GAME_SIZE.y)} / 2),
	}

	for !rl.WindowShouldClose() {
		if player.queue_free {
			on_player_death()
			player.queue_free = false
		}
		if queue_play_again {
			play_again_button.status = .Normal
			display_win_screen = false
			reload_game_data()
			reload_level()
			queue_play_again = false
		}
		#reverse for barrel, i in exploding_barrels { 	// This needs to be in reverse since we are removing
			if barrel.queue_free {
				unordered_remove(&exploding_barrels, i)
			}
		}

		// window sizing
		if rl.IsWindowResized() {
			previous_window_size := window_size
			window_size = {rl.GetScreenWidth(), rl.GetScreenHeight()}
			size_delta := window_size - previous_window_size
			// If one is negative pick the lower one
			if size_delta.x < 0 || size_delta.y < 0 {
				if size_delta.x < size_delta.y {
					window_size.y = i32(f32(window_size.x) / ASPECT_RATIO_X_Y)
				} else {
					window_size.x = i32(f32(window_size.y) * ASPECT_RATIO_X_Y)
				}
			} else {
				// If not negative pick the larger one
				if size_delta.x < size_delta.y {
					window_size.y = i32(f32(window_size.x) / ASPECT_RATIO_X_Y)
				} else {
					window_size.x = i32(f32(window_size.y) * ASPECT_RATIO_X_Y)
				}
			}
			if window_size.y == 1057 {
				window_size.x = 1920
			}
			rl.SetWindowSize(window_size.x, window_size.y)

			window_over_game = f32(window_size.x) / f32(GAME_SIZE.x)
			game_over_window = f32(GAME_SIZE.x) / f32(window_size.x)
		}

		// Camera Zooming
		{
			if editor_state.mode == .None {
				camera.zoom = window_over_game
				camera.offset = {f32(window_size.x), f32(window_size.y)} / 2
				camera.target = player.pos
				// camera.target = fit_camera_target_to_level_bounds(player.pos)
			} else {
				if rl.IsMouseButtonDown(.MIDDLE) {
					camera.target -= mouse_world_delta
				}
				camera.zoom += rl.GetMouseWheelMove() * 0.2 * camera.zoom
				camera.zoom = max(0.1, camera.zoom)
				if math.abs(camera.zoom - window_over_game) < 0.2 {
					camera.zoom = window_over_game
				}
			}
		}

		delta = rl.GetFrameTime()
		// Mouse movement
		mouse_pos = rl.GetMousePosition()
		mouse_delta = rl.GetMouseDelta()
		mouse_world_pos = screen_to_world(mouse_pos)
		mouse_world_delta = mouse_delta / camera.zoom

		#reverse for &timer, i in timers {
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


		when ODIN_DEBUG {
			if rl.IsKeyDown(.LEFT_CONTROL) {
				if rl.IsKeyPressed(.Q) {
					if rl.IsKeyDown(.LEFT_SHIFT) {
						editor_state.mode = EditorMode(
							(int(editor_state.mode) - 1) %% len(EditorMode),
						)
					} else {
						editor_state.mode = EditorMode(
							(int(editor_state.mode) + 1) %% len(EditorMode),
						)
					}
					if editor_state.mode == .None {
						save_level()
						reload_game_data()
						reload_level()
					}
				}

				// save level to file
				if editor_state.mode != .None {
					if rl.IsKeyPressed(.S) {
						save_level()
					} else if rl.IsKeyPressed(.L) {
						reload_level()
					} else if rl.IsKeyPressed(.G) {
						editor_state.show_tile_grid = !editor_state.show_tile_grid
					}
				}
			}
		}

		switch editor_state.mode {
		case .Level:
			update_geometry_editor(&editor_state)
		// case .NavMesh:
		// 	update_navmesh_editor(&editor_state)
		case .Entity:
			update_entity_editor(&editor_state)
		case .None:
			update_tilemap()


			// Check player collision with portal
			player_at_portal = check_collision_shapes(
				Circle{{}, PORTAL_RADIUS},
				level.portal_pos,
				player.shape,
				player.pos,
			)
			if is_level_finished() && is_control_pressed(controls.use_portal) && player_at_portal {
				if game_data.cur_level_idx == 1 { 	// 1 is the last level
					display_win_screen = true
				} else {
					game_data.cur_level_idx += 1
					reload_level()
				}
			}

			if display_win_screen {
				update_button(&play_again_button, mouse_pos)
				if play_again_button.status == .Released {
					queue_play_again = true
				}
			}

			if !player.can_fire_dash {
				player.fire_dash_timer -= delta
				if player.fire_dash_timer <= 0 {
					player.can_fire_dash = true
				}
			}

			if is_control_pressed(controls.movement_ability) {
				move_successful := false
				switch player.cur_ability {
				case .FIRE:
					if player.can_fire_dash {
						move_successful = true
						player.can_fire_dash = false
						player.fire_dash_timer = FIRE_DASH_COOLDOWN

						player.vel = normalize(get_directional_input()) * 400
						fire := Fire{{player.pos, FIRE_DASH_RADIUS}, FIRE_DASH_FIRE_DURATION}
						append(&fires, fire)
						attack := Attack {
							pos       = player.pos,
							shape     = Circle{{}, FIRE_DASH_RADIUS},
							damage    = 20,
							knockback = 400,
							targets   = {.Bomb, .Enemy, .ExplodingBarrel, .Tile},
							data      = ExplosionAttackData{true},
						}
						perform_attack(&attack)
					}
				case .WATER:
					move_successful = true
					player.surfing = true
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
					stop_player_attack()
					player.charging_weapon = false
					player.holding_item = false
				}
			}

			if player.surfing {
				player.vel = normalize(get_directional_input()) * 200
				surf_poly.rotation = angle(get_directional_input())
				surf_poly.pos = player.pos
				attack := Attack {
					targets   = {.Enemy, .ExplodingBarrel, .Bomb},
					damage    = 40 * delta,
					knockback = 210,
					shape     = Polygon{{}, surf_poly.points, surf_poly.rotation},
					pos       = surf_poly.pos,
					data      = SurfAttackData{},
				}
				perform_attack(&attack)
			}

			player_move(&player, delta)
			for wall in walls {
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
			for &barrel in exploding_barrels {
				if barrel.queue_free {
					continue
				}
				_, normal, depth := resolve_collision_shapes(
					player.shape,
					player.pos,
					barrel.shape,
					barrel.pos,
				)
				// fmt.printfln("%v, %v, %v", collide, normal, depth)
				if depth > 0 {
					// player.pos -= normal * depth
					barrel_vel_along_normal := proj(barrel.vel, normal)
					player_vel_along_normal := proj(player.vel, normal)
					barrel.vel -= barrel_vel_along_normal
					player.vel -= player_vel_along_normal
					barrel.vel += (barrel_vel_along_normal + player_vel_along_normal) / 2
					player.vel += (barrel_vel_along_normal + player_vel_along_normal) / 2
					barrel.pos += normal * depth
				}
			}


			#reverse for &fire, i in fires {
				fire.time_left -= delta
				if fire.time_left <= 0 {
					unordered_remove(&fires, i)
				}
			}

			// Move enemies and track player if in range
			// if false {
			#reverse for &enemy in enemies {

				// Update detection points
				for &p, i in enemy.detection_points {
					dir := vector_from_angle(f32(i) * 360 / f32(len(enemy.detection_points)))
					t := cast_ray_through_level(walls[:], enemy.pos, dir)
					if t < enemy.detection_range {
						p = enemy.pos + t * dir
					} else {
						p = enemy.pos + enemy.detection_range * dir
					}
				}

				// This collision detection does NOT use the player's shape, but a circle to approximate it
				if enemy.player_in_range &&
				   !check_collsion_circular_concave_circle(
						   enemy.detection_points[:],
						   enemy.pos,
						   {player.pos, 8},
					   ) {
					enemy.player_in_range = false
					// Calculate enemies path to last seen player location
					enemy.current_path = find_path_tiles(
						enemy.pos,
						player.pos,
						nav_graph,
						tilemap,
						wall_tilemap,
					)
				} else if !enemy.player_in_range &&
				   check_collsion_circular_concave_circle(
					   enemy.detection_points[:],
					   enemy.pos,
					   {player.pos, 8},
				   ) {
					enemy.player_in_range = true
					if enemy.current_path != nil {
						delete(enemy.current_path)
					}
					enemy.current_path = find_path_tiles(
						enemy.pos,
						player.pos,
						nav_graph,
						tilemap,
						wall_tilemap,
					)
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
						enemy.current_path = find_path_tiles(
							enemy.pos,
							player.pos,
							nav_graph,
							tilemap,
							wall_tilemap,
						)
						enemy.current_path_point = 1
					}
					if enemy.current_path_point >= len(enemy.current_path) {
						delete(enemy.current_path)
						enemy.current_path = find_path_tiles(
							enemy.pos,
							player.pos,
							nav_graph,
							tilemap,
							wall_tilemap,
						)
						enemy.current_path_point = 1
					}
				}
				// Follow path if there exists one and the enemy is not already at the end of it
				target := enemy.pos
				if enemy.current_path != nil &&
				   enemy.current_path_point < len(enemy.current_path) {
					target = enemy.current_path[enemy.current_path_point]
					if distance_squared(enemy.pos, enemy.current_path[enemy.current_path_point]) <
					   16 { 	// Enemy is at the point (tolerance of 16)
						enemy.current_path_point += 1
					}
				}

				// if player in flee range
				#partial switch data in enemy.data {
				case RangedEnemyData:
					if enemy.player_in_range &&
					   check_collision_shapes(
						   Circle{{}, data.flee_range},
						   enemy.pos,
						   player.shape,
						   player.pos,
					   ) {
						// Set target to opposite of the player. Gets a vector starting at the enemy pos pointing away from the player
						target = enemy.pos + (enemy.pos - player.pos)
					}
				}
				enemy_move(&enemy, delta, target)

				for wall in walls {
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
						switch data in enemy.data {
						case MeleeEnemyData:
							damage :: 5
							knockback :: 100
							perform_attack(
								&Attack {
									targets         = {.Bomb, .ExplodingBarrel, .Player},
									damage          = damage,
									knockback       = knockback,
									data            = SwordAttackData{},
									pos             = enemy.pos,
									shape           = data.attack_poly,
									exclude_targets = make(
										[dynamic]uuid.Identifier, // We don't want to reuse this
										context.temp_allocator,
									),
									direction       = vector_from_angle(data.attack_poly.rotation),
								},
							)
						case RangedEnemyData:
							// launch arrow
							to_player := normalize(player.pos - enemy.pos)
							tex := loaded_textures[.Arrow]
							arrow_sprite := Sprite {
								.Arrow,
								{0, 0, f32(tex.width), f32(tex.height)},
								{1, 1},
								{f32(tex.width) / 2, f32(tex.height) / 2},
								0,
								rl.WHITE,
							}
							append(
								&arrows,
								Arrow {
									entity = new_entity(enemy.pos),
									shape = Circle{{}, 4},
									vel = to_player * 300,
									z = 0,
									vel_z = 8,
									rot = angle(to_player),
									sprite = arrow_sprite,
									attack = Attack {
										targets = {.Player, .Wall, .ExplodingBarrel, .Enemy},
									},
									source = enemy.id,
								},
							)
						}
					}
				}

				// If player in attack range
				if !enemy.flinching &&
				   !enemy.charging &&
				   enemy.player_in_range &&
				   check_collision_shapes(
					   Circle{{}, enemy.attack_charge_range},
					   enemy.pos,
					   player.shape,
					   player.pos,
				   ) {
					switch &data in enemy.data {
					case MeleeEnemyData:
						data.attack_poly.rotation = angle(player.pos - enemy.pos)
						enemy.charging = true
						enemy.current_charge_time = enemy.start_charge_time
					case RangedEnemyData:
						if !check_collision_shapes(
							Circle{{}, data.flee_range},
							enemy.pos,
							player.shape,
							player.pos,
						) {
							enemy.charging = true
							enemy.current_charge_time = enemy.start_charge_time
						}
					}
				}
			}
			// }


			#reverse for &entity in exploding_barrels {
				generic_move(&entity, 1000, delta)
				for wall in walls {
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
					_, pnormal, pdepth := resolve_collision_shapes(
						entity.shape,
						entity.pos,
						player.shape,
						player.pos,
					)
					if pdepth > 0 {
						player.pos += pnormal * pdepth
					}
				}
			}

			// for &entity in z_entities {
			// 	zentity_move(&entity, delta)
			// 	for wall in level.walls {
			// 		_, normal, depth := resolve_collision_shapes(
			// 			entity.shape,
			// 			entity.pos,
			// 			wall.shape,
			// 			wall.pos,
			// 		)
			// 		// fmt.printfln("%v, %v, %v", collide, normal, depth)
			// 		if depth > 0 {
			// 			entity.pos -= normal * depth
			// 			entity.vel = slide(entity.vel, normal)
			// 		}
			// 	}
			// }

			#reverse for &bomb, i in bombs {
				zentity_move(&bomb, 300, 50, delta)
				for wall in walls {
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
				for barrel in exploding_barrels {
					if barrel.queue_free {
						continue
					}
					_, normal, depth := resolve_collision_shapes(
						bomb.shape,
						bomb.pos,
						barrel.shape,
						barrel.pos,
					)
					// fmt.printfln("%v, %v, %v", collide, normal, depth)
					if depth > 0 {
						bomb.pos -= normal * depth
						bomb.vel = slide(bomb.vel, normal)
					}
				}
				if bomb.z <= 0 { 	// if on ground, then start ticking
					bomb.time_left -= delta
					if bomb.time_left <= 0 {
						bomb_explosion(bomb.pos, 8)
						perform_attack(
							&{
								targets = {.Player, .Enemy, .ExplodingBarrel, .Tile},
								damage = 10,
								pos = bomb.pos,
								shape = Circle{{}, 8},
								data = ExplosionAttackData{true},
							},
						)
						unordered_remove(&bombs, i)
					}
				}
			}

			#reverse for &weapon, i in projectile_weapons {
				zentity_move(&weapon, 300, 30, delta)

				speed_damage_ratio :: 15
				speed_durablity_ratio :: 60

				weapon.attack.pos = weapon.pos
				weapon.attack.shape = weapon.shape
				weapon.attack.data = ProjectileAttackData {
					i,
					speed_damage_ratio,
					speed_durablity_ratio,
				}

				if perform_attack(&weapon.attack) == -1 {
					// if the weapon was deleted while performing its attack
					continue
				}

				if weapon.z <= 0 {
					add_item_to_world(weapon.data, weapon.pos)
					delete_projectile_weapon(i)
				}
			}

			#reverse for &arrow, i in arrows {
				zentity_move(&arrow, 300, 30, delta)

				speed_damage_ratio :: 15

				arrow.attack.pos = arrow.pos
				arrow.attack.shape = arrow.shape
				arrow.attack.data = ArrowAttackData{i, speed_damage_ratio}

				// if the arrow hit something while performing its attack, then delete it
				if perform_attack(&arrow.attack) == -1 {
					delete_arrow(i)
					continue
				}

				if arrow.z <= 0 {
					delete_arrow(i)
				}
			}

			#reverse for &rock, i in rocks {
				zentity_move(&rock, 300, 40, delta)

				speed_damage_ratio :: 15

				rock.attack.pos = rock.pos
				rock.attack.shape = rock.shape
				rock.attack.data = RockAttackData{i, speed_damage_ratio}

				// if the rock hits something while performing its attack, then delete it and create a rock item
				if perform_attack(&rock.attack) == -1 {
					delete_rock(i)
					add_item_to_world({id = .Rock, count = 1}, rock.pos)
					continue
				}

				// if the rock touches ground, then delete it and create a rock item
				if rock.z <= 0 {
					add_item_to_world({id = .Rock, count = 1}, rock.pos)
					delete_rock(i)
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
				stop_player_attack() // Cancel attack
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
				stop_player_attack() // Cancel attack
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
				stop_player_attack() // Cancel attack
				player.weapon_switched = true
				// fmt.println("switched to weapon", player.selected_weapon_idx)
			}

			// Weapon animation
			if player.cur_weapon_anim.pos_rotation_vel == 0 {
				// Do nothing. when vel is 0 that means we are not animating
			} else {
				// Animate
				player.cur_weapon_anim.pos_cur_rotation +=
					player.cur_weapon_anim.pos_rotation_vel * delta
				player.cur_weapon_anim.sprite_cur_rotation +=
					player.cur_weapon_anim.sprite_rotation_vel * delta
			}
			// Stop Weapon animation
			if player.cur_weapon_anim.pos_rotation_vel < 0 &&
			   (player.cur_weapon_anim.pos_cur_rotation <=
						   player.cur_weapon_anim.cpos_top_rotation ||
					   !player.attacking) {
				// Animating to top finished
				player.cur_weapon_anim.pos_cur_rotation = player.cur_weapon_anim.cpos_top_rotation
				player.cur_weapon_anim.sprite_cur_rotation =
					player.cur_weapon_anim.csprite_top_rotation
				player.cur_weapon_anim.pos_rotation_vel = 0
			} else if player.cur_weapon_anim.pos_rotation_vel > 0 &&
			   (player.cur_weapon_anim.pos_cur_rotation >=
						   player.cur_weapon_anim.cpos_bot_rotation ||
					   !player.attacking) {
				// Animating to bottom finished
				player.cur_weapon_anim.pos_cur_rotation = player.cur_weapon_anim.cpos_bot_rotation
				player.cur_weapon_anim.sprite_cur_rotation =
					player.cur_weapon_anim.csprite_bot_rotation
				player.cur_weapon_anim.pos_rotation_vel = 0
			}

			if player.attacking {
				if player.attack_dur_timer <= 0 {
					stop_player_attack()
				} else {
					player.attack_dur_timer -= delta

					targets_hit := perform_attack(&player.cur_attack)
					player.weapons[player.selected_weapon_idx].count -= targets_hit
					// Put this line inside if player.attack_dur_timer <= 0 if we want the animation to finish before deleting the item
					if player.weapons[player.selected_weapon_idx].count <= 0 {
						player.weapons[player.selected_weapon_idx].id = .Empty
					}
				}
			} else if !player.can_attack { 	// If right after attack finished then countdown attack interval timer until done
				if player.attack_interval_timer <= 0 {
					player.can_attack = true
				}
				player.attack_interval_timer -= delta
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
		}

		// Drawing
		{
			rl.BeginDrawing()
			rl.ClearBackground(rl.DARKGRAY)


			rl.BeginMode2D(camera)


			if editor_state.mode != .None {
				draw_level(editor_state.show_tile_grid)
			}

			switch editor_state.mode {
			case .Level:
				draw_geometry_editor_world(editor_state)
			// case .NavMesh:
			// 	draw_navmesh_editor_world(editor_state)
			case .Entity:
				draw_entity_editor_world(editor_state)
			case .None:
				draw_tilemap(tilemap)
				// draw_navmesh_editor_world(editor_state)
				if player.surfing {
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

					if check_collision_shapes(
						Circle{{}, player.pickup_range},
						player.pos,
						item.shape,
						item.pos,
					) {
						prompt: cstring = "Press E"
						size := rl.MeasureTextEx(rl.GetFontDefault(), prompt, 4, 1)
						rl.DrawTextEx(
							rl.GetFontDefault(),
							prompt,
							item.pos - {size.x / 2, size.y + 2},
							4,
							1,
							rl.WHITE,
						)
					}
				}

				for wall in walls {
					draw_shape(wall.shape, wall.pos, rl.GRAY)
				}

				// Draw portal
				portal_color := rl.BLUE if is_level_finished() else Color{50, 50, 50, 255}
				rl.DrawCircleV(level.portal_pos, PORTAL_RADIUS, portal_color)
				// Draw arrow to portal if level finished and player is at least 64 units away
				if is_level_finished() && !player_at_portal {
					angle_to_portal := angle(level.portal_pos - player.pos)
					arrow_polygon := Polygon {
						player.pos,
						{{14, -3}, {24, 0}, {14, 3}},
						angle_to_portal,
					}
					draw_polygon(arrow_polygon, rl.BLUE)
				}
				if player_at_portal {
					prompt: cstring
					prompt = "Press E"
					if !is_level_finished() {
						prompt = "Kill All Enemies"
					}
					size := rl.MeasureTextEx(rl.GetFontDefault(), prompt, 6, 1)
					rl.DrawTextEx(
						rl.GetFontDefault(),
						prompt,
						level.portal_pos - {size.x / 2, size.y + 1},
						6,
						1,
						rl.WHITE,
					)
				}


				for enemy in enemies {
					// draw_shape(enemy.shape, enemy.pos, rl.GREEN)
					draw_sprite(ENEMY_SPRITE, enemy.pos)
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

					// Draw ID
					// rl.DrawTextEx(
					// 	rl.GetFontDefault(),
					// 	fmt.ctprintf(uuid.to_string(enemy.id, context.temp_allocator)),
					// 	enemy.pos + {0, -10},
					// 	8,
					// 	2,
					// 	rl.YELLOW,
					// )

					attack_area_color := rl.Color{255, 255, 255, 120}
					if enemy.just_attacked {
						attack_area_color = rl.Color{255, 0, 0, 120}
					}
					if enemy.charging || enemy.just_attacked {
						bar_length: f32 = 3
						bar_height: f32 = 10
						bar_base_rec := get_centered_rect(
							{enemy.pos.x, enemy.pos.y},
							{bar_length, bar_height},
						)
						rl.DrawRectangleRec(bar_base_rec, rl.BLACK)
						bar_filled_rec := bar_base_rec
						bar_filled_rec.height *=
							enemy.current_charge_time / enemy.start_charge_time
						rl.DrawRectangleRec(bar_filled_rec, rl.DARKGREEN)

						switch data in enemy.data {
						case MeleeEnemyData:
							draw_shape(data.attack_poly, enemy.pos, attack_area_color)
						case RangedEnemyData:

						}
					}

					// Draw detection area
					when ODIN_DEBUG {
						rl.DrawCircleLinesV(enemy.pos, enemy.detection_range, rl.YELLOW)
						for p, i in enemy.detection_points {
							rl.DrawLineV(
								p,
								enemy.detection_points[(i + 1) % len(enemy.detection_points)],
								rl.YELLOW,
							)
						}
					}

					// if enemy.current_path != nil {
					// 	for point in enemy.current_path {
					// 		rl.DrawCircleV(point, 2, rl.RED)
					// 	}
					// }
				}

				for barrel in exploding_barrels {
					if barrel.queue_free {
						continue
					}
					draw_sprite(BARREL_SPRITE, barrel.pos)
				}

				// Draw Z Entities
				// for &entity in z_entities {
				// 	entity.sprite.scale = entity.z + 1
				// 	draw_sprite(entity.sprite, entity.pos)
				// }

				for &entity in bombs {
					entity.sprite.scale = entity.z + 1
					draw_sprite(entity.sprite, entity.pos)
				}

				for &entity in projectile_weapons {
					entity.sprite.scale = entity.z + 1
					draw_sprite(entity.sprite, entity.pos)
				}

				for &entity in arrows {
					entity.sprite.scale = entity.z + 1
					draw_sprite(entity.sprite, entity.pos)
				}

				for &entity in rocks {
					entity.sprite.scale = entity.z + 1
					draw_sprite(entity.sprite, entity.pos)
				}

				// Draw Player
				{
					// Player Sprite
					draw_sprite(PLAYER_SPRITE, player.pos)

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
						bar_filled_rec.y =
							bar_base_rec.y + bar_base_rec.height - bar_filled_rec.height
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
						bar_filled_rec.y =
							bar_base_rec.y + bar_base_rec.height - bar_filled_rec.height
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

					when ODIN_DEBUG {
						if !player.holding_item &&
						   player.weapons[player.selected_weapon_idx].id >= .Sword {
							attack_hitbox_color := rl.Color{255, 255, 255, 120}
							if player.attacking {
								attack_hitbox_color = rl.Color{255, 0, 0, 120}
							}
							draw_shape(player.attack_poly, player.pos, attack_hitbox_color)
						}
					}

					// Player pickup range
					// draw_shape_lines(Circle{{}, player.pickup_range}, player.pos, rl.DARKBLUE)
					// Collision shape
					// draw_shape(player.shape, player.pos, rl.RED)
				}
			}

			rl.EndMode2D()

			if camera.zoom != window_over_game {
				rl.DrawText(fmt.ctprintf("Zoom: x%v", camera.zoom), 24, 700, 16, rl.BLACK)
			}

			if editor_state.mode != .None {
				// Display mouse coordinates
				rl.DrawText(fmt.ctprintf("%v", mouse_world_pos), 20, 20, 16, rl.WHITE)
				if editor_state.show_tile_grid {
					rl.DrawText(
						fmt.ctprintf(
							"%v",
							Vec2i{i32(mouse_world_pos.x), i32(mouse_world_pos.y)} / 8,
						),
						20,
						40,
						16,
						rl.WHITE,
					)
				}
			}

			switch editor_state.mode {
			case .Level:
				draw_geometry_editor_ui(editor_state)
				rl.DrawText("Level Editor", 1300, 32, 16, rl.BLACK)
			// case .NavMesh:
			// 	draw_navmesh_editor_ui(editor_state)
			// 	rl.DrawText("NavMesh Editor", 1300, 32, 16, rl.BLACK)
			case .Entity:
				draw_entity_editor_ui(editor_state)
				rl.DrawText("Entity Editor", 1300, 32, 16, rl.BLACK)
			case .None:
				draw_hud()
				when ODIN_DEBUG { 	// Draw player coordinates
					rl.DrawText(fmt.ctprintf("%v", player.pos), 1200, 16, 20, rl.BLACK)
				}


				if is_level_finished() {
					message: cstring = "All enemies defeated. Head to the portal."
					size := rl.MeasureTextEx(rl.GetFontDefault(), message, 24, 1)
					rl.DrawTextEx(
						rl.GetFontDefault(),
						message,
						{f32(window_size.x) / 2, f32(window_size.y)} - {size.x / 2, size.y + 8},
						24,
						1,
						rl.DARKGREEN,
					)
				}
			}

			if display_win_screen {
				// draw background
				rl.DrawRectangle(0, 0, window_size.x, window_size.y, {0, 0, 0, 100})
				// draw text
				rl.DrawText("Thanks for playing!", 700, 200, 24, rl.BLACK)
				// draw button,
				draw_button(play_again_button)
			}

			// rl.DrawText(fmt.ctprintf("FPS: %v", rl.GetFPS()), 600, 20, 16, rl.BLACK)

			rl.EndDrawing()
		}
		free_all(context.temp_allocator)
	}

	save_level()
	unload_level()

	// save_game_data() Not saving game data automatically now
	unload_game_data()

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

zentity_move :: proc(e: ^ZEntity, friction: f32, gravity: f32, delta: f32) {
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

		e.rot += e.rot_vel * delta
		e.pos += e.vel * delta
	}
	// Update collision shape and sprite to match new rotation
	#partial switch &s in e.shape {
	case Polygon:
		s.rotation = e.rot
	}
	e.sprite.rotation = e.rot
}

player_move :: proc(e: ^Player, delta: f32) {
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

	e.pos += e.vel * delta

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
	#partial switch data in e.data {
	case RangedEnemyData:
		max_speed = 70.0
	}
	acceleration: f32 = 400.0
	friction: f32 = 240.0
	harsh_friction: f32 = 500.0

	desired_vel: Vec2
	steering: Vec2
	if !e.charging && !e.flinching && target != e.pos {
		desired_vel = normalize(target - e.pos) * max_speed
		steering = desired_vel - e.vel
	}

	acceleration_v := normalize(steering) * acceleration * delta

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
	// 	"id: %v, steering (mag): %v, steering: %v, desired vel: %v, path: %v, path_point: %v, target: %v",
	// 	uuid.to_string(e.id, context.temp_allocator),
	// 	length(steering),
	// 	steering,
	// 	desired_vel,
	// 	e.current_path,
	// 	e.current_path_point,
	// 	target,
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
		f32(sprite.tex_region.width) * math.abs(sprite.scale.x), // scale the sprite. a negative would mess this up
		f32(sprite.tex_region.height) * math.abs(sprite.scale.y),
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

damage_enemy :: proc(enemy_idx: int, amount: f32, should_flinch := true) {
	enemy := &enemies[enemy_idx]
	if should_flinch {
		enemy.charging = false
		enemy.flinching = true
		enemy.current_flinch_time = enemy.start_flinch_time
	}
	enemy.health -= amount
	if enemy.health <= 0 {
		unordered_remove(&enemies, enemy_idx)
	}
}

damage_exploding_barrel :: proc(barrel_idx: int, amount: f32) {
	barrel := &exploding_barrels[barrel_idx]
	if barrel.queue_free {
		return
	}
	barrel.health -= amount
	if barrel.health <= 0 {
		// KABOOM!!!
		// Visual
		fire := Fire{Circle{barrel.pos, 60}, 2}
		barrel.queue_free = true

		append(&fires, fire)
		// Damage
		perform_attack(
			&{
				targets = {.Player, .Enemy, .ExplodingBarrel, .Bomb, .Tile},
				damage = 40,
				knockback = 400,
				pos = fire.pos,
				shape = Circle{{}, fire.radius},
				data = ExplosionAttackData{false},
			},
		)
	}
}

delete_projectile_weapon :: proc(idx: int) {
	delete(projectile_weapons[idx].attack.exclude_targets)
	unordered_remove(&projectile_weapons, idx)
}

delete_arrow :: proc(idx: int) {
	unordered_remove(&arrows, idx)
}

delete_rock :: proc(idx: int) {
	unordered_remove(&rocks, idx)
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
	player.surfing = false
}

world_to_screen :: proc(point: Vec2) -> Vec2 {
	return (point - camera.target) * camera.zoom + camera.offset
}

screen_to_world :: proc(point: Vec2) -> Vec2 {
	return (point - camera.offset) / camera.zoom + camera.target
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
				entity = new_entity(
					player.pos + rotate_vector({-hold_multiplier * 5, 3}, angle(to_mouse)),
				),
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
		if player.item_hold_time >= 1 && player.health < player.max_health {
			heal_player(5)
			add_to_selected_item_count(-1)
		}
	case .Rock:
		tex := loaded_textures[.Rock]
		sprite := Sprite {
			.Rock,
			{0, 0, f32(tex.width), f32(tex.height)},
			{1, 1},
			{f32(tex.width) / 2, f32(tex.height) / 2},
			0,
			rl.WHITE,
		}

		sprite.rotation += angle(to_mouse)
		// 300 is an arbitrary multiplier. TODO: make a constant variable for it
		base_vel := hold_multiplier * 300
		append(
			&rocks,
			Rock {
				entity = new_entity(
					player.pos + rotate_vector({-hold_multiplier * 5, 3}, angle(to_mouse)),
				),
				shape = Circle{{}, 3},
				vel = to_mouse * base_vel,
				z = 0,
				vel_z = 10,
				rot = angle(to_mouse),
				sprite = sprite,
				attack = Attack{targets = {.Wall, .ExplodingBarrel, .Enemy}},
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

stop_player_attack :: proc() {
	if player.attacking {
		player.attacking = false
		delete(player.cur_attack.exclude_targets)
	}
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
		if player.can_attack {
			// Attack
			player.attack_poly.rotation = angle(mouse_world_pos - player.pos)
			player.attack_dur_timer = ATTACK_DURATION
			player.attack_interval_timer = ATTACK_INTERVAL
			player.attacking = true
			player.cur_attack = Attack {
				pos             = player.pos,
				shape           = player.attack_poly,
				damage          = SWORD_DAMAGE,
				knockback       = SWORD_KNOCKBACK,
				direction       = normalize(mouse_world_pos - player.pos),
				data            = SwordAttackData{},
				targets         = {.Enemy, .Bomb, .ExplodingBarrel},
				exclude_targets = make([dynamic]uuid.Identifier, context.allocator),
			}
			player.can_attack = false

			// Animation
			if player.cur_weapon_anim.pos_cur_rotation ==
			   player.cur_weapon_anim.cpos_top_rotation { 	// Animate down
				player.cur_weapon_anim.pos_rotation_vel =
					(player.cur_weapon_anim.cpos_bot_rotation -
						player.cur_weapon_anim.cpos_top_rotation) /
					ATTACK_DURATION
				player.cur_weapon_anim.sprite_rotation_vel =
					(player.cur_weapon_anim.csprite_bot_rotation -
						player.cur_weapon_anim.csprite_top_rotation) /
					ATTACK_DURATION
			} else { 	// Animate up
				player.cur_weapon_anim.pos_rotation_vel =
					(player.cur_weapon_anim.cpos_top_rotation -
						player.cur_weapon_anim.cpos_bot_rotation) /
					ATTACK_DURATION
				player.cur_weapon_anim.sprite_rotation_vel =
					(player.cur_weapon_anim.csprite_top_rotation -
						player.cur_weapon_anim.csprite_bot_rotation) /
					ATTACK_DURATION
			}
		}
	case .Stick:
		if player.can_attack {
			// Attack
			player.attack_poly.rotation = angle(mouse_world_pos - player.pos)
			player.attack_dur_timer = ATTACK_DURATION
			player.attack_interval_timer = ATTACK_INTERVAL
			player.attacking = true
			player.cur_attack = Attack {
				pos             = player.pos,
				shape           = player.attack_poly,
				damage          = STICK_DAMAGE,
				knockback       = STICK_KNOCKBACK,
				direction       = normalize(mouse_world_pos - player.pos),
				data            = SwordAttackData{},
				targets         = {.Enemy, .Bomb, .ExplodingBarrel},
				exclude_targets = make([dynamic]uuid.Identifier, context.allocator),
			}
			player.can_attack = false

			// Animation
			if player.cur_weapon_anim.pos_cur_rotation ==
			   player.cur_weapon_anim.cpos_top_rotation { 	// Animate down
				player.cur_weapon_anim.pos_rotation_vel =
					(player.cur_weapon_anim.cpos_bot_rotation -
						player.cur_weapon_anim.cpos_top_rotation) /
					ATTACK_DURATION
				player.cur_weapon_anim.sprite_rotation_vel =
					(player.cur_weapon_anim.csprite_bot_rotation -
						player.cur_weapon_anim.csprite_top_rotation) /
					ATTACK_DURATION
			} else { 	// Animate up
				player.cur_weapon_anim.pos_rotation_vel =
					(player.cur_weapon_anim.cpos_top_rotation -
						player.cur_weapon_anim.cpos_bot_rotation) /
					ATTACK_DURATION
				player.cur_weapon_anim.sprite_rotation_vel =
					(player.cur_weapon_anim.csprite_top_rotation -
						player.cur_weapon_anim.csprite_bot_rotation) /
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
				entity = new_entity(
					player.pos +
					rotate_vector(
						{-2, 5} +
						10 * vector_from_angle(-50 - get_weapon_charge_multiplier() * 50),
						angle(to_mouse),
					),
				),
				shape = Circle{{}, 4},
				vel = to_mouse * get_weapon_charge_multiplier() * 300,
				z = 0,
				vel_z = 8,
				rot = -140 - get_weapon_charge_multiplier() * 110 + angle(to_mouse),
				rot_vel = 1200 * get_weapon_charge_multiplier(),
				sprite = sprite,
				data = weapon_data,
				attack = Attack {
					targets = {.Enemy, .Wall, .ExplodingBarrel},
					exclude_targets = make([dynamic]uuid.Identifier, context.allocator),
				},
			},
		)
		player.weapons[player.selected_weapon_idx].id = .Empty
	case .Stick:
		// Throw stick here
		tex := loaded_textures[.Stick]
		sprite: Sprite = {
			.Stick,
			{0, 0, f32(tex.width), f32(tex.height)},
			{1, 1},
			{f32(tex.width) / 2, f32(tex.height) / 2},
			0,
			rl.WHITE,
		}
		append(
			&projectile_weapons,
			ProjectileWeapon {
				entity = new_entity(
					player.pos +
					rotate_vector(
						{-2, 5} +
						10 * vector_from_angle(-50 - get_weapon_charge_multiplier() * 50),
						angle(to_mouse),
					),
				),
				shape = Circle{{}, 4},
				vel = to_mouse * get_weapon_charge_multiplier() * 300,
				z = 0,
				vel_z = 8,
				rot = -140 - get_weapon_charge_multiplier() * 110 + angle(to_mouse),
				rot_vel = 1200 * get_weapon_charge_multiplier(),
				sprite = sprite,
				data = weapon_data,
				attack = Attack {
					targets = {.Enemy, .Wall, .ExplodingBarrel},
					exclude_targets = make([dynamic]uuid.Identifier, context.allocator),
				},
			},
		)
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
	case .Stick:
		sprite.tex_origin = {0, 8}
	}

	sprite_pos := player.pos
	if player.charging_weapon {
		sprite.rotation = -140 - get_weapon_charge_multiplier() * 110
		sprite_pos += {-2, 5} + 10 * vector_from_angle(-50 - get_weapon_charge_multiplier() * 50)
	} else {
		// Set rotation and position based on if sword is on top or not
		sprite.rotation = player.cur_weapon_anim.sprite_cur_rotation
		// The value 4 and {2, 0} are both constants here
		sprite_pos += {2, 0} + 4 * vector_from_angle(player.cur_weapon_anim.pos_cur_rotation)
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
		not_selected_idx: int = 0 if player.selected_weapon_idx == 1 else 1
		if player.weapons[player.selected_weapon_idx].id == .Empty {
			player.weapons[player.selected_weapon_idx] = data // copy data
			select_weapon(player.selected_weapon_idx) // select weapon
			return true // success!
		} else if player.weapons[not_selected_idx].id == .Empty {
			player.weapons[not_selected_idx] = data
			// select_weapon(not_selected_idx)
			return true
		}
		//  else {
		// Drop current weapon
		// NOTE: Create a different function. drop_item() could drop an item, not a weapon here
		// if item_data := drop_item(); item_data.id != .Empty {
		// 	add_item_to_world(item_data, player.pos)
		// }
		// player.weapons[player.selected_weapon_idx] = data // copy data
		// select_weapon(player.selected_weapon_idx) // select weapon
		// return true
		// }
	}
	return false
}

select_weapon :: proc(idx: int) {
	player.selected_weapon_idx = idx
	#partial switch player.weapons[idx].id {
	case .Sword:
		player.attack_poly.points = SWORD_HITBOX_POINTS
		player.cur_weapon_anim = SWORD_ANIMATION_DEFAULT
	case .Stick:
		player.attack_poly.points = STICK_HITBOX_POINTS
		player.cur_weapon_anim = STICK_ANIMATION_DEFAULT
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
			stop_player_attack() // Cancel attack
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

is_level_finished :: proc() -> bool {
	return len(enemies) == 0
}

add_item_to_world :: proc(data: ItemData, pos: Vec2) {
	item: Item
	item.entity = new_entity(pos)
	item.data = data
	setup_item(&item)
	append(&items, item)
}

perform_attack :: proc(attack: ^Attack) -> (targets_hit: int) {
	EXPLOSION_DAMAGE_MULTIPLIER :: 10
	// Perform attack
	switch data in attack.data {
	case SwordAttackData:
		// Attack all targets
		if .Enemy in attack.targets {
			#reverse for &enemy, i in enemies {
				// Exclude enemy
				if _, exclude_found := slice.linear_search(attack.exclude_targets[:], enemy.id);
				   exclude_found {
					continue
				}

				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, enemy.shape, enemy.pos) {
					enemy.vel += attack.direction * attack.knockback
					damage_enemy(i, attack.damage)
					append(&attack.exclude_targets, enemy.id)
					targets_hit += 1
				}
			}
		}
		if .ExplodingBarrel in attack.targets {
			for &barrel, i in exploding_barrels {
				// Exclude
				if _, exclude_found := slice.linear_search(attack.exclude_targets[:], barrel.id);
				   exclude_found || barrel.queue_free {
					continue
				}

				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, barrel.shape, barrel.pos) {
					barrel.vel += attack.direction * attack.knockback
					damage_exploding_barrel(i, attack.damage)
					append(&attack.exclude_targets, barrel.id)
					targets_hit += 1
				}
			}
		}
		if .Bomb in attack.targets {
			#reverse for &bomb in bombs {
				// Exclude
				if _, exclude_found := slice.linear_search(attack.exclude_targets[:], bomb.id);
				   exclude_found {
					continue
				}

				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, bomb.shape, bomb.pos) {
					bomb.vel += attack.direction * attack.knockback
					append(&attack.exclude_targets, bomb.id)
					targets_hit += 1
				}
			}
		}
		if .Player in attack.targets {
			// Exclude
			if _, exclude_found := slice.linear_search(attack.exclude_targets[:], player.id);
			   !exclude_found {
				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, player.shape, player.pos) {
					player.vel += attack.direction * attack.knockback
					damage_player(attack.damage)
					append(&attack.exclude_targets, player.id)
					targets_hit += 1
				}
			}
		}
	case ExplosionAttackData:
		if .Enemy in attack.targets {
			#reverse for &enemy, i in enemies {
				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, enemy.shape, enemy.pos) {
					// Knockback
					enemy.vel += normalize(enemy.pos - attack.pos) * attack.knockback
					// Damage
					damage_enemy(i, attack.damage)
					targets_hit += 1
				}
			}
		}
		if .Player in attack.targets {
			if check_collision_shapes(attack.shape, attack.pos, player.shape, player.pos) {
				player.vel += normalize(player.pos - attack.pos) * attack.knockback
				damage_player(attack.damage)
				targets_hit += 1
			}
		}
		if .ExplodingBarrel in attack.targets {
			for &barrel, i in exploding_barrels {
				if barrel.queue_free {
					continue
				}
				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, barrel.shape, barrel.pos) {
					barrel.vel += normalize(barrel.pos - attack.pos) * attack.knockback
					damage_exploding_barrel(i, attack.damage * EXPLOSION_DAMAGE_MULTIPLIER)
					targets_hit += 1
				}
			}
		}

		if .Bomb in attack.targets {
			#reverse for &bomb in bombs {
				// Exclude
				if _, exclude_found := slice.linear_search(attack.exclude_targets[:], bomb.id);
				   exclude_found {
					continue
				}

				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, bomb.shape, bomb.pos) {
					bomb.vel += normalize(bomb.pos - attack.pos) * attack.knockback
					append(&attack.exclude_targets, bomb.id)
					targets_hit += 1
				}
			}
		}

		if .Tile in attack.targets {
			tiles := get_tile_shape_collision(attack.shape, attack.pos)
			for tile in tiles {
				#partial switch tile_data in tilemap[tile.x][tile.y] {
				case GrassData:
					if data.burn_instantly {
						tilemap[tile.x][tile.y] = GrassData{false, 0, false, true}
					} else {
						tile_should_spread := rand.choice([]bool{true, false})
						tilemap[tile.x][tile.y] = GrassData{true, 1, tile_should_spread, false}
					}
				}
			}
		}
	case FireAttackData:
		if .Enemy in attack.targets {
			#reverse for &enemy, i in enemies {
				if check_collision_shapes(attack.shape, attack.pos, enemy.shape, enemy.pos) {
					// Damage
					damage_enemy(i, attack.damage, false)
					targets_hit += 1
				}
			}
		}
		if .ExplodingBarrel in attack.targets {
			for &barrel, i in exploding_barrels {
				if barrel.queue_free {
					continue
				}

				if check_collision_shapes(attack.shape, attack.pos, barrel.shape, barrel.pos) {
					// Damage
					damage_exploding_barrel(i, attack.damage)
					targets_hit += 1
				}
			}
		}
		if .Player in attack.targets {
			if check_collision_shapes(attack.shape, attack.pos, player.shape, player.pos) {
				damage_player(attack.damage)
			}
		}
	case ProjectileAttackData:
		weapon := &projectile_weapons[data.projectile_idx]
		if .Wall in attack.targets {
			for wall in walls {
				_, normal, depth := resolve_collision_shapes(
					weapon.shape,
					weapon.pos,
					wall.shape,
					wall.pos,
				)

				if depth > 0 {
					// Only damage the weapon if the wall is not already excluded
					if _, exclude_found := slice.linear_search(attack.exclude_targets[:], wall.id);
					   !exclude_found {
						// Add to exclude
						append(&attack.exclude_targets, wall.id)
						// Durability
						weapon.data.count -=
							int(math.abs(dot(normal, weapon.vel))) / data.speed_durablity_ratio
						if weapon.data.count <= 0 {
							delete_projectile_weapon(data.projectile_idx)
							return -1
						}
					}

					// Resolve collision
					weapon.pos -= normal * depth
					weapon.vel = slide(weapon.vel, normal)
				}
			}
		}

		if .Enemy in attack.targets {
			#reverse for enemy, i in enemies {
				_, normal, depth := resolve_collision_shapes(
					weapon.shape,
					weapon.pos,
					enemy.shape,
					enemy.pos,
				)

				if depth > 0 {
					// Only damage if enemy is not already excluded
					if _, exclude_found := slice.linear_search(
						attack.exclude_targets[:],
						enemy.id,
					); !exclude_found {
						// Add to exclude
						append(&attack.exclude_targets, enemy.id)
						// Damage
						damage_enemy(
							i,
							math.abs(dot(normal, weapon.vel)) / data.speed_damage_ratio,
						)
						// Durability
						weapon.data.count -=
							int(math.abs(dot(normal, weapon.vel))) / data.speed_durablity_ratio
						if weapon.data.count <= 0 {
							delete_projectile_weapon(data.projectile_idx)
							return -1
						}
					}

					// Resolve collision
					weapon.pos -= normal * depth
					weapon.vel = slide(weapon.vel, normal)
				}
			}
		}

		if .ExplodingBarrel in attack.targets {
			for barrel, i in exploding_barrels {
				if barrel.queue_free {
					continue
				}
				_, normal, depth := resolve_collision_shapes(
					weapon.shape,
					weapon.pos,
					barrel.shape,
					barrel.pos,
				)

				if depth > 0 {
					// Only damage if enemy is not already excluded
					if _, exclude_found := slice.linear_search(
						attack.exclude_targets[:],
						barrel.id,
					); !exclude_found {
						// Add to exclude
						append(&attack.exclude_targets, barrel.id)
						// Damage
						damage_exploding_barrel(
							i,
							math.abs(dot(normal, weapon.vel)) / data.speed_damage_ratio,
						)
						// Durability
						weapon.data.count -=
							int(math.abs(dot(normal, weapon.vel))) / data.speed_durablity_ratio
						if weapon.data.count <= 0 {
							delete_projectile_weapon(data.projectile_idx)
							return -1
						}
					}

					// Resolve collision
					weapon.pos -= normal * depth
					weapon.vel = slide(weapon.vel, normal)
				}
			}
		}

	case SurfAttackData:
		if .Enemy in attack.targets {
			#reverse for &enemy, i in enemies {
				if check_collision_shapes(attack.shape, attack.pos, enemy.shape, enemy.pos) {
					// Knockback
					enemy.vel = normalize(enemy.pos - attack.pos) * attack.knockback
					// Damage
					damage_enemy(i, attack.damage)
					targets_hit += 1
				}
			}
		}
		if .ExplodingBarrel in attack.targets {
			for &barrel, i in exploding_barrels {
				if barrel.queue_free {
					continue
				}
				if check_collision_shapes(attack.shape, attack.pos, barrel.shape, barrel.pos) {
					// Knockback
					barrel.vel = normalize(barrel.pos - attack.pos) * attack.knockback
					// Damage
					damage_exploding_barrel(i, attack.damage)
					targets_hit += 1
				}
			}
		}
		if .Bomb in attack.targets {
			#reverse for &bomb in bombs {
				if check_collision_shapes(attack.shape, attack.pos, bomb.shape, bomb.pos) {
					// Knockback
					bomb.vel = normalize(bomb.pos - attack.pos) * attack.knockback
					targets_hit += 1
				}
			}
		}
	case ArrowAttackData:
		arrow := &arrows[data.arrow_idx]
		if .Wall in attack.targets {
			for wall in walls {
				_, _, depth := resolve_collision_shapes(
					arrow.shape,
					arrow.pos,
					wall.shape,
					wall.pos,
				)

				if depth > 0 {
					return -1
				}
			}
		}

		if .Enemy in attack.targets {
			#reverse for enemy, i in enemies {
				// Don't hurt the source of the arrow
				if enemy.id == arrows[data.arrow_idx].source {
					continue
				}
				_, normal, depth := resolve_collision_shapes(
					arrow.shape,
					arrow.pos,
					enemy.shape,
					enemy.pos,
				)

				if depth > 0 {
					// Damage
					damage_enemy(i, math.abs(dot(normal, arrow.vel)) / data.speed_damage_ratio)

					return -1
				}
			}
		}

		if .ExplodingBarrel in attack.targets {
			for barrel, i in exploding_barrels {
				if barrel.queue_free {
					continue
				}

				_, normal, depth := resolve_collision_shapes(
					arrow.shape,
					arrow.pos,
					barrel.shape,
					barrel.pos,
				)

				if depth > 0 {
					// Damage
					damage_exploding_barrel(
						i,
						math.abs(dot(normal, arrow.vel)) / data.speed_damage_ratio,
					)

					return -1
				}
			}
		}

		if .Player in attack.targets && player.id != arrows[data.arrow_idx].source {
			_, normal, depth := resolve_collision_shapes(
				arrow.shape,
				arrow.pos,
				player.shape,
				player.pos,
			)

			if depth > 0 {
				damage_player(math.abs(dot(normal, arrow.vel)) / data.speed_damage_ratio)

				return -1
			}
		}
	case RockAttackData:
		rock := &rocks[data.rock_idx]
		if .Wall in attack.targets {
			for wall in walls {
				_, _, depth := resolve_collision_shapes(rock.shape, rock.pos, wall.shape, wall.pos)

				if depth > 0 {
					return -1
				}
			}
		}

		if .Enemy in attack.targets {
			#reverse for enemy, i in enemies {
				_, normal, depth := resolve_collision_shapes(
					rock.shape,
					rock.pos,
					enemy.shape,
					enemy.pos,
				)

				if depth > 0 {
					// Damage
					damage_enemy(i, math.abs(dot(normal, rock.vel)) / data.speed_damage_ratio)

					return -1
				}
			}
		}

		if .ExplodingBarrel in attack.targets {
			for barrel, i in exploding_barrels {
				if barrel.queue_free {
					continue
				}

				_, normal, depth := resolve_collision_shapes(
					rock.shape,
					rock.pos,
					barrel.shape,
					barrel.pos,
				)

				if depth > 0 {
					// Damage
					damage_exploding_barrel(
						i,
						math.abs(dot(normal, rock.vel)) / data.speed_damage_ratio,
					)

					return -1
				}
			}
		}
	}
	return
}

damage_player :: proc(amount: f32) {
	player.health -= amount
	player.health = max(player.health, 0)
	if player.health <= 0 {
		// Player is dead reload the level
		// TODO: make an actual player death animation
		fmt.println("you dead D:")
		player.queue_free = true
	}
}

on_player_death :: proc() {
	clear(&bombs)
	clear(&projectile_weapons)
	clear(&arrows)
	clear(&rocks)
	clear(&fires)
	reload_game_data()
	reload_level()
}

heal_player :: proc(amount: f32) {
	player.health += amount
	player.health = min(player.health, player.max_health)
}

fit_camera_target_to_level_bounds :: proc(target: Vec2) -> Vec2 {
	target := target

	// Get the top left and bottom right corners
	top_left := Vec2{level.bounds.x, level.bounds.y}
	bottom_right := top_left + Vec2{level.bounds.width, level.bounds.height}

	// Offset them
	offset_top_left := top_left + camera.offset / camera.zoom
	offset_bottom_right := bottom_right - camera.offset / camera.zoom

	target.x = clamp(target.x, offset_top_left.x, offset_bottom_right.x)
	target.y = clamp(target.y, offset_top_left.y, offset_bottom_right.y)

	return target
}
