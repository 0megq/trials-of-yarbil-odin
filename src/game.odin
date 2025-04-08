package game

import "core:crypto"
import "core:encoding/uuid"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:slice"
// import mu "vendor:microui"
import rl "vendor:raylib"

GAME_SIZE :: Vec2i{640, 360}
UI_SIZE :: Vec2i{1440, 810}
UI_OVER_GAME :: f32(UI_SIZE.y) / f32(GAME_SIZE.y)
ASPECT_RATIO_X_Y: f32 : f32(GAME_SIZE.x) / f32(GAME_SIZE.y)
PLAYER_BASE_MAX_SPEED :: 80
PLAYER_BASE_ACCELERATION :: 1500
PLAYER_BASE_FRICTION :: 750
PLAYER_BASE_HARSH_FRICTION :: 2000
ENEMY_PATHFINDING_TIME :: 0.2
FIRE_DASH_RADIUS :: 8
FIRE_DASH_FIRE_DURATION :: 1
FIRE_DASH_COOLDOWN :: 2
FIRE_TILE_DAMAGE :: 1
ITEM_HOLD_DIVISOR :: 1 // Max time
WEAPON_CHARGE_DIVISOR :: 1 // Max time
PORTAL_RADIUS :: 16
BOMB_EXPLOSION_TIME :: 1
CAMERA_LOOKAHEAD :: 8
CAMERA_SMOOTHING :: 30
PLAYER_SPEED_DISTRACTION_THRESHOLD :: 75
SPEED_SECOND_THRESHOLD :: 0.5
ENEMY_POST_RANGE :: 16
ENEMY_SEARCH_TOLERANCE :: 16

// weapon/attack related constants
ATTACK_DURATION :: 0.15
ATTACK_INTERVAL :: 0
SWORD_DAMAGE :: 40
SWORD_KNOCKBACK :: 60
SWORD_HITBOX_OFFSET :: 4
STICK_DAMAGE :: 10
STICK_KNOCKBACK :: 70
STICK_HITBOX_OFFSET :: 2

EditorMode :: enum {
	None,
	Level,
	Entity,
	Tutorial,
}

Menu :: enum {
	None,
	Pause,
	Main,
}

Timer :: struct {
	time_left:  f32,
	callable:   proc(),
	start_time: f32, // Set to 0 or less if want to not one shot
}

MovementAbility :: enum {
	FIRE,
	WATER,
	GROUND,
	AIR,
	ELECTRIC,
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
	slow_down:              Control,
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
	slow_down              = rl.KeyboardKey.LEFT_SHIFT,
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

game_data: GameData

debug_speed := f32(1)
// world data

main_world: World

player_at_portal: bool
seconds_above_distraction_threshold: f32
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

speedrun_timer := f32(0)

// misc
world_camera: rl.Camera2D
ui_camera: rl.Camera2D

window_size := UI_SIZE
window_over_game: f32
window_over_ui: f32

mouse_window_pos: Vec2
mouse_window_delta: Vec2
mouse_ui_pos: Vec2
mouse_ui_delta: Vec2
mouse_world_pos: Vec2
mouse_world_delta: Vec2

delta: f32

menu := Menu.None

main :: proc() {
	// Init RNG
	context.random_generator = crypto.random_generator()

	// Setup Tracking Allocator
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

	// Setup Window
	{
		rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
		rl.SetWindowMaxSize(1920, 1057)
		rl.InitWindow(window_size.x, window_size.y, "Trials of Yarbil")
		// Set window values
		window_over_game = f32(window_size.y) / f32(GAME_SIZE.y)
		window_over_ui = f32(window_size.y) / f32(UI_SIZE.y)
	}

	// Load resources and data
	{
		load_textures()
		// pixel_filter := rl.LoadShader(nil, "assets/pixel_filter.fs")
		load_game_data()
	}

	init_editor_state(&editor_state)

	// Init world
	{
		load_level()
		fires = make([dynamic]Fire, context.allocator)
		bombs = make([dynamic]Bomb, context.allocator)
		arrows = make([dynamic]Arrow, context.allocator)

		// Generate new ids for the walls. Potential source of bugs
		// for &wall in level.walls {
		// 	wall.id = uuid.generate_v4()
		// }

		// attack_poly.points = punch_points[:]
	}

	// Init ui camera
	ui_camera = rl.Camera2D {
		target = Vec2{f32(window_size.x), f32(window_size.y)} / 2,
		zoom   = window_over_ui,
		offset = ({f32(window_size.x), f32(window_size.y)} / 2),
	}

	// Update Loop
	for !rl.WindowShouldClose() {
		update()
	}

	// Save level if in editor
	if editor_state.mode != .None {
		save_level()
	}
	// Free level memory
	unload_level()

	// Free game data memory
	unload_game_data()

	// Unload textures
	unload_textures()

	// Free all memory
	mem.tracking_allocator_clear(&track)
	free_all(context.temp_allocator)
	free_all(context.allocator)

	// Done
	rl.CloseWindow()
}

// This is our update loop handles and draws EVERYTHING every frame
update :: proc() {
	delta = rl.GetFrameTime()
	mouse_window_pos = rl.GetMousePosition()
	mouse_window_delta = rl.GetMouseDelta()

	// Increase gameplay speed when debugging
	when ODIN_DEBUG {
		delta *= debug_speed

		if rl.IsKeyPressed(.LEFT_BRACKET) {
			debug_speed -= 0.25
		}
		if rl.IsKeyPressed(.RIGHT_BRACKET) {
			debug_speed += 0.25
		}
	}

	// Window resizing
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

		window_over_game = f32(window_size.y) / f32(GAME_SIZE.y)
		window_over_ui = f32(window_size.y) / f32(UI_SIZE.y)
	}

	// Update UI Camera and get UI mouse input
	ui_camera.offset = Vec2{f32(window_size.x), f32(window_size.y)} / 2
	ui_camera.zoom = window_over_ui
	ui_camera.target = Vec2{f32(UI_SIZE.x), f32(UI_SIZE.y)} / 2
	mouse_ui_pos = window_to_ui(mouse_window_pos)
	mouse_ui_delta = mouse_window_delta / ui_camera.zoom

	switch menu {
	case .None:
		// 1. Frame setup
		// 2. Update input
		// 3. Update editor (animations, movement, collision, attacks, win condition, timers)
		// 4. Menu-specific Clean up

		// Perform Queued World Actions (death and deletion). Remove things from the previous frame
		if main_world.player.queue_free {
			on_player_death()
			main_world.player.queue_free = false
		}
		if queue_play_again {
			play_again_button.status = .Normal
			display_win_screen = false
			reload_game_data()
			reload_level(&main_world)
			queue_play_again = false
		}
		#reverse for barrel, i in main_world.exploding_barrels { 	// This needs to be in reverse since we are removing
			if barrel.queue_free {
				unordered_remove(&main_world.exploding_barrels, i)
			}
		}

		// Update World Camera and get World mouse input
		{
			world_camera.offset = {f32(window_size.x), f32(window_size.y)} / 2
			if editor_state.mode == .None {
				world_camera.zoom = window_over_game
				world_camera.target = player.pos
				// Camera smoothing
				// world_camera.target = exp_decay(
				// 	world_camera.target,
				// 	player.pos + normalize(mouse_world_pos - player.pos) * 32,
				// 	2,
				// 	delta,
				// )

				// camera.target = 0
				// camera.target = fit_camera_target_to_level_bounds(player.pos)
			} else {
				world_camera.zoom += rl.GetMouseWheelMove() * 0.2 * world_camera.zoom
				world_camera.zoom = max(0.1, world_camera.zoom)
				if math.abs(world_camera.zoom - window_over_game) < 0.2 {
					world_camera.zoom = window_over_game
				}

				if rl.IsMouseButtonDown(.MIDDLE) {
					world_camera.target -= mouse_world_delta
				}
			}

			mouse_world_pos = window_to_world(mouse_window_pos)
			mouse_world_delta = mouse_window_delta / world_camera.zoom
		}
		// Editor Controls
		when ODIN_DEBUG {
			if rl.IsKeyDown(.LEFT_CONTROL) {
				// Switch Editor Mode
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

				// Save, load, show grid, change level
				if editor_state.mode != .None {
					// Save, load, show tile grid
					if rl.IsKeyPressed(.S) {
						save_level()
						// This is here simply to make it easy to update the wall tilemap and navgraph while editing
						place_walls_and_calculate_graph(&main_world)
					} else if rl.IsKeyPressed(.L) {
						reload_level()
					} else if rl.IsKeyPressed(.G) {
						editor_state.show_tile_grid = !editor_state.show_tile_grid
					}

					// Next level and previous level
					if rl.IsKeyPressed(.RIGHT) {
						save_level()
						game_data.cur_level_idx += 1
						// Reset editor
						init_editor_state(&editor_state)
						reload_level()
					} else if rl.IsKeyPressed(.LEFT) {
						save_level()
						game_data.cur_level_idx -= 1
						init_editor_state(&editor_state)
						reload_level()
					}
				}
			}
		}

		// Update Current Editor (Including World!)
		switch editor_state.mode {
		case .Level:
			update_geometry_editor(&editor_state)
		case .Entity:
			update_entity_editor(&editor_state)
		case .Tutorial:
			update_tutorial_editor(&editor_state)
		case .None:
			if !all_enemies_dead() {
				speedrun_timer += delta
			}

			// TUTORIAL ACTIONS
			for &action in tutorial.actions {
				if check_condition(&action.condition, action.invert_condition) &&
				   check_condition(&action.condition2, action.invert_condition2) &&
				   check_condition(&action.condition3, action.invert_condition3) {
					switch data in action.action {
					case EnableEntityAction:
						#partial switch data.type {
						case .Item:
							#reverse for item, i in disabled_items {
								if item.id == data.id {
									append(&items, item)
									if !data.should_clone {
										unordered_remove(&disabled_items, i)
									}
									break
								}
							}
						case .Enemy:
							#reverse for enemy, i in disabled_enemies {
								if enemy.id == data.id {
									append(&enemies, enemy)
									if !data.should_clone {
										unordered_remove(&disabled_enemies, i)
									}
									break
								}
							}
						}
					case SetTutorialFlagAction:
						flag: ^bool = get_tutorial_flag_from_name(data.flag_name)
						if flag != nil {
							flag^ = data.value
						}
					case PrintMessageAction:
						fmt.println(data.message)
					}
				}
			}

			// Fire spread and other tile updates
			update_tilemap()

			// Check player collision with portal
			player_at_portal = check_collision_shapes(
				Circle{{}, PORTAL_RADIUS},
				level.portal_pos,
				player.shape,
				player.pos,
			)
			if all_enemies_dead() && is_control_pressed(controls.use_portal) && player_at_portal {
				if game_data.cur_level_idx == -1 { 	// no win screen for now
					display_win_screen = true
				} else {
					// if next level exists, play it, else restart from the beginning
					game_data.cur_level_idx += 1
					clear_temp_entities()
					reload_level()
				}
			}

			if display_win_screen {
				update_button(&play_again_button, mouse_ui_pos)
				if play_again_button.status == .Released {
					queue_play_again = true
				}
			}

			// fire dash timer
			if !player.can_fire_dash {
				player.fire_dash_timer -= delta
				if player.fire_dash_timer <= 0 {
					player.can_fire_dash = true
				}
			} else {
				player.fire_dash_ready_time += delta
			}

			if !(level.has_tutorial && tutorial.disable_ability) &&
			   is_control_pressed(controls.movement_ability) {
				move_successful := false
				if player.can_fire_dash {
					move_successful = true
					player.can_fire_dash = false
					player.fire_dash_timer = FIRE_DASH_COOLDOWN
					player.fire_dash_ready_time = 0

					player.vel = normalize(get_directional_input()) * 400
					fire := Fire{{player.pos, FIRE_DASH_RADIUS}, FIRE_DASH_FIRE_DURATION}
					append(&fires, fire)
					attack := Attack {
						pos       = player.pos,
						shape     = Circle{{}, FIRE_DASH_RADIUS},
						damage    = 10,
						knockback = 100,
						targets   = {.Bomb, .Enemy, .ExplodingBarrel, .Tile},
						data      = ExplosionAttackData{true},
					}
					perform_attack(&attack)
				}
				if move_successful {
					stop_player_attack()
					player.charging_weapon = false
					player.holding_item = false
				}
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
			for wall in half_walls {
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

			if length_squared(player.vel) >= square(f32(PLAYER_SPEED_DISTRACTION_THRESHOLD)) {
				seconds_above_distraction_threshold += delta
			} else {
				seconds_above_distraction_threshold = 0
			}
			if seconds_above_distraction_threshold >= SPEED_SECOND_THRESHOLD {
				append(
					&alerts,
					Alert {
						pos = player.pos,
						range = 90,
						base_intensity = 0.8,
						base_duration = 1,
						decay_rate = 1,
						time_emitted = f32(rl.GetTime()),
					},
				)
			}


			#reverse for &fire, i in fires {
				fire.time_left -= delta
				if fire.time_left <= 0 {
					unordered_remove(&fires, i)
				}
			}

			/* -------------------------------------------------------------------------- */
			/*                               MARK:Enemy Loop                              */
			/* -------------------------------------------------------------------------- */
			#reverse for &enemy, idx in enemies {
				/* ---------------------------- Tutorial Dummies ---------------------------- */
				if level.has_tutorial && tutorial.enable_enemy_dummies {
					damage_enemy(idx, 0)
				}

				/* -------------------------------- Flinching ------------------------------- */
				enemy.target = enemy.pos
				if enemy.flinching {
					enemy.current_flinch_time -= delta
					if enemy.current_flinch_time <= 0 {
						enemy.flinching = false
					}
				} else {
					/* --------------------------- Update Vision Cone --------------------------- */
					{
						for &p, i in enemy.vision_points {
							dir := vector_from_angle(
								f32(i) * enemy.vision_fov / f32(len(enemy.vision_points) - 1) +
								enemy.look_angle -
								enemy.vision_fov / 2,
							)
							if i == len(enemy.vision_points) - 1 {
								p = enemy.pos
								break
							}
							t := cast_ray_through_level(walls[:], enemy.pos, dir)
							if t < enemy.vision_range {
								p = enemy.pos + t * dir
							} else {
								p = enemy.pos + enemy.vision_range * dir
							}
						}
					}

					/* -------------------------- Check For Player LOS -------------------------- */
					{
						enemy.can_see_player = check_collsion_circular_concave_circle(
							enemy.vision_points[:],
							enemy.pos,
							{player.pos, 8},
						)
						if enemy.can_see_player {
							enemy.last_seen_player_pos = player.pos
							enemy.last_seen_player_vel = player.vel
						}
					}

					/* ---------------------------- Player Flee Check --------------------------- */
					{
						#partial switch data in enemy.data {
						case RangedEnemyData:
							enemy.player_in_flee_range = check_collision_shapes(
								Circle{{}, data.flee_range},
								enemy.pos,
								player.shape,
								player.pos,
							)
						}
					}

					/* ------------------------------ Check Alerts ------------------------------ */
					if alert_states: bit_set[EnemyState] = {.Alerted, .Idle, .Searching};
					   enemy.state in alert_states { 	// If enemy is in a state that can detect alerts
						enemy.alert_just_detected = false
						detected_alert: Alert
						detected_effective_intensity: f32 = 0
						for alert in alerts {
							effective_intensity := get_effective_intensity(alert)
							// get effective range
							effective_enemy_range :=
								effective_intensity *
								(enemy.vision_range if alert.is_visual else enemy.hearing_range)

							// check los if alert is visual
							can_detect :=
								!alert.is_visual || check_collsion_circular_concave_circle(
									enemy.vision_points[:],
									enemy.pos,
									{alert.pos, 2}, // 2 is an arbitrary radius. Should work here.
								)

							detected :=
								can_detect &&
								distance_squared(enemy.pos, alert.pos) <
									square(min(effective_enemy_range, alert.range)) &&
								alert.time_emitted > enemy.last_alert.time_emitted

							if detected {
								if effective_intensity > detected_effective_intensity ||
								   (effective_intensity == detected_effective_intensity &&
										   distance_squared(enemy.pos, alert.pos) <
											   distance_squared(enemy.pos, detected_alert.pos)) {
									detected_alert = alert
									detected_effective_intensity = effective_intensity
								}
							}
						}
						// Check if alert is relevant
						if detected_effective_intensity > 0 &&
						   (detected_effective_intensity >
									   get_effective_intensity(enemy.last_alert) ||
								   enemy.state != .Alerted) {
							enemy.alert_just_detected = true
							enemy.last_alert_intensity_detected = detected_effective_intensity
							enemy.last_alert = detected_alert
						}
					}

					/* ------------------------------ Update State ------------------------------ */
					{
						update_enemy_state(&enemy, delta)
					}
				}

				/* -------------------------- Movement and Collsion ------------------------- */
				enemy_move(&enemy, delta)

				for wall in walls {
					_, normal, depth := resolve_collision_shapes(
						enemy.shape,
						enemy.pos,
						wall.shape,
						wall.pos,
					)
					if depth > 0 {
						enemy.pos -= normal * depth
						enemy.vel = slide(enemy.vel, normal)
					}
				}
				for wall in half_walls {
					_, normal, depth := resolve_collision_shapes(
						enemy.shape,
						enemy.pos,
						wall.shape,
						wall.pos,
					)
					if depth > 0 {
						enemy.pos -= normal * depth
						enemy.vel = slide(enemy.vel, normal)
					}
				}
			}

			/* ------------------------------ Update Alerts ----------------------------- */
			#reverse for &alert, i in alerts {
				if get_time_left(alert) <= 0 || get_effective_intensity(alert) <= 0 {
					unordered_remove(&alerts, i)
				}
			}


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
				for wall in half_walls {
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

			#reverse for &bomb, i in bombs {
				zentity_move(&bomb, 300, 50, delta)
				should_explode := false
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
						should_explode = true
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
						should_explode = true
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
						should_explode = true
					}
				}
				if bomb.z <= 0 { 	// if on ground, then start ticking
					should_explode = true
				}
				if should_explode {
					bomb_explosion(bomb.pos, 16)
					perform_attack(
						&{
							targets = {.Player, .Enemy, .ExplodingBarrel, .Tile},
							damage = 20,
							knockback = 20,
							pos = bomb.pos,
							shape = Circle{{}, 16},
							data = ExplosionAttackData{true},
						},
					)
					append(
						&alerts,
						Alert {
							pos = bomb.pos,
							range = 60,
							base_intensity = 1.1,
							base_duration = 0.5,
							decay_rate = 2,
							time_emitted = f32(rl.GetTime()),
						},
					)
					unordered_remove(&bombs, i)
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

			// weapon attack
			if is_control_pressed(controls.fire) {
				if player.weapons[player.selected_weapon_idx].id >= .Sword {
					fire_selected_weapon()
					player.holding_item = false // Cancel item hold
					player.charging_weapon = false // cancel charge
				}
			}

			// Handle player charging/holding item
			if player.holding_item {
				if player.item_switched || is_control_pressed(controls.cancel) {
					player.holding_item = false
				} else if is_control_released(controls.use_item) {
					use_bomb()
					player.holding_item = false
				}

				player.item_hold_time += delta
			}
			// Start player holding item
			if is_control_pressed(controls.use_item) &&
			   player.items[player.selected_item_idx].id != .Empty {
				stop_player_attack() // Cancel attack
				player.charging_weapon = false // Cancel charge
				player.holding_item = true
				player.item_hold_time = 0
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

					perform_attack(&player.cur_attack)
					append(
						&alerts,
						Alert {
							pos = player.pos,
							range = 60,
							base_intensity = 0.9,
							base_duration = 0.5,
							decay_rate = 2,
							time_emitted = f32(rl.GetTime()),
						},
					)
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
				// DEBUG: Player inventory
				// fmt.printfln(
				// 	"weapons: %v, items: %v, selected_weapon: %v, selected_item: %v",
				// 	player.weapons,
				// 	player.items,
				// 	player.selected_weapon_idx,
				// 	player.selected_item_idx,
				// )

			}
		}
	case .Main:
	// Send input
	// Update button and ui elements
	// Do stuff based on new button and ui status
	case .Pause:
	}

	draw_frame()

	free_all(context.temp_allocator)
}

draw_frame :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.DARKGRAY)

	rl.BeginMode2D(world_camera)
	#partial switch menu {
	case .None:
		draw_world(main_world)
	}
	rl.EndMode2D()

	rl.BeginMode2D(ui_camera)
	#partial switch menu {
	case .None:
		draw_world_ui(main_world)
	}
	rl.EndMode2D()

	rl.EndDrawing()
}

draw_world :: proc(world: World) {
	if editor_state.mode != .None {
		draw_level(editor_state.show_tile_grid)
	}

	switch editor_state.mode {
	case .Level:
		draw_geometry_editor_world(world, editor_state)
	case .Entity:
		draw_entity_editor_world(editor_state)
	case .Tutorial:
		draw_tutorial_editor_world(editor_state)
	case .None:
		draw_tilemap(world.tilemap)

		for fire in world.fires {
			rl.DrawCircleV(fire.pos, fire.radius, rl.ORANGE)
		}

		// Draw portal
		portal_color := rl.BLUE if all_enemies_dead(world) else Color{50, 50, 50, 255}
		rl.DrawCircleV(level.portal_pos, PORTAL_RADIUS, portal_color)

		// Draw arrow to portal if level finished and player is at least 64 units away
		if all_enemies_dead(world) && !player_at_portal {
			angle_to_portal := angle(level.portal_pos - world.player.pos)
			arrow_polygon := Polygon {
				world.player.pos,
				{{14, -3}, {24, 0}, {14, 3}},
				angle_to_portal,
			}
			draw_polygon(arrow_polygon, rl.BLUE)
		}

		// Draw portal prompts
		if player_at_portal {
			prompt: cstring
			prompt = "Press E"
			if !all_enemies_dead() {
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

		// Draw items
		for item in world.items {
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
				Circle{{}, world.player.pickup_range},
				world.player.pos,
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

		// Draw walls and half walls
		for wall in world.walls {
			draw_shape(wall.shape, wall.pos, rl.GRAY)
		}

		for wall in world.half_walls {
			draw_shape(wall.shape, wall.pos, rl.LIGHTGRAY)
		}

		// Draw in world level prompts
		if level.has_tutorial {
			for &prompt in tutorial.prompts {
				if !prompt.on_screen {
					font_size: f32 = 6
					spacing: f32 = 1
					text := fmt.ctprint(prompt.text)
					pos := get_centered_text_pos(prompt.pos, text, font_size, spacing)

					if check_condition(&prompt.condition, prompt.invert_condition, world) &&
					   check_condition(&prompt.condition2, prompt.invert_condition2, world) &&
					   check_condition(&prompt.condition3, prompt.invert_condition3, world) {
						rl.DrawTextEx(rl.GetFontDefault(), text, pos, font_size, spacing, rl.WHITE)
					} else {
						when ODIN_DEBUG {
							text_size := rl.MeasureTextEx(
								rl.GetFontDefault(),
								text,
								font_size,
								spacing,
							)
							rl.DrawRectangleLinesEx(
								{pos.x, pos.y, text_size.x, text_size.y},
								0.5,
								rl.YELLOW,
							)
						}
					}
				}
			}

		}

		for enemy in enemies {
			// DEBUG: Draw collision shape
			// draw_shape(enemy.shape, enemy.pos, rl.GREEN)
			sprite := ENEMY_SPRITE
			sprite.rotation = enemy.look_angle

			if sprite.rotation < -90 || sprite.rotation > 90 {
				sprite.scale = {-1, 1}
				sprite.rotation += 180
			}
			draw_sprite(sprite, enemy.pos)
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

			// DEBUG: Draw ID
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
				bar_filled_rec.height *= enemy.current_charge_time / enemy.start_charge_time
				rl.DrawRectangleRec(bar_filled_rec, rl.DARKGREEN)

				switch data in enemy.data {
				case MeleeEnemyData:
					draw_shape(data.attack_poly, enemy.pos, attack_area_color)
				case RangedEnemyData:

				}
			}

			// Draw vision area
			when ODIN_DEBUG {
				rl.DrawCircleLinesV(enemy.pos, enemy.vision_range, rl.YELLOW)
				for p, i in enemy.vision_points {
					rl.DrawLineV(
						p,
						enemy.vision_points[(i + 1) % len(enemy.vision_points)],
						rl.YELLOW,
					)
				}
			}

			// DEBUG: Enemy path
			// if enemy.current_path != nil {
			// 	for point in enemy.current_path {
			// 		rl.DrawCircleV(point, 2, rl.RED)
			// 	}
			// }
		}

		when ODIN_DEBUG {
			for alert in alerts {
				rl.DrawCircleLinesV(alert.pos, alert.range, rl.RED)
			}
		}

		for barrel in exploding_barrels {
			if barrel.queue_free {
				continue
			}
			draw_sprite(BARREL_SPRITE, barrel.pos)
		}

		for &entity in bombs {
			entity.sprite.scale = entity.z + 1
			draw_sprite(entity.sprite, entity.pos)
		}

		for &entity in arrows {
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
			if !player.holding_item && player.weapons[player.selected_weapon_idx].id != .Empty {
				draw_weapon(player.weapons[player.selected_weapon_idx].id)
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

			// DEBUG: Player pickup range
			// draw_shape_lines(Circle{{}, player.pickup_range}, player.pos, rl.DARKBLUE)
			// DEBUG: Collision shape
			// draw_shape(player.shape, player.pos, rl.RED)
		}
	}
}

draw_world_ui :: proc(world: World) {
	if world_camera.zoom != window_over_game {
		rl.DrawText(fmt.ctprintf("Zoom: x%v", world_camera.zoom), 24, 700, 16, rl.BLACK)
	}

	if editor_state.mode != .None {
		// Display mouse coordinates
		rl.DrawText(fmt.ctprintf("%v", mouse_world_pos), 20, 20, 16, rl.WHITE)
		if editor_state.show_tile_grid {
			rl.DrawText(
				fmt.ctprintf("%v", Vec2i{i32(mouse_world_pos.x), i32(mouse_world_pos.y)} / 8),
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
		rl.DrawText("Level Editor", 1300, 32, 16, rl.WHITE)

	case .Entity:
		draw_entity_editor_ui(editor_state)
		rl.DrawText("Entity Editor", 1300, 32, 16, rl.WHITE)
	case .Tutorial:
		draw_tutorial_editor_ui(editor_state)
		rl.DrawText("Tutorial Editor", 1300, 32, 16, rl.WHITE)
	case .None:
		if !(level.has_tutorial && tutorial.hide_all_hud) {
			draw_hud()
		}
		when ODIN_DEBUG { 	// Draw player coordinates
			rl.DrawText(fmt.ctprintf("%v", world.player.pos), 1200, 16, 20, rl.WHITE)
		}


		if all_enemies_dead() {
			message: cstring = "All enemies defeated. Head to the portal."
			size := rl.MeasureTextEx(rl.GetFontDefault(), message, 24, 1)
			rl.DrawTextEx(
				rl.GetFontDefault(),
				message,
				{f32(UI_SIZE.x) / 2, f32(UI_SIZE.y)} - {size.x / 2, size.y + 16},
				24,
				1,
				rl.DARKGREEN,
			)
		}

		// draw on screen tutorial prompt
		if level.has_tutorial {
			#reverse for &prompt in tutorial.prompts {
				if prompt.on_screen {
					center := prompt.pos * {f32(UI_SIZE.x), f32(UI_SIZE.y)}
					font_size: f32 = 24
					spacing: f32 = 1
					text := fmt.ctprint(prompt.text)
					pos := get_centered_text_pos(center, text, font_size, spacing)

					if check_condition(&prompt.condition, prompt.invert_condition) &&
					   check_condition(&prompt.condition2, prompt.invert_condition2) &&
					   check_condition(&prompt.condition3, prompt.invert_condition3) {
						rl.DrawTextEx(rl.GetFontDefault(), text, pos, font_size, spacing, rl.WHITE)
					} else {
						when ODIN_DEBUG {
							text_size := rl.MeasureTextEx(
								rl.GetFontDefault(),
								text,
								font_size,
								spacing,
							)
							rl.DrawRectangleLinesEx(
								{pos.x, pos.y, text_size.x, text_size.y},
								1,
								rl.YELLOW,
							)
						}
					}
				}
			}
		}
	}

	if display_win_screen {
		// draw background
		rl.DrawRectangle(0, 0, UI_SIZE.x, UI_SIZE.y, {0, 0, 0, 100})
		// draw text
		rl.DrawText("Thanks for playing!", 700, 200, 24, rl.BLACK)
		// draw button,
		draw_button(play_again_button)
	}

	// rl.DrawText(fmt.ctprintf("FPS: %v", rl.GetFPS()), 600, 20, 16, rl.BLACK)
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

player_move :: proc(p: ^Player, delta: f32) {
	max_speed: f32 = PLAYER_BASE_MAX_SPEED
	// Slow down player
	if p.holding_item || p.charging_weapon || p.attacking {
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

enemy_move :: proc(e: ^Enemy, delta: f32) {
	max_speed: f32 = 80.0
	#partial switch data in e.data {
	case RangedEnemyData:
		max_speed = 60.0
	}

	// if e.can_see_player {
	// 	// keep base speed
	// } else if e.distracted {
	// 	max_speed *= 0.8 // 80% speed when distracted
	// } else {
	// 	max_speed *= 0.5 // 50% speed when wandering
	// }

	acceleration: f32 = 400.0
	friction: f32 = 240.0
	harsh_friction: f32 = 500.0

	desired_vel: Vec2
	steering: Vec2
	if  /*!e.charging && !e.flinching && */e.target != e.pos {
		desired_vel = normalize(e.target - e.pos) * max_speed
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

cast_ray_through_walls :: proc(walls: []PhysicsEntity, start: Vec2, dir: Vec2) -> f32 {
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

// get_item_hold_multiplier :: proc() -> f32 {
// 	// https://en.wikipedia.org/wiki/Triangle_wave
// 	// 1/p * abs((x - p) % (2 * p) - p)
// 	// p = HOLD_DIVISOR
// 	// x = player.item_hold_time
// 	// Returns a value between 0 and 1
// 	if player.items[player.selected_item_idx].id == .Apple {
// 		// 1.0 are supposed to be same number. it requires 1.0 seconds to eat an apple
// 		return min(player.item_hold_time / 1.0, 1.0)
// 	}
// 	return(
// 		math.abs(
// 			math.mod(player.item_hold_time + ITEM_HOLD_DIVISOR, 2 * ITEM_HOLD_DIVISOR) -
// 			ITEM_HOLD_DIVISOR,
// 		) /
// 		ITEM_HOLD_DIVISOR \
// 	)
// }

// get_weapon_charge_multiplier :: proc() -> f32 {
// 	return(
// 		math.abs(
// 			math.mod(
// 				player.weapon_charge_time + WEAPON_CHARGE_DIVISOR,
// 				2 * WEAPON_CHARGE_DIVISOR,
// 			) -
// 			WEAPON_CHARGE_DIVISOR,
// 		) /
// 		WEAPON_CHARGE_DIVISOR \
// 	)
// }

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

damage_enemy :: proc(world: ^World, enemy_idx: int, amount: f32, should_flinch := true) {
	enemy := &world.enemies[enemy_idx]
	if should_flinch {
		enemy.charging = false
		enemy.flinching = true
		enemy.current_flinch_time = enemy.start_flinch_time
	}
	enemy.health -= amount
	if enemy.health <= 0 {
		unordered_remove(&world.enemies, enemy_idx)
		// reset player dash
		world.player.fire_dash_timer = 0 // Maybe we could send an event that an enemy died or something or return a bool when they do
	}
}

damage_exploding_barrel :: proc(world: ^World, barrel: ^ExplodingBarrel, amount: f32) {
	if barrel.queue_free {
		return
	}
	barrel.health -= amount
	if barrel.health <= 0 {
		// KABOOM!!!
		// Visual
		fire := Fire{Circle{barrel.pos, 60}, 2}
		barrel.queue_free = true

		append(&world.fires, fire)
		// Damage
		perform_attack(
			world,
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

// delete_projectile_weapon :: proc(idx: int) {
// 	delete(projectile_weapons[idx].attack.exclude_targets)
// 	unordered_remove(&projectile_weapons, idx)
// }

delete_arrow :: proc(idx: int) {
	unordered_remove(&arrows, idx)
}

// delete_rock :: proc(idx: int) {
// 	unordered_remove(&rocks, idx)
// }


exp_decay_angle :: proc(a, b: f32, decay: f32, delta: f32) -> f32 {
	diff := a - b
	if diff > 180 {
		diff -= 360
	} else if diff < -180 {
		diff += 360
	}

	return b + diff * math.exp(-decay * delta)
}

exp_decay :: proc(a, b: $T, decay: f32, delta: f32) -> T {
	return b + (a - b) * math.exp(-decay * delta)
}

// Coordinates
world_to_window :: proc(point: Vec2) -> Vec2 {
	return (point - world_camera.target) * world_camera.zoom + world_camera.offset
}

window_to_world :: proc(point: Vec2) -> Vec2 {
	return (point - world_camera.offset) / world_camera.zoom + world_camera.target
}

ui_to_window :: proc(point: Vec2) -> Vec2 {
	return (point - ui_camera.target) * ui_camera.zoom + ui_camera.offset
}

window_to_ui :: proc(point: Vec2) -> Vec2 {
	return (point - ui_camera.offset) / ui_camera.zoom + ui_camera.target
}

ui_to_world :: proc(point: Vec2) -> Vec2 {
	return window_to_world(ui_to_window(point))
}

world_to_ui :: proc(point: Vec2) -> Vec2 {
	return window_to_ui(world_to_window(point))
}

// MARK: Input
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

is_control_pressed :: proc(c: Control) -> bool {
	switch v in c {
	case rl.KeyboardKey:
		return rl.IsKeyPressed(v)
	case rl.MouseButton:
		return rl.IsMouseButtonPressed(v)
	}
	return false
}

is_control_down :: proc(c: Control) -> bool {
	switch v in c {
	case rl.KeyboardKey:
		return rl.IsKeyDown(v)
	case rl.MouseButton:
		return rl.IsMouseButtonDown(v)
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

// Clears entities and reloads game data and level
on_player_death :: proc() {
	clear_temp_entities()
	// Reload the game data. Maybe we don't need to reload game data each time
	reload_game_data()
	// Reload the level
	reload_level()
}

fit_world_camera_target_to_level_bounds :: proc(target: Vec2) -> Vec2 {
	target := target

	// Get the top left and bottom right corners
	top_left := Vec2{level.bounds.x, level.bounds.y}
	bottom_right := top_left + Vec2{level.bounds.width, level.bounds.height}

	// Offset them
	offset_top_left := top_left + world_camera.offset / world_camera.zoom
	offset_bottom_right := bottom_right - world_camera.offset / world_camera.zoom

	target.x = clamp(target.x, offset_top_left.x, offset_bottom_right.x)
	target.y = clamp(target.y, offset_top_left.y, offset_bottom_right.y)

	return target
}

// returns the position of the given text centered at center
get_centered_text_pos :: proc(center: Vec2, text: cstring, font_size: f32, spacing: f32) -> Vec2 {
	return center - rl.MeasureTextEx(rl.GetFontDefault(), text, font_size, spacing) / 2
}

// tutorial thing
check_condition :: proc(condition: ^Condition, invert_condition: bool, world: World) -> bool {
	passed_condition := false
	switch &c in condition {
	case EntityCountCondition:
		#partial switch c.type {
		case .Enemy:
			passed_condition = len(world.enemies) == c.count
		case:
		}

	case EntityExistsCondition:
		#partial switch c.type {
		case .Enemy:
			for enemy in world.enemies {
				if enemy.id == c.id {
					passed_condition = true
					break
				}
			}
			if c.check_disabled {
				for enemy in world.disabled_enemies {
					if enemy.id == c.id {
						passed_condition = true
						break
					}
				}
			}
		case .Item:
			for item in world.items {
				if item.id == c.id {
					passed_condition = true
					break
				}
			}
			if c.check_disabled {
				for item in world.disabled_items {
					if item.id == c.id {
						passed_condition = true
						break
					}
				}
			}
		case:
		}
	case InventorySlotsFilledCondition:
		if c.weapon {
			count := 0
			for weapon in world.player.weapons {
				if weapon.id != .Empty {
					count += 1
				}
			}
			passed_condition = count == c.count

		} else {
			passed_condition = world.player.item_count == c.count
		}
	case KeyPressedCondition:
		if rl.IsKeyPressed(c.key) {
			c.fulfilled = true
		}
		passed_condition = c.fulfilled
	case PlayerInAreaCondition:
		passed_condition = check_collision_shapes(world.player.shape, world.player.pos, c.area, {})
	case EnemyInStateCondition:
		for enemy in world.enemies {
			if enemy.id == c.id {
				passed_condition = enemy.state == c.state
			}
		}
	case PlayerHealthCondition:
		target_health := c.health
		if c.max_health {
			target_health = world.player.max_health
		}
		switch c.check {
		case -2:
			passed_condition = world.player.health < target_health
		case -1:
			passed_condition = world.player.health <= target_health
		case 0:
			passed_condition = world.player.health == target_health
		case 1:
			passed_condition = world.player.health >= target_health
		case 2:
			passed_condition = world.player.health > target_health
		}
	case:
		passed_condition = true
	}
	// this is a shortcut for inverting the value of passed_condition using XOR
	return passed_condition ~ invert_condition
}


/* ---------------------------- MARK:Enemy State ---------------------------- */
update_enemy_state :: proc(enemy: ^Enemy, delta: f32) {
	// enemy.can_see_player = false // temp: prevent enemy from seeing player: stop combat
	switch enemy.state {
	case .Idle:
		if distance_squared(enemy.pos, enemy.post_pos) > square(f32(ENEMY_POST_RANGE)) {
			// use pathfinding to return to post
			update_enemy_pathing(enemy, delta, enemy.post_pos)
			lerp_look_angle(
				enemy,
				angle(enemy.target - enemy.pos) + f32(math.sin(rl.GetTime()) * 10),
				delta,
			)
			enemy.idle_look_angle = enemy.look_angle
			enemy.idle_look_timer = 2
		} else {
			enemy.idle_look_timer -= delta
			if enemy.idle_look_timer <= 0 {
				enemy.idle_look_timer = rand.float32_range(5, 15)
				enemy.idle_look_angle = enemy.look_angle + rand.float32_range(-90, 90)
				for enemy.idle_look_angle > 180 {
					enemy.idle_look_angle -= 360
				}
				for enemy.idle_look_angle < -180 {
					enemy.idle_look_angle += 360
				}
			}
			lerp_look_angle(
				enemy,
				enemy.idle_look_angle + f32(math.sin(rl.GetTime() * 2) * 10),
				delta,
			)
		}
		// fmt.println(enemy.look_angle)
		// fmt.println(enemy.idle_look_angle)

		if enemy.can_see_player {
			if enemy.player_in_flee_range {
				change_enemy_state(enemy, .Fleeing)
			} else {
				change_enemy_state(enemy, .Combat)
			}
		} else if enemy.alert_just_detected {
			change_enemy_state(enemy, .Alerted)
		}
	case .Alerted:
		enemy.alert_timer -= delta

		// look at or investigate distraction
		if enemy.last_alert_intensity_detected > 0.8 &&
		   distance_squared(enemy.pos, enemy.last_alert.pos) > 500 {
			update_enemy_pathing(enemy, delta, enemy.last_alert.pos)
		}
		lerp_look_angle(
			enemy,
			angle(enemy.last_alert.pos - enemy.pos) + f32(math.sin(rl.GetTime()) * 40),
			delta,
		)


		if enemy.can_see_player {
			if enemy.player_in_flee_range {
				change_enemy_state(enemy, .Fleeing)
			} else {
				change_enemy_state(enemy, .Combat)
			}
		} else if enemy.alert_just_detected { 	// if new alert is detected
			change_enemy_state(enemy, .Alerted)
		} else if enemy.alert_timer <= 0 {
			// once alert wears off, go back to idle
			change_enemy_state(enemy, .Idle)
		}
	case .Combat:
		lerp_look_angle(enemy, angle(player.pos - enemy.pos), delta)

		// Attacking
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
							attack = Attack{targets = {.Player, .Wall, .ExplodingBarrel, .Enemy}},
							source = enemy.id,
						},
					)
				}
			}
		}

		// chasing
		if !enemy.charging {
			// use pathfinding to chase player
			update_enemy_pathing(enemy, delta, player.pos)
		}

		// if player is in attack range, start attacking
		if !enemy.flinching &&
		   !enemy.charging &&
		   enemy.can_see_player &&
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


		if !enemy.can_see_player {
			change_enemy_state(enemy, .Searching)
		} else if enemy.player_in_flee_range {
			change_enemy_state(enemy, .Fleeing)
		}
	case .Fleeing:
		// Run directly away from player
		enemy.target = enemy.pos + (enemy.pos - player.pos)
		lerp_look_angle(enemy, angle(player.pos - enemy.pos), delta)
		if !enemy.can_see_player {
			change_enemy_state(enemy, .Searching)
		} else if !enemy.player_in_flee_range {
			change_enemy_state(enemy, .Combat)
		}

	case .Searching:
		switch enemy.search_state {
		case 0:
			// 1 go to last seen player pos
			if distance_squared(enemy.pos, enemy.last_seen_player_pos) >
			   square(f32(ENEMY_SEARCH_TOLERANCE)) {
				enemy.search_timer += delta // accumulate search timer
				update_enemy_pathing(enemy, delta, enemy.last_seen_player_pos)
				lerp_look_angle(
					enemy,
					angle(enemy.target - enemy.pos) + f32(math.sin(8 * rl.GetTime())) * 5,
					delta,
				)
			} else {
				enemy.search_timer *= 2
				enemy.search_state = 1
			}
		case 1:
			// 2 look around
			lerp_look_angle(
				enemy,
				angle(enemy.last_seen_player_vel) + f32(math.sin(rl.GetTime()) * 20),
				delta,
			)

			enemy.search_timer -= delta
			if enemy.search_timer <= 0 {
				enemy.search_timer = 1.0
				enemy.search_state = 2
			}
		case 2:
			// 3 follow last seen player velocity
			enemy.target = enemy.pos + enemy.last_seen_player_vel
			lerp_look_angle(
				enemy,
				angle(enemy.target - enemy.pos) + f32(math.sin(8 * rl.GetTime())) * 5,
				delta,
			)
			enemy.search_timer -= delta
			if enemy.search_timer <= 0 {
				enemy.search_timer = 6.0
				enemy.search_state = 3
			}
		case 3:
			// 4 look around
			lerp_look_angle(
				enemy,
				angle(enemy.last_seen_player_vel) + f32(2 * math.sin(rl.GetTime()) * 40),
				delta,
			)
			enemy.search_timer -= delta
			if enemy.search_timer <= 0 {
				// Go back to idle
				enemy.search_state = 4
			}
		}

		if enemy.can_see_player {
			if enemy.player_in_flee_range {
				change_enemy_state(enemy, .Fleeing)
			} else {
				change_enemy_state(enemy, .Combat)
			}
		} else if enemy.alert_just_detected {
			change_enemy_state(enemy, .Alerted)
		} else if enemy.search_state == 4 {
			change_enemy_state(enemy, .Idle)
		}
	}
}

change_enemy_state :: proc(enemy: ^Enemy, state: EnemyState, world: World) {
	// Exit state code
	switch enemy.state {
	case .Idle:

	case .Alerted:

	case .Combat:

	case .Fleeing:

	case .Searching:

	}

	// Enter state code
	switch state {
	case .Idle:
		enemy.idle_look_timer = 2
		if distance_squared(enemy.pos, enemy.post_pos) > square(f32(ENEMY_POST_RANGE)) {
			start_enemy_pathing(enemy, world, enemy.post_pos)
		}
	case .Alerted:
		base_duration :: 5
		// Reset alert timer
		enemy.alert_timer = base_duration + enemy.last_alert_intensity_detected * 2

		// Determine if we look at or investigate alert
		if enemy.last_alert_intensity_detected > 0.8 {
			start_enemy_pathing(enemy, world, enemy.last_alert.pos)
		}
	case .Combat:
		start_enemy_pathing(enemy, world, world.player.pos)
	case .Fleeing:

	case .Searching:
		enemy.search_timer = 0
		enemy.search_state = 0
		start_enemy_pathing(enemy, world, enemy.last_seen_player_pos)
	}
	fmt.printfln("Enemy: %v, from %v to %v", enemy.id[0], enemy.state, state)

	enemy.state = state
}

lerp_look_angle :: proc(enemy: ^Enemy, target_angle: f32, delta: f32) {
	enemy.look_angle = exp_decay_angle(enemy.look_angle, target_angle, 4, delta)
}

get_effective_intensity :: proc(alert: Alert) -> f32 {
	time_elapsed := f32(rl.GetTime()) - alert.time_emitted
	return alert.base_intensity - alert.decay_rate * time_elapsed
}

get_time_left :: proc(alert: Alert) -> f32 {
	return alert.base_duration - (f32(rl.GetTime()) - alert.time_emitted)
}

start_enemy_pathing :: proc(enemy: ^Enemy, world: World, dest: Vec2) {
	if enemy.current_path != nil {
		delete(enemy.current_path)
	}
	enemy.current_path = find_path_tiles(
		enemy.pos,
		dest,
		world.nav_graph,
		world.tilemap,
		world.wall_tilemap,
	)
	enemy.current_path_point = 1
	enemy.pathfinding_timer = ENEMY_PATHFINDING_TIME
}

// Counts down the pathfinding timer and recalculates the path if necessary
// Also, sets the enemy's target to the current path point, if there is a path to follow. Returns true if there is path to follow
update_enemy_pathing :: proc(enemy: ^Enemy, delta: f32, dest: Vec2) -> bool {
	enemy.pathfinding_timer -= delta
	if enemy.pathfinding_timer < 0 || enemy.current_path_point >= len(enemy.current_path) {
		start_enemy_pathing(enemy, dest)
	}
	if enemy.current_path != nil && enemy.current_path_point < len(enemy.current_path) {
		enemy.target = enemy.current_path[enemy.current_path_point]
		if distance_squared(enemy.pos, enemy.current_path[enemy.current_path_point]) < 16 { 	// Enemy is at the point (tolerance of 16)
			enemy.current_path_point += 1
		}
		return true
	}
	return false
}

reset_speedrun_timer :: proc() {
	speedrun_timer = 0
}
