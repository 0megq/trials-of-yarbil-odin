package game

import "core:crypto"
import "core:fmt"
import "core:math"
import "core:mem"
// import "core:slice"
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
	Nil,
	World,
	Pause,
	Main,
	Win,
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
	{SWORD_HITBOX_OFFSET + 15, -5},
	{SWORD_HITBOX_OFFSET + 17, 0},
	{SWORD_HITBOX_OFFSET + 15, 5},
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
ENEMY_BASIC_SPRITE :: Sprite{.EnemyBasic, {0, 0, 16, 16}, {1, 1}, {7.5, 7.5}, 0, rl.WHITE}
BARREL_SPRITE :: Sprite{.ExplodingBarrel, {0, 0, 12, 12}, {1, 1}, {6, 6}, 0, rl.WHITE}

player_at_portal: bool
seconds_above_distraction_threshold: f32

// "Progress saved!" visuals
completion_show_time: f32 = 0
flash_interval: f32 : 1 // will switch on and off with this interval
max_show_time: f32 : 5

speedrun_timer := f32(0)

debug_speed := f32(1)

game_data: GameData

main_world: World
main_menu: struct {
	play_button:     Button,
	quit_button:     Button,
	feedback_button: Button,
}
pause_menu: struct {
	resume_button:               Button,
	main_menu_button:            Button,
	controls_button:             Button,
	feedback_button:             Button,
	controls_panel_close_button: Button,
	controls_panel_showing:      bool,
}
win_menu: struct {
	play_again_button: Button,
	main_menu_button:  Button,
	quit_button:       Button,
	feedback_button:   Button,
}
menu_change_queued: bool = false
new_menu: Menu = .Main
cur_menu: Menu = .Nil
prev_menu: Menu = .Nil

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

game_should_close := false

call_after_draw_queue: [100]proc()
call_after_draw_length := 0

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
		rl.SetExitKey(.KEY_NULL)
		// Set window values
		window_over_game = f32(window_size.y) / f32(GAME_SIZE.y)
		window_over_ui = f32(window_size.y) / f32(UI_SIZE.y)
	}
	icon := rl.LoadImage("res/images/client_icon.png")
	defer rl.UnloadImage(icon)
	rl.SetWindowIcon(icon)

	// Load resources and data
	{
		load_textures()
		// pixel_filter := rl.LoadShader(nil, "assets/pixel_filter.fs")
		load_game_data()
	}

	// Allocate memory for the main world (Should only happen once)
	{
		load_level(&main_world)
		// We need to allocate memory for the temp entities
		main_world.fires = make([dynamic]Fire, context.allocator)
		main_world.bombs = make([dynamic]Bomb, context.allocator)
		main_world.arrows = make([dynamic]Arrow, context.allocator)

		// Generate new ids for the walls. Potential source of bugs
		// for &wall in level.walls {
		// 	wall.id = uuid.generate_v4()
		// }
	}

	setup_main_menu()
	setup_pause_menu()
	setup_win_menu()

	init_editor_state(&editor_state)

	// Init ui camera
	ui_camera = rl.Camera2D {
		target = Vec2{f32(window_size.x), f32(window_size.y)} / 2,
		zoom   = window_over_ui,
		offset = ({f32(window_size.x), f32(window_size.y)} / 2),
	}

	queue_menu_change(.Main)

	// Update Loop
	for !rl.WindowShouldClose() && !game_should_close {
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
	// delta time and store mouse input
	delta = rl.GetFrameTime()
	mouse_window_pos = rl.GetMousePosition()
	mouse_window_delta = rl.GetMouseDelta()

	if rl.IsWindowResized() {
		handle_window_resize()
	}

	// Update UI Camera and get UI mouse input
	ui_camera.offset = Vec2{f32(window_size.x), f32(window_size.y)} / 2
	ui_camera.zoom = window_over_ui
	ui_camera.target = Vec2{f32(UI_SIZE.x), f32(UI_SIZE.y)} / 2
	mouse_ui_pos = window_to_ui(mouse_window_pos)
	mouse_ui_delta = mouse_window_delta / ui_camera.zoom

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

	if menu_change_queued {
		perform_menu_change()
	}

	#partial switch cur_menu {
	case .World:
		// Editor Hotkeys
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
						reload_level(&main_world)
					}
				}

				if editor_state.mode != .None {
					if rl.IsKeyPressed(.S) {
						save_level()
						// This is here simply to make it easy to update the wall tilemap and navgraph while editing
						place_walls_and_calculate_graph(&main_world)
					} else if rl.IsKeyPressed(.L) {
						reload_level(&main_world)
					} else if rl.IsKeyPressed(.G) {
						editor_state.show_tile_grid = !editor_state.show_tile_grid
					}

					if rl.IsKeyPressed(.RIGHT) {
						save_level()
						game_data.cur_level_idx += 1
						// We reinitialize editor state to clear data from the previous level
						init_editor_state(&editor_state)
						reload_level(&main_world)
					} else if rl.IsKeyPressed(.LEFT) {
						save_level()
						game_data.cur_level_idx -= 1
						init_editor_state(&editor_state)
						reload_level(&main_world)
					}
				}
			}
		}

		// Update Current Editor (Including World!)
		switch editor_state.mode {
		case .Level:
			update_world_camera_and_mouse_pos()
			update_geometry_editor(&main_world, &editor_state)
		case .Entity:
			update_world_camera_and_mouse_pos()
			update_entity_editor(&editor_state)
		case .Tutorial:
			update_world_camera_and_mouse_pos()
			update_tutorial_editor(&editor_state)
		case .None:
			world_update()
		}
		if rl.IsKeyPressed(.ESCAPE) {
			queue_menu_change(.Pause)
		}
	case .Main:
		update_button(&main_menu.play_button, mouse_ui_pos)
		update_button(&main_menu.quit_button, mouse_ui_pos)
		update_button(&main_menu.feedback_button, mouse_ui_pos)
		if main_menu.play_button.status == .Released {
			queue_menu_change(.World)
		} else if main_menu.quit_button.status == .Released {
			game_should_close = true
		} else if main_menu.feedback_button.status == .Released {
			rl.OpenURL(
				"https://docs.google.com/forms/d/e/1FAIpQLSeWk2kYDe3PCVlBTApyw5VWZ6MEjj05QZw44XMP_cwDo6bmxg/viewform?usp=header",
			)
		}
	case .Pause:
		if !pause_menu.controls_panel_showing {
			update_button(&pause_menu.resume_button, mouse_ui_pos)
			update_button(&pause_menu.controls_button, mouse_ui_pos)
			update_button(&pause_menu.main_menu_button, mouse_ui_pos)
			update_button(&pause_menu.feedback_button, mouse_ui_pos)
			if pause_menu.resume_button.status == .Released {
				queue_menu_change(.World)
			} else if pause_menu.controls_button.status == .Released {
				pause_menu.controls_panel_showing = true
			} else if pause_menu.main_menu_button.status == .Released {
				queue_menu_change(.Main)
			} else if pause_menu.feedback_button.status == .Released {
				rl.OpenURL(
					"https://docs.google.com/forms/d/e/1FAIpQLSeWk2kYDe3PCVlBTApyw5VWZ6MEjj05QZw44XMP_cwDo6bmxg/viewform?usp=header",
				)
			}
			if rl.IsKeyPressed(.ESCAPE) {
				queue_menu_change(.World)
			}
		} else {
			update_button(&pause_menu.controls_panel_close_button, mouse_ui_pos)
			if pause_menu.controls_panel_close_button.status == .Released ||
			   rl.IsKeyPressed(.ESCAPE) {
				pause_menu.controls_panel_showing = false
			}
		}
	case .Win:
		update_button(&win_menu.play_again_button, mouse_ui_pos)
		update_button(&win_menu.main_menu_button, mouse_ui_pos)
		update_button(&win_menu.quit_button, mouse_ui_pos)
		update_button(&win_menu.feedback_button, mouse_ui_pos)
		if win_menu.play_again_button.status == .Released {
			// Load base data (99) and save it into our current data
			reload_game_data(99)
			save_game_data()
			reload_level(&main_world)
			queue_menu_change(.World)
		} else if win_menu.main_menu_button.status == .Released {
			// reload_game_data(99)
			// save_game_data()
			// call_after_draw(proc() {reload_level(&main_world)})
			queue_menu_change(.Main)
		} else if win_menu.quit_button.status == .Released {
			game_should_close = true
		} else if win_menu.feedback_button.status == .Released {
			rl.OpenURL(
				"https://docs.google.com/forms/d/e/1FAIpQLSeWk2kYDe3PCVlBTApyw5VWZ6MEjj05QZw44XMP_cwDo6bmxg/viewform?usp=header",
			)
		}
	}

	draw_frame()

	for idx in 0 ..< call_after_draw_length {
		call_after_draw_queue[idx]()
	}
	call_after_draw_length = 0

	free_all(context.temp_allocator)
}

draw_frame :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.DARKGRAY)

	rl.BeginMode2D(world_camera)
	#partial switch cur_menu {
	case .World:
		draw_world(main_world)
	case .Pause:
		draw_world(main_world)
	case .Win:
		draw_world(main_world)
	}
	rl.EndMode2D()

	rl.BeginMode2D(ui_camera)
	#partial switch cur_menu {
	case .World:
		draw_world_ui(main_world)
	case .Main:
		rl.DrawTexture(
			loaded_textures[.TitleScreen],
			UI_SIZE.x / 2 - loaded_textures[.TitleScreen].width / 2,
			-80,
			rl.WHITE,
		)
		draw_button(main_menu.play_button)
		draw_button(main_menu.quit_button)
		draw_button(main_menu.feedback_button)
	case .Pause:
		draw_world_ui(main_world)
		rl.DrawRectangle(0, 0, UI_SIZE.x, UI_SIZE.y, {0, 0, 0, 100})
		draw_button(pause_menu.resume_button)
		draw_button(pause_menu.controls_button)
		draw_button(pause_menu.main_menu_button)
		draw_button(pause_menu.feedback_button)

		// Pause text
		{
			text: cstring = "Paused"
			font_size: f32 = 30
			spacing: f32 = 2
			center := Vec2{f32(UI_SIZE.x) / 2, f32(UI_SIZE.y) * 0.1}
			pos := get_centered_text_pos(center, text, font_size, spacing)
			rl.DrawRectangleRec(
				get_centered_rect(center, {f32(UI_SIZE.x), 50}),
				{200, 200, 255, 255},
			)
			rl.DrawTextEx(rl.GetFontDefault(), text, pos, font_size, spacing, rl.BLACK)
		}
		// Controls panel
		if pause_menu.controls_panel_showing {
			rl.DrawRectangle(0, 0, UI_SIZE.x, UI_SIZE.y, {0, 0, 0, 100})
			rec := get_centered_rect(
				{f32(UI_SIZE.x), f32(UI_SIZE.y)} / 2,
				{f32(UI_SIZE.x) * 0.3, f32(UI_SIZE.y) * 0.8},
			)
			// Panel Background
			rl.DrawRectangleRec(rec, {103, 132, 201, 255})

			// Panel Elements
			draw_button(pause_menu.controls_panel_close_button)

			x := rec.x + rec.width * 0.5
			cur_y: f32 = rec.y + 120
			width: f32 = 300
			height: f32 = 40
			font_size: f32 = 20
			spacing: f32 = 2

			{
				// Draw background panel
				// rl.DrawRectangleRec(get_centered_rect({x, cur_y}, {width, height}), rl.WHITE)

				label: cstring = "Move"
				control: cstring = "WASD"

				// Draw label
				left: Vec2 = get_left_text_pos({x - width / 2, cur_y}, label, font_size, spacing)
				rl.DrawTextEx(rl.GetFontDefault(), label, left, font_size, spacing, rl.BLACK)
				// Draw control
				right := get_right_text_pos({x + width / 2, cur_y}, control, font_size, spacing)
				rl.DrawTextEx(rl.GetFontDefault(), control, right, font_size, spacing, rl.BLACK)
			}

			// fire
			cur_y += height
			{
				label: cstring = "Attack"
				control: cstring = "LMB"

				// Draw label
				left: Vec2 = get_left_text_pos({x - width / 2, cur_y}, label, font_size, spacing)
				rl.DrawTextEx(rl.GetFontDefault(), label, left, font_size, spacing, rl.BLACK)
				// Draw control
				right := get_right_text_pos({x + width / 2, cur_y}, control, font_size, spacing)
				rl.DrawTextEx(rl.GetFontDefault(), control, right, font_size, spacing, rl.BLACK)
			}

			// dash
			cur_y += height
			{
				label: cstring = "Dash"
				control: cstring = "Space"

				// Draw label
				left: Vec2 = get_left_text_pos({x - width / 2, cur_y}, label, font_size, spacing)
				rl.DrawTextEx(rl.GetFontDefault(), label, left, font_size, spacing, rl.BLACK)
				// Draw control
				right := get_right_text_pos({x + width / 2, cur_y}, control, font_size, spacing)
				rl.DrawTextEx(rl.GetFontDefault(), control, right, font_size, spacing, rl.BLACK)
			}

			// use_item
			cur_y += height
			{
				label: cstring = "Use Item"
				control: cstring = "RMB"

				// Draw label
				left: Vec2 = get_left_text_pos({x - width / 2, cur_y}, label, font_size, spacing)
				rl.DrawTextEx(rl.GetFontDefault(), label, left, font_size, spacing, rl.BLACK)
				// Draw control
				right := get_right_text_pos({x + width / 2, cur_y}, control, font_size, spacing)
				rl.DrawTextEx(rl.GetFontDefault(), control, right, font_size, spacing, rl.BLACK)
			}

			// pickup/use_portal
			cur_y += height
			{
				label: cstring = "Pickup Item"
				control: cstring = "E"

				// Draw label
				left: Vec2 = get_left_text_pos({x - width / 2, cur_y}, label, font_size, spacing)
				rl.DrawTextEx(rl.GetFontDefault(), label, left, font_size, spacing, rl.BLACK)
				// Draw control
				right := get_right_text_pos({x + width / 2, cur_y}, control, font_size, spacing)
				rl.DrawTextEx(rl.GetFontDefault(), control, right, font_size, spacing, rl.BLACK)
			}

			cur_y += height
			{
				label: cstring = "Enter Portal"
				control: cstring = "E"

				// Draw label
				left: Vec2 = get_left_text_pos({x - width / 2, cur_y}, label, font_size, spacing)
				rl.DrawTextEx(rl.GetFontDefault(), label, left, font_size, spacing, rl.BLACK)
				// Draw control
				right := get_right_text_pos({x + width / 2, cur_y}, control, font_size, spacing)
				rl.DrawTextEx(rl.GetFontDefault(), control, right, font_size, spacing, rl.BLACK)
			}
		}
	case .Win:
		draw_world_ui(main_world)
		rl.DrawRectangle(0, 0, UI_SIZE.x, UI_SIZE.y, {0, 0, 0, 100})
		draw_button(win_menu.play_again_button)
		draw_button(win_menu.main_menu_button)
		draw_button(win_menu.feedback_button)
		draw_button(win_menu.quit_button)
		// Draw win text and background
		{
			text: cstring = "You win!"
			font_size: f32 = 30
			spacing: f32 = 2
			center := Vec2{f32(UI_SIZE.x) / 2, f32(UI_SIZE.y) * 0.1}
			pos := get_centered_text_pos(center, text, font_size, spacing)
			rl.DrawRectangleRec(
				get_centered_rect(center, {f32(UI_SIZE.x), 50}),
				{200, 255, 255, 255},
			)
			rl.DrawTextEx(rl.GetFontDefault(), text, pos, font_size, spacing, rl.BLACK)
		}
	}
	rl.EndMode2D()

	rl.EndDrawing()
}

call_after_draw :: proc(call: proc()) {
	if call_after_draw_length >= len(call_after_draw_queue) {
		rl.TraceLog(.ERROR, "call_after_draw_queue not big enough! Increase size")
	}
	call_after_draw_queue[call_after_draw_length] = call
	call_after_draw_length += 1
}

queue_menu_change :: proc(menu: Menu) {
	menu_change_queued = true
	new_menu = menu
}

perform_menu_change :: proc() {
	// Exit
	switch cur_menu {
	case .World:
	case .Pause:
	case .Main:
	case .Win:
	case .Nil:
	}

	// Entry
	switch new_menu {
	case .World:
	case .Pause:
	case .Main:
	case .Win:
	case .Nil:
	}

	prev_menu = cur_menu
	cur_menu = new_menu
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

handle_window_resize :: proc() {
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

almost_equals :: proc(a: f32, b: f32, epsilon: f32 = 0.001) -> bool {
	return math.abs(a - b) <= epsilon
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

// returns the position of the given text centered at center
get_centered_text_pos :: proc(center: Vec2, text: cstring, font_size: f32, spacing: f32) -> Vec2 {
	return center - rl.MeasureTextEx(rl.GetFontDefault(), text, font_size, spacing) / 2
}

// returns the position of the given text aligned to the right
get_right_text_pos :: proc(right: Vec2, text: cstring, font_size: f32, spacing: f32) -> Vec2 {
	size := rl.MeasureTextEx(rl.GetFontDefault(), text, font_size, spacing)
	return right - {size.x, size.y / 2}
}

// returns the position of the given text aligned to the left
get_left_text_pos :: proc(left: Vec2, text: cstring, font_size: f32, spacing: f32) -> Vec2 {
	size := rl.MeasureTextEx(rl.GetFontDefault(), text, font_size, spacing)
	return left - {0, size.y / 2}
}
